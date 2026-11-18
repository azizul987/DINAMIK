# Rencana Implementasi: Model Botol & Animasi Minum Potion

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambahkan representasi visual 3D saat pemain meminum ramuan, menggunakan model botol dari `res://resources/bottle/botol.fbx` yang terpasang di tangan kiri karakter dan dianimasikan menggunakan klip gerakan dari `res://char/Animations/Drinking.fbx` dengan pewarnaan cairan dinamis sesuai jenis ramuan.

**Architecture:**
1. **Scene Prefab Modular (`res://resources/bottle/potion_bottle.tscn`)**: Membuat prefab botol potion mandiri berbasis mesh `LabuBawah_001` dari `botol.fbx`, memiliki skrip pengatur warna cairan (`potion_bottle.gd`) dengan caching material statis (Rule 5 & 6 AGENTS.md).
2. **Penyematan Bone Attachment (`LeftHandAttachment`)**: Menambahkan node `BoneAttachment3D` pada skeleton `Players/Ranger/Rig_Medium/Skeleton3D` yang tertaut ke bone `handslot.l` (atau `hand.l`), menampung instance `potion_bottle.tscn` dengan visibilitas tersembunyi secara default.
3. **Ekstraksi & Integrasi Animasi (`drink`)**: Mengekstrak segmen aktif minum dari `res://char/Animations/Drinking.fbx` (rentang t=2.6s s.d 5.6s, dioptimalkan menjadi ~1.5s) dan mendaftarkannya ke dalam `res://resources/player/player_anim_library.tres` sebagai animasi `drink`.
4. **Logika Kontroler Minum (`res://Player.gd`)**: Mengelola state `is_drinking`, menampilkan botol dengan warna ramuan terkait, memainkan animasi `drink`, mengatur batasan mobilitas saat minum, dan menyembunyikan botol kembali setelah animasi tuntas.
5. **Pencatatan Registry (`res://FUNCTIONS_REGISTRY.md`)**: Mendaftarkan seluruh fungsi dan variabel baru dengan deskripsi objektif 1 kalimat.

**Tech Stack:** Godot 4.6 (Forward+ / Jolt Physics), GDScript, BoneAttachment3D, AnimationPlayer & AnimationLibrary, StandardMaterial3D.

---

## User Review & Alignment

> [!NOTE]
> **Keputusan Terkonfirmasi oleh Pengguna:**
> 1. **Durasi & Mobilitas Minum**: Mode **Semi-Mobile** dipilih. Kecepatan gerak karakter berkurang 50% (`walk_speed * 0.5`) selama durasi ~1.5 detik. Karakter tetap dapat memposisikan diri, namun serangan dan dash terkunci hingga botol selesai diteguk.
> 2. **Warna Cairan Botol**: Mode **Dinamis** dipilih. Material permukaan kaca botol otomatis berganti warna sesuai jenis ramuan yang dikonsumsi (Healing: Hijau Zamrud, Strength: Oranye, Slow: Biru Es, Berserk: Merah Darah, Ironskin: Putih Perak).
> 3. **Tangan Pemegang Botol**: Model botol disematkan pada **Tangan Kiri** (`handslot.l` / `wrist.l`) melalui `BoneAttachment3D`, sementara tangan kanan tetap memegang senjata.

---

## Proposed Changes

Grouped by component layer:

### Component 1: Prefab & Visual Model Botol (`resources/bottle/`)

#### [NEW] `res://resources/bottle/potion_bottle.gd`
Skrip pengontrol visual botol untuk mengubah warna cairan sesuai jenis ramuan:
- `set_potion_color(potion_name: String) -> void`: Mengubah albedo color surface 0 (`Kaca_Labu`) sesuai warna ramuan (Healing: Hijau Zamrud, Strength: Oranye, Slow: Biru Es, Berserk: Merah Darah, Ironskin: Perak/Putih).

