extends "res://test/fablewood_merge_capture.gd"
const DEST:="/home/ubuntu/fablewood_worldheart/native/"
const A:=preload("res://scripts/fablewood/merged_animation.gd")
const PAIRS:=[[&"caster_1",&"sniper_1"],[&"recruit",&"guard_1"],[&"caster_1",&"guard_1"]]
func capture(name:String)->void:
	screen.world._sync_terrain();screen.world.queue_redraw();await frames(3);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DEST+name+".png")
	if name=="worldheart_idle_0":
		for child:Node in screen.inspector.get_children():
			if child is Button:assert(child.get_global_rect().end.y<=screen._inspector_scroll.get_global_rect().end.y)
	if AudioServer.get_driver_name()=="PulseAudio":assert(Sfx._players.size()==8 and is_equal_approx(screen.DEFAULT_SFX_VOLUME,.4875))
func pair(index:int,slot:int)->UnitState:
	var free:Array[Vector2i]=[]
	for c:Vector2i in cells:
		if m.alive_unit_at(c)==null:free.append(c)
	var a:=add(PAIRS[index][0],free[0]);var b:=add(PAIRS[index][1],free[1])
	assert(m.apply_action([&"begin_merge",a.id,b.id]));assert(m.apply_action([&"place_merge",cells[slot]]));m.drain_events();return m.units[-1]
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(DEST)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model
	var w:Control=screen.world;w.set_process(false);w.presentation_paused=false
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			if m.stage.is_elevated_platform(Vector2i(x,y)):cells.append(Vector2i(x,y))
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,3))<b.distance_squared_to(Vector2i(4,3)))
	var first:=pair(0,0);var second:=pair(1,1);var overlapping:=pair(2,2)
	m.ultimates.states[first.id].remaining=123;m.ultimates.states[second.id].remaining=234
	screen._refresh_hud();w.reset_view();w.framing();w.merged_animation.advance(w,.1)
	await capture("complementary_donors")
	await click_button(screen.merge_flow.button);await click_cell(first.cell)
	assert(second.id in w.merge_eligible and not overlapping.id in w.merge_eligible)
	await capture("compatible_highlights")
	await click_cell(overlapping.cell);assert(m.pending_merge.is_empty() and screen.merge_flow.feedback!="")
	await capture("overlap_rejected")
	await click_cell(second.cell);assert(not m.pending_merge.is_empty() and m.pending_merge.channels.size()==4)
	w.hovered=first.cell;await capture("worldheart_placement_preview")
	await press(KEY_ESCAPE);assert(first.alive and second.alive and m.ultimates.states[first.id].remaining==123 and m.ultimates.states[second.id].remaining==234)
	await click_button(screen.merge_flow.button);await click_cell(first.cell);await click_cell(second.cell);await click_cell(first.cell)
	var u:UnitState=m.units[-1];assert(m.is_all_element(u) and m.range_for(u)==7 and m.merged[u.id].channels.size()==4)
	assert(not m.ultimates.states.has(first.id) and not m.ultimates.states.has(second.id))
	assert(w.merge_celebration.active.size()==1 and w.merge_celebration.active[0].parts.size()==4)
	w.merge_celebration.active[0].age=.4;await capture("fourfold_summoning")
	w.merge_celebration.clear();w.effects.clear();w.combat_particles.clear()
	screen.selected_id=u.id;w.selected=u.id;screen._refresh_inspector();screen._refresh_hud()
	w.zoom=1.85;w.pan=Vector2.ZERO;w.framing();w.pan+=Vector2(560,450)-w._origin-w.platform_surface_center(u.cell)*w._scale;w.framing()
	var key:=m.merge_key(u);var rect:Rect2=w.tower_draw_rect(u,false);var data:Dictionary=screen.MergedArt.DATA[key]
	assert((rect.position+Vector2(data.anchor)*(rect.size.y/float(data.canvas.y))).distance_to(w.platform_surface_center(u.cell))<.001)
	for state:String in ["idle","cast"]:
		for phase:float in [0.0,1.5,2.666667,3.916667]:
			w.merged_animation.states[u.id]={"idle":phase,"cast":phase,"weight":1.0 if state=="cast" else 0.0,"active":state=="cast","quiet":0.0,"last_attack":-1}
			await capture("worldheart_"+state+"_"+str(roundi(phase*12)))
	assert(m.apply_action([&"next_wave"]));m.timeline=WaveTimeline.new()
	for live:UnitState in m.units:
		if m.is_merged(live):
			for channel:Dictionary in m.merged[live.id].channels:channel.counter=1000000
	m.ultimates.states[u.id].remaining=0;screen._refresh_hud();await capture("worldheart_ready_four_colors")
	w.zoom=1.0;w.pan=Vector2.ZERO;w.framing()
	for direction:int in [-1,1]:
		for e:EnemyState in m.enemies:e.alive=false
		var best:=1;var score:=-100000.0
		for i:int in range(1,m.path_for(0).size()-1):
			var cell:Vector2i=m.path_for(0)[i]
			if maxi(absi(cell.x-u.cell.x),absi(cell.y-u.cell.y))>m.range_for(u):continue
			var offset:Vector2=w.route_center(Vector2(cell))-w.platform_surface_center(u.cell)
			var value:float=direction*offset.x-absf(offset.y)*.25
			if value>score:score=value;best=i
		for i:int in 5:
			m._spawn({"enemy_id":&"goblin" if i<3 else &"dragon","path_idx":0})
			var e:EnemyState=m.enemies[-1];e.hp=100000;e.hp_max=100000;e.step_units=0;e.progress_units=best*Pathing.PROGRESS_SCALE
		m.wave_active=true;m.ultimates.states[u.id].remaining=1;m.step();screen._present_events();w.merged_animation.advance(w,.2)
		assert(m.ultimates.info(u.id).active and w.merged_animation.states[u.id].active)
		var charge:Dictionary=m.ultimates.states[u.id].duplicate(true);var held:Dictionary=w.merged_animation.states.duplicate(true)
		w.presentation_paused=true;w._process(.4);assert(w.merged_animation.states==held and m.ultimates.states[u.id]==charge);w.presentation_paused=false
		var previous:=0
		for phase:int in [0,6,15,24,29]:
			m.step(phase-previous);previous=phase;screen._present_events();screen._refresh_hud();w.merged_animation.advance(w,.08)
			await capture("meteor_"+str(direction)+"_flight_"+str(phase))
		var hp:int=m.enemies[-1].hp;m.step();screen._present_events();screen._refresh_hud()
		assert(m.enemies[-1].hp<hp and w.meteor_effects.impacts.size()>0)
		for phase:float in [.06,.28,.8]:
			w.meteor_effects.impacts[-1].age=phase;await capture("meteor_"+str(direction)+"_impact_"+str(roundi(phase*100)))
		w.meteor_effects.clear();w.combat_particles.clear();w.effects.clear()
	# Reduced motion keeps a static warning and static impact, with no moving meteor.
	w.reduced_motion=true;m.ultimates.states[u.id].remaining=1;m.step();screen._present_events();w.merged_animation.advance(w,.1)
	await capture("reduced_motion_warning");m.step(30);screen._present_events();await capture("reduced_motion_impact")
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	w=screen.world;w.set_process(false);w.reduced_motion=false;w.reset_view();w.framing();screen._refresh_inspector();screen._refresh_hud()
	w.merged_animation.advance(w,.2);await capture("worldheart_cn_portrait")
	assert(screen._ultimate_status.get_global_rect().end.x<=720 and screen.merge_flow.button.get_global_rect().end.x<=720)
	var ev:Dictionary={"kind":"meteor_impact","unit":u.id,"tick":m.tick,"center":m.path_for(0)[4],"chains":[]}
	w.meteor_effects.clear();w.pan=Vector2(9999,9999);w.framing();assert(not w.meteor_effects.trigger(ev,w) and w.meteor_effects.impacts.is_empty())
	w.pan=Vector2.ZERO;w.framing()
	for i:int in 12:ev.tick=m.tick+i;w.meteor_effects.trigger(ev,w)
	assert(w.meteor_effects.impacts.size()<=4);w.meteor_effects.advance(2,w);assert(w.meteor_effects.impacts.is_empty())
	if AudioServer.get_driver_name()=="PulseAudio":
		await get_tree().create_timer(.15).timeout
		var before:int=Sfx._audible_start_count
		m.events.append(ev.duplicate(true));screen._present_events();assert(Sfx._audible_start_count==before+1)
		assert(not Sfx.play("meteor_impact"))
		w.pan=Vector2(9999,9999);w.framing();await get_tree().create_timer(.15).timeout
		before=Sfx._audible_start_count;m.events.append(ev.duplicate(true));screen._present_events();assert(Sfx._audible_start_count==before)
		var bus:=AudioServer.get_bus_index("SFX");screen._set_volume("SFX",0);assert(AudioServer.is_bus_mute(bus))
		screen._set_volume("SFX",screen.DEFAULT_SFX_VOLUME);assert(not AudioServer.is_bus_mute(bus))
		print("WORLDHEART_REAL_AUDIO_PASS actual meteor impact; dedupe; independently culled impact; mute; 8 voices; 0.4875 default")
	var reference:WeakRef=weakref(w);Game.open_title();await frames(12);assert(reference.get_ref()==null)
	print("WORLDHEART_NATIVE_PASS complementary pointer selection; rejection; rollback; fourfold summon; fixed high-resolution poses; both model-timed meteor directions; impact; pause; reduced motion; EN/CN; culling/caps/cleanup")
	get_tree().quit()
