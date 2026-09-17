extends SceneTree

const SolverScript = preload("res://runtime/player/player_finger_surface_grip_solver.gd")

# Offline geometry experiment. The captured input retains actual bone names,
# bone-local hinge frames, and RL_BoneRoot-derived world coordinates. No scene
# skeleton, player library, production rule, or weapon transform is modified.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("THE_WILL_GRIP_CAPTURE_PATH")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Provide THE_WILL_GRIP_CAPTURE_PATH from the acquisition diagnostic.")
		quit(1)
		return
	var input: Dictionary = file.get_var()
	file.close()
	var surface: Dictionary = input["surface"]
	var solver = SolverScript.new()
	var output := {"slot": input["slot"], "input": path, "digits": {}}
	if OS.get_environment("THE_WILL_GRIP_PROBE_MODE") == "radial_clearance":
		var placement: Dictionary = _probe_radial_clearance(input, solver)
		output["placement_experiment"] = placement
		if not bool(placement.get("valid", false)):
			print("GRIP_PLACEMENT_REJECTED=" + JSON.stringify(placement))
			quit(1)
			return
		# Moving copied Hand frames by +offset against fixed geometry is equivalent
		# to moving the weapon by -offset against a fixed Hand. This is an offline
		# relative-placement experiment, not an arm/wrist pose modification.
		var offset_world: Vector3 = placement["offset_world"]
		for digit_id: Variant in input["digits"]:
			var snapshot: Dictionary = input["digits"][digit_id]["snapshot"]
			var parent_world: Transform3D = snapshot["root_parent_world"]
			parent_world.origin += offset_world
			snapshot["root_parent_world"] = parent_world
			var bases: Array = snapshot["base_bone_world"]
			for i: int in range(bases.size()):
				var frame: Transform3D = bases[i]
				frame.origin += offset_world
				bases[i] = frame
	for digit_id: String in ["index", "middle", "ring", "pinky"]:
		var digit: Dictionary = input["digits"][digit_id]
		var snapshot: Dictionary = digit["snapshot"]
		var fk: Dictionary = solver._forward_kinematics(snapshot, [0.0, 0.0, 0.0])
		var point_world: Vector3 = fk["joint_origins_world"][0]
		var point_source_origin: StringName = snapshot["bone_names"][0]
		var sphere: Dictionary = solver.capsule_surface_query.query_prepared_surface(
			surface, point_world, point_source_origin, point_world, point_source_origin,
			float(snapshot["capsule_radii_m"][0]), surface["surface_source_origin_id"],
			snapshot["bone_root_origin_id"],
			{"classify_inside_solid": true, "surface_topology_state": surface.get("capsule_surface_topology", {})}
		)
		var report := {
			"fixed_base_sphere_valid": sphere.get("valid", false),
			"fixed_base_sphere_signed_distance_valid": sphere.get("signed_distance_valid", false),
			"fixed_base_sphere_penetration_meters": sphere.get("penetration_meters"),
			"fixed_base_sphere_cap_meters": digit["cap"],
			"coordinated": []
		}
		if OS.get_environment("THE_WILL_GRIP_PROBE_MODE") != "base":
			var probe_script = load("res://tools/probe_coordinated_digit_closure.gd")
			var probe = probe_script.new()
			for extra_open_degrees: float in [0.0, 30.0]:
				report["coordinated"].append(probe.probe(snapshot, surface, digit["preferred"], digit["cap"], digit["options"], extra_open_degrees))
		output["digits"][digit_id] = report
		var summaries: Array = []
		for candidate: Dictionary in report["coordinated"]:
			summaries.append({"status": candidate.get("status"), "angles_degrees": candidate.get("angles_degrees"), "overlaps_meters": candidate.get("signed_overlaps_meters"), "evaluations": candidate.get("pose_evaluation_count"), "milliseconds": candidate.get("elapsed_milliseconds"), "extra_root_open_degrees": candidate.get("wider_root_open_degrees")})
		print("GRIP_CLOSURE_CANDIDATE=" + JSON.stringify({"digit": digit_id, "fixed_base_penetration_meters": report["fixed_base_sphere_penetration_meters"], "candidates": summaries}))
	var result_path := "C:/WORKSPACE/test_artifacts/grip_closure_candidates_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var result_file := FileAccess.open(result_path, FileAccess.WRITE)
	result_file.store_string(JSON.stringify(output, "\t"))
	result_file.close()
	print("GRIP_CLOSURE_CANDIDATES_RESULT=" + result_path)
	quit(0)

