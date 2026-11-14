shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;

// Instance uniforms untuk efek kilat hit terbagi
instance uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	if (hit_flash <= 0.001) {
		discard;
	}
	ALBEDO = flash_color.rgb;
	ALPHA = hit_flash * flash_color.a;
}
