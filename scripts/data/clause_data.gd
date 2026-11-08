class_name ClauseData
extends RefCounted
## Mission clauses ("附加條款") and hidden objectives.
## mode "forbid": starts kept, can be broken during the shift.
## mode "require": starts unmet, must be met before the shift ends.
## excl_types: primary mission types it cannot be attached to.
## needs_target: only for missions that have a target prop.
## excl: other clause ids it may not be combined with.

static func clauses() -> Array[Dictionary]:
	return [
		{"id": "NO_GRAVITY", "mode": "forbid", "zh": "第 4-1 條：不得調整重力。",
			"excl_types": ["ANTIGRAV", "FLOAT"], "excl": []},
		{"id": "NO_JUMP", "mode": "forbid", "zh": "第 7-3 條：值班人員不得跳躍。",
			"excl_types": ["ANTIGRAV"], "excl": []},
		{"id": "NO_FURNITURE", "mode": "forbid", "zh": "第 2-9 條：不得損壞家具與電器。",
			"excl_types": ["SURVIVE"], "excl": []},
		{"id": "NO_GRAB_TARGET", "mode": "forbid", "zh": "第 5-5 條：不得用手接觸目標物件。",
			"excl_types": ["NO_TOUCH"], "needs_target": true, "excl": []},
		{"id": "THREE_RULES", "mode": "require", "zh": "第 1-1 條：本班次須使用至少三種物理規則。",
			"excl_types": [], "excl": []},
		{"id": "NEED_MUTATION", "mode": "require", "zh": "第 3-2 條：須經歷至少一次世界突變。",
			"excl_types": [], "excl": []},
		{"id": "VIA_CHAIN", "mode": "require", "zh": "第 6-6 條：目標須在連鎖反應中完成。",
			"excl_types": ["SURVIVE", "COLLISIONS", "CHAIN_ACTIVATE"], "needs_target": true, "excl": []},
	]


static func hidden() -> Array[Dictionary]:
	return [
		{"id": "H_TV_ON", "zh": "隱藏條款：任務完成時電視是開著的。", "excl_types": []},
		{"id": "H_NO_CUP", "zh": "隱藏條款：整個班次沒有任何杯子摔碎。", "excl_types": ["SURVIVE"]},
		{"id": "H_FEW_RULES", "zh": "隱藏條款：整個班次修改規則不超過 3 次。", "excl_types": ["SURVIVE"]},
		{"id": "H_TARGET_BUMPS", "zh": "隱藏條款：目標物件撞過 3 件不同的物品。", "excl_types": ["SURVIVE", "COLLISIONS", "CHAIN_ACTIVATE", "FLOAT"], "needs_target": true},
	]
