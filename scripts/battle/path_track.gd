class_name PathTrack
extends RefCounted
## A polyline route in pixels with distance-based sampling.

var points := PackedVector2Array()
var cumulative := PackedFloat32Array()
var length := 0.0
var flying := false


static func from_cells(cells: Array, origin: Vector2, cell: float, is_flying: bool) -> PathTrack:
	var t := PathTrack.new()
	t.flying = is_flying
	for c in cells:
		t.points.append(origin + (Vector2(float(c[0]), float(c[1])) + Vector2(0.5, 0.5)) * cell)
	t._measure()
	return t


func _measure() -> void:
	cumulative.clear()
	length = 0.0
	cumulative.append(0.0)
	for i in range(1, points.size()):
		length += points[i - 1].distance_to(points[i])
		cumulative.append(length)


func _segment(d: float) -> int:
	# Binary search for the segment containing distance d.
	var lo := 0
	var hi := points.size() - 2
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if cumulative[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return clampi(lo, 0, max(0, points.size() - 2))


func sample(d: float) -> Vector2:
	if points.size() < 2:
		return points[0] if points.size() == 1 else Vector2.ZERO
	d = clampf(d, 0.0, length)
	var i := _segment(d)
	var seg_len := cumulative[i + 1] - cumulative[i]
	var f := 0.0 if seg_len <= 0.0 else (d - cumulative[i]) / seg_len
	return points[i].lerp(points[i + 1], f)


func direction(d: float) -> Vector2:
	if points.size() < 2:
		return Vector2.RIGHT
	var i := _segment(clampf(d, 0.0, length))
	return (points[i + 1] - points[i]).normalized()


## Shortest distance from p to the polyline.
func distance_to_point(p: Vector2) -> float:
	var best := INF
	for i in points.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		best = minf(best, p.distance_to(q))
	return best
