# Rencana Implementasi: Buka Pintu Pasca Minum Potion & Efek Angin Dash

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengubah waktu pembukaan pintu `door` (bukan door1/door2) agar hanya terbuka setelah pemain meminum Healing Potion, serta menambahkan efek visual dan audio angin (*aerodynamic wind rush, shockwave ring, swoosh audio*) pada kemampuan Dash pemain.

**Architecture:** 
1. Di `tutorial_controller.gd`, hilangkan pemanggilan `d1.open_door()` pada saat meracik ramuan (`_advance_from_craft_healing`), dan pindahkan pemanggilan pembukaan `d1.open_door()` ke event saat pemain meminum ramuan penyembuh (`_on_potion_consumed("healing")`).
2. Buat prefab modular `res://dash_wind_effect.tscn` (berisi shockwave ring udara, semburan partikel garis angin CPUParticles3D unshaded, dan generator audio desau angin prosedural) sesuai Rule 5, 6, dan 7 AGENTS.md.
3. Hubungkan pemanggilan instansiasi `dash_wind_effect.tscn` di `Player.gd` saat fungsi `dash()` dipanggil, dan perbarui warna siluet ghost trail agar selaras dengan tema hembusan angin.

**Tech Stack:** Godot 4.6 (Forward+ / Compatibility), GDScript, CPUParticles3D, TorusMesh, AudioStreamWAV procedural synthesis.

**Spec:** Permintaan pengguna: "pintu door ya bukan door 1 atau dua tuh kebuka habis minum potion health aja gitu dan juga dash tuh ada efek angin gitu".

---

## Global Constraints

- **Rule 1 (Autoload vs Lokal):** Logika tutorial pintu tetap di `tutorial_controller.gd`, logika fisik dash di `Player.gd`.
- **Rule 2 (FUNCTIONS_REGISTRY.md):** Catat setiap fungsi dan variabel baru/berubah ke `FUNCTIONS_REGISTRY.md` dengan deskripsi objektif 1 kalimat.
- **Rule 4 (Auto-terminate tests):** Seluruh runner test headless wajib memanggil `quit(0/1)`.
- **Rule 5 (Scene & Prefab):** Efek angin wajib didefinisikan sebagai file Scene Prefab `res://dash_wind_effect.tscn`, bukan hardcode `.new()` di script.
- **Rule 6 (Performa & Caching):** Geometri primitif TorusMesh dibatasi segmen rendah (rings = 12), audio generator menggunakan `static var _cached_swoosh_stream`.
- **Rule 7 (Collision & Lifecycle):** Efek angin tidak memiliki collision (`collision_layer = 0`, `collision_mask = 0`), memiliki TTL self-destruct otomatis via `queue_free()`.

---

## Review Focus

1. **Pintu `door` tidak boleh terbuka saat racik:** Saat selesai crafting healing potion, status langkah berubah ke `USE_HEALING` namun `door` tetap tertutup rapat (`is_open == false`).
2. **Pintu `door` wajib terbuka setelah minum:** Begitu `GlobalLogic.consume_potion("healing")` dipanggil dan sinyal `potion_consumed` diterima, `door.open_door()` dipicu dan transisi ke `Step.COMBAT` berjalan mulus.
3. **Pintu lain tidak terpengaruh:** `door2` (pintu ruang slime) dan `door3` (segel potion) tetap mempertahankan mekanisme aslinya.
4. **Efek angin dash terarah sesuai orientasi:** Cincin shockwave dan partikel garis angin mengarah sejajar/berlawanan dengan vektor `dash_direction`.
5. **Tanpa kebocoran memori (Zero memory leak):** Instance `dash_wind_effect.tscn` otomatis membersihkan diri (`queue_free()`) dalam waktu < 0.5 detik.

---

### Task 1: Refactor Logika Pembukaan Pintu `door` pada `tutorial_controller.gd`

**Files:**
- Modify: `tutorial_controller.gd:343-375`
- Test: `test_door_open_sequence.gd`

