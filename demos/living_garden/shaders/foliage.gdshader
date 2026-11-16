shader_type spatial;
render_mode cull_disabled;
#include "res://addons/splite/render/cutaway.gdshaderinc"
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 palette_color : source_color = vec4(.5,.6,.3,1.);
uniform float palette_strength=0.;
uniform float wind = 0.025;
uniform float cut_policy = 2.0;
instance uniform float canopy_top = 5.0;
varying vec3 world;
void vertex(){
	vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	VERTEX.x+=sin(TIME*1.2+wp.z*.7+wp.x*.3)*wind*max(VERTEX.y,0.0);
	world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
	vec4 tex=texture(base_texture,UV)*tint;
	if(tex.a<.45 || cutaway_amount(world,cut_policy,canopy_top)>.86)discard;
	ALBEDO=mix(tex.rgb,palette_color.rgb*(.4+.9*dot(tex.rgb,vec3(.299,.587,.114))),palette_strength);ROUGHNESS=.92;SPECULAR=.1;
}
