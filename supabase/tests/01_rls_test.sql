-- RLS, permission and integrity tests. Runs in a transaction that is rolled back.
--   npm run db:test
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(66);

-- =============================================================================
-- Fixtures (as postgres, bypassing RLS)
-- =============================================================================
-- Org A: HQ → District WAR / District WAU → Site S1 (WAR) / Site S2 (WAU)
-- Org B: HQ_B
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'hq-admin@test.local'),
  ('00000000-0000-0000-0000-00000000a002', 'war-officer@test.local'),
  ('00000000-0000-0000-0000-00000000a003', 'wau-officer@test.local'),
  ('00000000-0000-0000-0000-00000000a004', 'viewer@test.local'),
  ('00000000-0000-0000-0000-00000000a005', 'war-store@test.local'),
  ('00000000-0000-0000-0000-00000000a006', 'war-admin@test.local'),
  ('00000000-0000-0000-0000-00000000a007', 'war-clerk@test.local'),
  ('00000000-0000-0000-0000-00000000a008', 'war-store-denied@test.local'),
  ('00000000-0000-0000-0000-00000000a009', 'viewer-granted@test.local'),
  ('00000000-0000-0000-0000-00000000a010', 'war-user-manager@test.local'),
  ('00000000-0000-0000-0000-00000000a011', 'target@test.local'),
  ('00000000-0000-0000-0000-00000000b001', 'b-admin@test.local'),
  ('00000000-0000-0000-0000-00000000c001', 'nobody@test.local');

insert into organizations (id, name, acronym, slug) values
  ('10000000-0000-0000-0000-00000000000a', 'Org A', 'ORGA', 'org-a'),
  ('10000000-0000-0000-0000-00000000000b', 'Org B', 'ORGB', 'org-b');

insert into unit_levels (id, organization_id, name, plural_name, depth, can_hold_stock, is_end_point) values
  ('20000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a', 'Central', 'Central', 0, true, false),
  ('20000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', 'District', 'Districts', 1, true, false),
  ('20000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', 'Site', 'Sites', 2, false, true),
  ('20000000-0000-0000-0000-0000000000b0', '10000000-0000-0000-0000-00000000000b', 'Central', 'Central', 0, true, false);

insert into attribute_definitions (organization_id, unit_level_id, key, label, type, options, required) values
  ('10000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a2',
   'ownership', 'Ownership', 'select', '["Government","Private"]', true),
  ('10000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a2',
   'levels', 'Levels', 'multi_select', '["Primary","JSS"]', false);

insert into units (id, organization_id, parent_id, level_id, name, code, attributes) values
  ('30000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a', null,
   '20000000-0000-0000-0000-0000000000a0', 'HQ', 'HQ', '{}'),
  ('30000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0',
   '20000000-0000-0000-0000-0000000000a1', 'WAR', 'WAR', '{}'),
  ('30000000-0000-0000-0000-0000000000a2', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0',
   '20000000-0000-0000-0000-0000000000a1', 'WAU', 'WAU', '{}'),
  ('30000000-0000-0000-0000-0000000000a3', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
   '20000000-0000-0000-0000-0000000000a2', 'S1', 'S1', '{"ownership":"Government"}'),
  ('30000000-0000-0000-0000-0000000000a4', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a2',
   '20000000-0000-0000-0000-0000000000a2', 'S2', 'S2', '{"ownership":"Private","levels":["JSS"]}'),
  ('30000000-0000-0000-0000-0000000000b0', '10000000-0000-0000-0000-00000000000b', null,
   '20000000-0000-0000-0000-0000000000b0', 'HQ B', 'HQB', '{}');

-- Custom roles (default roles were created by the organization trigger).
insert into roles (id, organization_id, name) values
  ('b0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', 'Stock Clerk'),
  ('b0000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-00000000000a', 'Stock Watcher'),
  ('b0000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-00000000000a', 'District User Manager');
