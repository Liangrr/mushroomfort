class_name EnemyDeathParticles
extends Control

## Lightweight presentation-only particles for static enemy deaths. The stable
## enemy id controls visual phase; no particle value is read by battle logic.

var _profile: Dictionary = {}
var _elapsed := 0.0
var _duration := 0.5
var _enemy_id := 0
var _reduced_motion := false


func setup(
	profile: Dictionary,
	body_size: Vector2,
	enemy_id: int,
	reduced_motion: bool,
) -> void:
	_profile = profile.duplicate(true)
	_enemy_id = enemy_id
	_reduced_motion = reduced_motion
	_duration = float(_profile.get(&"particle_lifetime", 0.5))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = body_size
	z_index = 5
	queue_redraw()


func advance(delta: float) -> bool:
	_elapsed = minf(_elapsed + maxf(delta, 0.0), _duration)
	queue_redraw()
	return is_complete()


func is_complete() -> bool:
	return _elapsed >= _duration


func progress() -> float:
	if _duration <= 0.0:
		return 1.0
	return clampf(_elapsed / _duration, 0.0, 1.0)


func rendered_particle_count() -> int:
	var authored := int(_profile.get(&"particle_count", 12))
	return mini(authored, 8) if _reduced_motion else authored


func _draw() -> void:
	var count := rendered_particle_count()
	if count <= 0:
		return
	var palette: Array = _profile.get(&"particle_colors", [])
	if palette.is_empty():
		palette = [Color("f4e9d0"), Color("d6a84f"), Color("c964cf")]
	var t := progress()
	var fade := 1.0 - t
	var center := Vector2(size.x * 0.5, size.y * float(_profile.get(&"particle_origin_y", 0.58)))
	var style := StringName(_profile.get(&"particle_style", &"radial"))
	for index: int in count:
		var color: Color = palette[index % palette.size()]
		color.a *= fade * fade
		var start := center + _start_offset(style, index, count)
		var travel := Vector2.ZERO if _reduced_motion else _travel(style, index, count, t)
		var point := start + travel
		var radius := lerpf(2.4, 0.7, t) * (0.78 + _unit_hash(index, 5) * 0.44)
		if index % 3 == 0:
			var tangent := Vector2(2.0 + radius, -1.0).rotated(_angle(style, index, count))
			draw_line(point - tangent, point + tangent, color, maxf(1.0, radius * 0.7), true)
		else:
			draw_circle(point, radius, color)


func _start_offset(style: StringName, index: int, count: int) -> Vector2:
	var centered := (float(index) + 0.5) / float(maxi(count, 1)) - 0.5
	match style:
		&"shield_fan":
			return Vector2(centered * size.x * 0.38, -absf(centered) * size.y * 0.12)
		&"ram_fan":
			return Vector2(centered * size.x * 0.22 + size.x * 0.12, centered * size.y * 0.10)
		&"bars":
			return Vector2(centered * size.x * 0.32, centered * size.y * 0.24)
		&"relay":
			return Vector2(cos(_angle(style, index, count)), sin(_angle(style, index, count))) * size.x * 0.10
		&"spear":
			return Vector2(centered * size.x * 0.20, centered * size.y * 0.14)
		&"fork":
			return Vector2(signf(centered) * size.x * 0.10, absf(centered) * size.y * 0.10)
		&"key_burst":
			return Vector2(centered * size.x * 0.16, centered * size.y * 0.16)
		_:
			return Vector2(centered * size.x * 0.28, centered * size.y * 0.14)


func _travel(style: StringName, index: int, count: int, t: float) -> Vector2:
	var angle := _angle(style, index, count)
	var speed := lerpf(12.0, 34.0, _unit_hash(index, 11))
	var eased := 1.0 - pow(1.0 - t, 2.0)
	var direction := Vector2(cos(angle), sin(angle))
	var travel := direction * speed * eased
	match style:
		&"runner_trail":
			travel += Vector2(18.0 * eased, -8.0 * eased)
		&"shield_fan":
			travel += Vector2(0.0, -8.0 * eased)
		&"ram_fan":
			travel += Vector2(14.0 * eased, -5.0 * eased)
		&"bars":
			travel = travel.lerp(Vector2(0.0, -20.0 * eased), 0.55)
		&"relay":
			travel = travel.rotated(t * (0.8 if index % 2 == 0 else -0.8)) + Vector2(0.0, -10.0 * eased)
		&"spear":
			travel += Vector2(0.0, -18.0 * eased)
		&"fork":
			travel += Vector2(signf(direction.x) * 7.0 * eased, -15.0 * eased)
		&"key_burst":
			travel += Vector2(0.0, -12.0 * eased)
	travel.y += 9.0 * t * t
	return travel


func _angle(style: StringName, index: int, count: int) -> float:
	var spread := (float(index) + 0.5) / float(maxi(count, 1)) - 0.5
	var jitter := (_unit_hash(index, 23) - 0.5) * 0.34
	match style:
		&"runner_trail":
			return -0.55 + spread * 1.1 + jitter
		&"shield_fan":
			return -PI * 0.5 + spread * 2.25 + jitter
		&"ram_fan":
			return -0.35 + spread * 1.55 + jitter
		&"bars":
			return -PI * 0.5 + spread * 1.3 + jitter
		&"relay":
			return TAU * float(index) / float(maxi(count, 1)) + jitter
		&"spear":
			return -PI * 0.5 + spread * 1.6 + jitter
		&"fork":
			return (-2.2 if index % 2 == 0 else -0.94) + spread * 0.45 + jitter
		&"key_burst":
			return -PI * 0.5 + spread * 2.5 + jitter
		_:
			return -PI * 0.5 + spread * 2.0 + jitter


func _unit_hash(index: int, salt: int) -> float:
	var value := sin(float((_enemy_id + 1) * 97 + (index + 1) * 53 + salt * 31)) * 43758.5453
	return value - floor(value)


func _exit_tree() -> void:
	_profile.clear()
