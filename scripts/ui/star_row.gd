class_name StarRow
extends Control
## Draws N rating stars; `filled` of them in amber. Supports a pop animation per star.

@export var count := 3
@export var filled := 0
@export var star_size := 28.0
var _scales: Array[float] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_scales.resize(count)
	_scales.fill(1.0)
	custom_minimum_size = Vector2(count * star_size * 1.15, star_size * 1.1)


func set_filled(n: int) -> void:
	filled = n
	queue_redraw()


## Animate stars popping in one by one (result screen).
func reveal(n: int, interval: float = 0.35) -> void:
	filled = 0
	for i in count:
		_scales[i] = 1.0
	queue_redraw()
	for i in n:
		await get_tree().create_timer(interval).timeout
		if not is_inside_tree():
			return
		filled = i + 1
		_scales[i] = 1.8
		Sound.play("upgrade", 1.0 + i * 0.12)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			_scales[i] = v
			queue_redraw(), 1.8, 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var step: float = size.x / maxf(1.0, float(count))
	for i in count:
		var c := Vector2(step * (i + 0.5), size.y / 2.0)
		var s: float = star_size * 0.5 * (_scales[i] if i < _scales.size() else 1.0)
		var pts := star_points(c, s, s * 0.48)
		var on := i < filled
		draw_colored_polygon(pts, Palette.AMBER if on else Color(Palette.INK, 0.25))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Palette.INK if on else Color(Palette.INK, 0.35), 2.5, true)
		if on:
			draw_circle(c + Vector2(-s * 0.2, -s * 0.25), s * 0.16, Color(1, 1, 0.85, 0.7))


static func star_points(c: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var r := outer if k % 2 == 0 else inner
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
