extends Node
const OUT:="/home/ubuntu/fablewood_music_impact/native/"
var screen:Control
var world:FablewoodWorld
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	world._sync_terrain();world.queue_redraw();await frames();await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(OUT+name+".png")==OK)
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	await frames();assert(AudioServer.get_driver_name()!="Dummy")
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(15)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;world=screen.world
	screen.model.dp=9999
	for pair:Array in [[&"caster_1",Vector2i(2,2)],[&"sniper_1",Vector2i(4,3)],[&"recruit",Vector2i(6,3)]]:
		if screen.model.stage.is_elevated_platform(pair[1]):screen.model.apply_action([&"deploy",pair[0],pair[1],0])
	screen._refresh_hud();assert(Music.play_cue(&"fablewood"));await frames()
	var player=Music._active_player();var starts:=Music.start_count()
	var cue=load("res://data/presentation/audio/cues/fablewood.tres")
	var marker:=float(cue.get_meta("epic_entry_seconds"))
	var hud_rect:Rect2=screen._hud.get_global_rect();var pan:=world.pan
	await shot("before")
	screen.speed=4;player.seek(marker-0.7)
	await Music.presentation_marker_reached
	assert(world.music_impact.trigger_count==1 and world.music_impact.motes.size()==32)
	screen.set_process(false);world.set_process(false)
	var hash_before:int=screen.model.state_hash()
	for age:float in [0.04,0.16,0.55,1.15]:
		world.music_impact.age=age;world._sync_terrain()
		assert(world.terrain_layer.position.is_equal_approx(world._origin))
		assert(world.pan==pan and screen._hud.get_global_rect()==hud_rect)
		for y:int in screen.model.stage.grid_size().y:
			for x:int in screen.model.stage.grid_size().x:
				var cell:=Vector2i(x,y)
				if screen.model.stage.is_elevated_platform(cell):assert(world.pick(world.screen_of(cell))==cell)
		await shot("impact_"+str(roundi(age*100)))
	assert(screen.model.state_hash()==hash_before)
	world.music_impact.advance(3,false);assert(world.music_impact.motes.is_empty())
	await shot("settled")
	# Real audio rollover rearms one event for the next loop, at 1x as at 4x.
	screen.set_process(true);world.set_process(true);screen.speed=1
	player.seek(player.stream.get_length()-0.6);await get_tree().create_timer(1.2).timeout
	player.seek(marker-0.7);await Music.presentation_marker_reached
	assert(world.music_impact.trigger_count==2 and Music.start_count()==starts)
	# Pausing immediately clears the impulse, instead of replaying a stale burst.
	screen._show_pause();await frames();assert(world.music_impact.motes.is_empty() and world.music_impact.shake_offset()==Vector2.ZERO)
	var count:=world.music_impact.trigger_count
	Music.presentation_marker_reached.emit(&"fablewood",&"epic_entry");assert(world.music_impact.trigger_count==count)
	screen._dismiss();screen.paused=false
	screen._set_volume("Music",0);Music.presentation_marker_reached.emit(&"fablewood",&"epic_entry");assert(world.music_impact.trigger_count==count)
	screen._set_volume("Music",0.5)
	# Native portrait and reduced-motion alternatives share the same callback.
	I18n.set_locale("zh-CN");get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	world=screen.world;screen._reduced_motion=false;world.reduced_motion=false
	world.reset_view();Music.presentation_marker_reached.emit(&"fablewood",&"epic_entry")
	screen.set_process(false);world.set_process(false);world.music_impact.age=0.55;await shot("portrait_cn")
	world.zoom=1.85;world.pan=Vector2.ZERO;world.framing()
	Music.presentation_marker_reached.emit(&"fablewood",&"epic_entry");world.music_impact.age=0.35;await shot("portrait_zoom")
	world.reduced_motion=true;Music.presentation_marker_reached.emit(&"fablewood",&"epic_entry");world.music_impact.age=0.35
	assert(world.music_impact.motes.is_empty() and world.music_impact.shake_offset()==Vector2.ZERO)
	await shot("reduced_motion")
	var old_world:WeakRef=weakref(world);Game.open_title();await frames(15);assert(old_world.get_ref()==null)
	Music.presentation_marker_reached.emit(&"fablewood",&"epic_entry")
	assert(Music.player_count()==2 and Music.start_count()==starts)
	Music.stop();Sfx.stop_all()
	print("MUSIC_IMPACT_NATIVE_PASS: current cue audio crossing at 4x/1x, actual rollover, fixed HUD/pan/picking/terrain/model, pause/mute guards, CN portrait/zoom/reduced motion and cleanup")
	get_tree().quit()
