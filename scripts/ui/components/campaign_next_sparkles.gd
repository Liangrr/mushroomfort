class_name CampaignNextSparkles
extends Control

const CYAN := Color("91eaf1")
const GOLD := Color("f0d89a")
const SPARKLE_POSITIONS := [
	Vector2(0.08, 0.24), Vector2(0.18, 0.72), Vector2(0.34, 0.16),
	Vector2(0.52, 0.82), Vector2(0.68, 0.28), Vector2(0.82, 0.66),
	Vector2(0.93, 0.18), Vector2(0.96, 0.82),
]
const PULSE_SECONDS := 2.4

var _elapsed := 0.0
var _reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_reduced_motion = bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
	set_process(not _reduced_motion)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, PULSE_SECONDS)
	queue_redraw()


func sparkle_count() -> int:
	return SPARKLE_POSITIONS.size()


func motion_reduced() -> bool:
	return _reduced_motion


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	var phase := 0.5 if _reduced_motion else _elapsed / PULSE_SECONDS
	var pulse := 0.5 + 0.5 * sin(phase * TAU)
	var outer := Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0))
	var inner := Rect2(Vector2(7.0, 7.0), size - Vector2(14.0, 14.0))
	draw_rect(outer, Color(CYAN, 0.16 + pulse * 0.16), false, 5.0)
	draw_rect(outer, Color(CYAN, 0.62 + pulse * 0.28), false, 1.5)
	draw_rect(inner, Color(GOLD, 0.34 + pulse * 0.22), false, 1.0)
	for index: int in SPARKLE_POSITIONS.size():
		var anchor: Vector2 = SPARKLE_POSITIONS[index]
		var drift := 0.0 if _reduced_motion else sin(phase * TAU + float(index) * 0.91) * 5.0
		var point := Vector2(anchor.x * size.x, clampf(anchor.y * size.y + drift, 8.0, size.y - 8.0))
		var twinkle := 0.72 if _reduced_motion else 0.35 + 0.65 * absf(sin(phase * TAU * 1.7 + float(index)))
		var radius := 2.5 + twinkle * 3.5
		var color := Color(GOLD if index % 2 == 0 else CYAN, 0.45 + twinkle * 0.5)
		draw_line(point - Vector2(radius, 0.0), point + Vector2(radius, 0.0), color, 1.2)
		draw_line(point - Vector2(0.0, radius), point + Vector2(0.0, radius), color, 1.2)
		draw_circle(point, 1.2 + twinkle, Color(1.0, 1.0, 1.0, 0.62 + twinkle * 0.30))
