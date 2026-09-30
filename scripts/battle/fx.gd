class_name BattleFx
extends Node2D
## All transient battle effects (petals, spores, rings, flashes, floating numbers)
## rendered in a single _draw pass with a hard cap. Quality setting scales counts.

const MAX_HIGH := 700
const MAX_LOW := 220
const MAX_TEXT := 48

class P:
	var kind := 0      # 0 petal, 1 spore, 2 spark, 3 ring, 4 disc, 5 drop, 6 star, 7 flake, 8 seed
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.0
	var age := 0.0
	var size := 4.0
	var size2 := 0.0
	var color := Color.WHITE
	var rot := 0.0
	var spin := 0.0
	var drag := 2.0
	var gravity := 0.0
	var width := 3.0

class T:
	var text := ""
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.9
	var age := 0.0
	var size := 20
	var color := Color.WHITE
	var pop := 1.0

enum { PETAL, SPORE, SPARK, RING, DISC, DROP, STAR, FLAKE, SEED }

var quality := 1.0
var _ps: Array[P] = []
var _texts: Array[T] = []
var _font: Font


func _ready() -> void:
	_font = UiTheme.display_font if UiTheme.display_font != null else ThemeDB.fallback_font
	refresh_quality()


func refresh_quality() -> void:
	quality = 1.0 if bool(Save.get_setting("fx_high")) else 0.4


func _cap() -> int:
	return MAX_HIGH if quality >= 1.0 else MAX_LOW


func _n(count: int) -> int:
	return maxi(1, int(round(count * quality)))


func add(kind: int, pos: Vector2, vel: Vector2, life: float, size: float, color: Color) -> P:
	if _ps.size() >= _cap():
		return null
	var p := P.new()
	p.kind = kind
	p.pos = pos
	p.vel = vel
	p.life = life
	p.size = size
	p.color = color
	p.rot = randf() * TAU
	p.spin = randf_range(-6.0, 6.0)
	_ps.append(p)
	return p


func burst(kind: int, pos: Vector2, count: int, colors: Array, speed: Vector2, life: Vector2, size: Vector2, gravity: float = 0.0, drag: float = 2.5) -> void:
	for i in _n(count):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.75) * randf_range(speed.x, speed.y)
		var p := add(kind, pos, v, randf_range(life.x, life.y), randf_range(size.x, size.y), colors[randi() % colors.size()])
		if p != null:
			p.gravity = gravity
			p.drag = drag


func ring(pos: Vector2, radius: float, color: Color, life: float = 0.45, width: float = 4.0, start: float = 0.1) -> void:
	var p := add(RING, pos, Vector2.ZERO, life, radius * start, color)
	if p != null:
		p.size2 = radius
		p.width = width


func flash(pos: Vector2, radius: float, color: Color, life: float = 0.18) -> void:
	var p := add(DISC, pos, Vector2.ZERO, life, radius, color)
	if p != null:
		p.size2 = radius * 1.25


func text(pos: Vector2, s: String, color: Color, size: int = 20, life: float = 0.85, rise: float = 46.0) -> void:
	if _texts.size() >= MAX_TEXT:
		_texts.pop_front()
	var t := T.new()
	t.text = s
	# Keep numbers readable when a kill happens right at the map edge.
	var half_w := float(s.length()) * float(size) * 0.3 + 8.0
	t.pos = Vector2(clampf(pos.x, half_w, 1280.0 - half_w), clampf(pos.y, 96.0, 700.0)) + Vector2(randf_range(-6, 6), 0)
	t.vel = Vector2(randf_range(-10, 10), -rise)
	t.life = life
	t.size = size
	t.color = color
	_texts.append(t)


# ---------------------------------------------------------------- recipes

func enemy_pop(pos: Vector2, size: float, boss: bool) -> void:
	var s := size / 48.0
	flash(pos, 26.0 * s, Color(1, 0.97, 0.85, 0.9), 0.14)
	ring(pos, 38.0 * s, Color(1, 0.95, 0.8, 0.8), 0.3, 3.0)
	burst(PETAL, pos, int(9 * s) + 4, [Palette.CORAL_LIGHT, Color("ffd0c4"), Palette.CREAM, Color("f6a6b8")], Vector2(90, 220) * sqrt(s), Vector2(0.6, 1.1), Vector2(4, 7), 90.0, 2.4)
	burst(SPORE, pos, int(6 * s) + 3, [Palette.AMBER_LIGHT, Color("fff2b8"), Palette.LIME], Vector2(20, 90) * sqrt(s), Vector2(0.5, 0.9), Vector2(3, 6), -30.0, 1.5)
	if boss:
		for i in 3:
			ring(pos, 90.0 + i * 50.0, Color(Palette.AMBER_LIGHT, 0.8), 0.5 + i * 0.12, 6.0)
		burst(SEED, pos, 26, [Palette.AMBER, Palette.AMBER_LIGHT], Vector2(160, 380), Vector2(0.8, 1.4), Vector2(5, 8), 260.0, 1.2)


