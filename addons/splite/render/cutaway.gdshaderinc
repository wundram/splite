uniform vec3 cut_origin = vec3(0.0);
uniform float cut_inner = 1.45;
uniform float cut_outer = 2.90;
uniform float cut_y_soft = 0.22;
uniform float cut_y_bias = 0.25;

float cutaway_amount(vec3 world, float policy, float hull_top) {
	if (policy < 0.5) {
		return 0.0;
	}
	float above = smoothstep(
			cut_origin.y + cut_y_bias,
			cut_origin.y + cut_y_bias + cut_y_soft,
			hull_top);
	float d = length(world.xz - cut_origin.xz);
	float ring = 1.0 - smoothstep(cut_inner, cut_outer, d);
	return clamp(above * ring, 0.0, 1.0);
}
