# Destructible Props Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengeliminasi lag dan drop frame rate setelah penambahan fitur objek hancur (peti dan kotak kayu) dengan membersihkan hierarki fisik bertumpuk (nested RigidBody3D dan multiple StaticBody3D) serta mengoptimalkan layer fisika ke 60 FPS stabil.

**Architecture:** Memisahkan representasi visual (`MeshInstance3D`) dari node fisik (`StaticBody3D` murni dengan single `BoxShape3D`), menghilangkan tumpukan `RigidBody3D` dan `ConvexPolygonShape3D` yang saling bertubrukan internal setiap frame tick, dan menerapkan `collision_mask = 0` pada objek statis agar physics server Godot 4 tidak menghabiskan siklus CPU untuk pemindaian kontak yang tidak perlu.

**Tech Stack:** Godot 4.6 Stable (Linux x86_64), GDScript, Godot PhysicsServer3D, Forward+ Clustered Renderer.

**Spec:** Sesuai permintaan pengguna mengenai performa berat ("game jadi berat jir") dan aturan anti-lag `AGENTS.md` (Aturan 6 & 7).

---

## Global Constraints

- Wajib menaati aturan `AGENTS.md` (Rule 6 anti-lag, Rule 7 physics layers & cleanup, Rule 5 prefab architecture).
- Dilarang hardcode node di script jika dapat didefinisikan secara rapi di prefab `.tscn`.
- Seluruh variabel dan fungsi baru wajib menggunakan static typing eksplisit dan dicatat di `FUNCTIONS_REGISTRY.md`.
- Gameplay flow tetap terjaga 100%: tebasan pedang menghancurkan peti & box, peti menjatuhkan Goblin Ear untuk resep Berserk Potion, dan tutorial berlanjut dengan mulus.

---

## Review Focus

1. **Nested Physics Body Removal:** Memastikan tidak ada lagi `RigidBody3D` yang bersarang di dalam `destructible_box.tscn` atau `main.tscn`.
2. **Convex Shape Elimination:** Mengganti seluruh `ConvexPolygonShape3D` (puluhan vertices) pada prop statis dengan satu `BoxShape3D` primitif hemat komputasi.
3. **Collision Mask Zeroing:** Memastikan `collision_mask = 0` pada seluruh static prop agar Godot tidak melakukan raycast/collision scanning pasif per-frame.
4. **Hitbox Interaction Integrity:** Memastikan hitbox pedang pemain (`Hitbox` Area3D) tetap dapat mendeteksi dan menghancurkan prop dengan lancar.
5. **Item Drop & Progression Continuity:** Memastikan drop `goblin_ear` dan `slime_gel` tetap keluar pada posisi yang tepat dan tutorial "Hancurkan Peti" -> "Racik Berserk Potion" tetap berjalan tanpa hambatan.

---

### Task 1: Rekonstruksi Bersih Prefab `destructible_box.tscn`

**Files:**
- Modify: `destructible_box.tscn`

**Interfaces:**
- Consumes: `res://destructible_prop.gd`, `res://DungeonTiles/material/PropSet_1_Mat.tres`, mesh box dari asset pack
- Produces: Prefab `destructible_box.tscn` ringan tanpa nested `RigidBody3D` atau convex collision

- [ ] **Step 1: Ekstrak definisi mesh box murni (`ArrayMesh`) ke sub-resource atau file resource**
Hilangkan child `VisualRoot` yang meng-instance `prop_set_1_box.tscn`. Gantikan dengan `MeshInstance3D` langsung yang menggunakan mesh kotak kayu dan material `PropSet_1_Mat.tres`.

- [ ] **Step 2: Konfigurasi collision layer & mask pada `destructible_box.tscn`**
Set `collision_layer = 1` (World/Props), `collision_mask = 0` (tidak memindai tabrakan eksternal), dengan single `BoxShape3D` berukuran `Vector3(1.1, 1.1, 1.1)`.

- [ ] **Step 3: Uji struktur node `destructible_box.tscn` via script headless**
Verifikasi bahwa tidak ada child bertipe `RigidBody3D` di dalam `destructible_box.tscn`.

---

