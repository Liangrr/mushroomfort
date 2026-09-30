extends SceneTree
const A:=preload("res://scripts/fablewood/endpoint_animation.gd")
func _init()->void:call_deferred("run")
func solid_bottom(image:Image)->int:
	for y:int in range(image.get_height()-1,-1,-1):
		for x:int in image.get_width():
			if image.get_pixel(x,y).a>=0.5:return y
	return -1
func logical_image(texture:AtlasTexture)->Image:
	assert(texture.get_size()==Vector2(A.CELL))
	var image:=Image.create(A.CELL.x,A.CELL.y,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.blit_rect(texture.atlas.get_image(),Rect2i(texture.region),Vector2i(texture.margin.position))
	return image
func run()->void:
	var W=load("res://scripts/fablewood/world.gd")
	var w=W.new()
	for name:String in ["gate","vault"]:
		assert(A.frame_index(0)==0 and A.frame_index(4)==0 and A.frame_index(3.99)==47)
		assert(A.frame(name,0)==A.frame(name,4))
		assert(A._frames[name].size()==48)
		var first:=logical_image(A._frames[name][0])
		var last:=logical_image(A._frames[name][47])
		assert(first.get_data()!=last.get_data(),"No fabricated duplicate terminal pose")
		assert(first.get_pixel(0,0).a==0.0)
		for i:int in 48:
			var image:=logical_image(A._frames[name][i])
			# Generated root shading may breathe; the authored solid ground contact
			# must remain fixed, and no frame may touch the canvas boundary.
			assert(absi(solid_bottom(image)-roundi(A.ANCHOR.y))<=1,"Generated endpoint contact drift")
			var bounds:=image.get_used_rect()
			assert(bounds.position.x>0 and bounds.position.y>0)
			assert(bounds.end.x<480 and bounds.end.y<480)
		var origin:=Vector2(180,200)
		var r0:Rect2=w.endpoint_draw_rect(name,origin,false)
		var r1:Rect2=w.endpoint_draw_rect(name,origin,true)
		# Reduced motion is the genuine first frame, not a mismatched legacy crop.
		assert(r0.is_equal_approx(r1))
		assert((r0.position+A.ANCHOR/Vector2(A.CELL)*r0.size).is_equal_approx(origin))
		assert((r1.position+A.ANCHOR/Vector2(A.CELL)*r1.size).is_equal_approx(origin))
	for i:int in 500:
		A.frame("gate",i*.017);A.frame("vault",i*.017)
	assert(A._frames.size()==2 and A._frames.gate.size()==48 and A._frames.vault.size()==48)
	w.free()
	print("ENDPOINT_ANIMATION_TEST_PASS: wrap, genuine motion, locked contacts, alpha, identical reduced-motion geometry, bounded caches")
	quit()
