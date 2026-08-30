extends RefCounted
class_name ForgeService

const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const CraftedItemCanonicalSolidResolverScript = preload("res://core/resolvers/crafted_item_canonical_solid_resolver.gd")
const CraftedItemCanonicalGeometryResolverScript = preload("res://core/resolvers/crafted_item_canonical_geometry_resolver.gd")
const ForgeStage2ServiceScript = preload("res://services/forge_stage2_service.gd")
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
var segment_resolver: SegmentResolver
var anchor_resolver: AnchorResolver
var joint_resolver: JointResolver
var bow_resolver: BowResolver
var profile_resolver: ProfileResolver
var capability_resolver: CapabilityResolver
var material_runtime_resolver
var canonical_solid_resolver
var canonical_geometry_resolver
var stage2_service

func _init(rules: ForgeRulesDef = null) -> void:
	tier_resolver = TierResolver.new()
	process_resolver = ProcessResolver.new()
	capability_resolver = CapabilityResolver.new()
	material_runtime_resolver = MaterialRuntimeResolverScript.new()
	canonical_solid_resolver = CraftedItemCanonicalSolidResolverScript.new()
	canonical_geometry_resolver = CraftedItemCanonicalGeometryResolverScript.new()
	set_forge_rules(rules)
	stage2_service = ForgeStage2ServiceScript.new(forge_rules)

func set_forge_rules(rules: ForgeRulesDef) -> void:
	forge_rules = rules if rules != null else DEFAULT_FORGE_RULES_RESOURCE
	segment_resolver = SegmentResolver.new(forge_rules)
	anchor_resolver = AnchorResolver.new(forge_rules)
	joint_resolver = JointResolver.new(forge_rules)
	bow_resolver = BowResolver.new(forge_rules)
	profile_resolver = ProfileResolver.new(forge_rules)
	if stage2_service != null and stage2_service.has_method("set_forge_rules"):
		stage2_service.call("set_forge_rules", forge_rules)

func bake_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {}
	) -> BakedProfile:
	if wip == null:
		return null
	if _wip_uses_forge_v2_runtime_contract(wip):
		return _bake_forge_v2_wip(wip, material_lookup)

	var authored_cells: Array[CellAtom] = _collect_authored_wip_cells(wip)
	var cells: Array[CellAtom] = _collect_wip_cells(wip)
	var segments: Array[SegmentAtom] = build_segments(cells, material_lookup)
	segments = classify_joint_segments(segments, material_lookup)
	var anchors: Array[AnchorAtom] = build_anchors(segments, material_lookup)
	var resolved_joint_data: Dictionary = joint_data if not joint_data.is_empty() else build_joint_data(segments, material_lookup)
	var resolved_bow_data: Dictionary = bow_data if not bow_data.is_empty() else build_bow_data(
		segments,
		material_lookup,
		wip.forge_intent,
		wip.equipment_context,
		authored_cells,
		anchors
	)
	var profile: BakedProfile = bake_profile(
		cells,
		segments,
		anchors,
		material_lookup,
		shape_data,
		resolved_joint_data,
		resolved_bow_data,
		wip.forge_intent,
		wip.equipment_context
	)
	profile.profile_id = _build_profile_id(wip)
	profile.material_variant_mix = _collect_material_variant_mix(cells)
	profile.material_volume_mix = _collect_material_volume_mix(cells)
	profile.resolved_material_stat_lines = _collect_aggregated_material_lines(cells, material_lookup, &"material_stats")
	profile.resolved_capability_bias_lines = _collect_aggregated_material_lines(cells, material_lookup, &"capability_bias")
	profile.resolved_skill_family_bias_lines = _collect_aggregated_material_lines(cells, material_lookup, &"skill_family_bias")
	profile.resolved_elemental_affinity_lines = _collect_aggregated_material_lines(cells, material_lookup, &"elemental_affinity")
	profile.resolved_equipment_context_bias_lines = _collect_aggregated_material_lines(cells, material_lookup, &"equipment_context_bias")
	profile.capability_scores = derive_capability_scores(profile, profile.resolved_capability_bias_lines)
	profile.material_runtime_data_resolved = true
	wip.latest_baked_profile_snapshot = profile.duplicate(true) as BakedProfile
	return profile

