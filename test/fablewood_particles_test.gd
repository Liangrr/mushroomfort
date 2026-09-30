extends SceneTree
const M:=preload("res://sim/fablewood_battle.gd")
const FX:=preload("res://scripts/fablewood/combat_particles.gd")
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func run()->void:
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var m:=M.create_fablewood(load("res://data/stages/s1.tres"),{"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids},42)
	m.wave=1;m._spawn({"enemy_id":&"goblin","path_idx":0})
	var e:EnemyState=m.enemies[0];e.resistance_permille=0
	var hp:=e.hp;m._damage_enemy(e,7,1)
	var events:=m.drain_events()
	check(events.size()==1 and events[0].kind=="damage" and int(events[0].amount)==hp-e.hp,"Only actual resolved damage produces a hit event")
	m._damage_enemy(e,99999,1);events=m.drain_events()
	var death_hits:=0
	for event:Dictionary in events:
		if event.kind=="damage" and bool(event.killed):death_hits+=1
	check(death_hits==1,"One lethal damage event")
	m._damage_enemy(e,7,1);check(m.drain_events().is_empty(),"No duplicate hit on dead enemies")
	var world=load("res://scripts/fablewood/world.gd").new();world.model=m;world.size=Vector2(1200,700)
	var fx:=FX.new();var at:=Vector2(0,150)
	var hash:=m.state_hash()
	for i:int in 100:
		fx.burst(at,"fire",12);fx.blood(at-Vector2(0,20),at,10,true,false)
	check(fx.particles.size()<=FX.MAX_PARTICLES,"Particle count is capped")
	check(fx.decals.size()<=FX.MAX_DECALS,"Ground decal count is capped")
	check(m.state_hash()==hash,"Visual emissions do not alter combat state")
	fx.clear()
	for element:String in ["fire","frost","storm","earth"]:fx.upgrade_burst(at,element)
	check(fx.particles.size()==28*4,"All four upgrade patterns emit the expected bounded burst")
	check(fx.particles.all(func(p:Dictionary)->bool:return bool(p.get("upgrade",false))),"Upgrade particles are distinct")
	for i:int in 40:fx.upgrade_burst(at,"fire")
	check(fx.particles.size()<=FX.MAX_PARTICLES and m.state_hash()==hash,"Upgrade effects remain bounded and simulation-independent")
	fx.advance(10.0,world)
	check(fx.particles.is_empty() and fx.decals.is_empty(),"Particles and ground stains expire")
	fx.burst(at,"storm",8);world.reduced_motion=true;fx.advance(0.01,world)
	check(fx.particles.is_empty(),"Reduced motion immediately removes moving particles")
	fx.blood(at,at,7,false,true)
	check(fx.particles.is_empty() and fx.decals.size()==1,"Reduced motion retains static hit evidence")
	fx.clear();world.reduced_motion=false
	world.pan=Vector2(99999,99999)
	world.add_event({"kind":"damage","enemy":e.id,"amount":7,"killed":true})
	check(world.combat_particles.particles.is_empty() and world.combat_particles.decals.is_empty(),"Off-screen hits do not allocate effects")
	world.add_event({"kind":"upgrade","cell":Vector2i(4,3),"element":"fire"})
	check(world.combat_particles.particles.is_empty() and world.effects.is_empty(),"Off-screen upgrades do not allocate delayed celebrations")
	fx.burst(at,"earth",8);fx.advance(0.01,world)
	check(fx.particles.is_empty(),"Particles are culled after camera movement")
	world.free()
	print("COMBAT_PARTICLES_TEST failures=",failures)
	quit(0 if failures==0 else 1)
