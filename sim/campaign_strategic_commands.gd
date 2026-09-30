extends RefCounted

## Inherited P16.2 command surface. CampaignState keeps the frozen P16.1
## projection API; this base keeps each lint-owned public seam below 20 methods.

const CampaignProgressionType := preload("res://sim/campaign_progression.gd")

var _data: Dictionary = {}
var _context: Dictionary = {}
var _command_context: Dictionary = {}
var _campaign_def: CampaignDef
var _catalogs: Dictionary = {}
var _stage_defs: Array = []
var _pending_control: Callable
var _restore_callable: Callable
var _certified_restore_callable: Callable
var _encoded_save_cache: Dictionary = {}
var _strategic_hash_cache: Dictionary = {}
var _data_checksum_cache := ""


func _campaign_uid() -> String:
	return String(_data["campaign_uid"])


func _campaign_seed() -> int:
	return int(_data["campaign_seed"])


func _campaign_generation() -> int:
	return int(_data["campaign_generation"])


func _save_revision() -> int:
	return int(_data["save_revision"])


func _next_recruitment_index() -> int:
	return int(_data["next_recruitment_index"])


func _next_attempt_id() -> int:
	return int(_data["next_attempt_id"])


func _next_resolution_index() -> int:
	return int(_data["next_resolution_index"])


func _roster() -> RosterState:
	return RosterState.from_normalized_rows(_data["heroes"])


func _offer(offer_id: String) -> Dictionary:
	for row: Dictionary in _data["offers"]:
		if row["offer_id"] == offer_id:
			return row.duplicate(true)
	return {}


func _stage_stars_map() -> Dictionary:
	var result := {}
	for row: Dictionary in _data["stage_stars"]:
		result[StringName(row["stage_id"])] = int(row["stars"])
	return result


func _stage_unlocked(stage_id: StringName) -> bool:
	var stage_ids: Array = _context["stage_order"]
	var target_index := stage_ids.find(String(stage_id))
	if target_index < 0:
		return false
	if target_index == 0:
		return true
	return _stage_stars_map().has(StringName(stage_ids[target_index - 1]))


func encode_save() -> Dictionary:
	if _encoded_save_cache.is_empty():
		_encoded_save_cache = CampaignCodec.encode_save(_data, _context)
	return _copy_encoded(_encoded_save_cache)


func cached_strategic_hash() -> Dictionary:
	if _strategic_hash_cache.is_empty():
		_strategic_hash_cache = CampaignHash.of_data(_data, _context)
	return _copy_encoded(_strategic_hash_cache)


func seed_validated_caches() -> void:
	var data_encoded := _encode_normalized(_data)
	var root := {}
	root["schema"] = CampaignCodec.SAVE_SCHEMA
	root["version"] = CampaignCodec.SAVE_VERSION
	root["checksum"] = data_encoded["sha256"]
	root["data"] = data_encoded["value"]
	_encoded_save_cache = _encode_normalized(root)
	_data_checksum_cache = data_encoded["sha256"]


func _validated_save_text() -> String:
	return String(_encoded_save_cache["text"])


func _validated_hash_hex() -> String:
	if _strategic_hash_cache.is_empty():
		_strategic_hash_cache = CampaignHash._of_normalized_data(_data)
	return String(_strategic_hash_cache["hex"])


func _certified_data_unchanged() -> bool:
	return CanonicalJson.sha256_hex(_data) == _data_checksum_cache


func restore_factory() -> Callable:
	var internal := _authority_restore_factory()
	return func(source: String) -> Dictionary:
		var restored: Dictionary = internal.call(source)
		if not restored["accepted"]:
			return restored
		return {"accepted": true, "error_code": &"", "value": restored["value"]}


func _authority_restore_factory() -> Callable:
	return func(source: String) -> Dictionary:
		var decoded := CampaignCodec.decode_save(source, _context)
		if not decoded["accepted"]:
			return {"accepted": false, "error_code": decoded["error_code"], "value": null}
		return _restore_callable.call(decoded["data"])


func restored_copy_without_pending() -> Dictionary:
	var restored: Dictionary = _restore_callable.call(_data)
	if not restored["accepted"]:
		return restored
	return {"accepted": true, "error_code": &"", "value": restored["value"]}


