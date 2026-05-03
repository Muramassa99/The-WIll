extends Resource
class_name CraftedItemWIP

const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")

const BUILDER_PATH_MELEE := &"builder_path_melee"
const BUILDER_PATH_RANGED_PHYSICAL := &"builder_path_ranged_physical"
const BUILDER_PATH_SHIELD := &"builder_path_shield"
const BUILDER_PATH_MAGIC := &"builder_path_magic"
const BUILDER_COMPONENT_PRIMARY := &"builder_component_primary"
const BUILDER_COMPONENT_BOW := &"builder_component_bow"
const BUILDER_COMPONENT_QUIVER := &"builder_component_quiver"
const STRING_ANCHOR_PAIR_A := &"a"
const STRING_ANCHOR_PAIR_B := &"b"
const STRING_ANCHOR_PAIR_C := &"c"
const STRING_ANCHOR_PAIR_D := &"d"
const STRING_ANCHOR_PAIR_E := &"e"
const STRING_ANCHOR_PAIR_F := &"f"
const STOW_SHOULDER_HANGING := &"stow_shoulder_hanging"
const STOW_SIDE_HIP := &"stow_side_hip"
const STOW_LOWER_BACK := &"stow_lower_back"
const GRIP_NORMAL := &"grip_normal"
const GRIP_REVERSE := &"grip_reverse"
const UNARMED_AUTHORING_WIP_ID := &"__unarmed_authoring__"
const FORGE_INTENT_UNARMED := &"intent_unarmed"
const EQUIPMENT_CONTEXT_UNARMED := &"ctx_unarmed"

@export var wip_id: StringName = &""
@export var forge_project_name: String = ""
@export_multiline var forge_project_notes: String = ""
@export var creator_id: StringName = &""
@export var created_timestamp: float = 0.0
@export var forge_builder_path_id: StringName = BUILDER_PATH_MELEE
@export var forge_builder_component_id: StringName = BUILDER_COMPONENT_PRIMARY
@export var builder_marker_positions: Dictionary = {}
@export var stage2_item_state: Resource
@export var combat_animation_station_state: Resource
@export var forge_intent: StringName = &""
@export var equipment_context: StringName = &""
@export var stow_position_mode: StringName = STOW_SHOULDER_HANGING
@export var grip_style_mode: StringName = GRIP_NORMAL
@export var layers: Array[LayerAtom] = []
@export var latest_baked_profile_snapshot: BakedProfile

static func get_builder_path_ids() -> Array[StringName]:
	return [
		BUILDER_PATH_MELEE,
		BUILDER_PATH_RANGED_PHYSICAL,
		BUILDER_PATH_SHIELD,
		BUILDER_PATH_MAGIC
	]

static func normalize_builder_path_id(builder_path_id: StringName) -> StringName:
	if get_builder_path_ids().has(builder_path_id):
		return builder_path_id
	return BUILDER_PATH_MELEE

static func get_builder_path_label(builder_path_id: StringName) -> String:
	match normalize_builder_path_id(builder_path_id):
		BUILDER_PATH_RANGED_PHYSICAL:
			return "Ranged Physical Weapon"
		BUILDER_PATH_SHIELD:
			return "Shield"
		BUILDER_PATH_MAGIC:
			return "Magic Weapon"
		_:
			return "Melee Weapon"

static func get_builder_component_ids(builder_path_id: StringName) -> Array[StringName]:
	match normalize_builder_path_id(builder_path_id):
		BUILDER_PATH_RANGED_PHYSICAL:
			return [
				BUILDER_COMPONENT_BOW,
				BUILDER_COMPONENT_QUIVER
			]
		_:
			return [BUILDER_COMPONENT_PRIMARY]

static func has_multiple_builder_components(builder_path_id: StringName) -> bool:
	return get_builder_component_ids(builder_path_id).size() > 1

static func get_default_builder_component_id(builder_path_id: StringName) -> StringName:
	match normalize_builder_path_id(builder_path_id):
		BUILDER_PATH_RANGED_PHYSICAL:
			return BUILDER_COMPONENT_BOW
		_:
			return BUILDER_COMPONENT_PRIMARY

static func normalize_builder_component_id(builder_path_id: StringName, builder_component_id: StringName) -> StringName:
	var supported_component_ids: Array[StringName] = get_builder_component_ids(builder_path_id)
	if supported_component_ids.has(builder_component_id):
		return builder_component_id
	return get_default_builder_component_id(builder_path_id)

