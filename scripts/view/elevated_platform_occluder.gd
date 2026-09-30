extends Node2D

## A raised platform must participate in the same painter-depth ordering as
## characters. Flat terrain stays in the shared background draw pass, while
## each platform is replayed here at its cell depth so characters behind it
## are occluded and characters standing on it remain visible above it.

var _points := PackedVector2Array()
var _top_color := Color.WHITE
var _right_wall_color := Color.WHITE
var _left_wall_color := Color.WHITE
var _texture: Texture2D = null
var _tints := PackedColorArray()
var _uvs := PackedVector2Array()
var _grid_line := Color.TRANSPARENT


func configure(
	cell: Vector2i,
	points: PackedVector2Array,
	top_color: Color,
	right_wall_color: Color,
	left_wall_color: Color,
	texture: Texture2D,
	tints: PackedColorArray,
	uvs: PackedVector2Array,
	grid_line: Color,
) -> void:
	name = "ElevatedPlatformOccluder_%d_%d" % [cell.x, cell.y]
	z_index = IsoProjection.tile_z(cell)
	_points = points
	_top_color = top_color
	_right_wall_color = right_wall_color
	_left_wall_color = left_wall_color
	_texture = texture
	_tints = tints
	_uvs = uvs
	_grid_line = grid_line
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()


func _draw() -> void:
	if _points.size() != 4:
		return
	var drop := Vector2(0.0, IsoProjection.ELEV_LIFT_PX)
	draw_colored_polygon(
		PackedVector2Array([
			_points[1], _points[1] + drop, _points[2] + drop, _points[2],
		]),
		_right_wall_color,
	)
	draw_colored_polygon(
		PackedVector2Array([
			_points[2], _points[2] + drop, _points[3] + drop, _points[3],
		]),
		_left_wall_color,
	)
	draw_colored_polygon(_points, _top_color)
	if _texture != null:
		draw_polygon(_points, _tints, _uvs, _texture)
	var closed := _points.duplicate()
	closed.append(_points[0])
	draw_polyline(closed, _grid_line, 1.2, true)
