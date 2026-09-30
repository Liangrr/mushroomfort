extends "fablewood_ultimate_test.gd"
const COMPLEMENTS:=[[0,5],[1,4],[2,3]]
func dual(m:FablewoodBattle,index:int,slot:int)->UnitState:
	var cells:=pads(m);var free:Array[Vector2i]=[]
	for c:Vector2i in cells:
		if m.alive_unit_at(c)==null:free.append(c)
	var a:=add(m,PAIRS[index][0],free[0]);var b:=add(m,PAIRS[index][1],free[1])
	check(m.apply_action([&"begin_merge",a.id,b.id]));check(m.apply_action([&"place_merge",cells[slot]]));return m.units[-1]
func worldheart(recipe:int=0,ground_count:int=1,air_count:int=1)->FablewoodBattle:
	var m:=make();var pair:Array=COMPLEMENTS[recipe];var a:=dual(m,pair[0],0);var b:=dual(m,pair[1],1)
	check(m.apply_action([&"begin_merge",a.id,b.id]));check(m.apply_action([&"place_merge",a.cell]))
	var u:UnitState=m.units[-1];check(m.apply_action([&"next_wave"]));m.timeline=WaveTimeline.new()
	for channel:Dictionary in m.merged[u.id].channels:channel.counter=1000000
	for i:int in ground_count+air_count:
		m._spawn({"enemy_id":&"goblin" if i<ground_count else &"dragon","path_idx":0})
		var e:EnemyState=m.enemies[-1];e.progress_units=near_progress(m,u);e.hp=100000;e.hp_max=100000;e.step_units=0
	m.drain_events();return m
func event_kind(m:FablewoodBattle,kind:String)->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for event:Dictionary in m.drain_events():
		if event.kind==kind:out.append(event)
	return out
func expected_hit(m:FablewoodBattle,u:UnitState,e:EnemyState)->int:
	var total:=0
	for channel:Dictionary in m.merged[u.id].channels:
		var raw:int=channel.damage*5
		total+=raw if channel.element=="earth" else maxi(floori(float(raw)*(1000-e.resistance_permille)/1000.0),ceili(float(raw)/20.0))
	return total
