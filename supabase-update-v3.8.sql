-- Ingetin v3.8: titip tugas ke teman yang belum gabung (kontak manual)
-- Jalankan sekali di Supabase > SQL Editor > New query > Run. Aman dijalankan ulang.
-- Berisi id kontak (tabel people milikmu). Saat kontak dihubungkan ke akun teman,
-- aplikasi memindahkannya ke kolom assignees sehingga temanmu langsung dapat notifikasi.
alter table public.tasks add column if not exists people_ids uuid[];
