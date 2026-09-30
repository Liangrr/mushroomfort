extends Node

var failures:=0
var checks:=0
var screen:Control

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frames(count:int=4)->void:
	for _i:int in count:await get_tree().process_frame
func capture(label:String)->void:
	var directory:=OS.get_environment("FABLEWOOD_UI_CAPTURES")
	if directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(directory)
	await frames(4)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))==OK,"native screenshot saved")

func key(code:Key)->void:
	for pressed:bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event);await frames(2)
func resize(to:Vector2i)->void:
	get_window().size=to;get_window().content_scale_size=to;await frames(5)
	screen._resize();await frames(3)
func pad()->Vector2i:
	for y:int in screen.model.stage.grid_rows.size():
		for x:int in screen.model.stage.grid_rows[y].length():
			var cell:=Vector2i(x,y)
			if screen.model.stage.is_elevated_platform(cell) and screen.model.alive_unit_at(cell)==null:return cell
	return Vector2i(-1,-1)
func _ready()->void:
	_run.call_deferred()
func _run()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	Game.open_title();await frames(12)
	I18n.set_locale(&"en-US");await frames();await capture("title-en")
	I18n.set_locale(&"zh-CN");await frames();await capture("title-cn")
	I18n.set_locale(&"en-US");await frames()
	TweakControls.set_value(&"ui.text_scale",1.2)
	check(Game.start_campaign(false),"campaign starts")
	check(Game.start_campaign_stage(&"s1"),"chapter starts")
	await frames(14)
	screen=Game.content
	if screen==null or screen.model==null:check(false,"active battle screen exists");finish();return
	if screen._tutorial_active:
		await capture("tutorial-en");screen._skip_tutorial()
	screen.set_process(false)
	screen._choose(&"caster_1");screen._cell_clicked(pad());await frames()
	var unit:UnitState=screen.model.units[0]
	var gold:int=screen.model.dp
	var tier:int=screen.model.tier(unit)
	screen._tutorial_upgrade_button.grab_focus();screen._show_pause();await frames()
	check(screen.overlay.is_ancestor_of(get_viewport().gui_get_focus_owner()),"modal takes focus")
	await capture("pause-en")
	await key(KEY_ENTER)
	check(screen.model.dp==gold and screen.model.tier(unit)==tier,"Enter cannot upgrade behind Pause")
	if screen.overlay!=null:screen._close_modal()
	screen._show_pause();screen._show_settings();await frames()
	var before:int=screen.model.state_hash()
	var countdown:float=screen._preparation_remaining
	screen.speed=3
	await resize(Vector2i(900,900))
	check(screen._modal_kind=="settings" and screen.paused,"Settings survives aspect rebuild")
	I18n.set_locale(&"zh-CN");await frames()
	check(screen._modal_kind=="settings" and screen.paused,"Settings survives locale rebuild")
	await capture("settings-cn-portrait")
	check(screen.model.state_hash()==before and screen._preparation_remaining==countdown and screen.speed==3,"modal rebuild preserves simulation/countdown/speed")
	screen._close_modal();await frames()
	check(screen._modal_kind=="pause" and screen.paused,"Settings Back returns to Pause")
	screen._close_modal();check(not screen.paused and screen.overlay==null,"Pause resumes exact prior state")
	for control:Control in screen._cards+[screen._next,screen.merge_flow.button]:
		var local_rect:Rect2=(screen.canvas.get_global_transform_with_canvas().affine_inverse()*control.get_global_transform_with_canvas())*Rect2(Vector2.ZERO,control.size)
		check(local_rect.position.x>=0 and local_rect.end.x<=screen._logical.x and local_rect.end.y<=screen._logical.y,"large localized action bar fits portrait canvas")
	await capture("battle-cn-portrait")
	screen._show_threats();await frames();await resize(Vector2i(1440,900))
	check(screen._modal_kind=="threats" and screen.paused,"Threat guide survives aspect rebuild")
	screen._close_threats();check(not screen.paused,"Threat guide restores active play")
	for nested:String in ["threats","tutorial"]:
		screen._show_pause()
		if nested=="threats":screen._show_threats()
		else:screen._show_tutorial()
		await frames()
		if nested=="threats":screen._close_threats()
		else:screen._skip_tutorial()
		await frames()
		check(screen._modal_kind=="pause" and screen.paused,"nested help returns to Pause")
		await key(KEY_ENTER)
		check(screen.overlay==null and not screen.paused,"Resume after nested help releases pause")
	for step:int in 6:
		screen._show_tutorial();screen._tutorial_step=step;screen.overlay.refresh();await frames(2)
		screen._skip_tutorial();await frames(2)
		check(not screen._tutorial_active and screen.overlay==null and not screen.paused,"Skip clears each tutorial step")
	var cfg:=ConfigFile.new();check(cfg.load(screen._settings_file)==OK,"tutorial settings persist")
	check(int(cfg.get_value("settings","tutorial_version",0))==screen.TUTORIAL_VERSION and cfg.get_value("settings","tutorial_status","")=="skipped","versioned skipped status persists")
	for recovery:String in ["escape","rebuild","pause"]:
		if recovery=="pause":screen._show_pause()
		screen._show_tutorial();await frames(2)
		var blocked_settings:=ProjectSettings.globalize_path(screen._settings_file+".tmp")
		check(DirAccess.make_dir_recursive_absolute(blocked_settings)==OK,"block one tutorial preference save")
		screen._skip_tutorial();await frames(2)
		check(screen._modal_kind=="message" and screen.paused,"tutorial save failure keeps recoverable feedback")
		check(DirAccess.remove_absolute(blocked_settings)==OK,"remove tutorial save obstruction")
		if recovery=="rebuild":
			await resize(Vector2i(900,900))
			var close:Button=screen.overlay.find_children("*","Button",true,false)[0]
			close.pressed.emit()
		else:
			if recovery=="pause":await resize(Vector2i(1440,900))
			await key(KEY_ESCAPE)
		if recovery=="pause":
			check(screen._modal_kind=="pause" and screen.paused,"tutorial save error returns to prior Pause menu")
			screen._close_modal()
		check(screen.overlay==null and not screen.paused,"tutorial save error restores play after "+recovery)
	screen._show_tutorial();screen._tutorial_step=1;screen.overlay.refresh();await frames(2)
	await capture("tutorial-cn")
	screen._tutorial_advance();check(screen._tutorial_step==1,"Next cannot bypass select action")
	screen._choose(&"caster_1");check(screen._tutorial_step==2,"successful selection advances")
	screen._cell_clicked(Vector2i(-1,-1));check(screen._tutorial_step==2,"invalid placement cannot advance")
	screen._cell_clicked(pad());check(screen._tutorial_step==3,"successful placement advances")
	await key(KEY_U)
	check(screen._tutorial_step==4,"U performs the required tutorial upgrade")
	screen._tutorial_advance();check(screen._tutorial_step==5,"informational camera page can advance")
	screen._tutorial_advance();check(screen._tutorial_active,"Next cannot bypass wave action")
	await key(KEY_ENTER)
	check(not screen._tutorial_active and screen.model.wave_active,"Enter launches the required wave instead of activating Skip")
	cfg.load(screen._settings_file)
	check(cfg.get_value("settings","tutorial_status","")=="complete","completion persists")
	# Fail the canonical terminal write, then exercise the actual recovery UI.
	var blocked_temp:String=Game.campaign_store._tmp_path
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_temp))==OK,"block one durable save")
	screen.model.apply_action([&"resign"]);screen._ended=true;screen._finish_result();await frames(8)
	check(screen._modal_kind=="save_error","failed terminal save shows retry")
	await capture("recovery-cn")
	await key(KEY_ESCAPE)
	check(screen._modal_kind=="save_error","Escape cannot discard terminal recovery")
	await resize(Vector2i(900,900))
	check(screen._modal_kind=="save_error","resize preserves terminal recovery")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_temp))==OK,"remove terminal save obstruction")
	var retry:Button=screen.overlay.find_children("*","Button",true,false)[0]
	retry.pressed.emit()
	var transition_deadline:=Time.get_ticks_msec()+3000
	while Game.content.mode!="results" and Time.get_ticks_msec()<transition_deadline:await frames()
	check(Game.content.mode=="results" and Game.last_result.leaderboard_saved,"same terminal retry reaches saved Results")
	check(Leaderboard.local_entries(50).size()==1,"recovery inserts exactly one local score")
	await capture("results-cn")
	var result:Control=Game.content
	result._show_scores();await frames();await capture("standings-cn");result._close_modal()
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_temp))==OK,"block one launch save")
	result._launch_stage(&"s1");await frames(6)
	check(Game.content==result and result.overlay!=null,"failed Results launch stays recoverable with feedback")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_temp))==OK,"remove launch save obstruction")
	result._close_modal();result._launch_stage(&"s1");await frames(10)
	check(Game.content.mode=="battle" and not Game.content._tutorial_active,"retry launches once without replaying completed tutorial")
	await _check_pause_resign()
	finish()

