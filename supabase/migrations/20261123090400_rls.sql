-- =============================================================================
-- Row Level Security.
--
-- Model: a membership (user, unit, role) grants access to that unit and all
-- its descendants (ltree subtree). Users can also see the *names* of their
-- units' ancestors (e.g. "MBSSE National Store" on an incoming dispatch), but
-- never siblings: a DEO officer in Western Area Rural cannot see another
-- district's schools or stock.
--
-- Every table has RLS enabled. anon has no access to anything. Status
-- transitions, document numbers and all stock changes happen only in
-- SECURITY DEFINER functions (Phases 4-5); column grants stop clients from
-- writing those columns directly.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Helper functions (SECURITY DEFINER so they can read memberships/units
-- without recursing through RLS; STABLE so the planner can cache them).
-- -----------------------------------------------------------------------------

create function private.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select is_platform_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

-- Is the current user a member of the org (optionally with one of p_roles)?
create function private.is_org_member(p_org uuid, p_roles public.app_role[] default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid()
      and m.organization_id = p_org
      and (p_roles is null or m.role = any (p_roles))
  );
$$;

-- Does the current user hold one of p_roles (any role if null) at p_unit or
-- one of its ancestors?
create function private.has_unit_access(p_unit uuid, p_roles public.app_role[] default null)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    join public.units mu on mu.id = m.unit_id
    join public.units u on u.id = p_unit
    where m.user_id = auth.uid()
      and u.organization_id = m.organization_id
      and u.path operator(extensions.<@) mu.path
      and (p_roles is null or m.role = any (p_roles))
  );
$$;

-- Units in the current user's subtrees. Used as `x in (select ...)` so the
-- set is computed once per query rather than once per row.
create function private.accessible_unit_ids(p_roles public.app_role[] default null)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from public.memberships m
  join public.units mu on mu.id = m.unit_id
  join public.units u
    on u.organization_id = m.organization_id
   and u.path operator(extensions.<@) mu.path
  where m.user_id = auth.uid()
    and (p_roles is null or m.role = any (p_roles));
$$;

-- Subtree units plus the ancestors of the user's membership units.
create function private.visible_unit_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from public.memberships m
  join public.units mu on mu.id = m.unit_id
  join public.units u
    on u.organization_id = m.organization_id
   and (u.path operator(extensions.<@) mu.path or u.path operator(extensions.@>) mu.path)
  where m.user_id = auth.uid();
$$;

create function private.is_end_point_level(p_level uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select is_end_point from public.unit_levels where id = p_level), false);
$$;

-- Do the current user and p_user share an organization?
create function private.shares_org_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships mine
    join public.memberships theirs on theirs.organization_id = mine.organization_id
    where mine.user_id = auth.uid() and theirs.user_id = p_user
  );
$$;

revoke all on all functions in schema private from public, anon;
grant execute on function
  private.is_platform_admin(),
  private.is_org_member(uuid, public.app_role[]),
  private.has_unit_access(uuid, public.app_role[]),
  private.accessible_unit_ids(public.app_role[]),
  private.visible_unit_ids(),
  private.is_end_point_level(uuid),
  private.shares_org_with(uuid)
to authenticated;

-- -----------------------------------------------------------------------------
-- Enable RLS on every table in public.
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- Organizations and profiles
-- -----------------------------------------------------------------------------
create policy "members read their organizations" on public.organizations
  for select to authenticated
  using (private.is_platform_admin() or private.is_org_member(id));

create policy "platform admins create organizations" on public.organizations
  for insert to authenticated
  with check (private.is_platform_admin());

create policy "org admins update their organization" on public.organizations
  for update to authenticated
  using (private.is_platform_admin() or private.is_org_member(id, '{org_admin}'))
  with check (private.is_platform_admin() or private.is_org_member(id, '{org_admin}'));

create policy "read own and co-member profiles" on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or private.is_platform_admin()
    or private.shares_org_with(id)
  );

