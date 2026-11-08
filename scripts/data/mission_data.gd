class_name MissionData
extends RefCounted
## Mission templates. MissionManager fills in targets/zones and validates.
## difficulty: rough 1-5 rating before modifiers.

static func all() -> Array[Dictionary]:
	return [
		{"type": "DELIVER", "title": "DELIVERY", "difficulty": 1, "stages": [1, 2, 3],
			"text": "把 %s 送到 %s", "hint": "抓起來搬、丟過去、或讓它自己滾過去都可以。"},
		{"type": "COLLISIONS", "title": "PERCUSSION", "difficulty": 1, "stages": [1, 2],
			"text": "讓 %s 發生 %d 次有力的碰撞", "hint": "高彈性、磁性、風扇都會幫忙。"},
		{"type": "FLOAT", "title": "LEVITATION", "difficulty": 2, "stages": [1, 2, 3],
			"text": "讓 %d 個物件同時漂浮在空中 %d 秒", "hint": "反重力、低重力、彈簧、時間氣泡。"},
		{"type": "NO_TOUCH", "title": "HANDS OFF", "difficulty": 3, "stages": [2, 3],
			"text": "不用手碰，把 %s 送到 %s", "hint": "推、撞、風扇、磁性、改重力方向。"},
		{"type": "ANTIGRAV", "title": "UPWARD DELIVERY", "difficulty": 3, "stages": [2, 3],
			"text": "在反重力狀態下，把 %s 送到 %s", "hint": "按 Q 開啟反重力，再把它帶到天花板的目標區。"},
		{"type": "CHAIN_ACTIVATE", "title": "RUBE GOLDBERG", "difficulty": 3, "stages": [2, 3],
			"text": "透過至少 %d 段連鎖反應啟動 %s", "hint": "不能直接按。讓別的東西撞上去。"},
		{"type": "BALANCE", "title": "STEADY HAND", "difficulty": 2, "stages": [1, 2, 3],
			"text": "讓 %s 在 %s 上連續停留 %d 秒", "hint": "高摩擦、低彈性、或乾脆用磁性吸住。"},
		{"type": "SURVIVE", "title": "END OF THE WORLD", "difficulty": 4, "stages": [3],
			"text": "讓 Deviation 達到 84（災難等級），然後撐過 %d 秒", "hint": "同時扭曲多條規則並持續出手，房間自己亂只能撐到一半。"},
	]
