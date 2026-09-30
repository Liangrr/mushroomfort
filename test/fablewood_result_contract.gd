extends SceneTree

const Model := preload("res://sim/fablewood_battle.gd")
const LaunchChecks := preload("fablewood_launch_checks.gd")
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func metadata(eligible: bool = true, reasons: Array = []) -> Dictionary:
	return {"tuning_ranked_eligible": eligible, "tuning_config_hash": ("baseline" if eligible else "modified").sha256_text(), "tuning_reasons": reasons}

func make(hard: bool = false) -> FablewoodBattle:
	var ids: Array[StringName] = [&"caster_1", &"sniper_1", &"recruit", &"guard_1"]
	var model := Model.create_fablewood(load("res://data/stages/s1.tres"), {"input": ids, "trusted_ticket_hashes": [], "fixed_operator_ids": ids}, 42)
	check(model.configure_hard_mode(hard), "mode configured before actions")
	check(model.apply_run_metadata(metadata()), "valid baseline provenance accepted")
	return model

func finish(model: FablewoodBattle) -> Dictionary:
	check(model.next_wave(), "wave starts")
	model.step(90)
	check(not model.configure_hard_mode(not model.hard_mode), "mode cannot change after run starts")
	check(model.apply_action([&"resign"]), "ordinary resign reaches terminal")
	var record := {"stage_id": model.stage.id, "result": model.result, "stars": model.stars, "kills": model.killed, "leaks": model.leaked}
	record.merge(model.result_metadata(), true)
	return record

func test_metadata(game: Node) -> void:
	var normal := make()
	var normal_result := finish(normal)
	check(normal_result.ranking_group == "normal" and not normal_result.hard_mode, "baseline Normal group")
	check(normal_result.terminal_tick == 90 and is_equal_approx(normal_result.duration_seconds, 3.0), "duration derives from actual terminal tick")
	var changed := make()
	changed.damage_scale = 2.0
	check(changed.apply_run_metadata(metadata(false, ["player.attack_multiplier"])), "applied gameplay deviation accepted")
	changed.damage_scale = 1.0
	check(changed.apply_run_metadata(metadata()), "reset can update config but not erase taint")
	var practice_result := finish(changed)
	check(practice_result.ranking_group == "practice" and not practice_result.tuning_ranked_eligible, "taint remains sticky after reset")
	check(practice_result.tuning_reasons == ["player.attack_multiplier"], "applied reason survives reset")
	check(practice_result.run_config_hash != normal_result.run_config_hash, "configuration history affects provenance")
	var tampered := changed.result_metadata()
	tampered["hard_mode"] = true
	tampered["tuning_reasons"].clear()
	check(not changed.result_metadata().hard_mode and changed.result_metadata().tuning_reasons.size() == 1, "sealed metadata returns isolated copies")
	check(not changed.apply_run_metadata(metadata()), "terminal metadata cannot be rewritten")
	var invalid := make()
	check(not invalid.apply_run_metadata({"tuning_ranked_eligible": true, "tuning_config_hash": "bad", "tuning_reasons": []}), "invalid metadata rejected atomically")
	check(not invalid.apply_run_metadata({"tuning_ranked_eligible": true, "tuning_config_hash": {}, "tuning_reasons": []}), "wrong-type metadata rejected without a cast error")
	check(finish(invalid).ranking_group == "normal", "bad metadata did not partially mutate baseline")
	game._reset_campaign_runtime()
	var hard := make(true)
	finish(hard)
	game.current_battle = hard
	check(game.prepare_result(hard.result, hard.stars) and game.commit_prepared_result(), "direct result saves")
	check(game.last_result.hard_mode and game.last_result.ranking_group == "hard", "direct result carries actual mode")
	var identity: String = game.last_result.leaderboard_submission_id
	check(game.record_result(hard.result, hard.stars) and game.last_result.leaderboard_submission_id == identity, "same terminal model finalizes once")

func test_terminal_collision() -> void:
	# The final wave and fatal town damage can resolve in one simulation tick.
	# Emptying the last wave cannot award a clear or heal a defeated town.
	var collision := make()
	collision.wave = 8
	collision.wave_active = true
	collision.base_hp = 0
	collision.step()
	check(collision.result == BattleModel.Result.DEFEAT and collision.stars == 0, "defeat wins coincident final-wave completion")
	check(collision.base_hp == 0 and collision.completed_waves == 0, "fatal tick awards no clear healing or rewards")
	var frozen := collision.result_metadata()
	var terminal_tick: int = collision.tick
	var gold: int = collision.dp
	collision.step(120)
	check(not collision.apply_action([&"resign"]), "terminal actions are rejected")
	check(collision.tick == terminal_tick and collision.dp == gold and collision.result_metadata() == frozen, "terminal ticks, rewards and metadata stay fixed")

