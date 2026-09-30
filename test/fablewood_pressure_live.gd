extends "res://test/fablewood_pressure_upgrades.gd"
func run()->void:
	policy.assign([&"caster_1",&"recruit",&"sniper_1",&"recruit"])
	center=Vector2i(4,3)
	for chapter:int in [1,2,3]:
		var m:=make(chapter)
		for wave:int in 8:
			if m.result!=BattleModel.Result.RUNNING:break
			defend(m);m.next_wave()
			var bound:=0
			while m.wave_active and m.result==BattleModel.Result.RUNNING and bound<20000:
				if m.tick%90==0:defend(m)
				m.step();m.drain_events();bound+=1
		print("LIVE_REINVESTMENT chapter ",chapter," result ",m.result," wave ",m.wave," HP ",m.base_hp," kills ",m.killed," gold ",m.dp)
	quit()
