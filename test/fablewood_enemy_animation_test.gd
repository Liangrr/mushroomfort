extends SceneTree
const M:=preload("res://sim/fablewood_battle.gd")
const A:=preload("res://scripts/fablewood/enemy_animation.gd")
var failures:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;push_error(label)
func make()->FablewoodBattle:
	var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
	var m:=M.create_fablewood(load("res://data/stages/s1.tres"),{"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids},42)
	m.wave=1;m.wave_active=true
	return m
func run()->void:
	for kind:StringName in A.SHEETS:
		check(A.SHEETS[kind].get_size()==Vector2(2048,1536),"Atlas dimensions "+String(kind))
		for i:int in A.FRAME_COUNT:check(A.frame(kind,float(i)/A.FPS).region==A.region(i),"Atlas frame bounds")
		check(A.frame(kind,0.0)==A.frame(kind,A.DURATION),"Loop reuses its first texture")
		var m:=make();m._spawn({"enemy_id":kind,"path_idx":0})
		var e:EnemyState=m.enemies[0];e.progress_units=Pathing.PROGRESS_SCALE
		var motion:Dictionary={};var hash:=m.state_hash()
		A.advance(m,motion,false)
		check(m.state_hash()==hash,"Presentation never changes simulation")
		var start:=float(motion[e.id].phase)
		m.step(3);A.advance(m,motion,false)
		var normal:=float(motion[e.id].phase)-start
		check(normal>0,"Locomotion advances frames")
		var slow:=make();slow._spawn({"enemy_id":kind,"path_idx":0})
		var se:EnemyState=slow.enemies[0];se.progress_units=Pathing.PROGRESS_SCALE
		slow.slow_until[se.id]=999
		var sm:Dictionary={};A.advance(slow,sm,false)
		var slow_start:=float(sm[se.id].phase)
		slow.step(3);A.advance(slow,sm,false)
		check(float(sm[se.id].phase)-slow_start<normal,"Frost slows animation with movement")
		var fast:=make();fast._spawn({"enemy_id":kind,"path_idx":0})
		fast.enemies[0].progress_units=Pathing.PROGRESS_SCALE
		var fm:Dictionary={};A.advance(fast,fm,false)
		var fast_start:=float(fm[0].phase)
		fast.step(6);A.advance(fast,fm,false)
		check(is_equal_approx(float(fm[0].phase)-fast_start,normal*2.0),"Double simulation travel produces double animation travel")
		var phase:=float(motion[e.id].phase)
		A.advance(m,motion,false)
		check(float(motion[e.id].phase)==phase,"Unchanged progress holds pose")
		e.stunned_until_tick=m.tick+30
		if not e.aerial:
			m.step(3);A.advance(m,motion,false)
			check(float(motion[e.id].phase)==phase,"Ground stagger holds pose")
		e.stunned_until_tick=0
		m.step(3);A.advance(m,motion,true)
		check(float(motion[e.id].phase)==phase,"Reduced motion holds pose")
		var progress:=e.progress_units
		A.advance(m,motion,false)
		check(float(motion[e.id].phase)==phase and int(motion[e.id].progress)==progress,"No catch-up after reduced motion")
		e.alive=false;A.advance(m,motion,false)
		check(motion.is_empty(),"Dead enemy animation is cleaned")
	check(A._frames.size()==4,"Only four cached sequences")
	print("ENEMY_ANIMATION_TEST failures=",failures)
	quit(0 if failures==0 else 1)
