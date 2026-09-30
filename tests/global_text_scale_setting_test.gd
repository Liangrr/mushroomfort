extends SceneTree

const PREFS := preload("res://scripts/view/view_preferences.gd")
const PATH := "user://global_text_scale_setting_test.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove()
	var manager := root.get_node_or_null("TextScale")
	_check(manager != null, "TextScale autoload is unavailable")
	if manager == null:
		_finish()
		return
	manager.call("set_scale", 1.0)
	await _settle()
	_check(_near(float(manager.call("value")), 1.0), "TextScale did not reset to 100 percent")
	_check(_near(PREFS.text_scale(PATH), 1.0), "text scale default is not 100 percent")
	_check(not PREFS.set_text_scale(0.5, PATH), "out-of-range text scale was accepted")
	_check(PREFS.set_text_scale(1.37, PATH), "valid text scale was not persisted")
	_check(_near(PREFS.text_scale(PATH), 1.35), "persisted text scale was not normalized to a five-percent step")

	var host := Control.new()
	host.name = "TextScaleTestHost"
	root.add_child(host)
	var project_theme := ThemeDB.get_project_theme()
	var project_default_base := project_theme.default_font_size
	var project_body_base := project_theme.get_font_size(&"font_size", &"AuiBodyLabel")
	for shared_index: int in range(3):
		var shared_theme_control := Control.new()
		shared_theme_control.name = "SharedThemeControl%d" % shared_index
		shared_theme_control.theme = project_theme
		host.add_child(shared_theme_control)
	var explicit := Label.new()
	explicit.name = "ExplicitSize"
	explicit.text = "Existing explicit type"
	explicit.add_theme_font_size_override(&"font_size", 20)
	host.add_child(explicit)
	var themed := Label.new()
	themed.name = "ThemedSize"
	themed.text = "Inherited theme type"
	themed.theme_type_variation = &"AuiBodyLabel"
	host.add_child(themed)
	await _settle()
	_check(explicit.get_theme_font_size(&"font_size") == 20, "100 percent changed an explicit font size")
	_check(themed.get_theme_font_size(&"font_size") == 27, "100 percent changed inherited body type")

	manager.call("set_scale", 1.25)
	await _settle()
	_check(explicit.get_theme_font_size(&"font_size") == 25, "existing explicit type did not scale to 125 percent")
	_check(themed.get_theme_font_size(&"font_size") == 34, "inherited theme type did not scale to 125 percent")

	var dynamic := Label.new()
	dynamic.name = "DynamicExplicitSize"
	dynamic.text = "Dynamic explicit type"
	dynamic.add_theme_font_size_override(&"font_size", 24)
	host.add_child(dynamic)
	await _settle()
	_check(dynamic.get_theme_font_size(&"font_size") == 30, "dynamically added explicit type did not inherit 125 percent")

	explicit.add_theme_font_size_override(&"font_size", 28)
	await _settle()
	_check(explicit.get_theme_font_size(&"font_size") == 35, "runtime override did not rebase before global scaling")
	manager.call("set_scale", 1.50)
	await _settle()
	_check(explicit.get_theme_font_size(&"font_size") == 42, "rebased explicit type compounded instead of reaching 150 percent")
	_check(dynamic.get_theme_font_size(&"font_size") == 36, "dynamic type compounded instead of reaching 150 percent")
	_check(themed.get_theme_font_size(&"font_size") == 41, "inherited theme type did not reach 150 percent")
	_check(project_theme.default_font_size == roundi(project_default_base * 1.5), "shared project theme default compounded above 150 percent")
	_check(project_theme.get_font_size(&"font_size", &"AuiBodyLabel") == roundi(project_body_base * 1.5), "shared project body type compounded above 150 percent")

	manager.call("set_scale", 0.80)
	await _settle()
	_check(explicit.get_theme_font_size(&"font_size") == 22, "rebased explicit type did not reach 80 percent")
	_check(dynamic.get_theme_font_size(&"font_size") == 19, "dynamic type did not reach 80 percent")
	_check(themed.get_theme_font_size(&"font_size") == 22, "inherited theme type did not reach 80 percent")

	manager.call("set_scale", 1.0)
	await _settle()
	_check(explicit.get_theme_font_size(&"font_size") == 28, "explicit type did not restore its rebased 100-percent size")
	_check(dynamic.get_theme_font_size(&"font_size") == 24, "dynamic type did not restore its 100-percent size")
	_check(themed.get_theme_font_size(&"font_size") == 27, "theme type did not restore its 100-percent size")
	_check(project_theme.default_font_size == project_default_base, "shared project theme default did not round-trip to 100 percent")
	_check(project_theme.get_font_size(&"font_size", &"AuiBodyLabel") == project_body_base, "shared project body type did not round-trip to 100 percent")
	host.queue_free()
	await _settle()
	_remove()
	_finish()


func _settle() -> void:
	for _frame: int in range(4):
		await process_frame


func _near(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 0.001


func _remove() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("GLOBAL_TEXT_SCALE_SETTING_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
