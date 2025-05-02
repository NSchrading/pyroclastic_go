shader_type canvas_item;

// Textures & Mapping
uniform sampler2D Skin: source_color; // Skin Texture
uniform vec2 SkinDimension = vec2(1.0, 1.0); // Skin lookup texture dimensions
uniform sampler2D burn_noise: hint_default_white; // Noise for burn effect

// Burn Progress & Shape
uniform float burn_progress: hint_range(0.0, 1.0) = 0.0; // Main burn progress (0=none, 1=fully burnt)
uniform float fire_thickness: hint_range(0.001, 0.2) = 0.05; // Thickness of the fire band
uniform float char_thickness: hint_range(0.001, 0.2) = 0.1; // Thickness of the char band

// Colors
uniform vec4 fire_color: source_color = vec4(1.0, 0.5, 0.0, 1.0); // Base fire color
uniform vec4 brighter_fire_color: source_color = vec4(1.0, 0.8, 0.0, 1.0); // Brighter flickers
uniform vec4 char_color: source_color = vec4(0.1, 0.1, 0.1, 1.0); // Base char color
uniform vec4 cloak_color : source_color = vec4(0.682, 0.149, 0.11, 1.0);

// Noise & Distortion Control
uniform float noise_scale: hint_range(0.1, 10.0) = 1.0; // Scale for noise lookups
uniform float noise_speed: hint_range(0.0, 2.0) = 0.5; // Animation speed for noise
uniform float distortion_strength: hint_range(0.0, 0.1) = 0.05; // Main burn edge distortion
uniform float bottom_distortion_strength: hint_range(0.0, 0.1) = 0.02; // Distortion for the bottom start edge
uniform float fire_intensity_multiplier: hint_range(0.0, 1.0) = 0.5; // How much brighter_fire_color mixes in
uniform float char_noise_intensity: hint_range(0.0, 0.5) = 0.3; // How much char color varies

// Final Alpha Adjustment
uniform float alpha_modification: hint_range(0.0, 1.0) = 0.0; // Additive alpha modifier at the end


