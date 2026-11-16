extends Node3D
const Art=preload("res://demos/living_garden/art.gd")
var kind_name:="Verdant pulse"
var age:=99.0
var cooldown:=0.0
var particles: GPUParticles3D
var lens: MeshInstance3D
var ring: MeshInstance3D
var light: OmniLight3D
var warp: DistortionField
var garden: Node

func _ready() -> void:
	var quad:=QuadMesh.new();quad.size=Vector2(4,4)
	lens=Art.mesh(self,quad,Vector3(0,.8,0),Color.WHITE)
	lens.material_override=ShaderMaterial.new()
	lens.material_override.shader=preload("res://demos/living_garden/shaders/magic.gdshader")
	lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus:=TorusMesh.new();torus.inner_radius=.94;torus.outer_radius=1.0;torus.rings=48;torus.ring_segments=8
	ring=Art.mesh(self,torus,Vector3(0,.08,0),Color("8bf0b7"),1.5)
	particles=GPUParticles3D.new();add_child(particles)
	particles.amount=90;particles.lifetime=1.7;particles.one_shot=true;particles.explosiveness=.75
	particles.visibility_aabb=AABB(Vector3(-4,-1,-4),Vector3(8,6,8))
	var process:=ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius=.45
	process.direction=Vector3.UP;process.spread=100
	process.initial_velocity_min=.6;process.initial_velocity_max=2.1
	process.gravity=Vector3(0,-.4,0)
	process.scale_min=.022;process.scale_max=.06
	process.color=Color("a0f6bf")
	particles.process_material=process
	var shape:=SphereMesh.new();shape.radius=.5;shape.height=1;shape.radial_segments=6;shape.rings=3
	shape.material=Art.material(Color("8ff3bc"),2)
	particles.draw_pass_1=shape;particles.emitting=false
	light=OmniLight3D.new();add_child(light);light.position.y=1.0;light.light_color=Color("80e9be");light.omni_range=4.5
	warp=DistortionField.new();warp.mode=DistortionField.Mode.SWIRL;warp.radius=3.;warp.rate=4.
	add_child(warp)
	garden.world.fields.append(warp)
	visible=false

func cast(at: Vector3,kind: int=0) -> bool:
	if cooldown>0:return false
	position=at;age=0;cooldown=2.2;visible=true
	kind_name="Verdant pulse" if kind==0 else "Moonlight bloom"
	var color:=Color("8ff3bc") if kind==0 else Color("a2bfff")
	warp.mode=DistortionField.Mode.SWIRL if kind==0 else DistortionField.Mode.BREATHE
	particles.process_material.color=color
	ring.material_override=Art.material(color,1.5)
	light.light_color=color
	lens.material_override.set_shader_parameter("glow",color)
	particles.restart();particles.emitting=true
	return true

func tick(delta: float) -> void:
	cooldown=maxf(0,cooldown-delta);age+=delta
	var strength:=clampf(1.-age/2.,0.,1.)
	visible=strength>0
	warp.strength=strength*.8
	light.light_energy=strength*2.
	ring.scale=Vector3.ONE*(.2+age*1.3)
	ring.visible=age<1.5
	lens.material_override.set_shader_parameter("strength",strength*.85)
	var camera:=get_viewport().get_camera_3d()
	if camera!=null:lens.global_basis=camera.global_basis
