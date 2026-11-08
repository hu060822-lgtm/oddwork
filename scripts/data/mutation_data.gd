class_name MutationData
extends RefCounted
## World mutations. Each one is a temporary change that opens new options.

static func all() -> Array[Dictionary]:
	return [
		{"id": "GRAVITY_FLIP", "title": "GRAVITY FLIP", "zh": "房間重力反轉", "dur": 12.0, "tier": 2},
		{"id": "BOUNCE_SURGE", "title": "BOUNCE SURGE", "zh": "所有物件彈性暴增", "dur": 15.0, "tier": 2},
		{"id": "ICE_FLOOR", "title": "ICE FLOOR", "zh": "地板變得極度滑溜", "dur": 15.0, "tier": 2},
		{"id": "GALE", "title": "GALE", "zh": "房間內出現強風", "dur": 12.0, "tier": 2},
		{"id": "SIZE_SHIFT", "title": "SIZE SHIFT", "zh": "物件體積隨機變化", "dur": 18.0, "tier": 3},
		{"id": "BRITTLE", "title": "BRITTLE", "zh": "部分物件變得極度脆弱", "dur": 15.0, "tier": 3},
		{"id": "TIME_STUTTER", "title": "TIME STUTTER", "zh": "時間出現不穩定", "dur": 12.0, "tier": 3},
		{"id": "MAGNET_PAIRS", "title": "MAGNET PAIRS", "zh": "特定物件開始互相吸引", "dur": 15.0, "tier": 2},
		{"id": "WRONG_LIGHTS", "title": "WRONG LIGHTS", "zh": "房間燈光異常", "dur": 10.0, "tier": 1},
		{"id": "COLLAPSE", "title": "COLLAPSE", "zh": "房間結構開始不穩定", "dur": 14.0, "tier": 4},
	]
