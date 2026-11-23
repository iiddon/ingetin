-- Ingetin: struktur database Supabase
-- Jalankan sekali di Supabase > SQL Editor > New query > Run.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  invite_code text unique not null default substr(md5(gen_random_uuid()::text), 1, 8),
  created_at timestamptz not null default now()
);

create table if not exists public.friendships (
  user_id uuid not null references public.profiles on delete cascade,
  friend_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id)
);

create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles on delete cascade,
  name text not null,
  color text not null default 'pink',
  linked_user_id uuid references public.profiles on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles on delete cascade,
  person_id uuid references public.people on delete set null,
  title text not null,
  date date not null,
  time text,
  location text,
  notes text,
  shared boolean not null default false,
  checklist jsonb not null default '[]'::jsonb,
  reminders jsonb not null default '["h-1","hari-h"]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles on delete cascade,
  person_id uuid references public.people on delete cascade,
  text text not null,
  kind text not null default 'ingat',
  created_at timestamptz not null default now()
);

create index if not exists events_owner_date on public.events (owner_id, date);
create index if not exists notes_owner on public.notes (owner_id);
create index if not exists people_owner on public.people (owner_id);

alter table public.profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.people enable row level security;
alter table public.events enable row level security;
alter table public.notes enable row level security;

-- helper: apakah user X teman saya?
create or replace function public.is_friend(other uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from friendships where user_id = auth.uid() and friend_id = other);
$$;

-- profiles: lihat diri sendiri & teman; ubah diri sendiri
drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated using (id = auth.uid() or public.is_friend(id));
drop policy if exists "profiles insert" on public.profiles;
create policy "profiles insert" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "profiles update" on public.profiles;
create policy "profiles update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- friendships: hanya lihat milik sendiri (dibuat lewat fungsi accept_invite)
drop policy if exists "friendships read" on public.friendships;
create policy "friendships read" on public.friendships for select to authenticated using (user_id = auth.uid());

-- people & notes: sepenuhnya pribadi
drop policy if exists "people own" on public.people;
create policy "people own" on public.people for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "notes own" on public.notes;
create policy "notes own" on public.notes for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- events: milik sendiri, atau acara teman yang dibagikan
drop policy if exists "events read" on public.events;
create policy "events read" on public.events for select to authenticated using (owner_id = auth.uid() or (shared and public.is_friend(owner_id)));
drop policy if exists "events insert" on public.events;
create policy "events insert" on public.events for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists "events update" on public.events;
create policy "events update" on public.events for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "events delete" on public.events;
create policy "events delete" on public.events for delete to authenticated using (owner_id = auth.uid());

-- terima undangan: hubungkan dua arah
create or replace function public.accept_invite(code text) returns text
language plpgsql security definer set search_path = public as $$
declare other public.profiles;
begin
  if auth.uid() is null then raise exception 'Belum masuk'; end if;
  select * into other from public.profiles where invite_code = lower(trim(code));
  if not found then raise exception 'Kode undangan tidak ditemukan'; end if;
  if other.id = auth.uid() then raise exception 'Ini kode undanganmu sendiri'; end if;
  insert into public.friendships (user_id, friend_id) values (auth.uid(), other.id) on conflict do nothing;
  insert into public.friendships (user_id, friend_id) values (other.id, auth.uid()) on conflict do nothing;
  return other.name;
end $$;

-- putuskan hubungan: hapus dua arah
create or replace function public.remove_friend(fid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.friendships where (user_id = auth.uid() and friend_id = fid) or (user_id = fid and friend_id = auth.uid());
end $$;

grant execute on function public.accept_invite(text) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.is_friend(uuid) to authenticated;
