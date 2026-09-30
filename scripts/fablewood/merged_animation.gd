class_name FablewoodMergedAnimation
extends RefCounted
const AtlasLayout := preload("res://scripts/fablewood/atlas_layout.gd")
const Art:=preload("res://scripts/fablewood/merged_art.gd")
const Layout:=preload("res://scripts/fablewood/merged_animation_layout.gd")
const COUNT:=48
const FPS:=12.0
const DURATION:=4.0
const DATA:=Layout.DATA
static var _cache:Dictionary={}
var states:Dictionary={}
static func frame_index(seconds:float)->int:return posmod(floori(seconds*FPS),COUNT)
static func frame(key:String,casting:bool,seconds:float)->AtlasTexture:
	var data:Dictionary=DATA[key]
	var index:int=data["cast" if casting else "idle"][frame_index(seconds)]
	if not _cache.has(key):_cache[key]={}
	var cache:Dictionary=_cache[key]
	if not cache.has(index):
		var page:=floori(float(index)/float(data.capacity));var slot:=index%int(data.capacity)
		var sheet:Texture2D=data.pages[page]
		var tex:=AtlasLayout.texture(sheet,sheet.resource_path,slot,Vector2(data.cell),int(data.columns))
		cache[index]=tex
	return cache[index]
static func contact_offset(key:String)->Vector2:
	return Art.DATA[key].anchor+Vector2(DATA[key].get("source_offset",Vector2(288,180)))-Vector2(DATA[key].trim)
static func rect(key:String,center:Vector2,height:float)->Rect2:
	# Native source pixels, with one shared crop across idle/cast. Restore trim once.
	var scale:=height/float(DATA[key].get("reference_height",480.0))
	return Rect2(center-contact_offset(key)*scale,Vector2(DATA[key].cell)*scale)
func advance(world:Control,delta:float)->void:
	if world.model==null:return
	var live:Dictionary={}
	for u:UnitState in world.model.units:
		if not u.alive or not world.model.is_merged(u):continue
		if not world.effect_visible(world.platform_surface_center(u.cell)):continue
		live[u.id]=true
		if not states.has(u.id):states[u.id]={"idle":0.0,"cast":0.0,"weight":0.0,"active":false,"quiet":9.0,"last_attack":-1}
		var s:Dictionary=states[u.id]
		if world.reduced_motion:
			s.idle=0.0;s.cast=0.0;s.weight=0.0;s.active=false;s.last_attack=u.last_attack_tick;continue
		if u.last_attack_tick!=int(s.last_attack):
			s.last_attack=u.last_attack_tick
			if u.last_attack_tick>=0 and world.model.tick-u.last_attack_tick<=4:
				if not s.active:s.cast=0.0
				s.active=true;s.quiet=0.0
		s.idle=fposmod(float(s.idle)+delta,DURATION)
		s.quiet=float(s.quiet)+delta
		var previous:=float(s.cast);s.cast=fposmod(previous+delta,DURATION)
		if s.active and float(s.quiet)>.8 and (float(s.cast)<previous or float(s.quiet)>DURATION+.2):s.active=false
		s.weight=move_toward(float(s.weight),1.0 if s.active else 0.0,delta*5.0)
	for id:int in states.keys():
		if not live.has(id):states.erase(id)
func clear()->void:states.clear()
