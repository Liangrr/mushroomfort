extends RefCounted
## Presentation only; immutable event snapshots never resolve damage or targets.
const P:=preload("res://scripts/fablewood/presentation.gd")
const MAX_EFFECTS:=18
var active:Array[Dictionary]=[]
var seen:Dictionary={}
func clear()->void:
	active.clear();seen.clear()
func trigger(ev:Dictionary,w)->bool:
	var stamp:int=ev.tick
	if int(seen.get(ev.unit,-1))>=stamp:return false
	seen[ev.unit]=stamp
	var u:UnitState=w.model.unit_by_id(ev.unit)
	if u==null:return false
	var origin:Vector2=w.tower_emission_point(u)
	var center:Vector2=w.route_center(Vector2(ev.center))
	var points:Array[Vector2]=[];var grounds:Array[Vector2]=[];var root_grounds:Array[Vector2]=[]
	for id:int in ev.hits:
		var e:EnemyState=w.model.enemies[id]
		var hit:Vector2=w.enemy_hit_point(e)
		if w.effect_visible(hit):
			points.append(hit);grounds.append(w.enemy_ground_position(e))
			if not e.aerial:root_grounds.append(w.enemy_ground_position(e))
	if not w.effect_visible(origin) and not w.effect_visible(center) and points.is_empty():return false
	if active.size()>=MAX_EFFECTS:active.pop_front()
	active.append({"key":ev.key,"unit":ev.unit,"origin":origin,"center":center,"points":points,"grounds":grounds,"root_grounds":root_grounds,"age":0.0,"life":1.25})
	if not w.reduced_motion:
		var parts:PackedStringArray=String(ev.key).split("_")
		for point:Vector2 in points:
			w.combat_particles.burst(point,parts[0],4,26.0)
			w.combat_particles.burst(point,parts[1],4,26.0)
	return true
func advance(delta:float,w)->void:
	if w.model==null:clear();return
	for id:int in seen.keys():
		var u:UnitState=w.model.unit_by_id(id)
		if u==null or not u.alive:seen.erase(id)
	var keep:Array[Dictionary]=[]
	for fx:Dictionary in active:
		var u:UnitState=w.model.unit_by_id(fx.unit)
		if u==null or not u.alive or w.model.result!=BattleModel.Result.RUNNING:continue
		fx.age=float(fx.age)+delta
		var visible:bool=w.effect_visible(fx.origin) or w.effect_visible(fx.center)
		for point:Vector2 in fx.points:visible=visible or w.effect_visible(point)
		if visible and float(fx.age)<float(fx.life):keep.append(fx)
	active=keep
func _shard(w,at:Vector2,color:Color,size:float)->void:
	w.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-size),at+Vector2(size*.4,0),at+Vector2(0,size*.5),at+Vector2(-size*.4,0)]),color)
func draw_ground(w)->void:
	var opacity:float=TweakControls.value(&"environment.effect_opacity",1.0)
	# Persistent grove reads current authoritative state, including wave/sell cleanup.
	for id:int in w.model.ultimates.states:
		var state:Dictionary=w.model.ultimates.states[id]
		if state.key!="frost_earth" or state.active.is_empty():continue
		var at:Vector2=w.route_center(Vector2(state.active.center))
		if not w.effect_visible(at):continue
		w._ellipse(at,Vector2(74,37),Color(.52,.92,.83,.7*opacity),2.0)
		w._ellipse(at,Vector2(67,33),Color(.7,.92,1,.4*opacity),1.0)
		for i:int in 12:
			var a:=float(i)*TAU/12;var point:=at+Vector2(cos(a)*70,sin(a)*35)
			_shard(w,point,Color(.68,.96,1,.72*opacity),7)
	for fx:Dictionary in active:
		var a:float=clampf(float(fx.age)/float(fx.life),0,1)
		var fade:float=(1-a)*opacity
		var center:Vector2=fx.center
		if w.reduced_motion:
			for at:Vector2 in fx.grounds:w._ellipse(at,Vector2(12,6),Color(P.GOLD,fade),2)
			continue
		match fx.key:
			"fire_frost":
				w._ellipse(center,Vector2(75,37)*(.3+a*.9),Color(P.COLORS.fire,fade),2.5)
				w._ellipse(center,Vector2(66,33)*(.45+a*.7),Color(P.COLORS.frost,fade),2.5)
			"fire_earth":
				for i:int in 8:
					var angle:=float(i)*TAU/8
					var v:=Vector2(cos(angle),sin(angle)*.5)
					var end:=center+v*(35+minf(a*3,1)*35)
					var path:=PackedVector2Array([center+v*10,center+v*30+Vector2(-6,4),center+v*44+Vector2(5,-3),end])
					w.draw_polyline(path,Color(.26,.12,.11,fade),5,true)
					w.draw_polyline(path,Color(1,.53,.15,fade),2,true)
			"storm_earth":
				for at:Vector2 in fx.root_grounds:
					w._ellipse(at,Vector2(15,7),Color(P.COLORS.earth,fade),2)
					for side:int in [-1,1]:
						w.draw_polyline(PackedVector2Array([at+Vector2(side*14,2),at+Vector2(side*10,-13),at+Vector2(side*16,-25),at+Vector2(side*5,-34)]),Color(P.COLORS.earth,fade),2.5,true)
func draw_air(w)->void:
	var opacity:float=TweakControls.value(&"environment.effect_opacity",1.0)
	for fx:Dictionary in active:
		var a:float=clampf(float(fx.age)/float(fx.life),0,1)
		var fade:float=(1-a)*opacity
		var parts:PackedStringArray=String(fx.key).split("_")
		var color:Color=P.COLORS["storm" if fx.key=="storm_earth" else parts[1]];color.a=fade
		if w.reduced_motion:
			for at:Vector2 in fx.points:_shard(w,at,color,7)
			continue
		var previous:Vector2=fx.origin
		for at:Vector2 in fx.points:
			match fx.key:
				"fire_storm":
					var mid:=previous.lerp(at,.5)
					w.draw_polyline(PackedVector2Array([previous,mid+Vector2(7,-9),mid+Vector2(-4,6),at]),Color(P.COLORS.fire,fade*.65),5,true)
					w.draw_polyline(PackedVector2Array([previous,mid+Vector2(7,-9),mid+Vector2(-4,6),at]),Color(.9,.8,1,fade),1.7,true)
					previous=at
				"frost_storm":
					for i:int in 5:
						var end:=at+Vector2((i-2)*7,0)
						var feather:=end+Vector2(18,-55)*(1-minf(a*2.5,1))
						w.draw_line(feather-Vector2(-5,14),feather,Color(.7,.66,1,fade*.5),1.5,true)
						_shard(w,feather,Color(.67,.91,1,fade),8)
				"fire_frost":
					for i:int in 6:
						var angle:=float(i)*TAU/6
						_shard(w,at+Vector2(cos(angle)*18,sin(angle)*10)*(.5+a),color,7)
				"fire_earth":
					for i:int in 4:_shard(w,at+Vector2((i-2)*9,-sin(a*PI)*22),Color(1,.65,.28,fade),5)
				"frost_earth":
					w._ellipse(at,Vector2(14,7),Color(.72,.94,1,fade),2)
				"storm_earth":
					w.draw_polyline(PackedVector2Array([at+Vector2(-11,8),at+Vector2(7,-4),at+Vector2(-4,-12),at+Vector2(10,-23)]),color,2,true)