static func get_builder_component_label(builder_path_id: StringName, builder_component_id: StringName) -> String:
	match normalize_builder_component_id(builder_path_id, builder_component_id):
		BUILDER_COMPONENT_BOW:
			return "Bow"
		BUILDER_COMPONENT_QUIVER:
			return "Quiver"
		_:
			return "Primary"

static func get_builder_scope_label(builder_path_id: StringName, builder_component_id: StringName) -> String:
	var normalized_builder_path_id: StringName = normalize_builder_path_id(builder_path_id)
	var builder_path_label: String = get_builder_path_label(normalized_builder_path_id)
	if not has_multiple_builder_components(normalized_builder_path_id):
		return builder_path_label
	return "%s / %s" % [
		builder_path_label,
		get_builder_component_label(normalized_builder_path_id, builder_component_id)
	]

static func is_ranged_bow_builder_component(builder_path_id: StringName, builder_component_id: StringName) -> bool:
	return (
		normalize_builder_path_id(builder_path_id) == BUILDER_PATH_RANGED_PHYSICAL
		and normalize_builder_component_id(builder_path_id, builder_component_id) == BUILDER_COMPONENT_BOW
	)

static func get_string_anchor_pair_ids() -> Array[StringName]:
	return [
		STRING_ANCHOR_PAIR_A,
		STRING_ANCHOR_PAIR_B,
		STRING_ANCHOR_PAIR_C,
		STRING_ANCHOR_PAIR_D,
		STRING_ANCHOR_PAIR_E,
		STRING_ANCHOR_PAIR_F,
	]

static func get_string_anchor_builder_marker_id(pair_id: StringName, endpoint_index: int) -> StringName:
	var normalized_pair_id: StringName = _normalize_string_anchor_pair_id(pair_id)
	var normalized_endpoint_index: int = 1 if endpoint_index <= 1 else 2
	return StringName("builder_marker_string_anchor_%s%d" % [
		String(normalized_pair_id),
		normalized_endpoint_index
	])

static func is_builder_marker_material_id(material_id: StringName) -> bool:
	return String(material_id).begins_with("builder_marker_")

static func is_string_anchor_builder_marker_id(material_id: StringName) -> bool:
	return String(material_id).begins_with("builder_marker_string_anchor_")

static func get_string_anchor_pair_id_from_marker_id(material_id: StringName) -> StringName:
	if not is_string_anchor_builder_marker_id(material_id):
		return StringName()
	var marker_text: String = String(material_id)
	var pair_and_endpoint: String = marker_text.trim_prefix("builder_marker_string_anchor_")
	if pair_and_endpoint.length() < 2:
		return StringName()
	return _normalize_string_anchor_pair_id(StringName(pair_and_endpoint.substr(0, pair_and_endpoint.length() - 1)))

static func get_string_anchor_endpoint_index_from_marker_id(material_id: StringName) -> int:
	if not is_string_anchor_builder_marker_id(material_id):
		return 0
	var marker_text: String = String(material_id)
	var endpoint_text: String = marker_text.right(1)
	return 1 if endpoint_text == "1" else 2 if endpoint_text == "2" else 0

static func get_builder_marker_display_name(material_id: StringName) -> String:
	if not is_string_anchor_builder_marker_id(material_id):
		return String(material_id)
	return "String Anchor %s" % get_builder_marker_short_label(material_id)

static func get_builder_marker_short_label(material_id: StringName) -> String:
	if not is_string_anchor_builder_marker_id(material_id):
		return String(material_id)
	return "%s%d" % [
		String(get_string_anchor_pair_id_from_marker_id(material_id)).to_upper(),
		get_string_anchor_endpoint_index_from_marker_id(material_id)
	]

static func get_builder_marker_color(material_id: StringName) -> Color:
	match get_string_anchor_pair_id_from_marker_id(material_id):
		STRING_ANCHOR_PAIR_A:
			return Color(0.25, 0.55, 1.0, 1.0)
		STRING_ANCHOR_PAIR_B:
			return Color(0.2, 0.9, 0.95, 1.0)
		STRING_ANCHOR_PAIR_C:
			return Color(0.25, 0.85, 0.35, 1.0)
		STRING_ANCHOR_PAIR_D:
			return Color(1.0, 0.85, 0.2, 1.0)
		STRING_ANCHOR_PAIR_E:
			return Color(1.0, 0.55, 0.15, 1.0)
		STRING_ANCHOR_PAIR_F:
			return Color(1.0, 0.35, 0.8, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)

