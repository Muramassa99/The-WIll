extends RefCounted
class_name PlayerRigFingerGripPresenter

const JosieRigScene = preload("res://Josie/josie.tscn")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const PlayerDigitHingeRulesScript = preload("res://runtime/player/player_digit_hinge_rules.gd")
const PlayerFingerSurfaceGripSolverScript = preload(
	"res://runtime/player/player_finger_surface_grip_solver.gd"
)
const PlayerHandSurfaceSeatSolverScript = preload(
	"res://runtime/player/player_hand_surface_seat_solver.gd"
)
const PrimaryGripHandleMeshPacketScript = preload(
	"res://core/resolvers/primary_grip_handle_mesh_packet.gd"
)
const PrimaryGripSeatResolverScript = preload(
	"res://core/resolvers/primary_grip_seat_resolver.gd"
)
const SLOT_RIGHT: StringName = &"hand_right"
const SLOT_LEFT: StringName = &"hand_left"
const GRIP_PATH_RIGHT_PRIMARY: StringName = &"right_primary"
const GRIP_PATH_LEFT_PRIMARY: StringName = &"left_primary"
const GRIP_PATH_RIGHT_SUPPORT: StringName = &"right_support"
const GRIP_PATH_LEFT_SUPPORT: StringName = &"left_support"
const FINGER_IDS: Array[StringName] = [&"thumb", &"index", &"middle", &"ring", &"pinky"]
const IDLE_BASELINE_ANIMATION_NAME: StringName = &"Idle"
const IDLE_BASELINE_SAMPLE_RATIO: float = 0.5
const GRIP_BASELINE_ANIMATION_NAMES: Array[StringName] = [&"SlowRun", &"Run"]
const GRIP_BASELINE_SAMPLE_RATIOS: Array[float] = [0.2, 0.5, 0.8]
const CURL_TRAJECTORY_SAMPLE_STEPS: int = 18
const PINKY_MAX_CURL_T: float = 0.58
const CONTACT_READINESS_META := "finger_grip_contact_readiness"
const CONTACT_DISTANCE_META := "finger_grip_contact_distance_meters"
const CONTACT_RAY_DEBUG_META := "finger_grip_contact_ray_debug"
const CONTACT_RAY_DEBUG_LIMIT: int = 96
const CONTACT_RAY_UNEXPECTED_COLLIDER_LIMIT: int = 16
const SURFACE_GRASP_DIAGNOSTICS_META := "finger_surface_grasp_diagnostics"
const SURFACE_GRASP_CONTEXT_META := "finger_surface_grasp_context_key"
const HAND_SURFACE_SEAT_DIAGNOSTICS_META := "hand_surface_seat_diagnostics"
const HAND_SURFACE_SEAT_CONTEXT_META := "hand_surface_seat_context_key"
const PREVIEW_PRIMARY_GRIP_SEAT_RATIO_META := "preview_primary_grip_seat_axis_ratio_from_span_start"
const PREVIEW_PRIMARY_GRIP_SEAT_RATIO_ORIGIN_META := "preview_primary_grip_seat_axis_ratio_origin_id"
const PREVIEW_SUPPORT_GRIP_SEAT_RATIO_META := "preview_support_grip_seat_axis_ratio_from_span_start"
const PREVIEW_SUPPORT_GRIP_SEAT_RATIO_ORIGIN_META := "preview_support_grip_seat_axis_ratio_origin_id"
const SURFACE_GRASP_POSITION_SIGNATURE_STEP_METERS: float = 0.0001
const SURFACE_GRASP_BASIS_SIGNATURE_STEP: float = 0.0001
const SURFACE_GRASP_BAND_RADIUS_METERS: float = 0.18
const CONTACT_FULL_SEAT_MIN_METERS: float = 0.055
const CONTACT_FADE_OUT_MIN_METERS: float = 0.18
const CONTACT_FULL_SEAT_CELL_MULTIPLIER: float = 4.0
const CONTACT_FADE_OUT_CELL_MULTIPLIER: float = 14.0
const SLOT_LABELS := {
	SLOT_RIGHT: "Right",
	SLOT_LEFT: "Left",
}
const FINGER_LABELS := {
	&"thumb": "Thumb",
	&"index": "Index",
	&"middle": "Middle",
	&"ring": "Ring",
	&"pinky": "Pinky",
}
const FINGER_CHAINS := {
	SLOT_RIGHT: {
		&"thumb": {
			"root": &"CC_Base_R_Thumb1",
			"guide": &"CC_Base_R_Thumb2",
			"mid": &"CC_Base_R_Thumb2",
			"end": &"CC_Base_R_Thumb3",
		},
		&"index": {
			"root": &"CC_Base_R_Index1",
			"guide": &"CC_Base_R_Index1",
			"mid": &"CC_Base_R_Index2",
			"end": &"CC_Base_R_Index3",
		},
		&"middle": {
			"root": &"CC_Base_R_Mid1",
			"guide": &"CC_Base_R_Mid1",
			"mid": &"CC_Base_R_Mid2",
			"end": &"CC_Base_R_Mid3",
		},
		&"ring": {
			"root": &"CC_Base_R_Ring1",
			"guide": &"CC_Base_R_Ring1",
			"mid": &"CC_Base_R_Ring2",
			"end": &"CC_Base_R_Ring3",
		},
		&"pinky": {
			"root": &"CC_Base_R_Pinky1",
			"guide": &"CC_Base_R_Pinky1",
			"mid": &"CC_Base_R_Pinky2",
			"end": &"CC_Base_R_Pinky3",
		},
	},
	SLOT_LEFT: {
		&"thumb": {
			"root": &"CC_Base_L_Thumb1",
			"guide": &"CC_Base_L_Thumb2",
			"mid": &"CC_Base_L_Thumb2",
			"end": &"CC_Base_L_Thumb3",
		},
		&"index": {
			"root": &"CC_Base_L_Index1",
			"guide": &"CC_Base_L_Index1",
			"mid": &"CC_Base_L_Index2",
			"end": &"CC_Base_L_Index3",
		},
		&"middle": {
			"root": &"CC_Base_L_Mid1",
			"guide": &"CC_Base_L_Mid1",
			"mid": &"CC_Base_L_Mid2",
			"end": &"CC_Base_L_Mid3",
		},
		&"ring": {
			"root": &"CC_Base_L_Ring1",
			"guide": &"CC_Base_L_Ring1",
			"mid": &"CC_Base_L_Ring2",
			"end": &"CC_Base_L_Ring3",
		},
		&"pinky": {
			"root": &"CC_Base_L_Pinky1",
			"guide": &"CC_Base_L_Pinky1",
			"mid": &"CC_Base_L_Pinky2",
			"end": &"CC_Base_L_Pinky3",
		},
	},
}
const FINGER_BASELINE_ROTATION_BONES := {
	SLOT_RIGHT: [
		&"CC_Base_R_Thumb1",
		&"CC_Base_R_Thumb2",
		&"CC_Base_R_Thumb3",
		&"CC_Base_R_Index1",
		&"CC_Base_R_Index2",
		&"CC_Base_R_Index3",
		&"CC_Base_R_Mid1",
		&"CC_Base_R_Mid2",
		&"CC_Base_R_Mid3",
		&"CC_Base_R_Ring1",
		&"CC_Base_R_Ring2",
		&"CC_Base_R_Ring3",
		&"CC_Base_R_Pinky1",
		&"CC_Base_R_Pinky2",
		&"CC_Base_R_Pinky3",
	],
	SLOT_LEFT: [
		&"CC_Base_L_Thumb1",
		&"CC_Base_L_Thumb2",
		&"CC_Base_L_Thumb3",
		&"CC_Base_L_Index1",
		&"CC_Base_L_Index2",
		&"CC_Base_L_Index3",
		&"CC_Base_L_Mid1",
		&"CC_Base_L_Mid2",
		&"CC_Base_L_Mid3",
		&"CC_Base_L_Ring1",
		&"CC_Base_L_Ring2",
		&"CC_Base_L_Ring3",
		&"CC_Base_L_Pinky1",
		&"CC_Base_L_Pinky2",
		&"CC_Base_L_Pinky3",
	],
}
const PALM_TRIANGULATION_BONES := {
	SLOT_RIGHT: {
		"hand": &"CC_Base_R_Hand",
		"thumb2": &"CC_Base_R_Thumb2",
		"index1": &"CC_Base_R_Index1",
		"mid1": &"CC_Base_R_Mid1",
		"mid2": &"CC_Base_R_Mid2",
		"ring1": &"CC_Base_R_Ring1",
		"pinky1": &"CC_Base_R_Pinky1",
	},
	SLOT_LEFT: {
		"hand": &"CC_Base_L_Hand",
		"thumb2": &"CC_Base_L_Thumb2",
		"index1": &"CC_Base_L_Index1",
		"mid1": &"CC_Base_L_Mid1",
		"mid2": &"CC_Base_L_Mid2",
		"ring1": &"CC_Base_L_Ring1",
		"pinky1": &"CC_Base_L_Pinky1",
	},
}
var animation_grip_baseline_cache: Dictionary = {}
var animation_idle_baseline_cache: Dictionary = {}
var animation_grip_baseline_initialized: bool = false
var surface_grasp_solver = PlayerFingerSurfaceGripSolverScript.new()
var surface_grasp_state_lookup: Dictionary = {}
var hand_surface_seat_solver = PlayerHandSurfaceSeatSolverScript.new()
var weapon_surface_seat_state_lookup: Dictionary = {}
var weapon_surface_seat_prepared_attempt_lookup: Dictionary = {}
var active_grip_execution_path_lookup: Dictionary = {}


func _resolve_grip_execution_path_id(
	slot_id: StringName,
	grip_guide: Node3D
) -> StringName:
	if grip_guide == null or not is_instance_valid(grip_guide):
		return StringName()
	var guide_role: StringName = StringName(grip_guide.name)
	if slot_id == SLOT_RIGHT:
		if guide_role == &"PrimaryGripGuide":
			return GRIP_PATH_RIGHT_PRIMARY
		if guide_role == &"SecondaryGripGuide":
			return GRIP_PATH_RIGHT_SUPPORT
	elif slot_id == SLOT_LEFT:
		if guide_role == &"PrimaryGripGuide":
			return GRIP_PATH_LEFT_PRIMARY
		if guide_role == &"SecondaryGripGuide":
			return GRIP_PATH_LEFT_SUPPORT
	return StringName()


func _grip_execution_paths_for_slot(slot_id: StringName) -> Array[StringName]:
	if slot_id == SLOT_RIGHT:
		var right_paths: Array[StringName] = [
			GRIP_PATH_RIGHT_PRIMARY,
			GRIP_PATH_RIGHT_SUPPORT,
		]
		return right_paths
	if slot_id == SLOT_LEFT:
		var left_paths: Array[StringName] = [
			GRIP_PATH_LEFT_PRIMARY,
			GRIP_PATH_LEFT_SUPPORT,
		]
		return left_paths
	var no_paths: Array[StringName] = []
	return no_paths


func _erase_cached_grip_execution_paths_for_slot(slot_id: StringName) -> void:
	for execution_path_id: StringName in _grip_execution_paths_for_slot(slot_id):
		surface_grasp_state_lookup.erase(execution_path_id)
		weapon_surface_seat_state_lookup.erase(execution_path_id)
		weapon_surface_seat_prepared_attempt_lookup.erase(execution_path_id)


func _active_grip_execution_path_id(slot_id: StringName) -> StringName:
	return active_grip_execution_path_lookup.get(
		slot_id,
		StringName()
	) as StringName

func ensure_finger_target_nodes(targets_root: Node3D) -> Dictionary:
	var target_lookup: Dictionary = {}
	if targets_root == null:
		return target_lookup
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var side_root: Node3D = _ensure_named_child_node(
			targets_root,
			"%sFingerGripTargets" % SLOT_LABELS.get(slot_id, "Hand")
		)
		var side_lookup: Dictionary = {}
		for finger_id: StringName in FINGER_IDS:
			side_lookup[finger_id] = _ensure_named_child_node(
				side_root,
				"%sGripTarget" % FINGER_LABELS.get(finger_id, "Finger")
			)
		target_lookup[slot_id] = side_lookup
	return target_lookup

func ensure_finger_ik_modifiers(
	skeleton: Skeleton3D,
	modifier_lookup: Dictionary,
	finger_target_lookup: Dictionary
) -> Dictionary:
	var resolved_lookup: Dictionary = modifier_lookup.duplicate(true)
	if skeleton == null:
		return resolved_lookup
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var side_target_lookup: Dictionary = finger_target_lookup.get(slot_id, {})
		var side_chains: Dictionary = FINGER_CHAINS.get(slot_id, {})
		for finger_id: StringName in FINGER_IDS:
			var chain_def: Dictionary = side_chains.get(finger_id, {})
			var target_node: Node3D = side_target_lookup.get(finger_id) as Node3D
			var modifier_key: StringName = StringName("%s_%s" % [String(slot_id), String(finger_id)])
			resolved_lookup[modifier_key] = _ensure_finger_ik_modifier(
				skeleton,
				"%s%sGripIK" % [SLOT_LABELS.get(slot_id, "Hand"), FINGER_LABELS.get(finger_id, "Finger")],
				chain_def.get("root", StringName()),
				chain_def.get("end", StringName()),
				target_node
			)
	return resolved_lookup

func update_finger_grip_targets(
	skeleton: Skeleton3D,
	source_lookup: Dictionary,
	finger_target_lookup: Dictionary,
	get_bone_world_position_callable: Callable,
	smoothing_speed: float,
	delta: float,
	allow_exact_surface_solve: bool = false
) -> void:
	if skeleton == null:
		return
	_ensure_animation_grip_baseline_cache()
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var side_targets: Dictionary = finger_target_lookup.get(slot_id, {})
		var grip_guide: Node3D = source_lookup.get(slot_id) as Node3D
		if grip_guide == null or not is_instance_valid(grip_guide):
			continue
		var grip_center_node: Node3D = _resolve_grip_center_node(grip_guide)
		if (
			grip_center_node == null
			or not bool(grip_center_node.get_meta("grip_shell_valid", false))
		):
			_clear_contact_ray_debug(grip_center_node)
			_apply_animation_contact_open_pose(skeleton, slot_id)
			continue
		var profile_offsets: Array = grip_center_node.get_meta("grip_shell_profile_offsets_minor", []) as Array
		if profile_offsets.is_empty():
			_clear_contact_ray_debug(grip_center_node)
			_apply_animation_contact_open_pose(skeleton, slot_id)
			continue
		var cell_world_size: float = float(grip_center_node.get_meta("grip_shell_cell_world_size", 0.0))
		if cell_world_size <= 0.0:
			_clear_contact_ray_debug(grip_center_node)
			_apply_animation_contact_open_pose(skeleton, slot_id)
			continue
		var major_axis_local: Vector3 = _resolve_grip_shell_axis_local(
			grip_center_node,
			&"grip_shell_major_axis_local",
			&"grip_shell_major_axis_origin_id",
			Vector3.FORWARD
		)
		var minor_axis_a_local: Vector3 = _resolve_grip_shell_axis_local(
			grip_center_node,
			&"grip_shell_minor_axis_a_local",
			&"grip_shell_minor_axis_a_origin_id",
			Vector3.RIGHT
		)
		var minor_axis_b_local: Vector3 = _resolve_grip_shell_axis_local(
			grip_center_node,
			&"grip_shell_minor_axis_b_local",
			&"grip_shell_minor_axis_b_origin_id",
			Vector3.UP
		)
		var center_world: Vector3 = grip_center_node.global_position
		var major_axis_world: Vector3 = (grip_center_node.global_basis * major_axis_local).normalized()
		var minor_axis_a_world: Vector3 = (grip_center_node.global_basis * minor_axis_a_local).normalized()
		var minor_axis_b_world: Vector3 = (grip_center_node.global_basis * minor_axis_b_local).normalized()
		var contact_axes: Dictionary = _resolve_roll_decoupled_contact_axes(
			skeleton,
			slot_id,
			major_axis_world,
			minor_axis_a_world,
			minor_axis_b_world
		)
		minor_axis_a_world = contact_axes.get("minor_axis_a_world", minor_axis_a_world) as Vector3
		minor_axis_b_world = contact_axes.get("minor_axis_b_world", minor_axis_b_world) as Vector3
		var side_chains: Dictionary = FINGER_CHAINS.get(slot_id, {})
		var palm_frame: Dictionary = _build_palm_frame(
			slot_id,
			get_bone_world_position_callable,
			center_world,
			major_axis_world,
			minor_axis_a_world,
			minor_axis_b_world
		)
		if palm_frame.is_empty():
			continue
		var contact_group_center_world: Vector3 = palm_frame.get("center_world", center_world) as Vector3
		var contact_distance_meters: float = contact_group_center_world.distance_to(center_world)
		var contact_readiness: float = _resolve_grip_contact_readiness(contact_distance_meters, cell_world_size)
		_set_source_contact_readiness(grip_guide, grip_center_node, contact_readiness, contact_distance_meters)
		if bool(grip_center_node.get_meta("grip_shell_exact_surface", false)):
			var execution_path_id: StringName = _resolve_grip_execution_path_id(
				slot_id,
				grip_guide
			)
			if execution_path_id == StringName():
				active_grip_execution_path_lookup.erase(slot_id)
			else:
				active_grip_execution_path_lookup[slot_id] = execution_path_id
			match execution_path_id:
				GRIP_PATH_RIGHT_PRIMARY:
					_update_right_primary_exact_surface_serial_grasp(
						skeleton,
						grip_guide,
						grip_center_node,
						contact_readiness,
						allow_exact_surface_solve
					)
				GRIP_PATH_LEFT_PRIMARY:
					_update_left_primary_exact_surface_serial_grasp(
						skeleton,
						grip_guide,
						grip_center_node,
						contact_readiness,
						allow_exact_surface_solve
					)
				GRIP_PATH_RIGHT_SUPPORT:
					_update_right_support_exact_surface_serial_grasp(
						skeleton,
						grip_guide,
						grip_center_node,
						contact_readiness,
						allow_exact_surface_solve
					)
				GRIP_PATH_LEFT_SUPPORT:
					_update_left_support_exact_surface_serial_grasp(
						skeleton,
						grip_guide,
						grip_center_node,
						contact_readiness,
						allow_exact_surface_solve
					)
				_:
					_clear_contact_ray_debug(grip_center_node)
					_apply_animation_contact_open_pose(skeleton, slot_id)
			_sync_finger_targets_to_current_pose(skeleton, slot_id, side_targets)
			# Exact Forge V2 Handles have one authority: the serial local-hinge
			# solver above. Never fall through to the legacy Bezier/max-curl path.
			continue
		_clear_contact_ray_debug(grip_center_node)
		_apply_animation_contact_open_pose(skeleton, slot_id)
		for finger_id: StringName in FINGER_IDS:
			var target_node: Node3D = side_targets.get(finger_id) as Node3D
			var chain_def: Dictionary = side_chains.get(finger_id, {})
			if target_node == null:
				continue
			var desired_position: Vector3 = _resolve_animation_baseline_tip_world_position_from_cache(
				skeleton,
				animation_idle_baseline_cache,
				slot_id,
				finger_id
			)
			if contact_readiness > 0.001:
				if _finger_uses_plane_curl_path(finger_id):
					desired_position = _resolve_plane_curl_finger_target_world_position(
						skeleton,
						slot_id,
						finger_id,
						chain_def,
						grip_center_node,
						cell_world_size,
						contact_readiness
					)
				else:
					desired_position = _resolve_finger_target_world_position(
						skeleton,
						slot_id,
						finger_id,
						chain_def,
						grip_center_node,
						palm_frame,
						center_world,
						profile_offsets,
						cell_world_size,
						major_axis_world,
						minor_axis_a_world,
						minor_axis_b_world,
						get_bone_world_position_callable
					)
			_move_target_toward(target_node, desired_position, smoothing_speed, delta)


