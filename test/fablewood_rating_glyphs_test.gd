extends Node
const Screen:=preload("res://scripts/fablewood/screen.gd")
const P:=preload("res://scripts/fablewood/presentation.gd")
func _ready()->void:
	call_deferred("_run")
func _run()->void:
	assert(P.BODY_FONT.has_char(0x2022),"Rating bullet must exist in the bundled font, not an OS fallback")
	var source:=FileAccess.get_file_as_string("res://scripts/fablewood/screen.gd")
	assert(source.count('"• ".repeat(')==2,"Both chapter and result ratings must use the supported bullet")
	assert(not source.contains("●"),"Do not reintroduce the missing U+25CF rating glyph")
	var previous_result:Dictionary=Game.last_result.duplicate(true)
	var previous_locale:StringName=I18n.locale()
	var output:=OS.get_environment("FABLEWOOD_GLYPH_CAPTURE_DIR")
	if not output.is_empty():DirAccess.make_dir_recursive_absolute(output)
	for locale:StringName in [&"en-US",&"zh-CN"]:
		I18n.set_locale(locale)
		for stars:int in range(4):
			Game.last_result={"result":BattleModel.Result.CLEAR if stars>0 else BattleModel.Result.DEFEAT,"stars":stars,"kills":99,"leaderboard_score":2164950,"leaderboard_saved":true,"stage_id":"s1"}
			var view:=Screen.new();view.mode="results";add_child(view)
			for frame:int in 4:await get_tree().process_frame
			var found:=0
			for node:Node in view.find_children("*","Label",true,false):
				var label:=node as Label
				assert(not label.text.contains("●"),"Visible label still requests a missing glyph")
				if label.get_theme_font_size("font_size")==25 and label.get_theme_color("font_color")==P.GOLD:
					found+=1
					assert(label.text=="• ".repeat(stars),"Earned-rating count changed")
					assert(label.get_theme_font("font").has_char(0x2022),"Effective rating font lacks U+2022")
			assert(found==1,"Expected exactly one result rating label")
			if stars==3 and not output.is_empty() and DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				assert(get_viewport().get_texture().get_image().save_png(output.path_join("ratings_%s.png"%locale))==OK)
			remove_child(view);view.queue_free();await get_tree().process_frame
	Game.last_result=previous_result
	I18n.set_locale(previous_locale)
	print("FABLEWOOD_RATING_GLYPHS_PASS: 8 localized result cases; both rating consumers; unchanged bundled font")
	get_tree().quit(0)
