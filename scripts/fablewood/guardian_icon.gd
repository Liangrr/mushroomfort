extends TextureRect
const GuardianAnim := preload("res://scripts/fablewood/guardian_animation.gd")
var element:="fire"
var tier:=1
var motion_owner:Node
var _elapsed:=0.0
var _atlas:AtlasTexture
func _ready()->void:
	_atlas=GuardianAnim.texture(element,tier)
	texture=_atlas
func _process(delta:float)->void:
	if not is_visible_in_tree() or not is_instance_valid(motion_owner):return
	if bool(motion_owner.get("_reduced_motion")):
		GuardianAnim.set_time(_atlas,0.0)
		return
	if bool(motion_owner.get("paused")) or bool(motion_owner.get("_ended")):return
	if texture!=_atlas:texture=_atlas
	_elapsed+=delta
	GuardianAnim.set_time(_atlas,_elapsed)
