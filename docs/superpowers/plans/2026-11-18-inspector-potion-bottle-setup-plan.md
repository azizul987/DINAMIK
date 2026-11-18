# Rencana Implementasi: Pengaturan Model Botol Ramuan via Inspector (`botol_model.tscn`)

Dokumen ini merinci rencana teknis untuk mengintegrasikan model botol ramuan buatan user [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn) sebagai nilai bawaan (*default*) pada slot **Inspector** dan menempatkannya langsung di **Scene Tree Dock**, sehingga developer dapat melihat botol di tangan karakter pada 3D Viewport editor Godot, mengatur posisi/rotasi/skala visual secara interaktif, atau mengganti prefab kapan saja dari Inspector.

---

## 1. Latar Belakang & Analisis Permintaan User

1. **Nama Scene Model**: Pengguna mengonfirmasi bahwa scene model yang digunakan adalah [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn) (yang menginstansiasi `botol.fbx` dengan mesh `LabuBawah_001`).
2. **Nilai Default Slot**: Pengguna meminta agar [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn) langsung dijadikan **nilai default** untuk slot Inspector pada karakter (`Player.gd`).
3. **Penyelarasan Scene & WYSIWYG**: Node botol dipasang langsung di bawah tulang tangan kiri (`handslot.l`) di dalam scene [main.tscn](file:///home/g/dinamik/main.tscn) dan [safe_room.tscn](file:///home/g/dinamik/safe_room.tscn), dan slot Inspector `potion_bottle` pada node `Players` langsung terhubung secara default ke node tersebut.

---

## 2. User Review Required

> [!IMPORTANT]
> **Skrip Pengontrol Warna Cairan pada `botol_model.tscn`**:
> Agar cairan botol tetap dapat berubah warna secara dinamis (Hijau Zamrud, Jingga, Biru Es, Merah Berserk, Perak Putih) saat meminum ramuan yang berbeda, skrip [potion_bottle.gd](file:///home/g/dinamik/resources/bottle/potion_bottle.gd) akan dikaitkan ke root node `Botol` pada [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn). Skrip disempurnakan agar otomatis mendeteksi mesh `LabuBawah_001` bawaan `botol.fbx`.

---

## 3. Rencana Perubahan Komponen

### Component 1: Pengontrol Botol Ramuan (`res://resources/bottle/potion_bottle.gd` & `botol_model.tscn`)

#### [MODIFY] [potion_bottle.gd](file:///home/g/dinamik/resources/bottle/potion_bottle.gd)
- Sempurnakan fungsi `_get_bottle_mesh()` agar secara rekursif mencari mesh `LabuBawah_001` (dari `botol_model.tscn`) atau `BottleMesh`, sehingga Surface 0 (`Kaca_Labu`) dapat ditimpa warnanya secara dinamis saat minum ramuan.

#### [MODIFY] [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn)
- Tautkan skrip `res://resources/bottle/potion_bottle.gd` pada root node `Botol`.

---

### Component 2: Player Controller (`res://Player.gd`)

#### [MODIFY] [Player.gd](file:///home/g/dinamik/Player.gd)
1. **Definisikan Slot Export dengan Default `botol_model.tscn`**:
   ```gdscript
   @export_group("Equipped Bottle")
   @export var potion_bottle: Node3D = null ## Node botol yang terpasang di tangan karakter (terhubung otomatis ke Botol di scene)
   @export var potion_bottle_scene: PackedScene = preload("res://resources/bottle/botol_model.tscn") ## Prefab botol ramuan default
   @export var bottle_scale: Vector3 = Vector3(0.9, 0.9, 0.9)
   @export var bottle_rotation_degrees: Vector3 = Vector3(-10.0, 75.0, -90.0)
   @export var bottle_position_offset: Vector3 = Vector3(0.02, 0.04, -0.01)
   @export var drink_speed_multiplier: float = 0.5
   ```
2. **Pembaruan Logika Inisialisasi (`_setup_bottle_attachment`)**:
   - Jika `potion_bottle` telah diisi via Inspector (default di scene), gunakan node tersebut.
   - Jika belum terisi, cari node `Botol` atau `PotionBottle` di Scene Tree di bawah `LeftHandAttachment`.
   - Jika belum ada di Scene Tree, instansiasi secara dinamis dari `potion_bottle_scene` sebagai fallback.
   - Di `_ready()`, pastikan botol tersembunyi saat runtime eksplorasi (`visible = false`), dan hanya muncul saat animasi `drink` diputar.

---

### Component 3: Scene Hierarchy (`res://main.tscn` & `res://safe_room.tscn`)

#### [MODIFY] [main.tscn](file:///home/g/dinamik/main.tscn) & [safe_room.tscn](file:///home/g/dinamik/safe_room.tscn)
Tambahkan sub-node `LeftHandAttachment` (`BoneAttachment3D`) ke `Skeleton3D` dan pasang instance [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn) di dalamnya:
```tscn
[node name="LeftHandAttachment" type="BoneAttachment3D" parent="Players/Ranger/Rig_Medium/Skeleton3D"]
bone_name = "handslot.l"
bone_idx = 22

[node name="Botol" parent="Players/Ranger/Rig_Medium/Skeleton3D/LeftHandAttachment" instance=ExtResource("botol_model_res")]
transform = Transform3D(0.9, 0, 0, 0, 0.9, 0, 0, 0, 0.9, 0.02, 0.04, -0.01)
rotation_degrees = Vector3(-10, 75, -90)
```
Dan hubungkan slot `potion_bottle` pada node `Players` ke node `Botol` tersebut:
```tscn
potion_bottle = NodePath("Ranger/Rig_Medium/Skeleton3D/LeftHandAttachment/Botol")
```

---

### Component 4: Dokumentasi Registry (`res://FUNCTIONS_REGISTRY.md`)

#### [MODIFY] [FUNCTIONS_REGISTRY.md](file:///home/g/dinamik/FUNCTIONS_REGISTRY.md)
Perbarui daftar variabel penting pada Seksi 2 (`Player.gd`) dan Seksi 27 untuk mencatat `potion_bottle`, `potion_bottle_scene` dengan nilai bawaan `botol_model.tscn`.

---

## 4. Rencana Verifikasi

### Automated Headless Test
1. Buat skrip runner pengujian headless `test_botol_model_runner.tscn`:
   - Memvalidasi bahwa properti `@export var potion_bottle` pada node `Players` di `main.tscn` terisi mengarah ke instance [botol_model.tscn](file:///home/g/dinamik/resources/bottle/botol_model.tscn).
   - Memvalidasi bahwa `LeftHandAttachment` terpasang di tulang `handslot.l` (indeks 22).
   - Menguji eksekusi `consume_potion`: botol muncul, warna cairan berubah sesuai ramuan, dan botol kembali disembunyikan setelah 1.6 detik.
   - Memastikan auto-terminate dengan `quit(0)`.
2. Jalankan runner via CLI:
   ```bash
   /opt/godot/Godot_v4.6-stable_linux.x86_64 --path /home/g/dinamik res://test_botol_model_runner.tscn --headless
   ```

### Manual Verification
1. Buka `main.tscn` di editor Godot.
2. Di Scene Dock, periksa node `Players -> Ranger -> Rig_Medium -> Skeleton3D -> LeftHandAttachment -> Botol`.
3. Di 3D Viewport, botol tampak di tangan karakter dalam editor.
4. Di panel Inspector node `Players`, periksa slot **Equipped Bottle**:
   - `Potion Bottle`: terisi `LeftHandAttachment/Botol` secara default.
   - `Potion Bottle Scene`: terisi `res://resources/bottle/botol_model.tscn` secara default.
