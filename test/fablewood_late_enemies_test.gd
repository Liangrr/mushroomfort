extends "fablewood_checks.gd"
var checks:=0
func check(ok:bool,message:String="") -> void:
	checks+=1;super.check(ok,message)
func single(kind:StringName,chapter:int=1)->FablewoodBattle:
	var m:=make(chapter);check(m!=null,"Chapter model accepts new roster")
	m.next_wave();m.timeline=WaveTimeline.new();m._spawn({"enemy_id":kind,"path_idx":0});m.enemies[-1].step_units=0;m.drain_events();return m
func frozen_steps(m:FablewoodBattle,count:int)->void:
	for i:int in count:
		for e:EnemyState in m.enemies:e.step_units=0
		m.step();m.drain_events()
func count_event(m:FablewoodBattle,kind:String)->int:
	var count:=0
	for e:Dictionary in m.drain_events():
		if e.kind==kind:count+=1
	return count
func run()->void:
	for chapter:int in range(1,4):
		var q:=make(chapter);check(q!=null,"New chapter resources load")
		for old:Array in [[&"goblin",105],[&"orc",300],[&"troll",780],[&"dragon",570]]:check(q.enemy_base_hp(q._defs[old[0]])==old[1],"Old base HP retained")
		var seen:Dictionary={}
		for row:Dictionary in q.stage.waves:
			if row.enemy_id in q.late_enemies.IDS:
				var wave:=floori(float(row.tick)/30000)+1
				check(chapter>=2 and wave>=(5 if chapter==2 else 3),"No early-game intrusion")
				seen[row.enemy_id]=true
		check(seen.is_empty() if chapter==1 else seen.size()==3,"All three introduced only in later chapters")
	var m:=single(&"prismback");var e:EnemyState=m.enemies[-1];var s:Dictionary=m.late_enemies.info(e.id)
	var shell:int=s.shell;var hp:=e.hp
	m._damage_enemy(e,100,1);check(e.hp==hp and int(s.shell)==shell-100,"Arts shell absorbs resolved damage")
	m._damage_enemy(e,55,0);check(e.hp==hp-41 and int(s.shell)==shell-100,"Earth physical bypasses shell")
	var before:=e.hp;var remain:int=s.shell
	m._damage_enemy(e,remain+30,1);check(e.hp==before-30 and int(s.shell)==0,"Shell overflow hits HP exactly")
	check(count_event(m,"shell_break")==1,"Shell breaks once")
	m.step(120);check(int(s.shell)==0,"No regeneration before four-second threshold")
	m.step();check(int(s.shell)==ceili(int(s.shell_max)/8.0),"One-eighth shell returns at threshold")
	m._damage_enemy(e,1,0);var post:int=s.shell
	m.step(119);check(int(s.shell)==post,"Any positive hit delays recovery")
	m.step(2);check(int(s.shell)>post,"Recovery resumes after another quiet interval")
	# A null/invalid hit cannot disrupt regeneration or award anything.
	var regen:int=s.regen;m._damage_enemy(e,0,1);check(int(s.regen)==regen,"Zero damage has no ability side effect")
	var earned:=m.earned;m._damage_enemy(e,100000,0);m._damage_enemy(e,100000,0)
	check(m.earned-earned==48 and not e.alive,"Prismback kill pays exactly once")
	m._check_terminal();check(m.late_enemies.states.is_empty(),"Killed shell state cleaned")
	# First tell, burst, cancellation and next-cycle reset.
	m=single(&"harrier");e=m.enemies[-1];s=m.late_enemies.info(e.id)
	m.step(97);check(int(s.mode)==0,"No premature tell")
	m.step();check(int(s.mode)==1 and count_event(m,"harrier_tell")==1,"23-tick readable windup")
	m.step(22);check(m.tick==120 and int(s.mode)==1,"Tell persists until burst threshold")
	e.step_units=100;var p:=e.progress_units;m.step();check(int(s.mode)==2 and e.progress_units-p==175 and e.step_units==100,"Burst multiplies movement, restores source speed")
	check(count_event(m,"harrier_dash")==1,"One actual burst cue")
	m.slow_until[e.id]=m.tick+5;p=e.progress_units;m.step();check(int(s.mode)==0 and e.progress_units-p==48,"Frost cancels burst and applies usual slow")
	e.step_units=0;m.step(48);check(int(s.mode)==0,"Cancelled burst cannot resume in its cycle")
	m.step(300-m.tick);m.step();check(int(s.mode)==2,"Next burst cycle can occur")
	m=single(&"harrier");e=m.enemies[-1];s=m.late_enemies.info(e.id);m.step(97)
	e.stunned_until_tick=123;m.step(30);check(int(s.mode)==0 and count_event(m,"harrier_dash")==0,"Freeze during tell cancels upcoming burst")
	# Mother casts, remains capped, and pays reduced gold for children.
	m=single(&"broodmother");e=m.enemies[-1];s=m.late_enemies.info(e.id)
	m.step(150);check(not s.warned,"No early brood tell")
	m.step();check(s.warned and count_event(m,"brood_tell")==1,"Brood tell starts one second early")
	m.step(29);check(m.enemies.size()==1,"No early children")
	e.progress_units=Pathing.PROGRESS_SCALE*5;e.stunned_until_tick=185
	m.step(5);check(m.enemies.size()==1,"Freeze delays due brood")
	m.step();check(m.enemies.size()==3 and int(s.broods)==1,"Exactly two children after freeze")
	for i:int in [1,2]:
		var child:EnemyState=m.enemies[i]
		check(child.def_id==&"goblin" and child.path_idx==e.path_idx,"Children use existing goblin/route")
		check(child.progress_units==e.progress_units-Pathing.PROGRESS_SCALE*(3+m.late_enemies.children.keys().find(child.id))/4+child.step_units,"Staggered children enter behind mother and advance through model")
	check(count_event(m,"brood_spawn")==1,"One actual brood event")
	frozen_steps(m,211);check(int(s.broods)==2 and m.late_enemies.children.size()==4,"Second pair appears")
	frozen_steps(m,230);check(int(s.broods)==2 and m.enemies.size()==5,"Four living children cap")
	earned=m.earned
	m._damage_enemy(m.enemies[1],100000,0);m._damage_enemy(m.enemies[2],100000,0)
	check(m.earned-earned==8,"Summoned goblins pay 4 gold each")
	frozen_steps(m,31);check(int(s.broods)==3 and m.enemies.size()==7,"Final pair after room opens")
	for child:EnemyState in m.enemies:
		if child.id!=e.id:m._damage_enemy(child,100000,0)
	frozen_steps(m,700);check(m.enemies.size()==7 and int(s.broods)==3,"Three-brood lifetime cap prevents farming")
	earned=m.earned;m._damage_enemy(e,100000,0);m._damage_enemy(e,100000,0);m._check_terminal()
	check(m.earned-earned>=38 and not m.wave_active and m.late_enemies.states.is_empty(),"Mother death clears state and wave finishes")
	# Dead mothers never schedule offspring; living children delay a wave clear.
	m=single(&"broodmother");e=m.enemies[0];frozen_steps(m,181);m._damage_enemy(e,100000,0);m._check_terminal()
	check(m.wave_active and m.alive_count()==2,"Wave waits for surviving children")
	frozen_steps(m,500);check(m.enemies.size()==3,"Dead mother cannot spawn again")
	check(m.apply_action([&"resign"]),"Resign accepted");var hash_before:=m.state_hash();m.step(100)
	check(m.late_enemies.states.is_empty() and m.late_enemies.children.is_empty() and m.state_hash()==hash_before,"Terminal state has no pending enemy work")
	# Global living-enemy cap leaves capacity intact and does not consume brood budget.
	m=single(&"broodmother");s=m.late_enemies.info(0)
	for i:int in 95:m._spawn({"enemy_id":&"goblin","path_idx":0})
	frozen_steps(m,190);check(m.enemies.size()==96 and int(s.broods)==0,"Global living cap respected")
	# Actual tower channels, not only synthetic damage/status calls.
	for pair:Array in [[&"prismback",&"guard_1"],[&"harrier",&"sniper_1"]]:
		m=single(pair[0]);e=m.enemies[0];m.dp=9999
		var pad:=pads(m)[0];check(m.apply_action([&"deploy",pair[1],pad,0]),"Counter tower deploys")
		var u:UnitState=m.units[-1];check(m.apply_action([&"upgrade",u.id]) and m.apply_action([&"upgrade",u.id]),"Counter tower reaches level three")
		var closest:=0;var distance:=999
		for i:int in m.path_for(0).size():
			var cell:Vector2i=m.path_for(0)[i];var d:=maxi(absi(cell.x-pad.x),absi(cell.y-pad.y))
			if d<distance:distance=d;closest=i
		e.progress_units=closest*Pathing.PROGRESS_SCALE
		if pair[0]==&"prismback":
			var protected:int=m.late_enemies.info(e.id).shell;var health:=e.hp
			check(m._fire_channel(u,"earth",m.base_attack_damage(u),3,m.range_for(u)),"Earth finds Prismback in its real range")
			check(e.hp==health-m.base_attack_damage(u) and int(m.late_enemies.info(e.id).shell)==protected,"Actual Earth attack bypasses crystal shell")
		else:
			m.tick=120;m.late_enemies.advance(m);check(int(m.late_enemies.info(e.id).mode)==2,"Harrier begins actual burst")
			check(m._fire_channel(u,"frost",m.base_attack_damage(u),3,m.range_for(u)),"Frost actually targets aerial Harrier")
			m.tick+=1;m.late_enemies.advance(m);check(int(m.late_enemies.info(e.id).mode)==0,"Real Frost attack cancels aerial burst")
	# Replay includes per-enemy state, child provenance and timing.
	var a:=single(&"prismback",3);var b:=single(&"prismback",3)
	for q:FablewoodBattle in [a,b]:
		q._spawn({"enemy_id":&"harrier","path_idx":0});q._spawn({"enemy_id":&"broodmother","path_idx":0})
	for tick:int in 800:
		for q:FablewoodBattle in [a,b]:
			for foe:EnemyState in q.enemies:foe.step_units=0
			if tick%35==0:q._damage_enemy(q.enemies[0],17,1)
			q.step();q.drain_events()
		check(a.state_hash()==b.state_hash(),"Replay agrees at each tick")
	b.late_enemies.states[0].shell+=1;check(a.state_hash()!=b.state_hash(),"Shell state contributes to battle hash")
	print("LATE_ENEMY_MODEL_PASS checks=",checks," failures=",failures," shell/bypass/recovery; dash/tell/slow; brood/caps/rewards; wave rollout; lifecycle; deterministic replay")
	quit(1 if failures else 0)
