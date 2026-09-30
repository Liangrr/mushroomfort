extends Node
const OUT:="/home/ubuntu/fablewood_upgrade_fix/"
var screen:Control
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	var m:FablewoodBattle=screen.model
	assert(m.apply_action([&"deploy",&"caster_1",Vector2i(4,3),0]))
	var u:UnitState=m.units[-1];screen.selected_id=u.id;screen.world.selected=u.id
	var cost:int=m.upgrade_cost(u);m.dp=cost-1
	screen._refresh_inspector();screen._refresh_hud();await frames()
	var button:Button=screen._tutorial_upgrade_button
	var identity:int=button.get_instance_id()
	assert(button.disabled)
	await shot("below_cost")
	# Award real kill gold, then let the normal active-wave HUD refresh run.
	m.wave=1;m.wave_active=true;m._spawn({"enemy_id":&"goblin","path_idx":0})
	var enemy:EnemyState=m.enemies[-1]
	m._spawn({"enemy_id":&"goblin","path_idx":0}) # Keep the wave running; no cleared-event inspector rebuild.
	m._damage_enemy(enemy,enemy.hp+1000,DamageRules.Kind.PHYSICAL)
	assert(m.dp>=cost)
	screen.paused=false;await frames(2);screen.paused=true;await frames()
	assert(screen.selected_id==u.id and screen._tutorial_upgrade_button.get_instance_id()==identity)
	assert(not button.disabled,"Upgrade must enable immediately after earned gold, without reselection")
	await shot("earned_gold_enabled")
	# Gold can also decrease; update in place without throwing away keyboard focus.
	button.grab_focus();m.dp=cost-1;screen._refresh_hud();assert(button.disabled)
	m.dp=cost;screen._refresh_hud();assert(not button.disabled)
	assert(button.get_instance_id()==identity)
	# The original action remains wired and creates the next tier's inspector.
	button.pressed.emit();await frames();assert(m.tier(u)==2)
	var next:Button=screen._tutorial_upgrade_button
	m.dp=m.upgrade_cost(u)-1;screen._refresh_hud();assert(next.disabled)
	m.dp=m.upgrade_cost(u);screen._refresh_hud();assert(not next.disabled)
	next.pressed.emit();await frames();assert(m.tier(u)==3)
	m.dp=9999;screen._refresh_hud();assert(screen._tutorial_upgrade_button.disabled)
	# Rebuild through the real locale/orientation path and recheck exact affordability.
	I18n.set_locale(&"zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	assert(screen._tutorial_upgrade_button.disabled)
	assert(m.apply_action([&"deploy",&"sniper_1",Vector2i(6,3),0]))
	u=m.units[-1];screen.selected_id=u.id;screen.world.selected=u.id
	m.dp=m.upgrade_cost(u)-1;screen._refresh_inspector();screen._refresh_hud();await frames()
	next=screen._tutorial_upgrade_button;assert(next.disabled)
	m.dp+=1;screen._refresh_hud();assert(not next.disabled)
	await shot("portrait_cn_enabled")
	m.apply_action([&"resign"]);screen._refresh_hud();assert(next.disabled)
	print("UPGRADE_AVAILABILITY_PASS: real earned gold, exact threshold, spend/re-enable, stable control identity, upgrade/max tier, localized portrait, terminal rejection")
	get_tree().quit()
