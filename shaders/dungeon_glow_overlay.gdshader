shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

// Glow properties — dikontrol per-instance agar tiap monster bisa punya warna glow beda
instance uniform vec4 glow_color : source_color = vec4(0.85, 0.35, 0.12, 1.0);
instance uniform float glow_intensity : hint_range(0.0, 3.0) = 0.55;
instance uniform float glow_pulse : hint_range(0.0, 1.5) = 0.25;

// Hit flash — overlay terang saat kena damage
instance uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// Denyut halus seperti napas monster
	float breath = 1.0 + sin(TIME * 2.8) * glow_pulse * 0.35;
	float base_alpha = glow_intensity * breath;

	// Hit flash menimpa glow dengan alpha lebih tinggi
	float combined_alpha = max(base_alpha, hit_flash * 0.85);
	vec3 col = mix(glow_color.rgb, flash_color.rgb, hit_flash);

	ALBEDO = col;
	// blend_add: alpha mengontrol seberapa banyak warna ditambahkan
	ALPHA = combined_alpha;
}