func build_test_print_from_wip(
		wip: CraftedItemWIP,
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {},
		prefer_cached_profile: bool = false
	) -> TestPrintInstance:
	var profile: BakedProfile = (
		wip.latest_baked_profile_snapshot.duplicate(true) as BakedProfile
		if prefer_cached_profile and wip != null and wip.latest_baked_profile_snapshot != null
		else bake_wip(wip, material_lookup, shape_data, joint_data, bow_data)
	)
	if profile == null:
		return null

	var test_print: TestPrintInstance = TestPrintInstance.new()
	test_print.test_id = _build_test_print_id(wip)
	test_print.source_wip_id = wip.wip_id
	test_print.baked_profile = profile
	test_print.display_cells = _collect_wip_cells(wip)
	test_print.canonical_solid = canonical_solid_resolver.call("resolve_from_cells", test_print.display_cells)
	var stage1_canonical_geometry = canonical_geometry_resolver.call("resolve_from_solid", test_print.canonical_solid)
	var stage2_item_state = (
		wip.stage2_item_state.duplicate(true)
		if wip != null and wip.stage2_item_state != null
		else null
	)
	if (
		not _stage2_item_state_has_runtime_geometry(stage2_item_state)
	) and stage2_service != null:
		stage2_item_state = stage2_service.build_stage2_item_state_from_stage1(
			wip,
			test_print.canonical_solid,
			stage1_canonical_geometry,
			profile,
			material_lookup
		)
		if wip != null and stage2_item_state != null:
			wip.stage2_item_state = stage2_item_state.duplicate(true)
	var stage2_canonical_geometry = null
	if _stage2_item_state_has_runtime_geometry(stage2_item_state):
		stage2_canonical_geometry = stage2_item_state.build_current_canonical_geometry(test_print.canonical_solid)
	test_print.stage2_item_state = stage2_item_state
	test_print.canonical_geometry = (
		stage2_canonical_geometry
		if stage2_canonical_geometry != null and not stage2_canonical_geometry.is_empty()
		else stage1_canonical_geometry
	)
	test_print.visual_mesh_source = (
		&"editable_mesh"
		if (
			stage2_item_state != null
			and stage2_item_state.has_current_editable_mesh()
			and bool(stage2_item_state.get("editable_mesh_visual_authority"))
		)
		else &"canonical_geometry"
	)
	return test_print

func build_material_variant(base_material: BaseMaterialDef, tier: TierDef) -> MaterialVariantDef:
	return tier_resolver.build_variant(base_material, tier)

func build_material_stack(process_rule: ProcessRuleDef, material_variant: MaterialVariantDef) -> ForgeMaterialStack:
	return process_resolver.build_stack(process_rule, material_variant)

func build_segments(cells: Array[CellAtom], material_lookup: Dictionary = {}) -> Array[SegmentAtom]:
	return segment_resolver.resolve_segments(cells, material_lookup)

