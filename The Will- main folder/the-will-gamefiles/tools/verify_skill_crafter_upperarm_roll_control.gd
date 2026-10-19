extends SceneTree

const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const PresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const MotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")
const ANGLE_EPSILON_DEGREES := 0.1
const POSITION_EPSILON_METERS := 0.0005

var checks: Array[Dictionary] = []
var output_path := "C:/WORKSPACE/godot_runs/verify_skill_crafter_upperarm_roll_control.json"

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
	call_deferred("_run")

func _run() -> void:
	var rig: PlayerHumanoidRig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	var trajectory := Node3D.new()
	root.add_child(trajectory)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.0
	viewport.add_child(camera)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	var presenter := PresenterScript.new()
	var sk: Skeleton3D = rig.get_node("JosieModel/Josie/Skeleton3D") as Skeleton3D
	for yaw: float in [0.0, 75.0]:
		rig.rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
		rig.set_upper_body_authoring_state({
			"active": true, "blend": 1.0, "two_hand": true, "dominant_slot_id": &"hand_right",
			"primary_target_world": rig.to_global(Vector3(0.32, 1.20, -0.68)),
			"secondary_target_world": rig.to_global(Vector3(-0.22, 1.18, -0.52)),
			"tip_world": rig.to_global(Vector3(0.58, 1.42, -1.08)),
			"pommel_world": rig.to_global(Vector3(0.18, 1.02, -0.44)),
		})
		rig.apply_authoring_preview_frame_now(false)
		for side: String in ["R", "L"]:
			_exercise(rig, sk, presenter, trajectory, camera, side, yaw)
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check["passed"])
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Elbow control reference and pointer contract; not anatomical or grip certification."}, "\t"))
		file.close()
	else:
		passed = false
	print("UPPERARM_ROLL_CONTROL passed=%s checks=%d output=%s" % [str(passed), checks.size(), output_path])
	quit(0 if passed else 1)

func _exercise(rig: PlayerHumanoidRig, sk: Skeleton3D, presenter: RefCounted, trajectory: Node3D, camera: Camera3D, side: String, yaw: float) -> void:
	var slot: StringName = &"hand_left" if side == "L" else &"hand_right"
	var label := "%s_yaw_%.0f" % [side, yaw]
	_apply_roll(rig, side, 45.0 if side == "R" else -55.0)
	var state: Dictionary = presenter.call("_build_upperarm_roll_gizmo_state", sk, trajectory, slot, 0.0, rig)
	_check(not state.is_empty(), label + "_control_available")
	if state.is_empty(): return
	var initial: Dictionary = rig.get_authoring_upperarm_roll_control_state(slot)
	_check(absf(float(state["initial_roll_degrees"])) > 1.0, label + "_visible_angle_not_stored_zero")
	var editor := MotionNodeEditorScript.new()
	editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, _pointer(camera, state, 0.0))
	_check(editor.resolve_upperarm_roll_drag(camera, _pointer(camera, state, 0.0)) == null, label + "_unmoved_grab_does_not_author")
	var target: Variant = editor.resolve_upperarm_roll_drag(camera, _pointer(camera, state, 3.0))
	_check(target != null, label + "_small_drag_resolves")
	if target == null: return
	_check(_angle_error(float(target), float(initial["initial_roll_degrees"]) + 3.0) <= ANGLE_EPSILON_DEGREES, label + "_small_drag_uses_visible_reference")
	var hand_before := _position(sk, "CC_Base_%s_Hand" % side)
	_apply_roll(rig, side, float(target))
	var after: Dictionary = rig.get_authoring_upperarm_roll_control_state(slot)
	_check(_angle_error(float(after["initial_roll_degrees"]), float(target)) <= ANGLE_EPSILON_DEGREES, label + "_rig_reaches_pointer_angle")
	_check(hand_before.distance_to(_position(sk, "CC_Base_%s_Hand" % side)) <= POSITION_EPSILON_METERS, label + "_manual_roll_holds_hand_position")
	var returned: Variant = editor.resolve_upperarm_roll_drag(camera, _pointer(camera, state, 0.0))
	_check(returned != null and _angle_error(float(returned), float(initial["initial_roll_degrees"])) <= ANGLE_EPSILON_DEGREES, label + "_return_to_grab_after_moving_is_valid")
	editor.end_drag()
	# Re-grab a realized pose even when the authored value differs from it.
	state = presenter.call("_build_upperarm_roll_gizmo_state", sk, trajectory, slot, -123.0, rig)
	editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, _pointer(camera, state, 0.0))
	target = editor.resolve_upperarm_roll_drag(camera, _pointer(camera, state, -2.0))
	_check(target != null and _angle_error(float(target), float(after["initial_roll_degrees"]) - 2.0) <= ANGLE_EPSILON_DEGREES, label + "_regrab_ignores_stale_authored_angle")
	editor.end_drag()
	_apply_roll(rig, side, 179.0)
	state = presenter.call("_build_upperarm_roll_gizmo_state", sk, trajectory, slot, 179.0, rig)
	editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, _pointer(camera, state, 0.0))
	target = editor.resolve_upperarm_roll_drag(camera, _pointer(camera, state, 4.0))
	_check(target != null and _angle_error(float(target), -177.0) <= ANGLE_EPSILON_DEGREES, label + "_wrap_keeps_small_positive_motion")
	if target != null:
		_apply_roll(rig, side, float(target))
		after = rig.get_authoring_upperarm_roll_control_state(slot)
		_check(_angle_error(float(after["initial_roll_degrees"]), -177.0) <= ANGLE_EPSILON_DEGREES, label + "_wrapped_target_realized")
	editor.end_drag()
	var upper_index := sk.find_bone("CC_Base_%s_Upperarm" % side)
	var forearm_index := sk.find_bone("CC_Base_%s_Forearm" % side)
	var upper_before := sk.get_bone_pose_rotation(upper_index)
	var forearm_before := sk.get_bone_pose_rotation(forearm_index)
	_apply_roll(rig, side, 0.0)
	_check(upper_before.is_equal_approx(sk.get_bone_pose_rotation(upper_index)) and forearm_before.is_equal_approx(sk.get_bone_pose_rotation(forearm_index)), label + "_legacy_zero_remains_automatic")
	_exercise_press_calibration(camera, state, label)

