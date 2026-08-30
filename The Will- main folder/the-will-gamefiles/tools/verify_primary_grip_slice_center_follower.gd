extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2WipCompatibilityAdapterScript = preload(
	"res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd"
)
const PrimaryGripSeatResolverScript = preload(
	"res://core/resolvers/primary_grip_seat_resolver.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)
const PlayerRigGripLayoutPresenterScript = preload(
	"res://runtime/player/player_rig_grip_layout_presenter.gd"
)
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const CombatOriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload(
	"res://runtime/forge/test_print_mesh_builder.gd"
)
const PlayerEquippedItemPresenterScript = preload(
	"res://runtime/player/player_equipped_item_presenter.gd"
)
const CombatAnimationStationPreviewPresenterScript = preload(
	"res://runtime/combat/combat_animation_station_preview_presenter.gd"
)
const DEFAULT_FORGE_RULES: ForgeRulesDef = preload(
	"res://core/defs/forge/forge_rules_default.tres"
)
const DEFAULT_FORGE_VIEW_TUNING: ForgeViewTuningDef = preload(
	"res://core/defs/forge/forge_view_tuning_default.tres"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_primary_grip_slice_center_follower_2026-08-25.txt"
)
const CELL_SIZE_METERS := 0.0125
const HANDLE_LENGTH_METERS := 0.38
const POSITION_EPSILON_METERS := 0.000025
const RATIO_EPSILON := 0.00002
const AXIS_EPSILON := 0.00001
const MIN_BENT_MIDPOINT_OFFSET_METERS := 0.075
const MIN_CURVE_DECOY_SEPARATION_METERS := 0.10

const HANDLE_START := Vector3(0.0, 0.0, 0.0)
const HANDLE_END := Vector3(HANDLE_LENGTH_METERS, 0.0, 0.0)
const STRAIGHT_MIDDLE := Vector3(HANDLE_LENGTH_METERS * 0.5, 0.0, 0.0)
# Deliberately disagrees with the protected mesh's middle ring. The protected
# indexed mesh must own position; this curve remains only transverse-frame data.
const BENT_CONSTRUCTION_CURVE_DECOY_MIDDLE := Vector3(
	HANDLE_LENGTH_METERS * 0.5,
	-0.055,
	0.070
)

var target_ratios := PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
var symmetric_profile := PackedVector2Array([
	Vector2(-0.025, -0.020),
	Vector2(0.025, -0.020),
	Vector2(0.025, 0.020),
	Vector2(-0.025, 0.020),
])
# Convex but deliberately asymmetric: its shoelace centroid is neither the
# chord nor its bounding-box center.
var asymmetric_profile := PackedVector2Array([
	Vector2(-0.030, -0.020),
	Vector2(0.030, -0.020),
	Vector2(0.020, 0.030),
	Vector2(-0.010, 0.040),
	Vector2(-0.035, 0.010),
])

var result_lines := PackedStringArray()
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	result_lines.append("scope=primary_grip_exact_protected_mesh_slice_centers")
	result_lines.append("cell_size_meters=%.6f" % CELL_SIZE_METERS)
	_verify_resolver_fail_closed()

	var straight_fixture := _build_profile_fixture(
		PackedVector3Array([HANDLE_START, STRAIGHT_MIDDLE, HANDLE_END]),
		symmetric_profile,
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]),
		&"verify_primary_grip_exact_slice_straight"
	)
	var bent_fixture := _build_profile_fixture(
		PackedVector3Array([
			HANDLE_START,
			BENT_CONSTRUCTION_CURVE_DECOY_MIDDLE,
			HANDLE_END,
		]),
		asymmetric_profile,
		PackedVector2Array([
			Vector2.ZERO,
			Vector2(0.085, -0.045),
			Vector2.ZERO,
		]),
		&"verify_primary_grip_exact_slice_bent_asymmetric"
	)

	if not straight_fixture.is_empty():
		_verify_fixture(straight_fixture, "straight", false)
	if not bent_fixture.is_empty():
		_verify_fixture(bent_fixture, "bent_asymmetric", true)
		_verify_adapter_exact_mesh_gate(bent_fixture)
		_verify_stage2_exact_mesh_rebake(bent_fixture)
		_verify_held_item_skill_crafter_path(bent_fixture)
	_finish()


