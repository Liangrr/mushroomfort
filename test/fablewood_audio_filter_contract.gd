extends SceneTree

const ScreenFilter := preload("res://scripts/fablewood/screen_filter.gd")
var failures := 0


func _init() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var music = root.get_node("Music")
	var sfx = root.get_node("Sfx")
	var tuning = root.get_node("TweakControls")
	# Exercise the owner-preview service explicitly; release gating is tested separately.
	tuning.set_value(&"audio.music_pitch_multiplier", 1.0)
	tuning.begin_stage()
	check(music.play_cue(&"fablewood"), "Supplied music cue starts")
	var player = music._active_player()
	var starts: int = music.start_count()
	var seek_serial: int = player.marker_clock.seek_serial
	var players: int = music.player_count()
	check(tuning.set_value(&"audio.music_pitch_multiplier", 1.1), "Valid music tuning accepted")
	music.apply_stage_tuning()
	check(is_equal_approx(player.pitch_scale, 1.0), "Requested next-stage pitch stays deferred")
	tuning.begin_stage()
	music.apply_stage_tuning()
	check(is_equal_approx(player.pitch_scale, 1.1), "Existing cue consumes active stage pitch")
	music.apply_stage_tuning()
	check(is_equal_approx(player.pitch_scale, 1.1), "Stage pitch is absolute, not compounded")
	check(music.start_count() == starts and player.marker_clock.seek_serial == seek_serial, "Stage tuning never restarts or seeks music")
	check(music.player_count() == players and music.current_id() == &"fablewood", "Stage tuning preserves owner and cue")

	var music_bus := AudioServer.get_bus_index(&"Music")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	var ui_bus := AudioServer.get_bus_index(&"UI")
	check(ui_bus >= 0 and AudioServer.get_bus_send(ui_bus) == &"SFX", "UI is a child of SFX")
	check(is_equal_approx(sfx.ui_volume(), 1.0), "New UI route preserves the delivered unity gain")
	check(sfx.bus_for_cue(&"ui_confirm") == &"UI" and sfx.bus_for_cue(&"fire") == &"SFX", "Semantic UI and combat cues route separately")
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(0.5))
	player.volume_db = -3.0
	music.set_master_volume(0.4)
	check(is_equal_approx(player._effective_gain(), db_to_linear(-3.0) * 0.5 * 0.4), "Browser effective gain includes Music and Master exactly once")
	music.set_master_volume(0.0)
	check(is_zero_approx(player._effective_gain()), "Master mute reaches browser BGM")
	music.set_master_volume(2.0)
	check(is_equal_approx(music.master_volume(), 1.0), "Master gain clamps without boosting supplied mix")
	sfx.set_ui_volume(0.3)
	check(is_equal_approx(sfx.ui_volume(), 0.3), "UI gain consumer updates")
	var ui_probe = load("res://scripts/manus/browser_bgm_player.gd").new()
	ui_probe.bus = &"UI"
	AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(0.4))
	check(is_equal_approx(ui_probe._effective_gain(), 0.3 * 0.4), "UI retains inherited SFX mix")
	AudioServer.set_bus_mute(sfx_bus, true)
	check(is_zero_approx(ui_probe._effective_gain()), "SFX mute includes UI")
	AudioServer.set_bus_mute(sfx_bus, false)
	sfx.set_ui_volume(0.0)
	check(is_zero_approx(ui_probe._effective_gain()), "UI can mute independently")
	sfx.set_ui_volume(1.0)
	ui_probe.free()

	check(tuning.set_value(&"audio.sfx_pitch", 1.1), "Valid next-action SFX pitch accepted")
	check(not sfx.play("missing_contract_cue"), "Unknown cue cannot start")
	check(is_equal_approx(float(tuning.active_value(&"audio.sfx_pitch", 1.0)), 1.0), "Rejected cue does not acknowledge next-action tuning")
	check(sfx.play("confirm"), "Valid UI cue starts")
	check(is_equal_approx(float(tuning.active_value(&"audio.sfx_pitch", 1.0)), 1.1), "Successful cue acknowledges next-action tuning")
	if AudioServer.get_driver_name() != "Dummy":
		var voice = sfx._players[(sfx._voice_cursor + sfx.VOICE_COUNT - 1) % sfx.VOICE_COUNT]
		check(voice.playing and voice.bus == &"UI", "Native semantic UI cue reaches the UI voice")
		check(is_equal_approx(voice.pitch_scale, 1.1), "Acknowledged next-action pitch reaches the actual native voice")

	var effect := ScreenFilter.new()
	root.add_child(effect)
	check(not effect.is_enabled() and not effect._rect.visible, "Filter is disabled by default")
	check(effect._rect.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect._rect.focus_mode == Control.FOCUS_NONE, "Fullscreen filter never owns input or focus")
	effect.set_enabled(true)
	effect.set_intensity(0.0)
	check(not effect._rect.visible, "Zero intensity is exactly the unfiltered baseline")
	effect.set_intensity(2.0)
	check(is_equal_approx(effect.intensity(), 1.0) and effect._rect.visible, "Filter clamps and reaches visible consumer")
	check(is_equal_approx(float(effect._rect.material.get_shader_parameter("intensity")), 1.0), "Filter intensity drives shader")
	check(effect._rect.size == root.get_visible_rect().size, "Filter covers the viewport")
	check(not effect.is_processing(), "Static filter adds no motion or simulation tick")
	effect.set_enabled(false)
	check(not effect._rect.visible, "Filter can be disabled after use")
	effect.queue_free()
	music.stop()
	sfx.stop_all()
	print("FABLEWOOD_AUDIO_FILTER_CONTRACT failures=", failures)
	quit(1 if failures else 0)
