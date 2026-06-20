extends RefCounted
class_name ForgeBenchMaterialStatePresenter

func reset_material_lookup_cache(cached_material_lookup: Dictionary) -> void:
	cached_material_lookup.clear()

func get_material_lookup(
	forge_controller: ForgeGridController,
	cached_material_lookup: Dictionary
) -> Dictionary:
	if forge_controller == null:
		return {}
	if cached_material_lookup.is_empty():
		cached_material_lookup.merge(forge_controller.build_default_material_lookup(), true)
	return cached_material_lookup

func build_material_catalog(
	material_catalog_presenter: RefCounted,
	forge_controller: ForgeGridController,
	forge_inventory_state: PlayerForgeInventoryState,
	selected_material_variant_id: StringName,
	armed_material_variant_id: StringName,
	material_lookup: Dictionary
) -> Dictionary:
	var material_catalog: Array[Dictionary] = material_catalog_presenter.build_material_catalog(
		forge_controller,
		forge_inventory_state,
		material_lookup
	)
	var selection_state: Dictionary = material_catalog_presenter.reconcile_selection(
		material_catalog,
		selected_material_variant_id,
		armed_material_variant_id
	)
	return {
		"material_catalog": material_catalog,
		"selected_material_variant_id": selection_state.get("selected_material_variant_id", StringName()),
		"armed_material_variant_id": selection_state.get("armed_material_variant_id", StringName()),
	}
