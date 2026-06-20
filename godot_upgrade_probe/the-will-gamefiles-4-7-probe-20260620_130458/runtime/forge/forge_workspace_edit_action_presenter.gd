extends RefCounted
class_name ForgeWorkspaceEditActionPresenter

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

func place_material_cell(
	forge_controller: ForgeGridController,
	inventory_state: PlayerForgeInventoryState,
	armed_material_variant_id: StringName,
	grid_position: Vector3i,
	ensure_wip_for_editing: Callable
) -> Dictionary:
	if forge_controller == null or armed_material_variant_id == StringName():
		return {
			"debug_status_dirty": true,
		}
	var current_wip: CraftedItemWIP = ensure_wip_for_editing.call()
	if current_wip == null:
		return {}
	return _place_material_cell_to_wip(
		forge_controller,
		inventory_state,
		current_wip,
		armed_material_variant_id,
		grid_position
	)

func apply_material_cells(
	forge_controller: ForgeGridController,
	inventory_state: PlayerForgeInventoryState,
	armed_material_variant_id: StringName,
	grid_positions: Array[Vector3i],
	ensure_wip_for_editing: Callable
) -> Dictionary:
	if forge_controller == null or armed_material_variant_id == StringName():
		return {
			"debug_status_dirty": true,
		}
	var current_wip: CraftedItemWIP = ensure_wip_for_editing.call()
	if current_wip == null:
		return {}
	var unique_positions: Array[Vector3i] = _dedupe_grid_positions(grid_positions)
	if unique_positions.is_empty():
		return {}
	if CraftedItemWIPScript.is_builder_marker_material_id(armed_material_variant_id):
		var any_builder_refresh: bool = false
		var any_builder_debug_status_dirty: bool = false
		for grid_position: Vector3i in unique_positions:
			var builder_result: Dictionary = _place_material_cell_to_wip(
				forge_controller,
				inventory_state,
				current_wip,
				armed_material_variant_id,
				grid_position
			)
			any_builder_refresh = any_builder_refresh or bool(builder_result.get("queue_edit_refresh", false))
			any_builder_debug_status_dirty = any_builder_debug_status_dirty or bool(builder_result.get("debug_status_dirty", false))
		return {
			"queue_edit_refresh": any_builder_refresh,
			"debug_status_dirty": any_builder_debug_status_dirty,
		}
	var any_refresh: bool = false
	var any_debug_status_dirty: bool = false
	var positions_to_apply: Array[Vector3i] = []
	var refund_counts: Dictionary = {}
	var requires_inventory: bool = _is_inventory_backed_material(armed_material_variant_id)
	var available_quantity: int = 0
	if requires_inventory:
		if inventory_state == null:
			return {
				"queue_edit_refresh": true,
				"debug_status_dirty": true,
			}
		available_quantity = inventory_state.get_quantity(armed_material_variant_id)
	for grid_position: Vector3i in unique_positions:
		var existing_material_id: StringName = forge_controller.get_material_id_at(grid_position)
		if existing_material_id == armed_material_variant_id:
			continue
		if requires_inventory:
			if available_quantity <= 0:
				any_refresh = true
				any_debug_status_dirty = true
				continue
			available_quantity -= 1
		positions_to_apply.append(grid_position)
		if _is_inventory_backed_material(existing_material_id) and existing_material_id != armed_material_variant_id:
			refund_counts[existing_material_id] = int(refund_counts.get(existing_material_id, 0)) + 1
	if positions_to_apply.is_empty():
		return {
			"queue_edit_refresh": any_refresh,
			"debug_status_dirty": any_debug_status_dirty,
		}
	if requires_inventory and not inventory_state.try_consume(armed_material_variant_id, positions_to_apply.size()):
		return {
			"queue_edit_refresh": true,
			"debug_status_dirty": true,
		}
	for refund_material_id_variant: Variant in refund_counts.keys():
		var refund_material_id: StringName = refund_material_id_variant
		_refund_inventory_material(inventory_state, refund_material_id, int(refund_counts.get(refund_material_id, 0)))
	var changed_count: int = forge_controller.set_materials_at(positions_to_apply, armed_material_variant_id)
	any_refresh = any_refresh or changed_count > 0
	return {
		"queue_edit_refresh": any_refresh,
		"debug_status_dirty": any_debug_status_dirty,
	}

func remove_cells(
	forge_controller: ForgeGridController,
	inventory_state: PlayerForgeInventoryState,
	grid_positions: Array[Vector3i]
) -> Dictionary:
	if forge_controller == null:
		return {}
	var unique_positions: Array[Vector3i] = _dedupe_grid_positions(grid_positions)
	if unique_positions.is_empty():
		return {}
	var any_refresh: bool = false
	var material_positions: Array[Vector3i] = []
	for grid_position: Vector3i in unique_positions:
		var removed_builder_marker_id: StringName = forge_controller.clear_builder_marker_at(grid_position)
		if removed_builder_marker_id != StringName():
			any_refresh = true
			continue
		material_positions.append(grid_position)
	var removal_result: Dictionary = forge_controller.remove_materials_at(material_positions)
	var removed_count: int = int(removal_result.get("removed_count", 0))
	var removed_counts: Dictionary = removal_result.get("removed_counts", {})
	for removed_material_id_variant: Variant in removed_counts.keys():
		var removed_material_id: StringName = removed_material_id_variant
		_refund_inventory_material(
			inventory_state,
			removed_material_id,
			int(removed_counts.get(removed_material_id, 0))
		)
	any_refresh = any_refresh or removed_count > 0
	return {
		"queue_edit_refresh": any_refresh,
	}

