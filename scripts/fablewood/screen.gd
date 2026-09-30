extends Control
const BuildPlacement:=preload("res://scripts/fablewood/build_placement.gd")
const MergeFlow:=preload("res://scripts/fablewood/merge_flow.gd")
const MergedArt:=preload("res://scripts/fablewood/merged_art.gd")
const P := preload("res://scripts/fablewood/presentation.gd")
const GuardianAnimation := preload("res://scripts/fablewood/guardian_animation.gd")
const GuardianIcon := preload("res://scripts/fablewood/guardian_icon.gd")
const LateVisuals := preload("res://scripts/fablewood/late_enemy_visuals.gd")
const WorldType := preload("res://scripts/fablewood/world.gd")
const ModelType := preload("res://sim/fablewood_battle.gd")
const TutorialCallout:=preload("res://scripts/fablewood/tutorial_callout.gd")
const UpgradeButton:=preload("res://scripts/fablewood/upgrade_button.gd")
const NextWaveButton:=preload("res://scripts/fablewood/next_wave_button.gd")
const ScreenFilter:=preload("res://scripts/fablewood/screen_filter.gd")
const TUTORIAL_VERSION:=1
const OpenSourceLicenses:=preload("res://scripts/manus/open_source_licenses.gd")
var merge_flow:FablewoodMergeFlow
var build_placement:FablewoodBuildPlacement
@export var mode := "title"
var model: FablewoodBattle
var startup_succeeded := false
var world: FablewoodWorld
var canvas: Control
var overlay: Control
var _inspector_panel:PanelContainer
var _inspector_scroll:ScrollContainer
var _ultimate_status:Label
var _ultimate_bar:ProgressBar
var inspector: VBoxContainer
var selected_id := -1
var chosen := &""
var paused := false
const WAVE_PREPARATION_SECONDS:=30.0
var _preparation_wave:=-1
var _preparation_remaining:=WAVE_PREPARATION_SECONDS
const MAX_GAME_SPEED:=4
var speed := 1
var _speed_button:Button
var accumulator := 0.0
var _ended := false
var _finalizing := false
var _saved := false
var _hud: Label
var _status: Label
var _threat_status: Label
var _next: Button
var _threats_button: Button
var _cards: Array[Button] = []
var _notice: Label
var _notice_time := 0.0
var _tutorial_step := 0
var _tutorial_active:=false
var _tutorial_pause_before:=false
var _tutorial_focus_before:WeakRef
var _tutorial_camera_before:Dictionary={}
var _tutorial_camera_row:Control
var _tutorial_start_button:Button
var _tutorial_upgrade_button:Button
var _tutorial_tour_requested:=false
var _logical := Vector2(1280,800)
var _portrait := false
var _music_volume := 0.5
const DEFAULT_SFX_VOLUME := 0.4875
var _sfx_volume := DEFAULT_SFX_VOLUME
var _reduced_motion := false
var _tutorial_seen := false
var _settings_file := "user://fablewood_settings.cfg"
var _hard_mode := false
var _scores_hard_mode := false
var _threats_paused_before:=false
var _threats_return_to_pause:=false
var _threats_focus_before:WeakRef
var _modal_kind:=""
var _modal_return_kind:=""
var _modal_message:=""
var _modal_pause_before:=false
var _modal_focus_before:WeakRef
var _modal_disabled_focus:Array[Dictionary]=[]
var _master_volume:=1.0
var _ui_volume:=1.0
var _filter_enabled:=false
var _filter_intensity:=0.3
var _screen_filter:CanvasLayer
var _tutorial_completed_version:=0
var _tutorial_status:=""
var _tutorial_completed_steps:Dictionary={}
var _input_method:="pointer"
var _scores_group:="normal"

func trf(key:String,values:Dictionary={}) -> String:
	return P.t(key,values)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme=P.make_theme()
	_load_preferences()
	_screen_filter=ScreenFilter.new()
	add_child(_screen_filter)
	_apply_filter()
	I18n.locale_changed.connect(_locale_changed)
	Music.presentation_marker_reached.connect(_on_music_marker)
	get_viewport().size_changed.connect(_resize)
	_portrait=get_viewport_rect().size.x/get_viewport_rect().size.y<1.1
	_logical=Vector2(720,1100) if _portrait else Vector2(1280,800)
	if mode=="battle":
		model=ModelType.create_fablewood(Game.pending_stage,Game.battle_launch(),Game.run_seed)
		if model==null:
			push_error("Fablewood battle launch rejected")
			return
		# The model owns the rule change and accepts it only before its first wave.
		if not model.configure_hard_mode(_hard_mode):
			push_error("Fablewood hard-mode configuration was rejected before battle startup")
			return
		TweakControls.begin_stage()
		_apply_tuning()
		model.apply_run_metadata(TweakControls.run_metadata())
		Music.apply_stage_tuning()
		startup_succeeded=true
	_build()
	_resize()
	if mode=="loading":
		Game.content=self
		await get_tree().create_timer(0.4).timeout
		Game.open_title()
	elif mode=="battle" and ((not _tutorial_seen and model.chapter==1) or _tutorial_tour_requested):
		_show_tutorial()

func _load_preferences() -> void:
	var cfg:=ConfigFile.new()
	if cfg.load(_settings_file)==OK:
		_music_volume=clampf(float(cfg.get_value("settings","music",0.5)),0,1)
		_sfx_volume=clampf(float(cfg.get_value("settings","sfx",DEFAULT_SFX_VOLUME)),0,1)
		_reduced_motion=bool(cfg.get_value("settings","motion",false))
		_tutorial_completed_version=int(cfg.get_value("settings","tutorial_version",TUTORIAL_VERSION if bool(cfg.get_value("settings","tutorial",false)) else 0))
		_tutorial_seen=_tutorial_completed_version>=TUTORIAL_VERSION
		_tutorial_status=String(cfg.get_value("settings","tutorial_status","complete" if _tutorial_seen else ""))
		_master_volume=_valid_gain(cfg.get_value("settings","master",1.0),1.0)
		_ui_volume=_valid_gain(cfg.get_value("settings","ui",1.0),1.0)
		_filter_enabled=bool(cfg.get_value("settings","filter_enabled",false))
		_filter_intensity=_valid_gain(cfg.get_value("settings","filter_intensity",0.3),0.3)
		_tutorial_tour_requested=bool(cfg.get_value("settings","tutorial_requested",false))
		_hard_mode=bool(cfg.get_value("settings","hard_mode",false))
		I18n.set_locale(StringName(cfg.get_value("settings","locale","en-US")))
	_set_volume("Music",_music_volume)
	_set_volume("SFX",_sfx_volume)
	Music.set_master_volume(_master_volume)
	Sfx.set_ui_volume(_ui_volume)

func _save_preferences() -> bool:
	var cfg:=ConfigFile.new()
	cfg.set_value("settings","music",_music_volume)
	cfg.set_value("settings","sfx",_sfx_volume)
	cfg.set_value("settings","motion",_reduced_motion)
	cfg.set_value("settings","tutorial_version",_tutorial_completed_version)
	cfg.set_value("settings","tutorial_status",_tutorial_status)
	cfg.set_value("settings","master",_master_volume)
	cfg.set_value("settings","ui",_ui_volume)
	cfg.set_value("settings","filter_enabled",_filter_enabled)
	cfg.set_value("settings","filter_intensity",_filter_intensity)
	cfg.set_value("settings","tutorial_requested",_tutorial_tour_requested)
	cfg.set_value("settings","hard_mode",_hard_mode)
	cfg.set_value("settings","locale",String(I18n.locale()))
	var temporary:=_settings_file+".tmp"
	if cfg.save(temporary)!=OK:return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(_settings_file))==OK

func _valid_gain(value:Variant,fallback:float)->float:
	return clampf(float(value),0.0,1.0) if (value is float or value is int) and is_finite(float(value)) else fallback

func _apply_filter()->void:
	if not is_instance_valid(_screen_filter):return
	_screen_filter.set_enabled(_filter_enabled)
	_screen_filter.set_intensity(_filter_intensity)

func _set_hard_mode(enabled:bool,toggle:CheckButton=null)->bool:
	if _hard_mode==enabled:return true
	var previous:=_hard_mode
	_hard_mode=enabled
	if _save_preferences():
		Sfx.play("confirm")
		return true
	_hard_mode=previous
	if is_instance_valid(toggle):toggle.set_pressed_no_signal(previous)
	_toast(trf("save_error"))
	return false

func _mode_tooltip(hard:bool)->String:
	return _wrap_tooltip(trf("hard_mode_hint") if hard else trf("normal_mode_hint"))

func _mode_badge(parent:Node,hard:bool,node_name:String,at:Vector2=Vector2.ZERO,dimensions:Vector2=Vector2(128,32),font_size:int=13)->PanelContainer:
	var fill:=Color("593b39") if hard else Color("263b45")
	var border:=Color("f0a967") if hard else Color("86ced7")
	var badge:=PanelContainer.new()
	badge.name=node_name
	badge.position=at
	badge.size=dimensions
	badge.custom_minimum_size=dimensions
	badge.mouse_filter=Control.MOUSE_FILTER_PASS
	badge.tooltip_text=_mode_tooltip(hard)
	var style:=P.box(fill,border,2,8)
	style.content_margin_left=8
	style.content_margin_right=8
	style.content_margin_top=3
	style.content_margin_bottom=3
	badge.add_theme_stylebox_override("panel",style)
	parent.add_child(badge)
	var copy:=_label(badge,trf("mode_hard") if hard else trf("mode_normal"),font_size,Vector2.ZERO,Vector2.ZERO,P.TEXT)
	copy.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	copy.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return badge

