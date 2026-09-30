extends RefCounted
## Deterministic enemy abilities; no Nodes, media, camera or presentation RNG.
const IDS:=[&"prismback",&"harrier",&"broodmother"]
const LIVE_CAP:=96
var states:Dictionary={}
var children:Dictionary={}
var last_tick:=-1
func register_enemy(m,e:EnemyState)->void:
	if not e.def_id in IDS:return
	var maximum:=ceili(e.hp_max*.35) if e.def_id==&"prismback" else 0
	states[e.id]={"born":m.tick,"shell":maximum,"shell_max":maximum,"last_hit":m.tick,"regen":m.tick+120,"mode":0,"cancel_cycle":-1,"warn_cycle":-1,"broods":0,"next_brood":m.tick+180,"warned":false}
func info(id:int)->Dictionary:return states.get(id,{})
func stop()->void:
	states.clear();children.clear()
func cleanup(m)->void:
	for id:int in states.keys():
		if id>=m.enemies.size() or not m.enemies[id].alive:states.erase(id)
	for id:int in children.keys():
		if id>=m.enemies.size() or not m.enemies[id].alive:children.erase(id)
func filter_damage(m,e:EnemyState,damage:int,kind:int)->int:
	if damage<=0 or not states.has(e.id):return damage
	var s:Dictionary=states[e.id]
	s.last_hit=m.tick;s.regen=m.tick+120
	if e.def_id!=&"prismback" or kind!=1 or int(s.shell)<=0:return damage
	var absorbed:=mini(damage,int(s.shell));s.shell=int(s.shell)-absorbed
	e.last_damage_tick=m.tick
	m.events.append({"kind":"shell_hit","enemy":e.id,"amount":absorbed})
	if int(s.shell)==0:m.events.append({"kind":"shell_break","enemy":e.id})
	return damage-absorbed
func speed_permille(e:EnemyState)->int:
	return 1750 if e.def_id==&"harrier" and int(states.get(e.id,{}).get("mode",0))==2 else 1000
func advance(m)->void:
	if last_tick==m.tick:return
	last_tick=m.tick;cleanup(m)
	if m.result!=0 or not m.wave_active:return
	for id:int in states.keys():
		var e:EnemyState=m.enemies[id];var s:Dictionary=states[id]
		if e.def_id==&"prismback":
			if m.tick>=int(s.regen) and int(s.shell)<int(s.shell_max):
				var old:int=s.shell;s.shell=mini(int(s.shell_max),int(s.shell)+ceili(int(s.shell_max)/8.0));s.regen=m.tick+30
				if old==0:m.events.append({"kind":"shell_restore","enemy":id})
		elif e.def_id==&"harrier":
			var age:int=m.tick-int(s.born);var phase:=posmod(age+60,180);var cycle:=floori(float(age+60)/180.0)
			var target_cycle:=cycle+1 if phase>=157 else cycle
			var impeded:bool=m.tick<int(m.slow_until.get(id,0)) or m.tick<e.stunned_until_tick
			if age>=97 and (phase>=157 or phase<45) and impeded and int(s.cancel_cycle)!=target_cycle:
				s.cancel_cycle=target_cycle;m.weaknesses.harrier_canceled(m,e)
			var mode:=0
			if age>=97 and phase>=157 and int(s.cancel_cycle)!=target_cycle:mode=1
			elif age>=120 and phase<45 and int(s.cancel_cycle)!=cycle:mode=2
			if mode==1 and int(s.mode)!=1:m.events.append({"kind":"harrier_tell","enemy":id})
			if mode==2 and int(s.mode)!=2:m.events.append({"kind":"harrier_dash","enemy":id})
			s.mode=mode
		elif e.def_id==&"broodmother" and int(s.broods)<3:
			if m.tick>=int(s.next_brood)-30 and not s.warned:
				s.warned=true;m.events.append({"kind":"brood_tell","enemy":id})
			if m.tick<int(s.next_brood) or m.tick<e.stunned_until_tick:continue
			var living:=0
			for child:int in children:
				if int(children[child])==id:living+=1
			if living>2 or m.alive_count()>LIVE_CAP-2:
				s.next_brood=m.tick+30;continue
			var spawned:Array[int]=[]
			for _i:int in 2:
				m._spawn({"enemy_id":&"goblin","path_idx":e.path_idx})
				var child:EnemyState=m.enemies[-1];child.progress_units=maxi(0,e.progress_units-Pathing.PROGRESS_SCALE*(3+_i)/4)
				children[child.id]=id;spawned.append(child.id)
			s.broods=int(s.broods)+1;s.next_brood=m.tick+210;s.warned=false
			m.events.append({"kind":"brood_spawn","enemy":id,"children":spawned})