func test_groups(board: Node) -> void:
	board.configure_for_testing("user://result-groups.json", "")
	board.clear_for_testing()
	var normal := finish(make())
	var hard := finish(make(true))
	hard["stage_id"] = &"s3"
	hard["result"] = BattleModel.Result.CLEAR
	var practice_model := make()
	practice_model.apply_run_metadata(metadata(false, ["gameplay.start_gold"]))
	var practice := finish(practice_model)
	var legacy := {"stage_id": &"s3", "result": BattleModel.Result.CLEAR, "stars": 3, "kills": 50, "leaks": 0}
	check(not board.record_mission(normal).is_empty(), "Normal saved")
	for i: int in 55:
		check(not board.record_mission(hard).is_empty(), "Hard saved")
	check(not board.record_mission(practice).is_empty(), "Practice saved")
	check(not board.record_mission(legacy).is_empty(), "untagged legacy saved without attribution")
	check(board.local_entries_for_mode(false, 1).size() == 1, "mode filtering happens before top-N")
	check(board.local_entries_for_mode(true, 50).size() == 50, "each comparison group has its own bounded top-N")
	check(board.local_entries_for_group("practice").size() == 1 and board.local_entries_for_group("legacy").size() == 1, "practice and legacy remain available outside verified groups")
	var old: Dictionary = board.local_entries_for_group("legacy")[0]
	check(not old.has("hard_mode") and not old.has("tuning_ranked_eligible"), "historical mode and eligibility not invented")
	board.configure_for_testing("user://result-groups.json", "")
	check(board.local_entries_for_mode(false, 1).size() == 1 and board.local_entries_for_mode(true, 50).size() == 50, "mode records survive reload and per-group retention")
	check(board.local_entries_for_group("practice")[0].tuning_reasons == ["gameplay.start_gold"], "practice provenance survives reload")
	check(board.local_entries_for_group("legacy").size() == 1, "unknown history survives reload")
	check(board.pending_count() == 0, "no remote submission queue")
	check(board.calculate_score({"stage_id": "s3", "victory": true, "stars": 3, "kills": 365, "leaks": 5}) == 2_375_750, "named completion/chapter/star/kill/leak formula retained")
	check(board.calculate_score({"stage_id": "s1", "victory": false, "stars": -3, "kills": -10, "leaks": 999}) == 50_000, "negative score inputs clamp within component bounds")
	check(board.calculate_score({"stage_id": "s10", "victory": true, "stars": 999, "kills": 999, "leaks": -99}) == 3_085_000, "score components preserve documented upper bounds")
	var tied: Array = [{"score": 10, "created_at": "same", "submission_id": "test0002"}, {"score": 10, "created_at": "same", "submission_id": "test0001"}]
	board.sort_entries(tied)
	check(tied[0].submission_id == "test0001", "deterministic score/time/identity ties")
	var file := FileAccess.open("user://malformed-scores.json", FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	board.configure_for_testing("user://malformed-scores.json", "")
	check(board.local_entries(50).is_empty(), "malformed local scores recover safely")
	var record: Dictionary = board.prepare_mission(normal)
	for field: String in ["terminal_tick", "ticks_per_second", "run_metadata_version"]:
		for value: Variant in [NAN, INF, -INF, -1, 0.5, 1.0e30, true, "1", {}]:
			var corrupted := record.duplicate(true)
			corrupted[field] = value
			var repaired: Dictionary = board._sanitize_saved_record(corrupted)
			check(repaired.get("ranking_group") == "legacy" and not repaired.has("hard_mode"), "invalid %s cannot enter verified standings: %s" % [field, value])
	for field: String in ["hard_mode", "tuning_ranked_eligible", "run_config_hash", "tuning_config_hash", "tuning_reasons"]:
		var corrupted := record.duplicate(true)
		corrupted[field] = {}
		check(board._sanitize_saved_record(corrupted).get("ranking_group") == "legacy", "wrong-type provenance preserved only as unknown history")
	for field: String in ["stars", "kills", "leaks", "score_version"]:
		for value: Variant in [NAN, INF, -INF, 0.5, 1.0e30, true, "1", {}]:
			var corrupted := record.duplicate(true)
			corrupted[field] = value
			check(board._sanitize_saved_record(corrupted).is_empty(), "corrupted score component rejected: %s %s" % [field, value])
	var falsified := record.duplicate(true)
	falsified["score"] = 9_999_999
	falsified["duration_seconds"] = INF
	falsified["ranking_group"] = "hard"
	var repaired: Dictionary = board._sanitize_saved_record(falsified)
	check(repaired.score == board.calculate_score(record) and repaired.duration_seconds == 3.0 and repaired.ranking_group == "normal", "derived score/duration/group recompute from validated authority fields")
	board.configure_for_testing("user://result-backup.json", "")
	check(not board.store_record(record).is_empty(), "baseline record persisted for corruption recovery")
	var edited := record.duplicate(true)
	edited["kills"] = 100
	check(board.store_record(edited).is_empty() and board.local_entries().size() == 1, "an identity cannot be reused with changed outcome")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(board.save_path), ProjectSettings.globalize_path(board.save_path + ".bak")) == OK, "valid local backup prepared")
	file = FileAccess.open(board.save_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	board.configure_for_testing("user://result-backup.json", "")
	check(board.local_entries_for_mode(false).size() == 1, "corrupt primary restores valid backup metadata")

func campaign_model(game: Node, hard: bool) -> FablewoodBattle:
	check(game.start_campaign_stage(&"s1", false), "canonical campaign ticket issued")
	var model := Model.create_fablewood(load("res://data/stages/s1.tres"), game.battle_launch(), 42)
	check(model != null, "model accepts canonical ticket")
	check(model.configure_hard_mode(hard) and model.apply_run_metadata(metadata()), "ticketed attempt configured")
	game.current_battle = model
	finish(model)
	return model

func test_retries(game: Node, board: Node) -> void:
	board.configure_for_testing("user://result-retries.json", "")
	board.clear_for_testing()
	# Earlier checks may leave a pending stage in the managed run's shared save.
	check(game.start_campaign(false, true), "durable campaign starts")
	var launch_revision: int = game.campaign.save_revision()
	var attempt_id: int = game.campaign.next_attempt_id()
	var launch_temp: String = game.campaign_store._tmp_path
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(launch_temp)) == OK, "launch save blocked for one write")
	check(not game.start_campaign_stage(&"s1", false) and game.mission_launch_retry_pending(), "launch storage failure retains retryable mutation")
	check(game.campaign.save_revision() == launch_revision and game.pending_campaign_stage_id().is_empty(), "failed launch publishes no phantom ticket")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(launch_temp)) == OK, "launch obstruction removed")
	check(game.start_campaign_stage(&"s1", false), "launch retries original mutation")
	check(game._pending_battle_ticket.attempt_id == attempt_id and game.campaign.save_revision() == launch_revision + 1, "launch commits one original attempt identity")
	check(game.start_campaign_stage(&"s1", false) and game._pending_battle_ticket.attempt_id == attempt_id and game.campaign.save_revision() == launch_revision + 1, "repeated launch resumes same attempt without duplication")
	var hard := campaign_model(game, true)
	var revision: int = game.campaign.save_revision()
	var blocked_campaign_temp: String = game.campaign_store._tmp_path
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_campaign_temp)) == OK, "campaign temp path blocked for one write")
	check(game.prepare_result(hard.result, hard.stars), "campaign result prepared")
	var frozen: Dictionary = hard.result_metadata()
	check(not game.commit_prepared_result(), "injected campaign write fails")
	check(board.local_entries(50).is_empty(), "no score before campaign outcome commits")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_campaign_temp)) == OK, "campaign temp obstruction removed")
	var retried: bool = game.prepare_result(hard.result, hard.stars) and game.commit_prepared_result()
	check(retried, "same campaign mutation retries")
	if not retried:return
	check(game.last_result.hard_mode and game.last_result.run_config_hash == frozen.run_config_hash, "frozen actual-attempt provenance retained through retry")
	check(game.last_result.terminal_tick == int(hard.terminal_outcome().terminal_tick), "ticketed terminal tick projected")
	check(game.campaign.save_revision() == revision + 1 and board.local_entries_for_mode(true).size() == 1, "one resolution and one Hard score")
	check(game.record_result(hard.result, hard.stars), "repeated finalization is idempotent")
	check(game.campaign.save_revision() == revision + 1 and board.local_entries_for_mode(true).size() == 1, "repeated finalization does not duplicate")
	var normal := campaign_model(game, false)
	var blocked_score_temp: String = board.save_path + ".tmp"
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_score_temp)) == OK, "local score temp path blocked for one write")
	check(game.record_result(normal.result, normal.stars), "campaign success independent from local score storage")
	check(not game.last_result.leaderboard_saved and game.last_result.leaderboard_score >= 0, "unsaved result retains calculated score")
	check(board.local_entries_for_mode(false).is_empty(), "failed write does not expose a durable phantom row")
	var identity: String = game.last_result.leaderboard_submission_id
	var created_at: String = game._leaderboard_record.created_at
	revision = game.campaign.save_revision()
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_score_temp)) == OK, "local score temp obstruction removed")
	check(game.retry_leaderboard_save() and game.retry_leaderboard_save(), "score-only retry and repeated retry succeed")
	check(game.campaign.save_revision() == revision, "score-only retry never resolves campaign again")
	check(game.last_result.leaderboard_submission_id == identity, "retry preserves record identity")
	check(board.local_entries_for_mode(false).size() == 1 and board.local_entries_for_mode(false)[0].created_at == created_at, "retry preserves timestamp and inserts once")
	board.configure_for_testing("user://result-retries.json", "")
	check(board.local_entries_for_mode(false).size() == 1 and board.local_entries_for_mode(true).size() == 1, "retried tagged results survive disk reload")
	check(board.pending_count() == 0, "retries remain local only")

func run() -> void:
	var game: Node = root.get_node("Game")
	var board: Node = root.get_node("Leaderboard")
	test_metadata(game)
	test_terminal_collision()
	test_groups(board)
	test_retries(game, board)
	var launch_fixture := LaunchChecks.new(self)
	var launch_result: Dictionary = await launch_fixture.run()
	failures += int(launch_result.failures)
	checks += int(launch_result.checks)
	print("FABLEWOOD_RESULT_CONTRACT failures=", failures, " checks=", checks)
	quit(0 if failures == 0 else 1)
