extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const CombatAnimationMotionNodeScript = preload(
	"res://core/models/combat_animation_motion_node.gd"
)
const CombatRuntimeClipBakerScript = preload(
	"res://core/resolvers/combat_runtime_clip_baker.gd"
)
const CombatAnimationStationPreviewPresenterScript = preload(
	"res://runtime/combat/combat_animation_station_preview_presenter.gd"
)
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const LayerAtomScript = preload("res://core/atoms/layer_atom.gd")
const CellAtomScript = preload("res://core/atoms/cell_atom.gd")

const RESULT_FILE_PATH := (
	"C:/WORKSPACE/DEBUG-LOGS/"
	+ "verify_runtime_pose_track_incremental_equivalence_results.txt"
)
const DOMINANT_SLOT_ID: StringName = &"hand_right"
const SKILL_SLOT_ID: StringName = &"skill_slot_3"
# Separate preview actors can differ by a few float32 ULPs after Skeleton3D
# modifier evaluation. This remains far below any authored/world-space tolerance.
const FLOAT_EPSILON: float = 0.000002

const POSE_TRACK_FIELDS: Array[StringName] = [
	&"baked_upper_body_bone_names",
	&"baked_upper_body_bone_pose_rotations",
	&"upper_body_pose_track_source",
	&"solved_replay_track_source",
	&"solved_replay_reference_bone_name",
	&"solved_replay_reference_origin_id",
	&"baked_solved_replay_frame_available",
	&"baked_solved_upper_body_bone_names",
	&"baked_solved_upper_body_pose_positions",
	&"baked_solved_upper_body_pose_rotations",
	&"baked_solved_upper_body_pose_scales",
	&"baked_solved_weapon_positions_reference_local",
	&"baked_solved_weapon_rotations_reference_local",
	&"baked_solved_weapon_scales_reference_local",
	&"baked_solved_weapon_reference_origin_id",
	&"baked_solved_anchor_node_paths",
	&"baked_solved_anchor_positions_weapon_local",
	&"baked_solved_anchor_rotations_weapon_local",
	&"baked_solved_anchor_scales_weapon_local",
	&"baked_solved_anchor_origin_id",
]

