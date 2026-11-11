# Aturan Arsitektur & Manajemen Fungsi Proyek

## 1. Pemisahan Logika & Variabel Global
- Setiap kali membuat variabel atau fungsi, tentukan cakupannya (lokal vs global).
- State/variabel bersama (misalnya: level Toxicity, HP Alkemis, lantai dungeon, inventori bahan ramuan) dan fungsi utilitas global harus disimpan di file Autoload/Singleton: `res://global_logic.gd`.
- Logika lokal khusus node (misalnya: pergerakan fisik Player, rotasi kamera, AI monster tertentu) tetap berada di skrip lokal masing-masing.

## 2. Pencatatan Fungsi & Variabel Penting (Registry)
- Rawat file `FUNCTIONS_REGISTRY.md` di root proyek yang mencatat seluruh fungsi dan variabel penting:
  - Lokasi file (`res://...`)
  - Nama, tipe data, nilai default, dan tujuan variabel
  - Nama fungsi, parameter, return type, dan kegunaannya
- **Pedoman Penulisan Deskripsi**:
  - Tulis deskripsi fungsional secara umum, objektif, dan ringkas (1 kalimat pendek per entri).
  - **DILARANG KERAS** menyisipkan catatan percakapan chat, riwayat revisi, atau instruksi (contoh terlarang: *"sesuai revisi"*, *"murni angka simpel"*, *"sesuai perintah user"*).
- **Sebelum membuat fungsi atau variabel baru**, agen WAJIB memeriksa `FUNCTIONS_REGISTRY.md` terlebih dahulu agar tidak membuat variabel/fungsi yang berulang/duplikat.

## 3. Aturan .gitignore
- File `FUNCTIONS_REGISTRY.md` harus selalu terdaftar di `.gitignore` agar tidak mengotori commit riwayat git.

## 4. Manajemen Proses Background & Lifecycle Task
- **Wajib Auto-Terminate pada Pengujian:** Setiap kali menjalankan pengujian headless Godot atau skrip runner, agen WAJIB menggunakan flag pembatas (misal `--quit-after N`) atau memastikan skrip memanggil `get_tree().quit()` / `quit()` agar proses tidak menggantung tanpa batas.
- **Pembersihan Proses di Akhir Giliran:** Sebelum menyelesaikan respon percakapan, agen WAJIB memeriksa task aktif via `manage_task` dan mematikan (*kill*) seluruh proses background yang tidak diperlukan, KECUALI pengguna secara eksplisit meminta proses tersebut tetap berjalan di latar belakang (misal dev server, watcher, atau daemon).