func has_pending_attempt() -> bool:
	if not _pending_control.is_valid():
		return false
	return _pending_control.call(&"has", null)["accepted"]


func pending_attempt() -> Variant:
	if not has_pending_attempt():
		return null
	return _pending_control.call(&"current", null)["pending"]


func recovery_offers(stage_input: Variant) -> Dictionary:
	if typeof(stage_input) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return _offer_reject(&"unknown_campaign_stage")
	var stage_id := String(stage_input)
	if not _command_context["recovery_rosters"].has(stage_id):
		return _offer_reject(&"unknown_campaign_stage")
	if not _stage_unlocked(StringName(stage_id)):
		return _offer_reject(&"stage_locked")
	if _stage_stars_map().has(StringName(stage_id)):
		return _offer_reject(&"stage_cleared")
	var ready := {}
	for row: Dictionary in _data["heroes"]:
		if row["life_status"] == "ready":
			ready[String(row["operator_def_id"])] = true
	var values: Array[Dictionary] = []
	for operator_id: String in _command_context["recovery_rosters"][stage_id]:
		if not ready.has(operator_id):
			values.append({
				"offer_id": "recovery:%s:%s" % [stage_id, operator_id],
				"operator_def_id": operator_id,
				"cost": 0,
			})
	return {"accepted": true, "error_code": &"", "offers": values}


func recruit(offer_id: String) -> Dictionary:
	var attempted := _event(&"recruit_attempted", {"offer_id": offer_id})
	if has_pending_attempt():
		return _recruit_reject(offer_id, &"attempt_pending", attempted)
	var source := _recruit_source(offer_id)
	if not source["accepted"]:
		return _recruit_reject(offer_id, source["error_code"], attempted)
	if (_data["heroes"] as Array).size() >= CampaignCodec.MAX_ROSTER:
		return _recruit_reject(offer_id, &"roster_limit", attempted)
	var next_data: Dictionary = _data.duplicate()
	next_data["heroes"] = (_data["heroes"] as Array).duplicate()
	var marks_before := int(_data["marks"])
	if source["source"] == &"contract":
		next_data["marks"] = marks_before - int(source["cost"])
		next_data["offers"] = (_data["offers"] as Array).duplicate(true)
		for offer_row: Dictionary in next_data["offers"]:
			if offer_row["offer_id"] == offer_id:
				offer_row["consumed"] = true
	var allocation := _plan_allocation(source)
	if not allocation["accepted"]:
		return _recruit_reject(offer_id, &"invalid_campaign_state", attempted)
	var hero_row: Dictionary = allocation["row"]
	next_data["heroes"].append(hero_row.duplicate(true))
	next_data["next_recruitment_index"] = allocation["next_recruitment_index"]
	next_data["save_revision"] = _save_revision() + 1
	var next_state := _state_from_data(next_data)
	if not next_state["accepted"]:
		return _recruit_reject(offer_id, &"invalid_campaign_state", attempted)
	var staged: Array[Dictionary] = [
		_event(&"hero_created", {
			"hero_id": hero_row["hero_id"],
			"operator_def_id": hero_row["operator_def_id"],
			"recruit_source": hero_row["recruit_source"],
			"source_id": hero_row["source_id"],
		}),
		_event(&"recruit_accepted", {
			"offer_id": offer_id,
			"hero_id": hero_row["hero_id"],
			"operator_def_id": hero_row["operator_def_id"],
			"marks_before": marks_before,
			"marks_after": next_data["marks"],
			"save_revision": next_data["save_revision"],
		}),
	]
	return _command_mutation(
		&"recruit", next_state["value"], staged, {"hero_id": hero_row["hero_id"]},
		[attempted],
	)


