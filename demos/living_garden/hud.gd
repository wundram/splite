extends Control
const Art=preload("res://demos/living_garden/art.gd")
var garden: Node
var help_open:=false
var portrait_open:=true
var map_open:=false
var portrait: SubViewportContainer
var serif: SystemFont
var sans: SystemFont
var ink:=Color("e5d7b4")
var gold:=Color("af9560")
var muted:=Color("99ae9d")
var portrait_model: Node3D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	serif=SystemFont.new();serif.font_names=PackedStringArray(["Baskerville","Georgia","serif"])
	sans=SystemFont.new();sans.font_names=PackedStringArray(["Avenir Next","sans-serif"])
	_build_portrait()

func _build_portrait() -> void:
	portrait=SubViewportContainer.new();portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait.size=Vector2(184,225);portrait.stretch=true;add_child(portrait)
	var view:=SubViewport.new();view.size=Vector2i(184,225);view.transparent_bg=true;view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE;portrait.add_child(view)
	var stage:=Node3D.new();view.add_child(stage)
	portrait_model=Art.source("player_ranger");stage.add_child(portrait_model)
	var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,1.05,3);camera.look_at(Vector3(0,.65,0));camera.fov=30
	var sun:=DirectionalLight3D.new();stage.add_child(sun);sun.rotation_degrees=Vector3(-35,-30,0);sun.light_color=Color("ffe6c1");sun.light_energy=1.4
	var fill:=OmniLight3D.new();stage.add_child(fill);fill.position=Vector3(-1,1,2);fill.light_energy=.8;fill.light_color=Color("aecfc8")

func _process(_delta: float) -> void:
	portrait.visible=portrait_open and not help_open and not map_open
	portrait.position=Vector2(size.x-223,171)
	if portrait.visible:portrait_model.rotation.y=sin(float(Time.get_ticks_msec())*.0003)*.16
	queue_redraw()

func panel(rect: Rect2,alpha: float=.94) -> void:
	draw_style_box(style(alpha),rect)
	draw_line(rect.position+Vector2(12,5),rect.position+Vector2(40,5),gold,1)
	draw_line(rect.end-Vector2(12,5),rect.end-Vector2(40,5),gold,1)
func style(alpha: float) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color(.055,.09,.08,alpha)
	box.border_color=Color(.53,.47,.31,.7);box.set_border_width_all(1);box.set_corner_radius_all(6)
	return box
func label_at(text: String,at: Vector2,font: Font,font_size: int,color: Color=Color("e5d7b4")) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw() -> void:
	if garden==null:return
	panel(Rect2(22,22,460,94))
	label_at("THE SLEEPING GARDEN",Vector2(42,48),sans,12,gold)
	label_at(garden.area_name(),Vector2(40,80),serif,29)
	var hint:="Follow the roses east. Something sleeps in the maze."
	if garden.shrine_awake:hint="The shrine is awake. Let the garden answer your light."
	label_at(hint,Vector2(42,101),sans,12,muted)
	_compass(Vector2(size.x-92,82))
	if portrait_open and not help_open and not map_open:
		panel(Rect2(size.x-238,145,216,349),.91)
		label_at("THE WAYFARER",Vector2(size.x-215,168),sans,12,gold)
		label_at("Ranger",Vector2(size.x-212,417),serif,24)
		label_at("Cloak  ·  Quiver  ·  Walking boots",Vector2(size.x-215,442),sans,11,muted)
		label_at("Ember carried" if garden.ember_taken else "A friend to small creatures",Vector2(size.x-215,466),sans,12)
	var bar:=Rect2(size.x*.5-266,size.y-74,532,52)
	panel(bar)
	label_at("SPACE / Q",bar.position+Vector2(18,21),sans,11,gold)
	label_at(garden.spell.kind_name if garden.spell!=null else "Garden magic",bar.position+Vector2(18,40),serif,17)
	var ready: float=1.-clampf(garden.spell.cooldown/2.2,0,1) if garden.spell!=null else 1.
	draw_line(bar.position+Vector2(143,17),bar.position+Vector2(210,17),Color("344b40"),3)
	draw_line(bar.position+Vector2(143,17),bar.position+Vector2(143+67*ready,17),Color("80c8a0"),3)
	label_at("Ready" if ready>.99 else "Gathering",bar.position+Vector2(143,39),sans,11,muted)
	label_at("E  Interact    I  Portrait    M  Map    H  Help",bar.position+Vector2(232,31),sans,12)
	label_at("%02d:%02d  ·  %d places discovered" % [int(garden.clock.time),int(fmod(garden.clock.time,1.)*60),garden.discovered.size()],Vector2(26,size.y-28),sans,12,muted)
	if map_open:_map()
	if help_open:_help()