func _verify_resolver_fail_closed() -> void:
	var missing_profile := BakedProfile.new()
	missing_profile.primary_grip_valid = true
	missing_profile.primary_grip_span_start = Vector3.ZERO
	missing_profile.primary_grip_span_end = Vector3.RIGHT * 10.0
	missing_profile.primary_grip_slide_axis = Vector3.RIGHT
	var missing_state: Dictionary = (
		PrimaryGripSeatResolverScript.resolve_profile_seat(missing_profile, 0.5)
	)
	var layout_presenter = PlayerRigGripLayoutPresenterScript.new()
	var missing_layout: Dictionary = layout_presenter.resolve_grip_hold_layout(
		missing_profile,
		&"hand_right",
		CELL_SIZE_METERS,
		0.75
	)
	_check(
		not bool(missing_state.get("valid", false)),
		"resolver_missing_path_fail_closed",
		"seat resolver accepted a profile with no authoritative slice path"
	)
	_check(
		not bool(missing_layout.get("valid", false)),
		"layout_missing_path_fail_closed",
		"grip layout silently fell back to the endcap chord"
	)
	var mismatched_state: Dictionary = (
		PrimaryGripSeatResolverScript.resolve_sampled_seat(
			PackedFloat32Array([0.0, 0.5, 1.0]),
			PackedVector3Array([Vector3.ZERO, Vector3.RIGHT]),
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
			0.5
		)
	)
	_check(
		not bool(mismatched_state.get("valid", false)),
		"resolver_mismatched_path_fail_closed",
		"seat resolver accepted mismatched ratio and center arrays"
	)


func _build_profile_fixture(
	handle_points: PackedVector3Array,
	profile_polygon_source: PackedVector2Array,
	ring_offsets: PackedVector2Array,
	wip_id: StringName
) -> Dictionary:
	var profile_polygon := _ensure_counter_clockwise(profile_polygon_source)
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		_record_failure("%s: no Handle profile entry exists" % String(wip_id))
		return {}
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", String(wip_id))
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", StringName(
		profile_entries[0].get("id", StringName())
	))
	state.call("set_active_handle_rounding_enabled", false)
	for point: Vector3 in handle_points:
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			_record_failure("%s: Handle fixture rejected a point" % String(wip_id))
			return {}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		_record_failure("%s: Handle fixture did not generate" % String(wip_id))
		return {}
	var handle_body: Resource = state.call("get_selected_material_body") as Resource
	if handle_body == null:
		_record_failure("%s: generated Handle body is missing" % String(wip_id))
		return {}
	handle_body.set("profile_polygon_2d_meters", profile_polygon)
	handle_body.call("normalize")
	if state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) == null:
		_record_failure("%s: generated Handle did not commit" % String(wip_id))
		return {}

	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = wip_id
	wip.forge_project_name = String(wip_id)
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	wip.forge_v2_authoring_state = state.duplicate(true) as Resource
	wip.ensure_combat_animation_station_state()

	var mesh := _build_watertight_profile_sweep_mesh(
		PackedFloat32Array([0.0, 0.5, 1.0]),
		profile_polygon,
		ring_offsets
	)
	if not bool(mesh.get("valid", false)):
		_record_failure("%s: protected mesh fixture failed" % String(wip_id))
		return {}
	var packet := _build_runtime_mesh_packet(mesh, wip_id, handle_body)
	var contract: Dictionary = (
		ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
			wip,
			packet,
			CELL_SIZE_METERS
		)
	)
	if not bool(contract.get("valid", false)):
		_record_failure("%s: adapter rejected fixture: %s" % [
			String(wip_id),
			String(contract.get("error", "unknown adapter error")),
		])
		return {}
	var profile := contract.get("baked_profile", null) as BakedProfile
	if profile == null or not profile.primary_grip_valid:
		_record_failure("%s: adapter produced no valid grip profile" % String(wip_id))
		return {}
	wip.stage2_item_state = contract.get("stage2_item_state", null) as Resource
	wip.latest_baked_profile_snapshot = profile.duplicate(true) as BakedProfile
	return {
		"wip": wip,
		"contract": contract,
		"packet": packet,
		"profile": profile,
		"profile_centroid": _calculate_polygon_centroid(profile_polygon),
		"ring_offsets": PackedVector2Array(ring_offsets),
	}


