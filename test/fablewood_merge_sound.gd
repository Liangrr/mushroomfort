extends "res://test/fablewood_merge_capture.gd"
func _ready()->void:
	assert(AudioServer.get_driver_name()!="Dummy")
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model
	assert(is_equal_approx(screen._sfx_volume,.4875));assert(Sfx.player_count()==8)
	assert(Sfx.prepare_cues([&"merge_success"]));assert(Music.play_cue(&"fablewood"))
	var before_music:int=Music.start_count()
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			if m.stage.is_elevated_platform(Vector2i(x,y)):cells.append(Vector2i(x,y))
	var a:=add(&"caster_1",cells[0]);var b:=add(&"sniper_1",cells[1]);m.drain_events()
	assert(m.apply_action([&"begin_merge",a.id,b.id]));screen._present_events()
	await get_tree().create_timer(.5).timeout
	var recorder:=AudioEffectRecord.new();var master:=AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master,recorder);recorder.set_recording_active(true)
	await get_tree().create_timer(.3).timeout
	assert(m.apply_action([&"place_merge",cells[0]]));screen._present_events()
	assert(Sfx._last_resolved_id==&"merge_success" and Sfx._last_stream_path.ends_with("merge_success.ogg"))
	var count:int=Sfx._audible_start_count;screen._present_events();assert(Sfx._audible_start_count==count)
	await get_tree().create_timer(3).timeout
	recorder.set_recording_active(false);assert(recorder.get_recording().save_to_wav("/home/ubuntu/fablewood_merge_animation/audio/native_mix.wav")==OK)
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
	screen._set_volume("SFX",0);assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	screen._set_volume("SFX",.4875);assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	assert(Music.start_count()==before_music and Sfx.player_count()==8)
	Music.stop();Sfx.stop_all();Game.open_title();await frames()
	print("MERGE_SOUND_NATIVE_PASS real placement cue; no duplicate; eight voices; preserved music/default/mute")
	get_tree().quit()
