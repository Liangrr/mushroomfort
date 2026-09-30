extends SceneTree
const M:=preload("res://sim/fablewood_battle.gd")
const A:=preload("res://scripts/fablewood/enemy_animation.gd")
func _init()->void:call_deferred("run")
func run()->void:
	var W=load("res://scripts/fablewood/world.gd")
	for kind:StringName in A.SHEETS:
		var ids:Array[StringName]=[&"caster_1",&"sniper_1",&"recruit",&"guard_1"]
		var m:=M.create_fablewood(load("res://data/stages/s1.tres"),{"input":ids,"trusted_ticket_hashes":[],"fixed_operator_ids":ids},42)
		m.wave=1;m.wave_active=true;m._spawn({"enemy_id":kind,"path_idx":0})
		var e:EnemyState=m.enemies[0];e.progress_units=Pathing.PROGRESS_SCALE
		var w=W.new();w.model=m;A.advance(m,w._enemy_motion,false)
		var phase_before:float=w._enemy_motion[e.id].phase
		var progress_before:=e.progress_units
		w.capture_enemy_tick();m.step();A.advance(m,w._enemy_motion,false)
		var hash_after:=m.state_hash();var travel:=e.progress_units-progress_before
		for alpha:float in [0.0,0.25,0.5,0.75,1.0]:
			w.render_alpha=alpha
			var shown:int=w.rendered_enemy_progress(e)
			assert(absi(shown-(progress_before+roundi(travel*alpha)))<=1)
			var wanted:=fposmod(phase_before+float(shown-progress_before)/Pathing.PROGRESS_SCALE*float(A.CYCLES_PER_TILE[kind])*A.DURATION,A.DURATION)
			assert(absf(w.rendered_enemy_phase(e)-wanted)<0.00001)
			assert(m.state_hash()==hash_after)
		# Direction must be derived from the actual shown segment, even just before a turn.
		w._enemy_tick_valid=false
		var path:=m.path_for(0)
		for i:int in range(path.size()-1):
			e.progress_units=i*Pathing.PROGRESS_SCALE+Pathing.PROGRESS_SCALE-1
			var d:=path[i+1]-path[i]
			assert(w.enemy_faces_left(e)==(d.x-d.y<0))
		# Jump-back/teleport does not interpolate backwards through the map.
		w.capture_enemy_tick();e.progress_units=0;w.render_alpha=0.5
		assert(w.rendered_enemy_progress(e)==0)
		w.free()
	print("WALK_INTERPOLATION_TEST_PASS: all enemy positions/phases, exact turns, no model mutation, safe reset")
	quit()
