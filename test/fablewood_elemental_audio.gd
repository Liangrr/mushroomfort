extends Node
const OUT:="/home/ubuntu/fablewood_elemental_audio/"
const M:=preload("res://sim/fablewood_battle.gd")
func frames(n:int=8)->void:
	for i:int in n:await get_tree().process_frame
func make()->FablewoodBattle:
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	return M.create_fablewood(load("res://data/stages/s1.tres"),{"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids},42)
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	var screen:Control=Game.content;screen.set_process(false);screen._skip_tutorial();screen.paused=false
	assert(AudioServer.get_driver_name()!="Dummy")
	assert(is_equal_approx(screen._sfx_volume,0.4875))
	assert(Sfx.reload_catalog());assert(Sfx.player_count()==8)
	var cues:Array[StringName]=[]
	for kind:String in ["fire","frost","storm","earth"]:
		cues.append(StringName(kind));cues.append(StringName(kind+"_hit"))
	assert(Sfx.prepare_cues(cues));assert(Sfx.resolved_id_for(&"damage")==&"")
	assert(Music.play_cue(&"fablewood"));assert(Music._active_player().stream.loop)
	var recorder:=AudioEffectRecord.new();var master:=AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master,recorder);recorder.set_recording_active(true)
	for id:StringName in [&"caster_1",&"sniper_1",&"recruit",&"guard_1"]:
		var m:=make();m.dp=9999;screen.model=m;screen.world.model=m
		assert(m.apply_action([&"deploy",id,Vector2i(4,3),0]))
		var u:UnitState=m.units[0];var kind:=m.element(u)
		m.wave=1;m._spawn({"enemy_id":&"goblin","path_idx":0})
		var enemy:EnemyState=m.enemies[0];enemy.hp=1000;enemy.hp_max=1000
		for index:int in m.path_for(0).size():
			var cell:Vector2i=m.path_for(0)[index]
			if maxi(absi(cell.x-u.cell.x),absi(cell.y-u.cell.y))<=m.range_for(u):enemy.progress_units=index*Pathing.PROGRESS_SCALE;break
		m.drain_events();m.tick=1;u.atk_counter=0;m._tick_combat()
		var event:Dictionary={}
		for ev:Dictionary in m.events:
			if ev.kind=="attack":event=ev
		assert(not event.is_empty() and enemy.hp<1000)
		assert(screen._attack_audio_cues(event)==[kind,kind+"_hit"])
		# Launch and impact must be culled independently, before SFX cooldowns/voices.
		var offscreen:=event.duplicate(true);offscreen.cell=Vector2i(1000,1000)
		assert(screen._attack_audio_cues(offscreen)==[kind+"_hit"])
		var launch_only:=event.duplicate(true);launch_only.hits=[]
		assert(screen._attack_audio_cues(launch_only)==[kind])
		screen.world.pan=Vector2(10000,10000);assert(screen._attack_audio_cues(event).is_empty());screen.world.pan=Vector2.ZERO
		Sfx._last_msec_by_id.clear();Sfx._last_started_frame_by_id.clear()
		var before:=Sfx.audible_start_count();var hash_before:=m.state_hash()
		screen._present_events()
		assert(Sfx.audible_start_count()==before+2 and m.state_hash()==hash_before)
		assert(Sfx._last_resolved_id==StringName(kind+"_hit"))
		assert(not Sfx.play(kind+"_hit"),"Same-frame/cooldown duplicate suppressed")
		assert(Sfx.player_count()==8)
		await get_tree().create_timer(1.6).timeout
	# A dense all-element burst stays within eight voices.
	Sfx._last_msec_by_id.clear();Sfx._last_started_frame_by_id.clear()
	for cue:StringName in cues:assert(Sfx.play(String(cue)))
	assert(Sfx.player_count()==8);await get_tree().create_timer(1.4).timeout
	recorder.set_recording_active(false);assert(recorder.get_recording().save_to_wav(OUT+"native_mix.wav")==OK)
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	screen._set_volume("SFX",0);assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	screen._set_volume("SFX",0.4875);assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	Music.stop();Sfx.stop_all()
	print("ELEMENTAL_AUDIO_PASS: eight loaded cues, real attacks emit launch+hit, independent spatial culling, no generic damage/death reuse, unchanged simulation, eight-voice bound, duplicate suppression, real mixer and mute/default preserved")
	get_tree().quit()
