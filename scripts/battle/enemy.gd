class_name Enemy
extends Node2D
## One pest walking (or flying) along a PathTrack. Simulation state lives here;
## Battle drives sim_step() at game speed and handles kills and leaks.

const FLASH_SHADER := preload("res://scripts/battle/flash.gdshader")
const FLY_HEIGHT := 26.0

var enemy_id := ""
var def: Dictionary = {}
var track: PathTrack
var dist := 0.0
var lateral := 0.0
var hp := 1.0
var max_hp := 1.0
var speed := 40.0
var armor := 0.0
var bounty := 0
var lives_cost := 1
var radius := 18.0
var flying := false
var boss := false
var slow_resist := 0.0
var stun_resist := 0.0

var slow_pct := 0.0
var slow_time := 0.0
var stun_time := 0.0
var frozen := false
var poison_dps := 0.0
var poison_time := 0.0
var poison_spread := 0.0
var vuln := 0.0          # set every step by sap puddles
var puddle_slow := 0.0   # set every step by sap puddles
var alive := true
var reached := false
var last_hit_by := ""

var sprite: Sprite2D
var _mat: ShaderMaterial
var _flash := 0.0
var _t := 0.0
var _base_scale := 1.0
var _facing := 1.0
var _spawn_anim := 0.0
var _anim := "walk"


func setup(id: String, enemy_def: Dictionary, path: PathTrack, hp_scale: float, start_dist: float = 0.0) -> void:
	enemy_id = id
	def = enemy_def
	track = path
	dist = start_dist
	max_hp = float(def.get("hp", 50)) * hp_scale
	hp = max_hp
	speed = float(def.get("speed", 40))
	armor = float(def.get("armor", 0.0))
	bounty = int(def.get("bounty", 5))
	lives_cost = int(def.get("lives", 1))
	radius = float(def.get("radius", 18))
	flying = bool(def.get("flying", false))
	boss = bool(def.get("boss", false))
	slow_resist = float(def.get("slow_resist", 0.0))
	stun_resist = float(def.get("stun_resist", 0.0))
	_anim = str(def.get("anim", "walk"))
	lateral = randf_range(-9.0, 9.0) if not boss else 0.0
	if flying:
		lateral = randf_range(-16.0, 16.0)
	_t = randf() * 10.0
	sprite = Sprite2D.new()
	sprite.texture = GameData.enemy_tex(str(def.get("sprite", id)))
	if sprite.texture != null:
		_base_scale = float(def.get("size", 48)) / float(sprite.texture.get_width())
	sprite.scale = Vector2.ONE * _base_scale
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.42) if sprite.texture != null else Vector2.ZERO
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	add_child(sprite)
	position = _pos_now()


func _pos_now() -> Vector2:
	var dir := track.direction(dist)
	return track.sample(dist) + dir.orthogonal() * lateral


func sim_step(dt: float) -> void:
	if slow_time > 0.0:
		slow_time -= dt
		if slow_time <= 0.0:
			slow_pct = 0.0
	if stun_time > 0.0:
		stun_time -= dt
		if stun_time <= 0.0:
			frozen = false
	if poison_time > 0.0:
		poison_time -= dt
		hp -= poison_dps * dt
		if poison_time <= 0.0:
			poison_dps = 0.0
			poison_spread = 0.0
	var slow := maxf(slow_pct, puddle_slow) * (1.0 - slow_resist)
	var v := 0.0 if stun_time > 0.0 else speed * (1.0 - slow)
	dist += v * dt
	if dist >= track.length:
		dist = track.length
		reached = true
	position = _pos_now()


func apply_damage(amount: float, armor_pierce: float = 0.0) -> float:
	var eff_armor := armor * (1.0 - clampf(armor_pierce, 0.0, 1.0))
	var dmg := amount * (1.0 - eff_armor) * (1.0 + vuln)
	hp -= dmg
	_flash = 1.0
	return dmg


func apply_slow(pct: float, duration: float) -> void:
	if pct >= slow_pct or slow_time <= 0.0:
		slow_pct = pct
	slow_time = maxf(slow_time, duration)


func apply_stun(duration: float, is_freeze: bool = false) -> void:
	var d := duration * (1.0 - stun_resist)
	if d > stun_time:
		stun_time = d
		frozen = is_freeze


func apply_poison(dps: float, duration: float, spread: float = 0.0) -> void:
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, duration)
	poison_spread = maxf(poison_spread, spread)


func remaining() -> float:
	return track.length - dist


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## Where projectiles should aim (body centre, accounting for flight height).
func aim_point() -> Vector2:
	var s := float(def.get("size", 48))
	return position + Vector2(0, -FLY_HEIGHT - s * 0.3 if flying else -s * 0.36)


func visual_step(dt: float) -> void:
	_t += dt
	_flash = maxf(0.0, _flash - dt * 7.0)
	_spawn_anim = minf(1.0, _spawn_anim + dt * 4.0)
	var dir := track.direction(dist)
	if absf(dir.x) > 0.2:
		_facing = signf(dir.x)
	sprite.flip_h = _facing < 0.0
	var stunned := stun_time > 0.0
	var tt := 0.0 if stunned else _t
	var sx := 1.0
	var sy := 1.0
	var oy := 0.0
	var rot := 0.0
	match _anim:
		"dash":
			oy = -absf(sin(tt * 16.0)) * 2.5
			rot = 0.07 * _facing
		"heavy":
			oy = -absf(sin(tt * 5.0)) * 2.0
			rot = sin(tt * 5.0) * 0.04
		"flutter":
			oy = -FLY_HEIGHT + sin(tt * 4.0) * 5.0
			sx = 1.0 + sin(tt * 22.0) * 0.12
		"ooze":
			sy = 1.0 + sin(tt * 7.0) * 0.1
			sx = 1.0 - sin(tt * 7.0) * 0.08
		_:
			oy = -absf(sin(tt * 9.0)) * 3.0
			sx = 1.0 + sin(tt * 18.0) * 0.03
	var appear := ease(_spawn_anim, 0.4)
	sprite.position = Vector2(0, oy)
	sprite.rotation = rot
	sprite.scale = Vector2(sx, sy) * _base_scale * appear
	var tint := Color.WHITE
	if frozen:
		tint = Color(0.72, 0.9, 1.35)
	elif poison_time > 0.0:
		tint = Color(0.82, 1.08, 0.62)
	elif slow_time > 0.0 or puddle_slow > 0.0:
		tint = Color(0.8, 0.92, 1.15) if puddle_slow <= 0.0 else Color(1.12, 0.92, 0.6)
	# Tint via modulate (batches); the flash shader is attached only while
	# flashing so crowds of pests keep 2D batching intact.
	sprite.self_modulate = tint
	if _flash > 0.01:
		sprite.material = _mat
		_mat.set_shader_parameter("tint", Color.WHITE)
		_mat.set_shader_parameter("flash", _flash)
	elif sprite.material != null:
		sprite.material = null
	queue_redraw()


func _draw() -> void:
	var w := float(def.get("size", 48))
	if flying:
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, w * 0.3, Color(0.05, 0.08, 0.15, 0.22))
	else:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.36))
		draw_circle(Vector2.ZERO, w * 0.42, Color(0.1, 0.06, 0.02, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
