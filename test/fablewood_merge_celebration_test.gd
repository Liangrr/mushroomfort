extends SceneTree
var FX:GDScript
class WorldStub:
	extends Control
	var shown:=true
	func platform_surface_center(cell:Vector2i)->Vector2:return Vector2(cell)*32
	func effect_visible(_at:Vector2)->bool:return shown
func _init()->void:call_deferred("run")
func run()->void:
	FX=load("res://scripts/fablewood/merge_celebration.gd")
	var world:=WorldStub.new();var fx:RefCounted=FX.new()
	var event:Dictionary={"kind":"merge_placed","unit":0,"cell":Vector2i(1,1),"element":"fire","second_element":"frost"}
	assert(fx.trigger(event,world));assert(not fx.trigger(event,world))
	event.kind="merge_prepare";event.unit=1;assert(not fx.trigger(event,world));event.kind="merge_placed"
	for i:int in range(1,150):
		event.unit=i;assert(fx.trigger(event,world));assert(fx.active.size()<=FX.MAX_ACTIVE and fx._seen.size()<=64)
	fx.advance(3,world);assert(fx.active.is_empty())
	world.shown=false;event.unit=200;assert(not fx.trigger(event,world));world.shown=true;assert(not fx.trigger(event,world))
	event.unit=201;assert(fx.trigger(event,world));world.shown=false;fx.advance(.1,world);assert(fx.active.is_empty())
	fx.clear();assert(fx._seen.is_empty());world.free()
	print("MERGE_CELEBRATION_PASS bounded events; expiry; culling; no replay; success-only")
	quit()
