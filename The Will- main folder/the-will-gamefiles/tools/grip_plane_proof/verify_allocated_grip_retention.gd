extends SceneTree

## Lifecycle proof, not an anatomical or finger-surface solver fixture. The real
## acquisition owner receives already accepted Hand/weapon frames on a named
## RL_BoneRoot chain. A separate saved-Glave run exercises the actual allocator.
const Owner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const RIGHT := &"hand_right"
const LEFT := &"hand_left"
var _checks := 0
var _failures: Array[String] = []

class FixtureAnatomy extends Resource:
	var source_signature := "allocated_grip_retention_fixture"

class FixtureBinding extends RefCounted:
	var states: Dictionary = {}
	func relationship(slot: StringName, _weapon: Node3D) -> Dictionary:
		return states.get(slot, {}).duplicate(true)

class FixtureActor extends Node3D:
	var skeleton: Skeleton3D
	var planar_grip_pose_binding := FixtureBinding.new()
	var standing_height_meters := 2.0
	var allocated := false
	var realization_calls := 0
	var left_hand_ik_target: Node3D
	var right_hand_ik_target: Node3D
	var left_hand_pole_target: Node3D
	var right_hand_pole_target: Node3D
	var _prepared_support_grip_seat: Dictionary = {}
	var _prepared_support_wrist_postures: Dictionary = {}
	var _wrist_motion_states: Dictionary = {}
	var _shoulder_motion_states: Dictionary = {}
	var _wrist_motion_failures: Dictionary = {}
	func has_authoring_weapon_motion_authority() -> bool:
		return allocated
	func clear_authoring_weapon_motion_authority() -> void:
		allocated = false
	func get_planar_grip_pose_state(slot: StringName) -> Dictionary:
		return planar_grip_pose_binding.states.get(slot, {}).duplicate(true)
	func claim_planar_grip_pose(slot: StringName, _weapon: Node3D, key: String) -> Dictionary:
		if planar_grip_pose_binding.states.get(slot, {}).get("relationship_key", "") != key:
			planar_grip_pose_binding.states[slot] = {"has_grip_pose": false, "relationship_key": key}
		return {"valid": true}
	func release_planar_grip_pose(slot: StringName) -> void:
		planar_grip_pose_binding.states.erase(slot)
	func remember_prepared_support_wrist_posture(slot: StringName, key: String) -> void:
		_prepared_support_wrist_postures[slot] = {"key": key, "local": skeleton.get_bone_pose(_hand(slot))}
	func capture_authoring_wrist_origin(slot: StringName) -> Dictionary:
		var machine: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(0)
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_hand(slot))
		var record := Origins.new()
		record.origin_id = Origins.ORIGIN_RIGHT_WRIST if slot == RIGHT else Origins.ORIGIN_LEFT_WRIST
		record.parent_origin_id = Origins.ORIGIN_RL_BONE_ROOT
		record.resolved_transform_to_machine = machine.affine_inverse() * hand
		return {"available": true, "machine_to_world": machine, "origin_record": record}
	func realize_prepared_support_hand_frame(_slot: StringName, _target: Transform3D, _local: Transform3D) -> Dictionary:
		realization_calls += 1
		return {"valid": false, "reason": "fixture_legacy_support_refuses"}
	func _hand(slot: StringName) -> int:
		return skeleton.find_bone("CC_Base_R_Hand" if slot == RIGHT else "CC_Base_L_Hand")

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(message)
		push_error(message)