create policy "update own profile" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- -----------------------------------------------------------------------------
-- Org-wide configuration: any member reads, org admins write.
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'unit_levels', 'attribute_definitions', 'metric_definitions', 'periods',
    'funding_sources', 'items', 'item_pack_sizes'
  ] loop
    execute format($p$
      create policy "members read" on public.%1$I
        for select to authenticated
        using (private.is_org_member(organization_id) or private.is_platform_admin());
      create policy "org admins insert" on public.%1$I
        for insert to authenticated
        with check (private.is_org_member(organization_id, '{org_admin}'));
      create policy "org admins update" on public.%1$I
        for update to authenticated
        using (private.is_org_member(organization_id, '{org_admin}'))
        with check (private.is_org_member(organization_id, '{org_admin}'));
      create policy "org admins delete" on public.%1$I
        for delete to authenticated
        using (private.is_org_member(organization_id, '{org_admin}'));
    $p$, t);
  end loop;
end;
$$;

create policy "members read lots" on public.stock_lots
  for select to authenticated
  using (private.is_org_member(organization_id) or private.is_platform_admin());

-- -----------------------------------------------------------------------------
-- Units
-- -----------------------------------------------------------------------------
create policy "read subtree and ancestors" on public.units
  for select to authenticated
  using (id in (select private.visible_unit_ids()) or private.is_platform_admin());

-- Org admins manage units under units they administer (or create a root);
-- unit officers may add/edit end points under their own unit (school import).
create policy "admins and officers insert units" on public.units
  for insert to authenticated
  with check (
    (parent_id is null and private.is_org_member(organization_id, '{org_admin}'))
    or private.has_unit_access(parent_id, '{org_admin}')
    or (private.has_unit_access(parent_id, '{unit_officer}') and private.is_end_point_level(level_id))
  );

create policy "admins and officers update units" on public.units
  for update to authenticated
  using (
    private.has_unit_access(id, '{org_admin}')
    or (private.has_unit_access(id, '{unit_officer}') and private.is_end_point_level(level_id))
  )
  with check (
    (parent_id is null and private.is_org_member(organization_id, '{org_admin}'))
    or private.has_unit_access(parent_id, '{org_admin}')
    or (private.has_unit_access(parent_id, '{unit_officer}') and private.is_end_point_level(level_id))
  );

create policy "admins delete units" on public.units
  for delete to authenticated
  using (private.has_unit_access(id, '{org_admin}'));

-- -----------------------------------------------------------------------------
-- Memberships: users see their own; org admins manage within their subtree.
-- -----------------------------------------------------------------------------
create policy "read own or administered memberships" on public.memberships
  for select to authenticated
  using (user_id = (select auth.uid()) or private.has_unit_access(unit_id, '{org_admin}'));

create policy "admins insert memberships" on public.memberships
  for insert to authenticated
  with check (private.has_unit_access(unit_id, '{org_admin}'));

create policy "admins update memberships" on public.memberships
  for update to authenticated
  using (private.has_unit_access(unit_id, '{org_admin}'))
  with check (private.has_unit_access(unit_id, '{org_admin}'));

create policy "admins delete memberships" on public.memberships
  for delete to authenticated
  using (private.has_unit_access(unit_id, '{org_admin}'));

-- -----------------------------------------------------------------------------
-- Metric values: subtree read; admins and unit officers write (census import).
-- -----------------------------------------------------------------------------
create policy "read subtree metric values" on public.metric_values
  for select to authenticated
  using (unit_id in (select private.accessible_unit_ids()));

create policy "officers insert metric values" on public.metric_values
  for insert to authenticated
  with check (private.has_unit_access(unit_id, '{org_admin,unit_officer}'));

create policy "officers update metric values" on public.metric_values
  for update to authenticated
  using (private.has_unit_access(unit_id, '{org_admin,unit_officer}'))
  with check (private.has_unit_access(unit_id, '{org_admin,unit_officer}'));

create policy "officers delete metric values" on public.metric_values
  for delete to authenticated
  using (private.has_unit_access(unit_id, '{org_admin,unit_officer}'));

-- -----------------------------------------------------------------------------
-- Receipts: read in subtree; store managers edit drafts at their store.
-- -----------------------------------------------------------------------------
create policy "read subtree receipts" on public.receipts
  for select to authenticated
  using (unit_id in (select private.accessible_unit_ids()));

create policy "store managers insert draft receipts" on public.receipts
  for insert to authenticated
  with check (status = 'draft' and private.has_unit_access(unit_id, '{org_admin,store_manager}'));

