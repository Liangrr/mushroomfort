class_name DamageRules
extends RefCounted

## Integer-only deterministic damage mitigation. Callers validate authored
## definitions separately; invalid runtime inputs fail closed to zero damage.
## No floats, RNG, wall-clock state, Nodes, Resources, or mutation live here.

enum Kind { PHYSICAL, ARTS }

const VERSION := 1
const MIN_DAMAGE_PERMILLE := 50
const PERMILLE := 1000


static func resolve(
	raw_damage: int,
	damage_kind: int,
	defense: int,
	resistance_permille: int,
) -> int:
	if raw_damage <= 0:
		return 0
	if not valid_kind(damage_kind):
		return 0
	if defense < 0 or not valid_resistance(resistance_permille):
		return 0
	var minimum := _ceil_div(raw_damage, PERMILLE / MIN_DAMAGE_PERMILLE)
	match damage_kind:
		Kind.PHYSICAL:
			return maxi(raw_damage - defense, minimum)
		Kind.ARTS:
			return maxi(
				_mul_div_floor(raw_damage, PERMILLE - resistance_permille, PERMILLE),
				minimum,
			)
	return 0


static func valid_kind(value: int) -> bool:
	return value == Kind.PHYSICAL or value == Kind.ARTS


static func valid_resistance(value: int) -> bool:
	return value >= 0 and value <= PERMILLE


static func authored_values_valid(
	damage_kind: int,
	defense: int,
	resistance_permille: int,
) -> bool:
	return valid_kind(damage_kind) and defense >= 0 and valid_resistance(resistance_permille)


static func _ceil_div(value: int, divisor: int) -> int:
	@warning_ignore("integer_division")
	return value / divisor + (1 if value % divisor != 0 else 0)


static func _mul_div_floor(value: int, factor: int, divisor: int) -> int:
	## Split quotient/remainder so even very large positive integers cannot
	## overflow through value * factor.
	@warning_ignore("integer_division")
	var whole := value / divisor
	var remainder := value % divisor
	@warning_ignore("integer_division")
	return whole * factor + remainder * factor / divisor
