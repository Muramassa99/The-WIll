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
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2HistoryCheckpointScript = preload(
	"res://runtime/forge_v2/forge_v2_history_checkpoint.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)
const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_weighted_mass_orientation_contract_2026-08-29.txt"
)
const CELL_SIZE_METERS := 0.0125
const POSITION_TOLERANCE_METERS := 0.001
const RATIO_TOLERANCE := 0.001
const AXIS_TOLERANCE := 0.0001
const COM_AUTHORITY := &"forge_v2_spatial_material_occupancy_density"
const REBUILD_AUTHORITY := &"forge_v2_active_body_occupancy_rebuild"
const LEGACY_COM_STORAGE_TEST_PATH := (
	"user://verify_baked_profile_intrinsic_com_legacy_storage.tres"
)

const HANDLE_START := Vector3(-0.20, 0.0, 0.0)
const HANDLE_MIDDLE := Vector3.ZERO
const HANDLE_END := Vector3(0.20, 0.0, 0.0)
const LEFT_DEPOSIT_START := Vector3(-0.32, -0.09, 0.0)
const LEFT_DEPOSIT_END := Vector3(-0.32, 0.09, 0.0)
const RIGHT_DEPOSIT_START := Vector3(0.32, -0.09, 0.0)
const RIGHT_DEPOSIT_END := Vector3(0.32, 0.09, 0.0)
const DEPOSIT_RADIUS_METERS := 0.045
const HANDLE_HALF_WIDTH_METERS := 0.025
const HANDLE_HALF_DEPTH_METERS := 0.020
const FINAL_MESH_MIN := Vector3(-0.40, -0.16, -0.08)
const FINAL_MESH_MAX := Vector3(0.40, 0.16, 0.08)
const ONE_SIDED_MESH_MIN := Vector3(-0.23, -0.12, -0.09)
const ONE_SIDED_MESH_MAX := Vector3(0.80, 0.12, 0.09)
const ONE_SIDED_DEPOSIT_START := Vector3(0.22, 0.0, 0.0)
const ONE_SIDED_DEPOSIT_END := Vector3(0.72, 0.0, 0.0)
const ONE_SIDED_DEPOSIT_RADIUS_METERS := 0.06

var result_lines := PackedStringArray()
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	result_lines.append("Forge V2 weighted mass/orientation contract")
	result_lines.append("cell_size_meters=%.6f" % CELL_SIZE_METERS)
	_verify_legacy_center_of_mass_storage_contract()

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
	var equal := _build_contract_scenario(
		forward_points,
		&"mat_iron_gray",
		&"mat_iron_gray",
		&"verify_weighted_mass_equal"
	)
	var dense_right := _build_contract_scenario(
		forward_points,
		&"mat_wood_gray",
		&"mat_gold_gray",
		&"verify_weighted_mass_dense_right"
	)
	var dense_left := _build_contract_scenario(
		forward_points,
		&"mat_gold_gray",
		&"mat_wood_gray",
		&"verify_weighted_mass_dense_left"
	)
	var dense_right_reversed := _build_contract_scenario(
		reverse_points,
		&"mat_wood_gray",
		&"mat_gold_gray",
		&"verify_weighted_mass_dense_right_reverse_handle"
	)
	var one_sided := _build_one_sided_contract_scenario(
		forward_points,
		&"verify_weighted_mass_unclamped_positive"
	)

	var equal_profile := _require_profile(equal, "equal-density control")
	var dense_right_profile := _require_profile(
		dense_right,
		"right-side dense distribution"
	)
	var dense_left_profile := _require_profile(
		dense_left,
		"left-side dense distribution"
	)
	var reversed_profile := _require_profile(
		dense_right_reversed,
		"right-side dense distribution with reversed Handle points"
	)
	var one_sided_profile := _require_profile(
		one_sided,
		"one-sided heavily biased distribution"
	)

	if equal_profile != null:
		_verify_equal_density_control(equal, equal_profile)
		_verify_checkpoint_tail_spatial_equivalence(equal)
		_verify_malformed_initialized_checkpoint_rejected(equal)
	if dense_right_profile != null and dense_left_profile != null:
		_verify_mirrored_unequal_density(
			dense_right_profile,
			dense_left_profile
		)
	if dense_right_profile != null and reversed_profile != null:
		_verify_handle_order_invariance(
			dense_right_profile,
			reversed_profile
		)
	if one_sided_profile != null:
		_verify_unclamped_com_projection(one_sided_profile)

	if failures.is_empty():
		result_lines.append("ok=true")
		_write_results()
		for line: String in result_lines:
			print(line)
		quit(0)
		return
	result_lines.append("failure_count=%d" % failures.size())
	for failure: String in failures:
		result_lines.append("FAIL: %s" % failure)
	result_lines.append("ok=false")
	_write_results()
	for line: String in result_lines:
		print(line)
	push_error(
		"Forge V2 weighted mass/orientation contract failed (%d checks)"
		% failures.size()
	)
	quit(1)


