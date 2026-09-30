extends SceneTree
## One authored Chapter 3 clear using ordinary deployment, upgrade and merge actions.
## No resource grants, enemy omissions, stat changes or forced terminal state.
const Model = preload("res://sim/fablewood_battle.gd")
const ORDER := [&"recruit", &"caster_1", &"guard_1", &"sniper_1"]
func _initialize() -> void:
	call_deferred("run")
func pads(m: FablewoodBattle) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in 8:
		for x: int in 10:
			if m.stage.is_elevated_platform(Vector2i(x, y)):
				result.append(Vector2i(x, y))
	return result
func place_order(m:FablewoodBattle,center:Vector2i)->Array[Vector2i]:
	var slots:=pads(m);slots.sort_custom(func(a:Vector2i,b:Vector2i)->bool:
		return a.distance_squared_to(center)<b.distance_squared_to(center) if a.distance_squared_to(center)!=b.distance_squared_to(center) else a.x*100+a.y<b.x*100+b.y)
	return slots
func improve(m:FablewoodBattle)->void:
	var slots:=place_order(m,Vector2i(4,3));var order:Array=ORDER
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
func run() -> void:
	var ids: Array[StringName] = [&"caster_1", &"sniper_1", &"recruit", &"guard_1"]
	var m := Model.create_fablewood(load("res://data/stages/s3.tres"), {"input": ids, "trusted_ticket_hashes": [], "fixed_operator_ids": ids}, 42)
	assert(m != null and m.dp == 300 and m.base_hp == 20)
	var worldheart_wave := 0
	for _wave: int in 8:
		if m.result != BattleModel.Result.RUNNING: break
		improve(m)
		assert(m.apply_action([&"next_wave"]))
		var elapsed := 0
		while m.wave_active and m.result == BattleModel.Result.RUNNING and elapsed < 15000:
			if m.tick % 30 == 0: improve(m)
			for unit: UnitState in m.units:
				if unit.alive and m.is_all_element(unit) and worldheart_wave == 0:
					worldheart_wave = m.wave
			m.step()
			m.drain_events()
			elapsed += 1
	assert(m.result == BattleModel.Result.CLEAR and m.wave == 8 and m.base_hp == 12)
	assert(m.earned == 2490 and m.dp_spent == 3079 and m.dp == 111 and worldheart_wave == 5)
	assert(m.dp == 300 + m.earned + 400 - m.dp_spent, "Only initial, kill and authored wave-clear gold funded the clear")
	print("FABLEWOOD_CHAPTER3_EARNED_GOLD_PASS hp=", m.base_hp, " kills_gold=", m.earned, " spent=", m.dp_spent, " remaining=", m.dp, " worldheart_wave=", worldheart_wave)
	quit()
