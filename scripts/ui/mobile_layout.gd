class_name MobileLayout
extends RefCounted
## Small, shared helpers for the browser/mobile presentation layer.
## Gameplay coordinates stay at the authored 1280x720 canvas; this class only
## detects small Web viewports and gives UI controls comfortable touch targets.
static func browser_size() -> Vector2:
	return Vector2(DisplayServer.window_get_size())
static func is_mobile_browser() -> bool:
	if OS.has_feature("mobile"):
		return true
	if not OS.has_feature("web"):
		return false
	var s := browser_size()
	return minf(s.x, s.y) <= 600.0
static func is_landscape_mobile() -> bool:
	var s := browser_size()
	return is_mobile_browser() and s.x >= s.y
static func touch_target(size: Vector2, minimum: float = 56.0) -> Vector2:
	if not is_mobile_browser():
		return size
	return Vector2(maxf(size.x, minimum), maxf(size.y, minimum))
static func edge_inset() -> float:
	return 18.0 if is_mobile_browser() else 12.0
