class_name GroundDecals
extends Node2D
## Effects that sit on the ground under units: sap puddles (gameplay) and
## fading scorch / frost marks (cosmetic).

class Puddle:
	var pos := Vector2.ZERO
	var radius := 40.0
	var time := 3.0
	var total := 3.0
	var slow := 0.4
	var vuln := 0.2
	var seed := 0.0

class Mark:
	var pos := Vector2.ZERO
	var radius := 30.0
	var time := 2.0
	var total := 2.0
	var color := Color.BLACK

var puddles: Array[Puddle] = []
var marks: Array[Mark] = []
var _t := 0.0


func add_puddle(pos: Vector2, cfg: Dictionary) -> void:
	var p := Puddle.new()
	p.pos = pos
	p.radius = float(cfg.get("radius", 40))
	p.total = float(cfg.get("duration", 3.0))
	p.time = p.total
	p.slow = float(cfg.get("slow", 0.4))
	p.vuln = float(cfg.get("vuln", 0.2))
	p.seed = randf() * 10.0
	puddles.append(p)
	if puddles.size() > 24:
		puddles.pop_front()


func add_mark(pos: Vector2, radius: float, color: Color, time: float = 2.0) -> void:
	if not bool(Save.get_setting("fx_high")) and marks.size() > 6:
		return
	var m := Mark.new()
	m.pos = pos
	m.radius = radius
	m.color = color
	m.time = time
	m.total = time
	marks.append(m)
	if marks.size() > 30:
		marks.pop_front()


## Resets per-enemy puddle effects then applies overlapping puddles.
func apply_to(enemies: Array) -> void:
	for e: Enemy in enemies:
		e.puddle_slow = 0.0
		e.vuln = 0.0
		if e.flying or not e.alive:
			continue
		for p in puddles:
			if e.position.distance_squared_to(p.pos) <= p.radius * p.radius:
				e.puddle_slow = maxf(e.puddle_slow, p.slow)
				e.vuln = maxf(e.vuln, p.vuln)


func step(dt: float) -> void:
	_t += dt
	var i := 0
	while i < puddles.size():
		puddles[i].time -= dt
		if puddles[i].time <= 0.0:
			puddles.remove_at(i)
		else:
			i += 1
	i = 0
	while i < marks.size():
		marks[i].time -= dt
		if marks[i].time <= 0.0:
			marks.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	for m in marks:
		var a := m.time / m.total
		draw_set_transform(m.pos, 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, m.radius, Color(m.color, m.color.a * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in puddles:
		var life := p.time / p.total
		var grow := minf(1.0, (p.total - p.time) * 6.0)
		var r := p.radius * grow
		var a := minf(1.0, life * 3.0)
		draw_set_transform(p.pos, 0.0, Vector2(1.0, 0.62))
		# Blobby outline from a few offset circles.
		for k in 5:
			var ang := p.seed + k * TAU / 5.0
			draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.35, r * 0.72, Color(0.55, 0.3, 0.05, 0.45 * a))
		draw_circle(Vector2.ZERO, r * 0.85, Color(0.95, 0.66, 0.18, 0.5 * a))
		draw_circle(Vector2(-r * 0.25, -r * 0.2), r * 0.3, Color(1.0, 0.9, 0.6, 0.35 * a))
		var bub := fmod(_t * 1.5 + p.seed, 1.0)
		draw_arc(Vector2(r * 0.3, r * 0.1), 3.0 + bub * 5.0, 0.0, TAU, 12, Color(1, 0.92, 0.7, 0.6 * (1.0 - bub) * a), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
