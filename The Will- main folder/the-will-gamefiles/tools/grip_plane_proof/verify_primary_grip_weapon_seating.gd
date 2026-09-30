extends SceneTree

## Reuse saved full-hand proposals; exercise the production primary application
## on an isolated real rig. No acquisition search or support-hand implementation.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Owner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const Data = preload("res://runtime/player/grip/character_grip_data.gd")
const Job = preload("res://runtime/player/grip/handle_grip_acquisition.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Assessment = preload("res://runtime/player/grip/realized_grip_assessment.gd")
const ROOT := &"RL_BoneRoot"
const SOURCE := "C:/WORKSPACE/test_artifacts/full_hand_grip_process_2026-09-27T09-05-46.json"
const SOURCE_SHA := "98f81ae6d7b2cd1e3c6fd971770b5041e555401ee9ba1e417c475f0d11b014d8"
var _checks := 0
var _failures: Array[String] = []
var _cases: Array = []

func _init() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		_failures.append(label)
		push_error(label)
	return value

func _run() -> void:
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not expected.begins_with("c:/workspace/") or expected != OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower():
		push_error("Requires isolated workspace user data"); quit(1); return
	if not _check(FileAccess.get_sha256(SOURCE) == SOURCE_SHA, "exact saved full-hand report"):
		_finish(); return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for source: Dictionary in report.cases:
		await _case(source)
	_finish()

func _case(source: Dictionary) -> void:
	var slot := StringName(source.slot)
	var path: String = source.source_trace
	if not _check(path.begins_with("C:/WORKSPACE/test_artifacts/") and FileAccess.get_sha256(path) == source.source_trace_sha256, str(slot) + " exact adapted source trace"):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var trace: Dictionary = file.get_var(false); file.close()
	var stage: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.serial == source.source_transaction:
			stage = transaction.finger_inputs[-1]
	if not _check(not stage.is_empty() and stage.transaction_serial == source.source_transaction, "matching source transaction"):
		return
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)
	rig.set_process(false)
	for node: Node in rig.find_children("*", "", true, false):
		if node is AnimationPlayer: node.stop()
		if node is AnimationTree: node.active = false
		if node is SkeletonModifier3D: node.active = false
	rig.get("finger_grip_presenter")._ensure_animation_grip_baseline_cache()
	var data: Dictionary = Data.load_for_actor(rig)
	if not _check(data.get("valid", false) and trace.anatomy_signature == data.anatomy.source_signature, "real rig prepared anatomy identity"):
		rig.free(); return
	var job := Job.new()
	if not _check(job.configure(data.anatomy, stage, data.config, rig).get("valid", false), "saved candidate configuration"):
		rig.free(); return
	var context: Dictionary = job._prepare(data.anatomy, stage)
	if not _check(context.get("valid", false), "current code prepares exact saved geometry"):
		_cases.append(context); rig.free(); return
	var parameters: Array = job._clamped(context, source.selected.parameters)
	for i: int in parameters.size():
		_check(absf(parameters[i] - source.selected.parameters[i]) < 1.0e-12, "saved parameter remains within current limits " + str(i))
	var translation: Vector3 = context.translation_u_world * parameters[-2] + context.translation_v_world * parameters[-1]
	_check(translation.distance_to(_v(source.selected.translation_world)) < 1.0e-8, "same saved transverse displacement")
	var candidate: Dictionary = job._rigid_candidate(context, parameters, translation)
	if not _check(candidate.get("valid", false), "saved proposal reconstructed"):
		rig.free(); return
	# Re-measure only the selected material state using current shared code.
	# No historical implementation hash is silently treated as current code.
	job._set_phase("circle", 0.0)
	var sampled: Dictionary = job._circle_sample(context, parameters, 0.0, true)
	_check(sampled.get("valid", false) and sampled.get("material_safe", false) == source.selected.material_safe, "current selected material safety matches saved source")
	_check(sampled.get("material_contacts", []) == source.selected.material_contacts, "current selected material contacts match saved source")
	var skeleton: Skeleton3D = rig.get("skeleton")
	if not _restore(skeleton, stage.posed_character):
		rig.free(); return
	var weapon := Node3D.new(); root.add_child(weapon)
	weapon.global_transform = stage.object.weapon_to_world
	for end: String in ["start", "end"]:
		weapon.set_meta("primary_grip_span_" + end + "_local", stage.object["primary_grip_span_" + end + "_local"])
		weapon.set_meta("primary_grip_span_" + end + "_origin_id", &"WeaponRootOrigin")
	weapon.set_meta("preview_primary_grip_seat_local", stage.object.grip_pivot_local)
	weapon.set_meta("preview_primary_grip_seat_origin_id", &"WeaponRootOrigin")
	var mesh_node := MeshInstance3D.new()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = stage.object.local_faces
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_node.mesh = mesh; mesh_node.set_meta("visual_mesh_source", &"editable_mesh")
	weapon.add_child(mesh_node); mesh_node.global_transform = stage.object.mesh_to_world
	var owner := Owner.new(); owner.name = Owner.NODE_NAME; rig.add_child(owner); owner.set_process(false)
	_check(owner.configure(rig, weapon), "production preview owner configured")
	var slots: Array[StringName] = [slot]
	owner.synchronize(slots, slot)
	var request: Dictionary = owner.get("_requests")[slot].duplicate()
	var before := _poses(skeleton)
	var hand_index := skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	var hand_before: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	var weapon_before := weapon.global_transform
	var stamp := owner._realization_stamp()
	var result := {"valid": true, "selected": sampled, "candidate": candidate,
		"weapon_to_world": weapon_before, "vectors_origin_id": ROOT}
	# An asynchronous job cannot apply after an unannounced upstream pose edit.
	var old_rotation := skeleton.get_bone_pose_rotation(hand_index)
	skeleton.set_bone_pose_rotation(hand_index, (old_rotation * Quaternion(Vector3.RIGHT, 0.01)).normalized())
	var edited := _poses(skeleton)
	_check(not owner.apply_primary_result(slot, request, result, stamp).get("valid", false), "stale pose rejected")
	_check(_poses(skeleton) == edited and weapon.global_transform == weapon_before, "stale rejection writes nothing")
	skeleton.set_bone_pose_rotation(hand_index, old_rotation)
	var axial_fault: Dictionary = result.duplicate(true)
	axial_fault.candidate.translation_world += context.station_axis_world * 0.001
	axial_fault.candidate.hand_to_world.origin += context.station_axis_world * 0.001
	_check(not owner.apply_primary_result(slot, request, axial_fault, stamp).get("valid", false), "axial seating rejected")
	_check(_poses(skeleton) == before and weapon.global_transform == weapon_before, "axial rejection writes nothing")
	var applied: Dictionary = owner.apply_primary_result(slot, request, result, stamp)
	if not _check(applied.get("valid", false), "production inverse placement applied: " + str(applied.get("reason", ""))):
		_cases.append(applied); weapon.free(); rig.free(); return
	var names: Array[StringName] = Job.Rules.get_finger_bone_names(slot)
	_check(weapon.global_basis == weapon_before.basis, "weapon orientation and scale unchanged")
	_check(weapon.global_position.distance_to(weapon_before.origin - translation) < 1.0e-7, "weapon receives negative proposal translation")
	_check(absf((weapon.global_position - weapon_before.origin).dot(context.station_axis_world)) < Owner.SEAT_AXIAL_GUARD_M, "handle percentage not changed by seating")
	_check((skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)) == hand_before, "Hand and wrist frame exactly fixed")
	for index: int in skeleton.get_bone_count():
		if skeleton.get_bone_name(index) not in names:
			_check(skeleton.get_bone_pose(index) == before[index], "non-digit bone unchanged " + str(index))
		else:
			_check(skeleton.get_bone_pose_position(index) == before[index].origin and skeleton.get_bone_pose_scale(index).is_equal_approx(before[index].basis.get_scale()), "digit dimensions preserved " + str(index))
	_check((weapon.global_transform.affine_inverse() * hand_before).is_equal_approx(weapon_before.affine_inverse() * candidate.hand_to_world), "same solved Hand-in-weapon relationship without arm IK")
	var pivot := {"point_local": stage.object.grip_pivot_local, "origin_id": &"WeaponRootOrigin", "source": "saved_named_station"}
	var actual: Dictionary = await owner._capture_realized(slot, request, pivot)
	_check(actual.get("valid", false), "actual skin captured at final skeleton signal")
	var assessed: Dictionary = {}
	if actual.get("valid", false):
		var assessor := Assessment.new()
		assessed = await assessor.assess(data.anatomy, actual, data.config, rig)
		_check(assessed.get("material_query_valid", false), "actual skin material query completed")
		for index: int in skeleton.get_bone_count():
			if skeleton.get_bone_name(index) not in names:
				_check(skeleton.get_bone_pose(index) == before[index], "observer preserves non-digit bone " + str(index))
	var seated := weapon.global_transform
	owner.recompose_primary_seat(); owner.recompose_primary_seat()
	_check(weapon.global_transform == seated, "repeated final seam does not accumulate seat")
	weapon.global_transform = weapon_before
	owner.recompose_primary_seat()
	_check(weapon.global_transform.is_equal_approx(seated), "macro rebuild recomposes same seat")
	owner.retain_roll()
	var roll_retained := weapon.global_transform
	owner.recompose_primary_seat()
	_check(weapon.global_transform == roll_retained, "retained pose does not receive duplicate correction")
	var station: Vector3 = weapon.get_meta("preview_primary_grip_seat_local")
	weapon.set_meta("preview_primary_grip_seat_local", station + Vector3(0.0, 0.001, 0.0))
	owner.synchronize(slots, slot)
	_check(owner.get("_primary_seat").is_empty(), "handle station edit discards old seat")
	_check(not owner._is_current(slot, request), "handle station edit invalidates old result")
	owner.clear()
	_check(not rig.get_planar_grip_pose_state(slot).get("owned", true), "release restores separate unarmed route")
	_cases.append({"slot": slot, "source_transaction": source.source_transaction,
		"inverse_placement_applied": applied.valid, "saved_material_contacts": source.selected.material_contacts,
		"actual_material_safe": assessed.get("actual_material_safe", false),
		"actual_material_contacts": assessed.get("actual_material_contacts", []),
		"actual_articulation_valid": assessed.get("articulation_valid", false),
		"actual_articulation": assessed.get("actual_articulation", {}),
		"actual_query_reason": assessed.get("reason", ""),
		"translation_m": translation.length(), "upstream_ik_invoked": false,
		"search_performed": false, "actual_3d_grip_verified": false})
	weapon.free(); rig.free()
	await process_frame

