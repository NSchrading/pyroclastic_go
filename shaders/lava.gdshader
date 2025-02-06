shader_type canvas_item;

uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.0);
uniform vec3 ripple_color_deep : source_color = vec3(0.1, 0.0, 0.0);
uniform vec3 ripple_color_mid_lava : source_color = vec3(1.0, 0.5, 0.0);
uniform vec3 ripple_color_surface : source_color = vec3(1.0, 1.0, 0.0);
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float glow_radius : hint_range(0.0, 1.0) = 0.5;
uniform float ripple_scale : hint_range(0.1, 10.0) = 2.0; // Scale for the main noise pattern
uniform float ripple_speed : hint_range(0.0, 5.0) = 0.5; // Overall animation speed

uniform sampler2D noise_texture : hint_default_white; // Assign seamless noise texture here

// Distortion Parameters
uniform float distort_scale : hint_range(0.1, 5.0) = 0.5;     // Scale for distortion noise lookup
uniform float distort_strength : hint_range(0.0, 0.5) = 0.05; // How much UVs are offset by noise


// --- Fragment Shader ---
void fragment() {
	// Center UVs for glow calculation
	vec2 centered_uv = UV - vec2(0.5, 0.5);
	// Basic time variable, scaled by ripple_speed
	float time = TIME * ripple_speed;

	vec2 distorted_uv = UV;
	vec2 distort_noise_uv_base = UV * distort_scale;

	// Use fract() for tiling.
	vec2 offset1_uv = fract(distort_noise_uv_base + vec2(time * 0.3, 10.0));
	vec2 offset2_uv = fract(distort_noise_uv_base + vec2(25.0, time * 0.5));
	// Sample texture, map [0, 1] result to [-1, 1] range for distortion offset
	vec2 uv_offset = vec2(
		texture(noise_texture, offset1_uv).r * 2.0 - 1.0,
		texture(noise_texture, offset2_uv).r * 2.0 - 1.0
	);
	// Apply the offset scaled by strength
	distorted_uv = UV + uv_offset * distort_strength;

	// 2. Central Glow Effect
	float dist_from_center = length(centered_uv);
	float glow_mask = smoothstep(glow_radius, 0.0, dist_from_center); // Fades out from center
	vec3 glow = glow_color * glow_intensity * glow_mask;

	// 3. Simplified Ripple Effect
	vec2 ripple_uv = fract(distorted_uv * ripple_scale + vec2(time * 0.1)); // Apply scale and simple time scroll
	// Directly sample the noise texture. Result is [0, 1] (assuming grayscale)
	float ripple_noise_01 = texture(noise_texture, ripple_uv).r;

	// 4. Color Mapping for Ripples
	// Use the [0, 1] noise value directly
	vec3 ripple_lava_color = ripple_color_deep;
	ripple_lava_color = mix(ripple_lava_color, ripple_color_mid_lava, smoothstep(0.3, 0.7, ripple_noise_01));
	ripple_lava_color = mix(ripple_lava_color, ripple_color_surface, smoothstep(0.7, 0.9, ripple_noise_01));

	// 5. Combine Glow and Ripples
	vec3 final_color = ripple_lava_color + glow;

	// Clamp final color
	final_color = clamp(final_color, vec3(0.0), vec3(1.0));

	// Output
	COLOR.rgb = final_color;
	COLOR.a = 0.8;
}
