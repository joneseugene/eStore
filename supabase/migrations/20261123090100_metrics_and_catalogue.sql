-- =============================================================================
-- Metrics (drive allocation) and catalogue (items, funding, lots).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Metric definitions, e.g. enrolment with dimensions grade × sex
-- dimensions: [{"key":"grade","label":"Grade","values":["Class 1",...]}, ...]
-- -----------------------------------------------------------------------------
create table public.metric_definitions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  unit_level_id uuid not null,
  key text not null check (key ~ '^[a-z][a-z0-9_]*$'),
  label text not null,
  dimensions jsonb not null default '[]'::jsonb check (jsonb_typeof(dimensions) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, key),
  unique (id, organization_id),
  foreign key (unit_level_id, organization_id)
    references public.unit_levels (id, organization_id) on delete restrict
);

create trigger metric_definitions_updated_at before update on public.metric_definitions
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Periods, e.g. academic year 2025/2026. At most one current per org.
-- -----------------------------------------------------------------------------
create table public.periods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_current boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name),
  unique (id, organization_id),
  check (ends_on > starts_on)
);

create unique index periods_one_current_per_org
  on public.periods (organization_id) where is_current;

create trigger periods_updated_at before update on public.periods
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Metric values: one number per unit / metric / period / dimension combination.
-- Only entered at the metric's level; totals higher up are rolled up, never stored.
-- -----------------------------------------------------------------------------
create table public.metric_values (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_id uuid not null,
  metric_id uuid not null,
  period_id uuid not null,
  dimension_values jsonb not null default '{}'::jsonb
    check (jsonb_typeof(dimension_values) = 'object'),
  value numeric not null check (value >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_id, metric_id, period_id, dimension_values),
  foreign key (unit_id, organization_id)
    references public.units (id, organization_id) on delete cascade,
  foreign key (metric_id, organization_id)
    references public.metric_definitions (id, organization_id) on delete restrict,
  foreign key (period_id, organization_id)
    references public.periods (id, organization_id) on delete restrict
);

create index metric_values_metric_period_idx on public.metric_values (metric_id, period_id);

create trigger metric_values_updated_at before update on public.metric_values
  for each row execute function private.set_updated_at();

-- Every defined dimension must be present with an allowed value, and the unit
-- must be at the metric's level.
create function private.validate_metric_value()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_metric record;
  v_dim jsonb;
  v_key text;
  v_unit_level uuid;
begin
  select unit_level_id, dimensions, label into v_metric
  from public.metric_definitions where id = new.metric_id;

  select level_id into v_unit_level from public.units where id = new.unit_id;

  if v_unit_level <> v_metric.unit_level_id then
    raise exception 'Metric "%" is not recorded at this unit''s level', v_metric.label
      using errcode = 'check_violation';
  end if;

  for v_key in select jsonb_object_keys(new.dimension_values) loop
    if not exists (
      select 1 from jsonb_array_elements(v_metric.dimensions) d where d ->> 'key' = v_key
    ) then
      raise exception 'Unknown dimension "%" for metric "%"', v_key, v_metric.label
        using errcode = 'check_violation';
    end if;
  end loop;

  for v_dim in select jsonb_array_elements(v_metric.dimensions) loop
    if not (new.dimension_values ? (v_dim ->> 'key')) then
      raise exception 'Dimension "%" is required for metric "%"', v_dim ->> 'label', v_metric.label
        using errcode = 'check_violation';
    end if;
    if not (v_dim -> 'values') @> jsonb_build_array(new.dimension_values -> (v_dim ->> 'key')) then
      raise exception 'Value % is not allowed for dimension "%"',
        new.dimension_values -> (v_dim ->> 'key'), v_dim ->> 'label'
        using errcode = 'check_violation';
    end if;
  end loop;

  return new;
end;
$$;

create trigger metric_values_validate
  before insert or update on public.metric_values
  for each row execute function private.validate_metric_value();

-- -----------------------------------------------------------------------------
-- Funding sources
-- -----------------------------------------------------------------------------
create type public.funding_source_type as enum ('government', 'multilateral', 'ngo', 'other');

create table public.funding_sources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  name text not null,
  type public.funding_source_type not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name),
  unique (id, organization_id)
);

create trigger funding_sources_updated_at before update on public.funding_sources
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Items and pack sizes
-- -----------------------------------------------------------------------------
create table public.items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  name text not null,
  sku text not null,
  category text,
  base_unit text not null,               -- e.g. "book", "bag (50kg)"
  is_perishable boolean not null default false,
  -- Tags / targeting, e.g. {"target_grades": ["Class 4"]}
  attributes jsonb not null default '{}'::jsonb check (jsonb_typeof(attributes) = 'object'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, sku),
  unique (id, organization_id)
);

create trigger items_updated_at before update on public.items
  for each row execute function private.set_updated_at();

create table public.item_pack_sizes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  item_id uuid not null,
  name text not null,                     -- e.g. "carton"
  quantity_in_base integer not null check (quantity_in_base > 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (item_id, name),
  unique (id, organization_id),
  foreign key (item_id, organization_id)
    references public.items (id, organization_id) on delete cascade
);

create trigger item_pack_sizes_updated_at before update on public.item_pack_sizes
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Stock lots: every unit of stock belongs to one, so donor traceability
-- survives every handover. Created only by stock functions.
-- -----------------------------------------------------------------------------
create table public.stock_lots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  item_id uuid not null,
  funding_source_id uuid not null,
  batch_number text,
  expiry_date date,
  first_received_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (item_id, funding_source_id, batch_number, expiry_date),
  unique (id, organization_id),
  foreign key (item_id, organization_id)
    references public.items (id, organization_id) on delete restrict,
  foreign key (funding_source_id, organization_id)
    references public.funding_sources (id, organization_id) on delete restrict
);

create trigger stock_lots_updated_at before update on public.stock_lots
  for each row execute function private.set_updated_at();
