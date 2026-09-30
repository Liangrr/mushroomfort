class_name TrapState
extends RefCounted

## Per-trap authoritative state (architecture rule 1: plain data, no Node).
## Effect fields are resolved once at placement from the TrapDef (same
## pattern as EnemyState.step_units — defs are read once). Exhausted
## ON_ENTER traps are removed from BattleModel.traps entirely, so every
## element of that array is a living trap.

var id: int = 0
var def_id: StringName = &""
var cell: Vector2i = Vector2i.ZERO
var charges_left: int = -1
var trigger: int = 0
var effect: int = 0
var damage: int = 0
var damage_kind: int = 0
var slow_permille: int = 0
var dp_cost: int = 0
# tick of the most recent ON_ENTER trigger (-1 = never) — the sprung frame
# keys off this; on the final charge the trap leaves the model the same
# tick, so callers holding the ref still read the trigger tick
var last_trigger_tick: int = -1
