class_name CampaignSaveStore
extends RefCounted

## Atomic CampaignSave storage with legacy admission and canonical v2/v3 promotion.
## The store owns bytes and winner selection;
## CampaignState owns codec context through the injected restore factory.

const MAIN := &"main"
const BAK := &"bak"
const TMP := &"tmp"
const NONE := &"none"
const COMMITTED := &"committed"
const RETRYABLE := &"retryable"
const INDETERMINATE := &"indeterminate"
const FALLBACK := &"fallback"
const PRODUCTION_SLOT := "user://campaign_v1.json"
const QUARANTINE_SUFFIX := ".invalid"
const CAMPAIGN_CODEC_SCRIPT := preload("res://sim/campaign_codec.gd")
const CANONICAL_JSON_SCRIPT := preload("res://sim/canonical_json.gd")
const FILE_OPS_SCRIPT := preload("res://sim/campaign_file_ops.gd")
const TEST_RUN_GUARD_SCRIPT := preload("res://autoloads/test_run_guard.gd")

static var _authority_store_ref: WeakRef

var _main_path := ""
var _tmp_path := ""
var _bak_path := ""
var _restore_factory: Callable
var _ops: Variant
var _committed_authority: Dictionary = {}


static func create(
	slot_path: String,
	restore_factory: Callable,
	file_ops: Variant,
) -> Dictionary:
	var valid := (
		not slot_path.is_empty() and slot_path.ends_with(".json")
		and restore_factory.is_valid() and file_ops != null
	)
	if not valid:
		return {"accepted": false, "error_code": &"invalid_store_config", "value": null}
	var store: Variant = (load("res://sim/campaign_save_store.gd") as GDScript).new()
	store._main_path = slot_path
	store._tmp_path = slot_path.get_basename() + ".tmp"
	store._bak_path = slot_path.get_basename() + ".bak"
	store._restore_factory = restore_factory
	store._ops = file_ops
	return {"accepted": true, "error_code": &"", "value": store}


static func create_production(state: Variant) -> Dictionary:
	if (
		TEST_RUN_GUARD_SCRIPT.is_test_invocation()
		and not TEST_RUN_GUARD_SCRIPT.isolated_test_user_data_active()
	):
		return {
			"accepted": false,
			"error_code": &"test_user_data_not_isolated",
			"value": null,
		}
	if state == null or not state.has_method("_authority_restore_factory"):
		return {"accepted": false, "error_code": &"invalid_store_config", "value": null}
	var created := create(
		PRODUCTION_SLOT, state._authority_restore_factory(), FILE_OPS_SCRIPT.new(),
	)
	if created["accepted"]:
		_authority_store_ref = weakref(created["value"])
	return created


## Preserve unreadable production bytes beside the live slot, then clear the
## canonical paths so startup can create a fresh authority. This is only called
## after load() proves that no main/backup/temp candidate is restorable.
func quarantine_invalid_slot() -> Dictionary:
	var archived := false
	for path: String in [_main_path, _bak_path, _tmp_path]:
		if not _ops.file_exists(path):
			continue
		var quarantine_path := path + QUARANTINE_SUFFIX
		if _ops.file_exists(quarantine_path):
			var removed: Dictionary = _ops.remove_path(quarantine_path)
			if not removed["accepted"]:
				return {"accepted": false, "error_code": &"store_cleanup_failed"}
		var renamed: Dictionary = _ops.rename_path(path, quarantine_path)
		if not renamed["accepted"]:
			return {"accepted": false, "error_code": &"store_rotate_failed"}
		archived = true
	return {
		"accepted": archived,
		"error_code": &"" if archived else &"slot_missing",
	}


