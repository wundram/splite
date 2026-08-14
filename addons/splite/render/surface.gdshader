shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

// Visible tile hull. Writes depth so splat dressing can test it.
// Cut-away discards a radius around the player so the hole is in the z-buffer.
// Opaque core only — no ALPHA fade (that would write a transparent lid).

#include "res://addons/splite/render/cutaway.gdshaderinc"

uniform float roughness : hint_range(0.0, 1.0) = 0.88;
instance uniform vec4 albedo : source_color = vec4(0.55, 0.55, 0.58, 1.0);
instance uniform float cut_policy = 0.0;
instance uniform float hull_top = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (cutaway_amount(v_world, cut_policy, hull_top) > 0.85) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
}
