extends Node
## Bind imported UI composites (Figtree / Fredoka + Noto Sans SC) and the game Theme
## to every root Control at runtime.
const GameFonts = preload("res://scripts/manus/game_fonts.gd")
var _regular: Font
var _theme: Theme


func _enter_tree() -> void:
	_regular = load("res://assets/template/fonts/ui_regular.tres") as Font
	assert(_regular != null, "Bundled UI font failed to import")
	var medium := load("res://assets/template/fonts/ui_medium.tres") as Font
	var bold := load("res://assets/template/fonts/ui_bold.tres") as Font
	var display := load("res://assets/mg/fonts/display.tres") as Font
	if display == null:
		display = bold
	_theme = UiTheme.build(_regular, medium, bold, display)
	get_tree().node_added.connect(_bind_node)
	_bind_tree(get_tree().root)


func theme() -> Theme:
	return _theme


func _bind_tree(node: Node) -> void:
	_bind_node(node)
	for child in node.get_children():
		_bind_tree(child)


func _bind_node(node: Node) -> void:
	if node is Control:
		if node.theme != null:
			if node.theme.default_font == null:
				node.theme = node.theme.duplicate()
				node.theme.default_font = _regular
		elif node.get_parent_control() == null:
			node.theme = _theme
	elif node is Label3D and node.font == null:
		GameFonts.apply_world_label(node, _regular)
