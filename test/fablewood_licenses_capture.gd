extends Node
## Real title input and layout acceptance for the shared runtime notice entry.
var output:String

func settle(frames:int=8)->void:
	for i:int in frames:await get_tree().process_frame

func shot(name:String)->void:
	await settle()
	await RenderingServer.frame_post_draw
	assert(get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))==OK)

func check_title(locale:StringName,dimensions:Vector2i,name:String)->void:
	get_window().size=dimensions
	get_window().content_scale_size=dimensions
	I18n.set_locale(locale)
	Game.open_title()
	await settle(20)
	var title:Control=Game.content
	var button:=title.find_child("OpenSourceLicensesButton",true,false) as Button
	assert(button!=null and button.is_visible_in_tree())
	assert(button.text==("Open Source Licenses" if locale==&"en-US" else "开源软件声明"))
	assert(button.size.x>=button.get_minimum_size().x)
	await shot(name+"_initial")
	button.grab_focus()
	await settle()
	var scroll:=button.get_parent().get_parent() as ScrollContainer
	assert(scroll!=null and scroll.get_global_rect().encloses(button.get_global_rect()))
	await shot(name)
	button.grab_focus()
	await get_tree().process_frame
	assert(get_viewport().gui_get_focus_owner()==button)
	var key:=InputEventKey.new()
	key.keycode=KEY_ENTER;key.physical_keycode=KEY_ENTER;key.pressed=true
	Input.parse_input_event(key)
	await settle()
	key=key.duplicate() as InputEventKey;key.pressed=false
	Input.parse_input_event(key)
	await settle()
	assert(Game.content==title and title.mode=="title")
	var dialog:=title.get_node("OpenSourceLicensesDialog") as AcceptDialog
	assert(dialog.visible)
	var text:=dialog.get_child(dialog.get_child_count()-1) as TextEdit
	assert(text!=null and not text.editable and text.text.contains("Permission is hereby granted"))
	await shot(name+"_dialog")
	dialog.confirmed.emit()
	await settle()
	assert(not title.has_node("OpenSourceLicensesDialog") and Game.content==title)
	print("FABLEWOOD_LICENSE_TITLE_PASS ",locale," ",dimensions)

func _ready()->void:
	output=OS.get_environment("FABLEWOOD_CAPTURE_DIR")
	if output.is_empty():output=ProjectSettings.globalize_path("res://build/license-captures")
	DirAccess.make_dir_recursive_absolute(output)
	await check_title(&"en-US",Vector2i(1440,900),"title_licenses_en")
	await check_title(&"zh-CN",Vector2i(1440,900),"title_licenses_cn")
	await check_title(&"zh-CN",Vector2i(720,1100),"title_licenses_cn_portrait")
	print("FABLEWOOD_LICENSE_CAPTURE_COMPLETE")
	get_tree().quit()
