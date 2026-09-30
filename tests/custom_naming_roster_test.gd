extends SceneTree

const RuntimeContext := preload("res://sim/campaign_runtime_context.gd")
const CampaignStateV3 := preload("res://sim/campaign_state_v3.gd")
const RosterFilter := preload("res://scripts/ui/components/roster_filter.gd")

var _failures: Array[String] = []


func _init() -> void:
	var context := RuntimeContext.build()
	var created: Dictionary = CampaignStateV3.create(5150, 1, context)
	_check(created.get("accepted", false), "rename fixture creation failed")
	if not created.get("accepted", false):
		_finish()
		return
	var state: Variant = created["value"]
	var initial: Dictionary = state.runtime_projection()
	var hero: Dictionary = initial["ready_heroes"][0]
	var hero_id := String(hero["hero_id"])
	var renamed: Dictionary = state.rename_hero(
		"test:rename:roster", state.save_revision(), hero_id, "Eir",
	)
	_check(renamed.get("accepted", false), "recruit rename was rejected")
	if not renamed.get("accepted", false):
		_finish()
		return
	state = _restore_mutation(renamed, context)
	if state == null:
		_finish()
		return

	var projection: Dictionary = state.runtime_projection()
	var projected := _hero(projection["ready_heroes"], hero_id)
	_check(not projected.is_empty(), "renamed recruit disappeared from ready projection")
	_check(String(projected.get("callsign", "")) == "Eir", "runtime projection lost custom callsign")
	var annotated := RosterFilter.annotate(projected)
	_check(String(annotated.get("callsign", "")) == "Eir", "roster annotation changed custom callsign")
	var faction := StringName(annotated["faction_id"])
	var filtered := RosterFilter.filter_rows([annotated], &"active", faction)
	_check(filtered.size() == 1, "faction filter excluded the renamed recruit")
	_check(String(filtered[0].get("callsign", "")) == "Eir", "filtered roster lost custom callsign")
	_finish()


func _restore_mutation(command: Dictionary, context: Dictionary) -> Variant:
	var mutation: Variant = command.get("payload", {}).get("mutation")
	if mutation == null:
		_check(false, "rename mutation missing")
		return null
	var restored: Dictionary = CampaignStateV3.restore_source(
		mutation.prospective_save_text(), context,
	)
	_check(restored.get("accepted", false), "renamed campaign failed save restoration")
	return restored["value"] if restored.get("accepted", false) else null


func _hero(rows: Array, hero_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row.get("hero_id", "")) == hero_id:
			return row
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CUSTOM_NAMING_ROSTER_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
