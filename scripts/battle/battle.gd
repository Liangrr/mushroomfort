class_name BattleScene
extends Node2D
## One level in play: grid, waves, economy, towers, enemies, input and juice.
## All numbers come from data/game/*.json via GameData.

signal tower_built(tower: Tower)
signal tower_selected(tower: Tower)
signal tower_upgraded(tower: Tower)
signal wave_started(index: int)
signal finished(won: bool)

const BattleHud := preload("res://scripts/battle/hud.gd")
const SIM_STEP := 1.0 / 60.0
const PROP_SIZE := {"tree": 124.0, "pine": 112.0, "rock": 72.0, "pond": 112.0, "bush": 84.0, "log": 96.0, "flowers": 72.0, "fern": 76.0, "shrooms": 74.0}

var level_index := 0
var level: Dictionary = {}
var cell := 64.0
var origin := Vector2(0, 8)
var cols := 20
var rows := 11

var ground_tracks: Array[PathTrack] = []
var air_tracks: Array[PathTrack] = []
var blocked := {}
var towers := {}                 # Vector2i -> Tower
var enemies: Array[Enemy] = []

var gold := 0
var lives := 20
var max_lives := 20
var waves: Array = []
var wave_index := -1             # last started wave (0-based)
var state := "prep"              # prep | wave | won | lost
var spawn_queue: Array = []
var wave_time := 0.0
var countdown := 0.0
var speed_index := 0
var paused := false
var kills := 0
var gold_earned := 0
var combo := 0
var combo_timer := 0.0
var best_combo := 0
var leak_log := {}               # enemy id -> lives lost (debug / balance)
var selected: Tower
var build_tower := ""            # tower id while placing from the build bar
var pending_cell := Vector2i(-99, -99)
var cursor_cell := Vector2i(6, 5)
var hover_upgrade_range := 0.0
var ring_cell := Vector2i(-99, -99)
var ring_tower := ""

var world: Node2D
var level_map: LevelMap
var decals: GroundDecals
var ground_overlay: BattleOverlay
var units: Node2D
var flyers: Node2D
var projectiles: Projectiles
var fx: BattleFx
var top_overlay: BattleOverlay
var hud  # BattleHud (scripts/battle/hud.gd)
var vault: Sprite2D

var _trauma := 0.0
var _shake_t := 0.0
var _hitstop := 0.0
var _echoes: Array = []
var _frame_kills := 0
var _cursor_mode := false
var _repeat := {}
var _vault_base_scale := 1.0
var _stats_dirty := true


func _ready() -> void:
	level = GameData.levels[clampi(level_index, 0, GameData.level_count() - 1)]
	var grid: Dictionary = GameData.balance.get("grid", {})
	cell = float(grid.get("cell", 64))
	cols = int(grid.get("cols", 20))
	rows = int(grid.get("rows", 11))
	var o: Array = grid.get("origin", [0, 8])
	origin = Vector2(float(o[0]), float(o[1]))
	gold = int(level.get("start_gold", 250))
	lives = int(level.get("lives", 20))
	max_lives = lives
	waves = level.get("waves", [])
	for p in level.get("paths", []):
		ground_tracks.append(PathTrack.from_cells(p, origin, cell, false))
	for p in level.get("air_paths", []):
		air_tracks.append(PathTrack.from_cells(p, origin, cell, true))
	_build_world()
	_compute_blocked()
	_place_cursor_default()
	hud = BattleHud.new()
	hud.battle = self
	add_child(hud)
	Sound.play_music("battle", 1.0)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_world() -> void:
	world = Node2D.new()
	add_child(world)
	level_map = LevelMap.new()
	level_map.battle = self
	world.add_child(level_map)
	level_map.build(level)
	decals = GroundDecals.new()
	world.add_child(decals)
	ground_overlay = BattleOverlay.new()
	ground_overlay.battle = self
	ground_overlay.mode = "ground"
	world.add_child(ground_overlay)
	units = Node2D.new()
	units.y_sort_enabled = true
	world.add_child(units)
	flyers = Node2D.new()
	flyers.y_sort_enabled = true
	world.add_child(flyers)
	projectiles = Projectiles.new()
	projectiles.battle = self
	world.add_child(projectiles)
	fx = BattleFx.new()
	world.add_child(fx)
	top_overlay = BattleOverlay.new()
	top_overlay.battle = self
	top_overlay.mode = "top"
	world.add_child(top_overlay)
	# Props and the vault share the y-sorted unit layer for natural depth.
	for prop: Dictionary in level.get("props", []):
		var c: Array = prop.get("cell", [0, 0])
		var s := Sprite2D.new()
		var kind := str(prop.get("type", "rock"))
		s.texture = GameData.tex("props/%s.png" % kind)
		if s.texture == null:
			continue
		var target: float = PROP_SIZE.get(kind, 80.0)
		var k := target / float(maxi(s.texture.get_width(), s.texture.get_height()))
		s.scale = Vector2.ONE * k
		s.offset = Vector2(0, -s.texture.get_height() * 0.5)
		s.position = cell_center(Vector2i(int(c[0]), int(c[1]))) + Vector2(0, 26)
		if kind == "pond" or kind == "flowers":
			s.position.y -= 10
		s.flip_h = (int(c[0]) * 7 + int(c[1])) % 2 == 0
		units.add_child(s)
	var v: Array = level.get("vault", [18, 5])
	vault = Sprite2D.new()
	vault.texture = GameData.tex("world/vault_intact.png")
	_vault_base_scale = 150.0 / 320.0
	vault.scale = Vector2.ONE * _vault_base_scale
	vault.offset = Vector2(0, -vault.texture.get_height() * 0.5) if vault.texture != null else Vector2.ZERO
	vault.position = cell_center(Vector2i(int(v[0]), int(v[1]))) + Vector2(0, 40)
	units.add_child(vault)


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	world.position = ((vs - Vector2(1280, 720)) / 2.0).round()
	if level_map != null:
		level_map.queue_redraw()


