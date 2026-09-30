class_name FablewoodMergeFlow
extends RefCounted
var host:Control
var active:=false
var first:=-1
var button:Button
var feedback:=""
func _init(owner:Control)->void:host=owner
func start()->void:
	if active:cancel();return
	if host.paused or host._ended or host._tutorial_active or not host.model.merge_available():return
	active=true;first=-1;feedback="";host.chosen=&"";host.selected_id=-1
	host.world.selected=-1;host.world.selected_element="";Sfx.play("confirm");refresh()
func refresh()->void:
	if not is_instance_valid(host.world):return
	var model:FablewoodBattle=host.model
	host.world.merge_first=first
	host.world.merge_active=active
	host.world.merge_pending_key=String(model.pending_merge.get("key",""))
	host.world.merge_eligible.clear()
	if active and model.pending_merge.is_empty():
		var a:=model.unit_by_id(first)
		for u:UnitState in model.units:
			if model.eligible_merge_donor(u) and (a==null or u.id==first or model.can_merge(a,u)):
				host.world.merge_eligible.append(u.id)
	host._refresh_inspector();host._refresh_hud();host.world.queue_redraw()
func refresh_button()->void:
	if not is_instance_valid(button):return
	button.disabled=host._ended or host._tutorial_active or (not active and not host.model.merge_available())
	button.text=host.trf("merge_cancel_short") if active else host.trf("merge_button")
	button.tooltip_text=host.trf("merge_cancel_hint") if active else host.trf("merge_requirement")
func click(cell:Vector2i)->void:
	if not active:return
	var model:FablewoodBattle=host.model
	if not model.pending_merge.is_empty():
		if model.apply_action([&"place_merge",cell]):
			active=false;first=-1;feedback="";host.selected_id=model.units[-1].id;host.world.selected=host.selected_id
			host._present_events();host._toast(host.trf("merge_complete"));refresh()
		else:reject("merge_empty_socket")
		return
	var u:=model.alive_unit_at(cell)
	if not model.eligible_merge_donor(u):reject("merge_requirement");return
	if u.id==first:first=-1;feedback="";refresh();return
	var a:=model.unit_by_id(first)
	if a==null:first=u.id;feedback="";Sfx.play("confirm");refresh();return
	if not model.can_merge(a,u):
		if model.is_merged(a)!=model.is_merged(u):reject("merge_same_kind")
		elif model.is_merged(a):reject("merge_no_overlap")
		else:reject("merge_different")
		return
	if model.apply_action([&"begin_merge",a.id,u.id]):
		feedback="";host._present_events();refresh()
	else:reject("merge_requirement")
func reject(key:String)->void:
	feedback=host.trf(key);Sfx.play("invalid");host._refresh_inspector()
func cancel()->void:
	if not host.model.pending_merge.is_empty() and not host.model.cancel_merge():
		reject("merge_requirement")
		return
	active=false;first=-1;feedback="";Sfx.play("back");refresh()
func exit_safely()->bool:
	if host.model!=null and not host.model.pending_merge.is_empty() and not host.model.cancel_merge():
		return false
	active=false;first=-1
	return true
