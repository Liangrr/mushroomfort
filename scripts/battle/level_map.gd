class_name LevelMap
extends Node2D
## Static terrain for a level: painted ground, textured dirt roads with animated
## flow chevrons, dotted moonlight air lanes and spawn burrows.

var battle: BattleScene
var _t := 0.0
var _ground: Texture2D
var _theme := "day"


func build(level: Dictionary) -> void:
	_ground = GameData.tex("maps/%s.jpg" % level.get("ground", "ground_1"))
	_theme = str(level.get("theme", "day"))
	var dirt := GameData.tex("maps/dirt.png")
	for track: PathTrack in battle.ground_tracks:
		var pts := _extend(track.points, 40.0)
		_line(pts, 66.0, Color(0.22, 0.14, 0.06, 0.35), null)
		_line(pts, 58.0, Color("6b4a2b"), null)
		var road := _line(pts, 50.0, Color(1, 1, 1), dirt)
		road.texture_mode = Line2D.LINE_TEXTURE_TILE
		road.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_line(pts, 22.0, Color(1.0, 0.94, 0.78, 0.13), null)
	for track: PathTrack in battle.ground_tracks:
		_burrow(track)


func _extend(points: PackedVector2Array, by: float) -> PackedVector2Array:
	# Push the first point further off-screen so roads bleed out of the map edge.
	# Routes that start at the map edge are pushed far enough to stay hidden
	# on ultra-wide / tall screens (the world is centred, not scaled).
	var out := points.duplicate()
	if out.size() >= 2:
		var p0: Vector2 = out[0]
		var at_edge := p0.x <= 8.0 or p0.x >= 1272.0 or p0.y <= 8.0 or p0.y >= 712.0
		out[0] = p0 + (p0 - out[1]).normalized() * (maxf(by, 900.0) if at_edge else by)
	return out


func _line(pts: PackedVector2Array, width: float, color: Color, tex: Texture2D) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.width = width
	l.default_color = color
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	if tex != null:
		l.texture = tex
	add_child(l)
	return l


func _burrow(track: PathTrack) -> void:
	# Place a burrow where the road enters the visible map.
	var p := track.points[0]
	var q := track.points[1]
	var entry := p.lerp(q, 0.5) if p.distance_to(q) > 64.0 else q
	entry.x = clampf(entry.x, 30.0, 1250.0)
	var s := Sprite2D.new()
	s.texture = GameData.tex("world/burrow.png")
	s.position = entry + Vector2(0, -6)
	s.scale = Vector2.ONE * (86.0 / 224.0)
	s.z_index = 0
	add_child(s)


func _process(delta: float) -> void:
	_t += delta * (battle.speed_factor() if battle != null else 1.0)
	queue_redraw()


func _draw() -> void:
	if _ground != null:
		# Cover the whole visible area around the 1280x720 play field.
		var vs := get_viewport_rect().size
		var k := maxf(1.0, maxf(vs.x / 1600.0, vs.y / 900.0))
		var sz := Vector2(1600, 900) * k
		draw_texture_rect(_ground, Rect2(Vector2(640, 360) - sz / 2.0, sz), false)


## Flow chevrons and air lanes are drawn by the ground overlay so they animate
## above the Line2D roads.
func draw_flow(canvas: CanvasItem) -> void:
	var spacing := 70.0
	var off := fmod(_t * 30.0, spacing)
	for track: PathTrack in battle.ground_tracks:
		var d := off
		while d < track.length - 30.0:
			var p := track.sample(d)
			if p.x > -10.0 and p.x < 1290.0:
				var dir := track.direction(d)
				var n := dir.orthogonal()
				var a := 0.28 * clampf(d / 60.0, 0.0, 1.0)
				canvas.draw_polyline(PackedVector2Array([p - dir * 6.0 + n * 8.0, p + dir * 5.0, p - dir * 6.0 - n * 8.0]), Color(0.25, 0.14, 0.05, a), 4.0, true)
			d += spacing
	var dash := 16.0
	var aoff := fmod(_t * 36.0, dash * 2.0)
	for track: PathTrack in battle.air_tracks:
		var d := aoff
		while d < track.length - 20.0:
			var a := track.sample(d)
			var b := track.sample(minf(track.length, d + dash))
			if a.x > -10.0 and a.x < 1290.0:
				canvas.draw_line(a, b, Color(0.1, 0.18, 0.32, 0.35), 6.0, true)
				canvas.draw_line(a, b, Color(Palette.MOON, 0.75), 3.0, true)
			d += dash * 2.0
		# A small wing marker where flyers enter.
		var start := track.sample(40.0)
		start.x = clampf(start.x, 26.0, 1254.0)
		_wing(canvas, start)


func _wing(canvas: CanvasItem, p: Vector2) -> void:
	var bob := sin(_t * 3.0) * 3.0
	var c := p + Vector2(0, bob)
	canvas.draw_circle(c, 17.0, Color(0.1, 0.18, 0.32, 0.6))
	canvas.draw_circle(c, 14.0, Color(Palette.MOON, 0.85))
	for s in [-1.0, 1.0]:
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 2), c + Vector2(10 * s, -8), c + Vector2(12 * s, 2), c + Vector2(4 * s, 6)]), Color(1, 1, 1, 0.95))
