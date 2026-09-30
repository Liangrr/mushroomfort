class_name HealingRules
extends RefCounted

## TD-023 targeted healing rules. Validation is a pure read over BattleModel;
## apply() mutates only after the complete guard passes, preserving the
## reject-with-zero-state-change contract. Campaign death is outside this seam.

const I32_MAX := 2_147_483_647


static func is_valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= 0 and int(value) <= I32_MAX


static func is_valid(model: BattleModel, healer_id: int, target_id: int) -> bool:
	if model.result != BattleModel.Result.RUNNING or healer_id == target_id:
		return false
	var healer := model.unit_by_id(healer_id)
	var target := model.unit_by_id(target_id)
	if healer == null or target == null or not healer.alive or not target.alive:
		return false
	if healer.skill_effect != SkillDef.Effect.HEAL_TARGET or not healer.is_skill_ready():
		return false
	if target.hp <= 0 or target.hp >= target.hp_max:
		return false
	var amount := int(healer.skill_params.get("amount", 0))
	var range_cells := int(healer.skill_params.get("range_cells", -1))
	if amount <= 0 or range_cells < 0:
		return false
	var distance := maxi(
		absi(healer.cell.x - target.cell.x),
		absi(healer.cell.y - target.cell.y),
	)
	return distance <= range_cells


static func apply(model: BattleModel, healer_id: int, target_id: int) -> bool:
	if not is_valid(model, healer_id, target_id):
		return false
	var healer := model.unit_by_id(healer_id)
	var target := model.unit_by_id(target_id)
	var amount := int(healer.skill_params["amount"])
	target.hp = mini(target.hp_max, target.hp + amount)
	healer.sp = 0
	healer.skill_triggered_tick = model.tick
	healer.skill_target_unit_id = target.id
	model.skills_fired += 1
	return true
