extends SceneTree

const RigScript = preload("res://runtime/player/player_humanoid_rig.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")

var failures: PackedStringArray = []
var checks: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	# A real Skeleton3D with nonidentity ancestors exposes missing root inverses,
	# lost basis/scale, and confusion between skeleton-global and world space.
	var scene := Node3D.new()
	root.add_child(scene)
	scene.transform = Transform3D(Basis(Vector3.UP, 0.61), Vector3(4.0, -2.0, 7.0))
	var fixture := Skeleton3D.new()
	scene.add_child(fixture)
	fixture.transform = Transform3D(Basis(Vector3.RIGHT, -0.27).scaled(Vector3.ONE * 0.764), Vector3(0.3, 1.1, -0.4))
	for bone_name: String in ["PresentationRoot", "RL_BoneRoot", "Forearm", "CC_Base_R_Hand", "CC_Base_L_Hand"]:
		fixture.add_bone(bone_name)
	for bone_index: int in range(1, 5):
		fixture.set_bone_parent(bone_index, 2 if bone_index >= 3 else bone_index - 1)
		fixture.set_bone_pose_position(bone_index, Vector3(0.11 * bone_index, 0.16, -0.07))
		fixture.set_bone_pose_rotation(bone_index, Quaternion(Vector3.FORWARD, 0.13 * bone_index))
	fixture.force_update_all_bone_transforms()
	# The rig stays outside the tree: this verifier exercises the read-only origin
	# capture API, without initializing locomotion, grip solvers or player saves.
	var rig = RigScript.new()
	rig.skeleton = fixture
	var before: Array[Transform3D] = []
	for bone_index: int in range(fixture.get_bone_count()):
		before.append(fixture.get_bone_pose(bone_index))
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var captured: Dictionary = rig.capture_authoring_wrist_origin(slot)
		_check(bool(captured.get("available", false)), "%s available" % slot)
		if not bool(captured.get("available", false)):
			continue
		var expected_id: StringName = OriginScript.ORIGIN_RIGHT_WRIST if slot == &"hand_right" else OriginScript.ORIGIN_LEFT_WRIST
		var hand_index: int = 3 if slot == &"hand_right" else 4
		var record: Resource = captured["origin_record"]
		var registry = captured["registry"]
		_check(captured["wrist_origin_id"] == expected_id, "%s named wrist" % slot)
		_check(record.parent_origin_id == OriginScript.ORIGIN_RL_BONE_ROOT, "%s machine parent" % slot)
		_check(record.resolve_phase == OriginScript.PHASE_POST_FINAL_POSE and record.is_dynamic, "%s phase and lifetime" % slot)
		_check(bool(registry.validate_origin_chain(expected_id).get("ok", false)), "%s validated registry chain" % slot)
		var wrist_to_machine: Transform3D = registry.resolve_transform_to_machine(expected_id)
		var reconstructed_world: Transform3D = captured["machine_to_world"] * wrist_to_machine
		var actual_world: Transform3D = fixture.global_transform * fixture.get_bone_global_pose(hand_index)
		_check(reconstructed_world.is_equal_approx(actual_world), "%s full world round trip" % slot)
		var expected_machine: Transform3D = fixture.get_bone_global_pose(1).affine_inverse() * fixture.get_bone_global_pose(hand_index)
		_check(wrist_to_machine.is_equal_approx(expected_machine), "%s root-relative basis and position" % slot)
	for bone_index: int in range(fixture.get_bone_count()):
		_check(before[bone_index].is_equal_approx(fixture.get_bone_pose(bone_index)), "capture does not write bone %d" % bone_index)
	var first: Dictionary = rig.capture_authoring_wrist_origin(&"hand_right")
	fixture.set_bone_pose_position(3, Vector3(0.7, -0.2, 0.3))
	fixture.set_bone_pose_rotation(3, Quaternion(Vector3.UP, 0.9))
	var moved: Dictionary = rig.capture_authoring_wrist_origin(&"hand_right")
	_check(bool(moved.get("available", false)), "changed pose recaptured")
	if bool(first.get("available", false)) and bool(moved.get("available", false)):
		_check(not first["origin_record"].transform_to_parent.is_equal_approx(moved["origin_record"].transform_to_parent), "capture refreshes dynamic frame")
	_check(not bool(rig.capture_authoring_wrist_origin(&"invalid_slot").get("available", false)), "unknown slot rejected")
	fixture.set_bone_parent(3, 0)
	_check(not bool(rig.capture_authoring_wrist_origin(&"hand_right").get("available", false)), "hand outside machine ancestry rejected")
	fixture.set_bone_parent(3, 2)
	fixture.set_bone_name(3, "MissingRightHand")
	_check(not bool(rig.capture_authoring_wrist_origin(&"hand_right").get("available", false)), "missing hand rejected")
	fixture.set_bone_name(3, "CC_Base_R_Hand")
	fixture.set_bone_name(1, "MissingMachineRoot")
	_check(not bool(rig.capture_authoring_wrist_origin(&"hand_right").get("available", false)), "missing root rejected")
	fixture.set_bone_name(1, "RL_BoneRoot")
	fixture.transform = Transform3D(Basis.from_scale(Vector3(0.0, 1.0, 1.0)), fixture.position)
	_check(not bool(rig.capture_authoring_wrist_origin(&"hand_right").get("available", false)), "singular presentation rejected")
	scene.remove_child(fixture)
	_check(not bool(rig.capture_authoring_wrist_origin(&"hand_right").get("available", false)), "missing scene/world frame rejected")
	fixture.free()
	rig.skeleton = null
	_check(not bool(rig.capture_authoring_wrist_origin(&"hand_right").get("available", false)), "missing skeleton rejected")
	rig.free()
	scene.free()
	print("WRIST_ORIGIN_RESULT=" + JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