func explosion(pos: Vector2, radius: float, big: bool) -> void:
	flash(pos, radius * 0.7, Color(1.0, 0.9, 0.55, 0.95), 0.16)
	ring(pos, radius, Color(1.0, 0.72, 0.3, 0.9), 0.36, 5.0 if big else 3.5)
	burst(SPARK, pos, 10 if big else 6, [Palette.AMBER_LIGHT, Color("ffb35c")], Vector2(160, 360), Vector2(0.2, 0.4), Vector2(8, 14), 0.0, 3.0)
	burst(SPORE, pos, 10 if big else 6, [Color("c89060"), Color("a87850"), Color("e6c49a")], Vector2(30, 110), Vector2(0.5, 0.9), Vector2(8, 14), -20.0, 2.0)
	burst(PETAL, pos, 8 if big else 4, [Color("f08a3a"), Palette.AMBER, Palette.CORAL], Vector2(100, 260), Vector2(0.5, 0.9), Vector2(4, 6), 120.0, 2.0)


func pulse_wave(pos: Vector2, radius: float, style: String) -> void:
	match style:
		"frost":
			ring(pos, radius, Color(0.8, 0.95, 1.0, 0.9), 0.5, 5.0, 0.2)
			ring(pos, radius * 0.7, Color(0.6, 0.85, 1.0, 0.6), 0.4, 3.0, 0.2)
			for i in _n(14):
				var a := randf() * TAU
				var p := add(FLAKE, pos + Vector2(cos(a), sin(a)) * randf_range(10.0, radius), Vector2(0, -12), randf_range(0.5, 0.9), randf_range(4, 7), Color(0.9, 0.97, 1.0, 0.95))
				if p != null:
					p.drag = 0.5
		"poison":
			ring(pos, radius, Color(Palette.LIME, 0.85), 0.5, 4.0, 0.2)
			burst(SPORE, pos, 14, [Palette.LIME, Color("8fc23a"), Color("c7a2e0")], Vector2(radius * 0.8, radius * 1.6), Vector2(0.5, 0.9), Vector2(5, 10), -10.0, 3.2)
		_:
			ring(pos, radius, Color(1.0, 0.92, 0.55, 0.9), 0.42, 4.0, 0.2)
			burst(SPORE, pos, 12, [Palette.AMBER_LIGHT, Color("fff2b8")], Vector2(radius * 0.9, radius * 1.7), Vector2(0.35, 0.65), Vector2(3, 6), 0.0, 3.4)


func sap_splat(pos: Vector2, radius: float) -> void:
	burst(DROP, pos, 8, [Palette.AMBER, Color("e39a2a")], Vector2(60, 150), Vector2(0.3, 0.55), Vector2(3, 5), 220.0, 1.5)
	ring(pos, radius, Color(Palette.AMBER, 0.7), 0.3, 3.0)


func hit_spark(pos: Vector2, color: Color) -> void:
	burst(SPARK, pos, 3, [color, Color(1, 1, 0.9)], Vector2(80, 180), Vector2(0.12, 0.22), Vector2(5, 9), 0.0, 4.0)


func stun_stars(pos: Vector2) -> void:
	burst(STAR, pos, 4, [Palette.AMBER_LIGHT, Color.WHITE], Vector2(40, 90), Vector2(0.5, 0.8), Vector2(5, 7), -40.0, 2.0)


func leak_burst(pos: Vector2) -> void:
	flash(pos, 60.0, Color(1.0, 0.35, 0.3, 0.55), 0.25)
	ring(pos, 90.0, Color(Palette.DANGER, 0.8), 0.45, 5.0)
	burst(SEED, pos, 6, [Palette.AMBER, Palette.AMBER_LIGHT], Vector2(120, 240), Vector2(0.6, 1.0), Vector2(5, 7), 300.0, 1.0)


