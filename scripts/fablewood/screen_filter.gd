extends CanvasLayer
## Static cosmetic warmth/vignette. No simulation, time, input or motion state.

const FILTER_SHADER := preload("res://scripts/fablewood/screen_filter.gdshader")
var _enabled := false
var _intensity := 0.3
var _rect: ColorRect


func _ready() -> void:
	layer = 20
	_rect = ColorRect.new()
	_rect.name = "CosmeticScreenFilter"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.focus_mode = Control.FOCUS_NONE
	var effect := ShaderMaterial.new()
	effect.shader = FILTER_SHADER
	_rect.material = effect
	add_child(_rect)
	get_viewport().size_changed.connect(_resize)
	_resize()
	_apply()


func set_enabled(value: bool) -> void:
	_enabled = value
	_apply()


func is_enabled() -> bool:
	return _enabled


func set_intensity(value: float) -> void:
	if not is_finite(value):
		return
	_intensity = clampf(value, 0.0, 1.0)
	_apply()


func intensity() -> float:
	return _intensity


func _apply() -> void:
	if not is_instance_valid(_rect):
		return
	_rect.visible = _enabled and _intensity > 0.0
	_rect.material.set_shader_parameter("intensity", _intensity)


func _resize() -> void:
	_rect.position = Vector2.ZERO
	_rect.size = get_viewport().get_visible_rect().size
