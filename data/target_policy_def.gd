class_name TargetPolicyDef
extends Resource

## Closed, data-owned targeting vocabulary. Runtime compilation and evaluation
## live in Targeting; BattleModel snapshots the compiled primitive dictionary at
## deploy/spawn and never re-reads this Resource during combat.

enum OwnerKind { OPERATOR, ENEMY }
enum CandidateDomain {
	NONE,
	BLOCKED_ENEMY,
	ENEMY_IN_OPERATOR_RANGE,
	CURRENT_BLOCKER,
	BLOCKER_THEN_DEPLOYED_UNIT,
}
enum AerialRule { ANY, EXCLUDE, PREFER }
enum RankKey { ENTITY_ID_ASC, PROGRESS_DESC, DISTANCE_ASC, ENGAGEMENT_ORDER_ASC }

@export var id: StringName = &""
@export var owner_kind: OwnerKind = OwnerKind.OPERATOR
@export var candidate_domain: CandidateDomain = CandidateDomain.NONE
@export var aerial_rule: AerialRule = AerialRule.ANY
@export var primary_rank: RankKey = RankKey.ENTITY_ID_ASC
@export var stable_entity_id_tie_break: bool = false