func _compass(c: Vector2) -> void:
	draw_circle(c,49,Color(.04,.07,.06,.88));draw_arc(c,47,0,TAU,64,gold,1,true)
	for i in 16:
		var a:=float(i)*TAU/16.
		draw_line(c+Vector2(sin(a),cos(a))*39,c+Vector2(sin(a),cos(a))*44,gold,1)
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,-29),c+Vector2(-7,0),c+Vector2(0,7),c+Vector2(7,0)]),Color("dbc488"))
	draw_colored_polygon(PackedVector2Array([c+Vector2(0,30),c+Vector2(-6,0),c+Vector2(0,-5),c+Vector2(6,0)]),Color("5c8270"))
	var a: float=garden.ranger.rotation.y
	draw_line(c,c+Vector2(sin(a),cos(a))*25,Color("a2dfca"),2)
	label_at("N",c+Vector2(-5,-52),serif,17)
	label_at("W",c+Vector2(-64,5),serif,14,gold);label_at("E",c+Vector2(54,5),serif,14,gold)

func _help() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0,.02,.015,.66))
	var p:=size*.5-Vector2(290,246)
	panel(Rect2(p,Vector2(580,492)),.98)
	label_at("A wayfarer's field notes",p+Vector2(30,46),serif,30)
	label_at("Take your time. Nothing here wants to fight.",p+Vector2(31,76),sans,14,muted)
	var rows:=[
		["W A S D  /  Arrows","Walk through the garden"],["E","Open doors / awaken the shrine / take the ember"],
		["SPACE  /  Q","Verdant pulse / moonlight bloom"],["I","Show or hide the character portrait"],
		["M","Unfold the garden map"],["[  /  ]","Move the sun backward / forward"],
		["F3","Show the camera cutaway guide"],["H  /  F1  /  Escape","Open or close these notes"]]
	for i in rows.size():
		var y:=p.y+119+i*36
		label_at(rows[i][0],Vector2(p.x+31,y),sans,12,gold)
		label_at(rows[i][1],Vector2(p.x+196,y),sans,12)
	label_at("Seek the sleeping stone beyond the rose labyrinth.",p+Vector2(31,448),serif,17,muted)

func _map() -> void:
	var p:=size*.5-Vector2(258,233)
	panel(Rect2(p,Vector2(516,466)),.98)
	label_at("A map of small wonders",p+Vector2(25,36),serif,27)
	var start:=p+Vector2(32,65);var cell:=12.
	for key in garden.world.cells:
		if key.x!=0:continue
		var entry: SplatWorld.Cell=garden.world.cells[key]
		var color:=Color("637b50")
		if entry.def.id==&"water":color=Color("376a6a")
		elif not garden.world.walk.get(key,false):color=Color("344d3d")
		elif entry.def.id==&"path":color=Color("aa9c70")
		draw_rect(Rect2(start+Vector2(key.y,key.z)*cell,Vector2.ONE*(cell-.4)),color)
	var here:=start+Vector2(garden.actor.position.x,garden.actor.position.z)*cell+Vector2.ONE*6
	draw_circle(here,5,Color("f6d692"))
	label_at("Woodland slopes          Pond & shrine          Rose labyrinth",p+Vector2(27,446),sans,12,muted)
