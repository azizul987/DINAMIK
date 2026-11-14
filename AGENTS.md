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

## 5. Arsitektur Berbasis Scene & Prefab (Best Practice Godot)
- **Utamakan Scene/Prefab (`.tscn`) daripada Hardcode Script:** Seluruh entitas visual, UI, collider, partikel, audio player, dan komponen game WAJIB didefinisikan sebagai file Scene Prefab (`.tscn`) atau sub-node scene di editor Godot, BUKAN di-instansiasi manual lewat kode GDScript (`.new()`).
- **Dilarang Hardcode Komponen:** Hindari membuat hierarki UI atau node 3D secara prosedural di dalam script (seperti `SubViewport.new()`, `ProgressBar.new()`, `MeshInstance3D.new()`, `Area3D.new()`) jika komponen tersebut merupakan bagian tetap dari entitas.
- **Referensi Bersih:** Skrip GDScript bertugas menghubungkan referensi node via `@onready`, memproses logika state, dan menggerakkan animasi/properti saat runtime.
- **Modular Spawning:** Objek yang dimunculkan berulang (seperti monster, item drop, projectile) WAJIB dibuat sebagai PackedScene prefab tersendiri dan dimunculkan menggunakan `PREFAB.instantiate()`.

## 6. Standar Optimasi Performa & Anti-Lag (Best Practice Godot 4 / Forward+)
- **SubViewport Bar Darah (UPDATE_ONCE):** Seluruh `SubViewport` offscreen untuk bar darah/billboard 3D WAJIB diatur ke `render_target_update_mode = SubViewport.UPDATE_ONCE` secara default di file `.tscn` dan script. Hanya aktifkan ke `UPDATE_ALWAYS` secara temporer saat nilai bar sedang beranimasi/berubah karena damage, lalu kembalikan ke `UPDATE_ONCE` setelah tween selesai. Saat entitas gugur/mati, matikan dengan `UPDATE_DISABLED`.
- **Manajemen Tween & State Timer AI:** Hindari penumpukan tween pada properti yang sama tanpa mematikan tween lama terlebih dahulu (simpan referensi seperti `_scale_tween` dan panggil `kill()` sebelum `create_tween()`). Pada state machine AI, selalu patuhi jeda pewaktu (misal `idle_timer`), dilarang memicu aksi lompat/serangan fisik berulang setiap frame.
- **Efisiensi Geometri Mesh Primitif:** Pada entitas atau partikel yang dimunculkan dalam jumlah jamak (seperti monster atau letupan cairan), jangan gunakan segmen default berlebih. Batasi `radial_segments` (12–24) dan `rings` (6–12) pada `SphereMesh` untuk mencegah beban ribuan poligon yang tidak perlu.
- **Caching Resource & Material Statis:** Dilarang mengalokasikan resource identik berulang di memori (misal `StandardMaterial3D.new()` untuk hit flash atau generator audio WAV di `_ready()`). Wajib gunakan variabel statis (`static var _cached_...`) agar resource dipakai bersama oleh seluruh instance scene.

## 7. Praktik Efisiensi Penambahan & Manajemen Node (Anti-Lag Node Lifecycle)
- **Spesifikasi Layer & Mask Fisika:** Setiap kali menambahkan node collider/fisik (`CharacterBody3D`, `Area3D`, `StaticBody3D`), WAJIB menetapkan `collision_layer` dan `collision_mask` secara spesifik sesuai perannya (pemain, musuh, proyektil, lingkungan). DILARANG membiarkan default Layer 1 untuk seluruh objek agar physics server tidak memproses tabrakan massal antar sesama entitas sejenis.
- **Batas Masa Hidup Node Dinamis (TTL & Cleanup):** Seluruh node yang dimunculkan dinamis (proyektil, floating text, partikel, loot drop) WAJIB memiliki mekanisme penghapusan otomatis (`queue_free()`) setelah masa hidupnya berakhir. Dilarang membiarkan entitas nonaktif tertimbun di dalam scene tree.
- **Deaktivasi Sensor & Loop Pasif:** Entitas yang sudah tidak bergerak atau tidak butuh kalkulasi per-frame WAJIB mematikan pemrosesan dengan `set_physics_process(false)` atau `set_process(false)`. Pada `Area3D` yang pasif/selesai digunakan, matikan `monitoring` dan `monitorable` via `set_deferred()`.
- **Dilarang Query Berat di Loop Frame:** DILARANG menjalankan pencarian node (seperti `get_node()`, `get_tree().get_nodes_in_group()`, atau `find_child()`) di dalam `_process()` atau `_physics_process()`. Seluruh referensi wajib di-cache di awal melalui `@onready` atau saat inisialisasi `_ready()`.
- **Efisiensi Pencahayaan Dinamis:** Saat menambahkan lampu dinamis (`OmniLight3D`, `SpotLight3D`), matikan bayangan (`shadow_enabled = false`) kecuali pada sumber cahaya utama level. Lampu proyektil atau efek visual kecil dilarang memakai real-time shadows.
