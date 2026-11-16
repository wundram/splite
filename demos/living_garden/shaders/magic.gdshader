shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never,shadows_disabled;
uniform sampler2D scene_color: hint_screen_texture,repeat_disable,filter_linear;
uniform float strength=0.0;
uniform vec4 glow: source_color=vec4(.20,.95,.73,1.);
void fragment(){
	vec2 p=UV*2.-1.;float r=length(p);
	float ring=exp(-pow((r-.68)*17.,2.));
	float envelope=(1.-smoothstep(.7,1.,r))*strength;
	vec2 warp=p*sin(r*24.-TIME*9.)*.014*envelope;
	ALBEDO=texture(scene_color,SCREEN_UV+warp).rgb+glow.rgb*ring*strength*.6;
	ALPHA=clamp(envelope+ring*strength,0.,.9);
}
