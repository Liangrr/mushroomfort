class_name FablewoodCombatParticles
extends RefCounted
## A bounded visual pool. It never mutates combat, scoring or random simulation state.
const MAX_PARTICLES:=384
const MAX_DECALS:=36
const BLOOD:=preload("res://assets/template/Effects/illuminated_ink_breakup_splatter.webp")
const TEXTURES:={
	"fire":preload("res://assets/template/Effects/illuminated_ember_flame_mote.webp"),
	"frost":preload("res://assets/template/Effects/illuminated_frost_shard_glint.webp"),
	"storm":preload("res://assets/template/Effects/illuminated_storm_spark_ribbon.webp"),
	"earth":preload("res://assets/template/Effects/illuminated_earth_leaf_root_stone_mote.webp")
}
var particles:Array[Dictionary]=[]
var decals:Array[Dictionary]=[]
var _free:Array[Dictionary]=[]
var _rng:=RandomNumberGenerator.new()
func _init()->void:_rng.seed=938713
func _particle(at:Vector2,velocity:Vector2,element:String,size:float,life:float,gravity:float,floor_y:float=10000.0)->void:
	if particles.size()>=MAX_PARTICLES:return
	var p:Dictionary=_free.pop_back() if not _free.is_empty() else {}
	p.clear();p.merge({"at":at,"velocity":velocity,"element":element,"size":size,"life":life,"duration":life,"gravity":gravity,"floor":floor_y,"angle":_rng.randf_range(-PI,PI),"spin":_rng.randf_range(-4.0,4.0)})
	particles.append(p)
func burst(at:Vector2,element:String,count:int,spread:float=32.0)->void:
	if not TEXTURES.has(element):return
	for i:int in mini(count,MAX_PARTICLES-particles.size()):
		var angle:=_rng.randf_range(-PI,PI)
		var velocity:=Vector2(cos(angle),sin(angle))*_rng.randf_range(spread*0.4,spread)
		velocity.y-=15.0
		var gravity:=95.0 if element=="earth" else -22.0 if element=="fire" else 8.0
		_particle(at,velocity,element,_rng.randf_range(7.0,13.0),_rng.randf_range(0.35,0.65),gravity)
func upgrade_burst(at:Vector2,element:String)->void:
	if not TEXTURES.has(element):return
	# A wide elemental crown plus small gold motes, distinct from the compact build puff.
	for i:int in mini(28,MAX_PARTICLES-particles.size()):
		var angle:=float(i)*TAU/18.0
		var glint:=i>=18
		var origin:=at+Vector2(cos(angle)*12,sin(angle)*5-8)
		var velocity:=Vector2(cos(angle)*_rng.randf_range(28,45),sin(angle)*16-_rng.randf_range(35,52))
		_particle(origin,velocity,element,_rng.randf_range(3,5) if glint else _rng.randf_range(8,12),_rng.randf_range(0.7,1.1),18)
		particles[-1]["upgrade"]=true
		particles[-1]["glint"]=glint

func muzzle(at:Vector2,toward:Vector2,element:String)->void:
	var aim:Vector2=(toward-at).normalized()
	for i:int in mini(5,MAX_PARTICLES-particles.size()):
		var velocity:=aim.rotated(_rng.randf_range(-0.4,0.4))*_rng.randf_range(18.0,40.0)
		_particle(at,velocity,element,_rng.randf_range(6.0,11.0),0.28,0.0)
func blood(at:Vector2,ground:Vector2,amount:int,killed:bool,reduced:bool)->void:
	if not reduced:
		var count:=18 if killed else clampi(8+amount/8,8,14)
		for i:int in mini(count,MAX_PARTICLES-particles.size()):
			var velocity:=Vector2(_rng.randf_range(-46,46),_rng.randf_range(-55,-15))
			_particle(at,velocity,"blood",_rng.randf_range(2.4,4.0),_rng.randf_range(0.45,0.8),145.0,ground.y)
	if decals.size()>=MAX_DECALS:decals.pop_front()
	var size:=_rng.randf_range(28,39) if killed else _rng.randf_range(14,22)
	decals.append({"at":ground+Vector2(_rng.randf_range(-3,3),0),"size":size,"angle":_rng.randf_range(-PI,PI),"life":5.5,"duration":5.5,"delay":0.12,"opacity":0.76 if killed else 0.55})