insert into role_permissions (role_id, organization_id, permission_key) values
  ('b0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', 'receipts.view'),
  ('b0000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-00000000000a', 'receipts.create'),
  ('b0000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-00000000000a', 'stock.view'),
  ('b0000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-00000000000a', 'users.view'),
  ('b0000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-00000000000a', 'users.manage'),
  ('b0000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-00000000000a', 'stock.view');

create temp view role_ids as
  select organization_id, key, id from roles where key is not null;

insert into memberships (user_id, organization_id, unit_id, role_id)
select m.user_id::uuid, m.org::uuid, m.unit::uuid,
       coalesce(m.custom_role::uuid, (select id from role_ids r where r.organization_id = m.org::uuid and r.key = m.role_key))
from (values
  ('00000000-0000-0000-0000-00000000a001', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0', 'org_admin', null),
  ('00000000-0000-0000-0000-00000000a002', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1', 'unit_officer', null),
  ('00000000-0000-0000-0000-00000000a003', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a2', 'unit_officer', null),
  ('00000000-0000-0000-0000-00000000a004', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0', 'viewer', null),
  ('00000000-0000-0000-0000-00000000a005', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1', 'store_manager', null),
  ('00000000-0000-0000-0000-00000000a006', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1', 'org_admin', null),
  ('00000000-0000-0000-0000-00000000a007', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1', null, 'b0000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-00000000a008', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1', 'store_manager', null),
  ('00000000-0000-0000-0000-00000000a009', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0', 'viewer', null),
  ('00000000-0000-0000-0000-00000000a010', '10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1', null, 'b0000000-0000-0000-0000-000000000003'),
  ('00000000-0000-0000-0000-00000000b001', '10000000-0000-0000-0000-00000000000b', '30000000-0000-0000-0000-0000000000b0', 'org_admin', null)
) as m(user_id, org, unit, role_key, custom_role);

-- Per-user overrides: a store manager denied receipts.create at WAR, and an
-- HQ viewer granted receipts.create at WAR only.
insert into user_permission_overrides (organization_id, user_id, unit_id, permission_key, effect) values
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000a008',
   '30000000-0000-0000-0000-0000000000a1', 'receipts.create', 'deny'),
  ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000a009',
   '30000000-0000-0000-0000-0000000000a1', 'receipts.create', 'grant');

insert into funding_sources (id, organization_id, name, type) values
  ('40000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a', 'GoSL', 'government');
insert into items (id, organization_id, name, sku, base_unit) values
  ('50000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a', 'Exercise book', 'EXB', 'book');
insert into stock_lots (id, organization_id, item_id, funding_source_id) values
  ('60000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a',
   '50000000-0000-0000-0000-0000000000a0', '40000000-0000-0000-0000-0000000000a0');

insert into stock_movements (organization_id, unit_id, item_id, lot_id, movement_type, quantity, source_type) values
  ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
   '50000000-0000-0000-0000-0000000000a0', '60000000-0000-0000-0000-0000000000a0', 'adjustment', 100, 'test'),
  ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a2',
   '50000000-0000-0000-0000-0000000000a0', '60000000-0000-0000-0000-0000000000a0', 'adjustment', 70, 'test');

insert into periods (id, organization_id, name, starts_on, ends_on, is_current) values
  ('70000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a', 'P1', '2025-09-01', '2026-07-31', true);
insert into metric_definitions (id, organization_id, unit_level_id, key, label, dimensions) values
  ('80000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a', '20000000-0000-0000-0000-0000000000a2',
   'headcount', 'Headcount', '[{"key":"sex","label":"Sex","values":["F","M"]}]');
insert into metric_values (organization_id, unit_id, metric_id, period_id, dimension_values, value) values
  ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a3',
   '80000000-0000-0000-0000-0000000000a0', '70000000-0000-0000-0000-0000000000a0', '{"sex":"F"}', 120),
  ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a4',
   '80000000-0000-0000-0000-0000000000a0', '70000000-0000-0000-0000-0000000000a0', '{"sex":"F"}', 90);

insert into dispatches (id, organization_id, from_unit_id, to_unit_id) values
  ('90000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a',
   '30000000-0000-0000-0000-0000000000a0', '30000000-0000-0000-0000-0000000000a1');

-- =============================================================================
-- Integrity (as postgres)
-- =============================================================================
select is(
  (select path::text from units where code = 'S1'),
  '30000000_0000_0000_0000_0000000000a0.30000000_0000_0000_0000_0000000000a1.30000000_0000_0000_0000_0000000000a3',
  'ltree path is maintained from the parent chain'
);

select throws_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code, attributes)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             '20000000-0000-0000-0000-0000000000a2', 'Bad', 'BAD1', '{"ownership":"Mission"}') $$,
  '23514', null, 'select attribute rejects a value outside its options'
);

