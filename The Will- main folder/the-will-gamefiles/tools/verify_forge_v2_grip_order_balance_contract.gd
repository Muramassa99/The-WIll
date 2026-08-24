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
const ForgeV2SplinePathSamplerScript = preload(
	"res://runtime/forge_v2/forge_v2_spline_path_sampler.gd"
)
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_grip_order_balance_contract_2026-08-23.txt"
)
const CELL_SIZE_METERS := 0.0125
const POSITION_TOLERANCE_METERS := 0.0005
const AXIS_TOLERANCE := 0.0001
const SHELL_TOLERANCE_METERS := 0.0005
const HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS := 0.001
const MAX_PROFILE_OFFSET_SAMPLES := 256
const GEOMETRY_EPSILON := 0.000001
const VOLUME_EPSILON := 0.000000000001
const HANDLE_FINAL_PROFILE_AXIS_X_SIGN := -1.0

const HANDLE_START := Vector3(0.0, 0.0, 0.0)
const HANDLE_MIDDLE := Vector3(0.19, 0.08, 0.0)
const HANDLE_END := Vector3(0.38, 0.0, 0.0)

const ORDER_MESH_MIN := Vector3(0.0, 0.0, -0.05)
const ORDER_MESH_MAX := Vector3(0.38, 0.16, 0.05)
const BALANCE_MESH_MIN := Vector3(0.0, -0.05, -0.05)
const BALANCE_MESH_MAX := Vector3(0.60, 0.13, 0.05)

var result_lines: PackedStringArray = []
var failure_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	result_lines.append("Forge V2 grip order/balance contract")
	result_lines.append("cell_size_meters=%.6f" % CELL_SIZE_METERS)

	var forward_points := PackedVector3Array([
		HANDLE_START,
		HANDLE_MIDDLE,
		HANDLE_END,
	])
	var reverse_points := PackedVector3Array([
		HANDLE_END,
		HANDLE_MIDDLE,
		HANDLE_START,
	])
	var asymmetric_profile := _build_asymmetric_profile_polygon()
	var order_packet := _build_box_packet(
		ORDER_MESH_MIN,
		ORDER_MESH_MAX,
		&"verify_order_invariant_handle"
	)
	var forward_contract := _build_contract(
		forward_points,
		asymmetric_profile,
		order_packet,
		&"verify_grip_order_forward"
	)
	var reverse_contract := _build_contract(
		reverse_points,
		asymmetric_profile,
		order_packet,
		&"verify_grip_order_reverse"
	)
	var forward_profile := _require_valid_profile(
		forward_contract,
		"forward-order contract"
	)
	var reverse_profile := _require_valid_profile(
		reverse_contract,
		"reverse-order contract"
	)
	if forward_profile != null and reverse_profile != null:
		_verify_order_invariance(
			forward_profile,
			reverse_profile,
			forward_points
		)

	var balance_packet := _build_box_packet(
		BALANCE_MESH_MIN,
		BALANCE_MESH_MAX,
		&"verify_asymmetric_blade_mass_extension"
	)
	var balance_contract := _build_contract(
		forward_points,
		PackedVector2Array(),
		balance_packet,
		&"verify_grip_balance_seating"
	)
	var balance_profile := _require_valid_profile(
		balance_contract,
		"blade-balance contract"
	)
	if balance_profile != null:
		_verify_balance_seating(
			balance_profile,
			forward_points,
			balance_contract.get("test_handle_body", null) as Resource,
			AABB(
				BALANCE_MESH_MIN,
				BALANCE_MESH_MAX - BALANCE_MESH_MIN
			)
		)

	if failure_lines.is_empty():
		result_lines.append("ok=true")
		_write_results()
		for line: String in result_lines:
			print(line)
		quit(0)
		return
	result_lines.append("failure_count=%d" % failure_lines.size())
	for failure: String in failure_lines:
		result_lines.append("FAIL: %s" % failure)
	result_lines.append("ok=false")
	_write_results()
	for line: String in result_lines:
		print(line)
	push_error(
		"Forge V2 grip order/balance contract failed (%d checks)"
		% failure_lines.size()
	)
	quit(1)