func _compute_blocked() -> void:
	blocked.clear()
	var clearance := float(GameData.balance.get("path_clearance", 46))
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var center := cell_center(c)
			for t in ground_tracks:
				if t.distance_to_point(center) < clearance:
					blocked[c] = "path"
					break
	for y in GameData.balance.get("blocked_rows", []):
		for x in cols:
			blocked[Vector2i(x, int(y))] = "edge"
	for prop: Dictionary in level.get("props", []):
		var pc: Array = prop.get("cell", [0, 0])
		blocked[Vector2i(int(pc[0]), int(pc[1]))] = "prop"
	var v: Array = level.get("vault", [18, 5])
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			blocked[Vector2i(int(v[0]) + dx, int(v[1]) + dy)] = "vault"


func _place_cursor_default() -> void:
	var best := Vector2i(cols / 2, rows / 2)
	var best_d := INF
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if is_buildable(c):
				var d := Vector2(c).distance_to(Vector2(4, 5))
				if d < best_d:
					best_d = d
					best = c
	cursor_cell = best


# ------------------------------------------------------------ grid helpers

func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(c) * cell, Vector2(cell, cell))


func world_to_cell(p: Vector2) -> Vector2i:
	var q := (p - origin) / cell
	return Vector2i(floori(q.x), floori(q.y))


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func is_buildable(c: Vector2i) -> bool:
	return in_grid(c) and not blocked.has(c) and not towers.has(c)


func build_block_reason(c: Vector2i) -> String:
	if towers.has(c):
		return ""
	if not in_grid(c) or blocked.has(c):
		var why := str(blocked.get(c, "edge"))
		return Loc.t("build.no_path") if why == "path" else Loc.t("build.no_here")
	return ""


func to_screen(p: Vector2) -> Vector2:
	return world.position + p


func speed_factor() -> float:
	if paused or state == "won" or state == "lost":
		return 0.0
	var speeds: Array = GameData.balance.get("speeds", [1, 2])
	return float(speeds[speed_index % speeds.size()])


func speed_label() -> String:
	var speeds: Array = GameData.balance.get("speeds", [1, 2])
	return "x%d" % int(speeds[speed_index % speeds.size()])


# ------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	_poll_cursor(dt)
	var f := speed_factor()
	if _hitstop > 0.0:
		_hitstop -= dt
		f = 0.0
	var sim_dt := dt * f
	_frame_kills = 0
	if sim_dt > 0.0:
		var steps := int(ceil(sim_dt / SIM_STEP - 0.001))
		var h := sim_dt / steps
		for i in steps:
			sim_step(h)
	if _frame_kills >= 3:
		shake(0.12 + minf(_frame_kills, 10) * 0.035)
	# Visuals advance at game speed (frozen when paused).
	var vis_dt := sim_dt
	for e in enemies:
		e.visual_step(vis_dt)
	for t: Tower in towers.values():
		t.visual_step(vis_dt if f > 0.0 else 0.0)
	fx.step(dt * maxf(f, 0.0) if not paused else 0.0)
	_update_shake(dt)
	if _stats_dirty:
		_stats_dirty = false
		hud.refresh_stats()


