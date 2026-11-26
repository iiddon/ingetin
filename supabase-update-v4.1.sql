-- Ingetin v4.1: Grup (tugas grup bisa dilihat semua anggota, tombol Ambil, kabar grup)
-- Jalankan sekali di Supabase > SQL Editor > New query > Run. Aman dijalankan ulang.
-- Butuh v3.3, v3.7, dan v3.8 sudah dijalankan.

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles on delete cascade,
  name text not null,
  color text,
  members uuid[] not null default '{}',
  member_people uuid[] not null default '{}',
  member_names jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists groups_members on public.groups using gin (members);
alter table public.groups enable row level security;

create or replace function public.group_member(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from groups g where g.id = gid and (g.owner_id = auth.uid() or auth.uid() = any(g.members)));
$$;
-- semua id ada di grup (pemilik atau anggota)
create or replace function public.all_in_group(gid uuid, ids uuid[]) returns boolean
language sql stable security definer set search_path = public as $$
  select gid is not null and coalesce((select bool_and(x = g.owner_id or x = any(g.members)) from groups g, unnest(coalesce(ids, '{}')) x where g.id = gid), true);
$$;

drop policy if exists "groups read" on public.groups;
drop policy if exists "groups add" on public.groups;
drop policy if exists "groups edit" on public.groups;
drop policy if exists "groups delete" on public.groups;
create policy "groups read" on public.groups for select to authenticated using (owner_id = auth.uid() or auth.uid() = any(members));
create policy "groups add" on public.groups for insert to authenticated with check (owner_id = auth.uid() and public.all_friends(members));
create policy "groups edit" on public.groups for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid() and public.all_friends(members));
create policy "groups delete" on public.groups for delete to authenticated using (owner_id = auth.uid());

-- tugas grup
alter table public.tasks add column if not exists group_id uuid references public.groups on delete set null;
alter table public.tasks add column if not exists group_notified boolean not null default false;
create index if not exists tasks_group on public.tasks (group_id);

drop policy if exists "tasks read" on public.tasks;
drop policy if exists "tasks add" on public.tasks;
drop policy if exists "tasks edit" on public.tasks;
create policy "tasks read" on public.tasks for select to authenticated
  using (owner_id = auth.uid() or assignee = auth.uid() or auth.uid() = any(coalesce(assignees, '{}'))
         or (group_id is not null and public.group_member(group_id)));
-- penerima titipan: teman sendiri, atau sesama anggota grup tugas itu
create policy "tasks add" on public.tasks for insert to authenticated
  with check (owner_id = auth.uid()
    and (group_id is null or public.group_member(group_id))
    and (public.all_friends(assignees) or public.all_in_group(group_id, assignees))
    and (assignee is null or public.is_friend(assignee) or public.all_in_group(group_id, array[assignee])));
create policy "tasks edit" on public.tasks for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid()
    and (group_id is null or public.group_member(group_id))
    and (public.all_friends(assignees) or public.all_in_group(group_id, assignees))
    and (assignee is null or public.is_friend(assignee) or public.all_in_group(group_id, array[assignee])));

-- yang bisa melihat obrolan: peserta + anggota grup (hanya baca)
create or replace function public.task_viewer(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.task_member(tid) or exists (select 1 from tasks t where t.id = tid and t.group_id is not null and public.group_member(t.group_id));
$$;
drop policy if exists "comments read" on public.task_comments;
create policy "comments read" on public.task_comments for select to authenticated using (public.task_viewer(task_id));

-- Ambil tugas grup yang belum dititipkan ke siapa pun
create or replace function public.claim_task(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare who text;
begin
  update tasks set assignees = array[auth.uid()], assignee = auth.uid(), notified = array[auth.uid()], assign_notified = true, updated_at = now()
  where id = p_id and group_id is not null and public.group_member(group_id) and not done
    and assignee is null and coalesce(array_length(assignees, 1), 0) = 0 and coalesce(array_length(people_ids, 1), 0) = 0;
  if not found then raise exception 'tugas sudah diambil'; end if;
  select coalesce(name, 'Seseorang') into who from profiles where id = auth.uid();
  insert into task_comments (task_id, author, text, kind, notified) values (p_id, auth.uid(), who || ' mengambil tugas ini', 'sys', true);
end $$;
grant execute on function public.claim_task(uuid) to authenticated;

-- kabar grup bisa dibisukan per orang
alter table if exists public.push_prefs add column if not exists muted_groups uuid[];

do $$ begin alter publication supabase_realtime add table public.groups; exception when others then null; end $$;
