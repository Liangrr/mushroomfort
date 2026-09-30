class_name SkillDef
extends Resource

## Operator active skill (all balance is data — architecture rule 4). One
## skill per operator; SP caps at sp_cost and trigger_skill requires full SP
##   ATK_MULT {mult}   ATK_INTERVAL_MULT {mult}   BLOCK_PLUS {amount}
##   DP_BURST {amount}   SPLASH_RADIUS_PLUS {dim}   STUN_IN_RANGE {stun_ticks, dim}
##   HEAL_TARGET {amount, range_cells}

## Append-only: .tres resources serialize this enum by integer ordinal.
enum Effect {
	ATK_MULT,
	ATK_INTERVAL_MULT,
	BLOCK_PLUS,
	DP_BURST,
	SPLASH_RADIUS_PLUS,
	STUN_IN_RANGE,
	HEAL_TARGET,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var sp_cost: int = 10
@export var duration_ticks: int = 0
@export var effect: Effect = Effect.ATK_MULT
@export var params: Dictionary = {}