func _verify_order_invariance(
	forward_profile: BakedProfile,
	reverse_profile: BakedProfile,
	forward_points: PackedVector3Array
) -> void:
	result_lines.append("scenario=reverse_point_order")
	var canonical_major := _canonicalize_axis(
		forward_points[forward_points.size() - 1] - forward_points[0]
	)
	var forward_major := forward_profile.primary_grip_slide_axis.normalized()
	var reverse_major := reverse_profile.primary_grip_slide_axis.normalized()
	var forward_contact := _profile_contact_meters(forward_profile)
	var reverse_contact := _profile_contact_meters(reverse_profile)
	var forward_tip := _profile_tip_meters(forward_profile)
	var reverse_tip := _profile_tip_meters(reverse_profile)
	var forward_pommel := _profile_pommel_meters(forward_profile)
	var reverse_pommel := _profile_pommel_meters(reverse_profile)
	var forward_shell := _build_effective_shell_points(forward_profile)
	var reverse_shell := _build_effective_shell_points(reverse_profile)
	# Reversing a Godot CSG path deliberately mirrors one transverse direction.
	# The fixture also supplies the same aggregate box mesh to both contracts, so
	# keep the world-shell delta diagnostic without treating it as an invariant.
	var shell_distance := _symmetric_point_set_distance(
		forward_shell,
		reverse_shell
	)
	var forward_offset_mean := _calculate_vector2_mean(
		forward_profile.primary_grip_profile_offsets_minor_meters
	)
	var reverse_offset_mean := _calculate_vector2_mean(
		reverse_profile.primary_grip_profile_offsets_minor_meters
	)
	var forward_shell_center := _calculate_point_mean(forward_shell)
	var reverse_shell_center := _calculate_point_mean(reverse_shell)
	var forward_tip_direction := (forward_tip - forward_contact).normalized()
	var reverse_tip_direction := (reverse_tip - reverse_contact).normalized()
	var forward_pommel_direction := (forward_pommel - forward_contact).normalized()
	var reverse_pommel_direction := (reverse_pommel - reverse_contact).normalized()
	var forward_tip_axial_position := forward_tip.dot(forward_major)
	var reverse_tip_axial_position := reverse_tip.dot(reverse_major)
	var forward_pommel_axial_position := forward_pommel.dot(forward_major)
	var reverse_pommel_axial_position := reverse_pommel.dot(reverse_major)
	var forward_handedness := _profile_frame_handedness(forward_profile)
	var reverse_handedness := _profile_frame_handedness(reverse_profile)

	result_lines.append("metric.order.canonical_major=%s" % canonical_major)
	result_lines.append("metric.order.forward_major=%s" % forward_major)
	result_lines.append("metric.order.reverse_major=%s" % reverse_major)
	result_lines.append(
		"metric.order.major_delta=%.9f"
		% forward_major.distance_to(reverse_major)
	)
	result_lines.append("metric.order.forward_contact_m=%s" % forward_contact)
	result_lines.append("metric.order.reverse_contact_m=%s" % reverse_contact)
	result_lines.append(
		"metric.order.contact_delta_m=%.9f"
		% forward_contact.distance_to(reverse_contact)
	)
	result_lines.append("metric.order.forward_tip_m=%s" % forward_tip)
	result_lines.append("metric.order.reverse_tip_m=%s" % reverse_tip)
	result_lines.append(
		"metric.order.tip_delta_m=%.9f"
		% forward_tip.distance_to(reverse_tip)
	)
	result_lines.append("metric.order.forward_pommel_m=%s" % forward_pommel)
	result_lines.append("metric.order.reverse_pommel_m=%s" % reverse_pommel)
	result_lines.append(
		"metric.order.pommel_delta_m=%.9f"
		% forward_pommel.distance_to(reverse_pommel)
	)
	result_lines.append(
		"metric.order.forward_shell_count=%d" % forward_shell.size()
	)
	result_lines.append(
		"metric.order.reverse_shell_count=%d" % reverse_shell.size()
	)
	result_lines.append(
		"metric.order.shell_symmetric_hausdorff_m=%.9f" % shell_distance
	)
	result_lines.append(
		"metric.order.reverse_path_directional_mirror_expected=true"
	)
	result_lines.append(
		"metric.order.forward_offset_mean_m=%s" % forward_offset_mean
	)
	result_lines.append(
		"metric.order.reverse_offset_mean_m=%s" % reverse_offset_mean
	)
	result_lines.append(
		"metric.order.forward_shell_center_error_m=%.9f"
		% forward_shell_center.distance_to(forward_contact)
	)
	result_lines.append(
		"metric.order.reverse_shell_center_error_m=%.9f"
		% reverse_shell_center.distance_to(reverse_contact)
	)
	result_lines.append(
		"metric.order.forward_tip_direction=%s" % forward_tip_direction
	)
	result_lines.append(
		"metric.order.reverse_tip_direction=%s" % reverse_tip_direction
	)
	result_lines.append(
		"metric.order.forward_pommel_direction=%s" % forward_pommel_direction
	)
	result_lines.append(
		"metric.order.reverse_pommel_direction=%s" % reverse_pommel_direction
	)
	result_lines.append(
		"metric.order.forward_tip_axial_position_m=%.9f"
		% forward_tip_axial_position
	)
	result_lines.append(
		"metric.order.reverse_tip_axial_position_m=%.9f"
		% reverse_tip_axial_position
	)
	result_lines.append(
		"metric.order.forward_pommel_axial_position_m=%.9f"
		% forward_pommel_axial_position
	)
	result_lines.append(
		"metric.order.reverse_pommel_axial_position_m=%.9f"
		% reverse_pommel_axial_position
	)
	result_lines.append(
		"metric.order.forward_frame_handedness=%.9f" % forward_handedness
	)
	result_lines.append(
		"metric.order.reverse_frame_handedness=%.9f" % reverse_handedness
	)

	_check(
		forward_major.distance_to(canonical_major) <= AXIS_TOLERANCE,
		"forward authored order exports the canonical major axis"
	)
	_check(
		reverse_major.distance_to(canonical_major) <= AXIS_TOLERANCE,
		"reverse authored order exports the same canonical major axis"
	)
	_check(
		forward_major.distance_to(reverse_major) <= AXIS_TOLERANCE,
		"major-axis direction is invariant under p0/p2 reversal"
	)
	_check(
		forward_tip_direction.distance_to(reverse_tip_direction) <= AXIS_TOLERANCE
		and forward_tip_direction.dot(forward_major) >= 1.0 - AXIS_TOLERANCE
		and reverse_tip_direction.dot(reverse_major) >= 1.0 - AXIS_TOLERANCE,
		"weapon tip direction is invariant and follows the exported major axis"
	)
	_check(
		forward_pommel_direction.distance_to(reverse_pommel_direction)
		<= AXIS_TOLERANCE
		and forward_pommel_direction.dot(-forward_major) >= 1.0 - AXIS_TOLERANCE
		and reverse_pommel_direction.dot(-reverse_major) >= 1.0 - AXIS_TOLERANCE,
		"weapon pommel direction remains opposite the exported major axis"
	)
	_check(
		absf(forward_tip_axial_position - reverse_tip_axial_position)
		<= POSITION_TOLERANCE_METERS
		and absf(forward_pommel_axial_position - reverse_pommel_axial_position)
		<= POSITION_TOLERANCE_METERS
		and absf(
			forward_profile.weapon_tip_distance_meters
			- reverse_profile.weapon_tip_distance_meters
		) <= POSITION_TOLERANCE_METERS
		and absf(
			forward_profile.weapon_pommel_distance_meters
			- reverse_profile.weapon_pommel_distance_meters
		) <= POSITION_TOLERANCE_METERS,
		"tip and pommel keep the same axial extremities and reaches"
	)
	_check(
		not forward_shell.is_empty() and not reverse_shell.is_empty(),
		"both authored orders produce an effective collision shell"
	)
	_check(
		forward_shell.size() == reverse_shell.size()
		and forward_offset_mean.length() <= SHELL_TOLERANCE_METERS
		and reverse_offset_mean.length() <= SHELL_TOLERANCE_METERS
		and forward_shell_center.distance_to(forward_contact)
		<= SHELL_TOLERANCE_METERS
		and reverse_shell_center.distance_to(reverse_contact)
		<= SHELL_TOLERANCE_METERS,
		"both collision shells remain zero-mean around their COM-seated contact"
	)
	_check(
		forward_handedness > 1.0 - AXIS_TOLERANCE
		and reverse_handedness > 1.0 - AXIS_TOLERANCE,
		"both authored orders export right-handed grip frames"
	)


