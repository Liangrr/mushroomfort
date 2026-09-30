class_name CampaignPromotionSnapshotCodec
extends RefCounted


static func normalize(
	value: Variant,
	context: Dictionary,
	data_keys: Array,
	core_keys: Array,
	normalize_core: Callable,
	normalize_resolution: Callable,
	normalize_anchor: Callable,
) -> Dictionary:
	if (
		typeof(value) != TYPE_DICTIONARY
		or not _exact_keys(value, data_keys)
		or typeof(value["promotion_proofs"]) != TYPE_ARRAY
		or not value["promotion_proofs"].is_empty()
	):
		return _reject()
	var core_input := {}
	for key: String in core_keys:
		core_input[key] = value[key]
	var core: Dictionary = normalize_core.call(core_input, context)
	if not core.get("accepted", false):
		return _reject()
	var last: Variant = null
	if value["last_resolution"] != null:
		var normalized: Dictionary = normalize_resolution.call(value["last_resolution"])
		if not normalized.get("accepted", false):
			return _reject()
		last = normalized["value"]
	var anchor: Dictionary = normalize_anchor.call(value["resolution_anchor"], context)
	if not anchor.get("accepted", false):
		return _reject()
	var ordered: Dictionary = core["value"].duplicate(true)
	ordered["resolution_anchor"] = anchor["value"]
	ordered["last_resolution"] = last
	return {"accepted": true, "error_code": &"", "value": ordered}


static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	var actual: Array = value.keys()
	for index: int in expected.size():
		if actual[index] != expected[index]:
			return false
	return true


static func _reject() -> Dictionary:
	return {"accepted": false, "error_code": &"invalid_promotion_proof"}
