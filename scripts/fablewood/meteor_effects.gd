extends RefCounted
## Presentation only. Flight comes from model ticks; damage never comes from this module.
const P:=preload("res://scripts/fablewood/presentation.gd")
const METEOR:=preload("res://assets/template/Effects/illuminated_worldheart_convergence_meteor.webp")
const KEY:="fire_frost_storm_earth"
const PARTS:=["fire","frost","storm","earth"]
const MAX_IMPACTS:=4
const LIFE:=1.5
var impacts:Array[Dictionary]=[]
var seen:Array[String]=[]
func clear()->void:impacts.clear();seen.clear()
func trigger(ev:Dictionary,w)->bool:
	if ev.get("kind","")!="meteor_impact":return false
	var token:=str(ev.unit)+":"+str(ev.tick)
	if token in seen:return false
	seen.append(token)
	if seen.size()>64:seen.pop_front()
	var center:Vector2=w.route_center(Vector2(ev.center))
	if not w.effect_visible(center):return false
	var chains:Array[Vector2]=[]
	for id:int in ev.chains:
		var e:EnemyState=w.model.enemies[id];var at:Vector2=w.enemy_hit_point(e)
		if w.effect_visible(at):chains.append(at)
	if impacts.size()>=MAX_IMPACTS:impacts.pop_front()
	impacts.append({"unit":ev.unit,"center":center,"cell":ev.center,"chains":chains,"age":0.0})
	if not w.reduced_motion:
		for part:String in PARTS:w.combat_particles.burst(center-Vector2(0,12),part,12,56.0)
	return true
func advance(delta:float,w)->void:
	if w.model==null:clear();return
	for i:int in range(impacts.size()-1,-1,-1):
		var fx:Dictionary=impacts[i];fx.age=float(fx.age)+delta
		var u:UnitState=w.model.unit_by_id(int(fx.unit))
		if u==null or not u.alive or w.model.result!=BattleModel.Result.RUNNING or float(fx.age)>=LIFE or not w.effect_visible(fx.center):impacts.remove_at(i)
func flight(w,u:UnitState,state:Dictionary)->Dictionary:
	var data:Dictionary=state.active
	var start:Vector2=w.tower_emission_point(u)
	var end:Vector2=w.route_center(Vector2(data.center))-Vector2(0,22)
	var t:=clampf(float(w.model.tick-1-int(data.launch_tick))/float(int(data.impact_tick)-int(data.launch_tick)),0,1)
	var point:=start.lerp(end,t)-Vector2(0,sin(t*PI)*125.0)
	var tangent:Vector2=end-start-Vector2(0,cos(t*PI)*PI*125.0)
	return {"point":point,"direction":tangent.normalized(),"t":t,"end":end}
func _outline(w,cell:Vector2i,radius:float)->PackedVector2Array:
	var points:PackedVector2Array=[]
	for offset:Vector2 in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius),Vector2(-radius,radius)]:points.append(w.route_center(Vector2(cell)+offset))
	points.append(points[0]);return points
