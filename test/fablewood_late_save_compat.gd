extends SceneTree
const C:=preload("res://sim/campaign_runtime_context.gd")
const V:=preload("res://sim/campaign_v3_codec.gd")
func _init()->void:call_deferred("verify")
func verify()->void:
	var context:=C.build();assert(not context.is_empty())
	var source:=FileAccess.get_file_as_string(get_script().resource_path.get_base_dir().path_join("fixtures/fablewood_pre_late_campaign.json"))
	var decoded:=V.decode_save(source,context);print("OLD_SAVE_DECODE ",decoded.get("accepted")," ",decoded.get("error_code"));assert(decoded.accepted)
	var f:=FileAccess.open("user://campaign_v1.json",FileAccess.WRITE);f.store_string(source);f.close()
	var game:Node=root.get_node("Game");assert(game.start_campaign(false));assert(game.start_campaign_stage(&"s1"))
	for i:int in 8:await process_frame
	var screen:Control=game.content;assert(screen.startup_succeeded and screen.model!=null)
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://campaign_v1.json"));var old:Dictionary=JSON.parse_string(source)
	assert(saved.data.campaign_uid==old.data.campaign_uid and saved.data.stage_stars==old.data.stage_stars and saved.data.marks==old.data.marks and saved.data.heroes==old.data.heroes)
	print("LATE_SAVE_COMPAT_PASS old campaign UID, stars, marks, heroes and pending Chapter1 ticket retained; validation not bypassed")
	quit()
