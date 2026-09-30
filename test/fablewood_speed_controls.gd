extends Node
const OUT:="/home/ubuntu/fablewood_speed/"
var screen:Control
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func key(code:Key,echo:bool=false,ctrl:bool=false)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.unicode=code;e.pressed=true;e.echo=echo;e.ctrl_pressed=ctrl
	Input.parse_input_event(e);await frames(2)
	e=e.duplicate();e.pressed=false;e.echo=false;Input.parse_input_event(e);await frames(2)
func click_button()->void:
	var pos:Vector2=screen._speed_button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pos;motion.global_position=pos;Input.parse_input_event(motion)
	var e:=InputEventMouseButton.new();e.position=pos;e.global_position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true
	Input.parse_input_event(e);await frames(2);e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await frames(2)
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=false
	assert(screen.speed==1 and screen._speed_button.text=="1×")
	await key(KEY_Q);assert(screen.speed==1)
	for n:int in [2,3,4]:
		await key(KEY_E);assert(screen.speed==n and screen._speed_button.text=="%d×"%n)
	await key(KEY_E);assert(screen.speed==4)
	await shot("speed_4x")
	await key(KEY_Q);assert(screen.speed==3)
	await key(KEY_E,true);assert(screen.speed==3,"Key repeat must not run away")
	await key(KEY_Q,false,true);assert(screen.speed==3,"Modifier shortcut must not change speed")
	# Pointer clicks cycle forward and wrap from four back to one.
	screen._set_game_speed(1)
	for n:int in [2,3,4,1]:
		await click_button();assert(screen.speed==n and screen._speed_button.text=="%d×"%n)
	# Paused/modal input cannot change speed.
	screen._set_game_speed(3);screen._show_pause();await frames()
	await key(KEY_E);assert(screen.speed==3)
	screen._dismiss();screen.paused=false
	# Typing into a GUI field must consume the keys before gameplay.
	var entry:=LineEdit.new();screen.canvas.add_child(entry);entry.grab_focus();await frames()
	await key(KEY_E);assert(screen.speed==3);entry.queue_free();await frames()
	# Fixed-step combat advances exactly the selected multiple; audio/UI clocks are untouched.
	screen.set_process(false)
	var m:FablewoodBattle=screen.model;m.wave=1;m.wave_active=true;m._spawn({"enemy_id":&"troll","path_idx":0})
	for n:int in [1,2,3,4]:
		screen._set_game_speed(n);screen.accumulator=0;var before:=m.tick
		screen._process(0.03333334);assert(m.tick-before==n,"Fixed steps must match current speed")
	screen.paused=true;var frozen:=m.tick;screen._process(0.1);assert(m.tick==frozen)
	screen._ended=true;screen._set_game_speed(1);assert(screen.speed==4);screen._ended=false
	# Resize/locale retain the selected speed and localized hint.
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	screen._dismiss();screen.paused=true
	assert(screen.speed==4 and screen._speed_button.text=="4×" and screen._speed_button.tooltip_text.contains("减速"))
	await shot("speed_cn_portrait")
	screen._show_tutorial();await frames();await key(KEY_Q)
	assert(screen.speed==4,"Unrelated tutorial steps must keep their input ownership")
	screen._tutorial_step=4;screen.overlay.refresh();await frames();await key(KEY_Q)
	assert(screen.speed==3 and screen.paused,"Camera tutorial permits speed controls without unpausing")
	await shot("speed_tutorial_cn")
	I18n.set_locale(&"en-US");get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900);await frames(12)
	await shot("speed_tutorial_en")
	print("GAME_SPEED_CONTROLS_PASS: Q/E clamped, clicks cycle 1–4, active labels, repeat/modifier/modal/text-input guards, exact fixed stepping, locale/resize retention")
	get_tree().quit()
