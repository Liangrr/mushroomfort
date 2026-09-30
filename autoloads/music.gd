extends Node

const BrowserBgmPlayer = preload("res://scripts/manus/browser_bgm_player.gd")

# The buffered browser renderer exposes a loop-relative audio position. Track
# wraps here, with explicit seeks rebasing the cursor rather than inventing a loop.
# Keep this presentation clock local; the canonical audio adapter stays unchanged.
class MarkerClock extends RefCounted:
	var loop_index := 0
	var previous := -1.0
	var seek_serial := 0

	func reset(position: float = 0.0) -> void:
		loop_index = 0
		previous = position
		seek_serial = 0

	func seek(position: float) -> void:
		previous = position
		seek_serial += 1

	func sample(position: float) -> int:
		if previous >= 0.0 and position < previous - 0.001:
			loop_index += 1
		previous = position
		return loop_index

class MusicPlayer extends BrowserBgmPlayer:
	var marker_clock := MarkerClock.new()
	var cue_tempo_scale := 1.0

	func play(from_position: float = 0.0) -> void:
		super.play(from_position)
		marker_clock.reset(get_playback_position())

	func seek(to_position: float) -> void:
		super.seek(to_position)
		marker_clock.seek(get_playback_position())


signal presentation_marker_reached(cue_id:StringName, marker_id:StringName)
const MARKER_TRACKER:=preload("res://scripts/fablewood/music_marker.gd")
var _presentation_marker:=MARKER_TRACKER.new()
var _marker_latency_serial:=-1
var _marker_output_latency:=0.0
var _marker_seek_serial:=0

## Sole runtime music owner. Playback is presentation-only: it never enters the
## deterministic BattleModel, state hash, save data, ticket, or replay.

const CATALOG_PATH := "res://bundled/music/catalog.tres"
const MUSIC_CATALOG_SCRIPT: GDScript = preload("res://bundled/music/music_catalog.gd")
const AUDIO_CUE_SCRIPT: GDScript = preload("res://data/presentation/audio/audio_cue.gd")
const MUSIC_PROFILE_SCRIPT: GDScript = preload("res://data/presentation/audio/music_profile.gd")
const PROFILE_PATHS := {
	&"lunaris": "res://data/presentation/audio/lunaris_profile.tres",
}
const PLAYER_NAMES := [&"Player", &"TransitionPlayer"]
const BUS_NAME := &"Music"
const CRITICAL_STATES := [&"critical", &"boss_critical"]
const CRITICAL_TEMPO_SCALE := 1.08

var _catalog: Resource = null
var _players: Array[MusicPlayer] = []
var _active_index := 1
var _current_id: StringName = &""
var _current_profile_id: StringName = &""
var _current_variant_id: StringName = &""
var _current_state_id: StringName = &""
var _pending_cue_id: StringName = &""
var _pending_state_id: StringName = &""
var _pending_due_msec := -1
var _pending_audio_seconds := -1.0
var _pending_previous_position := 0.0
var _pending_fade_seconds := 0.0
var _fade_tween: Tween = null
var _enabled := true
var _start_count := 0
var _stop_count := 0
var _last_transition_fade_seconds := 0.0
var _prepared_streams: Dictionary = {}


func _ready() -> void:
	reload_catalog()
	_ensure_players()
	set_process(true)


func _process(_delta: float) -> void:
	_update_presentation_marker()
	if _pending_audio_seconds < 0.0:
		return
	var player := _active_player()
	if not player.playing:
		return
	var position := player.get_playback_position()
	var advanced := position - _pending_previous_position
	if advanced < 0.0 and player.stream != null:
		advanced += player.stream.get_length()
	_pending_previous_position = position
	_pending_audio_seconds = maxf(_pending_audio_seconds - maxf(advanced, 0.0), 0.0)
	_pending_due_msec = roundi(_pending_audio_seconds * 1000.0)
	if _pending_audio_seconds > 0.01:
		return
	var cue_id := _pending_cue_id
	var state_id := _pending_state_id
	var fade_seconds := _pending_fade_seconds
	_clear_pending()
	if _transition_to(cue_id, fade_seconds, _tempo_scale_for_state(state_id)):
		_current_state_id = state_id