func _verify_fixture(
	fixture: Dictionary,
	label: String,
	is_bent_decoy_fixture: bool
) -> void:
	var profile := fixture.get("profile", null) as BakedProfile
	if profile == null:
		_record_failure("%s: fixture profile is missing" % label)
		return
	var ratios := profile.primary_grip_slice_axis_ratios_from_span_start
	var centers := profile.primary_grip_slice_centers
	var path_valid := PrimaryGripSeatResolverScript.sampled_path_is_valid(
		ratios,
		centers
	)
	_check(
		path_valid,
		"%s_exported_path_valid" % label,
		"%s profile did not export an authoritative path" % label
	)
	if not path_valid:
		return

	var span_start_meters := profile.primary_grip_span_start * CELL_SIZE_METERS
	var span_end_meters := profile.primary_grip_span_end * CELL_SIZE_METERS
	var span_axis := (span_end_meters - span_start_meters).normalized()
	var slide_axis := profile.primary_grip_slide_axis.normalized()
	var start_error := span_start_meters.distance_to(HANDLE_START)
	var end_error := span_end_meters.distance_to(HANDLE_END)
	result_lines.append("%s_sample_count=%d" % [label, centers.size()])
	result_lines.append("%s_raw_span_start_error_meters=%.9f" % [label, start_error])
	result_lines.append("%s_raw_span_end_error_meters=%.9f" % [label, end_error])
	result_lines.append("%s_slide_axis_score=%.9f" % [
		label,
		slide_axis.dot(Vector3.RIGHT),
	])
	_check(
		start_error <= POSITION_EPSILON_METERS
		and end_error <= POSITION_EPSILON_METERS,
		"%s_raw_endcap_axis_preserved" % label,
		"%s span endpoints no longer preserve the raw Handle endcaps" % label
	)
	_check(
		span_axis.dot(Vector3.RIGHT) >= 1.0 - AXIS_EPSILON
		and slide_axis.dot(Vector3.RIGHT) >= 1.0 - AXIS_EPSILON,
		"%s_position_offset_does_not_rotate_authority_axis" % label,
		"%s slice offsets changed endcap/slide orientation authority" % label
	)

	var max_exported_ratio_error := 0.0
	for sample_index: int in range(centers.size()):
		max_exported_ratio_error = maxf(
			max_exported_ratio_error,
			absf(
				_project_ratio(
					centers[sample_index],
					profile.primary_grip_span_start,
					profile.primary_grip_span_end
				) - float(ratios[sample_index])
			)
		)
	result_lines.append("%s_max_exported_ratio_error=%.9f" % [
		label,
		max_exported_ratio_error,
	])
	_check(
		max_exported_ratio_error <= RATIO_EPSILON,
		"%s_centers_stay_on_perpendicular_stations" % label,
		"%s slice centers drifted along the raw axis" % label
	)

	var max_oracle_error := 0.0
	var max_seat_ratio_error := 0.0
	var midpoint_chord_offset := 0.0
	var midpoint_actual := Vector3.ZERO
	for target_ratio: float in target_ratios:
		var seat_state: Dictionary = (
			PrimaryGripSeatResolverScript.resolve_profile_seat(profile, target_ratio)
		)
		if not bool(seat_state.get("valid", false)):
			_record_failure("%s ratio %.2f did not resolve" % [label, target_ratio])
			continue
		var actual_meters := (
			seat_state.get("position", Vector3.INF) as Vector3
		) * CELL_SIZE_METERS
		var expected_meters := _resolve_analytic_sweep_slice_centroid(
			target_ratio,
			fixture.get("profile_centroid", Vector2.ZERO) as Vector2,
			fixture.get("ring_offsets", PackedVector2Array()) as PackedVector2Array
		)
		var oracle_error := actual_meters.distance_to(expected_meters)
		var seat_ratio_error := absf(
			_project_ratio(actual_meters, HANDLE_START, HANDLE_END) - target_ratio
		)
		max_oracle_error = maxf(max_oracle_error, oracle_error)
		max_seat_ratio_error = maxf(max_seat_ratio_error, seat_ratio_error)
		if is_equal_approx(target_ratio, 0.5):
			midpoint_actual = actual_meters
			midpoint_chord_offset = actual_meters.distance_to(
				HANDLE_START.lerp(HANDLE_END, target_ratio)
			)
		result_lines.append("%s_ratio_%.2f_actual_meters=%s" % [
			label,
			target_ratio,
			str(actual_meters),
		])
		result_lines.append("%s_ratio_%.2f_analytic_error_meters=%.9f" % [
			label,
			target_ratio,
			oracle_error,
		])
	result_lines.append("%s_max_analytic_error_meters=%.9f" % [
		label,
		max_oracle_error,
	])
	result_lines.append("%s_max_seat_ratio_error=%.9f" % [
		label,
		max_seat_ratio_error,
	])
	_check(
		max_oracle_error <= POSITION_EPSILON_METERS,
		"%s_matches_analytic_protected_mesh_slice_centroids" % label,
		"%s seats differ from the independent swept-polygon oracle" % label
	)
	_check(
		max_seat_ratio_error <= RATIO_EPSILON,
		"%s_requested_station_ratios_preserved" % label,
		"%s resolved seats moved along the raw axis" % label
	)

	if not is_bent_decoy_fixture:
		_check(
			midpoint_chord_offset <= POSITION_EPSILON_METERS,
			"straight_symmetric_handle_retains_chord_position",
			"straight symmetric Handle acquired a transverse offset"
		)
		return
	result_lines.append("bent_asymmetric_midpoint_chord_offset_meters=%.9f" % (
		midpoint_chord_offset
	))
	_check(
		midpoint_chord_offset >= MIN_BENT_MIDPOINT_OFFSET_METERS,
		"bent_asymmetric_fixture_rejects_chord_fallback",
		"bent/asymmetric mesh does not distinguish its centroid from the chord"
	)
	var profile_centroid := fixture.get("profile_centroid", Vector2.ZERO) as Vector2
	var curve_decoy_center := Vector3(
		BENT_CONSTRUCTION_CURVE_DECOY_MIDDLE.x,
		BENT_CONSTRUCTION_CURVE_DECOY_MIDDLE.y + profile_centroid.x,
		BENT_CONSTRUCTION_CURVE_DECOY_MIDDLE.z + profile_centroid.y
	)
	var decoy_separation := midpoint_actual.distance_to(curve_decoy_center)
	result_lines.append("bent_asymmetric_curve_decoy_separation_meters=%.9f" % (
		decoy_separation
	))
	_check(
		decoy_separation >= MIN_CURVE_DECOY_SEPARATION_METERS,
		"protected_mesh_position_wins_over_construction_curve",
		"fixture did not prove protected-mesh positional authority"
	)


