class_name FablewoodTutorialCallout
extends Control
## Presentation adapter for the template's anchored callout/focus-ring pattern.
## The screen remains the tutorial flow/pause/persistence owner.
signal next_requested
signal back_requested
signal skip_requested
const P:=preload("res://scripts/fablewood/presentation.gd")
var host:Control
var card:PanelContainer
var step_label:Label
var heading:Label
var body:Label
var feedback:Label
var back_button:Button
var next_button:Button
var skip_button:Button
var target:=Rect2()
var connector:=PackedVector2Array()
var arrow:=PackedVector2Array()
var _clock:=0.0
var _layout_serial:=0
func setup(owner_screen:Control)->void:
	host=owner_screen;name="TutorialCalloutLayer";size=host._logical
	mouse_filter=Control.MOUSE_FILTER_STOP;z_index=110
	card=PanelContainer.new();card.name="TutorialCallout";card.add_theme_stylebox_override("panel",P.box(P.PANEL,P.GOLD,2,18));add_child(card)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);card.add_child(column)
	step_label=_label(column,15,P.GOLD);step_label.name="TutorialStep"
	heading=_label(column,25,P.TEXT);heading.name="TutorialTitle"
	body=_label(column,20,P.TEXT);body.name="TutorialBody"
	feedback=_label(column,17,P.GOLD);feedback.name="TutorialFeedback";feedback.visible=false
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);column.add_child(actions)
	skip_button=_button(actions,P.t("skip"),func():skip_requested.emit());skip_button.name="SkipTutorial"
	back_button=_button(actions,P.t("back"),func():back_requested.emit());back_button.name="TutorialBack"
	next_button=_button(actions,P.t("next_tip"),func():next_requested.emit());next_button.name="TutorialNext"
	next_button.add_theme_stylebox_override("normal",P.box(Color("384832"),P.GOLD,2,12))
	var buttons:Array[Button]=[skip_button,back_button,next_button]
	for i:int in buttons.size():
		var next:=buttons[(i+1)%buttons.size()]
		var previous:=buttons[posmod(i-1,buttons.size())]
		buttons[i].focus_next=buttons[i].get_path_to(next)
		buttons[i].focus_previous=buttons[i].get_path_to(previous)
		buttons[i].focus_neighbor_right=buttons[i].get_path_to(next)
		buttons[i].focus_neighbor_left=buttons[i].get_path_to(previous)
		buttons[i].focus_neighbor_bottom=buttons[i].get_path_to(next)
		buttons[i].focus_neighbor_top=buttons[i].get_path_to(previous)
	refresh()
func _label(parent:Node,font_size:int,color:Color)->Label:
	var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",roundi(font_size*float(TweakControls.value(&"ui.text_scale",1.0))))
	label.add_theme_color_override("font_color",color);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(label);return label
func _button(parent:Node,text:String,action:Callable)->Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(96,46);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",roundi(16*float(TweakControls.value(&"ui.text_scale",1.0))))
	button.pressed.connect(func():Sfx.play("confirm");action.call())
	button.mouse_entered.connect(func():Sfx.play("hover"));button.focus_entered.connect(func():Sfx.play("hover"))
	parent.add_child(button);return button
func refresh()->void:
	var data:Dictionary=host._tutorial_copy()
	step_label.text="%02d / %02d  ·  %s"%[host._tutorial_step+1,host._tutorial_count(),P.t("tutorial_title")]
	refresh_copy()
	feedback.text="";feedback.visible=false
	back_button.disabled=host._tutorial_step==0
	next_button.disabled=not host._tutorial_can_advance()
	next_button.text=P.t("coach_done" if host.mode=="battle" else "coach_enable") if host._tutorial_step==host._tutorial_count()-1 else P.t("next_tip")
	accessibility_name=heading.text;accessibility_description=body.text
	relayout();_layout_serial+=1
	_focus_primary.call_deferred(_layout_serial)
func refresh_copy()->void:
	var data:Dictionary=host._tutorial_copy()
	heading.text=P.t(data.title)
	body.text=P.t(data.body)+"\n"+P.t("coach_input_"+host._input_method)

func show_feedback(message:String)->void:
	feedback.text=message;feedback.visible=true;relayout()
func _focus_primary(serial:int)->void:
	if serial==_layout_serial and is_inside_tree():
		if next_button.disabled:skip_button.grab_focus()
		else:next_button.grab_focus()