select throws_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code, attributes)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             '20000000-0000-0000-0000-0000000000a2', 'Bad', 'BAD2', '{}') $$,
  '23514', null, 'required attribute must be present'
);

select throws_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code, attributes)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             '20000000-0000-0000-0000-0000000000a2', 'Bad', 'BAD3', '{"ownership":"Government","colour":"red"}') $$,
  '23514', null, 'unknown attribute keys are rejected'
);

select throws_ok(
  $$ update units set parent_id = '30000000-0000-0000-0000-0000000000a3' where code = 'WAR' $$,
  '23514', null, 'a unit cannot be placed under a lower or equal level'
);

select throws_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code)
     values ('10000000-0000-0000-0000-00000000000b', '30000000-0000-0000-0000-0000000000a0',
             '20000000-0000-0000-0000-0000000000b0', 'Cross', 'CROSS') $$,
  '23503', null, 'a unit cannot have a parent in another organization'
);

select throws_ok(
  $$ insert into metric_values (organization_id, unit_id, metric_id, period_id, dimension_values, value)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a3',
             '80000000-0000-0000-0000-0000000000a0', '70000000-0000-0000-0000-0000000000a0', '{"sex":"X"}', 1) $$,
  '23514', null, 'metric dimension values must be from the allowed list'
);

select throws_ok($$ update stock_movements set quantity = 1 $$,
  '42501', null, 'ledger rows cannot be updated, even by the owner');

select throws_ok($$ delete from stock_movements $$,
  '42501', null, 'ledger rows cannot be deleted, even by the owner');

select is(
  private.next_document_number('10000000-0000-0000-0000-00000000000a', 'DSP'),
  'ORGA-DSP-' || extract(year from now() at time zone 'Africa/Freetown')::int || '-000001',
  'document numbers follow the org format'
);

select is(
  private.next_document_number('10000000-0000-0000-0000-00000000000a', 'DSP'),
  'ORGA-DSP-' || extract(year from now() at time zone 'Africa/Freetown')::int || '-000002',
  'document numbers increment per org and type'
);

select ok((select count(*) from audit_log where entity = 'units') >= 6,
  'audit triggers record unit inserts');

select is(
  (select count(*)::int from roles where organization_id = '10000000-0000-0000-0000-00000000000a' and is_system),
  5, 'new organizations get the five starter roles'
);

select is(
  (select count(*)::int from role_permissions rp join roles r on r.id = rp.role_id
   where r.organization_id = '10000000-0000-0000-0000-00000000000a' and r.key = 'org_admin'),
  (select count(*)::int from permissions),
  'the starter Org Admin role holds every permission'
);

-- =============================================================================
-- Unit Officer at WAR: subtree plus ancestors; officer permissions only
-- =============================================================================
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a002","role":"authenticated"}', true);
set local role authenticated;

select results_eq($$ select code from units order by code $$, $$ values ('HQ'), ('S1'), ('WAR') $$,
  'WAR officer sees HQ (ancestor), WAR and its site, not WAU or its site');