func apply_exact_surface_open_pose_now(
	skeleton: Skeleton3D,
	slot_id: StringName
) -> bool:
	if skeleton == null or _active_grip_execution_path_id(slot_id) == StringName():
		return false
	_ensure_animation_grip_baseline_cache()
	var slot_cache: Dictionary = animation_idle_baseline_cache.get(
		slot_id,
		{}
	) as Dictionary
	var cached_rotations: Dictionary = slot_cache.get("rotations", {}) as Dictionary
	var expected_bone_count: int = PlayerDigitHingeRulesScript.get_finger_bone_names(
		slot_id
	).size()
	if expected_bone_count != 15 or cached_rotations.size() != expected_bone_count:
		return false
	_apply_animation_contact_open_pose(skeleton, slot_id)
	return true


func note_grip_source_assigned(slot_id: StringName, guide_node: Node3D) -> void:
	var execution_path_id: StringName = _resolve_grip_execution_path_id(
		slot_id,
		guide_node
	)
	if execution_path_id == StringName():
		_erase_cached_grip_execution_paths_for_slot(slot_id)
		active_grip_execution_path_lookup.erase(slot_id)
		return
	active_grip_execution_path_lookup[slot_id] = execution_path_id
	var source_instance_id: int = (
		guide_node.get_instance_id()
		if guide_node != null and is_instance_valid(guide_node)
		else 0
	)
	var state: Dictionary = surface_grasp_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	if int(state.get("source_instance_id", 0)) != source_instance_id:
		surface_grasp_state_lookup.erase(execution_path_id)
	var seat_state: Dictionary = weapon_surface_seat_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	if int(seat_state.get("source_instance_id", 0)) != source_instance_id:
		weapon_surface_seat_state_lookup.erase(execution_path_id)
		weapon_surface_seat_prepared_attempt_lookup.erase(execution_path_id)


func note_grip_source_cleared(slot_id: StringName) -> void:
	_erase_cached_grip_execution_paths_for_slot(slot_id)
	active_grip_execution_path_lookup.erase(slot_id)


func invalidate_cached_surface_grasp(slot_id: StringName = StringName()) -> void:
	if slot_id == StringName():
		for path_variant: Variant in surface_grasp_state_lookup.keys():
			_mark_surface_grasp_path_for_resolve(StringName(path_variant))
	else:
		for path_id: StringName in _grip_execution_paths_for_slot(slot_id):
			_mark_surface_grasp_path_for_resolve(path_id)


func _mark_surface_grasp_path_for_resolve(execution_path_id: StringName) -> void:
	var state: Dictionary = surface_grasp_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	if state.is_empty():
		return
	# Invalidation requests a replacement solve; it does not revoke the last safe
	# 15-bone packet while those rotations are still live on the Skeleton3D. Keep
	# rotations and their exact zero reference atomic until a new candidate commits.
	state["force_surface_resolve"] = true
	state["surface_resolve_invalidation_count"] = int(state.get(
		"surface_resolve_invalidation_count",
		0
	)) + 1
	state.erase("last_attempt_context_key")
	state.erase("last_attempt_status")
	state.erase("last_attempt_diagnostics")
	surface_grasp_state_lookup[execution_path_id] = state


func invalidate_cached_weapon_surface_seat(slot_id: StringName = StringName()) -> void:
	if slot_id == StringName():
		weapon_surface_seat_state_lookup.clear()
		weapon_surface_seat_prepared_attempt_lookup.clear()
	else:
		for path_id: StringName in _grip_execution_paths_for_slot(slot_id):
			weapon_surface_seat_state_lookup.erase(path_id)
			weapon_surface_seat_prepared_attempt_lookup.erase(path_id)


func get_surface_grasp_debug_state(slot_id: StringName) -> Dictionary:
	var execution_path_id: StringName = _active_grip_execution_path_id(slot_id)
	return (surface_grasp_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary).duplicate(true)


func reapply_committed_surface_grasp(
	skeleton: Skeleton3D,
	slot_id: StringName
) -> bool:
	if skeleton == null:
		return false
	var execution_path_id: StringName = _active_grip_execution_path_id(slot_id)
	if execution_path_id == StringName():
		return false
	var state: Dictionary = surface_grasp_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	if (
		not bool(state.get("valid", false))
		or String(state.get("context_key", "")).is_empty()
	):
		return false
	var rotations: Dictionary = _sanitize_surface_grasp_rotations(
		slot_id,
		state.get("rotations", {}) as Dictionary
	)
	if rotations.size() != 15:
		return false
	return _apply_surface_grasp_rotations(skeleton, slot_id, rotations)


func get_committed_surface_grasp_zero_packet(slot_id: StringName) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"committed_surface_grasp_zero_packet_unavailable",
		"slot_id": slot_id,
		"grip_execution_path_id": StringName(),
		"context_key": "",
		"zero_rotations": {},
		"packet_signature": "",
	}
	var execution_path_id: StringName = _active_grip_execution_path_id(slot_id)
	invalid["grip_execution_path_id"] = execution_path_id
	if execution_path_id == StringName():
		invalid["status"] = &"no_active_grip_execution_path"
		return invalid
	var state: Dictionary = surface_grasp_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	var context_key: String = String(state.get("context_key", ""))
	invalid["context_key"] = context_key
	var expected_bone_count: int = PlayerDigitHingeRulesScript.get_finger_bone_names(
		slot_id
	).size()
	var committed_rotations: Dictionary = state.get("rotations", {}) as Dictionary
	var committed_zero_rotations: Dictionary = _sanitize_surface_grasp_rotations(
		slot_id,
		state.get("zero_rotations", {}) as Dictionary
	)
	var zero_context_key: String = String(state.get(
		"zero_rotation_context_key",
		""
	))
	var packet_signature: String = String(state.get(
		"zero_rotation_packet_signature",
		""
	))
	if (
		not bool(state.get("valid", false))
		or context_key.is_empty()
		or zero_context_key != context_key
		or expected_bone_count != 15
		or committed_rotations.size() != expected_bone_count
		or committed_zero_rotations.size() != expected_bone_count
		or packet_signature.is_empty()
	):
		invalid["status"] = &"incomplete_committed_surface_grasp_zero_packet"
		return invalid
	return {
		"valid": true,
		"status": &"committed_surface_grasp_zero_packet_ready",
		"slot_id": slot_id,
		"grip_execution_path_id": execution_path_id,
		"context_key": context_key,
		"zero_rotations": committed_zero_rotations.duplicate(true),
		"packet_signature": packet_signature,
	}


func resolve_exact_surface_hand_seat_context_key(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D
) -> String:
	return resolve_exact_surface_weapon_seat_context_key(
		skeleton,
		slot_id,
		grip_guide
	)


func resolve_exact_surface_weapon_seat_context_key(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D
) -> String:
	var execution_path_id: StringName = _resolve_grip_execution_path_id(
		slot_id,
		grip_guide
	)
	if execution_path_id == StringName():
		return ""
	return _resolve_exact_surface_weapon_seat_context_key_for_path(
		skeleton,
		slot_id,
		grip_guide,
		execution_path_id
	)


func _resolve_exact_surface_weapon_seat_context_key_for_path(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D,
	execution_path_id: StringName
) -> String:
	if grip_guide == null or not is_instance_valid(grip_guide):
		return ""
	if _resolve_grip_execution_path_id(slot_id, grip_guide) != execution_path_id:
		return ""
	var grip_center_node: Node3D = _resolve_grip_center_node(grip_guide)
	var exact_surface_identity: Dictionary = _resolve_exact_handle_surface_identity_state(
		grip_center_node,
		execution_path_id
	)
	if not bool(exact_surface_identity.get("valid", false)):
		return ""
	var base_context_key: String = _build_surface_grasp_context_key(
		skeleton,
		slot_id,
		grip_guide,
		grip_center_node,
		exact_surface_identity,
		execution_path_id
	)
	var held_item: Node3D = grip_guide.get_parent() as Node3D
	if held_item == null or base_context_key.is_empty():
		return ""
	var ratio_meta_keys: Dictionary = _resolve_preview_grip_seat_ratio_meta_keys(
		execution_path_id
	)
	if not bool(ratio_meta_keys.get("valid", false)):
		return ""
	var ratio_origin_id: StringName = StringName(held_item.get_meta(
		StringName(ratio_meta_keys.get("origin_meta", StringName())),
		StringName()
	))
	var seat_ratio: float = float(held_item.get_meta(
		StringName(ratio_meta_keys.get("ratio_meta", StringName())),
		INF
	))
	if ratio_origin_id == StringName() or not is_finite(seat_ratio):
		return ""
	return str(hash([
		base_context_key,
		String(execution_path_id),
		hand_surface_seat_solver.get_revision(),
		String(ratio_origin_id),
		roundi(seat_ratio * 1000000.0),
	]))


func resolve_exact_surface_weapon_seat(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	allow_surface_solve: bool
) -> Dictionary:
	match _resolve_grip_execution_path_id(slot_id, grip_guide):
		GRIP_PATH_RIGHT_PRIMARY:
			return resolve_right_primary_exact_surface_weapon_seat(
				skeleton,
				grip_guide,
				anatomy_state,
				allow_surface_solve
			)
		GRIP_PATH_LEFT_PRIMARY:
			return resolve_left_primary_exact_surface_weapon_seat(
				skeleton,
				grip_guide,
				anatomy_state,
				allow_surface_solve
			)
		GRIP_PATH_RIGHT_SUPPORT:
			return resolve_right_support_exact_surface_weapon_seat(
				skeleton,
				grip_guide,
				anatomy_state,
				allow_surface_solve
			)
		GRIP_PATH_LEFT_SUPPORT:
			return resolve_left_support_exact_surface_weapon_seat(
				skeleton,
				grip_guide,
				anatomy_state,
				allow_surface_solve
			)
	return {
		"valid": false,
		"status": &"weapon_surface_seat_execution_path_invalid",
		"context_key": "",
	}


func resolve_right_primary_exact_surface_weapon_seat(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	allow_surface_solve: bool
) -> Dictionary:
	return _resolve_exact_surface_weapon_seat_for_path(
		skeleton,
		SLOT_RIGHT,
		grip_guide,
		anatomy_state,
		allow_surface_solve,
		GRIP_PATH_RIGHT_PRIMARY,
		false
	)


func resolve_left_primary_exact_surface_weapon_seat(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	allow_surface_solve: bool
) -> Dictionary:
	return _resolve_exact_surface_weapon_seat_for_path(
		skeleton,
		SLOT_LEFT,
		grip_guide,
		anatomy_state,
		allow_surface_solve,
		GRIP_PATH_LEFT_PRIMARY,
		false
	)


func resolve_right_support_exact_surface_weapon_seat(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	allow_surface_solve: bool
) -> Dictionary:
	return _resolve_exact_surface_weapon_seat_for_path(
		skeleton,
		SLOT_RIGHT,
		grip_guide,
		anatomy_state,
		allow_surface_solve,
		GRIP_PATH_RIGHT_SUPPORT,
		true
	)


func resolve_left_support_exact_surface_weapon_seat(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	allow_surface_solve: bool
) -> Dictionary:
	return _resolve_exact_surface_weapon_seat_for_path(
		skeleton,
		SLOT_LEFT,
		grip_guide,
		anatomy_state,
		allow_surface_solve,
		GRIP_PATH_LEFT_SUPPORT,
		true
	)