var result_lines := PackedStringArray()
var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	result_lines.append("verification=runtime_pose_track_incremental_equivalence")
	result_lines.append("uses_live_wip_data=false")
	result_lines.append("numeric_equivalence_epsilon=%s" % str(FLOAT_EPSILON))

	var fixture: Dictionary = _build_synthetic_fixture()
	var active_wip: CraftedItemWIP = fixture.get("wip", null) as CraftedItemWIP
	var active_draft: Resource = fixture.get("draft", null) as Resource
	var source_chain: Array = fixture.get("motion_node_chain", []) as Array
	_check(active_wip != null, "fixture_wip_exists", "synthetic WIP was not created")
	_check(active_draft != null, "fixture_draft_exists", "synthetic draft was not created")
	_check(source_chain.size() == 3, "fixture_node_count", "synthetic chain did not contain three nodes")
	if active_wip == null or active_draft == null or source_chain.is_empty():
		_finish()
		return
	var profile_presenter = CombatAnimationStationPreviewPresenterScript.new()
	var fixture_profile: BakedProfile = profile_presenter.ensure_baked_profile_snapshot(
		active_wip
	)
	var fixture_weapon_length: float = (
		fixture_profile.weapon_total_length_meters
		if fixture_profile != null
		else 0.0
	)
	_check(
		fixture_weapon_length > 0.001,
		"fixture_weapon_length_available",
		"synthetic WIP did not produce a usable physical weapon length"
	)
	if fixture_weapon_length <= 0.001:
		_finish()
		return
	_normalize_motion_node_weapon_lengths(source_chain, fixture_weapon_length)

	var base_clip = CombatRuntimeClipBakerScript.new().bake_from_motion_node_chain(
		source_chain,
		{
			"clip_kind": &"skill_playback",
			"clip_id": &"verify_incremental_pose_track",
			"source_draft_id": StringName(active_draft.get("draft_id")),
			"source_skill_slot_id": SKILL_SLOT_ID,
			"source_equipment_slot_id": DOMINANT_SLOT_ID,
			"source_weapon_wip_id": active_wip.wip_id,
			"source_weapon_length_meters": _resolve_weapon_length(source_chain),
			"sample_rate_hz": 12.0,
			"playback_speed_scale": 1.0,
			"loop_enabled": false,
		}
	)
	var base_frame_count: int = (
		int(base_clip.call("get_frame_count"))
		if base_clip != null and base_clip.has_method("get_frame_count")
		else 0
	)
	_check(base_clip != null, "base_clip_exists", "runtime clip baker returned null")
	_check(base_frame_count > 2, "base_clip_has_multiple_frames", "runtime clip had too few frames")
	if base_clip == null or base_frame_count <= 0:
		_finish()
		return

	var wrapper_clip = base_clip.call("duplicate_clip")
	var incremental_clip = base_clip.call("duplicate_clip")
	_check(wrapper_clip != null, "wrapper_clip_duplicate_exists", "wrapper clip duplication failed")
	_check(incremental_clip != null, "incremental_clip_duplicate_exists", "incremental clip duplication failed")
	if wrapper_clip == null or incremental_clip == null:
		_finish()
		return

	var wrapper_preview: Dictionary = await _create_preview_fixture("Wrapper")
	var wrapper_presenter = CombatAnimationStationPreviewPresenterScript.new()
	wrapper_presenter.configure_preview_hand_setup(DOMINANT_SLOT_ID, false)
	var wrapper_result: Dictionary = wrapper_presenter.bake_runtime_clip_upper_body_pose_track(
		wrapper_preview.get("container", null) as SubViewportContainer,
		wrapper_preview.get("viewport", null) as SubViewport,
		active_wip,
		active_draft,
		wrapper_clip,
		0
	)
	_check(bool(wrapper_result.get("baked", false)), "wrapper_baked", String(wrapper_result.get("reason", "")))
	_check(
		bool(wrapper_result.get("solved_replay_track", false)),
		"wrapper_solved_replay_track",
		"compatibility wrapper did not publish solved replay"
	)
	_check_solved_weapon_endpoint_parity(
		wrapper_clip,
		wrapper_preview,
		"wrapper"
	)
	_destroy_preview_fixture(wrapper_preview)
	await process_frame

	var incremental_preview: Dictionary = await _create_preview_fixture("Incremental")
	var incremental_presenter = CombatAnimationStationPreviewPresenterScript.new()
	incremental_presenter.configure_preview_hand_setup(DOMINANT_SLOT_ID, false)
	var bake_job: Dictionary = incremental_presenter.begin_runtime_clip_upper_body_pose_track_bake(
		incremental_preview.get("container", null) as SubViewportContainer,
		incremental_preview.get("viewport", null) as SubViewport,
		active_wip,
		active_draft,
		incremental_clip,
		0
	)
	_check(bool(bake_job.get("active", false)), "incremental_begin_active", "begin returned an inactive job")
	_check(not bool(bake_job.get("completed", true)), "incremental_begin_pending", "begin completed before any frame")
	_check(not bool(bake_job.get("failed", false)), "incremental_begin_not_failed", String((bake_job.get("result", {}) as Dictionary).get("reason", "")))
	_check(
		int(bake_job.get("frame_count", -1)) == base_frame_count,
		"incremental_begin_frame_count",
		"begin frame count differed from source clip"
	)
	_check(
		not bool(incremental_clip.call("has_upper_body_pose_track")),
		"incremental_begin_no_partial_upper_body_track",
		"begin published an upper-body track before finalization"
	)
	_check(
		not bool(incremental_clip.call("has_solved_replay_track")),
		"incremental_begin_no_partial_solved_track",
		"begin published solved replay before finalization"
	)

	var advance_call_count := 0
	var one_frame_progress_ok := true
	var monotonic_progress_ok := true
	var partial_tracks_unpublished := true
	var previous_completed_frame_count := 0
	while not bool(bake_job.get("completed", false)) and advance_call_count <= base_frame_count:
		var progress: Dictionary = incremental_presenter.advance_runtime_clip_upper_body_pose_track_bake(
			bake_job,
			1
		)
		advance_call_count += 1
		var completed_frame_count: int = int(progress.get("completed_frame_count", -1))
		one_frame_progress_ok = (
			one_frame_progress_ok
			and int(progress.get("processed_frame_count", -1)) == 1
		)
		monotonic_progress_ok = (
			monotonic_progress_ok
			and completed_frame_count == previous_completed_frame_count + 1
			and int(progress.get("remaining_frame_count", -1))
				== base_frame_count - completed_frame_count
		)
		previous_completed_frame_count = completed_frame_count
		if not bool(progress.get("completed", false)):
			partial_tracks_unpublished = (
				partial_tracks_unpublished
				and not bool(incremental_clip.call("has_upper_body_pose_track"))
				and not bool(incremental_clip.call("has_solved_replay_track"))
			)
			await process_frame

	var incremental_result: Dictionary = (bake_job.get("result", {}) as Dictionary).duplicate(true)
	_check(one_frame_progress_ok, "incremental_exactly_one_frame_per_advance", "an advance call processed other than one frame")
	_check(monotonic_progress_ok, "incremental_progress_monotonic", "completed/remaining counts skipped or regressed")
	_check(partial_tracks_unpublished, "incremental_partial_tracks_unpublished", "partial pose data became authoritative before finalization")
	_check(advance_call_count == base_frame_count, "incremental_advance_count_matches_frames", "incremental call count differed from clip frames")
	_check(bool(bake_job.get("completed", false)), "incremental_completed", "incremental job did not finalize")
	_check(not bool(bake_job.get("active", true)), "incremental_inactive_after_finalize", "finalized job remained active")
	_check(not bool(bake_job.get("failed", false)), "incremental_not_failed", String(incremental_result.get("reason", "")))
	_check(bool(incremental_result.get("baked", false)), "incremental_baked", String(incremental_result.get("reason", "")))
	_check(
		bool(incremental_result.get("solved_replay_track", false)),
		"incremental_solved_replay_track",
		"incremental finalization did not publish solved replay"
	)
	_check_solved_weapon_endpoint_parity(
		incremental_clip,
		incremental_preview,
		"incremental"
	)
	_destroy_preview_fixture(incremental_preview)

	_compare_result_metrics(wrapper_result, incremental_result)
	for field_name: StringName in POSE_TRACK_FIELDS:
		var wrapper_value: Variant = wrapper_clip.get(field_name)
		var incremental_value: Variant = incremental_clip.get(field_name)
		var matches: bool = _variants_match(wrapper_value, incremental_value)
		var max_numeric_delta: float = _variant_max_numeric_delta(wrapper_value, incremental_value)
		result_lines.append("pose_field_%s_match=%s" % [String(field_name), str(matches)])
		result_lines.append("pose_field_%s_max_numeric_delta=%s" % [
			String(field_name),
			str(max_numeric_delta),
		])
		result_lines.append("pose_field_%s_wrapper_hash=%s" % [String(field_name), _variant_hash(wrapper_value)])
		result_lines.append("pose_field_%s_incremental_hash=%s" % [String(field_name), _variant_hash(incremental_value)])
		if not matches:
			_record_failure("pose field mismatch: %s" % String(field_name))

	_check(
		bool(wrapper_clip.call("has_upper_body_pose_track"))
		and bool(incremental_clip.call("has_upper_body_pose_track")),
		"both_upper_body_tracks_valid",
		"one finalized clip lacked a valid upper-body track"
	)
	_check(
		bool(wrapper_clip.call("has_solved_replay_track"))
		and bool(incremental_clip.call("has_solved_replay_track")),
		"both_solved_replay_tracks_valid",
		"one finalized clip lacked valid solved replay"
	)
	_finish()


