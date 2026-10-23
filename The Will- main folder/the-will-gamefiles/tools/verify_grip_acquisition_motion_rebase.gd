extends SceneTree

const Proof = preload("res://runtime/player/grip/grip_acquisition_motion_rebase.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
var checks := 0
var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pure_guards()
	for slot: StringName in [&"hand_right", &"hand_left"]:
		_test_real_skin_capture(slot)
	print(JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)


func _state() -> Dictionary:
	var hand := Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.3, 1.4, -0.2))
	return {"hand_to_world": hand, "weapon_to_world": hand * Transform3D(Basis.IDENTITY, Vector3(0.01, 0.02, -0.03)),
		"mesh_origin": Vector3.ZERO,
		"dimensions": {&"finger": {"parent": &"hand", "position": Vector3(0.01, 0.02, 0.03), "metric": Basis.IDENTITY}},
		"contributors": {&"forearm": {"anchor": &"hand", "relative": Transform3D(Basis.IDENTITY, Vector3(0, -0.3, 0))}}}


func _test_pure_guards() -> void:
	var source := _state()
	var before := var_to_bytes(source)
	var delta := Transform3D(Basis(Vector3(1, 2, 3).normalized(), 1.1), Vector3(-0.6, 0.8, 1.2))
	var moved := source.duplicate(true)
	moved.hand_to_world = delta * source.hand_to_world
	moved.weapon_to_world = delta * source.weapon_to_world
	moved.mesh_origin = delta * source.mesh_origin
	var valid := Proof.compare_snapshots(source, moved, 0.0)
	_check(valid.get("valid", false) and valid.get("motion_rebased", false), "rigid hand and weapon movement accepted")
	_check(var_to_bytes(source) == before, "source evidence immutable")
	_check((valid.get("delta", Transform3D.IDENTITY) as Transform3D).is_equal_approx(delta), "correct source-to-current transport")
	var wrong := moved.duplicate(true)
	wrong.weapon_to_world.origin += Vector3(0.001, 0, 0)
	_check(not Proof.compare_snapshots(source, wrong, 0.0).get("valid", false), "changed weapon-in-Hand rejected")
	wrong = moved.duplicate(true)
	wrong.hand_to_world.basis *= Basis.from_scale(Vector3(1.01, 1.01, 1.01))
	wrong.weapon_to_world = wrong.hand_to_world * (source.hand_to_world as Transform3D).affine_inverse() * source.weapon_to_world
	_check(not Proof.compare_snapshots(source, wrong, 0.0).get("valid", false), "scale changed despite matching station rejected")
	wrong = moved.duplicate(true)
	wrong.hand_to_world.basis.x += wrong.hand_to_world.basis.y * 0.01
	wrong.weapon_to_world = wrong.hand_to_world * (source.hand_to_world as Transform3D).affine_inverse() * source.weapon_to_world
	_check(not Proof.compare_snapshots(source, wrong, 0.0).get("valid", false), "shear rejected")
	wrong = moved.duplicate(true)
	wrong.dimensions[&"finger"].position.x += 0.001
	_check(not Proof.compare_snapshots(source, wrong, 0.0).get("valid", false), "changed finger dimensions rejected")
	wrong = moved.duplicate(true)
	wrong.dimensions[&"finger"].metric.x.x = 1.01
	_check(not Proof.compare_snapshots(source, wrong, 0.0).get("valid", false), "changed finger metric rejected")
	wrong = moved.duplicate(true)
	wrong.contributors[&"forearm"].relative.basis = Basis(Vector3.UP, 0.05)
	_check(not Proof.compare_snapshots(source, wrong, 0.0).get("valid", false), "changed forearm skin relationship rejected")
	wrong = moved.duplicate(true)
	wrong.mesh_origin += Vector3(0.1, 0, 0)
	_check(Proof.compare_snapshots(source, wrong, 0.000001).get("valid", false), "tiny nonunit-weight residual stays inside numerical guard")
	_check(not Proof.compare_snapshots(source, wrong, 0.01).get("valid", false), "material residual mismatch rejected")


