extends Node
const OUT:="/home/ubuntu/fablewood_epic_music/"
func frames(n:int=8)->void:
	for i:int in n:await get_tree().process_frame
func record_mix(player,at:float,name:String,combat:bool=false)->void:
	player.seek(at);await get_tree().create_timer(0.2).timeout
	var recorder:=AudioEffectRecord.new();var master:=AudioServer.get_bus_index("Master")
	AudioServer.add_bus_effect(master,recorder);recorder.set_recording_active(true)
	await get_tree().create_timer(2.0).timeout
	if combat:
		for kind:String in ["fire","frost","storm","earth"]:
			Sfx.play(kind);Sfx.play(kind+"_hit");await get_tree().create_timer(0.8).timeout
	await get_tree().create_timer(2.0).timeout
	recorder.set_recording_active(false);assert(recorder.get_recording().save_to_wav(OUT+name+".wav")==OK)
	AudioServer.remove_bus_effect(master,AudioServer.get_bus_effect_count(master)-1)
func _ready()->void:
	await frames();assert(AudioServer.get_driver_name()!="Dummy")
	Game.open_title();await frames(14)
	var screen:Control=Game.content
	assert(is_equal_approx(screen._sfx_volume,0.4875) and is_equal_approx(screen._music_volume,0.5))
	assert(Music.play_cue(&"fablewood"));await get_tree().create_timer(0.8).timeout
	var player=Music._active_player()
	var cue=load("res://data/presentation/audio/cues/fablewood.tres")
	assert(player.playing and player.playback_type==AudioServer.PLAYBACK_TYPE_STREAM)
	assert(player.stream.loop and absf(player.stream.get_length()-float(cue.get_meta("duration_seconds")))<0.1)
	assert(cue.bpm==80.0 and Music.player_count()==2 and Sfx.player_count()==8)
	var starts:=Music.start_count()
	for i:int in 30:assert(Music.play_cue(&"fablewood"))
	assert(Music.start_count()==starts)
	await record_mix(player,12.0,"native_pastoral")
	await record_mix(player,92.0,"native_heroic_combat",true)
	player.seek(player.stream.get_length()-1.0);await get_tree().create_timer(2.0).timeout
	assert(player.playing and player.get_playback_position()<4.0 and Music.start_count()==starts)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=false
	var before:float=player.get_playback_position();screen._show_pause();await get_tree().create_timer(0.3).timeout
	assert(screen.paused and player.playing and Music.start_count()==starts)
	screen._dismiss();screen.paused=false;assert(player.get_playback_position()>=before)
	screen._set_volume("Music",0);assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	screen._set_volume("Music",0.5);assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))
	Game.open_title();await frames();assert(Music.start_count()==starts and player.playing)
	Music.stop();Sfx.stop_all()
	print("EPIC_MUSIC_PASS: current soundtrack stream, calm/heroic native captures, natural rollover, no repeated starts, pause/scene retention, two music/eight SFX voices, mute/default preservation")
	get_tree().quit()
