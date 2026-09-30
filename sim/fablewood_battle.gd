class_name FablewoodBattle
extends BattleModel
## Fablewood is an extension of the template's tactical authority, not a view-owned simulation.
const UltimateModel:=preload("res://sim/fablewood_ultimates.gd")
var ultimates:=UltimateModel.new()
const LateEnemyModel:=preload("res://sim/fablewood_late_enemies.gd")
var late_enemies:=LateEnemyModel.new()
const WeaknessModel:=preload("res://sim/fablewood_weaknesses.gd")
var weaknesses:=WeaknessModel.new()
var hard_mode:=false
# Result provenance is local metadata; it never changes combat rules or RNG.
var _run_started:=false
var _run_metadata:Dictionary={}
var _run_config_hashes:Array[String]=[]
var _run_initial_resources:Dictionary={"gold":300,"health":20}
var _sealed_result_metadata:Dictionary={}
const ELEMENTS := {&"caster_1":"fire", &"sniper_1":"frost", &"recruit":"storm", &"guard_1":"earth"}
const BASE_ATTACK_MULTIPLIER := 0.25
const ENEMY_BASE_HP_MULTIPLIER := 1.5
const REWARDS := {&"goblin":9, &"orc":18, &"troll":32, &"dragon":38, &"prismback":48, &"harrier":24, &"broodmother":38}
var chapter := 1
var wave := 0
var wave_active := false
var tiers: Dictionary = {}
var slow_until: Dictionary = {}
var burn_until: Dictionary = {}
var events: Array[Dictionary] = []
var total_upgrades := 0
var earned := 0
var difficulty := 1.0
var damage_scale := 1.0
var attack_scale := 1.0
var gold_scale := 1.0
var enemy_speed := 1.0
var tower_range := 0
var completed_waves := 0
const ELEMENT_ORDER:=["fire","frost","storm","earth"]
const ALL_ELEMENTS_KEY:="fire_frost_storm_earth"
var merged:Dictionary={}
var pending_merge:Dictionary={}
var total_merges:=0

static func create_fablewood(stage_def: StageDef, launch: Dictionary, seed_value: int) -> FablewoodBattle:
	var m := FablewoodBattle.new()
	m.stage = stage_def
	m.chapter = int(String(stage_def.id).trim_prefix("s"))
	for id: StringName in [&"caster_1", &"sniper_1", &"recruit", &"guard_1"]:
		m._op_defs[id] = load("res://data/operators/%s.tres" % id)
	for id: StringName in [&"goblin", &"orc", &"troll", &"dragon", &"prismback", &"harrier", &"broodmother"]:
		m._defs[id] = load("res://data/enemies/%s.tres" % id)
	if not BattleTicketRuntimeScript.configure(m, launch.input, stage_def, seed_value, launch.trusted_ticket_hashes):
		return null
	if not m._configure_fixed_operator_roster(launch.fixed_operator_ids):
		return null
	m.config = GameConfig.new()
	m.config.base_hp_start = 20
	m.config.dp_start = 300
	m.config.dp_cap = 9999
	m.config.dp_regen_interval_ticks = 100000000
	m.config.damage_stagger_ticks = 0
	m.base_hp = m.config.base_hp_start
	m.dp = m.config.dp_start
	m.timeline = WaveTimeline.new()
	for i: int in stage_def.paths.size():
		var cells := stage_def.path_cells(i)
		m._paths.append(cells)
		m._path_lengths.append(Pathing.length_units(cells))
	return m

func apply_action(action: Array) -> bool:
	if action.is_empty() or result != Result.RUNNING:
		return false
	_run_started=true
	if action[0]==&"begin_merge":return action.size()==3 and begin_merge(int(action[1]),int(action[2]))
	if action[0]==&"place_merge":return action.size()==2 and action[1] is Vector2i and place_merge(action[1])
	if action[0]==&"cancel_merge":return action.size()==1 and cancel_merge()
	if not pending_merge.is_empty():return false
	if action[0] == &"upgrade":
		return action.size() == 2 and upgrade(int(action[1]))
	if action[0] == &"next_wave":
		return action.size() == 1 and next_wave()
	var accepted := super.apply_action(action)
	if accepted and action[0] == &"deploy":
		var u: UnitState = units[-1]
		tiers[u.id] = 1
		u.atk = maxi(1, roundi(u.atk * damage_scale))
		u.atk_interval_ticks = maxi(6, roundi(u.atk_interval_ticks / attack_scale))
		events.append({"kind":"build", "cell":u.cell, "element":element(u)})
	if accepted and action[0]==&"retreat":ultimates.remove(int(action[1]))
	if accepted and result!=Result.RUNNING:
		ultimates.stop_effects();late_enemies.stop();weaknesses.clear()
	return accepted