func presentation_is_audible()->bool:
	if not _enabled or _players.is_empty() or AudioServer.get_driver_name()=="Dummy":return false
	var player:=_players[_active_index]
	if not player.playing or player.stream_paused:return false
	for name:String in ["Music","Master"]:
		var bus:=AudioServer.get_bus_index(name)
		if bus>=0 and (AudioServer.is_bus_mute(bus) or AudioServer.get_bus_volume_db(bus)<=-60):return false
	return true

func _update_presentation_marker()->void:
	if _current_id!=&"fablewood":
		_presentation_marker.reset();return
	if _players.is_empty():return
	var player:=_players[_active_index]
	if not player.playing or player.stream==null or player.stream_paused:return
	var cue:=_cue_for(_current_id)
	var marker:=float(cue.get_meta("epic_entry_seconds",-1.0))
	var length:=player.stream.get_length()
	if marker<0 or length<=0:return
	var position:=player.get_playback_position()
	var loop_index:=0
	if player.uses_browser_audio():
		# This is the Web Audio clock; Godot mixer latency must not be subtracted.
		loop_index=player.marker_clock.sample(position)
	else:
		var playback:=player._native.get_stream_playback()
		if playback==null:return
		# Native playback retains its actual decoder loop count and audible latency.
		var absolute:=float(playback.get_loop_count())*length+position
		if _marker_latency_serial!=_start_count:
			_marker_output_latency=AudioServer.get_output_latency()
			_marker_latency_serial=_start_count
		absolute+=(AudioServer.get_time_since_last_mix()-_marker_output_latency)*player.pitch_scale
		absolute=maxf(absolute,0)
		loop_index=floori(absolute/length)
		position=fposmod(absolute,length)
	var seeking:=_marker_seek_serial!=player.marker_clock.seek_serial
	_marker_seek_serial=player.marker_clock.seek_serial
	var reached:=_presentation_marker.sample(_start_count,loop_index,position,marker)
	# Sampling consumes a seek past the marker without queuing a delayed impact.
	if reached and not seeking:
		presentation_marker_reached.emit(_current_id,&"epic_entry")

func reload_catalog() -> bool:
	var loaded := load(CATALOG_PATH) as Resource
	if loaded == null or loaded.get_script() != MUSIC_CATALOG_SCRIPT:
		_catalog = null
		return false
	var entries_value: Variant = loaded.get("entries")
	if not entries_value is Dictionary or entries_value.is_empty():
		_catalog = null
		return false
	_catalog = loaded
	return true


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		stop()


func is_enabled() -> bool:
	return _enabled


## Stage tuning changes the existing voice, never its playback/marker clock.
func apply_stage_tuning() -> void:
	var multiplier := float(TweakControls.value(&"audio.music_pitch_multiplier", 1.0))
	for player: MusicPlayer in _ensure_players():
		var pitch := maxf(player.cue_tempo_scale * multiplier, 0.01)
		if not is_equal_approx(player.pitch_scale, pitch):
			player.pitch_scale = pitch


func set_master_volume(value: float) -> void:
	if not is_finite(value):
		return
	var volume := clampf(value, 0.0, 1.0)
	var index := AudioServer.get_bus_index(&"Master")
	var decibels := linear_to_db(maxf(volume, 0.001))
	if not is_equal_approx(AudioServer.get_bus_volume_db(index), decibels):
		AudioServer.set_bus_volume_db(index, decibels)
	if AudioServer.is_bus_mute(index) != (volume <= 0.0):
		AudioServer.set_bus_mute(index, volume <= 0.0)
	# The shared adapter mirrors Master into its independent Web Audio renderer.
	for player: MusicPlayer in _players:
		player._sync_controls()


func master_volume() -> float:
	var index := AudioServer.get_bus_index(&"Master")
	return 0.0 if AudioServer.is_bus_mute(index) else clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