// --- Fragment Shader ---
void fragment()
{
	// Sample the UV map texture
	vec4 map = texture(TEXTURE, UV);
	// Convert map RG values [0,1] to UV coordinates for the Skin texture
	vec2 scaledUV = (map.rg * 255.0 + 0.5) / SkinDimension;

	// cloak color pixels are at 7x1 and 7x2 in skin map.
	float x_offset = (7.5 / SkinDimension.x);
	float y_offset_color_1 = (1.5 / SkinDimension.y);
	float y_offset_color_2 = (2.5 / SkinDimension.y);
	vec4 original_color;
	if (abs(scaledUV.r - x_offset) < 0.001 && abs(scaledUV.g - y_offset_color_1) < 0.001) {
		original_color = cloak_color;
	}
	else if (abs(scaledUV.r - x_offset) < 0.001 && abs(scaledUV.g - y_offset_color_2) < 0.001) {
		original_color = cloak_color * 0.4;
	}
	else {
		original_color = texture(Skin, scaledUV);
	}

	// Use the alpha from the UV map texture as the base mask for the final output
	// This allows parts of the sprite using this shader to be inherently transparent.
	float base_mask_alpha = map.a;

	// Calculate a scaled time value once for use in noise lookups
	float time_scaled = TIME * noise_speed;

	// Calculate all required noise values upfront to avoid lookups inside logic/branches.
	// Noise for main burn height distortion
	float main_noise = texture(burn_noise, fract(UV * noise_scale + vec2(0.0, time_scaled))).r;
	// Noise for top edge dissolving effect
	float top_noise = texture(burn_noise, fract(UV * noise_scale + vec2(0.2, time_scaled * 0.5))).r;
	// Noise for bottom edge start variation
	float bottom_noise = texture(burn_noise, fract(UV * noise_scale * 0.5 + vec2(-0.1, time_scaled * 0.7) + 0.5)).r;
	// Noise for fire color intensity variation
	float fire_intensity_noise = texture(burn_noise, fract(UV * noise_scale * 2.0 + vec2(0.5, time_scaled * 1.2))).r;
	// Noise for char color variation
	float char_noise = texture(burn_noise, fract(UV * noise_scale * 1.5 + vec2(time_scaled * 0.8, 0.0))).r;


	// --- 3. Calculate Dynamic Burn Heights/Edges ---
	// Base burn line progresses from Y=1.0 (bottom) to Y=0.0 (top) as burn_progress goes from 0 to 1
	float base_burn_height = 1.0 - burn_progress;
	// Apply noise distortion to the main burn line
	float distorted_burn_height = base_burn_height + (main_noise * 2.0 - 1.0) * distortion_strength; // Map noise [0,1] to [-1,1] for distortion
	// Clamp the distorted height to prevent it going below 0 or above 1
	distorted_burn_height = clamp(distorted_burn_height, 0.0, 1.0);
	// Apply noise distortion to the bottom starting line
	float distorted_bottom_start = (bottom_noise * 2.0 - 1.0) * bottom_distortion_strength;
	// Clamp bottom start as well
	distorted_bottom_start = clamp(distorted_bottom_start, 0.0, 1.0);
	// Calculate the Y coordinates where fire ends and char begins
	float fire_end_height = distorted_burn_height + fire_thickness;
	// Calculate the Y coordinate where char ends
	float char_end_height = fire_end_height + char_thickness;
	// Calculate the Y coordinate where the top edge starts dissolving based on noise
	float dissolve_start_height = char_end_height;

	// Modulate fire color based on intensity noise
	vec3 modulated_fire_rgb = mix(fire_color.rgb, brighter_fire_color.rgb, fire_intensity_noise * fire_intensity_multiplier);
	// Modulate char color based on char noise (make it slightly brighter/varied)
	vec3 varied_char_rgb = mix(char_color.rgb, char_color.rgb * 1.2, char_noise * char_noise_intensity);

	// These factors go from 0.0 to 1.0 as UV.y crosses the respective boundaries.
	// Factor for blending from original to fire (starts at distorted_burn_height, ends at fire_end_height)
	float fire_blend = smoothstep(distorted_burn_height, fire_end_height, UV.y);
	// Factor for blending from the fire result to the char result (starts at fire_end_height, ends at char_end_height)
	float char_blend = smoothstep(fire_end_height, char_end_height, UV.y);
	// Factor for dissolving alpha above the char layer (starts at char_end_height, ends at dissolve_start_height)
	float dissolve_blend = smoothstep(char_end_height, dissolve_start_height, UV.y);
	// Factor for cutting off below the bottom burn start (starts slightly before, ends at distorted_bottom_start)
	float bottom_cutoff_blend = smoothstep(distorted_bottom_start - 0.01, distorted_bottom_start, UV.y); // Small overlap for smoothing

	// Mix between the calculated fire color and char color based on char_blend
	vec3 fire_char_mix = mix(modulated_fire_rgb, varied_char_rgb, char_blend);
	// Mix between the original skin color and the fire/char result based on fire_blend
	vec3 final_rgb = mix(original_color.rgb, fire_char_mix, fire_blend);

	// Start with the alpha from the original UV map texture (base mask)
	float final_alpha = base_mask_alpha;
	// Fade alpha out during the char phase (controlled by char_blend)
	final_alpha = mix(final_alpha, 0.0, char_blend);
	// Ensure alpha fades out completely during the dissolve phase
	final_alpha = mix(final_alpha, 0.0, dissolve_blend);

	// Apply the bottom cutoff (make transparent below the starting line)
	final_alpha *= bottom_cutoff_blend;
	// If burn is fully complete, force transparency
	// Mix towards 0 alpha based on burn_progress being exactly 1.0
	final_alpha = mix(final_alpha, 0.0, step(1.0, burn_progress));

	// Apply final uniform modification (additive/subtractive)
	final_alpha = final_alpha - alpha_modification;
	// Ensure alpha stays within valid range [0, 1]
	final_alpha = clamp(final_alpha, 0.0, 1.0);

	COLOR = vec4(final_rgb, final_alpha);
}
