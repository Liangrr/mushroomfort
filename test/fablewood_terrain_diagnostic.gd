extends Node
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/ubuntu/fablewood_terrain/native/diagnostic_"+name+".png")
func _ready()->void:
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	Game.start_campaign(false);Game.start_campaign_stage(&"s1");await frames(15)
	var screen:Control=Game.content;screen._skip_tutorial();screen.paused=true
	var layer:FablewoodOrganicTerrain=screen.world.terrain_layer
	print("LAYER ",layer.polygon," UV ",layer.uv," transform ",layer.transform," vis ",layer.visible)
	var mat:ShaderMaterial=layer.material
	layer.material=null;layer.color=Color(1,0,0,0.8);await shot("geometry")
	layer.color=Color.WHITE;layer.material=mat
	var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded; void fragment(){ COLOR=vec4(UV.x,UV.y,0.25,1.0); }"
	mat.shader=shader;await shot("uv")
	shader=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded; uniform sampler2D data; void fragment(){ COLOR=vec4(texture(data,UV).rgb,1.0); }"
	mat.shader=shader;mat.set_shader_parameter("data",ImageTexture.create_from_image(layer.mask));await shot("map")
	get_tree().quit()
