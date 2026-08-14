shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, shadows_disabled, unshaded, skip_vertex_transform;

// Camera-facing isotropic Gaussian.
// instance_color.rgb = albedo; instance_color.a = opacity
// INSTANCE_CUSTOM = (radius, oct_x, oct_y, policy + fract(hull_top / 8))
// Tests scene depth (meshes write it); does not write depth.

#include "res://addons/splite/render/cutaway.gdshaderinc"

uniform float softness : hint_range(1.0, 8.0) = 4.0;
uniform float saturate : hint_range(0.0, 2.0) = 1.08;
uniform float lift : hint_range(0.0, 0.4) = 0.02;

uniform vec3 light_dir = vec3(-0.76, 0.54, -0.35);
uniform vec3 light_color = vec3(1.0, 0.78, 0.52);
uniform float light_energy = 1.35;
uniform vec3 ambient_color = vec3(0.55, 0.50, 0.48);
uniform float ambient_energy = 0.28;
uniform vec3 lantern_pos = vec3(0.0);
uniform vec3 lantern_color = vec3(1.0, 0.72, 0.38);
uniform float lantern_energy = 0.0;
uniform float lantern_range = 5.5;

varying vec3 v_center;
varying vec3 v_shadow;
varying vec3 v_world;
varying float v_opacity;
varying float v_policy;
varying float v_hull_top;

vec2 _oct_sign_not_zero(vec2 v) {
	return vec2(v.x >= 0.0 ? 1.0 : -1.0, v.y >= 0.0 ? 1.0 : -1.0);
}

vec3 oct_decode(vec2 e) {
	vec2 f = e * 2.0 - 1.0;
	vec3 n = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
	if (n.z < 0.0) {
		n.xy = (1.0 - abs(n.yx)) * _oct_sign_not_zero(n.xy);
	}
	return normalize(n);
}

void vertex() {
	float radius = max(INSTANCE_CUSTOM.r, 0.001);
	v_opacity = COLOR.a;
	v_shadow = oct_decode(INSTANCE_CUSTOM.gb);
	float packed = INSTANCE_CUSTOM.a;
	v_policy = floor(packed);
	v_hull_top = fract(packed) * 8.0;
	vec4 world = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	v_center = world.xyz;
	vec3 cam_x = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 cam_y = normalize(INV_VIEW_MATRIX[1].xyz);
	world.xyz += (cam_x * VERTEX.x + cam_y * VERTEX.y) * radius;
	v_world = world.xyz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	float g = exp(-r2 * softness);
	float cut_center = cutaway_amount(v_center, v_policy, v_hull_top);
	float cut_frag = cutaway_amount(v_world, v_policy, v_hull_top);
	float alpha = g * v_opacity * (1.0 - cut_center);
	if (cut_frag > 0.95 || alpha < 0.02) {
		discard;
	}

	vec3 albedo = COLOR.rgb;
	vec3 L = normalize(light_dir);
	float ndotl = clamp(dot(v_shadow, L), 0.0, 1.0);
	vec3 lit = ambient_color * ambient_energy
			+ light_color * light_energy * (0.40 + 0.60 * ndotl);
	if (lantern_energy > 0.01) {
		vec3 to_lantern = lantern_pos - v_center;
		float r = length(to_lantern);
		float att = clamp(1.0 - r / lantern_range, 0.0, 1.0);
		att *= att;
		lit += lantern_color * lantern_energy * att
				* (0.35 + 0.65 * clamp(dot(v_shadow, to_lantern / max(r, 0.001)), 0.0, 1.0));
	}
	float luma = dot(albedo * lit, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(luma), albedo * lit, saturate) + lift;
	ALPHA = alpha;
}
