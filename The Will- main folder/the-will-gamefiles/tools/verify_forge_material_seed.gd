extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerControllerScript = preload("res://runtime/player/player_controller.gd")

const REQUIRED_MATERIAL_IDS: Array[StringName] = [
	&"mat_wood_gray",
	&"mat_iron_gray",
	&"mat_bone_gray",
	&"mat_hide_gray",
	&"mat_crystal_gray",
	&"mat_mana_core_gray",
	&"mat_healing_gray",
	&"mat_pyro_gray",
	&"mat_frost_gray",
	&"mat_aqua_gray",
	&"mat_scale_gray",
	&"mat_tendon_gray",
	&"mat_carapace_gray",
	&"mat_silver_gray",
	&"mat_gold_gray",
	&"mat_copper_gray",
]

const EXPECTED_CATALOG_ORDER: Array[StringName] = [
	&"mat_wood_gray",
	&"mat_iron_gray",
	&"mat_bone_gray",
	&"mat_hide_gray",
	&"mat_crystal_gray",
	&"mat_mana_core_gray",
	&"mat_healing_gray",
	&"mat_pyro_gray",
	&"mat_frost_gray",
	&"mat_aqua_gray",
	&"mat_scale_gray",
	&"mat_tendon_gray",
	&"mat_carapace_gray",
	&"mat_silver_gray",
	&"mat_gold_gray",
	&"mat_copper_gray",
]

func _init() -> void:
	var controller: Node = ForgeGridControllerScript.new()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var material_catalog_ids: Array[StringName] = controller.call("get_material_catalog_ids")
	var player: Node = PlayerControllerScript.new()
	var inventory_seed_def: Resource = controller.call("get_inventory_seed_def")
	player.call("ensure_forge_inventory_seeded",
		material_lookup,
		inventory_seed_def,
		controller.get_inventory_seed_quantity(),
		controller.get_inventory_seed_bonus_quantity()
	)
	var inventory_state: PlayerForgeInventoryState = player.get_forge_inventory_state()

	var lines: PackedStringArray = []
	lines.append("material_lookup_count=%d" % material_lookup.size())
	lines.append("material_catalog_count=%d" % material_catalog_ids.size())
	lines.append("material_catalog_ids=%s" % ",".join(PackedStringArray(material_catalog_ids)))
	lines.append("material_catalog_matches_expected=%s" % str(material_catalog_ids == EXPECTED_CATALOG_ORDER))
	lines.append("inventory_seed_entry_count=%d" % (
		inventory_seed_def.entries.size() if inventory_seed_def != null else 0
	))
	lines.append("seeded_stack_count=%d" % inventory_state.material_stacks.size())
	for material_id: StringName in REQUIRED_MATERIAL_IDS:
		lines.append("%s_loaded=%s" % [String(material_id), str(material_lookup.has(material_id))])
		lines.append("%s_quantity=%d" % [String(material_id), inventory_state.get_quantity(material_id)])

	var output: String = "\n".join(lines)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/forge_material_seed_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
		file.close()
	controller.free()
	player.free()
	quit()