func _restore(skeleton: Skeleton3D, pose: Dictionary) -> bool:
	var registered: Dictionary = HandSkin.new()._registry(pose.origin_records, pose.resolve_phase)
	if not _check(registered.get("valid", false), "source origin chain valid"): return false
	var root_index := skeleton.find_bone(ROOT)
	skeleton.global_transform = pose.machine_to_world * skeleton.get_bone_global_pose(root_index).affine_inverse()
	var entries: Array[Dictionary] = []
	for name: StringName in pose.bone_origin_ids:
		var index := skeleton.find_bone(name)
		if not _check(index >= 0, "captured bone exists " + str(name)): return false
		var frame: Transform3D = registered.registry.resolve_transform_to_machine(pose.bone_origin_ids[name])
		entries.append({"index": index, "depth": _depth(skeleton, index), "world": pose.machine_to_world * frame})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for entry: Dictionary in entries:
		skeleton.set_bone_global_pose(entry.index, skeleton.global_transform.affine_inverse() * (entry.world as Transform3D))
	for entry: Dictionary in entries:
		var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(entry.index)
		if not _check(actual.origin.distance_to(entry.world.origin) < 0.000005 and actual.basis.is_equal_approx(entry.world.basis), "restored captured frame " + str(entry.index)): return false
	return true

func _depth(skeleton: Skeleton3D, index: int) -> int:
	var depth := 0
	while index >= 0:
		depth += 1; index = skeleton.get_bone_parent(index)
	return depth

func _poses(skeleton: Skeleton3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): out.append(skeleton.get_bone_pose(index))
	return out

func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func _finish() -> void:
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures,
		"cases": _cases, "source_report": SOURCE, "source_sha256": SOURCE_SHA,
		"scope": "saved_candidates_on_frozen_real_rig_using_production_primary_application",
		"search_performed": false, "support_integration_tested": false, "actual_3d_grip_verified": false}
	var path := "C:/WORKSPACE/test_artifacts/verify_primary_grip_weapon_seating_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("PRIMARY_SEAT_RESULT=" + path + " checks=" + str(_checks) + " failures=" + str(_failures))
	quit(0 if _failures.is_empty() else 1)