**Interfaces:**
- Consumes: `GlobalLogic.potion_consumed(potion_name: String)`, `d1.open_door()`
- Produces: Pintu `door` terbuka hanya saat `Step.USE_HEALING` selesai diminum.

- [ ] **Step 1: Tulis automated test skenario urutan pintu**
Buat `test_door_open_sequence.gd` yang memuat `main.tscn`, mensimulasikan langkah `CRAFT_HEALING` dan memverifikasi `door.is_open == false`, lalu mensimulasikan minum potion dan memverifikasi `door.is_open == true`.

- [ ] **Step 2: Jalankan test untuk memverifikasi kondisi awal**
Jalankan `/opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --script res://test_door_open_sequence.gd`
Ekspektasi: FAIL pada tahap crafting karena saat ini `door` langsung terbuka saat selesai meracik.

- [ ] **Step 3: Edit `tutorial_controller.gd`**
- Hapus pemanggilan `d1.open_door()` dari `_advance_from_craft_healing()`.
- Tambahkan pemanggilan pembukaan pintu di `_on_potion_consumed(potion_name: String)`:
  ```gdscript
  if current_step == Step.USE_HEALING and not is_transitioning:
      if potion_name == "healing":
          is_transitioning = true
          _play_chime()
          _show_step_done("✓ Ramuan diminum")
          step_completed.emit(Step.USE_HEALING)

          var d1 := _get_door()
          if d1 and not d1.is_open:
              d1.open_door()

          await get_tree().create_timer(1.2).timeout
          start_step(Step.COMBAT)
  ```

- [ ] **Step 4: Jalankan test ulang dan verifikasi lulus**
Jalankan `/opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --script res://test_door_open_sequence.gd`
Ekspektasi: PASS.

- [ ] **Step 5: Bersihkan file test**
Hapus `test_door_open_sequence.gd`.

---

### Task 2: Pembuatan Prefab Efek Angin Dash (`dash_wind_effect.tscn` & `dash_wind_effect.gd`)

**Files:**
- Create: `dash_wind_effect.tscn`
- Create: `dash_wind_effect.gd`
- Test: `test_dash_wind_prefab.gd`

**Interfaces:**
- Consumes: `setup(dash_dir: Vector3)`
- Produces: Node3D mandiri dengan visual shockwave ring, CPUParticles3D wind streaks, dan audio desau angin sintetis dengan auto-cleanup.

- [ ] **Step 1: Tulis test verifikasi struktur prefab efek angin**
Buat `test_dash_wind_prefab.gd` untuk menginstansiasi `dash_wind_effect.tscn`, memanggil `setup(Vector3.FORWARD)`, memeriksa orientasi rotasi, pemutaran audio, emisi partikel, dan pelepasan memori otomatis.

- [ ] **Step 2: Jalankan test untuk memastikan test gagal (karena prefab belum ada)**
Jalankan `/opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --script res://test_dash_wind_prefab.gd`
Ekspektasi: FAIL (File not found).

- [ ] **Step 3: Implementasikan `dash_wind_effect.gd`**
- Definisikan `class_name DashWindEffect extends Node3D`.
- Implementasikan `_generate_wind_swoosh_sound() -> AudioStreamWAV` dengan caching statis `_cached_swoosh_stream`.
- Implementasikan `setup(dash_dir: Vector3) -> void` yang melakukan `look_at(global_position + dash_dir, Vector3.UP)`, memicu tween animasi ekspansi ring `(scale 0.2 -> 2.2, alpha 0.75 -> 0.0)`, mengaktifkan `wind_streaks.emitting = true`, memutar `wind_audio`, dan menjadwalkan `queue_free()` setelah 0.4 detik.

- [ ] **Step 4: Buat scene `dash_wind_effect.tscn`**
- Root: `DashWindEffect` (`Node3D`).
- Child 1: `WindRing` (`MeshInstance3D`) memakai `TorusMesh` (inner_radius 0.25, outer_radius 0.45, rings 12) dengan `StandardMaterial3D` unshaded transparan `Color(0.9, 0.96, 1.0, 0.75)`.
- Child 2: `WindStreaks` (`CPUParticles3D`) memakai `BoxMesh` ramping `(0.04, 0.04, 0.75)` unshaded `Color(0.92, 0.98, 1.0, 0.65)`, emit ke arah `-Z` (berlawanan dengan dash), spread 35 derajat, velocity 6-12 m/s, lifetime 0.28s.
- Child 3: `WindAudio` (`AudioStreamPlayer3D`) dengan `unit_size = 4.0`.

