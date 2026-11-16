shader_type spatial;
#include "res://addons/splite/render/cutaway.gdshaderinc"
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){if(cutaway_amount(world,2.,1.5)>.86)discard;ALBEDO=COLOR.rgb;ROUGHNESS=.92;}
