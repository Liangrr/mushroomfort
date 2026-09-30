class_name DefeatAmbientLayer
extends Control

## Presentation-only defeat ambience shared by the terminal battle overlay and
## defeated Results screen. All particles are deterministic and drawn locally;
## no gameplay state or random-number stream is touched.

const EMBER_COUNT := 18
const SHARD_COUNT := 7
const LOOP_SECONDS := 12.0
const CRIMSON := Color("b93b55")
const EMBER := Color("f19a72")
const ASH := Color("a98691")

var _elapsed_seconds := 0.0
var _reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced_motion = bool(ProjectSettings.get_setting(
		"accessibility/reduced_motion", false,
	))
	set_process(not _reduced_motion)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed_seconds = fmod(_elapsed_seconds + maxf(delta, 0.0), LOOP_SECONDS)
	queue_redraw()


func particle_count() -> int:
	return EMBER_COUNT


func shard_count() -> int:
	return SHARD_COUNT


func motion_reduced() -> bool:
	return _reduced_motion


func elapsed_seconds() -> float:
	return _elapsed_seconds


func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var motion_phase := 0.42 if _reduced_motion else _elapsed_seconds / LOOP_SECONDS
	draw_rect(Rect2(Vector2.ZERO, size), Color(CRIMSON, 0.035), true)
	_draw_scanline(motion_phase)
	_draw_embers(motion_phase)
	_draw_shards(motion_phase)


func _draw_scanline(phase: float) -> void:
	var scan_y := lerpf(size.y * 0.16, size.y * 0.84, fmod(phase * 1.45, 1.0))
	var edge := size.x * 0.08
	draw_line(
		Vector2(edge, scan_y),
		Vector2(size.x - edge, scan_y),
		Color(CRIMSON, 0.08),
		1.0,
	)
	draw_line(
		Vector2(edge * 1.35, scan_y + 3.0),
		Vector2(size.x - edge * 1.35, scan_y + 3.0),
		Color(EMBER, 0.025),
		1.0,
	)


func _draw_embers(phase: float) -> void:
	for index: int in EMBER_COUNT:
		var index_f := float(index)
		var normalized_x := fposmod(0.083 + index_f * 0.61803398875, 1.0)
		var base_y := fposmod(0.19 + index_f * 0.38196601125, 1.0)
		var rise := 0.0 if _reduced_motion else phase * (0.72 + float(index % 5) * 0.11)
		var normalized_y := fposmod(base_y - rise, 1.0)
		var drift := 0.0 if _reduced_motion else sin(phase * TAU * 2.0 + index_f * 0.73) * 12.0
		var point := Vector2(normalized_x * size.x + drift, normalized_y * size.y)
		var twinkle := 0.55 if _reduced_motion else 0.35 + 0.65 * absf(
			sin(phase * TAU * 3.1 + index_f * 1.17)
		)
		var radius := 1.1 + float(index % 3) * 0.45 + twinkle * 0.8
		var color := EMBER if index % 3 == 0 else (CRIMSON if index % 3 == 1 else ASH)
		draw_line(
			point + Vector2(0.0, radius * 1.8),
			point - Vector2(0.0, radius * 2.8),
			Color(color, 0.08 + twinkle * 0.10),
			maxf(1.0, radius * 0.55),
		)
		draw_circle(point, radius, Color(color, 0.11 + twinkle * 0.16))
		draw_circle(point, maxf(0.65, radius * 0.34), Color(1.0, 0.82, 0.70, 0.18 + twinkle * 0.22))


func _draw_shards(phase: float) -> void:
	for index: int in SHARD_COUNT:
		var index_f := float(index)
		var anchor := Vector2(
			fposmod(0.14 + index_f * 0.417, 1.0) * size.x,
			fposmod(0.08 + index_f * 0.263, 1.0) * size.y,
		)
		var sway := 0.0 if _reduced_motion else sin(phase * TAU + index_f) * 7.0
		var half_height := 4.0 + float(index % 3) * 2.0
		var half_width := 1.5 + float(index % 2)
		var center := anchor + Vector2(sway, 0.0)
		var shard := PackedVector2Array([
			center - Vector2(0.0, half_height),
			center + Vector2(half_width, 0.0),
			center + Vector2(0.0, half_height),
			center - Vector2(half_width, 0.0),
		])
		var alpha := 0.08 if _reduced_motion else 0.05 + 0.07 * absf(
			sin(phase * TAU * 1.8 + index_f * 0.61)
		)
		draw_colored_polygon(shard, Color(CRIMSON if index % 2 == 0 else ASH, alpha))
