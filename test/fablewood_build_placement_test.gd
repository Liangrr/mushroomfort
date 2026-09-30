extends Node
const Placement:=preload("res://scripts/fablewood/build_placement.gd")
var screen:Control
var output:=OS.get_environment("FABLEWOOD_PLACEMENT_CAPTURE_DIR")

func frames(count:int=3)->void:
	for i:int in count:await get_tree().process_frame

func pointer(canvas_point:Vector2)->void:
	var motion:=InputEventMouseMotion.new()
	motion.position=screen.canvas.get_global_transform_with_canvas()*canvas_point
	motion.global_position=motion.position
	Input.parse_input_event(motion)
	await frames()

func click_site(cell:Vector2i)->void:
	await pointer(screen.world.position+screen.world.screen_of(cell))
	for pressed:bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=screen.canvas.get_global_transform_with_canvas()*(screen.world.position+screen.world.screen_of(cell))
		event.global_position=event.position
		Input.parse_input_event(event)
		await frames(1)

func check_hud(hidden:bool)->void:
	for control:Control in screen.build_placement.hud:
		assert(control.is_visible_in_tree()!=hidden,"All battle HUD panels follow placement state")
	assert(screen.build_placement.cancel_button.visible==hidden,"Cancel remains available while the HUD is hidden")
	assert(screen.build_placement.ghost.visible==hidden,"The ghost exists only while placing")
	var button:Button=screen.build_placement.cancel_button
	var text_width:=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	assert(text_width+button.get_theme_stylebox("normal").get_minimum_size().x<=button.custom_minimum_size.x,"Cancel label must not clip")

func check_tint(valid:bool)->void:
	assert(screen.build_placement.preview_valid==valid,"Preview validity comes from the deployment validator")
	var tint:Color=screen.build_placement.ghost.material.get_shader_parameter("preview_color")
	assert(tint.is_equal_approx(Placement.VALID_COLOR if valid else Placement.INVALID_COLOR))

func shot(name:String)->void:
	if output.is_empty():return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))

