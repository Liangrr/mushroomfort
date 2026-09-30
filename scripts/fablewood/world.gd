class_name FablewoodWorld
extends Control
signal cell_clicked(cell: Vector2i)
const MergedAnim:=preload("res://scripts/fablewood/merged_animation.gd")
const UltimateEffects:=preload("res://scripts/fablewood/ultimate_effects.gd")
const MergeCelebration:=preload("res://scripts/fablewood/merge_celebration.gd")
const MeteorFX:=preload("res://scripts/fablewood/meteor_effects.gd")
var meteor_effects:=MeteorFX.new()
const MergedArt:=preload("res://scripts/fablewood/merged_art.gd")
const P := preload("res://scripts/fablewood/presentation.gd")
const GuardianAnim := preload("res://scripts/fablewood/guardian_animation.gd")
const EndpointAnim:=preload("res://scripts/fablewood/endpoint_animation.gd")
const EnemyAnim := preload("res://scripts/fablewood/enemy_animation.gd")
const LateVisuals:=preload("res://scripts/fablewood/late_enemy_visuals.gd")
const CombatParticles:=preload("res://scripts/fablewood/combat_particles.gd")
const OrganicTerrain:=preload("res://scripts/fablewood/organic_terrain.gd")
# Authored black top surface in the 256x256 platform image (not its root base).
const PAD_DRAW_SIZE:=Vector2(64,49)
const PAD_SOURCE_SIZE:=Vector2(256,256)
const PAD_ROOT_CONTACT:=Vector2(128,248)
const PAD_TOP_CENTER:=Vector2(126,138)
const PAD_TOP_RADII:=Vector2(70,27)
const TOWER_FOOTPRINT_CENTERS:={
	"fire":[Vector2(127.49,256.51),Vector2(127.21,273.34),Vector2(126,266)],
	"frost":[Vector2(127.05,259.18),Vector2(129.01,277.06),Vector2(125.79,285.41)],
	"storm":[Vector2(129.18,272.11),Vector2(127.09,259.34),Vector2(127.1,253.4)],
	"earth":[Vector2(126,255),Vector2(127.39,253.98),Vector2(127.28,252.25)],
}
const MusicImpact:=preload("res://scripts/fablewood/music_impact.gd")
var music_impact:=MusicImpact.new()
var terrain_layer:FablewoodOrganicTerrain
# Authored foot/underside pivots; weapons, wings and tails do not define contact.
const ENEMY_PIVOTS := {&"goblin":Vector2(112,248)/256.0,&"orc":Vector2(128,248)/256.0,&"troll":Vector2(100,248)/256.0,&"dragon":Vector2(160,248)/256.0}
var model: FablewoodBattle
var merge_active:=false
var merge_first:=-1
var merge_eligible:Array[int]=[]
var merge_pending_key:=""
var selected := -1
var selected_element := ""
var hovered := Vector2i(-99,-99)
var zoom := 1.0
var pan := Vector2.ZERO
var clock := 0.0
var _tower_motion:Dictionary={}
var _enemy_motion:Dictionary={}
var _enemy_tick_before:Dictionary={}
var _enemy_tick_valid:=false
var render_alpha:=1.0
var merged_animation:=MergedAnim.new()
var merge_celebration:=MergeCelebration.new()
var ultimate_effects:=UltimateEffects.new()
var combat_particles:=CombatParticles.new()
var _last_hit_fx:Dictionary={}
var effects: Array[Dictionary] = []
var reduced_motion := false
var presentation_paused := false
var _dragging := false
var _drag_start := Vector2.ZERO
var _drag_distance := 0.0
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _touch_primary := -1
var _touch_drag_distance := 0.0
var _touch_tap_allowed := false
var _origin := Vector2.ZERO
var _scale := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)
	_sync_terrain()

func _process(delta: float) -> void:
	if presentation_paused:music_impact.clear()
	else:music_impact.advance(delta,reduced_motion)
	_sync_terrain()
	if presentation_paused:
		queue_redraw()
		return
	clock += delta
	_advance_tower_animation(delta)
	merged_animation.advance(self,delta)
	merge_celebration.advance(delta,self)
	ultimate_effects.advance(delta,self)
	meteor_effects.advance(delta,self)
	if model!=null:EnemyAnim.advance(model,_enemy_motion,reduced_motion)
	combat_particles.advance(delta,self)
	for id:int in _last_hit_fx.keys():
		if model==null or not model.enemies[id].alive or model.tick-int(_last_hit_fx[id])>30:_last_hit_fx.erase(id)
	var keep: Array[Dictionary] = []
	for fx: Dictionary in effects:
		fx.life -= delta
		if float(fx.life) > 0.0:
			keep.append(fx)
	effects = keep
	queue_redraw()

func _sync_terrain()->void:
	if model==null:return
	if not is_instance_valid(terrain_layer):
		terrain_layer=OrganicTerrain.new();terrain_layer.name="OrganicTerrain";add_child(terrain_layer)
	terrain_layer.configure(model.stage,model.path_for(0))
	framing();terrain_layer.align_view(_origin,_scale)

func framing() -> void:
	var board := Rect2(-245.0,-35.0,665.0,350.0)
	_scale = minf(size.x / (board.size.x+45.0), size.y / (board.size.y+30.0)) * zoom
	_scale = maxf(_scale, 0.45)
	_origin = size*0.5 - board.get_center()*_scale + pan + music_impact.shake_offset()

