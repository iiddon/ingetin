-- Ingetin v3.7: obrolan per tugas + titip ke beberapa teman ("cukup salah satu")
-- Jalankan sekali di Supabase > SQL Editor > New query > Run. Aman dijalankan ulang.
-- Butuh supabase-update-v3.3.sql sudah dijalankan.

-- 1) Beberapa penerima titipan
alter table public.tasks add column if not exists assignees uuid[];
alter table public.tasks add column if not exists notified uuid[] not null default '{}';
update public.tasks set assignees = array[assignee] where assignee is not null and assignees is null;
update public.tasks set notified = array[assignee] where assignee is not null and assign_notified and notified = '{}';
create index if not exists tasks_assignees on public.tasks using gin (assignees);

-- semua penerima harus teman yang sudah terhubung
create or replace function public.all_friends(ids uuid[]) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(bool_and(public.is_friend(x)), true) from unnest(coalesce(ids, '{}')) x;
$$;
-- anggota tugas = pemilik atau salah satu penerima
create or replace function public.task_member(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from tasks t where t.id = tid and (t.owner_id = auth.uid() or t.assignee = auth.uid() or auth.uid() = any(coalesce(t.assignees, '{}'))));
$$;

drop policy if exists "tasks read" on public.tasks;
drop policy if exists "tasks add" on public.tasks;
drop policy if exists "tasks edit" on public.tasks;
create policy "tasks read" on public.tasks for select to authenticated
  using (owner_id = auth.uid() or assignee = auth.uid() or auth.uid() = any(coalesce(assignees, '{}')));
create policy "tasks add" on public.tasks for insert to authenticated
  with check (owner_id = auth.uid() and (assignee is null or public.is_friend(assignee)) and public.all_friends(assignees));
create policy "tasks edit" on public.tasks for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and (assignee is null or public.is_friend(assignee)) and public.all_friends(assignees));

-- 2) Obrolan per tugas
create table if not exists public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks on delete cascade,
  author uuid not null default auth.uid() references public.profiles on delete cascade,
  text text not null check (length(text) between 1 and 2000),
  kind text not null default 'msg' check (kind in ('msg', 'sys')),
  notified boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists task_comments_task on public.task_comments (task_id, created_at);
alter table public.task_comments enable row level security;
drop policy if exists "comments read" on public.task_comments;
drop policy if exists "comments add" on public.task_comments;
drop policy if exists "comments delete" on public.task_comments;
create policy "comments read" on public.task_comments for select to authenticated using (public.task_member(task_id));
create policy "comments add" on public.task_comments for insert to authenticated
  with check (author = auth.uid() and kind = 'msg' and public.task_member(task_id));
create policy "comments delete" on public.task_comments for delete to authenticated using (author = auth.uid());

-- 3) Mencentang: "cukup salah satu" + catatan otomatis di obrolan
create or replace function public.set_task_done(p_id uuid, p_done boolean) returns void
language plpgsql security definer set search_path = public as $$
declare who text;
begin
  update tasks set done = p_done,
    done_at = case when p_done then now() end,
    done_by = case when p_done then auth.uid() end,
    done_notified = false, updated_at = now()
  where id = p_id and (owner_id = auth.uid() or assignee = auth.uid() or auth.uid() = any(coalesce(assignees, '{}')));
  if not found then raise exception 'tugas tidak ditemukan'; end if;
  select coalesce(name, 'Seseorang') into who from profiles where id = auth.uid();
  insert into task_comments (task_id, author, text, kind, notified)
  values (p_id, auth.uid(), who || case when p_done then ' menandai tugas ini beres' else ' membuka lagi tugas ini' end, 'sys', true);
end $$;
grant execute on function public.set_task_done(uuid, boolean) to authenticated;

-- 4) Realtime (pesan & status langsung muncul)
do $$ begin alter publication supabase_realtime add table public.task_comments; exception when others then null; end $$;
do $$ begin alter publication supabase_realtime add table public.tasks; exception when others then null; end $$;