func _resolve_exact_surface_weapon_seat_for_path(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	allow_surface_solve: bool,
	execution_path_id: StringName,
	enforce_ordinary_proximal_safety: bool
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"weapon_surface_seat_input_invalid",
		"context_key": "",
		"grip_execution_path_id": execution_path_id,
	}
	if grip_guide == null or not is_instance_valid(grip_guide):
		return invalid
	if _resolve_grip_execution_path_id(slot_id, grip_guide) != execution_path_id:
		invalid["status"] = &"weapon_surface_seat_execution_path_mismatch"
		return invalid
	var held_item: Node3D = grip_guide.get_parent() as Node3D
	var grip_center_node: Node3D = _resolve_grip_center_node(grip_guide)
	var exact_surface_identity: Dictionary = _resolve_exact_handle_surface_identity_state(
		grip_center_node,
		execution_path_id
	)
	if held_item == null or not bool(exact_surface_identity.get("valid", false)):
		invalid["status"] = exact_surface_identity.get(
			"status",
			&"invalid_exact_handle_surface"
		)
		return invalid
	var context_key: String = _resolve_exact_surface_weapon_seat_context_key_for_path(
		skeleton,
		slot_id,
		grip_guide,
		execution_path_id
	)
	invalid["context_key"] = context_key
	if context_key.is_empty() or not bool(anatomy_state.get("valid", false)):
		invalid["status"] = &"weapon_surface_seat_context_invalid"
		return invalid
	var state: Dictionary = weapon_surface_seat_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	if (
		String(state.get("context_key", "")) == context_key
		and bool(state.get("terminal", false))
	):
		state["cache_hit_count"] = int(state.get("cache_hit_count", 0)) + 1
		weapon_surface_seat_state_lookup[execution_path_id] = state
		_publish_hand_surface_seat_diagnostics(grip_guide, grip_center_node, state)
		return state.duplicate(true)
	if not allow_surface_solve:
		invalid["status"] = &"weapon_surface_seat_deferred"
		invalid["source_instance_id"] = grip_guide.get_instance_id()
		return invalid
	var cumulative_solve_count: int = int(state.get("solve_count", 0)) + 1
	var cumulative_geometry_load_count: int = int(
		state.get("surface_geometry_load_count", 0)
	) + 1
	var stations: Dictionary = _resolve_weapon_surface_seat_stations(
		held_item,
		grip_guide,
		anatomy_state,
		execution_path_id
	)
	if not bool(stations.get("valid", false)):
		return _cache_weapon_surface_seat_failure(
			execution_path_id,
			grip_guide,
			grip_center_node,
			context_key,
			cumulative_solve_count,
			int(state.get("surface_geometry_load_count", 0)),
			stations.get("status", &"weapon_surface_seat_stations_invalid") as StringName,
			stations
		)
	var exact_surface: Dictionary = _resolve_exact_handle_surface_faces(
		exact_surface_identity
	)
	if not bool(exact_surface.get("valid", false)):
		return _cache_weapon_surface_seat_failure(
			execution_path_id,
			grip_guide,
			grip_center_node,
			context_key,
			cumulative_solve_count,
			cumulative_geometry_load_count,
			exact_surface.get("status", &"exact_surface_faces_missing") as StringName,
			exact_surface
		)
	var exact_faces: PackedVector3Array = exact_surface.get(
		"faces_local",
		PackedVector3Array()
	) as PackedVector3Array
	var exact_mesh: ArrayMesh = _build_exact_surface_array_mesh(exact_faces)
	var collision_shape: CollisionShape3D = exact_surface.get(
		"collision_shape"
	) as CollisionShape3D
	if exact_mesh == null or collision_shape == null:
		return _cache_weapon_surface_seat_failure(
			execution_path_id,
			grip_guide,
			grip_center_node,
			context_key,
			cumulative_solve_count,
			cumulative_geometry_load_count,
			&"weapon_surface_seat_mesh_missing",
			{"status": &"weapon_surface_seat_mesh_missing"}
		)
	var contact_surface_origin_id: StringName = exact_surface.get(
		"contact_surface_origin_id",
		StringName()
	) as StringName
	var prepared_surface: Dictionary = surface_grasp_solver.call(
		"prepare_surface",
		exact_mesh,
		collision_shape.global_transform,
		{
			"surface_source_origin_id": contact_surface_origin_id,
			"resolved_world_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
			"grip_filter_signature": [
				PrimaryGripHandleMeshPacketScript.SOURCE,
				exact_surface.get("body_signature", ""),
				contact_surface_origin_id,
				hash(exact_faces),
			],
		}
	) as Dictionary
	if not bool(prepared_surface.get("valid", false)):
		return _cache_weapon_surface_seat_failure(
			execution_path_id,
			grip_guide,
			grip_center_node,
			context_key,
			cumulative_solve_count,
			cumulative_geometry_load_count,
			prepared_surface.get("status", &"surface_prepare_failed") as StringName,
			prepared_surface
		)
	var seat_anatomy_state: Dictionary = anatomy_state.duplicate(true)
	# Primary already owns and moves the weapon. The additional full proximal
	# pre-seat safety gate exists for the inverse-composed support relationship,
	# where accepting only the index/pinky point probes could leave an ordinary
	# proximal phalanx buried before the shared digit solver starts.
	seat_anatomy_state["enforce_ordinary_proximal_safety"] = (
		enforce_ordinary_proximal_safety
	)
	var solve_started_usec: int = Time.get_ticks_usec()
	var solve_result: Dictionary = hand_surface_seat_solver.call(
		"solve_prepared",
		prepared_surface,
		seat_anatomy_state,
		stations.get("grip_pivot_c0_world", Vector3.ZERO) as Vector3,
		stations.get("index_slice_center_ci_world", Vector3.ZERO) as Vector3,
		stations.get("pinky_slice_center_cp_world", Vector3.ZERO) as Vector3,
		stations.get("endcap_axis_world", Vector3.ZERO) as Vector3,
		contact_surface_origin_id,
		PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID
	) as Dictionary
	var diagnostics: Dictionary = (
		solve_result.get("diagnostics", {}) as Dictionary
	).duplicate(true)
	diagnostics["solve_time_msec"] = float(
		Time.get_ticks_usec() - solve_started_usec
	) / 1000.0
	diagnostics["context_key"] = context_key
	diagnostics["grip_execution_path_id"] = execution_path_id
	diagnostics["surface_authority"] = PrimaryGripHandleMeshPacketScript.SOURCE
	diagnostics["surface_origin_id"] = contact_surface_origin_id
	diagnostics["bone_root_origin_id"] = PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID
	diagnostics["solve_order"] = &"c0_ci_cp_weapon_pivot_then_digits"
	diagnostics["stations"] = stations.duplicate(true)
	state = {
		"valid": bool(solve_result.get("valid", false)),
		"terminal": true,
		"status": solve_result.get("status", &"weapon_surface_seat_unsolved"),
		"context_key": context_key,
		"grip_execution_path_id": execution_path_id,
		"source_instance_id": grip_guide.get_instance_id(),
		"solve_count": cumulative_solve_count,
		"surface_geometry_load_count": cumulative_geometry_load_count,
		"cache_hit_count": 0,
		"diagnostics": diagnostics,
	}
	if bool(state.get("valid", false)):
		var correction_world: Transform3D = solve_result.get(
			"candidate_weapon_correction_about_grip_world",
			Transform3D.IDENTITY
		) as Transform3D
		var base_weapon_transform_world: Transform3D = held_item.global_transform
		var seat_correction_grip_local: Transform3D = (
			base_weapon_transform_world.affine_inverse()
			* correction_world
			* base_weapon_transform_world
		)
		var grip_pivot_local: Vector3 = stations.get(
			"grip_pivot_c0_local",
			Vector3.ZERO
		) as Vector3
		if (
			not _transform_is_finite(seat_correction_grip_local)
			or not grip_pivot_local.is_finite()
		):
			state["valid"] = false
			state["status"] = &"weapon_surface_seat_result_invalid"
		else:
			state["seat_correction_grip_local"] = seat_correction_grip_local
			state["seat_correction_grip_local_origin_id"] = (
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
			# Keep the rotational component visible to diagnostics, but the complete
			# Transform3D above is the only composition authority.  Its origin also
			# carries the required Handle-to-fixed-hand radial displacement.
			state["seat_rotation_grip_local"] = (
				seat_correction_grip_local.basis.orthonormalized()
			)
			state["seat_rotation_grip_local_origin_id"] = (
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
			state["grip_pivot_local"] = grip_pivot_local
			state["grip_pivot_local_origin_id"] = (
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
			state["grip_axis_ratio_from_span_start"] = float(stations.get(
				"grip_axis_ratio_from_span_start",
				0.0
			))
			state["index_station_ratio_from_span_start"] = float(stations.get(
				"index_station_ratio_from_span_start",
				0.0
			))
			state["pinky_station_ratio_from_span_start"] = float(stations.get(
				"pinky_station_ratio_from_span_start",
				0.0
			))
			state["index_radial_error_meters"] = float(solve_result.get(
				"index_radial_error_meters",
				INF
			))
			state["pinky_radial_error_meters"] = float(solve_result.get(
				"pinky_radial_error_meters",
				INF
			))
			state["seat_signature"] = String(solve_result.get(
				"seat_signature",
				""
			))
	weapon_surface_seat_state_lookup[execution_path_id] = state
	weapon_surface_seat_prepared_attempt_lookup[execution_path_id] = {
		"context_key": context_key,
		"collision_transform_hash": hash(collision_shape.global_transform),
		"exact_surface": exact_surface,
		"prepared_surface": prepared_surface,
	}
	_publish_hand_surface_seat_diagnostics(grip_guide, grip_center_node, state)
	return state.duplicate(true)


func _resolve_weapon_surface_seat_stations(
	held_item: Node3D,
	grip_guide: Node3D,
	anatomy_state: Dictionary,
	execution_path_id: StringName
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"weapon_surface_seat_station_data_missing",
	}
	if held_item == null or grip_guide == null:
		return invalid
	var ratio_meta_keys: Dictionary = _resolve_preview_grip_seat_ratio_meta_keys(
		execution_path_id
	)
	if not bool(ratio_meta_keys.get("valid", false)):
		invalid["status"] = &"weapon_surface_seat_guide_role_invalid"
		return invalid
	var path_origin_id: StringName = StringName(held_item.get_meta(
		"primary_grip_slice_center_path_origin_id",
		StringName()
	))
	var ratio_origin_id: StringName = StringName(held_item.get_meta(
		StringName(ratio_meta_keys.get("origin_meta", StringName())),
		StringName()
	))
	var span_start_origin_id: StringName = StringName(held_item.get_meta(
		"primary_grip_span_start_origin_id",
		StringName()
	))
	var span_end_origin_id: StringName = StringName(held_item.get_meta(
		"primary_grip_span_end_origin_id",
		StringName()
	))
	if (
		path_origin_id != CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		or ratio_origin_id != path_origin_id
		or span_start_origin_id != path_origin_id
		or span_end_origin_id != path_origin_id
	):
		invalid["status"] = &"weapon_surface_seat_station_origin_mismatch"
		return invalid
	var ratios_variant: Variant = held_item.get_meta(
		"primary_grip_slice_axis_ratios_from_span_start",
		null
	)
	var centers_variant: Variant = held_item.get_meta(
		"primary_grip_slice_centers_local",
		null
	)
	var span_start_variant: Variant = held_item.get_meta(
		"primary_grip_span_start_local",
		null
	)
	var span_end_variant: Variant = held_item.get_meta(
		"primary_grip_span_end_local",
		null
	)
	if (
		not ratios_variant is PackedFloat32Array
		or not centers_variant is PackedVector3Array
		or not span_start_variant is Vector3
		or not span_end_variant is Vector3
	):
		return invalid
	var ratios: PackedFloat32Array = ratios_variant as PackedFloat32Array
	var centers: PackedVector3Array = centers_variant as PackedVector3Array
	if not PrimaryGripSeatResolverScript.sampled_path_is_valid(ratios, centers):
		invalid["status"] = &"weapon_surface_seat_path_invalid"
		return invalid
	var c0_ratio: float = float(held_item.get_meta(
		StringName(ratio_meta_keys.get("ratio_meta", StringName())),
		INF
	))
	if not is_finite(c0_ratio) or c0_ratio < 0.0 or c0_ratio > 1.0:
		invalid["status"] = &"weapon_surface_seat_ratio_missing"
		return invalid
	var c0_state: Dictionary = PrimaryGripSeatResolverScript.resolve_sampled_seat(
		ratios,
		centers,
		path_origin_id,
		c0_ratio
	)
	if not bool(c0_state.get("valid", false)):
		invalid["status"] = &"weapon_surface_seat_c0_missing"
		return invalid
	var c0_local: Vector3 = c0_state.get("position", Vector3.ZERO) as Vector3
	if c0_local.distance_to(grip_guide.position) > 0.0005:
		invalid["status"] = &"weapon_surface_seat_guide_path_mismatch"
		invalid["guide_path_error_meters"] = c0_local.distance_to(
			grip_guide.position
		)
		return invalid
	var span_start_local: Vector3 = span_start_variant as Vector3
	var span_end_local: Vector3 = span_end_variant as Vector3
	var span_start_world: Vector3 = held_item.to_global(span_start_local)
	var span_end_world: Vector3 = held_item.to_global(span_end_local)
	var endcap_vector_world: Vector3 = span_end_world - span_start_world
	var span_length_meters: float = endcap_vector_world.length()
	if span_length_meters <= 0.000001:
		invalid["status"] = &"weapon_surface_seat_endcap_axis_missing"
		return invalid
	var endcap_axis_world: Vector3 = endcap_vector_world / span_length_meters
	var c0_world: Vector3 = held_item.to_global(c0_local)
	var index_world: Vector3 = anatomy_state.get(
		"index_point_world",
		Vector3.ZERO
	) as Vector3
	var pinky_world: Vector3 = anatomy_state.get(
		"pinky_point_world",
		Vector3.ZERO
	) as Vector3
	var index_signed_offset_meters: float = (
		index_world - c0_world
	).dot(endcap_axis_world)
	var pinky_signed_offset_meters: float = (
		pinky_world - c0_world
	).dot(endcap_axis_world)
	var index_ratio: float = c0_ratio + (
		index_signed_offset_meters / span_length_meters
	)
	var pinky_ratio: float = c0_ratio + (
		pinky_signed_offset_meters / span_length_meters
	)
	if (
		index_ratio < 0.0
		or index_ratio > 1.0
		or pinky_ratio < 0.0
		or pinky_ratio > 1.0
	):
		invalid["status"] = &"weapon_surface_seat_digit_station_outside_handle"
		invalid["index_station_ratio_from_span_start"] = index_ratio
		invalid["pinky_station_ratio_from_span_start"] = pinky_ratio
		return invalid
	var index_state: Dictionary = PrimaryGripSeatResolverScript.resolve_sampled_seat(
		ratios,
		centers,
		path_origin_id,
		index_ratio
	)
	var pinky_state: Dictionary = PrimaryGripSeatResolverScript.resolve_sampled_seat(
		ratios,
		centers,
		path_origin_id,
		pinky_ratio
	)
	if (
		not bool(index_state.get("valid", false))
		or not bool(pinky_state.get("valid", false))
	):
		invalid["status"] = &"weapon_surface_seat_digit_slice_missing"
		return invalid
	var index_local: Vector3 = index_state.get("position", Vector3.ZERO) as Vector3
	var pinky_local: Vector3 = pinky_state.get("position", Vector3.ZERO) as Vector3
	return {
		"valid": true,
		"status": &"weapon_surface_seat_stations_ready",
		"grip_pivot_c0_local": c0_local,
		"grip_pivot_c0_local_origin_id": path_origin_id,
		"grip_pivot_c0_world": c0_world,
		"grip_pivot_c0_world_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
		"index_slice_center_ci_local": index_local,
		"index_slice_center_ci_local_origin_id": path_origin_id,
		"index_slice_center_ci_world": held_item.to_global(index_local),
		"index_slice_center_ci_world_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
		"pinky_slice_center_cp_local": pinky_local,
		"pinky_slice_center_cp_local_origin_id": path_origin_id,
		"pinky_slice_center_cp_world": held_item.to_global(pinky_local),
		"pinky_slice_center_cp_world_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
		"endcap_axis_world": endcap_axis_world,
		"endcap_axis_world_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
		"grip_axis_ratio_from_span_start": c0_ratio,
		"index_station_ratio_from_span_start": index_ratio,
		"pinky_station_ratio_from_span_start": pinky_ratio,
		"index_signed_offset_from_grip_meters": index_signed_offset_meters,
		"pinky_signed_offset_from_grip_meters": pinky_signed_offset_meters,
		"span_length_meters": span_length_meters,
	}


func _resolve_preview_grip_seat_ratio_meta_keys(
	execution_path_id: StringName
) -> Dictionary:
	match execution_path_id:
		GRIP_PATH_RIGHT_PRIMARY, GRIP_PATH_LEFT_PRIMARY:
			return {
				"valid": true,
				"ratio_meta": StringName(PREVIEW_PRIMARY_GRIP_SEAT_RATIO_META),
				"origin_meta": StringName(PREVIEW_PRIMARY_GRIP_SEAT_RATIO_ORIGIN_META),
			}
		GRIP_PATH_RIGHT_SUPPORT, GRIP_PATH_LEFT_SUPPORT:
			return {
				"valid": true,
				"ratio_meta": StringName(PREVIEW_SUPPORT_GRIP_SEAT_RATIO_META),
				"origin_meta": StringName(PREVIEW_SUPPORT_GRIP_SEAT_RATIO_ORIGIN_META),
			}
	return {"valid": false}


func _cache_weapon_surface_seat_failure(
	execution_path_id: StringName,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	context_key: String,
	solve_count: int,
	geometry_load_count: int,
	status: StringName,
	diagnostics: Dictionary
) -> Dictionary:
	var recorded_diagnostics: Dictionary = diagnostics.duplicate(true)
	recorded_diagnostics["grip_execution_path_id"] = execution_path_id
	var state := {
		"valid": false,
		"terminal": true,
		"status": status,
		"context_key": context_key,
		"grip_execution_path_id": execution_path_id,
		"source_instance_id": grip_guide.get_instance_id(),
		"solve_count": solve_count,
		"surface_geometry_load_count": geometry_load_count,
		"cache_hit_count": 0,
		"diagnostics": recorded_diagnostics,
	}
	weapon_surface_seat_state_lookup[execution_path_id] = state
	_publish_hand_surface_seat_diagnostics(grip_guide, grip_center_node, state)
	return state.duplicate(true)


func get_hand_surface_seat_debug_state(slot_id: StringName) -> Dictionary:
	var execution_path_id: StringName = _active_grip_execution_path_id(slot_id)
	return (weapon_surface_seat_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary).duplicate(true)


func _publish_hand_surface_seat_diagnostics(
	grip_guide: Node3D,
	grip_center_node: Node3D,
	state: Dictionary
) -> void:
	for target_node: Node3D in [grip_guide, grip_center_node]:
		if target_node == null or not is_instance_valid(target_node):
			continue
		target_node.set_meta(
			HAND_SURFACE_SEAT_DIAGNOSTICS_META,
			(state.get("diagnostics", {}) as Dictionary).duplicate(true)
		)
		target_node.set_meta(
			HAND_SURFACE_SEAT_CONTEXT_META,
			String(state.get("context_key", ""))
		)


func _update_right_primary_exact_surface_serial_grasp(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	allow_surface_solve: bool
) -> void:
	_update_exact_surface_serial_grasp_for_path(
		skeleton,
		SLOT_RIGHT,
		grip_guide,
		grip_center_node,
		contact_readiness,
		allow_surface_solve,
		GRIP_PATH_RIGHT_PRIMARY
	)


func _update_left_primary_exact_surface_serial_grasp(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	allow_surface_solve: bool
) -> void:
	_update_exact_surface_serial_grasp_for_path(
		skeleton,
		SLOT_LEFT,
		grip_guide,
		grip_center_node,
		contact_readiness,
		allow_surface_solve,
		GRIP_PATH_LEFT_PRIMARY
	)


func _update_right_support_exact_surface_serial_grasp(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	allow_surface_solve: bool
) -> void:
	_update_exact_surface_serial_grasp_for_path(
		skeleton,
		SLOT_RIGHT,
		grip_guide,
		grip_center_node,
		contact_readiness,
		allow_surface_solve,
		GRIP_PATH_RIGHT_SUPPORT
	)


func _update_left_support_exact_surface_serial_grasp(
	skeleton: Skeleton3D,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	allow_surface_solve: bool
) -> void:
	_update_exact_surface_serial_grasp_for_path(
		skeleton,
		SLOT_LEFT,
		grip_guide,
		grip_center_node,
		contact_readiness,
		allow_surface_solve,
		GRIP_PATH_LEFT_SUPPORT
	)


func _update_exact_surface_serial_grasp_for_path(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	allow_surface_solve: bool,
	execution_path_id: StringName
) -> void:
	if _resolve_grip_execution_path_id(slot_id, grip_guide) != execution_path_id:
		_clear_contact_ray_debug(grip_center_node)
		_apply_animation_contact_open_pose(skeleton, slot_id)
		return
	# Surface identity is intentionally cheap and stable. A cached grasp must not
	# copy/hash the complete Handle triangle packet merely to prove that the hand
	# is still sitting at the same weapon-local Handle station.
	var exact_surface_identity: Dictionary = _resolve_exact_handle_surface_identity_state(
		grip_center_node,
		execution_path_id
	)
	var state: Dictionary = surface_grasp_state_lookup.get(
		execution_path_id,
		{}
	) as Dictionary
	state["grip_execution_path_id"] = execution_path_id
	state["source_instance_id"] = grip_guide.get_instance_id()
	if not bool(exact_surface_identity.get("valid", false)):
		state["valid"] = false
		state["status"] = exact_surface_identity.get("status", &"invalid_exact_handle_surface")
		state["diagnostics"] = exact_surface_identity.duplicate(true)
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	var expected_bone_count: int = PlayerDigitHingeRulesScript.get_finger_bone_names(
		slot_id
	).size()
	var context_key: String = _build_surface_grasp_context_key(
		skeleton,
		slot_id,
		grip_guide,
		grip_center_node,
		exact_surface_identity,
		execution_path_id
	)
	if context_key.is_empty():
		state["valid"] = false
		state["status"] = &"missing_stable_grip_context"
		state["diagnostics"] = {
			"status": &"missing_stable_grip_context",
			"required_origin": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		}
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	var cached_rotations: Dictionary = state.get("rotations", {}) as Dictionary
	var has_committed_grasp: bool = (
		bool(state.get("valid", false))
		and not String(state.get("context_key", "")).is_empty()
		and cached_rotations.size() == expected_bone_count
	)
	if (
		has_committed_grasp
		and String(state.get("context_key", "")) == context_key
		and not bool(state.get("force_surface_resolve", false))
	):
		_apply_surface_grasp_rotations(skeleton, slot_id, cached_rotations)
		state["cache_hit_count"] = int(state.get("cache_hit_count", 0)) + 1
		state["last_contact_readiness"] = contact_readiness
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	if not allow_surface_solve:
		if has_committed_grasp:
			_apply_surface_grasp_rotations(skeleton, slot_id, cached_rotations)
		state["pending_context_key"] = context_key
		state["deferred_surface_solve_count"] = int(
			state.get("deferred_surface_solve_count", 0)
		) + 1
		state["last_contact_readiness"] = contact_readiness
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	if String(state.get("last_attempt_context_key", "")) == context_key:
		# A rejected candidate must never expose the temporary open pose used by
		# the solver. Reassert the last committed local grasp while suppressing an
		# identical terminal attempt.
		if has_committed_grasp:
			_apply_surface_grasp_rotations(skeleton, slot_id, cached_rotations)
		state["suppressed_repeat_attempt_count"] = int(
			state.get("suppressed_repeat_attempt_count", 0)
		) + 1
		state["last_contact_readiness"] = contact_readiness
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	if contact_readiness <= 0.001:
		state["pending_context_key"] = context_key
		state["last_contact_readiness"] = contact_readiness
		var waiting_diagnostics := {
			"status": &"waiting_for_macro_hand_seat",
			"contact_readiness": contact_readiness,
		}
		state["last_request_context_key"] = context_key
		state["last_request_status"] = &"waiting_for_macro_hand_seat"
		state["last_request_diagnostics"] = waiting_diagnostics
		if has_committed_grasp:
			_apply_surface_grasp_rotations(skeleton, slot_id, cached_rotations)
		else:
			state["valid"] = false
			state["status"] = &"waiting_for_macro_hand_seat"
			state["diagnostics"] = waiting_diagnostics
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	if not _surface_solver_rules_have_valid_origins(skeleton, slot_id):
		var invalid_origin_diagnostics := {
			"status": &"invalid_digit_origin_chain",
			"bone_root_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
		}
		state["last_request_context_key"] = context_key
		state["last_request_status"] = &"invalid_digit_origin_chain"
		state["last_request_diagnostics"] = invalid_origin_diagnostics
		if has_committed_grasp:
			_apply_surface_grasp_rotations(skeleton, slot_id, cached_rotations)
		else:
			state["valid"] = false
			state["status"] = &"invalid_digit_origin_chain"
			state["diagnostics"] = invalid_origin_diagnostics
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	# Waiting for the macro seat is not a failed exact solve. Record the terminal
	# attempt only after the hand has actually reached a solve-ready relationship,
	# otherwise the same semantic grip would be suppressed forever once it seats.
	state["last_attempt_context_key"] = context_key
	var pre_attempt_live_rotations: Dictionary = _capture_surface_grasp_base_rotations(
		skeleton,
		slot_id
	)
	var rejected_attempt_restore_rotations: Dictionary = (
		cached_rotations.duplicate(true)
		if has_committed_grasp
		else pre_attempt_live_rotations.duplicate(true)
	)
	state["surface_geometry_load_count"] = int(
		state.get("surface_geometry_load_count", 0)
	) + 1
	var exact_surface: Dictionary = _resolve_exact_handle_surface_faces(
		exact_surface_identity
	)
	if not bool(exact_surface.get("valid", false)):
		state = _record_failed_surface_grasp_candidate(
			skeleton,
			slot_id,
			state,
			context_key,
			exact_surface.get("status", &"invalid_exact_handle_surface") as StringName,
			exact_surface.duplicate(true),
			rejected_attempt_restore_rotations,
			expected_bone_count,
			has_committed_grasp
		)
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	_clear_contact_ray_debug(grip_center_node)
	_apply_animation_contact_open_pose(skeleton, slot_id)
	var base_pose_rotations: Dictionary = _capture_surface_grasp_base_rotations(
		skeleton,
		slot_id
	)
	if base_pose_rotations.size() != expected_bone_count:
		var incomplete_snapshot_diagnostics := {
			"status": &"incomplete_open_pose_snapshot",
			"expected_bone_count": expected_bone_count,
			"captured_bone_count": base_pose_rotations.size(),
		}
		state = _record_failed_surface_grasp_candidate(
			skeleton,
			slot_id,
			state,
			context_key,
			&"incomplete_open_pose_snapshot",
			incomplete_snapshot_diagnostics,
			rejected_attempt_restore_rotations,
			expected_bone_count,
			has_committed_grasp
		)
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	var exact_faces: PackedVector3Array = exact_surface.get(
		"faces_local",
		PackedVector3Array()
	) as PackedVector3Array
	var exact_mesh: ArrayMesh = _build_exact_surface_array_mesh(exact_faces)
	if exact_mesh == null or exact_mesh.get_surface_count() != 1:
		state = _record_failed_surface_grasp_candidate(
			skeleton,
			slot_id,
			state,
			context_key,
			&"exact_surface_mesh_build_failed",
			{"status": &"exact_surface_mesh_build_failed"},
			rejected_attempt_restore_rotations,
			expected_bone_count,
			has_committed_grasp
		)
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	var collision_shape: CollisionShape3D = exact_surface.get("collision_shape") as CollisionShape3D
	var grip_center_world: Vector3 = grip_center_node.global_position
	var contact_surface_origin_id: StringName = exact_surface.get(
		"contact_surface_origin_id",
		StringName()
	) as StringName
	var solver_options := {
		"max_overlap_meters": PlayerDigitHingeRulesScript.MAX_CONTACT_OVERLAP_METERS,
		"preferred_overlap_meters": PlayerDigitHingeRulesScript.PREFERRED_CONTACT_OVERLAP_METERS,
		"grip_center_world": grip_center_world,
		"grip_center_world_origin_id": contact_surface_origin_id,
		"fallback_ray_target_world": grip_center_world,
		"fallback_ray_target_world_origin_id": contact_surface_origin_id,
		# Keep the exact protected Handle closed. Cropping its triangles around the
		# active grip station introduces artificial boundary edges and invalidates
		# the inside/outside authority needed by capsule contact.
		"surface_source_origin_id": contact_surface_origin_id,
		"resolved_world_origin_id": PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID,
		"grip_filter_signature": [
			PrimaryGripHandleMeshPacketScript.SOURCE,
			exact_surface.get("body_signature", ""),
			contact_surface_origin_id,
			hash(exact_faces),
		],
		"cache_context_signature": context_key,
		"base_pose_rotations": base_pose_rotations.duplicate(true),
		"max_fallback_ray_distance_meters": SURFACE_GRASP_BAND_RADIUS_METERS,
		"require_transient_path_safety": false,
	}
	var prepared_surface: Dictionary = surface_grasp_solver.call(
		"prepare_surface",
		exact_mesh,
		collision_shape.global_transform,
		solver_options
	) as Dictionary
	if not bool(prepared_surface.get("valid", false)):
		state = _record_failed_surface_grasp_candidate(
			skeleton,
			slot_id,
			state,
			context_key,
			prepared_surface.get("status", &"surface_prepare_failed") as StringName,
			prepared_surface.duplicate(true),
			rejected_attempt_restore_rotations,
			expected_bone_count,
			has_committed_grasp
		)
		surface_grasp_state_lookup[execution_path_id] = state
		_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)
		return
	var side_rules: Dictionary = PlayerDigitHingeRulesScript.get_surface_solver_side_rules(
		slot_id
	)
	var solve_started_usec: int = Time.get_ticks_usec()
	var solve_result: Dictionary = surface_grasp_solver.call(
		"solve_prepared",
		skeleton,
		prepared_surface,
		slot_id,
		side_rules,
		solver_options
	) as Dictionary
	var solve_elapsed_msec: float = float(
		Time.get_ticks_usec() - solve_started_usec
	) / 1000.0
	var diagnostics: Dictionary = (
		solve_result.get("diagnostics", {}) as Dictionary
	).duplicate(true)
	diagnostics["solve_time_msec"] = solve_elapsed_msec
	diagnostics["context_key"] = context_key
	diagnostics["grip_execution_path_id"] = execution_path_id
	diagnostics["contact_readiness"] = contact_readiness
	diagnostics["surface_authority"] = PrimaryGripHandleMeshPacketScript.SOURCE
	diagnostics["surface_origin_id"] = exact_surface.get(
		"contact_surface_origin_id",
		StringName()
	)
	diagnostics["grip_center_world"] = grip_center_world
	diagnostics["grip_guide_world_at_solve"] = grip_guide.global_position
	diagnostics["grip_guide_local_at_solve"] = grip_guide.position
	diagnostics["exact_surface_transform_origin_world"] = collision_shape.global_position
	diagnostics["bone_root_origin_id"] = PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID
	var solved_rotations: Dictionary = _sanitize_surface_grasp_rotations(
		slot_id,
		solve_result.get("rotations", {}) as Dictionary
	)
	var solved_zero_rotations: Dictionary = _sanitize_surface_grasp_rotations(
		slot_id,
		solve_result.get("zero_rotations", {}) as Dictionary
	)
	diagnostics["zero_rotation_count"] = solved_zero_rotations.size()
	var safe_to_apply: bool = (
		bool(solve_result.get("valid", false))
		and bool(solve_result.get("safe_to_apply", false))
		# The solver's per-section verdict is the penetration authority. Its raw
		# aggregate maximum may now come from thumb section 1's explicit 5 mm cap;
		# comparing that value to the ordinary 0.5 mm digit cap would reject an
		# otherwise verified result after the solve completed successfully.
		and bool(diagnostics.get("overlap_limit_respected", false))
		and solved_rotations.size() == expected_bone_count
	)
	state["solve_count"] = int(state.get("solve_count", 0)) + 1
	state["cache_miss_count"] = int(state.get("cache_miss_count", 0)) + 1
	state["last_contact_readiness"] = contact_readiness
	if safe_to_apply:
		state["context_key"] = context_key
		state["pending_context_key"] = ""
		state["force_surface_resolve"] = false
		state["diagnostics"] = diagnostics
		state["valid"] = true
		state["status"] = diagnostics.get("status", &"solved")
		state["rotations"] = solved_rotations
		if solved_zero_rotations.size() == expected_bone_count:
			var zero_packet_signature: String = (
				_build_surface_grasp_zero_rotation_packet_signature(
					slot_id,
					context_key,
					solved_zero_rotations
				)
			)
			if not zero_packet_signature.is_empty():
				state["zero_rotations"] = solved_zero_rotations
				state["zero_rotation_context_key"] = context_key
				state["zero_rotation_packet_signature"] = zero_packet_signature
			else:
				_clear_surface_grasp_zero_packet(state)
		else:
			# Debug reference data is ancillary. Never reject an otherwise safe
			# exact grip, but also never retain an old zero packet beside a newly
			# committed rotation packet.
			_clear_surface_grasp_zero_packet(state)
		state["last_attempt_status"] = state["status"]
		state["last_attempt_diagnostics"] = diagnostics.duplicate(true)
		state["last_attempt_safe_to_apply"] = true
		_apply_surface_grasp_rotations(skeleton, slot_id, solved_rotations)
	else:
		state = _record_failed_surface_grasp_candidate(
			skeleton,
			slot_id,
			state,
			context_key,
			&"surface_solve_rejected",
			diagnostics,
			rejected_attempt_restore_rotations,
			expected_bone_count,
			has_committed_grasp
		)
	surface_grasp_state_lookup[execution_path_id] = state
	_publish_surface_grasp_diagnostics(grip_guide, grip_center_node, state)


func _resolve_exact_handle_surface_identity_state(
	grip_center_node: Node3D,
	execution_path_id: StringName
) -> Dictionary:
	var invalid := {
		"valid": false,
		"status": &"invalid_exact_handle_surface",
	}
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		invalid["status"] = &"missing_grip_center"
		return invalid
	if (
		not bool(grip_center_node.get_meta("grip_shell_exact_surface", false))
		or StringName(grip_center_node.get_meta(
			"grip_shell_surface_authority",
			StringName()
		)) != PrimaryGripHandleMeshPacketScript.SOURCE
	):
		invalid["status"] = &"exact_surface_authority_missing"
		return invalid
	var guide_node: Node = grip_center_node.get_parent()
	var expected_guide_role: StringName = StringName()
	var expected_surface_origin_id: StringName = StringName()
	match execution_path_id:
		GRIP_PATH_RIGHT_PRIMARY, GRIP_PATH_LEFT_PRIMARY:
			expected_guide_role = &"PrimaryGripGuide"
			expected_surface_origin_id = (
				CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE
			)
		GRIP_PATH_RIGHT_SUPPORT, GRIP_PATH_LEFT_SUPPORT:
			expected_guide_role = &"SecondaryGripGuide"
			expected_surface_origin_id = (
				CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_CONTACT_SURFACE
			)
		_:
			invalid["status"] = &"exact_surface_execution_path_invalid"
			return invalid
	if guide_node == null or StringName(guide_node.name) != expected_guide_role:
		invalid["status"] = &"exact_surface_execution_path_guide_mismatch"
		return invalid
	var center_body_signature: String = String(grip_center_node.get_meta(
		"grip_shell_handle_body_signature",
		""
	))
	if (
		center_body_signature.is_empty()
		or StringName(grip_center_node.get_meta(
			"grip_shell_surface_local_origin_id",
			StringName()
		)) != expected_surface_origin_id
	):
		invalid["status"] = &"exact_surface_center_contract_invalid"
		return invalid
	var grip_area: Area3D = grip_center_node.get_node_or_null(
		"GripContactArea"
	) as Area3D
	if grip_area == null or not is_instance_valid(grip_area):
		invalid["status"] = &"exact_surface_area_missing"
		return invalid
	var source_vertices_origin_id: StringName = StringName(grip_area.get_meta(
		"grip_contact_source_vertices_origin_id",
		StringName()
	))
	var grip_center_origin_id: StringName = StringName(grip_area.get_meta(
		"grip_contact_grip_center_origin_id",
		StringName()
	))
	if (
		StringName(grip_area.get_meta(
			"grip_contact_surface_authority",
			StringName()
		)) != PrimaryGripHandleMeshPacketScript.SOURCE
		or String(grip_area.get_meta("grip_contact_handle_body_signature", ""))
			!= center_body_signature
		or not bool(grip_area.get_meta("grip_contact_handle_only", false))
		or source_vertices_origin_id != PrimaryGripHandleMeshPacketScript.VERTICES_ORIGIN_ID
		or grip_center_origin_id != source_vertices_origin_id
		or StringName(grip_area.get_meta(
			"grip_contact_faces_local_origin_id",
			StringName()
		)) != expected_surface_origin_id
	):
		invalid["status"] = &"exact_surface_area_contract_invalid"
		return invalid
	var collision_shapes: Array[CollisionShape3D] = []
	for child_node: Node in grip_area.get_children():
		var candidate_shape: CollisionShape3D = child_node as CollisionShape3D
		if candidate_shape != null:
			collision_shapes.append(candidate_shape)
	if collision_shapes.size() != 1:
		invalid["status"] = &"exact_surface_shape_count_invalid"
		invalid["shape_count"] = collision_shapes.size()
		return invalid
	var collision_shape: CollisionShape3D = collision_shapes[0]
	var exact_shape: ConcavePolygonShape3D = collision_shape.shape as ConcavePolygonShape3D
	if (
		String(collision_shape.name) != "ExactProtectedHandleMeshShape"
		or exact_shape == null
		or StringName(collision_shape.get_meta(
			"grip_contact_surface_authority",
			StringName()
		)) != PrimaryGripHandleMeshPacketScript.SOURCE
		or String(collision_shape.get_meta(
			"grip_contact_handle_body_signature",
			""
		)) != center_body_signature
		or StringName(collision_shape.get_meta(
			"grip_contact_source_vertices_origin_id",
			StringName()
		)) != source_vertices_origin_id
		or StringName(collision_shape.get_meta(
			"grip_contact_grip_center_origin_id",
			StringName()
		)) != grip_center_origin_id
		or StringName(collision_shape.get_meta(
			"grip_contact_faces_local_origin_id",
			StringName()
		)) != expected_surface_origin_id
	):
		invalid["status"] = &"exact_surface_shape_contract_invalid"
		return invalid
	return {
		"valid": true,
		"status": &"exact_handle_surface_identity_ready",
		"area": grip_area,
		"collision_shape": collision_shape,
		"shape_resource": exact_shape,
		"shape_resource_instance_id": exact_shape.get_instance_id(),
		"body_signature": center_body_signature,
		"source_vertices_origin_id": source_vertices_origin_id,
		"grip_center_origin_id": grip_center_origin_id,
		"contact_surface_origin_id": expected_surface_origin_id,
	}


func _resolve_exact_handle_surface_faces(
	exact_surface_identity: Dictionary
) -> Dictionary:
	if not bool(exact_surface_identity.get("valid", false)):
		return exact_surface_identity.duplicate(true)
	var exact_shape: ConcavePolygonShape3D = exact_surface_identity.get(
		"shape_resource",
		null
	) as ConcavePolygonShape3D
	if exact_shape == null or not is_instance_valid(exact_shape):
		return {
			"valid": false,
			"status": &"exact_surface_shape_resource_missing",
		}
	var faces_local: PackedVector3Array = exact_shape.get_faces()
	if faces_local.size() < 3 or faces_local.size() % 3 != 0:
		return {
			"valid": false,
			"status": &"exact_surface_faces_missing",
		}
	var resolved: Dictionary = exact_surface_identity.duplicate(false)
	resolved.erase("shape_resource")
	resolved["status"] = &"exact_handle_surface_ready"
	resolved["faces_local"] = faces_local
	return resolved


func _build_exact_surface_array_mesh(
	faces_local: PackedVector3Array
) -> ArrayMesh:
	if faces_local.size() < 3 or faces_local.size() % 3 != 0:
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces_local
	var exact_mesh := ArrayMesh.new()
	exact_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return exact_mesh


func _surface_solver_rules_have_valid_origins(
	skeleton: Skeleton3D,
	slot_id: StringName
) -> bool:
	for digit_id: StringName in FINGER_IDS:
		var chain_rules: Array[Dictionary] = PlayerDigitHingeRulesScript.get_chain_rules(
			slot_id,
			digit_id
		)
		if chain_rules.size() != 3:
			return false
		for rule: Dictionary in chain_rules:
			if not PlayerDigitHingeRulesScript.rule_has_valid_origin_chain(
				rule,
				skeleton
			):
				return false
	return true


func _capture_surface_grasp_base_rotations(
	skeleton: Skeleton3D,
	slot_id: StringName
) -> Dictionary:
	var rotations: Dictionary = {}
	for bone_name: StringName in PlayerDigitHingeRulesScript.get_finger_bone_names(
		slot_id
	):
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			rotations[bone_name] = skeleton.get_bone_pose_rotation(
				bone_index
			).normalized()
	return rotations


func _sanitize_surface_grasp_rotations(
	slot_id: StringName,
	rotations: Dictionary
) -> Dictionary:
	var sanitized: Dictionary = {}
	for bone_name: StringName in PlayerDigitHingeRulesScript.get_finger_bone_names(
		slot_id
	):
		var rotation_variant: Variant = rotations.get(bone_name, null)
		if rotation_variant is Quaternion:
			sanitized[bone_name] = (rotation_variant as Quaternion).normalized()
	return sanitized


func _build_surface_grasp_zero_rotation_packet_signature(
	slot_id: StringName,
	context_key: String,
	zero_rotations: Dictionary
) -> String:
	var ordered_bone_names: Array[StringName] = (
		PlayerDigitHingeRulesScript.get_finger_bone_names(slot_id)
	)
	if (
		context_key.is_empty()
		or ordered_bone_names.size() != 15
		or zero_rotations.size() != ordered_bone_names.size()
	):
		return ""
	var ordered_packet: Array = [
		String(PlayerFingerSurfaceGripSolverScript.SOLVER_REVISION),
		String(PlayerDigitHingeRulesScript.get_revision()),
		String(slot_id),
		context_key,
	]
	for bone_name: StringName in ordered_bone_names:
		var rotation_variant: Variant = zero_rotations.get(bone_name, null)
		if not rotation_variant is Quaternion:
			return ""
		var rotation: Quaternion = (rotation_variant as Quaternion).normalized()
		if (
			not is_finite(rotation.x)
			or not is_finite(rotation.y)
			or not is_finite(rotation.z)
			or not is_finite(rotation.w)
		):
			return ""
		ordered_packet.append(String(bone_name))
		ordered_packet.append([
			rotation.x,
			rotation.y,
			rotation.z,
			rotation.w,
		])
	return str(hash(ordered_packet))


func _clear_surface_grasp_zero_packet(state: Dictionary) -> void:
	state["zero_rotations"] = {}
	state.erase("zero_rotation_context_key")
	state.erase("zero_rotation_packet_signature")


func _apply_surface_grasp_rotations(
	skeleton: Skeleton3D,
	slot_id: StringName,
	rotations: Dictionary
) -> bool:
	var wrote_pose := false
	for bone_name: StringName in PlayerDigitHingeRulesScript.get_finger_bone_names(
		slot_id
	):
		var rotation_variant: Variant = rotations.get(bone_name, null)
		if not rotation_variant is Quaternion:
			continue
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		skeleton.set_bone_pose_rotation(
			bone_index,
			(rotation_variant as Quaternion).normalized()
		)
		wrote_pose = true
	if wrote_pose:
		skeleton.force_update_all_bone_transforms()
	return wrote_pose


func _record_failed_surface_grasp_candidate(
	skeleton: Skeleton3D,
	slot_id: StringName,
	state: Dictionary,
	context_key: String,
	attempt_status: StringName,
	attempt_diagnostics: Dictionary,
	restore_rotations: Dictionary,
	expected_bone_count: int,
	preserve_committed_grasp: bool
) -> Dictionary:
	var recorded_diagnostics: Dictionary = attempt_diagnostics.duplicate(true)
	recorded_diagnostics["context_key"] = context_key
	recorded_diagnostics["candidate_status"] = attempt_status
	state["last_attempt_context_key"] = context_key
	state["last_attempt_status"] = attempt_status
	state["last_attempt_diagnostics"] = recorded_diagnostics
	state["last_attempt_safe_to_apply"] = false
	state["last_rejected_context_key"] = context_key
	state["last_rejected_status"] = attempt_status
	state["last_rejected_diagnostics"] = recorded_diagnostics.duplicate(true)
	state["pending_context_key"] = ""
	if restore_rotations.size() == expected_bone_count:
		_apply_surface_grasp_rotations(skeleton, slot_id, restore_rotations)
	if preserve_committed_grasp:
		# The active cache is a committed local hand/Handle relationship. Candidate
		# work is allowed to replace it only after all safety gates accept the new
		# 15-bone result.
		state["retained_committed_after_rejection_count"] = int(
			state.get("retained_committed_after_rejection_count", 0)
		) + 1
		return state
	state["valid"] = false
	state["status"] = attempt_status
	state["context_key"] = context_key
	state["diagnostics"] = recorded_diagnostics
	state["rotations"] = {}
	_clear_surface_grasp_zero_packet(state)
	return state


func _build_surface_grasp_context_key(
	skeleton: Skeleton3D,
	slot_id: StringName,
	grip_guide: Node3D,
	grip_center_node: Node3D,
	exact_surface: Dictionary,
	execution_path_id: StringName
) -> String:
	if skeleton == null or grip_guide == null or grip_center_node == null:
		return ""
	if _resolve_grip_execution_path_id(slot_id, grip_guide) != execution_path_id:
		return ""
	var held_item: Node3D = grip_guide.get_parent() as Node3D
	if held_item == null:
		return ""
	var guide_position_origin_id: StringName = StringName(grip_guide.get_meta(
		"grip_guide_position_origin_id",
		grip_guide.get_meta(
			"dominant_hand_position_origin_id",
			grip_guide.get_meta(
				"support_hand_position_origin_id",
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
		)
	))
	if guide_position_origin_id == StringName():
		return ""
	var guide_position_variant: Variant = grip_guide.get_meta(
		"grip_guide_position_local",
		grip_guide.position
	)
	if not guide_position_variant is Vector3:
		return ""
	var guide_position_local: Vector3 = guide_position_variant as Vector3
	var guide_role: StringName = StringName(grip_guide.name)
	if guide_role != &"PrimaryGripGuide" and guide_role != &"SecondaryGripGuide":
		return ""
	var source_wip_id: StringName = StringName(held_item.get_meta(
		"source_wip_id",
		StringName()
	))
	var grip_style_mode: StringName = StringName(held_item.get_meta(
		"grip_style_mode",
		StringName()
	))
	var dominant_slot_id: StringName = StringName(held_item.get_meta(
		"dominant_contact_slot_id",
		StringName()
	))
	var hand_surface_relationship: Array = (
		_resolve_surface_grasp_hand_relationship_signature(
			skeleton,
			slot_id,
			exact_surface
		)
	)
	if hand_surface_relationship.is_empty():
		return ""
	return str(hash([
		PlayerDigitHingeRulesScript.get_revision(),
		String(execution_path_id),
		String(slot_id),
		String(guide_role),
		String(source_wip_id),
		exact_surface.get("body_signature", ""),
		exact_surface.get("contact_surface_origin_id", StringName()),
		int(exact_surface.get("shape_resource_instance_id", 0)),
		String(guide_position_origin_id),
		_quantize_surface_grasp_vector(guide_position_local),
		String(grip_style_mode),
		String(dominant_slot_id),
		hand_surface_relationship,
	]))


func _resolve_surface_grasp_hand_relationship_signature(
	skeleton: Skeleton3D,
	slot_id: StringName,
	exact_surface: Dictionary
) -> Array:
	if skeleton == null or not bool(exact_surface.get("valid", false)):
		return []
	var side_rules: Dictionary = PlayerDigitHingeRulesScript.get_surface_solver_side_rules(
		slot_id
	)
	var hand_bone_name: StringName = side_rules.get(
		"hand_bone_name",
		StringName()
	) as StringName
	var hand_root_origin_id: StringName = side_rules.get(
		"hand_bone_root_origin_id",
		StringName()
	) as StringName
	var contact_surface_origin_id: StringName = exact_surface.get(
		"contact_surface_origin_id",
		StringName()
	) as StringName
	var collision_shape: CollisionShape3D = exact_surface.get(
		"collision_shape",
		null
	) as CollisionShape3D
	var hand_bone_index: int = skeleton.find_bone(String(hand_bone_name))
	if (
		hand_bone_name == StringName()
		or hand_root_origin_id != PlayerDigitHingeRulesScript.ROOT_ORIGIN_ID
		or contact_surface_origin_id == StringName()
		or collision_shape == null
		or not is_instance_valid(collision_shape)
		or hand_bone_index < 0
	):
		return []
	var hand_world: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(hand_bone_index)
	)
	var hand_in_contact_surface: Transform3D = (
		collision_shape.global_transform.affine_inverse() * hand_world
	)
	if not _transform_is_finite(hand_in_contact_surface):
		return []
	return [
		String(hand_bone_name),
		String(hand_root_origin_id),
		String(contact_surface_origin_id),
		_quantize_surface_grasp_vector(hand_in_contact_surface.origin),
		_quantize_surface_grasp_basis(
			hand_in_contact_surface.basis.orthonormalized()
		),
	]


func _quantize_surface_grasp_vector(
	value: Vector3,
	step: float = SURFACE_GRASP_POSITION_SIGNATURE_STEP_METERS
) -> PackedInt64Array:
	var resolved_step: float = maxf(step, 0.0000001)
	return PackedInt64Array([
		roundi(value.x / resolved_step),
		roundi(value.y / resolved_step),
		roundi(value.z / resolved_step),
	])


func _quantize_surface_grasp_basis(value: Basis) -> PackedInt64Array:
	var resolved_step: float = maxf(
		SURFACE_GRASP_BASIS_SIGNATURE_STEP,
		0.0000001
	)
	return PackedInt64Array([
		roundi(value.x.x / resolved_step),
		roundi(value.x.y / resolved_step),
		roundi(value.x.z / resolved_step),
		roundi(value.y.x / resolved_step),
		roundi(value.y.y / resolved_step),
		roundi(value.y.z / resolved_step),
		roundi(value.z.x / resolved_step),
		roundi(value.z.y / resolved_step),
		roundi(value.z.z / resolved_step),
	])


func _basis_is_finite(value: Basis) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()


func _transform_is_finite(value: Transform3D) -> bool:
	return _basis_is_finite(value.basis) and value.origin.is_finite()


func _sync_finger_targets_to_current_pose(
	skeleton: Skeleton3D,
	slot_id: StringName,
	side_targets: Dictionary
) -> void:
	var side_chains: Dictionary = FINGER_CHAINS.get(slot_id, {}) as Dictionary
	for finger_id: StringName in FINGER_IDS:
		var target_node: Node3D = side_targets.get(finger_id) as Node3D
		if target_node == null:
			continue
		target_node.global_position = _get_current_chain_end_world_position(
			skeleton,
			side_chains.get(finger_id, {}) as Dictionary
		)


func _publish_surface_grasp_diagnostics(
	grip_guide: Node3D,
	grip_center_node: Node3D,
	state: Dictionary
) -> void:
	for target_node: Node3D in [grip_guide, grip_center_node]:
		if target_node == null or not is_instance_valid(target_node):
			continue
		target_node.set_meta(
			SURFACE_GRASP_DIAGNOSTICS_META,
			(state.get("diagnostics", {}) as Dictionary).duplicate(true)
		)
		target_node.set_meta(
			SURFACE_GRASP_CONTEXT_META,
			String(state.get("context_key", state.get("pending_context_key", "")))
		)

func _resolve_roll_decoupled_contact_axes(
	skeleton: Skeleton3D,
	slot_id: StringName,
	major_axis_world: Vector3,
	fallback_minor_axis_a_world: Vector3,
	fallback_minor_axis_b_world: Vector3
) -> Dictionary:
	var major_axis: Vector3 = major_axis_world.normalized()
	if major_axis.length_squared() <= 0.000001:
		return {
			"minor_axis_a_world": fallback_minor_axis_a_world,
			"minor_axis_b_world": fallback_minor_axis_b_world,
		}
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name)) if skeleton != null else -1
	var preferred_up: Vector3 = fallback_minor_axis_b_world
	if hand_index >= 0:
		var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
		preferred_up = (skeleton.global_basis * hand_pose.basis).orthonormalized().y
	preferred_up = preferred_up - major_axis * preferred_up.dot(major_axis)
	if preferred_up.length_squared() <= 0.000001:
		preferred_up = fallback_minor_axis_b_world - major_axis * fallback_minor_axis_b_world.dot(major_axis)
	if preferred_up.length_squared() <= 0.000001:
		preferred_up = Vector3.UP - major_axis * Vector3.UP.dot(major_axis)
	if preferred_up.length_squared() <= 0.000001:
		preferred_up = Vector3.RIGHT - major_axis * Vector3.RIGHT.dot(major_axis)
	preferred_up = preferred_up.normalized()
	var minor_axis_a: Vector3 = preferred_up.cross(major_axis).normalized()
	if minor_axis_a.length_squared() <= 0.000001:
		minor_axis_a = fallback_minor_axis_a_world.normalized()
	var minor_axis_b: Vector3 = major_axis.cross(minor_axis_a).normalized()
	if minor_axis_b.length_squared() <= 0.000001:
		minor_axis_b = preferred_up
	return {
		"minor_axis_a_world": minor_axis_a,
		"minor_axis_b_world": minor_axis_b,
	}

