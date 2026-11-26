-- Ingetin v4.2: tugas boleh dititipkan ke diri sendiri (bersama teman lain)
-- Jalankan sekali di Supabase > SQL Editor > New query > Run. Aman dijalankan ulang.
create or replace function public.all_friends(ids uuid[]) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(bool_and(x = auth.uid() or public.is_friend(x)), true) from unnest(coalesce(ids, '{}')) x;
$$;