func sim_step(dt: float) -> void:
	if state == "won" or state == "lost":
		return
	# Spawning.
	if state == "wave":
		wave_time += dt
		while not spawn_queue.is_empty() and spawn_queue[0].t <= wave_time:
			var s: Dictionary = spawn_queue.pop_front()
			_spawn(s.enemy, s.track, s.hp)
		if spawn_queue.is_empty() and wave_index < waves.size() - 1:
			countdown -= dt
			if countdown <= 0.0:
				start_next_wave()
	# Ground effects then movement.
	decals.apply_to(enemies)
	decals.step(dt)
	for e in enemies:
		if e.alive:
			e.sim_step(dt)
	# Delayed echo pulses.
	var i := 0
	while i < _echoes.size():
		_echoes[i].time -= dt
		if _echoes[i].time <= 0.0:
			var echo: Dictionary = _echoes[i]
			_echoes.remove_at(i)
			if is_instance_valid(echo.tower):
				_do_pulse(echo.tower, echo.mult, true)
		else:
			i += 1
	# Towers.
	for t: Tower in towers.values():
		t.cooldown -= dt
		if t.cooldown <= 0.0:
			_tower_try_fire(t)
	projectiles.step(dt)
	# Deaths and leaks.
	var survivors: Array[Enemy] = []
	for e in enemies:
		if e.alive and e.hp <= 0.0:
			_kill(e)
		elif e.alive and e.reached:
			_leak(e)
		if e.alive:
			survivors.append(e)
		else:
			e.queue_free()
	enemies = survivors
	if combo_timer > 0.0:
		combo_timer -= dt
		if combo_timer <= 0.0:
			if combo >= 5:
				hud.end_combo(combo)
			combo = 0
	# Wave end / victory.
	if state == "wave" and spawn_queue.is_empty() and enemies.is_empty():
		if wave_index >= waves.size() - 1:
			_finish(true)
		elif not _wave_cleared_paid:
			_wave_cleared_paid = true
			var bonus := int(GameData.balance.get("wave_clear_bonus", 0))
			if bonus > 0:
				add_gold(bonus)
				hud.toast(Loc.t("hud.wave_clear", {"gold": bonus}), Palette.AMBER_LIGHT)


var _wave_cleared_paid := true


# ------------------------------------------------------------ waves

func start_next_wave() -> void:
	if state == "won" or state == "lost" or wave_index >= waves.size() - 1:
		return
	if state == "wave" and not spawn_queue.is_empty():
		return
	var early := 0
	if state == "wave" and countdown > 0.0:
		early = int(round(countdown * float(GameData.balance.get("early_call_gold_per_second", 2))))
	elif state == "prep" and wave_index >= 0:
		early = 0
	wave_index += 1
	state = "wave"
	wave_time = 0.0
	_wave_cleared_paid = false
	countdown = float(level.get("prep_time", 12))
	spawn_queue = _build_queue(wave_index)
	if early > 0:
		add_gold(early)
		fx.text(Vector2(1180, 90), "+%d" % early, Palette.AMBER_LIGHT, 22)
		hud.toast(Loc.t("hud.early", {"gold": early}), Palette.AMBER_LIGHT)
	Sound.play("wave")
	hud.show_wave_banner(wave_index, bool(waves[wave_index].get("boss", false)))
	wave_started.emit(wave_index)
	_stats_dirty = true


