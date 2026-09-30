class_name FablewoodBuildPlacement
extends RefCounted
## Presentation only: never reserve gold, create units, or mutate the battle model.
const GhostShader:=preload("res://scripts/fablewood/build_placement.gdshader")
const VALID_COLOR:=Color(0.16,0.64,1.0,0.72)
const INVALID_COLOR:=Color(1.0,0.20,0.24,0.72)
var host:Control
var hud:Array[Control]=[]
var ghost:TextureRect
var cancel_button:Button
var pointer:=Vector2.ZERO
var preview_cell:=Vector2i(-99,-99)
var preview_valid:=false
var _unit:=UnitState.new()
var _material:=ShaderMaterial.new()

func _init(owner:Control,panels:Array[Control])->void:
	host=owner;hud=panels;_unit.id=-1
	_material.shader=GhostShader
	ghost=TextureRect.new();ghost.name="BuildPlacementGhost"
	ghost.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode=TextureRect.STRETCH_SCALE
	ghost.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ghost.material=_material;ghost.hide();host.canvas.add_child(ghost)
	cancel_button=host._button(host.canvas,host.trf("build_cancel"),cancel,Vector2(190,44))
	cancel_button.name="CancelBuildPlacement"
	var font:=cancel_button.get_theme_font("font")
	var font_size:=cancel_button.get_theme_font_size("font_size")
	var padding:=cancel_button.get_theme_stylebox("normal").get_minimum_size()
	cancel_button.custom_minimum_size=Vector2(maxf(190.0,font.get_string_size(cancel_button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+padding.x+16.0),maxf(44.0,font.get_height(font_size)+padding.y))
	cancel_button.position=Vector2(host._logical.x-cancel_button.custom_minimum_size.x-22,18)
	cancel_button.tooltip_text=host.trf("build_cancel_hint")
	cancel_button.hide()
	pointer=host.canvas.get_local_mouse_position()
	refresh()

func active()->bool:
	return host.chosen!=&"" and not host._ended

func begin()->void:
	pointer=host.canvas.get_local_mouse_position()
	var focus:=host.get_viewport().gui_get_focus_owner()
	if focus!=null:focus.release_focus()
	refresh()

func cancel()->void:
	if host.chosen==&"":return
	host.chosen=&"";host.world.selected_element=""
	host.world._dragging=false;host.world._drag_distance=0.0
	Sfx.play("back")
	host._refresh_inspector();host._refresh_hud();refresh()
	# Cancelling a guided placement returns to choosing instead of hiding its target.
	if host._tutorial_active and host._tutorial_step==2:
		host._tutorial_step=1
		(host.overlay as FablewoodTutorialCallout).refresh()

func set_pointer(canvas_position:Vector2)->void:
	pointer=canvas_position
	refresh()

func refresh()->void:
	var placing:=active()
	for panel:Control in hud:
		if is_instance_valid(panel):panel.visible=not placing
	cancel_button.visible=placing and (host.overlay==null or host._tutorial_active)
	ghost.visible=placing and Rect2(Vector2.ZERO,host._logical).has_point(pointer) and (host.overlay==null or host._tutorial_active)
	if not placing:
		preview_valid=false
		return
	host.world.selected_element=FablewoodBattle.ELEMENTS[host.chosen]
	host.world.framing()
	var local:Vector2=pointer-host.world.position
	var inside:=Rect2(Vector2.ZERO,host.world.size).has_point(local)
	preview_cell=host.world.pick(local) if inside else Vector2i(-99,-99)
	host.world.hovered=preview_cell
	preview_valid=inside and host.model.can_deploy_at(host.chosen,preview_cell)
	_unit.op_id=host.chosen;_unit.cell=preview_cell
	var world_rect:Rect2=host.world.tower_draw_rect(_unit,false)
	# Snap to a socket (also when occupied); over all other terrain follow freely.
	if not host.model.stage.is_elevated_platform(preview_cell):
		var anchor:Vector2=(local-host.world._origin)/host.world._scale
		world_rect.position+=anchor-host.world.platform_surface_center(preview_cell)
	ghost.texture=host.P.GUARDIANS[FablewoodBattle.ELEMENTS[host.chosen]][0]
	ghost.position=host.world.position+host.world._origin+world_rect.position*host.world._scale
	ghost.size=world_rect.size*host.world._scale
	_material.set_shader_parameter("preview_color",VALID_COLOR if preview_valid else INVALID_COLOR)
