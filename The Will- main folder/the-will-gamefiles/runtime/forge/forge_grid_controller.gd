extends Node
class_name ForgeGridController

signal active_wip_changed(wip)
signal active_test_print_changed(test_print)

const ForgeRulesDefScript = preload("res://core/defs/forge_rules_def.gd")
const ForgeAuthoringSandboxDefScript = preload("res://core/defs/forge/forge_authoring_sandbox_def.gd")
const ForgeViewTuningDefScript = preload("res://core/defs/forge_view_tuning_def.gd")
const ForgeAuthoringSandboxPresenterScript = preload("res://runtime/forge/forge_authoring_sandbox_presenter.gd")
const ForgeMaterialLookupPresenterScript = preload("res://runtime/forge/forge_material_lookup_presenter.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const ForgeStage2ServiceScript = preload("res://services/forge_stage2_service.gd")
const ForgeTestPrintPreviewPresenterScript = preload("res://runtime/forge/forge_test_print_preview_presenter.gd")
const ForgeWipCellStatePresenterScript = preload("res://runtime/forge/forge_wip_cell_state_presenter.gd")
const ForgeWipBuilderScript = preload("res://runtime/forge/forge_wip_builder.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_AUTHORING_SANDBOX_RESOURCE: Resource = preload("res://core/defs/forge/forge_authoring_sandbox_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")

@export var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
@export var forge_authoring_sandbox: Resource = DEFAULT_FORGE_AUTHORING_SANDBOX_RESOURCE
@export var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE
@export var auto_spawn_test_print_on_ready: bool = false
@export var test_print_spawn_root_path: NodePath
@export_dir var material_defs_root_dir: String = "res://core/defs/materials"

var grid_size: Vector3i = DEFAULT_FORGE_RULES_RESOURCE.grid_size
var active_wip: CraftedItemWIP
var active_test_print: TestPrintInstance
var active_baked_profile: BakedProfile
var active_layer_index: int = DEFAULT_FORGE_RULES_RESOURCE.grid_size.z >> 1
var configured_grid_size_override: Vector3i = Vector3i.ZERO
var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var forge_stage2_service = ForgeStage2ServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var test_print_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
var test_print_spawn_root: Node3D
var test_print_mesh_instance: MeshInstance3D
var active_cell_lookup: Dictionary = {}

var authoring_sandbox_presenter = ForgeAuthoringSandboxPresenterScript.new()
var material_lookup_presenter = ForgeMaterialLookupPresenterScript.new()
var test_print_preview_presenter = ForgeTestPrintPreviewPresenterScript.new()
var wip_cell_state_presenter = ForgeWipCellStatePresenterScript.new()
var wip_builder = ForgeWipBuilderScript.new()

func _ready() -> void:
	_apply_forge_rules()
	test_print_mesh_builder.set_view_tuning(_get_forge_view_tuning())
	test_print_spawn_root = get_node_or_null(test_print_spawn_root_path) as Node3D
	_ensure_test_print_mesh_instance()
	_sync_spawned_test_print_mesh()
	if not auto_spawn_test_print_on_ready:
		return
	spawn_test_print_from_active_wip_with_defaults()

func configure_grid(new_grid_size: Vector3i) -> void:
	configured_grid_size_override = new_grid_size
	grid_size = new_grid_size
	active_layer_index = clampi(active_layer_index, 0, grid_size.z - 1)

func get_cell_world_size_meters() -> float:
	return _get_forge_rules().cell_world_size_meters

func get_default_sample_preset_id() -> StringName:
	return authoring_sandbox_presenter.get_default_sample_preset_id(_get_forge_authoring_sandbox())

func get_sample_grip_preset_id() -> StringName:
	return authoring_sandbox_presenter.get_sample_grip_preset_id(_get_forge_authoring_sandbox())

func get_sample_flex_preset_id() -> StringName:
	return authoring_sandbox_presenter.get_sample_flex_preset_id(_get_forge_authoring_sandbox())

func get_sample_bow_preset_id() -> StringName:
	return authoring_sandbox_presenter.get_sample_bow_preset_id(_get_forge_authoring_sandbox())

func get_sample_preset_ids() -> Array[StringName]:
	return authoring_sandbox_presenter.get_sample_preset_ids(_get_forge_authoring_sandbox())

func get_sample_preset_defs() -> Array[Resource]:
	return authoring_sandbox_presenter.get_sample_preset_defs(_get_forge_authoring_sandbox())

func get_sample_preset_display_name(sample_preset_id: StringName) -> String:
	return authoring_sandbox_presenter.get_sample_preset_display_name(
		_get_forge_authoring_sandbox(),
		wip_builder,
		sample_preset_id
	)

func get_inventory_seed_quantity() -> int:
	return authoring_sandbox_presenter.get_inventory_seed_quantity(_get_forge_authoring_sandbox())

func get_inventory_seed_bonus_quantity() -> int:
	return authoring_sandbox_presenter.get_inventory_seed_bonus_quantity(_get_forge_authoring_sandbox())

func get_inventory_seed_def() -> Resource:
	return authoring_sandbox_presenter.get_inventory_seed_def(_get_forge_authoring_sandbox())

func get_material_catalog_def() -> Resource:
	return _get_forge_rules().material_catalog_def

func get_default_material_tier_def() -> Resource:
	return _get_forge_rules().default_material_tier_def

func get_material_catalog_ids() -> Array[StringName]:
	return material_lookup_presenter.build_ordered_material_ids(
		build_default_material_lookup(),
		get_material_catalog_def(),
		get_default_material_tier_def(),
		forge_service
	)

func set_active_wip(wip: CraftedItemWIP) -> void:
	active_wip = wip
	if active_wip != null and active_wip.forge_builder_path_id == StringName():
		active_wip.forge_builder_path_id = CraftedItemWIP.infer_builder_path_id_from_intent_and_context(
			active_wip.forge_intent,
			active_wip.equipment_context
		)
	if active_wip != null:
		active_wip.forge_builder_component_id = CraftedItemWIP.normalize_builder_component_id(
			active_wip.forge_builder_path_id,
			active_wip.forge_builder_component_id
		)
		CraftedItemWIP.migrate_builder_marker_cells_to_positions(active_wip)
	_apply_grid_size_for_active_wip()
	active_cell_lookup = wip_cell_state_presenter.rebuild_active_cell_lookup(active_wip)
	active_baked_profile = null
	emit_signal("active_wip_changed", active_wip)

func set_active_test_print(test_print: TestPrintInstance) -> void:
	active_test_print = test_print
	_sync_spawned_test_print_mesh()
	emit_signal("active_test_print_changed", active_test_print)

func clear_active_test_print() -> void:
	if active_test_print == null:
		return
	active_test_print = null
	_sync_spawned_test_print_mesh()
	emit_signal("active_test_print_changed", active_test_print)

func get_active_baked_profile() -> BakedProfile:
	return active_baked_profile

func get_forge_service() -> ForgeService:
	return forge_service

func ensure_stage2_item_state_for_active_wip():
	if active_wip == null:
		return null
	if active_wip.latest_baked_profile_snapshot == null:
		active_baked_profile = forge_service.bake_wip(active_wip, build_default_material_lookup())
	elif active_baked_profile == null:
		active_baked_profile = active_wip.latest_baked_profile_snapshot
	var stage2_item_state = forge_stage2_service.ensure_stage2_item_state_for_wip(
		active_wip,
		build_default_material_lookup()
	)
	if stage2_item_state == null:
		return null
	clear_active_test_print()
	emit_signal("active_wip_changed", active_wip)
	return stage2_item_state

func clear_active_baked_profile() -> void:
	active_baked_profile = null

func get_active_layer_index() -> int:
	return clampi(active_layer_index, 0, grid_size.z - 1)

func set_active_layer_index(layer_index: int) -> void:
	active_layer_index = clampi(layer_index, 0, grid_size.z - 1)

func ensure_editable_wip(project_name: String = "") -> CraftedItemWIP:
	if active_wip == null:
		load_new_blank_wip(project_name)
	return active_wip

func reset_active_sample_preset_wip() -> CraftedItemWIP:
	var sample_builder_path_id: StringName = authoring_sandbox_presenter.get_sample_preset_builder_path_id(
		_get_forge_authoring_sandbox(),
		wip_builder,
		authoring_sandbox_presenter.get_active_sample_preset_id()
	)
	_apply_grid_size_for_builder_path(sample_builder_path_id)
	set_active_layer_index(get_default_active_layer())
	var reset_wip: CraftedItemWIP = authoring_sandbox_presenter.reset_active_sample_preset_wip(
		_get_forge_authoring_sandbox(),
		wip_builder,
		grid_size,
		get_default_active_layer()
	)
	if reset_wip == null:
		return null
	set_active_wip(reset_wip)
	clear_active_test_print()
	return active_wip

func load_sample_preset_wip(preset_id: StringName) -> CraftedItemWIP:
	var sample_builder_path_id: StringName = authoring_sandbox_presenter.get_sample_preset_builder_path_id(
		_get_forge_authoring_sandbox(),
		wip_builder,
		preset_id
	)
	_apply_grid_size_for_builder_path(sample_builder_path_id)
	set_active_layer_index(get_default_active_layer())
	set_active_wip(authoring_sandbox_presenter.load_sample_preset_wip(
		_get_forge_authoring_sandbox(),
		wip_builder,
		grid_size,
		get_default_active_layer(),
		preset_id
	))
	if active_wip == null:
		return null
	clear_active_test_print()
	return active_wip

func load_player_saved_wip(saved_wip: CraftedItemWIP) -> CraftedItemWIP:
	if saved_wip == null:
		return null
	authoring_sandbox_presenter.clear_active_sample_preset()
	var resolved_builder_path_id: StringName = (
		CraftedItemWIP.normalize_builder_path_id(saved_wip.forge_builder_path_id)
		if saved_wip.forge_builder_path_id != StringName()
		else CraftedItemWIP.infer_builder_path_id_from_intent_and_context(saved_wip.forge_intent, saved_wip.equipment_context)
	)
	var resolved_builder_component_id: StringName = CraftedItemWIP.normalize_builder_component_id(
		resolved_builder_path_id,
		saved_wip.forge_builder_component_id
	)
	_apply_grid_size_for_builder_path(
		resolved_builder_path_id,
		resolved_builder_component_id
	)
	set_active_layer_index(get_default_active_layer())
	set_active_wip(saved_wip.duplicate(true) as CraftedItemWIP)
	clear_active_test_print()
	return active_wip

func load_new_blank_wip(project_name: String = "") -> CraftedItemWIP:
	return load_new_blank_wip_for_builder_path(project_name, CraftedItemWIP.BUILDER_PATH_MELEE)

func load_new_blank_wip_for_builder_path(
	project_name: String = "",
	builder_path_id: StringName = CraftedItemWIP.BUILDER_PATH_MELEE,
	builder_component_id: StringName = StringName()
) -> CraftedItemWIP:
	authoring_sandbox_presenter.clear_active_sample_preset()
	_apply_grid_size_for_builder_path(builder_path_id, builder_component_id)
	set_active_layer_index(get_default_active_layer())
	set_active_wip(wip_builder.build_blank_wip_for_builder_path(project_name, builder_path_id, builder_component_id))
	clear_active_test_print()
	return active_wip

func get_active_sample_preset_id() -> StringName:
	return authoring_sandbox_presenter.get_active_sample_preset_id()

func get_default_active_layer() -> int:
	return grid_size.z >> 1

func get_max_fill_cells() -> int:
	return int(floor(float(grid_size.x * grid_size.y * grid_size.z) * _get_forge_rules().max_fill_ratio))

func get_material_id_at(grid_position: Vector3i) -> StringName:
	return wip_cell_state_presenter.get_material_id_at(active_cell_lookup, grid_position)

func get_builder_marker_id_at(grid_position: Vector3i) -> StringName:
	return CraftedItemWIP.find_builder_marker_id_at_grid_position(active_wip, grid_position)

func get_pickable_material_id_at(grid_position: Vector3i) -> StringName:
	var builder_marker_id: StringName = get_builder_marker_id_at(grid_position)
	if builder_marker_id != StringName():
		return builder_marker_id
	return get_material_id_at(grid_position)

func set_builder_marker_at(grid_position: Vector3i, material_variant_id: StringName) -> bool:
	if material_variant_id == StringName():
		return false
	var wip: CraftedItemWIP = ensure_editable_wip()
	if wip == null:
		return false
	if not CraftedItemWIP.set_builder_marker_position(wip, material_variant_id, grid_position):
		return false
	_mark_wip_dirty(wip)
	return true

func clear_builder_marker_at(grid_position: Vector3i) -> StringName:
	if active_wip == null:
		return StringName()
	var marker_id: StringName = get_builder_marker_id_at(grid_position)
	if marker_id == StringName():
		return StringName()
	if not CraftedItemWIP.clear_builder_marker_position(active_wip, marker_id):
		return StringName()
	_mark_wip_dirty(active_wip)
	return marker_id

func set_material_at(grid_position: Vector3i, material_variant_id: StringName) -> bool:
	return wip_cell_state_presenter.set_material_at(
		active_cell_lookup,
		grid_position,
		material_variant_id,
		Callable(self, "ensure_editable_wip"),
		Callable(self, "_mark_wip_dirty")
	)

func set_materials_at(grid_positions: Array[Vector3i], material_variant_id: StringName) -> int:
	return wip_cell_state_presenter.set_materials_at(
		active_cell_lookup,
		grid_positions,
		material_variant_id,
		Callable(self, "ensure_editable_wip"),
		Callable(self, "_mark_wip_dirty")
	)

func remove_material_at(grid_position: Vector3i) -> StringName:
	return wip_cell_state_presenter.remove_material_at(
		active_wip,
		active_cell_lookup,
		grid_position,
		Callable(self, "_mark_wip_dirty")
	)

func remove_materials_at(grid_positions: Array[Vector3i]) -> Dictionary:
	return wip_cell_state_presenter.remove_materials_at(
		active_wip,
		active_cell_lookup,
		grid_positions,
		Callable(self, "_mark_wip_dirty")
	)

func build_default_material_lookup() -> Dictionary:
	return material_lookup_presenter.build_runtime_material_lookup(
		get_material_catalog_def(),
		get_default_material_tier_def(),
		material_defs_root_dir,
		forge_service
	)

func bake_active_wip(
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	if active_wip == null:
		return null
	active_baked_profile = forge_service.bake_wip(active_wip, material_lookup, shape_data, joint_data, bow_data)
	return active_baked_profile

func spawn_test_print_from_active_wip(
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> TestPrintInstance:
	if active_wip == null:
		return null
	set_active_test_print(forge_service.build_test_print_from_wip(
		active_wip,
		material_lookup,
		shape_data,
		joint_data,
		bow_data
	))
	active_baked_profile = active_test_print.baked_profile if active_test_print != null else null
	return active_test_print

func bake_active_wip_with_defaults() -> TestPrintInstance:
	ensure_editable_wip()
	var material_lookup: Dictionary = build_default_material_lookup()
	var test_print: TestPrintInstance = spawn_test_print_from_active_wip(material_lookup)
	if test_print == null:
		return null
	return test_print

func spawn_test_print_from_active_wip_with_defaults() -> TestPrintInstance:
	return bake_active_wip_with_defaults()

func _apply_forge_rules() -> void:
	var rules: ForgeRulesDef = _get_forge_rules()
	grid_size = configured_grid_size_override if configured_grid_size_override != Vector3i.ZERO else rules.grid_size
	forge_service.set_forge_rules(rules)
	forge_stage2_service.set_forge_rules(rules)
	test_print_mesh_builder.set_view_tuning(_get_forge_view_tuning())
	active_layer_index = clampi(active_layer_index, 0, grid_size.z - 1)

func _apply_grid_size_for_active_wip() -> void:
	if active_wip == null:
		return
	_apply_grid_size_for_builder_path(active_wip.forge_builder_path_id, active_wip.forge_builder_component_id)

func _apply_grid_size_for_builder_path(
	builder_path_id: StringName,
	builder_component_id: StringName = StringName()
) -> void:
	if configured_grid_size_override != Vector3i.ZERO:
		grid_size = configured_grid_size_override
	else:
		grid_size = _get_forge_rules().get_grid_size_for_builder_path_component(
			builder_path_id,
			builder_component_id
		)
	active_layer_index = clampi(active_layer_index, 0, grid_size.z - 1)

func _get_forge_rules() -> ForgeRulesDef:
	return forge_rules if forge_rules != null else DEFAULT_FORGE_RULES_RESOURCE

func _get_forge_authoring_sandbox() -> Resource:
	return authoring_sandbox_presenter.resolve_authoring_sandbox(
		forge_authoring_sandbox,
		DEFAULT_FORGE_AUTHORING_SANDBOX_RESOURCE
	)

func _mark_wip_dirty(wip: CraftedItemWIP) -> void:
	if wip != null:
		wip.latest_baked_profile_snapshot = null
		wip.stage2_item_state = null
	active_baked_profile = null
	active_wip = wip
	emit_signal("active_wip_changed", active_wip)
	clear_active_test_print()

func _ensure_test_print_mesh_instance() -> void:
	test_print_mesh_instance = test_print_preview_presenter.ensure_test_print_mesh_instance(
		test_print_spawn_root,
		test_print_mesh_instance,
		_build_test_print_material()
	)

func _sync_spawned_test_print_mesh() -> void:
	if test_print_spawn_root == null:
		return
	_ensure_test_print_mesh_instance()
	var material_lookup: Dictionary = build_default_material_lookup()
	test_print_mesh_instance = test_print_preview_presenter.sync_spawned_test_print_mesh(
		test_print_spawn_root,
		test_print_mesh_instance,
		active_test_print,
		test_print_mesh_builder,
		material_lookup
	)

func _build_test_print_material() -> StandardMaterial3D:
	return test_print_preview_presenter.build_test_print_material(_get_forge_view_tuning())

func _get_forge_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE
