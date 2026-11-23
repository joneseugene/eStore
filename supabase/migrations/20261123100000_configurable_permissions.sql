-- =============================================================================
-- Configurable roles and permissions.
--
-- Replaces the fixed app_role enum with:
--   permissions                 fixed catalogue (code and RLS check these keys)
--   roles + role_permissions    per-organization bundles, editable by admins
--   memberships.role_id         a user holds a role at a unit (subtree access)
--   user_permission_overrides   per-user grant/deny of one permission at a unit
--
-- Effective permission P at unit U for the current user:
--   (a role held at U or an ancestor includes P, OR a grant override for P at
--    U or an ancestor)  AND NOT  (a deny override for P at U or an ancestor).
-- Deny always wins.
--
-- Organization-scoped permissions (scope = 'organization') count only when
-- held at a root unit of the organization.
--
-- Escalation guards: you can only assign roles / grant permissions you hold
-- yourself at that unit, you cannot change your own memberships or overrides,
-- and you can only add a permission to a role if you hold it org-wide.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Remove the enum-based policies and helpers.
-- -----------------------------------------------------------------------------
do $$
declare
  p record;
begin
  for p in select policyname, tablename from pg_policies where schemaname = 'public' loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end;
$$;

drop function private.is_org_member(uuid, public.app_role[]);
drop function private.has_unit_access(uuid, public.app_role[]);
drop function private.accessible_unit_ids(public.app_role[]);

alter table public.memberships drop column role;
drop type public.app_role;

-- -----------------------------------------------------------------------------
-- 2. Permission catalogue (fixed; changes only through migrations).
-- -----------------------------------------------------------------------------
create type public.permission_scope as enum ('organization', 'unit');

create table public.permissions (
  key text primary key check (key ~ '^[a-z_]+(\.[a-z_]+)+$'),
  scope public.permission_scope not null,
  category text not null,
  label text not null,
  description text not null,
  sort_order integer not null
);

insert into public.permissions (key, scope, category, label, description, sort_order) values
  ('org.settings.manage',       'organization', 'Organization', 'Manage organization settings', 'Edit name, document number format and other organization settings.', 10),
  ('structure.manage',          'organization', 'Organization', 'Manage structure', 'Edit unit levels, attributes, metrics and periods.', 20),
  ('catalogue.manage',          'organization', 'Organization', 'Manage catalogue', 'Edit items, pack sizes and funding sources.', 30),
  ('roles.manage',              'organization', 'Organization', 'Manage roles', 'Create roles and choose their permissions.', 40),
  ('audit.view',                'organization', 'Organization', 'View audit log', 'See who changed what across the organization.', 50),
  ('units.manage',              'unit', 'Units', 'Manage units', 'Create, edit and move units of any level.', 100),
  ('end_points.manage',         'unit', 'Units', 'Manage end points', 'Create and edit end points (e.g. schools), including imports.', 110),
  ('users.view',                'unit', 'Users', 'View users', 'See who has access and with which roles.', 200),
  ('users.manage',              'unit', 'Users', 'Manage users', 'Assign roles and per-user permissions.', 210),
  ('metrics.view',              'unit', 'Metrics', 'View metrics', 'See population and other allocation metrics.', 300),
  ('metrics.manage',            'unit', 'Metrics', 'Manage metrics', 'Enter and import metric values.', 310),
  ('stock.view',                'unit', 'Stock', 'View stock', 'See stock on hand and movements.', 400),
  ('adjustments.create',        'unit', 'Stock', 'Record adjustments', 'Record stock adjustments, losses and damage.', 410),
  ('receipts.view',             'unit', 'Receipts', 'View receipts', 'See inbound waybills.', 500),
  ('receipts.create',           'unit', 'Receipts', 'Create receipts', 'Create and edit draft receipts.', 510),
  ('receipts.post',             'unit', 'Receipts', 'Post receipts', 'Post receipts into stock.', 520),
  ('allocations.view',          'unit', 'Allocation', 'View allocations', 'See allocation plans.', 600),
  ('allocations.create',        'unit', 'Allocation', 'Create allocations', 'Create and edit draft allocation plans.', 610),
  ('allocations.approve',       'unit', 'Allocation', 'Approve allocations', 'Approve allocation plans.', 620),
  ('dispatches.view',           'unit', 'Dispatch', 'View dispatches', 'See outgoing and incoming dispatches.', 700),
  ('dispatches.create',         'unit', 'Dispatch', 'Create dispatches', 'Create and edit draft dispatches.', 710),
  ('dispatches.approve',        'unit', 'Dispatch', 'Approve dispatches', 'Approve dispatches before they leave.', 720),
  ('dispatches.dispatch',       'unit', 'Dispatch', 'Mark dispatched', 'Mark dispatches as sent (stock leaves the sender).', 730),
  ('dispatches.confirm_receipt','unit', 'Dispatch', 'Confirm receipt', 'Confirm quantities received at the receiving unit.', 740),
  ('deliveries.record',         'unit', 'Dispatch', 'Record end-point deliveries', 'Record deliveries to end points that do not log in.', 750),
  ('reports.view',              'unit', 'Reports', 'View reports', 'See stock, coverage, traceability and discrepancy reports.', 800),
  ('reports.export',            'unit', 'Reports', 'Export reports', 'Download reports as CSV.', 810);