func click_modal_button(key_name:String)->void:
	var target:Button
	for candidate:Button in screen.overlay.find_children("*","Button",true,false):
		if candidate.text==screen.trf(key_name):target=candidate;break
	check(target!=null,"actual modal button exists: "+key_name)
	if target==null:return
	await frames()
	var point:Vector2=target.get_global_transform_with_canvas()*(target.size*0.5)
	for pressed:bool in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
		event.position=point;event.global_position=point;event.pressed=pressed
		Input.parse_input_event(event);await frames(2)

func _check_pause_resign()->void:
	for scenario:String in ["ordinary","pending_merge","restore_failure"]:
		if scenario!="ordinary":
			check(Game.start_campaign_stage(&"s1"),"new campaign attempt starts for "+scenario)
			await frames(12)
		screen=Game.content
		check(screen.mode=="battle" and screen.startup_succeeded,"live battle ready for "+scenario)
		if screen.mode!="battle" or not screen.startup_succeeded:return
		screen.set_process(false)
		var battle:FablewoodBattle=screen.model
		var donors:Array[UnitState]=[]
		if scenario!="ordinary":
			# Fixture funding avoids a long combat setup; every donor and tier is
			# created by the real model action before the real merge UI owns them.
			battle.dp=1000
			for id:StringName in [&"caster_1",&"sniper_1"]:
				check(battle.apply_action([&"deploy",id,pad(),0]),"deploy merge donor")
				var donor:UnitState=battle.units[-1]
				check(battle.apply_action([&"upgrade",donor.id]) and battle.apply_action([&"upgrade",donor.id]),"upgrade donor to tier III")
				donors.append(donor)
			screen._refresh_inspector();screen._refresh_hud()
			screen.merge_flow.button.pressed.emit()
			screen._cell_clicked(donors[0].cell);screen._cell_clicked(donors[1].cell)
			check(screen.merge_flow.active and not battle.pending_merge.is_empty() and not donors[0].alive and not donors[1].alive,"real merge selection holds both donors")
		var score_count:int=Leaderboard.local_entries(50).size()
		await key(KEY_SPACE)
		check(screen._modal_kind=="pause" and screen.paused,"Space opens actual Pause for "+scenario)
		if scenario=="restore_failure":
			# A conflicting donor occupancy makes cancellation fail atomically.
			# The end-attempt UI must remain recoverable, never finalize RUNNING.
			donors[0].alive=true
			await click_modal_button("resign")
			check(screen._modal_kind=="message" and screen.paused and not screen._ended and not screen._finalizing,"rejected merge exit keeps paused recovery instead of terminal save error")
			check(battle.result==BattleModel.Result.RUNNING and not battle.pending_merge.is_empty() and screen.merge_flow.active,"rejected exit retains pending merge ownership")
			check(Leaderboard.local_entries(50).size()==score_count,"rejected resignation writes no score")
			await capture("resign-merge-recovery")
			donors[0].alive=false
			await click_modal_button("back")
			check(screen._modal_kind=="pause" and screen.paused,"failed exit returns to retryable Pause")
		await click_modal_button("resign")
		var deadline:=Time.get_ticks_msec()+3000
		while Game.content.mode!="results" and Time.get_ticks_msec()<deadline:await frames()
		check(Game.content.mode=="results" and int(Game.last_result.get("result",-1))==BattleModel.Result.DEFEAT,"Pause resignation reaches defeat Results: "+scenario)
		check(battle.result==BattleModel.Result.DEFEAT and battle.pending_merge.is_empty(),"terminal resignation has no held donors")
		for donor:UnitState in donors:check(donor.alive,"held donor restored before sealing outcome")
		check(Leaderboard.local_entries(50).size()==score_count+1 and bool(Game.last_result.get("leaderboard_saved",false)),"one durable result saved for "+scenario)
	await capture("resign-merge-results")

func finish()->void:
	print("FABLEWOOD_UI_CONTRACT failures=",failures," checks=",checks)
	get_tree().quit(0 if failures==0 else 1)
