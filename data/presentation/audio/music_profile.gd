class_name MusicProfile
extends Resource

## Faction-authored soundtrack routing. Stage data selects a profile and variant;
## no simulation state stores streams or playback decisions.

@export var id: StringName = &""
@export var faction_id: StringName = &""
@export var staging_cue_id: StringName = &""
@export var battle_variants: Dictionary = {}
@export var boss_cue_id: StringName = &""
@export var victory_cue_id: StringName = &""
@export var defeat_cue_id: StringName = &""
@export_range(0.0, 30.0, 0.25) var minimum_state_hold_seconds: float = 8.0
@export_range(0.0, 2.0, 0.05) var routine_crossfade_seconds: float = 0.75
@export_range(0.0, 2.0, 0.05) var danger_crossfade_seconds: float = 0.35


func cue_id_for(variant_id: StringName, state_id: StringName) -> StringName:
	if variant_id == &"boss":
		return boss_cue_id
	var variant_value: Variant = battle_variants.get(variant_id, {})
	if not variant_value is Dictionary:
		return &""
	var variant: Dictionary = variant_value
	var cue_value: Variant = variant.get(state_id, &"")
	return cue_value as StringName if typeof(cue_value) == TYPE_STRING_NAME else StringName(cue_value)


func is_valid() -> bool:
	return not id.is_empty() and not faction_id.is_empty() and not staging_cue_id.is_empty()
