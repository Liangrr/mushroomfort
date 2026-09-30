class_name BattleOverlay
extends Node2D
## Two instances: mode "ground" (under units: flow arrows, build grid, range
## discs) and mode "top" (over everything: HP bars, ghost tower, cursor).

var battle: BattleScene
var mode := "ground"
var _t := 0.0
var _font: Font


func _ready() -> void:
	_font = UiTheme.bold_font if UiTheme.bold_font != null else ThemeDB.fallback_font


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if battle == null:
		return
	if mode == "ground":
		_draw_ground()
	else:
		_draw_top()


# ------------------------------------------------------------ ground layer

func _draw_ground() -> void:
	battle.level_map.draw_flow(self)
	var cs: float = battle.cell
	var preview: Dictionary = battle.preview_info()
	if preview.get("show_grid", false):
		for y in battle.rows:
			for x in battle.cols:
				var c := Vector2i(x, y)
				if battle.is_buildable(c):
					var r := battle.cell_rect(c).grow(-6.0)
					draw_rect(r, Color(1.0, 0.97, 0.85, 0.10), true)
					draw_rect(r, Color(1.0, 0.97, 0.85, 0.22), false, 1.5)
	# Selected tower range (and upgrade preview range).
	var sel: Tower = battle.selected
	if sel != null and is_instance_valid(sel):
		_range(sel.position + Vector2(0, 8), sel.range_px(), Palette.AMBER, 1.0, sel.hits_air())
		var up := float(preview.get("upgrade_range", 0.0))
		if up > 0.0 and absf(up - sel.range_px()) > 1.0:
			_dashed_ring(sel.position + Vector2(0, 8), up, Palette.CREAM, 3.0)
	if preview.has("cell"):
		var c: Vector2i = preview.cell
		var r := battle.cell_rect(c)
		var ok: bool = preview.get("valid", false)
		var col := Palette.AMBER_LIGHT if ok else Palette.DANGER
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(r.grow(-3.0), Color(col, 0.18 + 0.1 * pulse), true)
		draw_rect(r.grow(-3.0), Color(col, 0.9), false, 3.0)
		if preview.has("range") and ok:
			_range(r.get_center() + Vector2(0, 8), float(preview.range), Palette.AMBER_LIGHT if preview.get("affordable", true) else Palette.CORAL, 0.8, preview.get("air", true))


func _range(center: Vector2, radius: float, col: Color, strength: float, air: bool) -> void:
	draw_circle(center, radius, Color(col, 0.13 * strength))
	var segs := 64
	var rot := _t * 0.35
	for i in segs:
		if i % 2 == 0:
			var a0 := rot + TAU * i / segs
			var a1 := rot + TAU * (i + 1) / segs
			draw_arc(center, radius, a0, a1, 3, Color(col, 0.95 * strength), 3.0, true)
	draw_arc(center, radius + 3.0, 0.0, TAU, 64, Color(Palette.INK, 0.25 * strength), 1.5, true)
	if not air:
		# Ground-only badge: a small crossed wing at the ring top.
		var p := center + Vector2(0, -radius)
		draw_circle(p, 13.0, Palette.INK)
		draw_circle(p, 11.0, Palette.CREAM)
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, 1), p + Vector2(7 * s, -5), p + Vector2(8 * s, 1), p + Vector2(3 * s, 4)]), Palette.MOON_DARK)
		draw_line(p + Vector2(-8, -8), p + Vector2(8, 8), Palette.DANGER, 3.0, true)


func _dashed_ring(center: Vector2, radius: float, col: Color, width: float) -> void:
	var segs := 48
	for i in segs:
		if i % 2 == 0:
			draw_arc(center, radius, TAU * i / segs - _t * 0.5, TAU * (i + 1) / segs - _t * 0.5, 3, Color(col, 0.95), width, true)


# ------------------------------------------------------------ top layer