func build_anchors(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Array[AnchorAtom]:
	return anchor_resolver.resolve_anchors(segments, material_lookup)

func classify_joint_segments(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Array[SegmentAtom]:
	return joint_resolver.classify_joint_segments(segments, material_lookup)

func build_joint_data(segments: Array[SegmentAtom], material_lookup: Dictionary = {}) -> Dictionary:
	for segment: SegmentAtom in segments:
		if segment == null:
			continue
		if not joint_resolver.validate_joint_chain(segment, material_lookup):
			continue
		return joint_resolver.resolve_joint_properties(segment)
	return {
		"joint_chain_valid": false,
		"joint_type": &"none",
		"joint_axis": Vector3.ZERO,
		"motion_plane": &"",
		"link_count": 0,
		"hinge_count": 0,
		"angle_limit_min": 0.0,
		"angle_limit_max": 0.0,
		"supports_axial_spin": false,
		"supports_planar_hinge": false,
		"self_collision_mode": &"none",
		"validation_error": &"no_valid_joint_chain",
	}

func build_bow_data(
	segments: Array[SegmentAtom],
	material_lookup: Dictionary = {},
	forge_intent: StringName = &"",
	equipment_context: StringName = &"",
	authored_cells: Array[CellAtom] = [],
	anchors: Array[AnchorAtom] = []
) -> Dictionary:
	var resolved_anchors: Array[AnchorAtom] = anchors
	if resolved_anchors.is_empty():
		resolved_anchors = build_anchors(segments, material_lookup)
	var primary_grip_valid: bool = false
	for anchor: AnchorAtom in resolved_anchors:
		if anchor == null:
			continue
		if anchor.anchor_type == "primary_grip":
			primary_grip_valid = true
			break
	return bow_resolver.validate_bow_structure(
		segments,
		material_lookup,
		forge_intent,
		equipment_context,
		authored_cells,
		primary_grip_valid
	)

func bake_profile(
		cells: Array[CellAtom],
		segments: Array[SegmentAtom],
		anchors: Array[AnchorAtom],
		material_lookup: Dictionary = {},
		shape_data: Dictionary = {},
		joint_data: Dictionary = {},
		bow_data: Dictionary = {},
		forge_intent: StringName = &"",
		equipment_context: StringName = &""
	) -> BakedProfile:
	return profile_resolver.bake_profile(
		cells,
		segments,
		anchors,
		material_lookup,
		shape_data,
		joint_data,
		bow_data,
		forge_intent,
		equipment_context
	)

func derive_capability_scores(
		profile: BakedProfile,
		material_bias_lines: Array[StatLine] = [],
		context_bias_lines: Array[StatLine] = []
	) -> Dictionary[StringName, float]:
	return capability_resolver.derive_capability_scores(profile, material_bias_lines, context_bias_lines)

func _collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	return CraftedItemWIP.collect_bake_cells(wip)

func _collect_authored_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	return CraftedItemWIP.collect_cells(wip, true)

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

func _stage2_item_state_has_runtime_geometry(stage2_item_state: Resource) -> bool:
	return (
		stage2_item_state != null
		and (
			(
				stage2_item_state.has_method("has_current_shell")
				and bool(stage2_item_state.call("has_current_shell"))
			)
			or _stage2_item_state_has_authoritative_editable_mesh(
				stage2_item_state
			)
		)
	)

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
	return (
		wip != null
		and wip.forge_v2_authoring_state != null
		and wip.layers.is_empty()
	)

func _build_test_print_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"test_print_runtime"
	return StringName("test_print_%s" % String(wip.wip_id))

func _build_profile_id(wip: CraftedItemWIP) -> StringName:
	if wip == null or wip.wip_id == StringName():
		return &"profile_runtime"
	return StringName("profile_%s" % String(wip.wip_id))

func _collect_aggregated_material_lines(
		cells: Array[CellAtom],
		material_lookup: Dictionary,
		line_kind: StringName
	) -> Array[StatLine]:
	var line_lookup: Dictionary = {}
	for cell: CellAtom in cells:
		_merge_stat_lines(line_lookup, _resolve_material_lines_for_cell(cell, material_lookup, line_kind))
	return _build_sorted_stat_line_array(line_lookup)

func _resolve_material_lines_for_cell(
		cell: CellAtom,
		material_lookup: Dictionary,
		line_kind: StringName
	) -> Array[StatLine]:
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

func _collect_material_variant_mix(cells: Array[CellAtom]) -> Dictionary:
	var material_variant_mix: Dictionary = {}
	for cell: CellAtom in cells:
		if cell == null or cell.material_variant_id == StringName():
			continue
		material_variant_mix[cell.material_variant_id] = int(material_variant_mix.get(cell.material_variant_id, 0)) + 1
	return material_variant_mix

func _collect_material_volume_mix(cells: Array[CellAtom]) -> Dictionary:
	var material_volume_mix: Dictionary = {}
	for cell: CellAtom in cells:
		if cell == null or cell.material_variant_id == StringName():
			continue
		material_volume_mix[cell.material_variant_id] = float(material_volume_mix.get(cell.material_variant_id, 0.0)) + 1.0
	return material_volume_mix
