extends SceneTree

const CampaignStateV3Script := preload("res://sim/campaign_state_v3.gd")
const CampaignSaveStoreScript := preload("res://sim/campaign_save_store.gd")
const RuntimeContextScript := preload("res://sim/campaign_runtime_context.gd")

var _failures: Array[String] = []


class MemoryFileOps:
	extends RefCounted

	var files: Dictionary = {}
	var read_counts: Dictionary = {}
	var corrupt_path := ""
	var corrupt_ordinal := -1

	func file_exists(path: String) -> bool:
		return files.has(path)

	func read_bytes(path: String) -> Dictionary:
		if not files.has(path):
			return {"accepted": false, "error_code": &"file_missing", "bytes": PackedByteArray()}
		var ordinal := int(read_counts.get(path, 0)) + 1
		read_counts[path] = ordinal
		var bytes: PackedByteArray = (files[path] as PackedByteArray).duplicate()
		if path == corrupt_path and ordinal == corrupt_ordinal and not bytes.is_empty():
			bytes[bytes.size() - 1] = (bytes[-1] + 1) & 0xFF
			corrupt_path = ""
			corrupt_ordinal = -1
		return {"accepted": true, "error_code": &"", "bytes": bytes}

	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		files[path] = bytes.duplicate()
		return {"accepted": true, "error_code": &""}

	func rename_path(from_path: String, to_path: String) -> Dictionary:
		if not files.has(from_path):
			return {"accepted": false, "error_code": &"file_missing"}
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return {"accepted": true, "error_code": &""}

	func remove_path(path: String) -> Dictionary:
		if not files.has(path):
			return {"accepted": false, "error_code": &"file_missing"}
		files.erase(path)
		return {"accepted": true, "error_code": &""}

	func reset_reads() -> void:
		read_counts.clear()

	func corrupt_read(path: String, ordinal: int) -> void:
		corrupt_path = path
		corrupt_ordinal = ordinal


func _init() -> void:
	var context := RuntimeContextScript.build()
	var created := CampaignStateV3Script.create(443_211, 1, context)
	_check(created.get("accepted", false), "campaign fixture failed to create")
	if not created.get("accepted", false):
		_finish()
		return
	var state: Variant = created["value"]
	var restore_calls: Array[int] = [0]
	var restore_factory: Callable = func(source: String) -> Dictionary:
		restore_calls[0] += 1
		return CampaignStateV3Script.restore_source(source, context)
	var poisoned_ops: MemoryFileOps = MemoryFileOps.new()
	poisoned_ops.files["user://campaign_fast_path_poisoned.json"] = PackedByteArray()
	var poisoned_store_result: Dictionary = CampaignSaveStoreScript.create(
		"user://campaign_fast_path_poisoned.json", restore_factory, poisoned_ops,
	)
	var poisoned: Dictionary = poisoned_store_result["value"].save("", state)
	_check(
		poisoned["status"] == CampaignSaveStoreScript.INDETERMINATE,
		"empty expected preimage overwrote an existing invalid slot",
	)
	restore_calls[0] = 0
	var ops: MemoryFileOps = MemoryFileOps.new()
	var made: Dictionary = CampaignSaveStoreScript.create(
		"user://campaign_fast_path_test.json", restore_factory, ops,
	)
	_check(made.get("accepted", false), "save store fixture failed to create")
	if not made.get("accepted", false):
		_finish()
		return
	var store: Variant = made["value"]
	var initial: Dictionary = store.save("", state)
	_check(initial["status"] == CampaignSaveStoreScript.COMMITTED, "initial save failed")
	_check(restore_calls[0] == 0, "clean initial save performed semantic restore")

	var first: Variant = _renamed_state(state, "fast-path:first", "Astra")
	if first == null:
		_finish()
		return
	restore_calls[0] = 0
	ops.reset_reads()
	var saved_first: Dictionary = store.save(state._validated_save_text(), first)
	_check(saved_first["status"] == CampaignSaveStoreScript.COMMITTED, "clean append save failed")
	_check(restore_calls[0] == 0, "clean append save replayed campaign history")
	var idempotent: Dictionary = store.save(state._validated_save_text(), first)
	_check(idempotent["status"] == CampaignSaveStoreScript.COMMITTED, "idempotent save failed")
	_check(restore_calls[0] == 0, "idempotent save replayed campaign history")

	var second: Variant = _renamed_state(first, "fast-path:second", "Nova")
	if second == null:
		_finish()
		return
	restore_calls[0] = 0
	ops.reset_reads()
	ops.corrupt_read("user://campaign_fast_path_test.tmp", 1)
	var faulted: Dictionary = store.save(first._validated_save_text(), second)
	_check(faulted["status"] == CampaignSaveStoreScript.RETRYABLE, "corrupt temp echo was not retryable")
	_check(faulted["error_code"] == &"store_validate_failed", "corrupt temp echo exposed wrong error")
	_check(restore_calls[0] > 0, "save fault skipped exhaustive recovery validation")
	var retry: Dictionary = store.save(first._validated_save_text(), second)
	_check(retry["status"] == CampaignSaveStoreScript.COMMITTED, "exact save retry did not commit")

	var stale: Dictionary = store.save(first._validated_save_text(), state)
	_check(stale["status"] == CampaignSaveStoreScript.INDETERMINATE, "stale CAS preimage was accepted")
	var loaded: Dictionary = store.load()
	_check(loaded.get("accepted", false), "cold load failed after fast commits")
	if loaded.get("accepted", false):
		_check(
			loaded["state"]._validated_save_text() == second._validated_save_text(),
			"cold load did not preserve the latest committed bytes",
		)
	_finish()


func _renamed_state(state: Variant, command_id: String, callsign: String) -> Variant:
	var hero_id := String(state.runtime_projection()["ready_heroes"][0]["hero_id"])
	var command: Dictionary = state.rename_hero(
		command_id, state.save_revision(), hero_id, callsign,
	)
	_check(command.get("accepted", false), "%s rename command failed" % command_id)
	if not command.get("accepted", false):
		return null
	var mutation: Variant = command.get("payload", {}).get("mutation")
	_check(mutation != null, "%s omitted mutation" % command_id)
	return mutation.get("_prospective_state") if mutation != null else null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("CAMPAIGN_SAVE_FAST_PATH_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