## Valid repeats are successful no-ops: no seek and no restart.
func play_cue(cue_id: StringName) -> bool:
	if not _enabled or cue_id.is_empty():
		return false
	if _current_id == cue_id and (AudioServer.get_driver_name()=="Dummy" or _active_player().playing):
		_clear_pending()
		return true
	if not _transition_to(cue_id, 0.0):
		return false
	_clear_pending()
	return true


func transition_to_cue(cue_id: StringName, fade_seconds: float = 0.75) -> bool:
	if not _enabled or cue_id.is_empty():
		return false
	if _current_id == cue_id and (AudioServer.get_driver_name()=="Dummy" or _active_player().playing):
		_clear_pending()
		return true
	if not _transition_to(cue_id, maxf(fade_seconds, 0.0)):
		return false
	_clear_pending()
	return true


func transition_to_staging(
	profile_id: StringName = &"lunaris",
	fade_seconds: float = 0.75,
) -> bool:
	var profile := _profile_for(profile_id)
	if profile == null or not transition_to_cue(profile.staging_cue_id, fade_seconds):
		return false
	_current_profile_id = profile_id
	_current_variant_id = &"staging"
	_current_state_id = &"staging"
	return true


func play_staging(profile_id: StringName = &"lunaris") -> bool:
	var profile := _profile_for(profile_id)
	if profile == null:
		return false
	if not play_cue(profile.staging_cue_id):
		return false
	_current_profile_id = profile_id
	_current_variant_id = &"staging"
	_current_state_id = &"staging"
	return true


func play_battle(
	profile_id: StringName,
	variant_id: StringName,
	state_id: StringName = &"low",
) -> bool:
	if not _enabled:
		return false
	var profile := _profile_for(profile_id)
	if profile == null:
		return false
	var cue_id := profile.cue_id_for(variant_id, state_id)
	if cue_id.is_empty():
		return false
	if not _transition_to(cue_id, 0.0):
		return false
	_clear_pending()
	_current_profile_id = profile_id
	_current_variant_id = variant_id
	_current_state_id = state_id
	return true


func request_battle_state(state_id: StringName, danger: bool = false) -> bool:
	if not _enabled or _current_profile_id.is_empty() or _current_variant_id.is_empty():
		return false
	if state_id == _current_state_id:
		if not _pending_state_id.is_empty() and _pending_state_id != state_id:
			_clear_pending()
		return true
	if state_id == _pending_state_id:
		return true
	var profile := _profile_for(_current_profile_id)
	if profile == null:
		return false
	var cue_id := profile.cue_id_for(_current_variant_id, state_id)
	var cue := _cue_for(cue_id)
	var active_cue := _cue_for(_current_id)
	if cue == null or active_cue == null:
		return false
	if (
		cue_id == _current_id
		and _active_player().playing
		and String(_current_variant_id).begins_with("act2_")
	):
		_clear_pending()
		_current_state_id = state_id
		return true
	var bar_seconds := active_cue.seconds_per_bar()
	if bar_seconds <= 0.0 or not _active_player().playing:
		if not _transition_to(
			cue_id,
			profile.danger_crossfade_seconds if danger else profile.routine_crossfade_seconds,
			_tempo_scale_for_state(state_id),
		):
			return false
		_current_state_id = state_id
		return true
	var playback_position := _active_player().get_playback_position()
	var current_bar := playback_position / bar_seconds
	var target_bar := (
		floori(current_bar) + 1
		if danger
		else (floori(current_bar / 4.0) + 1) * 4
	)
	var wait_seconds := maxf(float(target_bar) * bar_seconds - playback_position, 0.01)
	_pending_cue_id = cue_id
	_pending_state_id = state_id
	_pending_audio_seconds = wait_seconds
	_pending_previous_position = playback_position
	_pending_due_msec = roundi(wait_seconds * 1000.0)
	_pending_fade_seconds = (
		profile.danger_crossfade_seconds if danger else profile.routine_crossfade_seconds
	)
	return true


func play_result(clear: bool) -> bool:
	var profile := _profile_for(_current_profile_id if not _current_profile_id.is_empty() else &"lunaris")
	if profile == null:
		return false
	if not _transition_to(profile.victory_cue_id if clear else profile.defeat_cue_id, 0.35):
		return false
	_clear_pending()
	_current_variant_id = &"result"
	_current_state_id = &"victory" if clear else &"defeat"
	return true


