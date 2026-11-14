shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Instance uniforms (ditetapkan per-musuh di level GPU)
instance uniform vec4 slime_color : source_color = vec4(0.2, 0.88, 0.35, 1.0);
instance uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
instance uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float emission_multiplier : hint_range(0.0, 5.0) = 0.5;

void fragment() {
	vec3 base_col = slime_color.rgb;
	// Mix base albedo dengan warna flash
	ALBEDO = mix(base_col, flash_color.rgb, hit_flash);
	ROUGHNESS = roughness;

	// Slime emission glow + kilatan terang saat terkena hit
	vec3 normal_emission = base_col * 0.7 * emission_multiplier;
	vec3 flash_emission = flash_color.rgb * 1.5;
	EMISSION = mix(normal_emission, flash_emission, hit_flash);
}
