class_name CampaignFileOps
extends RefCounted

## Production Godot filesystem operations used by CampaignSaveStore. Tests may
## subclass this interface to inject exact method/ordinal failures.


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func read_bytes(path: String) -> Dictionary:
	if not file_exists(path):
		return {"accepted": false, "error_code": &"file_missing", "bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"accepted": false, "error_code": &"file_read_failed", "bytes": PackedByteArray()}
	var bytes := file.get_buffer(file.get_length())
	var error := file.get_error()
	file.close()
	if error != OK:
		return {"accepted": false, "error_code": &"file_read_failed", "bytes": PackedByteArray()}
	return {"accepted": true, "error_code": &"", "bytes": bytes}


func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _reject(&"file_write_failed")
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return _accept() if error == OK else _reject(&"file_write_failed")


func rename_path(from_path: String, to_path: String) -> Dictionary:
	if not file_exists(from_path):
		return _reject(&"file_missing")
	var error := DirAccess.rename_absolute(from_path, to_path)
	return _accept() if error == OK else _reject(&"file_rename_failed")


func remove_path(path: String) -> Dictionary:
	if not file_exists(path):
		return _reject(&"file_missing")
	var error := DirAccess.remove_absolute(path)
	return _accept() if error == OK else _reject(&"file_remove_failed")


static func _accept() -> Dictionary:
	return {"accepted": true, "error_code": &""}


static func _reject(code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": code}