func _verify_legacy_center_of_mass_storage_contract() -> void:
	result_lines.append("scenario=legacy_intrinsic_com_storage_compatibility")
	var legacy_vector := Vector3(1.25, -2.5, 3.75)
	var api_vector := Vector3(-4.5, 5.25, -6.0)
	var profile := BakedProfile.new()
	# This direct write deliberately emulates an existing saved V1/V2 resource.
	profile.center_of_mass = legacy_vector
	var legacy_api_readback := (
		profile.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
	)
	_check(
		legacy_api_readback.is_equal_approx(legacy_vector),
		"legacy center_of_mass backing is readable through the intrinsic COM API"
	)
	profile.set_weapon_intrinsic_center_of_mass_weapon_root_cells(
		api_vector,
		&"verify_legacy_storage_api",
		true
	)
	_check(
		profile.center_of_mass.is_equal_approx(api_vector),
		"intrinsic COM API writes the one legacy serialized backing field"
	)
	var save_error := ResourceSaver.save(profile, LEGACY_COM_STORAGE_TEST_PATH)
	var absolute_test_path := ProjectSettings.globalize_path(
		LEGACY_COM_STORAGE_TEST_PATH
	)
	var serialized_text := (
		FileAccess.get_file_as_string(absolute_test_path)
		if save_error == OK
		else ""
	)
	var loaded_profile := ResourceLoader.load(
		LEGACY_COM_STORAGE_TEST_PATH,
		"BakedProfile",
		ResourceLoader.CACHE_MODE_IGNORE
	) as BakedProfile
	var loaded_api_readback := (
		loaded_profile.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		if loaded_profile != null
		else Vector3(INF, INF, INF)
	)
	_check(save_error == OK, "legacy COM compatibility fixture saves")
	_check(
		serialized_text.count("center_of_mass =") == 1,
		"serialized profile retains exactly one center_of_mass backing property"
	)
	_check(
		loaded_profile != null
		and loaded_api_readback.is_equal_approx(api_vector),
		"saved legacy COM backing round-trips through the intrinsic COM API"
	)
	if FileAccess.file_exists(absolute_test_path):
		DirAccess.remove_absolute(absolute_test_path)


func _verify_equal_density_control(
	scenario: Dictionary,
	profile: BakedProfile
) -> void:
	result_lines.append("scenario=equal_density_midpoint")
	var center_of_mass_meters := (
		profile.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		* CELL_SIZE_METERS
	)
	var spatial_summary := scenario.get("spatial_summary", {}) as Dictionary
	result_lines.append("metric.equal.com_m=%s" % center_of_mass_meters)
	result_lines.append(
		"metric.equal.com_ratio_unclamped=%.9f"
		% profile.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped
	)
	result_lines.append(
		"metric.equal.handle_coordinate_mode=%s"
		% String(profile.primary_grip_handle_coordinate_mode)
	)
	result_lines.append(
		"metric.equal.tip_ratio=%.9f"
		% profile.primary_grip_handle_tip_side_axis_ratio_from_span_start
	)
	result_lines.append(
		"metric.equal.spatial_authority=%s"
		% StringName(spatial_summary.get("spatial_authority_source", StringName()))
	)
	var expected_exact_volume_cell_equivalents := (
		(FINAL_MESH_MAX - FINAL_MESH_MIN).x
		* (FINAL_MESH_MAX - FINAL_MESH_MIN).y
		* (FINAL_MESH_MAX - FINAL_MESH_MIN).z
		/ pow(CELL_SIZE_METERS, 3.0)
	)

	_check(
		center_of_mass_meters.distance_to(Vector3.ZERO)
		<= POSITION_TOLERANCE_METERS,
		"equal-density symmetric occupancy resolves the exact mesh midpoint"
	)
	_check(
		absf(
			profile.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped
			- 0.5
		) <= RATIO_TOLERANCE,
		"equal-density control publishes the midpoint COM ratio"
	)
	_check(
		profile.primary_grip_center_balance_valid
		and profile.primary_grip_handle_coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
		and profile.primary_grip_handle_coordinate_mode_authority_source
		== BakedProfile
		.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_AUTHORITY_WEAPON_INTRINSIC_COM
		and absf(
			profile.primary_grip_handle_zero_axis_ratio_from_span_start - 0.5
		) <= RATIO_TOLERANCE,
		"midpoint COM selects balanced Handle zero at ratio 0.5"
	)
	_check(
		(profile.primary_grip_handle_zero_position * CELL_SIZE_METERS).distance_to(
			Vector3.ZERO
		) <= POSITION_TOLERANCE_METERS,
		"balanced Handle zero publishes the sampled midpoint position"
	)
	_check(
		profile.primary_grip_handle_tip_side_axis_ratio_from_span_start
		>= 1.0 - RATIO_TOLERANCE
		and profile.primary_grip_handle_tip_side_direction.normalized().dot(
			Vector3.RIGHT
		) >= 1.0 - AXIS_TOLERANCE
		and _profile_tip_meters(profile).x > _profile_pommel_meters(profile).x,
		"exact midpoint tie selects the canonical-positive Tip side"
	)
	_check(
		absf(
			profile.total_volume_cell_equivalents
			- expected_exact_volume_cell_equivalents
		) <= RATIO_TOLERANCE
		and profile.total_mass > 0.0,
		"spatial material weighting preserves exact final-mesh volume and mass"
	)
	_verify_authority_metadata(profile, spatial_summary, "equal-density control")


