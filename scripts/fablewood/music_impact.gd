class_name FablewoodMusicImpact
extends RefCounted
## A single bounded presentation burst; never modifies camera pan, actors or model RNG.
const DURATION:=2.2
const SHAKE_SECONDS:=0.42
const MAX_MOTES:=32
var age:=DURATION
var reduced:=false
var origin:=Vector2.ZERO
var motes:Array[Dictionary]=[]
var trigger_count:=0
func clear()->void:
	age=DURATION;motes.clear()
func start(at:Vector2,reduce_motion:bool)->void:
	clear();origin=at;age=0;reduced=reduce_motion;trigger_count+=1
	if reduced:return
	for i:int in MAX_MOTES:
		# Deterministic presentation pattern, independent of gameplay and repeat RNG.
		var angle:=float(i)*2.39996323
		var spread:=22.0+float(i%7)*5.0
		motes.append({"velocity":Vector2(cos(angle)*spread,sin(angle)*spread*0.55-20),"delay":float(i%4)*0.018,"radius":1.2+float(i%3)*0.45})
func advance(delta:float,reduce_motion:bool)->void:
	if reduce_motion and not reduced:motes.clear()
	reduced=reduce_motion
	age=minf(age+maxf(delta,0),DURATION)
	if age>=DURATION:motes.clear()
func shake_offset()->Vector2:
	if reduced or age>=SHAKE_SECONDS:return Vector2.ZERO
	var strength:=pow(1.0-age/SHAKE_SECONDS,2.0)*minf(age/0.025,1.0)
	return Vector2(sin(age*73.0)*2.2,sin(age*91.0)*1.4)*strength
func draw(world:Control)->void:
	if age>=DURATION or not world.effect_visible(origin):return
	var opacity:=float(TweakControls.value(&"environment.effect_opacity",1.0))
	var fade:=pow(1.0-age/DURATION,1.5)*minf(age/0.09,1.0)*opacity
	var gold:=Color("f4d98e")
	# A soft local bloom, never a fullscreen flash. Reduced motion keeps a fixed halo.
	for i:int in 5:
		world.draw_circle(origin,12.0+float(i)*5.0,Color(gold,fade*0.014))
	if reduced:
		world._ellipse(origin,Vector2(27,18),Color(gold,fade*0.30),0.8)
		return
	var t:=minf(age/1.1,1.0)
	world._ellipse(origin,Vector2(18+58*t,10+30*t),Color(gold,fade*(1-t)*0.38),0.9)
	for mote:Dictionary in motes:
		var elapsed:=maxf(age-float(mote.delay),0)
		var at:=origin+Vector2(mote.velocity)*elapsed+Vector2(0,-7*elapsed*elapsed)
		var radius:=float(mote.radius)*(0.8+fade*0.2)
		world.draw_circle(at,radius*3.0,Color(gold,fade*0.045))
		world.draw_line(at-Vector2(radius*1.5,0),at+Vector2(radius*1.5,0),Color(gold,fade*0.75),0.9,true)
		world.draw_line(at-Vector2(0,radius),at+Vector2(0,radius),Color(Color("fff0c7"),fade*0.7),0.9,true)
