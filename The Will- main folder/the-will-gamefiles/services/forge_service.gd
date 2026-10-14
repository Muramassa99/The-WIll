extends RefCounted
class_name ForgeService

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")
const ForgeV2WipCompatibilityAdapterScript = preload(
	"res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)

var forge_rules: ForgeRulesDef = DEFAULT_FORGE_RULES_RESOURCE
var tier_resolver: TierResolver
var process_resolver: ProcessResolver
var capability_resolver: CapabilityResolver
var material_runtime_resolver

func _init(rules: ForgeRulesDef = null) -> void:
	tier_resolver = TierResolver.new()
	process_resolver = ProcessResolver.new()
	capability_resolver = CapabilityResolver.new()
	material_runtime_resolver = MaterialRuntimeResolverScript.new()
	set_forge_rules(rules)

func set_forge_rules(rules: ForgeRulesDef) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE

func bake_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		_shape_data: Dictionary = {},
		_joint_data: Dictionary = {},
		_bow_data: Dictionary = {}
	) -> BakedProfile:
	if wip == null:
		return null
	if not _wip_uses_forge_v2_runtime_contract(wip):
		return _build_unsupported_wip_profile(wip)
	return _bake_forge_v2_wip(wip, material_lookup)

func _build_unsupported_wip_profile(wip: CraftedItemWIP) -> BakedProfile:
	var profile := BakedProfile.new()
	profile.profile_id = _build_profile_id(wip)
	profile.validation_error = "forge_v1_authoring_removed"
	return profile

func get_cached_profile_for_runtime(
	wip: CraftedItemWIP,
	material_lookup: Dictionary = {}
) -> BakedProfile:
	if wip == null or wip.latest_baked_profile_snapshot == null:
		return null
	if not _wip_uses_forge_v2_runtime_contract(wip):
		return _build_unsupported_wip_profile(wip)
	var profile := wip.latest_baked_profile_snapshot.duplicate(true) as BakedProfile
	# The former minimum rejected the Handle before populating its grip path.
	# Rebuild only that obsolete rejection using the saved mesh and any saved
	# wrapper. This load path never generates a missing prepared target.
	if profile.validation_error == "forge_v2_primary_handle_span_below_0_25_meters":
		return bake_wip(wip, material_lookup)
	if profile.primary_grip_valid:
		var cell_size_meters := forge_rules.cell_world_size_meters
		if wip.stage2_item_state != null:
			var saved_cell_size_meters := float(wip.stage2_item_state.get("cell_world_size_meters"))
			if saved_cell_size_meters > 0.0:
				cell_size_meters = saved_cell_size_meters
		ForgeV2WipCompatibilityAdapterScript.refresh_metric_handle_capacity(
			profile, wip, cell_size_meters
		)
	return profile


func build_test_print_from_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		_shape_data: Dictionary = {},
		_joint_data: Dictionary = {},
		_bow_data: Dictionary = {},
		prefer_cached_profile: bool = false
	) -> TestPrintInstance:
	var profile: BakedProfile = (
		get_cached_profile_for_runtime(wip, material_lookup)
		if prefer_cached_profile and wip != null and wip.latest_baked_profile_snapshot != null
		else bake_wip(wip, material_lookup)
	)
	if profile == null:
		return null
	var test_print := TestPrintInstance.new()
	test_print.test_id = _build_test_print_id(wip)
	test_print.source_wip_id = wip.wip_id
	test_print.baked_profile = profile
	if not _wip_uses_forge_v2_runtime_contract(wip):
		return test_print
	var stage2_item_state: Resource = (
		wip.stage2_item_state.duplicate(true)
		if wip.stage2_item_state != null
		else null
	)
	test_print.stage2_item_state = stage2_item_state
	# V2 owns its prepared mesh. A missing mesh must not regenerate block geometry.
	if _stage2_item_state_has_authoritative_editable_mesh(stage2_item_state):
		test_print.canonical_geometry = stage2_item_state.call("build_current_canonical_geometry")
		test_print.visual_mesh_source = &"editable_mesh"
	return test_print

func build_material_variant(base_material: BaseMaterialDef, tier: TierDef) -> MaterialVariantDef:
	return tier_resolver.build_variant(base_material, tier)

func build_material_stack(process_rule: ProcessRuleDef, material_variant: MaterialVariantDef) -> ForgeMaterialStack:
	return process_resolver.build_stack(process_rule, material_variant)

func derive_capability_scores(
		profile: BakedProfile,
		material_bias_lines: Array[StatLine] = [],
		context_bias_lines: Array[StatLine] = []
	) -> Dictionary[StringName, float]:
	return capability_resolver.derive_capability_scores(profile, material_bias_lines, context_bias_lines)