func _verify_balance_seating(
	profile: BakedProfile,
	handle_points: PackedVector3Array,
	handle_body: Resource,
	visible_mesh_bounds: AABB
) -> void:
	result_lines.append("scenario=asymmetric_blade_balance")
	var center_of_mass := profile.center_of_mass * CELL_SIZE_METERS
	var curve_oracle := _resolve_auto_curve_contact_oracle(
		handle_points,
		handle_body,
		center_of_mass,
		CELL_SIZE_METERS
	)
	var expected_contact: Vector3 = curve_oracle.get(
		"contact",
		Vector3.INF
	) as Vector3
	var linear_polyline_contact := _closest_point_on_three_point_path(
		handle_points,
		center_of_mass
	)
	var chord_contact := _closest_point_on_segment(
		handle_points[0],
		handle_points[handle_points.size() - 1],
		center_of_mass
	)
	var actual_contact := _profile_contact_meters(profile)
	var shell_points := _build_effective_shell_points(profile)
	var shell_center := _calculate_point_mean(shell_points)
	var offset_mean := _calculate_vector2_mean(
		profile.primary_grip_profile_offsets_minor_meters
	)
	var actual_contact_error := actual_contact.distance_to(expected_contact)
	var midpoint_error := HANDLE_MIDDLE.distance_to(expected_contact)
	var curve_chord_delta := expected_contact.distance_to(chord_contact)
	var curve_polyline_delta := expected_contact.distance_to(
		linear_polyline_contact
	)
	var shell_contact_distance := shell_center.distance_to(actual_contact)
	var all_shell_points_visible := _all_points_inside_bounds(
		shell_points,
		visible_mesh_bounds.grow(POSITION_TOLERANCE_METERS)
	)

	result_lines.append("metric.balance.com_m=%s" % center_of_mass)
	result_lines.append("metric.balance.authored_middle_m=%s" % HANDLE_MIDDLE)
	result_lines.append(
		"metric.balance.expected_auto_curve_contact_m=%s" % expected_contact
	)
	result_lines.append(
		"metric.balance.linear_polyline_contact_m=%s" % linear_polyline_contact
	)
	result_lines.append("metric.balance.chord_projection_m=%s" % chord_contact)
	result_lines.append("metric.balance.actual_contact_m=%s" % actual_contact)
	result_lines.append(
		"metric.balance.auto_curve_oracle_valid=%s"
		% bool(curve_oracle.get("valid", false))
	)
	result_lines.append(
		"metric.balance.auto_curve_length_m=%.9f"
		% float(curve_oracle.get("curve_length", 0.0))
	)
	result_lines.append(
		"metric.balance.auto_curve_contact_offset_m=%.9f"
		% float(curve_oracle.get("contact_offset", -1.0))
	)
	result_lines.append(
		"metric.balance.final_profile_sample_center_m=%s"
		% (curve_oracle.get("profile_sample_center", Vector2.INF) as Vector2)
	)
	result_lines.append(
		"metric.balance.middle_to_expected_m=%.9f" % midpoint_error
	)
	result_lines.append(
		"metric.balance.auto_curve_vs_chord_m=%.9f" % curve_chord_delta
	)
	result_lines.append(
		"metric.balance.auto_curve_vs_linear_polyline_m=%.9f"
		% curve_polyline_delta
	)
	result_lines.append(
		"metric.balance.actual_contact_error_m=%.9f" % actual_contact_error
	)
	result_lines.append("metric.balance.shell_center_m=%s" % shell_center)
	result_lines.append(
		"metric.balance.profile_offset_mean_m=%s" % offset_mean
	)
	result_lines.append(
		"metric.balance.shell_center_to_contact_m=%.9f" % shell_contact_distance
	)
	result_lines.append(
		"metric.balance.shell_all_points_visible=%s" % all_shell_points_visible
	)
	result_lines.append(
		"metric.balance.blade_extension_beyond_handle_m=%.9f"
		% (BALANCE_MESH_MAX.x - HANDLE_END.x)
	)

	_check(
		midpoint_error >= 0.05,
		"asymmetric blade fixture moves the COM seat materially away from p1"
	)
	_check(
		bool(curve_oracle.get("valid", false)),
		"auto Curve3D displaced-centerline oracle resolved successfully"
	)
	_check(
		curve_chord_delta >= 0.01 and curve_polyline_delta >= 0.005,
		"bent-handle fixture distinguishes auto-curve seating from straight approximations"
	)
	_check(
		actual_contact_error <= POSITION_TOLERANCE_METERS,
		"primary contact seats at the COM-nearest point on the auto Curve3D profile centerline"
	)
	_check(
		offset_mean.length() <= SHELL_TOLERANCE_METERS
		and shell_contact_distance <= SHELL_TOLERANCE_METERS,
		"published profile offsets and effective shell remain centered on contact"
	)
	_check(
		visible_mesh_bounds.grow(POSITION_TOLERANCE_METERS).has_point(
			actual_contact
		),
		"COM-seated primary contact remains inside the visible final mesh"
	)
	_check(
		not shell_points.is_empty() and all_shell_points_visible,
		"effective collision shell remains on the visible Handle"
	)


