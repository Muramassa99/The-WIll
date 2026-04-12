extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const ForgeProjectWorkflowScript = preload("res://runtime/forge/forge_project_workflow.gd")
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var forge_controller: ForgeGridController = ForgeGridControllerScript.new()
	get_root().add_child(forge_controller)
	await process_frame
	await process_frame

	var ranged_bow_wip: CraftedItemWIP = forge_controller.load_new_blank_wip_for_builder_path(
		"Ranged Bow Draft",
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL
	)
	var bow_source_text: String = ForgeProjectWorkflowScript.resolve_project_source_text(
		ranged_bow_wip,
		forge_controller,
		null
	)
	var ranged_bow_grid: Vector3i = forge_controller.grid_size

	var ranged_quiver_wip: CraftedItemWIP = forge_controller.load_new_blank_wip_for_builder_path(
		"Ranged Quiver Draft",
		CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL,
		CraftedItemWIP.BUILDER_COMPONENT_QUIVER
	)
	var quiver_source_text: String = ForgeProjectWorkflowScript.resolve_project_source_text(
		ranged_quiver_wip,
		forge_controller,
		null
	)
	var ranged_quiver_grid: Vector3i = forge_controller.grid_size

	var reset_quiver_wip: CraftedItemWIP = ForgeProjectWorkflowScript.reset_active_project(
		forge_controller,
		null,
		"Reset Quiver Draft"
	)
	var reset_quiver_grid: Vector3i = forge_controller.grid_size

	var legacy_ranged_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	legacy_ranged_wip.wip_id = &"legacy_ranged"
	legacy_ranged_wip.forge_project_name = "Legacy Ranged Draft"
	legacy_ranged_wip.forge_builder_path_id = CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL
	legacy_ranged_wip.forge_intent = &"intent_ranged"
	legacy_ranged_wip.equipment_context = &"ctx_weapon"
	forge_controller.load_player_saved_wip(legacy_ranged_wip)
	var legacy_ranged_grid: Vector3i = forge_controller.grid_size

	var lines: PackedStringArray = []
	lines.append("ranged_bow_component=%s" % String(ranged_bow_wip.forge_builder_component_id))
	lines.append("ranged_bow_component_is_default=%s" % str(
		ranged_bow_wip.forge_builder_component_id == CraftedItemWIP.BUILDER_COMPONENT_BOW
	))
	lines.append("ranged_bow_grid=%s" % str(ranged_bow_grid))
	lines.append("bow_source_mentions_bow=%s" % str(
		bow_source_text.to_lower().contains("bow")
	))
	lines.append("ranged_quiver_component=%s" % String(ranged_quiver_wip.forge_builder_component_id))
	lines.append("ranged_quiver_grid=%s" % str(ranged_quiver_grid))
	lines.append("ranged_quiver_grid_is_correct=%s" % str(
		ranged_quiver_wip != null and ranged_quiver_grid == Vector3i(140, 60, 60)
	))
	lines.append("quiver_source_mentions_quiver=%s" % str(
		quiver_source_text.to_lower().contains("quiver")
	))
	lines.append("reset_quiver_grid=%s" % str(reset_quiver_grid))
	lines.append("reset_kept_ranged_quiver=%s" % str(
		reset_quiver_wip != null
		and reset_quiver_wip.forge_builder_path_id == CraftedItemWIP.BUILDER_PATH_RANGED_PHYSICAL
		and reset_quiver_wip.forge_builder_component_id == CraftedItemWIP.BUILDER_COMPONENT_QUIVER
		and reset_quiver_grid == Vector3i(140, 60, 60)
	))
	lines.append("legacy_ranged_grid=%s" % str(legacy_ranged_grid))
	lines.append("legacy_saved_defaulted_to_bow=%s" % str(
		forge_controller.active_wip != null
		and forge_controller.active_wip.forge_builder_component_id == CraftedItemWIP.BUILDER_COMPONENT_BOW
		and legacy_ranged_grid == Vector3i(320, 160, 60)
	))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/ranged_physical_component_foundation_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