- [ ] **Step 5: Jalankan test verifikasi prefab**
Jalankan `/opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --script res://test_dash_wind_prefab.gd`
Ekspektasi: PASS.

- [ ] **Step 6: Bersihkan test**
Hapus `test_dash_wind_prefab.gd`.

---

### Task 3: Integrasi Efek Angin ke `Player.gd`

**Files:**
- Modify: `Player.gd:47-55`, `Player.gd:669-740`
- Test: `test_player_dash_wind.gd`

**Interfaces:**
- Consumes: `DASH_WIND_SCENE.instantiate()`, `dash_direction`
- Produces: Setiap kali tombol dash ditekan, efek angin instan dimunculkan di lokasi pemain, dan siluet jejak dash menggunakan nuansa angin yang serasi.

- [ ] **Step 1: Tulis test integrasi dash di Player**
Buat `test_player_dash_wind.gd` yang memanggil `player.dash()`, memastikan instance `DashWindEffect` tercipta di scene tree, posisinya selaras dengan pemain, dan ghost trail berwarna sejuk/angin.

- [ ] **Step 2: Jalankan test untuk memverifikasi kegagalan awal**
Jalankan `/opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --script res://test_player_dash_wind.gd`
Ekspektasi: FAIL (DashWindEffect belum di-spawn oleh Player).

- [ ] **Step 3: Modifikasi `Player.gd`**
- Tambahkan preload: `const DASH_WIND_SCENE: PackedScene = preload("res://dash_wind_effect.tscn")`.
- Sesuaikan warna default `dash_ghost_color` menjadi rona uap angin sejuk `Color(0.85, 0.95, 1.0, 0.45)`.
- Tambahkan helper method `_spawn_dash_wind_effect(dir: Vector3) -> void`.
- Panggil `_spawn_dash_wind_effect(dash_direction)` di dalam method `dash()`.

- [ ] **Step 4: Jalankan test integrasi ulang**
Jalankan `/opt/godot/Godot_v4.6-stable_linux.x86_64 --headless --script res://test_player_dash_wind.gd`
Ekspektasi: PASS.

- [ ] **Step 5: Bersihkan file test**
Hapus `test_player_dash_wind.gd`.

---

### Task 4: Sinkronisasi Registry & Verifikasi Gameplay Menyeluruh

**Files:**
- Modify: `FUNCTIONS_REGISTRY.md`
- Test: `test_full_gameplay_flow.gd`

- [ ] **Step 1: Perbarui dokumentasi di `FUNCTIONS_REGISTRY.md`**
- Perbarui entri `_advance_from_craft_healing` pada `tutorial_controller.gd`.
- Tambahkan entri section baru untuk `res://dash_wind_effect.gd`.
- Pastikan mematuhi Rule 2 (deskripsi fungsional ringkas 1 kalimat objektif, tanpa kata-kata instruksi chat).

- [ ] **Step 2: Jalankan pengujian gameplay penuh secara headless**
Jalankan script verifikasi skenario lengkap:
- Pemain spawn -> memungut slime gel -> meracik healing potion -> pintu `door` terverifikasi TETAP TERTUTUP.
- Pemain meminum healing potion -> pintu `door` terverifikasi TERBUKA dan beralih ke tugas kalahkan slime.
- Pemain melakukan dash -> efek angin `DashWindEffect` ter-spawn dengan audio dan partikel aktif.
- Pintu `door2` dan `door3` tetap bekerja sesuai perannya masing-masing.

- [ ] **Step 3: Pastikan tidak ada sisa background task aktif**
Periksa `manage_task: list` dan pastikan 0 proses menggantung.