func _build_contract(
	handle_points: PackedVector3Array,
	profile_override: PackedVector2Array,
	mesh_packet: Dictionary,
	wip_id: StringName
) -> Dictionary:
	var fixture := _build_committed_handle_fixture(
		handle_points,
		profile_override,
		String(wip_id)
	)
	if not bool(fixture.get("valid", false)):
		return {
			"valid": false,
			"error": String(fixture.get("error", "Handle fixture failed")),
		}
	var state: Resource = fixture.get("state") as Resource
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = wip_id
	wip.forge_project_name = "Forge V2 Grip Order/Balance Verification"
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	wip.forge_v2_authoring_state = state.duplicate(true) as Resource
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		mesh_packet,
		CELL_SIZE_METERS
	)
	contract["test_handle_body"] = fixture.get("handle_body", null)
	return contract


func _build_committed_handle_fixture(
	handle_points: PackedVector3Array,
	profile_override: PackedVector2Array,
	project_name: String
) -> Dictionary:
	if handle_points.size() != 3:
		return {"valid": false, "error": "fixture requires exactly three points"}
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"valid": false, "error": "no Handle profile entries are available"}
	var profile_id := StringName(profile_entries[0].get("id", StringName()))
	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", project_name)
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", profile_id)
	for point: Vector3 in handle_points:
		if int(state.call("append_spline_line_point", point, Vector3.UP)) < 0:
			return {"valid": false, "error": "Handle fixture rejected a point"}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return {"valid": false, "error": "Handle fixture did not generate"}
	var handle_body: Resource = state.call("get_selected_material_body") as Resource
	if handle_body == null:
		return {"valid": false, "error": "generated Handle body is missing"}
	if not profile_override.is_empty():
		handle_body.set(
			"profile_polygon_2d_meters",
			PackedVector2Array(profile_override)
		)
	var committed_layer: Resource = state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) as Resource
	if committed_layer == null:
		return {"valid": false, "error": "generated Handle did not commit"}
	return {
		"valid": true,
		"state": state,
		"handle_body": handle_body,
	}


