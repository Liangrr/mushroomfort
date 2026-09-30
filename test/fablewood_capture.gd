extends Node
const OUT := "user://fablewood_source/captures/"
func settle(frames:int=5) -> void:
	for i:int in frames:await get_tree().process_frame
func shot(name:String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK)
	print("CAPTURE ",name)
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900)
	get_window().content_scale_size=Vector2i(1440,900)
	await settle()
	Game.open_title()
	await settle(20)
	await shot("title_en")
	I18n.set_locale(&"zh-CN")
	await shot("title_cn")
	I18n.set_locale(&"en-US")
	assert(Game.start_campaign(false))
	Game.open_stage_select()
	await settle(15)
	await shot("chapters")
	assert(Game.start_campaign_stage(&"s1"))
	await settle(15)
	var screen:Control=Game.content
	await shot("tutorial")
	screen._skip_tutorial()
	screen.paused=true
	var m:FablewoodBattle=screen.model
	m.dp=8000
	var pads:Array[Vector2i]=[]
	for y:int in 8:
		for x:int in 10:
			if m.stage.is_elevated_platform(Vector2i(x,y)):pads.append(Vector2i(x,y))
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	for i:int in pads.size():
		m.apply_action([&"deploy",ids[i/3],pads[i],0])
		for level:int in i%3:m.apply_action([&"upgrade",m.units[-1].id])
	screen.selected_id=2
	screen.world.selected=2
	screen._refresh_inspector()
	screen._refresh_hud()
	screen._present_events()
	await settle(65)
	screen.world.effects.clear()
	# This scene pauses presentation before mass-deploying/upgrading every tier.
	# Clear its intentionally frozen bursts for the static-art reference capture.
	screen.world.combat_particles.clear()
	await shot("all_tiers_en")
	m.next_wave()
	# Real route segments cover both screen-left and screen-right movement.
	var enemy_ids:Array[StringName]=[&"goblin",&"orc",&"troll",&"dragon"]
	for i:int in 4:
		m._spawn({"enemy_id":enemy_ids[i],"path_idx":0})
		m.enemies[-1].progress_units=(i*5+1)*Pathing.PROGRESS_SCALE
	screen._refresh_hud()
	await shot("combat_a")
	for u:UnitState in m.units:u.atk_counter=999
	m.step(15)
	screen._present_events()
	await shot("combat_b")
	for i:int in 4:m.enemies[i].progress_units=(7+i*3)*Pathing.PROGRESS_SCALE
	await shot("turns_a")
	m.step(15)
	await shot("turns_b")
	I18n.set_locale(&"zh-CN")
	screen._dismiss()
	screen.paused=true
	await shot("battle_cn")
	screen._show_pause()
	await shot("pause_cn")
	screen._dismiss()
	get_window().size=Vector2i(720,1100)
	get_window().content_scale_size=Vector2i(720,1100)
	await settle(15)
	await shot("portrait_cn")
	I18n.set_locale(&"en-US")
	screen._dismiss()
	screen.paused=true
	await shot("portrait_en")
	screen.world.change_zoom(1.8)
	await shot("zoom_in")
	screen.world.change_zoom(0.3)
	await shot("zoom_out")

	# Every tutorial page can be skipped without a lingering input/pause lock.
	for page:int in 3:
		screen.paused=false;screen._show_tutorial();screen._tutorial_step=page;screen._tutorial_page()
		screen._skip_tutorial()
		assert(not screen.paused and screen.overlay==null)
	screen.paused=true
	screen._show_settings()
	await shot("settings_en")
	screen._dismiss()
	# Tweak is an Addon-hosted browser popover, not a native game panel.
	assert(not TweakControls.has_method("toggle"))
	# Real terminal route, using the current canonical ticket; no record shortcut.
	m.apply_action([&"resign"])
	assert(Game.record_result(m.result,m.stars))
	Game.open_results()
	await settle(15)
	await shot("defeat_results")
	var results:Control=Game.content
	results._show_scores()
	await shot("standings")
	results._dismiss()
	get_window().size=Vector2i(1440,900)
	get_window().content_scale_size=Vector2i(1440,900)
	# Result surface in both languages, using the saved data structure for layout.
	Game.last_result["result"]=BattleModel.Result.CLEAR
	Game.last_result["stars"]=3
	results._build();results._resize()
	await shot("victory_results")
	I18n.set_locale(&"zh-CN")
	await shot("victory_cn")
	print("FABLEWOOD_NATIVE_CAPTURE_COMPLETE")
	get_tree().quit()