func element(u: UnitState) -> String:
	return ELEMENTS.get(u.op_id, "fire")

func tier(u: UnitState) -> int:
	return int(tiers.get(u.id, 1))

func base_attack_damage(u: UnitState) -> int:
	if is_merged(u):
		var combined:=0
		for channel:Dictionary in merged[u.id].channels:combined+=int(channel.damage)
		return combined
	# A further half of the previous 0.5-rated damage, rounded upward per hit.
	return maxi(1, ceili(float(u.atk) * BASE_ATTACK_MULTIPLIER))

func _next_base_attack_damage(u: UnitState) -> int:
	return base_attack_damage(u)

func enemy_base_hp(definition: EnemyDef) -> int:
	# Reduce the preceding doubled base HP by 25%, rounding down before scaling.
	return maxi(1, floori(float(definition.hp) * ENEMY_BASE_HP_MULTIPLIER))

func range_for(u: UnitState) -> int:
	if is_merged(u):return int(merged[u.id].range)+tower_range*int(merged[u.id].get("range_weight",1))
	return (3 if element(u) == "storm" else 2) + (1 if tier(u) == 3 else 0) + tower_range

func upgrade_cost(u: UnitState) -> int:
	return roundi(u.dp_cost * (0.9 if tier(u) == 1 else 1.15))

func upgrade(unit_id: int) -> bool:
	var u := unit_by_id(unit_id)
	if not pending_merge.is_empty() or u == null or not u.alive or is_merged(u) or tier(u) >= 3 or dp < upgrade_cost(u):
		return false
	var cost := upgrade_cost(u)
	dp -= cost
	dp_spent += cost
	tiers[u.id] = tier(u) + 1
	u.atk = roundi(u.atk * 1.65)
	u.atk_interval_ticks = maxi(8, roundi(u.atk_interval_ticks * 0.86))
	total_upgrades += 1
	events.append({"kind":"upgrade", "cell":u.cell, "element":element(u)})
	return true

func configure_hard_mode(enabled:bool)->bool:
	if _run_started or result!=Result.RUNNING or tick!=0 or wave!=0 or not enemies.is_empty():return false
	hard_mode=enabled;return true

func apply_run_metadata(metadata:Dictionary)->bool:
	if result!=Result.RUNNING or not _sealed_result_metadata.is_empty():return false
	if typeof(metadata.get("tuning_ranked_eligible"))!=TYPE_BOOL:return false
	if not metadata.get("tuning_config_hash") is String:return false
	var config_hash:=String(metadata.get("tuning_config_hash",""))
	if config_hash.length()!=64 or not config_hash.is_valid_hex_number(false):return false
	var raw_reasons:Variant=metadata.get("tuning_reasons",[])
	if not raw_reasons is Array:return false
	var reasons:Array[String]=[]
	for reason:Variant in raw_reasons:
		if not reason is String or String(reason).is_empty():return false
		if not reasons.has(reason):reasons.append(reason)
	for reason:String in _run_metadata.get("tuning_reasons",[]):
		if not reasons.has(reason):reasons.append(reason)
	reasons.sort()
	var eligible:bool=bool(metadata.tuning_ranked_eligible) and bool(_run_metadata.get("tuning_ranked_eligible",true)) and reasons.is_empty()
	_run_metadata={"tuning_ranked_eligible":eligible,"tuning_config_hash":config_hash.to_lower(),"tuning_reasons":reasons}
	if not _run_started and tick==0 and wave==0:_run_initial_resources={"gold":dp,"health":base_hp}
	var actual_config:Dictionary={
		"stage_id":String(stage.id),"stage_waves":stage.waves,"stage_paths":stage.paths,
		"seed":run_seed,"hard_mode":hard_mode,"initial_resources":_run_initial_resources,
		"damage_scale":damage_scale,"attack_scale":attack_scale,"difficulty":difficulty,
		"enemy_speed":enemy_speed,"gold_scale":gold_scale,"tower_range":tower_range,
		"tuning_config_hash":config_hash.to_lower(),
	}
	var actual_hash:=JSON.stringify(actual_config).sha256_text()
	if not _run_config_hashes.has(actual_hash):_run_config_hashes.append(actual_hash)
	return true