func ground(c: Vector2, lifted: bool = false) -> Vector2:
	return Vector2((c.x-c.y)*32.0, (c.x+c.y)*16.0+32.0-(16.0 if lifted else 0.0))

func platform_rect(c:Vector2i)->Rect2:
	return Rect2(ground(Vector2(c),true)-PAD_ROOT_CONTACT/PAD_SOURCE_SIZE*PAD_DRAW_SIZE,PAD_DRAW_SIZE)

func platform_surface_center(c:Vector2i)->Vector2:
	return platform_rect(c).position+PAD_TOP_CENTER/PAD_SOURCE_SIZE*PAD_DRAW_SIZE

func platform_surface_radii()->Vector2:
	return PAD_TOP_RADII/PAD_SOURCE_SIZE*PAD_DRAW_SIZE

func cell_center(c: Vector2i) -> Vector2:
	if model.stage.is_elevated_platform(c):return platform_surface_center(c)
	return ground(Vector2(c)) - Vector2(0,16)

func screen_of(c: Vector2i) -> Vector2:
	framing()
	return _origin + cell_center(c)*_scale

func pick(at: Vector2) -> Vector2i:
	framing()
	var q := (at-_origin)/_scale
	var best := Vector2i(-99,-99)
	var distance := 999.0
	for y: int in model.stage.grid_size().y:
		for x: int in model.stage.grid_size().x:
			var c := Vector2i(x,y)
			if not model.stage.is_elevated_platform(c):
				continue
			var delta := q-cell_center(c)
			var metric := absf(delta.x)/38.0+absf(delta.y)/25.0
			if metric < 1.5 and metric < distance:
				distance=metric
				best=c
	return best

func change_zoom(multiplier: float, at: Vector2 = Vector2(-1,-1)) -> void:
	if at.x < 0: at=size*0.5
	framing()
	var before := (at-_origin)/_scale
	zoom = clampf(zoom*multiplier,0.7,1.85)
	framing()
	pan += at-(_origin+before*_scale)
	pan = pan.clamp(-size*0.55,size*0.55)
	queue_redraw()

func celebrate_music_entry()->void:
	framing()
	var at:=ground(Vector2(model.path_for(0)[-1]))-Vector2(0,55)
	# If the vault is outside the camera, let the visible roots answer the music.
	if not effect_visible(at):at=(size*Vector2(0.5,0.54)-_origin)/_scale
	music_impact.start(at,reduced_motion)
	queue_redraw()
func reset_view() -> void:
	zoom=1.0
	pan=Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if model == null: return
	# Godot normally emits mouse events as well as the original touch events.
	# The world owns native touch; counting the emulated mouse drag pans twice.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			change_zoom(1.1,event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			change_zoom(1.0/1.1,event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging=true
				_drag_start=event.position
				_drag_distance=0
			else:
				if _dragging and _drag_distance < 9: cell_clicked.emit(pick(event.position))
				_dragging=false
		accept_event()
	elif event is InputEventMouseMotion:
		hovered=pick(event.position)
		if _dragging:
			_drag_distance += event.relative.length()
			if _drag_distance>9: pan=(pan+event.relative).clamp(-size*0.55,size*0.55)
	elif event is InputEventMagnifyGesture:
		change_zoom(event.factor,event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touches.is_empty():
				_touch_primary=event.index;_touch_drag_distance=0.0;_touch_tap_allowed=true
			_touches[event.index]=event.position
			if _touches.size()>1:_touch_tap_allowed=false
		else:
			if _touches.size()==1 and _touches.has(event.index) and _touch_tap_allowed and _touch_drag_distance<9 and not event.canceled:
				cell_clicked.emit(pick(event.position))
			_touches.erase(event.index)
			_touch_tap_allowed=false
			_touch_primary=int(_touches.keys()[0]) if _touches.size()==1 else -1
			_touch_drag_distance=9.0
		_pinch_distance=0.0
		if _touches.size()==2:
			var points:=_touches.values()
			_pinch_distance=points[0].distance_to(points[1])
		accept_event()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):return
		_touches[event.index]=event.position
		if _touches.size()==2:
			var points := _touches.values()
			var distance: float = points[0].distance_to(points[1])
			if _pinch_distance>0: change_zoom(distance/_pinch_distance,(points[0]+points[1])*0.5)
			_pinch_distance=distance
		elif _touches.size()==1 and event.index==_touch_primary:
			_touch_drag_distance+=event.relative.length()
			if _touch_drag_distance>9:pan=(pan+event.relative).clamp(-size*0.55,size*0.55)
		accept_event()