func _verify_mirrored_unequal_density(
	dense_right: BakedProfile,
	dense_left: BakedProfile
) -> void:
	result_lines.append("scenario=mirrored_unequal_density")
	var right_com := (
		dense_right.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		* CELL_SIZE_METERS
	)
	var left_com := (
		dense_left.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		* CELL_SIZE_METERS
	)
	result_lines.append("metric.mirror.dense_right_com_m=%s" % right_com)
	result_lines.append("metric.mirror.dense_left_com_m=%s" % left_com)
	result_lines.append(
		"metric.mirror.com_symmetry_error_m=%.9f"
		% right_com.distance_to(-left_com)
	)
	result_lines.append(
		"metric.mirror.dense_right_tip_m=%s" % _profile_tip_meters(dense_right)
	)
	result_lines.append(
		"metric.mirror.dense_left_tip_m=%s" % _profile_tip_meters(dense_left)
	)

	_check(
		right_com.x > POSITION_TOLERANCE_METERS
		and left_com.x < -POSITION_TOLERANCE_METERS,
		"higher-density material shifts true COM toward its authored side"
	)
	_check(
		right_com.distance_to(-left_com) <= POSITION_TOLERANCE_METERS,
		"mirroring the unequal-density materials mirrors true COM"
	)
	_check(
		absf(dense_right.total_mass - dense_left.total_mass) <= RATIO_TOLERANCE
		and is_equal_approx(
			dense_right.total_volume_cell_equivalents,
			dense_left.total_volume_cell_equivalents
		),
		"mirrored material assignments preserve total mass and exact volume"
	)
	_check(
		dense_right.primary_grip_handle_tip_side_axis_ratio_from_span_start
		>= 1.0 - RATIO_TOLERANCE
		and dense_left.primary_grip_handle_tip_side_axis_ratio_from_span_start
		<= RATIO_TOLERANCE
		and _profile_tip_meters(dense_right).x > 0.0
		and _profile_pommel_meters(dense_right).x < 0.0
		and _profile_tip_meters(dense_left).x < 0.0
		and _profile_pommel_meters(dense_left).x > 0.0,
		"semantic Tip/Pommel follows the true COM side in both mirrors"
	)
	_check(
		dense_right.primary_grip_handle_coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
		and dense_left.primary_grip_handle_coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
		and dense_right.primary_grip_handle_zero_axis_ratio_from_span_start
		<= RATIO_TOLERANCE
		and dense_left.primary_grip_handle_zero_axis_ratio_from_span_start
		>= 1.0 - RATIO_TOLERANCE,
		"directional Handle zero selects the Pommel-side endcap"
	)
	_check(
		(dense_right.primary_grip_handle_zero_position * CELL_SIZE_METERS).x < 0.0
		and (dense_left.primary_grip_handle_zero_position * CELL_SIZE_METERS).x > 0.0,
		"directional Handle zero position is published on the opposite side from Tip"
	)


