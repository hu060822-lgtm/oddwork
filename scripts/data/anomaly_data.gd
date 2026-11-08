class_name AnomalyData
extends RefCounted
## The Anomaly Deck. Add a card by appending one AnomalyDef.make(...) line.

const G := RuleDefs.GRAVITY
const B := RuleDefs.BOUNCE
const M := RuleDefs.MAGNETISM
const F := RuleDefs.FRICTION
const T := RuleDefs.TIME


static func all() -> Array[AnomalyDef]:
	var a: Array[AnomalyDef] = []
	a.append(AnomalyDef.make("ANTI_GRAVITY", "ANTI-GRAVITY", "重力反轉。所有東西慢慢飄向天花板。", Color(0.62, 0.45, 1.0), {G: RuleDefs.GRAVITY_ANTI}, [], []))
	a.append(AnomalyDef.make("RUBBER_WORLD", "RUBBER WORLD", "所有物件變成橡膠般的高彈性。", Color(1.0, 0.82, 0.2), {B: RuleDefs.BOUNCE_HIGH}, [], []))
	a.append(AnomalyDef.make("EVERYTHING_ATTRACTS", "EVERYTHING ATTRACTS", "物件互相吸引，慢慢聚成一團。", Color(0.24, 1.0, 0.42), {M: RuleDefs.MAG_ATTRACT}, [], []))
	a.append(AnomalyDef.make("SLIPPERY_FLOOR", "SLIPPERY FLOOR", "地板幾乎沒有摩擦力。包括你腳下。", Color(0.45, 0.85, 1.0), {F: RuleDefs.FRICTION_SLICK}, [], []))
	a.append(AnomalyDef.make("STRONG_WIND", "STRONG WIND", "室內颳起會轉向的強風。", Color(0.75, 0.9, 0.85), {}, ["wind"], []))
	a.append(AnomalyDef.make("FRAGILE_WORLD", "FRAGILE WORLD", "所有東西都變得很容易碎。", Color(1.0, 0.55, 0.5), {}, ["fragile"], []))
	a.append(AnomalyDef.make("TIME_SICKNESS", "TIME SICKNESS", "時間忽快忽慢，無法預測。", Color(1.0, 0.42, 0.36), {T: RuleDefs.TIME_UNSTABLE}, [], [], "runs_1", "完成 1 局"))
	a.append(AnomalyDef.make("HEAVY_RAIN", "HEAVY RAIN", "室內下起大雨。積水的地板會打滑，物件變滑。", Color(0.4, 0.6, 0.95), {}, ["rain"], [], "mutations_3", "見過 3 種世界突變"))
	a.append(AnomalyDef.make("GIANT_MODE", "GIANT MODE", "所有物件變大、變重。", Color(0.95, 0.7, 0.3), {}, ["size:1.5"], ["MICRO_MODE"], "breaks_15", "累計破壞 15 個物件"))
	a.append(AnomalyDef.make("MICRO_MODE", "MICRO MODE", "所有物件縮小、變輕。", Color(0.6, 0.95, 0.8), {}, ["size:0.6"], ["GIANT_MODE"], "chain_4", "達成 4 段以上的連鎖反應"))
	a.append(AnomalyDef.make("UNSTABLE_STRUCTURE", "UNSTABLE STRUCTURE", "天花板開始掉落，地板偶爾震動。", Color(0.8, 0.6, 0.5), {}, ["structure"], [], "catastrophic", "讓 Deviation 進入災難等級"))
	a.append(AnomalyDef.make("DOUBLE_ANOMALY", "DOUBLE ANOMALY", "同時抽出另外兩張異常。", Color(1.0, 1.0, 1.0), {}, ["double"], [], "runs_3", "完成 3 局"))
	return a


## Named combinations that get a callout and a small Chaos bonus.
static func combos() -> Array[Dictionary]:
	return [
		{"a": "ANTI_GRAVITY", "b": "RUBBER_WORLD", "name": "ZERO-G PINBALL", "zh": "零重力彈珠台"},
		{"a": "EVERYTHING_ATTRACTS", "b": "GIANT_MODE", "name": "BLACK HOLE OFFICE", "zh": "黑洞辦公室"},
		{"a": "SLIPPERY_FLOOR", "b": "STRONG_WIND", "name": "ICE STORM", "zh": "冰風暴"},
		{"a": "FRAGILE_WORLD", "b": "RUBBER_WORLD", "name": "GLASS BOUNCE", "zh": "玻璃彈跳"},
		{"a": "HEAVY_RAIN", "b": "SLIPPERY_FLOOR", "name": "FLOOD ZONE", "zh": "淹水區"},
		{"a": "TIME_SICKNESS", "b": "UNSTABLE_STRUCTURE", "name": "COLLAPSING CLOCK", "zh": "崩塌時鐘"},
		{"a": "ANTI_GRAVITY", "b": "HEAVY_RAIN", "name": "RISING RAIN", "zh": "往上下的雨"},
		{"a": "MICRO_MODE", "b": "STRONG_WIND", "name": "DUST DEVIL", "zh": "塵捲風"},
	]