func save(expected_pre_text: String, prospective_state: Variant) -> Dictionary:
	_committed_authority = {}
	var revision: int = prospective_state.save_revision() if prospective_state != null else 0
	if prospective_state == null:
		return _save_result(INDETERMINATE, &"store_integrity_failure", revision)
	var prospective: String = prospective_state._validated_save_text()
	var prospective_bytes := prospective.to_utf8_buffer()
	var fast := _fast_precondition(expected_pre_text, prospective_bytes)
	if fast["status"] == INDETERMINATE:
		return _save_result(INDETERMINATE, fast["error_code"], revision)
	if fast["status"] == COMMITTED:
		_committed_authority = _authority_from_certified(prospective_state, prospective)
		if not _is_authority_store() or not _committed_authority.is_empty():
			return _save_result(COMMITTED, &"", revision)
	if fast["status"] == &"proceed":
		return _perform_save(
			expected_pre_text,
			prospective,
			prospective_bytes,
			prospective_state,
			revision,
			fast["preimage_bytes"],
		)
	# Recovery artifacts, a mismatched preimage, or an unavailable certified
	# copy retain the exhaustive semantic winner-selection path.
	var inspected := _inspect_all()
	if not inspected["accepted"]:
		return _save_result(INDETERMINATE, &"store_integrity_failure", revision)
	var winner := _select_winner(inspected["candidates"])
	var precondition := _save_precondition(
		inspected["candidates"], winner, expected_pre_text, prospective,
	)
	if precondition["status"] != &"proceed":
		if precondition["status"] == COMMITTED:
			_committed_authority = _authority_from(winner)
		return _save_result(precondition["status"], precondition["error_code"], revision)
	var preimage_bytes := PackedByteArray()
	if winner["accepted"]:
		preimage_bytes = (winner["bytes"] as PackedByteArray).duplicate()
	return _perform_save(
		expected_pre_text, prospective, prospective_bytes, prospective_state, revision,
		preimage_bytes,
	)


func load() -> Dictionary:
	var inspected := _inspect_all()
	if not inspected["accepted"]:
		return _load_reject(&"store_read_failed")
	var candidates: Dictionary = inspected["candidates"]
	var winner := _select_winner(candidates)
	if not winner["accepted"]:
		var code: StringName = &"slot_missing" if not _any_exists(candidates) else &"slot_corrupt"
		return _load_reject(code)
	var source: StringName = winner["source"]
	_cleanup_loaded_winner(source)
	if winner["migrated"]:
		var migrated := save(winner["text"], winner["state"])
		if migrated["status"] != COMMITTED:
			_consume_commit_authority()
			return _load_reject(&"store_migration_failed")
		var authority := _consume_commit_authority()
		if _is_authority_state(authority.get("state")):
			winner["state"] = authority["state"]
	return {
		"accepted": true,
		"error_code": &"",
		"state": winner["state"],
		"source": source,
	}


func _consume_commit_authority() -> Dictionary:
	var authority := _committed_authority
	_committed_authority = {}
	return authority


func _is_authority_store() -> bool:
	return (
		_authority_store_ref != null and _authority_store_ref.get_ref() == self
		and _main_path == PRODUCTION_SLOT
		and _ops != null and _ops.get_script() == FILE_OPS_SCRIPT
	)


## Clean in-session commits have no recovery artifacts. Compare the durable
## preimage bytes directly and reserve semantic parsing/replay for load,
## recovery, conflicts, and migrations.
func _fast_precondition(
	expected: String,
	prospective_bytes: PackedByteArray,
) -> Dictionary:
	if _ops.file_exists(_bak_path) or _ops.file_exists(_tmp_path):
		return {"status": FALLBACK, "error_code": &"", "preimage_bytes": PackedByteArray()}
	if not _ops.file_exists(_main_path):
		return {
			"status": &"proceed" if expected.is_empty() else FALLBACK,
			"error_code": &"",
			"preimage_bytes": PackedByteArray(),
		}
	var current := _read_exact_bytes(_main_path)
	if not current["accepted"]:
		return {
			"status": INDETERMINATE,
			"error_code": &"store_integrity_failure",
			"preimage_bytes": PackedByteArray(),
		}
	var current_bytes: PackedByteArray = current["bytes"]
	if current_bytes == prospective_bytes:
		return {
			"status": COMMITTED,
			"error_code": &"",
			"preimage_bytes": current_bytes.duplicate(),
		}
	if not expected.is_empty() and current_bytes == expected.to_utf8_buffer():
		return {
			"status": &"proceed",
			"error_code": &"",
			"preimage_bytes": current_bytes.duplicate(),
		}
	return {"status": FALLBACK, "error_code": &"", "preimage_bytes": PackedByteArray()}


