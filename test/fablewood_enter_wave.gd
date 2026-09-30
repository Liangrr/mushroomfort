extends Node
const OUT:="/home/ubuntu/fablewood_enter/"
var screen:Control
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func press(code:Key=KEY_ENTER,echo:bool=false)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;e.echo=echo
	Input.parse_input_event(e);await frames(2)
	e=e.duplicate();e.pressed=false;e.echo=false;Input.parse_input_event(e);await frames(2)
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false)
	var m:FablewoodBattle=screen.model
	screen._set_game_speed(3);screen._speed_button.grab_focus();await frames()
	await shot("ready_enter_hint")
	await press();assert(m.wave==1 and m.wave_active and screen.speed==3,"Enter starts wave rather than activating focused Speed")
	await press();assert(m.wave==1 and screen.speed==3,"Unavailable wave consumes Enter without unrelated actions")
	m.wave_active=false;screen._refresh_hud();await press(KEY_ENTER,true);assert(m.wave==1)
	await press(KEY_KP_ENTER);assert(m.wave==2 and m.wave_active)
	await shot("enter_started_wave")
	m.wave_active=false;screen.paused=true;await press();assert(m.wave==2)
	screen.paused=false
	var input:=LineEdit.new();screen.canvas.add_child(input);input.grab_focus();await frames()
	await press();assert(m.wave==2,"Text input owns Enter")
	input.queue_free();await frames()
	var modal:=Control.new();screen.canvas.add_child(modal);screen.overlay=modal
	await press();assert(m.wave==2,"Modal owns Enter")
	screen.overlay=null;modal.queue_free();await frames()
	screen._ended=true;await press();assert(m.wave==2);screen._ended=false
	m.wave=8;await press();assert(m.wave==8,"No ninth wave")
	# The normal tutorial's focused Next/Finish actions keep their Enter behavior.
	m.wave=0;screen._show_tutorial();await frames();await press()
	assert(m.wave==0 and screen._tutorial_active)
	screen._skip_tutorial();screen.paused=false
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen._dismiss();screen.paused=false;assert(screen._next.tooltip_text.contains("Enter"))
	await press();assert(m.wave==1 and m.wave_active)
	await shot("enter_cn_portrait")
	print("ENTER_NEXT_WAVE_PASS: Enter/keypad Enter, focused-button override, availability/repeat/pause/modal/text/tutorial/end guards, localized UI")
	get_tree().quit()
