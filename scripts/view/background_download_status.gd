class_name BackgroundDownloadStatus
extends RefCounted

## Presentation-only bridge for the Web host's subtle background-transfer chip.
## All identifiers originate from signed catalogs or allow-listed pack IDs.

const EVENT_NAME := "protos-prefetch-status"


static func publish(
		kind: StringName,
		asset_id: StringName,
		state: StringName,
		current: int = 0,
		total: int = 0,
	) -> void:
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({
		"kind": String(kind),
		"id": String(asset_id),
		"state": String(state),
		"current": maxi(current, 0),
		"total": maxi(total, 0),
	})
	JavaScriptBridge.eval(
		"window.dispatchEvent(new CustomEvent(%s,{detail:%s}));" % [
			JSON.stringify(EVENT_NAME), payload,
		],
		true,
	)
