shader_type spatial;

// Depth-compression viewmodel shader (ARCHITECTURE.md §4.5). Hands, watch,
// phone and carried props stay in the main viewport so they're lit by the
// real scene, but their view-space position is scaled toward the camera
// before projection so they never clip into world geometry, however close
// the player stands to a wall.

uniform float depth_scale : hint_range(0.1, 1.0) = 0.55;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view_position.xyz *= depth_scale;
	POSITION = PROJECTION_MATRIX * view_position;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
}
