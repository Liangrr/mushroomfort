extends SceneTree
const Runner = preload("fablewood_suite_runner.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ok := Runner.run(get_script().resource_path, [
		{"path": "fablewood_browser_music_marker_test.gd", "expect": "BROWSER_MUSIC_MARKER_PASS"},
		{"path": "fablewood_tuning_contract.gd", "expect": "FABLEWOOD_TUNING_CONTRACT_PASS"},
		{"path": "fablewood_audio_filter_contract.gd", "expect": "FABLEWOOD_AUDIO_FILTER_CONTRACT failures=0"},
		{"path": "fablewood_ui_contract.tscn", "expect": "FABLEWOOD_UI_CONTRACT failures=0"},
		{"path": "fablewood_world_input_test.gd", "expect": "FABLEWOOD_WORLD_INPUT failures=0"},
		{"path": "fablewood_test_run_guard_contract.gd", "expect": "FABLEWOOD_TEST_RUN_GUARD_CONTRACT"},
		{"path": "fablewood_hard_mode_ui_test.tscn", "expect": "FABLEWOOD_HARD_MODE_UI_TEST_OK"},
		{"path": "fablewood_build_placement_test.tscn", "expect": "FABLEWOOD_BUILD_PLACEMENT_PASS"},
		{"path": "fablewood_chapter3_regression.gd", "expect": "FABLEWOOD_CHAPTER3_EARNED_GOLD_PASS"},
	])
	if ok: print("FABLEWOOD_SOURCE_CONTRACT_SUITE_PASS")
	quit(0 if ok else 1)
