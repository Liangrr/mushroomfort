extends SceneTree


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		printerr("CONTENT_PACK_BUILD_FAIL|expected output path and at least one res:// texture")
		quit(2)
		return
	var output_path := String(arguments[0])
	var packer := PCKPacker.new()
	var start_error := packer.pck_start(output_path)
	if start_error != OK:
		printerr("CONTENT_PACK_BUILD_FAIL|start|%s" % error_string(start_error))
		quit(3)
		return
	var packed_paths: Dictionary = {}
	var resources := 0
	for index: int in range(1, arguments.size()):
		var source_path := String(arguments[index])
		if not source_path.begins_with("res://") or not source_path.ends_with(".webp"):
			printerr("CONTENT_PACK_BUILD_FAIL|invalid source|%s" % source_path)
			quit(4)
			return
		var import_path := source_path + ".import"
		var config := ConfigFile.new()
		if config.load(import_path) != OK:
			printerr("CONTENT_PACK_BUILD_FAIL|missing import|%s" % import_path)
			quit(5)
			return
		var destinations: PackedStringArray = config.get_value("deps", "dest_files", PackedStringArray())
		if destinations.is_empty():
			printerr("CONTENT_PACK_BUILD_FAIL|missing destination|%s" % import_path)
			quit(6)
			return
		if not _add_file(packer, import_path, packed_paths):
			quit(7)
			return
		for destination: String in destinations:
			if not _add_file(packer, destination, packed_paths):
				quit(8)
				return
		resources += 1
	var flush_error := packer.flush()
	if flush_error != OK:
		printerr("CONTENT_PACK_BUILD_FAIL|flush|%s" % error_string(flush_error))
		quit(9)
		return
	print("CONTENT_PACK_BUILD_OK|%s|resources=%d|files=%d" % [
		output_path, resources, packed_paths.size(),
	])
	quit(0)


func _add_file(packer: PCKPacker, resource_path: String, packed_paths: Dictionary) -> bool:
	if packed_paths.has(resource_path):
		return true
	var absolute_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(absolute_path):
		printerr("CONTENT_PACK_BUILD_FAIL|missing file|%s" % resource_path)
		return false
	var add_error := packer.add_file(resource_path, absolute_path)
	if add_error != OK:
		printerr("CONTENT_PACK_BUILD_FAIL|add|%s|%s" % [resource_path, error_string(add_error)])
		return false
	packed_paths[resource_path] = true
	return true
