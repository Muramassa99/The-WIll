extends SceneTree

## Read-only coverage audit, not a claim that every sampled direction should be
## permitted. Grid counts include repeated pole/seam directions; they are not
## spherical surface-area percentages. Uses the live profile and actual Idle.
const Resolver = preload("res://core/resolvers/combat_shoulder_motion_resolver.gd")
const LiveProfile = preload("res://core/defs/characters/josie/shoulder_motion_profile.tres")
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const GRID_STEP_DEGREES := 5
const PATH_STEP_DEGREES := 1.0
var out_dir := "C:/WORKSPACE/godot_runs/shoulder_coverage_20261107"
var output_path := ""
var legacy_mode := false

func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			out_dir = argument.trim_prefix("--out-dir=")
		elif argument.begins_with("--out="):
			output_path = argument.trim_prefix("--out=")
		elif argument == "--legacy":
			legacy_mode = true
	call_deferred("_run")

func _run() -> void:
	var profile: Dictionary = LiveProfile.as_dictionary()
	if legacy_mode:
		profile["coverage_mode"] = "measured_plus_provisional"
		profile["coverage_schema"] = "fixed_shoulder_neighborhoods_v1"
	var validation := Resolver.validate_profile(profile)
	var report := {
		"scope": "Coverage and interval continuity only; no movement, grip, saved-skill or anatomical certification.",
		"profile_path": "res://core/defs/characters/josie/shoulder_motion_profile.tres",
		"profile_revision": profile.get("revision", ""),
		"legacy_mode_override": legacy_mode,
		"coverage_schema": profile.get("coverage_schema", ""),
		"profile_valid": validation.get("valid", false),
		"profile_validation": validation,
		"grid_step_degrees": GRID_STEP_DEGREES,
		"grid_count_caveat": "Inclusive angle-grid samples, not unique directions or area percentages. Poles and -180/+180 seam repeat directions.",
		"region_convention": {"front": "0 <= plane <= 90", "posterior": "-90 <= plane < 0", "medial": "90 < plane <= 180", "posterior_medial": "-180 <= plane < -90"},
		"maximum_path_step_degrees": PATH_STEP_DEGREES,
		"sides": {}
	}
	if not bool(validation.get("valid", false)):
		_write_report(report, 1)
		return
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_process(false)
	rig.set_physics_process(false)
	rig.call("set_authoring_preview_mode_enabled", true)
	rig.call("reset_authoring_preview_baseline_pose")
	var all_calibrated := true
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var calibration: Dictionary = rig.call("capture_shoulder_constraint_calibration", slot)
		var idle: Dictionary = rig.call("capture_shoulder_motion_start_state", slot)
		if not bool(calibration.get("valid", false)) or not bool(idle.get("valid", false)):
			report.sides[String(slot)] = {"calibration": calibration, "idle": idle}
			all_calibrated = false
			continue
		var side: float = float(calibration.side_sign)
		var internal_sign: float = float(calibration.internal_sign)
		var direction: Vector3 = idle.direction_anatomical
		var grid := _sweep_grid(side, internal_sign, profile)
		grid["actual_idle"] = _describe(direction, side, internal_sign, profile)
		grid.actual_idle["source"] = "Imported rig after reset_authoring_preview_baseline_pose; sampled synchronously before any further frame."
		grid.actual_idle["h_degrees"] = rad_to_deg(float(idle.state.h))
		grid.actual_idle["origin_id"] = String(calibration.get("origin_id", ""))
		grid.actual_idle["machine_origin_id"] = "RL_BoneRoot"
		grid["explicit_probes"] = _probes(side, internal_sign, profile)
		grid["idle_to_donor_paths"] = _paths(direction, side, internal_sign, profile)
		report.sides[String(slot)] = grid
	report["rig_calibrated"] = all_calibrated
	rig.queue_free()
	_write_report(report, 0 if all_calibrated else 1)

func _sweep_grid(side: float, internal_sign: float, profile: Dictionary) -> Dictionary:
	var totals := _new_counts()
	var regions: Dictionary = {}
	for region: String in ["front", "posterior", "medial", "posterior_medial"]:
		regions[region] = _new_counts()
	var elevations: Array[Dictionary] = []
	for elevation: int in range(0, 181, GRID_STEP_DEGREES):
		var counts := _new_counts()
		for plane: int in range(-180, 181, GRID_STEP_DEGREES):
			var sample := _describe(_direction(elevation, plane, side), side, internal_sign, profile)
			_count(totals, sample)
			_count(counts, sample)
			_count(regions[_region(plane)], sample)
		counts["elevation_degrees"] = elevation
		elevations.append(counts)
	return {"grid_total": totals, "regions": regions, "by_elevation": elevations}

func _new_counts() -> Dictionary:
	return {"samples": 0, "covered": 0, "missing": 0, "conflicting": 0, "kinds": {}}

func _count(counts: Dictionary, sample: Dictionary) -> void:
	counts.samples += 1
	var kind := String(sample.coverage_kind)
	counts.kinds[kind] = int(counts.kinds.get(kind, 0)) + 1
	if bool(sample.covered):
		counts.covered += 1
	elif kind == "conflicting_samples":
		counts.conflicting += 1
	else:
		counts.missing += 1

