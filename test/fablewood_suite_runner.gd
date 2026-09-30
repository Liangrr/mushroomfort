extends RefCounted
## Source-only bounded subprocesses retain each fixture's isolated lifecycle.
## Pack checks stay individual so the runtime owns the exact selected PCK.
static func run(owner: String, checks: Array[Dictionary]) -> bool:
	var source_dir := ProjectSettings.globalize_path(owner.get_base_dir())
	var project_path := ProjectSettings.globalize_path("res://")
	if project_path.is_empty():
		push_error("The Fablewood source suite cannot run against a player pack")
		return false
	var base := PackedStringArray(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", project_path])
	var temporary_root := OS.get_environment("XDG_DATA_HOME").get_base_dir()
	if temporary_root.is_empty():
		temporary_root = OS.get_cache_dir()
	for check: Dictionary in checks:
		var isolated := temporary_root.path_join("manus-game-verify-td-suite-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
		if DirAccess.make_dir_recursive_absolute(isolated.path_join("data")) != OK or DirAccess.make_dir_recursive_absolute(isolated.path_join("config")) != OK:
			push_error("Could not create isolated fixture data directory")
			return false
		var previous_data := OS.get_environment("XDG_DATA_HOME")
		var previous_config := OS.get_environment("XDG_CONFIG_HOME")
		var previous_flag := OS.get_environment("PROTO_TD_TEST_ISOLATED")
		var previous_id := OS.get_environment("PROTO_TD_TEST_RUN_ID")
		OS.set_environment("XDG_DATA_HOME", isolated.path_join("data"))
		OS.set_environment("XDG_CONFIG_HOME", isolated.path_join("config"))
		# A manual parent's explicit save name must not defeat each child's
		# fresh managed XDG directory (especially on macOS).
		OS.unset_environment("PROTO_TD_TEST_ISOLATED")
		OS.unset_environment("PROTO_TD_TEST_RUN_ID")
		var args := base.duplicate()
		if check.path.ends_with(".gd"):
			args.append_array(["--script", source_dir.path_join(check.path)])
		else:
			args.append("res://test/" + check.path)
		# Assertions can abort a fixture without quitting Godot. Require its
		# success marker as well as a clean exit, and bound that case by frames.
		args.append_array(["--quit-after", "900"])
		var captured: Array = []
		var code := OS.execute(OS.get_executable_path(), args, captured, true)
		_restore_environment("XDG_DATA_HOME", previous_data)
		_restore_environment("XDG_CONFIG_HOME", previous_config)
		_restore_environment("PROTO_TD_TEST_ISOLATED", previous_flag)
		_restore_environment("PROTO_TD_TEST_RUN_ID", previous_id)
		_remove_tree(isolated)
		var output := "\n".join(captured)
		print(output)
		if code != 0 or not output.contains(check.expect) or output.contains("SCRIPT ERROR") or output.contains("Parse Error:") or output.contains("Compile Error:") or output.contains("ERROR:"):
			push_error("Fablewood fixture failed or did not complete: " + check.path)
			return false
	return true

static func _restore_environment(name: String, value: String) -> void:
	if value.is_empty():
		OS.unset_environment(name)
	else:
		OS.set_environment(name, value)

static func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for folder: String in directory.get_directories():
		if directory.is_link(folder):
			DirAccess.remove_absolute(path.path_join(folder))
		else:
			_remove_tree(path.path_join(folder))
	DirAccess.remove_absolute(path)
