-- =============================================================================
-- Advisor fixes after Phase 1 push.
-- 1. The FOR ALL write policies on line tables also applied to SELECT, giving
--    two permissive SELECT policies per table (slower). Split them into
--    INSERT / UPDATE / DELETE.
-- 2. Supabase's auto-enable-RLS event trigger function is SECURITY DEFINER and
--    executable by anon. Event-trigger functions cannot be called directly, so
--    this is not exploitable, but revoking keeps the security advisor clean.
-- =============================================================================

drop policy "edit lines of editable receipts" on public.receipt_lines;
drop policy "edit lines of draft plans" on public.allocation_lines;
drop policy "edit lines of draft dispatches" on public.dispatch_lines;

-- Generates insert/update/delete policies for a line table whose parent
-- document must be a draft the user may edit.
do $$
declare
  r record;
begin
  for r in
    select * from (values
      ('receipt_lines', 'receipt_id', 'receipts', 'unit_id', '{org_admin,store_manager}'),
      ('allocation_lines', 'plan_id', 'allocation_plans', 'from_unit_id', '{org_admin,store_manager,unit_officer}'),
      ('dispatch_lines', 'dispatch_id', 'dispatches', 'from_unit_id', '{org_admin,store_manager,unit_officer}')
    ) as t(line_table, fk, parent_table, unit_col, roles)
  loop
    execute format($p$
      create policy "insert lines of draft parent" on public.%1$I
        for insert to authenticated
        with check (exists (
          select 1 from public.%3$I p
          where p.id = %2$I and p.status = 'draft'
            and private.has_unit_access(p.%4$I, %5$L)
        ));
      create policy "update lines of draft parent" on public.%1$I
        for update to authenticated
        using (exists (
          select 1 from public.%3$I p
          where p.id = %2$I and p.status = 'draft'
            and private.has_unit_access(p.%4$I, %5$L)
        ))
        with check (exists (
          select 1 from public.%3$I p
          where p.id = %2$I and p.status = 'draft'
            and private.has_unit_access(p.%4$I, %5$L)
        ));
      create policy "delete lines of draft parent" on public.%1$I
        for delete to authenticated
        using (exists (
          select 1 from public.%3$I p
          where p.id = %2$I and p.status = 'draft'
            and private.has_unit_access(p.%4$I, %5$L)
        ));
    $p$, r.line_table, r.fk, r.parent_table, r.unit_col, r.roles);
  end loop;
end;
$$;

-- Let clients choose ids for drafts, so a document created offline can be
-- referenced by its lines before it syncs (Phase 6). Ids are random UUIDs.
grant insert (id) on
  public.receipts, public.receipt_lines,
  public.allocation_plans, public.allocation_lines,
  public.dispatches, public.dispatch_lines
to authenticated;

do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'rls_auto_enable') then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
