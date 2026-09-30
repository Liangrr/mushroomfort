extends Node
const OUT:="/home/ubuntu/fablewood_walk_audit/native/"
const A:=preload("res://scripts/fablewood/enemy_animation.gd")
var screen:Control
var model:FablewoodBattle
func frames(n:int=3)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("WALK_NATIVE ",name)
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	model=screen.model;model.wave=1;model.wave_active=true
	for kind:StringName in [&"goblin",&"orc",&"troll"]:
		for e:EnemyState in model.enemies:e.alive=false
		screen.world._enemy_tick_valid=false
		for segment:int in [1,4,6,14]:
			model._spawn({"enemy_id":kind,"path_idx":0});model.enemies[-1].progress_units=segment*Pathing.PROGRESS_SCALE
		A.advance(model,screen.world._enemy_motion,false);screen._refresh_hud()
		for phase:int in [40,46,47,0,1,8,16,24]:
			for state:Dictionary in screen.world._enemy_motion.values():state.phase=float(phase)/A.FPS
			await shot(String(kind)+"_phase_"+str(phase))
		# Real displacement from the model, shown at successive sub-tick alphas.
		screen.world.capture_enemy_tick();var before_hash:int=model.state_hash()
		model.step();A.advance(model,screen.world._enemy_motion,false)
		var after_hash:int=model.state_hash();assert(after_hash!=before_hash)
		var previous:Dictionary={}
		for alpha:float in [0.0,0.25,0.5,0.75,1.0]:
			screen.world.render_alpha=alpha
			for e:EnemyState in model.enemies:
				if not e.alive:continue
				var p:int=screen.world.rendered_enemy_progress(e)
				assert(p<=e.progress_units and p>=int(screen.world._enemy_tick_before[e.id]))
				if previous.has(e.id):assert(p>int(previous[e.id]))
				previous[e.id]=p
			await shot(String(kind)+"_subtick_"+str(roundi(alpha*100)))
			assert(model.state_hash()==after_hash)
		# Four actual turns, preserving phase across the segment boundary.
		screen.world._enemy_tick_valid=false
		var index:=0
		for e:EnemyState in model.enemies:
			if e.alive:e.progress_units=[2,5,7,15][index]*Pathing.PROGRESS_SCALE+995000;index+=1
		A.advance(model,screen.world._enemy_motion,false)
		await shot(String(kind)+"_turn_a")
		screen.world.capture_enemy_tick();model.step(2);A.advance(model,screen.world._enemy_motion,false)
		screen.world.render_alpha=1.0;await shot(String(kind)+"_turn_b")
		# Pausing freezes both the pose and fractional display position.
		var poses:Dictionary=screen.world._enemy_motion.duplicate(true)
		var pos:Dictionary={}
		for e:EnemyState in model.enemies:
			if e.alive:pos[e.id]=screen.world.enemy_ground_position(e)
		await frames(10)
		assert(poses==screen.world._enemy_motion)
		for e:EnemyState in model.enemies:
			if e.alive:assert(pos[e.id]==screen.world.enemy_ground_position(e))
	# Running 1x/2x and Frost/stagger keep cadence coupled to actual travel.
	screen.paused=false;await frames(35);screen.speed=2;await frames(35)
	for e:EnemyState in model.enemies:
		if e.alive:model.slow_until[e.id]=model.tick+60
	await frames(30);screen.paused=true;await shot("live_slowed")
	I18n.set_locale(&"zh-CN");await frames()
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen.world.zoom=1.85;await shot("portrait_zoom")
	screen.world.reduced_motion=true;await shot("reduced_motion")
	var weak:WeakRef=weakref(screen.world);Game.open_title();await frames(10)
	assert(weak.get_ref()==null)
	print("ALL_WALK_LOOP_NATIVE_CHECKS_PASS")
	get_tree().quit()