func _plan_allocation(source: Dictionary) -> Dictionary:
	var rows: Array = _data["heroes"]
	if _next_recruitment_index() != rows.size():
		return _source_reject(&"recruitment_counter_mismatch")
	var is_taken := func(candidate: String) -> bool:
		return not _hero_row(candidate).is_empty()
	var allocated := HeroIdentity.allocate_hero_id(
		_campaign_seed(), _campaign_generation(), _next_recruitment_index(), is_taken,
	)
	if not allocated["accepted"]:
		return allocated
	var row := CampaignProgressionType.add_initial_fields({
		"hero_id": allocated["hero_id"],
		"operator_def_id": String(source["operator_def_id"]),
		"recruitment_index": rows.size(),
		"recruited_after_resolution_index": _next_resolution_index() - 1,
		"recruit_source": String(source["source"]),
		"source_id": String(source["source_id"]),
		"name_version": HeroNames.VERSION,
		"custom_callsign": null,
		"life_status": "ready",
		"death": null,
	})
	if row.is_empty():
		return _source_reject(&"invalid_operator")
	return {
		"accepted": true,
		"error_code": &"",
		"row": row,
		"next_recruitment_index": rows.size() + 1,
	}


func _hero_row(hero_id: String) -> Dictionary:
	for row: Dictionary in _data["heroes"]:
		if row["hero_id"] == hero_id:
			return row
	return {}


func rename_hero(hero_id: String, candidate: String) -> Dictionary:
	if has_pending_attempt():
		return _rename_reject(hero_id, &"attempt_pending")
	var checked := _validate_rename(hero_id, candidate)
	if not checked["accepted"]:
		return _rename_reject(hero_id, checked["error_code"])
	var next_data: Dictionary = _data.duplicate()
	next_data["heroes"] = (_data["heroes"] as Array).duplicate()
	var changed: Dictionary = next_data["heroes"][checked["target_index"]].duplicate(true)
	changed["custom_callsign"] = checked["new_callsign"]
	next_data["heroes"][checked["target_index"]] = changed
	next_data["save_revision"] = _save_revision() + 1
	var next_state := _state_from_data(next_data)
	if not next_state["accepted"]:
		return _rename_reject(hero_id, &"invalid_campaign_state")
	var staged: Array[Dictionary] = [_event(&"hero_renamed", {
		"hero_id": hero_id,
		"old_callsign": checked["old_callsign"],
		"new_callsign": checked["new_callsign"],
		"save_revision": next_data["save_revision"],
	})]
	return _command_mutation(
		&"rename", next_state["value"], staged, {"hero_id": hero_id}, [],
	)


func _validate_rename(hero_id: String, candidate: String) -> Dictionary:
	var rows: Array = _data["heroes"]
	var target_index := -1
	for index: int in rows.size():
		if rows[index]["hero_id"] == hero_id:
			target_index = index
			break
	if target_index < 0:
		return _source_reject(&"unknown_hero")
	var trimmed := _trim_callsign(candidate)
	if not _valid_callsign(trimmed):
		return _source_reject(&"invalid_callsign")
	var old := _display_callsign_row(rows[target_index])
	if not old["accepted"]:
		return _source_reject(&"invalid_campaign_state")
	if String(old["value"]) == trimmed:
		return _source_reject(&"callsign_unchanged")
	var uniqueness := _callsign_is_unique(hero_id, trimmed, rows)
	if not uniqueness["accepted"]:
		return uniqueness
	return {
		"accepted": true,
		"error_code": &"",
		"target_index": target_index,
		"old_callsign": old["value"],
		"new_callsign": trimmed,
	}


func _callsign_is_unique(hero_id: String, candidate: String, rows: Array) -> Dictionary:
	var folded := candidate.to_lower()
	for row: Dictionary in rows:
		if row["hero_id"] == hero_id:
			continue
		var display := _display_callsign_row(row)
		if not display["accepted"]:
			return _source_reject(&"invalid_campaign_state")
		if String(display["value"]).to_lower() == folded:
			return _source_reject(&"duplicate_callsign")
	return {"accepted": true, "error_code": &""}


static func _display_callsign_row(row: Dictionary) -> Dictionary:
	if row["custom_callsign"] != null:
		return {
			"accepted": true,
			"error_code": &"",
			"value": String(row["custom_callsign"]),
		}
	var parsed := HeroIdentity.parse_u64_hex(String(row["hero_id"]))
	if not parsed["accepted"]:
		return parsed
	return HeroNames.default_name(int(parsed["bits"]), int(row["name_version"]))


