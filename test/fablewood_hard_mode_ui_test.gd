extends Node

const ScreenType := preload("res://scripts/fablewood/screen.gd")
const ModelType := preload("res://sim/fablewood_battle.gd")
const SETTINGS_PATH := "user://fablewood_hard_mode_ui_test.cfg"

var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	get_window().size = Vector2i(1440, 900)
	get_window().content_scale_size = Vector2i(1440, 900)
	var i18n := get_node_or_null("/root/I18n")
	_check(i18n != null and bool(i18n.call("reload_catalogs")), "localization catalogs did not load")
	if i18n == null:
		_finish()
		return
	_check(bool(i18n.call("set_locale", &"en-US")), "English locale did not activate")
	Game._reset_campaign_runtime()
	Leaderboard.configure_for_testing("user://fablewood_hard_mode_ui_scores.json", "")
	Leaderboard.clear_for_testing()
	await _test_title_preference_and_layout()
	await _test_battle_configuration_and_schedule()
	await _test_score_separation()
	await _test_result_metadata_badge()
	await _test_chinese_copy_and_font(i18n)
	_finish()

func _test_title_preference_and_layout() -> void:
	var title := await _make_screen("title")
	_check(title != null, "title screen did not instantiate")
	if title == null:
		return
	var toggle := title.find_child("HardModeToggle", true, false) as CheckButton
	var badge := title.find_child("TitleModeBadge", true, false) as PanelContainer
	var hint := title.find_child("HardModeHint", true, false) as Label
	_check(toggle != null and not toggle.button_pressed, "Hard Mode does not default OFF")
	_check(badge != null and _badge_copy(badge) == "NORMAL", "title does not show a Normal badge by default")
	_check(hint != null and hint.text.contains("+50% HP") and hint.text.contains("faster"), "English hard-mode hint is not concise and factual")
	_check(toggle != null and toggle.tooltip_text.contains("25% closer") and toggle.tooltip_text.contains("round up"), "Hard Mode tooltip omits precise spawn details")
	if toggle != null:
		toggle.button_pressed = true
		await _frames(3)
	_check(title._hard_mode, "Hard Mode toggle did not update the selected preference")
	var saved := ConfigFile.new()
	_check(saved.load(SETTINGS_PATH) == OK and bool(saved.get_value("settings", "hard_mode", false)), "Hard Mode selection was not durably saved")
	var rebuilt_badge := title.find_child("TitleModeBadge", true, false) as PanelContainer
	_check(rebuilt_badge != null and _badge_copy(rebuilt_badge) == "HARD", "title did not refresh its Hard badge after toggle")
	_check(_all_controls_within(title.canvas, Rect2(Vector2.ZERO, title._logical)), "title controls escape the logical canvas in landscape")
	get_window().size = Vector2i(720, 1100)
	get_window().content_scale_size = Vector2i(720, 1100)
	await _frames(4)
	_check(_all_controls_within(title.canvas, Rect2(Vector2.ZERO, title._logical)), "title controls escape the logical canvas in portrait")
	title.queue_free()
	await _frames(2)
	var restored := await _make_screen("title")
	_check(restored._hard_mode, "saved Hard preference did not survive screen recreation")
	restored.queue_free()
	await _frames(2)

func _test_battle_configuration_and_schedule() -> void:
	var battle := await _make_screen("battle", true, &"s2")
	_check(battle != null and battle.startup_succeeded, "Hard Mode battle screen did not start")
	if battle == null:
		return
	var model := battle.model as FablewoodBattle
	_check(model != null and bool(model.get("hard_mode")), "screen did not configure Hard Mode during model startup")
	var badge := battle.find_child("BattleModeBadge", true, false) as PanelContainer
	_check(badge != null and _badge_copy(badge) == "HARD", "battle status does not expose current Hard mode")
	_check(badge != null and badge.tooltip_text.contains("+50% HP"), "battle badge does not disclose mode values")
	# Chapter 1 has no late enemies. Use Chapter 2's first authored late wave,
	# with the screen paused so the fixture does not bypass four live waves.
	battle.paused = true
	var late_wave := 0
	for wave: int in range(1, 9):
		if _late_schedule_count(model, wave) > 0:
			late_wave = wave
			break
	_check(late_wave == 5, "Chapter 2 first late-enemy wave changed; update this concrete fixture")
	model.wave = late_wave - 1
	var expected := _late_schedule_count(model, late_wave)
	var normal := _make_model(&"s2", false)
	var authored := _late_schedule_count(normal, late_wave)
	_check(expected == authored + ceili(float(authored) / 3.0), "Hard schedule does not include its authored reinforcements")
	_check(battle._next_wave_late_threats().size() == expected, "next-wave warning does not read the model schedule including reinforcements")
	battle._show_threats()
	await _frames(2)
	var weakness := battle.find_child("HardModeWeaknessFeedback", true, false) as Label
	_check(weakness != null and weakness.text.contains("Earth") and weakness.text.contains("Frost") and weakness.text.contains("Fire"), "Hard Mode guide omits weakness feedback")
	var portraits := battle.find_children("", "TextureRect", true, false)
	var guide_portrait := false
	for node: Node in portraits:
		var image := node as TextureRect
		if image != null and image.texture != null and image.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			guide_portrait = true
	_check(guide_portrait, "late-enemy guide portraits are not mipmapped linear for smooth sharp scaling")
	battle.queue_free()
	await _frames(2)

