shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D diffuse_grass : source_color, repeat_disable;//, filter_nearest_mipmap;
uniform float wind_influence = .1;

global uniform float wind_speed;
global uniform vec3  wind_force;
global uniform vec3  wind_dir;

void vertex() {
	float world_influence = length(mod((MODELVIEW_MATRIX * vec4(VERTEX, 1)).xyz, vec3(1,1,1)));
	float _wind_speed = (TIME + world_influence) * wind_speed;
	VERTEX += COLOR.a * wind_dir * vec3(
		cos(VERTEX.x + _wind_speed) * wind_force.x,
		cos(VERTEX.y + _wind_speed) * wind_force.y,
		sin(VERTEX.z + _wind_speed) * wind_force.z
	);
}

void fragment() {
	vec4 color = texture(diffuse_grass, UV);
	if (color.a < .5) {
		discard;
	} else {
		ALBEDO = COLOR.rgb * color.rgb;
		//ALBEDO = vec3(COLOR.a);
	}
}

