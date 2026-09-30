class_name EnemyDamage
extends RefCounted

## Deterministic mutation seam shared by every EnemyState damage source.
## Returns true only when this hit makes the entity non-living by HP.


static func apply(enemy: EnemyState, damage: int, tick: int, damage_stagger_ticks: int) -> bool:
	if not enemy.alive or damage <= 0:
		return false
	enemy.hp -= damage
	enemy.last_damage_tick = tick
	enemy.damage_stagger_until_tick = maxi(
		enemy.damage_stagger_until_tick, tick + damage_stagger_ticks
	)
	return enemy.hp <= 0
