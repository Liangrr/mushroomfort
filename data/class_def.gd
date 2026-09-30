class_name ClassDef
extends Resource

## Data-owned persistent class graph. OperatorDef owns battle projection;
## ClassDef owns legal promotion edges, thresholds, and localization identity.

enum Stage { BASIC, STANDARD, ADVANCED }

const RULES_VERSION := 2
const BASIC_PROMOTION_XP_REQUIRED := 100
const ADVANCED_PROMOTION_XP_REQUIRED := 400

@export var class_id: StringName = &""
@export var stage: Stage = Stage.BASIC
@export var operator_def_id: StringName = &""
@export var promotion_from_class_id: StringName = &""
@export var promotion_to_class_ids: Array[StringName] = []
@export var promotion_xp_required: int = 0
@export var entitlement_id: StringName = &""
@export var name_key: StringName = &""
@export var role_key: StringName = &""
@export var description_key: StringName = &""
@export var name: String = ""
@export var role: String = ""
@export var description: String = ""
@export var rules_version: int = RULES_VERSION


static func normalize_catalog(
	resources: Array,
	operator_ids: Array,
	locale_entries: Dictionary,
) -> Dictionary:
	var operators := _string_set(operator_ids)
	var by_id := {}
	var operator_owners := {}
	for value: Variant in resources:
		if not value is Resource or value.get_script() != load("res://data/class_def.gd"):
			return _reject(&"invalid_class_resource")
		var definition := value as Resource
		var row := _normalize_row(definition, operators, locale_entries)
		if not row["accepted"]:
			return row
		var normalized: Dictionary = row["value"]
		var id := String(normalized["class_id"])
		var operator_id := String(normalized["operator_def_id"])
		if by_id.has(id):
			return _reject(&"duplicate_class_id")
		if operator_owners.has(operator_id):
			return _reject(&"duplicate_class_operator")
		by_id[id] = normalized
		operator_owners[operator_id] = id
	if by_id.is_empty() or operator_owners.size() != operators.size():
		return _reject(&"orphan_operator")
	for operator_id: String in operators:
		if not operator_owners.has(operator_id):
			return _reject(&"orphan_operator")
	var graph := _validate_graph(by_id)
	if not graph["accepted"]:
		return graph
	var ids: Array = by_id.keys()
	ids.sort()
	var rows: Array[Dictionary] = []
	for id: String in ids:
		rows.append((by_id[id] as Dictionary).duplicate(true))
	return {"accepted": true, "error_code": &"", "value": rows}


static func validate_obtainability(rows: Array, campaign_def: Variant) -> Dictionary:
	if campaign_def == null or campaign_def.schema_version != 3:
		return _reject(&"invalid_campaign_definition")
	var by_id := {}
	for row: Dictionary in rows:
		by_id[String(row["class_id"])] = row
	var starting := _unique_strings(campaign_def.starting_class_ids)
	if starting.size() != campaign_def.starting_class_ids.size():
		return _reject(&"duplicate_starting_class")
	var entitled := {}
	for raw: Variant in campaign_def.stage_class_entitlements:
		if typeof(raw) != TYPE_DICTIONARY:
			return _reject(&"invalid_class_entitlement")
		var entry := raw as Dictionary
		if not _exact_keys(entry, ["class_id", "stage_id"]):
			return _reject(&"invalid_class_entitlement")
		var stage_id := String(entry["stage_id"])
		var class_id := String(entry["class_id"])
		if not _ascii_id(stage_id) or not _ascii_id(class_id):
			return _reject(&"invalid_class_entitlement")
		if entitled.has(class_id):
			return _reject(&"duplicate_class_entitlement")
		entitled[class_id] = stage_id
	for row: Dictionary in rows:
		var id := String(row["class_id"])
		match int(row["stage"]):
			Stage.BASIC:
				if id != "recruit" or starting.has(id) or entitled.has(id):
					return _reject(&"invalid_basic_obtainability")
			Stage.STANDARD:
				if not starting.has(id) or not String(row["entitlement_id"]).is_empty():
					return _reject(&"invalid_standard_obtainability")
			Stage.ADVANCED:
				if not entitled.has(id) or String(row["entitlement_id"]) != id:
					return _reject(&"invalid_advanced_obtainability")
	if starting.size() != _stage_count(rows, Stage.STANDARD):
		return _reject(&"incomplete_starting_classes")
	if entitled.size() != _stage_count(rows, Stage.ADVANCED):
		return _reject(&"incomplete_class_entitlements")
	return {"accepted": true, "error_code": &""}


