extends "fablewood_merge_test.gd"
const PAIRS:=[[&"caster_1",&"sniper_1"],[&"caster_1",&"recruit"],[&"caster_1",&"guard_1"],[&"sniper_1",&"recruit"],[&"sniper_1",&"guard_1"],[&"recruit",&"guard_1"]]
func setup(index:int,ground_count:int=8,air_count:int=2)->FablewoodBattle:
	var m:=make();var cells:=pads(m)
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.distance_squared_to(Vector2i(4,3))<b.distance_squared_to(Vector2i(4,3)))
	var a:=add(m,PAIRS[index][0],cells[0]);var b:=add(m,PAIRS[index][1],cells[1])
	check(m.apply_action([&"begin_merge",a.id,b.id]));check(m.apply_action([&"place_merge",a.cell]))
	var u:UnitState=m.units[-1]
	check(m.apply_action([&"next_wave"]));m.timeline=WaveTimeline.new()
	for channel:Dictionary in m.merged[u.id].channels:channel.counter=1000000
	var at:=near_progress(m,u)
	for i:int in ground_count+air_count:
		m._spawn({"enemy_id":&"goblin" if i<ground_count else &"dragon","path_idx":0})
		var e:EnemyState=m.enemies[-1];e.progress_units=at;e.hp=100000;e.hp_max=100000;e.step_units=0
	m.drain_events();return m
func near_progress(m:FablewoodBattle,u:UnitState)->int:
	var path:=m.path_for(0);var best:=0;var distance:=999
	for i:int in path.size():
		var d:=maxi(absi(path[i].x-u.cell.x),absi(path[i].y-u.cell.y))
		if d<distance:best=i;distance=d
	return best*Pathing.PROGRESS_SCALE
func ult_events(m:FablewoodBattle)->Array[Dictionary]:
	var out:Array[Dictionary]=[]
	for event:Dictionary in m.drain_events():
		if event.kind=="ultimate":out.append(event)
	return out
func ready(m:FablewoodBattle)->void:m.ultimates.states[m.units[-1].id].remaining=1
func run()->void:
	for index:int in 6:
		var m:=setup(index);var u:UnitState=m.units[-1];var key:=m.merge_key(u)
		var initial:Dictionary=m.merged[u.id].duplicate(true);var base:=m.base_attack_damage(u);var radius:=m.range_for(u)
		var period:int=m.ultimates.info(u.id).period
		m.step(period-1);check(ult_events(m).is_empty());check(m.ultimates.info(u.id).remaining==1)
		var hp_before:int=m.enemies[0].hp
		var hp_all:Array[int]=[]
		for foe:EnemyState in m.enemies:hp_all.append(foe.hp)
		m.step();var events:=ult_events(m)
		check(events.size()==1);check(events[0].key==key);check(m.ultimates.info(u.id).remaining==period)
		check(m.ultimates.info(u.id).casts==1);check(m.base_attack_damage(u)==base and m.range_for(u)==radius)
		for i:int in 2:
			check(m.merged[u.id].channels[i].damage==initial.channels[i].damage)
			check(m.merged[u.id].channels[i].interval==initial.channels[i].interval)
		var hits:Array=events[0].hits;check(hits.size()==[8,6,8,4,8,6][index])
		var e:EnemyState=m.enemies[hits[0]];var cast_tick:int=events[0].tick
		for id:int in hits:
			var foe:EnemyState=m.enemies[id]
			var raw:int=base*[2,3,3,1,0,2][index]
			if index==4:raw=ceili(float(base)/2.0)
			if index==5 and foe.aerial:raw=base*3
			var physical:bool=index==2 or (index==5 and not foe.aerial)
			var expected:=raw if physical else maxi(floori(float(raw)*(1000-foe.resistance_permille)/1000.0),ceili(float(raw)/20.0))
			check(hp_all[id]-foe.hp==expected)
		match index:
			0:check(e.stunned_until_tick==cast_tick+30);check(m.burn_until[e.id]==cast_tick+90)
			1:check(e.aerial);check(m.burn_until[0]==cast_tick+120)
			2:check(not e.aerial);check(hp_before-m.enemies[0].hp==base*3);check(e.stunned_until_tick==cast_tick+45)
			3:check(e.aerial);check(m.slow_until[e.id]==cast_tick+60)
			4:check(m.slow_until[e.id]==cast_tick+60);check(not m.ultimates.states[u.id].active.is_empty())
			5:check(not e.aerial);check(e.stunned_until_tick==cast_tick+60);check(m.slow_until[m.enemies[-1].id]==cast_tick+60)
		# Duplicate tick delivery cannot charge twice or fire twice.
		m.ultimates.advance(m);var duplicate:=m.state_hash();m.ultimates.advance(m);check(m.state_hash()==duplicate)
		# Use a new deterministic fixture for exact repeated cadence.
		var repeat:=setup(index);var ru:UnitState=repeat.units[-1]
		repeat.step(period*2);var repeated:=ult_events(repeat);var casts:Array[int]=[]
		for event:Dictionary in repeated:
			if event.pulse==0:casts.append(event.tick)
		check(casts==[period-1,period*2-1]);check(repeat.ultimates.info(ru.id).casts==2)
		# Air-only legality: every guardian except Magmafault can acquire air.
		var air:=setup(index,0,3);ready(air);air.step();var aerial:=ult_events(air)
		check(aerial.is_empty() if index==2 else aerial.size()==1)
		if index==2:check(air.ultimates.info(air.units[-1].id).remaining==0)
		# Cooldown pauses in preparation and empty gaps; ready waits out of range.
		var wait:=setup(index,1,0);var wu:UnitState=wait.units[-1];wait.wave_active=false
		var left:int=wait.ultimates.info(wu.id).remaining;wait.step(10);check(wait.ultimates.info(wu.id).remaining==left)
		wait.wave_active=true;wait.enemies[0].alive=false;wait.tick+=1;wait.ultimates.advance(wait);check(wait.ultimates.info(wu.id).remaining==left)
		wait.enemies[0].alive=true;wait.enemies[0].progress_units=Pathing.length_units(wait.path_for(0))-1
		wu.cell=Vector2i(-50,-50);ready(wait);wait.tick+=1;wait.ultimates.advance(wait);check(ult_events(wait).is_empty());check(wait.ultimates.info(wu.id).remaining==0)
		wu.cell=u.cell;wait.enemies[0].progress_units=near_progress(wait,wu);wait.tick+=1;wait.ultimates.advance(wait);check(ult_events(wait).size()==1)
		# Selling deletes cooldown and pending pulses immediately.
		check(m.apply_action([&"retreat",u.id]));check(not m.ultimates.states.has(u.id))
		var terminal:=setup(index);ready(terminal);terminal.step();check(terminal.apply_action([&"resign"]))
		check(terminal.ultimates.states[terminal.units[-1].id].active.is_empty());var hash_after:=terminal.state_hash();terminal.step(100);check(terminal.state_hash()==hash_after)
		# Identical inputs/state produce identical hashes including pending pulses.
		var one:=setup(index);var two:=setup(index)
		one.step(period+35);two.step(period+35);check(one.state_hash()==two.state_hash())
		var saved_hash:=one.state_hash();one.ultimates.states[one.units[-1].id].remaining-=1;check(one.state_hash()!=saved_hash)
	_test_pulses();_test_status_and_rewards();_test_chain()
	print("ULTIMATE_MODEL_PASS checks=",checks," six recipes; thresholds; legality; pulses; status; cleanup; replay")
	quit()
