extends Node
const Screen:=preload("res://scripts/fablewood/screen.gd")
const P:=preload("res://scripts/fablewood/presentation.gd")
func _ready()->void:
	call_deferred("_run")
func _run()->void:
	var view:=Screen.new()
	var samples:=["Hard: Prismback, Harrier and Broodmother have +50% HP; their scheduled arrivals are 25% closer together, +1 late-enemy reinforcement for every 3 authored late enemies.","困难模式：晶背兽、疾风掠袭者和育群母体拥有更高生命值，出现间隔缩短，且会获得额外增援。守护最后的种子，合理使用元素克制。"]
	for text:String in samples:
		var wrapped:String=view._wrap_tooltip(text)
		assert(wrapped.replace("\n","").replace(" ","")==text.replace(" ",""),"Tooltip copy must remain unchanged")
		assert(wrapped.contains("\n"),"Long hint should wrap")
		for line:String in wrapped.split("\n"):
			assert(P.BODY_FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x<=360.0,"Tooltip line exceeds safe width")
	view.free()
	print("ILLUMINATED_GROVE_TOOLTIP_WRAP_PASS")
	get_tree().quit(0)
