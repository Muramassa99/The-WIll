extends SceneTree

const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)
const PlayerDigitHingeRulesScript = preload(
	"res://runtime/player/player_digit_hinge_rules.gd"
)

const SOURCE_LIBRARY_PATH := (
	"C:/Users/ixro1/AppData/Roaming/Godot/app_userdata/"
	+ "The Will-Gamefiles/forge/player_wip_library_state.tres"
)
const DIGIT_IDS: Array[StringName] = [
	&"thumb",
	&"index",
	&"middle",
	&"ring",
	&"pinky",
]
const RUN_ONE_HAND_COMPARE: bool = false
const RUN_BOOTSTRAP_COMPARE: bool = false
const RUN_EXTRA_DIGIT_SETTLE: bool = false


class FakePlayer:
	extends Node

	var forge_wip_library_state: PlayerForgeWipLibraryState = null
	var ui_mode_enabled := false

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var library: PlayerForgeWipLibraryState = ResourceLoader.load(
		SOURCE_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if library == null:
		push_error("selected-grip diagnostic could not load the WIP library")
		quit(1)
		return
	var selected_wip: CraftedItemWIP = library.get_saved_wip(library.selected_wip_id)
	if selected_wip == null:
		push_error("selected-grip diagnostic found no selected WIP")
		quit(1)
		return
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library
	root.add_child(fake_player)
	var ui := CombatAnimationStationUIScene.instantiate()
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await _wait_process_frames(3)
	ui.open_for(fake_player, "Current Selected Grip Entry Diagnostic")
	await _wait_process_frames(5)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(
		selected_wip.wip_id,
		&"hand_right",
		false,
		true
	)
	await _wait_process_frames(8)
	var slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_process_frames(8)
	await _wait_physics_frames(2)
	print("project_name=%s" % selected_wip.forge_project_name)
	print("wip_id=%s" % String(selected_wip.wip_id))
	print("open_ok=%s" % str(open_ok))
	print("slot_ok=%s" % str(slot_ok))
	var preview_subviewport: SubViewport = ui.get("preview_subviewport") as SubViewport
	var preview_root: Node3D = preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D if preview_subviewport != null else null
	var actor: Node3D = preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D if preview_root != null else null
	if actor == null:
		push_error("selected-grip diagnostic found no preview actor")
		quit(1)
		return
	var grip_presenter: RefCounted = actor.get("finger_grip_presenter") as RefCounted
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D
	var seat_state: Dictionary = held_item.get_meta(
		"weapon_surface_seat_state",
		{}
	) as Dictionary if held_item != null else {}
	var seat_diagnostics: Dictionary = seat_state.get("diagnostics", {}) as Dictionary
	print("seat_valid=%s" % str(bool(seat_state.get("valid", false))))
	print("seat_status=%s" % String(seat_state.get("status", StringName())))
	print("seat_proximal_safety_enforced=%s" % str(bool(
		seat_diagnostics.get("proximal_safety_enforced", false)
	)))
	print("seat_proximal_max_penetration_meters=%s" % str(
		seat_diagnostics.get("proximal_max_penetration_meters", -1.0)
	))
	print("seat_diagnostics=%s" % JSON.stringify(
		_compact_support_seat_diagnostics(seat_diagnostics)
	))
	var support_seat_state: Dictionary = held_item.get_meta(
		"preview_support_hand_surface_seat_state",
		{}
	) as Dictionary if held_item != null else {}
	var support_seat_diagnostics: Dictionary = support_seat_state.get(
		"diagnostics",
		{}
	) as Dictionary
	print("support_seat_valid=%s" % str(bool(support_seat_state.get("valid", false))))
	print("support_seat_status=%s" % String(
		support_seat_state.get("status", StringName())
	))
	print("support_seat_proximal_safety_enforced=%s" % str(bool(
		support_seat_diagnostics.get("proximal_safety_enforced", false)
	)))
	print("support_seat_proximal_max_penetration_meters=%s" % str(
		support_seat_diagnostics.get("proximal_max_penetration_meters", -1.0)
	))
	print("support_seat_diagnostics=%s" % JSON.stringify(
		_compact_support_seat_diagnostics(support_seat_diagnostics)
	))
	var grasp_state: Dictionary = grip_presenter.call(
		"get_surface_grasp_debug_state",
		&"hand_right"
	) as Dictionary if grip_presenter != null else {}
	var diagnostics: Dictionary = grasp_state.get("diagnostics", {}) as Dictionary
	var attempt_diagnostics: Dictionary = grasp_state.get(
		"last_attempt_diagnostics",
		diagnostics
	) as Dictionary
	var committed_diagnostics: Dictionary = grasp_state.get(
		"diagnostics",
		{}
	) as Dictionary
	var attempted_digit_results: Dictionary = attempt_diagnostics.get(
		"digit_results",
		{}
	) as Dictionary
	var digit_results: Dictionary = committed_diagnostics.get(
		"digit_results",
		attempted_digit_results
	) as Dictionary
	print("grasp_valid=%s" % str(bool(grasp_state.get("valid", false))))
	print("grasp_status=%s" % String(grasp_state.get("status", StringName())))
	print("solve_count=%d" % int(grasp_state.get("solve_count", 0)))
	print("rotation_count=%d" % (grasp_state.get("rotations", {}) as Dictionary).size())
	print("attempt_status=%s" % String(attempt_diagnostics.get("status", StringName())))
	print("unsafe_digit_count=%d" % int(attempt_diagnostics.get("unsafe_digit_count", -1)))
	print("solved_digit_count=%d" % int(attempt_diagnostics.get("solved_digit_count", -1)))
	print("grasp_attempt=%s" % JSON.stringify(
		_compact_grasp_attempt(attempt_diagnostics)
	))
	print("grasp_committed=%s" % JSON.stringify(
		_compact_grasp_attempt(committed_diagnostics)
	))
	var initial_support_grasp_state: Dictionary = grip_presenter.call(
		"get_surface_grasp_debug_state",
		&"hand_left"
	) as Dictionary if grip_presenter != null else {}
	var initial_support_attempt: Dictionary = initial_support_grasp_state.get(
		"last_attempt_diagnostics",
		{}
	) as Dictionary
	print("initial_support_grasp_valid=%s" % str(bool(
		initial_support_grasp_state.get("valid", false)
	)))
	print("initial_support_grasp_status=%s" % String(
		initial_support_grasp_state.get("status", StringName())
	))
	print("initial_support_grasp_attempt=%s" % JSON.stringify(
		_compact_grasp_attempt(initial_support_attempt)
	))
	var initial_support_digits: Dictionary = initial_support_attempt.get(
		"digit_results",
		{}
	) as Dictionary
	var initial_support_middle: Dictionary = initial_support_digits.get(
		&"middle",
		{}
	) as Dictionary
	print("initial_support_middle_detail=%s" % JSON.stringify({
		"neutral_fallback_sections": initial_support_middle.get(
			"neutral_fallback_sections",
			[]
		),
		"attempted_final_sections": initial_support_middle.get(
			"attempted_final_sections",
			[]
		),
	}))
	print("initial_pose_state=%s" % JSON.stringify(
		_compact_pose_state(actor, held_item, grip_presenter)
	))
	var debug_state: Dictionary = actor.call(
		"get_authoring_joint_range_debug_state"
	) as Dictionary if actor.has_method("get_authoring_joint_range_debug_state") else {}
	var debug_digits: Dictionary = debug_state.get("digit_bones", {}) as Dictionary
	for digit_id: StringName in DIGIT_IDS:
		var digit: Dictionary = digit_results.get(digit_id, {}) as Dictionary
		var attempted_digit: Dictionary = attempted_digit_results.get(
			digit_id,
		{}
		) as Dictionary
		print("digit_%s_status=%s" % [String(digit_id), String(digit.get("status", StringName()))])
		print("digit_%s_angles_rad=%s" % [String(digit_id), str(digit.get("joint_angles_rad", []))])
		print("digit_%s_attempt_angles_rad=%s" % [
			String(digit_id),
			str(attempted_digit.get("joint_angles_rad", [])),
		])
		print("digit_%s_contacts=%d" % [String(digit_id), int(digit.get("contacted_section_count", -1))])
		print("digit_%s_accepted=%d" % [String(digit_id), int(digit.get("accepted_section_count", -1))])
		print("digit_%s_max_penetration_meters=%s" % [
			String(digit_id),
			str(digit.get("max_penetration_meters", -1.0)),
		])
		print("digit_%s_attempted_max_penetration_meters=%s" % [
			String(digit_id),
			str(digit.get("attempted_max_penetration_meters", -1.0)),
		])
		var debug_angles: Array[float] = []
		var chain_rules: Array[Dictionary] = (
			PlayerDigitHingeRulesScript.get_chain_rules(&"hand_right", digit_id)
		)
		for rule: Dictionary in chain_rules:
			var bone_name: StringName = rule.get("bone", StringName()) as StringName
			var bone_debug: Dictionary = debug_digits.get(bone_name, {}) as Dictionary
			debug_angles.append(float(bone_debug.get("angle_degrees", NAN)))
		print("digit_%s_debug_angles_deg=%s" % [String(digit_id), str(debug_angles)])
		if digit_id != &"thumb" and not chain_rules.is_empty():
			var root_bone_name: StringName = chain_rules[0].get(
				"bone",
				StringName()
			) as StringName
			var root_debug: Dictionary = debug_digits.get(root_bone_name, {}) as Dictionary
			var final_sections: Array = digit.get("final_sections", []) as Array
			if not final_sections.is_empty():
				var root_section: Dictionary = final_sections[0] as Dictionary
				var joint_world: Vector3 = root_debug.get("joint_world", Vector3.ZERO) as Vector3
				var hinge_axis_world: Vector3 = root_debug.get(
					"hinge_axis_world",
					Vector3.ZERO
				) as Vector3
				var section_mid_world: Vector3 = (
					(root_section.get("section_segment_start_world", Vector3.ZERO) as Vector3)
					+ (root_section.get("section_segment_end_world", Vector3.ZERO) as Vector3)
				) * 0.5
				var inward_world: Vector3 = root_section.get(
					"inward_ray_direction_world",
					Vector3.ZERO
				) as Vector3
				var positive_curl_velocity: Vector3 = hinge_axis_world.cross(
					section_mid_world - joint_world
				)
				var approach_dot: float = 0.0
				if (
					positive_curl_velocity.length_squared() > 0.000000000001
					and inward_world.length_squared() > 0.000000000001
				):
					approach_dot = positive_curl_velocity.normalized().dot(
						inward_world.normalized()
					)
				print("digit_%s_positive_curl_inward_dot=%s" % [
					String(digit_id),
					str(approach_dot),
				])
		print("digit_%s_sections=%s" % [
			String(digit_id),
			JSON.stringify(_compact_digit_sections(digit)),
		])
		if digit_id == &"index" or digit_id == &"middle":
			print("digit_%s_section_contacts_full=%s" % [
				String(digit_id),
				JSON.stringify(digit.get("section_contacts", [])),
			])
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var debug_toggle_rotations_before: Dictionary = _capture_digit_rotations(skeleton)
	var primary_solve_count_before_toggle: int = int(grasp_state.get("solve_count", 0))
	var support_solve_count_before_toggle: int = int(
		initial_support_grasp_state.get("solve_count", 0)
	)
	actor.call("set_authoring_joint_range_debug_visible", false)
	actor.call("set_authoring_joint_range_debug_visible", true)
	var debug_toggle_rotations_after: Dictionary = _capture_digit_rotations(skeleton)
	var primary_state_after_toggle: Dictionary = grip_presenter.call(
		"get_surface_grasp_debug_state",
		&"hand_right"
	) as Dictionary
	var support_state_after_toggle: Dictionary = grip_presenter.call(
		"get_surface_grasp_debug_state",
		&"hand_left"
	) as Dictionary
	print("debug_toggle_rotation_mismatch_count=%d" % _rotation_mismatch_count(
		debug_toggle_rotations_before,
		debug_toggle_rotations_after
	))
	print("debug_toggle_primary_solve_count_delta=%d" % (
		int(primary_state_after_toggle.get("solve_count", 0))
		- primary_solve_count_before_toggle
	))
	print("debug_toggle_support_solve_count_delta=%d" % (
		int(support_state_after_toggle.get("solve_count", 0))
		- support_solve_count_before_toggle
	))
	if RUN_EXTRA_DIGIT_SETTLE:
		var preview_presenter: RefCounted = ui.get("preview_presenter") as RefCounted
		for settle_pass: int in range(1, 5):
			preview_presenter.call(
				"_settle_preview_digits_on_resolved_weapon",
				actor,
				held_item,
				true
			)
			await _wait_process_frames(2)
			var repeated_support_state: Dictionary = grip_presenter.call(
				"get_surface_grasp_debug_state",
				&"hand_left"
			) as Dictionary
			print("repeated_support_%d_valid=%s" % [
				settle_pass,
				str(bool(repeated_support_state.get("valid", false))),
			])
			print("repeated_support_%d_status=%s" % [
				settle_pass,
				String(repeated_support_state.get("status", StringName())),
			])
			print("repeated_support_%d_attempt=%s" % [
				settle_pass,
				JSON.stringify(_compact_grasp_attempt(repeated_support_state.get(
					"last_attempt_diagnostics",
					{}
				) as Dictionary)),
			])
	if RUN_ONE_HAND_COMPARE and not RUN_BOOTSTRAP_COMPARE:
		var direct_one_hand_ok: bool = ui.set_selected_motion_node_two_hand_state(
			&"two_hand_one_hand",
			false,
			false,
			false,
			true,
			false
		)
		await _wait_process_frames(8)
		await _wait_physics_frames(2)
		var direct_one_hand_state: Dictionary = grip_presenter.call(
			"get_surface_grasp_debug_state",
			&"hand_right"
		) as Dictionary
		print("direct_one_hand_ok=%s" % str(direct_one_hand_ok))
		print("direct_one_hand_valid=%s" % str(bool(
			direct_one_hand_state.get("valid", false)
		)))
		print("direct_one_hand_status=%s" % String(
			direct_one_hand_state.get("status", StringName())
		))
		print("direct_one_hand_attempt=%s" % JSON.stringify(
			_compact_grasp_attempt(direct_one_hand_state.get(
				"last_attempt_diagnostics",
				{}
			) as Dictionary)
		))
	if not RUN_BOOTSTRAP_COMPARE:
		ui.free()
		fake_player.free()
		await process_frame
		quit(0)
		return
	var session_state: RefCounted = ui.get("session_state") as RefCounted
	var active_draft: Resource = session_state.get("current_draft_ref") as Resource
	var motion_nodes: Array = active_draft.get("motion_node_chain") as Array
	var selected_node_index: int = int(active_draft.get("selected_motion_node_index"))
	var selected_node: Resource = motion_nodes[selected_node_index] as Resource
	var authored_grip_coordinate: float = float(selected_node.get("grip_seat_slide_offset"))
	print("authored_grip_coordinate=%s" % str(authored_grip_coordinate))
	print("authored_two_hand_state=%s" % String(selected_node.get("two_hand_state")))
	if not is_zero_approx(authored_grip_coordinate):
		var zero_ok: bool = ui.set_selected_motion_node_grip_seat_slide(
			0.0,
			false,
			false,
			false,
			true,
			false
		)
		await _wait_process_frames(8)
		var target_ok: bool = ui.set_selected_motion_node_grip_seat_slide(
			authored_grip_coordinate,
			false,
			false,
			false,
			true,
			false
		)
		await _wait_process_frames(8)
		await _wait_physics_frames(2)
		print("bootstrap_zero_ok=%s" % str(zero_ok))
		print("bootstrap_target_ok=%s" % str(target_ok))
		for slot_id: StringName in [&"hand_right", &"hand_left"]:
			var post_state: Dictionary = grip_presenter.call(
				"get_surface_grasp_debug_state",
				slot_id
			) as Dictionary
			var post_attempt: Dictionary = post_state.get(
				"last_attempt_diagnostics",
				{}
			) as Dictionary
			print("post_bootstrap_%s_valid=%s" % [
				String(slot_id),
				str(bool(post_state.get("valid", false))),
			])
			print("post_bootstrap_%s_status=%s" % [
				String(slot_id),
				String(post_state.get("status", StringName())),
			])
			print("post_bootstrap_%s_unsafe_digits=%d" % [
				String(slot_id),
				int(post_attempt.get("unsafe_digit_count", -1)),
			])
			print("post_bootstrap_%s_attempt=%s" % [
				String(slot_id),
				JSON.stringify(_compact_grasp_attempt(post_attempt)),
			])
		print("post_bootstrap_pose_state=%s" % JSON.stringify(
			_compact_pose_state(actor, held_item, grip_presenter)
		))
		if not RUN_ONE_HAND_COMPARE:
			ui.free()
			fake_player.free()
			await process_frame
			quit(0)
			return
		var one_hand_ok: bool = ui.set_selected_motion_node_two_hand_state(
			&"two_hand_one_hand",
			false,
			false,
			false,
			true,
			false
		)
		await _wait_process_frames(8)
		await _wait_physics_frames(2)
		var one_hand_state: Dictionary = grip_presenter.call(
			"get_surface_grasp_debug_state",
			&"hand_right"
		) as Dictionary
		var one_hand_attempt: Dictionary = one_hand_state.get(
			"last_attempt_diagnostics",
			{}
		) as Dictionary
		print("one_hand_switch_ok=%s" % str(one_hand_ok))
		print("one_hand_right_valid=%s" % str(bool(
			one_hand_state.get("valid", false)
		)))
		print("one_hand_right_status=%s" % String(
			one_hand_state.get("status", StringName())
		))
		print("one_hand_right_unsafe_digits=%d" % int(
			one_hand_attempt.get("unsafe_digit_count", -1)
		))
	ui.free()
	fake_player.free()
	await process_frame
	quit(0)


func _compact_support_seat_diagnostics(diagnostics: Dictionary) -> Dictionary:
	var best: Dictionary = diagnostics.get("best_overall", {}) as Dictionary
	var accepted: Dictionary = diagnostics.get("best_accepted", {}) as Dictionary
	return {
		"status": diagnostics.get("status", StringName()),
		"completed_iterations": diagnostics.get("completed_iterations", -1),
		"best_sample_index": best.get("sample_index", -1),
		"index_radial_error_meters": best.get("index_radial_error_meters", INF),
		"pinky_radial_error_meters": best.get("pinky_radial_error_meters", INF),
		"ordinary_proximal_capsules_safe": best.get(
			"ordinary_proximal_capsules_safe",
			false
		),
		"ordinary_proximal_worst_digit_id": best.get(
			"ordinary_proximal_worst_digit_id",
			StringName()
		),
		"ordinary_proximal_worst_penetration_meters": best.get(
			"ordinary_proximal_worst_penetration_meters",
			INF
		),
		"ordinary_proximal_surface_escape_translation_world": best.get(
			"ordinary_proximal_surface_escape_translation_world",
			Vector3.ZERO
		),
		"accepted_sample_index": accepted.get("sample_index", -1),
		"accepted_index_radial_error_meters": accepted.get(
			"index_radial_error_meters",
			INF
		),
		"accepted_pinky_radial_error_meters": accepted.get(
			"pinky_radial_error_meters",
			INF
		),
		"accepted_ordinary_proximal_capsules_safe": accepted.get(
			"ordinary_proximal_capsules_safe",
			false
		),
	}


func _compact_digit_sections(digit: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field_name: StringName in [
		&"section_contacts",
		&"final_sections",
		&"attempted_final_sections",
	]:
		var compact_sections: Array[Dictionary] = []
		for section_variant: Variant in digit.get(field_name, []):
			var section: Dictionary = section_variant as Dictionary
			compact_sections.append({
				"section_index": section.get("section_index", -1),
				"status": section.get("status", StringName()),
				"ray_hit": section.get("ray_hit", false),
				"in_contact": section.get("in_contact", false),
				"within_overlap_limit": section.get("within_overlap_limit", false),
				"penetration_meters": section.get("penetration_meters", -1.0),
				"surface_gap_meters": section.get("surface_gap_meters", -1.0),
				"contact_error_meters": section.get("contact_error_meters", -1.0),
			})
		result[field_name] = compact_sections
	return result


func _compact_pose_state(
	actor: Node3D,
	held_item: Node3D,
	grip_presenter: RefCounted
) -> Dictionary:
	var state: Dictionary = {
		"weapon_world": _compact_transform(held_item.global_transform),
	}
	for guide_name: String in ["PrimaryGripGuide", "SecondaryGripGuide"]:
		var guide: Node3D = held_item.get_node_or_null(guide_name) as Node3D
		if guide != null:
			state[guide_name] = _compact_transform(guide.global_transform)
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	if skeleton != null:
		for hand_record: Dictionary in [
			{"slot": &"hand_right", "bone": &"CC_Base_R_Hand"},
			{"slot": &"hand_left", "bone": &"CC_Base_L_Hand"},
		]:
			var bone_index: int = skeleton.find_bone(String(hand_record["bone"]))
			if bone_index >= 0:
				state["%s_world" % String(hand_record["slot"])] = _compact_transform(
					skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)
				)
	for slot_id: StringName in [&"hand_right", &"hand_left"]:
		var grasp: Dictionary = grip_presenter.call(
			"get_surface_grasp_debug_state",
			slot_id
		) as Dictionary
		state["%s_grasp" % String(slot_id)] = {
			"valid": grasp.get("valid", false),
			"status": grasp.get("status", StringName()),
			"context_key": grasp.get("context_key", ""),
			"grip_center_world": grasp.get("grip_center_world", Vector3.ZERO),
			"grip_guide_world_at_solve": grasp.get(
				"grip_guide_world_at_solve",
				Vector3.ZERO
			),
		}
	return state


func _compact_transform(value: Transform3D) -> Dictionary:
	var q: Quaternion = value.basis.orthonormalized().get_rotation_quaternion()
	return {
		"origin": value.origin,
		"rotation": Vector4(q.x, q.y, q.z, q.w),
	}


func _compact_grasp_attempt(attempt: Dictionary) -> Dictionary:
	var compact_digits: Dictionary = {}
	var digit_results: Dictionary = attempt.get("digit_results", {}) as Dictionary
	for digit_id: StringName in DIGIT_IDS:
		var digit: Dictionary = digit_results.get(digit_id, {}) as Dictionary
		compact_digits[digit_id] = {
			"status": digit.get("status", StringName()),
			"joint_angles_rad": digit.get("joint_angles_rad", []),
			"contacted_section_count": digit.get("contacted_section_count", -1),
			"accepted_section_count": digit.get("accepted_section_count", -1),
			"max_penetration_meters": digit.get("max_penetration_meters", -1.0),
			"attempted_max_penetration_meters": digit.get(
				"attempted_max_penetration_meters",
				-1.0
			),
		}
	return {
		"status": attempt.get("status", StringName()),
		"unsafe_digit_count": attempt.get("unsafe_digit_count", -1),
		"solved_digit_count": attempt.get("solved_digit_count", -1),
		"digit_results": compact_digits,
	}


func _capture_digit_rotations(skeleton: Skeleton3D) -> Dictionary:
	var rotations: Dictionary = {}
	if skeleton == null:
		return rotations
	for rule: Dictionary in PlayerDigitHingeRulesScript.get_all_rules():
		var bone_name: StringName = rule.get("bone", StringName()) as StringName
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index >= 0:
			rotations[bone_name] = skeleton.get_bone_pose_rotation(
				bone_index
			).normalized()
	return rotations


func _rotation_mismatch_count(before: Dictionary, after: Dictionary) -> int:
	if before.size() != after.size():
		return maxi(before.size(), after.size())
	var mismatch_count: int = 0
	for bone_name_variant: Variant in before.keys():
		var bone_name: StringName = bone_name_variant as StringName
		var before_rotation: Quaternion = before.get(
			bone_name,
			Quaternion.IDENTITY
		) as Quaternion
		var after_rotation: Quaternion = after.get(
			bone_name,
			Quaternion.IDENTITY
		) as Quaternion
		if absf(before_rotation.normalized().dot(after_rotation.normalized())) < 0.999999:
			mismatch_count += 1
	return mismatch_count


func _wait_process_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame
