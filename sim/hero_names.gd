class_name HeroNames
extends RefCounted

const HeroIdentity := preload("res://sim/hero_identity.gd")
const HeroNamesV1 := preload("res://data/names/hero_names_v1.gd")
const VERSION := 1
const D_NAME_FIRST := 4354685564936845355
const D_NAME_LAST := 5348507299053160145
const POSITIVE_MASK := 0x7fffffffffffffff


static func default_name(hero_bits: int, name_version: int = 1) -> Dictionary:
	if name_version != 1:
		return {
			"accepted": false,
			"error_code": &"unsupported_name_version",
		}
	var first_bits := HeroIdentity.splitmix64_bits(hero_bits ^ D_NAME_FIRST)
	var last_bits := HeroIdentity.splitmix64_bits(hero_bits ^ D_NAME_LAST)
	var first_index := int((first_bits & POSITIVE_MASK) % HeroNamesV1.FIRST.size())
	var last_index := int((last_bits & POSITIVE_MASK) % HeroNamesV1.LAST.size())
	return {
		"accepted": true,
		"error_code": &"",
		"value": "%s %s" % [
			HeroNamesV1.FIRST[first_index],
			HeroNamesV1.LAST[last_index],
		],
		"first_index": first_index,
		"last_index": last_index,
	}
