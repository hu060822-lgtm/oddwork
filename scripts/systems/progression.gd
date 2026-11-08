class_name ProgressionManager
extends Node
## Long-term progress: unlocks, Disaster Codex, chain hall of fame,
## personality history. Persists through SaveManager.

const UNLOCK_TEXT := {
	"runs_1": "異常卡：TIME SICKNESS",
	"runs_3": "異常卡：DOUBLE ANOMALY",
	"mutations_3": "異常卡：HEAVY RAIN",
	"breaks_15": "異常卡：GIANT MODE",
	"chain_4": "異常卡：MICRO MODE",
	"catastrophic": "異常卡：UNSTABLE STRUCTURE",
	"sideways_gravity": "特殊物理：橫向重力（Q 選單 → 重力）",
	"overcharged_pulse": "特殊物理：超載衝擊波（右鍵威力 +60%）",
}

const DISASTERS := {
	"CATASTROPHIC": ["CATASTROPHIC", "Deviation 進入災難等級。"],
	"MISRULED": ["MISRULED", "你被自己製造的混亂擊倒。"],
	"DEMOLITION": ["DEMOLITION DAY", "一個班次內破壞 10 個以上物件。"],
	"CHAIN_5": ["DOMINO THEORY", "完成 5 段以上的連鎖反應。"],
	"RUBE_GOLDBERG": ["RUBE GOLDBERG", "完成 8 段以上的連鎖反應。"],
	"GLASS_HOUSE": ["GLASS HOUSE", "一個班次內打破所有玻璃。"],
	"PERFECT_SHIFT": ["PERFECT SHIFT", "同一班次完成主要與加分任務。"],
	"HANDS_FREE": ["HANDS FREE", "完全不用手碰就完成任務。"],
	"WATCHED": ["IT IS WATCHING", "房間第一次對你的習慣做出反應。"],
}

var ctx: Node
var saver: SaveManager
var data: Dictionary = {}


static func defaults() -> Dictionary:
	return {
		"version": 1,
		"runs_started": 0, "runs_completed": 0,
		"best_points": 0, "best_grade": "-",
		"total_breaks": 0, "best_chain": 0,
		"unlocks": {},
		"codex": {},
		"chains_hall": [],
		"personalities": {},
		"last_personality": "",
		"observer": {},
		"settings": {"sensitivity": 1.0, "volume": 0.8},
		"incident_counter": 830,
		"last_incident": {},
		"last_comments": [],
	}


func setup(c: Node, save_path: String = "") -> void:
	ctx = c
	saver = SaveManager.new(save_path)
	data = saver.load_data(defaults())
	if saver.last_error != "":
		push_warning("MISRULE: " + saver.last_error)


func save() -> bool:
	return saver.save_data(data)


func unlocks() -> Dictionary:
	return data["unlocks"]


func has_unlock(k: String) -> bool:
	return (data["unlocks"] as Dictionary).has(k)


func codex_count(prefix: String) -> int:
	var n := 0
	for k: String in data["codex"]:
		if k.begins_with(prefix):
			n += 1
	return n


func record(id: String, title: String, desc: String) -> bool:
	var codex: Dictionary = data["codex"]
	if codex.has(id):
		codex[id]["count"] = int(codex[id]["count"]) + 1
		return false
	codex[id] = {"title": title, "desc": desc, "count": 1}
	if ctx:
		ctx.events.codex_unlocked.emit(title)
	return true


func record_disaster(key: String) -> bool:
	var d: Array = DISASTERS[key]
	return record("disaster:" + key, str(d[0]), str(d[1]))


func record_chain(ch: Dictionary) -> void:
	var links := int(ch.get("links", 0))
	data["best_chain"] = maxi(int(data["best_chain"]), links)
	var hall: Array = data["chains_hall"]
	hall.append({"links": links, "text": ChainTracker.describe(ch)})
	hall.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["links"]) > int(b["links"]))
	while hall.size() > 6:
		hall.pop_back()
	if links >= 5:
		record_disaster("CHAIN_5")
	if links >= 8:
		record_disaster("RUBE_GOLDBERG")


## Evaluate unlock conditions. Returns texts of newly unlocked things.
func evaluate_unlocks() -> Array[String]:
	var u: Dictionary = data["unlocks"]
	var new_ones: Array[String] = []
	var conds := {
		"runs_1": int(data["runs_completed"]) >= 1,
		"runs_3": int(data["runs_completed"]) >= 3,
		"sideways_gravity": int(data["runs_completed"]) >= 2,
		"mutations_3": codex_count("mutation:") >= 3,
		"breaks_15": int(data["total_breaks"]) >= 15,
		"chain_4": int(data["best_chain"]) >= 4,
		"overcharged_pulse": int(data["best_chain"]) >= 6,
		"catastrophic": (data["codex"] as Dictionary).has("disaster:CATASTROPHIC"),
	}
	for k: String in conds:
		if conds[k] and not u.has(k):
			u[k] = true
			new_ones.append(str(UNLOCK_TEXT[k]))
	return new_ones