static func _normalize_row(
	definition: Resource,
	operators: Dictionary,
	locale_entries: Dictionary,
) -> Dictionary:
	var id := String(definition.class_id)
	var operator_id := String(definition.operator_def_id)
	if not _ascii_id(id) or not operators.has(operator_id):
		return _reject(&"invalid_class_identity")
	if definition.rules_version != RULES_VERSION:
		return _reject(&"invalid_class_rules_version")
	if definition.stage < Stage.BASIC or definition.stage > Stage.ADVANCED:
		return _reject(&"invalid_class_stage")
	var from_id := String(definition.promotion_from_class_id)
	if not from_id.is_empty() and not _ascii_id(from_id):
		return _reject(&"invalid_class_edge")
	var targets: Array[String] = []
	for raw_target: StringName in definition.promotion_to_class_ids:
		var target := String(raw_target)
		if not _ascii_id(target) or targets.has(target):
			return _reject(&"invalid_class_edge")
		targets.append(target)
	var entitlement := String(definition.entitlement_id)
	if not entitlement.is_empty() and not _ascii_id(entitlement):
		return _reject(&"invalid_class_entitlement")
	if definition.stage == Stage.ADVANCED:
		if definition.promotion_xp_required != 0 or not targets.is_empty() or entitlement.is_empty():
			return _reject(&"invalid_advanced_class")
	elif definition.stage == Stage.BASIC:
		if definition.promotion_xp_required != BASIC_PROMOTION_XP_REQUIRED or not from_id.is_empty():
			return _reject(&"invalid_basic_class")
	elif (
		definition.promotion_xp_required != ADVANCED_PROMOTION_XP_REQUIRED
		or not entitlement.is_empty()
	):
		return _reject(&"invalid_standard_class")
	var localized := [
		[definition.name_key, definition.name],
		[definition.role_key, definition.role],
		[definition.description_key, definition.description],
	]
	for pair: Array in localized:
		var text_key := String(pair[0])
		var fallback := String(pair[1])
		if text_key.is_empty() or fallback.strip_edges().is_empty():
			return _reject(&"missing_class_localization")
		if not locale_entries.has(text_key) or String(locale_entries[text_key]) != fallback:
			return _reject(&"missing_class_localization")
	return {"accepted": true, "error_code": &"", "value": {
		"class_id": id,
		"stage": int(definition.stage),
		"operator_def_id": operator_id,
		"promotion_from_class_id": from_id,
		"promotion_to_class_ids": targets,
		"promotion_xp_required": definition.promotion_xp_required,
		"entitlement_id": entitlement,
		"rules_version": definition.rules_version,
	}}


static func _validate_graph(by_id: Dictionary) -> Dictionary:
	var roots: Array[String] = []
	for id: String in by_id:
		var row: Dictionary = by_id[id]
		if int(row["stage"]) == Stage.BASIC:
			roots.append(id)
		for target: String in row["promotion_to_class_ids"]:
			if not by_id.has(target):
				return _reject(&"missing_class_target")
			var target_row: Dictionary = by_id[target]
			if String(target_row["promotion_from_class_id"]) != id:
				return _reject(&"class_edge_mismatch")
			if int(target_row["stage"]) != int(row["stage"]) + 1:
				return _reject(&"invalid_class_stage_edge")
		var from_id := String(row["promotion_from_class_id"])
		if not from_id.is_empty():
			if not by_id.has(from_id):
				return _reject(&"missing_class_source")
			if not (by_id[from_id]["promotion_to_class_ids"] as Array).has(id):
				return _reject(&"class_edge_mismatch")
	if roots != ["recruit"]:
		return _reject(&"invalid_class_root")
	var reached := {"recruit": true}
	var queue: Array[String] = ["recruit"]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for target: String in by_id[current]["promotion_to_class_ids"]:
			if reached.has(target):
				return _reject(&"class_cycle")
			reached[target] = true
			queue.append(target)
	if reached.size() != by_id.size():
		return _reject(&"orphan_class")
	return {"accepted": true, "error_code": &""}


static func _string_set(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		var text := String(value)
		if result.has(text):
			return {}
		result[text] = true
	return result


static func _unique_strings(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		var text := String(value)
		if not _ascii_id(text) or result.has(text):
			return {}
		result[text] = true
	return result


static func _stage_count(rows: Array, expected: Stage) -> int:
	var count := 0
	for row: Dictionary in rows:
		if int(row["stage"]) == expected:
			count += 1
	return count


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	var actual: Array = value.keys()
	for index: int in expected.size():
		if actual[index] != expected[index]:
			return false
	return true


static func _ascii_id(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code}