func _verify_handle_order_invariance(
	forward: BakedProfile,
	reversed: BakedProfile
) -> void:
	result_lines.append("scenario=reverse_handle_point_order")
	var forward_com := (
		forward.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		* CELL_SIZE_METERS
	)
	var reversed_com := (
		reversed.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		* CELL_SIZE_METERS
	)
	result_lines.append(
		"metric.order.com_delta_m=%.9f"
		% forward_com.distance_to(reversed_com)
	)
	result_lines.append(
		"metric.order.slide_axis_delta=%.9f"
		% forward.primary_grip_slide_axis.distance_to(
			reversed.primary_grip_slide_axis
		)
	)
	result_lines.append(
		"metric.order.zero_position_delta_m=%.9f"
		% (forward.primary_grip_handle_zero_position * CELL_SIZE_METERS).distance_to(
			reversed.primary_grip_handle_zero_position * CELL_SIZE_METERS
		)
	)

	_check(
		forward_com.distance_to(reversed_com) <= POSITION_TOLERANCE_METERS,
		"authored Handle point reversal leaves spatially weighted COM invariant"
	)
	_check(
		forward.primary_grip_slide_axis.distance_to(
			reversed.primary_grip_slide_axis
		) <= AXIS_TOLERANCE,
		"authored Handle point reversal leaves the canonical Handle axis invariant"
	)
	_check(
		absf(
			forward.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped
			- reversed.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped
		) <= RATIO_TOLERANCE
		and forward.primary_grip_handle_tip_side_axis_ratio_from_span_start
		== reversed.primary_grip_handle_tip_side_axis_ratio_from_span_start,
		"authored Handle point reversal leaves COM projection and Tip side invariant"
	)
	_check(
		_profile_tip_meters(forward).distance_to(_profile_tip_meters(reversed))
		<= POSITION_TOLERANCE_METERS
		and _profile_pommel_meters(forward).distance_to(
			_profile_pommel_meters(reversed)
		) <= POSITION_TOLERANCE_METERS,
		"authored Handle point reversal leaves semantic extremities invariant"
	)
	_check(
		forward.primary_grip_handle_coordinate_mode
		== reversed.primary_grip_handle_coordinate_mode
		and absf(
			forward.primary_grip_handle_zero_axis_ratio_from_span_start
			- reversed.primary_grip_handle_zero_axis_ratio_from_span_start
		) <= RATIO_TOLERANCE
		and (forward.primary_grip_handle_zero_position * CELL_SIZE_METERS).distance_to(
			reversed.primary_grip_handle_zero_position * CELL_SIZE_METERS
		) <= POSITION_TOLERANCE_METERS,
		"authored Handle point reversal leaves Handle zero invariant"
	)


func _verify_authority_metadata(
	profile: BakedProfile,
	spatial_summary: Dictionary,
	context: String
) -> void:
	var expected_origin := PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
	_check(
		profile.weapon_intrinsic_center_of_mass_spatial_material_valid
		and profile.weapon_intrinsic_center_of_mass_authority_source
		== COM_AUTHORITY,
		"%s publishes spatial material COM authority" % context
	)
	_check(
		profile.weapon_intrinsic_center_of_mass_origin_id == expected_origin
		and profile.primary_grip_handle_tip_side_direction_origin_id
		== expected_origin
		and profile.primary_grip_handle_zero_position_origin_id
		== expected_origin
		and profile.primary_grip_center_balance_origin_id == expected_origin
		and profile.primary_grip_slice_centers_origin_id == expected_origin,
		"%s publishes explicit WeaponRoot origins for COM and Handle vectors"
		% context
	)
	_check(
		bool(spatial_summary.get("ok", false))
		and bool(spatial_summary.get("spatial_material_positions_valid", false))
		and StringName(spatial_summary.get(
			"spatial_positions_origin_id",
			StringName()
		)) == expected_origin
		and StringName(spatial_summary.get(
			"spatial_authority_source",
			StringName()
		)) == REBUILD_AUTHORITY,
		"%s resolver summary publishes spatial validity, origin, and authority"
		% context
	)


