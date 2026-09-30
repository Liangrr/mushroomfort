class_name BattleOutcomeBuilder
extends RefCounted

## The sole tactical BattleOutcome producer. UI and campaign code consume the
## already-sealed model result; they never reconstruct terminal attribution.

const BattleOutcomeV3Script := preload("res://sim/battle_outcome_v3.gd")


static func seal(model: BattleModel) -> Dictionary:
	if not model._is_ticketed() or model.result == BattleModel.Result.RUNNING:
		return {}
	var rows: Array[Dictionary] = []
	for record: Dictionary in model._battle_records:
		rows.append(record.duplicate(true))
	var sealed := (
		BattleOutcomeV3Script
		. seal(
			{
				"schema_version": BattleOutcomeV3Script.SCHEMA_VERSION,
				"attempt_id": model._ticket["attempt_id"],
				"ticket_hash": model._ticket["ticket_hash"],
				"result": "clear" if model.result == BattleModel.Result.CLEAR else "defeat",
				"terminal_reason": String(model.terminal_reason),
				"terminal_tick": model.tick,
				"stars": model.stars,
				"leaks": model.leaked,
				"kills": model.killed,
				"rows": rows,
			},
			model._ticket,
		)
	)
	return sealed["value"] if sealed["accepted"] else {}