func build_bloom(pos: Vector2, color: Color, big: bool) -> void:
	ring(pos, 60.0 if big else 46.0, Color(Palette.AMBER_LIGHT, 0.9), 0.45, 4.0)
	burst(PETAL, pos + Vector2(0, -30), 18 if big else 10, [color, color.lightened(0.3), Palette.CREAM, Palette.AMBER_LIGHT], Vector2(90, 240), Vector2(0.6, 1.1), Vector2(4, 8), 140.0, 2.2)
	burst(SPORE, pos + Vector2(0, -20), 10 if big else 6, [Palette.AMBER_LIGHT, Color("fff2b8")], Vector2(20, 80), Vector2(0.6, 1.0), Vector2(3, 6), -40.0, 1.5)


func sell_poof(pos: Vector2) -> void:
	burst(SPORE, pos, 14, [Color("d8c8a8"), Color("b8a888"), Palette.CREAM], Vector2(40, 140), Vector2(0.4, 0.8), Vector2(8, 14), -20.0, 2.5)
	burst(SEED, pos + Vector2(0, -20), 6, [Palette.AMBER, Palette.AMBER_LIGHT], Vector2(80, 180), Vector2(0.5, 0.8), Vector2(4, 6), 280.0, 1.0)


# ---------------------------------------------------------------- update & draw

func step(dt: float) -> void:
	var i := 0
	while i < _ps.size():
		var p := _ps[i]
		p.age += dt
		if p.age >= p.life:
			_ps[i] = _ps[_ps.size() - 1]
			_ps.pop_back()
			continue
		p.vel *= maxf(0.0, 1.0 - p.drag * dt)
		p.vel.y += p.gravity * dt
		p.pos += p.vel * dt
		p.rot += p.spin * dt
		i += 1
	var j := 0
	while j < _texts.size():
		var t := _texts[j]
		t.age += dt
		if t.age >= t.life:
			_texts.remove_at(j)
			continue
		t.vel *= maxf(0.0, 1.0 - 3.0 * dt)
		t.pos += t.vel * dt
		j += 1
	queue_redraw()


func _draw() -> void:
	for p in _ps:
		var k := p.age / p.life
		var fade := 1.0 - k
		var c := p.color
		match p.kind:
			PETAL:
				c.a *= minf(1.0, fade * 1.6)
				var d := Vector2(cos(p.rot), sin(p.rot)) * p.size
				var o := d.orthogonal() * 0.45
				draw_colored_polygon(PackedVector2Array([p.pos + d, p.pos + o, p.pos - d, p.pos - o]), c)
			SPORE:
				c.a *= fade * 0.85
				draw_circle(p.pos, p.size * (0.6 + k * 0.6), c)
			SPARK:
				c.a *= fade
				var dir := p.vel.normalized() if p.vel.length() > 1.0 else Vector2.RIGHT
				draw_line(p.pos - dir * p.size * fade, p.pos + dir * p.size * 0.3, c, 2.5, true)
			RING:
				c.a *= fade
				var r := lerpf(p.size, p.size2, ease(k, 0.35))
				draw_arc(p.pos, r, 0.0, TAU, 48, c, p.width * (0.4 + fade * 0.6), true)
			DISC:
				c.a *= fade
				draw_circle(p.pos, lerpf(p.size, p.size2, k), c)
			DROP:
				c.a *= fade
				draw_circle(p.pos, p.size, c)
				draw_circle(p.pos + Vector2(-p.size * 0.3, -p.size * 0.3), p.size * 0.35, Color(1, 1, 1, 0.6 * fade))
			STAR:
				c.a *= fade
				draw_colored_polygon(StarRow.star_points(p.pos, p.size, p.size * 0.45), c)
			FLAKE:
				c.a *= fade
				for a in 3:
					var ang := p.rot + a * PI / 3.0
					var v := Vector2(cos(ang), sin(ang)) * p.size
					draw_line(p.pos - v, p.pos + v, c, 1.6, true)
			SEED:
				c.a *= minf(1.0, fade * 2.0)
				draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.7))
				draw_circle(Vector2.ZERO, p.size, Palette.INK)
				draw_circle(Vector2.ZERO, p.size - 1.5, c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for t in _texts:
		var k := t.age / t.life
		var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var s := 1.0 + maxf(0.0, 0.35 - t.age * 2.0)
		var fs := int(t.size * s)
		var w := _font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := t.pos - Vector2(w / 2.0, 0)
		draw_string_outline(_font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(Palette.INK, a))
		draw_string(_font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(t.color, a))


func clear() -> void:
	_ps.clear()
	_texts.clear()
