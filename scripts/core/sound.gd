extends Node
## Audio routing and cues.
## Buses: MusicBase (+9.54 dB) -> Music (player volume, <= 0 dB) -> Master
##        SfxBase   (+6.02 dB) -> SFX   (player volume, <= 0 dB) -> Master
## Every cue below carries an explicit mix level (db) so the base gains stay fixed.

const BgmPlayer := preload("res://scripts/manus/browser_bgm_player.gd")
const AUDIO_DIR := "res://assets/mg/audio/"
const MUSIC_BASE_DB := 9.5424
const SFX_BASE_DB := 6.0206
const VOICES := 16

## id -> [file, mix dB, min seconds between plays, pitch jitter]
const CUES := {
	"click": ["click", -12.0, 0.03, 0.04],
	"hover": ["click", -22.0, 0.05, 0.08],
	"build": ["build", -9.0, 0.05, 0.03],
	"upgrade": ["upgrade", -9.0, 0.05, 0.0],
	"sell": ["coin", -10.0, 0.05, 0.04],
	"coin": ["coin", -18.0, 0.08, 0.1],
	"invalid": ["invalid", -12.0, 0.1, 0.0],
	"puff": ["puff", -16.0, 0.06, 0.08],
	"dew": ["dew", -19.0, 0.05, 0.1],
	"frost": ["frost", -15.0, 0.08, 0.06],
	"thorn": ["thorn", -18.0, 0.04, 0.1],
	"launch": ["boom_launch", -16.0, 0.06, 0.08],
	"explode": ["explode", -13.0, 0.05, 0.08],
	"pop": ["pop", -15.0, 0.035, 0.05],
	"hit": ["hit", -22.0, 0.04, 0.12],
	"split": ["split", -14.0, 0.06, 0.06],
	"leak": ["leak", -8.0, 0.1, 0.0],
	"wave": ["wave", -9.0, 0.2, 0.0],
	"victory": ["victory", -9.0, 0.5, 0.0],
	"defeat": ["defeat", -9.0, 0.5, 0.0],
}
const TRACKS := {
	"title": ["bgm_title", -12.0],
	"battle": ["bgm_battle", -13.0],
}

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _streams := {}
var _last_play := {}
var _music: Array = []
var _music_index := 0
var _current_track := ""
var _fade: Tween
var _headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SfxBase"
		add_child(p)
		_voices.append(p)
	for i in 2:
		var m: Node = BgmPlayer.new()
		m.bus = &"MusicBase"
		add_child(m)
		_music.append(m)
	apply_volumes()
	Save.settings_changed.connect(apply_volumes)


## Release playbacks before the engine tears resources down (clean exit logs).
func _exit_tree() -> void:
	for m: Node in _music:
		m.stop()
		m.stream = null
	for v in _voices:
		v.stop()
		v.stream = null
	_streams.clear()


func _setup_buses() -> void:
	_bus("Music", &"Master", 0.0)
	_bus("MusicBase", &"Music", 0.0, MUSIC_BASE_DB)
	_bus("SFX", &"Master", 0.0)
	_bus("SfxBase", &"SFX", 0.0, SFX_BASE_DB)


func _bus(bus_name: String, send: StringName, volume_db: float, amplify_db: float = 0.0) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	AudioServer.set_bus_volume_db(index, volume_db)
	if amplify_db != 0.0 and AudioServer.get_bus_effect_count(index) == 0:
		var amp := AudioEffectAmplify.new()
		amp.volume_db = amplify_db
		AudioServer.add_bus_effect(index, amp)


func apply_volumes() -> void:
	_set_linear("Master", float(Save.get_setting("master")))
	_set_linear("Music", float(Save.get_setting("music")))
	_set_linear("SFX", float(Save.get_setting("sfx")))


func _set_linear(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	value = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, minf(0.0, linear_to_db(maxf(value, 0.0001))))
	AudioServer.set_bus_mute(index, value <= 0.001)


func _stream(file: String) -> AudioStream:
	if _streams.has(file):
		return _streams[file]
	var path := AUDIO_DIR + file + ".ogg"
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("Missing audio %s" % path)
	_streams[file] = s
	return s


## Play a one-shot cue. pitch lets callers raise pitch for combos.
func play(id: String, pitch: float = 1.0, extra_db: float = 0.0) -> void:
	if _headless:
		return
	var cue: Array = CUES.get(id, [])
	if cue.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(id, -10.0)) < float(cue[2]):
		return
	_last_play[id] = now
	var stream := _stream(cue[0])
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = float(cue[1]) + extra_db
	var jitter := float(cue[3])
	voice.pitch_scale = maxf(0.2, pitch * (1.0 + randf_range(-jitter, jitter)))
	voice.play()


## Decode BGM ahead of time (called from the title screen).
func prepare_music(track: String) -> void:
	if _headless:
		return
	var def: Array = TRACKS.get(track, [])
	if def.is_empty():
		return
	var stream := _stream(def[0])
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var warm: Node = BgmPlayer.new()
	warm.bus = &"MusicBase"
	warm.stream = stream
	add_child(warm)
	warm.prepare()
	warm.queue_free()


func play_music(track: String, fade: float = 0.8) -> void:
	if track == _current_track:
		return
	if _headless:
		_current_track = track
		return
	var def: Array = TRACKS.get(track, [])
	var stream: AudioStream = _stream(def[0]) if not def.is_empty() else null
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var old: Node = _music[_music_index]
	_music_index = (_music_index + 1) % _music.size()
	var new_player: Node = _music[_music_index]
	_current_track = track
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	if old.is_playing():
		_fade.tween_property(old, "volume_db", -50.0, fade)
		_fade.chain().tween_callback(old.stop)
	if stream == null:
		return
	new_player.stream = stream
	new_player.volume_db = -50.0
	new_player.play()
	_fade.tween_property(new_player, "volume_db", float(def[1]), fade)


func stop_music(fade: float = 0.6) -> void:
	_current_track = ""
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	for m: Node in _music:
		if m.is_playing():
			_fade.tween_property(m, "volume_db", -50.0, fade)
	_fade.chain().tween_callback(func() -> void:
		for m: Node in _music:
			m.stop())
