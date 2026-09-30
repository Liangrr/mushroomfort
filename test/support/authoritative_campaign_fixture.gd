class_name AuthoritativeCampaignFixture
extends RefCounted

const CampaignRuntimeAuthorityScript := preload("res://sim/campaign_runtime_authority.gd")
const BattleOutcomeV3Script := preload("res://sim/battle_outcome_v3.gd")


static func clear_stage(
	game: Node,
	stage_id: StringName,
	command_prefix: String = "campaign-fixture",
	stars: int = 3,
) -> Dictionary:
	if game == null or not bool(game.get("campaign_active")):
		return _reject(&"campaign_inactive")
	var state: Variant = game.get("campaign")
	var store: Variant = game.get("campaign_store")
	if state == null or store == null:
		return _reject(&"campaign_state_missing")
	var projection: Dictionary = state.runtime_projection()
	var ready: Array = projection.get("ready_heroes", [])
	if ready.is_empty():
		return _reject(&"ready_hero_missing")
	var hero_id := String(ready[0].get("hero_id", ""))
	if hero_id.is_empty():
		return _reject(&"ready_hero_invalid")
	var ordinal := int(String(stage_id).trim_prefix("s"))
	var command_scope := "%s:%s:%d" % [
		command_prefix, stage_id, state.next_attempt_id(),
	]
	var begin: Dictionary = state.begin_attempt(
		"%s:begin" % command_scope,
		stage_id,
		[hero_id],
		91000 + ordinal,
		state.save_revision(),
	)
	if not begin.get("accepted", false):
		return _reject(begin.get("error_code", &"begin_rejected"))
	var committed_begin: Dictionary = CampaignRuntimeAuthorityScript.commit(begin, store)
	if not committed_begin.get("accepted", false):
		return _reject(committed_begin.get("error_code", &"begin_commit_rejected"))
	state = committed_begin["state"]
	game.set("campaign", state)
	var ticket: Dictionary = committed_begin["result"]["ticket"]
	var frozen: Dictionary = ticket["squad"][0]
	var outcome: Dictionary = BattleOutcomeV3Script.seal({
		"schema_version": BattleOutcomeV3Script.SCHEMA_VERSION,
		"attempt_id": ticket["attempt_id"],
		"ticket_hash": ticket["ticket_hash"],
		"result": "clear",
		"terminal_reason": "clear",
		"terminal_tick": 120,
		"stars": stars,
		"leaks": 0,
		"kills": 12,
		"rows": [{
			"slot_index": frozen["slot_index"],
			"battle_id": frozen["battle_id"],
			"hero_id": frozen["hero_id"],
			"class_id": frozen["class_id"],
			"operator_def_id": frozen["operator_def_id"],
			"deployments": 1,
			"retreats": 0,
			"fell": false,
			"first_fall_tick": null,
		}],
	}, ticket)
	if not outcome.get("accepted", false):
		return _reject(outcome.get("error_code", &"outcome_rejected"))
	var resolved: Dictionary = state.resolve_attempt(
		"%s:resolve" % command_scope,
		ticket["attempt_id"],
		outcome["value"],
		state.save_revision(),
	)
	if not resolved.get("accepted", false):
		return _reject(resolved.get("error_code", &"resolve_rejected"))
	var committed_resolution: Dictionary = CampaignRuntimeAuthorityScript.commit(resolved, store)
	if not committed_resolution.get("accepted", false):
		return _reject(committed_resolution.get("error_code", &"resolve_commit_rejected"))
	state = committed_resolution["state"]
	game.set("campaign", state)
	return {
		"accepted": true,
		"error_code": &"",
		"state": state,
		"resolution": committed_resolution["result"]["resolution"].duplicate(true),
	}


static func _reject(error_code: Variant) -> Dictionary:
	return {
		"accepted": false,
		"error_code": StringName(error_code),
	}