func refresh_finger_ik_influences(
	_enable_finger_grip_ik: bool,
	_finger_grip_ik_influence: float,
	modifier_lookup: Dictionary,
	_source_lookup: Dictionary
) -> void:
	# Finger contact is authored by the deterministic open-to-contact curl pass.
	# CCDIK nodes stay inactive so they cannot add unconstrained finger twist.
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		for finger_id: StringName in FINGER_IDS:
			var modifier: SkeletonModifier3D = modifier_lookup.get(
				StringName("%s_%s" % [String(slot_id), String(finger_id)]),
				null
			) as SkeletonModifier3D
			if modifier == null:
				continue
			var needs_reset: bool = modifier.active or modifier.influence > 0.0
			modifier.active = false
			modifier.influence = 0.0
			if needs_reset and modifier.has_method("reset"):
				modifier.call("reset")

func resolve_hand_grip_alignment_world_position(skeleton: Skeleton3D, slot_id: StringName) -> Vector3:
	if skeleton == null:
		return Vector3.ZERO
	_ensure_animation_grip_baseline_cache()
	return _resolve_hand_grip_center_world_from_cache(skeleton, animation_grip_baseline_cache, slot_id)

func _ensure_named_child_node(parent_node: Node3D, child_name: String) -> Node3D:
	var child_node: Node3D = parent_node.get_node_or_null(child_name) as Node3D
	if child_node == null:
		child_node = Node3D.new()
		child_node.name = child_name
		parent_node.add_child(child_node)
	return child_node

