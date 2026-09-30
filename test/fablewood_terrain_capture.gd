extends Node
const OUT:="/home/ubuntu/fablewood_terrain/native/"
const Terrain:=preload("res://scripts/fablewood/organic_terrain.gd")
const EnemyAnim:=preload("res://scripts/fablewood/enemy_animation.gd")
var screen:Control
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("TERRAIN_NATIVE ",name)
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	var model:FablewoodBattle=screen.model
	var hash_before:int=model.state_hash()
	var layer:FablewoodOrganicTerrain=screen.world.terrain_layer
	var rebuilds:int=layer.rebuild_count
	await shot("terrain_overview")
	await frames(15)
	assert(layer.rebuild_count==rebuilds,"Terrain data is cached, not rebuilt each frame")
	assert(model.state_hash()==hash_before,"Terrain presentation never changes authoritative state")
	# All authored chapter categories are represented without writing to stage resources.
	for chapter:int in [1,2,3]:
		var stage:StageDef=load("res://data/stages/s%d.tres"%chapter)
		var candidate:=Terrain.new();candidate.configure(stage,stage.path_cells(0))
		assert(candidate.mask.get_width()==stage.grid_size().x+2)
		for y:int in stage.grid_size().y:
			for x:int in stage.grid_size().x:
				var cell:=Vector2i(x,y);var pixel:=candidate.mask.get_pixel(x+1,y+1)
				assert((pixel.g>0.5)==(stage.tile_at(cell)!=StageDef.Tile.VOID))
				assert((pixel.r>0.5)==stage.path_cells(0).has(cell))
				assert((pixel.b>0.5)==stage.is_elevated_platform(cell))
		candidate.free()
	# Picking and tower contact origins are independent of the visual mask.
	var pads:Array[Vector2i]=[]
	for y:int in model.stage.grid_size().y:
		for x:int in model.stage.grid_size().x:
			var cell:=Vector2i(x,y)
			if model.stage.is_elevated_platform(cell):pads.append(cell)
	for z:float in [0.7,1.0,1.85]:
		screen.world.zoom=z;screen.world.pan=Vector2.ZERO;await frames()
		for cell:Vector2i in pads:assert(screen.world.pick(screen.world.screen_of(cell))==cell)
		assert(layer.rebuild_count==rebuilds)
	screen.world.zoom=1.5;screen.world.pan=Vector2(-120,15);await shot("terrain_zoom")
	screen.world.reset_view();model.dp=8000
	for i:int in mini(12,pads.size()):
		assert(model.apply_action([&"deploy",[&"caster_1",&"sniper_1",&"recruit",&"guard_1"][i%4],pads[i],0]))
		for upgrade:int in i%3:assert(model.apply_action([&"upgrade",model.units[-1].id]))
	model.wave=1;model.wave_active=true
	for i:int in 4:
		model._spawn({"enemy_id":[&"goblin",&"orc",&"troll",&"dragon"][i],"path_idx":0})
		model.enemies[-1].progress_units=[1,4,6,14][i]*Pathing.PROGRESS_SCALE
	EnemyAnim.advance(model,screen.world._enemy_motion,false);screen._refresh_hud()
	await shot("terrain_actors_a")
	model.step(8);EnemyAnim.advance(model,screen.world._enemy_motion,false)
	await shot("terrain_actors_b")
	I18n.set_locale(&"zh-CN");await frames()
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	await shot("terrain_portrait_cn")
	screen.world.zoom=1.85;await shot("terrain_portrait_zoom")
	var weak:WeakRef=weakref(screen.world.terrain_layer)
	Game.open_title();await frames(12)
	assert(weak.get_ref()==null,"Terrain resources leave with the world")
	print("ALL_ORGANIC_TERRAIN_NATIVE_CHECKS_PASS")
	get_tree().quit()