func _draw() -> void:
	if model == null: return
	framing()
	draw_set_transform(_origin,0,Vector2.ONE*_scale)
	var route := model.path_for(0)
	for y: int in model.stage.grid_size().y:
		for x: int in model.stage.grid_size().x:
			var c:=Vector2i(x,y)
			var tile:=model.stage.tile_at(c)
			if tile==StageDef.Tile.VOID: continue
			var lifted:=model.stage.is_elevated_platform(c)
			var center:=cell_center(c)
			if lifted:
				draw_texture_rect(P.PAD,platform_rect(c),false)
				if model.alive_unit_at(c)==null:
					var active:=selected_element!=""
					var color:=P.GOLD if active else Color("b4a782")
					draw_line(center+Vector2(-4,0),center+Vector2(4,0),color,1.8)
					draw_line(center+Vector2(0,-4),center+Vector2(0,4),color,1.8)
					if active or hovered==c: _ellipse(center,platform_surface_radii(),Color(color,0.7),1.1)
	ultimate_effects.draw_ground(self)
	meteor_effects.draw_ground(self)
	merge_celebration.draw_ground(self)
	combat_particles.draw_ground(self,float(TweakControls.value(&"environment.effect_opacity",1.0)))
	var unit:=model.unit_by_id(selected)
	if unit!=null and unit.alive:
		var c:=cell_center(unit.cell)
		var r:=float(model.range_for(unit))*35.0
		_ellipse(c,Vector2(r,r*0.5),Color(P.COLORS[model.element(unit)],0.48),1.3)
		_ellipse(c,platform_surface_radii(),P.COLORS[model.element(unit)],1.4)
	var actors: Array[Dictionary]=[]
	actors.append({"pos":ground(Vector2(route[0])),"type":"gate"})
	actors.append({"pos":ground(Vector2(route[-1])),"type":"vault"})
	for u: UnitState in model.units:
		if u.alive:actors.append({"pos":platform_surface_center(u.cell),"sort_y":ground(Vector2(u.cell),true).y,"type":"tower","u":u})
	for e: EnemyState in model.enemies:
		if e.alive:
			var position:=Pathing.position_of(model.path_for(e.path_idx),rendered_enemy_progress(e))
			actors.append({"pos":route_center(position),"type":"enemy","e":e})
	actors.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.get("sort_y",a.pos.y))<float(b.get("sort_y",b.pos.y)))
	for a: Dictionary in actors:
		var pos:Vector2=a.pos
		match a.type:
			"gate":_draw_endpoint("gate",pos)
			"vault":_draw_endpoint("vault",pos)
			"tower":
				var u:UnitState=a.u
				if model.is_merged(u):
					_draw_merged_tower(u);continue
				var level:=model.tier(u)
				if reduced_motion:
					draw_texture_rect(P.GUARDIANS[model.element(u)][level-1],tower_draw_rect(u,false),false)
				else:
					var state:Dictionary=_tower_motion.get(u.id,{})
					var energy:=1.0+float(state.get("burst",0.0))*0.18
					var texture:=GuardianAnim.frame(model.element(u),level,float(state.get("phase",clock)))
					draw_texture_rect(texture,tower_draw_rect(u,true),false,Color(energy,energy,energy))
				for i: int in level:draw_circle(pos+Vector2((i-(level-1)*0.5)*7,5),2.0,P.COLORS[model.element(u)])
			"enemy":_draw_enemy(a.e,pos)
	_draw_merge_overlay()
	for fx:Dictionary in effects:
		_draw_effect(fx)
	combat_particles.draw_air(self,float(TweakControls.value(&"environment.effect_opacity",1.0)))
	ultimate_effects.draw_air(self)
	meteor_effects.draw_air(self)
	merge_celebration.draw_air(self)
	music_impact.draw(self)
	draw_set_transform(Vector2.ZERO)

func endpoint_draw_rect(endpoint:String,at:Vector2,_animated:bool)->Rect2:
	var dimensions:=(Vector2(85,101) if endpoint=="gate" else Vector2(125,140))*EndpointAnim.DISPLAY_EXPANSION
	var pivot:=EndpointAnim.ANCHOR/Vector2(EndpointAnim.CELL)
	return Rect2(at-pivot*dimensions,dimensions)

func _draw_endpoint(endpoint:String,at:Vector2)->void:
	var texture:=EndpointAnim.frame(endpoint,0.0 if reduced_motion else clock)
	draw_texture_rect(texture,endpoint_draw_rect(endpoint,at,not reduced_motion),false)

func _draw_sprite(texture: Texture2D, at:Vector2, dimensions:Vector2, flip:bool=false, tint:Color=Color.WHITE, anchor:float=248.0/256.0) -> void:
	var rect:=Rect2(at-Vector2(dimensions.x*0.5,dimensions.y*anchor),dimensions)
	if flip:
		rect.position.x+=dimensions.x
		rect.size.x=-dimensions.x
	draw_texture_rect(texture,rect,false,tint)

func route_center(position:Vector2)->Vector2:
	# Route coordinates interpolate between tile centers, without boundary snapping.
	return ground(position)-Vector2(0,16)

func capture_enemy_tick()->void:
	# Keep one authoritative tick of history, not an unbounded position trail.
	_enemy_tick_before.clear()
	for e:EnemyState in model.enemies:
		if e.alive:_enemy_tick_before[e.id]=e.progress_units
	_enemy_tick_valid=true

func rendered_enemy_progress(e:EnemyState)->int:
	if not _enemy_tick_valid:return e.progress_units
	var before:=int(_enemy_tick_before.get(e.id,e.progress_units))
	# Teleports/reversed progress are not ordinary forward locomotion.
	if e.progress_units<before or e.progress_units-before>Pathing.PROGRESS_SCALE:return e.progress_units
	return roundi(lerpf(float(before),float(e.progress_units),clampf(render_alpha,0.0,1.0)))