func _exercise_press_calibration(camera: Camera3D, state: Dictionary, label: String) -> void:
	var center: Vector3 = state["center_global"]
	var axis: Vector3 = state["axis_global"]
	var normal: Vector3 = state["initial_normal_global"]
	var tangent := axis.cross(normal).normalized()
	for view: String in ["oblique", "rear", "off_center"]:
		var direction: Vector3 = axis if view == "off_center" else (axis * 0.65 + normal * (0.75 if view == "oblique" else -0.75)).normalized()
		camera.global_position = center + direction * 2.0
		camera.look_at(center, tangent)
		# Stay inside the sphere silhouette while pressing away from its exact
		# visible handle center, as the screen-space pick radius allows in the UI.
		var press := camera.unproject_position(center + normal * float(state["radius_meters"]) * 0.9)
		var editor := MotionNodeEditorScript.new()
		editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, press)
		_check(editor.resolve_upperarm_roll_drag(camera, press) == null, label + "_" + view + "_unchanged_press_is_noop")
		var moved: Variant = null
		for offset: Vector2 in [Vector2(0.25, 0.0), Vector2(0.0, 0.25)]:
			moved = editor.resolve_upperarm_roll_drag(camera, press + offset)
			if moved != null: break
		_check(moved != null and _angle_error(float(moved), float(state["initial_roll_degrees"])) < 5.0, label + "_" + view + "_small_pointer_has_small_angle")
		checks[-1]["angle_change_degrees"] = _angle_error(float(moved), float(state["initial_roll_degrees"])) if moved != null else null
		checks[-1]["viewport_size"] = str(camera.get_viewport().get_visible_rect().size)
		var returned: Variant = editor.resolve_upperarm_roll_drag(camera, press)
		_check(returned != null and _angle_error(float(returned), float(state["initial_roll_degrees"])) <= ANGLE_EPSILON_DEGREES, label + "_" + view + "_return_to_press_restores_angle")
		editor.end_drag()
		var exact_press := camera.unproject_position(center + normal * float(state["radius_meters"]))
		editor.begin_upperarm_roll_drag(state["drag_target"], state, camera, exact_press)
		var moved_normal: Vector3 = Basis(axis, deg_to_rad(3.0)) * normal
		var exact_move := camera.unproject_position(center + moved_normal * float(state["radius_meters"]))
		var directed: Variant = editor.resolve_upperarm_roll_drag(camera, exact_move)
		_check(directed != null and _angle_error(float(directed), float(state["initial_roll_degrees"]) + 3.0) <= ANGLE_EPSILON_DEGREES, label + "_" + view + "_selected_sphere_side_preserves_direction")
		editor.end_drag()

func _apply_roll(rig: PlayerHumanoidRig, side: String, degrees: float) -> void:
	var state: Dictionary = rig.get_upper_body_authoring_state()
	state["left_upperarm_roll_degrees" if side == "L" else "right_upperarm_roll_degrees"] = degrees
	rig.set_upper_body_authoring_state(state)
	rig.call("_apply_authoring_manual_upperarm_roll_pose", &"hand_left" if side == "L" else &"hand_right", StringName("CC_Base_%s_Upperarm" % side), StringName("CC_Base_%s_Forearm" % side), StringName("CC_Base_%s_Hand" % side))

func _pointer(camera: Camera3D, state: Dictionary, delta_degrees: float) -> Vector2:
	var center: Vector3 = state["center_global"]
	var axis: Vector3 = state["axis_global"]
	var normal: Vector3 = state["initial_normal_global"]
	camera.global_position = center + axis * 2.0
	camera.look_at(center, normal)
	var moved: Vector3 = Basis(axis, deg_to_rad(delta_degrees)) * normal
	return camera.unproject_position(center + moved * float(state["radius_meters"]) * 0.95)

func _position(sk: Skeleton3D, name: String) -> Vector3:
	return sk.to_global(sk.get_bone_global_pose(sk.find_bone(name)).origin)

func _angle_error(a: float, b: float) -> float:
	return absf(wrapf(a - b + 180.0, 0.0, 360.0) - 180.0)

func _check(passed: bool, label: String) -> void:
	checks.append({"check": label, "passed": passed})
	if not passed: push_error("UPPERARM_ROLL_CONTROL " + label)
