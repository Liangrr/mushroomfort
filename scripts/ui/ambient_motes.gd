class_name AmbientMotes
extends Control
## Floating petals, spores and fireflies drawn in one pass (menus and battles).

@export var amount := 36
@export var night := false
var _motes: Array = []
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var n := amount if bool(Save.get_setting("fx_high")) else amount / 3
	for i in n:
		_motes.append(_spawn(true))


func _spawn(anywhere: bool) -> Dictionary:
	var kind := randi() % 3
	return {
		"p": Vector2(randf() * max(size.x, 1280.0), randf() * max(size.y, 720.0) if anywhere else max(size.y, 720.0) + 10.0),
		"v": Vector2(randf_range(-12, 12), randf_range(-26, -8)),
		"kind": kind,
		"s": randf_range(2.0, 5.0) if kind != 0 else randf_range(5.0, 8.0),
		"ph": randf() * TAU,
		"rot": randf() * TAU,
	}


func _process(delta: float) -> void:
	_t += delta
	var h: float = max(size.y, 720.0)
	for m: Dictionary in _motes:
		m.p += (m.v + Vector2(sin(_t * 0.8 + m.ph) * 14.0, 0.0)) * delta
		m.rot += delta * 1.3
		if m.p.y < -20.0 or m.p.x < -30.0 or m.p.x > max(size.x, 1280.0) + 30.0:
			var fresh := _spawn(false)
			m.merge(fresh, true)
			m.p.y = h + 10.0
	queue_redraw()


func _draw() -> void:
	for m: Dictionary in _motes:
		var tw := 0.55 + 0.45 * sin(_t * 2.2 + m.ph)
		match int(m.kind):
			0:  # petal
				var col := Color(1.0, 0.72, 0.68, 0.75) if not night else Color(0.75, 0.8, 1.0, 0.6)
				var dir := Vector2(cos(m.rot), sin(m.rot))
				var pts := PackedVector2Array([m.p + dir * m.s, m.p + dir.orthogonal() * m.s * 0.45, m.p - dir * m.s, m.p - dir.orthogonal() * m.s * 0.45])
				draw_colored_polygon(pts, col)
			1:  # spore glow
				var c := Color(1.0, 0.9, 0.5) if not night else Color(0.6, 0.95, 1.0)
				draw_circle(m.p, m.s * 2.2, Color(c, 0.12 * tw))
				draw_circle(m.p, m.s * 0.8, Color(c, 0.8 * tw))
			_:  # dust mote
				draw_circle(m.p, m.s * 0.6, Color(1, 1, 0.9, 0.35 * tw))
