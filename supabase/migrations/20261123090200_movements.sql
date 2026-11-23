-- =============================================================================
-- Movements: receipts, allocations, dispatches, the stock ledger and balances.
-- Stock-changing transitions happen only in Postgres functions (Phases 4-5);
-- clients may create and edit drafts directly, under RLS.
-- =============================================================================

create type public.receipt_status as enum ('draft', 'posted');
create type public.allocation_status as enum ('draft', 'approved', 'executed', 'cancelled');
create type public.allocation_basis as enum ('metric', 'end_point_count', 'manual');
create type public.dispatch_status as enum (
  'draft', 'approved', 'in_transit', 'delivered', 'disputed', 'cancelled'
);
create type public.movement_type as enum (
  'receipt', 'dispatch_out', 'dispatch_in', 'issue', 'adjustment', 'loss_damage', 'return'
);

-- -----------------------------------------------------------------------------
-- Document numbers: {ORG}-{TYPE}-{YYYY}-{SEQ6}, sequence resets each year.
-- -----------------------------------------------------------------------------
create table private.document_counters (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  doc_type text not null,
  year integer not null,
  last_value integer not null default 0,
  primary key (organization_id, doc_type, year)
);

create function private.next_document_number(p_org uuid, p_doc_type text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.organizations;
  v_tz text;
  v_year integer;
  v_seq integer;
  v_format text;
begin
  select * into strict v_org from public.organizations where id = p_org;
  v_tz := coalesce(v_org.settings ->> 'timezone', 'Africa/Freetown');
  v_year := extract(year from now() at time zone v_tz)::integer;
  v_format := coalesce(v_org.settings ->> 'document_number_format', '{ORG}-{TYPE}-{YYYY}-{SEQ6}');

  insert into private.document_counters as c (organization_id, doc_type, year, last_value)
  values (p_org, p_doc_type, v_year, 1)
  on conflict (organization_id, doc_type, year)
    do update set last_value = c.last_value + 1
  returning last_value into v_seq;

  return replace(replace(replace(replace(v_format,
    '{ORG}', v_org.acronym),
    '{TYPE}', p_doc_type),
    '{YYYY}', v_year::text),
    '{SEQ6}', lpad(v_seq::text, 6, '0'));
end;
$$;

-- -----------------------------------------------------------------------------
-- Idempotency: one row per client-generated key, recorded by stock functions.
-- -----------------------------------------------------------------------------
create table private.processed_requests (
  idempotency_key uuid primary key,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid,
  operation text not null,
  result jsonb,
  created_at timestamptz not null default now()
);

-- -----------------------------------------------------------------------------
-- Receipts (inbound waybills at a store)
-- -----------------------------------------------------------------------------
create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  document_number text,                    -- assigned when posted
  waybill_number text not null,
  funding_source_id uuid not null,
  supplier text,
  vehicle_number text,
  driver_name text,
  driver_phone text,
  received_at timestamptz not null default now(),
  received_by uuid references public.profiles (id),
  status public.receipt_status not null default 'draft',
  notes text,
  photo_paths text[] not null default '{}',
  posted_at timestamptz,
  posted_by uuid references public.profiles (id),
  created_by uuid references public.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, document_number),
  unique (id, organization_id),
  foreign key (unit_id, organization_id)
    references public.units (id, organization_id) on delete restrict,
  foreign key (funding_source_id, organization_id)
    references public.funding_sources (id, organization_id) on delete restrict
);

create index receipts_unit_idx on public.receipts (unit_id, received_at desc);

create trigger receipts_updated_at before update on public.receipts
  for each row execute function private.set_updated_at();

create table public.receipt_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  receipt_id uuid not null,
  item_id uuid not null,
  batch_number text,
  expiry_date date,
  quantity_on_waybill numeric not null check (quantity_on_waybill >= 0),
  quantity_received numeric not null check (quantity_received >= 0),
  quantity_damaged numeric not null default 0 check (quantity_damaged >= 0),
  lot_id uuid,                              -- set when posted
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Damaged goods are a subset of what physically arrived.
  check (quantity_damaged <= quantity_received),
  foreign key (receipt_id, organization_id)
    references public.receipts (id, organization_id) on delete cascade,
  foreign key (item_id, organization_id)
    references public.items (id, organization_id) on delete restrict,
  foreign key (lot_id, organization_id)
    references public.stock_lots (id, organization_id) on delete restrict
);

create index receipt_lines_receipt_idx on public.receipt_lines (receipt_id);

create trigger receipt_lines_updated_at before update on public.receipt_lines
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Allocation plans
-- -----------------------------------------------------------------------------
create table public.allocation_plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  document_number text,
  from_unit_id uuid not null,
  item_id uuid not null,
  pack_size_id uuid,
  total_quantity numeric not null check (total_quantity > 0),
  basis public.allocation_basis not null,
  basis_metric_id uuid,
  basis_dimension_filter jsonb not null default '{}'::jsonb,
  attribute_filters jsonb not null default '{}'::jsonb,
  target_level_id uuid not null,
  period_id uuid,
  status public.allocation_status not null default 'draft',
  notes text,
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  created_by uuid references public.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, document_number),
  unique (id, organization_id),
  check ((basis = 'metric') = (basis_metric_id is not null)),
  check (basis <> 'metric' or period_id is not null),
  foreign key (from_unit_id, organization_id)
    references public.units (id, organization_id) on delete restrict,
  foreign key (item_id, organization_id)
    references public.items (id, organization_id) on delete restrict,
  foreign key (pack_size_id, organization_id)
    references public.item_pack_sizes (id, organization_id) on delete restrict,
  foreign key (basis_metric_id, organization_id)
    references public.metric_definitions (id, organization_id) on delete restrict,
  foreign key (target_level_id, organization_id)
    references public.unit_levels (id, organization_id) on delete restrict,
  foreign key (period_id, organization_id)
    references public.periods (id, organization_id) on delete restrict
);

