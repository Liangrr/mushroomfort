extends Node
const OUT:="/home/ubuntu/fablewood_animation/native/"
const A:=preload("res://scripts/fablewood/guardian_animation.gd")
var screen:Control
var m:FablewoodBattle
func frames(count:int=4)->void:
	for i:int in count:await get_tree().process_frame
func shot(name:String)->void:
	await frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("ANIMATION_CAPTURE ",name)
func phase(seconds:float)->void:
	for u:UnitState in m.units:
		if u.alive:screen.world._tower_motion[u.id]={"phase":seconds,"burst":0.0,"last_attack":u.last_attack_tick}
	screen.world.queue_redraw()
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"))
	await frames(15)
	screen=Game.content;screen._skip_tutorial();screen._reduced_motion=false;screen.world.reduced_motion=false
	m=screen.model;m.dp=9999
	var cells:Array[Vector2i]=[]
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			if m.stage.is_elevated_platform(Vector2i(x,y)):cells.append(Vector2i(x,y))
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	for i:int in 12:
		assert(m.apply_action([&"deploy",ids[floori(float(i)/3)],cells[i],0]))
		for upgrade:int in i%3:assert(m.apply_action([&"upgrade",m.units[-1].id]))
	m.drain_events();screen.world.effects.clear();screen.selected_id=0;screen.world.selected=0;screen._refresh_inspector();screen._refresh_hud()
	await frames(12)
	var simulation_hash:=m.state_hash()
	var before:float=screen.world._tower_motion[0].phase
	await frames(20)
	assert(screen.world._tower_motion[0].phase!=before)
	assert(m.state_hash()==simulation_hash,"Animation must not alter simulation")
	screen.paused=true;await frames()
	var frozen:float=screen.world._tower_motion[0].phase
	await frames(18);assert(screen.world._tower_motion[0].phase==frozen,"Pause freezes animation")
	for p:float in [0.0,0.67,1.33,2.0,2.67,3.33,3.92,4.0]:
		phase(p);await shot("tiers_"+str(roundi(p*100)))
	# Actual attacks cause a local playback accent without changing the anchor.
	m.wave=1;m.wave_active=true
	m._spawn({"enemy_id":&"troll","path_idx":0});m.enemies[-1].progress_units=8*Pathing.PROGRESS_SCALE
	for u:UnitState in m.units:u.atk_counter=0
	m.step();screen._present_events();screen.world._advance_tower_animation(0.05)
	var accented:=false
	for state:Dictionary in screen.world._tower_motion.values():accented=accented or float(state.burst)>0
	assert(accented,"Real attacks trigger animation accents")
	await shot("attack")
	screen._show_pause();await shot("pause");screen._dismiss();screen.paused=true
	I18n.set_locale(&"zh-CN");screen._dismiss();screen.paused=true;await frames();phase(1.33)
	await shot("cn_landscape")
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100)
	await frames(10);phase(2.0);await shot("cn_portrait")
	screen.world.zoom=1.8;phase(2.67);await shot("zoom_in")
	screen.world.zoom=0.72;phase(3.33);await shot("zoom_out")
	screen.world.zoom=1.0;screen._reduced_motion=true;screen.world.reduced_motion=true
	await shot("reduced_motion")
	# Upgrade to a different atlas with the same stable authored ground contact.
	screen._reduced_motion=false;screen.world.reduced_motion=false
	m.dp=9999;assert(m.apply_action([&"upgrade",0]));screen._refresh_inspector();phase(0.0)
	await shot("upgrade")
	assert(m.apply_action([&"retreat",0]));screen.world._advance_tower_animation(0.0)
	assert(not screen.world._tower_motion.has(0),"Removed tower releases its animation state")
	Game.open_title();await frames(8)
	assert(not is_instance_valid(screen),"Scene teardown releases animated UI/world")
	print("ANIMATION_NATIVE_CHECKS_COMPLETE")
	get_tree().quit()