func _ready()->void:
	assert(I18n.reload_catalogs())
	if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	screen=Game.content
	if screen._tutorial_active:screen._skip_tutorial()
	# Keep the model deterministic; cursor input and world rendering remain live.
	screen.set_process(false)
	var before:int=screen.model.state_hash()
	var socket:=Vector2i(4,3)
	assert(screen.model.can_deploy_at(&"caster_1",socket))
	for id:StringName in screen.P.IDS:
		screen._choose(id)
		await pointer(screen.world.position+screen.world.screen_of(socket))
		check_hud(true);check_tint(true)
		assert(screen.build_placement.ghost.texture==screen.P.GUARDIANS[FablewoodBattle.ELEMENTS[id]][0])
		assert(screen.build_placement.ghost.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	assert(screen.model.state_hash()==before,"Previewing all four towers must not spend gold or alter gameplay")
	screen._choose(&"caster_1")
	await pointer(screen.world.position+screen.world.screen_of(socket));await shot("blue_valid_site")
	var road:Vector2i=screen.model.path_for(0)[0]
	await pointer(screen.world.position+screen.world.screen_of(road))
	check_tint(false);await shot("red_invalid_site")
	await click_site(road)
	assert(screen.chosen==&"caster_1" and screen.model.units.is_empty());check_hud(true)
	var free_pointer:Vector2=screen.world.position+Vector2(7,9)
	await pointer(free_pointer);check_tint(false)
	var first_position:Vector2=screen.build_placement.ghost.position
	await pointer(free_pointer+Vector2(14,8))
	assert(screen.build_placement.ghost.position.distance_to(first_position+Vector2(14,8))<0.1,"Ghost follows the cursor over invalid terrain, not just sockets")
	await pointer(Vector2(1080,420));check_tint(false)
	assert(screen.build_placement.ghost.visible,"Ghost remains visible over the hidden inspector's area")
	# Camera changes retain the same pointer-to-board transform and socket contact.
	screen.world.change_zoom(1.2);screen.world.pan+=Vector2(16,-8)
	await pointer(screen.world.position+screen.world.screen_of(socket));check_tint(true)
	var expected:Rect2=screen.world.tower_draw_rect(screen.build_placement._unit,false)
	assert(screen.build_placement.ghost.position.distance_to(screen.world.position+screen.world._origin+expected.position*screen.world._scale)<0.1)
	await click_site(socket)
	assert(screen.model.units.size()==1 and screen.model.alive_unit_at(socket)!=null)
	assert(screen.chosen==&"");check_hud(false);await shot("hud_restored_after_placement")
	# Occupied sites reject without switching selection or spending anything.
	screen._choose(&"sniper_1")
	before=screen.model.state_hash()
	await pointer(screen.world.position+screen.world.screen_of(socket));check_tint(false)
	await click_site(socket)
	assert(screen.chosen==&"sniper_1" and screen.model.state_hash()==before);check_hud(true)
	var esc:=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true
	Input.parse_input_event(esc);await frames()
	assert(not screen.paused and screen.overlay==null and screen.chosen==&"");check_hud(false)
	# Gold insufficiency is a red preview even on a geometrically valid socket.
	var empty_socket:=Vector2i(-1,-1)
	for y:int in screen.model.stage.grid_size().y:
		for x:int in screen.model.stage.grid_size().x:
			if screen.model.can_deploy_at(&"caster_1",Vector2i(x,y)):empty_socket=Vector2i(x,y)
	assert(empty_socket!=Vector2i(-1,-1))
	var gold:int=screen.model.dp;screen.model.dp=0
	screen._choose(&"caster_1")
	await pointer(screen.world.position+screen.world.screen_of(empty_socket));check_tint(false)
	before=screen.model.state_hash()
	await click_site(empty_socket);assert(screen.model.state_hash()==before)
	screen.model.dp=gold;screen.build_placement.refresh();check_tint(true)
	var right:=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
	right.position=Vector2(3,3);Input.parse_input_event(right);await frames()
	assert(screen.chosen==&"" and screen.overlay==null);check_hud(false)
	# Native Cancel button, pause transition and rebuilt portrait UI all restore correctly.
	screen._choose(&"guard_1");screen.build_placement.cancel_button.pressed.emit();check_hud(false)
	screen._choose(&"caster_1");screen._show_pause();assert(screen.chosen==&"")
	for control:Control in screen.build_placement.hud:assert(control.visible)
	screen.paused=false;screen._dismiss()
	screen._choose(&"sniper_1")
	I18n.set_locale(&"zh-CN")
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100)
	await frames(12)
	await pointer(screen.world.position+screen.world.screen_of(empty_socket));check_hud(true);check_tint(true)
	assert(screen.build_placement.cancel_button.text=="取消建造")
	await shot("portrait_placement_cn")
	screen.build_placement.cancel_button.pressed.emit();check_hud(false)
	# Guided placement still has visible targets after cancellation or advancing.
	screen._show_tutorial();screen._tutorial_step=1
	(screen.overlay as FablewoodTutorialCallout).refresh()
	screen._choose(&"caster_1");assert(screen._tutorial_step==2);check_hud(true)
	screen.build_placement.cancel();assert(screen._tutorial_step==1);check_hud(false)
	screen._choose(&"caster_1");screen._tutorial_advance();assert(screen._tutorial_step==2)
	# The current callout deliberately avoids its spotlight. An arbitrary
	# distant pad may be covered by the card after the portrait relayout.
	var tutorial_socket:Vector2i=screen.world.pick(screen._tutorial_target_rect().get_center()-screen.world.position)
	await click_site(tutorial_socket);assert(screen._tutorial_step==3);check_hud(false)
	screen._skip_tutorial()
	print("FABLEWOOD_BUILD_PLACEMENT_PASS: cursor, blue/red validity, occupied sites, gold, camera, input, HUD, cancel, EN/CN portrait, tutorial")
	get_tree().quit()
