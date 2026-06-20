extends RefCounted
class_name ForgeMaterialLookupPresenter

func build_runtime_material_lookup(
	material_catalog_def: Resource,
	default_material_tier_def: Resource,
	material_defs_root_dir: String,
	forge_service: ForgeService
) -> Dictionary:
	var material_lookup: Dictionary = {}
	_collect_catalog_material_defs(material_lookup, material_catalog_def, default_material_tier_def, forge_service)
	_collect_material_defs_in_dir(material_defs_root_dir, material_lookup)
	return material_lookup

func build_ordered_material_ids(
	material_lookup: Dictionary,
	material_catalog_def: Resource,
	default_material_tier_def: Resource,
	forge_service: ForgeService
) -> Array[StringName]:
	var ordered_ids: Array[StringName] = []
	var has_authored_catalog: bool = false
	if material_catalog_def != null and not material_catalog_def.is_empty():
		has_authored_catalog = true
		for catalog_entry: Resource in material_catalog_def.entries:
			var base_material: BaseMaterialDef = _resolve_catalog_entry_material_def(catalog_entry)
			var material_id: StringName = _resolve_catalog_entry_material_id(catalog_entry, base_material, default_material_tier_def, forge_service)
			if material_id == StringName() or ordered_ids.has(material_id):
				continue
			if base_material != null and not material_lookup.has(material_id):
				material_lookup[material_id] = base_material
			if material_lookup.has(material_id):
				ordered_ids.append(material_id)
	if has_authored_catalog and not ordered_ids.is_empty():
		return ordered_ids

	var discovered_material_ids: Array = material_lookup.keys()
	discovered_material_ids.sort()
	for material_id_value in discovered_material_ids:
		var material_id: StringName = material_id_value
		if ordered_ids.has(material_id):
			continue
		ordered_ids.append(material_id)
	return ordered_ids

func _collect_catalog_material_defs(
	material_lookup: Dictionary,
	material_catalog_def: Resource,
	default_material_tier_def: Resource,
	forge_service: ForgeService
) -> void:
	if material_catalog_def == null or material_catalog_def.is_empty():
		return
	for catalog_entry: Resource in material_catalog_def.entries:
		var base_material: BaseMaterialDef = _resolve_catalog_entry_material_def(catalog_entry)
		var material_id: StringName = _resolve_catalog_entry_material_id(catalog_entry, base_material, default_material_tier_def, forge_service)
		var material_variant: MaterialVariantDef = _build_catalog_material_variant(base_material, default_material_tier_def, forge_service)
		if base_material == null:
			continue
		material_lookup[base_material.base_material_id] = base_material
		if material_variant != null:
			material_lookup[material_variant.variant_id] = material_variant
		if material_id != StringName() and material_lookup.has(material_id):
			continue
		if material_id != StringName():
			if material_variant != null:
				material_lookup[material_id] = material_variant
			else:
				material_lookup[material_id] = base_material

func _resolve_catalog_entry_material_def(catalog_entry: Resource) -> BaseMaterialDef:
	if catalog_entry == null:
		return null
	return catalog_entry.material_def as BaseMaterialDef

func _resolve_catalog_entry_material_id(
	catalog_entry: Resource,
	base_material: BaseMaterialDef,
	default_material_tier_def: Resource,
	forge_service: ForgeService
) -> StringName:
	var material_variant: MaterialVariantDef = _build_catalog_material_variant(base_material, default_material_tier_def, forge_service)
	if catalog_entry != null and catalog_entry.material_id != StringName():
		if base_material != null and material_variant != null and catalog_entry.material_id == base_material.base_material_id:
			return material_variant.variant_id
		return catalog_entry.material_id
	if material_variant != null:
		return material_variant.variant_id
	if base_material != null:
		return base_material.base_material_id
	return StringName()

func _build_catalog_material_variant(
	base_material: BaseMaterialDef,
	default_material_tier_def: Resource,
	forge_service: ForgeService
) -> MaterialVariantDef:
	var default_tier: TierDef = default_material_tier_def as TierDef
	if base_material == null or default_tier == null:
		return null
	return forge_service.build_material_variant(base_material, default_tier)

func _collect_material_defs_in_dir(directory_path: String, material_lookup: Dictionary) -> void:
	if directory_path.is_empty():
		return
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var entry_name: String = directory.get_next()
		if entry_name.is_empty():
			break
		if entry_name.begins_with("."):
			continue
		var entry_path: String = "%s/%s" % [directory_path, entry_name]
		if directory.current_is_dir():
			_collect_material_defs_in_dir(entry_path, material_lookup)
			continue
		if not entry_name.ends_with(".tres"):
			continue
		var base_material: BaseMaterialDef = load(entry_path) as BaseMaterialDef
		if base_material == null:
			continue
		if base_material.base_material_id == StringName():
			continue
		material_lookup[base_material.base_material_id] = base_material
	directory.list_dir_end()
