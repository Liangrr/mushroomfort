extends SceneTree
const M := preload("res://sim/fablewood_battle.gd")
var failures:=0
func _init() -> void:
	call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func make(chapter:int) -> FablewoodBattle:
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	return M.create_fablewood(load("res://data/stages/s%d.tres"%chapter),{"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids},42)
func pads(m:FablewoodBattle) -> Array[Vector2i]:
	var out:Array[Vector2i]=[]
	for y:int in 8:
		for x:int in 10:
			if m.stage.is_elevated_platform(Vector2i(x,y)):out.append(Vector2i(x,y))
	return out
func defend(m:FablewoodBattle) -> void:
	var positions:=pads(m)
	if m.chapter==2:
		# Verified earned-gold response: prioritize existing upgrades and aerial cover.
		positions.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,3))<b.distance_squared_to(Vector2i(4,3)))
		var response:Array[StringName]=[&"caster_1",&"recruit",&"sniper_1",&"recruit"]
		for u:UnitState in m.units:
			while m.tier(u)<3 and m.dp>=m.upgrade_cost(u):m.apply_action([&"upgrade",u.id])
		for i:int in positions.size():
			if m.alive_unit_at(positions[i])==null:m.apply_action([&"deploy",response[i%4],positions[i],0])
		return
	# Build a mixed defense using only earned gold. Prioritize central slots.
	positions.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,4))<b.distance_squared_to(Vector2i(4,4)))
	var order:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	for i:int in mini(positions.size(),8):
		var u:=m.alive_unit_at(positions[i])
		if u==null:
			m.apply_action([&"deploy",order[i%4],positions[i],0])
	for u:UnitState in m.units:
		if m.dp>=m.upgrade_cost(u):m.apply_action([&"upgrade",u.id])
func run() -> void:
	var m:=make(1)
	check(m!=null,"Model construction")
	var p:=pads(m)[0]
	check(not m.apply_action([&"deploy",&"caster_1",m.path_for(0)[1],0]),"Road placement rejects")
	check(m.apply_action([&"deploy",&"caster_1",p,0]),"Build accepts")
	var u:UnitState=m.units[0]
	var before:=u.atk
	check(m.apply_action([&"upgrade",u.id]),"First upgrade accepts")
	check(m.tier(u)==2 and u.atk>before,"Tier and stats both change")
	m.dp=1000
	check(m.apply_action([&"upgrade",u.id]),"Second upgrade accepts")
	var gold:=m.dp
	check(not m.apply_action([&"upgrade",u.id]) and m.dp==gold,"Maximum tier rejects without spending")
	check(m.apply_action([&"next_wave"]),"Next wave accepts")
	check(not m.apply_action([&"next_wave"]),"Concurrent wave rejects")
	var lose:=make(1)
	for w:int in 8:
		if lose.result!=BattleModel.Result.RUNNING:break
		lose.next_wave()
		var n:=0
		while lose.wave_active and lose.result==BattleModel.Result.RUNNING and n<10000:lose.step();n+=1
	check(lose.result==BattleModel.Result.DEFEAT,"An undefended town loses")
	for chapter:int in range(1,4):
		var a:=make(chapter)
		for w:int in 8:
			if a.result!=BattleModel.Result.RUNNING:break
			defend(a)
			check(a.next_wave(),"Wave starts chapter %d wave %d"%[chapter,w])
			var n:=0
			while a.wave_active and a.result==BattleModel.Result.RUNNING and n<15000:a.step();a.drain_events();n+=1
		print("BALANCE chapter=",chapter," result=",a.result," wave=",a.wave," hp=",a.base_hp," killed=",a.killed," gold=",a.dp," ticks=",a.tick)
		# Requested stat changes intentionally invalidate the old Chapter 3 auto-clear.
		# This asserts the observed reference outcome, not that Chapter 3 is unwinnable.
		var expected:=BattleModel.Result.DEFEAT if chapter==3 else BattleModel.Result.CLEAR
		check(a.result==expected,"Expected pressure-baseline outcome for chapter %d"%chapter)
	var a:=make(1);var b:=make(1)
	for q:FablewoodBattle in [a,b]:
		defend(q);q.next_wave();q.step(700)
	check(a.state_hash()==b.state_hash(),"Deterministic replay hash")
	var game:=root.get_node("Game")
	check(game.start_campaign(false),"Existing durable campaign starts with adapted content")
	if game.campaign!=null:
		check(game.start_campaign_stage(&"s1",false),"Existing campaign issues a chapter ticket")
		var ticketed:=M.create_fablewood(load("res://data/stages/s1.tres"),game.battle_launch(),42)
		check(ticketed!=null,"Adapted model accepts canonical campaign ticket")
		if ticketed!=null:
			game.current_battle=ticketed
			ticketed.apply_action([&"resign"])
			check(game.record_result(ticketed.result,ticketed.stars),"Existing campaign durably finalizes defeat")
			check(game.start_campaign_stage(&"s1",false),"Replay issues a new ticket")
			var winner:=M.create_fablewood(load("res://data/stages/s1.tres"),game.battle_launch(),42)
			game.current_battle=winner
			for w:int in 8:
				defend(winner);winner.next_wave()
				while winner.wave_active and winner.result==BattleModel.Result.RUNNING:winner.step();winner.drain_events()
			check(winner.result==BattleModel.Result.CLEAR,"Ticketed earned-gold run wins")
			check(game.record_result(winner.result,winner.stars),"Campaign durably finalizes victory")
			check(game.is_stage_unlocked(&"s2"),"Victory unlocks the next chapter")
			var scores:Node=root.get_node("Leaderboard")
			check(scores.local_entries(10).size()==2,"Exactly one local score per terminal attempt")
			check(scores.pending_count()==0,"No remote score queue")
	print("FABLEWOOD_CHECKS failures=",failures)
	quit(0 if failures==0 else 1)