func _build_asymmetric_profile_polygon() -> PackedVector2Array:
	# Local Y is deliberately off-center so a chronology-driven minor-axis flip
	# changes the effective world-space shell even though final geometry is equal.
	return PackedVector2Array([
		Vector2(-0.025, -0.010),
		Vector2(0.025, -0.010),
		Vector2(0.025, 0.030),
		Vector2(-0.025, 0.030),
	])


func _build_box_packet(
	minimum: Vector3,
	maximum: Vector3,
	source_id: StringName
) -> Dictionary:
	var vertices := PackedVector3Array([
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z),
	])
	var indices := PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 4, 7, 0, 7, 3,
		1, 2, 6, 1, 6, 5,
		0, 1, 5, 0, 5, 4,
		3, 7, 6, 3, 6, 2,
	])
	var size := maximum - minimum
	return {
		"ok": true,
		"vertices": vertices,
		"indices": indices,
		"watertight": true,
		"output_volume_m3": size.x * size.y * size.z,
		"source_original_ids": PackedStringArray([String(source_id)]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 1,
	}


func _require_valid_profile(contract: Dictionary, label: String) -> BakedProfile:
	if not bool(contract.get("valid", false)):
		_check(false, "%s was rejected: %s" % [
			label,
			String(contract.get("error", "unknown adapter error")),
		])
		return null
	var profile := contract.get("baked_profile", null) as BakedProfile
	if profile == null or not profile.primary_grip_valid:
		_check(false, "%s did not produce a valid primary grip" % label)
		return null
	return profile


func _profile_contact_meters(profile: BakedProfile) -> Vector3:
	return profile.primary_grip_contact_position * CELL_SIZE_METERS


func _profile_tip_meters(profile: BakedProfile) -> Vector3:
	return profile.weapon_tip_point * CELL_SIZE_METERS


func _profile_pommel_meters(profile: BakedProfile) -> Vector3:
	return profile.weapon_pommel_point * CELL_SIZE_METERS


func _build_effective_shell_points(profile: BakedProfile) -> PackedVector3Array:
	var points := PackedVector3Array()
	if profile == null:
		return points
	var contact := _profile_contact_meters(profile)
	var minor_axis_a := profile.primary_grip_minor_axis_a.normalized()
	var minor_axis_b := profile.primary_grip_minor_axis_b.normalized()
	for offset: Vector2 in profile.primary_grip_profile_offsets_minor_meters:
		points.append(
			contact
			+ minor_axis_a * offset.x
			+ minor_axis_b * offset.y
		)
	return points


func _profile_frame_handedness(profile: BakedProfile) -> float:
	var major := profile.primary_grip_slide_axis.normalized()
	var minor_a := profile.primary_grip_minor_axis_a.normalized()
	var minor_b := profile.primary_grip_minor_axis_b.normalized()
	return minor_a.cross(minor_b).dot(major)


func _canonicalize_axis(axis: Vector3) -> Vector3:
	var normalized := axis.normalized()
	if normalized.length_squared() <= 0.000001:
		return Vector3.RIGHT
	var absolute := normalized.abs()
	var dominant_component := normalized.x
	if absolute.y > absolute.x and absolute.y >= absolute.z:
		dominant_component = normalized.y
	elif absolute.z > absolute.x and absolute.z > absolute.y:
		dominant_component = normalized.z
	return -normalized if dominant_component < 0.0 else normalized


func _resolve_auto_curve_contact_oracle(
	handle_points: PackedVector3Array,
	handle_body: Resource,
	desired_contact: Vector3,
	cell_size_meters: float
) -> Dictionary:
	if handle_body == null or handle_points.size() < 2:
		return {"valid": false, "error": "Handle oracle input is incomplete"}
	var curve := ForgeV2SplinePathSamplerScript.build_auto_curve(
		handle_points,
		HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS,
		true
	)
	if curve == null or curve.point_count < 2 or curve.get_baked_length() <= 0.0:
		return {"valid": false, "error": "auto Curve3D did not bake"}
	_apply_oracle_curve_orientation(curve, handle_body, handle_points)

	var authored_polygon: PackedVector2Array = handle_body.get(
		"profile_polygon_2d_meters"
	)
	var authored_samples := _build_oracle_profile_offset_samples(
		authored_polygon,
		cell_size_meters
	)
	var final_samples := PackedVector2Array()
	for authored_sample: Vector2 in authored_samples:
		final_samples.append(Vector2(
			authored_sample.x * HANDLE_FINAL_PROFILE_AXIS_X_SIGN,
			authored_sample.y
		))
	var sample_center := _calculate_vector2_mean(final_samples)

	var curve_length := curve.get_baked_length()
	var sample_count := maxi(
		int(ceil(curve_length / HANDLE_GRIP_CURVE_BAKE_INTERVAL_METERS)),
		1
	)
	var curve_offsets := PackedFloat32Array()
	var displaced_centerline := PackedVector3Array()
	for sample_index: int in range(sample_count + 1):
		var curve_offset := curve_length * float(sample_index) / float(sample_count)
		var frame := _resolve_oracle_csg_profile_frame(curve, curve_offset)
		var curve_position: Vector3 = frame.get(
			"position",
			curve.sample_baked(curve_offset)
		) as Vector3
		var axis_a: Vector3 = frame.get("axis_x", Vector3.UP) as Vector3
		var axis_b: Vector3 = frame.get("axis_y", Vector3.FORWARD) as Vector3
		curve_offsets.append(curve_offset)
		displaced_centerline.append(
			curve_position + axis_a * sample_center.x + axis_b * sample_center.y
		)
	var closest_state := _resolve_oracle_closest_centerline_state(
		displaced_centerline,
		curve_offsets,
		desired_contact
	)
	var contact_offset := clampf(
		float(closest_state.get("curve_offset", curve_length * 0.5)),
		0.0,
		curve_length
	)
	var contact_frame := _resolve_oracle_csg_profile_frame(curve, contact_offset)
	var contact_position: Vector3 = contact_frame.get(
		"position",
		curve.sample_baked(contact_offset)
	) as Vector3
	var contact_axis_a: Vector3 = contact_frame.get("axis_x", Vector3.UP) as Vector3
	var contact_axis_b: Vector3 = contact_frame.get(
		"axis_y",
		Vector3.FORWARD
	) as Vector3
	return {
		"valid": true,
		"contact": (
			contact_position
			+ contact_axis_a * sample_center.x
			+ contact_axis_b * sample_center.y
		),
		"contact_offset": contact_offset,
		"curve_length": curve_length,
		"profile_sample_center": sample_center,
		"centerline_sample_count": displaced_centerline.size(),
	}


func _apply_oracle_curve_orientation(
	curve: Curve3D,
	handle_body: Resource,
	handle_points: PackedVector3Array
) -> void:
	var path_normals: PackedVector3Array = handle_body.get("path_surface_normals")
	var contact_direction: Vector2 = handle_body.get("profile_contact_direction_2d")
	var rotation_bias := float(handle_body.get("profile_rotation_bias_degrees"))
	var previous_tilt := 0.0
	var has_previous_tilt := false
	var normals_align := (
		curve.point_count == handle_points.size()
		and path_normals.size() >= handle_points.size()
	)
	for point_index: int in range(curve.point_count):
		var tangent := _resolve_oracle_curve_control_tangent(curve, point_index)
		var point_position := curve.get_point_position(point_index)
		var surface_normal := Vector3.FORWARD
		if normals_align and point_position.is_equal_approx(handle_points[point_index]):
			surface_normal = (
				ForgeV2ProfileShapeLibraryScript.interpolate_path_surface_normal(
					path_normals,
					point_index,
					0.0
				)
			)
		else:
			surface_normal = ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
				point_position,
				handle_points,
				path_normals
			)
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			surface_normal,
			contact_direction,
			rotation_bias
		)
		var tilt := float(frame.get("tilt_radians", 0.0))
		if has_previous_tilt:
			while tilt - previous_tilt > PI:
				tilt -= TAU
			while tilt - previous_tilt < -PI:
				tilt += TAU
		curve.set_point_tilt(point_index, tilt)
		previous_tilt = tilt
		has_previous_tilt = true