func _test_score_separation() -> void:
	var title := await _make_screen("title", true)
	_check(title != null, "score fixture title did not instantiate")
	if title == null:
		return
	var leaderboard := get_node_or_null("/root/Leaderboard")
	_check(leaderboard != null and leaderboard.has_method(&"local_entries_for_mode"), "mode-filtered score API is unavailable")
	if leaderboard != null and leaderboard.has_method(&"local_entries_for_mode"):
		leaderboard.call("clear_for_testing")
		_check(not leaderboard.call("record_mission", _sealed_result(_make_model(&"s1", false))).is_empty(), "sealed Normal result did not save")
		_check(not leaderboard.call("record_mission", _sealed_result(_make_model(&"s2", true))).is_empty(), "sealed Hard result did not save")
		title._scores_group = "normal"
		title._show_scores()
		await _frames(2)
		_check(_descendant_text(title.overlay).contains(title.trf("scores_group_normal")), "Normal score tab does not identify its comparison group")
		_check(_descendant_text(title.overlay).contains("The Inkspill"), "Normal score tab does not show its actual Normal record")
		_check(not _descendant_text(title.overlay).contains("The Hollow Stacks"), "Normal score tab silently includes a Hard score")
		var hard_tab := title.find_child("ScoresHardTab", true, false) as Button
		_check(hard_tab != null and hard_tab.text == title.trf("ranking_hard"), "Hard score tab does not expose its localized group")
		if hard_tab != null:
			hard_tab.pressed.emit()
			await _frames(2)
		_check(_descendant_text(title.overlay).contains(title.trf("scores_group_hard")), "Hard score tab did not select its comparison group")
		_check(_descendant_text(title.overlay).contains("The Hollow Stacks") and not _descendant_text(title.overlay).contains("The Inkspill"), "Hard score tab does not use filtered mode-only entries")
		for group: String in ["practice", "legacy"]:
			var tab := title.find_child("Scores" + group.capitalize() + "Tab", true, false) as Button
			_check(tab != null and tab.text == title.trf("ranking_" + group), "non-comparable history group remains reachable")
		leaderboard.call("clear_for_testing")
	title.queue_free()
	await _frames(2)

func _test_result_metadata_badge() -> void:
	var game := get_node_or_null("/root/Game")
	_check(game != null, "Game autoload is unavailable for result badge fixture")
	if game == null:
		return
	game._reset_campaign_runtime()
	var model := _make_model(&"s1", true)
	_sealed_result(model)
	game.current_battle = model
	_check(game.record_result(model.result, model.stars), "real Hard terminal result did not finalize")
	# A later preference change must never relabel an already sealed result.
	var result := await _make_screen("results", false)
	var badge := result.find_child("ResultModeBadge", true, false) as PanelContainer if result != null else null
	_check(badge != null and _badge_copy(badge) == "HARD" and not result._hard_mode, "result did not preserve actual attempt mode independently from current preference")
	if result != null:
		result.queue_free()
	await _frames(2)

