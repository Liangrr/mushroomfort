class_name FablewoodUpgradeButton
extends Button
const P:=preload("res://scripts/fablewood/presentation.gd")
const PULSE_DURATION:=1.05
var motion_owner:Control
var _initialized:=false
var _was_affordable:=false
var _pulse_elapsed:=0.0
var _pulse_active:=false
var pulse_count:=0
var _pulse_style:StyleBoxFlat
func _ready()->void:
	# Two readable lines fit without shifting adjacent inspector controls.
	custom_minimum_size.y=62
	add_theme_font_size_override("font_size",roundi(16*float(TweakControls.value(&"ui.text_scale",1.0))))
	add_theme_color_override("font_disabled_color",P.MUTED)
	for state:String in ["normal","hover","pressed","disabled","focus"]:
		var style:=get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left=8;style.content_margin_right=8
		style.content_margin_top=5;style.content_margin_bottom=5
		add_theme_stylebox_override(state,style)
	_pulse_style=P.box(Color.TRANSPARENT,P.GOLD,2,16)
	_pulse_style.shadow_size=4
func set_upgrade_state(cost:int,gold:int,maxed:bool,blocked:bool)->void:
	var shortfall:=maxi(0,cost-gold)
	var affordable:=not blocked and not maxed and shortfall==0
	var label:=P.t("max") if maxed else "%s  %d"%[P.t("upgrade"),cost]
	if not maxed and not blocked and shortfall>0:
		label+="\n"+P.t("upgrade_shortfall").format({"gold":shortfall})
	if text!=label:text=label
	if disabled==affordable:disabled=not affordable
	if _initialized and not _was_affordable and affordable and not _reduced():
		_pulse_elapsed=0;_pulse_active=true;pulse_count+=1;queue_redraw()
	if not affordable or _reduced():_stop_pulse()
	_was_affordable=affordable;_initialized=true
func _reduced()->bool:
	return is_instance_valid(motion_owner) and motion_owner._reduced_motion
func _stop_pulse()->void:
	if not _pulse_active:return
	_pulse_active=false;_pulse_elapsed=0;queue_redraw()
func _process(delta:float)->void:
	if not _pulse_active:return
	if _reduced() or disabled or not is_visible_in_tree():_stop_pulse();return
	if is_instance_valid(motion_owner) and (motion_owner.paused or motion_owner._ended):return
	_advance_pulse(delta)
func _advance_pulse(delta:float)->void:
	if not _pulse_active:return
	_pulse_elapsed=minf(PULSE_DURATION,_pulse_elapsed+delta)
	if _pulse_elapsed>=PULSE_DURATION:_pulse_active=false
	queue_redraw()
func _draw()->void:
	if not _pulse_active or _pulse_style==null:return
	var weight:=sin(PI*_pulse_elapsed/PULSE_DURATION)
	_pulse_style.border_color=Color(P.GOLD,weight*0.85)
	_pulse_style.shadow_color=Color(P.GOLD,weight*0.18)
	draw_style_box(_pulse_style,Rect2(Vector2.ZERO,size).grow(1.5))
