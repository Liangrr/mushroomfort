extends "res://test/fablewood_merge_capture.gd"
const OUT_ULT:="user://fablewood_merge_ultimates/native/"
const PAIRS:=[[&"caster_1",&"sniper_1"],[&"caster_1",&"recruit"],[&"caster_1",&"guard_1"],[&"sniper_1",&"recruit"],[&"sniper_1",&"guard_1"],[&"recruit",&"guard_1"]]
var last_event:Dictionary={}
func capture(name:String)->void:
	screen.world._sync_terrain();screen.world.queue_redraw();await frames(4);await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT_ULT+name+".png")==OK)
func enemies_for(u:UnitState)->void:
	for e:EnemyState in m.enemies:e.alive=false
	var positions:Array[int]=[];var path:=m.path_for(0)
	for i:int in path.size():
		if maxi(absi(path[i].x-u.cell.x),absi(path[i].y-u.cell.y))<=m.range_for(u):positions.append(i)
	positions.sort_custom(func(a:int,b:int)->bool:return path[a].distance_squared_to(u.cell)<path[b].distance_squared_to(u.cell))
	for i:int in mini(5,positions.size()):
		m._spawn({"enemy_id":&"dragon" if i==4 else &"orc" if i==2 else &"goblin","path_idx":0})
		var e:EnemyState=m.enemies[-1];e.hp=50000;e.hp_max=50000;e.step_units=0;e.progress_units=positions[i]*Pathing.PROGRESS_SCALE
func fire(u:UnitState)->void:
	m.wave=1;m.wave_active=true;m.timeline=WaveTimeline.new();m.ultimates.states[u.id].remaining=1
	for other:UnitState in m.units:
		if other.alive:
			for channel:Dictionary in m.merged[other.id].channels:channel.counter=1000000
	m.drain_events();m.step()
	for event:Dictionary in m.events:
		if event.kind=="ultimate":last_event=event.duplicate(true)
	screen._present_events();screen._refresh_hud()
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT_ULT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	# Exercise the catalog maximum through the actual chapter boundary.
	assert(TweakControls.set_value(&"ui.text_scale",1.2))
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	assert(is_equal_approx(float(TweakControls.active_value(&"ui.text_scale")),1.2))
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model
	var w:Control=screen.world;w.set_process(false);w.presentation_paused=false
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			if m.stage.is_elevated_platform(Vector2i(x,y)):cells.append(Vector2i(x,y))
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,3))<b.distance_squared_to(Vector2i(4,3)))
	var subject:UnitState
	for index:int in 6:
		if subject!=null:assert(m.apply_action([&"retreat",subject.id]))
		var a:=add(PAIRS[index][0],cells[0]);var b:=add(PAIRS[index][1],cells[1]);m.drain_events()
		assert(m.apply_action([&"begin_merge",a.id,b.id]));assert(m.apply_action([&"place_merge",cells[0]]))
		subject=m.units[-1];m.drain_events();screen.selected_id=subject.id;w.selected=subject.id
		screen._refresh_inspector();assert(not screen._ultimate_status.text.contains("ultimate_"));enemies_for(subject);w.reset_view();w.zoom=1.45;w.framing()
		w.pan+=Vector2(540,350)-w._origin-w.platform_surface_center(subject.cell)*w._scale;w.framing()
		w.ultimate_effects.clear();w.combat_particles.clear();w.effects.clear();w.merge_celebration.clear()
		m.ultimates.states[subject.id].remaining=0;screen._refresh_hud();await capture(m.merge_key(subject)+"_ready")
		fire(subject);assert(not w.ultimate_effects.active.is_empty())
		if index==5:assert(w.ultimate_effects.active[0].root_grounds.size()<w.ultimate_effects.active[0].grounds.size())
		assert(last_event.key==m.merge_key(subject));assert(Sfx._last_resolved_id==StringName(String(last_event.key).split("_")[1]+"_hit"))
		for phase:float in [.12,.48,.45]:
			w._process(phase);await capture(m.merge_key(subject)+"_cast_"+str(roundi(w.ultimate_effects.active[0].age*100)))
		assert(w.merged_animation.states[subject.id].active)
		var before:=m.state_hash();var effects_before:=str(w.ultimate_effects.active)
		w.presentation_paused=true;w._process(.8);assert(str(w.ultimate_effects.active)==effects_before and m.state_hash()==before);w.presentation_paused=false
		print("ULTIMATE_NATIVE_RECIPE ",m.merge_key(subject))
	# Localized compact inspector survives rebuilds without resetting cooldown.
	var charge:int=m.ultimates.states[subject.id].remaining
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	w=screen.world;w.set_process(false);screen._refresh_inspector();screen._refresh_hud();assert(m.ultimates.states[subject.id].remaining==charge)
	w.reset_view();var before_vfx:=m.state_hash();w.ultimate_effects.trigger(last_event,w);assert(m.state_hash()==before_vfx);w._process(.18);await capture("portrait_cn_circuit")
	w.reduced_motion=true;w._process(.1);await capture("portrait_cn_reduced_motion")
	# Text scaling must keep controls reachable through local scrolling.
	assert(is_equal_approx(float(TweakControls.value(&"ui.text_scale")),1.2));screen._refresh_inspector();await frames(5);await capture("portrait_cn_large_text")
	screen._inspector_scroll.scroll_vertical=1000;await capture("portrait_cn_large_text_scrolled")
	print("ULTIMATE_LAYOUT ",screen._inspector_panel.size," scroll=",screen._inspector_scroll.size," vbox=",screen.inspector.size)
	for child:Control in screen.inspector.get_children():print("ULTIMATE_CHILD ",child.get_class()," ",child.size," ",child.get_combined_minimum_size())
	assert(screen._inspector_panel.position.x+screen._inspector_panel.size.x<=720)
	assert(screen._inspector_panel.position.y+screen._inspector_panel.size.y<=903)
	assert(TweakControls.reset_value(&"ui.text_scale"))
	# Culling, deduplication, particle/effect bounds and teardown.
	w.reduced_motion=false;w.ultimate_effects.clear();w.combat_particles.clear()
	var ev:=last_event.duplicate(true)
	for i:int in 100:
		ev.tick=m.tick+i+10;w.ultimate_effects.trigger(ev,w)
	assert(w.ultimate_effects.active.size()==w.ultimate_effects.MAX_EFFECTS);assert(w.combat_particles.particles.size()<=w.combat_particles.MAX_PARTICLES)
	assert(not w.ultimate_effects.trigger(ev,w))
	w.pan=Vector2(9999,9999);w.framing();ev.tick+=1;assert(not w.ultimate_effects.trigger(ev,w));w.ultimate_effects.advance(.1,w);assert(w.ultimate_effects.active.is_empty())
	w.reset_view();assert(not w.ultimate_effects.trigger(ev,w))
	ev.tick+=1;assert(w.ultimate_effects.trigger(ev,w));w.ultimate_effects.advance(2,w);assert(w.ultimate_effects.active.is_empty())
	assert(m.apply_action([&"retreat",subject.id]));w.ultimate_effects.advance(.1,w);assert(w.ultimate_effects.seen.is_empty())
	var ref:WeakRef=weakref(w);Game.open_title();await frames(12);assert(ref.get_ref()==null)
	I18n.set_locale(&"en-US");await frames(5)
	print("ULTIMATE_NATIVE_PASS six actual casts; cooldown HUD; pause; CN portrait; large text; reduced motion; culling; caps; teardown")
	get_tree().quit()