func prepare_results(profile_id: StringName = &"lunaris") -> bool:
	var profile := _profile_for(profile_id)
	if profile == null:
		return false
	var prepared := true
	for cue_id: StringName in [profile.victory_cue_id, profile.defeat_cue_id]:
		var cue := _cue_for(cue_id)
		if cue == null or not cue.is_valid():
			prepared = false
			continue
		var stream := load(cue.stream_path) as AudioStream
		if stream == null:
			prepared = false
			continue
		_prepared_streams[cue.stream_path] = stream
		if OS.has_feature("web"):
			stream.set("loop", cue.loop)
			var warmup := BrowserBgmPlayer.new()
			warmup.stream = stream
			add_child(warmup)
			if not warmup.prepare():
				prepared = false
			warmup.queue_free()
	return prepared


func stop() -> bool:
	_clear_pending()
	if _current_id.is_empty() and not _any_player_active():
		return false
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
	for player: MusicPlayer in _ensure_players():
		player.stop()
		player.stream = null
		player.pitch_scale = 1.0
		player.volume_db = 0.0
	_current_id = &""
	_current_profile_id = &""
	_current_variant_id = &""
	_current_state_id = &""
	_stop_count += 1
	return true


func current_id() -> StringName:
	return _current_id


func current_profile_id() -> StringName:
	return _current_profile_id


func current_variant_id() -> StringName:
	return _current_variant_id


func current_state_id() -> StringName:
	return _current_state_id


func pending_state_id() -> StringName:
	return _pending_state_id


func pending_due_msec() -> int:
	return _pending_due_msec


func minimum_state_hold_seconds(profile_id: StringName) -> float:
	var profile := _profile_for(profile_id)
	return profile.minimum_state_hold_seconds if profile != null else 0.0


func commit_pending_now_for_test() -> bool:
	if _pending_audio_seconds < 0.0:
		return false
	_pending_audio_seconds = 0.0
	_pending_due_msec = 0
	_process(0.0)
	return true


func start_count() -> int:
	return _start_count


func stop_count() -> int:
	return _stop_count


func player_count() -> int:
	return _ensure_players().size()


func current_stream_path() -> String:
	var player := _active_player()
	return player.stream.resource_path if player.stream != null else ""


func current_tempo_scale() -> float:
	return _active_player().pitch_scale


func last_transition_fade_seconds() -> float:
	return _last_transition_fade_seconds


func _transition_to(
	cue_id: StringName,
	fade_seconds: float,
	tempo_scale: float = 1.0,
) -> bool:
	fade_seconds *= float(TweakControls.value(
		&"audio.transition_duration_multiplier", 1.0,
	))
	var cue := _cue_for(cue_id)
	if cue == null or not cue.is_valid():
		return false
	if _current_id == cue_id and (AudioServer.get_driver_name()=="Dummy" or _active_player().playing):
		return true
	# Dummy playback itself retains OggVorbis objects at exit in Godot; do not
	# allocate inaudible streams in deterministic/native-visual checks.
	if AudioServer.get_driver_name()=="Dummy":
		_active_player().cue_tempo_scale = tempo_scale
		apply_stage_tuning()
		_current_id=cue_id
		_start_count+=1
		return true
	var stream := _prepared_streams.get(cue.stream_path) as AudioStream
	if stream == null:
		stream = load(cue.stream_path) as AudioStream
	if stream == null:
		return false
	# Keep one resource/cache identity for both crossfade voices and later visits.
	_prepared_streams[cue.stream_path] = stream
	stream.set("loop", cue.loop)
	var players := _ensure_players()
	var old_index := _active_index
	var new_index := 1 - _active_index
	var old_player := players[old_index]
	var new_player := players[new_index]
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null
	new_player.stop()
	new_player.stream = stream
	new_player.cue_tempo_scale = tempo_scale
	new_player.pitch_scale = maxf(
		tempo_scale * float(TweakControls.value(&"audio.music_pitch_multiplier", 1.0)),
		0.01,
	)
	new_player.volume_db = cue.volume_db if fade_seconds <= 0.0 else -60.0
	new_player.play()
	_active_index = new_index
	_current_id = cue_id
	_last_transition_fade_seconds = maxf(fade_seconds, 0.0)
	_start_count += 1
	_marker_seek_serial = new_player.marker_clock.seek_serial
	if not old_player.playing or fade_seconds <= 0.0:
		new_player.volume_db = cue.volume_db
		old_player.stop()
		old_player.stream = null
		old_player.pitch_scale = 1.0
		old_player.volume_db = 0.0
		return true
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(new_player, "volume_db", cue.volume_db, fade_seconds)
	_fade_tween.tween_property(old_player, "volume_db", -60.0, fade_seconds)
	_fade_tween.chain().tween_callback(_finish_crossfade.bind(old_index))
	return true


