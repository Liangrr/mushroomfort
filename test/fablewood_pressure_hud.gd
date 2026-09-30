extends Node
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	var screen:Control=Game.content
	screen._skip_tutorial();screen.paused=true
	var m:FablewoodBattle=screen.model
	assert(m.apply_action([&"deploy",&"caster_1",Vector2i(4,3),0]))
	screen.selected_id=m.units[-1].id;screen.world.selected=screen.selected_id
	screen._refresh_inspector();screen._refresh_hud();await frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/ubuntu/fablewood_alignment/native/damage_hud.png")
	print("ROUNDED_DAMAGE_HUD_CAPTURED")
	get_tree().quit()
