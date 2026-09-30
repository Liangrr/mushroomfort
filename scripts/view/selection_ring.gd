## SelectionRing — presentation-only rotating ellipse drawn around a
## deployed tower's feet. Lives entirely in the view layer; zero model reads
## after construction. Aged in _process (rule 10).
##
## Usage:
##   var ring := SelectionRing.new()
##   ring.attach(unit_node)   # call once after _make_unit_node
##   ring.detach()            # call when unit deselected or retreated
extends Node2D

## Ellipse geometry — matches the isometric 2:1 tile footprint at SPRITE_SCALE.
const RING_RX := 22.0  # half-width  (≈ tile_w/2 * 0.68)
const RING_RY := 11.0  # half-height (≈ tile_h/2 * 0.68)
const RING_SEGMENTS := 32
const RING_COLOR := Color(1.0, 0.92, 0.3, 0.9)  # warm gold
const RING_WIDTH := 2.5
const RING_DASH_ON := 6  # segments on
const RING_DASH_OFF := 3  # segments off
const ROTATION_SPEED := 1.8  # radians per second

var _phase := 0.0


func _process(delta: float) -> void:
	_phase += ROTATION_SPEED * delta
	queue_redraw()


func _draw() -> void:
	var pts: PackedVector2Array = _ellipse_points(RING_SEGMENTS, _phase)
	# Draw dashed ring by skipping every RING_DASH_OFF segment block
	var i := 0
	while i < RING_SEGMENTS:
		# draw RING_DASH_ON consecutive segments
		for j in range(RING_DASH_ON):
			var a := pts[(i + j) % RING_SEGMENTS]
			var b := pts[(i + j + 1) % RING_SEGMENTS]
			draw_line(a, b, RING_COLOR, RING_WIDTH, true)
		i += RING_DASH_ON + RING_DASH_OFF


func _ellipse_points(n: int, phase: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for k in range(n):
		var angle := phase + k * TAU / n
		pts[k] = Vector2(cos(angle) * RING_RX, sin(angle) * RING_RY)
	return pts


## Attach to a unit node; ring sits at feet level (y=0 in node-local space).
func attach(unit_node: Node2D) -> void:
	name = "SelectionRing"
	z_index = -1  # behind the unit body, above the tile
	unit_node.add_child(self)


## Remove from tree cleanly.
func detach() -> void:
	if is_inside_tree():
		queue_free()