func rendered_enemy_phase(e:EnemyState)->float:
	if LateVisuals.is_late(e.def_id):
		# Late sheets are locomotion-driven from the rendered authoritative path
		# progress. They therefore stop on pause, freeze and a stationary segment.
		return LateVisuals.normalized_phase_for_progress(rendered_enemy_progress(e),e.def_id)
	var phase:=float(_enemy_motion.get(e.id,{"phase":0.0}).phase)
	var actual:=e.progress_units;var shown:=rendered_enemy_progress(e)
	if not e.aerial:
		var stop_at:=Pathing.length_units(model.path_for(e.path_idx))-Pathing.PROGRESS_SCALE
		actual=mini(actual,stop_at);shown=mini(shown,stop_at)
	var lag:=maxf(0.0,float(actual-shown)/Pathing.PROGRESS_SCALE)
	return fposmod(phase-lag*float(EnemyAnim.CYCLES_PER_TILE[e.def_id])*EnemyAnim.DURATION,EnemyAnim.DURATION)

func enemy_ground_position(e:EnemyState)->Vector2:
	return route_center(Pathing.position_of(model.path_for(e.path_idx),rendered_enemy_progress(e)))

func enemy_faces_left(e:EnemyState)->bool:
	var path:=model.path_for(e.path_idx)
	if path.size()<2:return false
	# Follow the segment actually being rendered: no look-ahead turn snapping.
	var segment:=mini(floori(float(rendered_enemy_progress(e))/Pathing.PROGRESS_SCALE),path.size()-2)
	var direction:=path[segment+1]-path[segment]
	return direction.x-direction.y<0

func enemy_segment_displacement(e:EnemyState)->Vector2i:
	var path:=model.path_for(e.path_idx)
	if path.size()<2:return Vector2i(0,-1)
	# Like legacy facing, use the segment being rendered rather than a future
	# waypoint; this prevents a turn from snapping early during interpolation.
	var segment:=mini(floori(float(rendered_enemy_progress(e))/Pathing.PROGRESS_SCALE),path.size()-2)
	return path[segment+1]-path[segment]

func enemy_sprite_transform(at:Vector2,flip:bool)->Transform2D:
	# Mirror about the visible contact point exactly once; never offset by a width.
	return Transform2D(Vector2(-_scale if flip else _scale,0),Vector2(0,_scale),_origin+at*_scale)

func _draw_enemy(e:EnemyState, pos:Vector2) -> void:
	if LateVisuals.is_late(e.def_id):
		_draw_late_enemy(e,pos)
		return
	var h:float={&"goblin":34.0,&"orc":44.0,&"troll":62.0,&"dragon":78.0}.get(e.def_id,40.0)
	h *= float(TweakControls.value(&"enemies.visual_scale",1.0))
	var floating:=21.0 if e.aerial else 0.0
	_ellipse(pos,Vector2(h*0.22,3),Color(0,0,0,0.32),2.3)
	var tint:=Color.WHITE
	if model.tick<int(model.slow_until.get(e.id,0)):tint=Color("a1e4ff")
	if model.tick-e.last_damage_tick<4:tint=Color("ffcfb5")
	var contact:=pos-Vector2(0,floating)
	var phase:=0.0 if reduced_motion else rendered_enemy_phase(e)
	var dimensions:=Vector2.ONE*h*EnemyAnim.DISPLAY_EXPANSION
	var pivot:=EnemyAnim.ANCHOR/EnemyAnim.CELL
	var directional:=EnemyAnim.has_directions(e.def_id)
	var facing:=String(LateVisuals.facing_for_displacement(enemy_segment_displacement(e)))
	draw_set_transform_matrix(enemy_sprite_transform(contact,not directional and enemy_faces_left(e)))
	draw_texture_rect(EnemyAnim.frame(e.def_id,phase,facing),Rect2(-pivot*dimensions,dimensions),false,tint)
	draw_set_transform(_origin,0,Vector2.ONE*_scale)
	var bar:=Rect2(pos+Vector2(-h*0.29,-h-floating-5),Vector2(h*0.58,3.5))
	draw_rect(bar,Color("151421"))
	bar.size.x*=clampf(float(e.hp)/e.hp_max,0,1)
	draw_rect(bar,Color("c88ade") if e.aerial else Color("9bc987"))

func _draw_late_enemy(e:EnemyState,pos:Vector2)->void:
	var scale:=float(TweakControls.value(&"enemies.visual_scale",1.0))
	var dimensions:=LateVisuals.dimensions(e.def_id)*scale
	var phase:=0.0 if reduced_motion else rendered_enemy_phase(e)
	var floating:=21.0 if e.aerial else 0.0
	# The small flight bob shares model-derived movement phase, so it never keeps
	# moving while combat is paused or while a freeze has stopped the Harrier.
	if e.def_id==&"harrier" and not reduced_motion:
		floating+=sin(phase/LateVisuals.NORMALIZED_DURATION*TAU)*2.0
	var contact:=pos-Vector2(0,floating)
	var state:Dictionary=model.late_enemies.info(e.id)
	if not e.aerial:
		_ellipse(pos,Vector2(dimensions.x*.23,3.5),Color(0,0,0,0.32),2.3)
	else:
		_ellipse(pos,Vector2(dimensions.x*.18,2.8),Color(0,0,0,0.24),1.8)
	var tint:=Color.WHITE
	if model.tick<int(model.slow_until.get(e.id,0)):tint=Color("a1e4ff")
	if model.tick-e.last_damage_tick<4:tint=Color("ffcfb5")
	var facing:=LateVisuals.facing_for_displacement(enemy_segment_displacement(e))
	var texture:=LateVisuals.frame(e.def_id,facing,phase)
	if texture!=null:
		# Pages are final directional artwork; Broodmother NE is an offline reflection
		# of its symmetric NW rear view. Never apply another runtime mirror.
		draw_set_transform_matrix(enemy_sprite_transform(contact,false))
		draw_texture_rect(texture,Rect2(-LateVisuals.anchor(e.def_id)*dimensions,dimensions),false,tint)
		draw_set_transform(_origin,0,Vector2.ONE*_scale)
	else:
		# Atlas delivery may race a running editor session. Retain only an intentional
		# tactical marker rather than substituting pre-existing enemy art.
		var marker:=Color("7dd8eb") if e.def_id==&"prismback" else Color("edb86c") if e.def_id==&"broodmother" else Color("8edeee")
		_ellipse(contact-Vector2(0,dimensions.y*.42),Vector2(dimensions.x*.18,dimensions.y*.12),Color(marker,.82),1.8)
	_draw_late_telegraph(e,pos,contact,dimensions,state)
	_draw_late_health_and_shell(e,pos,dimensions,floating,state)