func _bake_forge_v2_wip(
	wip: CraftedItemWIP,
	material_lookup: Dictionary
) -> BakedProfile:
	var runtime_mesh_packet := _build_forge_v2_runtime_mesh_packet(wip)
	var runtime_cell_size_meters := maxf(
		forge_rules.cell_world_size_meters if forge_rules != null else 0.0125,
		0.0001
	)
	if wip.stage2_item_state != null:
		var saved_cell_size_meters := float(
			wip.stage2_item_state.get("cell_world_size_meters")
		)
		if saved_cell_size_meters > 0.0:
			runtime_cell_size_meters = saved_cell_size_meters
	var runtime_contract: Dictionary = (
		ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
			wip,
			runtime_mesh_packet,
			runtime_cell_size_meters,
			material_lookup
		)
	)
	var profile := runtime_contract.get("baked_profile", null) as BakedProfile
	if profile == null:
		profile = BakedProfile.new()
		profile.validation_error = String(runtime_contract.get(
			"error",
			"forge_v2_runtime_contract_failed"
		))
	var rebuilt_stage2_state := runtime_contract.get(
		"stage2_item_state",
		null
	) as Resource
	if rebuilt_stage2_state != null:
		wip.stage2_item_state = rebuilt_stage2_state.duplicate(true) as Resource
	profile.profile_id = _build_profile_id(wip)
	_enrich_forge_v2_profile_material_data(profile, material_lookup)
	wip.latest_baked_profile_snapshot = profile.duplicate(true) as BakedProfile
	return profile

func _build_forge_v2_runtime_mesh_packet(wip: CraftedItemWIP) -> Dictionary:
	if wip == null or not _stage2_item_state_has_authoritative_editable_mesh(
		wip.stage2_item_state
	):
		return {
			"ok": false,
			"error_code": "FORGE_V2_RUNTIME_EDITABLE_MESH_UNAVAILABLE",
		}
	var stage2_item_state := wip.stage2_item_state
	var editable_mesh_state := stage2_item_state.get(
		"current_editable_mesh_state"
	) as Resource
	var surface_arrays: Array = editable_mesh_state.get("surface_arrays") as Array
	if (
		surface_arrays.size() <= Mesh.ARRAY_VERTEX
		or not surface_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array
	):
		return {
			"ok": false,
			"error_code": "FORGE_V2_RUNTIME_VERTEX_ARRAY_INVALID",
		}
	var vertices_cell_units := surface_arrays[
		Mesh.ARRAY_VERTEX
	] as PackedVector3Array
	var indices := PackedInt32Array()
	if (
		surface_arrays.size() > Mesh.ARRAY_INDEX
		and surface_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array
	):
		indices = PackedInt32Array(surface_arrays[Mesh.ARRAY_INDEX])
	if vertices_cell_units.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return {
			"ok": false,
			"error_code": "FORGE_V2_RUNTIME_MESH_INVALID",
		}
	var cell_size_meters := maxf(
		float(stage2_item_state.get("cell_world_size_meters")),
		0.0001
	)
	var vertices_meters := PackedVector3Array()
	vertices_meters.resize(vertices_cell_units.size())
	for vertex_index: int in range(vertices_cell_units.size()):
		vertices_meters[vertex_index] = (
			vertices_cell_units[vertex_index] * cell_size_meters
		)
	var runtime_mesh_packet := {
		"ok": true,
		"vertices": vertices_meters,
		"indices": indices,
		"watertight": true,
		"source": &"stage2_authoritative_editable_mesh",
	}
	var primary_grip_handle_mesh_state := stage2_item_state.get(
		"primary_grip_handle_mesh_state"
	) as Resource
	var primary_grip_handle_mesh_source := StringName(stage2_item_state.get(
		"primary_grip_handle_mesh_source"
	))
	var primary_grip_handle_body_signature := String(stage2_item_state.get(
		"primary_grip_handle_body_signature"
	))
	var primary_grip_handle_mesh_origin_id := StringName(stage2_item_state.get(
		"primary_grip_handle_mesh_origin_id"
	))
	if (
		primary_grip_handle_mesh_origin_id == StringName()
		and primary_grip_handle_mesh_source
		== PrimaryGripHandleMeshPacketScript.SOURCE
	):
		primary_grip_handle_mesh_origin_id = (
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		)
		stage2_item_state.set(
			"primary_grip_handle_mesh_origin_id",
			primary_grip_handle_mesh_origin_id
		)
	if (
		primary_grip_handle_mesh_state != null
		and primary_grip_handle_mesh_source
		== PrimaryGripHandleMeshPacketScript.SOURCE
		and not primary_grip_handle_body_signature.is_empty()
		and primary_grip_handle_mesh_origin_id
		== PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		and primary_grip_handle_mesh_state.has_method("has_surface_arrays")
		and bool(primary_grip_handle_mesh_state.call("has_surface_arrays"))
		and int(primary_grip_handle_mesh_state.get("primitive_type"))
		== Mesh.PRIMITIVE_TRIANGLES
	):
		var primary_grip_surface_arrays: Array = primary_grip_handle_mesh_state.get(
			"surface_arrays"
		) as Array
		if (
			primary_grip_surface_arrays.size() > Mesh.ARRAY_INDEX
			and primary_grip_surface_arrays[Mesh.ARRAY_VERTEX]
			is PackedVector3Array
			and primary_grip_surface_arrays[Mesh.ARRAY_INDEX]
			is PackedInt32Array
		):
			var primary_grip_vertices_cell_units := (
				primary_grip_surface_arrays[Mesh.ARRAY_VERTEX]
				as PackedVector3Array
			)
			var primary_grip_indices := PackedInt32Array(
				primary_grip_surface_arrays[Mesh.ARRAY_INDEX]
			)
			if (
				not primary_grip_vertices_cell_units.is_empty()
				and not primary_grip_indices.is_empty()
				and primary_grip_indices.size() % 3 == 0
			):
				var primary_grip_vertices_meters := PackedVector3Array()
				primary_grip_vertices_meters.resize(
					primary_grip_vertices_cell_units.size()
				)
				for vertex_index: int in range(
					primary_grip_vertices_cell_units.size()
				):
					primary_grip_vertices_meters[vertex_index] = (
						primary_grip_vertices_cell_units[vertex_index]
						* cell_size_meters
					)
				runtime_mesh_packet["primary_grip_handle_vertices"] = (
					primary_grip_vertices_meters
				)
				runtime_mesh_packet["primary_grip_handle_indices"] = (
					primary_grip_indices
				)
				runtime_mesh_packet["primary_grip_handle_mesh_source"] = (
					primary_grip_handle_mesh_source
				)
				runtime_mesh_packet[
					"primary_grip_handle_body_signature"
				] = (
					primary_grip_handle_body_signature
				)
				runtime_mesh_packet[
					"primary_grip_handle_vertices_origin_id"
				] = (
					primary_grip_handle_mesh_origin_id
				)
	var primary_grip_target_wrapper := stage2_item_state.get(
		"primary_grip_target_wrapper"
	) as Resource
	if primary_grip_target_wrapper != null:
		# The adapter validates against the restored handle and current authored
		# body, then copies the prepared target into its replacement Stage2.
		# Missing legacy targets remain missing; no preparation occurs on load.
		runtime_mesh_packet["primary_grip_target_wrapper"] = (
			primary_grip_target_wrapper
		)
	return runtime_mesh_packet

