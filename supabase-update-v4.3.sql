-- Ingetin v4.3: checklist di Tugas + persiapan acara bisa dicentang teman yang dibagikan
-- Jalankan sekali di Supabase > SQL Editor > New query > Run. Aman dijalankan ulang.

-- 1) Kolom checklist untuk tugas
alter table public.tasks add column if not exists checklist jsonb not null default '[]'::jsonb;

-- 2) Yang dititipi boleh mencentang langkah checklist (tidak boleh mengubah teks/menambah/menghapus)
create or replace function public.set_task_check(p_id uuid, p_list jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare cur jsonb;
begin
  select coalesce(checklist, '[]'::jsonb) into cur from tasks
   where id = p_id and (owner_id = auth.uid() or assignee = auth.uid() or auth.uid() = any(coalesce(assignees, '{}')));
  if not found then raise exception 'tugas tidak ditemukan'; end if;
  if jsonb_typeof(p_list) <> 'array' or jsonb_array_length(p_list) <> jsonb_array_length(cur)
     or exists (select 1 from jsonb_array_elements(cur) with ordinality a(x, i)
                join jsonb_array_elements(p_list) with ordinality b(y, j) on i = j
                where (x->>'text') is distinct from (y->>'text'))
  then raise exception 'hanya boleh mencentang langkah yang ada'; end if;
  update tasks set checklist = p_list where id = p_id;
end $$;
grant execute on function public.set_task_check(uuid, jsonb) to authenticated;

-- 3) Teman yang dibagikan acara boleh mencentang checklist persiapan
create or replace function public.set_event_check(p_id uuid, p_date date, p_list jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare e events; cur jsonb; rec boolean; k text := p_date::text;
begin
  select * into e from events
   where id = p_id and (owner_id = auth.uid() or (shared and public.is_friend(owner_id) and (share_with is null or auth.uid() = any(share_with))));
  if not found then raise exception 'acara tidak ditemukan'; end if;
  rec := coalesce(e.repeat, '') in ('daily', 'weekly', 'monthly', 'yearly');
  if rec then
    cur := coalesce(e.occ -> k -> 'checklist',
      (select coalesce(jsonb_agg(jsonb_build_object('text', x->>'text', 'done', false) order by i), '[]'::jsonb)
         from jsonb_array_elements(coalesce(e.checklist, '[]'::jsonb)) with ordinality t(x, i)));
  else
    cur := coalesce(e.checklist, '[]'::jsonb);
  end if;
  if jsonb_typeof(p_list) <> 'array' or jsonb_array_length(p_list) <> jsonb_array_length(cur)
     or exists (select 1 from jsonb_array_elements(cur) with ordinality a(x, i)
                join jsonb_array_elements(p_list) with ordinality b(y, j) on i = j
                where (x->>'text') is distinct from (y->>'text'))
  then raise exception 'hanya boleh mencentang item yang ada'; end if;
  if rec then
    update events set occ = jsonb_set(coalesce(occ, '{}'::jsonb), array[k], coalesce(occ -> k, '{}'::jsonb) || jsonb_build_object('checklist', p_list)), updated_at = now()
     where id = p_id;
  else
    update events set checklist = p_list, updated_at = now() where id = p_id;
  end if;
end $$;
grant execute on function public.set_event_check(uuid, date, jsonb) to authenticated;