func result_metadata()->Dictionary:
	if result==Result.RUNNING:return {}
	if not _sealed_result_metadata.is_empty():return _sealed_result_metadata.duplicate(true)
	var outcome:=terminal_outcome()
	var terminal_tick:=int(outcome.get("terminal_tick",tick))
	var tick_rate:=maxi(1,config.ticks_per_second)
	var group:="legacy"
	if not _run_metadata.is_empty():
		group=("hard" if hard_mode else "normal") if bool(_run_metadata.tuning_ranked_eligible) else "practice"
	_sealed_result_metadata={
		"run_metadata_version":1,"hard_mode":hard_mode,"terminal_tick":terminal_tick,
		"ticks_per_second":tick_rate,"duration_seconds":float(terminal_tick)/tick_rate,
		"run_config_hash":JSON.stringify(_run_config_hashes).sha256_text(),"ranking_group":group,
	}
	_sealed_result_metadata.merge(_run_metadata,true)
	return _sealed_result_metadata.duplicate(true)
func get_wave_schedule(wave_number:int)->Array[Dictionary]:
	var schedule:Array[Dictionary]=[];var late:Array[Dictionary]=[]
	for entry:Dictionary in stage.waves:
		if int(entry.tick)/30000!=wave_number-1:continue
		var row:Dictionary={"tick":int(entry.tick)%30000,"enemy_id":entry.enemy_id,"path_idx":entry.path_idx,"order":schedule.size()}
		schedule.append(row)
		if entry.enemy_id in LateEnemyModel.IDS:late.append(row)
	if hard_mode and not late.is_empty():
		var first:=2147483647
		for row:Dictionary in late:first=mini(first,int(row.tick))
		for row:Dictionary in late:row.tick=first+(int(row.tick)-first)*3/4
		for i:int in ceili(float(late.size())/3.0):
			var donor:Dictionary=late[mini(i*3,late.size()-1)]
			schedule.append({"tick":int(donor.tick)+15,"enemy_id":donor.enemy_id,"path_idx":donor.path_idx,"order":schedule.size()})
	schedule.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.tick)<int(b.tick) if a.tick!=b.tick else int(a.order)<int(b.order))
	return schedule
func next_wave() -> bool:
	if not pending_merge.is_empty() or wave_active or wave >= 8:return false
	_run_started=true
	wave+=1;wave_active=true
	var schedule:=get_wave_schedule(wave)
	for entry:Dictionary in schedule:entry.tick=int(entry.tick)+tick
	# The model already sorted ties by authored order; do not re-sort ambiguously.
	timeline=WaveTimeline.new();timeline.entries=schedule
	events.append({"kind":"wave","wave":wave})
	return true

func _spawn(entry: Dictionary) -> void:
	super._spawn(entry)
	var e: EnemyState = enemies[-1]
	var multiplier := (1.0 + (chapter - 1) * 0.23 + (wave - 1) * 0.12) * difficulty
	e.hp = ceili(enemy_base_hp(_defs[e.def_id]) * multiplier)
	if hard_mode and e.def_id in LateEnemyModel.IDS:e.hp=ceili(e.hp*1.5)
	e.hp_max = e.hp
	e.step_units = maxi(1, roundi(e.step_units * enemy_speed))
	if chapter == 3 and wave == 8 and e.def_id == &"dragon":
		e.hp = ceili(e.hp * 1.5)
		e.hp_max = e.hp

	late_enemies.register_enemy(self,e)

