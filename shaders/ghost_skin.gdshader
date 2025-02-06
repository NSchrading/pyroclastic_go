shader_type canvas_item;

uniform sampler2D Skin; // assign skin sprite in inspector
uniform vec2 SkinDimension;  // assign length and width of skin sprite in editor
uniform vec3 cloak_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float ghost_alpha = 0.5;

void fragment()
{
	// pixel mapping from UV skin map
	vec4 map = texture(TEXTURE, UV);  // collect RGBA of pixel from sprite texture
	vec2 scaledUV = (map.rg * 255.0 + 0.5) / SkinDimension;  // scale the UV to the SkinDimension x SkinDimension "skin" sprite
	
	// cloak color pixels are at 7x1 and 7x2 in skin map.
	float x_offset = (7.5 / SkinDimension.x);
	float y_offset_color_1 = (1.5 / SkinDimension.y);
	float y_offset_color_2 = (2.5 / SkinDimension.y);

	if (abs(scaledUV.r - x_offset) < 0.001 && abs(scaledUV.g - y_offset_color_1) < 0.001) {
		COLOR.rgb = cloak_color;
		COLOR.a = map.a - ghost_alpha; // set ghost transparency
	}
	else if (abs(scaledUV.r - x_offset) < 0.001 && abs(scaledUV.g - y_offset_color_2) < 0.001) {
		COLOR.rgb = cloak_color * 0.4;
		COLOR.a = map.a - ghost_alpha; // set ghost transparency
	}
	else {
		vec4 color = texture(Skin, scaledUV);  // collect the rgba from the 'skin' sprite based on the scaledUV
		color.a = map.a - ghost_alpha; // set ghost transparency
		COLOR = color;
	}
}