func begin_attempt(stage_input: Variant, selected_input: Variant) -> Dictionary:
	if has_pending_attempt():
		return _command_reject(&"attempt_pending")
	var prepared := _prepare_begin(stage_input, selected_input)
	if not prepared["accepted"]:
		return _command_reject(prepared["error_code"])
	return _command_mutation(
		&"begin_attempt", prepared["state"], prepared["events"],
		{"ticket": prepared["ticket"]}, [],
	)


func _prepare_begin(stage_input: Variant, selected_input: Variant) -> Dictionary:
	var stage := _validate_attempt_stage(stage_input)
	if not stage["accepted"]:
		return stage
	var normalized := _normalize_selected(selected_input, stage["stage_id"])
	if not normalized["accepted"]:
		return normalized
	var manifest_result := _manifest_for_ids(normalized["ids"])
	if not manifest_result["accepted"]:
		return manifest_result
	var ticket_result := _ticket_for_manifest(stage["stage_id"], manifest_result["manifest"])
	if not ticket_result["accepted"]:
		return ticket_result
	return _prepare_begin_state(stage["stage_id"], ticket_result["value"])


func _validate_attempt_stage(stage_input: Variant) -> Dictionary:
	if typeof(stage_input) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return _source_reject(&"unknown_campaign_stage")
	var stage_id := String(stage_input)
	if not _command_context["squad_sizes"].has(stage_id):
		return _source_reject(&"unknown_campaign_stage")
	if not _stage_unlocked(StringName(stage_id)):
		return _source_reject(&"stage_locked")
	if _next_attempt_id() >= CampaignCodec.U63_MAX:
		return _source_reject(&"attempt_counter_exhausted")
	return {"accepted": true, "error_code": &"", "stage_id": stage_id}


func _normalize_selected(selected_input: Variant, stage_id: String) -> Dictionary:
	if typeof(selected_input) != TYPE_ARRAY or (selected_input as Array).is_empty():
		return _source_reject(&"empty_squad")
	var selected: Array = selected_input
	if selected.size() > int(_command_context["squad_sizes"][stage_id]):
		return _source_reject(&"squad_too_large")
	var ids: Array[String] = []
	for raw_id: Variant in selected:
		if typeof(raw_id) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return _source_reject(&"unknown_hero")
		var hero_id := String(raw_id)
		if ids.has(hero_id):
			return _source_reject(&"duplicate_hero")
		ids.append(hero_id)
	return {"accepted": true, "error_code": &"", "ids": ids}


func _manifest_for_ids(ids: Array[String]) -> Dictionary:
	var manifest: Array[Dictionary] = []
	for hero_id: String in ids:
		var row := _hero_row(hero_id)
		if row.is_empty():
			return _source_reject(&"unknown_hero")
		if row["life_status"] != "ready":
			return _source_reject(&"hero_not_ready")
		manifest.append({
			"battle_id": hero_id,
			"operator_def_id": String(row["operator_def_id"]),
		})
	return {"accepted": true, "error_code": &"", "manifest": manifest}


func _ticket_for_manifest(stage_id: String, manifest: Array[Dictionary]) -> Dictionary:
	return CampaignBattleTicket.from_data({
		"campaign_uid": _campaign_uid(),
		"attempt_id": _next_attempt_id(),
		"stage_id": stage_id,
		"manifest": manifest,
		"manifest_hash": CanonicalJson.sha256_hex(manifest),
	})


func _prepare_begin_state(stage_id: String, ticket: CampaignBattleTicket) -> Dictionary:
	var next_data: Dictionary = _data.duplicate()
	next_data["next_attempt_id"] = _next_attempt_id() + 1
	next_data["save_revision"] = _save_revision() + 1
	var next_state := _state_from_data(next_data)
	if not next_state["accepted"]:
		return _source_reject(&"invalid_campaign_state")
	var state: Variant = next_state["value"]
	var events: Array[Dictionary] = [_event(&"campaign_attempt_started", {
		"attempt_id": ticket.attempt_id(),
		"stage_id": stage_id,
		"manifest_hash": ticket.manifest_hash(),
		"save_revision": next_data["save_revision"],
	})]
	return {
		"accepted": true,
		"error_code": &"",
		"state": state,
		"ticket": ticket,
		"events": events,
	}


