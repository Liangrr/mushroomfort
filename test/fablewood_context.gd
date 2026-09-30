extends SceneTree
func _init() -> void:
	var C:=preload("res://sim/campaign_runtime_context.gd")
	var V:=preload("res://sim/campaign_v3_codec.gd")
	var classes:=C._resources("res://data/classes")
	var result:=V.derive_environment_sha256(C._resources("res://data/operators"),classes,C._ids("res://data/traps"),C._campaign_stages(),load("res://data/campaigns/p16_v3.tres"),C._class_text_entries(classes))
	print("FABLEWOOD_ENVIRONMENT=",JSON.stringify(result))
	quit()
