class_name Pathing
extends RefCounted

## Path-space math (pure functions). A path is an ordered list of grid cells.
## Progress is measured in fixed-point micro-tiles from the spawn cell; the
## total traversal length is path.size() tile-lengths — an enemy spawns at
## the outer edge of the spawn cell and leaks after walking through every
## cell (reaching the far edge of the base cell).

const PROGRESS_SCALE := 1_000_000


static func length_units(path: Array[Vector2i]) -> int:
	return path.size() * PROGRESS_SCALE


## Per-tick advance for a given speed at 30 model ticks/s. Float math only at
## this one boundary, floored once; accumulated state stays integer.
static func step_units_for(speed_tiles_per_s: float, ticks_per_second: int) -> int:
	return floori(speed_tiles_per_s * float(PROGRESS_SCALE) / float(ticks_per_second))


## Continuous position in tile space (cell units) for rendering. Clamps to
## the last cell's center while the enemy walks its final tile-length.
static func position_of(path: Array[Vector2i], progress_units: int) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var p := clampi(progress_units, 0, length_units(path))
	@warning_ignore("integer_division")
	var seg := p / PROGRESS_SCALE
	if seg >= path.size() - 1:
		return Vector2(path[path.size() - 1])
	var frac := float(p % PROGRESS_SCALE) / float(PROGRESS_SCALE)
	return Vector2(path[seg]).lerp(Vector2(path[seg + 1]), frac)


static func cell_of(path: Array[Vector2i], progress_units: int) -> Vector2i:
	if path.is_empty():
		return Vector2i.ZERO
	@warning_ignore("integer_division")
	var seg := clampi(progress_units, 0, length_units(path) - 1) / PROGRESS_SCALE
	return path[mini(seg, path.size() - 1)]
