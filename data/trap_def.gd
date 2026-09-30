class_name TrapDef
extends Resource

## Trap archetype (all balance is data — architecture rule 4). Traps are the
## GROUND path cells, DP-costed, no refund, no block, no unit slot. ON_ENTER
## traps spend one charge per triggered enemy and are removed at 0 charges;
## CELL_AURA traps (charges -1) are permanent. slow_permille: 500 = -50%.

enum Trigger { ON_ENTER, CELL_AURA }
enum Effect { DAMAGE, SLOW }

const DamageRulesScript := preload("res://sim/damage_rules.gd")

@export var id: StringName = &""
@export var display_name: String = ""
@export var dp_cost: int = 1
@export var trigger: Trigger = Trigger.ON_ENTER
@export var effect: Effect = Effect.DAMAGE
@export var damage: int = 0
@export_enum("Physical", "Arts") var damage_kind: int = DamageRulesScript.Kind.PHYSICAL
@export var slow_permille: int = 0
@export var charges: int = -1
@export var sprite_id: StringName = &""
