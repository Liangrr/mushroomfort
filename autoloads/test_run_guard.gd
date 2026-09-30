extends Node

## Prevent repository tests and visual harnesses from touching the playable
## application's user:// directory. The supported runners generate a temporary
## project configuration with a unique custom user-data name before Godot starts.

const ISOLATED_ENV := "PROTO_TD_TEST_ISOLATED"
const RUN_ID_ENV := "PROTO_TD_TEST_RUN_ID"
const USER_DIR_PREFIX := "GameTemplateTDTests-"
const REFUSAL_EXIT_CODE := 78
const REFUSAL_MARKER := "TEST_USER_DATA_ISOLATION_REQUIRED"

var _emergency_user_dir := ""
var _managed_user_dir := ""


func _enter_tree() -> void:
	var managed_root := _managed_verifier_root()
	var managed_boot := not managed_root.is_empty() and _is_verifier_boot(managed_root)
	if not (is_test_invocation() or managed_boot) or isolated_test_user_data_active():
		return
	if _verifier_requires_custom_user_dir(OS.get_name()) and not managed_root.is_empty():
		# macOS and Windows ignore XDG_DATA_HOME. Redirect before later autoloads access saves,
		# including when the verifier uses immutable project settings from a PCK.
		var name := _verifier_user_dir_name(managed_root)
		ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
		ProjectSettings.set_setting("application/config/custom_user_dir_name", name)
		var user_dir := OS.get_user_data_dir()
		if user_dir.replace("\\", "/").get_file() == name and not DirAccess.dir_exists_absolute(user_dir) and DirAccess.make_dir_recursive_absolute(user_dir) == OK:
			_managed_user_dir = user_dir
			return
	_emergency_user_dir = _redirect_unisolated_test_user_data()
	push_error((
		"%s: run repository tests through tools/run_godot_test.sh or "
		+ "tools/run_godot_isolated.sh; refusing shared production user:// access."
	) % REFUSAL_MARKER)
	get_tree().quit(REFUSAL_EXIT_CODE)


func _exit_tree() -> void:
	if not _managed_user_dir.is_empty() and _managed_user_dir.replace("\\", "/").get_file().begins_with(USER_DIR_PREFIX + "verify-"):
		_remove_tree(_managed_user_dir)
	if (
		not _emergency_user_dir.is_empty()
		and _emergency_user_dir.replace("\\", "/").get_file().begins_with(
			USER_DIR_PREFIX + "refused-",
		)
	):
		_remove_tree(_emergency_user_dir)


static func _redirect_unisolated_test_user_data() -> String:
	# SceneTree test bodies in this repository defer their work until after
	# autoload creation. Redirect immediately so even the final message-queue
	# flush performed by quit() cannot expose the playable user:// directory.
	var emergency_name := "%srefused-%d-%d" % [
		USER_DIR_PREFIX, OS.get_process_id(), Time.get_ticks_msec(),
	]
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting(
		"application/config/custom_user_dir_name", emergency_name,
	)
	return OS.get_user_data_dir()


static func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child_path := path.path_join(entry)
			if directory.is_link(entry):
				DirAccess.remove_absolute(child_path)
			elif directory.current_is_dir():
				_remove_tree(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)


static func is_test_invocation() -> bool:
	for raw_arg: String in OS.get_cmdline_args():
		var arg := raw_arg.replace("\\", "/")
		for prefix: String in ["--script=", "-s=", "-gtest="]:
			if arg.begins_with(prefix):
				arg = arg.trim_prefix(prefix)
				break
		if _is_test_target(arg):
			return true
	return false


static func isolated_test_user_data_active() -> bool:
	# GameDev verification creates a fresh private XDG data/config root, including
	# for a release PCK whose immutable project settings cannot be rewritten.
	if _managed_verifier_data_isolated() or _custom_verifier_data_isolated():
		return true
	if OS.get_environment(ISOLATED_ENV) != "1":
		return false
	var run_id := OS.get_environment(RUN_ID_ENV)
	if not _valid_run_id(run_id):
		return false
	if not bool(ProjectSettings.get_setting(
		"application/config/use_custom_user_dir", false,
	)):
		return false
	var expected_name := USER_DIR_PREFIX + run_id
	if String(ProjectSettings.get_setting(
		"application/config/custom_user_dir_name", "",
	)) != expected_name:
		return false
	return OS.get_user_data_dir().replace("\\", "/").get_file() == expected_name


