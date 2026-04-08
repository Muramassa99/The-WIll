extends RefCounted
class_name ForgeAuthoringSandboxPresenter

var active_authoring_preset_id: StringName = StringName()

func resolve_authoring_sandbox(authoring_sandbox: Resource, default_resource: Resource) -> Resource:
	return authoring_sandbox if authoring_sandbox != null else default_resource

func get_default_sample_preset_id(authoring_sandbox: Resource) -> StringName:
	if authoring_sandbox == null:
		return StringName()
	return authoring_sandbox.default_sample_preset_id

func get_sample_grip_preset_id(authoring_sandbox: Resource) -> StringName:
	if authoring_sandbox == null:
		return StringName()
	return authoring_sandbox.sample_grip_preset_id

func get_sample_flex_preset_id(authoring_sandbox: Resource) -> StringName:
	if authoring_sandbox == null:
		return StringName()
	return authoring_sandbox.sample_flex_preset_id

func get_sample_bow_preset_id(authoring_sandbox: Resource) -> StringName:
	if authoring_sandbox == null:
		return StringName()
	return authoring_sandbox.sample_bow_preset_id

func get_sample_preset_ids(authoring_sandbox: Resource) -> Array[StringName]:
	var preset_ids: Array[StringName] = []
	if authoring_sandbox == null:
		return preset_ids
	for preset_def: Resource in authoring_sandbox.sample_presets:
		if preset_def == null:
			continue
		preset_ids.append(preset_def.preset_id)
	return preset_ids

func get_sample_preset_defs(authoring_sandbox: Resource) -> Array[Resource]:
	if authoring_sandbox == null:
		return []
	return authoring_sandbox.sample_presets

func get_sample_preset_display_name(authoring_sandbox: Resource, wip_builder: ForgeWipBuilder, sample_preset_id: StringName) -> String:
	if authoring_sandbox == null or wip_builder == null:
		return String(sample_preset_id)
	var preset_def: Resource = wip_builder.get_sample_preset_def(authoring_sandbox, sample_preset_id)
	if preset_def == null or preset_def.display_name.is_empty():
		return String(sample_preset_id)
	return preset_def.display_name

func get_sample_preset_builder_path_id(authoring_sandbox: Resource, wip_builder: ForgeWipBuilder, sample_preset_id: StringName) -> StringName:
	if authoring_sandbox == null or wip_builder == null:
		return CraftedItemWIP.BUILDER_PATH_MELEE
	var preset_def: Resource = wip_builder.get_sample_preset_def(authoring_sandbox, sample_preset_id)
	if preset_def == null:
		return CraftedItemWIP.BUILDER_PATH_MELEE
	return CraftedItemWIP.infer_builder_path_id_from_intent_and_context(
		preset_def.forge_intent,
		preset_def.equipment_context
	)

func get_inventory_seed_quantity(authoring_sandbox: Resource) -> int:
	if authoring_sandbox == null:
		return 0
	return authoring_sandbox.inventory_seed_quantity

func get_inventory_seed_bonus_quantity(authoring_sandbox: Resource) -> int:
	if authoring_sandbox == null:
		return 0
	return authoring_sandbox.inventory_seed_bonus_quantity

func get_inventory_seed_def(authoring_sandbox: Resource) -> Resource:
	if authoring_sandbox == null:
		return null
	return authoring_sandbox.inventory_seed_def

func load_sample_preset_wip(
		authoring_sandbox: Resource,
		wip_builder: ForgeWipBuilder,
		grid_size: Vector3i,
		default_active_layer: int,
		sample_preset_id: StringName
	) -> CraftedItemWIP:
	if authoring_sandbox == null or wip_builder == null:
		return null
	active_authoring_preset_id = sample_preset_id if sample_preset_id != StringName() else authoring_sandbox.default_sample_preset_id
	return wip_builder.build_sample_preset_wip(
		authoring_sandbox,
		grid_size,
		default_active_layer,
		active_authoring_preset_id
	)

func reset_active_sample_preset_wip(
		authoring_sandbox: Resource,
		wip_builder: ForgeWipBuilder,
		grid_size: Vector3i,
		default_active_layer: int
	) -> CraftedItemWIP:
	if active_authoring_preset_id == StringName():
		return null
	return load_sample_preset_wip(
		authoring_sandbox,
		wip_builder,
		grid_size,
		default_active_layer,
		active_authoring_preset_id
	)

func clear_active_sample_preset() -> void:
	active_authoring_preset_id = StringName()

func get_active_sample_preset_id() -> StringName:
	return active_authoring_preset_id
