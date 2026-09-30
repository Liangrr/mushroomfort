extends SceneTree
const M:=preload("res://sim/fablewood_battle.gd")
const A:=preload("res://scripts/fablewood/guardian_animation.gd")
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func make()->FablewoodBattle:
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	return M.create_fablewood(load("res://data/stages/s1.tres"),{"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids},42)
func run()->void:
	var previous:Dictionary={&"caster_1":12.5,&"sniper_1":5.0,&"recruit":9.0,&"guard_1":30.0}
	for id:StringName in previous:
		var m:=make();m.dp=9999
		check(m.apply_action([&"deploy",id,Vector2i(4,3),0]),"Legal deployment")
		var u:UnitState=m.units[0]
		var expected:=ceili(float(previous[id])*0.5)
		check(m.base_attack_damage(u)==expected,"Ceil of half previous base: "+String(id))
		m.wave=1;m._spawn({"enemy_id":&"goblin","path_idx":0})
		var enemy:EnemyState=m.enemies[0]
		enemy.hp=1000;enemy.hp_max=1000;enemy.defense=0;enemy.resistance_permille=0
		for index:int in m.path_for(0).size():
			var cell:Vector2i=m.path_for(0)[index]
			if maxi(absi(cell.x-u.cell.x),absi(cell.y-u.cell.y))<=m.range_for(u):enemy.progress_units=index*Pathing.PROGRESS_SCALE;break
		m.tick=1;u.atk_counter=0;m._tick_combat();var first:=1000-enemy.hp
		u.atk_counter=0;m._tick_combat()
		check(first==expected and 1000-enemy.hp==expected*2,"Every actual hit rounds up: "+String(id))
		for level:int in range(1,4):
			var expected_tier:=ceili(float(u.atk)*0.25)
			for attack:int in 20:check(m._next_base_attack_damage(u)==expected_tier,"No fractional carry at tier "+str(level))
			if level<3:
				var cost:=m.upgrade_cost(u);var rating:=u.atk
				check(m.apply_action([&"upgrade",u.id]),"Upgrade remains legal")
				check(u.atk==roundi(rating*1.65),"Unchanged upgrade progression")
				check(cost==roundi(u.dp_cost*(0.9 if level==1 else 1.15)),"Unchanged upgrade cost")
	var hp:Dictionary={&"goblin":105,&"orc":300,&"troll":780,&"dragon":570}
	for chapter:int in range(1,4):
		for wave:int in range(1,9):
			var m:=make();m.chapter=chapter;m.wave=wave
			for id:StringName in hp:
				check(m.enemy_base_hp(m._defs[id])==hp[id],"75% of previous enemy base HP, rounded down")
				m._spawn({"enemy_id":id,"path_idx":0})
				var expected:=ceili(hp[id]*(1.0+(chapter-1)*0.23+(wave-1)*0.12))
				if chapter==3 and wave==8 and id==&"dragon":expected=ceili(expected*1.5)
				check(m.enemies[-1].hp==expected and m.enemies[-1].hp_max==expected,"Spawn HP and max HP use upward rounding")
	var fractional:=EnemyDef.new();fractional.hp=71
	check(make().enemy_base_hp(fractional)==106,"Fractional 142 * 0.75 rounds down to 106, not 107")
	var world=load("res://scripts/fablewood/world.gd").new();world.model=make();world._origin=Vector2(51,73)
	for scale_value:float in [0.7,1.0,1.85]:
		world._scale=scale_value
		for cell:Vector2i in world.model.path_for(0):
			var contact:Vector2=world.route_center(Vector2(cell))
			check(contact.is_equal_approx(world.cell_center(cell)),"Enemy contact is tile center")
			for flip:bool in [false,true]:
				check((world.enemy_sprite_transform(contact,flip)*Vector2.ZERO).is_equal_approx(world._origin+contact*scale_value),"No mirror-origin translation")
	world.free()
	for element:String in A.SHEETS:
		for tier:int in range(1,4):
			check(A.SHEETS[element][tier-1].get_size()==Vector2(1536,1440),"Atlas dimensions unchanged")
			for frame:int in 48:check(A.frame(element,tier,float(frame)/A.FPS).region==A.region(frame),"Correct atlas cell")
			check(A.frame(element,tier,0.0)==A.frame(element,tier,4.0),"Loop wraps without allocation")
	check(A._frames.size()==12,"Bounded cache of twelve sequences")
	print("FABLEWOOD_PRESSURE_ALIGNMENT failures=",failures,"; Fire 7 / Frost 3 / Storm 5 / Earth 15; HP 105 / 300 / 780 / 570")
	quit(0 if failures==0 else 1)
