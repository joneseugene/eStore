-- =============================================================================
-- Foundation: extensions, private schema, enums, tenancy and hierarchy.
-- Core tables are sector-agnostic: no education concepts appear here.
-- =============================================================================

create extension if not exists ltree with schema extensions;

-- Helper functions live in a schema the Data API does not expose.
create schema if not exists private;
grant usage on schema private to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Enums
-- -----------------------------------------------------------------------------
create type public.app_role as enum (
  'org_admin',
  'approver',
  'store_manager',
  'unit_officer',
  'end_point_user',
  'viewer'
);

create type public.attribute_type as enum (
  'text', 'number', 'boolean', 'select', 'multi_select'
);

-- -----------------------------------------------------------------------------
-- Utility triggers
-- -----------------------------------------------------------------------------
create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Profiles (one per auth user)
-- -----------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  phone text,
  is_platform_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function private.set_updated_at();

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.phone
  );
  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- -----------------------------------------------------------------------------
-- Organizations (tenants)
-- -----------------------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  acronym text not null check (acronym ~ '^[A-Z0-9]{2,12}$'),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  sector_template text,
  -- document_number_format, approval rules, timezone, ...
  settings jsonb not null default jsonb_build_object(
    'timezone', 'Africa/Freetown',
    'document_number_format', '{ORG}-{TYPE}-{YYYY}-{SEQ6}'
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger organizations_updated_at before update on public.organizations
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Unit levels (e.g. National Store / District Office / End point)
-- -----------------------------------------------------------------------------
create table public.unit_levels (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  name text not null,
  plural_name text not null,
  depth smallint not null check (depth >= 0),
  can_hold_stock boolean not null default false,
  is_end_point boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, depth),
  unique (organization_id, name),
  unique (id, organization_id)
);

create trigger unit_levels_updated_at before update on public.unit_levels
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Attribute definitions (per level), e.g. ownership, emis_code
-- -----------------------------------------------------------------------------
create table public.attribute_definitions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  unit_level_id uuid not null,
  key text not null check (key ~ '^[a-z][a-z0-9_]*$'),
  label text not null,
  type public.attribute_type not null,
  -- For select / multi_select: JSON array of allowed string values.
  options jsonb,
  required boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_level_id, key),
  foreign key (unit_level_id, organization_id)
    references public.unit_levels (id, organization_id) on delete cascade,
  check (
    (type in ('select', 'multi_select')
      and jsonb_typeof(options) = 'array' and jsonb_array_length(options) > 0)
    or (type not in ('select', 'multi_select') and options is null)
  )
);

create trigger attribute_definitions_updated_at before update on public.attribute_definitions
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Units: the hierarchy as a tree with a materialised ltree path
-- -----------------------------------------------------------------------------
create table public.units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete restrict,
  parent_id uuid,
  level_id uuid not null,
  name text not null,
  code text not null,
  path extensions.ltree not null,
  attributes jsonb not null default '{}'::jsonb check (jsonb_typeof(attributes) = 'object'),
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code),
  unique (id, organization_id),
  check (parent_id is null or parent_id <> id),
  foreign key (parent_id, organization_id)
    references public.units (id, organization_id) on delete restrict,
  foreign key (level_id, organization_id)
    references public.unit_levels (id, organization_id) on delete restrict
);

create index units_path_gist on public.units using gist (path);
create index units_parent_idx on public.units (parent_id);
create index units_level_idx on public.units (level_id);
create index units_attributes_gin on public.units using gin (attributes);

create trigger units_updated_at before update on public.units
  for each row execute function private.set_updated_at();

-- ltree label for a unit id (labels cannot contain '-').
create function private.unit_label(p_id uuid)
returns extensions.ltree
language sql
immutable
set search_path = ''
as $$
  select extensions.text2ltree(replace(p_id::text, '-', '_'));
$$;

-- Maintain path, and check level ordering and cycles.
create function private.units_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent_path extensions.ltree;
  v_parent_depth smallint;
  v_parent_is_end_point boolean;
  v_depth smallint;
