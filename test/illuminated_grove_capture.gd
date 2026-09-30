extends Node
## Focused presentation capture; all simulation actions use the existing model.
var output:String
func settle(frames:int=8)->void:
	for i:int in frames:await get_tree().process_frame
func shot(name:String)->void:
	await settle()
	await RenderingServer.frame_post_draw
	var error:=get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))
	assert(error==OK)
	print("ILLUMINATED_CAPTURE ",name)
func _ready()->void:
	output=OS.get_environment("FABLEWOOD_CAPTURE_DIR")
	if output.is_empty():output=ProjectSettings.globalize_path("res://build/illuminated-captures")
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size=Vector2i(1440,900)
	get_window().content_scale_size=Vector2i(1440,900)
	await settle()
	I18n.set_locale(&"en-US")
	assert(Game.start_campaign(false))
	assert(Game.start_campaign_stage(&"s1"))
	await settle(20)
	var screen:Control=Game.content
	screen._skip_tutorial();screen.paused=true
	var m:FablewoodBattle=screen.model
	m.dp=8000
	var placed:=false
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			var cell:=Vector2i(x,y)
			if not placed and m.stage.is_elevated_platform(cell):
				assert(m.apply_action([&"deploy",&"caster_1",cell,0]))
				placed=true
	assert(placed)
	screen.selected_id=m.units[0].id;screen.world.selected=screen.selected_id
	m.next_wave()
	var route:=m.path_for(0)
	var spawned:=0
	for i:int in route.size()-1:
		var direction:Vector2i=route[i+1]-route[i]
		if direction.x+direction.y>0 and spawned<3 and i>1:
			m._spawn({"enemy_id":&"goblin","path_idx":0})
			m.enemies[-1].progress_units=i*Pathing.PROGRESS_SCALE+Pathing.PROGRESS_SCALE/3
			spawned+=1
	screen._refresh_hud();screen._refresh_inspector();screen._present_events()
	screen.world.effects.clear()
	screen.world.reduced_motion=true
	await shot("slice_static_en")
	screen.world.reduced_motion=false
	await shot("slice_motion_start")
	# Advance the actual distance-driven visual state without changing attack rules.
	for enemy:EnemyState in m.enemies:
		if enemy.alive:
			screen.world._enemy_motion[enemy.id]={"phase":0.72,"progress":enemy.progress_units}
	screen.world._advance_tower_animation(1.2)
	await shot("slice_motion_later")
	I18n.set_locale(&"zh-CN")
	screen._dismiss();screen.paused=true
	screen.world.reduced_motion=true
	get_window().size=Vector2i(720,1100)
	get_window().content_scale_size=Vector2i(720,1100)
	await shot("slice_static_cn_portrait")
	print("ILLUMINATED_NATIVE_CAPTURE_COMPLETE")
	get_tree().quit()
