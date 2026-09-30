extends Node
const OUT:="/home/ubuntu/fablewood_auto_wave/"
var screen:Control
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func press(code:Key)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e)
	await frames(2);e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await frames(2)
func click(button:Button)->void:
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.global_position=point;e.pressed=true
	Input.parse_input_event(e);await frames(2);e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await frames(2)
func clear_wave()->void:
	var m:FablewoodBattle=screen.model
	while m.wave_active and m.result==BattleModel.Result.RUNNING:
		m.step()
		for enemy:EnemyState in m.enemies:
			if enemy.alive:m._damage_enemy(enemy,enemy.hp+1000,DamageRules.Kind.PHYSICAL)
	screen._present_events();screen._refresh_hud()
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen.set_process(false);screen._skip_tutorial();screen.paused=false
	var m:FablewoodBattle=screen.model
	# A new preparation period starts once, including the first wave after onboarding.
	screen._preparation_wave=-1;screen._refresh_hud()
	assert(screen._preparation_remaining==30 and screen._next.text.contains("30s"))
	await shot("countdown_30_en")
	var tick:int=m.tick;screen._process(12)
	assert(screen._preparation_remaining==18 and m.tick==tick and m.wave==0)
	# Battle speed never eats the player's real preparation time.
	for speed:int in range(1,5):
		screen._set_game_speed(speed);var before:float=screen._preparation_remaining
		screen._process(1);assert(screen._preparation_remaining==before-1)
	assert(screen._preparation_remaining==14)
	# Pausing, a modal, tutorial and the global developer pause all freeze it.
	await press(KEY_SPACE);screen._process(10);assert(screen._preparation_remaining==14)
	await press(KEY_SPACE);assert(not screen.paused)
	screen._show_settings();screen._advance_preparation(10);assert(screen._preparation_remaining==14);screen._dismiss()
	screen._show_tutorial();screen._advance_preparation(10);assert(screen._preparation_remaining==14)
	screen._skip_tutorial();screen.paused=false
	get_tree().paused=true;screen._advance_preparation(10);assert(screen._preparation_remaining==14);get_tree().paused=false
	# Rebuilding or translating UI does not reset an in-progress countdown.
	I18n.set_locale(&"zh-CN");await frames();assert(screen._preparation_remaining==14)
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(8)
	assert(screen._preparation_remaining==14)
	await shot("countdown_cn_portrait")
	screen._advance_preparation(9);assert(screen._preparation_remaining==5)
	await shot("countdown_5_cn")
	screen._advance_preparation(4.5);assert(m.wave==0 and screen._next.text.contains("1秒"))
	screen._advance_preparation(0.5);assert(m.wave==1 and m.wave_active and not screen._next.wave_ready and screen._preparation_remaining==0)
	screen._advance_preparation(30);assert(m.wave==1,"Expiry can start only one wave")
	clear_wave();assert(screen._preparation_remaining==30 and screen._next.wave_ready)
	# An early button click cancels the timer and starts immediately.
	screen._advance_preparation(4);await click(screen._next);assert(m.wave==2 and m.wave_active and screen._preparation_remaining==0)
	clear_wave();assert(screen._preparation_remaining==30)
	screen._advance_preparation(7);await press(KEY_ENTER);assert(m.wave==3 and m.wave_active and screen._preparation_remaining==0)
	clear_wave()
	# Reduced motion preserves the functional numeric/bar countdown.
	screen._reduced_motion=true;screen._process(1);assert(screen._preparation_remaining==29)
	# Finish remaining waves normally; no hidden ninth countdown or delayed callback.
	while m.wave<8:
		screen._next_wave();clear_wave()
	assert(m.result==BattleModel.Result.CLEAR and screen._preparation_remaining==0 and not screen._next.wave_ready)
	screen._advance_preparation(100);assert(m.wave==8)
	# New scene/chapter gets a fresh timer. Old scene owns no deferred timers.
	Game.open_title();await frames();assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(12)
	screen=Game.content;screen.set_process(false);screen._skip_tutorial();screen.paused=false;screen._preparation_wave=-1;screen._refresh_hud()
	assert(screen._preparation_remaining==30 and screen.model.wave==0)
	I18n.set_locale(&"en-US");get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900);await frames(8)
	screen._show_tutorial();screen._tutorial_step=5;screen.overlay.refresh();await shot("countdown_tutorial_en")
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(8)
	await shot("countdown_tutorial_cn")
	print("AUTO_WAVE_PASS: 30 active seconds independent of speed; pause/modal/tutorial guards; locale/resize retention; exactly-once expiry; button/Enter early start; all-wave reset/final suppression; replay fresh; reduced motion")
	get_tree().quit()
