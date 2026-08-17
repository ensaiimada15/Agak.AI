-- ============================================================
-- Linear per-user chat memory + rolling psychological notes.
--
-- conversation_history : jsonb array of { role, content } turns,
--                        newest last. Linear — no branches.
-- user_notes           : rolling PSYCHOLOGICAL summary of the
--                        senior, REVISED (compacted) after each
--                        exchange by the chat edge function so the
--                        field stays bounded (~1200 chars).
-- ============================================================

alter table public.user
  add column if not exists conversation_history jsonb not null default '[]'::jsonb;