func _verify_adapter_exact_mesh_gate(fixture: Dictionary) -> void:
	var wip := fixture.get("wip", null) as CraftedItemWIP
	var packet := (fixture.get("packet", {}) as Dictionary).duplicate(true)
	packet.erase("primary_grip_handle_vertices")
	packet.erase("primary_grip_handle_indices")
	packet.erase("primary_grip_handle_mesh_source")
	var contract: Dictionary = (
		ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
			wip,
			packet,
			CELL_SIZE_METERS
		)
	)
	var error := String(contract.get("error", ""))
	result_lines.append("missing_exact_mesh_error=%s" % error)
	_check(
		not bool(contract.get("valid", false))
		and error == "forge_v2_primary_handle_exact_mesh_missing",
		"adapter_missing_exact_handle_mesh_fail_closed",
		"adapter accepted a V2 Handle without exact protected mesh authority"
	)


func _verify_stage2_exact_mesh_rebake(fixture: Dictionary) -> void:
	var source_wip := fixture.get("wip", null) as CraftedItemWIP
	if source_wip == null or source_wip.stage2_item_state == null:
		_record_failure("stage2 exact Handle mesh state was not produced")
		return
	var handle_mesh_state := source_wip.stage2_item_state.get(
		"primary_grip_handle_mesh_state"
	) as Resource
	_check(
		handle_mesh_state != null
		and handle_mesh_state.has_method("has_surface_arrays")
		and bool(handle_mesh_state.call("has_surface_arrays")),
		"stage2_persists_exact_handle_mesh",
		"Stage2 did not retain protected Handle geometry for rebakes"
	)
	if handle_mesh_state == null:
		return
	var rebake_wip := source_wip.duplicate(true) as CraftedItemWIP
	var forge_service = ForgeServiceScript.new()
	var rebaked_profile := forge_service.bake_wip(rebake_wip, {}) as BakedProfile
	_check(
		rebaked_profile != null
		and rebaked_profile.primary_grip_valid
		and PrimaryGripSeatResolverScript.profile_has_authoritative_path(
			rebaked_profile
		),
		"forge_service_rebake_reuses_exact_handle_mesh",
		"ForgeService rebake lost protected Handle slice authority"
	)
	if rebaked_profile == null or not rebaked_profile.primary_grip_valid:
		return
	var expected_profile := fixture.get("profile", null) as BakedProfile
	var max_rebake_error := 0.0
	for target_ratio: float in target_ratios:
		var before_state := PrimaryGripSeatResolverScript.resolve_profile_seat(
			expected_profile,
			target_ratio
		)
		var after_state := PrimaryGripSeatResolverScript.resolve_profile_seat(
			rebaked_profile,
			target_ratio
		)
		if (
			not bool(before_state.get("valid", false))
			or not bool(after_state.get("valid", false))
		):
			max_rebake_error = INF
			break
		max_rebake_error = maxf(
			max_rebake_error,
			(before_state.get("position", Vector3.ZERO) as Vector3).distance_to(
				after_state.get("position", Vector3.INF) as Vector3
			) * CELL_SIZE_METERS
		)
	result_lines.append("forge_service_rebake_max_seat_error_meters=%.9f" % (
		max_rebake_error
	))
	_check(
		max_rebake_error <= POSITION_EPSILON_METERS,
		"forge_service_rebake_preserves_slice_centers",
		"persisted Handle geometry produced different seats after rebake"
	)