static func get_builder_marker_catalog_entries(builder_path_id: StringName, builder_component_id: StringName) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not is_ranged_bow_builder_component(builder_path_id, builder_component_id):
		return entries
	for pair_id: StringName in get_string_anchor_pair_ids():
		for endpoint_index in [1, 2]:
			var material_id: StringName = get_string_anchor_builder_marker_id(pair_id, endpoint_index)
			entries.append({
				"material_id": material_id,
				"quantity": 0,
				"display_name": get_builder_marker_display_name(material_id),
				"is_builder_marker": true,
				"is_placeable_without_inventory": true,
				"builder_marker_color": get_builder_marker_color(material_id),
				"builder_marker_pair_id": pair_id,
				"builder_marker_endpoint_index": endpoint_index,
			})
	return entries

static func collect_builder_marker_positions(wip: CraftedItemWIP) -> Dictionary:
	var positions: Dictionary = {}
	if wip == null:
		return positions
	if wip.builder_marker_positions == null:
		wip.builder_marker_positions = {}
	for marker_id: StringName in _collect_builder_marker_ids():
		var storage_key: String = _build_builder_marker_storage_key(marker_id)
		var position_variant: Variant = wip.builder_marker_positions.get(storage_key, wip.builder_marker_positions.get(marker_id))
		if position_variant is Vector3i:
			positions[marker_id] = position_variant
	return positions

static func find_builder_marker_id_at_grid_position(wip: CraftedItemWIP, grid_position: Vector3i) -> StringName:
	var marker_positions: Dictionary = collect_builder_marker_positions(wip)
	for marker_id: StringName in marker_positions.keys():
		var marker_position: Variant = marker_positions.get(marker_id)
		if marker_position is Vector3i and marker_position == grid_position:
			return marker_id
	return StringName()

static func get_builder_marker_position(wip: CraftedItemWIP, material_id: StringName) -> Variant:
	if wip == null or not is_builder_marker_material_id(material_id):
		return null
	return collect_builder_marker_positions(wip).get(material_id)

static func set_builder_marker_position(wip: CraftedItemWIP, material_id: StringName, grid_position: Vector3i) -> bool:
	if wip == null or not is_builder_marker_material_id(material_id):
		return false
	var storage: Dictionary = wip.builder_marker_positions if wip.builder_marker_positions != null else {}
	var existing_positions: Dictionary = collect_builder_marker_positions(wip)
	var existing_position_variant: Variant = existing_positions.get(material_id)
	if existing_position_variant is Vector3i and existing_position_variant == grid_position:
		return false
	var conflicting_marker_id: StringName = find_builder_marker_id_at_grid_position(wip, grid_position)
	if conflicting_marker_id != StringName() and conflicting_marker_id != material_id:
		storage.erase(_build_builder_marker_storage_key(conflicting_marker_id))
		storage.erase(conflicting_marker_id)
	if storage.has(material_id):
		storage.erase(material_id)
	storage[_build_builder_marker_storage_key(material_id)] = grid_position
	wip.builder_marker_positions = storage
	return true

static func clear_builder_marker_position(wip: CraftedItemWIP, material_id: StringName) -> bool:
	if wip == null or not is_builder_marker_material_id(material_id) or wip.builder_marker_positions == null:
		return false
	var storage: Dictionary = wip.builder_marker_positions
	var removed: bool = false
	var storage_key: String = _build_builder_marker_storage_key(material_id)
	if storage.has(storage_key):
		storage.erase(storage_key)
		removed = true
	if storage.has(material_id):
		storage.erase(material_id)
		removed = true
	if removed:
		wip.builder_marker_positions = storage
	return removed

static func migrate_builder_marker_cells_to_positions(wip: CraftedItemWIP) -> bool:
	if wip == null:
		return false
	var migration_changed: bool = false
	var empty_layers: Array[LayerAtom] = []
	for layer_atom: LayerAtom in wip.layers:
		if layer_atom == null:
			continue
		var cells_to_remove: Array[CellAtom] = []
		for cell: CellAtom in layer_atom.cells:
			if cell == null or not is_builder_marker_material_id(cell.material_variant_id):
				continue
			set_builder_marker_position(wip, cell.material_variant_id, cell.grid_position)
			cells_to_remove.append(cell)
			migration_changed = true
		for cell: CellAtom in cells_to_remove:
			layer_atom.cells.erase(cell)
		if layer_atom.cells.is_empty():
			empty_layers.append(layer_atom)
	for empty_layer: LayerAtom in empty_layers:
		wip.layers.erase(empty_layer)
	if migration_changed:
		wip.latest_baked_profile_snapshot = null
	return migration_changed

