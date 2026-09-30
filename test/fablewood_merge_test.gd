extends SceneTree
const M:=preload("res://sim/fablewood_battle.gd")
const Context:=preload("res://sim/campaign_runtime_context.gd")
var checks:=0
class FlowWorld extends Control:
	var selected := -1
	var selected_element := ""
	var merge_first := -1
	var merge_active := false
	var merge_pending_key := ""
	var merge_eligible: Array[int] = []
class FlowHost extends Control:
	var model: FablewoodBattle
	var world := FlowWorld.new()
	var paused := false
	var _ended := false
	var _tutorial_active := false
	var chosen: StringName = &""
	var selected_id := -1
	func _init(battle: FablewoodBattle) -> void:
		model = battle
		add_child(world)
	func _refresh_inspector() -> void: pass
	func _refresh_hud() -> void: pass
	func _present_events() -> void: pass
	func trf(key: String) -> String: return key
func _init()->void:call_deferred("run")
func check(value:bool)->void:
	assert(value);checks+=1
func make()->FablewoodBattle:
	var stage:StageDef=load("res://data/stages/s1.tres")
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var launch:={"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids}
	return M.create_fablewood(stage,launch,42)
func pads(m:FablewoodBattle)->Array[Vector2i]:
	var out:Array[Vector2i]=[]
	for y:int in m.stage.grid_size().y:
		for x:int in m.stage.grid_size().x:
			var c:=Vector2i(x,y)
			if m.stage.is_elevated_platform(c):out.append(c)
	return out
func add(m:FablewoodBattle,id:StringName,cell:Vector2i)->UnitState:
	m.dp=9999;check(m.apply_action([&"deploy",id,cell,0]));var u:=m.units[-1]
	check(m.apply_action([&"upgrade",u.id]));check(m.apply_action([&"upgrade",u.id]));return u
func check_production_cancel() -> void:
	var battle := make()
	var cells := pads(battle)
	var a := add(battle, &"caster_1", cells[0])
	var b := add(battle, &"sniper_1", cells[1])
	a.atk_counter = 7
	b.atk_counter = 11
	var before := battle.state_hash()
	var host := FlowHost.new(battle)
	# Load after autoload startup; --main-pack resolves the actual shipped
	# production helper, while this external fixture stays outside the PCK.
	var flow: RefCounted = load("res://scripts/fablewood/merge_flow.gd").new(host)
	flow.start()
	check(flow.active)
	flow.click(a.cell)
	flow.click(b.cell)
	check(not battle.pending_merge.is_empty() and not a.alive and not b.alive)
	flow.cancel()
	check(not flow.active and battle.pending_merge.is_empty())
	check(a.alive and b.alive and battle.state_hash() == before)
	flow.start()
	flow.click(a.cell)
	flow.click(b.cell)
	# Fault injection: restoration must fail if a donor's original cell is
	# occupied. The UI must retain its recovery route instead of hiding it.
	a.alive = true
	flow.cancel()
	check(flow.active and not battle.pending_merge.is_empty())
	a.alive = false
	flow.cancel()
	check(not flow.active and battle.state_hash() == before)
	host.free()
func run()->void:
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var keys:Array[String]=[]
	for i:int in 4:
		for j:int in range(i+1,4):
			var m:=make();check(m!=null);var cells:=pads(m)
			var a:=add(m,ids[i],cells[0]);var b:=add(m,ids[j],cells[1])
			var expected_damage:=m.base_attack_damage(a)+m.base_attack_damage(b)
			var expected_range:=maxi(m.range_for(a),m.range_for(b))
			a.atk_counter=7;b.atk_counter=11
			var gold:=m.dp;var hash_before:=m.state_hash()
			check(m.merge_available());check(not m.apply_action([&"begin_merge",a.id,a.id]));check(m.state_hash()==hash_before)
			check(m.apply_action([&"begin_merge",b.id,a.id]));check(not a.alive and not b.alive and m.deployed_count()==0)
			check(m.state_hash()!=hash_before and m.dp==gold)
			check(not m.apply_action([&"place_merge",Vector2i(-10,0)]));check(not m.apply_action([&"deploy",ids[0],cells[0],0]))
			check(not m.apply_action([&"next_wave"]));check(not m.apply_action([&"upgrade",a.id]));check(not m.apply_action([&"retreat",b.id]))
			check(m.apply_action([&"cancel_merge"]));check(a.alive and b.alive and a.atk_counter==7 and b.atk_counter==11 and m.dp==gold)
			check(m.state_hash()==hash_before);check(not m.apply_action([&"cancel_merge"]))
			check(m.apply_action([&"begin_merge",a.id,b.id]));check(m.apply_action([&"place_merge",cells[0]]))
			var u:=m.units[-1];check(m.is_merged(u));keys.append(m.merge_key(u))
			check(u.id==2 and u.cell==cells[0] and m.deployed_count()==1 and not a.alive and not b.alive)
			check(m.base_attack_damage(u)==expected_damage and m.range_for(u)==expected_range and m.dp==gold)
			check(m.merged[u.id].channels[0].counter==7 and m.merged[u.id].channels[1].counter==11)
			check(m.eligible_merge_donor(u) and not m.merge_available());check(not m.apply_action([&"upgrade",u.id]));check(not m.apply_action([&"place_merge",cells[1]]))
			# Resolve both channels at a shared in-range target using normal combat events.
			m._spawn({"enemy_id":&"troll","path_idx":0});var enemy:=m.enemies[-1];enemy.hp=100000;enemy.hp_max=100000
			u.cell=Pathing.cell_of(m.path_for(0),enemy.progress_units)+Vector2i(1,0)
			for channel:Dictionary in m.merged[u.id].channels:channel.counter=0
			m.tick=1;m.drain_events();m._tick_combat();var attacks:Array[String]=[]
			for event:Dictionary in m.drain_events():
				if event.kind=="attack":attacks.append(event.element)
			check(attacks.size()==2 and attacks.has(m.element(a)) and attacks.has(m.element(b)))
			if attacks.has("fire"):check(m.burn_until[enemy.id]==91)
			if attacks.has("frost"):check(m.slow_until[enemy.id]==86)
			if attacks.has("earth"):check(enemy.stunned_until_tick==18)
			# Ground-only channels cannot acquire a flying enemy.
			enemy.alive=false;m._spawn({"enemy_id":&"dragon","path_idx":0});m.enemies[-1].hp=100000
			for channel:Dictionary in m.merged[u.id].channels:channel.counter=0
			m.drain_events();m._tick_combat();var air_count:=0
			for event:Dictionary in m.drain_events():
				if event.kind=="attack":check(event.element in ["frost","storm"]);air_count+=1
			check(air_count==int(i in [1,2])+int(j in [1,2]))
			var refund:=floori(float(u.dp_cost)*m.config.retreat_refund_percent/100.0)
			check(m.apply_action([&"retreat",u.id]));check(m.dp==mini(m.config.dp_cap,gold+refund))
	check(keys==["fire_frost","fire_storm","fire_earth","frost_storm","frost_earth","storm_earth"])
	var m:=make();var cells:=pads(m);var a:=add(m,ids[0],cells[0]);var b:=add(m,ids[0],cells[1])
	check(not m.merge_available());check(not m.apply_action([&"begin_merge",a.id,b.id]))
	check_production_cancel()
	print("MERGE_MODEL_PASS checks=",checks," recipes=",keys)
	quit()
