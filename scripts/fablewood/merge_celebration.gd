class_name FablewoodMergeCelebration
extends RefCounted
const P:=preload("res://scripts/fablewood/presentation.gd")
const FX:=preload("res://scripts/fablewood/combat_particles.gd")
const DURATION:=2.4
const MAX_ACTIVE:=3
var active:Array[Dictionary]=[]
var _seen:Array[int]=[]
func trigger(event:Dictionary,world:Control)->bool:
	if event.get("kind","")!="merge_placed":return false
	var id:=int(event.get("unit",-1))
	if id<0 or id in _seen:return false
	_seen.append(id)
	if _seen.size()>64:_seen.pop_front()
	var at:Vector2=world.platform_surface_center(event.cell)
	if not world.effect_visible(at):return false
	if active.size()>=MAX_ACTIVE:active.pop_front()
	active.append({"unit":id,"at":at,"a":String(event.element),"b":String(event.second_element),"parts":event.get("elements",PackedStringArray([String(event.element),String(event.second_element)])),"age":0.0})
	return true
func advance(delta:float,world:Control)->void:
	for i:int in range(active.size()-1,-1,-1):
		var e:Dictionary=active[i];e.age=float(e.age)+delta
		if float(e.age)>=DURATION or not world.effect_visible(e.at):active.remove_at(i)
func clear()->void:active.clear();_seen.clear()
func draw_ground(world:Control)->void:
	var opacity:=float(TweakControls.value(&"environment.effect_opacity",1.0))
	for e:Dictionary in active:
		var t:=float(e.age);var fade:=clampf(1-t/DURATION,0,1)*opacity
		var radius:=34.0 if world.reduced_motion else 27.0+minf(t,1.2)*34.0
		for j:int in e.parts.size():
			var color:Color=P.COLORS[e.parts[j]];color.a=fade*.8
			world._ellipse(e.at,Vector2(radius+j*7,(radius+j*7)*.45),color,2.0)
		for j:int in 12:
			var angle:=j*TAU/12.0
			var a:Vector2=e.at+Vector2(cos(angle),sin(angle)*.45)*(radius-4)
			var b:Vector2=e.at+Vector2(cos(angle),sin(angle)*.45)*(radius+1)
			world.draw_line(a,b,Color(P.GOLD,fade*.75),1.5)
func draw_air(world:Control)->void:
	var opacity:=float(TweakControls.value(&"environment.effect_opacity",1.0))
	for e:Dictionary in active:
		var t:=float(e.age);var fade:=clampf(1-t/DURATION,0,1)*opacity
		if world.reduced_motion:continue
		# All inherited elemental ribbons converge into the new guardian's heart.
		for strand:int in e.parts.size():
			var color:Color=P.COLORS[e.parts[strand]]
			var previous:=Vector2.ZERO
			for j:int in 24:
				var u:=float(j)/23.0;var angle:=u*TAU*1.3+t*3.0+strand*TAU/float(e.parts.size())
				var radius:=(31.0+u*16)*clampf(1.2-t*.3,.2,1)
				var p:Vector2=e.at+Vector2(cos(angle)*radius,sin(angle)*radius*.35-u*104.0)
				if j>0:world.draw_line(previous,p,Color(color,fade*(.2+u*.5)),2.0,true)
				previous=p
		# A concise starburst; no screen-filling flash and no HUD transform.
		var bloom:=maxf(0.0,1-absf(t-.4)/.4)*opacity
		var heart:Vector2=e.at-Vector2(0,54)
		if bloom>0:
			for j:int in 10:
				var a:=float(j)*TAU/10.0+t*.15
				var dir:=Vector2(cos(a),sin(a)*.8)
				world.draw_line(heart+dir*8,heart+dir*(18+bloom*43),Color(P.GOLD,bloom*.75),2,true)
			world.draw_circle(heart,4+bloom*5,Color(1,.96,.72,bloom*.8))
		for j:int in 40:
			var phase:=float(j)*2.399963;var elapsed:=maxf(0,t-.18)
			var speed:=25.0+float(j%7)*7.0
			var at:Vector2=heart+Vector2(cos(phase)*speed*elapsed,sin(phase)*speed*elapsed*.55-40*elapsed+25*elapsed*elapsed)
			var alpha:=fade*clampf(1-elapsed/2.2,0,1)
			if j%3==0:
				var element:String=e.a if j%2==0 else e.b
				var size:=5.0+float(j%4)
				world.draw_texture_rect(FX.TEXTURES[element],Rect2(at-Vector2.ONE*size/2,Vector2.ONE*size),false,Color(1,1,1,alpha))
			else:world.draw_circle(at,1.0+float(j%3)*.4,Color(P.GOLD,alpha))
