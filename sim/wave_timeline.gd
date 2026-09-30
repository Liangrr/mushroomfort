class_name WaveTimeline
extends RefCounted

## Seeded, deterministic spawn schedule. Entries: {tick, enemy_id, path_idx},
## sorted by tick; due() advances a cursor, so each entry spawns exactly once.

var entries: Array[Dictionary] = []
var next_index: int = 0


static func from_waves(waves: Array[Dictionary]) -> WaveTimeline:
	var timeline := WaveTimeline.new()
	timeline.entries = waves.duplicate()
	timeline.entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return int(a["tick"]) < int(b["tick"])
	)
	return timeline


func due(tick: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	while next_index < entries.size() and int(entries[next_index]["tick"]) <= tick:
		out.append(entries[next_index])
		next_index += 1
	return out


func exhausted() -> bool:
	return next_index >= entries.size()