func _draw_late_telegraph(e:EnemyState,pos:Vector2,contact:Vector2,dimensions:Vector2,state:Dictionary)->void:
	if e.def_id==&"prismback" and int(state.get("shell",0))>0:
		# A low crystal rim makes the protected state legible without obscuring the
		# grounded silhouette or the separate shell meter.
		_ellipse(pos-Vector2(0,2),Vector2(dimensions.x*.31,dimensions.y*.075),Color("62d7ef",.9),1.55)
		_ellipse(pos-Vector2(0,2),Vector2(dimensions.x*.25,dimensions.y*.055),Color("a68cff",.55),1.0)
	elif e.def_id==&"harrier":
		var mode:=int(state.get("mode",0))
		if mode==1:
			var center:=contact-Vector2(0,dimensions.y*.48)
			draw_arc(center,dimensions.x*.38,0,TAU,24,Color("f4cf75",.95),2.0,true)
			for i:int in 3:
				var angle:=float(i)*TAU/3.0-PI*.5
				var at:=center+Vector2(cos(angle),sin(angle))*dimensions.x*.38
				draw_circle(at,2.4,Color("fff0af",.95))
		elif mode==2:
			var direction:=Vector2(enemy_segment_displacement(e)).normalized()
			var trail:=Vector2(direction.x-direction.y,(direction.x+direction.y)*.5).normalized()
			if trail.length_squared()>0:
				draw_line(contact+trail*dimensions.x*.14,contact-trail*dimensions.x*.52,Color("d7fbff",.75),2.4,true)
				draw_line(contact+trail*dimensions.x*.04,contact-trail*dimensions.x*.34+Vector2(0,5),Color("54cce8",.8),1.35,true)
	elif e.def_id==&"broodmother" and bool(state.get("warned",false)):
		# Amber pod tell: a fixed, readable warning in reduced-motion too.
		var pod:=contact-Vector2(0,dimensions.y*.48)
		for i:int in 3:
			var offset:=Vector2((i-1)*dimensions.x*.14,absf(float(i-1))*3.0)
			draw_circle(pod+offset,3.4,Color("ffc35a",.95))
			draw_arc(pod,dimensions.x*.32,-PI*.9,PI*.15,12,Color("e29a38",.85),1.45,true)

func _draw_late_health_and_shell(e:EnemyState,pos:Vector2,dimensions:Vector2,floating:float,state:Dictionary)->void:
	var width:=maxf(31.0,dimensions.x*.62)
	var facing:=LateVisuals.facing_for_displacement(enemy_segment_displacement(e))
	var top:=pos.y-dimensions.y*LateVisuals.visible_height_ratio(e.def_id,facing)-floating-5.0
	var health:=Rect2(Vector2(pos.x-width*.5,top),Vector2(width,3.6))
	draw_rect(health.grow(1.2),Color("10121c",.9))
	draw_rect(health,Color("31283d") if e.aerial else Color("263b31"))
	draw_rect(Rect2(health.position,Vector2(health.size.x*clampf(float(e.hp)/maxi(1,e.hp_max),0,1),health.size.y)),Color("c88ade") if e.aerial else Color("9bc987"))
	if e.def_id!=&"prismback":return
	var shell_max:=maxi(1,int(state.get("shell_max",0)))
	var shell:=clampf(float(int(state.get("shell",0)))/shell_max,0,1)
	var shell_bar:=Rect2(Vector2(pos.x-width*.5,top-7.0),Vector2(width,3.2))
	draw_rect(shell_bar.grow(1.1),Color("0e1620",.96))
	draw_rect(shell_bar,Color("263a52",.95))
	draw_rect(Rect2(shell_bar.position,Vector2(shell_bar.size.x*shell,shell_bar.size.y)),Color("62d7ef") if shell>0 else Color("30455b"))

func enemy_art_bounds(e:EnemyState,at:Vector2=Vector2.INF)->Rect2:
	var ground_at:=enemy_ground_position(e) if at==Vector2.INF else at
	if LateVisuals.is_late(e.def_id):
		var dimensions:=LateVisuals.dimensions(e.def_id)*float(TweakControls.value(&"enemies.visual_scale",1.0))
		var floating:=21.0 if e.aerial else 0.0
		return Rect2(ground_at-Vector2(0,floating)-LateVisuals.anchor(e.def_id)*dimensions,dimensions)
	var h:float={&"goblin":34.0,&"orc":44.0,&"troll":62.0,&"dragon":78.0}.get(e.def_id,40.0)
	h*=float(TweakControls.value(&"enemies.visual_scale",1.0))
	var dimensions:=Vector2.ONE*h*EnemyAnim.DISPLAY_EXPANSION
	return Rect2(ground_at-Vector2(0,21.0 if e.aerial else 0.0)-EnemyAnim.ANCHOR/EnemyAnim.CELL*dimensions,dimensions)