static func collect_cells(wip: CraftedItemWIP, include_builder_markers: bool = true) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	if wip == null:
		return cells
	for layer in wip.layers:
		if layer == null:
			continue
		for cell in layer.cells:
			if cell == null:
				continue
			cells.append(cell)
	if include_builder_markers:
		cells.append_array(collect_builder_marker_cells(wip))
	return cells

static func collect_bake_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	return collect_cells(wip, false)

static func collect_builder_marker_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	var marker_positions: Dictionary = collect_builder_marker_positions(wip)
	for pair_id: StringName in get_string_anchor_pair_ids():
		for endpoint_index in [1, 2]:
			var marker_id: StringName = get_string_anchor_builder_marker_id(pair_id, endpoint_index)
			var grid_position_variant: Variant = marker_positions.get(marker_id)
			if grid_position_variant is not Vector3i:
				continue
			cells.append(_build_builder_marker_cell(marker_id, grid_position_variant))
	return cells

static func find_first_cell_by_material_id(wip: CraftedItemWIP, material_id: StringName) -> CellAtom:
	if is_builder_marker_material_id(material_id):
		var marker_position_variant: Variant = get_builder_marker_position(wip, material_id)
		if marker_position_variant is Vector3i:
			return _build_builder_marker_cell(material_id, marker_position_variant)
		return null
	for cell: CellAtom in collect_cells(wip, true):
		if cell != null and cell.material_variant_id == material_id:
			return cell
	return null

static func resolve_first_complete_string_anchor_pair(cells: Array[CellAtom]) -> Dictionary:
	for pair_id: StringName in get_string_anchor_pair_ids():
		var endpoint_one_id: StringName = get_string_anchor_builder_marker_id(pair_id, 1)
		var endpoint_two_id: StringName = get_string_anchor_builder_marker_id(pair_id, 2)
		var endpoint_one_cell: CellAtom = null
		var endpoint_two_cell: CellAtom = null
		for cell: CellAtom in cells:
			if cell == null:
				continue
			if cell.material_variant_id == endpoint_one_id:
				endpoint_one_cell = cell
			elif cell.material_variant_id == endpoint_two_id:
				endpoint_two_cell = cell
		if endpoint_one_cell == null or endpoint_two_cell == null:
			continue
		if endpoint_one_cell.grid_position == endpoint_two_cell.grid_position:
			continue
		return {
			"valid": true,
			"pair_id": pair_id,
			"endpoint_one_cell": endpoint_one_cell,
			"endpoint_two_cell": endpoint_two_cell,
		}
	return {
		"valid": false,
		"pair_id": StringName(),
		"endpoint_one_cell": null,
		"endpoint_two_cell": null,
	}

static func _normalize_string_anchor_pair_id(pair_id: StringName) -> StringName:
	if get_string_anchor_pair_ids().has(pair_id):
		return pair_id
	return STRING_ANCHOR_PAIR_A

static func _collect_builder_marker_ids() -> Array[StringName]:
	var marker_ids: Array[StringName] = []
	for pair_id: StringName in get_string_anchor_pair_ids():
		for endpoint_index in [1, 2]:
			marker_ids.append(get_string_anchor_builder_marker_id(pair_id, endpoint_index))
	return marker_ids

static func _build_builder_marker_cell(material_id: StringName, grid_position: Vector3i) -> CellAtom:
	var cell: CellAtom = CellAtom.new()
	cell.grid_position = grid_position
	cell.layer_index = grid_position.z
	cell.material_variant_id = material_id
	return cell

static func _build_builder_marker_storage_key(material_id: StringName) -> String:
	return String(material_id)

static func infer_builder_path_id_from_intent_and_context(
	resolved_forge_intent: StringName,
	resolved_equipment_context: StringName
) -> StringName:
	if resolved_forge_intent == &"intent_shield" or resolved_equipment_context == &"ctx_shield":
		return BUILDER_PATH_SHIELD
	if resolved_forge_intent == &"intent_ranged" and resolved_equipment_context == &"ctx_weapon":
		return BUILDER_PATH_RANGED_PHYSICAL
	if resolved_forge_intent == &"intent_magic" or resolved_equipment_context == &"ctx_focus":
		return BUILDER_PATH_MAGIC
	return BUILDER_PATH_MELEE

static func get_default_forge_intent_for_builder_path(builder_path_id: StringName) -> StringName:
	match normalize_builder_path_id(builder_path_id):
		BUILDER_PATH_RANGED_PHYSICAL:
			return &"intent_ranged"
		BUILDER_PATH_SHIELD:
			return &"intent_shield"
		BUILDER_PATH_MAGIC:
			return &"intent_magic"
		_:
			return &"intent_melee"

