extends "res://test/fablewood_walk_audit_capture.gd"
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	model=screen.model;model.wave=1;model.wave_active=true
	for segment:int in [1,4,6,14]:
		model._spawn({"enemy_id":&"dragon","path_idx":0});model.enemies[-1].progress_units=segment*Pathing.PROGRESS_SCALE
	A.advance(model,screen.world._enemy_motion,false)
	await shot("dragon_shared_a")
	screen.world.capture_enemy_tick();model.step(2);A.advance(model,screen.world._enemy_motion,false)
	screen.world.render_alpha=0.5;await shot("dragon_shared_mid")
	screen.world.render_alpha=1.0;await shot("dragon_shared_b")
	print("DRAGON_SHARED_RENDERING_REGRESSION_PASS")
	get_tree().quit()