func _process(delta:float)->void:
	if not is_instance_valid(host):return
	if not host._reduced_motion:_clock+=delta
	relayout();queue_redraw()
func relayout()->void:
	size=host._logical
	target=host._tutorial_target_rect().grow(7).intersection(Rect2(Vector2(12,12),size-Vector2(24,24)))
	var width:=minf(620.0,size.x-48.0) if host._portrait else 430.0
	width=minf(size.x-48.0,maxf(width,card.get_combined_minimum_size().x))
	card.custom_minimum_size=Vector2(width,0);card.size.x=width
	var height:=maxf(218.0,card.get_combined_minimum_size().y)
	card.size=Vector2(width,height)
	var safe:=Rect2(Vector2(22,94),size-Vector2(44,116))
	var options:Array[Vector2]=[
		Vector2(target.get_center().x-width*0.5,target.position.y-height-28),
		Vector2(target.get_center().x-width*0.5,target.end.y+28),
		Vector2(target.position.x-width-28,target.get_center().y-height*0.5),
		Vector2(target.end.x+28,target.get_center().y-height*0.5)]
	for related:Rect2 in host._tutorial_avoid_rects():
		options.append(Vector2(target.get_center().x-width*0.5,related.position.y-height-28))
		options.append(Vector2(target.get_center().x-width*0.5,related.end.y+28))
		options.append(Vector2(related.position.x-width-28,target.get_center().y-height*0.5))
		options.append(Vector2(related.end.x+28,target.get_center().y-height*0.5))
	var best:=Vector2(24,100);var best_score:=INF
	for candidate:Vector2 in options:
		candidate.x=clampf(candidate.x,safe.position.x,maxf(safe.position.x,safe.end.x-width))
		candidate.y=clampf(candidate.y,safe.position.y,maxf(safe.position.y,safe.end.y-height))
		var rect:=Rect2(candidate,card.size)
		var overlap:=rect.intersection(target.grow(12)).get_area()
		var score:=overlap*1000.0+rect.get_center().distance_to(target.get_center())
		for related:Rect2 in host._tutorial_avoid_rects():score+=rect.intersection(related.grow(8)).get_area()*100.0
		if score<best_score:best_score=score;best=candidate
	card.position=best
	var card_rect:=Rect2(card.position,card.size)
	var start:=Vector2(clampf(target.get_center().x,card_rect.position.x,card_rect.end.x),clampf(target.get_center().y,card_rect.position.y,card_rect.end.y))
	var tip:=Vector2(clampf(card_rect.get_center().x,target.position.x,target.end.x),clampf(card_rect.get_center().y,target.position.y,target.end.y))
	connector=PackedVector2Array([start,tip])
	var direction:=start.direction_to(tip)
	var base:=tip-direction*13
	var side:=Vector2(-direction.y,direction.x)*6
	arrow=PackedVector2Array([tip,base+side,base-side])
func _has_point(point:Vector2)->bool:
	if is_instance_valid(card) and Rect2(card.position,card.size).has_point(point):return true
	if is_instance_valid(host) and host._tutorial_allows_target():
		for rect:Rect2 in host._tutorial_input_rects():
			if rect.has_point(point):return false
	return Rect2(Vector2.ZERO,size).has_point(point)
func _draw()->void:
	if not is_instance_valid(host) or target.size.x<=0:return
	var dim:=Color(0.015,0.018,0.03,0.48)
	draw_rect(Rect2(0,0,size.x,target.position.y),dim)
	draw_rect(Rect2(0,target.end.y,size.x,maxf(0,size.y-target.end.y)),dim)
	draw_rect(Rect2(0,target.position.y,target.position.x,target.size.y),dim)
	draw_rect(Rect2(target.end.x,target.position.y,maxf(0,size.x-target.end.x),target.size.y),dim)
	var outline:=P.box(Color(0,0,0,0),P.GOLD,3,12)
	draw_style_box(outline,target)
	if not host._reduced_motion:
		var glow:=P.box(Color(0,0,0,0),Color(P.GOLD,0.25+sin(_clock*3.0)*0.12),2,15)
		draw_style_box(glow,target.grow(4))
	if host.mode=="battle" and host._tutorial_step==0:
		var points:PackedVector2Array=host._tutorial_route_points()
		if points.size()>1:draw_polyline(points,Color(P.GOLD,0.72),2.5,true)
	if connector.size()==2:
		draw_polyline(connector,P.GOLD,2.2,true);draw_colored_polygon(arrow,P.GOLD)
