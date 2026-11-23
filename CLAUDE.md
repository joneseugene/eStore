# eStore — Build Brief

You are a senior full-stack engineer building eStore with me. Read this whole brief before writing code. Build in the phases at the end, stop after each phase for my review, and ask me before making any decision this brief doesn't cover.

## 1. What eStore is

eStore is a multi-tenant Progressive Web App that lets any Ministry, Department or Agency (MDA) in Sierra Leone manage its central store and track how goods are distributed down its hierarchy to end points.

The common pattern across MDAs:
- Goods arrive at a central store from the Government of Sierra Leone (GoSL) or partners (World Bank, UNICEF, etc.), with a waybill.
- The store records what the waybill says versus what was actually received and damaged.
- HQ allocates goods to lower offices using a rule (e.g. in proportion to population served), approves the allocation, and dispatches.
- Each lower office confirms what it actually received, then allocates and dispatches to its own end points.
- Donors and auditors need to trace every item from waybill to final recipient.

First tenant and first sector template: the Ministry of Basic and Senior Secondary Education (MBSSE).
- Hierarchy: National Store (HQ) → District Education Offices (DEOs) → Schools.
- Goods: teaching and learning materials (textbooks per class, exercise books, etc.) and sometimes food (e.g. 50kg bags of rice).
- Allocation is mostly by school population: HQ needs pupil and teacher counts per DEO; each DEO needs counts per school, filterable by school ownership (Government, Government-Assisted, Mission, Community, Private — to be confirmed against MBSSE's census categories), government approval status and level (Pre-primary, Primary, JSS, SSS).

## 2. Core principle: abstract core, configured sectors

Never hard-code education concepts into core tables, business logic or UI. Words like "DEO", "School", "Pupils" and "Class 4" must come from tenant configuration, seeded from a sector template.

Acceptance test for the architecture: onboarding the Ministry of Health (Central Medical Stores → DHMTs → Health Facilities, allocating by catchment population) must require only new template/config data, with zero code changes.

## 3. Stack

- Next.js (App Router) with TypeScript, strict mode
- Supabase: Postgres, Auth, Row Level Security, Storage (waybill and delivery-note photos), database functions (RPC) for all stock-changing operations
- @supabase/ssr for server/client auth; generated Supabase TypeScript types
- Tailwind CSS + shadcn/ui; React Hook Form + Zod for all forms and server-side validation
- PWA via Serwist (service worker, installable, offline shell); IndexedDB (Dexie) for the offline action queue
- Supabase CLI with SQL migrations in supabase/migrations; seed in supabase/seed.sql

Never expose the service role key to the client. All writes that change stock go through Postgres functions, called from server actions.

## 4. Data model (core, sector-agnostic)

Every tenant-owned table has organization_id. Use uuid primary keys, created_at/updated_at timestamps, and snake_case.

Tenancy and structure
- organizations: name, acronym, slug, sector_template, settings (jsonb: document number formats, approval rules, timezone).
- unit_levels: per organization; name (e.g. "District Education Office"), plural label, depth/order, can_hold_stock, is_end_point.
- units: the hierarchy as a tree; parent_id, level_id, name, code, path (Postgres ltree, maintained by trigger), attributes (jsonb, validated against attribute_definitions), latitude/longitude, is_active.
- attribute_definitions: per organization and unit level; key, label, type (text, number, boolean, select, multi_select), options, required. Education example: ownership, government_approved, school_levels, emis_code, chiefdom.

Metrics (drive allocation)
- metric_definitions: per organization; key, label, unit_level it applies to, dimensions (e.g. grade and sex for enrolment; level and sex for teachers).
- periods: per organization; e.g. academic year "2025/2026"; one marked current.
- metric_values: unit_id, metric_id, period_id, dimension values (jsonb), value. Unique per unit/metric/period/dimension combination. Higher-level totals are computed by rolling up the tree, never stored by hand.

People and access
- profiles: linked to auth.users; name, phone.
- memberships: user_id, organization_id, unit_id, role. Roles: org_admin, approver, store_manager, unit_officer, end_point_user (not used in v1), viewer (donors/auditors, read-only). A membership grants access to that unit and all its descendants. A platform_admin flag on profiles allows creating organizations.

Catalogue and funding
- items: name, sku, category, base unit of measure, is_perishable, tags/target attributes (jsonb, e.g. target grades).
- item_pack_sizes: conversions (e.g. 1 carton = 20 books).
- funding_sources: name, type (government, multilateral, NGO, other).
- stock_lots: item, funding source, batch number, expiry date. Every unit of stock belongs to a lot, so donor traceability survives every handover.

Movements
- receipts + receipt_lines: inbound waybills at a store; waybill number, funding source, supplier, vehicle, driver, received_at, received_by, status (draft, posted), photos; per line: quantity on waybill, received, damaged.
- allocation_plans + allocation_lines: from_unit, item, total quantity, basis (a metric with optional dimension filter, number of end points, or manual), attribute filters (jsonb), period, status (draft, approved, executed); per line: to_unit, basis_count, proposed quantity, final quantity.
- dispatches + dispatch_lines: from_unit, to_unit, optional allocation plan, waybill/delivery-note number, status (draft, approved, in_transit, delivered, disputed, cancelled), vehicle, driver and phone, dispatched_at, received_by, received_at, receiver note, photos; per line: lot, quantity sent, quantity received.
- stock_movements: the ledger. unit, item, lot, type (receipt, dispatch_out, dispatch_in, issue, adjustment, loss_damage, return), signed quantity, references to source document, created_by, idempotency_key. Never update or delete ledger rows; corrections are new adjustment rows.
- stock_balances: a view (or materialised view) summing the ledger per unit, item and lot.
- audit_log: written by triggers on all important tables: actor, action, entity, entity_id, before/after jsonb.

## 5. Security (RLS)

- Enable RLS on every table. No table is readable without a policy.
- Write SECURITY DEFINER, STABLE helper functions, e.g. has_unit_access(unit_id, min_role) using ltree ancestry against the user's memberships, and is_org_member(org_id).
- Users see their units and descendants only. A DEO officer in Western Area Rural must never see another district's schools or stock.
- Viewers are read-only. Only approvers can approve allocations and dispatches. Only store managers and unit officers can post receipts and confirm deliveries at their own unit.
- Write SQL tests (pgTAP or plain SQL scripts run in CI) proving cross-district and cross-tenant access is denied.

## 6. Business rules

- All stock changes happen inside Postgres functions in a single transaction: post_receipt, approve_allocation, create_dispatches_from_allocation, mark_dispatched, confirm_dispatch_receipt, record_adjustment.
- Stock can never go negative at any unit/item/lot; the function must fail with a clear error.
- Dispatching moves stock out of the sender when marked dispatched; it enters the receiver only when the receiver confirms. Differences between sent and received are recorded as loss_damage with a reason, and the dispatch becomes "disputed" until resolved.
- Allocation: compute proposed quantities proportionally to the basis counts of eligible units (after attribute filters), using the largest-remainder method so lines sum exactly to the total and respect pack sizes. The approver can override any line; the plan must still sum to the total.
- Lot selection on dispatch defaults to earliest expiry first, then oldest receipt (FEFO/FIFO), with manual override.
- Document numbers follow the organization's format setting, e.g. MBSSE-DSP-2026-000123, generated in the database, unique per organization.
- Every mutation from the client carries a client-generated UUID idempotency key, so offline retries never post twice.

## 7. Education sector template (seed for MBSSE)

Provide a reusable template (SQL or a TypeScript seeding script) that creates:
- Levels: National Store (HQ, holds stock), District Education Office (holds stock), School (end point).
- Units: MBSSE National Store and one DEO per district, including Western Area Urban and Western Area Rural. Keep the DEO list easy to edit; I will confirm it with MBSSE.
- School attributes: emis_code, ownership (select), government_approved (boolean), school_levels (multi-select: Pre-primary, Primary, JSS, SSS), chiefdom, town.
- Metrics: enrolment by grade (ECE, Class 1–6, JSS 1–3, SSS 1–4) and sex; teachers by level and sex.
- Current period 2025/2026; funding sources GoSL, World Bank, UNICEF; a starter catalogue (core textbooks per class, exercise books, pens, 50kg bag of rice).
- Demo users for each role and a few sample schools with data, clearly marked as demo data.

## 8. School and census import

- CSV/Excel upload of end points plus metric values, with a column-mapping screen, a validation preview (errors per row), and an upsert keyed on code (EMIS code for schools).
- Import is scoped: a DEO officer can only import into their district.

## 9. PWA and low-connectivity requirements

Users in districts often have weak, expensive mobile data and use low-end Android phones.
- Installable PWA with offline app shell.
- Offline-capable flows: confirming receipt of a dispatch and recording a delivery to a school. Queue actions in IndexedDB, show a clear "pending sync" indicator, sync automatically when back online, and surface conflicts or failures plainly.
- Compress photos client-side before upload (target under 300 KB).
- Keep JavaScript lean, paginate lists, avoid heavy charts on mobile. Mobile-first layouts; large tap targets.
- Times stored in UTC and displayed in Africa/Freetown. Quantities formatted with thousands separators.

## 10. Screens (v1)

- Org setup (org_admin): levels, units tree, attribute and metric configuration, users and roles, funding sources, items.
- End points: list with filters by attributes, profile page with metrics per period, import.
- Store: stock on hand by item and lot, receipts (create, post), adjustments.
- Allocation: create plan → choose item, quantity, basis and filters → review proposed lines with basis counts → adjust → approve → generate dispatches.
- Dispatches: outgoing and incoming lists, dispatch detail, mark dispatched, confirm receipt with quantities and photo.
- Reports: stock by unit, distribution coverage (which end points have received an item), donor traceability (where a funding source's goods went), discrepancies. CSV export everywhere.
- In v1, schools do not log in; DEO officers record each school delivery with a photo of the signed delivery note.

## 11. Engineering conventions

- Typed end to end: regenerate Supabase types after every migration.
- Validate every input with Zod on the server, even if validated on the client.
- Server components by default; server actions for mutations; no business logic duplicated in the client.
- Labels for levels, attributes and metrics always come from configuration.
- Small, readable modules; feature folders (e.g. app/(app)/[org]/dispatches).
- Tests: SQL tests for RLS and stock functions; unit tests for allocation math; one Playwright happy-path test per phase.
- Keep a short README with setup steps, and a DECISIONS.md logging any design choice you make.

## 12. Build phases (stop and report after each)

0. Project setup: Next.js, Tailwind, shadcn/ui, Supabase CLI, Serwist PWA shell, linting, folder structure.
1. Database: core schema migrations, ltree paths, RLS helpers and policies, audit triggers, RLS tests.
2. Auth and org setup: sign-in, memberships, org switcher, admin screens for levels, units, attributes, metrics, users.
3. Education template and seed; end points list, profiles and CSV import.
4. Catalogue, funding sources, lots, receipts, stock ledger and balances.
5. Allocation engine and approval, dispatch generation, dispatch and confirmation flows.
6. District-to-school distribution and the offline queue.
7. Reports and exports.

At the end of each phase, give me: what was built, how to run and test it, any decisions you made, and open questions.

## 13. Working with me

- Before Phase 0, list any questions or assumptions you want me to confirm.
- If something in this brief seems wrong or over-engineered for v1, say so and propose an alternative instead of silently changing it.
- Prefer boring, well-supported libraries over clever ones.