func resolve_attempt(
	ticket_input: Variant,
	outcome_input: Variant,
	pending_input: Variant,
) -> Dictionary:
	var inputs := _prepare_resolution_inputs(ticket_input, outcome_input)
	if not inputs["accepted"]:
		return inputs["result"]
	if inputs["duplicate"]:
		return inputs["result"]
	var pending_check := _validate_pending(inputs["ticket"], inputs["outcome"], pending_input)
	if not pending_check["accepted"]:
		return _command_reject(pending_check["error_code"])
	return _derive_resolution(inputs["ticket"], inputs["outcome"], pending_check["pending"])


func _prepare_resolution_inputs(ticket_input: Variant, outcome_input: Variant) -> Dictionary:
	var ticket_result := _coerce_ticket(ticket_input)
	if not ticket_result["accepted"]:
		return _resolution_input_reject(ticket_result["error_code"])
	var outcome_result := _coerce_outcome(outcome_input)
	if not outcome_result["accepted"]:
		return _resolution_input_reject(outcome_result["error_code"])
	var ticket: CampaignBattleTicket = ticket_result["value"]
	var outcome: BattleOutcome = outcome_result["value"]
	if ticket.campaign_uid() != _campaign_uid() or outcome.campaign_uid() != _campaign_uid():
		return _resolution_input_reject(&"wrong_campaign")
	var duplicate := _duplicate_resolution(ticket, outcome)
	if duplicate["handled"]:
		return {
			"accepted": true,
			"duplicate": true,
			"result": duplicate["result"],
		}
	return {
		"accepted": true,
		"duplicate": false,
		"result": {},
		"ticket": ticket,
		"outcome": outcome,
	}


func _validate_pending(
	ticket: CampaignBattleTicket,
	outcome: BattleOutcome,
	pending_input: Variant,
) -> Dictionary:
	var capability := _validate_capability(pending_input)
	if not capability["accepted"]:
		return capability
	var pending: CampaignPendingAttempt = capability["pending"]
	var identity := _validate_resolution_identity(ticket, outcome, pending)
	if not identity["accepted"]:
		return identity
	return {"accepted": true, "error_code": &"", "pending": pending}


func _validate_capability(pending_input: Variant) -> Dictionary:
	var pending: CampaignPendingAttempt = (
		pending_input if pending_input is CampaignPendingAttempt else null
	)
	if pending == null or not _pending_control.is_valid():
		return _source_reject(&"no_pending_ticket")
	var authority: Dictionary = _pending_control.call(&"validate", pending)
	if not authority["accepted"]:
		return _source_reject(&"no_pending_ticket")
	if authority["status"] == CampaignPendingAttempt.RESERVED:
		return _source_reject(&"resolution_pending")
	if authority["status"] != CampaignPendingAttempt.ACTIVE:
		return _source_reject(&"no_pending_ticket")
	return {"accepted": true, "error_code": &"", "pending": pending}


func _validate_resolution_identity(
	ticket: CampaignBattleTicket,
	outcome: BattleOutcome,
	pending: CampaignPendingAttempt,
) -> Dictionary:
	if ticket.attempt_id() != outcome.attempt_id() or ticket.attempt_id() != pending.attempt_id():
		return _source_reject(&"wrong_attempt")
	if (
		not _certified_data_unchanged()
		or _validated_hash_hex() != pending.committed_strategic_hash()
	):
		return _source_reject(&"pending_state_mismatch")
	if ticket.stage_id() != outcome.stage_id() or ticket.stage_id() != pending.stage_id():
		return _source_reject(&"stage_mismatch")
	if (
		ticket.manifest_hash() != outcome.manifest_hash()
		or ticket.manifest_hash() != pending.manifest_hash()
	):
		return _source_reject(&"manifest_mismatch")
	if _next_resolution_index() >= CampaignCodec.U63_MAX:
		return _source_reject(&"resolution_counter_exhausted")
	return {"accepted": true, "error_code": &""}


