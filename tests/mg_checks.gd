extends SceneTree
## Data contract checks for Mushroom Garrison (no autoloads needed).
## Run: tools/run_godot_test.sh tests/mg_checks.gd   -> prints "MG_CHECKS failures=0"
## Validates towers (2 branches each), enemies, levels (3 maps, 10-15 waves,
## valid enemy/path references, paths inside the grid) and zh/en string parity.

var failures := 0


func _initialize() -> void:
	var towers: Dictionary = _json("res://data/game/towers.json")
	var enemies: Dictionary = _json("res://data/game/enemies.json").get("enemies", {})
	var balance: Dictionary = _json("res://data/game/balance.json")
	var zh: Dictionary = _json("res://localization/zh.json")
	var en: Dictionary = _json("res://localization/en.json")

	# Strings: same key set in both languages.
	for k in zh:
		_check(en.has(k), "en missing key %s" % k)
	for k in en:
		_check(zh.has(k), "zh missing key %s" % k)

	# Towers: 4 roles, each with branch a and b reachable from level 2.
	var order: Array = towers.get("order", [])
	_check(order.size() == 4, "expected 4 towers, got %d" % order.size())
	for id in order:
		var t: Dictionary = towers.towers.get(id, {})
		var lv: Dictionary = t.get("levels", {})
		_check(lv.has("1") and lv.has("2"), "%s needs levels 1 and 2" % id)
		var nxt: Array = lv.get("2", {}).get("next", [])
		_check(nxt.size() == 2, "%s level 2 must fork into two branches" % id)
		for key in lv:
			var st: Dictionary = lv[key]
			_check(int(st.get("cost", 0)) > 0, "%s.%s cost" % [id, key])
			_check(float(st.get("range", 0)) > 0.0, "%s.%s range" % [id, key])
			_check(ResourceLoader.exists("res://assets/mg/towers/%s.png" % st.get("sprite", "")), "%s.%s sprite missing" % [id, key])
			for n in st.get("next", []):
				_check(lv.has(n), "%s.%s -> unknown level %s" % [id, key, n])
			for sk in ["name", "desc"]:
				if st.has(sk):
					_check(zh.has(st[sk]), "string %s" % st[sk])
		_check(zh.has(t.get("name", "")), "tower name string %s" % t.get("name", ""))

	# Enemies: split targets exist.
	for id in enemies:
		var e: Dictionary = enemies[id]
		_check(float(e.get("hp", 0)) > 0.0 and float(e.get("speed", 0)) > 0.0, "enemy %s hp/speed" % id)
		if e.has("split"):
			_check(enemies.has(e.split.get("into", "")), "enemy %s splits into unknown" % id)

	# Levels.
	var levels: Array = balance.get("level_order", [])
	_check(levels.size() == 3, "expected 3 levels")
	for lid in levels:
		var l: Dictionary = _json("res://data/game/levels/%s.json" % lid)
		var waves: Array = l.get("waves", [])
		_check(waves.size() >= 10 and waves.size() <= 15, "%s has %d waves" % [lid, waves.size()])
		var paths: Array = l.get("paths", [])
		var air: Array = l.get("air_paths", [])
		_check(paths.size() >= 1, "%s needs a ground path" % lid)
		for p in paths + air:
			for pt in p:
				_check(float(pt[0]) >= -1.0 and float(pt[0]) <= 20.0 and float(pt[1]) >= 0.0 and float(pt[1]) <= 10.0, "%s path point out of grid %s" % [lid, str(pt)])
		for wi in waves.size():
			for g in waves[wi].get("groups", []):
				var eid := str(g.get("enemy", ""))
				_check(enemies.has(eid), "%s wave %d unknown enemy %s" % [lid, wi + 1, eid])
				var flying: bool = enemies.get(eid, {}).get("flying", false)
				var pool: Array = air if flying else paths
				_check(int(g.get("path", 0)) < pool.size(), "%s wave %d path index %d" % [lid, wi + 1, int(g.get("path", 0))])
				_check(int(g.get("count", 0)) > 0, "%s wave %d count" % [lid, wi + 1])
		_check(zh.has(l.get("name", "")), "%s name string" % lid)

	print("MG_CHECKS failures=%d" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures += 1
		printerr("CHECK FAILED: ", msg)


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_check(false, "cannot open " + path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		_check(false, "bad json " + path)
		return {}
	return d
