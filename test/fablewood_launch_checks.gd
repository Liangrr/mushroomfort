extends RefCounted

const SCREEN_PATH := "res://scripts/fablewood/screen.gd"
var tree: SceneTree
var game: Node
var failures := 0
var checks := 0


func _init(active_tree: SceneTree) -> void:
	tree = active_tree


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	return ok


func frames(count: int = 4) -> void:
	for _i: int in count:
		await tree.process_frame


func live_screens() -> Array[Node]:
	var screens: Array[Node] = []
	for child: Node in tree.root.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == SCREEN_PATH:
			screens.append(child)
	return screens


func live_battles() -> Array[Node]:
	var battles: Array[Node] = []
	for child: Node in tree.root.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == SCREEN_PATH and child.mode == "battle":
			battles.append(child)
	return battles


func press_button(key: String, count: int = 2) -> void:
	var screen: Control = game.content
	var target: Button = null
	for button: Button in screen.find_children("*", "Button", true, false):
		if not button.disabled and button.text == screen.trf(key):
			target = button
			break
	if check(target != null, "actual %s button exists" % key):
		# Reproduce two input activations before either deferred swap can run.
		for _i: int in count:
			target.pressed.emit()


func one_battle(label: String, stage_id: StringName) -> bool:
	var battles := live_battles()
	if not check(battles.size() == 1, "%s leaves exactly one live battle, got %d" % [label, battles.size()]):
		return false
	var screen: Control = battles[0]
	check(game.content == screen and screen.startup_succeeded, label + " publishes the accepted screen")
	check(game.current_battle == screen.model and screen.model.stage.id == stage_id, label + " publishes the matching model")
	screen.set_process(false)
	if screen._tutorial_active:
		screen._skip_tutorial()
	return true


func results(clear: bool) -> bool:
	var model: FablewoodBattle = game.current_battle
	if clear:
		# Put the model at the final-wave boundary; use its terminal transition.
		model.wave = 8
		model.completed_waves = 7
		model.wave_active = true
		model.timeline = WaveTimeline.new()
		model.step()
		check(model.result == BattleModel.Result.CLEAR, "final-wave fixture reaches a clear")
	else:
		check(model.apply_action([&"resign"]), "attempt reaches a normal defeat")
	if not check(game.record_result(model.result, model.stars), "terminal result commits before opening Results"):
		return false
	game.open_results()
	await frames()
	check(game.content.mode == "results" and live_battles().is_empty(), "Results retires the prior battle")
	return true


func test_buttons() -> bool:
	check(game.start_campaign(false, true), "fresh isolated campaign starts")
	game.open_stage_select()
	await frames()
	var revision: int = game.campaign.save_revision()
	press_button("play")
	check(game.campaign.save_revision() == revision + 1, "double Play commits one ticket")
	await frames()
	if not one_battle("double Play", &"s1"):
		return false
	if not await results(false):
		return false
	revision = game.campaign.save_revision()
	press_button("retry")
	check(game.campaign.save_revision() == revision + 1, "double Replay commits one ticket")
	await frames()
	if not one_battle("double Replay", &"s1"):
		return false
	if not await results(true):
		return false
	revision = game.campaign.save_revision()
	press_button("continue")
	check(game.campaign.save_revision() == revision + 1, "double Continue commits one ticket")
	await frames()
	return one_battle("double Continue", &"s2")


func test_activation_retry() -> bool:
	game.open_stage_select()
	await frames()
	var previous: Node = game.content
	var previous_model: BattleModel = game.current_battle
	var ticket: Dictionary = game._pending_battle_ticket.duplicate(true)
	var revision: int = game.campaign.save_revision()
	# Replace only the cached scene for one activation, without changing files or
	# adding a production fault hook. A scene with no battle model is rejected.
	var original: PackedScene = load(game.BATTLE_SCENE_PATH)
	var rejected := PackedScene.new()
	var empty := Node.new()
	check(rejected.pack(empty) == OK, "rejected activation fixture packs")
	empty.free()
	rejected.take_over_path(game.BATTLE_SCENE_PATH)
	check(game.start_campaign_stage(&"s2") and game.start_campaign_stage(&"s2"), "duplicate pending-attempt API calls are accepted")
	await frames()
	check(game.content == previous and previous.is_inside_tree(), "rejected activation retains the usable chapter screen")
	check(live_battles().is_empty() and game.current_battle == previous_model, "rejected activation leaves no live candidate or changed model")
	check(game._pending_battle_ticket == ticket and game.campaign.save_revision() == revision, "rejected activation retains its one durable attempt")
	original.take_over_path(game.BATTLE_SCENE_PATH)
	check(game.start_campaign_stage(&"s2") and game.start_campaign_stage(&"s2"), "retry can queue the same attempt after activation rejection")
	await frames()
	check(game._pending_battle_ticket == ticket and game.campaign.save_revision() == revision, "successful activation retry does not issue another ticket")
	return one_battle("double API retry", &"s2")