func _verify_held_item_skill_crafter_path(fixture: Dictionary) -> void:
	var source_wip := fixture.get("wip", null) as CraftedItemWIP
	var source_profile := fixture.get("profile", null) as BakedProfile
	if source_wip == null or source_profile == null:
		_record_failure("bent held-item fixture is incomplete")
		return
	var forge_service = ForgeServiceScript.new()
	var mesh_builder = TestPrintMeshBuilderScript.new()
	var equipped_presenter = PlayerEquippedItemPresenterScript.new()
	var held_item: Node3D = equipped_presenter.build_equipped_item_node(
		source_wip.duplicate(true) as CraftedItemWIP,
		&"hand_right",
		forge_service,
		{},
		mesh_builder,
		null,
		DEFAULT_FORGE_RULES,
		DEFAULT_FORGE_VIEW_TUNING,
		true
	)
	_check(
		held_item != null,
		"bent_fixture_builds_equipped_item",
		"the real equipped-item presenter rejected the bent V2 fixture"
	)
	if held_item == null:
		return
	var guide := held_item.get_node_or_null("PrimaryGripGuide") as Node3D
	var anchor := held_item.get_node_or_null("PrimaryGripAnchor") as Node3D
	var basis_anchor := held_item.get_node_or_null(
		"PrimaryGripAnchor/PrimaryGripBasisAnchor"
	) as Node3D
	_check(
		guide != null and anchor != null and basis_anchor != null,
		"equipped_item_has_primary_grip_consumers",
		"equipped item is missing its primary guide, anchor, or basis anchor"
	)
	if guide == null or anchor == null or basis_anchor == null:
		held_item.free()
		return

	var held_ratios_variant: Variant = held_item.get_meta(
		"primary_grip_slice_axis_ratios_from_span_start",
		null
	)
	var held_centers_variant: Variant = held_item.get_meta(
		"primary_grip_slice_centers_local",
		null
	)
	var metadata_types_valid := (
		held_ratios_variant is PackedFloat32Array
		and held_centers_variant is PackedVector3Array
	)
	_check(
		metadata_types_valid,
		"equipped_item_publishes_rebased_slice_path",
		"equipped item did not publish the sampled Handle path"
	)
	if not metadata_types_valid:
		held_item.free()
		return
	var held_ratios := held_ratios_variant as PackedFloat32Array
	var held_centers := held_centers_variant as PackedVector3Array
	var ratio_count_matches := (
		held_ratios.size()
		== source_profile.primary_grip_slice_axis_ratios_from_span_start.size()
	)
	var center_count_matches := (
		held_centers.size()
		== source_profile.primary_grip_slice_centers.size()
	)
	var max_ratio_copy_error := 0.0
	var max_rebase_error_meters := 0.0
	if ratio_count_matches and center_count_matches:
		for sample_index: int in range(held_centers.size()):
			max_ratio_copy_error = maxf(
				max_ratio_copy_error,
				absf(
					float(held_ratios[sample_index])
					- float(
						source_profile.primary_grip_slice_axis_ratios_from_span_start[
							sample_index
						]
					)
				)
			)
			var expected_rebased_center := (
				(
					source_profile.primary_grip_slice_centers[sample_index]
					- source_profile.primary_grip_contact_position
				)
				* CELL_SIZE_METERS
			)
			max_rebase_error_meters = maxf(
				max_rebase_error_meters,
				held_centers[sample_index].distance_to(expected_rebased_center)
			)
	result_lines.append(
		"held_item_path_max_ratio_copy_error=%.9f" % max_ratio_copy_error
	)
	result_lines.append(
		"held_item_path_max_rebase_error_meters=%.9f" % max_rebase_error_meters
	)
	_check(
		ratio_count_matches
		and center_count_matches
		and max_ratio_copy_error <= RATIO_EPSILON
		and max_rebase_error_meters <= POSITION_EPSILON_METERS
		and StringName(held_item.get_meta(
			"primary_grip_slice_center_path_origin_id",
			StringName()
		)) == CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"equipped_item_rebases_exact_path_once",
		"equipped path was not copied and rebased into weapon-root meters exactly once"
	)
	if not ratio_count_matches or not center_count_matches:
		held_item.free()
		return

	var base_ratio := float(held_item.get_meta(
		"primary_grip_axis_ratio_from_span_start",
		-1.0
	))
	var initial_seat := PrimaryGripSeatResolverScript.resolve_sampled_seat(
		held_ratios,
		held_centers,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		base_ratio
	)
	var initial_seat_valid := bool(initial_seat.get("valid", false))
	var initial_position := initial_seat.get(
		"position",
		Vector3.INF
	) as Vector3
	_check(
		initial_seat_valid
		and guide.position.distance_to(initial_position) <= POSITION_EPSILON_METERS
		and anchor.position.distance_to(initial_position) <= POSITION_EPSILON_METERS,
		"equipped_item_initial_guide_anchor_use_sampled_seat",
		"initial guide and anchor do not sit on the rebased Handle path"
	)

	var guide_basis := guide.transform.basis.orthonormalized()
	var anchor_basis := anchor.transform.basis.orthonormalized()
	var contact_basis := basis_anchor.transform.basis.orthonormalized()
	var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()
	var tip_side_ratio := float(held_item.get_meta(
		"primary_grip_handle_tip_side_axis_ratio_from_span_start",
		1.0
	))
	for handle_coordinate: float in [0.0, 0.5, 1.0]:
		var target_ratio := (
			PrimaryGripSeatResolverScript.resolve_handle_coordinate_axis_ratio(
				handle_coordinate,
				tip_side_ratio
			)
		)
		var expected_seat := PrimaryGripSeatResolverScript.resolve_sampled_seat(
			held_ratios,
			held_centers,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
			target_ratio
		)
		preview_presenter.call(
			"_apply_preview_motion_grip_state",
			held_item,
			null,
			{
				"grip_seat_slide_offset": handle_coordinate,
				"axial_reposition_offset": 0.0,
				"preferred_grip_style_mode": held_item.get_meta(
					"grip_style_mode",
					CraftedItemWIPScript.GRIP_NORMAL
				),
			},
			null
		)
		var expected_position := expected_seat.get(
			"position",
			Vector3.INF
		) as Vector3
		var slide_label := "pommel" if handle_coordinate <= 0.0 else (
			"tip" if handle_coordinate >= 1.0 else "midpoint"
		)
		result_lines.append(
			"preview_slide_%s_guide_error_meters=%.9f" % [
				slide_label,
				guide.position.distance_to(expected_position),
			]
		)
		result_lines.append(
			"preview_slide_%s_anchor_error_meters=%.9f" % [
				slide_label,
				anchor.position.distance_to(expected_position),
			]
		)
		_check(
			bool(expected_seat.get("valid", false))
			and guide.position.distance_to(expected_position)
			<= POSITION_EPSILON_METERS
			and anchor.position.distance_to(expected_position)
			<= POSITION_EPSILON_METERS,
			"preview_slide_%s_moves_guide_anchor_on_sampled_path" % slide_label,
			"Skill Crafter slide %s did not move both consumers to the sampled seat"
			% slide_label
		)
		_check(
			_basis_matches(guide.transform.basis, guide_basis)
			and _basis_matches(anchor.transform.basis, anchor_basis)
			and _basis_matches(basis_anchor.transform.basis, contact_basis),
			"preview_slide_%s_preserves_grip_bases" % slide_label,
			"Skill Crafter slide %s changed orientation authority" % slide_label
		)
	held_item.free()


