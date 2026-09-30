extends Node
const OUT:="user://fablewood_merge/native/"
var screen:Control
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK)
func touch(cell:Vector2i)->void:
	var w:FablewoodWorld=screen.world;w.framing()
	var point:=w.get_global_transform()*(w._origin+w.platform_surface_center(cell)*w._scale)
	for down:bool in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=0;e.position=point;e.pressed=down;Input.parse_input_event(e);await frames(2)
func add(id:StringName,cell:Vector2i)->UnitState:
	var m:FablewoodBattle=screen.model;m.dp=9999;assert(m.apply_action([&"deploy",id,cell,0]));var u:=m.units[-1]
	assert(m.apply_action([&"upgrade",u.id]));assert(m.apply_action([&"upgrade",u.id]));return u
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(TweakControls.set_value(&"ui.text_scale",1.2))
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	assert(is_equal_approx(float(TweakControls.active_value(&"ui.text_scale")),1.2))
	screen=Game.content;screen._skip_tutorial();screen.set_process(false);screen.paused=false
	var m:FablewoodBattle=screen.model
	var a:=add(&"recruit",Vector2i(4,3));var b:=add(&"guard_1",Vector2i(6,3))
	screen._refresh_hud();screen.merge_flow.start();await touch(a.cell);await touch(b.cell)
	assert(not m.pending_merge.is_empty());await touch(a.cell);assert(m.is_merged(m.units[-1]))
	var u:=m.units[-1];screen._refresh_inspector();screen._refresh_hud()
	# Actual merged attacks feed both elemental audio and presentation channels.
	m._spawn({"enemy_id":&"troll","path_idx":0});var enemy:=m.enemies[-1];enemy.hp=100000;enemy.hp_max=100000
	for index:int in m.path_for(0).size():
		var cell:=m.path_for(0)[index]
		if cell.distance_to(u.cell)<2:enemy.progress_units=index*Pathing.PROGRESS_SCALE;break
	m.drain_events();screen.world.effects.clear();screen.world.combat_particles.clear()
	for channel:Dictionary in m.merged[u.id].channels:channel.counter=0
	m._tick_combat();screen._present_events();await shot("dual_attack")
	assert(screen.world.effects.any(func(e:Dictionary)->bool:return e.get("element","")=="storm"))
	assert(screen.world.effects.any(func(e:Dictionary)->bool:return e.get("element","")=="earth"))
	var state:=m.state_hash();screen.world.reduced_motion=true;screen._reduced_motion=true
	await shot("merged_reduced_motion");assert(m.state_hash()==state)
	# Largest supported text, both locales; pending transaction still cancellable.
	assert(is_equal_approx(float(TweakControls.value(&"ui.text_scale")),1.2))
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen.selected_id=u.id;screen.world.selected=u.id;screen._refresh_inspector();await shot("large_cn")
	assert(screen.inspector.get_parent().get_global_rect().end.y<screen._cards[0].get_parent().get_global_rect().position.y)
	a=add(&"caster_1",Vector2i(4,5));b=add(&"sniper_1",Vector2i(6,5));screen._refresh_hud();screen.merge_flow.start();screen.merge_flow.click(a.cell);screen.merge_flow.click(b.cell)
	await shot("large_pending_cn");assert(screen.inspector.get_parent().get_global_rect().end.y<screen._cards[0].get_parent().get_global_rect().position.y)
	screen.merge_flow.cancel();I18n.set_locale(&"en-US");get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900);await frames(10)
	screen.selected_id=u.id;screen._refresh_inspector();await shot("large_en")
	assert(screen.inspector.get_parent().get_global_rect().end.y<screen._cards[0].get_parent().get_global_rect().position.y)
	assert(TweakControls.reset_value(&"ui.text_scale"))
	print("MERGE_EXTRA_PASS touch; dual attacks; reduced motion; large EN/CN layouts")
	get_tree().quit()