static func get_default_equipment_context_for_builder_path(builder_path_id: StringName) -> StringName:
	match normalize_builder_path_id(builder_path_id):
		BUILDER_PATH_SHIELD:
			return &"ctx_shield"
		BUILDER_PATH_MAGIC:
			return &"ctx_focus"
		_:
			return &"ctx_weapon"

static func is_unarmed_authoring_wip(wip: CraftedItemWIP) -> bool:
	return (
		wip != null
		and (
			wip.wip_id == UNARMED_AUTHORING_WIP_ID
			or wip.forge_intent == FORGE_INTENT_UNARMED
			or wip.equipment_context == EQUIPMENT_CONTEXT_UNARMED
		)
	)

static func apply_builder_path_defaults(
	target_wip: CraftedItemWIP,
	builder_path_id: StringName,
	builder_component_id: StringName = StringName()
) -> CraftedItemWIP:
	if target_wip == null:
		return null
	var normalized_builder_path_id: StringName = normalize_builder_path_id(builder_path_id)
	var normalized_builder_component_id: StringName = normalize_builder_component_id(
		normalized_builder_path_id,
		builder_component_id
	)
	target_wip.forge_builder_path_id = normalized_builder_path_id
	target_wip.forge_builder_component_id = normalized_builder_component_id
	target_wip.forge_intent = get_default_forge_intent_for_builder_path(normalized_builder_path_id)
	target_wip.equipment_context = get_default_equipment_context_for_builder_path(normalized_builder_path_id)
	target_wip.ensure_combat_animation_station_state()
	return target_wip

func ensure_combat_animation_station_state() -> Resource:
	var station_state: Resource = combat_animation_station_state
	if station_state == null or not station_state.has_method("ensure_default_baseline_content"):
		station_state = CombatAnimationStationStateScript.new()
		combat_animation_station_state = station_state
	station_state.call(
		"ensure_default_baseline_content",
		forge_builder_path_id,
		equipment_context,
		grip_style_mode,
		stow_position_mode
	)
	return station_state

static func get_stow_position_modes() -> Array[StringName]:
	return [
		STOW_SHOULDER_HANGING,
		STOW_LOWER_BACK,
		STOW_SIDE_HIP
	]

static func normalize_stow_position_mode(stow_mode: StringName) -> StringName:
	if get_stow_position_modes().has(stow_mode):
		return stow_mode
	return STOW_SHOULDER_HANGING

static func get_stow_position_label(stow_mode: StringName) -> String:
	match normalize_stow_position_mode(stow_mode):
		STOW_SIDE_HIP:
			return "Hip"
		STOW_LOWER_BACK:
			return "Lower Back"
		_:
			return "Upper Back"

static func get_stow_position_note(stow_mode: StringName) -> String:
	match normalize_stow_position_mode(stow_mode):
		STOW_SIDE_HIP:
			return "Recommended for short and medium weapon builds."
		STOW_LOWER_BACK:
			return "Recommended for short weapon builds."
		_:
			return "Recommended for medium and long weapon builds."

static func get_grip_style_modes() -> Array[StringName]:
	return [
		GRIP_NORMAL,
		GRIP_REVERSE
	]

static func normalize_grip_style_mode(grip_mode: StringName) -> StringName:
	if get_grip_style_modes().has(grip_mode):
		return grip_mode
	return GRIP_NORMAL

static func supports_reverse_grip_for_context(resolved_forge_intent: StringName, resolved_equipment_context: StringName) -> bool:
	return resolved_forge_intent == &"intent_melee" and resolved_equipment_context == &"ctx_weapon"

static func resolve_supported_grip_style(grip_mode: StringName, resolved_forge_intent: StringName, resolved_equipment_context: StringName) -> StringName:
	var normalized_mode: StringName = normalize_grip_style_mode(grip_mode)
	if normalized_mode == GRIP_REVERSE and not supports_reverse_grip_for_context(resolved_forge_intent, resolved_equipment_context):
		return GRIP_NORMAL
	return normalized_mode

static func get_grip_style_label(grip_mode: StringName) -> String:
	match normalize_grip_style_mode(grip_mode):
		GRIP_REVERSE:
			return "Reverse Grip"
		_:
			return "Normal Grip"

static func get_grip_style_note(grip_mode: StringName) -> String:
	match normalize_grip_style_mode(grip_mode):
		GRIP_REVERSE:
			return "Reverse grip shortens the weapon's effective reach significantly and disables two-handed weapon techniques, but grants +25% attack speed."
		_:
			return "Standard forward-facing hold. Supports normal one-handed and two-handed weapon use when available."
