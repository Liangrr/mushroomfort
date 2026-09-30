class_name LevelMinimap
extends Control
## Miniature of a level: ground painting, ground paths (dirt), air paths (dotted blue) and the vault.

var level: Dictionary = {}
var locked := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var ground := GameData.tex("maps/%s.jpg" % level.get("ground", "ground_1"))
	if ground != null:
		draw_texture_rect(ground, r, false)
	var grid: Dictionary = GameData.balance.get("grid", {})
	var cols := float(grid.get("cols", 20))
	var rows := float(grid.get("rows", 11))
	var k := Vector2(size.x / cols, size.y / rows)
	for path in level.get("air_paths", []):
		var pts := _pts(path, k)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := int(a.distance_to(b) / 9.0)
			for j in n:
				if j % 2 == 0:
					draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(Palette.MOON, 0.9), 2.5)
	for path in level.get("paths", []):
		var pts := _pts(path, k)
		draw_polyline(pts, Color(Palette.INK, 0.6), k.y * 0.95, true)
		draw_polyline(pts, Color("d9b278"), k.y * 0.7, true)
	var vault: Array = level.get("vault", [0, 0])
	var vc := Vector2((float(vault[0]) + 0.5) * k.x, (float(vault[1]) + 0.5) * k.y)
	var vt := GameData.tex("world/vault_intact.png")
	if vt != null:
		var vs := Vector2(k.x * 2.6, k.x * 2.6 * vt.get_height() / vt.get_width())
		draw_texture_rect(vt, Rect2(vc - vs * Vector2(0.5, 0.7), vs), false)
	if locked:
		draw_rect(r, Color(0.1, 0.08, 0.05, 0.6))
	draw_rect(r, Palette.INK, false, 3.0)


func _pts(path: Array, k: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in path:
		out.append(Vector2((float(p[0]) + 0.5) * k.x, (float(p[1]) + 0.5) * k.y))
	return out