func _basis_matches(actual: Basis, expected: Basis) -> bool:
	var actual_basis := actual.orthonormalized()
	return (
		actual_basis.x.distance_to(expected.x) <= AXIS_EPSILON
		and actual_basis.y.distance_to(expected.y) <= AXIS_EPSILON
		and actual_basis.z.distance_to(expected.z) <= AXIS_EPSILON
	)


func _build_watertight_profile_sweep_mesh(
	ring_ratios: PackedFloat32Array,
	profile_polygon: PackedVector2Array,
	ring_offsets: PackedVector2Array
) -> Dictionary:
	if (
		ring_ratios.size() < 2
		or ring_ratios.size() != ring_offsets.size()
		or profile_polygon.size() < 3
	):
		return {"valid": false}
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var profile_count := profile_polygon.size()
	for ring_index: int in range(ring_ratios.size()):
		var x := HANDLE_LENGTH_METERS * float(ring_ratios[ring_index])
		var ring_offset := ring_offsets[ring_index]
		for profile_point: Vector2 in profile_polygon:
			vertices.append(Vector3(
				x,
				profile_point.x + ring_offset.x,
				profile_point.y + ring_offset.y
			))
	for ring_index: int in range(ring_ratios.size() - 1):
		var from_offset := ring_index * profile_count
		var to_offset := (ring_index + 1) * profile_count
		for profile_index: int in range(profile_count):
			var next_profile_index := (profile_index + 1) % profile_count
			var from_a := from_offset + profile_index
			var from_b := from_offset + next_profile_index
			var to_a := to_offset + profile_index
			var to_b := to_offset + next_profile_index
			indices.append_array(PackedInt32Array([
				from_a, from_b, to_a,
				from_b, to_b, to_a,
			]))
	var cap_indices := Geometry2D.triangulate_polygon(profile_polygon)
	if cap_indices.size() < 3:
		return {"valid": false}
	var end_offset := (ring_ratios.size() - 1) * profile_count
	for triangle_offset: int in range(0, cap_indices.size(), 3):
		var a := int(cap_indices[triangle_offset])
		var b := int(cap_indices[triangle_offset + 1])
		var c := int(cap_indices[triangle_offset + 2])
		indices.append_array(PackedInt32Array([c, b, a]))
		indices.append_array(PackedInt32Array([
			end_offset + a,
			end_offset + b,
			end_offset + c,
		]))
	return {
		"valid": not vertices.is_empty() and indices.size() % 3 == 0,
		"vertices": vertices,
		"indices": indices,
	}


