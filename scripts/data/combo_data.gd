class_name ComboData
extends RefCounted
## Physics rule combinations. Each entry lists the rule levels it needs
## (rule -> allowed levels); ComboManager runs the matching effect while all
## requirements hold. Requirements are checked in order, so put the
## more specific (3-rule) combinations first.




static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({
		"id": "BLACK_HOLE", "title": "THE ACCIDENTAL BLACK HOLE", "zh": "意外黑洞",
		"desc": "反重力或低重力＋磁力吸引＋時間加速：房間中央形成會吞噬物件的漩渦，最後爆開。",
		"needs": {RuleDefs.GRAVITY: [RuleDefs.GRAVITY_ANTI, RuleDefs.GRAVITY_LOW], RuleDefs.MAGNETISM: [RuleDefs.MAG_ATTRACT, RuleDefs.MAG_METAL], RuleDefs.TIME: [RuleDefs.TIME_FAST]},
		"color": Color(0.7, 0.3, 1.0),
	})
	out.append({
		"id": "PING_PONG", "title": "THE LAUNDRY UNIVERSE", "zh": "天花板乒乓",
		"desc": "反重力＋高彈性：天花板會把物件彈回地板，物件在兩者之間來回。",
		"needs": {RuleDefs.GRAVITY: [RuleDefs.GRAVITY_ANTI], RuleDefs.BOUNCE: [RuleDefs.BOUNCE_HIGH, RuleDefs.BOUNCE_EXTREME]},
		"color": Color(0.85, 0.65, 1.0),
	})
	out.append({
		"id": "METAL_SOUP", "title": "METAL SOUP", "zh": "金屬濃湯",
		"desc": "磁力＋極滑地板：被吸在一起的物件開始繞著中心旋轉。",
		"needs": {RuleDefs.MAGNETISM: [RuleDefs.MAG_ATTRACT, RuleDefs.MAG_METAL], RuleDefs.FRICTION: [RuleDefs.FRICTION_SLICK]},
		"color": Color(0.4, 1.0, 0.8),
	})
	out.append({
		"id": "GRAVITY_OPTIONAL", "title": "GRAVITY IS OPTIONAL", "zh": "重力是選配",
		"desc": "低重力＋磁力排斥：物件互相推開到半空中，懸浮在離地約一公尺的地方。",
		"needs": {RuleDefs.GRAVITY: [RuleDefs.GRAVITY_LOW], RuleDefs.MAGNETISM: [RuleDefs.MAG_REPEL]},
		"color": Color(0.5, 0.9, 1.0),
	})
	out.append({
		"id": "TEMPORAL_BREAKFAST", "title": "TEMPORAL BREAKFAST", "zh": "時間早餐",
		"desc": "時間加速＋高彈性：每次碰撞都會多送一點能量給被撞的物件。",
		"needs": {RuleDefs.TIME: [RuleDefs.TIME_FAST], RuleDefs.BOUNCE: [RuleDefs.BOUNCE_HIGH, RuleDefs.BOUNCE_EXTREME]},
		"color": Color(1.0, 0.6, 0.3),
	})
	return out


static func matches(def: Dictionary, levels: Array) -> bool:
	var needs: Dictionary = def["needs"]
	for rule: int in needs:
		if not (needs[rule] as Array).has(int(levels[rule])):
			return false
	return true
