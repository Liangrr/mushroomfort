extends Node
const OUT:="/home/ubuntu/fablewood_controls/"
var screen:Control
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func press(code:Key,echo:bool=false)->void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.unicode=code if code==KEY_U else 0;e.pressed=true;e.echo=echo
	Input.parse_input_event(e);await frames(2);e=e.duplicate();e.pressed=false;e.echo=false;Input.parse_input_event(e);await frames(2)
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false)
	var m:FablewoodBattle=screen.model;var next:Button=screen._next
	assert(next.wave_ready and not next.disabled)
	next.set_process(false);var bounds:Rect2=next.get_global_rect()
	next.pulse_elapsed=0;next.queue_redraw();await shot("ready_low")
	next._advance_pulse(1.1);assert(next.pulse_elapsed>1);await shot("ready_high")
	assert(next.get_global_rect()==bounds and next.scale==Vector2.ONE)
	screen._set_game_speed(3);screen._speed_button.grab_focus();await frames()
	await press(KEY_SPACE);assert(screen.paused and m.wave==0 and screen.speed==3)
	var phase:float=next.pulse_elapsed;next._process(0.2);assert(next.pulse_elapsed==phase)
	await press(KEY_SPACE,true);assert(screen.paused)
	await shot("space_paused")
	await press(KEY_SPACE);assert(not screen.paused and screen.overlay==null and m.wave==0)
	# U only spends gold for the selected, non-maxed, affordable tower.
	assert(m.apply_action([&"deploy",&"caster_1",Vector2i(4,3),0]))
	var u:UnitState=m.units[-1];screen.selected_id=u.id;screen.world.selected=u.id
	m.dp=m.upgrade_cost(u)-1;screen._refresh_inspector();screen._refresh_hud();var gold:int=m.dp
	await press(KEY_U);assert(m.tier(u)==1 and m.dp==gold)
	m.dp=m.upgrade_cost(u);screen._refresh_hud();screen._speed_button.grab_focus()
	await press(KEY_U);assert(m.tier(u)==2 and m.dp==0 and screen.selected_id==u.id and screen.speed==3)
	assert(screen.world.combat_particles.particles.size()>0,"U reuses successful upgrade feedback")
	await shot("u_upgrade")
	m.dp=999;gold=m.dp;await press(KEY_U,true);assert(m.tier(u)==2 and m.dp==gold)
	await press(KEY_U);assert(m.tier(u)==3);gold=m.dp
	await press(KEY_U);assert(m.tier(u)==3 and m.dp==gold)
	screen.selected_id=-1;screen._refresh_inspector();await press(KEY_U);assert(m.dp==gold)
	# Settings and text entry do not become accidental resume/upgrade shortcuts.
	screen._show_pause();screen._show_settings();await frames();var settings:Control=screen.overlay
	screen._speed_button.grab_focus();await press(KEY_SPACE);assert(screen.paused and screen.overlay==settings)
	screen._dismiss();screen.paused=false
	var entry:=LineEdit.new();screen.canvas.add_child(entry);entry.grab_focus();await frames()
	await press(KEY_SPACE);await press(KEY_U);assert(not screen.paused and m.wave==0 and m.dp==gold)
	entry.queue_free();await frames()
	# Enter still starts waves; readiness pulse stops and returns after a real clear.
	await press(KEY_ENTER);assert(m.wave==1 and m.wave_active and not next.wave_ready)
	screen._set_game_speed(4)
	screen._process(0.03333334);var before_pause:int=m.tick
	await press(KEY_SPACE);screen._process(0.1);assert(m.tick==before_pause and screen.paused)
	await press(KEY_SPACE);screen._process(0.03333334);assert(m.tick>before_pause and not screen.paused and screen.speed==4)
	while m.wave_active:
		m.step()
		for enemy:EnemyState in m.enemies:
			if enemy.alive:m._damage_enemy(enemy,enemy.hp+1000,DamageRules.Kind.PHYSICAL)
	screen._refresh_hud();assert(next.wave_ready and not next.disabled and next.pulse_elapsed==0)
	next._advance_pulse(0.4);screen._reduced_motion=true;phase=next.pulse_elapsed;next._process(0.4);assert(next.pulse_elapsed==phase)
	next.set_wave_ready(false);assert(next.pulse_elapsed==0 and next.disabled)
	next.set_wave_ready(true);next._advance_pulse(500);assert(next.pulse_elapsed<next.PULSE_PERIOD)
	# Chinese portrait layout and reduced-motion fallback remain readable.
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen._dismiss();screen.paused=false;screen._reduced_motion=false;screen._next.set_process(false);screen._next._advance_pulse(1.1)
	await shot("ready_cn_portrait")
	m.wave=8;screen._refresh_hud();assert(not screen._next.wave_ready and screen._next.disabled)
	screen._ended=true;await press(KEY_SPACE);assert(not screen.paused)
	print("READY_CONTROLS_PASS: pulse ready/active/clear/end lifecycle, bounded phase, pause/reduced motion, exact U affordability/tier/gold/feedback and Space toggles without waves; modal/text guards and Enter retained")
	get_tree().quit()