-- -----------------------------------------------------------------------------
-- 3. Roles, role permissions, user overrides.
-- -----------------------------------------------------------------------------
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  -- Stable key for roles created from a template (null for custom roles).
  key text check (key ~ '^[a-z][a-z0-9_]*$'),
  name text not null,
  description text not null default '',
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name),
  unique (organization_id, key),
  unique (id, organization_id)
);

create trigger roles_updated_at before update on public.roles
  for each row execute function private.set_updated_at();

create table public.role_permissions (
  role_id uuid not null,
  organization_id uuid not null,
  permission_key text not null references public.permissions (key) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_key),
  foreign key (role_id, organization_id)
    references public.roles (id, organization_id) on delete cascade
);

create type public.permission_effect as enum ('grant', 'deny');

create table public.user_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  unit_id uuid not null,
  permission_key text not null references public.permissions (key) on delete cascade,
  effect public.permission_effect not null,
  reason text,
  created_by uuid references public.profiles (id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, unit_id, permission_key),
  foreign key (unit_id, organization_id)
    references public.units (id, organization_id) on delete cascade
);

create index user_permission_overrides_user_idx
  on public.user_permission_overrides (user_id, permission_key);

create trigger user_permission_overrides_updated_at before update on public.user_permission_overrides
  for each row execute function private.set_updated_at();

alter table public.memberships add column role_id uuid not null;
alter table public.memberships
  add constraint memberships_user_unit_role_key unique (user_id, unit_id, role_id),
  add constraint memberships_role_fkey foreign key (role_id, organization_id)
    references public.roles (id, organization_id) on delete restrict;
create index memberships_role_idx on public.memberships (role_id);

-- -----------------------------------------------------------------------------
-- 4. Permission helpers.
-- -----------------------------------------------------------------------------
create function private.is_org_member(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.memberships m
    where m.user_id = auth.uid() and m.organization_id = p_org
  );
$$;

-- Does the current user hold permission p_perm at unit p_unit?
create function private.has_permission(p_unit uuid, p_perm text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select path, organization_id from public.units where id = p_unit
  )
  select
    exists (
      select 1
      from target t
      join public.memberships m
        on m.organization_id = t.organization_id and m.user_id = auth.uid()
      join public.role_permissions rp
        on rp.role_id = m.role_id and rp.permission_key = p_perm
      join public.units mu on mu.id = m.unit_id
      where t.path operator(extensions.<@) mu.path
      union all
      select 1
      from target t
      join public.user_permission_overrides o
        on o.organization_id = t.organization_id and o.user_id = auth.uid()
       and o.permission_key = p_perm and o.effect = 'grant'
      join public.units ou on ou.id = o.unit_id
      where t.path operator(extensions.<@) ou.path
    )
    and not exists (
      select 1
      from target t
      join public.user_permission_overrides o
        on o.organization_id = t.organization_id and o.user_id = auth.uid()
       and o.permission_key = p_perm and o.effect = 'deny'
      join public.units ou on ou.id = o.unit_id
      where t.path operator(extensions.<@) ou.path
    );
$$;

-- Organization-scoped permission: held at a root unit of the organization.
create function private.has_org_permission(p_org uuid, p_perm text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.units r
    where r.organization_id = p_org
      and r.parent_id is null
      and private.has_permission(r.id, p_perm)
  );
$$;

