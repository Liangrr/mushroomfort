class_name BattleEndpointLandmark
extends TextureRect

## Presentation-only loop for strategic SPAWN/BASE landmarks. The battle model,
## paths, endpoint tiles, and enemy lifecycle remain authoritative elsewhere.

var _art_id: StringName = &""
var _frame_count := 0
var _fps := 0.0
var _elapsed := 0.0
var _frame_index := 0


func setup(art_id: StringName) -> bool:
	_art_id = art_id
	_frame_count = Art.frame_count(art_id)
	_fps = Art.fps(art_id)
	var native_size := Art.size(art_id)
	if _frame_count <= 0 or _fps <= 0.0 or native_size == Vector2i.ZERO:
		return false
	var display_size := native_size
	var stored_display_size: Variant = Art.metadata(art_id).get("display_size", native_size)
	if stored_display_size is Vector2i:
		display_size = stored_display_size
	if display_size == Vector2i.ZERO:
		return false
	var first_frame := Art.animation_texture(art_id, &"idle", 0)
	if first_frame == null:
		first_frame = Art.animation_texture(art_id, &"default", 0)
	if first_frame == null:
		first_frame = Art.texture(art_id, 0)
	if first_frame == null:
		return false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(display_size)
	size = Vector2(display_size)
	texture = first_frame
	set_process(_frame_count > 1)
	return true


func art_id() -> StringName:
	return _art_id


func frame_index() -> int:
	return _frame_index


func frame_count() -> int:
	return _frame_count


func _process(delta: float) -> void:
	if _frame_count <= 1 or bool(ProjectSettings.get_setting("accessibility/reduced_motion", false)):
		_set_frame(0)
		return
	_elapsed = fmod(_elapsed + delta, float(_frame_count) / _fps)
	_set_frame(int(floor(_elapsed * _fps)) % _frame_count)


func _set_frame(index: int) -> void:
	if index == _frame_index and texture != null:
		return
	_frame_index = index
	var next_texture := Art.animation_texture(_art_id, &"idle", index)
	if next_texture == null:
		next_texture = Art.animation_texture(_art_id, &"default", index)
	if next_texture == null:
		next_texture = Art.texture(_art_id, index)
	if next_texture != null:
		texture = next_texture
