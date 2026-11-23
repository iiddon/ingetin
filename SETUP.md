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