func _place_material_cell_to_wip(
	forge_controller: ForgeGridController,
	inventory_state: PlayerForgeInventoryState,
	current_wip: CraftedItemWIP,
	armed_material_variant_id: StringName,
	grid_position: Vector3i
) -> Dictionary:
	if CraftedItemWIPScript.is_builder_marker_material_id(armed_material_variant_id):
		return _place_builder_marker_cell(
			forge_controller,
			current_wip,
			armed_material_variant_id,
			grid_position
		)
	var existing_material_id: StringName = forge_controller.get_material_id_at(grid_position)
	if existing_material_id == armed_material_variant_id:
		return {}
	if not _try_apply_inventory_swap(inventory_state, existing_material_id, armed_material_variant_id):
		return {
			"queue_edit_refresh": true,
		}
	forge_controller.set_material_at(grid_position, armed_material_variant_id)
	return {
		"queue_edit_refresh": true,
	}

func remove_cell(
	forge_controller: ForgeGridController,
	inventory_state: PlayerForgeInventoryState,
	grid_position: Vector3i
) -> Dictionary:
	if forge_controller == null:
		return {}
	var removed_builder_marker_id: StringName = forge_controller.clear_builder_marker_at(grid_position)
	if removed_builder_marker_id != StringName():
		return {
			"queue_edit_refresh": true,
		}
	var removed_material_id: StringName = forge_controller.remove_material_at(grid_position)
	if removed_material_id == StringName():
		return {}
	_refund_inventory_material(inventory_state, removed_material_id, 1)
	return {
		"queue_edit_refresh": true,
	}

func pick_material_from_grid(
	forge_controller: ForgeGridController,
	material_catalog: Array[Dictionary],
	grid_position: Vector3i
) -> Dictionary:
	if forge_controller == null:
		return {}
	var material_id: StringName = forge_controller.get_pickable_material_id_at(grid_position)
	if material_id == StringName():
		return {}
	var entry: Dictionary = _get_material_entry(material_catalog, material_id)
	return {
		"selected_material_variant_id": material_id,
		"armed_material_variant_id": material_id if int(entry.get("quantity", 0)) > 0 or bool(entry.get("is_placeable_without_inventory", false)) else StringName(),
	}

func pick_material_from_screen_position(
	free_workspace_preview: ForgeWorkspacePreview,
	forge_controller: ForgeGridController,
	material_catalog: Array[Dictionary],
	screen_position: Vector2
) -> Dictionary:
	if not is_instance_valid(free_workspace_preview):
		return {}
	var grid_position_variant: Variant = free_workspace_preview.screen_to_grid(screen_position)
	if grid_position_variant == null:
		return {}
	return pick_material_from_grid(forge_controller, material_catalog, grid_position_variant)

func _try_apply_inventory_swap(
	inventory_state: PlayerForgeInventoryState,
	refund_material_id: StringName,
	consume_material_id: StringName
) -> bool:
	if consume_material_id == StringName() or not _is_inventory_backed_material(consume_material_id):
		return true
	if inventory_state == null:
		return false
	if _is_inventory_backed_material(refund_material_id) and refund_material_id != consume_material_id:
		inventory_state.add_quantity(refund_material_id, 1)
	if inventory_state.try_consume(consume_material_id, 1):
		return true
	if _is_inventory_backed_material(refund_material_id) and refund_material_id != consume_material_id:
		inventory_state.try_consume(refund_material_id, 1)
	return false

func _refund_inventory_material(
	inventory_state: PlayerForgeInventoryState,
	material_id: StringName,
	amount: int
) -> void:
	if not _is_inventory_backed_material(material_id) or amount <= 0 or inventory_state == null:
		return
	inventory_state.add_quantity(material_id, amount)

func _place_builder_marker_cell(
	forge_controller: ForgeGridController,
	current_wip: CraftedItemWIP,
	builder_marker_material_id: StringName,
	grid_position: Vector3i
) -> Dictionary:
	if current_wip == null:
		return {}
	var existing_marker_position_variant: Variant = CraftedItemWIPScript.get_builder_marker_position(current_wip, builder_marker_material_id)
	if existing_marker_position_variant is Vector3i and existing_marker_position_variant == grid_position:
		return {}
	if not forge_controller.set_builder_marker_at(grid_position, builder_marker_material_id):
		return {}
	return {
		"queue_edit_refresh": true,
	}

func _get_material_entry(material_catalog: Array[Dictionary], material_id: StringName) -> Dictionary:
	for entry: Dictionary in material_catalog:
		if entry.get("material_id", &"") == material_id:
			return entry
	return {}

func _is_inventory_backed_material(material_id: StringName) -> bool:
	return material_id != StringName() and not CraftedItemWIPScript.is_builder_marker_material_id(material_id)

func _dedupe_grid_positions(grid_positions: Array[Vector3i]) -> Array[Vector3i]:
	var unique_positions: Array[Vector3i] = []
	var visited: Dictionary = {}
	for grid_position: Vector3i in grid_positions:
		if visited.has(grid_position):
			continue
		visited[grid_position] = true
		unique_positions.append(grid_position)
	return unique_positions