func test_storage_retry() -> bool:
	game.open_title()
	await frames()
	check(live_battles().is_empty(), "returning to Title leaves no orphan battle")
	check(game.start_campaign(false, true), "storage-failure campaign starts")
	game.open_stage_select()
	await frames()
	var previous: Node = game.content
	var revision: int = game.campaign.save_revision()
	var temporary: String = game.campaign_store._tmp_path
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temporary)) == OK, "one campaign write is obstructed")
	press_button("play")
	await frames()
	check(game.content == previous and live_battles().is_empty(), "failed durable launch queues no battle")
	check(game.mission_launch_retry_pending() and game.campaign.save_revision() == revision, "failed durable launch retains retry without advancing revision")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary)) == OK, "campaign write obstruction is removed")
	check(previous.overlay != null, "launch failure exposes its dismissible error")
	press_button("close", 1)
	await frames()
	check(previous.overlay == null, "closing the launch error restores chapter controls")
	press_button("play")
	await frames()
	check(not game.mission_launch_retry_pending() and game.campaign.save_revision() == revision + 1, "storage retry commits exactly one original attempt")
	return one_battle("double storage retry", &"s1")


func test_mixed_navigation() -> bool:
	if not await results(false):
		return false
	press_button("chapters", 1)
	press_button("retry", 1)
	var ticket: Dictionary = game._pending_battle_ticket.duplicate(true)
	var revision: int = game.campaign.save_revision()
	await frames()
	check(live_screens().size() == 1, "Chapters then Replay retires the intervening chapter screen")
	if not one_battle("Chapters then Replay", &"s1"):
		return false
	check(game._pending_battle_ticket == ticket and game.campaign.save_revision() == revision, "mixed navigation preserves its one committed attempt")
	if not await results(false):
		return false
	var previous_stage: StageDef = game.pending_stage
	var previous_model: BattleModel = game.current_battle
	var original: PackedScene = load(game.BATTLE_SCENE_PATH)
	var rejected := PackedScene.new()
	var empty := Node.new()
	check(rejected.pack(empty) == OK, "mixed rejected activation packs")
	empty.free()
	rejected.take_over_path(game.BATTLE_SCENE_PATH)
	press_button("chapters", 1)
	press_button("retry", 1)
	ticket = game._pending_battle_ticket.duplicate(true)
	revision = game.campaign.save_revision()
	await frames()
	check(live_screens().size() == 1 and game.content.mode == "chapters", "mixed rejection retains only the current chapter screen")
	check(game.pending_stage == previous_stage and game.current_battle == previous_model, "mixed rejection restores prequeue stage and model")
	check(game._pending_battle_ticket == ticket and game.campaign.save_revision() == revision, "mixed rejection retains its one committed ticket")
	check(not game._battle_swap_pending, "mixed rejection releases launch guard")
	original.take_over_path(game.BATTLE_SCENE_PATH)
	press_button("resume_attempt", 1)
	await frames()
	check(live_screens().size() == 1, "mixed rejection retry retires its chapter screen")
	if not one_battle("mixed rejection retry", &"s1"):
		return false
	check(game._pending_battle_ticket == ticket and game.campaign.save_revision() == revision, "mixed rejection retry reuses ticket and revision")
	if not await results(false):
		return false
	press_button("retry", 1)
	press_button("chapters", 1)
	await frames()
	check(live_screens().size() == 1 and game.content.mode == "chapters", "Replay then Chapters leaves only the requested chapter screen")
	check(live_battles().is_empty() and not game._battle_swap_pending, "reverse navigation leaves no battle or launch lock")
	return true


func test_navigation_cancellation() -> bool:
	game.open_title()
	await frames()
	check(game.start_campaign(false, true), "fresh mixed-navigation campaign starts")
	game.open_stage_select()
	await frames()
	press_button("back", 1)
	press_button("play", 1)
	await frames()
	check(live_screens().size() == 1 and game.content.mode == "title", "Back then stale Play leaves only Title")
	check(live_battles().is_empty() and not game._battle_swap_pending, "stale Play is rejected after Back clears campaign")
	check(game.start_campaign(false, true), "fresh cancellation campaign starts")
	game.open_stage_select()
	await frames()
	press_button("play", 1)
	var ticket: Dictionary = game._pending_battle_ticket.duplicate(true)
	var revision: int = game.campaign.save_revision()
	press_button("back", 1)
	await frames()
	check(live_screens().size() == 1 and game.content.mode == "title", "Play then Back leaves only Title")
	check(not game._battle_swap_pending and game.pending_stage == null and game.current_battle == null, "cancelled launch releases guard without restoring cleared pointers")
	check(game.start_campaign(false), "cancelled committed attempt reloads normally")
	check(game._pending_battle_ticket == ticket and game.campaign.save_revision() == revision, "navigation cancellation preserves durable attempt for resume")
	game.open_stage_select()
	await frames()
	press_button("resume_attempt", 1)
	await frames()
	check(live_screens().size() == 1, "resuming cancelled launch owns only one screen")
	if not one_battle("resume cancelled launch", &"s1"):
		return false
	game.open_title()
	await frames()
	check(game.start_campaign(false, true), "fresh campaign still starts after cancellation")
	game.open_stage_select()
	await frames()
	press_button("play", 1)
	await frames()
	check(live_screens().size() == 1, "fresh Play after cancellation owns one screen")
	return one_battle("fresh Play after cancellation", &"s1")


func run() -> Dictionary:
	game = tree.root.get_node("Game")
	var ok := await test_buttons()
	if ok:
		ok = await test_activation_retry()
	if ok:
		ok = await test_storage_retry()
	if ok:
		ok = await test_mixed_navigation()
	if ok:
		await test_navigation_cancellation()
	game.open_title()
	await frames()
	check(live_battles().is_empty(), "final Title has no orphan battles")
	print("FABLEWOOD_LAUNCH_CONTRACT failures=", failures, " checks=", checks)
	return {"failures": failures, "checks": checks}
