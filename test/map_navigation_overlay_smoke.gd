extends SceneTree

const OVERLAY_SCRIPT := preload("res://scripts/ui/map_navigation_overlay.gd")
const PREFS_PATH := "user://map_navigation_overlay_smoke.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := PackedStringArray()
	_remove_preferences()
	var overlay: MapNavigationOverlay = OVERLAY_SCRIPT.new()
	root.add_child(overlay)
	overlay.setup(PREFS_PATH)
	overlay.set_context(true, true, true)
	if not overlay.hint_visible():
		failures.append("first portrait overflow must show the pan hint")
	if overlay.get_node_or_null("RecenterMap") != null:
		failures.append("removed CENTER control is still present")
	if overlay.has_method("recenter_enabled"):
		failures.append("removed CENTER feature API is still exposed")
	overlay.notify_pan_used()
	if overlay.hint_visible():
		failures.append("a real pan must dismiss the first-use hint")
	overlay.queue_free()
	await process_frame

	var restored: MapNavigationOverlay = OVERLAY_SCRIPT.new()
	root.add_child(restored)
	restored.setup(PREFS_PATH)
	restored.set_context(true, true, true)
	if restored.hint_visible():
		failures.append("completed pan hint did not persist across overlay instances")
	restored.set_context(false, true, true)
	if restored.hint_visible():
		failures.append("landscape must not show the portrait pan hint")
	restored.set_context(true, false, true)
	if restored.hint_visible():
		failures.append("non-overflowing maps must not show the pan hint")
	if restored.get_node_or_null("RecenterMap") != null:
		failures.append("restored overlay recreated the removed CENTER control")
	restored.queue_free()
	await process_frame
	_remove_preferences()

	if failures.is_empty():
		print("MAP_NAVIGATION_OVERLAY_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _remove_preferences() -> void:
	var absolute := ProjectSettings.globalize_path(PREFS_PATH)
	if FileAccess.file_exists(PREFS_PATH):
		DirAccess.remove_absolute(absolute)