func _probe_radial_clearance(input: Dictionary, solver: RefCounted) -> Dictionary:
	if not input.has("observation_weapon_world") or input.get("observation_weapon_world_origin_id") != &"RL_BoneRoot":
		return {"valid": false, "reason": "missing_observed_weapon_frame"}
	if input.get("weapon_tip_local_origin_id") != &"WeaponRootOrigin" or input.get("weapon_pommel_local_origin_id") != &"WeaponRootOrigin":
		return {"valid": false, "reason": "missing_weapon_endpoint_origins"}
	var weapon_world: Transform3D = input["observation_weapon_world"]
	var axis_world: Vector3 = (weapon_world.basis * ((input["weapon_tip_local"] as Vector3) - (input["weapon_pommel_local"] as Vector3))).normalized()
	var surface: Dictionary = input["surface"]
	var offset_world := Vector3.ZERO
	var samples: Array = []
	var zero_angles: Array[float] = [0.0, 0.0, 0.0]
	for iteration: int in range(16):
		var worst_excess := 0.0
		var worst_direction := Vector3.ZERO
		var worst_digit := ""
		for digit_id: String in ["index", "middle", "ring", "pinky"]:
			var digit: Dictionary = input["digits"][digit_id]
			var snapshot: Dictionary = digit["snapshot"]
			var fk: Dictionary = solver._forward_kinematics(snapshot, zero_angles)
			var point_world: Vector3 = (fk["joint_origins_world"][0] as Vector3) + offset_world
			var point_origin: StringName = snapshot["bone_names"][0]
			var query: Dictionary = solver.capsule_surface_query.query_prepared_surface(surface, point_world, point_origin, point_world, point_origin, snapshot["capsule_radii_m"][0], surface["surface_source_origin_id"], snapshot["bone_root_origin_id"], {"classify_inside_solid": true, "surface_topology_state": surface.get("capsule_surface_topology", {})})
			if not bool(query.get("valid", false)) or not bool(query.get("signed_distance_valid", false)):
				return {"valid": false, "reason": "unclassified_fixed_base"}
			var excess: float = float(query["penetration_meters"]) - float(digit["cap"])
			if excess > worst_excess:
				worst_excess = excess
				worst_digit = digit_id
				worst_direction = (point_world - (query["closest_triangle_point_world"] as Vector3)).normalized()
				if bool(query.get("segment_axis_inside_solid", false)):
					worst_direction = -worst_direction
		samples.append({"iteration": iteration, "worst_digit": worst_digit, "excess_meters": worst_excess})
		if worst_excess <= 0.000001:
			return {"valid": true, "offset_world": offset_world, "offset_world_origin_id": &"RL_BoneRoot", "axial_offset_meters": offset_world.dot(axis_world), "samples": samples}
		var radial_direction: Vector3 = worst_direction - axis_world * worst_direction.dot(axis_world)
		if radial_direction.length_squared() < 0.000001:
			return {"valid": false, "reason": "no_radial_escape_direction", "samples": samples}
		radial_direction = radial_direction.normalized()
		offset_world += radial_direction * minf((worst_excess + 0.00002) / maxf(radial_direction.dot(worst_direction), 0.1), 0.005)
		if offset_world.length() > 0.02:
			return {"valid": false, "reason": "diagnostic_translation_budget", "samples": samples}
	return {"valid": false, "reason": "diagnostic_iteration_budget", "samples": samples}