### Task 2: Rekonstruksi Bersih Prefab `destructible_chest.tscn`

**Files:**
- Modify: `destructible_chest.tscn`

**Interfaces:**
- Consumes: `res://destructible_prop.gd`, `res://DungeonTiles/material/PropSet_1_Mat.tres`, mesh chest base & lid
- Produces: Prefab `destructible_chest.tscn` ringan tanpa duplicate `StaticBody3D` atau convex collision

- [ ] **Step 1: Hilangkan nested `StaticBody3D` dan 3 `ConvexPolygonShape3D` dari visual chest**
Ganti child `VisualRoot` instanced scene dengan hierarki visual murni:
  - `VisualRoot` (`Node3D`)
    - `BaseMesh` (`MeshInstance3D`): mesh badan peti
    - `LidMesh` (`MeshInstance3D`): mesh tutup peti dengan offset elevasi `0.722562`
Keduanya memakai material `PropSet_1_Mat.tres` tanpa ada node `StaticBody3D` atau `CollisionShape3D` di dalamnya.

- [ ] **Step 2: Konfigurasi collision layer & mask pada `destructible_chest.tscn`**
Set `collision_layer = 1`, `collision_mask = 0` pada root `DestructibleChest`, dengan single `BoxShape3D` berukuran `Vector3(1.5, 0.95, 0.9)` pada ketinggian `y = 0.475`.

- [ ] **Step 3: Uji struktur node `destructible_chest.tscn` via script headless**
Verifikasi bahwa hanya ada tepat 1 `StaticBody3D` dan 0 `ConvexPolygonShape3D` di dalam seluruh pohon node chest.

---

### Task 3: Optimasi Kode & Audio Caching pada `destructible_prop.gd`

**Files:**
- Modify: `destructible_prop.gd`

**Interfaces:**
- Consumes: `GlobalLogic`, `AudioStreamWAV`
- Produces: Evaluasi damage cepat dan zero-allocation pada runtime statis

- [ ] **Step 1: Optimasi inisialisasi collision dan visibilitas di `_ready()`**
Pastikan `collision_mask = 0` ditegakkan di script jika belum diatur di inspector. Pastikan `set_process(false)` dan `set_physics_process(false)` aktif karena static prop tidak memerlukan update per-frame.

- [ ] **Step 2: Optimasi audio setup & lazy streaming**
Pastikan generator audio buffer PCM `_generate_wood_hit_sound()` hanya berjalan satu kali saja secara statis di memori game.

- [ ] **Step 3: Uji unit test interaksi serangan pada `destructible_prop.gd`**
Jalankan script test headless untuk memvalidasi `take_damage()`, sinyal `prop_destroyed`, dan kemunculan drop item.

---

### Task 4: Verifikasi Menyeluruh di `main.tscn` & Benchmark Performa

**Files:**
- Verify: `main.tscn`, `Player.gd`, `tutorial_controller.gd`
- Update: `FUNCTIONS_REGISTRY.md`
- Update: `walkthrough.md`

**Interfaces:**
- Consumes: Full gameplay loop di `main.tscn`
- Produces: Laporan verifikasi 60 FPS bebas lag dan konfirmasi fungsionalitas

- [ ] **Step 1: Jalankan runner profiling `main.tscn`**
Periksa jumlah total `RigidBody3D` (harus berkurang drastis dari 17 menjadi hanya dekorasi dungeon statis tanpa ada body yang tersangkut di dalam static body), dan total `CollisionShape3D` pada props hancur.

- [ ] **Step 2: Jalankan simulasi serangan pedang pemain ke Chest dan Box**
Pastikan pedang pemain (`Hitbox`) tetap dapat memukul Chest dan Box, audio kayu berbunyi, partikel serpihan muncul, dan Goblin Ear terlempar keluar.

- [ ] **Step 3: Jalankan verifikasi alur tutorial**
Pastikan tutorial step "Hancurkan Peti" otomatis beralih menjadi "Racik Berserk Potion" saat Goblin Ear diambil oleh pemain.

- [ ] **Step 4: Update `FUNCTIONS_REGISTRY.md` & `walkthrough.md`**
Catat optimasi yang telah diterapkan dan sertakan perbandingan performa.

---