func _derive_resolution(
	ticket: CampaignBattleTicket,
	outcome: BattleOutcome,
	pending: CampaignPendingAttempt,
) -> Dictionary:
	var derived := CampaignHash._derive_certified_transaction(
		ticket.data_copy(), outcome.data_copy(), _data, _context,
	)
	if not derived["accepted"]:
		return _command_reject(derived["error_code"])
	var next_state := _state_from_data(derived["state_after"])
	var receipt_result := CampaignResolution.from_data(derived["resolution"])
	if not next_state["accepted"] or not receipt_result["accepted"]:
		return _command_reject(&"invalid_campaign_state")
	if not _pending_control.call(&"reserve", pending)["accepted"]:
		return _command_reject(&"resolution_pending")
	var finalize := func(action: StringName) -> bool:
		return _pending_control.call(action, pending)["accepted"]
	var receipt: CampaignResolution = receipt_result["value"]
	var command := _command_mutation(
		&"resolve_attempt", next_state["value"],
		_resolution_events(receipt, next_state["value"]),
		{"receipt": receipt, "fresh": true}, [], pending, finalize,
	)
	if not command["accepted"]:
		finalize.call(&"release")
	return command


static func _resolution_input_reject(code: StringName) -> Dictionary:
	return {"accepted": false, "duplicate": false, "result": _command_reject(code)}


func _recruit_source(offer_id: String) -> Dictionary:
	var paid: Dictionary = _offer(offer_id)
	if not paid.is_empty():
		return _paid_source(offer_id, paid)
	return _recovery_source(offer_id)


static func _paid_source(offer_id: String, paid: Dictionary) -> Dictionary:
	if bool(paid["consumed"]):
		return _source_reject(&"offer_consumed")
	return {
		"accepted": true,
		"source": &"contract",
		"source_id": offer_id,
		"operator_def_id": paid["operator_def_id"],
		"cost": paid["cost"],
	}


func _recovery_source(offer_id: String) -> Dictionary:
	var parsed := _parse_recovery_offer(offer_id)
	if not parsed["accepted"]:
		return parsed
	var offers_result := recovery_offers(parsed["stage_id"])
	if not offers_result["accepted"]:
		return _source_reject(offers_result["error_code"])
	for row: Dictionary in offers_result["offers"]:
		if row["offer_id"] == offer_id:
			return {
				"accepted": true,
				"source": &"recovery",
				"source_id": parsed["stage_id"],
				"operator_def_id": parsed["operator_id"],
				"cost": 0,
			}
	return _source_reject(&"recovery_not_available")


func _parse_recovery_offer(offer_id: String) -> Dictionary:
	if not offer_id.begins_with("recovery:"):
		return _source_reject(&"unknown_offer")
	var parts := offer_id.split(":", false)
	if parts.size() != 3:
		return _source_reject(&"unknown_offer")
	var stage_id := String(parts[1])
	var operator_id := String(parts[2])
	if not _command_context["recovery_rosters"].has(stage_id):
		return _source_reject(&"unknown_offer")
	if not (_command_context["recovery_rosters"][stage_id] as Array).has(operator_id):
		return _source_reject(&"unknown_offer")
	return {
		"accepted": true,
		"error_code": &"",
		"stage_id": stage_id,
		"operator_id": operator_id,
	}


func _state_from_data(data: Dictionary) -> Dictionary:
	return _certified_restore_callable.call(data)


func _command_mutation(
	operation_name: StringName,
	next_state: Variant,
	staged_events: Array[Dictionary],
	result: Dictionary,
	immediate_events: Array[Dictionary],
	pending: CampaignPendingAttempt = null,
	pending_authority: Callable = Callable(),
) -> Dictionary:
	var created := CampaignMutation._create(
		operation_name, self, next_state, staged_events, result,
		pending, pending_authority,
	)
	if not created["accepted"]:
		return _command_reject(created["error_code"])
	return {
		"accepted": true,
		"error_code": &"",
		"events": immediate_events,
		"payload": {"mutation": created["value"]},
	}


func _duplicate_resolution(
	ticket: CampaignBattleTicket,
	outcome: BattleOutcome,
) -> Dictionary:
	var last: Variant = _data["last_resolution"]
	if last == null or int(last["attempt_id"]) != ticket.attempt_id():
		return {"handled": false, "result": {}}
	if String(last["outcome_hash"]) != outcome.outcome_hash():
		return {"handled": true, "result": _command_reject(&"resolved_attempt_mismatch")}
	var receipt_result := CampaignResolution.from_data(last)
	if not receipt_result["accepted"]:
		return {"handled": true, "result": _command_reject(&"invalid_campaign_state")}
	var event := _event(&"resolution_duplicate_observed", {
		"attempt_id": ticket.attempt_id(),
		"outcome_hash": outcome.outcome_hash(),
	})
	return {
		"handled": true,
		"result": {
			"accepted": true,
			"error_code": &"",
			"events": [event],
			"payload": {"receipt": receipt_result["value"], "fresh": false},
		},
	}


