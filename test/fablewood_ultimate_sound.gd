extends "res://test/fablewood_ultimate_capture.gd"
func capture(_name:String)->void:
	await get_tree().create_timer(.13).timeout
func fire(u:UnitState)->void:
	assert(AudioServer.get_driver_name()!="Dummy","This fixture requires a real native audio driver")
	var started:int=Sfx._audible_start_count
	super.fire(u)
	assert(Sfx._audible_start_count>started and Sfx._players.size()==8)
	assert(is_equal_approx(screen.DEFAULT_SFX_VOLUME,.4875))
	var w:Control=screen.world;var pan:Vector2=w.pan
	w.pan=Vector2(9999,9999);w.framing()
	var before:int=Sfx._audible_start_count
	m.events.append(last_event.duplicate(true));screen._present_events()
	assert(Sfx._audible_start_count==before)
	w.pan=pan;w.framing()
	var bus:=AudioServer.get_bus_index("SFX")
	screen._set_volume("SFX",0);assert(AudioServer.is_bus_mute(bus))
	screen._set_volume("SFX",screen.DEFAULT_SFX_VOLUME);assert(not AudioServer.is_bus_mute(bus))
	print("ULTIMATE_REAL_AUDIO_PASS ",m.merge_key(u)," paired cues; 8 voices; offscreen silent; mute; default unchanged")
