extends "res://test/fablewood_checks.gd"
const ORDERS:=[[&"recruit",&"caster_1",&"guard_1",&"sniper_1"],[&"caster_1",&"guard_1",&"recruit",&"sniper_1"],[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]]
func place_order(m:FablewoodBattle,center:Vector2i)->Array[Vector2i]:
	var slots:=pads(m);slots.sort_custom(func(a:Vector2i,b:Vector2i)->bool:
		return a.distance_squared_to(center)<b.distance_squared_to(center) if a.distance_squared_to(center)!=b.distance_squared_to(center) else a.x*100+a.y<b.x*100+b.y)
	return slots
func improve(m:FablewoodBattle,policy:int)->void:
	var slots:=place_order(m,Vector2i(4,3) if policy<3 else Vector2i(4,4));var order:Array=ORDERS[policy%3]
	# Four distinct elements first; then max each, consolidate, and rebuild a rear guard.
	var all:UnitState=null
	for u:UnitState in m.units:
		if u.alive and m.is_all_element(u):all=u;break
	if all==null:
		var present:Dictionary={}
		for u:UnitState in m.units:
			if u.alive:
				for element:String in m.elements_for(u):present[element]=true
		for id:StringName in order:
			if present.has(m.ELEMENTS[id]):continue
			for p:Vector2i in slots:
				if m.alive_unit_at(p)==null:
					if m.apply_action([&"deploy",id,p,0]):present[m.ELEMENTS[id]]=true
					break
		for id:StringName in order:
			for u:UnitState in m.units:
				if u.alive and not m.is_merged(u) and u.op_id==id:
					while m.tier(u)<3 and m.dp>=m.upgrade_cost(u):m.apply_action([&"upgrade",u.id])
		var again:=true
		while again:
			again=false
			for a:UnitState in m.units:
				if not m.eligible_merge_donor(a):continue
				for b:UnitState in m.units:
					if not m.can_merge(a,b):continue
					if m.apply_action([&"begin_merge",a.id,b.id]):
						for p:Vector2i in slots:
							if m.can_place_merge(p):m.apply_action([&"place_merge",p]);break
						again=true
					break
				if again:break
	else:
		# Build diverse counter coverage after the central super-tower, not more unneeded merges.
		for u:UnitState in m.units:
			if u.alive and not m.is_merged(u):
				while m.tier(u)<3 and m.dp>=m.upgrade_cost(u):m.apply_action([&"upgrade",u.id])
		for i:int in slots.size():
			if m.alive_unit_at(slots[i])==null:m.apply_action([&"deploy",order[i%4],slots[i],0])
func run()->void:
	for chapter:int in [1,2,3]:
		for policy:int in range(-1,6):
			if chapter==1 and policy!=-1:continue
			for expanded:bool in ([true] if chapter==1 else [false,true]):
				var m:=make(chapter)
				if not expanded:
					m.stage=m.stage.duplicate(true);var rows:Array[Dictionary]=[]
					for row:Dictionary in m.stage.waves:
						if not row.enemy_id in m.late_enemies.IDS:rows.append(row)
					m.stage.waves=rows
				var merged_at:=0
				for wave:int in 8:
					if m.result!=BattleModel.Result.RUNNING:break
					if policy<0:defend(m)
					else:improve(m,policy)
					m.next_wave();var elapsed:=0
					while m.wave_active and m.result==BattleModel.Result.RUNNING and elapsed<15000:
						if policy>=0 and m.tick%30==0:improve(m,policy)
						for u:UnitState in m.units:
							if u.alive and m.is_all_element(u) and merged_at==0:merged_at=m.wave
						m.step();m.drain_events();elapsed+=1
				if chapter==1:assert(m.result==BattleModel.Result.CLEAR and m.base_hp==12)
				if chapter==2 and policy==-1:assert(m.result==BattleModel.Result.CLEAR and m.base_hp==19)
				if chapter==3 and policy==0:assert(m.result==BattleModel.Result.CLEAR and m.base_hp==(12 if expanded else 20))
				if chapter==3 and policy==-1:assert(m.result==BattleModel.Result.DEFEAT and m.wave==(5 if expanded else 7))
				print("LATE_BALANCE chapter=",chapter," policy=",policy," expanded=",expanded," result=",m.result," wave=",m.wave," hp=",m.base_hp," leaks=",m.leaked," earned=",m.earned," spent=",m.dp_spent," gold=",m.dp," worldheart_wave=",merged_at)
	print("LATE_BALANCE_COMPLETE earned gold only; no forced victories or stat overrides")
	quit()