func _verify_checkpoint_tail_spatial_equivalence(
	scenario: Dictionary
) -> void:
	result_lines.append("scenario=checkpoint_plus_protected_handle_plus_tail")
	var state := scenario.get("state") as Resource
	var handle_body := scenario.get("handle_body") as Resource
	var full_summary := scenario.get("spatial_summary", {}) as Dictionary
	if state == null or handle_body == null or not bool(full_summary.get(
		"ok",
		false
	)):
		_check(false, "checkpoint equivalence fixture is incomplete")
		return
	var ordinary_bodies: Array[Resource] = []
	for body_variant: Variant in state.get("material_bodies") as Array:
		var body := body_variant as Resource
		if body != null and body != handle_body:
			ordinary_bodies.append(body)
	if ordinary_bodies.size() < 2:
		_check(false, "checkpoint equivalence requires a prefix and active tail")
		return
	var prefix_body := ordinary_bodies[0]
	var active_tail_bodies: Array[Resource] = [handle_body]
	active_tail_bodies.append_array(ordinary_bodies.slice(1))
	var sample_cell_size_meters := float(full_summary.get(
		"resolver_sample_cell_size_meters",
		0.0
	))
	var resolver := ForgeV2MaterialVolumeResolverScript.new()
	var occupancy_delta := resolver.call(
		"build_checkpoint_occupancy_delta",
		{},
		[prefix_body],
		sample_cell_size_meters
	) as Dictionary
	var checkpoint := ForgeV2HistoryCheckpointScript.new() as Resource
	var next_identity := checkpoint.call(
		"build_next_identity_descriptor",
		1
	) as Dictionary
	var checkpoint_advanced := bool(checkpoint.call(
		"advance_logical_checkpoint_with_occupancy_delta",
		1,
		next_identity,
		StringName(prefix_body.get("material_variant_id")),
		{},
		1,
		sample_cell_size_meters,
		occupancy_delta
	))
	var restored_resolver := ForgeV2MaterialVolumeResolverScript.new()
	var restore_result: Dictionary = {}
	var restored_summary: Dictionary = {}
	if checkpoint_advanced:
		restore_result = restored_resolver.call(
			"restore_incremental_committed_cache_from_checkpoint",
			checkpoint.call("to_native_packet") as Dictionary,
			active_tail_bodies
		) as Dictionary
		if bool(restore_result.get("ok", false)):
			restored_summary = restored_resolver.call(
				"build_cached_spatial_usage_summary"
			) as Dictionary
	result_lines.append(
		"metric.checkpoint.full_cells=%d"
		% int(full_summary.get("spatial_occupied_cell_count", 0))
	)
	result_lines.append(
		"metric.checkpoint.restored_cells=%d"
		% int(restored_summary.get("spatial_occupied_cell_count", 0))
	)
	_check(
		bool(occupancy_delta.get("ok", false))
		and checkpoint_advanced
		and bool(restore_result.get("ok", false))
		and bool(restored_summary.get("ok", false)),
		"checkpoint prefix restores with protected Handle and active tail"
	)
	_check(
		_spatial_summaries_match(full_summary, restored_summary),
		"checkpoint + protected Handle + tail matches full-history spatial truth"
	)
	_check(
		StringName(restored_summary.get(
			"spatial_authority_source",
			StringName()
		)) == &"forge_v2_checkpoint_tail_occupancy_cache",
		"restored spatial summary identifies checkpoint-tail authority"
	)


func _verify_malformed_initialized_checkpoint_rejected(
	scenario: Dictionary
) -> void:
	result_lines.append("scenario=malformed_initialized_checkpoint")
	var handle_body := scenario.get("handle_body") as Resource
	if handle_body == null:
		_check(false, "malformed checkpoint fixture has no protected Handle tail")
		return
	var malformed_checkpoint := {
		"checkpoint_initialized": true,
		"checkpoint_id": &"verify_missing_prefix_occupancy",
		"checkpoint_revision": 1,
		"checkpoint_operation_count": 1,
		"material_variant_id": &"mat_iron_gray",
		"resolver_sample_cell_size_meters": CELL_SIZE_METERS,
	}
	var resolver := ForgeV2MaterialVolumeResolverScript.new()
	var restore_result := resolver.call(
		"restore_incremental_committed_cache_from_checkpoint",
		malformed_checkpoint,
		[handle_body]
	) as Dictionary
	var reason := StringName(restore_result.get("reason", StringName()))
	result_lines.append(
		"metric.malformed_checkpoint.restore_ok=%s"
		% bool(restore_result.get("ok", false))
	)
	result_lines.append(
		"metric.malformed_checkpoint.reason=%s" % String(reason)
	)
	_check(
		not bool(restore_result.get("ok", false))
		and reason != StringName()
		and reason != &"none",
		"initialized checkpoint with nonzero history and no prefix occupancy fails visibly"
	)


func _spatial_summaries_match(left: Dictionary, right: Dictionary) -> bool:
	if int(left.get("spatial_occupied_cell_count", -1)) != int(right.get(
		"spatial_occupied_cell_count",
		-2
	)):
		return false
	var left_materials := left.get("materials", {}) as Dictionary
	var right_materials := right.get("materials", {}) as Dictionary
	if left_materials.size() != right_materials.size():
		return false
	for material_key: Variant in left_materials.keys():
		if not right_materials.has(material_key):
			return false
		var left_entry := left_materials[material_key] as Dictionary
		var right_entry := right_materials[material_key] as Dictionary
		if not is_equal_approx(
			float(left_entry.get("rough_volume_cell_equivalents", -1.0)),
			float(right_entry.get("rough_volume_cell_equivalents", -2.0))
		):
			return false
		if (
			(left_entry.get(
				"rough_spatial_centroid_meters",
				Vector3.ZERO
			) as Vector3).distance_to(
				right_entry.get(
					"rough_spatial_centroid_meters",
					Vector3.ZERO
				) as Vector3
			) > POSITION_TOLERANCE_METERS
		):
			return false
	return true


