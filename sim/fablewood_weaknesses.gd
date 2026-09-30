extends RefCounted
## Success feedback only: never modifies damage, movement, gold or rewards.
var cooldowns:Dictionary={}
var controls:Dictionary={}
var fire_groups:Dictionary={}
var fire_tick:=-1
func _cell(m,e:EnemyState)->Vector2i:
	return Pathing.cell_of(m.path_for(e.path_idx),e.progress_units)
func _emit(m,key:String,owner:int,e:EnemyState,element:String)->void:
	var token:=key+":"+str(owner)
	if m.tick<int(cooldowns.get(token,-1)):return
	cooldowns[token]=m.tick+45
	m.events.append({"kind":"weakness","key":key,"enemy":e.id,"cell":_cell(m,e),"element":element,"tick":m.tick})
func damage_applied(m,e:EnemyState,amount:int,source:String,shield_before:int)->void:
	if amount<=0 or source.is_empty():return
	if e.def_id==&"prismback" and shield_before>0 and "earth" in source:
		_emit(m,"shell_bypass",e.id,e,"earth")
	if not "fire" in source or not m.late_enemies.children.has(e.id):return
	if fire_tick!=m.tick:fire_tick=m.tick;fire_groups.clear()
	var mother:int=m.late_enemies.children[e.id]
	if not fire_groups.has(mother):fire_groups[mother]=[]
	var ids:Array=fire_groups[mother]
	if not e.id in ids:ids.append(e.id)
	if ids.size()>=2:_emit(m,"swarm_scorched",mother,e,"fire")
func control_applied(m,e:EnemyState,source:String,until:int)->void:
	if not e.alive or e.def_id!=&"harrier" or source.is_empty():return
	controls[e.id]={"element":"frost" if "frost" in source else "earth" if "earth" in source else "storm","until":until}
func harrier_canceled(m,e:EnemyState)->void:
	if not controls.has(e.id):return
	var tag:Dictionary=controls[e.id]
	if m.tick<int(tag.until):_emit(m,"burst_disrupted",e.id,e,String(tag.element))
func cleanup(m)->void:
	for key:String in cooldowns.keys():
		if m.tick>=int(cooldowns[key]):cooldowns.erase(key)
	for id:int in controls.keys():
		if m.tick>=int(controls[id].until) or id>=m.enemies.size() or not m.enemies[id].alive:controls.erase(id)
	if fire_tick!=m.tick:fire_groups.clear()
func clear()->void:
	cooldowns.clear();controls.clear();fire_groups.clear();fire_tick=-1
func signature()->Array:return [cooldowns,controls,fire_groups,fire_tick]