func _set_volume(bus:String,volume:float) -> void:
	var idx:=AudioServer.get_bus_index(bus)
	if idx>=0:
		AudioServer.set_bus_volume_db(idx,linear_to_db(maxf(volume,0.001)))
		AudioServer.set_bus_mute(idx,volume<=0.001)

func _apply_tuning() -> void:
	model.damage_scale=float(TweakControls.value(&"player.attack_multiplier",1.0))
	model.attack_scale=float(TweakControls.value(&"player.attack_speed_multiplier",1.0))
	model.difficulty=float(TweakControls.value(&"enemies.health_multiplier",1.0))
	model.enemy_speed=float(TweakControls.value(&"enemies.movement_speed_multiplier",1.0))
	model.dp=roundi(float(TweakControls.value(&"gameplay.start_gold",300.0)))
	model.gold_scale=float(TweakControls.value(&"gameplay.reward_scale",1.0))
	model.base_hp=roundi(float(TweakControls.value(&"gameplay.town_health",20.0)))
	model.tower_range=roundi(float(TweakControls.value(&"player.range_bonus",0.0)))

func _build() -> void:
	if canvas!=null:
		remove_child(canvas)
		canvas.queue_free()
	canvas=Control.new()
	canvas.size=_logical
	add_child(canvas)
	var bg:=TextureRect.new()
	bg.texture=P.BACKDROP if mode=="battle" else P.TITLE
	bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size=_logical
	bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)
	if mode!="battle":
		var shade:=ColorRect.new()
		shade.color=Color(0.04,0.045,0.075,0.28)
		shade.size=_logical
		shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		canvas.add_child(shade)
	match mode:
		"loading":
			_label(canvas,"FABLEWOOD",48,Vector2(50,_logical.y-160),Vector2(600,70),P.GOLD)
			_label(canvas,trf("subtitle"),20,Vector2(54,_logical.y-90),Vector2(610,45))
		"title":_title()
		"chapters":_chapters()
		"battle":_battle()
		"results":_results()

func _resize() -> void:
	if canvas==null:return
	var view:=get_viewport_rect().size
	var portrait:=view.x/view.y<1.1
	if portrait!=_portrait:
		_portrait=portrait
		_logical=Vector2(720,1100) if portrait else Vector2(1280,800)
		_rebuild_canvas()
	var factor:=minf(view.x/_logical.x,view.y/_logical.y)
	canvas.scale=Vector2.ONE*factor
	canvas.position=(view-_logical*factor)*0.5

func _locale_changed(_locale:StringName) -> void:
	_save_preferences()
	_rebuild_canvas()
	_resize()

func _rebuild_canvas()->void:
	var state:={"kind":_modal_kind,"return":_modal_return_kind,"message":_modal_message,"pause_before":_modal_pause_before,"focus":_modal_focus_before,"threats_pause":_threats_paused_before,"threats_return":_threats_return_to_pause,"threats_focus":_threats_focus_before}
	var was_paused:=paused
	var camera:={"zoom":world.zoom,"pan":world.pan} if is_instance_valid(world) else {}
	_dismiss(false)
	_build()
	if not camera.is_empty() and is_instance_valid(world):
		world.zoom=camera.zoom;world.pan=camera.pan
	paused=was_paused
	if _tutorial_active:_tutorial_page()
	else:
		match state.kind:
			"pause":_show_pause()
			"settings":_show_settings()
			"scores":_show_scores()
			"threats":_show_threats()
			"save_error":_show_save_error()
			"message":
				var v:=_modal(state.message,"message")
				_button(v,trf("close"),_close_modal)
		if overlay!=null:
			_modal_return_kind=state["return"]
			_modal_pause_before=state.pause_before
			_modal_focus_before=state.focus
			_threats_paused_before=state.threats_pause
			_threats_return_to_pause=state.threats_return
			_threats_focus_before=state.threats_focus

func _scaled_font(size:int)->int:
	return roundi(size*float(TweakControls.value(&"ui.text_scale",1.0)))

func _panel(parent:Node,at:Vector2,dimensions:Vector2,fill:Color=P.PANEL) -> PanelContainer:
	var panel:=PanelContainer.new()
	panel.position=at
	panel.size=dimensions
	panel.add_theme_stylebox_override("panel",P.box(fill))
	parent.add_child(panel)
	return panel

func _label(parent:Node,text:String,font_size:int=18,at:Vector2=Vector2.ZERO,dimensions:Vector2=Vector2.ZERO,color:Color=P.TEXT) -> Label:
	var l:=Label.new()
	l.text=text
	l.position=at
	l.size=dimensions
	l.add_theme_font_size_override("font_size",_scaled_font(font_size))
	l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _text(parent:Node,text:String,font_size:int=18) -> Label:
	var l:=_label(parent,text,font_size)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return l

func _button(parent:Node,text:String,fn:Callable,dimensions:Vector2=Vector2(0,48),accent:bool=false,button_script:GDScript=null) -> Button:
	var b:Button=button_script.new() if button_script!=null else Button.new()
	b.text=text
	b.add_theme_font_size_override("font_size",_scaled_font(18))
	b.accessibility_name=text
	b.clip_text=true
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL if dimensions.x==0 else Control.SIZE_FILL
	b.custom_minimum_size=dimensions
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	if dimensions.x>0 and dimensions.x<80:
		for state:String in ["normal","hover","pressed","disabled"]:
			var style:=P.box(P.PANEL,P.GOLD if state=="hover" else P.BORDER)
			style.content_margin_left=5;style.content_margin_right=5
			b.add_theme_stylebox_override(state,style)
	if accent:
		b.add_theme_stylebox_override("normal",P.box(Color("3c533a"),P.GOLD))
		b.add_theme_stylebox_override("hover",P.box(Color("506343"),P.GOLD,2))
	b.pressed.connect(func():
		if is_instance_valid(overlay) and not _tutorial_active and not overlay.is_ancestor_of(b):return
		Music.play_cue(&"fablewood")
		Sfx.play("confirm")
		fn.call())
	parent.add_child(b)
	return b

func _vbox(parent:Node) -> VBoxContainer:
	var b:=VBoxContainer.new()
	parent.add_child(b)
	return b