func _build_synthetic_fixture() -> Dictionary:
	var wip: CraftedItemWIP = CraftedItemWIPScript.new()
	wip.wip_id = &"verify_runtime_pose_track_incremental_weapon"
	wip.forge_project_name = "Runtime Pose Track Incremental Verifier"
	wip.creator_id = &"verification"
	wip.created_timestamp = 1.0
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	var layer_a: LayerAtom = LayerAtomScript.new() as LayerAtom
	layer_a.layer_index = 20
	layer_a.cells = _build_handle_cells(20)
	var layer_b: LayerAtom = LayerAtomScript.new() as LayerAtom
	layer_b.layer_index = 21
	layer_b.cells = _build_handle_cells(21)
	wip.layers = [layer_a, layer_b]

	var station_state: Resource = wip.ensure_combat_animation_station_state()
	var draft: Resource = station_state.call(
		"get_or_create_skill_draft",
		SKILL_SLOT_ID,
		"Incremental Pose Track Skill",
		wip.grip_style_mode,
		SKILL_SLOT_ID
	) as Resource
	var motion_node_chain: Array = [
		_build_motion_node(0, Vector3(0.18, 0.18, -0.46), Vector3(-0.08, -0.04, 0.22), Vector3(0.0, -12.0, 4.0), 0.01),
		_build_motion_node(1, Vector3(0.32, 0.09, -0.40), Vector3(-0.02, -0.10, 0.20), Vector3(3.0, -28.0, -6.0), 0.12),
		_build_motion_node(2, Vector3(0.12, 0.25, -0.34), Vector3(-0.18, -0.01, 0.18), Vector3(-7.0, 16.0, 13.0), 0.12),
	]
	if draft != null:
		draft.set("skill_name", "Incremental Pose Track Skill")
		draft.set("preview_loop_enabled", false)
		draft.set("preview_playback_speed_scale", 1.0)
		draft.set("motion_node_chain", motion_node_chain)
		draft.set("selected_motion_node_index", 0)
		if draft.has_method("normalize"):
			draft.call("normalize")
	return {
		"wip": wip,
		"draft": draft,
		"motion_node_chain": motion_node_chain,
	}


