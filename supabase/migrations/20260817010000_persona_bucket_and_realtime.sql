-- ============================================================
-- 1) Public storage bucket for the editable chat persona
--    (supabase/functions/chat/persona.md is the source of truth;
--    upload it here with:
--      supabase storage cp supabase/functions/chat/persona.md \
--        public/persona.md )
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('public', 'public', true, 5242880, null)
on conflict (id) do nothing;

-- ============================================================
-- 2) Realtime: let the app listen for NEW benefit rows so it can
--    pop a "we think you might like this" notification.
-- ============================================================
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'benefit'
  ) then
    alter publication supabase_realtime add table public.benefit;
  end if;
end $$;
