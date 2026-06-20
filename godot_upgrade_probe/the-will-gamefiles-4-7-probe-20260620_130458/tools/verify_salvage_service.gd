extends SceneTree

const PlayerBodyInventoryStateScript = preload("res://core/models/player_body_inventory_state.gd")
const PlayerForgeInventoryStateScript = preload("res://core/models/player_forge_inventory_state.gd")
const StoredItemInstanceScript = preload("res://core/models/stored_item_instance.gd")
const FinalizedItemInstanceScript = preload("res://core/models/finalized_item_instance.gd")
const SalvageServiceScript = preload("res://services/salvage_service.gd")

const OUTPUT_PATH := "c:/WORKSPACE/salvage_service_results.txt"
const TEMP_BODY_SAVE_PATH := "c:/WORKSPACE/tmp_verify_salvage_body_state.tres"
const TEMP_STALE_BODY_SAVE_PATH := "c:/WORKSPACE/tmp_verify_salvage_body_state_stale.tres"

func _init() -> void:
	var salvage_service = SalvageServiceScript.new()
	var body_state = PlayerBodyInventoryStateScript.new()
	var forge_inventory_state = PlayerForgeInventoryStateScript.new()
	body_state.save_file_path = TEMP_BODY_SAVE_PATH

	body_state.owned_items.append(_build_raw_drop_item(&"drop_stack_wood_3", "Wood Raw (Gray)", &"drop_wood_raw_gray", 3))
	body_state.owned_items.append(_build_raw_drop_item(&"drop_stack_iron_2", "Iron Raw (Gray)", &"drop_iron_raw_gray", 2))
	body_state.owned_items.append(_build_finalized_item())

	var available_items: Array[Resource] = salvage_service.call("get_available_disassembly_items", body_state)
	var preview_result = salvage_service.call(
		"build_salvage_preview_from_inventory",
		body_state,
		[&"drop_stack_wood_3", &"drop_stack_iron_2"]
	)
	var finalized_preview = salvage_service.call(
		"build_salvage_preview_from_inventory",
		body_state,
		[&"practice_sword_finalized_1"]
	)
	var unconfirmed_commit = salvage_service.call(
		"commit_salvage_preview",
		body_state,
		forge_inventory_state,
		preview_result,
		false
	)
	var confirmed_commit = salvage_service.call(
		"commit_salvage_preview",
		body_state,
		forge_inventory_state,
		preview_result,
		true
	)

	var stale_body_state = PlayerBodyInventoryStateScript.new()
	var stale_forge_inventory_state = PlayerForgeInventoryStateScript.new()
	stale_body_state.save_file_path = TEMP_STALE_BODY_SAVE_PATH
	stale_body_state.owned_items.append(_build_raw_drop_item(&"drop_stack_stale_wood", "Wood Raw (Gray)", &"drop_wood_raw_gray", 2))
	var stale_preview = salvage_service.call(
		"build_salvage_preview_from_inventory",
		stale_body_state,
		[&"drop_stack_stale_wood"]
	)
	var stale_item = stale_body_state.get_item(&"drop_stack_stale_wood")
	if stale_item != null:
		stale_item.stack_count = 1
	var stale_commit = salvage_service.call(
		"commit_salvage_preview",
		stale_body_state,
		stale_forge_inventory_state,
		stale_preview,
		true
	)

	var lines: PackedStringArray = []
	lines.append("available_item_count=%d" % available_items.size())
	lines.append("available_has_finalized=%s" % str(_contains_item_id(available_items, &"practice_sword_finalized_1")))
	lines.append("preview_valid=%s" % str(preview_result.preview_valid))
	lines.append("preview_supported_count=%d" % preview_result.supported_item_ids.size())
	lines.append("preview_output_stack_count=%d" % preview_result.preview_material_stacks.size())
	lines.append("preview_total_quantity=%d" % preview_result.get_total_preview_quantity())
	lines.append("preview_wood_quantity=%d" % _get_stack_quantity(preview_result.preview_material_stacks, &"mat_wood_gray"))
	lines.append("preview_iron_quantity=%d" % _get_stack_quantity(preview_result.preview_material_stacks, &"mat_iron_gray"))
	lines.append("finalized_preview_valid=%s" % str(finalized_preview.preview_valid))
	lines.append("finalized_preview_failure_reason=%s" % String(finalized_preview.failure_reason))
	lines.append("unconfirmed_commit_applied=%s" % str(unconfirmed_commit.commit_applied))
	lines.append("unconfirmed_commit_failure_reason=%s" % String(unconfirmed_commit.failure_reason))
	lines.append("confirmed_commit_applied=%s" % str(confirmed_commit.commit_applied))
	lines.append("confirmed_commit_failure_reason=%s" % String(confirmed_commit.failure_reason))
	lines.append("body_remaining_item_count=%d" % body_state.get_owned_items().size())
	lines.append("body_remaining_has_wood=%s" % str(body_state.get_item(&"drop_stack_wood_3") != null))
	lines.append("body_remaining_has_iron=%s" % str(body_state.get_item(&"drop_stack_iron_2") != null))
	lines.append("forge_inventory_wood_quantity=%d" % forge_inventory_state.get_quantity(&"mat_wood_gray"))
	lines.append("forge_inventory_iron_quantity=%d" % forge_inventory_state.get_quantity(&"mat_iron_gray"))
	lines.append("stale_commit_applied=%s" % str(stale_commit.commit_applied))
	lines.append("stale_commit_failure_reason=%s" % String(stale_commit.failure_reason))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	_cleanup_temp_file(TEMP_BODY_SAVE_PATH)
	_cleanup_temp_file(TEMP_STALE_BODY_SAVE_PATH)
	quit()

func _build_raw_drop_item(
		item_instance_id: StringName,
		display_name: String,
		raw_drop_id: StringName,
		stack_count: int
	):
	var stored_item = StoredItemInstanceScript.new()
	stored_item.item_instance_id = item_instance_id
	stored_item.item_kind = &"raw_drop"
	stored_item.display_name = display_name
	stored_item.stack_count = stack_count
	stored_item.raw_drop_id = raw_drop_id
	stored_item.is_disassemblable = true
	return stored_item

func _build_finalized_item():
	var finalized_item = FinalizedItemInstanceScript.new()
	finalized_item.finalized_item_id = &"finalized_practice_sword"
	finalized_item.final_item_name = "Practice Sword"
	finalized_item.source_wip_id = &"wip_practice_sword"
	finalized_item.finalized_timestamp = Time.get_unix_time_from_system()

	var stored_item = StoredItemInstanceScript.new()
	stored_item.item_instance_id = &"practice_sword_finalized_1"
	stored_item.item_kind = &"finalized_item"
	stored_item.stack_count = 1
	stored_item.finalized_item = finalized_item
	stored_item.is_disassemblable = true
	return stored_item

func _contains_item_id(items: Array[Resource], item_instance_id: StringName) -> bool:
	for stored_item: Resource in items:
		if stored_item == null:
			continue
		if stored_item.item_instance_id == item_instance_id:
			return true
	return false

func _get_stack_quantity(material_stacks: Array[ForgeMaterialStack], material_variant_id: StringName) -> int:
	for material_stack: ForgeMaterialStack in material_stacks:
		if material_stack == null:
			continue
		if material_stack.material_variant_id == material_variant_id:
			return material_stack.quantity
	return 0

func _cleanup_temp_file(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
