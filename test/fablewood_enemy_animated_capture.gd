extends Node
const OUT:="/home/ubuntu/fablewood_enemy_animation/native/"
const A:=preload("res://scripts/fablewood/enemy_animation.gd")
var screen:Control
var model:FablewoodBattle
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("ENEMY_NATIVE ",name)
func sync()->void:A.advance(model,screen.world._enemy_motion,false)
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	model=screen.model;model.wave=1;model.wave_active=true
	for kind:StringName in [&"goblin",&"orc",&"troll",&"dragon"]:
		for e:EnemyState in model.enemies:e.alive=false
		for segment:int in [1,4,6,14]:
			model._spawn({"enemy_id":kind,"path_idx":0});model.enemies[-1].progress_units=segment*Pathing.PROGRESS_SCALE
		sync();screen._refresh_hud()
		# All four projected travel directions at fixed contacts and a common camera.
		for frame:int in [0,8,16,24,32,40]:
			for state:Dictionary in screen.world._enemy_motion.values():state.phase=float(frame)/A.FPS
			await shot(String(kind)+"_pose_"+str(frame))
		# Native displacement + direction change, not merely stationary atlas evidence.
		var index:=0
		for e:EnemyState in model.enemies:
			if not e.alive:continue
			e.progress_units=[2,5,7,15][index]*Pathing.PROGRESS_SCALE+950000;index+=1
		sync();await shot(String(kind)+"_turn_a")
		model.step(8);sync();await shot(String(kind)+"_turn_b")
		for e:EnemyState in model.enemies:
			if e.alive:
				e.last_damage_tick=model.tick;e.stunned_until_tick=model.tick+20
				model.slow_until[e.id]=model.tick+60
		await shot(String(kind)+"_hit")
		var before:Dictionary=screen.world._enemy_motion.duplicate(true)
		await frames(12)
		assert(before==screen.world._enemy_motion,"Paused enemy animation freezes")
	# Mixed roster in portrait, at both world zoom limits and reduced motion.
	for e:EnemyState in model.enemies:e.alive=false
	var index:=0
	for kind:StringName in [&"goblin",&"orc",&"troll",&"dragon"]:
		model._spawn({"enemy_id":kind,"path_idx":0});model.enemies[-1].progress_units=[1,4,6,14][index]*Pathing.PROGRESS_SCALE;index+=1
	sync();I18n.set_locale(&"zh-CN");await frames()
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen.world.zoom=1.8;await shot("portrait_zoom")
	screen.world.zoom=0.7;await shot("portrait_wide")
	screen.world.reduced_motion=true;await shot("reduced_motion")
	screen.world.reduced_motion=false;screen.paused=false;await frames(24);screen.paused=true
	await shot("moving_portrait")
	var old:WeakRef=weakref(screen.world)
	Game.open_title();await frames(10)
	assert(old.get_ref()==null,"World and per-enemy states are released on menu return")
	print("ALL_ENEMY_ANIMATION_NATIVE_CHECKS_PASS")
	get_tree().quit()
