extends "res://test/fablewood_late_enemies_capture.gd"
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(12)
	screen=Game.content;screen._skip_tutorial();screen.paused=false;screen.set_process(false);m=screen.model;w=screen.world;w.set_process(false);w.presentation_paused=false
	m.next_wave();m.timeline=WaveTimeline.new()
	var art=load("res://scripts/fablewood/late_enemy_visuals.gd");var path:=m.path_for(0)
	for kind:StringName in KINDS:
		for face:String in DIRS:
			clear_enemies();var segment:=1
			for i:int in range(1,path.size()-2):
				if path[i+1]-path[i]==DIRS[face]:segment=i;break
			var e:=create(kind,segment);e.last_damage_tick=-1000
			var period:=roundi(Pathing.PROGRESS_SCALE/float(art.CYCLES_PER_TILE[kind]))
			var boundary:=ceili(float(segment*Pathing.PROGRESS_SCALE+e.step_units)/period)*period
			e.progress_units=boundary-maxi(1,e.step_units/2)
			w._enemy_tick_valid=false;w._enemy_motion.erase(e.id);w.pan=Vector2.ZERO;w.framing();w.pan=Vector2(530,365)-w._origin-w.enemy_ground_position(e)*w._scale;w.framing();w._process(.1)
			await shot("%s_%s_wrap_before"%[kind,face]);var phase:float=w.rendered_enemy_phase(e)
			advance(1)
			assert(w.rendered_enemy_phase(e)<phase and w.enemy_segment_displacement(e)==DIRS[face]);await shot("%s_%s_wrap_after"%[kind,face])
	print("LATE_NATIVE_WRAP_PASS actual final-to-first animation transitions for all12 facings")
	get_tree().quit()
