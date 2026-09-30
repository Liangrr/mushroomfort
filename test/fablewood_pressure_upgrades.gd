extends "res://test/fablewood_pressure_strategy.gd"
func defend(m:FablewoodBattle)->void:
	var positions:=pads(m)
	positions.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(center)<b.distance_squared_to(center))
	for u:UnitState in m.units:
		while m.tier(u)<3 and m.dp>=m.upgrade_cost(u):m.apply_action([&"upgrade",u.id])
	for i:int in positions.size():
		if m.alive_unit_at(positions[i])==null:m.apply_action([&"deploy",policy[i%policy.size()],positions[i],0])
func run()->void:
	var policies:Array[Array]=[
		[&"caster_1",&"sniper_1",&"recruit",&"recruit"],
		[&"caster_1",&"sniper_1",&"caster_1",&"recruit"],
		[&"caster_1",&"sniper_1",&"recruit",&"guard_1"],
		[&"caster_1",&"recruit",&"sniper_1",&"recruit"]]
	for focus:Vector2i in [Vector2i(2,3),Vector2i(4,3)]:
		center=focus
		for n:int in policies.size():
			policy.assign(policies[n])
			for chapter:int in [2,3]:
				var m:=make(chapter)
				for wave:int in 8:
					if m.result!=BattleModel.Result.RUNNING:break
					defend(m);m.next_wave()
					var bound:=0
					while m.wave_active and m.result==BattleModel.Result.RUNNING and bound<20000:m.step();m.drain_events();bound+=1
				print("UPGRADE_POLICY ",n," focus ",center," chapter ",chapter," result ",m.result," wave ",m.wave," HP ",m.base_hp," kills ",m.killed," gold ",m.dp)
	quit()
