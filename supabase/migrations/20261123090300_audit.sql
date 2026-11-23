-- =============================================================================
-- Audit log: written by triggers on all important tables.
-- metric_values (bulk census imports) and stock_movements (already an
-- append-only ledger) are deliberately not audited row by row.
-- =============================================================================

create table public.audit_log (
  id bigint generated always as identity primary key,
  organization_id uuid,
  actor_id uuid,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  entity text not null,
  entity_id uuid,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_entity_idx on public.audit_log (entity, entity_id);
create index audit_log_org_time_idx on public.audit_log (organization_id, created_at desc);

create function private.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_after jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_row jsonb := coalesce(v_after, v_before);
begin
  -- Skip no-op updates (e.g. only updated_at changed).
  if tg_op = 'UPDATE'
     and (v_before - 'updated_at') = (v_after - 'updated_at') then
    return null;
  end if;

  insert into public.audit_log (organization_id, actor_id, action, entity, entity_id, before, after)
  values (
    case when tg_table_name = 'organizations'
      then (v_row ->> 'id')::uuid
      else (v_row ->> 'organization_id')::uuid
    end,
    auth.uid(),
    tg_op,
    tg_table_name,
    (v_row ->> 'id')::uuid,
    v_before,
    v_after
  );
  return null;
end;
$$;

create function private.audit_log_is_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_log is append-only' using errcode = 'insufficient_privilege';
end;
$$;

create trigger audit_log_no_update
  before update or delete on public.audit_log
  for each row execute function private.audit_log_is_append_only();

do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations', 'profiles', 'unit_levels', 'attribute_definitions', 'units', 'memberships',
    'metric_definitions', 'periods', 'funding_sources', 'items', 'item_pack_sizes',
    'stock_lots', 'receipts', 'receipt_lines', 'allocation_plans', 'allocation_lines',
    'dispatches', 'dispatch_lines'
  ] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function private.write_audit_log()',
      t || '_audit', t
    );
  end loop;
end;
$$;
