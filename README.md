# Ingetin

Kalender bersama teman. Gunanya supaya kamu ingat acara, hal penting tentang teman, dan apa saja yang perlu disiapkan.

**Buka aplikasi:** https://iiddon.github.io/ingetin/

## Fitur
- **Kalender bulanan** dengan warna berbeda untuk setiap teman, ditambah ringkasan "Minggu ini", "Segera", dan "Ingat juga".
- **Tambah cepat**: tulis seperti chat biasa, misalnya "Dina sidang skripsi 3 Desember jam 9". Tanggal, jam, dan nama teman dibaca otomatis. Kalimat tanpa tanggal seperti "Rina alergi udang" disimpan sebagai catatan.
- **Profil teman** berisi tiga bagian: *Yang harus diingat*, *Event mendatang*, dan *Pernah cerita*.
- **Checklist persiapan** dan **pengingat** H-7, H-3, H-1, dan hari H untuk setiap acara.
- **Tambah ke Kalender HP** lewat file .ics, supaya pengingat tetap berbunyi walau aplikasi tertutup.
- **Undang teman** lewat WhatsApp. Acara yang dibagikan langsung muncul di kalender teman.
- Bisa diinstal di iPad atau HP (Bagikan › Tambah ke Layar Utama), dan tetap terbuka saat offline.
- Ekspor dan impor cadangan data.

## Penyimpanan
- Tanpa pengaturan apa pun, data disimpan di perangkat (localStorage).
- Untuk berbagi dengan teman, sambungkan ke Supabase. Langkahnya ada di [SETUP.md](SETUP.md).

## File
| File | Isi |
|---|---|
| `index.html` | Seluruh aplikasi |
| `config.js` | Alamat dan kunci Supabase |
| `supabase-setup.sql` | Struktur database dan aturan keamanan |
| `sw.js`, `manifest.json` | Pengaturan PWA (bisa diinstal dan offline) |
| `icon*.png`, `icon.svg`, `favicon*` | Ikon aplikasi |