func _read_exact_bytes(path: String) -> Dictionary:
	if not _ops.file_exists(path):
		return {"accepted": false, "error_code": &"file_missing", "bytes": PackedByteArray()}
	var read: Dictionary = _ops.read_bytes(path)
	if not read.get("accepted", false) or not (read.get("bytes") is PackedByteArray):
		return {"accepted": false, "error_code": &"file_read_failed", "bytes": PackedByteArray()}
	return {
		"accepted": true,
		"error_code": &"",
		"bytes": (read["bytes"] as PackedByteArray).duplicate(),
	}


func _perform_save(
	expected: String,
	prospective: String,
	prospective_bytes: PackedByteArray,
	prospective_state: Variant,
	revision: int,
	preimage_bytes: PackedByteArray,
) -> Dictionary:
	var staged := _write_validated_tmp(prospective_bytes)
	if not staged["accepted"]:
		return _failed_save(
			staged["error_code"], expected, prospective, revision, false, preimage_bytes,
		)
	var promoted := _promote_tmp()
	if not promoted["accepted"]:
		return _failed_save(
			promoted["error_code"], expected, prospective, revision,
			promoted["rollback_failed"], preimage_bytes,
		)
	var committed := _validate_committed_main(
		prospective, prospective_bytes, prospective_state,
	)
	var main_error: StringName = committed["error_code"]
	if not main_error.is_empty():
		var rollback_failed := _rollback_main(promoted["had_main"])
		return _failed_save(
			main_error, expected, prospective, revision, rollback_failed, preimage_bytes,
		)
	_committed_authority = _authority_from(committed)
	_remove_if_exists(_bak_path)
	return _save_result(COMMITTED, &"", revision)


func _write_validated_tmp(
	prospective_bytes: PackedByteArray,
) -> Dictionary:
	var write: Dictionary = _ops.write_bytes(_tmp_path, prospective_bytes)
	if not write["accepted"]:
		return _stage_reject(&"store_write_failed")
	var tmp := _read_exact_bytes(_tmp_path)
	if not tmp["accepted"]:
		return _stage_reject(&"store_read_failed")
	if tmp["bytes"] != prospective_bytes:
		return _stage_reject(&"store_validate_failed")
	return {"accepted": true, "error_code": &""}


func _promote_tmp() -> Dictionary:
	if _ops.file_exists(_bak_path):
		var removed: Dictionary = _ops.remove_path(_bak_path)
		if not removed["accepted"]:
			return _promotion_reject(&"store_cleanup_failed", false, false)
	var had_main: bool = _ops.file_exists(_main_path)
	if had_main:
		var rotated: Dictionary = _ops.rename_path(_main_path, _bak_path)
		if not rotated["accepted"]:
			return _promotion_reject(&"store_rotate_failed", false, had_main)
	var promoted: Dictionary = _ops.rename_path(_tmp_path, _main_path)
	if not promoted["accepted"]:
		return _promotion_reject(
			&"store_promote_failed", _rollback_main(had_main), had_main,
		)
	return {
		"accepted": true,
		"error_code": &"",
		"rollback_failed": false,
		"had_main": had_main,
	}


