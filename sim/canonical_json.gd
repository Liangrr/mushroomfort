class_name CanonicalJson
extends RefCounted

const I64_TENTHS := 922_337_203_685_477_580


static func text(value: Variant) -> String:
	return JSON.stringify(value, "", false, true) + "\n"


static func bytes(value: Variant) -> PackedByteArray:
	return text(value).to_utf8_buffer()


static func sha256_hex(value: Variant) -> String:
	return sha256_bytes(bytes(value))


static func sha256_text(source: String) -> String:
	return sha256_bytes(source.to_utf8_buffer())


static func sha256_bytes(source: PackedByteArray) -> String:
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error := context.update(source)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func restore_exact_integers(source: String, parsed: Variant) -> Dictionary:
	var scanned := _scan_integer_lexemes(source)
	if not scanned["accepted"]:
		return scanned
	var cursor := {"index": 0}
	var restored := _restore_numeric_leaves(parsed, scanned["value"], cursor)
	if not restored["accepted"]:
		return restored
	if int(cursor["index"]) != (scanned["value"] as Array).size():
		return _reject(&"invalid_integer")
	return _accept(restored["value"])


static func _scan_integer_lexemes(source: String) -> Dictionary:
	var values: Array[int] = []
	var in_string := false
	var escaped := false
	var index := 0
	while index < source.length():
		var character := source.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == "\"":
				in_string = false
			index += 1
			continue
		if character == "\"":
			in_string = true
			index += 1
			continue
		if character == "-" or _is_digit(character):
			var end := index + 1
			while end < source.length() and source.substr(end, 1) in "0123456789+-.eE":
				end += 1
			var parsed := _parse_i64_lexeme(source.substr(index, end - index))
			if not parsed["accepted"]:
				return parsed
			values.append(int(parsed["value"]))
			index = end
			continue
		index += 1
	return _accept(values)


static func _parse_i64_lexeme(lexeme: String) -> Dictionary:
	if lexeme.is_empty():
		return _reject(&"invalid_integer")
	var negative := lexeme.begins_with("-")
	var start := 1 if negative else 0
	if start == lexeme.length():
		return _reject(&"invalid_integer")
	if lexeme.substr(start, 1) == "0" and lexeme.length() - start > 1:
		return _reject(&"invalid_integer")
	var result := 0
	var final_limit := 8 if negative else 7
	for index: int in range(start, lexeme.length()):
		var character := lexeme.substr(index, 1)
		if not _is_digit(character):
			return _reject(&"invalid_integer")
		var digit := character.unicode_at(0) - 48
		if result < -I64_TENTHS:
			return _reject(&"invalid_integer")
		if result == -I64_TENTHS and digit > final_limit:
			return _reject(&"invalid_integer")
		result = result * 10 - digit
	return _accept(result if negative else -result)


static func _restore_numeric_leaves(
	value: Variant,
	values: Array,
	cursor: Dictionary,
) -> Dictionary:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			var index := int(cursor["index"])
			if index >= values.size():
				return _reject(&"invalid_integer")
			cursor["index"] = index + 1
			return _accept(values[index])
		TYPE_ARRAY:
			var array: Array = []
			for item: Variant in value:
				var restored := _restore_numeric_leaves(item, values, cursor)
				if not restored["accepted"]:
					return restored
				array.append(restored["value"])
			return _accept(array)
		TYPE_DICTIONARY:
			var dictionary := {}
			for key: Variant in value:
				var restored := _restore_numeric_leaves(value[key], values, cursor)
				if not restored["accepted"]:
					return restored
				dictionary[key] = restored["value"]
			return _accept(dictionary)
		_:
			return _accept(value)


static func _is_digit(character: String) -> bool:
	return character.length() == 1 and character >= "0" and character <= "9"


static func _accept(value: Variant) -> Dictionary:
	return {"accepted": true, "error_code": &"", "value": value}


static func _reject(error_code: StringName) -> Dictionary:
	return {"accepted": false, "error_code": error_code}
