extends "res://tools/verify_combat_weapon_motion_rig.gd"

## Narrow reversible-policy check on the imported rig. Synthetic rigid prop,
## no player save, grip search, editor-fluidity or full replay certification.
const IsolationAdapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")

func _run() -> void:
	actor_parent = Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	_disable_animation_trees()
	skeleton = rig.skeleton
	_check(skeleton != null and rig.has_method("is_authoring_arm_spine_isolation_enabled"), "isolation_api_available")
	if skeleton == null or not rig.has_method("is_authoring_arm_spine_isolation_enabled"):
		_finish()
		return
	_check(bool(rig.get("authoring_arm_spine_isolation_enabled")), "temporary_isolation_defaults_on")
	for side: String in ["R", "L"]:
		_seed_bent_neutral_wrist(side)
	base_poses = _poses()
	actor_parent.transform = Transform3D(Basis.from_euler(Vector3(0.13, -0.37, 0.09)), Vector3(1.0, 0.4, -1.2))
	for side: String in ["R", "L"]:
		for two_hand: bool in [false, true]:
			_check_macro_isolation(side, two_hand)
	_check_nonpreview_policy()
	for enabled: bool in [true, false]:
		rig.set("authoring_arm_spine_isolation_enabled", enabled)
		for side: String in ["R", "L"]:
			for two_hand: bool in [false, true]:
				for mode: String in ["tip", "pommel", "roll"]:
					_check_allocator_parameters(side, two_hand, mode, enabled)
	rig.set("authoring_arm_spine_isolation_enabled", true)
	for side: String in ["R", "L"]:
		_check_small_motion(side)
		_exercise_independent_arm(side)
	_finish()

func _disable_animation_trees() -> void:
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false

func _seed_nondefault_torso() -> void:
	rig.clear_authoring_independent_arm_pose_authority()
	rig.clear_upper_body_authoring_state()
	for bone_name: String in ["CC_Base_Waist", "CC_Base_Spine01", "CC_Base_Spine02"]:
		var index := skeleton.find_bone(bone_name)
		var previous := skeleton.get_bone_pose_rotation(index)
		skeleton.set_bone_pose_rotation(index, (Quaternion(Vector3.UP, 0.09) * Quaternion(Vector3.RIGHT, -0.04) * previous).normalized())
	skeleton.force_update_all_bone_transforms()

func _macro_state(side: String, two_hand: bool) -> Dictionary:
	var chest := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("CC_Base_Spine02"))
	var point := chest.origin + actor_parent.global_basis * Vector3(0.6, 0.2, 0.7)
	return {"active": true, "two_hand": two_hand, "blend": 1.0,
		"dominant_slot_id": _slot(side), "primary_target_world": point,
		"secondary_target_world": point + actor_parent.global_basis * Vector3(0.0, 0.0, 0.1) if two_hand else Vector3.ZERO,
		"tip_world": point + actor_parent.global_basis * Vector3(0.5, 0.3, 0.6), "pommel_world": point}

func _clavicle_pose(side: String) -> Transform3D:
	return skeleton.get_bone_pose(skeleton.find_bone("CC_Base_" + side + "_Clavicle"))

func _check_macro_isolation(side: String, two_hand: bool) -> void:
	_restore()
	_seed_nondefault_torso()
	var before := _proximal_spine_poses()
	var shoulder_before := _clavicle_pose(side)
	var label := "%s_%s_macro" % [side, "two_hand" if two_hand else "one_hand"]
	rig.set("authoring_arm_spine_isolation_enabled", true)
	rig.set_upper_body_authoring_state(_macro_state(side, two_hand))
	rig.apply_upper_body_authoring_pose_now()
	_check(_proximal_spine_unchanged(before), label + "_preserves_nondefault_core")
	_check(_basis_error(_clavicle_pose(side).basis, shoulder_before.basis) > 0.00001, label + "_clavicle_remains_available")
	rig.set("authoring_arm_spine_isolation_enabled", false)
	rig.apply_upper_body_authoring_pose_now()
	_check(not _proximal_spine_unchanged(before), label + "_switch_off_restores_torso_contribution")
	rig.clear_upper_body_authoring_state()

