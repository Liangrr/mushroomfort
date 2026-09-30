extends Node
const OUT:="/home/ubuntu/fablewood_merge/native/"
var screen:Control
var m:FablewoodBattle
var cells:Array[Vector2i]=[]
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func press(key:Key)->void:
	for down:bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=key;e.pressed=down;Input.parse_input_event(e);await frames(2)
func click_point(point:Vector2,touch:bool=false)->void:
	get_viewport().warp_mouse(point)
	var motion:=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion);await frames(2)
	for down:bool in [true,false]:
		if touch:
			var e:=InputEventScreenTouch.new();e.index=0;e.position=point;e.pressed=down;Input.parse_input_event(e)
		else:
			var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.pressed=down;Input.parse_input_event(e)
		await frames(2)
func click_button(button:Button)->void:await click_point(button.get_global_rect().get_center())
func click_cell(cell:Vector2i,touch:bool=false)->void:
	screen.world.framing()
	var point:Vector2=screen.world.get_global_transform()*(screen.world._origin+screen.world.platform_surface_center(cell)*screen.world._scale)
	await click_point(point,touch)
func add(id:StringName,cell:Vector2i)->UnitState:
	m.dp=9999;assert(m.apply_action([&"deploy",id,cell,0]));var u:=m.units[-1]
	assert(m.apply_action([&"upgrade",u.id]));assert(m.apply_action([&"upgrade",u.id]));return u
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			if m.stage.is_elevated_platform(Vector2i(x,y)):cells.append(Vector2i(x,y))
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,3))<b.distance_squared_to(Vector2i(4,3)))
	assert(screen.merge_flow.button.disabled);await shot("disabled")
	var a:=add(&"caster_1",cells[0]);var b:=add(&"sniper_1",cells[1]);m.dp=0;m.drain_events();screen._refresh_hud()
	assert(not screen.merge_flow.button.disabled);await shot("available")
	await click_button(screen.merge_flow.button);assert(screen.merge_flow.active);await shot("select_first")
	var time:float=screen._preparation_remaining;screen._advance_preparation(3);assert(screen._preparation_remaining==time)
	await click_cell(a.cell);assert(screen.merge_flow.first==a.id);await shot("select_second")
	await click_cell(b.cell);assert(not m.pending_merge.is_empty() and not a.alive and not b.alive)
	screen.world.hovered=cells[0];await shot("pending_placement")
	await press(KEY_ENTER);assert(m.wave==0)
	await press(KEY_SPACE);assert(screen.paused and not m.pending_merge.is_empty())
	await press(KEY_SPACE);assert(not screen.paused and not m.pending_merge.is_empty())
	await press(KEY_ESCAPE);assert(not screen.merge_flow.active and a.alive and b.alive and m.pending_merge.is_empty())
	await click_button(screen.merge_flow.button);await click_cell(a.cell);await click_cell(b.cell)
	await click_cell(Vector2i(0,0));assert(not m.pending_merge.is_empty());await shot("invalid_socket")
	await click_cell(cells[0]);assert(m.pending_merge.is_empty() and not screen.merge_flow.active)
	var merged:=m.units[-1];assert(m.is_merged(merged) and merged.cell==cells[0] and m.dp==0)
	assert(screen._tutorial_upgrade_button==null);await press(KEY_U);assert(m.tier(merged)==3)
	screen.world.combat_particles.clear();screen.world.effects.clear();await shot("placed_rimeflame")
	# Every dual-element guardian in the same active scene, through legal model transactions.
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var index:=1
	for i:int in 4:
		for j:int in range(i+1,4):
			if i==0 and j==1:continue
			var left:=add(ids[i],cells[index]);var right:=add(ids[j],cells[10])
			assert(m.apply_action([&"begin_merge",left.id,right.id]));assert(m.apply_action([&"place_merge",cells[index]]));index+=1
	m.drain_events();screen.world.combat_particles.clear();screen.world.effects.clear();screen.world.reset_view();screen._refresh_hud();await shot("all_six")
	var displayed:Array[UnitState]=[]
	for actor:UnitState in m.units:
		if actor.alive:displayed.append(actor)
	for u:UnitState in displayed:
		for actor:UnitState in displayed:actor.alive=actor.id==u.id
		screen.selected_id=u.id;screen.world.selected=u.id;screen._refresh_inspector()
		screen.world.zoom=1.75;screen.world.framing()
		var target:=Vector2(565,400);screen.world.pan+=target-screen.world._origin-screen.world.platform_surface_center(u.cell)*screen.world._scale
		await shot(m.merge_key(u)+"_close")
		var rect:Rect2=screen.world.tower_draw_rect(u,false);var data:Dictionary=screen.MergedArt.DATA[m.merge_key(u)]
		assert((rect.position+data.anchor*(rect.size.y/480.0)).distance_to(screen.world.platform_surface_center(u.cell))<.001)
	for actor:UnitState in displayed:actor.alive=true
	# Language and resize retain merged state and toolbar ownership.
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	screen._refresh_inspector();screen._refresh_hud();await shot("portrait_cn")
	assert(screen.merge_flow.button.get_global_rect().end.x<=720 and screen._next.get_global_rect().end.x<=720)
	assert(m.deployed_count()==6)
	# Start a second merge, retain it over resize, then leave safely.
	a=add(&"caster_1",cells[7]);b=add(&"guard_1",cells[8]);screen._refresh_hud();screen.merge_flow.start()
	screen.merge_flow.click(a.cell);screen.merge_flow.click(b.cell);assert(not m.pending_merge.is_empty())
	await shot("portrait_pending_cn")
	screen._build();screen._resize();await frames();assert(not m.pending_merge.is_empty() and screen.world.merge_pending_key!="")
	Game.open_title();await frames(12);assert(m.pending_merge.is_empty() and a.alive and b.alive)
	print("MERGE_NATIVE_PASS six recipes; real pointer; rollback; hotkeys; pause; resize; EN/CN; grounded footprints; menu recovery")
	get_tree().quit()
