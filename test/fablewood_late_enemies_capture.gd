extends Node
const OUT:="user://fablewood_lategame/native/"
const KINDS:=[&"prismback",&"harrier",&"broodmother"]
const DIRS:={"SE":Vector2i(1,0),"SW":Vector2i(0,1),"NW":Vector2i(-1,0),"NE":Vector2i(0,-1)}
var screen:Control
var m:FablewoodBattle
var w:Control
func frames(n:int=3)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	w._sync_terrain();screen._refresh_hud();w.queue_redraw();await frames();await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK)
func advance(n:int)->void:
	for i:int in n:
		w.capture_enemy_tick();m.step();w.render_alpha=1.0;screen._present_events();w._process(1.0/30.0)
func clear_enemies()->void:
	for e:EnemyState in m.enemies:e.alive=false
	m.late_enemies.cleanup(m);w._enemy_motion.clear();m.drain_events();w.effects.clear();w.combat_particles.clear();m.wave_active=true
func create(kind:StringName,segment:int)->EnemyState:
	m._spawn({"enemy_id":kind,"path_idx":0});var e:EnemyState=m.enemies[-1]
	e.progress_units=segment*Pathing.PROGRESS_SCALE+Pathing.PROGRESS_SCALE/5;e.hp=100000;e.hp_max=100000
	w._enemy_tick_valid=false;w._process(0.0);w.zoom=1.85;w.pan=Vector2.ZERO;w.framing()
	w.pan+=Vector2(530,365)-w._origin-w.enemy_ground_position(e)*w._scale;w.framing();return e
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT);get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	# The real chapter launch consumes this supported NEXT_STAGE setting.
	assert(TweakControls.set_value(&"ui.text_scale",1.2))
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(18)
	assert(is_equal_approx(float(TweakControls.active_value(&"ui.text_scale")),1.2))
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model;w=screen.world
	w.set_process(false);w.presentation_paused=false;w.reduced_motion=false;m.next_wave();m.timeline=WaveTimeline.new()
	var path:=m.path_for(0);var indices:Dictionary={}
	for direction:String in DIRS:
		for i:int in range(1,path.size()-2):
			if path[i+1]-path[i]==DIRS[direction]:indices[direction]=i;break
	assert(indices.size()==4)
	for kind:StringName in KINDS:
		for direction:String in DIRS:
			clear_enemies();var e:=create(kind,indices[direction]);var start:=e.progress_units
			await shot(String(kind)+"_"+direction+"_start")
			advance(12);assert(e.progress_units>start);await shot(String(kind)+"_"+direction+"_move")
			var ground:Vector2=w.enemy_ground_position(e);var phase:float=w.rendered_enemy_phase(e)
			e.stunned_until_tick=m.tick+12;advance(6)
			assert(w.enemy_ground_position(e).distance_to(ground)<.001 and is_equal_approx(w.rendered_enemy_phase(e),phase))
			await shot(String(kind)+"_"+direction+"_stop")
			print("LATE_NATIVE_FACING ",kind," ",direction," grid_delta=",DIRS[direction]," progress_delta=",e.progress_units-start)
		# Actual route reversal/turn: keep camera fixed through the rendered corner.
		clear_enemies();var turn:=create(kind,2);turn.progress_units=Pathing.PROGRESS_SCALE*3-10000;w._enemy_tick_valid=false
		await shot(String(kind)+"_turn_before");advance(8);await shot(String(kind)+"_turn_after")
		w.reduced_motion=true;await shot(String(kind)+"_reduced_motion");w.reduced_motion=false
	# Drive each real model ability and inspect warning/impact phases.
	clear_enemies();var prism:=create(&"prismback",10);prism.step_units=0
	await shot("prismback_shell_full");var cues:int=Sfx._audible_start_count;m._damage_enemy(prism,100000,1);screen._present_events();assert(Sfx._audible_start_count==cues+1);await shot("prismback_shell_broken")
	var hash_before:=m.state_hash();w.presentation_paused=true;var clock:float=w.clock;w._process(.75)
	assert(w.clock==clock and m.state_hash()==hash_before);w.presentation_paused=false
	clear_enemies();var harrier:=create(&"harrier",10);harrier.step_units=0;advance(98);await shot("harrier_windup")
	cues=Sfx._audible_start_count;advance(23);assert(int(m.late_enemies.info(harrier.id).mode)==2 and Sfx._audible_start_count==cues+1);await shot("harrier_dash")
	m.slow_until[harrier.id]=m.tick+60;advance(1);assert(int(m.late_enemies.info(harrier.id).mode)==0);await shot("harrier_frost_counter")
	clear_enemies();var mother:=create(&"broodmother",10);mother.step_units=0;advance(151);await shot("broodmother_windup")
	cues=Sfx._audible_start_count;advance(30);assert(m.late_enemies.children.size()==2 and Sfx._audible_start_count==cues+1);await shot("broodmother_children");advance(44);await shot("broodmother_children_separated")
	# Mother origin is independently culled before sound allocation.
	var starts:int=Sfx._audible_start_count;w.pan=Vector2(99999,99999);w.framing()
	m.events.append({"kind":"brood_spawn","enemy":mother.id,"children":[]});screen._present_events();assert(Sfx._audible_start_count==starts)
	if AudioServer.get_driver_name()!="Dummy":
		Sfx._process(.01);assert(Sfx._world_guards.is_empty());assert(Sfx.player_count()==8)
		w.reset_view();w.pan=Vector2.ZERO;w.framing();var bus:=AudioServer.get_bus_index("SFX")
		AudioServer.set_bus_mute(bus,true);assert(AudioServer.is_bus_mute(bus));assert(is_equal_approx(screen._sfx_volume,.4875));AudioServer.set_bus_mute(bus,false)
		print("LATE_NATIVE_AUDIO_PASS three actual semantic cues; eight-voice cap; offscreen start/active guards; mute/default preserved")
	w.reset_view();w.reduced_motion=true;await shot("reduced_motion_abilities")
	# Actual next-wave names, responsive guide and exact modal-pause restoration.
	clear_enemies();m.wave_active=false;m.wave=7
	m.stage=m.stage.duplicate(true);m.stage.waves=(load("res://data/stages/s3.tres") as StageDef).waves.duplicate(true)
	screen._refresh_inspector();screen._refresh_hud();w.reduced_motion=false
	# The current UI projects scheduled spawns, not only three distinct species.
	var expected_threats:=PackedStringArray()
	for entry:Dictionary in m.get_wave_schedule(m.wave+1):
		if StringName(entry.enemy_id) in KINDS:expected_threats.append(String(entry.enemy_id))
	assert(screen._next_wave_late_threats()==expected_threats)
	for kind:StringName in KINDS:assert(String(kind) in expected_threats)
	await shot("next_wave_threats_en")
	screen.paused=false;screen.open_threats_guide();await frames(5)
	assert(screen.threats_guide_open() and screen.paused)
	var guide_scroll:ScrollContainer=screen.overlay.find_children("*","ScrollContainer",true,false)[0]
	assert(guide_scroll.follow_focus and guide_scroll.scroll_vertical==0)
	await shot("guide_en_top");guide_scroll.scroll_vertical=450;await shot("guide_en_middle");guide_scroll.scroll_vertical=10000;await shot("guide_en_bottom")
	var frozen_tick:=m.tick;screen._process(.3);assert(m.tick==frozen_tick)
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;Input.parse_input_event(escape);await frames(3)
	assert(not screen.threats_guide_open() and not screen.paused)
	screen._show_pause();screen.open_threats_guide();screen.close_threats_guide();assert(screen.paused and screen.overlay.get_meta("pause_menu",false));screen._dismiss();screen.paused=false
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	screen=Game.content;screen.set_process(false);w=screen.world;w.set_process(false);w.reset_view()
	screen._refresh_hud();await shot("next_wave_threats_cn_portrait")
	assert(is_equal_approx(float(TweakControls.value(&"ui.text_scale")),1.2));screen.open_threats_guide();await frames(5)
	guide_scroll=screen.overlay.find_children("*","ScrollContainer",true,false)[0]
	await shot("guide_cn_portrait_large_top");guide_scroll.scroll_vertical=10000;await shot("guide_cn_portrait_large_bottom")
	assert(guide_scroll.get_global_rect().end.x<=720)
	screen.close_threats_guide();assert(TweakControls.reset_value(&"ui.text_scale"))
	m=screen.model;screen._show_tutorial();screen.open_threats_guide();assert(not screen.threats_guide_open());screen._skip_tutorial()
	var old_world:WeakRef=weakref(w);Game.open_title();await frames(8);assert(old_world.get_ref()==null)
	print("LATE_NATIVE_UI_PASS actual pre-wave warnings; English guide top/middle/bottom; Chinese portrait/large text; Escape/prior pause; tutorial ownership; title teardown")

	print("LATE_NATIVE_MOVEMENT_PASS 12 actual facings; displacement; turns; stopped anchors; abilities; pause; reduced motion; offscreen cue rejection")
	get_tree().quit()