func _finish_crossfade(old_index: int) -> void:
	var players := _ensure_players()
	if old_index >= 0 and old_index < players.size() and old_index != _active_index:
		players[old_index].stop()
		players[old_index].stream = null
		players[old_index].pitch_scale = 1.0
		players[old_index].volume_db = 0.0
	_fade_tween = null


func _cue_for(cue_id: StringName) -> AudioCue:
	if cue_id.is_empty():
		return null
	if _catalog == null and not reload_catalog():
		return null
	var entries_value: Variant = _catalog.get("entries")
	if not entries_value is Dictionary:
		return null
	var entries: Dictionary = entries_value
	var value: Variant = entries.get(cue_id)
	if value is Resource and (value as Resource).get_script() == AUDIO_CUE_SCRIPT:
		return value as AudioCue
	if value is Dictionary:
		var legacy_entry: Dictionary = value
		var stream_path := String(legacy_entry.get("path", ""))
		if stream_path.is_empty():
			return null
		var cue := AUDIO_CUE_SCRIPT.new() as AudioCue
		cue.id = cue_id
		cue.stream_path = stream_path
		cue.loop = bool(legacy_entry.get("loop", true))
		return cue
	return null


func _profile_for(profile_id: StringName) -> MusicProfile:
	var path := String(PROFILE_PATHS.get(profile_id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var profile := load(path) as Resource
	if profile == null or profile.get_script() != MUSIC_PROFILE_SCRIPT:
		return null
	return profile as MusicProfile


func _ensure_players() -> Array[MusicPlayer]:
	_ensure_bus()
	if _players.size() == PLAYER_NAMES.size():
		var all_valid := true
		for player: MusicPlayer in _players:
			if not is_instance_valid(player):
				all_valid = false
				break
		if all_valid:
			for player: MusicPlayer in _players:
				player.bus = BUS_NAME
				player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
			return _players
	_players.clear()
	for player_name: StringName in PLAYER_NAMES:
		var player := get_node_or_null(NodePath(String(player_name))) as MusicPlayer
		if player == null:
			player = MusicPlayer.new()
			player.name = player_name
			add_child(player)
		player.bus = BUS_NAME
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		_players.append(player)
	return _players


func _ensure_bus() -> void:
	var index := AudioServer.get_bus_index(BUS_NAME)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS_NAME)
	if AudioServer.get_bus_send(index) != &"Master":
		AudioServer.set_bus_send(index, &"Master")


func _active_player() -> MusicPlayer:
	return _ensure_players()[_active_index]


func _any_player_active() -> bool:
	for player: MusicPlayer in _ensure_players():
		if player.playing or player.stream != null:
			return true
	return false


func _tempo_scale_for_state(state_id: StringName) -> float:
	return CRITICAL_TEMPO_SCALE if state_id in CRITICAL_STATES else 1.0


func _clear_pending() -> void:
	_pending_cue_id = &""
	_pending_state_id = &""
	_pending_due_msec = -1
	_pending_audio_seconds = -1.0
	_pending_previous_position = 0.0
	_pending_fade_seconds = 0.0

func _exit_tree() -> void:
	stop()
	_prepared_streams.clear()
	_catalog=null