-- Platform admins may do any organization-level management (bootstrap).
create function private.can_manage_org(p_org uuid, p_perm text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_platform_admin() or private.has_org_permission(p_org, p_perm);
$$;

-- All units where the current user holds p_perm. Use as
-- `unit_id in (select private.units_with_permission('x'))` so the set is
-- computed once per query.
create function private.units_with_permission(p_perm text)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  with grant_paths as (
    select mu.path, mu.organization_id
    from public.memberships m
    join public.role_permissions rp
      on rp.role_id = m.role_id and rp.permission_key = p_perm
    join public.units mu on mu.id = m.unit_id
    where m.user_id = auth.uid()
    union
    select ou.path, ou.organization_id
    from public.user_permission_overrides o
    join public.units ou on ou.id = o.unit_id
    where o.user_id = auth.uid() and o.permission_key = p_perm and o.effect = 'grant'
  ),
  deny_paths as (
    select ou.path
    from public.user_permission_overrides o
    join public.units ou on ou.id = o.unit_id
    where o.user_id = auth.uid() and o.permission_key = p_perm and o.effect = 'deny'
  )
  select distinct u.id
  from public.units u
  join grant_paths g
    on u.organization_id = g.organization_id
   and u.path operator(extensions.<@) g.path
  where not exists (
    select 1 from deny_paths d where u.path operator(extensions.<@) d.path
  );
$$;

-- Can the current user hand out every permission in p_role at p_unit?
create function private.can_assign_role(p_unit uuid, p_role uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.role_permissions rp
    where rp.role_id = p_role
      and not private.has_permission(p_unit, rp.permission_key)
  );
$$;

-- All permission keys the current user holds at a unit (for the UI).
-- SECURITY INVOKER: it only ever reports the caller's own permissions.
create function public.my_permissions(p_unit uuid)
returns setof text
language sql
stable
security invoker
set search_path = ''
as $$
  select p.key from public.permissions p
  where case p.scope
    when 'unit' then private.has_permission(p_unit, p.key)
    else private.has_org_permission(
      (select organization_id from public.units where id = p_unit), p.key)
  end
  order by p.sort_order;
$$;

revoke all on all functions in schema private from public, anon;
grant execute on function
  private.is_platform_admin(),
  private.is_org_member(uuid),
  private.has_permission(uuid, text),
  private.has_org_permission(uuid, text),
  private.can_manage_org(uuid, text),
  private.units_with_permission(text),
  private.can_assign_role(uuid, uuid),
  private.visible_unit_ids(),
  private.is_end_point_level(uuid),
  private.shares_org_with(uuid)
to authenticated;
revoke all on function public.my_permissions(uuid) from public, anon;
grant execute on function public.my_permissions(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Starter roles for every new organization. Sector templates (Phase 3)
--    may adjust them; org admins can edit them afterwards.
-- -----------------------------------------------------------------------------
create function private.create_default_roles(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_role uuid;
begin
  for r in
    select * from (values
      ('org_admin', 'Org Admin', 'Full control of the organization.', null::text[]),
      ('approver', 'Approver', 'Approves allocations and dispatches; read access to operations.', array[
        'stock.view', 'receipts.view', 'allocations.view', 'allocations.approve',
        'dispatches.view', 'dispatches.approve', 'metrics.view', 'users.view',
        'reports.view', 'reports.export']),
      ('store_manager', 'Store Manager', 'Runs a store: receipts, adjustments, dispatches.', array[
        'stock.view', 'adjustments.create', 'receipts.view', 'receipts.create', 'receipts.post',
        'allocations.view', 'allocations.create', 'dispatches.view', 'dispatches.create',
        'dispatches.dispatch', 'dispatches.confirm_receipt', 'metrics.view',
        'reports.view', 'reports.export']),
      ('unit_officer', 'Unit Officer', 'Manages end points and census data; distributes to end points.', array[
        'stock.view', 'receipts.view', 'metrics.view', 'metrics.manage', 'end_points.manage',
        'allocations.view', 'allocations.create', 'dispatches.view', 'dispatches.create',
        'dispatches.dispatch', 'dispatches.confirm_receipt', 'deliveries.record',
        'reports.view', 'reports.export']),
      ('viewer', 'Viewer', 'Read-only access for donors and auditors.', array[
        'stock.view', 'receipts.view', 'allocations.view', 'dispatches.view',
        'metrics.view', 'reports.view', 'reports.export'])
    ) as t(key, name, description, perms)
  loop
    insert into public.roles (organization_id, key, name, description, is_system)
    values (p_org, r.key, r.name, r.description, true)
    returning id into v_role;

    insert into public.role_permissions (role_id, organization_id, permission_key)
    select v_role, p_org, p.key
    from public.permissions p
    where r.perms is null or p.key = any (r.perms);
  end loop;
end;
$$;

create function private.organizations_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.create_default_roles(new.id);
  return null;
end;
$$;

create trigger organizations_default_roles
  after insert on public.organizations
  for each row execute function private.organizations_after_insert();

-- Create roles for any organizations that already exist.
select private.create_default_roles(id) from public.organizations;

-- -----------------------------------------------------------------------------
-- 6. Policies.
-- -----------------------------------------------------------------------------
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.user_permission_overrides enable row level security;

-- Organizations and profiles
create policy "members read their organizations" on public.organizations
  for select to authenticated
  using (private.is_platform_admin() or private.is_org_member(id));

create policy "platform admins create organizations" on public.organizations
  for insert to authenticated
  with check (private.is_platform_admin());

create policy "settings managers update organization" on public.organizations
  for update to authenticated
  using (private.can_manage_org(id, 'org.settings.manage'))
  with check (private.can_manage_org(id, 'org.settings.manage'));

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

-- Permission catalogue: readable by every signed-in user.
create policy "read permission catalogue" on public.permissions
  for select to authenticated
  using (true);

-- Org-wide configuration: members read; the matching org permission writes.
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('unit_levels', 'structure.manage'),
      ('attribute_definitions', 'structure.manage'),
      ('metric_definitions', 'structure.manage'),
      ('periods', 'structure.manage'),
      ('funding_sources', 'catalogue.manage'),
      ('items', 'catalogue.manage'),
      ('item_pack_sizes', 'catalogue.manage')
    ) as t(tbl, perm)
  loop
    execute format($p$
      create policy "members read" on public.%1$I
        for select to authenticated
        using (private.is_org_member(organization_id) or private.is_platform_admin());
      create policy "managers insert" on public.%1$I
        for insert to authenticated
        with check (private.can_manage_org(organization_id, %2$L));
      create policy "managers update" on public.%1$I
        for update to authenticated
        using (private.can_manage_org(organization_id, %2$L))
        with check (private.can_manage_org(organization_id, %2$L));
      create policy "managers delete" on public.%1$I
        for delete to authenticated
        using (private.can_manage_org(organization_id, %2$L));
    $p$, r.tbl, r.perm);
  end loop;
end;
$$;

create policy "members read lots" on public.stock_lots
  for select to authenticated
  using (private.is_org_member(organization_id) or private.is_platform_admin());

-- Roles
create policy "members read roles" on public.roles
  for select to authenticated
  using (private.is_org_member(organization_id) or private.is_platform_admin());

create policy "role managers insert roles" on public.roles
  for insert to authenticated
  with check (private.can_manage_org(organization_id, 'roles.manage'));

create policy "role managers update roles" on public.roles
  for update to authenticated
  using (private.can_manage_org(organization_id, 'roles.manage'))
  with check (private.can_manage_org(organization_id, 'roles.manage'));

create policy "role managers delete custom roles" on public.roles
  for delete to authenticated
  using (not is_system and private.can_manage_org(organization_id, 'roles.manage'));

create policy "members read role permissions" on public.role_permissions
  for select to authenticated
  using (private.is_org_member(organization_id) or private.is_platform_admin());

-- Adding a permission to a role requires holding it org-wide yourself.
create policy "role managers add permissions they hold" on public.role_permissions
  for insert to authenticated
  with check (
    private.is_platform_admin()
    or (private.has_org_permission(organization_id, 'roles.manage')
        and private.has_org_permission(organization_id, permission_key))
  );

create policy "role managers remove permissions" on public.role_permissions
  for delete to authenticated
  using (private.can_manage_org(organization_id, 'roles.manage'));

-- Units
create policy "read subtree and ancestors" on public.units
  for select to authenticated
  using (id in (select private.visible_unit_ids()) or private.is_platform_admin());

create policy "managers insert units" on public.units
  for insert to authenticated
  with check (
    (parent_id is null and private.can_manage_org(organization_id, 'units.manage'))
    or private.has_permission(parent_id, 'units.manage')
    or (private.has_permission(parent_id, 'end_points.manage') and private.is_end_point_level(level_id))
  );

create policy "managers update units" on public.units
  for update to authenticated
  using (
    private.is_platform_admin()
    or private.has_permission(id, 'units.manage')
    or (private.has_permission(id, 'end_points.manage') and private.is_end_point_level(level_id))
  )
  with check (
    (parent_id is null and private.can_manage_org(organization_id, 'units.manage'))
    or private.has_permission(parent_id, 'units.manage')
    or (private.has_permission(parent_id, 'end_points.manage') and private.is_end_point_level(level_id))
  );

create policy "managers delete units" on public.units
  for delete to authenticated
  using (private.is_platform_admin() or private.has_permission(id, 'units.manage'));

-- Memberships: never your own; only roles whose every permission you hold.
create policy "read own or managed memberships" on public.memberships
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.has_permission(unit_id, 'users.view')
    or private.is_platform_admin()
  );

create policy "user managers insert memberships" on public.memberships
  for insert to authenticated
  with check (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.can_assign_role(unit_id, role_id))
  );