func _ellipse(center:Vector2, radii:Vector2, color:Color, width:float) -> void:
	var points:=PackedVector2Array()
	for i: int in 49:
		var angle:=float(i)/48.0*TAU
		points.append(center+Vector2(cos(angle),sin(angle))*radii)
	draw_polyline(points,color,width,true)

func effect_visible(at:Vector2)->bool:
	framing()
	return Rect2(Vector2(-35,-70),size+Vector2(70,100)).has_point(_origin+at*_scale)
func enemy_hit_point(e:EnemyState)->Vector2:
	if LateVisuals.is_late(e.def_id):
		var bounds:=enemy_art_bounds(e)
		return bounds.position+Vector2(bounds.size.x*.5,bounds.size.y*.42)
	var h:float={&"goblin":34.0,&"orc":44.0,&"troll":62.0,&"dragon":78.0}.get(e.def_id,40.0)
	h*=float(TweakControls.value(&"enemies.visual_scale",1.0))
	return enemy_ground_position(e)-Vector2(0,h*0.48+(21.0 if e.aerial else 0.0))
func tower_draw_rect(u:UnitState,animated:bool)->Rect2:
	if model.is_merged(u):return MergedArt.rect(model.merge_key(u),platform_surface_center(u.cell),MergedArt.height_for(model.merge_key(u))*float(TweakControls.value(&"player.visual_scale",1.0)))
	var level:=model.tier(u)
	var h:float=[60.0,77.0,94.0][level-1]*float(TweakControls.value(&"player.visual_scale",1.0))
	var dimensions:=Vector2(h*0.8,h)
	# New static/idle art shares one normalized contact canvas.
	if model.element(u) in ["fire","frost","storm","earth"]:
		dimensions*=GuardianAnim.DISPLAY_EXPANSION
		return Rect2(platform_surface_center(u.cell)-Vector2(96,211)/GuardianAnim.CELL*dimensions,dimensions)
	var point:Vector2=TOWER_FOOTPRINT_CENTERS[model.element(u)][level-1]
	if animated:
		# The existing atlas adds (32,40) padding to the 256x320 source.
		point=(point+Vector2(32,40))/Vector2(320,400)
		dimensions*=GuardianAnim.DISPLAY_EXPANSION
	else:point/=Vector2(256,320)
	return Rect2(platform_surface_center(u.cell)-point*dimensions,dimensions)

func tower_emission_point(u:UnitState)->Vector2:
	var rect:=tower_draw_rect(u,false)
	# Original source-space emission point, transformed with the same footprint.
	return rect.position+Vector2(0.5,0.51 if model.is_all_element(u) else 0.275)*rect.size
func add_event(ev:Dictionary) -> void:
	if ev.kind=="meteor_impact":
		meteor_effects.trigger(ev,self);return
	if ev.kind=="meteor_launch":return
	if ev.kind=="ultimate":
		ultimate_effects.trigger(ev,self);return
	if ev.kind=="merge_placed":
		merge_celebration.trigger(ev,self);return
	if ev.kind=="merge_prepare":
		var centers:Array[Vector2]=[cell_center(ev.cell),cell_center(ev.get("second_cell",ev.cell))]
		for i:int in 2:
			if not effect_visible(centers[i]):continue
			var element:String=ev.element if i==0 else ev.second_element
			if not reduced_motion:combat_particles.upgrade_burst(centers[i],element)
			effects.append({"kind":"ascend","at":centers[i],"element":element,"life":1.1,"duration":1.1})
		return
	if not audio_visible(ev):return
	if effects.size()>=90:effects.pop_front()
	if ev.kind=="shell_break":
		var cracked:=enemy_ground_position(model.enemies[ev.enemy])
		effects.append({"kind":"shell_crack","at":cracked,"life":.48,"duration":.48})
	elif ev.kind=="shell_restore":
		var restored:=enemy_ground_position(model.enemies[ev.enemy])
		effects.append({"kind":"shell_restore","at":restored,"life":.65,"duration":.65})
	elif ev.kind=="brood_spawn":
		var mother:=enemy_ground_position(model.enemies[ev.enemy])
		effects.append({"kind":"brood_spawn","at":mother,"life":.58,"duration":.58})
	elif ev.kind in ["shell_hit","harrier_tell","harrier_dash","brood_tell"]:
		# Persistent bars and state-led telegraphs communicate these transitions.
		# They are deliberately not one-shot audio paths or replaying particle lists.
		return
	elif ev.kind=="attack":
		var u:=model.unit_by_id(ev.unit)
		if u==null:return
		var from:=tower_emission_point(u)
		for id:int in ev.hits:
			var e:EnemyState=model.enemies[id]
			var to:=enemy_hit_point(e)
			effects.append({"kind":"bolt","element":ev.element,"from":from,"to":to,"life":0.32,"duration":0.32})
			if not reduced_motion:
				combat_particles.muzzle(from,to,ev.element)
				if effect_visible(to):combat_particles.burst(to,ev.element,8 if ev.element!="earth" else 11,30.0)
	elif ev.kind=="damage":
		var e:EnemyState=model.enemies[ev.enemy]
		if model.tick-int(_last_hit_fx.get(e.id,-1000))<3 and not bool(ev.killed):return
		_last_hit_fx[e.id]=model.tick
		combat_particles.blood(enemy_hit_point(e),enemy_ground_position(e),int(ev.amount),bool(ev.killed),reduced_motion)
	elif ev.kind=="upgrade":
		var center:=cell_center(ev.cell)
		effects.append({"kind":"ascend","at":center,"element":ev.element,"life":1.1,"duration":1.1})
		if not reduced_motion:combat_particles.upgrade_burst(center,ev.element)
	elif ev.kind=="build":
		effects.append({"kind":"bloom","at":cell_center(ev.cell),"element":ev.element,"life":0.75,"duration":0.75})
		if not reduced_motion:combat_particles.burst(cell_center(ev.cell)-Vector2(0,12),ev.element,7,24.0)
	elif ev.kind=="enemy":
		var e:EnemyState=model.enemies[ev.enemy]
		effects.append({"kind":"ink","at":enemy_ground_position(e),"life":0.45,"duration":0.45})
	while effects.size()>90:effects.pop_front()
