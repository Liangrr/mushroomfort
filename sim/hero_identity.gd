class_name HeroIdentity
extends RefCounted

## Pure P16 identity arithmetic. Signed Godot ints carry unsigned 64-bit bits;
## formatting/parsing never route through JSON numbers.

const SM_GAMMA := -7046029254386353131
const SM_M1 := -4658895280553007687
const SM_M2 := -7723592293110705685
const D_CAMPAIGN := 1279209098695240241
const D_HERO := 2870177450012600261
const HEX := "0123456789abcdef"
const MAX_COLLISION_ORDINAL := 31


static func logical_shift_right(value: int, bits: int) -> int:
	assert(bits > 0 and bits < 64)
	return (value >> bits) & ((1 << (64 - bits)) - 1)


static func splitmix64_bits(value: int) -> int:
	var mixed := value + SM_GAMMA
	mixed = (mixed ^ logical_shift_right(mixed, 30)) * SM_M1
	mixed = (mixed ^ logical_shift_right(mixed, 27)) * SM_M2
	return mixed ^ logical_shift_right(mixed, 31)


static func format_u64_hex(bits: int) -> String:
	var text := ""
	for shift: int in range(60, -1, -4):
		text += HEX[(bits >> shift) & 0xF]
	return text


static func parse_u64_hex(text: String) -> Dictionary:
	if text.length() != 16:
		return _reject(&"invalid_hex_length")
	var bits := 0
	for index: int in 16:
		var digit := HEX.find(text.substr(index, 1))
		if digit < 0:
			return _reject(&"invalid_hex_character")
		bits = (bits << 4) | digit
	return {
		"accepted": true,
		"error_code": &"",
		"bits": bits,
	}


static func campaign_uid_bits(seed_value: int, generation: int) -> int:
	return splitmix64_bits(splitmix64_bits(seed_value ^ D_CAMPAIGN) ^ generation)


static func campaign_uid(seed_value: int, generation: int) -> String:
	return format_u64_hex(campaign_uid_bits(seed_value, generation))


static func hero_bits(
	seed_value: int,
	generation: int,
	recruitment_index: int,
	collision_ordinal: int,
) -> int:
	var bits := splitmix64_bits(seed_value ^ D_HERO)
	bits = splitmix64_bits(bits ^ generation)
	bits = splitmix64_bits(bits ^ recruitment_index)
	return splitmix64_bits(bits ^ collision_ordinal)


static func hero_id(
	seed_value: int,
	generation: int,
	recruitment_index: int,
	collision_ordinal: int = 0,
) -> String:
	return format_u64_hex(hero_bits(
		seed_value,
		generation,
		recruitment_index,
		collision_ordinal,
	))


static func allocate_hero_id(
	seed_value: int,
	generation: int,
	recruitment_index: int,
	is_taken: Callable,
) -> Dictionary:
	if generation < 1 or recruitment_index < 0 or not is_taken.is_valid():
		return _reject(&"invalid_identity_request")
	for ordinal: int in MAX_COLLISION_ORDINAL + 1:
		var bits := hero_bits(seed_value, generation, recruitment_index, ordinal)
		var candidate := format_u64_hex(bits)
		if not bool(is_taken.call(candidate)):
			return {
				"accepted": true,
				"error_code": &"",
				"hero_id": candidate,
				"bits": bits,
				"collision_ordinal": ordinal,
			}
	return _reject(&"id_collision_exhausted")


static func _reject(error_code: StringName) -> Dictionary:
	return {
		"accepted": false,
		"error_code": error_code,
	}