func _region(plane: float) -> String:
	if plane >= 0.0 and plane <= 90.0:
		return "front"
	if plane >= -90.0 and plane < 0.0:
		return "posterior"
	return "medial" if plane > 90.0 else "posterior_medial"

func _probes(side: float, internal_sign: float, profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pair: Vector2 in [Vector2(60.0, 22.5), Vector2(45.0, 22.5), Vector2(74.99, 0.0), Vector2(75.0, 0.0), Vector2(75.01, 0.0), Vector2(90.0, 45.0)]:
		var row := _describe(_direction(pair.x, pair.y, side), side, internal_sign, profile)
		row["requested_elevation_degrees"] = pair.x
		row["requested_plane_degrees"] = pair.y
		result.append(row)
	return result

func _paths(start: Vector3, side: float, internal_sign: float, profile: Dictionary) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	for pair: Vector2 in [Vector2(30.0, 0.0), Vector2(60.0, 0.0), Vector2(60.0, 45.0), Vector2(90.0, 0.0), Vector2(90.0, 45.0), Vector2(90.0, 90.0), Vector2(120.0, 45.0), Vector2(150.0, 45.0)]:
		var target := _direction(pair.x, pair.y, side)
		var angle := start.angle_to(target)
		var steps := maxi(1, ceili(rad_to_deg(angle) / PATH_STEP_DEGREES))
		var rotation := Quaternion(start, target)
		var counts := _new_counts()
		var transitions: Array[Dictionary] = []
		var previous: Dictionary = {}
		var largest_minimum_jump: Dictionary = {"absolute_degrees": 0.0}
		var largest_maximum_jump: Dictionary = {"absolute_degrees": 0.0}
		for i: int in range(steps + 1):
			var t := float(i) / float(steps)
			var direction: Vector3 = Quaternion.IDENTITY.slerp(rotation, t) * start
			var sample := _describe(direction.normalized(), side, internal_sign, profile)
			sample["path_fraction"] = t
			_count(counts, sample)
			if not previous.is_empty():
				if bool(previous.covered) != bool(sample.covered) or String(previous.coverage_kind) != String(sample.coverage_kind):
					transitions.append({"from": previous, "to": sample})
				if bool(previous.covered) and bool(sample.covered):
					var lower_change := absf(float(sample.minimum_degrees) - float(previous.minimum_degrees))
					var upper_change := absf(float(sample.maximum_degrees) - float(previous.maximum_degrees))
					if lower_change > float(largest_minimum_jump.absolute_degrees):
						largest_minimum_jump = {"absolute_degrees": lower_change, "from": previous, "to": sample}
					if upper_change > float(largest_maximum_jump.absolute_degrees):
						largest_maximum_jump = {"absolute_degrees": upper_change, "from": previous, "to": sample}
			previous = sample
		paths.append({"target_elevation_degrees": pair.x, "target_plane_degrees": pair.y,
			"arc_degrees": rad_to_deg(angle), "actual_step_degrees": rad_to_deg(angle) / float(steps),
			"counts": counts, "coverage_transitions": transitions,
			"maximum_adjacent_lower_bound_jump": largest_minimum_jump,
			"maximum_adjacent_upper_bound_jump": largest_maximum_jump,
			"jump_scope": "Compared only adjacent covered samples; uncovered intervals reported separately, never treated as zero bounds."})
	return paths

func _direction(elevation: float, plane: float, side: float) -> Vector3:
	var e := deg_to_rad(elevation)
	var p := deg_to_rad(plane)
	return Vector3(side * sin(e) * cos(p), -cos(e), -sin(e) * sin(p)).normalized()

func _describe(direction: Vector3, side: float, internal_sign: float, profile: Dictionary) -> Dictionary:
	var result := Resolver.sample_bounds(direction, side, profile, internal_sign)
	var covered := bool(result.get("covered", false))
	return {"direction_anatomical": [direction.x, direction.y, direction.z],
		"elevation_degrees": rad_to_deg(float(result.elevation_radians)),
			"plane_degrees": rad_to_deg(float(result.plane_radians)), "covered": covered,
			"coverage_kind": String(result.get("coverage_kind", "")), "reason": String(result.get("reason", "")),
			"minimum_degrees": rad_to_deg(float(result.minimum_radians)) if covered else null,
			"maximum_degrees": rad_to_deg(float(result.maximum_radians)) if covered else null,
			"sources": result.get("coverage_sources", [])}

func _write_report(report: Dictionary, exit_code: int) -> void:
	var destination := output_path if not output_path.is_empty() else out_dir.path_join("coverage_report.json")
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write shoulder coverage audit: " + destination)
		quit(1)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	print("SHOULDER_COVERAGE_AUDIT output=%s profile_valid=%s rig_calibrated=%s" % [destination, report.get("profile_valid", false), report.get("rig_calibrated", false)])
	quit(exit_code)