func _build_motion_node(
	index: int,
	tip_position: Vector3,
	pommel_position: Vector3,
	orientation_degrees: Vector3,
	transition_seconds: float
) -> CombatAnimationMotionNode:
	var motion_node: CombatAnimationMotionNode = CombatAnimationMotionNodeScript.new()
	motion_node.node_index = index
	motion_node.node_id = StringName("incremental_pose_node_%02d" % index)
	motion_node.tip_position_local = tip_position
	motion_node.tip_position_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	motion_node.pommel_position_local = pommel_position
	motion_node.pommel_position_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	motion_node.weapon_orientation_degrees = orientation_degrees
	motion_node.weapon_orientation_authored = true
	motion_node.weapon_roll_degrees = 7.0 - float(index) * 5.0
	motion_node.axial_reposition_offset = 0.15 + float(index) * 0.22
	motion_node.grip_seat_slide_offset = 0.2 + float(index) * 0.17
	motion_node.body_support_blend = 0.25 + float(index) * 0.12
	motion_node.right_upperarm_roll_degrees = 3.0 + float(index) * 7.0
	motion_node.left_upperarm_roll_degrees = -2.0 - float(index) * 4.0
	motion_node.two_hand_state = &"two_hand_one_hand"
	motion_node.primary_hand_slot = &"hand_right"
	motion_node.preferred_grip_style_mode = &"grip_normal"
	motion_node.transition_duration_seconds = transition_seconds
	motion_node.normalize()
	return motion_node


func _build_handle_cells(layer_index: int) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	for x: int in range(20, 48):
		for y: int in range(10, 13):
			var cell: CellAtom = CellAtomScript.new() as CellAtom
			cell.grid_position = Vector3i(x, y, layer_index)
			cell.layer_index = layer_index
			cell.material_variant_id = &"mat_wood_gray"
			cells.append(cell)
	return cells


func _resolve_weapon_length(motion_node_chain: Array) -> float:
	var longest := 0.0
	for node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = node_variant as CombatAnimationMotionNode
		if motion_node != null:
			longest = maxf(
				longest,
				motion_node.tip_position_local.distance_to(motion_node.pommel_position_local)
			)
	return maxf(longest, 0.24)


func _normalize_motion_node_weapon_lengths(
	motion_node_chain: Array,
	weapon_length_meters: float
) -> void:
	for node_variant: Variant in motion_node_chain:
		var motion_node: CombatAnimationMotionNode = (
			node_variant as CombatAnimationMotionNode
		)
		if motion_node == null:
			continue
		var axis: Vector3 = (
			motion_node.tip_position_local - motion_node.pommel_position_local
		)
		if axis.length_squared() <= 0.000001:
			axis = Vector3.UP
		motion_node.tip_position_local = (
			motion_node.pommel_position_local
			+ axis.normalized() * weapon_length_meters
		)
		motion_node.normalize()


func _create_preview_fixture(label: String) -> Dictionary:
	var preview_container := SubViewportContainer.new()
	preview_container.name = "%sPoseTrackPreviewContainer" % label
	preview_container.size = Vector2(960.0, 540.0)
	var preview_subviewport := SubViewport.new()
	preview_subviewport.name = "%sPoseTrackPreviewViewport" % label
	preview_subviewport.size = Vector2i(960, 540)
	preview_container.add_child(preview_subviewport)
	root.add_child(preview_container)
	await process_frame
	return {
		"container": preview_container,
		"viewport": preview_subviewport,
	}


func _destroy_preview_fixture(preview_fixture: Dictionary) -> void:
	var preview_container: SubViewportContainer = preview_fixture.get("container", null) as SubViewportContainer
	if preview_container != null and is_instance_valid(preview_container):
		preview_container.queue_free()


