extends Node
const OUT:="/home/ubuntu/fablewood_source/captures/"
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
func _ready()->void:
	get_window().size=Vector2i(1440,900)
	get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false))
	assert(Game.start_campaign_stage(&"s1"))
	await frames(15)
	var screen:Control=Game.content
	screen._skip_tutorial();screen.paused=true
	var m:FablewoodBattle=screen.model
	m.wave=1;m.wave_active=true
	var segments:=[1,4,6,14]
	for kind:StringName in [&"goblin",&"orc",&"troll",&"dragon"]:
		for old:EnemyState in m.enemies:old.alive=false
		for segment:int in segments:
			m._spawn({"enemy_id":kind,"path_idx":0})
			m.enemies[-1].progress_units=segment*Pathing.PROGRESS_SCALE+150000
		screen._refresh_hud()
		await shot("facing_"+String(kind)+"_a")
		m.step(15)
		await shot("facing_"+String(kind)+"_b")
	print("FACING_SWEEP_COMPLETE: each type SE NE NW SW, stable camera, 15-tick displacement")
	get_tree().quit()