func advance(delta:float,world:Control)->void:
	if world.reduced_motion and not particles.is_empty():
		_free.append_array(particles)
		particles.clear()
	for i:int in range(particles.size()-1,-1,-1):
		var p:Dictionary=particles[i]
		p.life=float(p.life)-delta
		if float(p.life)<=0 or not world.effect_visible(p.at):
			_free.append(p);particles.remove_at(i);continue
		p.velocity=Vector2(p.velocity)+Vector2(0,float(p.gravity)*delta)
		p.at=Vector2(p.at)+Vector2(p.velocity)*delta
		p.angle=float(p.angle)+float(p.spin)*delta
		if p.element=="blood" and float(p.at.y)>=float(p.floor):
			p.at.y=p.floor;p.velocity=Vector2.ZERO;p.gravity=0.0;p.life=minf(float(p.life),0.12)
	for i:int in range(decals.size()-1,-1,-1):
		var d:Dictionary=decals[i]
		d.life=float(d.life)-delta;d.delay=float(d.delay)-delta
		if float(d.life)<=0:decals.remove_at(i)
func draw_ground(world:Control,opacity:float)->void:
	for d:Dictionary in decals:
		if float(d.delay)>0 or not world.effect_visible(d.at):continue
		var fade:=minf(1.0,float(d.life)/1.8)*float(d.opacity)*opacity
		var scale_x:float=float(d.size)/128.0*world._scale
		var scale_y:float=scale_x*0.48
		var angle:=float(d.angle)
		# Rotate in the ground plane before flattening into the isometric surface.
		var basis_x:=Vector2(cos(angle)*scale_x,sin(angle)*scale_y)
		var basis_y:=Vector2(-sin(angle)*scale_x,cos(angle)*scale_y)
		world.draw_set_transform_matrix(Transform2D(basis_x,basis_y,world._origin+Vector2(d.at)*world._scale))
		world.draw_texture_rect(BLOOD,Rect2(-64,-64,128,128),false,Color(1,1,1,fade))
	world.draw_set_transform(world._origin,0,Vector2.ONE*world._scale)
func draw_air(world:Control,opacity:float)->void:
	for p:Dictionary in particles:
		var fade:=clampf(float(p.life)/float(p.duration),0,1)*opacity
		var at:Vector2=p.at
		if bool(p.get("glint",false)):
			var radius:=float(p.size)*(0.5+fade*0.5)
			var color:=Color(Color("f7dea0"),fade)
			world.draw_line(at-Vector2(radius,0),at+Vector2(radius,0),color,1.3,true)
			world.draw_line(at-Vector2(0,radius),at+Vector2(0,radius),color,1.3,true)
		elif p.element=="blood":
			var radius:=float(p.size)*(0.5+fade*0.5)
			world.draw_line(at-Vector2(p.velocity).normalized()*radius*1.4,at,Color(Color("28223d"),fade),radius*1.1,true)
			world.draw_circle(at,radius*0.65,Color(Color("72538f"),fade))
		else:
			var size:=float(p.size)*(0.55+fade*0.45)
			world.draw_set_transform(world._origin+at*world._scale,float(p.angle),Vector2.ONE*world._scale)
			world.draw_texture_rect(TEXTURES[p.element],Rect2(Vector2.ONE*(-size*0.5),Vector2.ONE*size),false,Color(1,1,1,fade))
			world.draw_set_transform(world._origin,0,Vector2.ONE*world._scale)
func clear()->void:
	particles.clear();decals.clear();_free.clear()
