class_name IncidentData
extends RefCounted
## Special incidents. Triggers live in IncidentManager; this is the text side.

static func all() -> Array[Dictionary]:
	return [
		{"id": "ROOM_SERVICE", "title": "ROOM SERVICE", "zh": "客房服務",
			"desc": "你站著不動太久。房間從天花板送來了沒人點的東西。",
			"notice": "客房服務：您點的物品已送達。（沒有人點）"},
		{"id": "POWER_OUTAGE", "title": "POWER OUTAGE", "zh": "停電",
			"desc": "電器在短時間內被觸發太多次，整棟建築跳電。燈熄了，物理沒有。",
			"notice": "跳電了。燈熄了，但東西還在動。"},
		{"id": "DUPLICATION_ERROR", "title": "DUPLICATION ERROR", "zh": "複製錯誤",
			"desc": "印表機被啟動太多次，開始列印不應該存在的物件副本。",
			"notice": "印表機發生錯誤：正在列印不存在的東西。"},
		{"id": "THE_NEIGHBOR", "title": "THE NEIGHBOR", "zh": "隔壁的人",
			"desc": "在房間記得你、而且一片混亂的時候，牆的另一邊傳來敲擊聲。這棟樓應該沒有隔壁。",
			"notice": "牆的另一邊有人在敲。"},
		{"id": "THE_INSPECTION", "title": "THE INSPECTION", "zh": "例行檢查",
			"desc": "Deviation 進入災難等級時，正常事務部派來沒有五官的檢查員。你必須證明這裡從沒發生過異常。",
			"notice": "正常事務部檢查員到場。請證明這個房間從來沒有發生過異常。"},
	]


static func get_def(id: String) -> Dictionary:
	for d in all():
		if str(d["id"]) == id:
			return d
	return {}
