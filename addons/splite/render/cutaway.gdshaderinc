uniform vec3 cut_origin = vec3(0.0);
uniform float cut_inner = 1.45;
uniform float cut_outer = 2.90;
uniform float cut_y_soft = 0.22;
uniform float cut_y_bias = 0.25;
uniform float cut_head = 0.72;

float cutaway_amount(vec3 world, float policy, float hull_top) {
	if (policy < 0.5) {
		return 0.0;
	}
	// cut_origin.y is the actor head.
	// IF_ABOVE (1): hull floor vs feet — a 1.25 m landing must stay open
	// while you stand under it. Head+bias vs floor is only 0.28 m of slack.
	// IF_OCCLUDES (2): visual top vs head, so a same-level canopy still opens.
	float ref_y = cut_origin.y + cut_y_bias;
	if (policy < 1.5) {
		ref_y = cut_origin.y - cut_head + cut_y_bias;
	}
	float above = smoothstep(ref_y, ref_y + cut_y_soft, hull_top);
	float d = length(world.xz - cut_origin.xz);
	float ring = 1.0 - smoothstep(cut_inner, cut_outer, d);
	return clamp(above * ring, 0.0, 1.0);
}
