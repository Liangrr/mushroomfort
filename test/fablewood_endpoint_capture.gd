extends Node
const OUT:="/home/ubuntu/fablewood_endpoints/native/"
const A:=preload("res://scripts/fablewood/endpoint_animation.gd")
var screen:Control
func frames(n:int=4)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("ENDPOINT_NATIVE ",name)
func focus(endpoint:String,z:float)->void:
	var w:FablewoodWorld=screen.world
	var path:Array[Vector2i]=screen.model.path_for(0)
	var at:=w.ground(Vector2(path[0] if endpoint=="gate" else path[-1]))
	w.zoom=z;w.pan=Vector2.ZERO;w.framing()
	w.pan=w.size*Vector2(.5,.7)-(w._origin+at*w._scale)
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	var hash_before:int=screen.model.state_hash()
	for endpoint:String in ["gate","vault"]:
		focus(endpoint,1.85)
		for frame:int in [0,12,24,36,47,0]:
			screen.world.clock=frame/A.FPS
			await shot(endpoint+"_frame_"+str(frame))
			assert(screen.model.state_hash()==hash_before)
		var frozen:float=screen.world.clock;await frames(12);assert(screen.world.clock==frozen)
		screen.world.reduced_motion=true;await shot(endpoint+"_static")
		screen.world.reduced_motion=false
	screen.world.reset_view();await shot("both_overview")
	# Default 1x/2x speed affects the battle, not ambient prop animations.
	screen.paused=false;await frames(15);assert(screen.world.clock>0)
	screen.speed=2;var start:float=screen.world.clock;await frames(15);assert(screen.world.clock>start)
	screen.paused=true;await frames();var stopped:float=screen.world.clock;await frames(15);assert(screen.world.clock==stopped)
	I18n.set_locale(&"zh-CN");await frames()
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	focus("vault",1.85);screen.world.clock=2;await shot("vault_portrait_cn")
	focus("gate",1.85);screen.world.clock=2;await shot("gate_portrait_cn")
	screen.world.zoom=.7;screen.world.pan=Vector2.ZERO;await shot("portrait_zoom_out")
	var old:WeakRef=weakref(screen.world);Game.open_title();await frames(12);assert(old.get_ref()==null)
	assert(Game.start_campaign(false))
	assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=true
	assert(screen.world.clock<2.0)
	assert(A._frames.size()==2 and A._frames.gate.size()==48 and A._frames.vault.size()==48)
	print("ALL_ENDPOINT_NATIVE_CHECKS_PASS")
	get_tree().quit()