select is((select count(*)::int from units where code in ('WAU', 'S2', 'HQB')), 0,
  'WAR officer cannot see another district, its sites, or another tenant');

select is((select coalesce(sum(quantity), 0)::int from stock_balances), 100,
  'WAR officer sees only WAR stock');

select is((select count(*)::int from metric_values), 1,
  'WAR officer sees only metric values for sites in WAR');

select is((select count(*)::int from dispatches), 1,
  'WAR officer sees the dispatch addressed to WAR');

select lives_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code, attributes)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             '20000000-0000-0000-0000-0000000000a2', 'New site', 'S9', '{"ownership":"Government"}') $$,
  'WAR officer can add an end point under WAR (end_points.manage)'
);

select throws_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code, attributes)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a2',
             '20000000-0000-0000-0000-0000000000a2', 'Sneaky', 'S10', '{"ownership":"Government"}') $$,
  '42501', null, 'WAR officer cannot add an end point under WAU'
);

select throws_ok(
  $$ insert into units (organization_id, parent_id, level_id, name, code)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0',
             '20000000-0000-0000-0000-0000000000a1', 'New district', 'D9') $$,
  '42501', null, 'WAR officer cannot add a non-end-point unit (no units.manage)'
);

select throws_ok(
  $$ insert into metric_values (organization_id, unit_id, metric_id, period_id, dimension_values, value)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a4',
             '80000000-0000-0000-0000-0000000000a0', '70000000-0000-0000-0000-0000000000a0', '{"sex":"M"}', 5) $$,
  '42501', null, 'WAR officer cannot write metric values for a WAU site'
);

select throws_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             'WB-1', '40000000-0000-0000-0000-0000000000a0') $$,
  '42501', null, 'Unit Officer role cannot create receipts (no receipts.create)'
);

select throws_ok(
  $$ insert into stock_movements (organization_id, unit_id, item_id, lot_id, movement_type, quantity, source_type)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             '50000000-0000-0000-0000-0000000000a0', '60000000-0000-0000-0000-0000000000a0', 'adjustment', 1000, 'hack') $$,
  '42501', null, 'clients cannot write to the stock ledger'
);

select throws_ok($$ update dispatches set status = 'delivered' $$,
  '42501', null, 'clients cannot change dispatch status directly');

select throws_ok(
  $$ update profiles set is_platform_admin = true where id = '00000000-0000-0000-0000-00000000a002' $$,
  '42501', null, 'users cannot make themselves platform admins');

select is((select count(*)::int from audit_log), 0, 'WAR officer cannot read the audit log');

select ok(
  'end_points.manage' = any (array(select my_permissions('30000000-0000-0000-0000-0000000000a1')))
  and not 'receipts.create' = any (array(select my_permissions('30000000-0000-0000-0000-0000000000a1'))),
  'my_permissions reports the officer''s effective permissions'
);

-- =============================================================================
-- Unit Officer at WAU cannot see WAR's incoming dispatch
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a003","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from dispatches), 0, 'WAU officer cannot see a dispatch between HQ and WAR');
select is((select coalesce(sum(quantity), 0)::int from stock_balances), 70, 'WAU officer sees only WAU stock');

-- =============================================================================
-- Store Manager at WAR
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a005","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into receipts (id, organization_id, unit_id, waybill_number, funding_source_id)
     values ('a0000000-0000-0000-0000-0000000000a0', '10000000-0000-0000-0000-00000000000a',
             '30000000-0000-0000-0000-0000000000a1', 'WB-2', '40000000-0000-0000-0000-0000000000a0') $$,
  'store manager can draft a receipt at their store'
);

select lives_ok(
  $$ insert into receipt_lines (organization_id, receipt_id, item_id, quantity_on_waybill, quantity_received)
     values ('10000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-0000000000a0',
             '50000000-0000-0000-0000-0000000000a0', 500, 490) $$,
  'store manager can add lines to their draft receipt'
);