static func _managed_verifier_data_isolated() -> bool:
	if OS.get_name() != "Linux":
		return false
	var run_root := _managed_verifier_root()
	if run_root.is_empty():
		return false
	# A matching environment name alone is insufficient: the engine's resolved
	# user:// directory must actually be contained in that temporary data root.
	return _verifier_user_data_contained(run_root.path_join("data"), OS.get_user_data_dir())


static func _verifier_requires_custom_user_dir(platform: String) -> bool:
	return platform in ["macOS", "Windows"]


static func _verifier_user_dir_name(run_root: String) -> String:
	if run_root.is_empty():
		return ""
	return "%sverify-%s-%d" % [USER_DIR_PREFIX, run_root.get_file(), OS.get_process_id()]


static func _custom_verifier_data_isolated() -> bool:
	if not _verifier_requires_custom_user_dir(OS.get_name()):
		return false
	var expected_name := _verifier_user_dir_name(_managed_verifier_root())
	if expected_name.is_empty():
		return false
	var user_dir := OS.get_user_data_dir().replace("\\", "/")
	var parent := DirAccess.open(user_dir.get_base_dir())
	return (
		bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false))
		and String(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")) == expected_name
		and user_dir.get_file() == expected_name
		and DirAccess.dir_exists_absolute(user_dir)
		and parent != null and not parent.is_link(expected_name)
	)


static func _verifier_root_from_paths(data_path: String, config_path: String) -> String:
	# Node's tmpdir() may be on any volume or a custom TMPDIR. Validate the
	# private verifier layout, not a hardcoded operating-system temp location.
	var data_root := data_path.replace("\\", "/").simplify_path().trim_suffix("/")
	var config_root := config_path.replace("\\", "/").simplify_path().trim_suffix("/")
	if not data_root.is_absolute_path() or data_root.get_file() != "data":
		return ""
	if data_root.contains("://") or config_root.contains("://"):
		return ""
	var run_root := data_root.get_base_dir()
	if not run_root.get_file().begins_with("manus-game-verify-") or run_root.get_file().length() <= "manus-game-verify-".length() or not _valid_run_id(run_root.get_file()):
		return ""
	if config_root != run_root.path_join("config"):
		return ""
	return run_root


static func _verifier_user_data_contained(data_root: String, user_dir: String) -> bool:
	var data_path := data_root.replace("\\", "/").simplify_path().trim_suffix("/")
	var user_path := user_dir.replace("\\", "/").simplify_path()
	return data_path.is_absolute_path() and user_path.begins_with(data_path + "/")


static func _managed_verifier_root() -> String:
	var run_root := _verifier_root_from_paths(OS.get_environment("XDG_DATA_HOME"), OS.get_environment("XDG_CONFIG_HOME"))
	if run_root.is_empty():
		return ""
	var parent := DirAccess.open(run_root.get_base_dir())
	var directory := DirAccess.open(run_root)
	if parent == null or directory == null or parent.is_link(run_root.get_file()) or directory.is_link("data") or directory.is_link("config"):
		return ""
	return run_root


static func _is_verifier_boot(run_root: String) -> bool:
	for raw_arg: String in OS.get_cmdline_args():
		var arg := raw_arg.replace("\\", "/").trim_prefix("--script=").trim_prefix("-s=")
		if arg.simplify_path() == run_root.path_join("font_binding_boot.gd"):
			return true
	return false


static func _is_test_target(arg: String) -> bool:
	var normalized := arg.trim_prefix("./")
	if not (
		normalized.ends_with(".gd")
		or normalized.ends_with(".tscn")
		or normalized.ends_with(".scn")
	):
		return false
	return (
		normalized.begins_with("res://tests/")
		or normalized.begins_with("res://test/")
		or normalized.begins_with("tests/")
		or normalized.begins_with("test/")
		or normalized.contains("/tests/")
		or normalized.contains("/test/")
	)


static func _valid_run_id(value: String) -> bool:
	if value.is_empty() or value.length() > 96:
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-":
			return false
	return true
