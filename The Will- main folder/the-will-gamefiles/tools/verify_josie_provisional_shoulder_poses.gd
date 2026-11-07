extends SceneTree

## Pose-review fixture, NOT an anatomical acceptance oracle or allocator test.
## Actual imported pose translations/scales remain unchanged. Fixture rotations
## construct a fixed chest-relative h=0 centre, elbow90, wrist neutral; +/-10
## trials always start from that same centre. No profile or player save writes.
## Source: Shoulder and Forearm Rotation Limits for Josie (1).md, missing-sample
## rules. Ten degrees is an inspection increment; 15 degrees is a local gap cap.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Calibration = preload("res://runtime/player/combat_shoulder_rig_calibration.gd")
const Shoulder = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const Wrist = preload("res://core/resolvers/combat_wrist_motion_resolver.gd")
const TILE := Vector2i(480, 640)
const POSITION_EPSILON := 0.00005
const ANGLE_EPSILON := deg_to_rad(0.025)
var output_dir := "C:/WORKSPACE/godot_runs/josie_provisional_shoulder"
var screenshots := true
var rig: PlayerHumanoidRig
var skeleton: Skeleton3D
var baseline: Array[Transform3D] = []
var views: Array[SubViewport] = []
var cameras: Array[Camera3D] = []
var checks: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var references: Array[Dictionary] = []
var html := "<!doctype html><meta charset='utf-8'><title>Josie shoulder pose review</title><style>body{background:#222;color:#eee;font:16px sans-serif}img{max-width:100%}section{margin:2em 0}</style><h1>Fixed candidate shoulder centres</h1><p>Each image: columns -10, 0, +10 degrees; top front, bottom active-arm side. Checked mechanics and collision proxies do not establish anatomical validity. Profile rows require human review. No weapon or grip is present.</p>"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="): output_dir = argument.trim_prefix("--out-dir=")
		if argument == "--no-screenshots": screenshots = false
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(TILE.x * 2, TILE.y)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in rig.find_children("*", "AnimationTree", true, false): (node as AnimationTree).active = false
	for node: Node in rig.find_children("*", "AnimationPlayer", true, false): (node as AnimationPlayer).stop(true)
	for node: Node in rig.find_children("*", "SkeletonModifier3D", true, false): (node as SkeletonModifier3D).active = false
	skeleton = rig.skeleton
	if skeleton == null:
		_check(false, "skeleton_missing")
		_finish()
		return
	baseline = _poses()
	if screenshots: _build_views()
	var cases: Array[Dictionary] = []
	for elevation: float in [30.0, 60.0, 120.0, 150.0]:
		for plane: float in [0.0, 45.0, 90.0]:
			cases.append({"id": "e%d_p%d" % [elevation, plane], "elevation": elevation, "plane": plane,
				"region": "anterior_lowered" if elevation < 90.0 else ("anterior_raised" if elevation < 150.0 else "overhead")})
	cases.append({"id": "e180_p45", "elevation": 180.0, "plane": 45.0, "region": "overhead"})
	cases.append({"id": "e30_pm90", "elevation": 30.0, "plane": -90.0, "region": "posterior"})
	cases.append({"id": "e90_pm30", "elevation": 90.0, "plane": -30.0, "region": "posterior"})
	for side: String in ["R", "L"]:
		_restore(baseline)
		var calibration: Dictionary = Calibration.build(skeleton, _slot(side))
		_check(calibration.get("valid", false), side + "_fixed_rest_calibration")
		if not calibration.get("valid", false): continue
		# Separate paired-study zero check, not another provisional interval.
		var reference := _seed_centre(side, _direction(2.0, 0.0, side), calibration)
		if reference.get("valid", false):
			var data := _observe(side, calibration, 0.0)
			var chest_frame: Basis = _chest_frame(calibration)
			var distal: Vector3 = (data.wrist_skeleton - data.elbow_skeleton).normalized()
			data["forearm_forward_error_degrees"] = rad_to_deg(distal.angle_to(-chest_frame.z))
			data["reference"] = "2 degree abduction, h=0 engineering convention; forearm should face forward"
			_check(float(data.forearm_forward_error_degrees) <= rad_to_deg(ANGLE_EPSILON), side + "_lowered_zero_forearm_forward")
			references.append(data)
		for spec: Dictionary in cases:
			await _review_row(side, spec, calibration)
	_restore(baseline)
	_finish()