func _ensure_finger_ik_modifier(
	skeleton: Skeleton3D,
	modifier_name: String,
	root_bone_name: StringName,
	end_bone_name: StringName,
	target_node: Node3D
) -> CCDIK3D:
	var modifier: CCDIK3D = skeleton.get_node_or_null(modifier_name) as CCDIK3D
	if modifier == null:
		modifier = CCDIK3D.new()
		modifier.name = modifier_name
		skeleton.add_child(modifier)
	modifier.setting_count = 1
	modifier.mutable_bone_axes = true
	modifier.deterministic = true
	modifier.max_iterations = 6
	modifier.min_distance = 0.0015
	modifier.angular_delta_limit = deg_to_rad(12.0)
	var root_bone_index: int = skeleton.find_bone(String(root_bone_name))
	var end_bone_index: int = skeleton.find_bone(String(end_bone_name))
	if root_bone_index >= 0:
		modifier.set_root_bone(0, root_bone_index)
	modifier.set_root_bone_name(0, String(root_bone_name))
	if end_bone_index >= 0:
		modifier.set_end_bone(0, end_bone_index)
	modifier.set_end_bone_name(0, String(end_bone_name))
	if target_node != null:
		modifier.set_target_node(0, modifier.get_path_to(target_node))
	modifier.active = false
	modifier.influence = 0.0
	return modifier

