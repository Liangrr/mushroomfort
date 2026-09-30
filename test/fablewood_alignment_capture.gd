extends Node
const OUT:="/home/ubuntu/fablewood_alignment/native/"
var screen:Control
var model:FablewoodBattle
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("ALIGNMENT_CAPTURE ",name)
func verify_contacts()->void:
	var world:FablewoodWorld=screen.world
	world.framing()
	for e:EnemyState in model.enemies:
		if not e.alive:continue
		var pos:=world.enemy_ground_position(e)
		var transform:=world.enemy_sprite_transform(pos,world.enemy_faces_left(e))
		assert((transform*Vector2.ZERO).is_equal_approx(world._origin+pos*world._scale))
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true;screen._reduced_motion=true;screen.world.reduced_motion=true
	model=screen.model;model.wave=1;model.wave_active=true
	for kind:StringName in [&"goblin",&"orc",&"troll",&"dragon"]:
		for e:EnemyState in model.enemies:e.alive=false
		for segment:int in [1,4,6,14]:
			model._spawn({"enemy_id":kind,"path_idx":0})
			model.enemies[-1].progress_units=segment*Pathing.PROGRESS_SCALE
		screen._refresh_hud();verify_contacts();await shot(String(kind)+"_centers")
		model.step(12);verify_contacts();await shot(String(kind)+"_moving")
		# Same camera; make each actor cross a route corner continuously.
		var i:=0
		for e:EnemyState in model.enemies:
			if not e.alive:continue
			e.progress_units=[2,5,7,15][i]*Pathing.PROGRESS_SCALE+980000;i+=1
		verify_contacts();await shot(String(kind)+"_turn_before")
		model.step(3);verify_contacts();await shot(String(kind)+"_turn_after")
		# Verify a stopped enemy retains its orientation/contact.
		var positions:Array[Vector2]=[]
		for e:EnemyState in model.enemies:
			if e.alive:e.stunned_until_tick=model.tick+60;positions.append(screen.world.enemy_ground_position(e))
		model.step(2);i=0
		for e:EnemyState in model.enemies:
			if e.alive:
				# Aerial movement is intentionally independent of ground stagger.
				if not e.aerial:assert(screen.world.enemy_ground_position(e).is_equal_approx(positions[i]))
				i+=1
		await shot(String(kind)+"_stopped")
	# Native range/scale coverage with one of every type.
	for e:EnemyState in model.enemies:e.alive=false
	var j:=0
	for kind:StringName in [&"goblin",&"orc",&"troll",&"dragon"]:
		model._spawn({"enemy_id":kind,"path_idx":0});model.enemies[-1].progress_units=[1,4,6,14][j]*Pathing.PROGRESS_SCALE;j+=1
	I18n.set_locale(&"zh-CN");await frames();screen.paused=true
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen.world.zoom=1.8;verify_contacts();await shot("portrait_zoom")
	screen.world.zoom=0.7;verify_contacts();await shot("portrait_wide")
	screen.world.zoom=1.0;screen._reduced_motion=false;screen.world.reduced_motion=false;screen.paused=false
	await frames(12);screen.paused=true;await shot("motion_enabled")
	print("ENEMY_ALIGNMENT_NATIVE_COMPLETE")
	get_tree().quit()