#### [NEW] `res://resources/bottle/potion_bottle.tscn`
Scene Prefab modular berisikan:
- `Node3D` root (`PotionBottle`)
- `MeshInstance3D` (`BottleMesh`) memuat ArrayMesh dari `res://resources/bottle/botol.fbx`
- Scale disesuaikan ke ukuran genggaman tangan (skala ~0.9 - 1.0) dengan offset rotasi agar pas di genggaman tangan kiri.

---

### Component 2: Animasi Karakter (`resources/player/`)

#### [MODIFY] `res://resources/player/player_anim_library.tres`
- Menambahkan sub-resource animasi `drink` yang diekstrak dari `res://char/Animations/Drinking.fbx`.
- Disesuaikan agar loop wrap false, durasi ~1.5 detik, menggerakkan bone tangan kiri ke area mulut dan kembali ke bawah.

---

### Component 3: Hirarki Scene Pemain (`res://main.tscn`)

#### [MODIFY] `res://main.tscn`
- Di bawah node `Players/Ranger/Rig_Medium/Skeleton3D`, tambahkan `BoneAttachment3D` bernama `LeftHandAttachment` dengan `bone_name = "handslot.l"`.
- Instansiasikan `res://resources/bottle/potion_bottle.tscn` sebagai anak dari `LeftHandAttachment` dengan nama `PotionBottle`, default `visible = false`.

---

### Component 4: Logika Pemain (`res://Player.gd`)

#### [MODIFY] `res://Player.gd`
- Tambahkan variabel:
  - `@onready var potion_bottle: Node3D = %PotionBottle` (atau via node path `LeftHandAttachment/PotionBottle`)
  - `var is_drinking: bool = false`
  - `var drink_speed_multiplier: float = 0.4`
- Di fungsi `_physics_process`:
  - Jika `is_drinking`, batasi kecepatan gerak (misal `walk_speed * drink_speed_multiplier`) dan cegah aksi attack/dash saat sedang minum.
- Di fungsi `_on_potion_consumed(potion_name: String)`:
  - Panggil `_play_drink_sequence(potion_name: String)`.
  - Tampilkan botol, atur warna cairan sesuai jenis ramuan.
  - Putar `animation_player.play("drink", 0.15, 1.6)`.
  - Saat animasi selesai, sembunyikan botol dan kembalikan state `is_drinking = false`.

---

### Component 5: Dokumentasi Proyek

#### [MODIFY] `res://FUNCTIONS_REGISTRY.md`
- Daftarkan `potion_bottle.gd` (fungsi `set_potion_color`, variabel warna).
- Daftarkan variabel & fungsi baru di `Player.gd` (`is_drinking`, `_play_drink_sequence`).

---

## Verification Plan

### Automated Tests
1. **Asset & Prefab Validation**:
   Skrip headless yang menginstansiasi `potion_bottle.tscn` dan memverifikasi `set_potion_color` mengubah albedo material surface 0 tanpa error:
   ```bash
   /opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --path . --script res://test_potion_bottle.gd
   ```
2. **Player Integration Test**:
   Skrip headless yang memuat `main.tscn`, memicu `GlobalLogic.consume_potion("healing")`, memverifikasi bahwa `potion_bottle.visible == true` dan `animation_player.current_animation == "drink"`, kemudian setelah timer durasi verifikasi `potion_bottle.visible == false`:
   ```bash
   /opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --path . --script res://test_drinking_sequence.gd
   ```

### Manual Verification
1. Jalankan game di editor atau test runner.
2. Ambil bahan / craft ramuan healing atau gunakan tombol debug (B untuk bahan).
3. Tekan angka 1 untuk minum healing potion:
   - Perhatikan karakter mengangkat botol di tangan kiri ke arah mulut.
   - Perhatikan cairan di dalam botol berwarna hijau menyala.
   - Perhatikan suara tegukan audio dan efek visual toast/angka melayang sinkron.
   - Perhatikan setelah selesai minum botol disimpan kembali dan karakter kembali ke animasi idle/bergerak normal.
