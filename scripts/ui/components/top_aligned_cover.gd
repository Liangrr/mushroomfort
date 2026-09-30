extends Control

## Draws a texture with CSS-like `object-fit: cover` geometry while pinning
## vertical crop to the source's top edge. Horizontal overflow stays centered.

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), source_rect_for_target(size))


func source_rect_for_target(target_size: Vector2) -> Rect2:
	if texture == null or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2()
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2()

	var source_aspect := source_size.x / source_size.y
	var target_aspect := target_size.x / target_size.y
	if target_aspect > source_aspect:
		var crop_height := source_size.x / target_aspect
		return Rect2(0.0, 0.0, source_size.x, crop_height)

	var crop_width := source_size.y * target_aspect
	var crop_left := (source_size.x - crop_width) * 0.5
	return Rect2(crop_left, 0.0, crop_width, source_size.y)
