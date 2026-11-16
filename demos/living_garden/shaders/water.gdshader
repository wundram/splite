shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled;
uniform vec4 deep_color : source_color=vec4(.045,.24,.23,.77);
varying vec3 world;
void vertex(){
	world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
	float a=world.x*2.5+world.z*1.8+TIME*.9;
	float b=world.x*-.9+world.z*3.8-TIME*1.1;
	VERTEX.y+=sin(a)*.018+sin(b)*.009;
	NORMAL=normalize(vec3(-cos(a)*.045+cos(b)*.008,1.,-cos(a)*.032-cos(b)*.034));
}
void fragment(){
	float ripple=pow(.5+.5*sin(world.x*10.+world.z*7.+sin(world.z*2.+TIME)*2.-TIME*1.5),20.);
	ALBEDO=deep_color.rgb+vec3(.012,.027,.025)*ripple;
	METALLIC=.55;ROUGHNESS=.12;SPECULAR=.85;
	EMISSION=vec3(.004,.012,.01)*ripple;ALPHA=deep_color.a;
}