func _validate_committed_main(
	prospective: String,
	prospective_bytes: PackedByteArray,
	prospective_state: Variant,
) -> Dictionary:
	var main := _read_exact_bytes(_main_path)
	if not main["accepted"]:
		return {"error_code": &"store_read_failed", "state": null}
	if main["bytes"] != prospective_bytes:
		return {"error_code": &"store_validate_failed", "state": null}
	var authority := _authority_from_certified(prospective_state, prospective)
	if _is_authority_store() and authority.is_empty():
		return {"error_code": &"store_integrity_failure", "state": null}
	return {
		"error_code": &"", "state": authority.get("state"),
		"pending_issue": authority.get("pending_issue", Callable()),
	}


static func _stage_reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code}


static func _promotion_reject(
	code: StringName,
	rollback_failed: bool,
	had_main: bool,
) -> Dictionary:
	return {
		"accepted": false,
		"error_code": code,
		"rollback_failed": rollback_failed,
		"had_main": had_main,
	}


func _save_precondition(
	candidates: Dictionary,
	winner: Dictionary,
	expected: String,
	prospective: String,
) -> Dictionary:
	if winner["accepted"] and winner["text"] == prospective:
		return {"status": COMMITTED, "error_code": &""}
	var exact_pre: bool = winner["accepted"] and winner["text"] == expected
	var empty_pre: bool = expected.is_empty() and not _any_exists(candidates)
	if exact_pre or empty_pre:
		return {"status": &"proceed", "error_code": &""}
	return {"status": INDETERMINATE, "error_code": &"store_integrity_failure"}


func _failed_save(
	trigger: StringName,
	expected: String,
	prospective: String,
	revision: int,
	rollback_failed: bool,
	preimage_bytes: PackedByteArray,
) -> Dictionary:
	var inspected := _inspect_all()
	if not inspected["accepted"]:
		return _save_result(INDETERMINATE, &"store_integrity_failure", revision)
	var winner := _select_winner(inspected["candidates"])
	if winner["accepted"] and winner["text"] == prospective:
		_committed_authority = _authority_from(winner)
		return _save_result(COMMITTED, &"", revision)
	var restored_preimage := _restore_preimage(expected, preimage_bytes)
	rollback_failed = rollback_failed or not restored_preimage
	inspected = _inspect_all()
	if not inspected["accepted"]:
		return _save_result(INDETERMINATE, &"store_integrity_failure", revision)
	winner = _select_winner(inspected["candidates"])
	var preimage_wins: bool = winner["accepted"] and winner["text"] == expected
	var empty_pre_wins: bool = expected.is_empty() and not _any_exists(inspected["candidates"])
	if preimage_wins or empty_pre_wins:
		var code := &"store_restore_failed" if rollback_failed else trigger
		return _save_result(RETRYABLE, code, revision)
	return _save_result(INDETERMINATE, &"store_integrity_failure", revision)


func _restore_preimage(expected: String, bytes: PackedByteArray) -> bool:
	if expected.is_empty():
		var failed := false
		for path: String in [_main_path, _bak_path, _tmp_path]:
			if _ops.file_exists(path):
					failed = not _ops.remove_path(path)["accepted"] or failed
		return not failed
	var bak := _read_candidate(_bak_path, BAK)
	if (
		not bak["read_error"] and bak["valid"]
		and bak["text"] == expected and bak["bytes"] == bytes
	):
		return _ops.rename_path(_bak_path, _main_path)["accepted"]
	var write: Dictionary = _ops.write_bytes(_main_path, bytes)
	if not write["accepted"]:
		return false
	var restored := _read_candidate(_main_path, MAIN)
	return (
		not restored["read_error"]
		and restored["valid"]
		and restored["text"] == expected
		and restored["bytes"] == bytes
	)


func _rollback_main(had_main: bool) -> bool:
	var failed := false
	if _ops.file_exists(_main_path):
		var removed: Dictionary = _ops.remove_path(_main_path)
		failed = not removed["accepted"]
	if had_main and _ops.file_exists(_bak_path) and not _ops.file_exists(_main_path):
		var restored: Dictionary = _ops.rename_path(_bak_path, _main_path)
		failed = failed or not restored["accepted"]
	return failed


