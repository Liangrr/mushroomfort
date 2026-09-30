extends SceneTree
## Active Fablewood tuning contract. Run through the isolated source verifier.
const Catalog = preload("res://scripts/fablewood/tuning_catalog.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("TUNING_CONTRACT: " + message)

func settle(count: int = 3) -> void:
	for _frame: int in count:
		await process_frame

func test_catalog() -> void:
	var catalog := Catalog.new()
	expect(catalog.descriptors.size() == 15, "The existing 15 controls are preserved")
	var categories: Dictionary = {}
	for item: RefCounted in catalog.descriptors:
		categories[item.category] = true
		expect(catalog.validate(item.id, item.default_value).ok, "Valid default: " + String(item.id))
		expect(not catalog.validate(item.id, item.minimum - 1).ok and not catalog.validate(item.id, item.maximum + 1).ok, "Bounds: " + String(item.id))
		for bad: Variant in [NAN, INF, -INF, "1", true, null, Vector2.ZERO]:
			expect(not catalog.validate(item.id, bad).ok, "Reject malformed input: " + String(item.id))
	expect(categories.size() == 6, "All six categories are represented")
	expect(not catalog.validate(&"retired.control", 1.0).ok, "Unknown direct edits are rejected")
	expect(not catalog.validate(&"player.range_bonus", 0.49).ok, "Integer controls reject off-step values")
	expect(not catalog.validate(&"player.attack_multiplier", 1.26).ok, "Fractional controls reject off-step values")
	var canonical: Dictionary = catalog.validate(&"player.range_bonus", 1.0)
	expect(canonical.ok and typeof(canonical.value) == TYPE_INT, "Integer controls retain their typed value")
	var patch: Dictionary = catalog.validate_patch({"player.attack_multiplier": 1.5, "player.range_bonus": NAN})
	expect(not patch.ok and patch.values.is_empty(), "One malformed known value rejects the complete patch")
	patch = catalog.validate_patch({"retired.control": 1.0, "player.attack_multiplier": 1.5})
	expect(not patch.ok and patch.values.is_empty(), "Unknown controls reject the complete patch")

func test_service(t: Node) -> void:
	t.reset_all()
	t.acknowledge_action(&"audio.sfx_pitch")
	t.begin_stage()
	var baseline: Dictionary = t.run_metadata()
	expect(baseline.tuning_ranked_eligible and baseline.tuning_reasons.is_empty(), "Baseline stage is eligible")
	expect(t.set_value(&"player.attack_multiplier", 1.5), "Pending edit accepted")
	expect(t.requested_value(&"player.attack_multiplier") == 1.5 and t.value(&"player.attack_multiplier") == 1.0, "NEXT_STAGE separates requested and consumed values")
	expect(t.run_metadata() == baseline, "Pending gameplay edit cannot taint the current run")
	t.begin_stage()
	var applied: Dictionary = t.run_metadata()
	expect(t.value(&"player.attack_multiplier") == 1.5 and not applied.tuning_ranked_eligible, "New stage consumes and records gameplay edit")
	expect(applied.tuning_config_hash != baseline.tuning_config_hash and applied.tuning_reasons == ["player.attack_multiplier"], "Applied provenance identifies the consumed configuration")
	t.reset_value(&"player.attack_multiplier")
	expect(t.requested_value(&"player.attack_multiplier") == 1.0 and t.value(&"player.attack_multiplier") == 1.5, "Reset changes draft while preserving stage snapshot")
	expect(t.run_metadata() == applied, "Reset cannot erase applied-run provenance")
	applied.tuning_reasons.clear()
	expect(not t.run_metadata().tuning_reasons.is_empty(), "Returned provenance cannot mutate the service snapshot")
	t.begin_stage()
	t.set_value(&"player.visual_scale", 1.2)
	t.set_value(&"enemies.visual_scale", 1.1)
	t.set_value(&"environment.effect_opacity", 0.6)
	expect(t.value(&"player.visual_scale") == 1.2 and t.active_value(&"player.visual_scale") == 1.2, "LIVE values apply immediately")
	expect(t.run_metadata() == baseline, "Cosmetic live changes preserve eligibility and gameplay hash")
	t.set_value(&"audio.sfx_pitch", 1.1)
	expect(is_equal_approx(t.value(&"audio.sfx_pitch"), 1.1) and t.active_value(&"audio.sfx_pitch") == 1.0, "NEXT_ACTION exposes requested value without claiming application")
	expect(t.acknowledge_action(&"audio.sfx_pitch") and is_equal_approx(t.active_value(&"audio.sfx_pitch"), 1.1), "An actual cue acknowledgement updates active pitch")
	expect(not t.acknowledge_action(&"player.attack_multiplier"), "Action acknowledgement cannot apply stage controls")
	for id: StringName in [&"ui.text_scale", &"environment.zoom", &"audio.music_pitch_multiplier"]:
		t.set_value(id, 1.1)
		expect(t.value(id) == 1.0 and t.active_value(id) == 1.0, "Cosmetic stage value remains frozen: " + String(id))
	t.begin_stage()
	expect(is_equal_approx(t.value(&"ui.text_scale"), 1.1) and is_equal_approx(t.value(&"environment.zoom"), 1.1) and is_equal_approx(t.value(&"audio.music_pitch_multiplier"), 1.1), "Cosmetic stage controls apply at the declared boundary")
	expect(t.run_metadata() == baseline, "Cosmetic stage changes preserve baseline eligibility")
	var before: Dictionary = t.delta_values()
	expect(not t.set_value(&"player.attack_multiplier", NAN) and t.delta_values() == before, "Service rejects invalid values without draft mutation")
	t.reset_all()
	t.begin_stage()

func combat_sample(model: RefCounted) -> Dictionary:
	var sample: Dictionary = {"gold": model.dp, "health": model.base_hp}
	expect(model.apply_action([&"deploy", &"caster_1", Vector2i(4, 3), 0]), "Actual deployment accepts the legal root socket")
	var unit: RefCounted = model.units[-1]
	sample.merge({"attack": unit.atk, "interval": unit.atk_interval_ticks, "range": model.range_for(unit)})
	model.wave = 1
	model._spawn({"enemy_id": &"goblin", "path_idx": 0})
	var enemy: RefCounted = model.enemies[-1]
	sample.merge({"enemy_hp": enemy.hp, "enemy_step": enemy.step_units})
	var earned_before: int = model.earned
	model._damage_enemy(enemy, 99999, 1)
	sample["reward"] = model.earned - earned_before
	return sample

func test_stage_consumers(t: Node) -> void:
	var game: Node = root.get_node("Game")
	var i18n: Node = root.get_node("I18n")
	t.reset_all()
	game.start_battle(&"s1")
	await settle(12)
	var screen: Control = game.content
	if screen._tutorial_active:
		screen._skip_tutorial()
	var baseline_model: RefCounted = screen.model
	var baseline: Dictionary = combat_sample(baseline_model)
	var changes: Dictionary = {
		&"gameplay.start_gold": 450, &"gameplay.town_health": 15,
		&"gameplay.reward_scale": 2.0, &"player.attack_multiplier": 1.5,
		&"player.attack_speed_multiplier": 2.0, &"player.range_bonus": 1,
		&"enemies.health_multiplier": 1.4, &"enemies.movement_speed_multiplier": 1.2,
		&"ui.text_scale": 1.1, &"environment.zoom": 1.1,
	}
	for id: StringName in changes:
		expect(t.set_value(id, changes[id]), "Accept draft stage consumer: " + String(id))
	i18n.set_locale(&"zh-CN")
	root.size = Vector2i(720, 1100)
	root.content_scale_size = root.size
	await settle(8)
	expect(screen.model == baseline_model and screen.model.damage_scale == 1.0 and screen.model.difficulty == 1.0, "Locale/orientation rebuild does not reapply pending gameplay")
	expect(t.value(&"ui.text_scale") == 1.0 and screen.world.zoom == 1.0, "Locale/orientation rebuild retains active text and initial zoom")
	expect(t.run_metadata().tuning_ranked_eligible, "Pending edits leave the actual battle eligible")
	game.start_battle(&"s1")
	await settle(12)
	screen = game.content
	if screen._tutorial_active:
		screen._skip_tutorial()
	var tuned_model: RefCounted = screen.model
	var tuned: Dictionary = combat_sample(tuned_model)
	expect(tuned.gold == 450 and tuned.health == 15, "New battle consumes requested starting gold and health")
	expect(tuned.attack == roundi(baseline.attack * 1.5), "Deployment consumes applied attack multiplier")
	expect(tuned.interval == maxi(6, roundi(baseline.interval / 2.0)), "Deployment consumes applied attack speed")
	expect(tuned.range == baseline.range + 1, "Actual guardian range consumes applied range bonus")
	expect(tuned.enemy_hp == ceili(baseline.enemy_hp * 1.4), "Actual spawn consumes applied enemy health")
	expect(tuned.enemy_step == maxi(1, roundi(baseline.enemy_step * 1.2)), "Actual spawn consumes applied enemy speed")
	expect(tuned.reward == baseline.reward * 2, "Actual defeat reward consumes applied gold scaling")
	expect(is_equal_approx(screen.world.zoom, 1.1) and is_equal_approx(t.value(&"ui.text_scale"), 1.1), "New battle consumes pending cosmetic stage values")
	expect(not tuned_model._run_metadata.tuning_ranked_eligible and tuned_model._run_metadata.tuning_reasons.size() == 8, "Actual model captures all eight applied gameplay deviations")
	var simulation_hash: int = tuned_model.state_hash()
	t.set_value(&"player.visual_scale", 1.2)
	t.set_value(&"enemies.visual_scale", 1.1)
	t.set_value(&"environment.effect_opacity", 0.6)
	expect(tuned_model.state_hash() == simulation_hash, "Live rendering controls cannot mutate combat authority")
	t.reset_all()
	expect(not tuned_model._run_metadata.tuning_ranked_eligible and tuned_model.damage_scale == 1.5, "Reset cannot rewrite a running model or its captured provenance")
	screen.queue_free()
	game.content = null
	game.current_battle = null
	await settle()
	t.begin_stage()

func test_bridge(t: Node) -> void:
	var bridge: Node = root.get_node("TuningBridge")
	var i18n: Node = root.get_node("I18n")
	t.reset_all()
	t.begin_stage()
	i18n.set_locale(&"en-US")
	var result: Dictionary = bridge.handle_request({"operation": "describe", "requestId": "describe-en"})
	expect(result.error.is_empty() and result.requestId == "describe-en", "Describe responds with the caller request identity")
	var state: Dictionary = result.state
	expect(state.controls.size() == 15 and state.requested.size() == 15 and state.active.size() == 15, "Host receives the complete 15-control contract")
	expect(state.schemaDigest.length() == 64 and not state.has("revision"), "Wire schema uses a content digest without a numeric revision")
	var categories: Dictionary = {}
	for control: Dictionary in state.controls:
		categories[control.category] = true
		expect(control.type == "number" and control.applyMode in ["LIVE", "NEXT_ACTION", "NEXT_STAGE"], "Typed honest host control: " + control.id)
		expect(not control.label.begins_with("tuning.") and not control.description.begins_with("tuning."), "Host control presentation is translated: " + control.id)
	expect(categories.size() == 6 and categories.has("Guardians"), "Six localized categories are exposed")
	i18n.set_locale(&"zh-CN")
	var localized: Dictionary = bridge.handle_request({"operation": "describe"}).state
	expect(localized.schemaDigest == state.schemaDigest and localized.controls[0].label != state.controls[0].label, "Locale changes presentation without invalidating schema")
	var request: Dictionary = {"operation": "apply", "requestId": "apply", "schemaDigest": state.schemaDigest, "patch": {"player.attack_multiplier": 1.5}}
	bridge.handle_request({"operation": "disconnect"})
	expect(bridge.handle_request(request).error == "unavailable" and t.delta_values().is_empty(), "Disconnected Apply is rejected without changes")
	expect(bridge.handle_request({"operation": "connect", "requestId": "connect"}).error.is_empty(), "Host connection obtains an editing lease")
	var invalid := request.duplicate(true)
	invalid.schemaDigest = "stale"
	expect(bridge.handle_request(invalid).error == "invalid" and t.delta_values().is_empty(), "Stale schemas cannot edit the preview")
	for bad: Variant in [NAN, INF, "1.5", 1.26, 1000, null]:
		invalid = request.duplicate(true)
		invalid.patch = {"player.attack_multiplier": 1.5, "gameplay.reward_scale": bad}
		expect(bridge.handle_request(invalid).error == "invalid" and t.delta_values().is_empty(), "Invalid multi-control patches are atomic")
	invalid = request.duplicate(true)
	invalid.patch = {"unknown": 1.0, "player.attack_multiplier": 1.5}
	expect(bridge.handle_request(invalid).error == "invalid", "Unknown wire IDs reject the complete patch")
	invalid.patch = {1: 1.0}
	expect(bridge.handle_request(invalid).error == "invalid", "Non-string wire IDs are rejected")
	invalid.patch = []
	expect(bridge.handle_request(invalid).error == "invalid", "Non-dictionary wire patches are rejected")
	var events: Array[Dictionary] = []
	var observe: Callable = func(id: StringName, requested: Variant, active: Variant):
		events.append({"id": id, "requested": requested, "active": active, "other": t.requested_value(&"player.visual_scale")})
	t.value_changed.connect(observe)
	request.patch["player.visual_scale"] = 1.2
	result = bridge.handle_request(request)
	expect(result.error.is_empty() and result.state.requested["player.attack_multiplier"] == 1.5 and result.state.active["player.attack_multiplier"] == 1.0, "Apply exposes pending stage values")
	expect(result.state.active["player.visual_scale"] == 1.2, "Apply commits live presentation values")
	expect(events.size() == 2 and events[0].other == 1.2 and events[1].other == 1.2, "All values commit before change observers run")
	bridge.handle_request(request)
	expect(events.size() == 2, "An unchanged Apply emits no value changes")
	var rejected: Dictionary = t.apply_preview_patch({&"player.attack_multiplier": 1.8, &"gameplay.start_gold": NAN})
	expect(not rejected.ok and t.requested_value(&"player.attack_multiplier") == 1.5 and events.size() == 2, "Manager independently rejects a whole invalid transaction without notification")
	var oversized: Dictionary = {}
	for index: int in 129:
		oversized["control-%d" % index] = 1
	invalid = request.duplicate(true)
	invalid.patch = oversized
	expect(bridge.handle_request(invalid).error == "invalid" and not t.apply_preview_patch(oversized).ok, "Host and manager both bound the patch size")
	var read: Dictionary = bridge.handle_request({"operation": "read"})
	expect(read.state.requested == result.state.requested and read.error.is_empty(), "Read returns the manager state without an edit")
	# Editing/resetting Addon draft data does not call Apply and cannot affect
	# game state. The host owns that draft; the returned dictionary is detached.
	read.state.requested["player.attack_multiplier"] = 1.0
	expect(t.requested_value(&"player.attack_multiplier") == 1.5, "A host draft edit is not a game mutation")
	t.begin_stage()
	expect(not t.run_metadata().tuning_ranked_eligible and t.active_value(&"player.attack_multiplier") == 1.5, "Stage consumes applied host patch with sticky provenance")
	request.patch = {"player.attack_multiplier": 1.0, "player.visual_scale": 1.0}
	bridge.handle_request(request)
	expect(not t.run_metadata().tuning_ranked_eligible and t.active_value(&"player.attack_multiplier") == 1.5, "Applying a reset does not erase current-stage provenance")
	bridge._lease_until = 0
	request.patch = {"player.attack_multiplier": 1.4}
	expect(bridge.handle_request(request).error == "unavailable", "Expired leases reject edits")
	bridge.handle_request({"operation": "heartbeat"})
	expect(bridge.handle_request(request).error.is_empty(), "Heartbeat refreshes the active connection lease")
	bridge.handle_request({"operation": "disconnect"})
	expect(bridge.handle_request({"operation": "unknown"}).is_empty(), "Unsupported operations produce no response")
	t.value_changed.disconnect(observe)
	t.reset_all()
	t.begin_stage()
	# Old template-local drafts cannot affect a fresh production manager.
	var draft := ConfigFile.new()
	draft.set_value("meta", "schema", 1)
	draft.set_value("values", "player.attack_multiplier", 2.0)
	draft.save("user://fablewood_tuning.cfg")
	var saved := FileAccess.get_file_as_string("user://fablewood_tuning.cfg")
	var fresh: Node = t.get_script().new()
	root.add_child(fresh)
	expect(fresh.value(&"player.attack_multiplier") == 1.0 and fresh.delta_values().is_empty(), "Fresh manager ignores old local tuning files")
	fresh.set_value(&"player.attack_multiplier", 1.5)
	fresh.reset_all()
	expect(fresh.get_child_count() == 0 and not fresh.has_method("toggle") and not fresh.has_method("_input"), "Parameter manager creates no panel, launcher or shortcut")
	fresh.queue_free()
	await settle()
	expect(FileAccess.get_file_as_string("user://fablewood_tuning.cfg") == saved, "Preview edit/reset/teardown performs no tuning disk writes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://fablewood_tuning.cfg"))

func run() -> void:
	await settle()
	var tuning: Node = root.get_node("TweakControls")
	test_catalog()
	test_service(tuning)
	await test_stage_consumers(tuning)
	await test_bridge(tuning)
	root.get_node("Music").stop()
	root.get_node("Sfx").stop_all()
	await settle()
	if failures.is_empty():
		print("FABLEWOOD_TUNING_CONTRACT_PASS checks=%d" % checks)
	else:
		print("FABLEWOOD_TUNING_CONTRACT_FAIL ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
