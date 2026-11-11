shader_type canvas_item;

uniform float toxicity_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed : hint_range(0.5, 12.0) = 4.5;
uniform vec4 vein_color : source_color = vec4(0.12, 0.95, 0.35, 1.0);
uniform vec4 miasma_color : source_color = vec4(0.48, 0.04, 0.68, 1.0);

void fragment() {
	if (toxicity_ratio <= 0.70) {
		COLOR = vec4(0.0);
	} else {
		float factor = clamp((toxicity_ratio - 0.70) / 0.30, 0.0, 1.0);

		// Screen center and aspect ratio correction
		vec2 center = UV - vec2(0.5);
		center.x *= 1.7778; // 16:9 aspect compensation

		float r = length(center);
		float angle = atan(center.y, center.x);

		// Organic branching veins using polar sinusoidal noise
		float speed = pulse_speed + factor * 6.0;
		float n1 = sin(angle * 14.0 + sin(r * 26.0 - TIME * (speed * 0.7)));
		float n2 = cos(angle * 9.0 + cos(r * 16.0 + TIME * (speed * 1.1)));
		float branch = smoothstep(0.42, 0.92, (n1 * 0.5 + n2 * 0.5 + 0.5));

		// Creep inwards as factor increases: threshold moves from 0.58 down to 0.28
		float threshold = mix(0.58, 0.26, factor);
		float vignette = smoothstep(threshold, 0.72, r);

		// Throbbing heartbeat pulse
		float pulse = 0.82 + 0.18 * sin(TIME * speed);

		float vein_alpha = branch * vignette * pulse * factor;
		float edge_glow = pow(vignette, 2.2) * 0.45 * pulse * factor;

		vec3 col = mix(miasma_color.rgb, vein_color.rgb, branch);
		float final_alpha = clamp(vein_alpha + edge_glow, 0.0, 0.88);

		COLOR = vec4(col, final_alpha);
	}
}