func _effective_step(e: EnemyState, _start_cell: Vector2i) -> int:
	if tick < int(slow_until.get(e.id, 0)):
		return maxi(1, roundi(e.step_units * 0.48))
	return e.step_units

func _advance_enemies() -> Array[Dictionary]:
	late_enemies.advance(self)
	# The inherited movement/leak/block authority remains active. Aerial slowing
	# temporarily adjusts copied speed for this tick and restores the source value.
	var changed: Dictionary = {}
	for e: EnemyState in enemies:
		if e.alive and e.aerial:
			changed[e.id] = e.step_units
			var factor:=0.48 if tick<int(slow_until.get(e.id,0)) else 1.0
			e.step_units=maxi(1,roundi(e.step_units*factor*late_enemies.speed_permille(e)/1000.0)) if e.step_units>0 else 0
	var old_hp := base_hp
	var entrants := super._advance_enemies()
	for id: int in changed:
		enemies[id].step_units = changed[id]
	if base_hp < old_hp:
		events.append({"kind":"breach", "amount":old_hp-base_hp})
	return entrants

func _tick_combat() -> void:
	for e: EnemyState in enemies:
		if not e.alive:
			continue
		if tick % 30 == 0 and tick < int(burn_until.get(e.id, 0)):
			_damage_enemy(e, 9 + chapter * 2, 1)
		elif e.def_id == &"troll" and tick % 60 == 0:
			e.hp = mini(e.hp_max, e.hp + 12)
	ultimates.advance(self)
	for u:UnitState in units:
		if not u.alive:continue
		if is_merged(u):
			for channel:Dictionary in merged[u.id].channels:
				if int(channel.counter)>0:channel.counter=int(channel.counter)-1;continue
				if _fire_channel(u,String(channel.element),int(channel.damage),3,range_for(u)):
					channel.counter=int(channel.interval)-1
		elif u.atk_counter>0:u.atk_counter-=1
		elif _fire_channel(u,element(u),_next_base_attack_damage(u),tier(u),range_for(u)):
			u.atk_counter=u.atk_interval_ticks-1

func _fire_channel(u:UnitState,kind:String,attack_damage:int,attack_tier:int,attack_range:int)->bool:
	var candidates:Array[EnemyState]=[]
	for e:EnemyState in enemies:
		if not e.alive or (e.aerial and kind in ["fire","earth"]):continue
		var c:=Pathing.cell_of(path_for(e.path_idx),e.progress_units)
		if maxi(absi(c.x-u.cell.x),absi(c.y-u.cell.y))<=attack_range:candidates.append(e)
	if candidates.is_empty():return false
	candidates.sort_custom(func(a:EnemyState,b:EnemyState)->bool:
		if kind=="storm" and a.aerial!=b.aerial:return a.aerial
		return a.progress_units>b.progress_units if a.progress_units!=b.progress_units else a.id<b.id)
	var primary:=candidates[0]
	var target_cell:=Pathing.cell_of(path_for(primary.path_idx),primary.progress_units)
	u.last_attack_tick=tick;u.last_attack_cell=target_cell
	var hits:Array[int]=[]
	match kind:
		"fire":
			for e:EnemyState in enemies:
				if not e.alive or e.aerial:continue
				var c:=Pathing.cell_of(path_for(e.path_idx),e.progress_units)
				if maxi(absi(c.x-target_cell.x),absi(c.y-target_cell.y))<=1:
					_elemental_damage(e,attack_damage,1,"fire");burn_until[e.id]=maxi(int(burn_until.get(e.id,0)),tick+90);hits.append(e.id)
		"frost":
			_elemental_damage(primary,attack_damage,1,"frost");slow_until[primary.id]=maxi(int(slow_until.get(primary.id,0)),tick+55+attack_tier*10);weaknesses.control_applied(self,primary,"frost",int(slow_until[primary.id]));hits.append(primary.id)
		"storm":
			for i:int in mini(candidates.size(),attack_tier+1):
				var e:=candidates[i]
				_elemental_damage(e,roundi(attack_damage*(1.4 if e.aerial else 1.0)),1,"storm");hits.append(e.id)
		"earth":
			_elemental_damage(primary,attack_damage+primary.defense,0,"earth");primary.stunned_until_tick=maxi(primary.stunned_until_tick,tick+8+attack_tier*3);hits.append(primary.id)
	events.append({"kind":"attack","element":kind,"unit":u.id,"cell":u.cell,"hits":hits})
	return true

