class_name CampaignMutation
extends RefCounted

## One validated prospective strategic mutation. Commands are never reapplied;
## Retry repeats only the exact expected-preimage SaveStore CAS.

const PENDING := &"pending"
const COMMITTED := &"committed"
const ABANDONED := &"abandoned"
const BLOCKED := &"blocked"
const SAVE_STORE_SCRIPT := preload("res://sim/campaign_save_store.gd")
const BATTLE_TICKET_PATH := "res://sim/campaign_battle_ticket.gd"

var _operation: StringName
var _status := PENDING
var _pre_state: Variant
var _prospective_state: Variant
var _pre_save := ""
var _prospective_save := ""
var _pre_hash := ""
var _prospective_hash := ""
var _staged_events: Array[Dictionary] = []
var _result: Dictionary = {}
var _pending_attempt: Variant
var _pending_authority: Callable


static func _create(
	operation_name: StringName,
	pre_state: Variant,
	prospective_state: Variant,
	staged_events: Array[Dictionary],
	result: Dictionary,
	pending_attempt: Variant = null,
	pending_authority: Callable = Callable(),
) -> Dictionary:
	var mutation: Variant = (load("res://sim/campaign_mutation.gd") as GDScript).new()
	mutation._operation = operation_name
	mutation._pre_state = pre_state
	mutation._prospective_state = prospective_state
	mutation._pre_save = pre_state._validated_save_text()
	mutation._prospective_save = prospective_state._validated_save_text()
	mutation._staged_events = staged_events.duplicate(true)
	mutation._result = result.duplicate(true)
	mutation._pending_attempt = pending_attempt
	mutation._pending_authority = pending_authority
	return {"accepted": true, "error_code": &"", "value": mutation}


func operation() -> StringName:
	return _operation


func status() -> StringName:
	return _status


func pre_save_text() -> String:
	return _pre_save


func prospective_save_text() -> String:
	return _prospective_save


func pre_hash() -> String:
	if _pre_hash.is_empty():
		_pre_hash = _pre_state._validated_hash_hex()
	return _pre_hash


func prospective_hash() -> String:
	if _prospective_hash.is_empty():
		_prospective_hash = _prospective_state._validated_hash_hex()
	return _prospective_hash


func retry_save(store: Variant) -> Dictionary:
	if _status != PENDING or store == null:
		return _reject(&"mutation_not_pending")
	if store.get_script() != SAVE_STORE_SCRIPT or not store._is_authority_store():
		return _reject(&"invalid_save_store")
	var save_result: Dictionary = store.save(_pre_save, _prospective_state)
	var save_code: StringName = save_result["error_code"]
	var events: Array[Dictionary] = [
		_event(&"autosave_attempted", _save_payload(&"")),
	]
	match save_result["status"]:
		SAVE_STORE_SCRIPT.COMMITTED:
			var authority: Dictionary = store._consume_commit_authority()
			var authoritative_state: Variant = authority.get("state")
			var valid_authority: bool = (
				authoritative_state != null
				and authoritative_state.has_method("_validated_save_text")
				and authoritative_state != _prospective_state
				and authoritative_state._validated_save_text() == _prospective_save
			)
			if not valid_authority:
				_status = BLOCKED
				events.append(_event(
					&"autosave_failed", _save_payload(&"store_integrity_failure"),
				))
				return _failed(
					&"store_integrity_failure", events, {"status": String(BLOCKED)},
				)
			_status = COMMITTED
			_finalize_capability(true, authoritative_state, authority)
			events.append(_event(&"autosave_succeeded", _save_payload(&"")))
			events.append_array(_staged_events.duplicate(true))
			return _accepted(events, _committed_payload(authoritative_state))
		SAVE_STORE_SCRIPT.RETRYABLE:
			events.append(_event(&"autosave_failed", _save_payload(save_code)))
			return _failed(save_code, events, {"status": String(PENDING)})
		_:
			_status = BLOCKED
			events.append(_event(&"autosave_failed", _save_payload(&"store_integrity_failure")))
			return _failed(
				&"store_integrity_failure", events, {"status": String(BLOCKED)},
			)


func abandon() -> Dictionary:
	if _status != PENDING:
		return _reject(&"mutation_not_pending")
	var restored: Dictionary = _pre_state.restored_copy_without_pending()
	if not restored["accepted"]:
		_status = BLOCKED
		return _reject(&"mutation_restore_mismatch")
	var state: Variant = restored["value"]
	var restored_hash: Dictionary = state.strategic_hash()
	if not restored_hash["accepted"] or restored_hash["hex"] != pre_hash():
		_status = BLOCKED
		return _reject(&"mutation_restore_mismatch")
	_status = ABANDONED
	_finalize_capability(false, state, {})
	var result := {}
	if _operation == &"resolve_attempt" and _pending_attempt != null:
		result = {"aborted_attempt_id": _pending_attempt.attempt_id()}
	var payload := {"status": String(ABANDONED), "state": state, "result": result}
	var event_data := {
		"operation": String(_operation),
		"restored_revision": state.save_revision(),
	}
	return _accepted([_event(&"strategic_mutation_abandoned", event_data)], payload)


func _finalize_capability(
	committed: bool,
	authoritative_state: Variant,
	authority: Dictionary,
) -> void:
	if _pending_attempt == null:
		if (
			_operation == &"begin_attempt" and committed
				and _is_legacy_ticket(_result.get("ticket"))
			):
			var ticket: Variant = _result["ticket"]
			var issue: Callable = authority.get("pending_issue", Callable())
			if issue.is_valid():
				var issued: Dictionary = issue.call(
					ticket, authoritative_state._validated_hash_hex(),
				)
				if issued["accepted"]:
					_pending_attempt = issued["pending"]
		return
	if _operation == &"resolve_attempt" and _pending_authority.is_valid():
		_pending_authority.call(&"resolve" if committed else &"abort")


func _committed_payload(committed_state: Variant) -> Dictionary:
	var result := _result.duplicate(true)
	if _operation == &"begin_attempt" and _is_legacy_ticket(_result.get("ticket")):
		result["pending_attempt"] = _pending_attempt
	return {
		"status": String(COMMITTED),
		"state": committed_state,
		"result": result,
	}


static func _is_legacy_ticket(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and value.get_script() == load(BATTLE_TICKET_PATH)


func _save_payload(code: StringName) -> Dictionary:
	return {
		"operation": String(_operation),
		"save_revision": _prospective_state.save_revision(),
		"error_code": String(code),
	}


static func _event(name: StringName, data: Dictionary) -> Dictionary:
	return {"name": name, "data": data}


static func _accepted(events: Array[Dictionary], payload: Dictionary) -> Dictionary:
	return {"accepted": true, "error_code": &"", "events": events, "payload": payload}


static func _failed(
	code: StringName,
	events: Array[Dictionary],
	payload: Dictionary,
) -> Dictionary:
	return {"accepted": false, "error_code": code, "events": events, "payload": payload}


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "events": [], "payload": {}}
