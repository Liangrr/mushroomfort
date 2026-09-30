extends Node
## Two-language string table (localization/zh.json, localization/en.json).
## Auto-detects the browser/OS locale on first run; a manual choice is remembered.

signal changed

const LANGS := ["zh", "en"]

var lang := "en"
var _tables := {}


func _ready() -> void:
	for code in LANGS:
		_tables[code] = _load_table("res://localization/%s.json" % code)
	var saved := str(Save.get_setting("language", ""))
	lang = saved if saved in LANGS else detect()


static func detect() -> String:
	return "zh" if OS.get_locale().to_lower().begins_with("zh") else "en"


func set_lang(code: String) -> void:
	if not code in LANGS:
		return
	lang = code
	Save.set_setting("language", code)
	changed.emit()


func toggle() -> void:
	set_lang("en" if lang == "zh" else "zh")


## Look up a key; `{name}` placeholders are replaced from params.
func t(key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = _tables.get(lang, {})
	var text: String = str(table.get(key, _tables.get("en", {}).get(key, key)))
	for k in params:
		text = text.replace("{%s}" % k, str(params[k]))
	return text


func has_key(key: String) -> bool:
	return _tables.get("en", {}).has(key)


func _load_table(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing localization table %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid localization table %s" % path)
		return {}
	return parsed
