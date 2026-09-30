extends "res://test/fablewood_merge_capture.gd"
var OUT_ANIM:String="/home/ubuntu/fablewood_merge_resolution/"+OS.get_environment("RESOLUTION_PASS")+"/"
const A:=preload("res://scripts/fablewood/merged_animation.gd")
func capture(name:String)->void:
	screen.world._sync_terrain();screen.world.queue_redraw();await frames(3);await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_ANIM+name+".png")
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT_ANIM)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model
	var w:Control=screen.world;w.presentation_paused=false;w.reduced_motion=false;w.set_process(false)
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			if m.stage.is_elevated_platform(Vector2i(x,y)):cells.append(Vector2i(x,y))
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,3))<b.distance_squared_to(Vector2i(4,3)))
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var guardians:Array[UnitState]=[]
	for i:int in 4:
		for j:int in range(i+1,4):
			await get_tree().create_timer(.12).timeout
			var a:=add(ids[i],cells[guardians.size()]);var b:=add(ids[j],cells[-1]);m.drain_events()
			var played:int=Sfx._audible_start_count
			var merge_frame:int=Sfx._last_started_frame_by_id.get(&"merge_success",-1)
			assert(m.apply_action([&"begin_merge",a.id,b.id]));screen._present_events()
			assert(w.merge_celebration.active.is_empty());assert(int(Sfx._last_started_frame_by_id.get(&"merge_success",-1))==merge_frame)
			assert(not m.apply_action([&"place_merge",Vector2i(-1,-1)]));screen._present_events();assert(w.merge_celebration.active.is_empty())
			assert(m.apply_action([&"place_merge",cells[guardians.size()]]));screen._present_events()
			var u:UnitState=m.units[-1];guardians.append(u)
			assert(w.merge_celebration.active.size()==1 and Sfx._last_resolved_id==&"merge_success")
			assert(Sfx._audible_start_count>played)
			w.merge_celebration.clear();w.effects.clear();w.combat_particles.clear();await frames(4)
	w.reset_view();w.framing();w.merged_animation.advance(w,.1)
	assert(w.merged_animation.states.size()==6)
	for u:UnitState in guardians:
		for other:UnitState in guardians:other.alive=other==u
		var key:=m.merge_key(u);screen.selected_id=u.id;w.selected=u.id;screen._refresh_inspector()
		w.zoom=1.85;w.pan=Vector2.ZERO;w.framing();w.pan+=Vector2(565,410)-w._origin-w.platform_surface_center(u.cell)*w._scale;w.framing()
		var rect:=A.rect(key,w.platform_surface_center(u.cell),104.0)
		var anchor:Vector2=A.contact_offset(key)
		assert((rect.position+anchor*(104.0/float(A.DATA[key].get("reference_height",480.0)))).distance_to(w.platform_surface_center(u.cell))<.001)
		for state:String in ["idle","cast"]:
			for phase:float in [0.0,1.5,2.666667,3.916667]:
				w.merged_animation.states[u.id]={"idle":phase,"cast":phase,"weight":1.0 if state=="cast" else 0.0,"active":state=="cast","quiet":0.0,"last_attack":-1}
				await capture(key+"_"+state+"_"+str(roundi(phase*12)))
	# Real attacks activate casting; stopping allows recovery without changing stats.
	for u:UnitState in guardians:u.alive=true
	w.reset_view();w.framing();w.merged_animation.clear();w.merged_animation.advance(w,.1)
	m.next_wave();m.step(1);assert(not m.enemies.is_empty())
	var enemy:EnemyState=m.enemies[0];enemy.hp=100000;enemy.progress_units=8000
	var subject:UnitState=guardians[0]
	assert(m._fire_channel(subject,"frost",1,3,30));screen._present_events();w.merged_animation.advance(w,.2)
	assert(w.merged_animation.states[subject.id].active and w.merged_animation.states[subject.id].weight>0)
	var hold:Dictionary=w.merged_animation.states.duplicate(true);w.presentation_paused=true;w._process(.3);assert(hold==w.merged_animation.states)
	w.presentation_paused=false;w.merged_animation.advance(w,4.3);assert(not w.merged_animation.states[subject.id].active)
	w.effects.clear();w.combat_particles.clear();enemy.alive=false
	var event:Dictionary={"kind":"merge_placed","unit":subject.id,"cell":subject.cell,"element":"fire","second_element":"frost"}
	w.merge_celebration.clear();assert(w.merge_celebration.trigger(event,w));assert(not w.merge_celebration.trigger(event,w))
	for phase:float in [.12,.4,1.2]:
		w.merge_celebration.active[0].age=phase;await capture("celebration_"+str(roundi(phase*100)))
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	w=screen.world;w.set_process(false);w.reset_view();w.framing();screen._refresh_inspector()
	w.merge_celebration.clear();assert(w.merge_celebration.trigger(event,w));w.merge_celebration.active[0].age=.4
	await capture("portrait_cn_celebration")
	w.reduced_motion=true;w.merged_animation.advance(w,.1);await capture("reduced_motion")
	for st:Dictionary in w.merged_animation.states.values():assert(st.weight==0)
	w.merge_celebration.advance(3,w);assert(w.merge_celebration.active.is_empty())
	w.reduced_motion=false;w.pan=Vector2(9999,9999);w.framing();event.unit=999
	assert(not w.merge_celebration.trigger(event,w));w.merged_animation.advance(w,.1);assert(w.merged_animation.states.is_empty())
	w.pan=Vector2.ZERO;w.framing();assert(not w.merge_celebration.trigger(event,w))
	var ref:WeakRef=weakref(w);Game.open_title();await frames(12);assert(ref.get_ref()==null)
	print("MERGED_RESOLUTION_NATIVE_PASS six idle/cast states; grounded shared anchors; real attack transition; pause; reduced motion; success-only cue; culling; cleanup; EN/CN")
	get_tree().quit()