func _verify_unclamped_com_projection(profile: BakedProfile) -> void:
	result_lines.append("scenario=unclamped_com_projection_beyond_handle")
	var center_of_mass_meters := (
		profile.get_weapon_intrinsic_center_of_mass_weapon_root_cells()
		* CELL_SIZE_METERS
	)
	var weapon_intrinsic_com_handle_ratio_unclamped := (
		profile.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped
	)
	var contact_ratio := profile.primary_grip_axis_ratio_from_span_start
	result_lines.append("metric.unclamped.com_m=%s" % center_of_mass_meters)
	result_lines.append(
		"metric.unclamped.com_ratio=%.9f"
		% weapon_intrinsic_com_handle_ratio_unclamped
	)
	result_lines.append(
		"metric.unclamped.contact_ratio=%.9f" % contact_ratio
	)
	result_lines.append(
		"metric.unclamped.zero_ratio=%.9f"
		% profile.primary_grip_handle_zero_axis_ratio_from_span_start
	)
	_check(
		weapon_intrinsic_com_handle_ratio_unclamped > 1.0 + RATIO_TOLERANCE,
		"stored true Handle-axis COM projection remains genuinely unclamped beyond ratio 1"
	)
	_check(
		contact_ratio >= 0.0 and contact_ratio <= 1.0,
		"surface contact seat remains bounded independently from unclamped COM truth"
	)
	_check(
		profile.primary_grip_handle_coordinate_mode
		== BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
		and profile.primary_grip_handle_zero_axis_ratio_from_span_start
		<= RATIO_TOLERANCE
		and (profile.primary_grip_handle_zero_position * CELL_SIZE_METERS).x < 0.0,
		"out-of-span positive COM keeps directional zero at the Pommel endcap"
	)
	_check(
		profile.primary_grip_handle_tip_side_axis_ratio_from_span_start
		>= 1.0 - RATIO_TOLERANCE
		and _profile_tip_meters(profile).x > _profile_pommel_meters(profile).x,
		"out-of-span positive COM selects the canonical-positive semantic Tip"
	)


func _build_contract_scenario(
	handle_points: PackedVector3Array,
	left_material_id: StringName,
	right_material_id: StringName,
	wip_id: StringName
) -> Dictionary:
	var fixture := _build_committed_fixture(
		handle_points,
		left_material_id,
		right_material_id,
		String(wip_id)
	)
	if not bool(fixture.get("valid", false)):
		return {
			"valid": false,
			"error": String(fixture.get("error", "fixture failed")),
		}
	var state := fixture.get("state") as Resource
	var handle_body := fixture.get("handle_body") as Resource
	var spatial_summary := state.call(
		"get_material_spatial_usage_summary"
	) as Dictionary
	var wip := _build_wip_from_state(state, wip_id)
	var packet := _build_final_mesh_packet(handle_points, handle_body)
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		packet,
		CELL_SIZE_METERS
	) as Dictionary
	contract["spatial_summary"] = spatial_summary
	contract["state"] = state
	contract["handle_body"] = handle_body
	return contract


func _build_one_sided_contract_scenario(
	handle_points: PackedVector3Array,
	wip_id: StringName
) -> Dictionary:
	var fixture := _build_committed_fixture(
		handle_points,
		StringName(),
		StringName(),
		String(wip_id)
	)
	if not bool(fixture.get("valid", false)):
		return {
			"valid": false,
			"error": String(fixture.get("error", "fixture failed")),
		}
	var state := fixture.get("state") as Resource
	var handle_body := fixture.get("handle_body") as Resource
	if not _append_committed_deposit(
		state,
		&"mat_gold_gray",
		ONE_SIDED_DEPOSIT_START,
		ONE_SIDED_DEPOSIT_END,
		ONE_SIDED_DEPOSIT_RADIUS_METERS
	):
		return {
			"valid": false,
			"error": "one-sided dense material deposit did not commit",
		}
	state.call("normalize")
	var spatial_summary := state.call(
		"get_material_spatial_usage_summary"
	) as Dictionary
	var wip := _build_wip_from_state(state, wip_id)
	var packet := _build_final_mesh_packet(
		handle_points,
		handle_body,
		ONE_SIDED_MESH_MIN,
		ONE_SIDED_MESH_MAX
	)
	var contract := ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		wip,
		packet,
		CELL_SIZE_METERS
	) as Dictionary
	contract["spatial_summary"] = spatial_summary
	contract["state"] = state
	contract["handle_body"] = handle_body
	return contract