select throws_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a0',
             'WB-3', '40000000-0000-0000-0000-0000000000a0') $$,
  '42501', null, 'store manager cannot draft a receipt at a parent store'
);

select throws_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id, status)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             'WB-4', '40000000-0000-0000-0000-0000000000a0', 'posted') $$,
  '42501', null, 'clients cannot create an already-posted receipt'
);

-- =============================================================================
-- Custom role "Stock Clerk" (receipts.view + receipts.create) at WAR
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a007","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             'WB-5', '40000000-0000-0000-0000-0000000000a0') $$,
  'a custom role with receipts.create can draft receipts'
);

select is((select count(*)::int from stock_movements), 0,
  'a custom role without stock.view sees no stock');

-- =============================================================================
-- Deny override: Store Manager at WAR denied receipts.create
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a008","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             'WB-6', '40000000-0000-0000-0000-0000000000a0') $$,
  '42501', null, 'a deny override removes a permission the role grants'
);

select is((select coalesce(sum(quantity), 0)::int from stock_balances), 100,
  'a deny override leaves the role''s other permissions intact');

-- =============================================================================
-- Grant override: HQ Viewer granted receipts.create at WAR only
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a009","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a1',
             'WB-7', '40000000-0000-0000-0000-0000000000a0') $$,
  'a grant override adds a permission at its unit'
);

select throws_ok(
  $$ insert into receipts (organization_id, unit_id, waybill_number, funding_source_id)
     values ('10000000-0000-0000-0000-00000000000a', '30000000-0000-0000-0000-0000000000a2',
             'WB-8', '40000000-0000-0000-0000-0000000000a0') $$,
  '42501', null, 'a grant override does not apply outside its unit''s subtree'
);

-- =============================================================================
-- Viewer at HQ: reads, writes nothing
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a004","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from units), 6, 'HQ viewer sees every unit in the org');

select throws_ok(
  $$ insert into items (organization_id, name, sku, base_unit)
     values ('10000000-0000-0000-0000-00000000000a', 'Pen', 'PEN', 'pen') $$,
  '42501', null, 'viewer cannot create items'
);

select throws_ok(
  $$ insert into receipt_lines (organization_id, receipt_id, item_id, quantity_on_waybill, quantity_received)
     values ('10000000-0000-0000-0000-00000000000a', 'a0000000-0000-0000-0000-0000000000a0',
             '50000000-0000-0000-0000-0000000000a0', 1, 1) $$,
  '42501', null, 'viewer cannot add lines to a draft receipt'
);

select lives_ok($$ update units set name = 'Renamed' where code = 'WAR' $$,
  'viewer update statement runs (RLS filters it to zero rows)');

select is((select name from units where code = 'WAR'), 'WAR', 'viewer update changed nothing');

-- =============================================================================
-- District User Manager (users.view, users.manage, stock.view) at WAR:
-- can only hand out what they hold
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a010","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into memberships (user_id, organization_id, unit_id, role_id)
     values ('00000000-0000-0000-0000-00000000a011', '10000000-0000-0000-0000-00000000000a',
             '30000000-0000-0000-0000-0000000000a1', 'b0000000-0000-0000-0000-000000000002') $$,
  'a user manager can assign a role whose permissions they hold'
);

select throws_ok(
  $$ insert into memberships (user_id, organization_id, unit_id, role_id)
     values ('00000000-0000-0000-0000-00000000a011', '10000000-0000-0000-0000-00000000000a',
             '30000000-0000-0000-0000-0000000000a1',
             (select id from roles where organization_id = '10000000-0000-0000-0000-00000000000a' and key = 'store_manager')) $$,
  '42501', null, 'a user manager cannot assign a role with permissions they lack'
);

