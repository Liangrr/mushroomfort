class_name CampaignRuntimeAuthority
extends RefCounted

## Runtime-only coordinator for the production CampaignSave slot. It never
## applies strategic rules itself: commands build CampaignMutations, SaveStore
## commits exact bytes, and only the independently restored state is published.

const CampaignStateV3Script := preload("res://sim/campaign_state_v3.gd")
const CampaignSaveStoreScript := preload("res://sim/campaign_save_store.gd")
const CampaignV3CodecScript := preload("res://sim/campaign_v3_codec.gd")
const CommandHistoryScript := preload("res://sim/campaign_v3_command_history.gd")
const CommandsScript := preload("res://sim/campaign_v3_commands.gd")
const CampaignMutationScript := preload("res://sim/campaign_mutation.gd")


static func load_or_create(seed_value: int, context: Dictionary) -> Dictionary:
	if context.is_empty():
		return _reject(&"missing_validation_context")
	var bootstrap := CampaignStateV3Script.create(seed_value, 1, context)
	if not bootstrap["accepted"]:
		return _reject(bootstrap["error_code"])
	var store_result := CampaignSaveStoreScript.create_production(bootstrap["value"])
	if not store_result["accepted"]:
		return _reject(store_result["error_code"])
	var store: Variant = store_result["value"]
	var loaded: Dictionary = store.load()
	if loaded["accepted"]:
		var state: Variant = loaded["state"]
		if CommandHistoryScript.can_append(state.data_copy(), context):
			return {"accepted": true, "error_code": &"", "state": state, "store": store}
		# Legacy/pre-command bytes remain valid migration inputs, but cannot
		# authenticate new commands. Roll them into a fresh Recruit generation.
		return start_new(seed_value, context)
	if loaded["error_code"] == &"slot_corrupt":
		var quarantined: Dictionary = store.quarantine_invalid_slot()
		if not quarantined["accepted"]:
			return _reject(quarantined["error_code"])
		return start_new(seed_value, context)
	if loaded["error_code"] != &"slot_missing":
		return _reject(loaded["error_code"])
	return start_new(seed_value, context)


static func start_new(seed_value: int, context: Dictionary) -> Dictionary:
	if context.is_empty():
		return _reject(&"missing_validation_context")
	var bootstrap := CampaignStateV3Script.create(seed_value, 1, context)
	if not bootstrap["accepted"]:
		return _reject(bootstrap["error_code"])
	var store_result := CampaignSaveStoreScript.create_production(bootstrap["value"])
	if not store_result["accepted"]:
		return _reject(store_result["error_code"])
	var store: Variant = store_result["value"]
	var existing: Dictionary = store.load()
	var generation := 1
	var expected_preimage := ""
	if existing["accepted"]:
		var prior: Variant = existing["state"]
		if prior.campaign_generation() >= CampaignV3CodecScript.U63_MAX:
			return _reject(&"generation_counter_exhausted")
		generation = prior.campaign_generation() + 1
		expected_preimage = prior._validated_save_text()
	elif existing["error_code"] != &"slot_missing":
		return _reject(existing["error_code"])
	var fresh := CampaignStateV3Script.create(seed_value, generation, context)
	if not fresh["accepted"]:
		return _reject(fresh["error_code"])
	var saved: Dictionary = store.save(expected_preimage, fresh["value"])
	if saved["status"] != CampaignSaveStoreScript.COMMITTED:
		return _reject(saved["error_code"])
	var authority: Dictionary = store._consume_commit_authority()
	var state: Variant = authority.get("state")
	if state == null or state._validated_save_text() != fresh["value"]._validated_save_text():
		return _reject(&"store_integrity_failure")
	return {
		"accepted": true,
		"error_code": &"",
		"state": state,
		"store": store,
	}


static func commit(command: Dictionary, store: Variant) -> Dictionary:
	if not command.get("accepted", false):
		return _reject(command.get("error_code", &"invalid_command"))
	var payload: Dictionary = command.get("payload", {})
	var mutation: Variant = payload.get("mutation")
	if mutation == null:
		return _publish_duplicate(command, store)
	if store == null:
		return _reject(&"invalid_runtime_mutation")
	var committed: Dictionary = mutation.retry_save(store)
	if not committed["accepted"]:
		return {
			"accepted": false,
			"error_code": committed["error_code"],
			"retryable": mutation.status() == CampaignMutationScript.PENDING,
			"mutation": mutation,
		}
	return {
		"accepted": true,
		"error_code": &"",
		"retryable": false,
		"mutation": null,
		"state": committed["payload"]["state"],
		"result": committed["payload"]["result"].duplicate(true),
		"events": (committed["events"] as Array).duplicate(true),
	}


static func _publish_duplicate(command: Dictionary, store: Variant) -> Dictionary:
	var result: Dictionary = command.get("payload", {})
	if (
		store == null
		or not store.has_method("_is_authority_store")
		or not store._is_authority_store()
		or result.get("fresh", true) != false
		or not result.has("receipt_bytes")
	):
		return _reject(&"invalid_runtime_mutation")
	var loaded: Dictionary = store.load()
	if not loaded["accepted"]:
		return _reject(loaded["error_code"])
	var state: Variant = loaded["state"]
	var durable := false
	for record: Dictionary in state.data_copy()["command_receipts"]:
		var expected: Dictionary = CommandsScript.duplicate_result(record)
		if (
			expected["payload"] == result
			and expected["events"] == command.get("events", [])
		):
			durable = true
			break
	if not durable:
		return _reject(&"duplicate_authority_mismatch")
	return {
		"accepted": true,
		"error_code": &"",
		"retryable": false,
		"mutation": null,
		"state": state,
		"result": result.duplicate(true),
		"events": (command.get("events", []) as Array).duplicate(true),
	}


static func retry(mutation: Variant, store: Variant) -> Dictionary:
	if mutation == null or store == null:
		return _reject(&"invalid_runtime_mutation")
	var committed: Dictionary = mutation.retry_save(store)
	if not committed["accepted"]:
		return {
			"accepted": false,
			"error_code": committed["error_code"],
			"retryable": mutation.status() == CampaignMutationScript.PENDING,
			"mutation": mutation,
		}
	return {
		"accepted": true,
		"error_code": &"",
		"retryable": false,
		"mutation": null,
		"state": committed["payload"]["state"],
		"result": committed["payload"]["result"].duplicate(true),
		"events": (committed["events"] as Array).duplicate(true),
	}


static func _reject(code: StringName) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"retryable": false,
		"mutation": null,
	}