func _resolve_oracle_curve_control_tangent(
	curve: Curve3D,
	point_index: int
) -> Vector3:
	var current_position := curve.get_point_position(point_index)
	var tangent := Vector3.ZERO
	if point_index > 0:
		tangent += current_position - curve.get_point_position(point_index - 1)
	if point_index < curve.point_count - 1:
		tangent += curve.get_point_position(point_index + 1) - current_position
	return (
		tangent.normalized()
		if tangent.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
		else Vector3.RIGHT
	)


func _resolve_oracle_csg_profile_frame(
	curve: Curve3D,
	curve_offset: float
) -> Dictionary:
	var safe_offset := clampf(curve_offset, 0.0, curve.get_baked_length())
	var pose := curve.sample_baked_with_rotation(safe_offset, false, false)
	var tangent := (pose.basis * Vector3.FORWARD).normalized()
	if tangent.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		var delta := maxf(curve.bake_interval * 0.5, 0.0001)
		tangent = (
			curve.sample_baked(minf(safe_offset + delta, curve.get_baked_length()))
			- curve.sample_baked(maxf(safe_offset - delta, 0.0))
		).normalized()
	var up := curve.sample_baked_up_vector(safe_offset, true).normalized()
	if up.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
		up = _resolve_oracle_profile_frame_fallback_normal(tangent)
	var facing := Transform3D.IDENTITY.looking_at(tangent, up)
	var axis_x := -facing.basis.x.normalized()
	var axis_y := facing.basis.y.normalized()
	if (
		axis_x.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
		or axis_y.length_squared() <= GEOMETRY_EPSILON * GEOMETRY_EPSILON
	):
		axis_x = _resolve_oracle_profile_frame_fallback_normal(tangent)
		axis_y = tangent.cross(axis_x).normalized()
	return {
		"position": curve.sample_baked(safe_offset),
		"tangent": tangent,
		"axis_x": axis_x,
		"axis_y": axis_y,
	}


