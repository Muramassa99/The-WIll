extends RefCounted
class_name ForgeV2MaterialPalette

const DEFAULT_MATERIAL_CATALOG: Resource = preload("res://core/defs/forge/forge_material_catalog_default.tres")
const ForgeV2MaterialTierPolicyScript = preload("res://runtime/forge_v2/forge_v2_material_tier_policy.gd")

const PLACEHOLDER_ICON_PATH := "res://assets/ui_v2/material_placeholder_icon.png"
const DEFAULT_MATERIAL_VARIANT_ID := &"mat_iron_gray"

static func get_material_variant_ids() -> Array[StringName]:
	var material_ids: Array[StringName] = []
	for entry: Resource in _get_catalog_entries():
		if entry == null:
			continue
		var material_id: StringName = StringName(entry.get("material_id"))
		if material_id == StringName():
			continue
		material_ids.append(material_id)
	return material_ids

static func normalize_material_variant_id(material_variant_id: StringName) -> StringName:
	var material_ids: Array[StringName] = get_material_variant_ids()
	if material_ids.has(material_variant_id):
		return material_variant_id
	if material_variant_id == &"iron_gray" and material_ids.has(DEFAULT_MATERIAL_VARIANT_ID):
		return DEFAULT_MATERIAL_VARIANT_ID
	if material_ids.has(DEFAULT_MATERIAL_VARIANT_ID):
		return DEFAULT_MATERIAL_VARIANT_ID
	if material_ids.is_empty():
		return DEFAULT_MATERIAL_VARIANT_ID
	return material_ids[0]

static func get_material_label(material_variant_id: StringName) -> String:
	var normalized_material_id: StringName = normalize_material_variant_id(material_variant_id)
	for entry: Resource in _get_catalog_entries():
		if entry == null or StringName(entry.get("material_id")) != normalized_material_id:
			continue
		return _resolve_display_name(entry)
	return _format_material_id(normalized_material_id)

static func build_palette_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Resource in _get_catalog_entries():
		if entry == null:
			continue
		var material_id: StringName = StringName(entry.get("material_id"))
		if material_id == StringName():
			continue
		var material_def: Resource = entry.get("material_def") as Resource
		entries.append({
			"id": material_id,
			"material_variant_id": material_id,
			"label": _resolve_display_name(entry),
			"short_label": _resolve_short_label(entry),
			"icon_path": PLACEHOLDER_ICON_PATH,
			"tier_id": ForgeV2MaterialTierPolicyScript.extract_tier_id_from_material_variant_id(material_id),
			"albedo_color": _resolve_albedo_color(material_def),
			"material_family": StringName(material_def.get("material_family")) if material_def != null else &"unknown",
		})
	return entries

static func _get_catalog_entries() -> Array[Resource]:
	if DEFAULT_MATERIAL_CATALOG == null:
		return []
	var catalog_entries: Array[Resource] = []
	var raw_entries: Array = DEFAULT_MATERIAL_CATALOG.get("entries") as Array
	for entry_variant: Variant in raw_entries:
		var entry: Resource = entry_variant as Resource
		if entry != null:
			catalog_entries.append(entry)
	return catalog_entries

static func _resolve_display_name(entry: Resource) -> String:
	var material_def: Resource = null
	if entry != null:
		material_def = entry.get("material_def") as Resource
	if material_def != null:
		var display_name: String = String(material_def.get("display_name")).strip_edges()
		if not display_name.is_empty():
			return display_name
	return _format_material_id(StringName(entry.get("material_id")) if entry != null else StringName())

static func _resolve_short_label(entry: Resource) -> String:
	var display_name: String = _resolve_display_name(entry)
	if display_name.length() <= 2:
		return display_name.to_upper()
	return display_name.substr(0, 2).to_upper()

static func _resolve_albedo_color(material_def: Resource) -> Color:
	if material_def == null:
		return Color(0.8, 0.82, 0.84, 1.0)
	var color_value: Variant = material_def.get("albedo_color")
	if color_value is Color:
		return color_value
	return Color(0.8, 0.82, 0.84, 1.0)

static func _format_material_id(material_id: StringName) -> String:
	var text: String = String(material_id)
	text = text.trim_prefix("mat_").trim_suffix("_gray").replace("_", " ")
	return text.capitalize()