func _title() -> void:
	var p:=_panel(canvas,Vector2(44,80) if not _portrait else Vector2(40,280),Vector2(445,630) if not _portrait else Vector2(640,720),P.PANEL_DEEP)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;p.add_child(scroll)
	var v:=_vbox(scroll);v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_label(v,"FABLEWOOD",49 if not _portrait else 58,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	_label(v,trf("subtitle"),15,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	_text(v,trf("tagline"),24)
	_text(v,trf("intro"),19)
	var mode_card:=PanelContainer.new();mode_card.add_theme_stylebox_override("panel",P.box(P.PANEL_INSET,P.BORDER,1,10));v.add_child(mode_card)
	var mode_column:=VBoxContainer.new();mode_column.add_theme_constant_override("separation",4);mode_card.add_child(mode_column)
	var mode_row:=HBoxContainer.new();mode_column.add_child(mode_row)
	var hard_toggle:=CheckButton.new();hard_toggle.name="HardModeToggle";hard_toggle.text=trf("hard_mode_toggle");hard_toggle.button_pressed=_hard_mode;hard_toggle.custom_minimum_size=Vector2(0,42);hard_toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hard_toggle.tooltip_text=_wrap_tooltip(trf("hard_mode_hint"));mode_row.add_child(hard_toggle)
	_mode_badge(mode_row,_hard_mode,"TitleModeBadge",Vector2.ZERO,Vector2(104,28),12)
	hard_toggle.toggled.connect(func(enabled:bool):
		if _set_hard_mode(enabled,hard_toggle):
			_build();_resize())
	var hard_hint:=_text(mode_column,trf("hard_mode_summary"),14);hard_hint.name="HardModeHint";hard_hint.add_theme_color_override("font_color",P.MUTED);hard_hint.tooltip_text=_wrap_tooltip(trf("hard_mode_hint"))
	_tutorial_start_button=_button(v,trf("play"),func():
		if Game.start_campaign(false):Game.open_stage_select()
		else:_toast(trf("save_error")),Vector2(0,56),true)
	var row:=HBoxContainer.new();v.add_child(row)
	_button(row,trf("scores"),_show_scores,Vector2(190,48))
	_button(row,trf("settings"),_show_settings,Vector2(165,48))
	_button(v,trf("help"),_show_tutorial,Vector2(0,44))
	var licenses:=_button(v,trf("open_source_licenses"),OpenSourceLicenses.open.bind(self),Vector2(0,40))
	licenses.name="OpenSourceLicensesButton"
	licenses.action_mode=BaseButton.ACTION_MODE_BUTTON_PRESS
	licenses.clip_text=false
	var langs:=HBoxContainer.new();v.add_child(langs)
	_label(langs,trf("language"),13,Vector2.ZERO,Vector2.ZERO,P.MUTED)
	for loc:String in ["en-US","zh-CN"]:
		var b:=_button(langs,"EN" if loc=="en-US" else "CN 简体中文",func():I18n.set_locale(StringName(loc)),Vector2(75 if loc=="en-US" else 155,42),String(I18n.locale())==loc)
		b.tooltip_text="English" if loc=="en-US" else "简体中文"
	_label(canvas,trf("genre_tagline"),13,Vector2(48,42),Vector2(500,30),P.GOLD)
	_label(canvas,trf("elements_tagline"),13,Vector2(48,_logical.y-45),Vector2(600,30),P.MUTED)

func _chapters() -> void:
	_label(canvas,"FABLEWOOD",30,Vector2(42,32),Vector2(600,50),P.GOLD)
	_label(canvas,trf("chapters"),42,Vector2(42,87),Vector2(650,65))
	if not _portrait:_grove_accent(P.CHAPTER_ACCENT,Vector2(42,176),Vector2(260,65))
	var row:=Control.new();canvas.add_child(row)
	for i:int in 3:
		var stage_id:=StringName("s%d"%(i+1))
		var locked:=not Game.is_stage_unlocked(stage_id)
		var pending:=Game.pending_campaign_stage_id()
		if pending!=&"" and pending!=stage_id:locked=true
		var at:=Vector2(42+i*399,265) if not _portrait else Vector2(40,175+i*264)
		var p:=_panel(row,at,Vector2(378,350) if not _portrait else Vector2(640,244))
		var v:=_vbox(p)
		var header:=HBoxContainer.new();v.add_child(header)
		_label(header,"%s 0%d"%[trf("chapter"),i+1],14,Vector2.ZERO,Vector2.ZERO,P.GOLD).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		_mode_badge(header,_hard_mode,"StageModeBadge_%s"%stage_id,Vector2.ZERO,Vector2(102,25),11)
		_label(v,trf("chapter%d"%(i+1)),28)
		_text(v,trf("story%d"%(i+1)),18)
		var projection:=Game.campaign_projection()
		var stars:int=int(projection.get("stage_stars",{}).get(stage_id,0))
		_label(v,"• ".repeat(stars) if stars>0 else "8 %s  ·  4 %s"%[trf("wave"),trf("guardians")],16,Vector2.ZERO,Vector2.ZERO,P.GOLD)
		var b:=_button(v,trf("locked") if locked else trf("resume_attempt") if pending==stage_id else trf("play"),func():
			_launch_stage(stage_id),Vector2(0,52),not locked)
		b.disabled=locked
	var back:=_button(canvas,trf("back"),func():Game.open_title(),Vector2(180,48));back.position=Vector2(42,_logical.y-85)

func _battle() -> void:
	build_placement=null
	if merge_flow==null:merge_flow=MergeFlow.new(self)
	_cards=[]
	var top:=_panel(canvas,Vector2(18,15),Vector2(_logical.x-36,65),P.PANEL_DEEP)
	var row:=HBoxContainer.new();top.add_child(row)
	_label(row,"FABLEWOOD",22,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	_hud=_label(row,"",21)
	_hud.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(row,"Ⅱ",_show_pause,Vector2(55,43)).tooltip_text=trf("pause_hint")
	world=WorldType.new()
	world.model=model
	world.reduced_motion=_reduced_motion
	world.zoom=float(TweakControls.value(&"environment.zoom",1.0))
	world.position=Vector2(12,92)
	world.size=Vector2(1010,555) if not _portrait else Vector2(696,638)
	world.cell_clicked.connect(_cell_clicked)
	canvas.add_child(world)
	var status_panel:=_panel(canvas,Vector2(28,94),Vector2(430,68),P.PANEL_INSET)
	var status_rows:=_vbox(status_panel);status_rows.add_theme_constant_override("separation",3)
	var status_header:=HBoxContainer.new();status_rows.add_child(status_header)
	_status=_label(status_header,"",16);_status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_mode_badge(status_header,_hard_mode,"BattleModeBadge",Vector2.ZERO,Vector2(98,23),11)
	_threat_status=_label(status_rows,"",13,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	_threat_status.clip_text=true
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_threat_status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var camera_row:=HBoxContainer.new();canvas.add_child(camera_row)
	_tutorial_camera_row=camera_row
	camera_row.position=Vector2(26,592) if not _portrait else Vector2(26,678)
	_button(camera_row,"−",func():world.change_zoom(0.9),Vector2(42,40)).tooltip_text=trf("zoom")
	_button(camera_row,"+",func():world.change_zoom(1.1),Vector2(42,40)).tooltip_text=trf("zoom")
	_button(camera_row,trf("fit"),func():world.reset_view(),Vector2(78,40)).tooltip_text=trf("reset_view")
	_speed_button=_button(camera_row,"%d×"%speed,func():_set_game_speed(1 if speed==MAX_GAME_SPEED else speed+1),Vector2(98,40))
	_speed_button.tooltip_text=trf("speed_hint")
	_threats_button=_button(camera_row,"",_show_threats,Vector2(126,40))
	_threats_button.tooltip_text=trf("threats_hint")
	var side:=_panel(canvas,Vector2(1030,93) if not _portrait else Vector2(22,740),Vector2(230,539) if not _portrait else Vector2(676,147))
	_inspector_panel=side
	_inspector_scroll=ScrollContainer.new();_inspector_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;_inspector_scroll.follow_focus=true
	side.add_child(_inspector_scroll)
	inspector=_vbox(_inspector_scroll);inspector.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_refresh_inspector()
	var bottom:=_panel(canvas,Vector2(20,656) if not _portrait else Vector2(20,903),Vector2(1240,105) if not _portrait else Vector2(680,145),P.PANEL_DEEP)
	var buildrow:=HBoxContainer.new();bottom.add_child(buildrow)
	for i:int in P.IDS.size():
		var id:StringName=P.IDS[i]
		var element:String=FablewoodBattle.ELEMENTS[id]
		var b:=_button(buildrow,"%s\n%d"%[trf(element),model._op_defs[id].dp_cost],func():_choose(id),Vector2(171,78) if not _portrait else Vector2(82,119))
		if not _portrait:
			b.icon=GuardianAnimation.frame(element,1,0.0)
		else:
			b.text="\n\n%s\n%d"%[trf(element),model._op_defs[id].dp_cost]
			b.clip_text=false
			var thumb:=GuardianIcon.new();thumb.element=element;thumb.tier=1;thumb.motion_owner=self;thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;thumb.position=Vector2(21,7);thumb.size=Vector2(41,47);thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(thumb)
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",60 if not _portrait else 36)
		b.add_theme_font_size_override("font_size",_scaled_font(17 if not _portrait else 16))
		b.tooltip_text=trf(element+"_role")
		_cards.append(b)
	merge_flow.button=_button(buildrow,trf("merge_button"),merge_flow.start,Vector2(148,78) if not _portrait else Vector2(102,119))
	merge_flow.button.add_theme_font_size_override("font_size",_scaled_font(16))
	_next=_button(buildrow,trf("next"),_next_wave,Vector2(300,78) if not _portrait else Vector2(148,119),true,NextWaveButton)
	_next.motion_owner=self
	_next.tooltip_text=trf("next_wave_hint")
	if _portrait:
		# Keep all six actions inside the narrow bar at the largest text setting.
		for control:Node in buildrow.get_children():
			if not control is Button:continue
			for state:String in ["normal","hover","pressed","disabled","focus"]:
				var style:=control.get_theme_stylebox(state).duplicate() as StyleBoxFlat
				style.content_margin_left=5;style.content_margin_right=5
				control.add_theme_stylebox_override(state,style)
	_notice=_label(canvas,"",19,Vector2(220,605) if not _portrait else Vector2(230,678),Vector2(700,40),P.GOLD)
	merge_flow.refresh()
	build_placement=BuildPlacement.new(self,[top,status_panel,camera_row,side,bottom,_notice])

func _choose(id:StringName) -> void:
	if not _gameplay_action_allowed([1,2]) or model==null or id not in P.IDS:return
	if paused and not (_tutorial_active and _tutorial_step in [1,2]):return
	if overlay!=null and not _tutorial_active:return
	if merge_flow!=null and merge_flow.active:return
	chosen=id
	selected_id=-1
	world.selected=-1
	world.selected_element=FablewoodBattle.ELEMENTS[id]
	_refresh_inspector()
	if build_placement!=null:build_placement.begin()
	if _tutorial_active and _tutorial_step==1:_tutorial_advance(true)
func _cell_clicked(cell:Vector2i) -> void:
	if not _gameplay_action_allowed([2,3]):return
	if merge_flow!=null and merge_flow.active:
		merge_flow.click(cell);return
	var was_empty:=model.alive_unit_at(cell)==null
	var u:=model.alive_unit_at(cell)
	if chosen!=&"":
		# An occupied socket is an invalid placement, not an implicit cancellation.
		if model.apply_action([&"deploy",chosen,cell,0]):
			selected_id=model.units[-1].id
			world.selected=selected_id
			chosen=&""
			world.selected_element=""
			_present_events()
		else:
			Sfx.play("invalid")
			_toast(trf("insufficient") if not model.is_deployable(chosen) else trf("invalid"))
	elif u!=null:
		selected_id=u.id
		world.selected=u.id
		world.selected_element=""
		Sfx.play("confirm")
	_refresh_inspector()
	_refresh_hud()
	if _tutorial_active and _tutorial_step==2 and was_empty and model.alive_unit_at(cell)!=null:_tutorial_advance(true)
func _refresh_inspector() -> void:
	if inspector==null:return
	call_deferred("_fit_upgrade_layout")
	_tutorial_upgrade_button=null
	_ultimate_status=null;_ultimate_bar=null
	inspector.tooltip_text=""
	inspector.add_theme_constant_override("separation",12)
	for child:Node in inspector.get_children():
		inspector.remove_child(child);child.queue_free()
	if merge_flow!=null and merge_flow.active:
		_refresh_merge_inspector();return
	var u:=model.unit_by_id(selected_id)
	if u!=null and u.alive and model.is_merged(u):
		_refresh_merged_inspector(u);return
	if u!=null and u.alive:
		var el:=model.element(u)
		_label(inspector,trf(el),27,Vector2.ZERO,Vector2.ZERO,P.COLORS[el])
		if not _portrait:
			var image:=GuardianIcon.new();image.element=el;image.tier=model.tier(u);image.motion_owner=self;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(160,155);inspector.add_child(image)
		_label(inspector,"%s %d · %s"%[trf("tier"),model.tier(u),trf("tier%d"%model.tier(u))],17,Vector2.ZERO,Vector2.ZERO,P.GOLD)
		if not _portrait:
			_text(inspector,trf(el+"_role"),16)
			_text(inspector,"%s %s\n%s %d"%[trf("damage"),str(model.base_attack_damage(u)),trf("range"),model.range_for(u)],16)
		var row: BoxContainer=HBoxContainer.new() if _portrait else VBoxContainer.new();inspector.add_child(row)
		var b:=_button(row,trf("max") if model.tier(u)==3 else "%s  %d"%[trf("upgrade"),model.upgrade_cost(u)],func():
			if not _gameplay_action_allowed([3]):return
			if model.apply_action([&"upgrade",u.id]):
				_present_events();_toast(trf("upgraded"));_refresh_inspector();_refresh_hud()
				if _tutorial_active and _tutorial_step==3:_tutorial_advance(true)
			else:Sfx.play("invalid"),Vector2(0,62),true,UpgradeButton)
		b.motion_owner=self
		b.tooltip_text=trf("upgrade_hint")
		_tutorial_upgrade_button=b
		_refresh_upgrade_availability()
		_button(row,"%s  %d"%[trf("sell"),roundi(u.dp_cost*0.5)],func():
			if not _gameplay_action_allowed():return
			if model.apply_action([&"retreat",u.id]):
				selected_id=-1;world.selected=-1;Sfx.play("back");_refresh_inspector();_refresh_hud(),Vector2(0,40))
	else:
		_label(inspector,trf("last_seed"),25,Vector2.ZERO,Vector2.ZERO,P.GOLD)
		if not _portrait:
			var image:=TextureRect.new();image.texture=P.SEED;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(150,130);inspector.add_child(image)
		_text(inspector,trf("select") if chosen==&"" else trf(FablewoodBattle.ELEMENTS[chosen]+"_role"),18)
		_refresh_threats_inspector()
		if not _portrait:
			_text(inspector,trf("select_tower"),16)
			_text(inspector,trf("hint_keys"),14).add_theme_color_override("font_color",P.MUTED)

func _next_wave_late_threats()->PackedStringArray:
	var result:=PackedStringArray()
	if model==null or model.wave_active or model.result!=BattleModel.Result.RUNNING:return result
	# The model projection is authoritative: in Hard mode it includes its added
	# reinforcements as well as authored spawns. `model.wave` is completed waves,
	# while the public schedule accepts the player-visible one-based wave number.
	var schedule:Array[Dictionary]=model.get_wave_schedule(model.wave+1)
	for entry:Dictionary in schedule:
		var kind:=StringName(entry.get("enemy_id",&""))
		if LateVisuals.is_late(kind):result.append(String(kind))
	return result

func _threat_names(threats:PackedStringArray)->String:
	var names:=PackedStringArray()
	for kind:String in threats:
		var title:=trf("enemy_"+kind)
		if not names.has(title):names.append(title)
	return " · ".join(names)

func _refresh_threats_inspector()->void:
	var threats:=_next_wave_late_threats()
	if threats.is_empty():return
	_text(inspector,trf("threats_preview").format({"names":_threat_names(threats)}),15).add_theme_color_override("font_color",P.GOLD)
	_button(inspector,"%s: %d"%[trf("threats"),threats.size()],_show_threats,Vector2(0,40)).tooltip_text=trf("threats_hint")

func _refresh_threats_button()->void:
	if not is_instance_valid(_threats_button):return
	var count:=_next_wave_late_threats().size()
	_threats_button.text="%s%s"%[trf("threats"),": %d"%count if count>0 else ""]
	_threats_button.disabled=_ended or _tutorial_active or (merge_flow!=null and merge_flow.active)

func _fit_upgrade_layout() -> void:
	if not is_instance_valid(inspector) or not is_instance_valid(_notice) or not is_instance_valid(_tutorial_camera_row):return
	if _portrait:
		var side:=_inspector_panel
		side.size.y=clampf(inspector.get_combined_minimum_size().y+32,147,350)
		side.position.y=minf(740,903-12-side.size.y)
		_tutorial_camera_row.position.y=minf(678,side.position.y-12-_tutorial_camera_row.size.y)
	_notice.position=Vector2(_tutorial_camera_row.position.x+_tutorial_camera_row.size.x+18,_tutorial_camera_row.position.y+7)
	_notice.size.x=maxf(1,( _logical.x-22 if _portrait else 1010)-_notice.position.x)

func _refresh_upgrade_availability() -> void:
	if model==null or not is_instance_valid(_tutorial_upgrade_button):return
	var u:=model.unit_by_id(selected_id)
	var blocked:=_ended or model.result!=BattleModel.Result.RUNNING or u==null or not u.alive
	var cost:=model.upgrade_cost(u) if u!=null else 0
	_tutorial_upgrade_button.set_upgrade_state(cost,model.dp,u!=null and model.tier(u)>=3,blocked)

func _refresh_hud() -> void:
	if build_placement!=null:build_placement.refresh()
	if _hud==null:return
	_refresh_upgrade_availability()
	_refresh_ultimate_status()
	if merge_flow!=null:merge_flow.refresh_button()
	_hud.text=trf("hud_stats",{"health":maxi(0,model.base_hp),"gold":model.dp,"wave":model.wave})
	_hud.add_theme_font_size_override("font_size",_scaled_font(16 if _portrait else 21))
	_status.text="%s 0%d  ·  %s"%[trf("chapter"),model.chapter,trf("incoming") if model.wave_active else trf("prepare") if model.wave==0 else trf("waiting")]
	var threats:=_next_wave_late_threats()
	_threat_status.visible=not threats.is_empty()
	_threat_status.text=trf("threats_count_warning").format({"count":threats.size()})
	_threat_status.tooltip_text=_threat_names(threats)
	_refresh_threats_button()
	_refresh_wave_control()
	_next.add_theme_font_size_override("font_size",_scaled_font(16 if _portrait else 19))
	for i:int in _cards.size():
		_cards[i].disabled=not model.is_deployable(P.IDS[i]) or _ended or (merge_flow!=null and merge_flow.active)

func _wave_preparation_ready()->bool:
	return model!=null and not model.wave_active and model.wave<8 and model.result==BattleModel.Result.RUNNING and not _ended
func _sync_preparation()->void:
	if not _wave_preparation_ready():
		_preparation_wave=-1;_preparation_remaining=0;return
	if _preparation_wave!=model.wave:
		_preparation_wave=model.wave;_preparation_remaining=WAVE_PREPARATION_SECONDS
func _refresh_wave_control()->void:
	_sync_preparation()
	if not is_instance_valid(_next):return
	var ready:=_wave_preparation_ready()
	_next.set_wave_ready(ready and not (merge_flow!=null and merge_flow.active))
	_next.set_countdown(_preparation_remaining,WAVE_PREPARATION_SECONDS)
	var label:="%s %d/8\n%d %s"%[trf("wave"),model.wave,model.alive_count(),trf("remaining")] if model.wave_active else trf("next")
	if ready:label+="\n"+trf("wave_auto_in").format({"seconds":maxi(1,ceili(_preparation_remaining))})
	if _next.text!=label:_next.text=label
func _advance_preparation(delta:float)->void:
	_sync_preparation()
	if not _wave_preparation_ready() or paused or get_tree().paused or _tutorial_active or overlay!=null or (merge_flow!=null and merge_flow.active):return
	# Preparation is real active-play time: 30 seconds at every combat speed.
	_preparation_remaining=maxf(0,_preparation_remaining-maxf(0,delta))
	if _preparation_remaining<=0:_next_wave()
	else:_refresh_wave_control()
func _set_game_speed(value:int) -> void:
	if mode!="battle" or _ended:return
	speed=clampi(value,1,MAX_GAME_SPEED)
	if is_instance_valid(_speed_button):_speed_button.text="%d×"%speed
func _handle_speed_key(event:InputEventKey) -> bool:
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:return false
	var direction:=0
	if event.is_action_pressed(&"battle_speed_down"):direction=-1
	elif event.is_action_pressed(&"battle_speed_up"):direction=1
	if direction==0:return false
	var previous:=speed
	_set_game_speed(speed+direction)
	if speed!=previous:Sfx.play("click")
	get_viewport().set_input_as_handled()
	return true

func _next_wave() -> void:
	if not _gameplay_action_allowed([5]) or (merge_flow!=null and merge_flow.active):return
	if model.apply_action([&"next_wave"]):
		if _tutorial_active and _tutorial_step==5:_tutorial_finish(false,true)
		_present_events();_refresh_hud()

func _gameplay_action_allowed(tutorial_steps:Array=[])->bool:
	if _ended or get_tree().paused:return false
	if _tutorial_active:return _tutorial_step in tutorial_steps
	return not paused and overlay==null

func _launch_stage(stage_id:StringName)->void:
	if not Game.start_campaign_stage(stage_id):_toast(trf("save_error"))

func _on_music_marker(cue_id:StringName,marker_id:StringName)->void:
	if cue_id!=&"fablewood" or marker_id!=&"epic_entry":return
	if mode!="battle" or model==null or not is_instance_valid(world):return
	if paused or _ended or get_tree().paused or is_instance_valid(overlay):return
	if not Music.presentation_is_audible():return
	world.celebrate_music_entry()
func _process(delta:float) -> void:
	if mode!="battle" or model==null:return
	if _notice_time>0:
		_notice_time-=delta
		if _notice_time<=0 and is_instance_valid(_notice):_notice.text=""
	world.presentation_paused=paused or _ended
	if build_placement!=null:build_placement.refresh()
	if not Music.presentation_is_audible():world.music_impact.clear()
	if not _portrait:
		for i:int in _cards.size():
			var kind:String=FablewoodBattle.ELEMENTS[P.IDS[i]]
			var frame:=GuardianAnimation.frame(kind,1,0.0 if _reduced_motion else world.clock)
			if _cards[i].icon!=frame:_cards[i].icon=frame
	if get_tree().paused or _ended:return
	if paused and not (_tutorial_active and _tutorial_step==4):return
	if Input.is_physical_key_pressed(KEY_A):world.pan.x+=delta*300
	if Input.is_physical_key_pressed(KEY_D):world.pan.x-=delta*300
	if Input.is_physical_key_pressed(KEY_W):world.pan.y+=delta*300
	if Input.is_physical_key_pressed(KEY_S):world.pan.y-=delta*300
	if paused:return
	if not model.wave_active:
		_advance_preparation(delta)
		return
	if model.wave_active:
		accumulator+=minf(delta,0.12)*speed
		while accumulator>=1.0/30.0 and model.result==BattleModel.Result.RUNNING:
			world.capture_enemy_tick()
			model.step()
			accumulator-=1.0/30.0
		world.render_alpha=clampf(accumulator*30.0,0.0,1.0)
		_present_events()
		_refresh_hud()
		if model.result!=BattleModel.Result.RUNNING:
			_ended=true
			_finish_result()

func _attack_audio_cues(event:Dictionary)->Array[String]:
	var cues:Array[String]=[]
	var kind:=String(event.get("element",""))
	if kind not in ["fire","frost","storm","earth"]:return cues
	# An off-screen launcher must not suppress an on-screen impact, or vice versa.
	if world.audio_visible(event):cues.append(kind)
	for id:int in event.get("hits",[]):
		if id>=0 and id<model.enemies.size() and world.audio_visible({"kind":"damage","enemy":id}):
			cues.append(kind+"_hit");break
	return cues
func _present_events() -> void:
	for event:Dictionary in model.drain_events():
		world.add_event(event)
		if event.kind in ["shell_break","harrier_dash","brood_spawn"]:
			var cue:String={"shell_break":"enemy_shell_break","harrier_dash":"enemy_harrier_dash","brood_spawn":"enemy_brood_spawn"}[event.kind]
			# The model emitted this event once; use its enemy origin for independent
			# culling rather than the generic event visibility and never replay tells.
			var origin:Dictionary={"kind":"damage","enemy":int(event.enemy)}
			if world.audio_visible(origin):Sfx.play(cue,Callable(world,"late_audio_visible").bind(origin))
			continue
		if event.kind=="meteor_launch":
			if world.audio_visible(event):Sfx.play("storm")
			continue
		if event.kind=="meteor_impact":
			if world.audio_visible({"kind":"meteor_impact","cell":event.center}):Sfx.play("meteor_impact")
			continue
		if event.kind=="ultimate":
			var parts:PackedStringArray=String(event.key).split("_")
			if int(event.pulse)==0 and world.audio_visible(event):Sfx.play(parts[0])
			for id:int in event.hits:
				if world.audio_visible({"kind":"damage","enemy":id}):
					Sfx.play(parts[1]+"_hit");break
			continue
		if event.kind=="merge_placed":
			if world.audio_visible(event):Sfx.play("merge_success")
			continue
		if event.kind=="merge_prepare":
			Sfx.play("confirm");continue
		if event.kind=="attack":
			for cue:String in _attack_audio_cues(event):Sfx.play(cue)
			continue
		# Actual projectile hits are sounded from their typed attack event, not
		# the generic damage notification (which also includes periodic burns).
		if event.kind=="damage" or not world.audio_visible(event):continue
		if event.kind=="cleared":Sfx.play("upgrade");_refresh_inspector()
		else:Sfx.play(event.kind)

func _finish_result() -> void:
	if _finalizing:return
	_finalizing=true
	if build_placement!=null:build_placement.cancel()
	if merge_flow!=null:merge_flow.exit_safely()
	Sfx.play("victory" if model.result==BattleModel.Result.CLEAR else "defeat")
	await get_tree().process_frame
	var prepared:=Game.prepare_result(model.result,model.stars)
	await get_tree().process_frame
	_saved=prepared and Game.commit_prepared_result()
	_finalizing=false
	if _saved:
		await get_tree().create_timer(0.65).timeout
		Game.open_results()
	else:_show_save_error()

func _show_save_error()->void:
	var v:=_modal(trf("save_error"),"save_error")
	_button(v,trf("retry_save"),func():_dismiss();_finish_result(),Vector2(0,52),true)

func _results() -> void:
	var r:=Game.last_result
	var win:=int(r.get("result",2))==BattleModel.Result.CLEAR
	var p:=_panel(canvas,Vector2((_logical.x-620)/2,160) if not _portrait else Vector2(40,280),Vector2(620,505) if not _portrait else Vector2(640,670))
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;p.add_child(scroll)
	var v:=_vbox(scroll);v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_grove_accent(P.RESULT_ACCENT,p.position+Vector2(p.size.x-78,12),Vector2(58,58))
	_label(v,"FABLEWOOD",20,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	if r.has("hard_mode"):
		_mode_badge(v,bool(r.get("hard_mode",false)),"ResultModeBadge",Vector2.ZERO,Vector2(132,30),13)
	_text(v,trf("victory") if win else trf("defeat"),35)
	_text(v,trf("victory_body") if win else trf("defeat_body"),20)
	_label(v,"• ".repeat(int(r.get("stars",0))),25,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	_text(v,trf("result_stats",{"kills":int(r.get("kills",0)),"score":int(r.get("leaderboard_score",0))}),22)
	_text(v,trf("ranking_"+String(r.get("ranking_group","legacy"))),16)
	_text(v,trf("combat_duration",{"seconds":int(r.get("duration_seconds",0))}),15)
	_label(v,trf("record") if bool(r.get("leaderboard_saved",true)) else trf("save_error"),15,Vector2.ZERO,Vector2.ZERO,P.MUTED)
	if not bool(r.get("leaderboard_saved",true)):
		_button(v,trf("retry_score_save"),func():
			if Game.retry_leaderboard_save():_rebuild_canvas();_resize()
			else:_toast(trf("save_error")),Vector2(0,44))
	var chapter:=int(String(r.get("stage_id","s1")).trim_prefix("s"))
	if win and chapter<3:_button(v,trf("continue"),func():_launch_stage(StringName("s%d"%(chapter+1))),Vector2(0,56),true)
	_button(v,trf("retry"),func():_launch_stage(StringName(r.get("stage_id","s1"))),Vector2(0,50),not win)
	var row:=HBoxContainer.new();v.add_child(row)
	_button(row,trf("chapters"),func():Game.open_stage_select(),Vector2(270,45))
	_button(row,trf("scores"),_show_scores,Vector2(260,45))
	_button(v,trf("menu"),func():Game.open_title(),Vector2(0,45))

func _modal(title:String,kind:String="message") -> VBoxContainer:
	var continuing:=not _modal_kind.is_empty()
	var previous_kind:=_modal_kind
	if not continuing:
		_modal_pause_before=paused
		var focus:=get_viewport().gui_get_focus_owner()
		_modal_focus_before=weakref(focus) if focus!=null else null
	else:_remove_overlay()
	_modal_kind=kind
	_modal_message=title
	if kind!=previous_kind:_modal_return_kind=previous_kind
	if mode=="battle":paused=true
	overlay=Control.new();overlay.name="Modal_"+kind;overlay.size=_logical;overlay.mouse_filter=Control.MOUSE_FILTER_STOP;canvas.add_child(overlay)
	var shade:=ColorRect.new();shade.color=Color(0.02,0.025,0.05,0.72);shade.size=_logical;shade.mouse_filter=Control.MOUSE_FILTER_STOP;overlay.add_child(shade)
	var panel:=_panel(overlay,Vector2((_logical.x-600)/2,(_logical.y-540)/2),Vector2(600,540))
	var margin:=ScrollContainer.new();margin.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;margin.follow_focus=true;panel.add_child(margin)
	var v:=_vbox(margin);v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_text(v,title,29)
	_lock_modal_focus.call_deferred(overlay)
	return v

func _remove_overlay()->void:
	for entry:Dictionary in _modal_disabled_focus:
		var control:Control=entry.ref.get_ref()
		if is_instance_valid(control):control.focus_mode=entry.mode
	_modal_disabled_focus.clear()
	if is_instance_valid(overlay):
		overlay.get_parent().remove_child(overlay);overlay.queue_free()
	overlay=null

func _lock_modal_focus(expected:Control)->void:
	if not is_instance_valid(expected) or overlay!=expected:return
	var controls:Array[Control]=[]
	for node:Node in canvas.find_children("*","Control",true,false):
		var control:=node as Control
		if control.focus_mode==Control.FOCUS_NONE:continue
		if overlay.is_ancestor_of(control):
			if control.is_visible_in_tree() and not (control is BaseButton and control.disabled):controls.append(control)
		else:
			_modal_disabled_focus.append({"ref":weakref(control),"mode":control.focus_mode})
			control.focus_mode=Control.FOCUS_NONE
	for i:int in controls.size():
		controls[i].focus_next=controls[i].get_path_to(controls[(i+1)%controls.size()])
		controls[i].focus_previous=controls[i].get_path_to(controls[posmod(i-1,controls.size())])
	if not controls.is_empty():controls[0].grab_focus()

func _close_modal()->void:
	if _modal_kind=="save_error":return
	if _modal_kind=="threats":_close_threats();return
	if _modal_kind in ["settings","message"] and _modal_return_kind=="pause":_show_pause();return
	var restore_paused:=_modal_pause_before
	_dismiss()
	paused=restore_paused

func _dismiss(restore_focus:bool=true) -> void:
	_remove_overlay()
	_modal_kind="";_modal_return_kind=""
	if restore_focus and _modal_focus_before!=null:
		var previous:Control=_modal_focus_before.get_ref()
		if is_instance_valid(previous) and previous.is_inside_tree() and previous.is_visible_in_tree():previous.grab_focus()
	_modal_focus_before=null

func _show_pause() -> void:
	if _ended:return
	if build_placement!=null:build_placement.cancel()
	var v:=_modal(trf("paused"),"pause")
	# Resume also releases a Pause menu recreated after a nested guide or tour.
	_modal_pause_before=false
	overlay.set_meta("pause_menu",true)
	_button(v,trf("resume"),_close_modal,Vector2(0,55),true).tooltip_text=trf("pause_hint")
	_button(v,trf("settings"),_show_settings,Vector2(0,50))
	_button(v,trf("threats"),_show_threats,Vector2(0,50)).tooltip_text=trf("threats_hint")
	_button(v,trf("help"),_show_tutorial,Vector2(0,50))
	_button(v,trf("resign"),_resign_attempt,Vector2(0,50))
	_text(v,trf("select_tower"),17)

func _resign_attempt()->void:
	if model==null or _ended or _finalizing or _modal_kind!="pause":return
	# Restore held donors before the model accepts a terminal action. Keep the
	# paused recovery route until both operations have actually succeeded.
	if merge_flow!=null and not merge_flow.exit_safely():
		_show_resign_error()
		return
	if not model.apply_action([&"resign"]):
		if merge_flow!=null:merge_flow.refresh()
		_show_resign_error()
		return
	_dismiss();paused=false;_ended=true;_finish_result()

func _show_resign_error()->void:
	Sfx.play("invalid")
	var v:=_modal(trf("resign_rejected"))
	_button(v,trf("back"),_close_modal,Vector2(0,50))

func _show_settings() -> void:
	var v:=_modal(trf("settings"),"settings")
	for bus:String in ["Master","Music","SFX","UI"]:
		_label(v,trf({"Master":"master","Music":"music","SFX":"sfx","UI":"ui_audio"}[bus]),19)
		var slider:=HSlider.new();slider.name="Volume"+bus;slider.min_value=0;slider.max_value=1;slider.step=0.0025 if bus=="SFX" else 0.05;slider.scrollable=false
		slider.value={"Master":_master_volume,"Music":_music_volume,"SFX":_sfx_volume,"UI":_ui_volume}[bus]
		slider.custom_minimum_size=Vector2(0,40);v.add_child(slider)
		slider.value_changed.connect(func(value:float):
			match bus:
				"Master":_master_volume=value;Music.set_master_volume(value)
				"Music":_music_volume=value;_set_volume(bus,value)
				"SFX":_sfx_volume=value;_set_volume(bus,value)
				"UI":_ui_volume=value;Sfx.set_ui_volume(value)
			if not _save_preferences():_toast(trf("save_error")))
	var motion:=CheckButton.new();motion.text=trf("motion");motion.button_pressed=_reduced_motion;v.add_child(motion)
	motion.toggled.connect(func(on:bool):
		_reduced_motion=on;_save_preferences();Sfx.play("confirm")
		if is_instance_valid(world):world.reduced_motion=on)
	var filter_toggle:=CheckButton.new();filter_toggle.name="ScreenFilterEnabled";filter_toggle.text=trf("screen_filter");filter_toggle.button_pressed=_filter_enabled;v.add_child(filter_toggle)
	filter_toggle.toggled.connect(func(on:bool):_filter_enabled=on;_apply_filter();_save_preferences())
	_label(v,trf("filter_intensity"),19)
	var intensity:=HSlider.new();intensity.name="ScreenFilterIntensity";intensity.min_value=0;intensity.max_value=1;intensity.step=0.05;intensity.value=_filter_intensity;intensity.scrollable=false;intensity.custom_minimum_size=Vector2(0,40);v.add_child(intensity)
	intensity.value_changed.connect(func(value:float):_filter_intensity=value;_apply_filter();_save_preferences())
	var row:=HBoxContainer.new();v.add_child(row)
	_button(row,"EN",func():I18n.set_locale(&"en-US"),Vector2(180,48))
	_button(row,"CN 简体中文",func():I18n.set_locale(&"zh-CN"),Vector2(240,48))
	_button(v,trf("back"),_close_modal,Vector2(0,50))

func _local_score_entries(hard:bool)->Array[Dictionary]:
	return Leaderboard.local_entries_for_mode(hard,8)

func _show_scores() -> void:
	var v:=_modal(trf("scores"),"scores")
	var tabs:=GridContainer.new();tabs.columns=2;v.add_child(tabs)
	for group:String in ["normal","hard","practice","legacy"]:
		var tab:=_button(tabs,trf("ranking_"+group),func():
			_scores_group=group;_scores_hard_mode=group=="hard";_show_scores(),Vector2(0,44),_scores_group==group)
		tab.name="Scores"+group.capitalize()+"Tab"
	_text(v,trf("scores_group_"+_scores_group),15)
	var entries:Array[Dictionary]=Leaderboard.local_entries_for_group(_scores_group,8)
	if entries.is_empty():_text(v,trf("empty"),20)
	for i:int in entries.size():
		var e:Dictionary=entries[i]
		var chapter:=int(String(e.get("stage_id","s1")).trim_prefix("s"))
		_text(v,trf("score_row",{"rank":i+1,"chapter":trf("chapter%d"%clampi(chapter,1,3)),"score":e.get("score",0)}),19)
	_button(v,trf("back"),_close_modal,Vector2(0,50))

func _focus_live_button(button:Button)->void:
	if is_instance_valid(button) and button.is_inside_tree() and not button.is_queued_for_deletion():button.grab_focus()

func _show_threats()->void:
	if mode!="battle" or model==null or _ended or _tutorial_active or (merge_flow!=null and merge_flow.active):return
	if overlay!=null and not bool(overlay.get_meta("pause_menu",false)):return
	var focus:=get_viewport().gui_get_focus_owner()
	_threats_focus_before=weakref(focus) if focus!=null else null
	_threats_paused_before=paused
	_threats_return_to_pause=overlay!=null and bool(overlay.get_meta("pause_menu",false))
	if overlay!=null:_dismiss()
	# This is a deliberate, player-opened modal. It never auto-opens on a model
	# event, and it holds the live simulation just like the normal pause menu.
	paused=true
	var v:=_modal(trf("threats_title"),"threats")
	(v.get_parent() as ScrollContainer).follow_focus=true
	var first_close:=_button(v,trf("back"),_close_threats,Vector2(0,48),true)
	_focus_live_button.call_deferred(first_close)
	overlay.set_meta("threats_guide",true)
	_text(v,trf("threats_intro"),17)
	if _hard_mode:
		var hard_feedback:=_text(v,trf("hard_mode_weakness"),15)
		hard_feedback.name="HardModeWeaknessFeedback"
		hard_feedback.add_theme_color_override("font_color",P.GOLD)
	_guide_enemy(v,"prismback")
	_guide_enemy(v,"harrier")
	_guide_enemy(v,"broodmother")
	_label(v,trf("threats_tower_title"),20,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	_text(v,trf("threats_tower_rules"),16)
	_button(v,trf("back"),_close_threats,Vector2(0,50),true)

## Public seams for focused native UI captures. They retain the same tutorial,
## merge, focus and prior-pause rules as the player-facing buttons.
func open_threats_guide()->void:
	_show_threats()

func close_threats_guide()->void:
	_close_threats()

func threats_guide_open()->bool:
	return overlay!=null and bool(overlay.get_meta("threats_guide",false))

func _guide_enemy(parent:Node,kind:String)->void:
	var card:=_panel(parent,Vector2.ZERO,Vector2.ZERO,Color("20232f"))
	card.custom_minimum_size=Vector2(0,154 if not _portrait else 168)
	var column:=_vbox(card)
	_label(column,trf("enemy_"+kind),21,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	var portrait:=TextureRect.new()
	portrait.texture=LateVisuals.frame(StringName(kind),&"SE",0.0)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.custom_minimum_size=Vector2(0,76)
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)
	if portrait.texture==null:
		# Never replace an undelivered creature with legacy art; the copy remains a
		# truthful guide entry until the authored directional carrier is present.
		_text(column,trf("threats_art_pending"),13).add_theme_color_override("font_color",P.MUTED)
	_text(column,trf("enemy_"+kind+"_guide"),15)
	_text(column,trf("enemy_"+kind+"_counter"),14).add_theme_color_override("font_color",P.GOLD)

func _close_threats()->void:
	if overlay==null or not bool(overlay.get_meta("threats_guide",false)):return
	_dismiss()
	if _threats_return_to_pause:
		paused=true
		_show_pause()
		var buttons:=overlay.find_children("*","Button",true,false)
		if not buttons.is_empty():(buttons[0] as Button).grab_focus()
	elif _threats_paused_before:
		# Defensive restoration for a paused caller outside the standard pause menu.
		paused=true
		_show_pause()
	else:
		paused=false
		var old_focus:Control=_threats_focus_before.get_ref() if _threats_focus_before!=null else null
		if is_instance_valid(old_focus) and old_focus.is_inside_tree() and old_focus.is_visible_in_tree():old_focus.grab_focus()
		elif is_instance_valid(_threats_button):_threats_button.grab_focus()
	_threats_return_to_pause=false
	_threats_paused_before=false
	_threats_focus_before=null

func _show_tutorial() -> void:
	if _tutorial_active:return
	_tutorial_active=true
	_notice_time=0
	if is_instance_valid(_notice):_notice.text=""
	_tutorial_step=0
	_tutorial_completed_steps.clear()
	_tutorial_pause_before=paused
	var focus:=get_viewport().gui_get_focus_owner()
	_tutorial_focus_before=_modal_focus_before if _modal_kind=="pause" else weakref(focus) if focus!=null else null
	if mode=="battle":
		paused=true
		_tutorial_camera_before={"zoom":world.zoom,"pan":world.pan}
		world.reset_view()
	_tutorial_page()
func _tutorial_count()->int:return 6 if mode=="battle" else 1
func _tutorial_copy()->Dictionary:
	if mode!="battle":return {"title":"coach_start_title","body":"coach_start_body"}
	var key:String=["route","choose","place","upgrade","camera","wave"][_tutorial_step]
	return {"title":"coach_"+key+"_title","body":"coach_"+key+"_body"}
func _tutorial_page() -> void:
	_dismiss()
	var callout:=TutorialCallout.new()
	overlay=callout;canvas.add_child(callout);callout.setup(self)
	callout.next_requested.connect(func():_tutorial_advance(false))
	callout.back_requested.connect(_tutorial_back)
	callout.skip_requested.connect(_skip_tutorial)
func _tutorial_can_advance()->bool:
	return mode!="battle" or _tutorial_step in [0,4] or _tutorial_completed_steps.has(_tutorial_step)

func _tutorial_advance(from_action:bool=false)->void:
	if not _tutorial_active:return
	if from_action:_tutorial_completed_steps[_tutorial_step]=true
	if not _tutorial_can_advance():return
	if _tutorial_step+1>=_tutorial_count():
		_tutorial_finish(false)
		return
	_tutorial_step+=1
	if build_placement!=null and chosen!=&"" and _tutorial_step!=2:build_placement.cancel()
	(overlay as FablewoodTutorialCallout).refresh()
func _tutorial_back()->void:
	if _tutorial_step>0:
		_tutorial_step-=1
		if build_placement!=null and chosen!=&"" and _tutorial_step!=2:build_placement.cancel()
		(overlay as FablewoodTutorialCallout).refresh()
func _tutorial_control_rect(control:Control)->Rect2:
	if not is_instance_valid(control):return Rect2()
	var transform:=canvas.get_global_transform_with_canvas().affine_inverse()*control.get_global_transform_with_canvas()
	return transform*Rect2(Vector2.ZERO,control.size)
func _tutorial_world_point(point:Vector2)->Vector2:
	world.framing()
	return world.position+world._origin+point*world._scale
func _tutorial_target_rect()->Rect2:
	if mode!="battle":return _tutorial_control_rect(_tutorial_start_button)
	match _tutorial_step:
		0:
			var goal:=_tutorial_world_point(world.ground(Vector2(model.path_for(0)[-1])))
			return Rect2(goal-Vector2(65,137)*world._scale,Vector2(130,144)*world._scale)
		1:return _tutorial_control_rect(_cards[0])
		2:
			var target_cell:=Vector2i(4,3)
			for y:int in model.stage.grid_size().y:
				for x:int in model.stage.grid_size().x:
					var candidate:=Vector2i(x,y)
					if model.stage.is_elevated_platform(candidate) and model.alive_unit_at(candidate)==null:
						if not model.stage.is_elevated_platform(target_cell) or model.alive_unit_at(target_cell)!=null:target_cell=candidate
			var at:=world.position+world.screen_of(target_cell)
			return Rect2(at-Vector2(32,20)*world._scale,Vector2(64,40)*world._scale)
		3:
			if is_instance_valid(_tutorial_upgrade_button):return _tutorial_control_rect(_tutorial_upgrade_button)
			return _tutorial_control_rect(inspector.get_parent())
		4:return _tutorial_control_rect(_tutorial_camera_row)
		5:return _tutorial_control_rect(_next)
	return Rect2()
func _tutorial_avoid_rects()->Array[Rect2]:
	var rects:Array[Rect2]=[]
	if mode=="battle" and _tutorial_step==3:rects.append(_tutorial_control_rect(inspector.get_parent()))
	if mode=="battle" and _tutorial_step==2:
		for card:Button in _cards:rects.append(_tutorial_control_rect(card))
	return rects
func _tutorial_route_points()->PackedVector2Array:
	var points:=PackedVector2Array()
	for cell:Vector2i in model.path_for(0):points.append(_tutorial_world_point(world.cell_center(cell)))
	return points
func _tutorial_allows_target()->bool:
	return mode=="battle" and _tutorial_step in [1,2,3,4,5]
func _tutorial_input_rects()->Array[Rect2]:
	var rects:Array[Rect2]=[_tutorial_target_rect().grow(7)]
	if build_placement!=null and build_placement.active():rects.append(_tutorial_control_rect(build_placement.cancel_button))
	if mode=="battle" and _tutorial_step in [2,3,4]:rects.append(_tutorial_control_rect(world))
	if mode=="battle" and _tutorial_step==2:
		for card:Button in _cards:rects.append(_tutorial_control_rect(card))
	return rects
func _tutorial_finish(skipped:bool,launch_wave:bool=false)->void:
	if not _tutorial_active:
		# Compatibility seam for existing deterministic/native test harnesses.
		_tutorial_seen=true;_tutorial_completed_version=TUTORIAL_VERSION;_tutorial_status="skipped" if skipped else "complete";_save_preferences();paused=false;_dismiss();return
	_tutorial_active=false
	if mode=="battle":
		_tutorial_seen=true;_tutorial_tour_requested=false;_tutorial_completed_version=TUTORIAL_VERSION;_tutorial_status="skipped" if skipped else "complete"
	else:_tutorial_tour_requested=not skipped
	var saved:=_save_preferences()
	_dismiss()
	paused=false if launch_wave else _tutorial_pause_before
	if mode=="battle" and not _tutorial_camera_before.is_empty():
		world.zoom=float(_tutorial_camera_before.zoom);world.pan=_tutorial_camera_before.pan
	_tutorial_camera_before.clear()
	var old_focus:Control=_tutorial_focus_before.get_ref() if _tutorial_focus_before!=null else null
	if mode=="battle" and paused:
		_show_pause()
		_modal_focus_before=_tutorial_focus_before
		var pause_buttons:=overlay.find_children("*","Button",true,false)
		if not pause_buttons.is_empty():(pause_buttons[0] as Button).grab_focus()
	elif is_instance_valid(old_focus) and old_focus.is_inside_tree() and old_focus.is_visible_in_tree():old_focus.grab_focus()
	elif mode=="battle":_next.grab_focus()
	elif is_instance_valid(_tutorial_start_button):_tutorial_start_button.grab_focus()
	if not saved:
		var message:=_modal(trf("save_error"))
		_button(message,trf("close"),_close_modal,Vector2(0,50))
func _skip_tutorial() -> void:
	_tutorial_finish(true)
func _toast(message:String) -> void:
	if _tutorial_active and is_instance_valid(overlay) and overlay is FablewoodTutorialCallout:
		(overlay as FablewoodTutorialCallout).show_feedback(message)
		return
	if is_instance_valid(_notice):
		_notice.text=message
		_notice_time=2.5
	else:
		var v:=_modal(message)
		_button(v,trf("close"),_close_modal)

func _input(event:InputEvent) -> void:
	var method:=_input_method
	if event is InputEventScreenTouch or event is InputEventScreenDrag:method="touch"
	elif event is InputEventMouseButton:method="pointer"
	elif event is InputEventKey and event.pressed:method="keyboard"
	if method!=_input_method:
		_input_method=method
		if _tutorial_active and overlay is FablewoodTutorialCallout:overlay.refresh_copy()
	if build_placement!=null and build_placement.active():
		if event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag:
			build_placement.set_pointer(canvas.get_global_transform_with_canvas().affine_inverse()*event.position)
		var cancel_key:bool=event is InputEventKey and event.keycode==KEY_ESCAPE
		var cancel_mouse:bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT
		if cancel_key or cancel_mouse:
			get_viewport().set_input_as_handled()
			if event.is_pressed() and not event.is_echo():build_placement.cancel()
			return
	if merge_flow!=null and merge_flow.active and event is InputEventKey and event.keycode==KEY_ESCAPE and overlay==null:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:merge_flow.cancel()
		return
	if not event is InputEventKey or event.keycode not in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_U]:return
	if mode!="battle" or model==null or get_tree().paused or _ended:return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:return
	var focus:=get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:return
	if _tutorial_active:
		# Required tour actions own their hotkeys before GUI focus can activate Skip.
		if event.keycode==KEY_U and _tutorial_step==3:
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo:
				_refresh_upgrade_availability()
				if is_instance_valid(_tutorial_upgrade_button) and not _tutorial_upgrade_button.disabled:
					_tutorial_upgrade_button.pressed.emit()
		elif event.keycode in [KEY_ENTER,KEY_KP_ENTER] and _tutorial_step==5:
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo:_next_wave()
		return
	if event.keycode==KEY_SPACE:
		# Only the actual pause menu can be closed by Space; never dismiss Settings/dialogs.
		if overlay!=null and not overlay.get_meta("pause_menu",false):return
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			Sfx.play("confirm")
			if paused:_close_modal()
			else:_show_pause()
		return
	if paused or overlay!=null:
		if overlay!=null and (focus==null or not overlay.is_ancestor_of(focus)):get_viewport().set_input_as_handled()
		return
	if merge_flow!=null and merge_flow.active:
		get_viewport().set_input_as_handled();return
	# Reserve gameplay hotkeys even if an unrelated gameplay button has focus.
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo:return
	if event.keycode==KEY_U:
		_refresh_upgrade_availability()
		if is_instance_valid(_tutorial_upgrade_button) and not _tutorial_upgrade_button.disabled:
			_tutorial_upgrade_button.pressed.emit()
	elif model.result==BattleModel.Result.RUNNING and not model.wave_active and model.wave<8:
		_next_wave()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _tutorial_active:
			if event.keycode==KEY_ESCAPE:_skip_tutorial()
			elif mode=="battle" and _tutorial_step==4 and _handle_speed_key(event):pass
			elif mode=="battle" and _tutorial_step in [1,2] and event.keycode>=KEY_1 and event.keycode<=KEY_4:_choose(P.IDS[event.keycode-KEY_1])
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_ESCAPE:
			if overlay!=null and bool(overlay.get_meta("threats_guide",false)):
				_close_threats()
			elif overlay!=null:_close_modal()
			elif mode=="battle":_show_pause()
			get_viewport().set_input_as_handled()
		elif mode=="battle" and not paused and not _ended and overlay==null:
			if _handle_speed_key(event):return
			if event.keycode>=KEY_1 and event.keycode<=KEY_4:_choose(P.IDS[event.keycode-KEY_1])

func _merge_image(key:String,height:float)->void:
	var image:=TextureRect.new();image.texture=MergedArt.DATA[key].texture
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size=Vector2(160,height);inspector.add_child(image)
func _refresh_merge_inspector()->void:
	var pending:=not model.pending_merge.is_empty()
	var key:=String(model.pending_merge.get("key",""))
	_label(inspector,MergedArt.title(key) if pending else trf("merge_title"),25,Vector2.ZERO,Vector2.ZERO,P.GOLD)
	if pending:
		_text(inspector,MergedArt.subtitle(key),17)
		if not _portrait:_merge_image(key,145)
		_text(inspector,trf("merge_place"),17)
	else:
		var first_donor:=model.unit_by_id(merge_flow.first)
		_text(inspector,trf("merge_second_dual" if model.is_merged(first_donor) else "merge_second") if merge_flow.first>=0 else trf("merge_first"),18)
		if merge_flow.first>=0:
			var donor:=model.unit_by_id(merge_flow.first)
			var donor_title:=MergedArt.title(model.merge_key(donor)) if model.is_merged(donor) else trf(model.element(donor))
			_text(inspector,trf("merge_selected").format({"element":donor_title}),17).add_theme_color_override("font_color",P.GOLD if model.is_merged(donor) else P.COLORS[model.element(donor)])
	if merge_flow.feedback!="":_text(inspector,merge_flow.feedback,15).add_theme_color_override("font_color",Color("ffb995"))
	if not _portrait:_text(inspector,trf("merge_safety"),15).add_theme_color_override("font_color",P.MUTED)
	_button(inspector,trf("merge_cancel"),merge_flow.cancel,Vector2(0,42))
func _refresh_merged_inspector(u:UnitState)->void:
	inspector.add_theme_constant_override("separation",6)
	var key:=model.merge_key(u)
	_text(inspector,MergedArt.title(key),24).add_theme_color_override("font_color",P.GOLD)
	_text(inspector,MergedArt.subtitle(key),17)
	if not _portrait:_merge_image(key,64)
	var damage_parts:PackedStringArray=[]
	var details:PackedStringArray=[trf("merge_channels")]
	for channel:Dictionary in model.merged[u.id].channels:
		damage_parts.append(str(channel.damage))
		details.append("%s  %d / %.2fs — %s"%[trf(channel.element),int(channel.damage),float(channel.interval)/30.0,trf("merge_"+String(channel.element)+"_ability")])
	var stats_copy:="%s %d · %s %d"%[trf("damage"),model.base_attack_damage(u),trf("range"),model.range_for(u)] if model.is_all_element(u) else "%s %d (%s) · %s %d"%[trf("damage"),model.base_attack_damage(u)," + ".join(damage_parts),trf("range"),model.range_for(u)]
	var stats:=_text(inspector,stats_copy,16)
	stats.mouse_filter=Control.MOUSE_FILTER_PASS;stats.tooltip_text="\n".join(details)
	_text(inspector,trf("ultimate_label")+" · "+trf("ultimate_"+key+"_name"),18).add_theme_color_override("font_color",P.GOLD)
	_ultimate_status=_text(inspector,"",15)
	_ultimate_bar=ProgressBar.new();_ultimate_bar.show_percentage=false;_ultimate_bar.custom_minimum_size=Vector2(0,8);_ultimate_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("101621")
	var fill:=StyleBoxFlat.new();fill.bg_color=P.GOLD
	_ultimate_bar.add_theme_stylebox_override("background",bg);_ultimate_bar.add_theme_stylebox_override("fill",fill);inspector.add_child(_ultimate_bar)
	_refresh_ultimate_status()
	_text(inspector,trf("ultimate_"+key+"_desc"),15)
	_button(inspector,"%s  %d"%[trf("sell"),roundi(u.dp_cost*.5)],func():
		if not _gameplay_action_allowed():return
		if model.apply_action([&"retreat",u.id]):
			selected_id=-1;world.selected=-1;Sfx.play("back");_refresh_inspector();_refresh_hud(),Vector2(0,40))
func _refresh_ultimate_status()->void:
	if not is_instance_valid(_ultimate_status) or not is_instance_valid(_ultimate_bar):return
	var state:Dictionary=model.ultimates.info(selected_id)
	if state.is_empty():return
	var label:=trf("ultimate_ready") if int(state.remaining)==0 else trf("ultimate_cooldown").format({"seconds":ceili(float(state.remaining)/30.0)})
	if bool(state.active):label=trf("ultimate_active")+" · "+label
	elif not model.wave_active or model.alive_count()==0:label+=" · "+trf("ultimate_waiting")
	_ultimate_status.text=label
	_ultimate_status.tooltip_text=trf("ultimate_timing")
	_ultimate_status.mouse_filter=Control.MOUSE_FILTER_PASS
	_ultimate_bar.value=100.0*(1.0-float(state.remaining)/float(state.period))

func _exit_tree()->void:
	if merge_flow!=null:merge_flow.exit_safely()

func _grove_accent(texture:Texture2D,at:Vector2,dimensions:Vector2)->void:
	# Decoration is separate from input and existing control layout.
	var image:=TextureRect.new()
	image.texture=texture;image.position=at;image.size=dimensions
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(image)

func _wrap_tooltip(copy:String)->String:
	# Bound the default tooltip with presentation-only breaks and current font metrics.
	var lines:=PackedStringArray()
	var line:=""
	for index:int in copy.length():
		var glyph:=copy.substr(index,1)
		if glyph=="\n":
			lines.append(line);line="";continue
		line+=glyph
		if P.BODY_FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x>360.0:
			var split:=line.rfind(" ")
			if split>0:
				lines.append(line.left(split));line=line.substr(split+1)
			else:
				lines.append(line.left(line.length()-1));line=glyph
	if not line.is_empty():lines.append(line)
	return "\n".join(lines)
