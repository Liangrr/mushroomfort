extends SceneTree

const Guard := preload("res://autoloads/test_run_guard.gd")
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for base: String in ["/tmp/manus-game-verify-abc123", "/var/tmp/manus-game-verify-abc123", "/srv/custom-cache/manus-game-verify-abc123", "/Volumes/Build Temp/manus-game-verify-abc123", "C:/Users/Tester/AppData/Local/Temp/manus-game-verify-abc123", "D:/Custom Temp/manus-game-verify-abc123"]:
		check(Guard._verifier_root_from_paths(base + "/data", base + "/config") == base, "Paired private verifier paths accepted: " + base)
	check(Guard._verifier_root_from_paths("C:\\Custom Temp\\manus-game-verify-abc123\\data", "C:\\Custom Temp\\manus-game-verify-abc123\\config") == "C:/Custom Temp/manus-game-verify-abc123", "Windows native separators normalize")
	for pair: Array in [["", ""], ["relative/manus-game-verify-abc/data", "relative/manus-game-verify-abc/config"], ["/tmp/ordinary-project/data", "/tmp/ordinary-project/config"], ["/tmp/manus-game-verify-/data", "/tmp/manus-game-verify-/config"], ["/tmp/manus-game-verify-a/data", "/tmp/manus-game-verify-b/config"], ["/tmp/manus-game-verify-a/data", "/tmp/manus-game-verify-a/data"], ["res://manus-game-verify-a/data", "res://manus-game-verify-a/config"]]:
		check(Guard._verifier_root_from_paths(pair[0], pair[1]).is_empty(), "Malformed or shared verifier paths rejected")
	check(Guard._verifier_requires_custom_user_dir("Windows") and Guard._verifier_requires_custom_user_dir("macOS"), "Non-XDG desktop platforms use a private custom directory")
	check(not Guard._verifier_requires_custom_user_dir("Linux"), "Linux honors its actual XDG user directory")
	for pair: Array in [["/srv/tmp/manus-game-verify-a/data", "/srv/tmp/manus-game-verify-a/data/app_userdata/game"], ["C:/Temp/manus-game-verify-a/data", "C:/Temp/manus-game-verify-a/data/game"]]:
		check(Guard._verifier_user_data_contained(pair[0], pair[1]), "Resolved user directory is inside the verified data root")
	for user: String in ["/srv/tmp/manus-game-verify-a/data-escape/game", "/srv/tmp/manus-game-verify-a/data/../shared/game", "/Users/player/Library/Application Support/Fablewood"]:
		check(not Guard._verifier_user_data_contained("/srv/tmp/manus-game-verify-a/data", user), "Outside user directory cannot claim verifier isolation")
	check(Guard.isolated_test_user_data_active(), "This test itself uses confirmed isolated user data")
	var previous_data := OS.get_environment("XDG_DATA_HOME")
	var previous_config := OS.get_environment("XDG_CONFIG_HOME")
	var base := ProjectSettings.globalize_path("user://custom-temp/manus-game-verify-contract")
	check(DirAccess.make_dir_recursive_absolute(base.path_join("data")) == OK and DirAccess.make_dir_recursive_absolute(base.path_join("config")) == OK, "Private filesystem fixture created")
	OS.set_environment("XDG_DATA_HOME", base.path_join("data"))
	OS.set_environment("XDG_CONFIG_HOME", base.path_join("config"))
	check(Guard._managed_verifier_root() == base, "Filesystem verifier accepts a nonstandard temp parent")
	OS.set_environment("XDG_CONFIG_HOME", base.path_join("other"))
	check(Guard._managed_verifier_root().is_empty(), "Filesystem verifier rejects mismatched config root")
	OS.set_environment("XDG_DATA_HOME", previous_data)
	OS.set_environment("XDG_CONFIG_HOME", previous_config)
	print("FABLEWOOD_TEST_RUN_GUARD_CONTRACT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
