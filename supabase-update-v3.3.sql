-- Ingetin v3.3: fitur Tugas (to-do), titip ke teman, ringkasan pagi dari server
-- Jalankan sekali di Supabase > SQL Editor > New query > Run. Aman dijalankan ulang.
-- Butuh: supabase-setup.sql (dan supabase-update-v3.1.sql untuk notifikasi server).

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles on delete cascade,
  title text not null,
  due date,
  time text,
  notes text,
  done boolean not null default false,
  done_at timestamptz,
  done_by uuid references public.profiles on delete set null,
  event_id uuid references public.events on delete set null,
  event_date date,
  assignee uuid references public.profiles on delete set null,
  remind boolean not null default true,
  assign_notified boolean not null default false,
  done_notified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists tasks_owner on public.tasks (owner_id);
create index if not exists tasks_assignee on public.tasks (assignee);
alter table public.tasks enable row level security;

drop policy if exists "tasks read" on public.tasks;
drop policy if exists "tasks add" on public.tasks;
drop policy if exists "tasks edit" on public.tasks;
drop policy if exists "tasks delete" on public.tasks;
-- pemilik & teman yang dititipi bisa melihat
create policy "tasks read" on public.tasks for select to authenticated
  using (owner_id = auth.uid() or assignee = auth.uid());
-- hanya boleh dititipkan ke teman yang sudah terhubung
create policy "tasks add" on public.tasks for insert to authenticated
  with check (owner_id = auth.uid() and (assignee is null or public.is_friend(assignee)));
create policy "tasks edit" on public.tasks for update to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and (assignee is null or public.is_friend(assignee)));
create policy "tasks delete" on public.tasks for delete to authenticated
  using (owner_id = auth.uid());

-- teman yang dititipi hanya bisa mencentang (tidak bisa mengubah isi tugas)
create or replace function public.set_task_done(p_id uuid, p_done boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  update tasks set done = p_done,
    done_at = case when p_done then now() end,
    done_by = case when p_done then auth.uid() end,
    done_notified = false, updated_at = now()
  where id = p_id and (assignee = auth.uid() or owner_id = auth.uid());
  if not found then raise exception 'tugas tidak ditemukan'; end if;
end $$;
grant execute on function public.set_task_done(uuid, boolean) to authenticated;

-- kalau penerima titipan diganti, kabari penerima yang baru
create or replace function public.tasks_touch() returns trigger
language plpgsql as $$
begin
  if new.assignee is distinct from old.assignee then new.assign_notified := false; end if;
  if new.done and not old.done then new.done_notified := false; end if;
  return new;
end $$;
drop trigger if exists tasks_touch on public.tasks;
create trigger tasks_touch before update on public.tasks for each row execute function public.tasks_touch();

-- ringkasan pagi dari server: simpan pengaturannya
alter table if exists public.push_prefs add column if not exists brief jsonb;
alter table if exists public.push_prefs add column if not exists tz_min int;
