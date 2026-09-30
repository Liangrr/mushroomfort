class_name UiKit
extends RefCounted
## Small helpers so screens can be built in readable code.


static func label(text: String, variation: String = "", size: int = 0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func button(text: String, callback: Callable, variation: String = "", min_size: Vector2 = Vector2.ZERO) -> GameButton:
	var b := GameButton.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if min_size != Vector2.ZERO:
		b.custom_minimum_size = min_size
	if callback.is_valid():
		b.pressed.connect(callback)
	return b


static func vbox(separation: int = 12, align: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.alignment = align
	return v


static func hbox(separation: int = 12, align: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.alignment = align
	return h


static func icon(texture: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	return p


static func dim(alpha: float = 0.55) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.08, 0.06, 0.03, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


static func center(child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(child)
	return cc


## Anchor a control to a point of its parent (0..1 per axis) and give it an
## offset rectangle from that point. Grows away from the anchored edge.
static func place(c: Control, anchor: Vector2, pos: Vector2, size: Vector2 = Vector2.ZERO) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if anchor.x >= 1.0 else (Control.GROW_DIRECTION_BOTH if anchor.x > 0.0 else Control.GROW_DIRECTION_END)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if anchor.y >= 1.0 else (Control.GROW_DIRECTION_BOTH if anchor.y > 0.0 else Control.GROW_DIRECTION_END)


## Pop-in animation for panels.
static func pop_in(node: Control, delay: float = 0.0) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(0.85, 0.85)
	node.modulate.a = 0.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 1.0, 0.18).set_delay(delay)


## Wire vertical focus neighbours for a list of controls (gamepad menus).
static func chain_focus(controls: Array) -> void:
	for i in controls.size():
		var c: Control = controls[i]
		var prev: Control = controls[(i - 1 + controls.size()) % controls.size()]
		var nxt: Control = controls[(i + 1) % controls.size()]
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(nxt)