func _resolve_grip_center_node(grip_guide: Node3D) -> Node3D:
	if grip_guide == null:
		return null
	var grip_center_node: Node3D = grip_guide.get_node_or_null("GripShellCenter") as Node3D
	return grip_center_node if grip_center_node != null else grip_guide

func _resolve_grip_shell_axis_local(
	grip_center_node: Node3D,
	value_meta_name: StringName,
	origin_meta_name: StringName,
	fallback_value: Vector3
) -> Vector3:
	var resolved_origin_id: StringName = _resolve_origin_meta_value(
		grip_center_node,
		origin_meta_name,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var resolved_axis_vector: Vector3 = _get_origin_tracked_vector3_meta(
		grip_center_node,
		value_meta_name,
		origin_meta_name,
		fallback_value,
		resolved_origin_id
	)
	if resolved_axis_vector.length_squared() > 0.000001:
		return resolved_axis_vector
	return fallback_value

func _resolve_origin_meta_value(target: Object, origin_meta_name: StringName, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = fallback_origin_id
	if resolved_origin_id == StringName():
		resolved_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	if target == null:
		return resolved_origin_id
	var stored_origin_id: StringName = StringName(target.get_meta(origin_meta_name, StringName()))
	if stored_origin_id != StringName():
		return stored_origin_id
	target.set_meta(origin_meta_name, resolved_origin_id)
	return resolved_origin_id

func _get_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: StringName,
	origin_meta_name: StringName,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_meta_value(target, origin_meta_name, fallback_origin_id)
	if target == null:
		return fallback_value
	var stored_value: Variant = target.get_meta(value_meta_name, fallback_value)
	if stored_value is Vector3:
		return stored_value as Vector3
	target.set_meta(value_meta_name, fallback_value)
	return fallback_value

func _build_palm_frame(
	slot_id: StringName,
	get_bone_world_position_callable: Callable,
	shell_center_world: Vector3,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3
) -> Dictionary:
	var bone_names: Dictionary = PALM_TRIANGULATION_BONES.get(slot_id, {})
	if bone_names.is_empty():
		return {}
	var hand_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("hand", StringName()))
	var thumb2_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("thumb2", StringName()))
	var index1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("index1", StringName()))
	var mid1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("mid1", StringName()))
	var mid2_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("mid2", StringName()))
	var ring1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("ring1", StringName()))
	var pinky1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("pinky1", StringName()))
	var center_world: Vector3 = (
		hand_world
		+ thumb2_world
		+ index1_world
		+ mid1_world
		+ ring1_world
		+ pinky1_world
	) / 6.0
	var knuckle_span_world: Vector3 = pinky1_world - index1_world
	var thumb_span_world: Vector3 = thumb2_world - hand_world
	var palm_normal_world: Vector3 = (index1_world - hand_world).cross(pinky1_world - hand_world)
	if palm_normal_world.length_squared() <= 0.000001:
		palm_normal_world = (mid1_world - hand_world).cross(ring1_world - hand_world)
	if palm_normal_world.length_squared() <= 0.000001:
		palm_normal_world = major_axis_world.cross(knuckle_span_world)
	if palm_normal_world.length_squared() <= 0.000001:
		palm_normal_world = minor_axis_a_world.cross(minor_axis_b_world)
	palm_normal_world = palm_normal_world.normalized()
	var shell_to_palm: Vector3 = center_world - shell_center_world
	if palm_normal_world.dot(shell_to_palm) < 0.0:
		palm_normal_world = -palm_normal_world
	if knuckle_span_world.length_squared() <= 0.000001:
		knuckle_span_world = minor_axis_a_world
	return {
		"center_world": center_world,
		"hand_world": hand_world,
		"thumb2_world": thumb2_world,
		"index1_world": index1_world,
		"mid1_world": mid1_world,
		"mid2_world": mid2_world,
		"ring1_world": ring1_world,
		"pinky1_world": pinky1_world,
		"thumb_close_world": mid2_world - thumb2_world,
		"knuckle_span_world": knuckle_span_world.normalized(),
		"thumb_span_world": thumb_span_world.normalized() if thumb_span_world.length_squared() > 0.000001 else minor_axis_a_world,
		"palm_normal_world": palm_normal_world,
	}

func _resolve_finger_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	palm_frame: Dictionary,
	center_world: Vector3,
	profile_offsets: Array,
	cell_world_size: float,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	get_bone_world_position_callable: Callable
) -> Vector3:
	var guide_bone_name: StringName = chain_def.get("guide", chain_def.get("root", StringName()))
	var end_bone_name: StringName = chain_def.get("end", guide_bone_name)
	var guide_position: Vector3 = get_bone_world_position_callable.call(guide_bone_name)
	var end_position: Vector3 = get_bone_world_position_callable.call(end_bone_name)
	var palm_center_world: Vector3 = palm_frame.get("center_world", guide_position)
	var palm_shell_vector: Vector3 = center_world - palm_center_world
	if finger_id == &"thumb":
		return _resolve_thumb_target_world_position(
			skeleton,
			slot_id,
			finger_id,
			chain_def,
			grip_center_node,
			palm_frame,
			center_world,
			profile_offsets,
			cell_world_size,
			major_axis_world,
			minor_axis_a_world,
			minor_axis_b_world,
			get_bone_world_position_callable
		)
	return _resolve_non_thumb_target_world_position(
		skeleton,
		slot_id,
		finger_id,
		chain_def,
		grip_center_node,
		palm_frame,
		center_world,
		palm_center_world,
		guide_position,
		end_position,
		profile_offsets,
		cell_world_size,
		major_axis_world,
		minor_axis_a_world,
		minor_axis_b_world,
		palm_shell_vector,
		get_bone_world_position_callable
	)

func _resolve_non_thumb_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	palm_frame: Dictionary,
	center_world: Vector3,
	palm_center_world: Vector3,
	guide_position: Vector3,
	end_position: Vector3,
	profile_offsets: Array,
	cell_world_size: float,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	palm_shell_vector: Vector3,
	get_bone_world_position_callable: Callable
) -> Vector3:
	var mid_bone_name: StringName = chain_def.get("mid", chain_def.get("guide", chain_def.get("root", StringName())))
	var mid_position: Vector3 = get_bone_world_position_callable.call(mid_bone_name)
	var lane_vector: Vector3 = guide_position - palm_center_world
	lane_vector -= major_axis_world * lane_vector.dot(major_axis_world)
	if lane_vector.length_squared() <= 0.000001:
		lane_vector = palm_frame.get("knuckle_span_world", minor_axis_a_world)
	var palm_normal_world: Vector3 = palm_frame.get("palm_normal_world", Vector3.ZERO)
	var curl_direction_world: Vector3 = -palm_normal_world
	if curl_direction_world.length_squared() <= 0.000001:
		curl_direction_world = (center_world - guide_position).normalized()
	if curl_direction_world.length_squared() <= 0.000001:
		curl_direction_world = -minor_axis_b_world
	var approach_vector: Vector3 = center_world - guide_position
	var major_offset: float = clampf(
		approach_vector.dot(major_axis_world),
		-cell_world_size * 0.4,
		cell_world_size * 0.4
	)
	var lane_2d: Vector2 = Vector2(
		lane_vector.dot(minor_axis_a_world),
		lane_vector.dot(minor_axis_b_world)
	)
	if lane_2d.length_squared() <= 0.000001:
		lane_2d = Vector2.RIGHT
	var radial_direction_2d: Vector2 = lane_2d.normalized()
	var support_point_2d: Vector2 = _resolve_profile_support_point(profile_offsets, radial_direction_2d, cell_world_size)
	var radial_offset_world: Vector3 = (
		minor_axis_a_world * support_point_2d.x
		+ minor_axis_b_world * support_point_2d.y
	)
	var closure_vector: Vector3 = curl_direction_world
	var mid_alignment_vector: Vector3 = end_position - mid_position
	if mid_alignment_vector.length_squared() > 0.000001:
		var blended_alignment: Vector3 = (curl_direction_world.normalized() * 0.8) + (mid_alignment_vector.normalized() * 0.2)
		if blended_alignment.length_squared() > 0.000001:
			closure_vector = blended_alignment.normalized()
	if closure_vector.length_squared() <= 0.000001:
		closure_vector = palm_shell_vector if palm_shell_vector.length_squared() > 0.000001 else lane_vector
	var radial_clearance: float = cell_world_size * 0.08
	var radial_clearance_world: Vector3 = closure_vector.normalized() * radial_clearance
	var predicted_target: Vector3 = center_world \
		+ major_axis_world * major_offset \
		+ radial_offset_world \
		+ radial_clearance_world
	var cast_from_world: Vector3 = end_position
	var baseline_tip_world: Vector3 = _resolve_animation_baseline_tip_world_position(skeleton, slot_id, finger_id)
	if baseline_tip_world.length_squared() > 0.000001:
		cast_from_world = baseline_tip_world
		predicted_target = baseline_tip_world.lerp(predicted_target, 0.42)
	return _resolve_contact_target_world_position(
		grip_center_node,
		cast_from_world,
		predicted_target,
		cell_world_size,
		closure_vector,
		slot_id,
		finger_id,
		&"surface_contact"
	)

func _resolve_thumb_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	palm_frame: Dictionary,
	center_world: Vector3,
	profile_offsets: Array,
	cell_world_size: float,
	major_axis_world: Vector3,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	get_bone_world_position_callable: Callable
) -> Vector3:
	var thumb_guide_name: StringName = chain_def.get("guide", chain_def.get("root", StringName()))
	var thumb_end_name: StringName = chain_def.get("end", thumb_guide_name)
	var thumb_guide_position: Vector3 = get_bone_world_position_callable.call(thumb_guide_name)
	var thumb_end_position: Vector3 = get_bone_world_position_callable.call(thumb_end_name)
	var mid2_position: Vector3 = palm_frame.get("mid2_world", thumb_guide_position)
	var pinky1_position: Vector3 = palm_frame.get("pinky1_world", thumb_guide_position)
	var open_vector: Vector3 = thumb_guide_position - pinky1_position
	var close_vector: Vector3 = mid2_position - thumb_guide_position
	open_vector -= major_axis_world * open_vector.dot(major_axis_world)
	close_vector -= major_axis_world * close_vector.dot(major_axis_world)
	if open_vector.length_squared() <= 0.000001:
		open_vector = _resolve_fallback_radial_world(minor_axis_a_world, minor_axis_b_world, &"thumb")
	if close_vector.length_squared() <= 0.000001:
		close_vector = palm_frame.get("thumb_close_world", minor_axis_a_world)
	var desired_thumb_plane_vector: Vector3 = (close_vector.normalized() * 0.82) + (open_vector.normalized() * 0.28)
	if desired_thumb_plane_vector.length_squared() <= 0.000001:
		desired_thumb_plane_vector = close_vector if close_vector.length_squared() > 0.000001 else open_vector
	var dir_2d: Vector2 = Vector2(
		desired_thumb_plane_vector.dot(minor_axis_a_world),
		desired_thumb_plane_vector.dot(minor_axis_b_world)
	)
	if dir_2d.length_squared() <= 0.000001:
		dir_2d = Vector2(-1.0 if slot_id == SLOT_RIGHT else 1.0, 0.3).normalized()
	var radial_direction_2d: Vector2 = dir_2d.normalized()
	var support_point_2d: Vector2 = _resolve_profile_support_point(profile_offsets, radial_direction_2d, cell_world_size)
	var radial_offset_world: Vector3 = (
		minor_axis_a_world * support_point_2d.x
		+ minor_axis_b_world * support_point_2d.y
	)
	var approach_vector: Vector3 = center_world - thumb_guide_position
	var major_offset: float = clampf(
		approach_vector.dot(major_axis_world),
		-cell_world_size * 0.3,
		cell_world_size * 0.3
	)
	var shell_closure_vector: Vector3 = (center_world + radial_offset_world) - thumb_guide_position
	if shell_closure_vector.length_squared() <= 0.000001:
		shell_closure_vector = desired_thumb_plane_vector
	var radial_clearance_world: Vector3 = shell_closure_vector.normalized() * (cell_world_size * 0.1)
	var predicted_target: Vector3 = center_world \
		+ major_axis_world * major_offset \
		+ radial_offset_world \
		+ radial_clearance_world
	var cast_from_world: Vector3 = thumb_end_position
	var baseline_tip_world: Vector3 = _resolve_animation_baseline_tip_world_position(skeleton, slot_id, finger_id)
	if baseline_tip_world.length_squared() > 0.000001:
		cast_from_world = baseline_tip_world
		predicted_target = baseline_tip_world.lerp(predicted_target, 0.38)
	return _resolve_contact_target_world_position(
		grip_center_node,
		cast_from_world,
		predicted_target,
		cell_world_size,
		shell_closure_vector,
		slot_id,
		finger_id,
		&"thumb_contact"
	)

func _resolve_profile_support_point(profile_offsets: Array, radial_direction_2d: Vector2, cell_world_size: float) -> Vector2:
	var half_extent: float = cell_world_size * 0.5
	var best_point: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for offset_variant: Variant in profile_offsets:
		var offset: Vector2 = offset_variant as Vector2
		var candidate_point: Vector2 = Vector2(
			offset.x + (half_extent if radial_direction_2d.x >= 0.0 else -half_extent),
			offset.y + (half_extent if radial_direction_2d.y >= 0.0 else -half_extent)
		)
		var candidate_score: float = candidate_point.dot(radial_direction_2d)
		if candidate_score > best_score:
			best_score = candidate_score
			best_point = candidate_point
	return best_point

func _resolve_contact_target_world_position(
	grip_center_node: Node3D,
	cast_from_world: Vector3,
	predicted_target_world: Vector3,
	cell_world_size: float,
	preferred_direction_world: Vector3 = Vector3.ZERO,
	slot_id: StringName = StringName(),
	finger_id: StringName = StringName(),
	ray_context: StringName = &"contact_target"
) -> Vector3:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return predicted_target_world
	var world_3d: World3D = grip_center_node.get_world_3d()
	if world_3d == null:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			cast_from_world,
			predicted_target_world,
			0,
			{},
			"missing_world"
		)
		return predicted_target_world
	var direction: Vector3 = predicted_target_world - cast_from_world
	if preferred_direction_world.length_squared() > 0.000001:
		direction = preferred_direction_world.normalized() * maxf(direction.length(), cell_world_size * 3.0)
	if direction.length_squared() <= 0.000001:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			cast_from_world,
			predicted_target_world,
			0,
			{},
			"empty_direction"
		)
		return predicted_target_world
	var collision_mask: int = int(grip_center_node.get_meta("grip_shell_collision_layer", 0))
	if collision_mask <= 0:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			cast_from_world,
			predicted_target_world,
			collision_mask,
			{},
			"missing_collision_mask"
		)
		return predicted_target_world
	var ray_distance: float = maxf(direction.length() + cell_world_size * 2.0, cell_world_size * 4.0)
	var ray_to_world: Vector3 = cast_from_world + direction.normalized() * ray_distance
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		cast_from_world,
		ray_to_world,
		collision_mask
	)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = false
	ray_query.hit_from_inside = true
	var hit: Dictionary = _intersect_expected_contact_area_ray(
		world_3d,
		grip_center_node,
		ray_query
	)
	_record_contact_ray_debug(
		grip_center_node,
		slot_id,
		finger_id,
		ray_context,
		cast_from_world,
		ray_to_world,
		collision_mask,
		hit,
		"" if not hit.is_empty() else "expected_contact_area_not_hit"
	)
	if hit.is_empty():
		return predicted_target_world
	var hit_position: Vector3 = hit.get("position", predicted_target_world)
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.length_squared() <= 0.000001:
		hit_normal = -direction.normalized()
	return hit_position + hit_normal.normalized() * (cell_world_size * 0.05)

func _resolve_fallback_radial_world(minor_axis_a_world: Vector3, minor_axis_b_world: Vector3, finger_id: StringName) -> Vector3:
	if finger_id == &"thumb":
		return (-minor_axis_a_world + minor_axis_b_world * 0.2).normalized()
	if finger_id == &"pinky":
		return (minor_axis_a_world - minor_axis_b_world * 0.15).normalized()
	return minor_axis_a_world.normalized()

