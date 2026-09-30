extends Node
const OUT:="/home/ubuntu/fablewood_enemy_animation/native/"
var screen:Control
var model:FablewoodBattle
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("PARTICLE_NATIVE ",name)
func flush()->void:
	for event:Dictionary in model.drain_events():screen.world.add_event(event)
func advance_visual(seconds:float)->void:
	screen.world.combat_particles.advance(seconds,screen.world)
	for effect:Dictionary in screen.world.effects:effect.life=maxf(0.001,float(effect.life)-seconds)
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true;model=screen.model;model.dp=9999
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var pads:Array[Vector2i]=[Vector2i(4,3),Vector2i(6,3),Vector2i(4,5),Vector2i(6,5)]
	for i:int in 4:
		assert(model.apply_action([&"deploy",ids[i],pads[i],0]));model.upgrade(model.units[-1].id)
	flush();screen.world.combat_particles.clear();screen.world.effects.clear()
	model.wave=1;model.wave_active=true
	var kinds:Array[StringName]=[&"goblin",&"orc",&"troll",&"dragon",&"goblin",&"goblin"]
	for i:int in kinds.size():
		model._spawn({"enemy_id":kinds[i],"path_idx":0})
		model.enemies[-1].progress_units=[4,6,14,18,15,16][i]*Pathing.PROGRESS_SCALE
	model.enemies[-1].hp=1
	model.tick=1;model._tick_combat();flush()
	screen.selected_id=model.units[0].id;screen._refresh_inspector();screen._refresh_hud()
	assert(screen.world.combat_particles.particles.size()>0)
	assert(screen.world.combat_particles.decals.size()>0)
	advance_visual(0.14);await shot("particles_impact")
	var frozen:Dictionary={"particles":screen.world.combat_particles.particles.duplicate(true),"decals":screen.world.combat_particles.decals.duplicate(true)}
	await frames(12)
	assert(frozen.particles==screen.world.combat_particles.particles and frozen.decals==screen.world.combat_particles.decals,"Pause freezes particles and fading")
	advance_visual(0.25);await shot("particles_spray")
	advance_visual(0.55);await shot("particles_ground_decals")
	# Repeat genuine attacks while emitting more particles; no decorative fake hits.
	for u:UnitState in model.units:u.atk_counter=0
	model.tick+=3;model._tick_combat();flush();advance_visual(0.12)
	I18n.set_locale(&"zh-CN");await frames()
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(10)
	for u:UnitState in model.units:u.atk_counter=0
	model.tick+=3;model._tick_combat();flush();advance_visual(0.12)
	await shot("particles_portrait_cn")
	screen.world.reduced_motion=true;screen.world.combat_particles.advance(0.01,screen.world)
	assert(screen.world.combat_particles.particles.is_empty())
	await shot("particles_reduced_motion")
	screen.world.combat_particles.advance(8.0,screen.world)
	assert(screen.world.combat_particles.decals.is_empty(),"Ground blood fades and expires")
	print("ALL_PARTICLE_NATIVE_CHECKS_PASS")
	get_tree().quit()