func _draw_effect(fx:Dictionary) -> void:
	var age:=1.0-float(fx.life)/float(fx.duration)
	if fx.kind=="bolt":
		var col:Color=P.COLORS[fx.element]
		col.a = float(TweakControls.value(&"environment.effect_opacity",1.0))
		var a:Vector2=fx.from
		var b:Vector2=fx.to
		if reduced_motion:
			_ellipse(b,Vector2(7,4),Color(col,(1-age)*col.a),1.8)
			return
		if fx.element=="storm":
			var mid:=a.lerp(b,0.5)+Vector2(5,-8)
			draw_polyline(PackedVector2Array([a,mid,a.lerp(b,0.65)+Vector2(-5,3),b]),Color(col,(1.0-age)*col.a),2.2,true)
		else:
			var p:=a.lerp(b,minf(age*2.0,1.0))
			if fx.element=="earth":p.y-=sin(minf(age*2,1)*PI)*25
			draw_circle(p,3.8 if fx.element=="earth" else 3.0,Color(col,(1-age)*col.a))
		if age>0.35:_ellipse(b,Vector2(7,4)*(0.4+age*1.8),Color(col,(1-age)*col.a),1.6)
	elif fx.kind=="ascend":
		var opacity:=float(TweakControls.value(&"environment.effect_opacity",1.0))
		var color:Color=P.COLORS[fx.element]
		var fade:float=(1.0-age)*opacity
		if reduced_motion:
			_ellipse(fx.at,Vector2(30,13),Color(P.GOLD,fade*0.75),2)
		else:
			var expansion:=1.0-pow(1.0-age,3.0)
			_ellipse(fx.at,Vector2(24,11)*(1.0+expansion*1.1),Color(P.GOLD,fade*0.8),2.0)
			_ellipse(fx.at-Vector2(0,expansion*38),Vector2(18,8)*(1.0+expansion*0.45),Color(color,fade*0.75),1.6)
	elif fx.kind=="bloom":
		var color:Color=P.COLORS[fx.element]
		_ellipse(fx.at,Vector2(28,14)*(1+age),Color(color,1-age),2)
		if not reduced_motion:
			for i:int in 8:
				var a:=float(i)*TAU/8
				draw_circle(fx.at+Vector2(cos(a)*25*age,sin(a)*12*age-30*age),1.8,Color(color,1-age))
	elif fx.kind=="ink":
		for i:int in 5:
			var a:=float(i)*TAU/5
			draw_circle(fx.at+Vector2(cos(a),sin(a))*age*16,3*(1-age),Color("ba82d8"))
	elif fx.kind=="shell_crack":
		var opacity:float=(1-age)*float(TweakControls.value(&"environment.effect_opacity",1.0))
		for i:int in 5:
			var angle:=float(i)*TAU/5.0
			var start:Vector2=fx.at+Vector2(cos(angle),sin(angle)*.45)*5
			var end:Vector2=fx.at+Vector2(cos(angle+.32),sin(angle+.32)*.45)*(12+age*18)
			draw_line(start,end,Color("b6efff",opacity),1.65,true)
	elif fx.kind=="shell_restore":
		var fade:float=(1-age)*float(TweakControls.value(&"environment.effect_opacity",1.0))
		_ellipse(fx.at,Vector2(17,7)*(1+age*1.4),Color("72ddee",fade),1.65)
	elif fx.kind=="brood_spawn":
		var fade:float=(1-age)*float(TweakControls.value(&"environment.effect_opacity",1.0))
		for i:int in 6:
			var angle:=float(i)*TAU/6.0
			var point:Vector2=fx.at+Vector2(cos(angle)*22*age,sin(angle)*9*age-8*age)
			draw_circle(point,2.4*(1-age),Color("f1ad4d",fade))

func audio_visible(ev:Dictionary) -> bool:
	if ev.kind in ["wave","cleared","breach","victory","defeat"]:return true
	framing()
	var at:=Vector2.ZERO
	if ev.has("cell"):
		at=cell_center(ev.cell)
	elif ev.has("enemy"):
		var e:EnemyState=model.enemies[ev.enemy]
		at=enemy_ground_position(e)
	else:return false
	return Rect2(Vector2(-35,-70),size+Vector2(70,100)).has_point(_origin+at*_scale)