func _enrich_forge_v2_profile_material_data(
	profile: BakedProfile,
	material_lookup: Dictionary
) -> void:
	if profile == null:
		return
	var volume_mix: Dictionary = profile.material_volume_mix
	var total_mass := 0.0
	var runtime_material_data_resolved := not volume_mix.is_empty()
	for material_key: Variant in volume_mix.keys():
		var material_variant_id := StringName(material_key)
		if material_runtime_resolver.resolve_base_material_for_material_id(
			material_variant_id,
			material_lookup
		) == null:
			runtime_material_data_resolved = false
		var volume_cell_equivalents := maxf(
			float(volume_mix.get(material_key, 0.0)),
			0.0
		)
		total_mass += (
			material_runtime_resolver.resolve_density_per_material_id(
				material_variant_id,
				material_lookup
			)
			* volume_cell_equivalents
		)
	if (
		not profile.weapon_intrinsic_center_of_mass_spatial_material_valid
		and (total_mass > 0.0 or profile.total_mass <= 0.0)
	):
		profile.total_mass = total_mass
	profile.resolved_material_stat_lines = (
		_collect_aggregated_material_lines_from_volume_mix(
			volume_mix,
			material_lookup,
			&"material_stats"
		)
	)
	profile.resolved_capability_bias_lines = (
		_collect_aggregated_material_lines_from_volume_mix(
			volume_mix,
			material_lookup,
			&"capability_bias"
		)
	)
	profile.resolved_skill_family_bias_lines = (
		_collect_aggregated_material_lines_from_volume_mix(
			volume_mix,
			material_lookup,
			&"skill_family_bias"
		)
	)
	profile.resolved_elemental_affinity_lines = (
		_collect_aggregated_material_lines_from_volume_mix(
			volume_mix,
			material_lookup,
			&"elemental_affinity"
		)
	)
	profile.resolved_equipment_context_bias_lines = (
		_collect_aggregated_material_lines_from_volume_mix(
			volume_mix,
			material_lookup,
			&"equipment_context_bias"
		)
	)
	profile.capability_scores = derive_capability_scores(
		profile,
		profile.resolved_capability_bias_lines
	)
	profile.material_runtime_data_resolved = runtime_material_data_resolved

