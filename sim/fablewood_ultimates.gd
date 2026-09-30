extends RefCounted
## Model-only automatic abilities. No Node, wall clock, visual RNG or audio.
const PERIODS := {"fire_frost":12*30,"fire_storm":14*30,"fire_earth":16*30,"frost_storm":12*30,"frost_earth":18*30,"storm_earth":15*30,"fire_frost_storm_earth":20*30}
const METEOR_KEY:="fire_frost_storm_earth"
const METEOR_FLIGHT_TICKS:=30
var states:Dictionary={}
var last_tick:=-1

func register(id:int,key:String)->void:
	states[id]={"key":key,"remaining":int(PERIODS[key]),"casts":0,"active":{}}
func suspend(id:int,tick:int)->void:
	if states.has(id):states[id].suspended_at=tick
func resume(id:int,tick:int)->void:
	if not states.has(id) or not states[id].has("suspended_at"):return
	var state:Dictionary=states[id];var elapsed:=tick-int(state.suspended_at)
	for field:String in ["next_tick","end_tick","launch_tick","impact_tick"]:
		if state.active.has(field):state.active[field]=int(state.active[field])+elapsed
	state.erase("suspended_at")
func remove(id:int)->void:
	states.erase(id)
func stop_effects()->void:
	for state:Dictionary in states.values():state.active={}
func info(id:int)->Dictionary:
	if not states.has(id):return {}
	var state:Dictionary=states[id]
	return {"key":state.key,"remaining":state.remaining,"period":PERIODS[state.key],"active":not state.active.is_empty(),"casts":state.casts}
func advance(m)->void:
	# A model tick is the only clock, including delayed pulses.
	if last_tick==m.tick:return
	last_tick=m.tick
	for id:int in states.keys():
		var u:UnitState=m.unit_by_id(id)
		if u==null or (not u.alive and not states[id].has("suspended_at")):states.erase(id)
	if m.result!=BattleModel.Result.RUNNING or not m.wave_active:
		stop_effects();return
	for id:int in states:
		var u:UnitState=m.unit_by_id(id)
		var state:Dictionary=states[id]
		if state.has("suspended_at"):continue
		if not state.active.is_empty():_advance_active(m,u,state)
		if m.alive_count()==0:continue
		state.remaining=maxi(0,int(state.remaining)-1)
		if int(state.remaining)==0 and _cast(m,u,state):
			state.remaining=int(PERIODS[state.key]);state.casts=int(state.casts)+1

func _cell(m,e:EnemyState)->Vector2i:
	return Pathing.cell_of(m.path_for(e.path_idx),e.progress_units)
func _distance(a:Vector2i,b:Vector2i)->int:
	return maxi(absi(a.x-b.x),absi(a.y-b.y))
func _targets(m,u:UnitState,mask:String="all",air_first:bool=false)->Array[EnemyState]:
	var out:Array[EnemyState]=[]
	for e:EnemyState in m.enemies:
		if not e.alive or (mask=="ground" and e.aerial) or (mask=="air" and not e.aerial):continue
		if _distance(_cell(m,e),u.cell)<=m.range_for(u):out.append(e)
	out.sort_custom(func(a:EnemyState,b:EnemyState)->bool:
		if air_first and a.aerial!=b.aerial:return a.aerial
		return a.progress_units>b.progress_units if a.progress_units!=b.progress_units else a.id<b.id)
	return out
func _area(m,targets:Array[EnemyState],center:Vector2i,radius:int,cap:int)->Array[EnemyState]:
	var out:Array[EnemyState]=[]
	for e:EnemyState in targets:
		if _distance(_cell(m,e),center)<=radius:
			out.append(e)
			if out.size()>=cap:break
	return out
func _hit(m,e:EnemyState,power:int,physical:bool=false,freeze:int=0,slow:int=0,burn:int=0,source:String="")->void:
	# Match inherited Earth armor bypass while retaining centralized kill accounting.
	m._elemental_damage(e,power+e.defense if physical else power,0 if physical else 1,source)
	if not e.alive:return
	if freeze>0:e.stunned_until_tick=maxi(e.stunned_until_tick,m.tick+freeze)
	if slow>0:m.slow_until[e.id]=maxi(int(m.slow_until.get(e.id,0)),m.tick+slow)
	if freeze>0 or slow>0:m.weaknesses.control_applied(m,e,source,maxi(m.tick+freeze,m.tick+slow))
	if burn>0 and not e.aerial:m.burn_until[e.id]=maxi(int(m.burn_until.get(e.id,0)),m.tick+burn)
func _event(m,u:UnitState,state:Dictionary,targets:Array[EnemyState],center:Vector2i,pulse:int=0)->void:
	var hits:Array[int]=[]
	for e:EnemyState in targets:hits.append(e.id)
	u.last_attack_tick=m.tick;u.last_attack_cell=center
	m.events.append({"kind":"ultimate","key":state.key,"unit":u.id,"cell":u.cell,"center":center,"hits":hits,"pulse":pulse,"tick":m.tick})
