extends Node
## Native capture harness for visual iteration (not shipped).
## Scenarios drive the real game through Main: title, maps, battle, and
## mid-wave combat with towers, saving PNGs to /tmp/mg_cap/.

var scenario := "all"
var out_dir := "/tmp/mg_cap"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		scenario = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("CAPTURED ", name, " ", img.get_size())


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _main() -> Node:
	return get_tree().root.get_node("Main")


func _run() -> void:
	var lang := "zh" if scenario.ends_with("_zh") else "en"
	Loc.set_lang(lang)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _wait(1.2)
	if scenario.begins_with("all") or scenario.begins_with("title"):
		await _snap("title_" + lang)
	if scenario.begins_with("shell"):
		main.open_settings()
		await _wait(0.6)
		await _snap("settings_" + lang)
		main.close_modals()
		await _wait(0.3)
		main.open_help()
		await _wait(0.6)
		await _snap("help_" + lang)
		get_tree().quit(0)
		return
	if scenario.begins_with("click"):
		var play: Control = main.current.find_child("PlayButton", true, false)
		var at := play.get_global_rect().get_center()
		print("play button rect ", play.get_global_rect(), " visible ", play.is_visible_in_tree())
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		Input.parse_input_event(mv)
		await _wait(0.2)
		print("hovered: ", get_viewport().gui_get_hovered_control())
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = at
			ev.global_position = at
			Input.parse_input_event(ev)
			await _wait(0.05)
		await _wait(1.0)
		print("after click current: ", main.current.get_script().resource_path)
		get_tree().quit(0)
		return
	if scenario.begins_with("all") or scenario.begins_with("maps"):
		main.go("map_select")
		await _wait(1.2)
		await _snap("maps_" + lang)
	if scenario.begins_with("swarm"):
		Save.set_tutorial_done(true)
		main.go("battle", {"level": 1})
		await _wait(1.4)
		var sb: BattleScene = main.current
		sb.gold = 9000
		var cells := _good_cells(sb, 6)
		var kinds := [["boom", "a2"], ["boom", "b2"], ["puff", "b2"], ["dew", "a2"], ["thorn", "a2"], ["puff", "a2"]]
		for i in mini(cells.size(), kinds.size()):
			sb.try_build(cells[i], kinds[i][0])
			var tw: Tower = sb.towers[cells[i]]
			sb.try_upgrade(tw, "2")
			sb.try_upgrade(tw, str(kinds[i][1]).substr(0, 1) + "1")
			sb.try_upgrade(tw, kinds[i][1])
		sb.state = "wave"
		sb.wave_index = 3
		var ids := ["munchbug", "dashmite", "shellback", "gloop", "duskmoth"]
		for k in 42:
			var tr: PathTrack = sb.air_tracks[k % sb.air_tracks.size()] if ids[k % 5] == "duskmoth" else sb.ground_tracks[k % sb.ground_tracks.size()]
			sb._spawn(ids[k % 5], tr, 1.4, 180.0 + float(k % 14) * 34.0)
		for n in 6:
			await _wait(0.25)
			await _snap("swarm_%d_%s" % [n, lang])
		if scenario.contains("perf"):
			sb.speed_index = 1
			for k in 60:
				var tr2: PathTrack = sb.ground_tracks[k % sb.ground_tracks.size()]
				sb._spawn(["munchbug", "gloop", "dashmite"][k % 3], tr2, 2.0, float(k % 20) * 25.0)
			for sec in 8:
				await _wait(1.0)
				print("PERF fps=%d process_ms=%.2f physics_ms=%.2f draw_calls=%d objects=%d enemies=%d" % [
					Engine.get_frames_per_second(),
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					sb.enemies.size()])
		print("MG_CAPTURE_DONE")
		get_tree().quit(0)
		return
	if scenario.begins_with("all") or scenario.begins_with("battle"):
		var level := 0
		if scenario.contains("L2"):
			level = 1
		elif scenario.contains("L3"):
			level = 2
		if not scenario.contains("tutorial"):
			Save.set_tutorial_done(true)
		main.go("battle", {"level": level})
		await _wait(1.4)
		await _snap("battle_start_L%d_%s" % [level + 1, lang])
		var b: BattleScene = main.current
		b.gold = 5000
		# A representative defence with every tower family and both branches.
		var picks := [["thorn", "a2"], ["puff", "a1"], ["dew", "b1"], ["boom", "b2"], ["thorn", "b1"], ["puff", "b2"], ["dew", "a2"], ["boom", "a1"]]
		var bot_cells := _good_cells(b, picks.size())
		for i in mini(picks.size(), bot_cells.size()):
			b.try_build(bot_cells[i], picks[i][0])
			var t: Tower = b.towers[bot_cells[i]]
			var target: String = picks[i][1]
			b.try_upgrade(t, "2")
			b.try_upgrade(t, target.substr(0, 1) + "1")
			if target.ends_with("2"):
				b.try_upgrade(t, target)
		b.select_tower(b.towers[bot_cells[0]])
		await _wait(0.6)
		await _snap("battle_selected_L%d_%s" % [level + 1, lang])
		b.deselect()
		b.open_ring(_free_cell(b))
		b.ring_tower = "boom"
		await _wait(0.5)
		await _snap("battle_ring_L%d_%s" % [level + 1, lang])
		b.close_ring()
		b.speed_index = 1
		var waves := 6 if level == 0 else 5
		for w in waves:
			b.start_next_wave()
			await _wait(2.2)
		await _snap("battle_combat_L%d_%s" % [level + 1, lang])
		await _wait(2.5)
		await _snap("battle_combat2_L%d_%s" % [level + 1, lang])
		b.hud.open_pause()
		await _wait(0.6)
		await _snap("battle_pause_L%d_%s" % [level + 1, lang])
		b.hud.close_pause()
		b._finish(true)
		await _wait(3.2)
		await _snap("battle_result_L%d_%s" % [level + 1, lang])
	print("MG_CAPTURE_DONE")
	get_tree().quit(0)


func _good_cells(b: BattleScene, n: int) -> Array:
	var scored: Array = []
	for y in b.rows:
		for x in b.cols:
			var c := Vector2i(x, y)
			if not b.is_buildable(c):
				continue
			var p := b.cell_center(c)
			var s := 0.0
			for tr: PathTrack in b.ground_tracks:
				var d := 0.0
				while d < tr.length:
					if tr.sample(d).distance_to(p) < 150.0:
						s += 1.0
					d += 16.0
			scored.append([s, c])
	scored.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])
	var out: Array = []
	for e in scored:
		var ok := true
		for o: Vector2i in out:
			if (o - e[1]).length() < 2.0:
				ok = false
		if ok:
			out.append(e[1])
		if out.size() >= n:
			break
	return out


func _free_cell(b: BattleScene) -> Vector2i:
	for y in range(3, b.rows):
		for x in range(3, b.cols):
			if b.is_buildable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(5, 5)