func _review_row(side: String, spec: Dictionary, calibration: Dictionary) -> void:
	_restore(baseline)
	var direction := _direction(float(spec.elevation), float(spec.plane), side)
	var seeded := _seed_centre(side, direction, calibration)
	var label := side + "_" + String(spec.id)
	_check(seeded.get("valid", false), label + "_centre_constructed")
	if not seeded.get("valid", false):
		rows.append({"id": label, "setup_failure": seeded})
		return
	var centre := _poses()
	var reference := _observe(side, calibration, 0.0)
	var montage: Image
	if screenshots:
		_position_cameras(side, calibration)
		montage = Image.create_empty(TILE.x * 3, TILE.y * 2, false, Image.FORMAT_RGBA8)
	var trials: Array[Dictionary] = []
	for column: int in 3:
		var degrees := float(column - 1) * 10.0
		_restore(centre)
		var composed := _set_h(side, calibration, deg_to_rad(degrees))
		var trial := _observe(side, calibration, degrees)
		var world := skeleton.global_transform
		trial["shoulder_displacement_m"] = (world * trial.shoulder_skeleton).distance_to(world * reference.shoulder_skeleton)
		trial["elbow_displacement_m"] = (world * trial.elbow_skeleton).distance_to(world * reference.elbow_skeleton)
		trial["direction_error_degrees"] = rad_to_deg((trial.direction_anatomical as Vector3).angle_to(direction))
		trial["mechanical_pass"] = composed.get("valid", false) and float(trial.shoulder_displacement_m) <= POSITION_EPSILON and float(trial.elbow_displacement_m) <= POSITION_EPSILON and float(trial.direction_error_degrees) <= rad_to_deg(ANGLE_EPSILON) and float(trial.h_error_degrees) <= rad_to_deg(ANGLE_EPSILON) and absf(float(trial.elbow_degrees) - 90.0) <= rad_to_deg(ANGLE_EPSILON) and float(trial.maximum_proximal_change_m) <= POSITION_EPSILON and float(trial.maximum_proximal_angle_degrees) <= rad_to_deg(ANGLE_EPSILON) and bool(trial.offsets_unchanged) and bool(trial.wrist_neutral_valid)
		_check(bool(trial.mechanical_pass), label + "_h_%d_mechanics" % degrees)
		trials.append(trial)
		if screenshots:
			await process_frame
			await RenderingServer.frame_post_draw
			for view: int in views.size():
				var image := views[view].get_texture().get_image()
				image.convert(Image.FORMAT_RGBA8)
				montage.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i(column * TILE.x, view * TILE.y))
	var filename := label + ".png"
	if screenshots: _check(montage.save_png(output_dir.path_join(filename)) == OK, label + "_image_saved")
	rows.append({"id": label, "side": _slot(side), "region_id": spec.region, "direction_side_neutral": _direction(spec.elevation, spec.plane, "R"),
		"centre_h_degrees": 0.0, "trial_endpoints_degrees": [-10.0, 10.0], "local_neighborhood_degrees": 15.0,
		"origin_id": calibration.origin_id, "machine_origin_id": "RL_BoneRoot", "zero_convention": calibration.zero_convention,
		"provenance_kind": "candidate_unreviewed", "trials": trials, "montage": filename if screenshots else "not_rendered"})
	html += "<section><h2>%s | %s | elevation %s / plane %s</h2><p>Left -10°, centre 0°, right +10°. " % [label, spec.region, spec.elevation, spec.plane]
	for trial: Dictionary in trials: html += "h=%s: mechanical=%s, collision=%s; " % [trial.requested_h_degrees, trial.mechanical_pass, trial.collision_status]
	html += "</p><img src='%s'></section>" % filename if screenshots else "</p></section>"
	print("JOSIE_SHOULDER_REVIEW row=%s" % label)

func _seed_centre(side: String, direction: Vector3, calibration: Dictionary) -> Dictionary:
	var u := _bone(side, "Upperarm")
	var f := _bone(side, "Forearm")
	var h := _bone(side, "Hand")
	_point_segment(u, f, _chest_frame(calibration) * direction)
	var composed := _set_h(side, calibration, 0.0)
	if not composed.get("valid", false): return composed
	# This is reference-pose construction: retain the actual child translations
	# and align the forearm shaft to the calibrated hinge's positive 90° plane.
	# It does not assert that live IK can reach this pose or change its limits.
	var upper := skeleton.get_bone_global_pose(u)
	var shaft := (skeleton.get_bone_global_pose(f).origin - upper.origin).normalized()
	var hinge: Vector3 = upper.basis.orthonormalized() * (calibration.material_frame_in_upperarm as Basis).x
	_point_segment(f, h, hinge.cross(shaft).normalized())
	var wrist_calibration: Dictionary = rig.capture_wrist_constraint_calibration(_slot(side))
	var wrist_profile: Dictionary = rig.wrist_motion_profile.call("as_dictionary")
	var neutral := Wrist.compose(skeleton.get_bone_global_pose(f), skeleton.get_bone_global_pose(h), wrist_calibration, wrist_profile,
		{"rho": 0.0, "beta": 0.0, "gamma": 0.0}, PI * 0.5, rig.authoring_elbow_full_flexion_radians())
	if not neutral.get("valid", false): return neutral
	var target := Transform3D(neutral.accepted_hand_basis, skeleton.get_bone_global_pose(h).origin)
	var indexed: Dictionary = rig.call("_resolve_authoring_forearm_hand_index", _slot(side), skeleton.global_transform * target)
	if indexed.get("valid", false): rig.call("_write_authoring_forearm_hand_index", _slot(side), indexed)
	return indexed