func _build_runtime_mesh_packet(
	mesh: Dictionary,
	source_id: StringName,
	handle_body: Resource
) -> Dictionary:
	var vertices := mesh.get("vertices", PackedVector3Array()) as PackedVector3Array
	var indices := mesh.get("indices", PackedInt32Array()) as PackedInt32Array
	return {
		"ok": true,
		"vertices": PackedVector3Array(vertices),
		"indices": PackedInt32Array(indices),
		"watertight": true,
		"primary_grip_handle_vertices": PackedVector3Array(vertices),
		"primary_grip_handle_indices": PackedInt32Array(indices),
		"primary_grip_handle_mesh_source": PrimaryGripHandleMeshPacketScript.SOURCE,
		"primary_grip_handle_body_signature": (
			PrimaryGripHandleMeshPacketScript.build_body_signature(handle_body)
		),
		"source_original_ids": PackedStringArray([String(source_id)]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 1,
	}


func _resolve_analytic_sweep_slice_centroid(
	target_ratio: float,
	profile_centroid: Vector2,
	ring_offsets: PackedVector2Array
) -> Vector3:
	var ratio := clampf(target_ratio, 0.0, 1.0)
	var segment_index := 0
	var segment_ratio := ratio * 2.0
	if ratio > 0.5:
		segment_index = 1
		segment_ratio = (ratio - 0.5) * 2.0
	var offset := ring_offsets[segment_index].lerp(
		ring_offsets[segment_index + 1],
		clampf(segment_ratio, 0.0, 1.0)
	)
	return Vector3(
		HANDLE_LENGTH_METERS * ratio,
		profile_centroid.x + offset.x,
		profile_centroid.y + offset.y
	)


func _ensure_counter_clockwise(
	polygon_source: PackedVector2Array
) -> PackedVector2Array:
	var polygon := PackedVector2Array(polygon_source)
	if _calculate_polygon_signed_area_twice(polygon) >= 0.0:
		return polygon
	var reversed := PackedVector2Array()
	for point_index: int in range(polygon.size() - 1, -1, -1):
		reversed.append(polygon[point_index])
	return reversed


func _calculate_polygon_centroid(polygon: PackedVector2Array) -> Vector2:
	var signed_area_twice := 0.0
	var numerator := Vector2.ZERO
	for point_index: int in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		var cross := point_a.cross(point_b)
		signed_area_twice += cross
		numerator += (point_a + point_b) * cross
	if absf(signed_area_twice) <= 0.000000000001:
		return Vector2.ZERO
	return numerator / (3.0 * signed_area_twice)


func _calculate_polygon_signed_area_twice(
	polygon: PackedVector2Array
) -> float:
	var signed_area_twice := 0.0
	for point_index: int in range(polygon.size()):
		signed_area_twice += polygon[point_index].cross(
		polygon[(point_index + 1) % polygon.size()]
	)
	return signed_area_twice


func _project_ratio(
	position: Vector3,
	span_start: Vector3,
	span_end: Vector3
) -> float:
	var span := span_end - span_start
	var span_length_squared := span.length_squared()
	if span_length_squared <= 0.000000000001:
		return 0.0
	return (position - span_start).dot(span) / span_length_squared


func _check(condition: bool, assertion_id: String, failure_message: String) -> void:
	result_lines.append("%s=%s" % [assertion_id, str(condition)])
	if not condition:
		_record_failure("%s: %s" % [assertion_id, failure_message])


func _record_failure(message: String) -> void:
	failures.append(message)
	result_lines.append("FAIL: %s" % message)


func _finish() -> void:
	result_lines.append("failure_count=%d" % failures.size())
	result_lines.append("ok=%s" % str(failures.is_empty()))
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines) + "\n")
		file.close()
	if failures.is_empty():
		print("Primary grip exact protected-mesh slice verifier passed")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)