func _draw_top() -> void:
	for e: Enemy in battle.enemies:
		if not e.alive:
			continue
		if e.hp < e.max_hp or e.boss:
			_hp_bar(e)
		if e.stun_time > 0.0 and not e.frozen:
			var p := e.aim_point() + Vector2(0, -float(e.def.get("size", 48)) * 0.5)
			for k in 3:
				var a := _t * 5.0 + k * TAU / 3.0
				draw_colored_polygon(StarRow.star_points(p + Vector2(cos(a) * 12.0, sin(a) * 4.0), 5.0, 2.2), Palette.AMBER_LIGHT)
	var preview: Dictionary = battle.preview_info()
	if preview.has("cell") and preview.has("tower"):
		var r := battle.cell_rect(preview.cell)
		var base := r.get_center()
		var tex := GameData.tower_tex(str(GameData.tower_stats(preview.tower, "1").get("sprite", "")))
		if tex != null:
			var h := 84.0
			var s := h / tex.get_height()
			var size := Vector2(tex.get_width(), tex.get_height()) * s
			var bob := sin(_t * 5.0) * 3.0
			var ok: bool = preview.get("valid", false)
			var mod := Color(1, 1, 1, 0.72) if ok else Color(1.0, 0.45, 0.4, 0.6)
			draw_texture_rect(tex, Rect2(base + Vector2(-size.x / 2.0, 24.0 - size.y + bob), size), false, mod)
			if not ok:
				var c := base + Vector2(0, -10)
				draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), Palette.INK, 9.0)
				draw_line(c + Vector2(14, -14), c + Vector2(-14, 14), Palette.INK, 9.0)
				draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), Palette.DANGER, 5.0)
				draw_line(c + Vector2(14, -14), c + Vector2(-14, 14), Palette.DANGER, 5.0)
			var reason := str(preview.get("reason", ""))
			if reason != "":
				_tag(base + Vector2(0, 46), reason, Palette.DANGER)
	if battle.cursor_visible():
		var r := battle.cell_rect(battle.cursor_cell).grow(2.0)
		var k := 10.0 + sin(_t * 6.0) * 2.0
		var col := Palette.CREAM
		for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
			var p: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_line(p, p + Vector2(d.x * k, 0), Palette.INK, 7.0)
			draw_line(p, p + Vector2(0, d.y * k), Palette.INK, 7.0)
			draw_line(p, p + Vector2(d.x * k, 0), col, 4.0)
			draw_line(p, p + Vector2(0, d.y * k), col, 4.0)


func _hp_bar(e: Enemy) -> void:
	var w := 40.0 if not e.boss else 96.0
	var h := 7.0 if not e.boss else 11.0
	var top := e.aim_point() + Vector2(-w / 2.0, -float(e.def.get("size", 48)) * 0.52 - 6.0)
	var ratio := e.hp_ratio()
	draw_rect(Rect2(top - Vector2(2, 2), Vector2(w + 4, h + 4)), Palette.INK, true)
	draw_rect(Rect2(top, Vector2(w, h)), Color("5a2a20"), true)
	var col := Palette.LIME.lerp(Palette.AMBER, clampf((0.7 - ratio) / 0.4, 0.0, 1.0))
	if ratio < 0.3:
		col = Palette.CORAL_LIGHT
	if e.flying:
		col = Palette.MOON
	draw_rect(Rect2(top, Vector2(w * ratio, h)), col, true)
	draw_rect(Rect2(top, Vector2(w * ratio, h * 0.4)), Color(1, 1, 1, 0.3), true)
	if e.armor > 0.0:
		# Shield pip for armoured pests.
		var p := top + Vector2(-8, h / 2.0)
		draw_circle(p, 7.0, Palette.INK)
		draw_circle(p, 5.0, Color("b8b8c8"))


func _tag(center: Vector2, text: String, col: Color) -> void:
	var fs := 16
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	var r := Rect2(center - Vector2(w / 2.0, 13), Vector2(w, 26))
	draw_style_box(_pill(col), r)
	draw_string(_font, Vector2(r.position.x + 9, r.position.y + 19), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.CREAM)


var _pill_cache := {}
func _pill(col: Color) -> StyleBoxFlat:
	if _pill_cache.has(col):
		return _pill_cache[col]
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Palette.INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	_pill_cache[col] = sb
	return sb