func _test_pulses()->void:
	for index:int in [3,4]:
		var m:=setup(index,1,0);ready(m);m.step();var first:=ult_events(m);check(first.size()==1)
		var interval:=15 if index==3 else 30
		m.step(interval-1);check(ult_events(m).is_empty())
		# Reacquire a newly spawned target instead of striking the dead enemy.
		m.enemies[0].alive=false;m._spawn({"enemy_id":&"dragon","path_idx":0})
		m.enemies[-1].progress_units=m.enemies[0].progress_units;m.enemies[-1].step_units=0;m.enemies[-1].hp=100000
		m.step();var second:=ult_events(m);check(second.size()==1 and second[0].pulse==1);check(second[0].hits==[1])
		m.step(160);var rest:=ult_events(m);check(rest.size()==(1 if index==3 else 3));check(m.ultimates.states[m.units[-1].id].active.is_empty())
		var clear:=setup(index,1,0);ready(clear);clear.step();clear.enemies[0].alive=false;clear.step();check(not clear.wave_active);check(clear.ultimates.states[clear.units[-1].id].active.is_empty())
func _test_status_and_rewards()->void:
	var m:=setup(5,1,0);var u:UnitState=m.units[-1];var e:EnemyState=m.enemies[0]
	ready(m);m.step();var expiry:=e.stunned_until_tick
	check(m._fire_channel(u,"earth",1,3,m.range_for(u)));check(e.stunned_until_tick==expiry)
	m.burn_until[e.id]=m.tick+500;m.slow_until[e.id]=m.tick+500
	check(m._fire_channel(u,"fire",1,3,m.range_for(u)));check(m.burn_until[e.id]==m.tick+500)
	check(m._fire_channel(u,"frost",1,3,m.range_for(u)));check(m.slow_until[e.id]==m.tick+500)
	var kill:=setup(0,1,0);kill.enemies[0].hp=1;ready(kill);var earned:=kill.earned;kill.step()
	check(kill.killed==1);check(kill.earned-earned==9);var earned_after:=kill.earned;kill._damage_enemy(kill.enemies[0],999,1);check(kill.earned==earned_after)
func _test_chain()->void:
	var m:=setup(1,8,0);var u:UnitState=m.units[-1]
	# All hits are distinct and every chain edge obeys the hop bound.
	ready(m);m.step();var event:=ult_events(m)[0];var visited:Dictionary={}
	for id:int in event.hits:
		check(not visited.has(id));visited[id]=true
		var cell:=Pathing.cell_of(m.path_for(0),m.enemies[id].progress_units)
		check(maxi(absi(cell.x-u.cell.x),absi(cell.y-u.cell.y))<=m.range_for(u))
	check(event.hits.size()==6)

	var gap:=setup(1,2,0);var gu:UnitState=gap.units[-1]
	gap.enemies[0].progress_units=0;gap.enemies[1].progress_units=20*Pathing.PROGRESS_SCALE
	ready(gap);gap.step();var disconnected:=ult_events(gap)[0]
	check(disconnected.hits==[1])
	check(gap.enemies[0].hp==100000)
