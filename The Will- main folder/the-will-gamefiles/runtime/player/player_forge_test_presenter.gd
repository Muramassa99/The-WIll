extends RefCounted
class_name PlayerForgeTestPresenter

func preview_saved_wip_test_status(
	saved_wip_id: StringName,
	wip_library: PlayerForgeWipLibraryState,
	forge_service: ForgeService,
	material_lookup: Dictionary
) -> Dictionary:
	if wip_library == null or saved_wip_id == StringName():
		return {"valid": false, "message": "No saved WIP selected."}
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return {"valid": false, "message": "Saved WIP could not be found."}
	var baked_profile: BakedProfile = forge_service.bake_wip(saved_wip, material_lookup)
	if baked_profile == null:
		return {"valid": false, "message": "Bake did not return a profile."}
	if not baked_profile.primary_grip_valid:
		var failure_text: String = baked_profile.validation_error if not baked_profile.validation_error.is_empty() else "No valid primary grip area yet."
		return {"valid": false, "message": failure_text, "baked_profile": baked_profile}
	return {"valid": true, "message": "Valid primary grip area detected.", "baked_profile": baked_profile}

func preview_saved_wip_grip_hold_layout(
	saved_wip_id: StringName,
	dominant_slot_id: StringName,
	wip_library: PlayerForgeWipLibraryState,
	forge_service: ForgeService,
	material_lookup: Dictionary,
	humanoid_rig: Node3D,
	cell_world_size_meters: float
) -> Dictionary:
	if wip_library == null or saved_wip_id == StringName():
		return {"valid": false, "message": "No saved WIP selected."}
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return {"valid": false, "message": "Saved WIP could not be found."}
	var baked_profile: BakedProfile = forge_service.bake_wip(saved_wip, material_lookup)
	if baked_profile == null:
		return {"valid": false, "message": "Bake did not return a profile."}
	if humanoid_rig == null or not humanoid_rig.has_method("resolve_grip_hold_layout"):
		return {"valid": false, "message": "No humanoid rig grip layout resolver is available.", "baked_profile": baked_profile}
	var layout: Dictionary = humanoid_rig.resolve_grip_hold_layout(
		baked_profile,
		dominant_slot_id,
		cell_world_size_meters
	)
	layout["baked_profile"] = baked_profile
	return layout

func equip_saved_wip_to_hand(
	saved_wip_id: StringName,
	slot_id: StringName,
	wip_library: PlayerForgeWipLibraryState,
	forge_service: ForgeService,
	material_lookup: Dictionary,
	resolved_equipment_state,
	sync_equipped_test_meshes_callback: Callable,
	equipped_item_presenter: PlayerEquippedItemPresenter
) -> Dictionary:
	if slot_id != &"hand_right" and slot_id != &"hand_left":
		return {"success": false, "message": "Only hand slots support forge test equips."}
	if wip_library == null:
		return {"success": false, "message": "No WIP library is available for this character."}
	var saved_wip: CraftedItemWIP = wip_library.get_saved_wip_clone(saved_wip_id)
	if saved_wip == null:
		return {"success": false, "message": "The selected saved WIP could not be found."}
	var status_preview: Dictionary = preview_saved_wip_test_status(
		saved_wip_id,
		wip_library,
		forge_service,
		material_lookup
	)
	if not bool(status_preview.get("valid", false)):
		return {"success": false, "message": String(status_preview.get("message", "The selected WIP is not valid for forge hand testing yet."))}
	if resolved_equipment_state == null:
		return {"success": false, "message": "No equipment state is available for this character."}
	resolved_equipment_state.equip_forge_test_wip(slot_id, saved_wip)
	sync_equipped_test_meshes_callback.call()
	return {
		"success": true,
		"message": "Equipped %s into %s." % [
			equipped_item_presenter.get_saved_wip_display_name(saved_wip),
			String(slot_id).replace("_", " ")
		]
	}

func clear_equipment_slot(
	slot_id: StringName,
	resolved_equipment_state,
	sync_equipped_test_meshes_callback: Callable
) -> void:
	if resolved_equipment_state == null:
		return
	resolved_equipment_state.clear_slot(slot_id)
	sync_equipped_test_meshes_callback.call()

func sync_equipped_test_meshes(
	humanoid_rig: Node3D,
	held_item_nodes: Dictionary,
	resolved_equipment_state,
	wip_library: PlayerForgeWipLibraryState,
	weapons_drawn: bool,
	forge_service: ForgeService,
	material_lookup: Dictionary,
	held_item_mesh_builder: TestPrintMeshBuilder,
	forge_rules: ForgeRulesDef,
	forge_view_tuning: ForgeViewTuningDef,
	equipped_item_presenter: PlayerEquippedItemPresenter
) -> void:
	equipped_item_presenter.sync_equipped_test_meshes(
		humanoid_rig,
		held_item_nodes,
		resolved_equipment_state,
		wip_library,
		weapons_drawn,
		forge_service,
		material_lookup,
		held_item_mesh_builder,
		forge_rules,
		forge_view_tuning
	)

func get_hand_anchor(humanoid_rig: Node3D, slot_id: StringName, equipped_item_presenter: PlayerEquippedItemPresenter) -> Node3D:
	return equipped_item_presenter.get_hand_anchor(humanoid_rig, slot_id)
