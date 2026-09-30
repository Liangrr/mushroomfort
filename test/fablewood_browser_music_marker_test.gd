extends SceneTree

const Tracker = preload("res://scripts/fablewood/music_marker.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var music_owner = load("res://autoloads/music.gd")
	var clock = music_owner.MarkerClock.new()
	var tracker := Tracker.new()
	clock.reset()
	assert(not tracker.sample(1, clock.sample(0.0), 0.0, 77.0))
	assert(not tracker.sample(1, clock.sample(76.99), 76.99, 77.0))
	assert(tracker.sample(1, clock.sample(77.02), 77.02, 77.0))
	# A backwards seek is still the same loop and cannot replay its impact.
	clock.seek(70.0)
	assert(clock.seek_serial == 1 and clock.sample(70.0) == 0)
	assert(not tracker.sample(1, clock.sample(70.0), 70.0, 77.0))
	assert(not tracker.sample(1, clock.sample(77.01), 77.01, 77.0))
	# A real end-to-start wrap rearms precisely one impact.
	assert(clock.sample(137.99) == 0)
	assert(not tracker.sample(1, clock.sample(0.02), 0.02, 77.0))
	assert(clock.loop_index == 1)
	assert(not tracker.sample(1, clock.sample(76.98), 76.98, 77.0))
	assert(tracker.sample(1, clock.sample(77.03), 77.03, 77.0))
	assert(not tracker.sample(1, clock.sample(77.05), 77.05, 77.0))
	# Seeking near the end must not fabricate a wrap before audio reaches it.
	clock.seek(137.9)
	assert(clock.sample(137.9) == 1)
	assert(clock.sample(0.01) == 2)
	assert(not tracker.sample(1, clock.loop_index, 0.01, 77.0))
	assert(not tracker.sample(1, clock.sample(76.9), 76.9, 77.0))
	assert(not tracker.sample(1, clock.sample(82.0), 82.0, 77.0))
	assert(tracker.consumed, "A stalled frame must consume, not defer, an old impact")
	# Restarting playback begins a fresh serial without replaying a seeked marker.
	clock.reset(90.0)
	assert(clock.loop_index == 0 and clock.seek_serial == 0)
	assert(not tracker.sample(2, clock.sample(90.0), 90.0, 77.0))
	var player = music_owner.MusicPlayer.new()
	assert(player.get_node("GodotFallback") is AudioStreamPlayer)
	assert(not player.uses_browser_audio())
	player.free()
	print("BROWSER_MUSIC_MARKER_PASS: actual wraps rearm; seeks, repeats and stalls do not; native fallback retained")
	quit()