func _inspect_all() -> Dictionary:
	var candidates := {
		MAIN: _read_candidate(_main_path, MAIN),
		BAK: _read_candidate(_bak_path, BAK),
		TMP: _read_candidate(_tmp_path, TMP),
	}
	for candidate: Dictionary in candidates.values():
		if candidate["read_error"]:
			return {"accepted": false, "error_code": &"store_read_failed", "candidates": {}}
	return {"accepted": true, "error_code": &"", "candidates": candidates}


func _read_candidate(path: String, source: StringName) -> Dictionary:
	var candidate := {
		"source": source,
		"path": path,
		"exists": _ops.file_exists(path),
		"read_error": false,
		"text": "",
		"bytes": PackedByteArray(),
		"canonical_text": "",
		"canonical_bytes": PackedByteArray(),
		"migrated": false,
		"valid": false,
		"state": null,
		"pending_issue": Callable(),
		"header": null,
	}
	if not candidate["exists"]:
		return candidate
	var read: Dictionary = _ops.read_bytes(path)
	if not read["accepted"]:
		candidate["read_error"] = true
		return candidate
	var bytes: PackedByteArray = read["bytes"]
	candidate["bytes"] = bytes.duplicate()
	candidate["text"] = bytes.get_string_from_utf8()
	if candidate["text"].to_utf8_buffer() != bytes:
		return candidate
	candidate["header"] = _comparable_header(candidate["text"])
	var restored: Dictionary = _restore_factory.call(candidate["text"])
	if restored.get("accepted", false) and _is_authority_state(restored.get("value")):
		var state: Variant = restored["value"]
		var encoded: Dictionary = state.encode_save()
		if encoded["accepted"]:
			candidate["valid"] = true
			candidate["state"] = state
			candidate["pending_issue"] = restored.get("pending_issue", Callable())
			candidate["canonical_text"] = encoded["text"]
			candidate["canonical_bytes"] = (encoded["bytes"] as PackedByteArray).duplicate()
			candidate["migrated"] = encoded["text"] != candidate["text"]
			candidate["header"] = _comparable_header(encoded["text"])
	return candidate


func _authority_from(candidate: Dictionary) -> Dictionary:
	if not _is_authority_store():
		return {}
	return {
		"state": candidate["state"],
		"pending_issue": candidate.get("pending_issue", Callable()),
	}


func _authority_from_certified(state: Variant, source: String) -> Dictionary:
	if not _is_authority_store() or state == null:
		return {}
	if not state.has_method("_certified_committed_copy"):
		return {}
	var copied: Dictionary = state._certified_committed_copy(source)
	if not copied.get("accepted", false) or not _is_authority_state(copied.get("value")):
		return {}
	return {"state": copied["value"], "pending_issue": Callable()}


func _select_winner(candidates: Dictionary) -> Dictionary:
	var main: Dictionary = candidates[MAIN]
	var bak: Dictionary = candidates[BAK]
	var tmp: Dictionary = candidates[TMP]
	if main["valid"]:
		return _winner(main)
	if bak["valid"]:
		var divergent_equal: bool = (
			tmp["valid"] and _same_version(bak, tmp) and bak["text"] != tmp["text"]
		)
		return _no_winner() if divergent_equal else _winner(bak)
	if tmp["valid"] and _tmp_not_older_than_invalid_headers(tmp, [main, bak]):
		return _winner(tmp)
	return _no_winner()


func _tmp_not_older_than_invalid_headers(tmp: Dictionary, others: Array) -> bool:
	var tmp_header: Dictionary = tmp["header"]
	for other: Dictionary in others:
		if other["valid"] or other["header"] == null:
			continue
		if _compare_headers(tmp_header, other["header"]) < 0:
			return false
	return true