func _observe(side: String, calibration: Dictionary, degrees: float) -> Dictionary:
	var u := _bone(side, "Upperarm")
	var f := _bone(side, "Forearm")
	var h := _bone(side, "Hand")
	var chest := skeleton.get_bone_global_pose(skeleton.find_bone(String(calibration.chest_bone_name)))
	var upper := skeleton.get_bone_global_pose(u)
	var forearm := skeleton.get_bone_global_pose(f)
	var hand := skeleton.get_bone_global_pose(h)
	var measured := Shoulder.measure(chest, upper, forearm, calibration, rig.shoulder_motion_profile.call("as_dictionary"))
	var bend: float = rig.capture_elbow_bend_radians(_slot(side))
	var wrist := Wrist.measure_state(forearm, hand, rig.capture_wrist_constraint_calibration(_slot(side)), rig.wrist_motion_profile.call("as_dictionary"), {}, bend, rig.authoring_elbow_full_flexion_radians())
	var collision_ready: bool = rig.sync_runtime_body_restriction_root_now()
	var collision := rig.get_body_self_collision_debug_state()
	var checked: bool = collision_ready and int(collision.get("checked_pair_count", 0)) > 0
	var maximum_position := 0.0
	var maximum_angle := 0.0
	var offsets_unchanged := true
	var bone_records: Array[Dictionary] = []
	for index: int in skeleton.get_bone_count():
		var pose := skeleton.get_bone_pose(index)
		offsets_unchanged = offsets_unchanged and pose.origin.is_equal_approx(baseline[index].origin) and pose.basis.get_scale().is_equal_approx(baseline[index].basis.get_scale())
		var cursor := index
		while cursor >= 0 and cursor != u: cursor = skeleton.get_bone_parent(cursor)
		if cursor != u:
			maximum_position = maxf(maximum_position, pose.origin.distance_to(baseline[index].origin))
			maximum_angle = maxf(maximum_angle, _angle(pose.basis, baseline[index].basis))
		else:
			var parent := skeleton.get_bone_parent(index)
			bone_records.append({"bone": skeleton.get_bone_name(index), "parent": skeleton.get_bone_name(parent) if parent >= 0 else "",
				"local_pose": pose, "skeleton_pose": skeleton.get_bone_global_pose(index)})
	var state: Dictionary = wrist.get("state", {})
	var wrist_maximum := maxf(absf(float(state.get("rho", INF))), maxf(absf(float(state.get("beta", INF))), absf(float(state.get("gamma", INF)))))
	var reference_chain: Array[Dictionary] = []
	var ancestor := skeleton.get_bone_parent(u)
	while ancestor >= 0:
		var parent := skeleton.get_bone_parent(ancestor)
		reference_chain.append({"bone": skeleton.get_bone_name(ancestor), "parent": skeleton.get_bone_name(parent) if parent >= 0 else "",
			"local_pose": skeleton.get_bone_pose(ancestor), "skeleton_pose": skeleton.get_bone_global_pose(ancestor)})
		if skeleton.get_bone_name(ancestor) == "RL_BoneRoot": break
		ancestor = parent
	return {"requested_h_degrees": degrees, "measured_h_degrees": rad_to_deg(float(measured.get("state", {}).get("h", INF))),
		"h_error_degrees": absf(rad_to_deg(float(measured.get("state", {}).get("h", INF))) - degrees),
		"direction_anatomical": measured.get("direction_anatomical", Vector3.ZERO), "elbow_degrees": rad_to_deg(bend),
		"shoulder_skeleton": upper.origin, "elbow_skeleton": forearm.origin, "wrist_skeleton": hand.origin,
		"maximum_proximal_change_m": maximum_position, "maximum_proximal_angle_degrees": rad_to_deg(maximum_angle),
		"offsets_unchanged": offsets_unchanged, "wrist_neutral_valid": wrist.get("valid", false) and wrist_maximum <= ANGLE_EPSILON,
		"wrist": wrist, "shoulder_measurement": measured, "collision_status": ("no_illegal_overlap" if collision.get("legal", false) else "illegal_overlap") if checked else "NOT_CHECKED",
		"body_proxy_collision": collision, "bone_reference_space": "local_pose: parent bone; skeleton_pose: Skeleton3D; named ancestry reaches RL_BoneRoot",
		"skeleton_to_world": skeleton.global_transform, "reference_chain": reference_chain, "bones": bone_records}

