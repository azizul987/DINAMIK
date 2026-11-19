shader_type spatial;
render_mode blend_add, unshaded;

// Glow tipis menyeluruh: tekstur & bentuk model tetap terlihat,
// hanya diberi pendar warna lembut yang berdenyut.
instance uniform vec4 glow_color : source_color = vec4(0.85, 0.35, 0.12, 1.0);
instance uniform float glow_intensity : hint_range(0.0, 1.0) = 0.28;
instance uniform float glow_pulse : hint_range(0.0, 1.5) = 0.25;

// Hit flash — kilatan terang saat terkena damage.
instance uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// Denyut halus seperti napas monster
	float breath = 1.0 + sin(TIME * 2.8) * glow_pulse * 0.35;
	float body_alpha = clamp(glow_intensity * breath, 0.0, 1.0);
	float combined_alpha = clamp(max(body_alpha, hit_flash * 0.85), 0.0, 1.0);

	ALBEDO = mix(glow_color.rgb, flash_color.rgb, hit_flash);
	ALPHA = combined_alpha;
}
