class_name OperatorDef
extends Resource

## Operator archetype (all balance is data — architecture rule 4). Full schema

## Append-only: .tres resources serialize this enum by integer ordinal.
enum OpClass { VANGUARD, GUARD, DEFENDER, SNIPER, CASTER, HEALER, RECRUIT }
enum Placement { GROUND, ELEVATED }
const TargetPolicyDefScript := preload("res://data/target_policy_def.gd")
const DamageRulesScript := preload("res://sim/damage_rules.gd")

@export var id: StringName = &""
@export var display_name: String = ""
@export var op_class: OpClass = OpClass.GUARD
@export var rarity: int = 1
@export var dp_cost: int = 10
@export var block: int = 1
@export var hp: int = 100
@export var atk: int = 10
@export var defense: int = 0
@export_range(0, 1000) var resistance_permille: int = 0
@export_enum("Physical", "Arts") var attack_damage_kind: int = DamageRulesScript.Kind.PHYSICAL
@export var atk_interval_ticks: int = 30
@export var range_offsets: Array[Vector2i] = []
@export var target_policy: TargetPolicyDefScript = null
@export var placement: Placement = Placement.GROUND
@export var dp_generation_interval_ticks: int = 0
## square splash side length for basic attacks; 0 = single target (P14:
## moved out of unit_state logic — rule 4)
@export var splash_dim: int = 0
@export var skill: SkillDef = null
@export var sprite_id: StringName = &""
@export var portrait_id: StringName = &""
