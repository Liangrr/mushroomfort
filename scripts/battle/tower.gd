class_name Tower
extends Node2D
## A planted mushroom turret. Stats come straight from towers.json level entries;
## Battle resolves the actual attacks (pulse / shot / lob).

const FLASH_SHADER := preload("res://scripts/battle/flash.gdshader")
const TIER_HEIGHT := {1: 84.0, 2: 94.0, 3: 108.0, 4: 118.0}

var tower_id := ""
var def: Dictionary = {}
var level_key := "1"
var stats: Dictionary = {}
var cell := Vector2i.ZERO
var cooldown := 0.4
var spent := 0
var pulse_count := 0
var kills := 0
var damage_dealt := 0.0

var sprite: Sprite2D
var _mat: ShaderMaterial
var _t := 0.0
var _kick := 0.0
var _bloom := 1.0
var _flash := 0.0
var _facing := 1.0
var _display_h := 84.0
var color := Color.WHITE


func setup(id: String, at_cell: Vector2i, at_pos: Vector2) -> void:
	tower_id = id
	def = GameData.towers.get(id, {})
	color = Color(str(def.get("color", "#ffffff")))
	cell = at_cell
	position = at_pos
	_t = randf() * 10.0
	sprite = Sprite2D.new()
	_mat = ShaderMaterial.new()
	_mat.shader = FLASH_SHADER
	add_child(sprite)
	set_level("1")


func set_level(key: String) -> void:
	level_key = key
	stats = GameData.tower_stats(tower_id, key)
	spent += int(stats.get("cost", 0))
	pulse_count = 0
	sprite.texture = GameData.tower_tex(str(stats.get("sprite", tower_id + "_1")))
	_display_h = TIER_HEIGHT.get(tier(), 90.0)
	if sprite.texture != null:
		sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
	sprite.position = Vector2(0, 24)
	_bloom = 0.0
	_flash = 1.0
	cooldown = minf(cooldown, 0.35)


func tier() -> int:
	match level_key:
		"1": return 1
		"2": return 2
		"a1", "b1": return 3
	return 4


func branch() -> String:
	return level_key.substr(0, 1) if level_key.length() == 2 else ""


func next_options() -> Array:
	return stats.get("next", [])


func range_px() -> float:
	return float(stats.get("range", 100))


func hits_air() -> bool:
	return bool(stats.get("air", true))


func attack() -> String:
	return str(stats.get("attack", "shot"))


func display_name() -> String:
	return Loc.t(str(stats.get("name", def.get("name", ""))))


func sell_value() -> int:
	return int(round(spent * float(GameData.balance.get("sell_refund", 0.7))))


func base_scale() -> float:
	if sprite.texture == null:
		return 1.0
	return _display_h / float(sprite.texture.get_height())


## Where shots leave the tower.
func muzzle() -> Vector2:
	if tower_id == "thorn":
		return position + Vector2(_facing * _display_h * 0.32, 24 - _display_h * 0.55)
	return position + Vector2(0, 24 - _display_h * 0.78)


func face(target_pos: Vector2) -> void:
	if tower_id == "thorn" and absf(target_pos.x - position.x) > 4.0:
		_facing = signf(target_pos.x - position.x)


func on_fire() -> void:
	_kick = 1.0


func visual_step(dt: float) -> void:
	_t += dt
	_kick = maxf(0.0, _kick - dt * 5.0)
	_flash = maxf(0.0, _flash - dt * 3.0)
	_bloom = minf(1.0, _bloom + dt * 2.2)
	var s := base_scale()
	var breathe := sin(_t * 2.1) * 0.02
	# Elastic bloom when planted or upgraded.
	var b := 1.0
	if _bloom < 1.0:
		b = 1.0 + sin(_bloom * PI * 2.5) * (1.0 - _bloom) * 0.35
		b *= minf(1.0, 0.3 + _bloom * 2.0)
	var k := _kick
	sprite.scale = Vector2(s * (1.0 - breathe + k * 0.09) * b, s * (1.0 + breathe - k * 0.13) * b)
	sprite.flip_h = _facing < 0.0
	if _flash > 0.01:
		sprite.material = _mat
		_mat.set_shader_parameter("flash", _flash * 0.6)
	elif sprite.material != null:
		sprite.material = null
	queue_redraw()


func _draw() -> void:
	# Ground shadow.
	draw_set_transform(Vector2(0, 20), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 30.0 + tier() * 2.0, Color(0.08, 0.05, 0.02, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var t4 := tier() == 4
	if tier() >= 3:
		# Branch aura: a soft ring of drifting petals behind the tower.
		var col := Palette.BRANCH_A if branch() == "a" else Palette.BRANCH_B
		var n := 6 if t4 else 3
		for i in n:
			var a := _t * (0.9 if t4 else 0.6) + i * TAU / n
			var p := Vector2(cos(a) * 34.0, 12.0 + sin(a) * 11.0)
			var pr := 5.0 if t4 else 4.0
			var dir := Vector2(cos(a * 2.0), sin(a * 2.0))
			draw_colored_polygon(PackedVector2Array([p + dir * pr * 1.4, p + dir.orthogonal() * pr * 0.6, p - dir * pr * 1.4, p - dir.orthogonal() * pr * 0.6]), Color(col, 0.85))
		if t4:
			var glow := 0.18 + 0.08 * sin(_t * 3.0)
			draw_set_transform(Vector2(0, 20), 0.0, Vector2(1.0, 0.34))
			draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(col, glow * 2.0), 3.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Level pips (little flowers) under the tower.
	var pips := tier()
	var start := -(pips - 1) * 7.0
	for i in pips:
		var c := Vector2(start + i * 14.0, 34.0)
		var pc := Palette.AMBER if i < 2 else (Palette.BRANCH_A if branch() == "a" else Palette.BRANCH_B)
		draw_circle(c, 5.5, Palette.INK)
		draw_circle(c, 4.0, pc)