func _resolve_oracle_closest_centerline_state(
	centerline_points: PackedVector3Array,
	curve_offsets: PackedFloat32Array,
	desired_position: Vector3
) -> Dictionary:
	var best_distance_squared := INF
	var best_offset := 0.0
	for point_index: int in range(maxi(centerline_points.size() - 1, 0)):
		var point_a := centerline_points[point_index]
		var point_b := centerline_points[point_index + 1]
		var segment := point_b - point_a
		var segment_length_squared := segment.length_squared()
		var ratio := 0.0
		if segment_length_squared > GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			ratio = clampf(
				(desired_position - point_a).dot(segment) / segment_length_squared,
				0.0,
				1.0
			)
		var candidate := point_a + segment * ratio
		var distance_squared := desired_position.distance_squared_to(candidate)
		if distance_squared >= best_distance_squared:
			continue
		best_distance_squared = distance_squared
		best_offset = lerpf(
			curve_offsets[point_index],
			curve_offsets[point_index + 1],
			ratio
		)
	return {
		"curve_offset": best_offset,
		"distance_squared": best_distance_squared,
	}


func _build_oracle_profile_offset_samples(
	polygon: PackedVector2Array,
	cell_size_meters: float
) -> PackedVector2Array:
	var samples := PackedVector2Array()
	if polygon.size() < 3:
		return samples
	var bounds := _calculate_oracle_polygon_bounds(polygon)
	var cell_size := maxf(cell_size_meters, 0.001)
	var half_cell := cell_size * 0.5
	var column_count := maxi(
		int(floor((bounds.size.x + GEOMETRY_EPSILON) / cell_size)),
		0
	)
	var row_count := maxi(
		int(floor((bounds.size.y + GEOMETRY_EPSILON) / cell_size)),
		0
	)
	if column_count <= 0 or row_count <= 0:
		return samples
	var occupied_size := Vector2(
		float(column_count) * cell_size,
		float(row_count) * cell_size
	)
	var leading_margin := (bounds.size - occupied_size) * 0.5
	var first_center := bounds.position + leading_margin + Vector2.ONE * half_cell
	var stride_cells := 1
	while (
		ceili(float(column_count) / float(stride_cells))
		* ceili(float(row_count) / float(stride_cells))
		> MAX_PROFILE_OFFSET_SAMPLES
	):
		stride_cells += 1
	for column_index in range(0, column_count, stride_cells):
		for row_index in range(0, row_count, stride_cells):
			var candidate := first_center + Vector2(
				float(column_index) * cell_size,
				float(row_index) * cell_size
			)
			if not _oracle_point_is_strictly_inside_polygon(candidate, polygon):
				continue
			_append_unique_oracle_profile_sample(samples, candidate)
			if samples.size() >= MAX_PROFILE_OFFSET_SAMPLES:
				return samples
	if samples.is_empty():
		var polygon_center := _calculate_oracle_polygon_centroid(polygon)
		var inset_bounds := bounds.grow(-half_cell)
		if (
			inset_bounds.has_point(polygon_center)
			and _oracle_point_is_strictly_inside_polygon(polygon_center, polygon)
		):
			_append_unique_oracle_profile_sample(samples, polygon_center)
	return samples


func _append_unique_oracle_profile_sample(
	samples: PackedVector2Array,
	candidate: Vector2
) -> void:
	for existing: Vector2 in samples:
		if existing.distance_squared_to(candidate) <= VOLUME_EPSILON:
			return
	samples.append(candidate)


func _oracle_point_is_strictly_inside_polygon(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	if not Geometry2D.is_point_in_polygon(point, polygon):
		return false
	for point_index in range(polygon.size()):
		if _oracle_distance_squared_to_segment(
			point,
			polygon[point_index],
			polygon[(point_index + 1) % polygon.size()]
		) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			return false
	return true


func _oracle_point_is_inside_or_on_polygon(
	point: Vector2,
	polygon: PackedVector2Array
) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon):
		return true
	for point_index in range(polygon.size()):
		if _oracle_distance_squared_to_segment(
			point,
			polygon[point_index],
			polygon[(point_index + 1) % polygon.size()]
		) <= GEOMETRY_EPSILON * GEOMETRY_EPSILON:
			return true
	return false


