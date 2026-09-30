extends "res://scripts/manus/preview/tuning_transport.gd"
## Thin mapping from the active Fablewood catalog to the Addon's Tweak popover.
func store() -> Variant:
	return get_node_or_null("/root/TweakControls")

func settings() -> Array:
	var result: Array = []
	for entry: RefCounted in store().catalog.descriptors:
		result.append({"id": str(entry.id), "category_key": "tuning.category." + str(entry.category),
			"type": str(entry.value_type), "default": entry.default_value,
			"min": entry.minimum, "max": entry.maximum, "step": entry.step,
			"unit_key": "tuning.unit." + str(entry.unit), "label_key": entry.label_key,
			"description_key": entry.description_key, "apply_mode": str(entry.apply_mode),
			"integrity": str(entry.integrity)})
	return result

func requested(setting: Dictionary) -> Variant:
	return store().requested_value(StringName(setting.id))

func active(setting: Dictionary) -> Variant:
	return store().active_value(StringName(setting.id))

func commit(patch: Dictionary) -> bool:
	return bool(store().apply_preview_patch(patch).get("ok", false))

func translate(value: String) -> String:
	var i18n := get_node_or_null("/root/I18n")
	if i18n == null or value.is_empty():
		return value
	return str(i18n.call("t", StringName("fw." + value), value)).format({"value": ""}).strip_edges()