create index allocation_plans_from_unit_idx on public.allocation_plans (from_unit_id);

create trigger allocation_plans_updated_at before update on public.allocation_plans
  for each row execute function private.set_updated_at();

create table public.allocation_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  plan_id uuid not null,
  to_unit_id uuid not null,
  basis_count numeric not null default 0 check (basis_count >= 0),
  proposed_quantity numeric not null default 0 check (proposed_quantity >= 0),
  final_quantity numeric not null default 0 check (final_quantity >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, to_unit_id),
  foreign key (plan_id, organization_id)
    references public.allocation_plans (id, organization_id) on delete cascade,
  foreign key (to_unit_id, organization_id)
    references public.units (id, organization_id) on delete restrict
);

create index allocation_lines_to_unit_idx on public.allocation_lines (to_unit_id);

create trigger allocation_lines_updated_at before update on public.allocation_lines
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Dispatches (unit → unit, including DEO → school deliveries)
-- -----------------------------------------------------------------------------
create table public.dispatches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  document_number text,
  from_unit_id uuid not null,
  to_unit_id uuid not null,
  allocation_plan_id uuid,
  status public.dispatch_status not null default 'draft',
  vehicle_number text,
  driver_name text,
  driver_phone text,
  approved_by uuid references public.profiles (id),
  approved_at timestamptz,
  dispatched_by uuid references public.profiles (id),
  dispatched_at timestamptz,
  -- Receiver: a user, or (for end points that don't log in) a named person.
  received_by uuid references public.profiles (id),
  received_by_name text,
  received_at timestamptz,
  receiver_note text,
  photo_paths text[] not null default '{}',
  created_by uuid references public.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, document_number),
  unique (id, organization_id),
  check (from_unit_id <> to_unit_id),
  foreign key (from_unit_id, organization_id)
    references public.units (id, organization_id) on delete restrict,
  foreign key (to_unit_id, organization_id)
    references public.units (id, organization_id) on delete restrict,
  foreign key (allocation_plan_id, organization_id)
    references public.allocation_plans (id, organization_id) on delete restrict
);

create index dispatches_from_idx on public.dispatches (from_unit_id, created_at desc);
create index dispatches_to_idx on public.dispatches (to_unit_id, created_at desc);
create index dispatches_plan_idx on public.dispatches (allocation_plan_id);

create trigger dispatches_updated_at before update on public.dispatches
  for each row execute function private.set_updated_at();

create table public.dispatch_lines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  dispatch_id uuid not null,
  item_id uuid not null,
  lot_id uuid,                              -- chosen FEFO/FIFO when dispatched
  quantity_sent numeric not null check (quantity_sent > 0),
  quantity_received numeric check (quantity_received >= 0),
  discrepancy_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (dispatch_id, organization_id)
    references public.dispatches (id, organization_id) on delete cascade,
  foreign key (item_id, organization_id)
    references public.items (id, organization_id) on delete restrict,
  foreign key (lot_id, organization_id)
    references public.stock_lots (id, organization_id) on delete restrict
);

create index dispatch_lines_dispatch_idx on public.dispatch_lines (dispatch_id);

create trigger dispatch_lines_updated_at before update on public.dispatch_lines
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Stock ledger: append-only. Corrections are new adjustment rows.
-- -----------------------------------------------------------------------------
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  item_id uuid not null,
  lot_id uuid not null,
  movement_type public.movement_type not null,
  quantity numeric not null check (quantity <> 0),   -- signed
  source_type text not null,                          -- 'receipt', 'dispatch', 'adjustment', ...
  source_id uuid,
  source_line_id uuid,
  reason text,
  idempotency_key uuid,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  foreign key (unit_id, organization_id)
    references public.units (id, organization_id) on delete restrict,
  foreign key (item_id, organization_id)
    references public.items (id, organization_id) on delete restrict,
  foreign key (lot_id, organization_id)
    references public.stock_lots (id, organization_id) on delete restrict
);

create index stock_movements_balance_idx on public.stock_movements (unit_id, item_id, lot_id);
create index stock_movements_source_idx on public.stock_movements (source_type, source_id);
create index stock_movements_lot_idx on public.stock_movements (lot_id);

create function private.ledger_is_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'stock_movements is append-only; record an adjustment instead'
    using errcode = 'insufficient_privilege';
end;
$$;

create trigger stock_movements_no_update
  before update or delete on public.stock_movements
  for each row execute function private.ledger_is_append_only();

create trigger stock_movements_no_truncate
  before truncate on public.stock_movements
  for each statement execute function private.ledger_is_append_only();

-- Balances: a plain view over the ledger. security_invoker makes the caller's
-- RLS on stock_movements apply.
create view public.stock_balances
with (security_invoker = true)
as
select
  organization_id,
  unit_id,
  item_id,
  lot_id,
  sum(quantity) as quantity,
  max(created_at) as last_movement_at
from public.stock_movements
group by organization_id, unit_id, item_id, lot_id;