func run()->void:
	for pair:Array in COMPLEMENTS:
		for reversed:bool in [false,true]:
			var m:=make();var a:=dual(m,pair[0],0);var b:=dual(m,pair[1],1)
			check(m.can_merge(a,b) and m.merge_available())
			check(not m.can_merge(a,a))
			m.tower_range=2
			var range_sum:=m.range_for(a)+m.range_for(b);var power:=m.base_attack_damage(a)+m.base_attack_damage(b)
			m.merged[a.id].channels[0].counter=7;m.merged[b.id].channels[0].counter=11
			var channels:Array=m.merged[a.id].channels.duplicate(true)+m.merged[b.id].channels.duplicate(true)
			m.ultimates.states[a.id].remaining=123;m.ultimates.states[b.id].remaining=234
			var old_hash:=m.state_hash();var old_gold:=m.dp
			check(m.apply_action([&"begin_merge",b.id if reversed else a.id,a.id if reversed else b.id]))
			check(not a.alive and not b.alive and m.pending_merge.channels.size()==4)
			check(not m.apply_action([&"place_merge",Vector2i(-1,-1)]))
			check(m.apply_action([&"cancel_merge"]));check(m.state_hash()==old_hash and m.dp==old_gold)
			check(m.ultimates.states[a.id].remaining==123 and m.ultimates.states[b.id].remaining==234)
			check(m.apply_action([&"begin_merge",a.id,b.id]));check(m.apply_action([&"place_merge",a.cell]))
			var u:UnitState=m.units[-1]
			check(m.is_all_element(u) and m.elements_for(u)==PackedStringArray(["fire","frost","storm","earth"]))
			check(m.range_for(u)==range_sum and m.base_attack_damage(u)==power)
			check(not m.ultimates.states.has(a.id) and not m.ultimates.states.has(b.id))
			check(m.ultimates.info(u.id).remaining==600 and m.dp==old_gold and m.deployed_count()==1)
			for original:Dictionary in channels:
				for current:Dictionary in m.merged[u.id].channels:
					if current.element==original.element:check(current==original)
			m.tower_range=3;check(m.range_for(u)==range_sum+2)
			check(not m.eligible_merge_donor(u) and not m.apply_action([&"upgrade",u.id]))
			check(m.apply_action([&"retreat",u.id]) and not m.ultimates.states.has(u.id))
	# Every overlapping recipe is rejected, not just duplicate identities.
	for a_index:int in 6:
		for b_index:int in range(a_index,6):
			var m:=make();var a:=dual(m,a_index,0);var b:=dual(m,b_index,1)
			var common:=false
			for part:String in m.elements_for(a):common=common or part in m.elements_for(b)
			check(m.can_merge(a,b)==not common)
			if common:
				var before:=m.state_hash();check(not m.apply_action([&"begin_merge",a.id,b.id]));check(m.state_hash()==before)
	var mixed:=make();var mixed_dual:=dual(mixed,0,0);var basic:=add(mixed,&"guard_1",pads(mixed)[1]);check(not mixed.can_merge(mixed_dual,basic))
	# Suspended donors retain charges and delayed-pulse clocks even if API ticks continue.
	var held:=make();var da:=dual(held,2,0);var db:=dual(held,3,1)
	held.wave_active=true;held._spawn({"enemy_id":&"troll","path_idx":0});held.enemies[-1].hp=100000
	held.ultimates.states[db.id].active={"next_tick":10,"end_tick":31,"pulse":1,"center":Vector2i(1,1),"power":10}
	check(held.apply_action([&"begin_merge",da.id,db.id]));var saved:int=held.ultimates.states[db.id].remaining
	for tick:int in range(1,6):held.tick=tick;held.ultimates.advance(held)
	check(held.ultimates.states[db.id].remaining==saved)
	check(held.apply_action([&"cancel_merge"]));check(held.ultimates.states[db.id].active.next_tick==15 and held.ultimates.states[db.id].active.end_tick==36)
	# Natural threshold, fixed travel time, mitigation and statuses against ground/air.
	var m:=worldheart();var u:UnitState=m.units[-1]
	m.step(599);check(event_kind(m,"meteor_launch").is_empty());check(m.ultimates.info(u.id).remaining==1)
	m.step();var launch:=event_kind(m,"meteor_launch");check(launch.size()==1 and m.ultimates.info(u.id).casts==1)
	check(m.enemies[0].hp==100000 and m.enemies[1].hp==100000)
	var center:Vector2i=launch[0].center
	m.step(29);check(event_kind(m,"meteor_impact").is_empty() and m.enemies[0].hp==100000)
	m.step();var impact:=event_kind(m,"meteor_impact");check(impact.size()==1 and impact[0].center==center)
	for e:EnemyState in m.enemies:
		check(100000-e.hp==expected_hit(m,u,e));check(e.stunned_until_tick==int(impact[0].tick)+30 and m.slow_until[e.id]==int(impact[0].tick)+90)
		check(not m.burn_until.has(e.id) if e.aerial else m.burn_until[e.id]==int(impact[0].tick)+120)
	check(m.ultimates.states[u.id].active.is_empty())
	var state:Dictionary=m.ultimates.states.duplicate(true);var after_tick:=m.tick;m.tick=m.ultimates.last_tick;m.ultimates.advance(m);m.tick=after_tick;check(m.ultimates.states==state and event_kind(m,"meteor_impact").is_empty())
	# Direct and aftershock caps are distinct, IDs never overlap, and untouched foes stay untouched.
	m=worldheart(1,20,0);u=m.units[-1];m.ultimates.states[u.id].remaining=1;m.step();m.drain_events();m.step(30);impact=event_kind(m,"meteor_impact")
	check(impact.size()==1 and impact[0].hits.size()==12 and impact[0].chains.size()==3)
	for id:int in impact[0].chains:check(not id in impact[0].hits and not m.burn_until.has(id) and m.enemies[id].stunned_until_tick<=m.tick)
	for e:EnemyState in m.enemies:
		if not e.id in impact[0].hits and not e.id in impact[0].chains:check(e.hp==100000)
	# Locked point does not chase a target; owner removal cancels pending damage.
	m=worldheart();u=m.units[-1];m.ultimates.states[u.id].remaining=1;m.step();launch=event_kind(m,"meteor_launch");center=launch[0].center
	for e:EnemyState in m.enemies:e.progress_units=(m.path_for(0).size()-1)*Pathing.PROGRESS_SCALE
	for i:int in 30:m.tick+=1;m.ultimates.advance(m)
	impact=event_kind(m,"meteor_impact");check(impact.size()==1 and impact[0].center==center and impact[0].hits.is_empty())
	m=worldheart();u=m.units[-1];m.ultimates.states[u.id].remaining=1;m.step();m.drain_events();check(m.apply_action([&"retreat",u.id]));m.step(40);check(event_kind(m,"meteor_impact").is_empty())
	# Ready holds without valid targets; inactive waves do not recharge; terminal cancels flights.
	m=worldheart();u=m.units[-1];u.cell=Vector2i(100,100);m.ultimates.states[u.id].remaining=1;m.step(20);check(m.ultimates.info(u.id).remaining==0 and m.ultimates.info(u.id).casts==0)
	m.wave_active=false;var remain:int=m.ultimates.info(u.id).remaining;m.step(20);check(m.ultimates.info(u.id).remaining==remain)
	m=worldheart();u=m.units[-1];m.ultimates.states[u.id].remaining=1;m.step();m.wave_active=false;m.step();check(m.ultimates.states[u.id].active.is_empty())
	m=worldheart();u=m.units[-1];m.ultimates.states[u.id].remaining=1;m.step();m.base_hp=0;m._check_terminal();check(m.ultimates.states[u.id].active.is_empty())
	# All four inherited attacks really fire beyond either ordinary donor's range.
	m=worldheart();u=m.units[-1]
	u.cell=Pathing.cell_of(m.path_for(0),m.enemies[0].progress_units)+Vector2i(5,0)
	for channel:Dictionary in m.merged[u.id].channels:channel.counter=0
	m.tick=1;m._tick_combat();var attacks:Array[String]=[]
	for event:Dictionary in m.drain_events():
		if event.kind=="attack":attacks.append(event.element)
	check(attacks==["fire","frost","storm","earth"])
	m.enemies[0].alive=false
	for channel:Dictionary in m.merged[u.id].channels:channel.counter=0
	m._tick_combat();attacks=[]
	for event:Dictionary in m.drain_events():
		if event.kind=="attack":attacks.append(event.element)
	check(attacks==["frost","storm"])
	# Four components cannot award the same death more than once.
	m=worldheart(0,1,0);u=m.units[-1];m.enemies[0].hp=1;m.ultimates.states[u.id].remaining=1;m.step();m.drain_events();m.step(30)
	check(not m.enemies[0].alive and m.earned==9)
	var kills:=0
	for event:Dictionary in m.drain_events():
		if event.kind=="enemy":kills+=1
	check(kills==1);m.step(40);check(m.earned==9)
	# Fresh identical campaigns remain bit-for-bit deterministic through launches/impacts.
	var one:=worldheart(2,4,2);var two:=worldheart(2,4,2)
	for i:int in 1350:
		one.step();two.step();check(one.state_hash()==two.state_hash());check(one.drain_events()==two.drain_events())
	print("WORLDHEART_MODEL_PASS checks=",checks," complementary recipes; additive range; rollback; four channels; timed meteor; mitigation; caps; cleanup; deterministic replay")
	quit()
