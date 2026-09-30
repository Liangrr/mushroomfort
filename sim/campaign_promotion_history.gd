class_name CampaignPromotionHistory
extends RefCounted

const CampaignProgressionType := preload("res://sim/campaign_progression.gd")
const CampaignHashType := preload("res://sim/campaign_hash.gd")

static func validate(data: Dictionary, context: Dictionary) -> Dictionary:
	var receipts: Array = data["promotion_receipts"]
	var proofs: Array = data["promotion_proofs"]
	if receipts.size() != proofs.size():
		return _reject(&"promotion_history_mismatch")
	var heroes := _heroes_by_id(data["heroes"])
	for index: int in receipts.size():
		var receipt: Dictionary = receipts[index]
		var proof: Dictionary = proofs[index]
		if proof["command_id"] != receipt["command_id"]:
			return _reject(&"promotion_history_mismatch")
		var transition := _validate_transition(receipt, proof, index)
		if not transition["accepted"]:
			return transition
		var hero: Dictionary = heroes.get(receipt["hero_id"], {})
		if not _current_hero_matches(hero, receipt, context["promotion_rules"]):
			return _reject(&"promotion_history_mismatch")
	return _accept()


static func _validate_transition(
	receipt: Dictionary,
	proof: Dictionary,
	index: int,
) -> Dictionary:
	var before: Dictionary = proof["before_data"]
	var after: Dictionary = proof["after_data"]
	var expected_id := "promote:%s:%d:%s:%s" % [
		before["campaign_uid"], receipt["prior_save_revision"],
		receipt["hero_id"], receipt["new_class_id"],
	]
	if (
		receipt["command_id"] != expected_id
		or int(before["save_revision"]) != int(receipt["prior_save_revision"])
		or int(after["save_revision"]) != int(receipt["new_save_revision"])
		or before["promotion_receipts"].size() != index
		or after["promotion_receipts"].size() != index + 1
		or after["promotion_receipts"][-1] != receipt
	):
		return _reject(&"promotion_history_mismatch")
	for prior_index: int in index:
		if before["promotion_receipts"][prior_index] != after["promotion_receipts"][prior_index]:
			return _reject(&"promotion_history_mismatch")
	var expected: Dictionary = before.duplicate(true)
	expected["save_revision"] = receipt["new_save_revision"]
	var hero := _hero_by_id(expected["heroes"], String(receipt["hero_id"]))
	if hero.is_empty():
		return _reject(&"promotion_history_mismatch")
	if (
		hero["first_class_id"] != receipt["prior_class_id"]
		or hero["advanced_class_id"] != null
		or hero["operator_def_id"] != receipt["prior_operator_def_id"]
	):
		return _reject(&"promotion_history_mismatch")
	hero["advanced_class_id"] = receipt["new_class_id"]
	hero["operator_def_id"] = receipt["new_operator_def_id"]
	expected["promotion_receipts"].append(receipt.duplicate(true))
	if expected != after:
		return _reject(&"promotion_history_mismatch")
	var before_hash := CampaignHashType.of_normalized_data(before, false)
	var after_hash := CampaignHashType.of_normalized_data(after, false)
	if (
		before_hash["hex"] != receipt["before_strategic_hash"]
		or after_hash["hex"] != receipt["after_strategic_hash"]
	):
		return _reject(&"promotion_hash_mismatch")
	return _accept()


static func _current_hero_matches(
	hero: Dictionary,
	receipt: Dictionary,
	rules: Dictionary,
) -> bool:
	if hero.is_empty():
		return false
	var choice := CampaignProgressionType.promotion_choice(
		rules, String(receipt["new_class_id"]),
	)
	return (
		not choice.is_empty()
		and receipt["prior_class_id"] == rules["source_class_id"]
		and receipt["prior_operator_def_id"] == "caster_1"
		and receipt["new_operator_def_id"] == choice["operator_def_id"]
		and hero["first_class_id"] == receipt["prior_class_id"]
		and hero["advanced_class_id"] == receipt["new_class_id"]
		and hero["operator_def_id"] == receipt["new_operator_def_id"]
		and int(hero["xp"]) >= int(rules["xp_required"])
	)


static func _heroes_by_id(rows: Array) -> Dictionary:
	var result := {}
	for hero: Dictionary in rows:
		result[hero["hero_id"]] = hero
	return result


static func _hero_by_id(rows: Array, hero_id: String) -> Dictionary:
	for hero: Dictionary in rows:
		if hero["hero_id"] == hero_id:
			return hero
	return {}


static func _accept() -> Dictionary:
	return {"accepted": true, "error_code": &""}


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