func _check_solved_weapon_endpoint_parity(
	clip,
	preview_fixture: Dictionary,
	label: String
) -> void:
	var viewport: SubViewport = preview_fixture.get("viewport", null) as SubViewport
	var preview_root: Node3D = (
		viewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D
		if viewport != null
		else null
	)
	var held_item: Node3D = (
		preview_root.get_meta("preview_held_item", null) as Node3D
		if preview_root != null
		else null
	)
	_check(
		held_item != null and is_instance_valid(held_item),
		"%s_solved_endpoint_weapon_available" % label,
		"preview weapon was unavailable for solved-frame endpoint verification"
	)
	if held_item == null or not is_instance_valid(held_item):
		return
	var local_tip: Vector3 = held_item.get_meta(
		"weapon_tip_local",
		Vector3.ZERO
	) as Vector3
	var local_pommel: Vector3 = held_item.get_meta(
		"weapon_pommel_local",
		Vector3.ZERO
	) as Vector3
	var baked_tips: PackedVector3Array = clip.get(
		"baked_tip_positions_local"
	) as PackedVector3Array
	var baked_pommels: PackedVector3Array = clip.get(
		"baked_pommel_positions_local"
	) as PackedVector3Array
	var weapon_positions: PackedVector3Array = clip.get(
		"baked_solved_weapon_positions_reference_local"
	) as PackedVector3Array
	var weapon_rotations: PackedVector4Array = clip.get(
		"baked_solved_weapon_rotations_reference_local"
	) as PackedVector4Array
	var weapon_scales: PackedVector3Array = clip.get(
		"baked_solved_weapon_scales_reference_local"
	) as PackedVector3Array
	var frame_availability: Array = clip.get(
		"baked_solved_replay_frame_available"
	) as Array
	var frame_count: int = baked_tips.size()
	var size_match: bool = (
		frame_count > 0
		and baked_pommels.size() == frame_count
		and weapon_positions.size() == frame_count
		and weapon_rotations.size() == frame_count
		and weapon_scales.size() == frame_count
		and frame_availability.size() == frame_count
	)
	_check(
		size_match,
		"%s_solved_endpoint_frame_arrays_match" % label,
		"solved weapon and authored endpoint frame arrays differed in size"
	)
	if not size_match:
		return
	var all_available_frames_match := true
	var available_frame_count := 0
	var max_tip_error_meters := 0.0
	var max_pommel_error_meters := 0.0
	for frame_index: int in range(frame_count):
		if not bool(frame_availability[frame_index]):
			continue
		available_frame_count += 1
		var packed_rotation: Vector4 = weapon_rotations[frame_index]
		var rotation := Quaternion(
			packed_rotation.x,
			packed_rotation.y,
			packed_rotation.z,
			packed_rotation.w
		).normalized()
		var weapon_basis := Basis(rotation).scaled(weapon_scales[frame_index])
		var weapon_reference_transform := Transform3D(
			weapon_basis,
			weapon_positions[frame_index]
		)
		var tip_error_meters: float = (
			weapon_reference_transform * local_tip
		).distance_to(baked_tips[frame_index])
		var pommel_error_meters: float = (
			weapon_reference_transform * local_pommel
		).distance_to(baked_pommels[frame_index])
		max_tip_error_meters = maxf(max_tip_error_meters, tip_error_meters)
		max_pommel_error_meters = maxf(
			max_pommel_error_meters,
			pommel_error_meters
		)
		all_available_frames_match = (
			all_available_frames_match
			and tip_error_meters <= FLOAT_EPSILON
			and pommel_error_meters <= FLOAT_EPSILON
		)
	result_lines.append(
		"%s_solved_endpoint_available_frame_count=%d" % [
			label,
			available_frame_count,
		]
	)
	result_lines.append(
		"%s_solved_endpoint_max_tip_error_meters=%s" % [
			label,
			str(max_tip_error_meters),
		]
	)
	result_lines.append(
		"%s_solved_endpoint_max_pommel_error_meters=%s" % [
			label,
			str(max_pommel_error_meters),
		]
	)
	_check(
		available_frame_count > 0 and all_available_frames_match,
		"%s_solved_weapon_matches_authored_endpoints" % label,
		"a solved weapon frame reconstructed different Tip/Pommel endpoints"
	)


