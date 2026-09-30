class_name FablewoodEnemyAnimation
extends RefCounted
const AtlasLayout := preload("res://scripts/fablewood/atlas_layout.gd")
## Visual state only: no collision, damage, speed, rewards or simulation writes.
const LateVisuals:=preload("res://scripts/fablewood/late_enemy_visuals.gd")
const CELL:=Vector2(256,256)
const ANCHOR:=Vector2(128,224)
const COLUMNS:=8
const FRAME_COUNT:=48
const FPS:=24.0
const DURATION:=2.0
const DISPLAY_EXPANSION:=1.5
const CYCLES_PER_TILE:={&"goblin":2.8800000000,&"orc":1.9200000000,&"troll":1.9764705882,&"dragon":0.65}
const SHEETS:={
	&"goblin":preload("res://assets/template/InvadersIlluminated/goblin/SE.webp"),
	&"orc":preload("res://assets/template/InvadersIlluminated/orc/SE.webp"),
	&"troll":preload("res://assets/template/InvadersIlluminated/troll/SE.webp"),
	&"dragon":preload("res://assets/template/InvadersIlluminated/dragon/SE.webp")
}
const DIRECTIONAL:={
	&"orc":{"NE":preload("res://assets/template/InvadersIlluminated/orc/NE.webp"),"SE":preload("res://assets/template/InvadersIlluminated/orc/SE.webp"),"NW":preload("res://assets/template/InvadersIlluminated/orc/NW.webp"),"SW":preload("res://assets/template/InvadersIlluminated/orc/SW.webp")},
	&"dragon":{
		"NE":preload("res://assets/template/InvadersIlluminated/dragon/NE.webp"),
		"SE":preload("res://assets/template/InvadersIlluminated/dragon/SE.webp"),
		"NW":preload("res://assets/template/InvadersIlluminated/dragon/NW.webp"),
		"SW":preload("res://assets/template/InvadersIlluminated/dragon/SW.webp")
	},
	&"troll":{
		"NE":preload("res://assets/template/InvadersIlluminated/troll/NE.webp"),
		"SE":preload("res://assets/template/InvadersIlluminated/troll/SE.webp"),
		"NW":preload("res://assets/template/InvadersIlluminated/troll/NW.webp"),
		"SW":preload("res://assets/template/InvadersIlluminated/troll/SW.webp")
	},
	&"goblin":{
		"NE":preload("res://assets/template/InvadersIlluminated/goblin/NE.webp"),
		"SE":preload("res://assets/template/InvadersIlluminated/goblin/SE.webp"),
		"NW":preload("res://assets/template/InvadersIlluminated/goblin/NW.webp"),
		"SW":preload("res://assets/template/InvadersIlluminated/goblin/SW.webp")
	}
}
static var _frames:Dictionary={}
static func has_directions(kind:StringName)->bool:
	return DIRECTIONAL.has(kind)
static func frame_index(seconds:float)->int:
	return posmod(floori(seconds*FPS),FRAME_COUNT)
static func region(index:int)->Rect2:
	var i:=posmod(index,FRAME_COUNT)
	return Rect2(Vector2(i%COLUMNS,floori(float(i)/COLUMNS))*CELL,CELL)
static func frame(kind:StringName,seconds:float,facing:String="SE")->AtlasTexture:
	var key:="%s_%s"%[kind,facing if has_directions(kind) else "legacy"]
	if not _frames.has(key):
		var sequence:Array[AtlasTexture]=[]
		var sheet:Texture2D=DIRECTIONAL[kind][facing] if has_directions(kind) else SHEETS[kind]
		for i:int in FRAME_COUNT:
			var texture:=AtlasLayout.texture(sheet,sheet.resource_path,i,CELL,COLUMNS)
			sequence.append(texture)
		_frames[key]=sequence
	return _frames[key][frame_index(seconds)]
static func advance(model:FablewoodBattle,motion:Dictionary,reduced:bool)->void:
	var live:Dictionary={}
	for e:EnemyState in model.enemies:
		if not e.alive:continue
		live[e.id]=true
		# Directional late-enemy sheets derive their whole phase from rendered model
		# progress in FablewoodLateEnemyVisuals. Keep the legacy dictionary out of
		# that path so these IDs never index the old animation tables.
		if LateVisuals.is_late(e.def_id):continue
		if not motion.has(e.id):motion[e.id]={"phase":fposmod(float(e.id)*0.23,DURATION),"progress":e.progress_units}
		var state:Dictionary=motion[e.id]
		var previous:=int(state.progress)
		state.progress=e.progress_units
		if reduced or e.progress_units<=previous:continue
		# Ground actors stop animating when path rendering reaches its final center.
		var stop_at:=Pathing.length_units(model.path_for(e.path_idx))-Pathing.PROGRESS_SCALE
		var distance:=e.progress_units-previous if e.aerial else mini(e.progress_units,stop_at)-mini(previous,stop_at)
		var traveled:=maxf(0.0,float(distance)/Pathing.PROGRESS_SCALE)
		state.phase=fposmod(float(state.phase)+traveled*float(CYCLES_PER_TILE[e.def_id])*DURATION,DURATION)
	for id:int in motion.keys():
		if not live.has(id):motion.erase(id)