func _set_h(side: String, calibration: Dictionary, h: float) -> Dictionary:
	var u := _bone(side, "Upperarm")
	var composed := Shoulder.compose(skeleton.get_bone_global_pose(skeleton.find_bone(String(calibration.chest_bone_name))),
		skeleton.get_bone_global_pose(u), skeleton.get_bone_global_pose(_bone(side, "Forearm")), calibration, h)
	if composed.get("valid", false): _set_basis(u, composed.upperarm_basis)
	return composed

func _point_segment(parent: int, child: int, direction: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(parent)
	var shaft := (skeleton.get_bone_global_pose(child).origin - pose.origin).normalized()
	_set_basis(parent, Basis(Quaternion(shaft, direction.normalized())) * pose.basis)

func _set_basis(index: int, basis: Basis) -> void:
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(index))
	skeleton.set_bone_pose_rotation(index, (parent.basis.inverse() * basis).orthonormalized().get_rotation_quaternion().normalized())
	skeleton.force_update_all_bone_transforms()

func _direction(elevation: float, plane: float, side: String) -> Vector3:
	var e := deg_to_rad(elevation)
	var p := deg_to_rad(plane)
	return Vector3(sin(e) * cos(p) * (1.0 if side == "R" else -1.0), -cos(e), -sin(e) * sin(p)).normalized()

func _chest_frame(calibration: Dictionary) -> Basis:
	return skeleton.get_bone_global_pose(skeleton.find_bone(String(calibration.chest_bone_name))).basis.orthonormalized() * calibration.chest_anatomical_in_bone

func _bone(side: String, suffix: String) -> int: return skeleton.find_bone("CC_Base_" + side + "_" + suffix)
func _slot(side: String) -> StringName: return &"hand_right" if side == "R" else &"hand_left"

func _poses() -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): result.append(skeleton.get_bone_pose(index))
	return result

func _restore(poses: Array[Transform3D]) -> void:
	for index: int in poses.size(): skeleton.set_bone_pose(index, poses[index])
	skeleton.force_update_all_bone_transforms()

func _angle(a: Basis, b: Basis) -> float:
	var q := (a.orthonormalized().get_rotation_quaternion().inverse() * b.orthonormalized().get_rotation_quaternion()).normalized()
	return 2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w))

func _build_views() -> void:
	for index: int in 2:
		var container := SubViewportContainer.new()
		container.position = Vector2(index * TILE.x, 0)
		root.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = TILE
		viewport.world_3d = root.world_3d
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.45
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.2, 0.21, 0.23)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color.WHITE
		environment.ambient_light_energy = 0.85
		camera.environment = environment
		viewport.add_child(camera)
		camera.current = true
		views.append(viewport)
		cameras.append(camera)
	var light := DirectionalLight3D.new()
	root.add_child(light)
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 0.8

func _position_cameras(side: String, calibration: Dictionary) -> void:
	var chest := skeleton.get_bone_global_pose(skeleton.find_bone(String(calibration.chest_bone_name)))
	var frame := skeleton.global_basis.orthonormalized() * _chest_frame(calibration)
	var centre: Vector3 = skeleton.global_transform * chest.origin - frame.y * 0.12
	for index: int in cameras.size():
		var outward: Vector3 = -frame.z if index == 0 else frame.x * (1.0 if side == "R" else -1.0)
		cameras[index].global_position = centre + outward * 4.0
		cameras[index].look_at(centre, frame.y)

func _check(passed: bool, label: String) -> void:
	checks.append({"passed": passed, "check": label})
	if not passed: push_warning("JOSIE_SHOULDER_REVIEW " + label)

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks: passed = passed and check.passed
	var report := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify({"mechanical_checks_passed": passed, "anatomy_validated": false,
		"source": "GDD-and Text Resources/Reserch/Shoulder and Forearm Rotation Limits for Josie (1).md",
		"scope": "Fixed reference-pose inspection; rotations constructed explicitly, posed bone offsets unchanged; no allocator, saved skill, acquisition, or gameplay acceptance claim.",
		"checks": checks, "lowered_zero_references": references, "rows": rows}, "\t"))
	report.close()
	var page := FileAccess.open(output_dir.path_join("review.html"), FileAccess.WRITE)
	if page != null: page.store_string(html)
	print("JOSIE_SHOULDER_REVIEW mechanical=%s rows=%d output=%s" % [passed, rows.size(), output_dir])
	quit(0 if passed else 1)
