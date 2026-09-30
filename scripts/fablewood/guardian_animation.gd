class_name FablewoodGuardianAnimation
extends RefCounted
const AtlasLayout := preload("res://scripts/fablewood/atlas_layout.gd")
## Presentation-only atlas playback. Damage, targeting and attack timing stay in the model.
const CELL := Vector2(192,240)
const COLUMNS := 8
const FRAME_COUNT := 48
const FPS := 12.0
const DURATION := 4.0
const DISPLAY_EXPANSION := 1.25
const GROUND_ANCHOR := 0.88
const SHEETS := {
	"fire":[preload("res://assets/template/GuardianAnimations/illuminated_fire_1_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_fire_2_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_fire_3_idle.webp")],
	"frost":[preload("res://assets/template/GuardianAnimations/illuminated_frost_1_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_frost_2_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_frost_3_idle.webp")],
	"storm":[preload("res://assets/template/GuardianAnimations/illuminated_storm_1_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_storm_2_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_storm_3_idle.webp")],
	"earth":[preload("res://assets/template/GuardianAnimations/illuminated_earth_1_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_earth_2_idle.webp"),preload("res://assets/template/GuardianAnimations/illuminated_earth_3_idle.webp")]
}
static var _frames:Dictionary={}
static func frame_index(seconds:float)->int:
	return posmod(floori(seconds*FPS),FRAME_COUNT)
static func region(index:int)->Rect2:
	var frame:=posmod(index,FRAME_COUNT)
	return Rect2(Vector2(frame%COLUMNS,floori(float(frame)/COLUMNS))*CELL,CELL)
static func texture(element:String,tier:int)->AtlasTexture:
	var sheet:Texture2D=SHEETS[element][clampi(tier,1,3)-1]
	return AtlasLayout.texture(sheet,sheet.resource_path,0,CELL,COLUMNS)
static func set_time(value:AtlasTexture,seconds:float)->void:
	AtlasLayout.set_frame(value,value.atlas.resource_path,frame_index(seconds),CELL,COLUMNS)
static func frame(element:String,tier:int,seconds:float)->AtlasTexture:
	var key:="%s_%d"%[element,tier]
	if not _frames.has(key):
		var sequence:Array[AtlasTexture]=[]
		for i:int in FRAME_COUNT:
			var value:=texture(element,tier)
			AtlasLayout.set_frame(value,value.atlas.resource_path,i,CELL,COLUMNS)
			sequence.append(value)
		_frames[key]=sequence
	return _frames[key][frame_index(seconds)]