create policy "user managers update memberships" on public.memberships
  for update to authenticated
  using (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.can_assign_role(unit_id, role_id))
  )
  with check (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.can_assign_role(unit_id, role_id))
  );

create policy "user managers delete memberships" on public.memberships
  for delete to authenticated
  using (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.can_assign_role(unit_id, role_id))
  );

-- Per-user overrides: same rules; you can only grant or deny what you hold.
create policy "read own or managed overrides" on public.user_permission_overrides
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.has_permission(unit_id, 'users.view')
    or private.is_platform_admin()
  );

create policy "user managers insert overrides" on public.user_permission_overrides
  for insert to authenticated
  with check (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.has_permission(unit_id, permission_key))
  );

create policy "user managers update overrides" on public.user_permission_overrides
  for update to authenticated
  using (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.has_permission(unit_id, permission_key))
  )
  with check (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.has_permission(unit_id, permission_key))
  );

create policy "user managers delete overrides" on public.user_permission_overrides
  for delete to authenticated
  using (
    private.is_platform_admin()
    or (user_id <> (select auth.uid())
        and private.has_permission(unit_id, 'users.manage')
        and private.has_permission(unit_id, permission_key))
  );

-- Metric values
create policy "read metric values" on public.metric_values
  for select to authenticated
  using (unit_id in (select private.units_with_permission('metrics.view')));

