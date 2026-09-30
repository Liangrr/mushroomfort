class_name FablewoodMergedArt
extends RefCounted
const P:=preload("res://scripts/fablewood/presentation.gd")
const DATA:={
 "fire_frost_storm_earth":{"name":"worldheart","texture":preload("res://assets/template/MergedGuardians/illuminated_fire_frost_storm_earth.webp"),"anchor":Vector2(256,564),"canvas":Vector2(512,640),"height":124.0,"foundation_y":520.0},
 "fire_frost":{"name":"rimeflame","texture":preload("res://assets/template/MergedGuardians/illuminated_fire_frost.webp"),"anchor":Vector2(193.58,414.94)},
 "fire_storm":{"name":"thunderpyre","texture":preload("res://assets/template/MergedGuardians/illuminated_fire_storm.webp"),"anchor":Vector2(192.208,238.428),"canvas":Vector2(384,288)},
 "fire_earth":{"name":"cinderroot","texture":preload("res://assets/template/MergedGuardians/illuminated_fire_earth.webp"),"anchor":Vector2(191,414),"canvas":Vector2(384,480)},
 "frost_storm":{"name":"tempestquill","texture":preload("res://assets/template/MergedGuardians/illuminated_frost_storm.webp"),"anchor":Vector2(190.85,422.19),"canvas":Vector2(384,480)},
 "frost_earth":{"name":"winterbark","texture":preload("res://assets/template/MergedGuardians/illuminated_frost_earth.webp"),"anchor":Vector2(192,413),"canvas":Vector2(384,480)},
 "storm_earth":{"name":"thornvolt","texture":preload("res://assets/template/MergedGuardians/illuminated_storm_earth.webp"),"anchor":Vector2(192,417)},
}
static func rect(key:String,center:Vector2,height:float)->Rect2:
	var canvas:Vector2=DATA[key].get("canvas",Vector2(384,480))
	var scale:=height/canvas.y
	return Rect2(center-DATA[key].anchor*scale,canvas*scale)
static func height_for(key:String)->float:return float(DATA[key].get("height",104.0))
static func canvas_for(key:String)->Vector2:return DATA[key].get("canvas",Vector2(384,480))
static func elements(key:String)->PackedStringArray:return key.split("_")
static func title(key:String)->String:return P.t(DATA[key].name)
static func subtitle(key:String)->String:
	var names:PackedStringArray=[]
	for part:String in elements(key):names.append(P.t(part))
	return "/".join(names) if key=="fire_frost_storm_earth" else " + ".join(names)