func _test_chinese_copy_and_font(i18n: Node) -> void:
	_check(bool(i18n.call("set_locale", &"zh-CN")), "Chinese locale did not activate")
	var title := await _make_screen("title", true)
	_check(title != null, "Chinese title did not instantiate")
	if title != null:
		var toggle := title.find_child("HardModeToggle", true, false) as CheckButton
		var badge := title.find_child("TitleModeBadge", true, false) as PanelContainer
		_check(toggle != null and toggle.text == "困难模式", "Hard Mode toggle did not localize to Chinese")
		_check(badge != null and _badge_copy(badge) == "困难", "Chinese title does not show Hard badge")
		_check(toggle != null and toggle.get_theme_font(&"font").has_char("困".unicode_at(0)), "title font lacks the Hard Mode Chinese glyph")
		_check(_all_controls_within(title.canvas, Rect2(Vector2.ZERO, title._logical)), "Chinese portrait title overflows logical canvas")
		title.queue_free()
	_check(bool(i18n.call("set_locale", &"en-US")), "English locale was not restored")
	await _frames(2)

func _make_screen(screen_mode: String, hard: Variant = null, stage_id: StringName = &"s1") -> Control:
	# _ready owns loading persisted preferences; setting the instance member
	# before add_child would be overwritten and would not test the real route.
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)
	if hard is bool:
		settings.set_value("settings", "hard_mode", hard)
	settings.set_value("settings", "locale", String(I18n.locale()))
	settings.set_value("settings", "tutorial_version", 1)
	settings.set_value("settings", "tutorial_status", "skipped")
	_check(settings.save(SETTINGS_PATH) == OK, "fixture preferences could not be persisted")
	var screen := ScreenType.new() as Control
	screen.mode = screen_mode
	screen._settings_file = SETTINGS_PATH
	if screen_mode == "battle":
		var game := get_node_or_null("/root/Game")
		if game == null:
			return null
		game._reset_campaign_runtime()
		game.set("pending_stage", load("res://data/stages/%s.tres" % stage_id))
	get_tree().root.add_child(screen)
	await _frames(3)
	return screen

func _make_model(stage_id: StringName, hard: bool) -> FablewoodBattle:
	var ids: Array[StringName] = [&"caster_1", &"sniper_1", &"recruit", &"guard_1"]
	var model := ModelType.create_fablewood(load("res://data/stages/%s.tres" % stage_id), {"input": ids, "trusted_ticket_hashes": [], "fixed_operator_ids": ids}, 42)
	_check(model != null and model.configure_hard_mode(hard), "fixture model could not set actual difficulty")
	_check(model.apply_run_metadata({"tuning_ranked_eligible": true, "tuning_config_hash": "baseline".sha256_text(), "tuning_reasons": []}), "fixture model rejected baseline provenance")
	return model

func _sealed_result(model: FablewoodBattle) -> Dictionary:
	_check(model.apply_action([&"resign"]), "fixture did not reach a real terminal outcome")
	var result := {"stage_id": model.stage.id, "result": model.result, "stars": model.stars, "kills": model.killed, "leaks": model.leaked}
	result.merge(model.result_metadata(), true)
	return result

func _late_schedule_count(model: FablewoodBattle, wave: int) -> int:
	var count := 0
	if model == null or not model.has_method(&"get_wave_schedule"):
		return count
	var schedule: Array = model.call(&"get_wave_schedule", wave)
	for raw: Variant in schedule:
		if raw is Dictionary and StringName((raw as Dictionary).get("enemy_id", &"")) in [&"prismback", &"harrier", &"broodmother"]:
			count += 1
	return count

func _badge_copy(badge: PanelContainer) -> String:
	if badge == null:
		return ""
	var copy := badge.get_child(0) as Label
	return copy.text if copy != null else ""

func _all_controls_within(host: Control, bounds: Rect2) -> bool:
	if host == null:
		return false
	for node: Node in host.find_children("", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		# Scroll content is deliberately clipped and can exceed its viewport.
		# Check the viewport's actual canvas-space bounds, not nested local offsets.
		var parent := control.get_parent()
		var clipped := false
		while parent != host and parent != null:
			if parent is ScrollContainer:
				clipped = true
				break
			parent = parent.get_parent()
		if clipped:
			continue
		var transform := host.get_global_transform().affine_inverse() * control.get_global_transform()
		var rect := transform * Rect2(Vector2.ZERO, control.size)
		if control == host or control.size.is_zero_approx():
			continue
		if not bounds.encloses(rect):
			return false
	return true

func _descendant_text(node: Node) -> String:
	var out := ""
	if node == null:
		return out
	for label: Node in node.find_children("", "Label", true, false):
		out += (label as Label).text + "\n"
	return out

func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	if _failures.is_empty():
		print("FABLEWOOD_HARD_MODE_UI_TEST_OK checks=", _checks)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)