func _resolution_events(
	receipt: CampaignResolution,
	next_state: Variant,
) -> Array[Dictionary]:
	var events: Array[Dictionary] = [_event(&"campaign_resolution_committed", {
		"resolution_index": receipt.resolution_index(),
		"attempt_id": receipt.attempt_id(),
		"stage_id": String(receipt.stage_id()),
		"outcome_hash": receipt.outcome_hash(),
		"save_revision": next_state.save_revision(),
	})]
	for hero_id: String in receipt.dead_hero_ids():
		var hero: HeroState = next_state.roster().by_id(hero_id)
		var death: Dictionary = hero.death()
		var payload := {
			"hero_id": hero_id,
			"resolution_index": receipt.resolution_index(),
			"stage_id": String(receipt.stage_id()),
			"terminal_reason": String(receipt.terminal_reason()),
			"terminal_tick": death["terminal_tick"],
		}
		events.append(_event(&"hero_fallen", payload.duplicate(true)))
		events.append(_event(&"permanent_death_committed", payload.duplicate(true)))
	return events


static func _coerce_ticket(value: Variant) -> Dictionary:
	if value is CampaignBattleTicket:
		return CampaignBattleTicket.from_data(value.data_copy())
	if typeof(value) != TYPE_DICTIONARY:
		return {"accepted": false, "error_code": &"invalid_ticket", "value": null}
	return CampaignBattleTicket.from_data(value)


static func _coerce_outcome(value: Variant) -> Dictionary:
	if value is BattleOutcome:
		return BattleOutcome.from_data(value.data_copy())
	if typeof(value) != TYPE_DICTIONARY:
		return {"accepted": false, "error_code": &"invalid_outcome", "value": null}
	return BattleOutcome.from_data(value)


static func _trim_callsign(value: String) -> String:
	var first := 0
	var last := value.length()
	while first < last and value.substr(first, 1) in [" ", "\t"]:
		first += 1
	while last > first and value.substr(last - 1, 1) in [" ", "\t"]:
		last -= 1
	return value.substr(first, last - first)


static func _copy_encoded(value: Dictionary) -> Dictionary:
	var result := value.duplicate()
	if result.get("value") is Dictionary or result.get("value") is Array:
		result["value"] = result["value"].duplicate(true)
	if result.get("bytes") is PackedByteArray:
		result["bytes"] = (result["bytes"] as PackedByteArray).duplicate()
	return result


static func _encode_normalized(value: Variant) -> Dictionary:
	var source := CanonicalJson.text(value)
	return {
		"accepted": true,
		"error_code": &"",
		"value": value,
		"text": source,
		"bytes": source.to_utf8_buffer(),
		"sha256": CanonicalJson.sha256_text(source),
	}


static func _valid_callsign(value: String) -> bool:
	if value.is_empty():
		return false
	var count := 0
	for character: String in value:
		var codepoint := character.unicode_at(0)
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159):
			return false
		count += 1
	return count <= 20


static func _event(name: StringName, data: Dictionary) -> Dictionary:
	return {"name": name, "data": data}


static func _offer_reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "offers": []}


static func _source_reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code}


static func _command_reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "events": [], "payload": {}}


static func _recruit_reject(
	offer_id: String,
	code: StringName,
	attempted: Dictionary,
) -> Dictionary:
	var rejected := _event(&"recruit_rejected", {
		"offer_id": offer_id,
		"error_code": String(code),
	})
	return {
		"accepted": false,
		"error_code": code,
		"events": [attempted, rejected],
		"payload": {},
	}


static func _rename_reject(hero_id: String, code: StringName) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"events": [_event(&"rename_rejected", {
			"hero_id": hero_id,
			"error_code": String(code),
		})],
		"payload": {},
	}
