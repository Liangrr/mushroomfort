extends Node
const OUT:="user://fablewood_upgrade_feedback/"
var screen:Control
var m:FablewoodBattle
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK)
func check_text(b:Button)->void:
	var font:=b.get_theme_font("font");var px:=b.get_theme_font_size("font_size")
	for line:String in b.text.split("\n"):
		assert(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x<=b.size.x-16,"Shortfall label must not clip")
	assert(not b.get_global_rect().intersects(screen._cards[0].get_parent().get_global_rect()),"Build tray must not cover upgrade text")
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(TweakControls.set_value(&"ui.text_scale",1.2))
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	assert(is_equal_approx(float(TweakControls.active_value(&"ui.text_scale")),1.2))
	screen=Game.content;screen._skip_tutorial();screen.paused=true;m=screen.model
	assert(m.apply_action([&"deploy",&"caster_1",Vector2i(4,3),0]))
	var u:UnitState=m.units[-1];var cost:int=m.upgrade_cost(u)
	screen.selected_id=u.id;screen.world.selected=u.id;m.dp=cost-27
	screen._present_events();screen._refresh_inspector();screen._refresh_hud();await frames()
	var b:FablewoodUpgradeButton=screen._tutorial_upgrade_button
	assert(b.disabled and b.text=="Upgrade  72\nNeed 27 more gold")
	assert(b.pulse_count==0);check_text(b);await shot("shortfall_en")
	m.dp=cost-1;screen._refresh_hud();assert(b.text.ends_with("Need 1 more gold"))
	m.dp=cost;screen._refresh_hud();assert(not b.disabled and b.pulse_count==1 and b._pulse_active)
	var identity:=b.get_instance_id();var bounds:=b.get_global_rect()
	for i:int in 30:screen._refresh_hud()
	assert(b.pulse_count==1 and b.get_instance_id()==identity)
	b._advance_pulse(0.48);await shot("affordable_pulse")
	assert(bounds==b.get_global_rect())
	var phase:=b._pulse_elapsed;await frames(10);assert(phase==b._pulse_elapsed,"Pause freezes pulse")
	b._advance_pulse(1.0);assert(not b._pulse_active)
	await shot("affordable_settled")
	m.dp=cost-4;screen._refresh_hud();m.dp=cost;screen._refresh_hud();assert(b.pulse_count==2)
	screen._reduced_motion=true;b._process(0.01);assert(not b._pulse_active)
	m.dp=cost-2;screen._refresh_hud();m.dp=cost;screen._refresh_hud();assert(b.pulse_count==2)
	screen._reduced_motion=false
	# Actual success emits the unique pattern; invalid upgrade does not emit anything.
	screen.world.combat_particles.clear();screen.world.effects.clear();m.drain_events()
	m.dp=cost-1;assert(not m.apply_action([&"upgrade",u.id]));screen._present_events()
	assert(screen.world.combat_particles.particles.is_empty() and screen.world.effects.is_empty())
	m.dp=cost;screen._refresh_hud()
	# Real gameplay button actions require an unpaused battle.
	screen.paused=false;b.pressed.emit();screen.paused=true;await frames()
	assert(m.tier(u)==2)
	assert(screen.world.effects.any(func(e:Dictionary)->bool:return e.kind=="ascend"))
	assert(screen.world.combat_particles.particles.size()==28)
	assert(screen.world.combat_particles.particles.all(func(p:Dictionary)->bool:return bool(p.get("upgrade",false))))
	screen.world.combat_particles.advance(0.22,screen.world)
	for fx:Dictionary in screen.world.effects:fx.life-=0.22
	assert(not screen._notice.get_global_rect().intersects(screen._tutorial_camera_row.get_global_rect()))
	await shot("fire_upgrade_burst")
	var frozen:Array=screen.world.combat_particles.particles.duplicate(true);await frames(10)
	assert(screen.world.combat_particles.particles==frozen)
	# Cover every elemental burst on actual successful upgrades.
	var ids:Array[StringName]=[&"sniper_1",&"recruit",&"guard_1"]
	var pads:Array[Vector2i]=[Vector2i(6,3),Vector2i(4,5),Vector2i(6,5)]
	for i:int in 3:
		m.dp=9999;assert(m.apply_action([&"deploy",ids[i],pads[i],0]));u=m.units[-1]
		m.drain_events();screen.world.combat_particles.clear();screen.world.effects.clear()
		assert(m.apply_action([&"upgrade",u.id]));screen._present_events()
		assert(screen.world.combat_particles.particles.size()==28)
		screen.world.combat_particles.advance(0.22,screen.world)
		for fx:Dictionary in screen.world.effects:fx.life-=0.22
		await shot("upgrade_element_%d"%i)
	# Reduced motion retains a static success ring, with no moving particles.
	screen.world.combat_particles.clear();screen.world.effects.clear();screen.world.reduced_motion=true
	assert(m.apply_action([&"upgrade",u.id]));screen._present_events()
	assert(screen.world.combat_particles.particles.is_empty())
	await shot("reduced_upgrade")
	screen.world.combat_particles.advance(3.0,screen.world)
	# Localized, large-text portrait shortfall uses the same live control.
	assert(is_equal_approx(float(TweakControls.value(&"ui.text_scale")),1.2))
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	screen._dismiss();screen.paused=true;u=m.units[1];screen.selected_id=u.id;screen.world.selected=u.id
	cost=m.upgrade_cost(u);m.dp=cost-35;screen._refresh_inspector();screen._refresh_hud();await frames()
	b=screen._tutorial_upgrade_button;assert(b.text.ends_with("还需 35 金币"));check_text(b)
	await shot("shortfall_cn_portrait")
	I18n.set_locale(&"en-US");get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900);await frames(10)
	screen._dismiss();screen.paused=true;m.dp=0;screen._refresh_hud();await frames()
	b=screen._tutorial_upgrade_button;check_text(b);await shot("shortfall_large_en")
	m.dp=m.upgrade_cost(u);screen._refresh_hud()
	screen.paused=false;b.pressed.emit();screen.paused=true;await frames()
	m.dp=9999;screen._refresh_hud();b=screen._tutorial_upgrade_button
	assert(b.disabled and b.text=="Fully awakened" and not b._pulse_active)
	print("UPGRADE_FEEDBACK_NATIVE_PASS: exact labels, one-shot pulse/lifecycle, four success-only bursts, reduced motion, EN/CN and large text")
	get_tree().quit()