begin
  select depth into v_depth from public.unit_levels where id = new.level_id;

  if new.parent_id is null then
    new.path := private.unit_label(new.id);
    return new;
  end if;

  select u.path, l.depth, l.is_end_point
    into v_parent_path, v_parent_depth, v_parent_is_end_point
  from public.units u
  join public.unit_levels l on l.id = u.level_id
  where u.id = new.parent_id and u.organization_id = new.organization_id;

  if not found then
    raise exception 'Parent unit not found in this organization'
      using errcode = 'foreign_key_violation';
  end if;

  if v_parent_is_end_point then
    raise exception 'An end-point unit cannot have child units'
      using errcode = 'check_violation';
  end if;

  if v_depth <= v_parent_depth then
    raise exception 'A unit''s level must be below its parent''s level'
      using errcode = 'check_violation';
  end if;

  if tg_op = 'UPDATE' and extensions.ltree_isparent(old.path, v_parent_path) then
    raise exception 'A unit cannot be moved under itself or its descendants'
      using errcode = 'check_violation';
  end if;

  new.path := extensions.ltree_addltree(v_parent_path, private.unit_label(new.id));
  return new;
end;
$$;

create trigger units_before_write
  before insert or update of parent_id, level_id on public.units
  for each row execute function private.units_before_write();

-- When a unit moves, rewrite the paths of all its descendants.
create function private.units_after_move()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.path is distinct from old.path then
    update public.units
    set path = extensions.ltree_addltree(
      new.path,
      extensions.subpath(path, extensions.nlevel(old.path))
    )
    where extensions.ltree_isparent(old.path, path) and id <> new.id;
  end if;
  return null;
end;
$$;

create trigger units_after_move
  after update of parent_id on public.units
  for each row execute function private.units_after_move();

-- Validate units.attributes against the level's attribute definitions.
create function private.validate_unit_attributes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  d record;
  v_key text;
  v_value jsonb;
  v_elem jsonb;
begin
  -- Unknown keys are rejected so typos never silently pass.
  for v_key in select jsonb_object_keys(new.attributes) loop
    if not exists (
      select 1 from public.attribute_definitions
      where unit_level_id = new.level_id and key = v_key
    ) then
      raise exception 'Unknown attribute "%" for this unit level', v_key
        using errcode = 'check_violation';
    end if;
  end loop;

  for d in
    select key, label, type, options, required
    from public.attribute_definitions
    where unit_level_id = new.level_id
  loop
    v_value := new.attributes -> d.key;

    if v_value is null or v_value = 'null'::jsonb then
      if d.required then
        raise exception 'Attribute "%" is required', d.label
          using errcode = 'check_violation';
      end if;
      continue;
    end if;

    case d.type
      when 'text' then
        if jsonb_typeof(v_value) <> 'string' then
          raise exception 'Attribute "%" must be text', d.label using errcode = 'check_violation';
        end if;
      when 'number' then
        if jsonb_typeof(v_value) <> 'number' then
          raise exception 'Attribute "%" must be a number', d.label using errcode = 'check_violation';
        end if;
      when 'boolean' then
        if jsonb_typeof(v_value) <> 'boolean' then
          raise exception 'Attribute "%" must be true or false', d.label using errcode = 'check_violation';
        end if;
      when 'select' then
        if jsonb_typeof(v_value) <> 'string' or not d.options @> jsonb_build_array(v_value) then
          raise exception 'Attribute "%" must be one of %', d.label, d.options
            using errcode = 'check_violation';
        end if;
      when 'multi_select' then
        if jsonb_typeof(v_value) <> 'array' then
          raise exception 'Attribute "%" must be a list', d.label using errcode = 'check_violation';
        end if;
        for v_elem in select jsonb_array_elements(v_value) loop
          if not d.options @> jsonb_build_array(v_elem) then
            raise exception 'Attribute "%" value % is not one of %', d.label, v_elem, d.options
              using errcode = 'check_violation';
          end if;
        end loop;
    end case;
  end loop;

  return new;
end;
$$;

create trigger units_validate_attributes
  before insert or update of attributes, level_id on public.units
  for each row execute function private.validate_unit_attributes();

-- -----------------------------------------------------------------------------
-- Memberships: a role at a unit grants access to the unit and its subtree.
-- -----------------------------------------------------------------------------
create table public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete restrict,
  unit_id uuid not null,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, unit_id, role),
  foreign key (unit_id, organization_id)
    references public.units (id, organization_id) on delete cascade
);

create index memberships_user_idx on public.memberships (user_id);
create index memberships_unit_idx on public.memberships (unit_id);

create trigger memberships_updated_at before update on public.memberships
  for each row execute function private.set_updated_at();