func _cast(m,u:UnitState,state:Dictionary)->bool:
	var key:String=state.key
	var targets:=_targets(m,u,"ground" if key=="fire_earth" else "all",key in ["fire_storm","frost_storm"])
	if targets.is_empty():return false
	var center:=_cell(m,targets[0]);var power:int=m.base_attack_damage(u)
	if key==METEOR_KEY:
		state.active={"center":center,"launch_tick":m.tick,"impact_tick":m.tick+METEOR_FLIGHT_TICKS,"channels":m.merged[u.id].channels.duplicate(true)}
		u.last_attack_tick=m.tick;u.last_attack_cell=center
		m.events.append({"kind":"meteor_launch","key":key,"unit":u.id,"cell":u.cell,"center":center,"tick":m.tick,"impact_tick":m.tick+METEOR_FLIGHT_TICKS,"radius":3,"hits":[]})
		return true
	match key:
		"fire_frost":
			targets=_area(m,targets,center,2,8)
			for e:EnemyState in targets:_hit(m,e,power*2,false,30,0,90,key)
		"fire_storm":
			var chain:Array[EnemyState]=[targets[0]]
			while chain.size()<6:
				var next:EnemyState=null
				for e:EnemyState in targets:
					if not chain.has(e) and _distance(_cell(m,chain[-1]),_cell(m,e))<=3:
						next=e;break
				if next==null:break
				chain.append(next)
			targets=chain
			for e:EnemyState in targets:_hit(m,e,power*3,false,0,0,120,key)
		"fire_earth":
			targets=_area(m,targets,center,2,8)
			for e:EnemyState in targets:_hit(m,e,power*3,true,45,0,120,key)
		"frost_storm","frost_earth":
			state.active={"center":center,"power":power,"pulse":0,"next_tick":m.tick,"end_tick":m.tick+(31 if key=="frost_storm" else 150)}
			_advance_active(m,u,state)
			return true
		"storm_earth":
			targets=[]
			var ground:=_targets(m,u,"ground");var air:=_targets(m,u,"air")
			for i:int in mini(4,ground.size()):
				targets.append(ground[i]);_hit(m,ground[i],power*2,true,60,0,0,key)
			for i:int in mini(2,air.size()):
				targets.append(air[i]);_hit(m,air[i],power*3,false,0,60,0,key)
	_event(m,u,state,targets,center)
	return true
func _advance_active(m,u:UnitState,state:Dictionary)->void:
	var active:Dictionary=state.active
	if state.key==METEOR_KEY:
		if m.tick>=int(active.impact_tick):_meteor_impact(m,u,state)
		return
	if m.tick>=int(active.end_tick):state.active={};return
	if m.tick<int(active.next_tick):return
	var grove:bool=state.key=="frost_earth"
	var limit:=5 if grove else 3
	if int(active.pulse)>=limit:return
	var targets:=_targets(m,u,"all",not grove)
	if grove:targets=_area(m,targets,active.center,2,8)
	else:targets=targets.slice(0,mini(4,targets.size()))
	var power:=ceili(float(active.power)/2.0) if grove else int(active.power)
	for e:EnemyState in targets:_hit(m,e,power,false,0,60,0,String(state.key))
	# An empty pulse still advances its fixed schedule, but never replays later.
	_event(m,u,state,targets,active.center,int(active.pulse))
	active.pulse=int(active.pulse)+1;active.next_tick=m.tick+(30 if grove else 15)

func _meteor_impact(m,u:UnitState,state:Dictionary)->void:
	var active:Dictionary=state.active
	var center:Vector2i=active.center
	var candidates:Array[EnemyState]=[]
	for e:EnemyState in m.enemies:
		if e.alive:candidates.append(e)
	candidates.sort_custom(func(a:EnemyState,b:EnemyState)->bool:return a.progress_units>b.progress_units if a.progress_units!=b.progress_units else a.id<b.id)
	var direct:=_area(m,candidates,center,3,12)
	var hits:Array[int]=[];var chains:Array[int]=[];var storm_power:=0
	for channel:Dictionary in active.channels:
		if channel.element=="storm":storm_power=int(channel.damage)*3
	for e:EnemyState in direct:
		hits.append(e.id)
		for channel:Dictionary in active.channels:
			if e.alive:_hit(m,e,int(channel.damage)*5,channel.element=="earth",0,0,0,String(channel.element))
		if e.alive:
			e.stunned_until_tick=maxi(e.stunned_until_tick,m.tick+30)
			m.slow_until[e.id]=maxi(int(m.slow_until.get(e.id,0)),m.tick+90)
			m.weaknesses.control_applied(m,e,"frost",m.tick+90)
			if not e.aerial:m.burn_until[e.id]=maxi(int(m.burn_until.get(e.id,0)),m.tick+120)
	for e:EnemyState in candidates:
		if not e.alive or e.id in hits:continue
		var nearby:=false
		for primary:EnemyState in direct:
			if _distance(_cell(m,e),_cell(m,primary))<=2:nearby=true;break
		if not nearby:continue
		chains.append(e.id);_hit(m,e,storm_power,false,0,60,0,"storm")
		if chains.size()==3:break
	state.active={}
	m.events.append({"kind":"meteor_impact","key":METEOR_KEY,"unit":u.id,"cell":u.cell,"center":center,"tick":m.tick,"radius":3,"hits":hits,"chains":chains})
