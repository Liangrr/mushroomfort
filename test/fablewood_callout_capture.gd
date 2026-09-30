extends Node
const OUT:="/home/ubuntu/fablewood_callouts/native/"
var screen:Control
func frames(n:int=5)->void:
	for i:int in n:await get_tree().process_frame
func shot(name:String)->void:
	await frames();await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	print("CALLOUT_NATIVE ",name)
func check_layout()->void:
	var tour:FablewoodTutorialCallout=screen.overlay
	var card_rect:=Rect2(tour.card.position,tour.card.size)
	assert(Rect2(Vector2.ZERO,screen._logical).encloses(card_rect),"Callout stays inside game surface")
	assert(not card_rect.intersects(tour.target),"Callout does not cover its highlighted target")
	for related:Rect2 in screen._tutorial_avoid_rects():assert(not card_rect.intersects(related),"Related build/upgrade context remains visible")
	assert(tour.skip_button.visible and not tour.skip_button.disabled,"Skip available on every step")
	assert(tour.connector.size()==2 and tour.arrow.size()==3,"Arrow/focus geometry is present")
func _ready()->void:
	assert(I18n.reload_catalogs(),"Canonical bilingual catalogs load")
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=Vector2i(1440,900)
	assert(Game.start_campaign(false));assert(Game.start_campaign_stage(&"s1"));await frames(16)
	screen=Game.content
	if screen._tutorial_active:screen._skip_tutorial()
	screen._show_tutorial();await frames()
	assert(screen.paused and screen._tutorial_active)
	for step:int in 6:
		screen._tutorial_step=step;(screen.overlay as FablewoodTutorialCallout).refresh();await frames()
		check_layout();await shot("en_step_"+str(step))
	# Actual selection/build/upgrade transitions while the simulation remains held.
	screen._tutorial_step=1;(screen.overlay as FablewoodTutorialCallout).refresh()
	screen._choose(&"caster_1");assert(screen._tutorial_step==2)
	var tick:int=screen.model.tick;var hp:int=screen.model.base_hp
	screen._cell_clicked(Vector2i(0,6));await frames()
	assert(screen._tutorial_step==2 and (screen.overlay as FablewoodTutorialCallout).feedback.visible)
	check_layout();await shot("invalid_placement_feedback")
	screen._cell_clicked(Vector2i(4,3));assert(screen._tutorial_step==3 and screen.model.units.size()==1)
	await frames();check_layout();await shot("en_upgrade_target")
	screen._tutorial_upgrade_button.pressed.emit();assert(screen._tutorial_step==4 and screen.model.tier(screen.model.units[0])==2)
	assert(screen.model.tick==tick and screen.model.base_hp==hp,"Tutorial actions do not advance combat")
	# Keep the same step across locale and orientation changes.
	I18n.set_locale(&"zh-CN");await frames()
	assert(screen._tutorial_active and screen._tutorial_step==4 and screen.paused)
	get_window().size=Vector2i(720,1100);get_window().content_scale_size=Vector2i(720,1100);await frames(12)
	for step:int in 6:
		screen._tutorial_step=step;(screen.overlay as FablewoodTutorialCallout).refresh();await frames()
		check_layout();await shot("cn_portrait_step_"+str(step))
	# Skip at every step must remove all tutorial hit interception and highlights.
	for step:int in 6:
		screen._tutorial_step=step;screen._skip_tutorial();await frames()
		assert(not screen._tutorial_active and screen.overlay==null and not screen.paused)
		if step<5:screen._show_tutorial();await frames()
	# A help tour opened from Pause must return to Pause, not silently resume.
	screen._show_pause();screen._show_tutorial();await frames();screen._skip_tutorial();await frames()
	assert(screen.paused and not screen._tutorial_active and screen.overlay!=null)
	screen.paused=false;screen._dismiss()
	# Starting a wave is explicit; Ready/Skip never starts one.
	screen._show_tutorial();screen._tutorial_step=5;(screen.overlay as FablewoodTutorialCallout).refresh()
	screen._next_wave();await frames()
	assert(not screen._tutorial_active and screen.model.wave_active and not screen.paused)
	# Title help is a contextual start-button hint and arms only the next battle.
	Game.open_title();await frames(12);screen=Game.content;screen._show_tutorial();await frames()
	check_layout();await shot("title_help_cn")
	screen._tutorial_advance();assert(screen._tutorial_tour_requested)
	assert(Game.content==screen and screen.mode=="title","Manual title help completion never starts or resets a game")
	print("ALL_CALLOUT_NATIVE_CHECKS_PASS")
	get_tree().quit()