func late_audio_visible(ev:Dictionary)->bool:
	# Passed as an SFX audibility callback so a source stops once pause, camera
	# movement, or enemy cleanup makes it inaudible. Normal legacy cues retain
	# their established one-shot behavior.
	return is_inside_tree() and not presentation_paused and model!=null and audio_visible(ev)

func _advance_tower_animation(delta:float)->void:
	if model==null:return
	var live:Dictionary={}
	for u:UnitState in model.units:
		if not u.alive:continue
		live[u.id]=true
		if not _tower_motion.has(u.id):
			_tower_motion[u.id]={"phase":fposmod(float(u.id)*0.37,GuardianAnim.DURATION),"burst":0.0,"last_attack":-1}
		var state:Dictionary=_tower_motion[u.id]
		if reduced_motion:continue
		if u.last_attack_tick>=0 and u.last_attack_tick!=int(state.last_attack):
			state.last_attack=u.last_attack_tick
			state.burst=1.0
		state.phase=fposmod(float(state.phase)+delta*(1.0+float(state.burst)*1.6),GuardianAnim.DURATION)
		state.burst=maxf(0.0,float(state.burst)-delta*2.5)
	for id:int in _tower_motion.keys():
		if not live.has(id):_tower_motion.erase(id)

func _exit_tree()->void:
	meteor_effects.clear()
	ultimate_effects.clear()
	merged_animation.clear()
	merge_celebration.clear()
	music_impact.clear()
	_enemy_tick_before.clear()
	_enemy_motion.clear()
	_tower_motion.clear()
	_last_hit_fx.clear()
	combat_particles.clear()

func _draw_merged_tower(u:UnitState)->void:
	var key:=model.merge_key(u);var center:=platform_surface_center(u.cell)
	if reduced_motion:
		draw_texture_rect(MergedArt.DATA[key].texture,tower_draw_rect(u,false),false)
	else:
		var motion:Dictionary=merged_animation.states.get(u.id,{"idle":0.0,"cast":0.0,"weight":0.0})
		var rect:=MergedAnim.rect(key,center,MergedArt.height_for(key)*float(TweakControls.value(&"player.visual_scale",1.0)))
		var weight:=float(motion.weight)
		draw_texture_rect(MergedAnim.frame(key,false,float(motion.idle)),rect,false,Color(1,1,1,1-weight))
		if weight>0:draw_texture_rect(MergedAnim.frame(key,true,float(motion.cast)),rect,false,Color(1,1,1,weight))
		if weight>0 and weight<1:
			# Repaint the rigid base from the source during the short alpha crossfade.
			var base:=tower_draw_rect(u,false);var canvas:=MergedArt.canvas_for(key);var ratio:=base.size.y/canvas.y
			var y:=float(MergedArt.DATA[key].get("foundation_y",400.0));var region:=Rect2(0,y,canvas.x,canvas.y-y)
			draw_texture_rect_region(MergedArt.DATA[key].texture,Rect2(base.position+region.position*ratio,region.size*ratio),region)
	var parts:=MergedArt.elements(key)
	for i:int in parts.size():
		var phase:=(0.0 if reduced_motion else clock*.8)+float(i)*TAU/float(parts.size())
		var offset:=Vector2(cos(phase)*13,sin(phase)*5)
		var color:Color=P.COLORS[parts[i]];color.a=.65
		draw_circle(center+offset-Vector2(0,28),2.0,color)
	var ultimate:Dictionary=model.ultimates.info(u.id)
	if not ultimate.is_empty():
		var charge:=1.0-float(ultimate.remaining)/float(ultimate.period)
		var meter:=Rect2(center+Vector2(-17,9),Vector2(34,4))
		draw_rect(meter.grow(1),Color("171c26"))
		var segment:=34.0/float(parts.size())
		for i:int in parts.size():
			var filled:=clampf(charge*parts.size()-i,0,1)
			draw_rect(Rect2(meter.position+Vector2(i*segment,0),Vector2(segment*filled,4)),P.COLORS[parts[i]])
		if int(ultimate.remaining)==0:_ellipse(center+Vector2(0,11),Vector2(21,5),P.GOLD,1.0)
	if u.id==selected:_ellipse(center,platform_surface_radii(),P.GOLD,2.0)
func _draw_merge_overlay()->void:
	if not merge_active:return
	if merge_pending_key!="":
		for y:int in model.stage.grid_size().y:
			for x:int in model.stage.grid_size().x:
				var cell:=Vector2i(x,y)
				if model.can_place_merge(cell):_ellipse(platform_surface_center(cell),platform_surface_radii(),Color(1,.84,.4,.5),1.5)
		if model.can_place_merge(hovered):
			var rect:=MergedArt.rect(merge_pending_key,platform_surface_center(hovered),MergedArt.height_for(merge_pending_key)*float(TweakControls.value(&"player.visual_scale",1.0)))
			draw_texture_rect(MergedArt.DATA[merge_pending_key].texture,rect,false,Color(1,1,1,.65))
	else:
		for id:int in merge_eligible:
			var u:=model.unit_by_id(id)
			if u!=null and u.alive:_ellipse(platform_surface_center(u.cell),platform_surface_radii()*1.1,P.GOLD if id==merge_first else Color(.4,1,.8,.9),3.0 if id==merge_first else 2.0)