func _move_target_toward(target_node: Node3D, desired_global_position: Vector3, smoothing_speed: float, delta: float) -> void:
	if target_node == null:
		return
	var blend_factor: float = clampf(smoothing_speed * delta, 0.0, 1.0)
	target_node.global_position = target_node.global_position.lerp(desired_global_position, blend_factor)

func _source_is_valid(source_node_variant: Variant) -> bool:
	var source_node: Node3D = source_node_variant as Node3D
	return source_node != null and is_instance_valid(source_node)

func _resolve_grip_contact_readiness(contact_distance_meters: float, cell_world_size: float) -> float:
	var full_seat_distance: float = maxf(
		CONTACT_FULL_SEAT_MIN_METERS,
		cell_world_size * CONTACT_FULL_SEAT_CELL_MULTIPLIER
	)
	var fade_out_distance: float = maxf(
		CONTACT_FADE_OUT_MIN_METERS,
		full_seat_distance + cell_world_size * CONTACT_FADE_OUT_CELL_MULTIPLIER
	)
	if contact_distance_meters <= full_seat_distance:
		return 1.0
	if contact_distance_meters >= fade_out_distance:
		return 0.0
	var fade_t: float = clampf(
		(contact_distance_meters - full_seat_distance) / maxf(fade_out_distance - full_seat_distance, 0.000001),
		0.0,
		1.0
	)
	var smooth_fade_t: float = fade_t * fade_t * (3.0 - 2.0 * fade_t)
	return 1.0 - smooth_fade_t

func _set_source_contact_readiness(
	grip_guide: Node3D,
	grip_center_node: Node3D,
	contact_readiness: float,
	contact_distance_meters: float
) -> void:
	for source_node: Node3D in [grip_guide, grip_center_node]:
		if source_node == null or not is_instance_valid(source_node):
			continue
		source_node.set_meta(CONTACT_READINESS_META, clampf(contact_readiness, 0.0, 1.0))
		source_node.set_meta(CONTACT_DISTANCE_META, maxf(contact_distance_meters, 0.0))

func _clear_contact_ray_debug(grip_center_node: Node3D) -> void:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return
	grip_center_node.set_meta(CONTACT_RAY_DEBUG_META, [])

func _record_contact_ray_debug(
	grip_center_node: Node3D,
	slot_id: StringName,
	finger_id: StringName,
	ray_context: StringName,
	from_world: Vector3,
	to_world: Vector3,
	collision_mask: int,
	ray_hit: Dictionary = {},
	skipped_reason: String = ""
) -> void:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return
	var has_hit: bool = not ray_hit.is_empty()
	var hit_position: Vector3 = Vector3.ZERO
	var hit_normal: Vector3 = Vector3.ZERO
	var collider_object: Object = null
	if has_hit:
		hit_position = ray_hit.get("position", Vector3.ZERO) as Vector3
		hit_normal = ray_hit.get("normal", Vector3.ZERO) as Vector3
		collider_object = ray_hit.get("collider", null) as Object
	var collider_node: Node = collider_object as Node
	var collider_name: String = ""
	var collider_path: String = ""
	var collider_class: String = ""
	var collider_layer: int = -1
	if collider_object != null:
		collider_class = collider_object.get_class()
	if collider_node != null:
		collider_name = String(collider_node.name)
		collider_path = String(collider_node.get_path())
	var collision_object: CollisionObject3D = collider_node as CollisionObject3D
	if collision_object != null:
		collider_layer = collision_object.collision_layer
	var hit_distance: float = -1.0
	if has_hit:
		hit_distance = from_world.distance_to(hit_position)
	var ray_entries: Array = grip_center_node.get_meta(CONTACT_RAY_DEBUG_META, []) as Array
	ray_entries.append({
		"slot_id": String(slot_id),
		"finger_id": String(finger_id),
		"context": String(ray_context),
		"from_world": from_world,
		"to_world": to_world,
		"collision_mask": collision_mask,
		"hit": has_hit,
		"hit_position": hit_position,
		"hit_normal": hit_normal,
		"hit_distance_meters": hit_distance,
		"collider_name": collider_name,
		"collider_path": collider_path,
		"collider_class": collider_class,
		"collider_layer": collider_layer,
		"skipped_reason": skipped_reason,
	})
	while ray_entries.size() > CONTACT_RAY_DEBUG_LIMIT:
		ray_entries.pop_front()
	grip_center_node.set_meta(CONTACT_RAY_DEBUG_META, ray_entries)

func _resolve_source_contact_readiness(source_node_variant: Variant) -> float:
	if not _source_is_valid(source_node_variant):
		return 0.0
	var source_node: Node3D = source_node_variant as Node3D
	if source_node.has_meta(CONTACT_READINESS_META):
		return clampf(float(source_node.get_meta(CONTACT_READINESS_META, 1.0)), 0.0, 1.0)
	var grip_center_node: Node3D = _resolve_grip_center_node(source_node)
	if grip_center_node != null and grip_center_node.has_meta(CONTACT_READINESS_META):
		return clampf(float(grip_center_node.get_meta(CONTACT_READINESS_META, 1.0)), 0.0, 1.0)
	return 1.0

func _ensure_animation_grip_baseline_cache() -> void:
	if animation_grip_baseline_initialized:
		return
	animation_grip_baseline_initialized = true
	animation_idle_baseline_cache = _build_animation_pose_cache(
		[IDLE_BASELINE_ANIMATION_NAME],
		[IDLE_BASELINE_SAMPLE_RATIO]
	)
	animation_grip_baseline_cache = _build_animation_pose_cache(
		GRIP_BASELINE_ANIMATION_NAMES,
		GRIP_BASELINE_SAMPLE_RATIOS
	)

func _build_animation_pose_cache(animation_names: Array[StringName], sample_ratios: Array[float]) -> Dictionary:
	var baseline_cache: Dictionary = {}
	var rotation_counts: Dictionary = {}
	var tip_counts: Dictionary = {}
	var joint_counts: Dictionary = {}
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		baseline_cache[slot_id] = {
			"rotations": {},
			"tip_offsets": {},
			"tip_offset_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
			"joint_offsets": {},
			"joint_offset_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		}
		rotation_counts[slot_id] = {}
		tip_counts[slot_id] = {}
		joint_counts[slot_id] = {}
	for animation_name: StringName in animation_names:
		for sample_ratio: float in sample_ratios:
			var sample: Dictionary = _sample_animation_hand_pose(animation_name, sample_ratio)
			if sample.is_empty():
				continue
			for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
				var slot_sample: Dictionary = sample.get(slot_id, {})
				if slot_sample.is_empty():
					continue
				var slot_cache: Dictionary = baseline_cache.get(slot_id, {})
				var slot_rotation_counts: Dictionary = rotation_counts.get(slot_id, {})
				var slot_tip_counts: Dictionary = tip_counts.get(slot_id, {})
				var slot_joint_counts: Dictionary = joint_counts.get(slot_id, {})
				var rotation_cache: Dictionary = slot_cache.get("rotations", {})
				var tip_cache: Dictionary = slot_cache.get("tip_offsets", {})
				var joint_cache: Dictionary = slot_cache.get("joint_offsets", {})
				for bone_name_variant: Variant in (slot_sample.get("rotations", {}) as Dictionary).keys():
					var bone_name: StringName = bone_name_variant as StringName
					var sample_rotation: Quaternion = (slot_sample.get("rotations", {}) as Dictionary).get(
						bone_name,
						Quaternion.IDENTITY
					) as Quaternion
					var count: int = int(slot_rotation_counts.get(bone_name, 0))
					if count <= 0:
						rotation_cache[bone_name] = sample_rotation
					else:
						var blend_weight: float = 1.0 / float(count + 1)
						rotation_cache[bone_name] = (rotation_cache.get(bone_name, Quaternion.IDENTITY) as Quaternion).slerp(
							sample_rotation,
							blend_weight
						)
					slot_rotation_counts[bone_name] = count + 1
				for finger_id_variant: Variant in (slot_sample.get("tip_offsets", {}) as Dictionary).keys():
					var finger_id: StringName = finger_id_variant as StringName
					var sample_offset: Vector3 = (slot_sample.get("tip_offsets", {}) as Dictionary).get(
						finger_id,
						Vector3.ZERO
					) as Vector3
					var tip_count: int = int(slot_tip_counts.get(finger_id, 0))
					if tip_count <= 0:
						tip_cache[finger_id] = sample_offset
					else:
						var blend_weight: float = 1.0 / float(tip_count + 1)
						tip_cache[finger_id] = (tip_cache.get(finger_id, Vector3.ZERO) as Vector3).lerp(
							sample_offset,
							blend_weight
						)
					slot_tip_counts[finger_id] = tip_count + 1
				for finger_id_variant: Variant in (slot_sample.get("joint_offsets", {}) as Dictionary).keys():
					var joint_finger_id: StringName = finger_id_variant as StringName
					var sample_joint_lookup: Dictionary = (slot_sample.get("joint_offsets", {}) as Dictionary).get(
						joint_finger_id,
						{}
					) as Dictionary
					var joint_cache_lookup: Dictionary = joint_cache.get(joint_finger_id, {})
					var joint_count: int = int(slot_joint_counts.get(joint_finger_id, 0))
					for joint_key_variant: Variant in sample_joint_lookup.keys():
						var joint_key: StringName = joint_key_variant as StringName
						var sample_joint_offset: Vector3 = sample_joint_lookup.get(joint_key, Vector3.ZERO) as Vector3
						if joint_count <= 0:
							joint_cache_lookup[joint_key] = sample_joint_offset
						else:
							var joint_blend_weight: float = 1.0 / float(joint_count + 1)
							joint_cache_lookup[joint_key] = (joint_cache_lookup.get(joint_key, Vector3.ZERO) as Vector3).lerp(
								sample_joint_offset,
								joint_blend_weight
							)
					joint_cache[joint_finger_id] = joint_cache_lookup
					slot_joint_counts[joint_finger_id] = joint_count + 1
				slot_cache["rotations"] = rotation_cache
				slot_cache["tip_offsets"] = tip_cache
				slot_cache["joint_offsets"] = joint_cache
				baseline_cache[slot_id] = slot_cache
				rotation_counts[slot_id] = slot_rotation_counts
				tip_counts[slot_id] = slot_tip_counts
				joint_counts[slot_id] = slot_joint_counts
	return baseline_cache

func _sample_animation_hand_pose(animation_name: StringName, sample_ratio: float) -> Dictionary:
	var josie_root: Node3D = JosieRigScene.instantiate() as Node3D
	if josie_root == null:
		return {}
	var animation_player: AnimationPlayer = josie_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var skeleton: Skeleton3D = josie_root.get_node_or_null("Josie/Skeleton3D") as Skeleton3D
	if animation_player == null or skeleton == null or not animation_player.has_animation(String(animation_name)):
		josie_root.free()
		return {}
	var animation: Animation = animation_player.get_animation(String(animation_name))
	if animation == null:
		josie_root.free()
		return {}
	animation_player.play(String(animation_name))
	animation_player.advance(animation.length * clampf(sample_ratio, 0.0, 1.0))
	skeleton.force_update_all_bone_transforms()
	var sample: Dictionary = {}
	for slot_id: StringName in [SLOT_RIGHT, SLOT_LEFT]:
		var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
		var hand_index: int = skeleton.find_bone(String(hand_name))
		if hand_index < 0:
			continue
		var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
		var hand_inverse: Transform3D = hand_pose.affine_inverse()
		var rotation_lookup: Dictionary = {}
		for bone_name: StringName in FINGER_BASELINE_ROTATION_BONES.get(slot_id, []):
			var bone_index: int = skeleton.find_bone(String(bone_name))
			if bone_index < 0:
				continue
			var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
			var relative_basis: Basis = hand_pose.basis.inverse() * bone_pose.basis
			rotation_lookup[bone_name] = relative_basis.get_rotation_quaternion()
		var tip_lookup: Dictionary = {}
		var joint_lookup: Dictionary = {}
		var slot_chains: Dictionary = FINGER_CHAINS.get(slot_id, {})
		for finger_id: StringName in FINGER_IDS:
			var chain_def: Dictionary = slot_chains.get(finger_id, {})
			var finger_joint_offsets: Dictionary = {}
			for joint_key: StringName in [&"root", &"guide", &"mid", &"end"]:
				var joint_bone_name: StringName = chain_def.get(joint_key, StringName())
				var joint_bone_index: int = skeleton.find_bone(String(joint_bone_name))
				if joint_bone_index < 0:
					continue
				var joint_pose: Transform3D = skeleton.get_bone_global_pose(joint_bone_index)
				finger_joint_offsets[joint_key] = hand_inverse * joint_pose.origin
			if not finger_joint_offsets.is_empty():
				joint_lookup[finger_id] = finger_joint_offsets
			var end_bone_name: StringName = (slot_chains.get(finger_id, {}) as Dictionary).get("end", StringName())
			var end_bone_index: int = skeleton.find_bone(String(end_bone_name))
			if end_bone_index < 0:
				continue
			var end_pose: Transform3D = skeleton.get_bone_global_pose(end_bone_index)
			tip_lookup[finger_id] = hand_inverse * end_pose.origin
		sample[slot_id] = {
			"rotations": rotation_lookup,
			"tip_offsets": tip_lookup,
			"tip_offset_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
			"joint_offsets": joint_lookup,
			"joint_offset_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		}
	josie_root.free()
	return sample

func _apply_animation_contact_open_pose(skeleton: Skeleton3D, slot_id: StringName) -> void:
	_apply_animation_pose_cache_to_slot(skeleton, animation_idle_baseline_cache, slot_id)

func _apply_animation_pose_cache_to_slot(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName
) -> void:
	var slot_cache: Dictionary = pose_cache.get(slot_id, {})
	if slot_cache.is_empty():
		return
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var rotation_lookup: Dictionary = slot_cache.get("rotations", {})
	for bone_name_variant: Variant in rotation_lookup.keys():
		var bone_name: StringName = bone_name_variant as StringName
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var parent_pose: Transform3D = skeleton.get_bone_global_pose(parent_index)
		var desired_hand_relative_rotation: Quaternion = rotation_lookup.get(bone_name, Quaternion.IDENTITY) as Quaternion
		var desired_global_basis: Basis = hand_pose.basis * Basis(desired_hand_relative_rotation)
		var desired_local_basis: Basis = parent_pose.basis.inverse() * desired_global_basis
		skeleton.set_bone_pose_rotation(
			bone_index,
			desired_local_basis.get_rotation_quaternion().normalized()
		)
	skeleton.force_update_all_bone_transforms()

func _resolve_animation_baseline_tip_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName
) -> Vector3:
	return _resolve_animation_baseline_tip_world_position_from_cache(
		skeleton,
		animation_grip_baseline_cache,
		slot_id,
		finger_id
	)

func _resolve_animation_baseline_tip_world_position_from_cache(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName,
	finger_id: StringName
) -> Vector3:
	var slot_cache: Dictionary = pose_cache.get(slot_id, {})
	if slot_cache.is_empty():
		return Vector3.ZERO
	var tip_offset_origin_id: StringName = StringName(slot_cache.get(
		"tip_offset_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	))
	if tip_offset_origin_id == StringName():
		tip_offset_origin_id = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	slot_cache["tip_offset_origin_id"] = tip_offset_origin_id
	var local_tip_offset: Vector3 = (slot_cache.get("tip_offsets", {}) as Dictionary).get(finger_id, Vector3.ZERO) as Vector3
	if local_tip_offset.length_squared() <= 0.000001:
		return Vector3.ZERO
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return Vector3.ZERO
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var local_tip_position: Vector3 = hand_pose * local_tip_offset
	return skeleton.to_global(local_tip_position)

func _resolve_animation_joint_world_position_from_cache(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName,
	finger_id: StringName,
	joint_key: StringName
) -> Vector3:
	var slot_cache: Dictionary = pose_cache.get(slot_id, {})
	if slot_cache.is_empty():
		return Vector3.ZERO
	var joint_offset_origin_id: StringName = StringName(slot_cache.get(
		"joint_offset_origin_id",
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	))
	if joint_offset_origin_id == StringName():
		joint_offset_origin_id = CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	slot_cache["joint_offset_origin_id"] = joint_offset_origin_id
	var local_joint_offset: Vector3 = ((slot_cache.get("joint_offsets", {}) as Dictionary).get(finger_id, {}) as Dictionary).get(
		joint_key,
		Vector3.ZERO
	) as Vector3
	if local_joint_offset.length_squared() <= 0.000001:
		return Vector3.ZERO
	var hand_name: StringName = (PALM_TRIANGULATION_BONES.get(slot_id, {}) as Dictionary).get("hand", StringName())
	var hand_index: int = skeleton.find_bone(String(hand_name))
	if hand_index < 0:
		return Vector3.ZERO
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
	var local_joint_position: Vector3 = hand_pose * local_joint_offset
	return skeleton.to_global(local_joint_position)

func _resolve_hand_grip_center_world_from_cache(
	skeleton: Skeleton3D,
	pose_cache: Dictionary,
	slot_id: StringName
) -> Vector3:
	var sample_points: Array[Vector3] = []
	for finger_id: StringName in [&"thumb", &"index"]:
		for joint_key: StringName in [&"root", &"mid", &"end"]:
			var joint_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
				skeleton,
				pose_cache,
				slot_id,
				finger_id,
				joint_key
			)
			if joint_world.length_squared() > 0.000001:
				sample_points.append(joint_world)
	if sample_points.is_empty():
		return Vector3.ZERO
	var center_world: Vector3 = Vector3.ZERO
	for point_world: Vector3 in sample_points:
		center_world += point_world
	return center_world / float(sample_points.size())

func _resolve_plane_curl_finger_target_world_position(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	cell_world_size: float,
	contact_readiness: float
) -> Vector3:
	var curl_stop: Dictionary = _resolve_plane_curl_stop(
		skeleton,
		slot_id,
		finger_id,
		chain_def,
		grip_center_node,
		cell_world_size
	)
	var curl_t: float = float(curl_stop.get("t", _resolve_max_curl_t_for_finger(finger_id)))
	var resolved_readiness: float = clampf(contact_readiness, 0.0, 1.0)
	_apply_plane_curl_pose(skeleton, slot_id, finger_id, curl_t * resolved_readiness)
	skeleton.force_update_all_bone_transforms()
	var target_world: Vector3 = curl_stop.get("target_world", Vector3.ZERO) as Vector3
	if resolved_readiness < 0.999:
		var baseline_tip_world: Vector3 = _resolve_animation_baseline_tip_world_position_from_cache(
			skeleton,
			animation_grip_baseline_cache,
			slot_id,
			finger_id
		)
		if baseline_tip_world.length_squared() > 0.000001:
			target_world = baseline_tip_world.lerp(target_world, resolved_readiness)
	return target_world

func _resolve_plane_curl_stop(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	chain_def: Dictionary,
	grip_center_node: Node3D,
	cell_world_size: float
) -> Dictionary:
	var max_curl_t: float = _resolve_max_curl_t_for_finger(finger_id)
	var idle_mid_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_idle_baseline_cache,
		slot_id,
		finger_id,
		&"mid"
	)
	var idle_tip_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_idle_baseline_cache,
		slot_id,
		finger_id,
		&"end"
	)
	var grip_mid_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_grip_baseline_cache,
		slot_id,
		finger_id,
		&"mid"
	)
	var grip_tip_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
		skeleton,
		animation_grip_baseline_cache,
		slot_id,
		finger_id,
		&"end"
	)
	if idle_tip_world.length_squared() <= 0.000001 or grip_tip_world.length_squared() <= 0.000001:
		return {
			"t": max_curl_t,
			"target_world": _get_current_chain_end_world_position(skeleton, chain_def),
		}
	var capped_grip_mid_world: Vector3 = idle_mid_world.lerp(grip_mid_world, max_curl_t)
	var capped_grip_tip_world: Vector3 = idle_tip_world.lerp(grip_tip_world, max_curl_t)
	var control_a_world: Vector3 = idle_tip_world.lerp(idle_mid_world, 0.45)
	var control_b_world: Vector3 = capped_grip_tip_world.lerp(capped_grip_mid_world, 0.45)
	var previous_point_world: Vector3 = idle_tip_world
	var previous_t: float = 0.0
	for step_index in range(1, CURL_TRAJECTORY_SAMPLE_STEPS + 1):
		var curve_t: float = max_curl_t * (float(step_index) / float(CURL_TRAJECTORY_SAMPLE_STEPS))
		var sample_point_world: Vector3 = _sample_cubic_bezier_3d(
			idle_tip_world,
			control_a_world,
			control_b_world,
			capped_grip_tip_world,
			curve_t / maxf(max_curl_t, 0.000001)
		)
		var hit: Dictionary = _resolve_contact_hit_on_segment(
			grip_center_node,
			previous_point_world,
			sample_point_world,
			slot_id,
			finger_id,
			&"plane_curl"
		)
		if not hit.is_empty():
			var segment_length: float = previous_point_world.distance_to(sample_point_world)
			var local_fraction: float = 0.0
			if segment_length > 0.000001:
				local_fraction = clampf(
					previous_point_world.distance_to(hit.get("position", sample_point_world) as Vector3) / segment_length,
					0.0,
					1.0
				)
			var stopped_t: float = lerpf(previous_t, curve_t, local_fraction)
			var hit_position: Vector3 = hit.get("position", sample_point_world) as Vector3
			var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO) as Vector3
			if hit_normal.length_squared() <= 0.000001:
				hit_normal = (previous_point_world - sample_point_world).normalized()
			return {
				"t": stopped_t,
				"target_world": hit_position + hit_normal.normalized() * (cell_world_size * 0.05),
			}
		previous_point_world = sample_point_world
		previous_t = curve_t
	var fallback_hit: Dictionary = _resolve_contact_hit_against_profile_cells(
		grip_center_node,
		capped_grip_tip_world,
		slot_id,
		finger_id,
		&"plane_curl_profile_fallback"
	)
	if fallback_hit.is_empty():
		fallback_hit = _resolve_contact_hit_against_profile_cells(
			grip_center_node,
			idle_tip_world,
			slot_id,
			finger_id,
			&"plane_curl_idle_profile_fallback"
		)
	if not fallback_hit.is_empty():
		var fallback_hit_position: Vector3 = fallback_hit.get("position", capped_grip_tip_world) as Vector3
		var fallback_hit_normal: Vector3 = fallback_hit.get("normal", Vector3.ZERO) as Vector3
		if fallback_hit_normal.length_squared() <= 0.000001:
			fallback_hit_normal = (capped_grip_tip_world - grip_center_node.global_position).normalized()
		if fallback_hit_normal.length_squared() <= 0.000001:
			fallback_hit_normal = Vector3.UP
		return {
			"t": max_curl_t,
			"target_world": fallback_hit_position + fallback_hit_normal.normalized() * (cell_world_size * 0.05),
		}
	return {
		"t": max_curl_t,
		"target_world": capped_grip_tip_world,
	}

