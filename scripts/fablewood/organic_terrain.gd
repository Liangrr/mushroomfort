class_name FablewoodOrganicTerrain
extends Polygon2D
## Cached categorical material data; this never mutates StageDef or the simulation.
const P:=preload("res://scripts/fablewood/presentation.gd")
const SHADER:=preload("res://scripts/fablewood/organic_terrain.gdshader")
var _stage:StageDef
var _route:Array[Vector2i]=[]
var mask:Image
var rebuild_count:=0
func configure(stage:StageDef,route:Array[Vector2i])->void:
	if stage==_stage and route==_route:return
	_stage=stage;_route.assign(route)
	var dimensions:=stage.grid_size()
	var pixels:=dimensions+Vector2i(2,2)
	mask=Image.create(pixels.x,pixels.y,false,Image.FORMAT_RGB8)
	mask.fill(Color.BLACK)
	for y:int in dimensions.y:
		for x:int in dimensions.x:
			var cell:=Vector2i(x,y)
			var present:=stage.tile_at(cell)!=StageDef.Tile.VOID
			mask.set_pixel(x+1,y+1,Color(1.0 if present and route.has(cell) else 0.0,1.0 if present else 0.0,1.0 if present and stage.is_elevated_platform(cell) else 0.0))
	var shader_material:=ShaderMaterial.new();shader_material.shader=SHADER
	texture=ImageTexture.create_from_image(mask)
	shader_material.set_shader_parameter("material_map",texture)
	shader_material.set_shader_parameter("map_size",Vector2(pixels))
	shader_material.set_shader_parameter("root_art",P.ROOT)
	shader_material.set_shader_parameter("road_art",P.PATH)
	material=shader_material
	var corners:=PackedVector2Array([Vector2(-1,-1),Vector2(dimensions.x+1,-1),Vector2(dimensions.x+1,dimensions.y+1),Vector2(-1,dimensions.y+1)])
	var vertices:=PackedVector2Array()
	for point:Vector2 in corners:vertices.append(project(point))
	polygon=vertices
	uv=PackedVector2Array([Vector2(0,0),Vector2(pixels.x,0),Vector2(pixels),Vector2(0,pixels.y)])
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	z_index=0;show_behind_parent=true
	rebuild_count+=1
static func project(point:Vector2)->Vector2:
	return Vector2((point.x-point.y)*32.0,(point.x+point.y)*16.0)
func align_view(origin:Vector2,world_scale:float)->void:
	position=origin;scale=Vector2.ONE*world_scale
