class_name RuleDefs
extends RefCounted
## Static description of the five tamperable physics rules and their levels.

enum { GRAVITY, BOUNCE, MAGNETISM, FRICTION, TIME }

const COUNT := 5
const NAMES: Array[String] = ["GRAVITY", "BOUNCE", "MAGNETISM", "FRICTION", "TIME"]
const NAMES_ZH: Array[String] = ["重力", "彈性", "磁性", "摩擦", "時間"]
const COLORS: Array[Color] = [
	Color(0.62, 0.45, 1.0), Color(1.0, 0.82, 0.2), Color(0.24, 1.0, 0.42),
	Color(0.45, 0.85, 1.0), Color(1.0, 0.42, 0.36)]

# Level names per rule. Level 0 is always the "normal" state.
const LEVELS: Array = [
	["NORMAL", "LOW", "HIGH", "ANTI", "SIDEWAYS"],
	["NORMAL", "HIGH", "EXTREME", "DEAD"],
	["OFF", "ATTRACT", "REPEL", "METAL ONLY"],
	["NORMAL", "SLICK", "STICKY", "PATCHWORK"],
	["NORMAL", "SLOW", "FAST", "UNSTABLE", "POCKETS"],
]
const LEVELS_ZH: Array = [
	["正常", "低重力", "高重力", "反重力", "橫向重力"],
	["正常", "高彈性", "極端彈性", "幾乎不彈"],
	["關閉", "互相吸引", "互相排斥", "只吸金屬"],
	["正常", "極滑", "極黏", "拼布地板"],
	["正常", "慢動作", "加速", "不穩定", "時間氣泡"],
]

# Levels that must be unlocked through progression before they show up.
const LOCKED_LEVELS := {"0:4": "sideways_gravity"}

const GRAVITY_NORMAL := 0
const GRAVITY_LOW := 1
const GRAVITY_HIGH := 2
const GRAVITY_ANTI := 3
const GRAVITY_SIDEWAYS := 4
const BOUNCE_NORMAL := 0
const BOUNCE_HIGH := 1
const BOUNCE_EXTREME := 2
const BOUNCE_DEAD := 3
const MAG_OFF := 0
const MAG_ATTRACT := 1
const MAG_REPEL := 2
const MAG_METAL := 3
const FRICTION_NORMAL := 0
const FRICTION_SLICK := 1
const FRICTION_STICKY := 2
const FRICTION_PATCH := 3
const TIME_NORMAL := 0
const TIME_SLOW := 1
const TIME_FAST := 2
const TIME_UNSTABLE := 3
const TIME_POCKETS := 4


static func level_count(rule: int) -> int:
	return (LEVELS[rule] as Array).size()


static func level_name(rule: int, level: int) -> String:
	return str((LEVELS[rule] as Array)[level])


static func level_name_zh(rule: int, level: int) -> String:
	return str((LEVELS_ZH[rule] as Array)[level])


static func is_locked(rule: int, level: int, unlocks: Dictionary) -> bool:
	var key := "%d:%d" % [rule, level]
	if not LOCKED_LEVELS.has(key):
		return false
	return not unlocks.has(str(LOCKED_LEVELS[key]))
