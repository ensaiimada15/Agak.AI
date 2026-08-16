-- ============================================================
-- Seniors registry: name + senior ID, authed via Supabase Auth.
--
-- Pattern: the app signs seniors up with a synthetic email
--   <senior_id>@seniors.agakai.app
-- and stores full_name + senior_id in auth user metadata.
-- This trigger mirrors that metadata into a queryable table.
-- ============================================================

create table if not exists public.seniors (
  id         uuid primary key references auth.users (id) on delete cascade,
  senior_id  text unique,
  full_name  text not null,
  created_at timestamptz not null default now()
);

alter table public.seniors enable row level security;

-- Seniors can read their own row (service role bypasses RLS,
-- so an LGU dashboard can list seniors via an edge function if needed).
create policy "seniors_select_own"
  on public.seniors for select
  using (auth.uid() = id);

create or replace function public.handle_new_senior()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.seniors (id, senior_id, full_name)
  values (
    new.id,
    nullif(btrim(new.raw_user_meta_data ->> 'senior_id'), ''),
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'Senior Citizen')
  )
  on conflict (id) do update
    set senior_id = excluded.senior_id,
        full_name = excluded.full_name;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_senior();
