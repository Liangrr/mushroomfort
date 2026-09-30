extends SceneTree

var _loading: Control
var _output_path := ""
var _locale_id := &"en-US"


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--locale="):
			_locale_id = StringName(argument.trim_prefix("--locale="))
	call_deferred("_run")


func _run() -> void:
	if _output_path.is_empty():
		print("LOADING_ART_VISUAL_HARNESS_READY")
		quit(0)
		return
	if not bool(root.get_node("I18n").call("set_locale", _locale_id)):
		push_error("loading visual harness could not set locale %s" % _locale_id)
		quit(1)
		return
	_loading = load("res://scenes/loading.tscn").instantiate() as Control
	root.add_child(_loading)
	_loading.set_process(false)
	var progress := _loading.find_child("Progress", true, false) as ProgressBar
	var status := _loading.find_child("StatusLabel", true, false) as Label
	var percentage := _loading.find_child("PercentageLabel", true, false) as Label
	if progress != null:
		progress.value = 62.0
	if status != null:
		status.text = String(root.get_node("I18n").call("t", &"ui.loading.phase.aligning", "ALIGNING LUNAR GEOMETRY"))
	if percentage != null:
		percentage.text = "62%"
	for _frame: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(_output_path)
	if error != OK:
		push_error("loading visual capture failed: %s" % error_string(error))
		quit(1)
		return
	print("LOADING_ART_VISUAL_OK|%s|%dx%d|%s" % [_output_path, image.get_width(), image.get_height(), _locale_id])
	_loading.queue_free()
	await process_frame
	quit(0)