select throws_ok(
  $$ insert into user_permission_overrides (organization_id, user_id, unit_id, permission_key, effect)
     values ('10000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000a011',
             '30000000-0000-0000-0000-0000000000a1', 'receipts.post', 'grant') $$,
  '42501', null, 'a user manager cannot grant a permission they lack'
);

select throws_ok(
  $$ insert into role_permissions (role_id, organization_id, permission_key)
     values ('b0000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-00000000000a', 'receipts.post') $$,
  '42501', null, 'without roles.manage, role permissions cannot be changed'
);

-- =============================================================================
-- Org Admin role held at a district (not root): org-wide permissions don't apply
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a006","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ insert into items (organization_id, name, sku, base_unit)
     values ('10000000-0000-0000-0000-00000000000a', 'Pen', 'PEN2', 'pen') $$,
  '42501', null, 'organization-scoped permissions only count at a root unit'
);

select is((select count(*)::int from audit_log), 0, 'district-level admin cannot read the org audit log');

select throws_ok(
  $$ insert into memberships (user_id, organization_id, unit_id, role_id)
     values ('00000000-0000-0000-0000-00000000a006', '10000000-0000-0000-0000-00000000000a',
             '30000000-0000-0000-0000-0000000000a3', 'b0000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'users cannot change their own memberships'
);

-- =============================================================================
-- Org Admin at HQ (root)
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000a001","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from units), 6, 'HQ admin sees every unit in the org');
select ok((select count(*) from audit_log) > 0, 'root org admin can read the audit log (audit.view)');

select lives_ok(
  $$ insert into items (organization_id, name, sku, base_unit)
     values ('10000000-0000-0000-0000-00000000000a', 'Pen', 'PEN', 'pen') $$,
  'root org admin can create items'
);

select lives_ok(
  $$ insert into roles (id, organization_id, name, description)
     values ('b0000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-00000000000a', 'Data Clerk', 'Census entry') $$,
  'root org admin can create a custom role'
);

select lives_ok(
  $$ insert into role_permissions (role_id, organization_id, permission_key)
     values ('b0000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-00000000000a', 'metrics.manage') $$,
  'root org admin can add permissions to a role'
);

select lives_ok($$ delete from roles where key = 'approver' $$,
  'deleting a starter role runs (RLS filters it out)');

select is(
  (select count(*)::int from roles where organization_id = '10000000-0000-0000-0000-00000000000a' and is_system),
  5, 'starter roles cannot be deleted'
);

-- =============================================================================
-- Cross-tenant: Org B admin sees nothing of Org A
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000b001","role":"authenticated"}', true);
set local role authenticated;

select results_eq($$ select code from units $$, $$ values ('HQB') $$, 'Org B admin sees only Org B units');
select is((select count(*)::int from organizations), 1, 'Org B admin sees only Org B');

select is(
  (select count(*)::int from items) + (select count(*)::int from stock_movements)
  + (select count(*)::int from dispatches) + (select count(*)::int from metric_values)
  + (select count(*)::int from roles where organization_id = '10000000-0000-0000-0000-00000000000a'),
  0, 'Org B admin sees no Org A items, stock, dispatches, metrics or roles'
);

select throws_ok(
  $$ insert into memberships (user_id, organization_id, unit_id, role_id)
     values ('00000000-0000-0000-0000-00000000a011', '10000000-0000-0000-0000-00000000000a',
             '30000000-0000-0000-0000-0000000000a0', 'b0000000-0000-0000-0000-000000000002') $$,
  '42501', null, 'Org B admin cannot grant access in Org A'
);

-- =============================================================================
-- No membership / anonymous
-- =============================================================================
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000c001","role":"authenticated"}', true);
set local role authenticated;

select is((select count(*)::int from units) + (select count(*)::int from organizations), 0,
  'a signed-in user with no membership sees nothing');

reset role;
set local role anon;

select throws_ok($$ select count(*) from units $$, '42501', null, 'anonymous users have no table access');

reset role;
select * from finish();
rollback;
