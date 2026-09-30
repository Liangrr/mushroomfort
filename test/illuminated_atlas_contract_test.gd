extends SceneTree
const Layout:=preload("res://scripts/fablewood/atlas_layout.gd")
func _init()->void:
	var file:=FileAccess.open(Layout.METADATA_PATH,FileAccess.READ)
	assert(file!=null,"Packed atlas metadata must ship in the player")
	var metadata:Dictionary=JSON.parse_string(file.get_as_text())
	assert(metadata.enabled and metadata.atlases.size()==56)
	for path:String in metadata.atlases:
		var record:Dictionary=metadata.atlases[path]
		var sheet:=load("res://"+path) as Texture2D
		assert(sheet!=null,"Packed texture must load: "+path)
		assert(sheet.resource_path=="res://"+path,"Resource identity must survive export")
		var cell:=Vector2(record.original_cell[0],record.original_cell[1])
		var packed:=Vector2(record.packed_cell[0],record.packed_cell[1])
		assert(sheet.get_size()==packed*Vector2(8,6))
		for frame:int in 48:
			var texture:=Layout.texture(sheet,sheet.resource_path,frame,cell,8)
			assert(texture.get_size()==cell,"Logical canvas changed: "+path)
			assert(texture.margin.position==Vector2(record.trim_offset[0],record.trim_offset[1]))
			assert(texture.region.position.x>=0 and texture.region.position.y>=0)
			assert(texture.region.end.x<=sheet.get_width() and texture.region.end.y<=sheet.get_height())
			Layout.set_frame(texture,sheet.resource_path,(frame+1)%48,cell,8)
			assert(texture.get_size()==cell)
	print("ILLUMINATED_ATLAS_CONTRACT_PASS atlases=%d frames=%d"%[metadata.atlases.size(),metadata.atlases.size()*48])
	quit(0)