func _collect_aggregated_material_lines_from_volume_mix(
	volume_mix: Dictionary,
	material_lookup: Dictionary,
	line_kind: StringName
) -> Array[StatLine]:
	var line_lookup: Dictionary = {}
	for material_key: Variant in volume_mix.keys():
		var volume_cell_equivalents := maxf(
			float(volume_mix.get(material_key, 0.0)),
			0.0
		)
		if volume_cell_equivalents <= 0.0:
			continue
		var representative_cell := CellAtom.new()
		representative_cell.material_variant_id = StringName(material_key)
		var material_lines: Array[StatLine] = _resolve_material_lines_for_cell(
			representative_cell,
			material_lookup,
			line_kind
		)
		for material_line: StatLine in material_lines:
			if material_line == null or not material_line.is_valid():
				continue
			var scale := volume_cell_equivalents if material_line.is_numeric() else 1.0
			_merge_stat_lines(line_lookup, [material_line.copy_scaled(scale)])
	return _build_sorted_stat_line_array(line_lookup)

func _resolve_material_lines_for_cell(
		cell: CellAtom,
		material_lookup: Dictionary,
		line_kind: StringName
	) -> Array[StatLine]:
	# Shared material lookup still accepts a representative CellAtom carrying
	# only the material ID. V2 volume aggregation does not generate block geometry.
	match line_kind:
		&"material_stats":
			return material_runtime_resolver.resolve_material_stat_lines_for_cell(cell, material_lookup)
		&"capability_bias":
			return material_runtime_resolver.resolve_capability_bias_lines_for_cell(cell, material_lookup)
		&"skill_family_bias":
			return material_runtime_resolver.resolve_skill_family_bias_lines_for_cell(cell, material_lookup)
		&"elemental_affinity":
			return material_runtime_resolver.resolve_elemental_affinity_lines_for_cell(cell, material_lookup)
		&"equipment_context_bias":
			return material_runtime_resolver.resolve_equipment_context_bias_lines_for_cell(cell, material_lookup)
		_:
			return []

func _stage2_item_state_has_authoritative_editable_mesh(
	stage2_item_state: Resource
) -> bool:
	return (
		stage2_item_state != null
		and bool(stage2_item_state.get("editable_mesh_visual_authority"))
		and stage2_item_state.has_method("has_current_editable_mesh")
		and bool(stage2_item_state.call("has_current_editable_mesh"))
	)

func _wip_uses_forge_v2_runtime_contract(wip: CraftedItemWIP) -> bool:
	return CraftedItemWIP.is_forge_v2_authoring_wip(wip)

func _build_test_print_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"test_print_runtime"
	return StringName("test_print_%s" % String(wip.wip_id))

func _build_profile_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"profile_runtime"
	return StringName("profile_%s" % String(wip.wip_id))

func _merge_stat_lines(line_lookup: Dictionary, stat_lines: Array[StatLine]) -> void:
	for stat_line: StatLine in stat_lines:
		if stat_line == null or not stat_line.is_valid():
			continue
		var line_key: String = _build_stat_line_key(stat_line)
		var existing_line: StatLine = line_lookup.get(line_key) as StatLine
		if existing_line == null:
			line_lookup[line_key] = stat_line.copy_scaled(1.0)
			continue
		if stat_line.is_numeric():
			existing_line.value += stat_line.value
			continue
		if stat_line.is_flag():
			existing_line.value = maxf(existing_line.value, stat_line.value)
			continue
		if stat_line.is_enum() and existing_line.enum_value == StringName():
			existing_line.enum_value = stat_line.enum_value

func _build_sorted_stat_line_array(line_lookup: Dictionary) -> Array[StatLine]:
	var sorted_keys: Array = line_lookup.keys()
	sorted_keys.sort()
	var sorted_lines: Array[StatLine] = []
	for line_key in sorted_keys:
		var stat_line: StatLine = line_lookup.get(line_key) as StatLine
		if stat_line == null:
			continue
		sorted_lines.append(stat_line)
	return sorted_lines

func _build_stat_line_key(stat_line: StatLine) -> String:
	return "%s|%d|%s" % [String(stat_line.stat_id), int(stat_line.value_kind), String(stat_line.enum_value)]
