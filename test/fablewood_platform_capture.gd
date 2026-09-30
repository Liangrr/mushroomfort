extends Node
const OUT:="/home/ubuntu/fablewood_platform_alignment/native/"
var screen:Control
var model:FablewoodBattle
var pads:Array[Vector2i]=[]
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("PLATFORM_NATIVE ",name)
func focus(cell:Vector2i,z:float)->void:
	screen.world.zoom=z;screen.world.pan=Vector2.ZERO;screen.world.framing()
	screen.world.pan=screen.world.size*.5-screen.world.screen_of(cell)
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true;model=screen.model
	for y:int in model.stage.grid_size().y:
		for x:int in model.stage.grid_size().x:
			var c:=Vector2i(x,y)
			if model.stage.is_elevated_platform(c):pads.append(c)
	var world:FablewoodWorld=screen.world
	for z:float in [0.7,1.0,1.85]:
		world.zoom=z;await frames()
		for c:Vector2i in pads:
			var expected:=world.platform_rect(c).position+Vector2(126,138)/256.0*Vector2(64,49)
			assert(world.cell_center(c).is_equal_approx(expected))
			assert(world.pick(world.screen_of(c))==c)
	world.reset_view();await shot("empty_overview")
	world.selected_element="fire";focus(Vector2i(4,3),1.85);await shot("empty_selected_zoom")
	# Native user-sized close-up, all twelve unique tower tiers and shared bases.
	model.dp=100000
	for i:int in mini(12,pads.size()):
		assert(model.apply_action([&"deploy",[&"caster_1",&"sniper_1",&"recruit",&"guard_1"][floori(i/3.0)],pads[i],0]))
		for level:int in i%3:assert(model.apply_action([&"upgrade",model.units[-1].id]))
	world._advance_tower_animation(0.0)
	assert(world._tower_motion.size()==12)
	for u:UnitState in model.units:
		var point:Vector2=world.TOWER_FOOTPRINT_CENTERS[model.element(u)][model.tier(u)-1]
		for animated:bool in [false,true]:
			var uv:Vector2=(point+Vector2(32,40))/Vector2(320,400) if animated else point/Vector2(256,320)
			var rect:=world.tower_draw_rect(u,animated)
			assert((rect.position+uv*rect.size).is_equal_approx(world.platform_surface_center(u.cell)))
	world.selected_element="";world.reset_view();screen._refresh_hud();await shot("all_tiers")
	for element:int in 4:
		focus(pads[element*3+1],1.85)
		world.selected=model.units[element*3+1].id
		for state:Dictionary in world._tower_motion.values():state.phase=0.0
		await shot("element_%d_phase_0"%element)
		for state:Dictionary in world._tower_motion.values():state.phase=2.0
		await shot("element_%d_phase_2"%element)
	world.reduced_motion=true;await shot("static_reduced_motion")
	I18n.set_locale(&"zh-CN");await frames()
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	world=screen.world;world.reduced_motion=true
	focus(pads[7],1.85);await shot("portrait_cn")
	world.reduced_motion=false;await shot("portrait_cn_animated")
	# The same visual anchor must survive upgrades, selling and returning empty.
	var cell:Vector2i=pads[7];var anchor:=world.screen_of(cell)
	var u:UnitState=model.alive_unit_at(cell)
	assert(model.apply_action([&"upgrade",u.id]));assert(world.screen_of(cell).is_equal_approx(anchor))
	assert(model.apply_action([&"retreat",u.id]));world.selected=-1;world.selected_element="storm"
	assert(world.pick(anchor)==cell);await shot("sold_empty")
	print("ALL_PLATFORM_SURFACE_NATIVE_CHECKS_PASS")
	get_tree().quit()
