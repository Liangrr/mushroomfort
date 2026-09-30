class_name FablewoodEndpointAnimation
extends RefCounted
const AtlasLayout := preload("res://scripts/fablewood/atlas_layout.gd")
## Presentation-only cached ambient loops; no simulation or event authority.
const SHEETS:={
	"gate":preload("res://assets/template/EndpointAnimations/illuminated_gate_idle.webp"),
	"vault":preload("res://assets/template/EndpointAnimations/illuminated_vault_idle.webp"),
}
const CELL:=Vector2i(480,480)
const FRAME_COUNT:=48
const FPS:=12.0
const DURATION:=4.0
const COLUMNS:=8
const ANCHOR:=Vector2(240,426)
const DISPLAY_EXPANSION:=1.25
static var _frames:Dictionary={}
static func frame_index(time:float)->int:
	return mini(FRAME_COUNT-1,floori(fposmod(time,DURATION)*FPS))
static func frame(endpoint:String,time:float)->AtlasTexture:
	if not _frames.has(endpoint):
		var items:Array[AtlasTexture]=[]
		for i:int in FRAME_COUNT:
			var sheet:Texture2D=SHEETS[endpoint]
			var texture:=AtlasLayout.texture(sheet,sheet.resource_path,i,Vector2(CELL),COLUMNS)
			items.append(texture)
		_frames[endpoint]=items
	return _frames[endpoint][frame_index(time)]
