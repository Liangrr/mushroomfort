class_name FablewoodNextWaveButton
extends Button
const P:=preload("res://scripts/fablewood/presentation.gd")
const PULSE_PERIOD:=2.2
var motion_owner:Control
var wave_ready:=false
var pulse_elapsed:=0.0
var _last_reduced:=false
var _pulse_style:StyleBoxFlat
var preparation_fraction:=1.0
var preparation_seconds:=30.0
func _ready()->void:
	_pulse_style=P.box(Color.TRANSPARENT,P.GOLD,2,16)
	_pulse_style.shadow_size=4
func set_wave_ready(value:bool)->void:
	disabled=not value
	if wave_ready==value:return
	wave_ready=value;pulse_elapsed=0;queue_redraw()
func set_countdown(remaining:float,duration:float)->void:
	var ratio:=clampf(remaining/maxf(0.001,duration),0,1)
	if is_equal_approx(ratio,preparation_fraction) and is_equal_approx(remaining,preparation_seconds):return
	preparation_fraction=ratio;preparation_seconds=remaining;queue_redraw()
func _reduced()->bool:
	return is_instance_valid(motion_owner) and motion_owner._reduced_motion
func _process(delta:float)->void:
	if not wave_ready:return
	var reduced:=_reduced()
	if _last_reduced!=reduced:_last_reduced=reduced;queue_redraw()
	if reduced or not is_visible_in_tree() or get_tree().paused:return
	if is_instance_valid(motion_owner) and (motion_owner.paused or motion_owner._ended):return
	_advance_pulse(delta)
func _advance_pulse(delta:float)->void:
	if not wave_ready:return
	pulse_elapsed=fposmod(pulse_elapsed+delta,PULSE_PERIOD)
	queue_redraw()
func _draw()->void:
	if not wave_ready or _pulse_style==null:return
	var strength:=0.32 if _reduced() else (0.5-0.5*cos(TAU*pulse_elapsed/PULSE_PERIOD))
	_pulse_style.border_color=Color(P.GOLD,strength*0.75)
	_pulse_style.shadow_color=Color(P.GOLD,strength*0.16)
	draw_style_box(_pulse_style,Rect2(Vector2.ZERO,size).grow(1.5))
	var track:=Rect2(Vector2(14,size.y-12),Vector2(maxf(0,size.x-28),4))
	draw_rect(track,Color(0.06,0.09,0.07,0.55))
	track.size.x*=preparation_fraction
	draw_rect(track,Color("ffce85") if preparation_seconds<=5 else Color(P.GOLD,0.85))
