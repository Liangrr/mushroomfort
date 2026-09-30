class_name PlayerDataReset
extends RefCounted

## Removes every persisted file and directory beneath user:// without removing
## the platform-owned user-data root itself. Callers must stop writers first.

const USER_ROOT := "user://"


static func clear_all() -> Dictionary:
	var failures: Array[String] = []
	var removed := [0]
	var root_absolute := ProjectSettings.globalize_path(USER_ROOT).simplify_path()
	if root_absolute.is_empty() or root_absolute == "/":
		return {
			&"accepted": false,
			&"error_code": &"unsafe_user_data_root",
			&"removed_count": 0,
			&"failures": [root_absolute],
		}
	_clear_directory(USER_ROOT, root_absolute, failures, removed)
	return {
		&"accepted": failures.is_empty(),
		&"error_code": &"" if failures.is_empty() else &"player_data_clear_failed",
		&"removed_count": int(removed[0]),
		&"failures": failures,
	}


static func _clear_directory(
	virtual_path: String,
	root_absolute: String,
	failures: Array[String],
	removed: Array,
	) -> void:
	var directory := DirAccess.open(virtual_path)
	if directory == null:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(virtual_path)):
			failures.append(virtual_path)
		return
	directory.list_dir_begin()
	var names: Array[String] = []
	var directories: Dictionary = {}
	var links: Dictionary = {}
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		names.append(name)
		directories[name] = directory.current_is_dir()
		links[name] = directory.is_link(name)
	directory.list_dir_end()
	for name: String in names:
		var child_virtual := virtual_path.path_join(name)
		var child_absolute := ProjectSettings.globalize_path(child_virtual).simplify_path()
		if not _is_safe_descendant(root_absolute, child_absolute):
			failures.append(child_virtual)
			continue
		if bool(directories.get(name, false)) and not bool(links.get(name, false)):
			_clear_directory(child_virtual, root_absolute, failures, removed)
			if DirAccess.remove_absolute(child_absolute) != OK:
				failures.append(child_virtual)
			else:
				removed[0] = int(removed[0]) + 1
		elif DirAccess.remove_absolute(child_absolute) != OK:
			failures.append(child_virtual)
		else:
			removed[0] = int(removed[0]) + 1


static func _is_safe_descendant(root_absolute: String, candidate_absolute: String) -> bool:
	var normalized_root := root_absolute.trim_suffix("/")
	return (
		not normalized_root.is_empty()
		and candidate_absolute.begins_with(normalized_root + "/")
	)