func _build_committed_fixture(
	handle_points: PackedVector3Array,
	left_material_id: StringName,
	right_material_id: StringName,
	project_name: String
) -> Dictionary:
	if handle_points.size() != 3:
		return {"valid": false, "error": "fixture requires three Handle points"}
	var profile_entries: Array[Dictionary] = (
		ForgeV2ProfileShapeLibraryScript.build_handle_profile_entries()
	)
	if profile_entries.is_empty():
		return {"valid": false, "error": "no Handle profile is available"}
	var profile_id := StringName(profile_entries[0].get("id", StringName()))
	var state := ForgeV2AuthoringStateScript.new() as Resource
	state.call("reset_new_draft", project_name)
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	state.call("set_active_profile_id", profile_id)
	state.call("set_active_material_variant_id", &"mat_iron_gray")
	for point: Vector3 in handle_points:
		if int(state.call(
			"append_spline_line_point",
			point,
			Vector3.UP
		)) < 0:
			return {"valid": false, "error": "Handle point was rejected"}
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return {"valid": false, "error": "Handle did not generate"}
	var handle_body := state.call("get_selected_material_body") as Resource
	if handle_body == null:
		return {"valid": false, "error": "generated Handle body is missing"}
	if state.call(
		"commit_material_body_as_layer",
		StringName(handle_body.get("body_id"))
	) == null:
		return {"valid": false, "error": "Handle did not commit"}

	# Match the existing persisted mixed-material fixture lane. The verifier is
	# interested in the production full-CSG spatial summary, not bounded-history
	# eligibility.
	state.set("bounded_history_suspended_reason", &"mixed_material_fallback")
	if left_material_id != StringName() and not _append_committed_deposit(
		state,
		left_material_id,
		LEFT_DEPOSIT_START,
		LEFT_DEPOSIT_END
	):
		return {"valid": false, "error": "left material deposit did not commit"}
	if right_material_id != StringName() and not _append_committed_deposit(
		state,
		right_material_id,
		RIGHT_DEPOSIT_START,
		RIGHT_DEPOSIT_END
	):
		return {"valid": false, "error": "right material deposit did not commit"}
	state.call("normalize")
	return {
		"valid": true,
		"state": state,
		"handle_body": handle_body,
	}


func _append_committed_deposit(
	state: Resource,
	material_id: StringName,
	start: Vector3,
	endpoint: Vector3,
	radius_meters: float = DEPOSIT_RADIUS_METERS
) -> bool:
	state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_VOLUME_STROKE)
	state.call("set_active_material_variant_id", material_id)
	var body := state.call(
		"append_point_material_body",
		start,
		radius_meters,
		1.0,
		Vector3.UP,
		Vector3.ZERO
	) as Resource
	if body == null:
		return false
	var body_id := StringName(body.get("body_id"))
	if not bool(state.call(
		"append_point_to_material_body",
		body_id,
		endpoint,
		0.0,
		true,
		Vector3.UP,
		Vector3.ZERO
	)):
		return false
	return state.call("commit_material_body_as_layer", body_id) != null


func _build_wip_from_state(
	state: Resource,
	wip_id: StringName
) -> CraftedItemWIP:
	var wip := CraftedItemWIPScript.new() as CraftedItemWIP
	wip.wip_id = wip_id
	wip.forge_project_name = "Forge V2 Weighted Mass Verification"
	wip.creator_id = &"verify"
	wip.created_timestamp = Time.get_unix_time_from_system()
	wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.layers = []
	wip.forge_v2_authoring_state = state.duplicate(true) as Resource
	return wip


