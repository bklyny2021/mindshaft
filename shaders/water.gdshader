// MindShaft water — simple, Godot 4 compatible surface shader.
// Purely visual plane at sea level; never touches block/collision (no falling).
shader_type spatial;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform vec3 albedo : source_color = vec3(0.02, 0.32, 0.62);
uniform float metallic = 0.1;
uniform float roughness = 0.1;
uniform float time_scale = 0.6;
uniform vec2 wave_dir1 = vec2(0.6, 0.8);
uniform vec2 wave_dir2 = vec2(-0.7, 0.5);
uniform float noise_scale = 0.05;
uniform float height_scale = 4.0;
uniform vec3 shallow_color : source_color = vec3(0.0, 0.4, 0.7);
uniform vec3 deep_color : source_color = vec3(0.005, 0.1, 0.3);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Gentle animated ripple so the surface visibly moves.
	vec2 p = wpos.xz * noise_scale;
	float h = (dot(wpos.xz, wave_dir1) + dot(wpos.xz, wave_dir2));
	VERTEX.y += sin(h + TIME * 2.0) * height_scale * 0.05;
}

void fragment() {
	// Depth fade: darker/clearer where deeper.
	float depth_tex = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	float depth_ratio = clamp(1.0 - depth_tex * 3.0, 0.0, 1.0);
	vec3 base = mix(shallow_color, deep_color, depth_ratio);

	// Simple animated normal-ish ripple mix for a lively surface.
	vec2 uv = wpos.xz * 0.8 + TIME * wave_dir1 * time_scale;
	float n = sin(dot(uv, wave_dir1));
	float n2 = cos(dot(wpos.xz * 1.3, wave_dir2) - TIME * time_scale);
	vec3 ripple = vec3(0.5 + 0.5 * n, 0.5 + 0.5 * n2, 1.0);

	ALBEDO = base;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL = normalize(ripple);
}