func _elemental_damage(e:EnemyState,raw_damage:int,damage_kind:int,source:String)->void:
	if not e.alive:return
	var before:=e.hp
	var shield_before:=int(late_enemies.info(e.id).get("shell",0)) if damage_kind==0 else 0
	_damage_enemy(e,raw_damage,damage_kind)
	weaknesses.damage_applied(self,e,maxi(0,before-maxi(0,e.hp)),source,shield_before)
func _damage_enemy(e:EnemyState,raw_damage:int,damage_kind:int)->void:
	if not e.alive:return
	var previous:=e.hp
	var resolved:=DamageRulesScript.resolve(raw_damage,damage_kind,e.defense,e.resistance_permille)
	resolved=late_enemies.filter_damage(self,e,resolved,damage_kind)
	if EnemyDamageScript.apply(e,resolved,tick,config.damage_stagger_ticks):_kill_enemy(e)
	var applied:=maxi(0,previous-maxi(0,e.hp))
	if applied>0:
		events.append({"kind":"damage","enemy":e.id,"amount":applied,"killed":not e.alive})

func _kill_enemy(e: EnemyState) -> void:
	super._kill_enemy(e)
	var reward := roundi((4 if late_enemies.children.has(e.id) else int(REWARDS.get(e.def_id,10))) * gold_scale)
	_grant_dp(reward)
	earned += reward
	events.append({"kind":"enemy", "enemy":e.id, "gold":reward})

func is_merged(u:UnitState)->bool:
	return u!=null and merged.has(u.id)
func merge_key(u:UnitState)->String:
	return String(merged[u.id].key) if is_merged(u) else ""
func elements_for(u:UnitState)->PackedStringArray:
	if u==null:return PackedStringArray()
	if is_merged(u):return merge_key(u).split("_")
	return PackedStringArray([element(u)])
func is_all_element(u:UnitState)->bool:
	return is_merged(u) and merge_key(u)==ALL_ELEMENTS_KEY
func eligible_merge_donor(u:UnitState)->bool:
	if u==null or not u.alive:return false
	if is_merged(u):return elements_for(u).size()==2
	return tier(u)==3 and ELEMENTS.has(u.op_id)
func can_merge(a:UnitState,b:UnitState)->bool:
	if result!=Result.RUNNING or not pending_merge.is_empty() or not eligible_merge_donor(a) or not eligible_merge_donor(b) or a.id==b.id:return false
	var first:=elements_for(a);var second:=elements_for(b)
	if first.size()!=second.size():return false
	for part:String in first:
		if part in second:return false
	return true
func merge_available()->bool:
	if result!=Result.RUNNING or not pending_merge.is_empty():return false
	for i:int in units.size():
		if not eligible_merge_donor(units[i]):continue
		for j:int in range(i+1,units.size()):
			if can_merge(units[i],units[j]):return true
	return false
func begin_merge(first_id:int,second_id:int)->bool:
	var a:=unit_by_id(first_id);var b:=unit_by_id(second_id)
	if not can_merge(a,b):return false
	if ELEMENT_ORDER.find(elements_for(a)[0])>ELEMENT_ORDER.find(elements_for(b)[0]):
		var swap:=a;a=b;b=swap
	var channels:Array[Dictionary]=[]
	for donor:UnitState in [a,b]:
		if is_merged(donor):
			for channel:Dictionary in merged[donor.id].channels:channels.append(channel.duplicate(true))
		else:channels.append({"element":element(donor),"damage":base_attack_damage(donor),"interval":donor.atk_interval_ticks,"counter":donor.atk_counter})
	channels.sort_custom(func(x:Dictionary,y:Dictionary)->bool:return ELEMENT_ORDER.find(x.element)<ELEMENT_ORDER.find(y.element))
	var parts:PackedStringArray=[]
	for channel:Dictionary in channels:parts.append(channel.element)
	var weight:=2 if channels.size()==4 else 1
	var inherited_range:=range_for(a)+range_for(b) if weight==2 else maxi(range_for(a),range_for(b))
	pending_merge={"donors":[a.id,b.id],"key":"_".join(parts),"channels":channels,"range":inherited_range-tower_range*weight,"range_weight":weight}
	for donor:UnitState in [a,b]:
		ultimates.suspend(donor.id,tick)
		donor.alive=false;_release_all_blocked(donor)
	events.append({"kind":"merge_prepare","cell":a.cell,"element":elements_for(a)[0],"second_cell":b.cell,"second_element":elements_for(b)[0],"elements":parts})
	return true