func _build_final_mesh_packet(
	handle_points: PackedVector3Array,
	handle_body: Resource,
	mesh_minimum: Vector3 = FINAL_MESH_MIN,
	mesh_maximum: Vector3 = FINAL_MESH_MAX
) -> Dictionary:
	var final_box := _build_box_geometry(mesh_minimum, mesh_maximum)
	var handle_prism := _build_handle_prism(handle_points)
	var final_size := mesh_maximum - mesh_minimum
	return {
		"ok": true,
		"vertices": final_box.get("vertices", PackedVector3Array()),
		"indices": final_box.get("indices", PackedInt32Array()),
		"primary_grip_handle_vertices": handle_prism.get(
			"vertices",
			PackedVector3Array()
		),
		"primary_grip_handle_indices": handle_prism.get(
			"indices",
			PackedInt32Array()
		),
		"primary_grip_handle_mesh_source": PrimaryGripHandleMeshPacketScript.SOURCE,
		"primary_grip_handle_body_signature": (
			PrimaryGripHandleMeshPacketScript.build_body_signature(handle_body)
		),
		"primary_grip_handle_vertices_origin_id": (
			PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		),
		"watertight": true,
		"output_volume_m3": (
			final_size.x * final_size.y * final_size.z
		),
		"source_original_ids": PackedStringArray(["verify_weighted_mass"]),
		"material_variant_id": &"mat_iron_gray",
		"source_state_revision": 1,
	}


func _build_handle_prism(handle_points: PackedVector3Array) -> Dictionary:
	var axis := (handle_points[2] - handle_points[0]).normalized()
	var minor_a := Vector3.UP - axis * axis.dot(Vector3.UP)
	if minor_a.length_squared() <= 0.000000000001:
		minor_a = Vector3.RIGHT - axis * axis.dot(Vector3.RIGHT)
	minor_a = minor_a.normalized()
	var minor_b := axis.cross(minor_a).normalized()
	var vertices := PackedVector3Array()
	for center: Vector3 in handle_points:
		vertices.append(
			center - minor_a * HANDLE_HALF_WIDTH_METERS
			- minor_b * HANDLE_HALF_DEPTH_METERS
		)
		vertices.append(
			center + minor_a * HANDLE_HALF_WIDTH_METERS
			- minor_b * HANDLE_HALF_DEPTH_METERS
		)
		vertices.append(
			center + minor_a * HANDLE_HALF_WIDTH_METERS
			+ minor_b * HANDLE_HALF_DEPTH_METERS
		)
		vertices.append(
			center - minor_a * HANDLE_HALF_WIDTH_METERS
			+ minor_b * HANDLE_HALF_DEPTH_METERS
		)
	var indices := PackedInt32Array([0, 2, 1, 0, 3, 2])
	for ring_index: int in range(handle_points.size() - 1):
		var ring_start := ring_index * 4
		var next_ring_start := (ring_index + 1) * 4
		for corner_index: int in range(4):
			var next_corner := (corner_index + 1) % 4
			indices.append_array(PackedInt32Array([
				ring_start + corner_index,
				ring_start + next_corner,
				next_ring_start + next_corner,
				ring_start + corner_index,
				next_ring_start + next_corner,
				next_ring_start + corner_index,
			]))
	var final_ring := (handle_points.size() - 1) * 4
	indices.append_array(PackedInt32Array([
		final_ring,
		final_ring + 1,
		final_ring + 2,
		final_ring,
		final_ring + 2,
		final_ring + 3,
	]))
	return {"vertices": vertices, "indices": indices}


func _build_box_geometry(minimum: Vector3, maximum: Vector3) -> Dictionary:
	return {
		"vertices": PackedVector3Array([
			Vector3(minimum.x, minimum.y, minimum.z),
			Vector3(maximum.x, minimum.y, minimum.z),
			Vector3(maximum.x, maximum.y, minimum.z),
			Vector3(minimum.x, maximum.y, minimum.z),
			Vector3(minimum.x, minimum.y, maximum.z),
			Vector3(maximum.x, minimum.y, maximum.z),
			Vector3(maximum.x, maximum.y, maximum.z),
			Vector3(minimum.x, maximum.y, maximum.z),
		]),
		"indices": PackedInt32Array([
			0, 2, 1, 0, 3, 2,
			4, 5, 6, 4, 6, 7,
			0, 4, 7, 0, 7, 3,
			1, 2, 6, 1, 6, 5,
			0, 1, 5, 0, 5, 4,
			3, 7, 6, 3, 6, 2,
		]),
	}


func _require_profile(contract: Dictionary, label: String) -> BakedProfile:
	if not bool(contract.get("valid", false)):
		_check(false, "%s was rejected: %s" % [
			label,
			String(contract.get("error", "unknown adapter error")),
		])
		return null
	var profile := contract.get("baked_profile") as BakedProfile
	if profile == null or not profile.primary_grip_valid:
		_check(false, "%s produced no valid primary grip profile" % label)
		return null
	return profile


func _profile_tip_meters(profile: BakedProfile) -> Vector3:
	return profile.weapon_tip_point * CELL_SIZE_METERS


func _profile_pommel_meters(profile: BakedProfile) -> Vector3:
	return profile.weapon_pommel_point * CELL_SIZE_METERS


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(result_lines) + "\n")
	file.close()