func _build_queue(w: int) -> Array:
	var out: Array = []
	var wave: Dictionary = waves[w]
	var growth := 1.0 + float(level.get("hp_growth", 0.1)) * w
	for g: Dictionary in wave.get("groups", []):
		var def: Dictionary = GameData.enemies.get(str(g.get("enemy", "")), {})
		if def.is_empty():
			push_warning("Unknown enemy %s in %s wave %d" % [g.get("enemy"), level.get("id"), w + 1])
			continue
		var flying := bool(def.get("flying", false))
		var tracks := air_tracks if flying else ground_tracks
		if tracks.is_empty():
			tracks = ground_tracks
		var count := int(g.get("count", 1))
		for k in count:
			var path_i: int = int(g.get("path", k)) % tracks.size()
			out.append({
				"t": float(g.get("delay", 0.0)) + k * float(g.get("gap", 1.0)),
				"enemy": str(g.enemy),
				"track": tracks[path_i],
				"hp": growth * float(g.get("hp", 1.0)),
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	return out


## Enemy types in the upcoming wave (for the HUD preview).
func next_wave_types() -> Array:
	var w := wave_index + 1
	if w >= waves.size():
		return []
	var seen: Array = []
	for g: Dictionary in waves[w].get("groups", []):
		var id := str(g.get("enemy", ""))
		if not id in seen:
			seen.append(id)
	return seen


func can_call_wave() -> bool:
	if state == "prep":
		return true
	return state == "wave" and spawn_queue.is_empty() and wave_index < waves.size() - 1


func _spawn(enemy_id: String, track: PathTrack, hp_scale: float, at_dist: float = 0.0) -> Enemy:
	var e := Enemy.new()
	e.setup(enemy_id, GameData.enemies[enemy_id], track, hp_scale, at_dist)
	(flyers if e.flying else units).add_child(e)
	enemies.append(e)
	if e.boss:
		shake(0.45)
		hud.toast(Loc.t("hud.boss_arrives"), Palette.CORAL_LIGHT)
	return e


# ------------------------------------------------------------ towers

func tower_cost(tower_id: String) -> int:
	return int(GameData.tower_stats(tower_id, "1").get("cost", 100))


func try_build(c: Vector2i, tower_id: String) -> bool:
	if not is_buildable(c):
		Sound.play("invalid")
		hud.toast(build_block_reason(c) if build_block_reason(c) != "" else Loc.t("build.no_here"), Palette.CORAL_LIGHT)
		return false
	var cost := tower_cost(tower_id)
	if gold < cost:
		Sound.play("invalid")
		hud.toast(Loc.t("build.no_gold"), Palette.CORAL_LIGHT)
		hud.shake_gold()
		return false
	gold -= cost
	var t := Tower.new()
	t.setup(tower_id, c, cell_center(c))
	units.add_child(t)
	towers[c] = t
	fx.build_bloom(t.position, t.color, false)
	decals.add_mark(t.position + Vector2(0, 22), 34.0, Color(0.25, 0.15, 0.05, 0.25), 1.2)
	Sound.play("build")
	shake(0.12)
	build_tower = ""
	pending_cell = Vector2i(-99, -99)
	_stats_dirty = true
	tower_built.emit(t)
	return true


func try_upgrade(t: Tower, key: String) -> bool:
	if t == null or not key in t.next_options():
		return false
	var cost := int(GameData.tower_stats(t.tower_id, key).get("cost", 0))
	if gold < cost:
		Sound.play("invalid")
		hud.toast(Loc.t("build.no_gold"), Palette.CORAL_LIGHT)
		hud.shake_gold()
		return false
	gold -= cost
	t.set_level(key)
	fx.build_bloom(t.position, t.color, true)
	fx.ring(t.position + Vector2(0, 8), t.range_px(), Color(Palette.AMBER_LIGHT, 0.8), 0.6, 4.0, 0.3)
	Sound.play("upgrade")
	shake(0.2)
	_stats_dirty = true
	tower_upgraded.emit(t)
	return true


func sell(t: Tower) -> void:
	if t == null:
		return
	var value := t.sell_value()
	add_gold(value, false)
	fx.sell_poof(t.position)
	fx.text(t.position + Vector2(0, -40), "+%d" % value, Palette.AMBER_LIGHT, 22)
	Sound.play("sell")
	towers.erase(t.cell)
	if selected == t:
		deselect()
	t.queue_free()
	_stats_dirty = true


func select_tower(t: Tower) -> void:
	selected = t
	build_tower = ""
	close_ring()
	if t != null:
		cursor_cell = t.cell
		Sound.play("click")
	hud.on_selection_changed()
	tower_selected.emit(t)


func deselect() -> void:
	if selected == null:
		return
	selected = null
	hover_upgrade_range = 0.0
	hud.on_selection_changed()


func add_gold(amount: int, count_as_income: bool = true) -> void:
	gold += amount
	if count_as_income:
		gold_earned += amount
	_stats_dirty = true


func _tower_try_fire(t: Tower) -> void:
	match t.attack():
		"pulse":
			if _any_in_range(t):
				_do_pulse(t, 1.0, false)
				t.cooldown = float(t.stats.get("interval", 1.0))
				var echo: Dictionary = t.stats.get("echo", {})
				if not echo.is_empty():
					_echoes.append({"time": float(echo.get("delay", 0.4)), "tower": t, "mult": float(echo.get("mult", 0.5))})
			else:
				t.cooldown = 0.05
		"lob":
			var target := find_target(t)
			if target != null:
				projectiles.fire_lob(t, target)
				t.on_fire()
				Sound.play("launch")
				t.cooldown = float(t.stats.get("interval", 2.0))
			else:
				t.cooldown = 0.05
		_:
			var target := find_target(t)
			if target != null:
				t.face(target.position)
				var n := int(t.stats.get("spread_count", 1))
				var spread := float(t.stats.get("spread_angle", 0.0))
				for k in n:
					projectiles.fire_shot(t, target, (k - (n - 1) / 2.0) * spread)
				t.on_fire()
				Sound.play("thorn" if str(t.stats.get("projectile", "")).contains("thorn") else "dew")
				t.cooldown = float(t.stats.get("interval", 1.0))
			else:
				t.cooldown = 0.05


func _in_range(t: Tower, e: Enemy) -> bool:
	if not e.alive or (e.flying and not t.hits_air()):
		return false
	var r := t.range_px()
	return t.position.distance_squared_to(e.position) <= r * r


func _any_in_range(t: Tower) -> bool:
	for e in enemies:
		if _in_range(t, e):
			return true
	return false


func find_target(t: Tower) -> Enemy:
	var best: Enemy = null
	var mode := str(t.stats.get("target", "first"))
	var best_score := -INF
	for e in enemies:
		if not _in_range(t, e):
			continue
		var score := -e.remaining()
		if mode == "strong":
			score = e.hp + (100000.0 if e.boss else 0.0) - e.remaining() * 0.01
		if score > best_score:
			best_score = score
			best = e
	return best


func _do_pulse(t: Tower, mult: float, is_echo: bool) -> void:
	var s := t.stats
	var style := str(s.get("pulse_style", "poison" if s.has("poison") else "spore"))
	t.pulse_count += 0 if is_echo else 1
	var freeze := false
	if s.has("freeze_every") and not is_echo:
		freeze = t.pulse_count % int(s.freeze_every) == 0
	var hit := 0
	for e in enemies:
		if not _in_range(t, e):
			continue
		hit += 1
		damage_enemy(e, float(s.get("damage", 10)) * mult, 0.0, t)
		if s.has("slow"):
			e.apply_slow(float(s.slow.get("pct", 0.3)), float(s.slow.get("duration", 1.0)))
		if s.has("poison"):
			e.apply_poison(float(s.poison.get("dps", 10)) * mult, float(s.poison.get("duration", 3.0)), float(s.poison.get("spread", 0.0)))
		if freeze:
			e.apply_stun(float(s.get("freeze_duration", 0.8)), true)
	t.on_fire()
	fx.pulse_wave(t.position + Vector2(0, 8), t.range_px() * (0.85 if is_echo else 1.0), style)
	if freeze:
		fx.ring(t.position + Vector2(0, 8), t.range_px(), Color(0.85, 0.97, 1.0, 1.0), 0.7, 7.0, 0.5)
		Sound.play("frost", 0.85)
	else:
		Sound.play("frost" if style == "frost" else "puff", 1.15 if is_echo else 1.0)


func damage_enemy(e: Enemy, amount: float, armor_pierce: float, t: Tower) -> float:
	if not e.alive:
		return 0.0
	var dealt := e.apply_damage(amount, armor_pierce)
	if t != null and is_instance_valid(t):
		t.damage_dealt += dealt
		e.last_hit_by = t.tower_id
	if dealt >= 50.0 and fx.quality >= 1.0:
		fx.text(e.aim_point() + Vector2(0, -24), str(int(dealt)), Palette.CREAM if dealt < 150.0 else Palette.AMBER_LIGHT, 18 if dealt < 150.0 else 24, 0.7)
	return dealt


# --- projectile callbacks

func on_homing_impact(s: Projectiles.Shot) -> void:
	var ground_pos := s.pos + Vector2(0, 16)
	if s.target != null and is_instance_valid(s.target) and s.target.alive:
		var e := s.target
		ground_pos = e.position
		damage_enemy(e, s.damage, s.armor_pierce, s.tower)
		var slow: Dictionary = s.stats.get("slow", {})
		if not slow.is_empty():
			e.apply_slow(float(slow.get("pct", 0.3)), float(slow.get("duration", 1.0)))
		fx.hit_spark(e.aim_point(), Palette.MOON if s.kind == "dew" else Palette.AMBER)
		Sound.play("hit", 1.3)
	if s.stats.has("puddle"):
		decals.add_puddle(ground_pos, s.stats.puddle)
		fx.sap_splat(ground_pos, float(s.stats.puddle.get("radius", 40)) * 0.7)
	elif s.kind == "dew":
		fx.burst(BattleFx.DROP, s.pos, 4, [Palette.MOON, Color(0.8, 0.95, 1.0)], Vector2(40, 110), Vector2(0.2, 0.4), Vector2(2, 3.5), 200.0, 1.5)


func on_line_hit(s: Projectiles.Shot, e: Enemy) -> void:
	damage_enemy(e, s.damage, s.armor_pierce, s.tower)
	fx.hit_spark(e.aim_point(), Color(1.0, 0.55, 0.5) if s.kind == "longthorn" else Palette.CREAM)
	Sound.play("hit")


func on_lob_impact(s: Projectiles.Shot) -> void:
	var cl: Dictionary = s.stats.get("cluster", {})
	var radius := float(cl.get("radius", 40)) if s.bomblet else float(s.stats.get("splash", 60))
	var stun := 0.0 if s.bomblet else float(s.stats.get("stun", 0.0))
	var hit := 0
	for e in enemies:
		if not e.alive or e.flying:
			continue
		if e.position.distance_squared_to(s.end) <= radius * radius:
			damage_enemy(e, s.damage, 0.0, s.tower)
			hit += 1
			if stun > 0.0:
				e.apply_stun(stun)
				fx.stun_stars(e.aim_point())
	var big := not s.bomblet
	fx.explosion(s.end, radius, big)
	decals.add_mark(s.end, radius * 0.6, Color(0.2, 0.12, 0.05, 0.3), 2.5)
	Sound.play("explode", 1.25 if s.bomblet else (0.8 if stun > 0.0 else 1.0), -5.0 if s.bomblet else 0.0)
	if big:
		shake(0.16 if stun <= 0.0 else 0.26)


# ------------------------------------------------------------ kills & leaks

func _kill(e: Enemy) -> void:
	e.alive = false
	kills += 1
	_frame_kills += 1
	add_gold(e.bounty)
	combo += 1
	combo_timer = float(GameData.balance.get("combo_window", 1.1))
	best_combo = maxi(best_combo, combo)
	var size := float(e.def.get("size", 48))
	fx.enemy_pop(e.aim_point(), size, e.boss)
	fx.text(e.aim_point() + Vector2(0, -10), "+%d" % e.bounty, Palette.AMBER_LIGHT, 17 if not e.boss else 30, 0.8, 40.0)
	Sound.play("pop", 1.0 + minf(combo, 16) * 0.035)
	if combo >= 5:
		hud.show_combo(combo, e.position)
	var every := int(GameData.balance.get("combo_bonus_every", 8))
	if every > 0 and combo % every == 0:
		var bonus := int(GameData.balance.get("combo_bonus_gold", 6))
		add_gold(bonus)
		fx.text(e.aim_point() + Vector2(0, -44), Loc.t("hud.combo_bonus", {"gold": bonus}), Palette.LIME, 22, 1.1, 30.0)
		Sound.play("coin", 1.2)
	if e.boss:
		_hitstop = 0.12
		shake(0.9)
		hud.toast(Loc.t("hud.boss_down"), Palette.AMBER_LIGHT)
	elif combo >= 6 and combo % 6 == 0:
		_hitstop = maxf(_hitstop, 0.04)
	# Poison spread (Rotcap B2).
	if e.poison_spread > 0.0 and e.poison_time > 0.0:
		fx.pulse_wave(e.position, e.poison_spread, "poison")
		for o in enemies:
			if o != e and o.alive and o.position.distance_to(e.position) <= e.poison_spread:
				o.apply_poison(e.poison_dps, maxf(2.0, e.poison_time), e.poison_spread)
	# Split into smaller oozes.
	var split: Dictionary = e.def.get("split", {})
	if not split.is_empty():
		var into := str(split.get("into", ""))
		if GameData.enemies.has(into):
			var n := int(split.get("count", 2))
			var hp_scale := e.max_hp / float(e.def.get("hp", 1)) 
			for k in n:
				var d := e.dist + (k - (n - 1) / 2.0) * 16.0
				var child := _spawn(into, e.track, hp_scale, clampf(d, 0.0, e.track.length - 1.0))
				child.lateral = e.lateral + (k - (n - 1) / 2.0) * 7.0
				child._spawn_anim = 0.4
			fx.burst(BattleFx.SPORE, e.aim_point(), 10, [Color("9ccf4a"), Color("c2e070"), Color("6fa83a")], Vector2(60, 160), Vector2(0.3, 0.6), Vector2(4, 8), 120.0, 2.0)
			Sound.play("split")


func _leak(e: Enemy) -> void:
	e.alive = false
	leak_log[e.enemy_id] = int(leak_log.get(e.enemy_id, 0)) + e.lives_cost
	lives = maxi(0, lives - e.lives_cost)
	fx.leak_burst(vault.position + Vector2(0, -40))
	Sound.play("leak")
	shake(0.5)
	hud.flash_damage()
	var tw := create_tween()
	vault.scale = Vector2(1.12, 0.86) * _vault_base_scale
	tw.tween_property(vault, "scale", Vector2.ONE * _vault_base_scale, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if lives <= max_lives / 2:
		vault.texture = GameData.tex("world/vault_damaged.png")
	_stats_dirty = true
	if lives <= 0:
		_finish(false)


func stars_for(remaining_lives: int) -> int:
	var cfg: Dictionary = GameData.balance.get("stars", {})
	var ratio := float(remaining_lives) / float(max_lives)
	if ratio >= float(cfg.get("three", 0.9)):
		return 3
	if ratio >= float(cfg.get("two", 0.5)):
		return 2
	return 1


func score_value(won: bool) -> int:
	var sc: Dictionary = GameData.balance.get("score", {})
	var s := kills * int(sc.get("per_kill", 10)) + lives * int(sc.get("per_life", 150)) + gold * int(sc.get("per_gold", 1))
	if won:
		s += int(sc.get("win_bonus", 2000))
	return s


func _finish(won: bool) -> void:
	if state == "won" or state == "lost":
		return
	state = "won" if won else "lost"
	build_tower = ""
	close_ring()
	deselect()
	var stars := stars_for(lives) if won else 0
	var score := score_value(won)
	var is_best := Save.submit_result(str(level.get("id", "")), won, stars, lives, score)
	CloudService.save_progress()
	if won:
		CloudService.submit_score(str(level.get("id", "")), score, stars, lives)
	if Engine.has_meta("autoplay"):
		print("[battle] finished level=%s won=%s lives=%d stars=%d score=%d wave=%d" % [level.id, won, lives, stars, score, wave_index + 1])
	Sound.stop_music(0.5)
	Sound.play("victory" if won else "defeat")
	if won:
		shake(0.3)
	hud.show_result(won, stars, score, is_best)
	finished.emit(won)


# ------------------------------------------------------------ juice

func shake(amount: float) -> void:
	if not bool(Save.get_setting("shake")):
		return
	_trauma = minf(1.0, _trauma + amount)


func _update_shake(dt: float) -> void:
	_shake_t += dt
	_trauma = maxf(0.0, _trauma - dt * 1.8)
	var base := ((get_viewport().get_visible_rect().size - Vector2(1280, 720)) / 2.0).round()
	if _trauma <= 0.0:
		world.position = base
		world.rotation = 0.0
		return
	var k := _trauma * _trauma
	var off := Vector2(sin(_shake_t * 71.0) + sin(_shake_t * 37.0) * 0.5, cos(_shake_t * 63.0) + sin(_shake_t * 29.0) * 0.5) * 9.0 * k
	world.position = base + off
	world.rotation = sin(_shake_t * 45.0) * 0.004 * k


# ------------------------------------------------------------ input

func preview_info() -> Dictionary:
	var info := {}
	info.upgrade_range = hover_upgrade_range
	if state == "won" or state == "lost":
		return info
	var tid := build_tower if build_tower != "" else ring_tower
	var c := cursor_cell if build_tower != "" else ring_cell
	if build_tower != "" and Controls.device == "touch" and pending_cell == Vector2i(-99, -99):
		info.show_grid = true
		return info
	if build_tower != "" and Controls.device == "touch":
		c = pending_cell
	if tid != "":
		info.show_grid = true
		info.cell = c
		info.tower = tid
		info.valid = is_buildable(c)
		info.reason = build_block_reason(c)
		var st := GameData.tower_stats(tid, "1")
		info.range = float(st.get("range", 100))
		info.air = bool(st.get("air", true))
		info.affordable = gold >= int(st.get("cost", 0))
		if info.valid and not info.affordable:
			info.reason = Loc.t("build.no_gold")
	elif ring_cell != Vector2i(-99, -99):
		info.show_grid = true
		info.cell = ring_cell
		info.valid = true
	return info


func cursor_visible() -> bool:
	return _cursor_mode and state != "won" and state != "lost" and not paused and ring_cell == Vector2i(-99, -99)


func begin_build(tower_id: String) -> void:
	if state == "won" or state == "lost":
		return
	close_ring()
	deselect()
	if build_tower == tower_id:
		cancel_build()
		return
	build_tower = tower_id
	pending_cell = Vector2i(-99, -99)
	Sound.play("click")
	hud.on_selection_changed()


func cancel_build() -> void:
	build_tower = ""
	pending_cell = Vector2i(-99, -99)
	hud.on_selection_changed()


func open_ring(c: Vector2i) -> void:
	ring_cell = c
	ring_tower = ""
	deselect()
	Sound.play("click")
	hud.open_ring(c)


func close_ring() -> void:
	if ring_cell == Vector2i(-99, -99):
		return
	ring_cell = Vector2i(-99, -99)
	ring_tower = ""
	hud.close_ring()


func _unhandled_input(event: InputEvent) -> void:
	if state == "won" or state == "lost" or paused:
		return
	if event is InputEventMouseMotion:
		_cursor_mode = false
		var c := world_to_cell(world.get_local_mouse_position())
		if in_grid(c):
			cursor_cell = c
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_action()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_cursor_mode = false
			var c := world_to_cell(world.get_local_mouse_position())
			if in_grid(c):
				cursor_cell = c
			_activate_cell(c, Controls.device == "touch")
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept"):
		_cursor_mode = true
		_activate_cell(cursor_cell, false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not _cancel_action():
			hud.open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mg_pause") or event.is_action_pressed("mg_menu"):
		hud.open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mg_speed"):
		cycle_speed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mg_wave"):
		call_wave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mg_prev_tower") or event.is_action_pressed("mg_next_tower"):
		_cycle_tower(-1 if event.is_action_pressed("mg_prev_tower") else 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mg_upgrade"):
		# U: open (and focus) the upgrade panel for the tower under the cursor.
		var t: Tower = selected if selected != null else towers.get(cursor_cell)
		if t != null:
			if selected != t:
				select_tower(t)
			hud._focus_panel.call_deferred()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mg_sell") and selected != null:
		sell(selected)
		get_viewport().set_input_as_handled()
	else:
		for i in 4:
			if event.is_action_pressed("mg_tower_%d" % (i + 1)) and i < GameData.tower_order.size():
				begin_build(str(GameData.tower_order[i]))
				get_viewport().set_input_as_handled()
				return


func _activate_cell(c: Vector2i, touch: bool) -> void:
	if build_tower != "":
		if touch and pending_cell != c:
			pending_cell = c
			Sound.play("hover")
			return
		try_build(c, build_tower)
		hud.on_selection_changed()
		return
	if towers.has(c):
		if selected == towers[c]:
			deselect()
		else:
			select_tower(towers[c])
		return
	if ring_cell != Vector2i(-99, -99):
		close_ring()
		return
	if selected != null:
		deselect()
		return
	if is_buildable(c):
		open_ring(c)
	elif in_grid(c):
		Sound.play("invalid")
		var why := build_block_reason(c)
		if why != "":
			fx.text(cell_center(c), why, Palette.CORAL_LIGHT, 16, 0.8, 24.0)


func _cancel_action() -> bool:
	if ring_cell != Vector2i(-99, -99):
		close_ring()
		return true
	if build_tower != "":
		cancel_build()
		return true
	if selected != null:
		deselect()
		return true
	return false


func cycle_speed() -> void:
	var speeds: Array = GameData.balance.get("speeds", [1, 2])
	speed_index = (speed_index + 1) % speeds.size()
	Sound.play("click", 1.0 + speed_index * 0.15)
	_stats_dirty = true


func call_wave() -> void:
	if can_call_wave():
		start_next_wave()
	else:
		Sound.play("invalid")


func set_paused(p: bool) -> void:
	paused = p
	_stats_dirty = true


func _cycle_tower(dir: int) -> void:
	if towers.is_empty():
		return
	var list: Array = towers.values()
	list.sort_custom(func(a: Tower, b: Tower) -> bool: return a.cell.x * 100 + a.cell.y < b.cell.x * 100 + b.cell.y)
	var idx := list.find(selected)
	idx = (idx + dir + list.size()) % list.size() if idx >= 0 else (0 if dir > 0 else list.size() - 1)
	_cursor_mode = true
	select_tower(list[idx])


func _poll_cursor(dt: float) -> void:
	if paused or state == "won" or state == "lost":
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		if Input.is_action_pressed(action):
			var t: float = _repeat.get(action, -1.0)
			if t < 0.0:
				_move_cursor(action)
				_repeat[action] = 0.32
			else:
				t -= dt
				if t <= 0.0:
					_move_cursor(action)
					t = 0.085
				_repeat[action] = t
		else:
			_repeat[action] = -1.0


func _move_cursor(action: String) -> void:
	var d := Vector2i.ZERO
	match action:
		"ui_left": d = Vector2i(-1, 0)
		"ui_right": d = Vector2i(1, 0)
		"ui_up": d = Vector2i(0, -1)
		"ui_down": d = Vector2i(0, 1)
	var n := cursor_cell + d
	var top := 1 if 0 in GameData.balance.get("blocked_rows", []) else 0
	n.x = clampi(n.x, 0, cols - 1)
	n.y = clampi(n.y, top, rows - 1 - (1 if (rows - 1) in GameData.balance.get("blocked_rows", []) else 0))
	if n != cursor_cell:
		cursor_cell = n
		_cursor_mode = true
		if selected != null and not towers.has(n):
			deselect()
		elif towers.has(n) and selected != null:
			select_tower(towers[n])
		Sound.play("hover")
