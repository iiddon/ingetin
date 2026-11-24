-- Ingetin v3.1: notifikasi walau aplikasi ditutup (Web Push)
-- Jalankan sekali di Supabase > SQL Editor > New query > Run.
-- Lalu buat Edge Function "push" (lihat SETUP.md bagian Notifikasi server).
-- Aman dijalankan ulang.

-- 1) Langganan push per perangkat
create table if not exists public.push_subs (
  endpoint text primary key,
  user_id uuid not null references public.profiles on delete cascade,
  sub jsonb not null,
  tz_min int not null default 420,
  ua text,
  created_at timestamptz not null default now()
);
create index if not exists push_subs_user on public.push_subs (user_id);
alter table public.push_subs enable row level security;
drop policy if exists "push_subs own" on public.push_subs;
create policy "push_subs own" on public.push_subs for select to authenticated using (user_id = auth.uid());

-- simpan / ganti langganan perangkat ini (perangkat bisa pindah akun)
create or replace function public.save_push_sub(p_endpoint text, p_sub jsonb, p_tz int, p_ua text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  delete from push_subs where endpoint = p_endpoint;
  insert into push_subs (endpoint, user_id, sub, tz_min, ua) values (p_endpoint, auth.uid(), p_sub, coalesce(p_tz, 420), left(p_ua, 160));
end $$;
create or replace function public.delete_push_sub(p_endpoint text) returns void
language sql security definer set search_path = public as $$
  delete from push_subs where endpoint = p_endpoint and user_id = auth.uid();
$$;
grant execute on function public.save_push_sub(text, jsonb, int, text) to authenticated;
grant execute on function public.delete_push_sub(text) to authenticated;

-- 2) Pengaturan pengingat untuk acara teman (supaya server tahu)
create table if not exists public.push_prefs (
  user_id uuid primary key default auth.uid() references public.profiles on delete cascade,
  friend_rem jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.push_prefs enable row level security;
drop policy if exists "push_prefs own" on public.push_prefs;
create policy "push_prefs own" on public.push_prefs for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3) Catatan pengingat yang sudah dikirim (supaya tidak dobel)
create table if not exists public.push_sent (
  user_id uuid not null references public.profiles on delete cascade,
  key text not null,
  sent_at timestamptz not null default now(),
  primary key (user_id, key)
);
alter table public.push_sent enable row level security;
drop policy if exists "push_sent read" on public.push_sent;
drop policy if exists "push_sent add" on public.push_sent;
create policy "push_sent read" on public.push_sent for select to authenticated using (user_id = auth.uid());
create policy "push_sent add" on public.push_sent for insert to authenticated with check (user_id = auth.uid());

-- 4) Kunci VAPID (dibuat otomatis oleh Edge Function, hanya server yang bisa membaca)
create table if not exists public.push_vapid (
  id int primary key check (id = 1),
  public_key text not null,
  private_key text not null
);
alter table public.push_vapid enable row level security;
revoke all on public.push_vapid from anon, authenticated;

-- 5) Jadwal: panggil Edge Function tiap menit
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
select cron.unschedule(jobid) from cron.job where jobname = 'ingetin-push';
select cron.schedule('ingetin-push', '* * * * *', $$
  select net.http_post(
    url := 'https://lumpmckfiuhngdzqrqis.supabase.co/functions/v1/push',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := '{"run":true}'::jsonb
  );
$$);