func _oracle_distance_squared_to_segment(
	point: Vector2,
	segment_start: Vector2,
	segment_end: Vector2
) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= VOLUME_EPSILON:
		return point.distance_squared_to(segment_start)
	var ratio := clampf(
		(point - segment_start).dot(segment) / segment_length_squared,
		0.0,
		1.0
	)
	return point.distance_squared_to(segment_start + segment * ratio)


func _calculate_oracle_polygon_centroid(
	polygon: PackedVector2Array
) -> Vector2:
	var signed_area_times_two := 0.0
	var centroid_numerator := Vector2.ZERO
	for point_index in range(polygon.size()):
		var point_a := polygon[point_index]
		var point_b := polygon[(point_index + 1) % polygon.size()]
		var cross := point_a.cross(point_b)
		signed_area_times_two += cross
		centroid_numerator += (point_a + point_b) * cross
	if absf(signed_area_times_two) > VOLUME_EPSILON:
		var centroid := centroid_numerator / (3.0 * signed_area_times_two)
		if _oracle_point_is_inside_or_on_polygon(centroid, polygon):
			return centroid
	var average := _calculate_vector2_mean(polygon)
	return average if _oracle_point_is_inside_or_on_polygon(average, polygon) else polygon[0]


func _calculate_oracle_polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var min_point := polygon[0]
	var max_point := polygon[0]
	for point: Vector2 in polygon:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _resolve_oracle_profile_frame_fallback_normal(axis: Vector3) -> Vector3:
	var normalized_axis := axis.normalized()
	var reference := Vector3.UP
	if absf(normalized_axis.dot(reference)) > 0.95:
		reference = Vector3.RIGHT
	var projected := reference - normalized_axis * reference.dot(normalized_axis)
	return (
		projected.normalized()
		if projected.length_squared() > GEOMETRY_EPSILON * GEOMETRY_EPSILON
		else Vector3.FORWARD
	)


func _closest_point_on_three_point_path(
	path_points: PackedVector3Array,
	query: Vector3
) -> Vector3:
	if path_points.is_empty():
		return Vector3.ZERO
	var closest := path_points[0]
	var closest_distance_squared := query.distance_squared_to(closest)
	for point_index in range(path_points.size() - 1):
		var candidate := _closest_point_on_segment(
			path_points[point_index],
			path_points[point_index + 1],
			query
		)
		var distance_squared := query.distance_squared_to(candidate)
		if distance_squared + 0.000000000001 < closest_distance_squared:
			closest = candidate
			closest_distance_squared = distance_squared
	return closest


func _closest_point_on_segment(
	segment_start: Vector3,
	segment_end: Vector3,
	query: Vector3
) -> Vector3:
	var segment := segment_end - segment_start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000000000001:
		return segment_start
	var ratio := clampf(
		(query - segment_start).dot(segment) / length_squared,
		0.0,
		1.0
	)
	return segment_start + segment * ratio


func _symmetric_point_set_distance(
	first: PackedVector3Array,
	second: PackedVector3Array
) -> float:
	if first.is_empty() or second.is_empty():
		return INF
	return maxf(
		_directed_point_set_distance(first, second),
		_directed_point_set_distance(second, first)
	)


func _directed_point_set_distance(
	source: PackedVector3Array,
	target: PackedVector3Array
) -> float:
	var maximum_nearest_distance := 0.0
	for source_point: Vector3 in source:
		var nearest_distance_squared := INF
		for target_point: Vector3 in target:
			nearest_distance_squared = minf(
				nearest_distance_squared,
				source_point.distance_squared_to(target_point)
			)
		maximum_nearest_distance = maxf(
			maximum_nearest_distance,
			sqrt(nearest_distance_squared)
		)
	return maximum_nearest_distance


func _calculate_point_mean(points: PackedVector3Array) -> Vector3:
	if points.is_empty():
		return Vector3(INF, INF, INF)
	var total := Vector3.ZERO
	for point: Vector3 in points:
		total += point
	return total / float(points.size())


func _calculate_vector2_mean(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.INF
	var total := Vector2.ZERO
	for point: Vector2 in points:
		total += point
	return total / float(points.size())


func _all_points_inside_bounds(points: PackedVector3Array, bounds: AABB) -> bool:
	if points.is_empty():
		return false
	for point: Vector3 in points:
		if not bounds.has_point(point):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		result_lines.append("PASS: %s" % message)
		return
	failure_lines.append("requirement not met: %s" % message)


func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(result_lines) + "\n")
	file.close()