create policy "metric managers insert" on public.metric_values
  for insert to authenticated
  with check (private.has_permission(unit_id, 'metrics.manage'));

create policy "metric managers update" on public.metric_values
  for update to authenticated
  using (private.has_permission(unit_id, 'metrics.manage'))
  with check (private.has_permission(unit_id, 'metrics.manage'));

create policy "metric managers delete" on public.metric_values
  for delete to authenticated
  using (private.has_permission(unit_id, 'metrics.manage'));

-- Draft documents and their lines. Reading uses <area>.view; editing drafts
-- uses <area>.create at the owning unit.
create policy "read receipts" on public.receipts
  for select to authenticated
  using (unit_id in (select private.units_with_permission('receipts.view')));

create policy "insert draft receipts" on public.receipts
  for insert to authenticated
  with check (status = 'draft' and private.has_permission(unit_id, 'receipts.create'));

create policy "update draft receipts" on public.receipts
  for update to authenticated
  using (status = 'draft' and private.has_permission(unit_id, 'receipts.create'))
  with check (status = 'draft' and private.has_permission(unit_id, 'receipts.create'));

create policy "delete draft receipts" on public.receipts
  for delete to authenticated
  using (status = 'draft' and private.has_permission(unit_id, 'receipts.create'));

create policy "read allocation plans" on public.allocation_plans
  for select to authenticated
  using (from_unit_id in (select private.units_with_permission('allocations.view')));

create policy "insert draft plans" on public.allocation_plans
  for insert to authenticated
  with check (status = 'draft' and private.has_permission(from_unit_id, 'allocations.create'));

create policy "update draft plans" on public.allocation_plans
  for update to authenticated
  using (status = 'draft' and private.has_permission(from_unit_id, 'allocations.create'))
  with check (status = 'draft' and private.has_permission(from_unit_id, 'allocations.create'));