func draw_ground(w)->void:
	if w.model==null:return
	var opacity:float=TweakControls.value(&"environment.effect_opacity",1.0)
	for id:int in w.model.ultimates.states:
		var state:Dictionary=w.model.ultimates.states[id]
		if state.key!=KEY or state.active.is_empty():continue
		var u:UnitState=w.model.unit_by_id(id)
		if u==null or not u.alive:continue
		var center:Vector2=w.route_center(Vector2(state.active.center))
		if not w.effect_visible(center):continue
		var progress:float=flight(w,u,state).t
		var boundary:=_outline(w,state.active.center,3.0)
		for i:int in 4:w.draw_line(boundary[i],boundary[i+1],Color(P.COLORS[PARTS[i]],opacity*.6),1.5,true)
		w._ellipse(center,Vector2(18,9),Color(P.GOLD,opacity*.8),2)
		if not w.reduced_motion:w._ellipse(center,Vector2(8,4)*(1+progress),Color(1,.9,.65,.6*opacity),2)
	for fx:Dictionary in impacts:
		var t:float=float(fx.age)/LIFE;var fade:float=(1-t)*opacity
		var center:Vector2=fx.center
		if w.reduced_motion:
			var boundary:=_outline(w,fx.cell,3.0)
			for i:int in 4:w.draw_line(boundary[i],boundary[i+1],Color(P.COLORS[PARTS[i]],fade*.8),2,true)
			w._ellipse(center,Vector2(24,12),Color(P.GOLD,fade),2)
			continue
		w._ellipse(center,Vector2(28,14)*(1+t),Color(.15,.12,.16,fade*.65),7)
		for i:int in 4:
			var radius:=12.0+minf(t*3.2,1)*(62+i*8)
			w._ellipse(center,Vector2(radius,radius*.48),Color(P.COLORS[PARTS[i]],fade*.7),2.6)
		for i:int in 8:
			var angle:=float(i)*TAU/8
			var v:=Vector2(cos(angle),sin(angle)*.5)
			w.draw_polyline(PackedVector2Array([center+v*10,center+v*25+Vector2(3,-3),center+v*(35+minf(t*4,1)*30)]),Color(.9,.64,.28,fade*.65),1.4,true)
func _rock(w,point:Vector2,_direction:Vector2,_t:float,opacity:float)->void:
	# The rounded artwork is direction-neutral; the trail shows the current velocity.
	w.draw_texture_rect(METEOR,Rect2(point-Vector2(34,34),Vector2(68,68)),false,Color(1,1,1,opacity))
func draw_air(w)->void:
	if w.model==null:return
	var opacity:float=TweakControls.value(&"environment.effect_opacity",1.0)
	for id:int in w.model.ultimates.states:
		var state:Dictionary=w.model.ultimates.states[id]
		if state.key!=KEY or state.active.is_empty():continue
		var u:UnitState=w.model.unit_by_id(id)
		if u==null or not u.alive:continue
		var f:=flight(w,u,state)
		if w.reduced_motion:continue
		if not w.effect_visible(f.point):continue
		var dir:Vector2=f.direction;var side:=Vector2(-dir.y,dir.x)
		for i:int in 4:
			var color:Color=P.COLORS[PARTS[i]];color.a=opacity*.72
			var edge:Vector2=f.point+side*(i-1.5)*6
			var tail:Vector2=edge-dir*(58+i*8)
			w.draw_colored_polygon(PackedVector2Array([edge+side*7,tail,edge-side*7]),color)
			if i==2:w.draw_polyline(PackedVector2Array([tail,edge-dir*32+side*6,edge-dir*19-side*6,edge]),Color(.9,.8,1,opacity),1.5,true)
		_rock(w,f.point,dir,f.t,opacity)
	for fx:Dictionary in impacts:
		var t:float=float(fx.age)/LIFE;var fade:float=(1-t)*opacity;var center:Vector2=fx.center
		if not w.reduced_motion:
			if t<.3:w._ellipse(center-Vector2(0,8),Vector2(27,14)*(1+t*4),Color(1,.93,.72,fade*.5),5)
			for i:int in 20:
				var a:=float(i)*TAU/20;var start:=center-Vector2(0,8)
				var point:=start+Vector2(cos(a)*60*t,sin(a)*25*t-sin(t*PI)*(20+float(i%4)*7))
				var color:Color=P.COLORS[PARTS[i%4]];color.a=fade
				var r:=2.5*(1-t)+.6
				w.draw_colored_polygon(PackedVector2Array([point+Vector2(-r,0),point+Vector2(0,-r*2),point+Vector2(r,0),point+Vector2(0,r)]),color)
		for point:Vector2 in fx.chains:
			if w.reduced_motion:w._ellipse(point,Vector2(9,5),Color(P.COLORS.storm,fade),2)
			else:w.draw_polyline(PackedVector2Array([center-Vector2(0,9),center.lerp(point,.5)+Vector2(8,-15),center.lerp(point,.6)+Vector2(-5,5),point]),Color(.8,.6,1,fade),2.2,true)
