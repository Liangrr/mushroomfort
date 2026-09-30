extends Node
const OUT:="user://fablewood_callouts/native/"
var screen:Control
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func click(at:Vector2)->void:
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion)
	for pressed:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event);await frames(2)
func tap(at:Vector2)->void:
	for pressed:bool in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed
		Input.parse_input_event(event);await frames(2)
func target_center()->Vector2:
	return screen.canvas.get_global_transform_with_canvas()*screen._tutorial_target_rect().get_center()
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	# Text scale is captured when a real chapter starts, not on a UI rebuild.
	assert(TweakControls.set_value(&"ui.text_scale",1.2))
	assert(I18n.reload_catalogs());assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	assert(is_equal_approx(float(TweakControls.active_value(&"ui.text_scale")),1.2))
	screen=Game.content;if screen._tutorial_active:screen._skip_tutorial()
	screen._show_tutorial();screen._tutorial_step=1;(screen.overlay as FablewoodTutorialCallout).refresh();await frames()
	await click(target_center());assert(screen._tutorial_step==2,"Mouse input passes through the selected tower spotlight")
	await tap(target_center());assert(screen._tutorial_step==3 and screen.model.units.size()==1,"Touch input passes through to the root pad")
	await frames();await click(screen._tutorial_upgrade_button.get_global_rect().get_center())
	assert(screen._tutorial_step==4,"Upgrade button remains usable through the callout")
	var old_zoom:float=screen.world.zoom
	var zoom_button:Button=screen._tutorial_camera_row.get_child(1)
	await click(zoom_button.get_global_rect().get_center())
	assert(screen.world.zoom>old_zoom,"Camera controls are usable through their spotlight")
	# Button input, not a direct flow-method call, exercises Skip dispatch.
	await click((screen.overlay as FablewoodTutorialCallout).skip_button.get_global_rect().get_center())
	assert(not screen._tutorial_active and not screen.paused and screen.overlay==null)
	var cfg:=ConfigFile.new();assert(cfg.load(screen._settings_file)==OK)
	assert(cfg.get_value("settings","tutorial_version",0)==screen.TUTORIAL_VERSION)
	assert(cfg.get_value("settings","tutorial_status","")=="skipped")
	# Keyboard Escape dismisses the entire tutorial and focus remains usable.
	screen._show_tutorial();await frames()
	var key:=InputEventKey.new();key.keycode=KEY_ESCAPE;key.pressed=true;Input.parse_input_event(key);await frames()
	assert(not screen._tutorial_active and not screen.paused)
	# Largest supported text setting is 1.2, not an invented accessibility value.
	assert(is_equal_approx(float(TweakControls.value(&"ui.text_scale")),1.2))
	screen._show_tutorial();screen._tutorial_step=5;(screen.overlay as FablewoodTutorialCallout).refresh();await frames(12)
	var tour:FablewoodTutorialCallout=screen.overlay
	assert(Rect2(Vector2.ZERO,screen._logical).encloses(Rect2(tour.card.position,tour.card.size)))
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+"large_text_en.png")==OK)
	I18n.set_locale(&"zh-CN");await frames();get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	tour=screen.overlay
	assert(Rect2(Vector2.ZERO,screen._logical).encloses(Rect2(tour.card.position,tour.card.size)))
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+"large_text_cn_portrait.png")==OK)
	screen._skip_tutorial();screen._show_pause();screen._show_tutorial();await frames()
	(screen.overlay as FablewoodTutorialCallout).skip_button.grab_focus()
	for pressed:bool in [true,false]:
		var pad:=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_A;pad.pressed=pressed
		Input.parse_input_event(pad);await frames(2)
	assert(not screen._tutorial_active and screen.paused,"Manually opened tutorial returns to Pause after gamepad Skip")
	assert(get_viewport().gui_get_focus_owner() is Button,"Pause return restores usable focus")
	screen.paused=false;screen._dismiss();screen._show_tutorial();await frames()
	var settings_path:String=screen._settings_file
	screen._settings_file="/dev/null/cannot-save.cfg"
	screen._skip_tutorial();await frames()
	assert(not screen._tutorial_active and screen.overlay!=null and screen.paused,"Storage failure is visible and does not leave tutorial locks")
	var close_buttons:Array=screen.overlay.find_children("*","Button",true,false)
	(close_buttons[0] as Button).pressed.emit();await frames()
	assert(not screen.paused and not screen.model.wave_active,"Closing a manual tutorial/error does not start a wave")
	screen._settings_file=settings_path
	print("CALLOUT_POINTER_TOUCH_KEYBOARD_LARGE_TEXT_PASS")
	get_tree().quit()