create policy "store managers update draft receipts" on public.receipts
  for update to authenticated
  using (status = 'draft' and private.has_unit_access(unit_id, '{org_admin,store_manager}'))
  with check (status = 'draft' and private.has_unit_access(unit_id, '{org_admin,store_manager}'));

create policy "store managers delete draft receipts" on public.receipts
  for delete to authenticated
  using (status = 'draft' and private.has_unit_access(unit_id, '{org_admin,store_manager}'));

create policy "read lines of visible receipts" on public.receipt_lines
  for select to authenticated
  using (exists (select 1 from public.receipts r where r.id = receipt_id));

create policy "edit lines of editable receipts" on public.receipt_lines
  for all to authenticated
  using (exists (
    select 1 from public.receipts r
    where r.id = receipt_id and r.status = 'draft'
      and private.has_unit_access(r.unit_id, '{org_admin,store_manager}')
  ))
  with check (exists (
    select 1 from public.receipts r
    where r.id = receipt_id and r.status = 'draft'
      and private.has_unit_access(r.unit_id, '{org_admin,store_manager}')
  ));

-- -----------------------------------------------------------------------------
-- Allocation plans: read in sender's subtree; lines also visible to recipients.
-- -----------------------------------------------------------------------------
create policy "read subtree allocation plans" on public.allocation_plans
  for select to authenticated
  using (from_unit_id in (select private.accessible_unit_ids()));