func _cleanup_loaded_winner(source: StringName) -> void:
	match source:
		MAIN:
			_remove_if_exists(_tmp_path)
			_remove_if_exists(_bak_path)
		BAK:
			_remove_if_exists(_main_path)
			if _ops.file_exists(_bak_path):
				_ops.rename_path(_bak_path, _main_path)
			_remove_if_exists(_tmp_path)
		TMP:
			_remove_if_exists(_main_path)
			_remove_if_exists(_bak_path)
			if _ops.file_exists(_tmp_path):
				_ops.rename_path(_tmp_path, _main_path)


func _remove_if_exists(path: String) -> void:
	if _ops.file_exists(path):
		_ops.remove_path(path)


static func _comparable_header(source: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return null
	var restored := CANONICAL_JSON_SCRIPT.restore_exact_integers(source, parser.data)
	if not restored["accepted"] or typeof(restored["value"]) != TYPE_DICTIONARY:
		return null
	var root: Dictionary = restored["value"]
	var keys := ["schema", "version", "checksum", "data"]
	if root.keys() != keys or root.get("schema") != CAMPAIGN_CODEC_SCRIPT.SAVE_SCHEMA:
		return null
	if (
		typeof(root.get("version")) != TYPE_INT
		or int(root["version"]) not in [
			CAMPAIGN_CODEC_SCRIPT.SAVE_VERSION, CAMPAIGN_CODEC_SCRIPT.RECRUIT_SAVE_VERSION
		]
	):
		return null
	if not _is_hex(String(root.get("checksum", "")), 64):
		return null
	if typeof(root.get("data")) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = root["data"]
	for key: String in ["campaign_generation", "save_revision"]:
		if typeof(data.get(key)) != TYPE_INT:
			return null
		if int(data[key]) < 1 or int(data[key]) > CAMPAIGN_CODEC_SCRIPT.U63_MAX:
			return null
	return {
		"campaign_generation": int(data["campaign_generation"]),
		"save_revision": int(data["save_revision"]),
	}


static func _same_version(a: Dictionary, b: Dictionary) -> bool:
	if a["header"] == null or b["header"] == null:
		return false
	return _compare_headers(a["header"], b["header"]) == 0


static func _compare_headers(a: Dictionary, b: Dictionary) -> int:
	var generation_compare := int(a["campaign_generation"]) - int(b["campaign_generation"])
	if generation_compare != 0:
		return signi(generation_compare)
	return signi(int(a["save_revision"]) - int(b["save_revision"]))


static func _winner(candidate: Dictionary) -> Dictionary:
	return {
		"accepted": true,
		"source": candidate["source"],
		"text": candidate["text"],
		"bytes": (candidate["bytes"] as PackedByteArray).duplicate(),
		"canonical_text": candidate["canonical_text"],
		"canonical_bytes": (candidate["canonical_bytes"] as PackedByteArray).duplicate(),
		"migrated": candidate["migrated"],
		"state": candidate["state"],
	}


static func _no_winner() -> Dictionary:
	return {
		"accepted": false,
		"source": NONE,
		"text": "",
		"bytes": PackedByteArray(),
		"canonical_text": "",
		"canonical_bytes": PackedByteArray(),
		"migrated": false,
		"state": null,
	}


static func _any_exists(candidates: Dictionary) -> bool:
	for candidate: Dictionary in candidates.values():
		if candidate["exists"]:
			return true
	return false


static func _is_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _save_result(status: StringName, code: StringName, revision: int) -> Dictionary:
	return {"status": status, "error_code": code, "save_revision": revision}


static func _is_authority_state(value: Variant) -> bool:
	return (
		value != null
		and value.has_method("encode_save")
		and value.has_method("save_revision")
		and value.has_method("_validated_save_text")
	)


static func _load_reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code, "state": null, "source": NONE}
