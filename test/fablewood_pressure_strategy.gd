extends "res://test/fablewood_checks.gd"
var policy:Array[StringName]=[]
var center:=Vector2i(4,3)
var fill_limit:=12
func defend(m:FablewoodBattle)->void:
	var positions:=pads(m)
	positions.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(center)<b.distance_squared_to(center))
	for i:int in mini(positions.size(),fill_limit):
		if m.alive_unit_at(positions[i])==null:m.apply_action([&"deploy",policy[i%policy.size()],positions[i],0])
	for u:UnitState in m.units:
		if m.dp>=m.upgrade_cost(u):m.apply_action([&"upgrade",u.id])
func run()->void:
	var policies:Array[Array]=[
		[&"caster_1",&"sniper_1",&"recruit",&"recruit"],
		[&"caster_1",&"recruit",&"sniper_1",&"recruit"],
		[&"caster_1",&"sniper_1",&"recruit",&"recruit",&"recruit"],
		[&"caster_1",&"sniper_1",&"caster_1",&"recruit"],
		[&"caster_1",&"sniper_1",&"recruit",&"guard_1"],
		[&"caster_1",&"recruit",&"recruit",&"sniper_1",&"guard_1"]]
	for n:int in policies.size():
		policy.assign(policies[n])
		for chapter:int in [2,3]:
			var m:=make(chapter)
			for wave:int in 8:
				if m.result!=BattleModel.Result.RUNNING:break
				defend(m);m.next_wave()
				var bound:=0
				while m.wave_active and m.result==BattleModel.Result.RUNNING and bound<20000:m.step();m.drain_events();bound+=1
			print("PRESSURE_POLICY ",n," chapter ",chapter," result ",m.result," wave ",m.wave," HP ",m.base_hp," kills ",m.killed," gold ",m.dp)
	quit()
