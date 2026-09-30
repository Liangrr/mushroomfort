class_name Projectiles
extends Node2D
## Owns all in-flight projectiles. Damage is applied through Battle so kills,
## rewards and effects stay in one place.

class Shot:
	var kind := "thorn"
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var speed := 600.0
	var target: Enemy
	var target_pos := Vector2.ZERO
	var damage := 10.0
	var pierce := 1
	var armor_pierce := 0.0
	var air := true
	var hit := {}
	var travel := 0.0
	var max_travel := 300.0
	var stats: Dictionary = {}
	var tower: Tower
	# lob
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var t := 0.0
	var dur := 0.7
	var height := 90.0
	var bomblet := false
	var trail: Array = []

var battle: Node
var shots: Array[Shot] = []


func fire_shot(tower: Tower, target: Enemy, angle_offset: float = 0.0) -> void:
	var s := Shot.new()
	s.kind = str(tower.stats.get("projectile", "thorn"))
	s.pos = tower.muzzle()
	s.speed = float(tower.stats.get("speed", 600))
	s.target = target
	s.target_pos = target.aim_point()
	s.damage = float(tower.stats.get("damage", 10))
	s.pierce = int(tower.stats.get("pierce", 1))
	s.armor_pierce = float(tower.stats.get("armor_pierce", 0.0))
	s.air = tower.hits_air()
	s.stats = tower.stats
	s.tower = tower
	if s.kind == "thorn" or s.kind == "longthorn":
		# Straight piercing shot aimed with a little lead.
		var lead_t := s.pos.distance_to(s.target_pos) / s.speed
		var ahead: Vector2 = target.track.sample(target.dist + target.speed * lead_t * 0.8) - target.position
		var aim: Vector2 = s.target_pos + ahead
		s.vel = (aim - s.pos).normalized().rotated(deg_to_rad(angle_offset)) * s.speed
		s.max_travel = tower.range_px() * 1.35
		s.target = null
	shots.append(s)


func fire_lob(tower: Tower, target: Enemy) -> void:
	var s := Shot.new()
	s.kind = "bomb"
	s.stats = tower.stats
	s.tower = tower
	s.start = tower.muzzle()
	s.pos = s.start
	s.dur = float(tower.stats.get("flight", 0.75))
	# Predict where the target will be when the bomb lands.
	var slow := maxf(target.slow_pct if target.slow_time > 0.0 else 0.0, target.puddle_slow)
	var v := 0.0 if target.stun_time > 0.0 else target.speed * (1.0 - slow)
	s.end = target.track.sample(minf(target.track.length, target.dist + v * s.dur))
	s.height = 70.0 + s.start.distance_to(s.end) * 0.35
	s.damage = float(tower.stats.get("damage", 30))
	shots.append(s)


func _bomblet(from: Vector2, to: Vector2, stats: Dictionary, tower: Tower) -> void:
	var s := Shot.new()
	s.kind = "bomb"
	s.bomblet = true
	s.stats = stats
	s.tower = tower
	s.start = from
	s.pos = from
	s.end = to
	s.dur = randf_range(0.28, 0.4)
	s.height = 40.0
	var cl: Dictionary = stats.get("cluster", {})
	s.damage = float(cl.get("damage", 20))
	shots.append(s)


func step(dt: float) -> void:
	var i := 0
	while i < shots.size():
		var s := shots[i]
		var done := false
		match s.kind:
			"bomb":
				done = _step_lob(s, dt)
			"thorn", "longthorn":
				done = _step_line(s, dt)
			_:
				done = _step_homing(s, dt)
		if done:
			shots[i] = shots[shots.size() - 1]
			shots.pop_back()
		else:
			i += 1
	queue_redraw()


func _step_homing(s: Shot, dt: float) -> bool:
	if s.target != null and is_instance_valid(s.target) and s.target.alive:
		s.target_pos = s.target.aim_point()
	else:
		s.target = null
	var to := s.target_pos - s.pos
	var step_len := s.speed * dt
	s.trail.push_front(s.pos)
	if s.trail.size() > 5:
		s.trail.pop_back()
	if to.length() <= step_len + 6.0:
		s.pos = s.target_pos
		battle.on_homing_impact(s)
		return true
	s.pos += to.normalized() * step_len
	return false


