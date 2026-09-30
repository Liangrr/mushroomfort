class_name EnemyDamageFeedback
extends RefCounted

## View-only damage feedback. Animation clocks and flashes age on render frames;
## authoritative movement pause remains EnemyState.damage_stagger_until_tick.

const EnemyAnimatorType := preload("res://scripts/view/enemy_animator.gd")

var _anim_paused_seconds: Dictionary = {}
var _seen_ticks: Dictionary = {}
var _flash_frames: Dictionary = {}
var _flash_totals: Dictionary = {}
var _death_effects: Dictionary = {}


func register(enemy: EnemyState) -> void:
	_seen_ticks[enemy.id] = -1


func remove(enemy_id: int) -> void:
	_anim_paused_seconds.erase(enemy_id)
	_seen_ticks.erase(enemy_id)
	_flash_frames.erase(enemy_id)
	_flash_totals.erase(enemy_id)
	_death_effects.erase(enemy_id)


func process(delta: float, model: BattleModel, rects: Dictionary, cfg: JuiceConfig) -> void:
	for enemy: EnemyState in model.enemies:
		if enemy.alive and is_staggered(model, enemy):
			_anim_paused_seconds[enemy.id] = (
				float(_anim_paused_seconds.get(enemy.id, 0.0)) + delta
			)
		if not rects.has(enemy.id):
			continue
		var body := rects[enemy.id] as ColorRect
		if (
			not enemy.alive
			and enemy.died_at_tick >= 0
			and EnemyAnimatorType.uses_static_sprite(enemy.def_id)
		):
			if not _death_effects.has(enemy.id):
				var reduced_motion := bool(ProjectSettings.get_setting("accessibility/reduced_motion", false))
				if EnemyAnimatorType.begin_death_effect(
					body, enemy.def_id, enemy.id, reduced_motion,
				):
					_death_effects[enemy.id] = true
			if _death_effects.has(enemy.id) and EnemyAnimatorType.advance_death_effect(body, delta):
				_death_effects.erase(enemy.id)
		var seen := int(_seen_ticks.get(enemy.id, -1))
		if enemy.last_damage_tick <= seen:
			continue
		_seen_ticks[enemy.id] = enemy.last_damage_tick
		var total := EnemyAnimatorType.damage_flash_frames_for(enemy.def_id, cfg.damage_flash_frames)
		_flash_frames[enemy.id] = total
		_flash_totals[enemy.id] = total
		(
			EnemyAnimatorType
			. apply_damage_flash(
				body,
				total,
				total,
				cfg.damage_flash_white,
				cfg.damage_flash_red,
				enemy.def_id,
			)
		)


func age(rects: Dictionary, cfg: JuiceConfig) -> void:
	for enemy_id: int in _flash_frames.keys():
		if not rects.has(enemy_id):
			_flash_frames.erase(enemy_id)
			_flash_totals.erase(enemy_id)
			continue
		var left := int(_flash_frames[enemy_id])
		var total := int(_flash_totals.get(enemy_id, cfg.damage_flash_frames))
		var body := rects[enemy_id] as ColorRect
		var def_id := StringName(body.get_meta(&"enemy_death_def_id", &""))
		if def_id.is_empty():
			def_id = StringName(body.get_meta(&"enemy_def_id", &""))
		(
			EnemyAnimatorType
			. apply_damage_flash(
				body,
				left,
				total,
				cfg.damage_flash_white,
				cfg.damage_flash_red,
				def_id,
			)
		)
		if left > 0:
			_flash_frames[enemy_id] = left - 1
		else:
			_flash_frames.erase(enemy_id)
			_flash_totals.erase(enemy_id)


func animation_seconds(global_seconds: float, enemy_id: int) -> float:
	return global_seconds - float(_anim_paused_seconds.get(enemy_id, 0.0))


func retain_dead(enemy: EnemyState) -> bool:
	return (
		enemy.last_damage_tick > int(_seen_ticks.get(enemy.id, -1))
		or _flash_frames.has(enemy.id)
		or _death_effects.has(enemy.id)
	)


func is_staggered(model: BattleModel, enemy: EnemyState) -> bool:
	return model.tick < enemy.damage_stagger_until_tick
