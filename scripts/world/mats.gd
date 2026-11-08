class_name Mats
extends RefCounted
## Shared low-poly materials. Flat colours, no textures: cheap on GL Compatibility.

const BEIGE := Color(0.86, 0.83, 0.72)
const BEIGE_DARK := Color(0.72, 0.68, 0.57)
const GREY := Color(0.52, 0.53, 0.52)
const GREY_DARK := Color(0.30, 0.31, 0.31)
const YELLOW := Color(0.93, 0.76, 0.16)
const RED_DARK := Color(0.50, 0.11, 0.10)
const GREEN_FL := Color(0.24, 1.0, 0.42)
const WOOD := Color(0.62, 0.45, 0.28)
const WOOD_DARK := Color(0.42, 0.29, 0.18)
const METAL := Color(0.62, 0.65, 0.68)
const CARDBOARD := Color(0.71, 0.56, 0.36)
const WHITE := Color(0.94, 0.94, 0.90)

static var _cache: Dictionary = {}


static func solid(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key := "s%s|%.2f|%.2f" % [c.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m


static func glow(c: Color, energy: float = 1.6) -> StandardMaterial3D:
	var key := "g%s|%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func ghost(c: Color) -> StandardMaterial3D:
	var key := "t%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_cache[key] = m
	return m


static func unique(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
