extends Node3D
const Art=preload("res://demos/living_garden/art.gd")
var species := "rabbit"
var home := Vector3.ZERO
var garden: Node
var phase := 0.0
var age := 0.0
var wings: Array[Node3D]=[]
var ears: Array[Node3D]=[]
var heading := 0.0
var velocity := Vector3.ZERO

func _ready() -> void:
	position=home;heading=phase
	match species:
		"rabbit":
			Art.ellipsoid(self,Vector3(0,.17,0),Vector3(.24,.27,.4),Color("e1d5b6"))
			Art.ellipsoid(self,Vector3(0,.31,.15),Vector3(.21,.22,.2),Color("eee2c8"))
			for x in [-.055,.055]:
				ears.append(Art.ellipsoid(self,Vector3(x,.49,.12),Vector3(.06,.25,.065),Color("d6bdb0")))
				Art.ellipsoid(self,Vector3(x,.34,.235),Vector3(.026,.03,.016),Color("322d2c"))
				Art.ellipsoid(self,Vector3(x,.055,.10),Vector3(.07,.07,.15),Color("e5d8bd"))
			Art.ellipsoid(self,Vector3(0,.23,-.20),Vector3(.12,.13,.11),Color("f4ead8"))
		"bird":
			Art.ellipsoid(self,Vector3.ZERO,Vector3(.15,.15,.28),Color("668a9b"))
			Art.ellipsoid(self,Vector3(0,.06,.13),Vector3(.12,.12,.13),Color("e1ccb0"))
			Art.ellipsoid(self,Vector3(0,.04,.23),Vector3(.04,.045,.1),Color("c9944d"))
			for x in [-1,1]:wings.append(Art.ellipsoid(self,Vector3(x*.17,0,0),Vector3(.30,.045,.18),Color("526b7e")))
		"koi":
			Art.ellipsoid(self,Vector3.ZERO,Vector3(.17,.10,.49),Color("edddbb"))
			Art.ellipsoid(self,Vector3(0,.035,.06),Vector3(.16,.055,.22),Color("d6763e"))
			Art.ellipsoid(self,Vector3(.025,.04,-.12),Vector3(.12,.04,.09),Color("3b4640"))
			var tail:=Art.ellipsoid(self,Vector3(0,0,-.31),Vector3(.28,.035,.15),Color("d5b783"));wings.append(tail)

func tick(delta: float) -> void:
	age+=delta
	visible=garden.world.active_rooms.has(&"OUTSIDE")
	if not visible:return
	var t:=age+phase
	if species=="rabbit":
		var active:=fmod(t,7.0)<3.0
		if active:
			heading+=sin(t*.8)*delta
			var step:=Vector3(sin(heading),0,cos(heading))*delta*.48
			var next:=position+step
			if next.distance_to(home)>2.0 or not garden.world.is_walkable(0,Vector2(next.x,next.z)):
				heading+=PI*.71
			else:position=next
			rotation.y=heading
		position.y=garden.slope_height(Vector2(position.x,position.z))+.03+(absf(sin(t*10.))*.095 if active else 0.)
		for ear in ears:ear.rotation.x=sin(t*2.)*.12
	elif species=="bird":
		position=home+Vector3(sin(t*.55)*2.0,sin(t*1.3)*.2,cos(t*.55)*1.5)
		rotation.y=atan2(cos(t*.55)*2.,-sin(t*.55)*1.5)
		for i in wings.size():wings[i].rotation.z=sin(t*13.)*.8*(1 if i==0 else -1)
	else:
		position=home+Vector3(sin(t*.34)*1.55,sin(t)*.025,cos(t*.34)*.95)
		rotation.y=atan2(cos(t*.34)*1.55,-sin(t*.34)*.95)
		wings[0].rotation.y=sin(t*7.)*.5
