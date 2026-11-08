class_name ScoringManager
extends RefCounted
## Turns a shift's statistics into four scores (0-100 each) and points.
## Chaos is only one of four dimensions: breaking things alone never wins.

const WEIGHTS := {"efficiency": 1.0, "creativity": 1.25, "chaos": 1.0, "completion": 1.5}


static func score_shift(s: Dictionary) -> Dictionary:
	var limit: float = s.get("time_limit", 150.0)
	var done: bool = s.get("primary_done", false)
	var used: float = s.get("time_used", limit)
	var eff := 0.0
	if done:
		eff = 100.0 * pow(clampf(1.0 - used / limit, 0.12, 1.0), 0.6)
		var direct := int(s.get("throws", 0)) + int(s.get("grabs", 0))
		eff = clampf(eff + 10.0 - direct * 0.6, 0.0, 100.0)
	var rules_used: int = (s.get("rules_used", {}) as Dictionary).size()
	var creativity := rules_used * 11.0
	# A chain is creative when it travels far (depth) and through devices,
	# not when a pile of objects collides at once.
	creativity += minf(int(s.get("best_depth", 0)), 8) * 6.0
	creativity += minf((s.get("devices_used", {}) as Dictionary).size(), 5) * 6.0
	if done and not bool(s.get("target_grabbed", false)):
		creativity += 18.0
	creativity += minf(int(s.get("combos", 0)), 2) * 6.0
	creativity = clampf(creativity, 0.0, 100.0)
	var chaos := float(s.get("peak_deviation", 0.0)) * 0.45
	chaos += minf(int(s.get("mutations", 0)), 4) * 7.0
	chaos += minf(int(s.get("breaks", 0)), 10) * 1.5
	chaos += minf(int(s.get("chain_links", 0)), 30) * 0.6
	chaos = clampf(chaos, 0.0, 100.0)
	var completion := (70.0 if done else 0.0) + (30.0 if bool(s.get("secondary_done", false)) else 0.0)
	var dims := {"efficiency": eff, "creativity": creativity, "chaos": chaos, "completion": completion}
	var pts := 0.0
	for k: String in WEIGHTS:
		pts += float(dims[k]) * float(WEIGHTS[k])
	dims["points"] = int(round(pts * 10.0))
	return dims


static func grade(avg_points: float) -> String:
	if avg_points >= 3600:
		return "S"
	if avg_points >= 2900:
		return "A"
	if avg_points >= 2200:
		return "B"
	if avg_points >= 1400:
		return "C"
	return "D"


## Chaos Personality: the title that best describes how this run was played.
static func personality(t: Dictionary) -> Dictionary:
	var c := {
		"THE ARCHITECT": float(t.get("completed", 0)) * 25.0 + float(t.get("efficiency", 0)) * 0.5 - float(t.get("breaks", 0)) * 3.0,
		"THE DESTROYER": float(t.get("breaks", 0)) * 6.0 + float(t.get("chaos", 0)) * 0.3,
		"THE ACCIDENTAL GENIUS": float(t.get("best_chain", 0)) * 14.0 - float(t.get("throws", 0)) * 0.8,
		"THE PUPPETEER": float(t.get("pulses", 0)) * 2.0 + float(t.get("indirect", 0)) * 25.0 - float(t.get("grabs", 0)) * 1.0,
		"THE PHYSICIST": float(t.get("rule_changes", 0)) * 3.0 + float(t.get("rules_used", 0)) * 8.0,
		"THE STORM CHASER": float(t.get("cata_time", 0)) * 1.2 + float(t.get("mutations", 0)) * 6.0,
		"THE JUGGLER": float(t.get("throws", 0)) * 2.2,
		"THE BYSTANDER": 40.0 - float(t.get("rule_changes", 0)) * 4.0 - float(t.get("throws", 0)) * 2.0 - float(t.get("pulses", 0)) * 2.0,
	}
	var desc := {
		"THE ARCHITECT": "有計畫、有效率，混亂只是工具。",
		"THE DESTROYER": "你沒有在解謎，你在拆房子。",
		"THE ACCIDENTAL GENIUS": "很少親自動手，卻引發了漂亮的連鎖反應。",
		"THE PUPPETEER": "從不直接碰目標，全靠推與撞。",
		"THE PHYSICIST": "不停改寫物理規則，像在做實驗。",
		"THE STORM CHASER": "主動追著災難跑。",
		"THE JUGGLER": "什麼都想丟丟看。",
		"THE BYSTANDER": "房間在等你做點什麼。",
	}
	var best := "THE BYSTANDER"
	var bv := -99999.0
	for k: String in c:
		if float(c[k]) > bv:
			bv = float(c[k])
			best = k
	return {"title": best, "desc": desc[best]}
