shader_type canvas_item;
render_mode blend_mix;

// Appearance
uniform vec4 base_color: source_color = vec4(1.0, 1.0, 1.0, 1.0); // Color tint for the base sprite texture
uniform vec4 glow_color: source_color = vec4(0.7, 0.85, 1.0, 0.15); // Color and MAX alpha for the glow effect
uniform float alpha_threshold: hint_range(0.0, 1.0) = 0.4; // Noise cutoff for cloud visibility (higher = less cloud)
uniform float alpha_smoothness: hint_range(0.01, 0.5) = 0.1; // Softness of the cloud edges

// Noise Texture Control
uniform sampler2D noise_texture: hint_default_white;
uniform float noise_scale: hint_range(0.1, 10.0) = 1.5; // Tiling/zoom factor for the main noise pattern
uniform vec2 noise_scroll_speed = vec2(0.01, -0.04); // Speed/direction of the noise pattern's internal scroll

// Overall Movement
uniform float wind_speed: hint_range(-0.5, 0.5) = 0.03; // Horizontal drift speed of the entire effect

// Distortion
uniform float distort_noise_scale: hint_range(1.0, 15.0) = 4.0; // Tiling/zoom factor for distortion noise samples
uniform float distort_speed: hint_range(0.0, 0.5) = 0.02; // Animation speed of the distortion effect
uniform float distort_strength: hint_range(0.0, 0.05) = 0.01; // Maximum UV offset caused by distortion


void fragment() {
	// Base UV coordinates from the Sprite2D node [0, 1]
	vec2 base_uv = UV;

	float main_time = TIME;
	float distort_time_scaled = main_time * distort_speed;

	// 1. Calculate UV coordinates for the main noise lookup (used for cloud alpha and glow)
	// This incorporates scaling, internal scrolling, and overall wind drift.
	vec2 noise_lookup_uv = base_uv * noise_scale;
	noise_lookup_uv += main_time * noise_scroll_speed; // Apply internal scroll
	noise_lookup_uv.x += main_time * wind_speed * noise_scale; // Apply wind drift (scaled for consistency)
	noise_lookup_uv = fract(noise_lookup_uv); // Ensure seamless tiling by wrapping UVs

	// 2. Calculate Distortion Offset
	vec2 distortion_offset = vec2(0.0); // Initialize offset to zero

	// Sample noise texture twice at different locations/times for x and y offsets
	// Use different scales and time offsets for a more varied distortion pattern
	vec2 warp_uv1 = fract(base_uv * distort_noise_scale + vec2(13.4, 5.6) + distort_time_scaled * vec2(1.1, 0.9));
	vec2 warp_uv2 = fract(base_uv * distort_noise_scale + vec2(-7.2, -18.3) - distort_time_scaled * vec2(0.8, 1.2));

	// Sample the noise texture (assuming grayscale, use .r channel)
	// Map the texture value [0, 1] to an offset range of [-1, 1]
	distortion_offset = vec2(
		texture(noise_texture, warp_uv1).r * 2.0 - 1.0,
		texture(noise_texture, warp_uv2).r * 2.0 - 1.0
	);
	// Apply the user-controlled strength to the calculated offset
	distortion_offset *= distort_strength;

	// 3. Calculate final UV for sampling the base sprite texture (apply distortion)
	vec2 final_sprite_uv = base_uv + distortion_offset;

	// Use the non-distorted, scrolled/scaled noise_lookup_uv. Result is [0, 1].
	float noise_value_01 = texture(noise_texture, noise_lookup_uv).r;
	// Use the potentially distorted final_sprite_uv.
	vec4 sprite_color = texture(TEXTURE, final_sprite_uv);

	// This creates the wispy cloud shape using the noise pattern.
	float cloud_alpha = smoothstep(alpha_threshold - alpha_smoothness,
								   alpha_threshold + alpha_smoothness,
								   noise_value_01);

	// Modulate the calculated cloud shape alpha by the base sprite's alpha (acts as a mask)
	// and also by the alpha component of the base_color uniform (allows fading the whole effect).
	float final_alpha = cloud_alpha * sprite_color.a * base_color.a;

	// Tint the base sprite's color by the base_color uniform's RGB components.
	vec3 base_final_rgb = sprite_color.rgb * base_color.rgb;

	// The glow is brighter where the noise value is higher (closer to 1.0).
	// Use the alpha component of glow_color as a maximum intensity factor for the glow.
	float glow_factor = smoothstep(0.6, 0.9, noise_value_01) * glow_color.a;
	// Mix the glow color onto the base color using the calculated glow_factor.
	vec3 final_rgb_with_glow = mix(base_final_rgb, glow_color.rgb, glow_factor);

	// Output the final calculated color and alpha
	COLOR = vec4(final_rgb_with_glow, final_alpha);
}