func _compare_result_metrics(wrapper_result: Dictionary, incremental_result: Dictionary) -> void:
	var wrapper_keys: Array = wrapper_result.keys()
	var incremental_keys: Array = incremental_result.keys()
	wrapper_keys.sort()
	incremental_keys.sort()
	_check(
		wrapper_keys == incremental_keys,
		"result_metric_key_sets_match",
		"wrapper and incremental result dictionaries exposed different metrics"
	)
	for key_variant: Variant in wrapper_keys:
		var key: String = String(key_variant)
		var matches: bool = (
			incremental_result.has(key_variant)
			and _variants_match(wrapper_result.get(key_variant), incremental_result.get(key_variant))
		)
		result_lines.append("result_metric_%s_match=%s" % [key, str(matches)])
		result_lines.append("result_metric_%s_wrapper=%s" % [key, str(wrapper_result.get(key_variant))])
		result_lines.append("result_metric_%s_incremental=%s" % [key, str(incremental_result.get(key_variant))])
		result_lines.append("result_metric_%s_max_numeric_delta=%s" % [
			key,
			str(_variant_max_numeric_delta(
				wrapper_result.get(key_variant),
				incremental_result.get(key_variant)
			)),
		])
		if not matches:
			_record_failure("result metric mismatch: %s" % key)


func _variants_match(first: Variant, second: Variant) -> bool:
	if typeof(first) != typeof(second):
		return false
	match typeof(first):
		TYPE_FLOAT:
			return absf(float(first) - float(second)) <= FLOAT_EPSILON
		TYPE_VECTOR2:
			return (first as Vector2).distance_to(second as Vector2) <= FLOAT_EPSILON
		TYPE_VECTOR3:
			return (first as Vector3).distance_to(second as Vector3) <= FLOAT_EPSILON
		TYPE_VECTOR4:
			return (first as Vector4).distance_to(second as Vector4) <= FLOAT_EPSILON
		TYPE_QUATERNION:
			return _quaternion_distance(first as Quaternion, second as Quaternion) <= FLOAT_EPSILON
		TYPE_ARRAY:
			var first_array: Array = first as Array
			var second_array: Array = second as Array
			if first_array.size() != second_array.size():
				return false
			for element_index: int in range(first_array.size()):
				if not _variants_match(first_array[element_index], second_array[element_index]):
					return false
			return true
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			if first.size() != second.size():
				return false
			for element_index: int in range(first.size()):
				if not _variants_match(first[element_index], second[element_index]):
					return false
			return true
		_:
			return var_to_bytes(first) == var_to_bytes(second)


func _variant_max_numeric_delta(first: Variant, second: Variant) -> float:
	if typeof(first) != typeof(second):
		return INF
	match typeof(first):
		TYPE_INT, TYPE_FLOAT:
			return absf(float(first) - float(second))
		TYPE_VECTOR2:
			return (first as Vector2).distance_to(second as Vector2)
		TYPE_VECTOR3:
			return (first as Vector3).distance_to(second as Vector3)
		TYPE_VECTOR4:
			return (first as Vector4).distance_to(second as Vector4)
		TYPE_QUATERNION:
			return _quaternion_distance(first as Quaternion, second as Quaternion)
		TYPE_ARRAY:
			var first_array: Array = first as Array
			var second_array: Array = second as Array
			if first_array.size() != second_array.size():
				return INF
			var max_delta := 0.0
			for element_index: int in range(first_array.size()):
				max_delta = maxf(
					max_delta,
					_variant_max_numeric_delta(first_array[element_index], second_array[element_index])
				)
			return max_delta
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			if first.size() != second.size():
				return INF
			var max_delta := 0.0
			for element_index: int in range(first.size()):
				max_delta = maxf(
					max_delta,
					_variant_max_numeric_delta(first[element_index], second[element_index])
				)
			return max_delta
		_:
			return 0.0 if var_to_bytes(first) == var_to_bytes(second) else INF


func _quaternion_distance(first: Quaternion, second: Quaternion) -> float:
	return 1.0 - absf(first.normalized().dot(second.normalized()))


func _variant_hash(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()


func _check(condition: bool, assertion_id: String, failure_message: String) -> void:
	result_lines.append("%s=%s" % [assertion_id, str(condition)])
	if not condition:
		_record_failure("%s: %s" % [assertion_id, failure_message])


func _record_failure(message: String) -> void:
	failures.append(message)
	result_lines.append("FAIL: %s" % message)


func _finish() -> void:
	result_lines.append("failure_count=%d" % failures.size())
	result_lines.append("all_checks_passed=%s" % str(failures.is_empty()))
	var result_file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(result_lines) + "\n")
		result_file.close()
	if failures.is_empty():
		print("Runtime pose-track incremental equivalence verifier passed")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)