func _check_nonpreview_policy() -> void:
	_restore()
	_seed_nondefault_torso()
	rig.set("authoring_arm_spine_isolation_enabled", true)
	rig.set_authoring_preview_mode_enabled(false)
	_disable_animation_trees()
	_check(not bool(rig.call("is_authoring_arm_spine_isolation_enabled")), "isolation_not_active_outside_authoring")
	var before := _proximal_spine_poses()
	rig.set_upper_body_authoring_state(_macro_state("R", true))
	rig.apply_upper_body_authoring_pose_now()
	_check(not _proximal_spine_unchanged(before), "nonpreview_macro_retains_torso_behavior")
	rig.clear_upper_body_authoring_state()
	rig.set_authoring_preview_mode_enabled(true)
	_disable_animation_trees()

func _check_allocator_parameters(side: String, two_hand: bool, mode: String, enabled: bool) -> void:
	_restore()
	_seed_nondefault_torso()
	var prop := _make_isolation_prop(side)
	var request := _request(side, prop, prop.global_transform, mode)
	if two_hand:
		request.support_slot = _slot("L" if side == "R" else "R")
	var adapter := IsolationAdapter.new()
	var initialized: Dictionary = adapter.call("_initialize", rig, request)
	var label := "%s_%s_%s_isolation_%s" % [side, "two_hand" if two_hand else "one_hand", mode, enabled]
	_check(initialized.get("valid", false), label + "_initializes", initialized)
	if initialized.get("valid", false):
		var groups: Array = adapter.get("groups")
		var expect_torso := not enabled and two_hand and mode != "tip"
		_check((groups.has(&"torso")) == expect_torso, label + "_correct_torso_parameters", {"groups": groups})
		_check(groups.has(&"shoulder_girdle"), label + "_clavicle_parameters_remain")
	prop.free()

func _make_isolation_prop(side: String) -> Node3D:
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _hand_world(side) * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.08, 0.0))
	prop.set_meta("fixture_hand_in_weapon", {
		&"hand_right": prop.global_transform.affine_inverse() * _hand_world("R"),
		&"hand_left": prop.global_transform.affine_inverse() * _hand_world("L")})
	return prop

func _check_small_motion(side: String) -> void:
	_restore()
	_seed_nondefault_torso()
	var prop := _make_isolation_prop(side)
	var relationship: Transform3D = prop.get_meta("fixture_hand_in_weapon")[_slot(side)]
	var ancestors := _proximal_spine_poses()
	var other := _arm_world_poses("L" if side == "R" else "R")
	for mode: String in ["tip", "pommel", "roll"]:
		var before := prop.global_transform
		var target := before
		if mode == "pommel":
			target.origin += actor_parent.global_basis * Vector3(0.001, 0.001, 0.0)
		else:
			var axis := _hand_world(side).basis.x.normalized() if mode == "tip" else before.basis.z.normalized()
			target = _orbit(before, Vector3.ZERO, axis, deg_to_rad(0.5))
		var result := _allocate(_request(side, prop, target, mode))
		var label := side + "_small_" + mode
		_record(label, result)
		_check(result.get("valid", false) and not _pose_error(before, prop.global_transform), label + "_makes_actual_motion", {"status": result.get("status"), "reason": result.get("reason")})
		_check(_proximal_spine_unchanged(ancestors), label + "_core_remains_fixed")
		_check(_world_poses_unchanged(other), label + "_opposite_arm_remains_fixed")
		_check(_pose_error(prop.global_transform.affine_inverse() * _hand_world(side), relationship), label + "_attachment_retained")
	prop.free()

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("arm_spine_isolation_report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Real imported rig. Nondefault shared ancestors preserved, macro switch reversal and preview-only scope, R/L one/two-hand allocator parameter inclusion, small one-hand motion/contact and independent-arm paths. Synthetic rigid prop; no saved weapon/grip acquisition, pointer latency, complete F/Save or equipped certification."}, "\t"))
	file.close()
	print("ARM_SPINE_ISOLATION passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
