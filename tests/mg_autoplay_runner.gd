extends Node
## Headless balance bot: plays every level with scripted strategies and prints
## lives / stars per level. Run: tools/run_godot_test.sh tests/mg_autoplay.gd -- [strategy] [levels]
##   strategy: balanced (default) | novice | greedy | single_<tower>
## Prints "MG_AUTOPLAY_DONE" at the end.

const DT := 1.0 / 30.0

var strategy := "balanced"


func _ready() -> void:
	Engine.set_meta("autoplay", true)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		strategy = args[0]
	var levels: Array = [0, 1, 2]
	if args.size() > 1:
		levels = []
		for s in args[1].split(","):
			levels.append(int(s))
	_run.call_deferred(levels)


func _run(levels: Array) -> void:
	Save.set_tutorial_done(true)
	for li in levels:
		await _play(int(li))
	print("MG_AUTOPLAY_DONE")
	get_tree().quit(0)


func _play(li: int) -> void:
	var b: BattleScene = load("res://scripts/battle/battle.gd").new()
	b.level_index = li
	get_tree().root.add_child(b)
	await get_tree().process_frame
	b.set_process(false)
	b.set_process_unhandled_input(false)
	var bot := Bot.new(b, strategy)
	var t := 0.0
	var wave_log := []
	var last_wave := -1
	var lives_at_wave := b.lives
	while b.state != "won" and b.state != "lost" and t < 4000.0:
		bot.think()
		b.sim_step(DT)
		b.fx.step(DT)
		t += DT
		if b.wave_index != last_wave:
			if last_wave >= 0:
				wave_log.append("%d:-%d" % [last_wave + 1, lives_at_wave - b.lives])
			lives_at_wave = b.lives
			last_wave = b.wave_index
	wave_log.append("%d:-%d" % [last_wave + 1, lives_at_wave - b.lives])
	var tower_desc := {}
	for tw: Tower in b.towers.values():
		var k := "%s%s" % [tw.tower_id, tw.level_key]
		tower_desc[k] = int(tower_desc.get(k, 0)) + 1
	print("MG_RESULT level=%d strategy=%s state=%s lives=%d/%d stars=%d wave=%d/%d time=%.0fs kills=%d gold_left=%d towers=%s" % [
		li + 1, strategy, b.state, b.lives, b.max_lives, b.stars_for(b.lives) if b.state == "won" else 0,
		b.wave_index + 1, b.waves.size(), t, b.kills, b.gold, JSON.stringify(tower_desc)])
	print("  leaks per wave: ", " ".join(wave_log), "  by enemy: ", JSON.stringify(b.leak_log))
	b.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


class Bot:
	var b: BattleScene
	var strategy: String
	var builds := 0
	var ups := 0
	var order: Array = ["thorn", "puff", "dew", "boom", "thorn", "puff", "boom", "thorn", "dew", "puff", "boom", "thorn"]
	var branch_pick := {"puff": ["a1", "b1"], "dew": ["a1", "b1"], "thorn": ["a1", "b1"], "boom": ["b1", "a1"]}
	var branch_count := {}

	func _init(battle: BattleScene, strat: String) -> void:
		b = battle
		strategy = strat
		if strat.begins_with("single_"):
			order = [strat.substr(7)]

	func think() -> void:
		if b.state == "prep":
			_spend()
			b.start_next_wave()
			return
		_spend()
		if strategy == "greedy" and b.can_call_wave() and b.enemies.size() < 4:
			b.start_next_wave()

	func _spend() -> void:
		for guard in 6:
			var want_build := b.towers.size() < 4 or strategy == "novice"
			if not want_build:
				var tiers := 0
				for t: Tower in b.towers.values():
					tiers += t.tier()
				var avg := float(tiers) / b.towers.size()
				var max_towers := 14 if strategy != "greedy" else 12
				want_build = avg >= 2.6 and b.towers.size() < max_towers
				if b.towers.size() >= max_towers:
					want_build = false
			if want_build:
				var tid: String = order[builds % order.size()]
				if b.gold < b.tower_cost(tid):
					return
				var c := _best_cell(tid)
				if c == Vector2i(-1, -1):
					return
				if b.try_build(c, tid):
					builds += 1
				else:
					return
			else:
				if strategy == "novice":
					return
				var best: Tower = null
				var best_cost := 1 << 30
				var best_key := ""
				for t: Tower in b.towers.values():
					var opts: Array = t.next_options()
					if opts.is_empty():
						continue
					var key := str(opts[0])
					if opts.size() > 1:
						var n := int(branch_count.get(t.tower_id, 0))
						key = str(branch_pick[t.tower_id][n % 2])
					var cost := int(GameData.tower_stats(t.tower_id, key).get("cost", 0)) + t.tier() * 40
					if cost < best_cost:
						best_cost = cost
						best = t
						best_key = key
				if best == null:
					return
				var real := int(GameData.tower_stats(best.tower_id, best_key).get("cost", 0))
				if b.gold < real:
					return
				if best.next_options().size() > 1:
					branch_count[best.tower_id] = int(branch_count.get(best.tower_id, 0)) + 1
				b.try_upgrade(best, best_key)
				ups += 1

	func _best_cell(tid: String) -> Vector2i:
		var st := GameData.tower_stats(tid, "1")
		var r := float(st.get("range", 100))
		var air := bool(st.get("air", true))
		var best := Vector2i(-1, -1)
		var best_score := 0.0
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
						if tr.sample(d).distance_to(p) <= r * 0.92:
							s += 1.0
						d += 12.0
				if air:
					for tr: PathTrack in b.air_tracks:
						var d := 0.0
						while d < tr.length:
							if tr.sample(d).distance_to(p) <= r * 0.92:
								s += 0.6
							d += 12.0
				# Spread out: avoid stacking identical towers.
				for t: Tower in b.towers.values():
					if t.tower_id == tid and t.position.distance_to(p) < r * 0.7:
						s *= 0.8
				if s > best_score:
					best_score = s
					best = c
		return best
