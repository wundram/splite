shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, skip_vertex_transform;

// Trained anisotropic Gaussian. MODEL_MATRIX basis stores R * diag(sigma).
// instance_color.rgb = albedo; instance_color.a = opacity
// INSTANCE_CUSTOM = (radius, oct_x, oct_y, policy + fract(hull_top / 8))
// Tests scene depth (meshes write it); does not write depth.

#include "res://addons/splite/render/cutaway.gdshaderinc"

uniform float softness : hint_range(1.0, 8.0) = 4.0;
uniform bool scene_lighting = false;
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
varying vec3 v_view_center;
varying vec3 v_view_normal;
varying vec3 v_view_surface;
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
    v_opacity = COLOR.a;
    v_shadow = oct_decode(INSTANCE_CUSTOM.gb);
    v_policy = floor(INSTANCE_CUSTOM.a);
    v_hull_top = fract(INSTANCE_CUSTOM.a) * 8.0;
    vec4 center = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
    v_center = center.xyz;
    v_world = center.xyz;
    vec4 view_center = VIEW_MATRIX * center;
    v_view_center = view_center.xyz;
    v_view_normal = mat3(VIEW_MATRIX) * v_shadow;
    mat3 axes = mat3(VIEW_MATRIX * MODEL_MATRIX);
    float depth = max(-view_center.z, 0.001);
    vec2 focal = vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE * 0.5;
    vec3 jx;
    vec3 jy;
    if (abs(PROJECTION_MATRIX[3][3]) > 0.5) {
        jx = vec3(focal.x, 0.0, 0.0);
        jy = vec3(0.0, focal.y, 0.0);
    } else {
        jx = vec3(focal.x / depth, 0.0, focal.x * view_center.x / (depth * depth));
        jy = vec3(0.0, focal.y / depth, focal.y * view_center.y / (depth * depth));
    }
    vec3 ax = vec3(dot(jx, axes[0]), dot(jx, axes[1]), dot(jx, axes[2]));
    vec3 ay = vec3(dot(jy, axes[0]), dot(jy, axes[1]), dot(jy, axes[2]));
    // gsplat's default screen-space low-pass variance is 0.3 pixels squared.
    float a = dot(ax, ax) + 0.3;
    float b = dot(ax, ay);
    float c = dot(ay, ay) + 0.3;
    float mid = 0.5 * (a + c);
    float spread = sqrt(max(0.0, 0.25 * (a-c)*(a-c) + b*b));
    float major = max(mid + spread, 0.0001);
    float minor = max(mid - spread, 0.0001);
    vec2 direction = abs(b) > 0.00001 ? normalize(vec2(b, major-a)) : (a >= c ? vec2(1.0,0.0) : vec2(0.0,1.0));
    vec2 perpendicular = vec2(-direction.y, direction.x);
    vec2 pixels = 3.0 * (direction * sqrt(major) * VERTEX.x + perpendicular * sqrt(minor) * VERTEX.y);
    // Conditional mean depth of the ellipsoid at this projected point. Using
    // only its center for shadow lookup makes a large splat one flat shadow blob.
    vec3 z_axes = vec3(axes[0].z, axes[1].z, axes[2].z);
    vec2 covariance_z = vec2(dot(z_axes, ax), dot(z_axes, ay));
    float dz = dot(covariance_z, vec2(c * pixels.x - b * pixels.y, a * pixels.y - b * pixels.x)) / max(a*c-b*b, 0.00001);
    v_view_surface.z = view_center.z + dz;
    if (abs(PROJECTION_MATRIX[3][3]) > 0.5) {
        v_view_surface.xy = view_center.xy + pixels / focal;
    } else {
        v_view_surface.xy = (view_center.xy / depth + pixels / focal) * max(-v_view_surface.z, 0.001);
    }
    vec4 clip = PROJECTION_MATRIX * view_center;
    clip.xy += pixels * (2.0 / VIEWPORT_SIZE) * clip.w;
    POSITION = clip;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	float g = exp(-4.5 * r2);
	float cut_center = cutaway_amount(v_center, v_policy, v_hull_top);
	float cut_frag = cutaway_amount(v_world, v_policy, v_hull_top);
	float alpha = min(0.99, g * v_opacity) * (1.0 - cut_center);
	if (cut_frag > 0.95 || alpha < (1.0 / 255.0)) {
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
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	if (scene_lighting) {
		ALBEDO = albedo;
		EMISSION = vec3(0.0);
		LIGHT_VERTEX = v_view_surface;
		NORMAL = normalize(v_view_normal);
		if (dot(NORMAL, -v_view_center) < 0.0) { NORMAL = -NORMAL; }
	} else {
		ALBEDO = vec3(0.0);
		EMISSION = mix(vec3(luma), albedo * lit, saturate) + lift;
	}
	ALPHA = alpha;
}