func can_place_merge(cell:Vector2i)->bool:
	return result==Result.RUNNING and not pending_merge.is_empty() and stage.is_elevated_platform(cell) and alive_unit_at(cell)==null
func place_merge(cell:Vector2i)->bool:
	if not can_place_merge(cell):return false
	var a:=unit_by_id(int(pending_merge.donors[0]));var b:=unit_by_id(int(pending_merge.donors[1]))
	if a==null or b==null or a.alive or b.alive:return false
	var u:=UnitState.new();u.id=_next_unit_id;_next_unit_id+=1
	# Retain template-compatible identity fields; merge data owns all inherited channels.
	BattleTicketRuntimeScript.copy_legacy_unit(_op_defs[a.op_id],u)
	u.cell=cell;u.facing=UnitState.DEFAULT_FACING;u.dp_cost=a.dp_cost+b.dp_cost
	u.atk=a.atk+b.atk;u.atk_interval_ticks=mini(a.atk_interval_ticks,b.atk_interval_ticks)
	u.hp=a.hp+b.hp;u.hp_max=a.hp_max+b.hp_max
	units.append(u);tiers[u.id]=3;merged[u.id]=pending_merge.duplicate(true);pending_merge={};total_merges+=1
	ultimates.remove(a.id);ultimates.remove(b.id)
	ultimates.register(u.id,merge_key(u))
	events.append({"kind":"merge_placed","unit":u.id,"cell":cell,"element":element(a),"second_element":element(b),"elements":elements_for(u),"key":merge_key(u)})
	return true
func cancel_merge()->bool:
	if pending_merge.is_empty():return false
	for id:int in pending_merge.donors:
		var donor:=unit_by_id(id)
		if donor==null or alive_unit_at(donor.cell)!=null:return false
	for id:int in pending_merge.donors:
		unit_by_id(id).alive=true;ultimates.resume(id,tick)
	pending_merge={}
	return true
func is_deployable(op_id:StringName)->bool:
	return pending_merge.is_empty() and super.is_deployable(op_id)

func _check_terminal() -> void:
	late_enemies.cleanup(self);weaknesses.cleanup(self)
	if base_hp<=0 and not pending_merge.is_empty():cancel_merge()
	if base_hp <= 0:
		ultimates.stop_effects();late_enemies.stop();weaknesses.clear()
		result = Result.DEFEAT
		stars = 0
		terminal_reason = &"base_defeat"
		return
	if wave_active and timeline.exhausted() and alive_count() == 0:
		wave_active = false
		ultimates.stop_effects()
		completed_waves += 1
		_grant_dp(35 + chapter * 5)
		base_hp = mini(20, base_hp + 1)
		events.append({"kind":"cleared", "wave":wave})
		if wave == 8:
			if not pending_merge.is_empty():cancel_merge()
			result = Result.CLEAR
			stars = 3 if leaked == 0 else 2 if base_hp >= 12 else 1
			terminal_reason = &"clear"

func state_hash() -> int:
	var extra := str([BASE_ATTACK_MULTIPLIER, ENEMY_BASE_HP_MULTIPLIER, wave, wave_active, tiers, slow_until, burn_until, total_upgrades, earned, difficulty, damage_scale, attack_scale, gold_scale, enemy_speed, tower_range,merged,pending_merge,total_merges,ultimates.states,ultimates.last_tick,late_enemies.states,late_enemies.children,late_enemies.last_tick,hard_mode,weaknesses.signature()])
	return super.state_hash() ^ extra.hash()

func drain_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out
