class_name AnomalyDef
extends Resource
## One card of the Anomaly Deck. Pure data; AnomalyManager interprets it.

@export var id: String = ""
@export var title: String = ""
@export var desc: String = ""
@export var color: Color = Color.WHITE
## rule index -> level applied when the card is played
@export var rules: Dictionary = {}
## free-form effect tags: "rain", "wind", "fragile", "size:1.45", "structure", "double"
@export var effects: PackedStringArray = PackedStringArray()
@export var incompatible: PackedStringArray = PackedStringArray()
## progression key needed before the card can be drawn ("" = always)
@export var unlock_key: String = ""
@export var unlock_hint: String = ""


static func make(p_id: String, p_title: String, p_desc: String, p_color: Color, p_rules: Dictionary, p_effects: Array, p_incompat: Array, p_unlock: String = "", p_hint: String = "") -> AnomalyDef:
	var d := AnomalyDef.new()
	d.id = p_id
	d.title = p_title
	d.desc = p_desc
	d.color = p_color
	d.rules = p_rules
	d.effects = PackedStringArray(p_effects)
	d.incompatible = PackedStringArray(p_incompat)
	d.unlock_key = p_unlock
	d.unlock_hint = p_hint
	return d