func _resolve_contact_hit_against_profile_cells(
	grip_center_node: Node3D,
	from_world: Vector3,
	slot_id: StringName,
	finger_id: StringName,
	ray_context: StringName
) -> Dictionary:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return {}
	var profile_offsets: Array = grip_center_node.get_meta("grip_shell_profile_offsets_minor", []) as Array
	if profile_offsets.is_empty():
		return _resolve_contact_hit_on_segment(
			grip_center_node,
			from_world,
			grip_center_node.global_position,
			slot_id,
			finger_id,
			ray_context
		)
	var minor_axis_a_local: Vector3 = _resolve_grip_shell_axis_local(
		grip_center_node,
		&"grip_shell_minor_axis_a_local",
		&"grip_shell_minor_axis_a_origin_id",
		Vector3.RIGHT
	)
	var minor_axis_b_local: Vector3 = _resolve_grip_shell_axis_local(
		grip_center_node,
		&"grip_shell_minor_axis_b_local",
		&"grip_shell_minor_axis_b_origin_id",
		Vector3.UP
	)
	var minor_axis_a_world: Vector3 = (grip_center_node.global_basis * minor_axis_a_local).normalized()
	var minor_axis_b_world: Vector3 = (grip_center_node.global_basis * minor_axis_b_local).normalized()
	if minor_axis_a_world.length_squared() <= 0.000001:
		minor_axis_a_world = grip_center_node.global_basis.x.normalized()
	if minor_axis_b_world.length_squared() <= 0.000001:
		minor_axis_b_world = grip_center_node.global_basis.y.normalized()
	var closest_index: int = -1
	var closest_distance_squared: float = INF
	for profile_index in range(profile_offsets.size()):
		var offset_minor: Vector2 = profile_offsets[profile_index] as Vector2
		var candidate_world: Vector3 = grip_center_node.global_position \
			+ minor_axis_a_world * offset_minor.x \
			+ minor_axis_b_world * offset_minor.y
		var distance_squared: float = from_world.distance_squared_to(candidate_world)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_index = profile_index
	if closest_index >= 0:
		var closest_hit: Dictionary = _resolve_contact_hit_against_profile_cell_index(
			grip_center_node,
			from_world,
			profile_offsets,
			closest_index,
			minor_axis_a_world,
			minor_axis_b_world,
			slot_id,
			finger_id,
			ray_context
		)
		if not closest_hit.is_empty():
			return closest_hit
	for profile_index in range(profile_offsets.size()):
		if profile_index == closest_index:
			continue
		var profile_hit: Dictionary = _resolve_contact_hit_against_profile_cell_index(
			grip_center_node,
			from_world,
			profile_offsets,
			profile_index,
			minor_axis_a_world,
			minor_axis_b_world,
			slot_id,
			finger_id,
			ray_context
		)
		if not profile_hit.is_empty():
			return profile_hit
	return {}

func _resolve_contact_hit_against_profile_cell_index(
	grip_center_node: Node3D,
	from_world: Vector3,
	profile_offsets: Array,
	profile_index: int,
	minor_axis_a_world: Vector3,
	minor_axis_b_world: Vector3,
	slot_id: StringName,
	finger_id: StringName,
	ray_context: StringName
) -> Dictionary:
	if profile_index < 0 or profile_index >= profile_offsets.size():
		return {}
	var offset_minor: Vector2 = profile_offsets[profile_index] as Vector2
	var cell_center_world: Vector3 = grip_center_node.global_position \
		+ minor_axis_a_world * offset_minor.x \
		+ minor_axis_b_world * offset_minor.y
	return _resolve_contact_hit_on_segment(
		grip_center_node,
		from_world,
		cell_center_world,
		slot_id,
		finger_id,
		ray_context
	)

func _apply_plane_curl_pose(
	skeleton: Skeleton3D,
	slot_id: StringName,
	finger_id: StringName,
	curl_t: float
) -> void:
	var slot_idle_cache: Dictionary = animation_idle_baseline_cache.get(slot_id, {})
	if slot_idle_cache.is_empty():
		return
	var plane_bones: Array[StringName] = _resolve_ordered_finger_bones(slot_id, finger_id)
	for bone_name: StringName in plane_bones:
		if bone_name == StringName():
			continue
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var open_local_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
		var desired_local_rotation: Quaternion = _resolve_planar_contact_group_rotation(
			skeleton,
			bone_name,
			open_local_rotation,
			curl_t
		)
		skeleton.set_bone_pose_rotation(bone_index, desired_local_rotation)

func _resolve_ordered_finger_bones(slot_id: StringName, finger_id: StringName) -> Array[StringName]:
	var chain_def: Dictionary = (FINGER_CHAINS.get(slot_id, {}) as Dictionary).get(finger_id, {})
	var ordered_bones: Array[StringName] = []
	for joint_key: StringName in [&"root", &"guide", &"mid", &"end"]:
		var bone_name: StringName = chain_def.get(joint_key, StringName())
		if bone_name == StringName() or bone_name in ordered_bones:
			continue
		ordered_bones.append(bone_name)
	return ordered_bones

func _resolve_planar_contact_group_rotation(
	skeleton: Skeleton3D,
	bone_name: StringName,
	open_rotation: Quaternion,
	curl_t: float
) -> Quaternion:
	var rule: Dictionary = PlayerDigitHingeRulesScript.get_rule_for_bone(bone_name)
	if not PlayerDigitHingeRulesScript.rule_has_valid_origin_chain(rule, skeleton):
		return open_rotation.normalized()
	var hinge_axis_local: Vector3 = rule.get(
		"hinge_axis_local",
		Vector3.ZERO
	) as Vector3
	var hinge_axis_origin_id: StringName = rule.get(
		"hinge_axis_origin_id",
		StringName()
	) as StringName
	if hinge_axis_origin_id != bone_name:
		return open_rotation.normalized()
	hinge_axis_local = hinge_axis_local.normalized()
	if hinge_axis_local.length_squared() <= 0.000001:
		return open_rotation.normalized()
	var tween_t: float = _smooth_contact_group_tween_t(curl_t)
	var closed_degrees: float = PlayerDigitHingeRulesScript.get_closed_degrees_for_bone(bone_name)
	var resolved_angle: float = deg_to_rad(closed_degrees) * tween_t
	return (
		open_rotation.normalized() * Quaternion(hinge_axis_local, resolved_angle)
	).normalized()

func _smooth_contact_group_tween_t(raw_t: float) -> float:
	var resolved_t: float = clampf(raw_t, 0.0, 1.0)
	return resolved_t * resolved_t * (3.0 - 2.0 * resolved_t)

func _resolve_max_curl_t_for_finger(finger_id: StringName) -> float:
	if finger_id == &"pinky":
		return PINKY_MAX_CURL_T
	return 1.0

func _finger_uses_plane_curl_path(finger_id: StringName) -> bool:
	return finger_id in FINGER_IDS

func _get_current_chain_end_world_position(skeleton: Skeleton3D, chain_def: Dictionary) -> Vector3:
	var end_bone_name: StringName = chain_def.get("end", StringName())
	var end_bone_index: int = skeleton.find_bone(String(end_bone_name))
	if end_bone_index < 0:
		return Vector3.ZERO
	return skeleton.to_global(skeleton.get_bone_global_pose(end_bone_index).origin)

func _sample_cubic_bezier_3d(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	t: float
) -> Vector3:
	var u: float = 1.0 - t
	var tt: float = t * t
	var uu: float = u * u
	var uuu: float = uu * u
	var ttt: float = tt * t
	return (p0 * uuu) + (p1 * 3.0 * uu * t) + (p2 * 3.0 * u * tt) + (p3 * ttt)

func _resolve_contact_hit_on_segment(
	grip_center_node: Node3D,
	from_world: Vector3,
	to_world: Vector3,
	slot_id: StringName = StringName(),
	finger_id: StringName = StringName(),
	ray_context: StringName = &"contact_segment"
) -> Dictionary:
	if grip_center_node == null or not is_instance_valid(grip_center_node):
		return {}
	var world_3d: World3D = grip_center_node.get_world_3d()
	if world_3d == null:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			from_world,
			to_world,
			0,
			{},
			"missing_world"
		)
		return {}
	var collision_mask: int = int(grip_center_node.get_meta("grip_shell_collision_layer", 0))
	if collision_mask <= 0:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			from_world,
			to_world,
			collision_mask,
			{},
			"missing_collision_mask"
		)
		return {}
	if from_world.distance_to(to_world) <= 0.000001:
		_record_contact_ray_debug(
			grip_center_node,
			slot_id,
			finger_id,
			ray_context,
			from_world,
			to_world,
			collision_mask,
			{},
			"empty_segment"
		)
		return {}
	var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_world,
		to_world,
		collision_mask
	)
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = false
	ray_query.hit_from_inside = true
	var hit: Dictionary = _intersect_expected_contact_area_ray(
		world_3d,
		grip_center_node,
		ray_query
	)
	_record_contact_ray_debug(
		grip_center_node,
		slot_id,
		finger_id,
		ray_context,
		from_world,
		to_world,
		collision_mask,
		hit
	)
	return hit

func _intersect_expected_contact_area_ray(
	world_3d: World3D,
	grip_center_node: Node3D,
	ray_query: PhysicsRayQueryParameters3D
) -> Dictionary:
	if world_3d == null or grip_center_node == null or ray_query == null:
		return {}
	var expected_area: Area3D = grip_center_node.get_node_or_null(
		"GripContactArea"
	) as Area3D
	if expected_area == null or not is_instance_valid(expected_area):
		return {}
	var surface_authority := StringName(expected_area.get_meta(
		"grip_contact_surface_authority",
		StringName()
	))
	if surface_authority == PrimaryGripHandleMeshPacketScript.SOURCE:
		var guide_node: Node = grip_center_node.get_parent()
		var expected_surface_origin_id := (
			CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_CONTACT_SURFACE
			if guide_node != null and String(guide_node.name) == "SecondaryGripGuide"
			else CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE
		)
		if (
			StringName(expected_area.get_meta(
				"grip_contact_faces_local_origin_id",
				StringName()
			)) != expected_surface_origin_id
			or not bool(expected_area.get_meta("grip_contact_handle_only", false))
			or String(expected_area.get_meta(
				"grip_contact_handle_body_signature",
				""
			)).is_empty()
		):
			return {}
	var excluded_rids: Array[RID] = []
	for _attempt_index: int in range(CONTACT_RAY_UNEXPECTED_COLLIDER_LIMIT):
		ray_query.exclude = excluded_rids
		var candidate_hit: Dictionary = world_3d.direct_space_state.intersect_ray(
			ray_query
		)
		if candidate_hit.is_empty():
			return {}
		var candidate_collider := candidate_hit.get("collider") as CollisionObject3D
		if candidate_collider == expected_area:
			return candidate_hit
		if candidate_collider == null or not is_instance_valid(candidate_collider):
			return {}
		excluded_rids.append(candidate_collider.get_rid())
	return {}

func _resolve_baseline_contact_target_world_position(
	grip_center_node: Node3D,
	center_world: Vector3,
	baseline_tip_world: Vector3,
	cell_world_size: float
) -> Vector3:
	if baseline_tip_world.length_squared() <= 0.000001:
		return Vector3.ZERO
	var hit: Dictionary = _resolve_contact_hit_on_segment(
		grip_center_node,
		baseline_tip_world,
		center_world,
		StringName(),
		StringName(),
		&"baseline_contact_tip_to_center"
	)
	if hit.is_empty():
		hit = _resolve_contact_hit_on_segment(
			grip_center_node,
			center_world,
			baseline_tip_world,
			StringName(),
			StringName(),
			&"baseline_contact_center_to_tip"
		)
	if hit.is_empty():
		return baseline_tip_world
	var hit_position: Vector3 = hit.get("position", baseline_tip_world)
	var hit_normal: Vector3 = hit.get("normal", Vector3.ZERO)
	if hit_normal.length_squared() <= 0.000001:
		hit_normal = (baseline_tip_world - center_world).normalized()
	return hit_position + hit_normal.normalized() * (cell_world_size * 0.05)