create policy "planners insert draft plans" on public.allocation_plans
  for insert to authenticated
  with check (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'));

create policy "planners update draft plans" on public.allocation_plans
  for update to authenticated
  using (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'))
  with check (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'));

create policy "planners delete draft plans" on public.allocation_plans
  for delete to authenticated
  using (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'));

create policy "read allocation lines as sender or recipient" on public.allocation_lines
  for select to authenticated
  using (
    to_unit_id in (select private.accessible_unit_ids())
    or exists (select 1 from public.allocation_plans p where p.id = plan_id)
  );

create policy "edit lines of draft plans" on public.allocation_lines
  for all to authenticated
  using (exists (
    select 1 from public.allocation_plans p
    where p.id = plan_id and p.status = 'draft'
      and private.has_unit_access(p.from_unit_id, '{org_admin,store_manager,unit_officer}')
  ))
  with check (exists (
    select 1 from public.allocation_plans p
    where p.id = plan_id and p.status = 'draft'
      and private.has_unit_access(p.from_unit_id, '{org_admin,store_manager,unit_officer}')
  ));

-- -----------------------------------------------------------------------------
-- Dispatches: visible to sender's and receiver's subtrees.
-- -----------------------------------------------------------------------------
create policy "read dispatches as sender or receiver" on public.dispatches
  for select to authenticated
  using (
    from_unit_id in (select private.accessible_unit_ids())
    or to_unit_id in (select private.accessible_unit_ids())
  );

create policy "senders insert draft dispatches" on public.dispatches
  for insert to authenticated
  with check (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'));

create policy "senders update draft dispatches" on public.dispatches
  for update to authenticated
  using (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'))
  with check (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'));

create policy "senders delete draft dispatches" on public.dispatches
  for delete to authenticated
  using (status = 'draft'
    and private.has_unit_access(from_unit_id, '{org_admin,store_manager,unit_officer}'));

create policy "read lines of visible dispatches" on public.dispatch_lines
  for select to authenticated
  using (exists (select 1 from public.dispatches d where d.id = dispatch_id));

create policy "edit lines of draft dispatches" on public.dispatch_lines
  for all to authenticated
  using (exists (
    select 1 from public.dispatches d
    where d.id = dispatch_id and d.status = 'draft'
      and private.has_unit_access(d.from_unit_id, '{org_admin,store_manager,unit_officer}')
  ))
  with check (exists (
    select 1 from public.dispatches d
    where d.id = dispatch_id and d.status = 'draft'
      and private.has_unit_access(d.from_unit_id, '{org_admin,store_manager,unit_officer}')
  ));

-- -----------------------------------------------------------------------------
-- Ledger and audit: read-only for clients.
-- -----------------------------------------------------------------------------
create policy "read subtree stock movements" on public.stock_movements
  for select to authenticated
  using (unit_id in (select private.accessible_unit_ids()));

create policy "org admins read audit log" on public.audit_log
  for select to authenticated
  using (private.is_org_member(organization_id, '{org_admin}') or private.is_platform_admin());

-- -----------------------------------------------------------------------------
-- Grants. anon gets nothing. authenticated gets SELECT everywhere (RLS
-- filters rows) and only the writes listed below. Workflow columns (status,
-- document numbers, approvals, posting, receiving, lots) are writable only by
-- SECURITY DEFINER functions. organization_id is never updatable.
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
grant select on all tables in schema public to authenticated;

-- Config tables: full writes (RLS limits to org admins).
grant insert, delete on
  public.unit_levels, public.attribute_definitions, public.metric_definitions,
  public.periods, public.funding_sources, public.items, public.item_pack_sizes,
  public.memberships, public.metric_values, public.units
to authenticated;

grant update (name, plural_name, depth, can_hold_stock, is_end_point)
  on public.unit_levels to authenticated;
grant update (label, type, options, required, sort_order)
  on public.attribute_definitions to authenticated;
grant update (label, unit_level_id, dimensions)
  on public.metric_definitions to authenticated;
grant update (name, starts_on, ends_on, is_current)
  on public.periods to authenticated;
grant update (name, type, is_active)
  on public.funding_sources to authenticated;
grant update (name, sku, category, base_unit, is_perishable, attributes, is_active)
  on public.items to authenticated;
grant update (name, quantity_in_base)
  on public.item_pack_sizes to authenticated;
grant update (unit_id, role)
  on public.memberships to authenticated;
grant update (value)
  on public.metric_values to authenticated;
grant update (parent_id, level_id, name, code, attributes, latitude, longitude, is_active)
  on public.units to authenticated;

grant insert on public.organizations to authenticated;
grant update (name, acronym, settings) on public.organizations to authenticated;

grant update (full_name, phone) on public.profiles to authenticated;

-- Draft documents.
grant insert (organization_id, unit_id, waybill_number, funding_source_id, supplier,
              vehicle_number, driver_name, driver_phone, received_at, received_by,
              notes, photo_paths)
  on public.receipts to authenticated;
grant update (waybill_number, funding_source_id, supplier, vehicle_number, driver_name,
              driver_phone, received_at, received_by, notes, photo_paths)
  on public.receipts to authenticated;
grant delete on public.receipts to authenticated;

grant insert (organization_id, receipt_id, item_id, batch_number, expiry_date,
              quantity_on_waybill, quantity_received, quantity_damaged)
  on public.receipt_lines to authenticated;
grant update (item_id, batch_number, expiry_date, quantity_on_waybill,
              quantity_received, quantity_damaged)
  on public.receipt_lines to authenticated;
grant delete on public.receipt_lines to authenticated;

grant insert (organization_id, from_unit_id, item_id, pack_size_id, total_quantity, basis,
              basis_metric_id, basis_dimension_filter, attribute_filters,
              target_level_id, period_id, notes)
  on public.allocation_plans to authenticated;
grant update (item_id, pack_size_id, total_quantity, basis, basis_metric_id,
              basis_dimension_filter, attribute_filters, target_level_id, period_id, notes)
  on public.allocation_plans to authenticated;
grant delete on public.allocation_plans to authenticated;

grant insert (organization_id, plan_id, to_unit_id, basis_count, proposed_quantity, final_quantity)
  on public.allocation_lines to authenticated;
grant update (final_quantity) on public.allocation_lines to authenticated;
grant delete on public.allocation_lines to authenticated;

grant insert (organization_id, from_unit_id, to_unit_id, allocation_plan_id,
              vehicle_number, driver_name, driver_phone)
  on public.dispatches to authenticated;
grant update (to_unit_id, vehicle_number, driver_name, driver_phone)
  on public.dispatches to authenticated;
grant delete on public.dispatches to authenticated;

grant insert (organization_id, dispatch_id, item_id, lot_id, quantity_sent)
  on public.dispatch_lines to authenticated;
grant update (item_id, lot_id, quantity_sent) on public.dispatch_lines to authenticated;
grant delete on public.dispatch_lines to authenticated;

-- Future tables and functions created by migrations start with no client
-- access; each migration must grant explicitly.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated, public;