func _fixture(primary: StringName, two_hands: bool) -> Dictionary:
	var scene := Node3D.new()
	root.add_child(scene)
	scene.transform = Transform3D(Basis(Vector3.UP, 0.35), Vector3(2, 0.5, -3))
	var actor := FixtureActor.new()
	scene.add_child(actor)
	actor.transform = Transform3D(Basis(Vector3.FORWARD, -0.12), Vector3(0.2, 0, 0.1))
	var skeleton := Skeleton3D.new()
	actor.skeleton = skeleton
	actor.add_child(skeleton)
	skeleton.position = Vector3(0.03, 0.05, -0.02)
	skeleton.add_bone("RL_BoneRoot")
	for side: String in ["R", "L"]:
		var hand := skeleton.get_bone_count()
		skeleton.add_bone("CC_Base_" + side + "_Hand")
		skeleton.set_bone_parent(hand, 0)
		skeleton.set_bone_pose_position(hand, Vector3(0.2 if side == "R" else -0.2, 1.1, 0.3))
		var digit := skeleton.get_bone_count()
		skeleton.add_bone("CC_Base_" + side + "_Index1")
		skeleton.set_bone_parent(digit, hand)
		skeleton.set_bone_pose_position(digit, Vector3(0, 0.03, 0))
		skeleton.set_bone_pose_rotation(digit, Quaternion(Vector3.RIGHT, 0.42))
	skeleton.force_update_all_bone_transforms()
	var weapon := Node3D.new()
	scene.add_child(weapon)
	weapon.transform = Transform3D(Basis(Vector3.RIGHT, 0.28), Vector3(0, 1.1, 0.3))
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.set_meta("visual_mesh_source", &"editable_mesh")
	weapon.add_child(mesh)
	weapon.set_meta("preview_primary_grip_seat_local", Vector3(0.1, 0, 0))
	weapon.set_meta("preview_primary_grip_seat_origin_id", Origins.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("preview_support_grip_seat_local", Vector3(-0.1, 0, 0))
	weapon.set_meta("preview_support_grip_seat_origin_id", Origins.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("grip_style_mode", &"grip_normal")
	var support: StringName = LEFT if primary == RIGHT else RIGHT
	var owner := Owner.new()
	actor.add_child(owner)
	owner.set_process(false)
	owner._actor = actor
	owner._weapon = weapon
	owner._skeleton = skeleton
	owner._data = {"valid": true, "anatomy": FixtureAnatomy.new()}
	owner._dominant = primary
	owner._slots.assign([primary, support] if two_hands else [primary])
	for slot: StringName in owner._slots:
		var key: String = Owner.relationship_key(weapon, slot, primary, owner._data.anatomy.source_signature)
		var hand_world: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(actor._hand(slot))
		actor.planar_grip_pose_binding.states[slot] = {"has_grip_pose": true, "relationship_key": key,
			"hand_in_weapon": weapon.global_transform.affine_inverse() * hand_world,
			"digit_states": {"index": {"angle": 0.42}}}
		owner._requests[slot] = {"key": key, "serial": 1, "dominant": primary}
		owner._status[slot] = {"status": "preview_applied", "serial": 1}
	owner._primary_seat = {"key": owner._requests[primary].key, "slot": primary, "last_applied_world": weapon.global_transform}
	if two_hands:
		owner._capture_support_motion_snapshot(support)
	return {"scene": scene, "actor": actor, "owner": owner, "weapon": weapon, "skeleton": skeleton, "primary": primary, "support": support}

func _apply_rigid_motion(f: Dictionary) -> void:
	# Deliberately change both pose-local data and the weapon world frame. The
	# same named machine root carries both hands; stored grip offsets stay fixed.
	var previous: Transform3D = f.skeleton.global_transform * f.skeleton.get_bone_global_pose(0)
	f.skeleton.set_bone_pose_position(0, Vector3(0.04, 0.02, -0.01))
	f.skeleton.set_bone_pose_rotation(0, Quaternion(Vector3.UP, 0.13))
	f.skeleton.force_update_all_bone_transforms()
	var current: Transform3D = f.skeleton.global_transform * f.skeleton.get_bone_global_pose(0)
	f.weapon.global_transform = current * previous.affine_inverse() * f.weapon.global_transform
	f.actor.allocated = true
	f.actor._wrist_motion_states = {f.support: {"rho": -1.58}}
	f.actor._shoulder_motion_states = {f.support: {"h": 0.2}}

func _exercise(primary: StringName, two_hands: bool) -> void:
	var f := _fixture(primary, two_hands)
	var label := String(primary) + (" two hands" if two_hands else " one hand")
	var before: Dictionary = f.actor.planar_grip_pose_binding.states.duplicate(true)
	var old_weapon: Transform3D = f.weapon.global_transform
	_check(not f.owner.accept_authoring_weapon_motion(), "no allocator authority cannot adopt " + label)
	_apply_rigid_motion(f)
	if two_hands:
		# An accepted semantic pose can have a residual below 0.025 degrees but
		# above the old 0.00005-radian threshold. No solver should restart for it.
		var hand: int = f.actor._hand(f.support)
		f.skeleton.set_bone_pose_rotation(hand, Quaternion(Vector3.UP, deg_to_rad(0.02)))
		f.skeleton.force_update_all_bone_transforms()
	var accepted_weapon: Transform3D = f.weapon.global_transform
	var accepted_root: Transform3D = f.skeleton.get_bone_pose(0)
	_check(f.owner.accept_authoring_weapon_motion(), "accepted complete motion adopted " + label)
	_check(f.actor.planar_grip_pose_binding.states == before, "immutable grip packet retained " + label)
	_check(f.weapon.global_transform == accepted_weapon and f.skeleton.get_bone_pose(0) == accepted_root, "adoption does not move body or weapon " + label)
	for side: String in ["R", "L"]:
		var digit: int = f.skeleton.find_bone("CC_Base_" + side + "_Index1")
		_check(f.skeleton.get_bone_pose_rotation(digit).is_equal_approx(Quaternion(Vector3.RIGHT, 0.42)), "digit remains unchanged " + label + side)
	if two_hands:
		_check(f.owner._support_motion_snapshot.weapon_world == accepted_weapon and f.owner._support_motion_snapshot.poses[0] == accepted_root, "fallback advances to accepted frame " + label)
		_check(f.actor._prepared_support_wrist_postures.has(f.support), "accepted support wrist remembered " + label)
	else:
		_check(f.owner._support_motion_snapshot.is_empty(), "single hand creates no support snapshot " + label)
	await process_frame
	f.owner._retain_final_skeleton_grip()
	_check(f.weapon.global_transform == accepted_weapon and f.skeleton.get_bone_pose(0) == accepted_root, "delayed callback retains allocator commit " + label)
	_check(f.actor.realization_calls == 0 and f.owner._support_motion_clamp_count == 0, "delayed callback does not rerun legacy support solver " + label)
	# Leaving allocated motion must not resurrect the old acquisition-time frame.
	f.actor.allocated = false
	var retained: Dictionary = f.owner.retain_support_motion()
	_check(not retained.get("motion_clamped", false) and f.actor.realization_calls == 0, "shared tolerance accepts legal residual on ownership exit " + label)
	if two_hands:
		f.weapon.global_position += Vector3(0.03, 0.01, 0)
		f.actor._wrist_motion_states = {f.support: {"rho": 2.0}}
		f.actor._shoulder_motion_states = {f.support: {"h": 1.0}}
		retained = f.owner.retain_support_motion()
		_check(retained.get("motion_clamped", false), "genuine detached support still guarded " + label)
		var actual: Transform3D = f.weapon.global_transform
		var position_error := actual.origin.distance_to(accepted_weapon.origin)
		var basis_error := maxf(actual.basis.x.distance_to(accepted_weapon.basis.x), maxf(actual.basis.y.distance_to(accepted_weapon.basis.y), actual.basis.z.distance_to(accepted_weapon.basis.z)))
		print(JSON.stringify({"label": label, "fallback_actual": actual, "fallback_expected": accepted_weapon,
			"position_error_m": position_error, "basis_column_error": basis_error}))
		# World assignment through this transformed parent rereads with measured
		# 2.98e-8 Basis rounding and zero position error. Check numerical equality,
		# not bit identity; this is far stricter than the motion contact allowance.
		_check(position_error <= 1.0e-7 and basis_error <= 1.0e-7 and actual != old_weapon, "fallback uses newest accepted weapon frame " + label)
		_check(f.skeleton.get_bone_pose(0) == accepted_root, "fallback uses newest accepted bones " + label)
		_check(is_equal_approx(float(f.actor._wrist_motion_states[f.support].rho), -1.58) and is_equal_approx(float(f.actor._shoulder_motion_states[f.support].h), 0.2), "fallback restores matching semantic continuation " + label)
	f.scene.free()

func _identity_checks() -> void:
	var f := _fixture(RIGHT, true)
	_apply_rigid_motion(f)
	_check(f.owner.accept_authoring_weapon_motion(), "identity fixture adopts accepted motion")
	var snapshot: Dictionary = f.owner._support_motion_snapshot.duplicate(true)
	f.owner.synchronize(f.owner._slots.duplicate(), RIGHT)
	_check(f.owner._owns_allocated_motion() and f.actor.allocated, "unchanged request preserves allocator ownership")
	_check(f.owner._queue.is_empty() and f.owner._support_motion_snapshot == snapshot, "unchanged request does not invalidate pose or queue acquisition")
	f.weapon.set_meta("preview_support_grip_seat_local", Vector3(-0.12, 0, 0))
	f.owner.synchronize(f.owner._slots.duplicate(), RIGHT, &"handle_position_changed")
	_check(not f.owner._owns_allocated_motion() and not f.actor.allocated, "changed support request releases allocator ownership")
	_check(f.owner._allocated_motion_identity.is_empty() and f.owner._support_motion_snapshot.is_empty(), "changed support request removes stale allocation snapshot")
	_check(f.owner._queue.has(LEFT), "changed support station requests new acquisition")
	f.scene.free()
	f = _fixture(LEFT, true)
	_apply_rigid_motion(f)
	_check(f.owner.accept_authoring_weapon_motion(), "reacquisition fixture adopts accepted motion")
	f.owner.reacquire()
	_check(not f.actor.allocated and not f.owner._owns_allocated_motion(), "explicit reacquisition releases allocator authority")
	_check(f.owner._queue.has(LEFT) and f.owner._queue.has(RIGHT), "explicit reacquisition renews both hands")
	f.scene.free()

func _rejection_checks() -> void:
	var f := _fixture(RIGHT, true)
	_apply_rigid_motion(f)
	var snapshot: Dictionary = f.owner._support_motion_snapshot.duplicate(true)
	for reason: String in ["missing_binding", "pending", "busy", "manual"]:
		match reason:
			"missing_binding": f.actor.planar_grip_pose_binding.states[LEFT].has_grip_pose = false
			"pending": f.owner._queue.assign([LEFT])
			"busy": f.owner._busy = true
			"manual": f.owner._manual_reacquisition_required = true
		_check(not f.owner.accept_authoring_weapon_motion(), "refuse adoption: " + reason)
		_check(f.owner._support_motion_snapshot == snapshot, "refusal preserves previous snapshot: " + reason)
		f.actor.planar_grip_pose_binding.states[LEFT].has_grip_pose = true
		f.owner._queue.clear()
		f.owner._busy = false
		f.owner._manual_reacquisition_required = false
	f.scene.free()

func _run() -> void:
	for primary: StringName in [RIGHT, LEFT]:
		await _exercise(primary, true)
		await _exercise(primary, false)
	_rejection_checks()
	_identity_checks()
	print(JSON.stringify({"checks": _checks, "failures": _failures, "scope": "allocated grip retention lifecycle; mocked allocator and anatomical solve"}))
	quit(0 if _failures.is_empty() else 1)
