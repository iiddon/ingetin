-- Ingetin v2.8: bagikan acara hanya ke teman yang dipilih.
-- Jalankan sekali di Supabase > SQL Editor > New query > Run.
alter table public.events add column if not exists share_with uuid[];

drop policy if exists "events read" on public.events;
create policy "events read" on public.events for select to authenticated
  using (owner_id = auth.uid() or (shared and public.is_friend(owner_id) and (share_with is null or auth.uid() = any(share_with))));
