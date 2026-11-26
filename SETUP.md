# Menyambungkan Ingetin dengan teman (Supabase)

Tanpa langkah ini, Ingetin tetap bisa dipakai, tetapi datanya hanya tersimpan di perangkat itu saja.
Supaya kamu dan teman bisa saling melihat acara, Ingetin butuh database online. Supabase gratis untuk pemakaian kecil.

## 1. Buat project Supabase (sekitar 5 menit)
1. Buka https://supabase.com, lalu daftar atau masuk.
2. Klik **New project**. Isi nama `ingetin`, buat password database, pilih region **Southeast Asia (Singapore)**, lalu klik **Create**.

## 2. Buat tabel
1. Di menu kiri, buka **SQL Editor**, lalu klik **New query**.
2. Salin seluruh isi file `supabase-setup.sql`, tempel di editor, lalu klik **Run**. Hasilnya harus *Success*.

## 3. Atur login
1. Buka **Authentication › Sign In / Providers › Email**.
2. Supaya bisa langsung masuk setelah daftar, **matikan "Confirm email"**. Kalau tetap dinyalakan, pengguna baru harus membuka link konfirmasi di email dulu.
3. Buka **Authentication › URL Configuration**, lalu isi **Site URL** dengan alamat aplikasi, misalnya `https://iiddon.github.io/ingetin/`.

## 4. Masukkan kunci ke aplikasi
1. Buka **Project Settings › API** (atau **Data API**).
2. Salin **Project URL** dan **anon public key**.
3. Masukkan keduanya ke file `config.js` di repo:
   ```js
   window.INGETIN_CONFIG = {
     supabaseUrl: 'https://xxxx.supabase.co',
     supabaseAnonKey: 'eyJhbGciOi...'
   };
   ```
   Kunci *anon* memang dibuat untuk dipakai di aplikasi publik. Data tetap aman karena dilindungi aturan RLS di database.
   Jangan pernah memasukkan kunci **service_role**.

Kalau `config.js` diisi di repo, semua orang yang membuka link aplikasi otomatis memakai database yang sama.
Untuk percobaan, kamu juga bisa mengisi URL dan key langsung di aplikasi lewat **Pengaturan** (hanya berlaku di perangkat itu).

## 5. Mulai pakai
1. Buka aplikasi, lalu masuk ke **Pengaturan › Daftar**.
2. Kalau sebelumnya sudah ada data di perangkat, Ingetin akan menawarkan untuk memindahkannya ke akunmu.
3. Ketuk **Undang teman › Kirim lewat WhatsApp**. Setelah temanmu daftar lewat link itu, kalian otomatis terhubung.
4. Saat membuat acara, nyalakan **Bagikan ke teman yang terhubung** supaya acara itu muncul di kalender mereka.
   Catatan tentang teman selalu pribadi dan tidak pernah dibagikan.

## Notifikasi server (v3.1): pengingat tetap muncul walau aplikasi ditutup

Cukup sekali per proyek Supabase. Panduan yang sama ada di aplikasi: Pengaturan › Notifikasi › **Panduan menyiapkan server** (lengkap dengan tombol salin).

1. **Jalankan SQL**: Supabase › SQL Editor › New query › tempel isi `supabase-update-v3.1.sql` › Run.
   Ini membuat tabel `push_subs`, `push_prefs`, `push_sent`, `push_vapid`, dan jadwal Cron `ingetin-push` yang berjalan tiap menit.
2. **Buat Edge Function**: Supabase › Edge Functions › Deploy a new function › Via Editor.
   Beri nama `push`, hapus contoh kode, tempel isi `supabase/functions/push/index.ts`, lalu Deploy.
3. **Matikan Verify JWT**: buka fungsi `push` › Details › matikan *Enforce JWT Verification* › Save.
   (Fungsi ini tidak memberi akses data; Cron dan aplikasi memanggilnya tanpa token.)
4. **Nyalakan di aplikasi**: masuk ke akun, lalu Pengaturan › Notifikasi › nyalakan *Notifikasi walau aplikasi ditutup*. Notifikasi uji akan datang.

Catatan:
- Kunci VAPID dibuat otomatis oleh fungsi dan disimpan di tabel `push_vapid` yang hanya bisa dibaca server. Tidak ada kunci rahasia yang perlu disalin.
- Nyalakan per HP. Kalau ganti HP atau menghapus data browser, nyalakan lagi.
- Cek jadwal: SQL Editor › `select * from cron.job_run_details order by start_time desc limit 5;`

## Update v3.3: Tugas, titip ke teman, ringkasan pagi dari server

1. SQL Editor › New query › tempel isi `supabase-update-v3.3.sql` › Run.
2. Edge Functions › `push` › Code › ganti seluruh isinya dengan `supabase/functions/push/index.ts` terbaru › Deploy.
   (Pastikan *Enforce JWT Verification* tetap mati.)
3. Buka Ingetin sekali supaya pengaturan Ringkasan pagi terkirim ke server.

Panduan & tombol salin juga ada di aplikasi: Pengaturan › Notifikasi › Panduan menyiapkan server.

## Update v3.7: obrolan per tugas & titip ke beberapa teman

1. SQL Editor › New query › tempel isi `supabase-update-v3.7.sql` › Run (setelah v3.3).
2. Edge Functions › `push` › Code › ganti seluruh isinya dengan `supabase/functions/push/index.ts` terbaru › Deploy.

## Update v3.8: titip tugas ke teman yang belum gabung

SQL Editor › New query › tempel isi `supabase-update-v3.8.sql` › Run. (Fungsi `push` tidak perlu diubah.)

## Update v4.1: Grup

1. SQL Editor › New query › tempel isi `supabase-update-v4.1.sql` › Run (setelah v3.8).
2. Edge Functions › `push` › Code › ganti seluruh isinya dengan `supabase/functions/push/index.ts` terbaru › Deploy.

## Update v4.2: titip ke diri sendiri

SQL Editor › New query › tempel isi `supabase-update-v4.2.sql` › Run, lalu perbarui kode fungsi `push` (Code › ganti › Deploy).
