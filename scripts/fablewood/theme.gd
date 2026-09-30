extends Theme

func _init() -> void:
	# A cold editor import has not produced texture/font cache files yet.
	# Load the presentation only at runtime, after resource import is complete.
	if Engine.is_editor_hint():
		return
	var presentation = load("res://scripts/fablewood/presentation.gd")
	merge_with(presentation.make_theme())
