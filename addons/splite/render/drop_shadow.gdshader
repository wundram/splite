shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, shadows_disabled, unshaded, skip_vertex_transform;

// Ground-aligned drop. INSTANCE_CUSTOM = (half_x, half_z, strength, shape)
// shape >= 0.5 => blob (gaussian); else rounded hull.

varying float v_str;
varying float v_blob;
varying vec2 v_uv;

void vertex() {
	v_str = INSTANCE_CUSTOM.b;
	v_blob = INSTANCE_CUSTOM.a;
	vec4 world = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec2 half = max(INSTANCE_CUSTOM.rg, vec2(0.04));
	world.xz += VERTEX.xy * half;
	v_uv = VERTEX.xy;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world;
}

void fragment() {
	float r2 = dot(v_uv, v_uv);
	if (r2 > 1.0) {
		discard;
	}
	float g;
	if (v_blob > 0.5) {
		g = exp(-r2 * 2.8);
	} else {
		float box = max(abs(v_uv.x), abs(v_uv.y));
		g = 1.0 - smoothstep(0.62, 1.0, box);
	}
	ALBEDO = vec3(0.0);
	ALPHA = g * v_str;
}