func _test_real_skin_capture(slot: StringName) -> void:
	var space := Node3D.new()
	root.add_child(space)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	space.add_child(skeleton)
	skeleton.add_bone("Root")
	skeleton.add_bone("Forearm")
	skeleton.set_bone_parent(1, 0)
	var hand_name: StringName = &"CC_Base_R_Hand" if slot == &"hand_right" else &"CC_Base_L_Hand"
	skeleton.add_bone(hand_name)
	skeleton.set_bone_parent(2, 1)
	skeleton.set_bone_pose_position(2, Vector3(0, 0.3, 0))
	var selected: Array[StringName] = Rules.get_finger_bone_names(slot)
	for i: int in selected.size():
		skeleton.add_bone(selected[i])
		var index := skeleton.find_bone(selected[i])
		skeleton.set_bone_parent(index, 2 if i % 3 == 0 else index - 1)
		skeleton.set_bone_pose_position(index, Vector3(0, 0.025, 0))
	skeleton.add_bone("FingerExtra")
	var extra := skeleton.find_bone("FingerExtra")
	skeleton.set_bone_parent(extra, skeleton.find_bone(selected[0]))
	skeleton.add_bone("Unrelated")
	var unrelated := skeleton.find_bone("Unrelated")
	skeleton.set_bone_parent(unrelated, 0)
	var skin := Skin.new()
	var reference := {"bind_bone_names": [], "bind_poses": [], "bind_global_rests": [], "surfaces": []}
	for index: int in skeleton.get_bone_count():
		var name := StringName(skeleton.get_bone_name(index))
		skin.add_named_bind(name, Transform3D.IDENTITY)
		reference.bind_bone_names.append(name)
		reference.bind_poses.append(Transform3D.IDENTITY)
		reference.bind_global_rests.append(skeleton.get_bone_global_rest(index))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.02, 0, 0), Vector3(0, 0.02, 0), Vector3(1, 0, 0), Vector3(1.02, 0, 0), Vector3(1, 0.02, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([2, 1, 0, 0, extra, 1, 0, 0, 1, 0, 0, 0, unrelated, 0, 0, 0, unrelated, 0, 0, 0, unrelated, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([0.75, 0.25, 0, 0, 0.75, 0.25, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var mesh := MeshInstance3D.new()
	mesh.mesh = ArrayMesh.new()
	(mesh.mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.skin = skin
	mesh.skeleton = NodePath("../Skeleton")
	space.add_child(mesh)
	var stored: Array = mesh.mesh.surface_get_arrays(0)
	reference.surfaces.append({"vertices": stored[Mesh.ARRAY_VERTEX], "bones": stored[Mesh.ARRAY_BONES], "weights": stored[Mesh.ARRAY_WEIGHTS], "indices": stored[Mesh.ARRAY_INDEX]})
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(2)
	var weapon := hand * Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.01, 0, 0.01))
	var capture: Dictionary = Proof.capture(skeleton, mesh, reference, slot, weapon)
	_check(capture.get("valid", false), String(slot) + " real weighted skin capture: " + str(capture.get("reason", "")))
	if not capture.get("valid", false):
		space.free()
		return
	_check(capture.relevant_vertex_count == 3, String(slot) + " only touching triangle domain")
	_check(&"Forearm" in capture.contributors and &"Unrelated" not in capture.contributors, String(slot) + " full neighbor triangle contributors retained")
	_check(Proof.validate(capture, skeleton, mesh, weapon).get("valid", false), String(slot) + " unchanged scene accepted")
	var delta := Transform3D(Basis(Vector3.UP, 0.65), Vector3(0.4, -0.1, 0.2))
	space.transform = delta
	weapon = delta * weapon
	_check(Proof.validate(capture, skeleton, mesh, weapon).get("valid", false), String(slot) + " whole actor rigid transport accepted")
	skeleton.set_bone_pose_rotation(unrelated, Quaternion(Vector3.UP, 0.5))
	_check(Proof.validate(capture, skeleton, mesh, weapon).get("valid", false), String(slot) + " unrelated body motion does not discard hand solve")
	skeleton.set_bone_pose_rotation(skeleton.find_bone(selected[0]), Quaternion(Vector3.RIGHT, 0.9))
	_check(Proof.validate(capture, skeleton, mesh, weapon).get("valid", false), String(slot) + " closure and extra descendant follow calibrated local chain")
	var before := _poses(skeleton)
	Proof.validate(capture, skeleton, mesh, weapon)
	_check(before == _poses(skeleton), String(slot) + " proof is read-only")
	skeleton.set_bone_pose_position(skeleton.find_bone(selected[1]), Vector3(0, 0.03, 0))
	_check(not Proof.validate(capture, skeleton, mesh, weapon).get("valid", false), String(slot) + " live altered dimensions rejected")
	skeleton.set_bone_pose_position(skeleton.find_bone(selected[1]), Vector3(0, 0.025, 0))
	var old_hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(2)
	skeleton.set_bone_pose_rotation(2, Quaternion(Vector3.UP, 0.3))
	var new_hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(2)
	var rotated_weapon := new_hand * old_hand.affine_inverse() * weapon
	_check(not Proof.validate(capture, skeleton, mesh, rotated_weapon).get("valid", false), String(slot) + " wrist change rejected even if weapon moves with Hand")
	skeleton.set_bone_pose_rotation(2, Quaternion.IDENTITY)
	skin.set_bind_pose(0, Transform3D(Basis.IDENTITY, Vector3(0.001, 0, 0)))
	_check(not Proof.validate(capture, skeleton, mesh, weapon).get("valid", false), String(slot) + " in-place skin bind mutation rejected")
	space.free()


func _poses(skeleton: Skeleton3D) -> Array:
	var result: Array = []
	for index: int in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(index))
	return result
