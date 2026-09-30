extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Art._reset_manifests_for_test()
	_validate_manifest(
		&"world.act1.spawn", Vector2i(589, 600), Vector2i(64, 64), 24, 6, 12.0
	)
	_validate_manifest(
		&"world.act1.core", Vector2i(401, 600), Vector2i(64, 80), 6, 6, 6.0
	)

	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	var portal := BattleEndpointLandmark.new()
	root.add_child(portal)
	_check(portal.setup(&"world.act1.spawn"), "portal setup failed")
	_check(portal.size == Vector2(64, 64), "portal display exceeds its one-tile runtime box")
	_check(
		portal.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"portal does not use mipmapped linear downsampling"
	)
	portal.call("_process", 0.1)
	_check(portal.frame_index() == 1, "portal idle did not advance at 12 FPS")

	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	portal.call("_process", 0.25)
	_check(portal.frame_index() == 0, "reduced motion did not freeze the portal")
	root.remove_child(portal)
	portal.free()
	ProjectSettings.set_setting("accessibility/reduced_motion", false)
	_finish()


func _validate_manifest(
	id: StringName,
	expected_source_size: Vector2i,
	expected_display_size: Vector2i,
	frames: int,
	columns: int,
	fps: float
) -> void:
	var metadata := Art.metadata(id)
	_check(Art.size(id) == expected_source_size, "%s source frame size drifted" % id)
	_check(maxi(expected_source_size.x, expected_source_size.y) == 600, "%s is not 600px" % id)
	_check(
		metadata.get("display_size", Vector2i.ZERO) == expected_display_size,
		"%s display size drifted" % id
	)
	_check(int(metadata.get("columns", 0)) == columns, "%s atlas column count drifted" % id)
	_check(Art.frame_count(id) == frames, "%s frame count drifted" % id)
	_check(is_equal_approx(Art.fps(id), fps), "%s playback rate drifted" % id)
	var first := Art.animation_texture(id, &"idle", 0) as AtlasTexture
	var last := Art.animation_texture(id, &"idle", frames - 1) as AtlasTexture
	_check(first != null, "%s first idle frame is missing" % id)
	_check(last != null, "%s last idle frame is missing" % id)
	if last != null:
		var expected_last_origin := Vector2i(
			((frames - 1) % columns) * expected_source_size.x,
			((frames - 1) / columns) * expected_source_size.y,
		)
		_check(
			last.region.position == Vector2(expected_last_origin),
			"%s last atlas region drifted" % id
		)
		_check(
			maxi(last.atlas.get_width(), last.atlas.get_height()) <= 4096,
			"%s atlas exceeds the 4096px WebGL compatibility ceiling" % id
		)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("BATTLE_ENDPOINT_LANDMARK_TEST_OK")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