func _step_line(s: Shot, dt: float) -> bool:
	var move := s.vel * dt
	s.trail.push_front(s.pos)
	if s.trail.size() > (7 if s.kind == "longthorn" else 3):
		s.trail.pop_back()
	# Sweep in two halves so fast thorns don't tunnel through small pests.
	for half in 2:
		s.pos += move * 0.5
		for e: Enemy in battle.enemies:
			if not e.alive or s.hit.has(e.get_instance_id()):
				continue
			if e.flying and not s.air:
				continue
			if s.pos.distance_to(e.aim_point()) <= e.radius + 8.0:
				s.hit[e.get_instance_id()] = true
				battle.on_line_hit(s, e)
				s.pierce -= 1
				if s.pierce <= 0:
					return true
	s.travel += move.length()
	return s.travel >= s.max_travel or not Rect2(-80, -80, 1440, 880).has_point(s.pos)


func _step_lob(s: Shot, dt: float) -> bool:
	s.t += dt
	var f := clampf(s.t / s.dur, 0.0, 1.0)
	s.pos = s.start.lerp(s.end, f) + Vector2(0, -s.height * 4.0 * f * (1.0 - f))
	if f >= 1.0:
		battle.on_lob_impact(s)
		if not s.bomblet:
			var cl: Dictionary = s.stats.get("cluster", {})
			for k in int(cl.get("count", 0)):
				var a := TAU * k / maxf(1.0, float(cl.get("count", 1))) + randf_range(-0.3, 0.3)
				var r := float(cl.get("spread", 50)) * randf_range(0.6, 1.0)
				_bomblet(s.end, s.end + Vector2(cos(a), sin(a) * 0.7) * r, s.stats, s.tower)
		return true
	return false


func _draw() -> void:
	for s in shots:
		match s.kind:
			"dew":
				for k in s.trail.size():
					draw_circle(s.trail[k], 6.0 - k, Color(Palette.MOON, 0.25 - k * 0.04))
				draw_circle(s.pos, 8.0, Palette.MOON_DARK)
				draw_circle(s.pos, 6.5, Color(0.72, 0.9, 1.0))
				draw_circle(s.pos + Vector2(-2.5, -2.5), 2.2, Color.WHITE)
			"amber":
				for k in s.trail.size():
					draw_circle(s.trail[k], 7.0 - k, Color(Palette.AMBER, 0.3 - k * 0.05))
				draw_circle(s.pos, 9.0, Color("8a4f12"))
				draw_circle(s.pos, 7.5, Palette.AMBER)
				draw_circle(s.pos + Vector2(-2.5, -3), 2.5, Color(1, 0.95, 0.75))
			"thorn", "longthorn":
				var long := s.kind == "longthorn"
				var dir := s.vel.normalized()
				var n := dir.orthogonal()
				var L := 22.0 if long else 15.0
				var W := 4.0 if long else 3.2
				if s.trail.size() > 1:
					var tc := Color(1.0, 0.5, 0.45, 0.35) if long else Color(1, 1, 0.9, 0.25)
					draw_polyline(PackedVector2Array(s.trail), tc, 3.0 if long else 2.0, true)
				var body := Color("b3263a") if long else Color("e9dcb2")
				var tip := s.pos + dir * L * 0.6
				var tail := s.pos - dir * L * 0.4
				draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, tail + n * W, tail - dir * 3.0, tail - n * W]), Palette.INK)
				draw_colored_polygon(PackedVector2Array([tip, tail + n * (W - 1.2), tail - dir * 1.5, tail - n * (W - 1.2)]), body)
			"bomb":
				var f := clampf(s.t / s.dur, 0.0, 1.0)
				var ground := s.start.lerp(s.end, f)
				var r := 6.0 if s.bomblet else 10.0
				draw_set_transform(ground + Vector2(0, 4), 0.0, Vector2(1.0, 0.4))
				draw_circle(Vector2.ZERO, r * (0.7 + f * 0.4), Color(0, 0, 0, 0.22))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_circle(s.pos, r + 2.0, Palette.INK)
				draw_circle(s.pos, r, Color("9a6a3a") if not s.bomblet else Color("e0a040"))
				draw_circle(s.pos + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 0.9, 0.7, 0.7))
				if not s.bomblet:
					var sp := s.pos + Vector2(0, -r - 3)
					draw_line(s.pos + Vector2(0, -r), sp, Color("5c8a2c"), 3.0)
					draw_circle(sp, 2.5 + randf() * 1.5, Palette.AMBER_LIGHT)


func clear() -> void:
	shots.clear()