create policy "delete draft plans" on public.allocation_plans
  for delete to authenticated
  using (status = 'draft' and private.has_permission(from_unit_id, 'allocations.create'));

create policy "read dispatches as sender or receiver" on public.dispatches
  for select to authenticated
  using (
    from_unit_id in (select private.units_with_permission('dispatches.view'))
    or to_unit_id in (select private.units_with_permission('dispatches.view'))
  );

create policy "insert draft dispatches" on public.dispatches
  for insert to authenticated
  with check (status = 'draft' and private.has_permission(from_unit_id, 'dispatches.create'));

create policy "update draft dispatches" on public.dispatches
  for update to authenticated
  using (status = 'draft' and private.has_permission(from_unit_id, 'dispatches.create'))
  with check (status = 'draft' and private.has_permission(from_unit_id, 'dispatches.create'));

create policy "delete draft dispatches" on public.dispatches
  for delete to authenticated
  using (status = 'draft' and private.has_permission(from_unit_id, 'dispatches.create'));

create policy "read receipt lines" on public.receipt_lines
  for select to authenticated
  using (exists (select 1 from public.receipts r where r.id = receipt_id));

create policy "read allocation lines as sender or recipient" on public.allocation_lines
  for select to authenticated
  using (
    to_unit_id in (select private.units_with_permission('allocations.view'))
    or exists (select 1 from public.allocation_plans p where p.id = plan_id)
  );

create policy "read dispatch lines" on public.dispatch_lines
  for select to authenticated
  using (exists (select 1 from public.dispatches d where d.id = dispatch_id));

do $$
declare
  r record;
  v_check text;
begin
  for r in
    select * from (values
      ('receipt_lines', 'receipt_id', 'receipts', 'unit_id', 'receipts.create'),
      ('allocation_lines', 'plan_id', 'allocation_plans', 'from_unit_id', 'allocations.create'),
      ('dispatch_lines', 'dispatch_id', 'dispatches', 'from_unit_id', 'dispatches.create')
    ) as t(line_table, fk, parent_table, unit_col, perm)
  loop
    v_check := format(
      'exists (select 1 from public.%I p where p.id = %I and p.status = ''draft''
                 and private.has_permission(p.%I, %L))',
      r.parent_table, r.fk, r.unit_col, r.perm);
    execute format(
      'create policy "insert lines of draft parent" on public.%I
         for insert to authenticated with check (%s)', r.line_table, v_check);
    execute format(
      'create policy "update lines of draft parent" on public.%I
         for update to authenticated using (%s) with check (%s)', r.line_table, v_check, v_check);
    execute format(
      'create policy "delete lines of draft parent" on public.%I
         for delete to authenticated using (%s)', r.line_table, v_check);
  end loop;
end;
$$;

-- Ledger and audit
create policy "read stock movements" on public.stock_movements
  for select to authenticated
  using (unit_id in (select private.units_with_permission('stock.view')));

create policy "auditors read audit log" on public.audit_log
  for select to authenticated
  using (private.can_manage_org(organization_id, 'audit.view'));

-- -----------------------------------------------------------------------------
-- 7. Grants for new tables and changed columns.
-- -----------------------------------------------------------------------------
grant select on public.permissions, public.roles, public.role_permissions,
  public.user_permission_overrides to authenticated;

grant insert (id, organization_id, name, description) on public.roles to authenticated;
grant update (name, description) on public.roles to authenticated;
grant delete on public.roles to authenticated;

grant insert (role_id, organization_id, permission_key) on public.role_permissions to authenticated;
grant delete on public.role_permissions to authenticated;

grant insert (id, organization_id, user_id, unit_id, permission_key, effect, reason)
  on public.user_permission_overrides to authenticated;
grant update (effect, reason) on public.user_permission_overrides to authenticated;
grant delete on public.user_permission_overrides to authenticated;

grant update (unit_id, role_id) on public.memberships to authenticated;

-- -----------------------------------------------------------------------------
-- 8. Audit the new tables.
-- -----------------------------------------------------------------------------
create trigger roles_audit after insert or update or delete on public.roles
  for each row execute function private.write_audit_log();
create trigger role_permissions_audit after insert or update or delete on public.role_permissions
  for each row execute function private.write_audit_log();
create trigger user_permission_overrides_audit
  after insert or update or delete on public.user_permission_overrides
  for each row execute function private.write_audit_log();
