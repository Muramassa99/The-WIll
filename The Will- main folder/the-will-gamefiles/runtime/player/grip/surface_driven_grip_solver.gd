extends RefCounted

## Bounded final-pose fit. Authored weapon basis, longitudinal station and Hand
## are fixed. Only the transverse seat and anatomical digit hinges are fitted.
## Contact witnesses are reselected on the palmar skin at every candidate.
const Anatomy = preload("res://runtime/player/grip/prepared_surface_grip_anatomy.gd")
const Surface = preload("res://runtime/player/grip/grip_surface_query.gd")
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const SeatFit = preload("res://runtime/player/grip/surface_grip_seat_fit.gd")
const HandFit = preload("res://runtime/player/grip/surface_grip_hand_fit.gd")
const ROOT := &"RL_BoneRoot"
const WEAPON_ROOT := &"WeaponRootOrigin"
const METHOD := &"surface_contact_v6"
const REVISION := &"coupled_hand_surface_fit_v4"
const ACTIVE: Array[StringName] = [&"middle", &"index", &"ring", &"pinky"]
const ALL_DIGITS: Array[StringName] = [&"middle", &"index", &"ring", &"pinky", &"thumb"]
const SECTION_PULL_WEIGHTS := [0.6, 0.8, 0.3]
# Bounded soft location preference, not a contact probability or eligibility rule.
const LOCATION_PREFERENCE_WEIGHT := 36.0
# Game-pose style preference only; authored ROM and material caps remain guards.
const DISTRIBUTED_BEND_WEIGHT := 0.05
const DISTAL_TO_MIDDLE_BEND_RATIO := 2.0 / 3.0
const CONTACT_BAND_M := 0.00005
const NUMERIC_GUARD_M := 0.000002
const PALM_CAP_M := 0.0035
var _cancel_check: Callable
var _progress_callback: Callable
var _anatomy := Anatomy.new()
var _spatial := Spatial.new()
var _prepared: Dictionary = {}
var _surface: Dictionary = {}
var _kernels: Dictionary = {}
var _blocks: Dictionary = {}
var _palm: Array = []
var _safety: Array = []
var _weapon := Transform3D.IDENTITY
var _axis := Vector3.ZERO
var _pivot := Vector3.ZERO
var _outward := Vector3.ZERO
var _tangent := Vector3.ZERO
var _metrics: Dictionary = {}
var _events: Array = []
var _repairing := false
var _point_cache: Array = []
var _point_cache_frames: Dictionary = {}
var _thumb_active := false
var _normal_cache: Array = []

func configure_lifecycle(cancel_check: Callable, progress_callback: Callable) -> void:
	_cancel_check = cancel_check
	_progress_callback = progress_callback

func diagnostic_snapshot() -> Dictionary:
	return {"revision":REVISION, "totals":_metrics.duplicate(true), "events":_events.duplicate(true)}

func run(anatomy: Resource, stage: Dictionary, config: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var setup := _initialize_inputs(anatomy, stage, config)
	if not setup.get("valid", false): return setup
	var original: Transform3D = setup.weapon
	var angles: Dictionary = setup.angles
	var seats: Array = []
	_progress(&"surface_final_pose_seat_search")
	if config.get("seat_weapon", true):
		var seat_fit := SeatFit.new()
		seats = seat_fit.make_candidates(self, original, angles)
		_metrics["preshape_seats"] = seat_fit.metrics
	else:
		if config.has("seed_digit_states"):
			var seeded := _validated_digit_angles(config.seed_digit_states)
			if not seeded.get("valid", false): return seeded
			angles = seeded.angles
			_metrics["fixed_seat_warm_start"] = true
		seats.append({"weapon":original, "angles":angles, "cost":0.0})
	if _cancelled(): return _fail("acquisition_cancelled")
	if seats.is_empty(): return _fail("surface_seat_candidates_unavailable")
	_thumb_active = true
	_progress(&"surface_coupled_hand_and_seat_fit")
	var fitted := HandFit.new().fit(self, original, seats, bool(config.get("seat_weapon", true)))
	if not fitted.get("valid", false): return _fail(fitted.get("reason", "whole_hand_fit_failed"))
	angles = fitted.angles
	var best: Dictionary = fitted.assessment
	_metrics["coupled_hand_fit"] = fitted.metrics
	if _cancelled(): return _fail("acquisition_cancelled")
	return _compose_final(angles, best, original, started)

## Check the realized support-arm pose using the same skin/limit contract,
## without rerunning optimization or trusting the requested virtual hand frame.
func assess_final_pose(anatomy: Resource, stage: Dictionary, config: Dictionary, digit_states: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var setup := _initialize_inputs(anatomy, stage, config)
	if not setup.get("valid", false): return setup
	var checked := _validated_digit_angles(digit_states)
	if not checked.get("valid", false): return checked
	var angles: Dictionary = checked.angles
	_thumb_active = true
	var best := _assess(angles)
	var result := _compose_final(angles, best, setup.weapon, started)
	result["assessment_only"] = true
	return result

func _validated_digit_angles(digit_states: Variant) -> Dictionary:
	if not digit_states is Dictionary: return _fail("invalid_realized_digit_states")
	var angles: Dictionary = _prepared.open_angles.duplicate(true)
	for id: StringName in ALL_DIGITS:
		var state: Variant = digit_states.get(id, {})
		if not state is Dictionary: return _fail("invalid_realized_digit_state_" + String(id))
		var values: Variant = state.get("angles_rad", [])
		if not (values is Array or values is PackedFloat32Array or values is PackedFloat64Array):
			return _fail("invalid_realized_digit_angles_" + String(id))
		if values.size() != 3: return _fail("missing_realized_digit_angles_" + String(id))
		var snapshot: Dictionary = _prepared.adapter.digit_inputs[id].snapshot
		var bounded: Array[float] = []
		for joint: int in 3:
			if not (values[joint] is float or values[joint] is int):
				return _fail("invalid_realized_digit_angles_" + String(id))
			var value := float(values[joint])
			if not is_finite(value) or value < float(snapshot.min_angles_rad[joint]) - 0.000001 or value > float(snapshot.max_angles_rad[joint]) + 0.000001:
				return _fail("invalid_realized_digit_angles_" + String(id))
			bounded.append(clampf(value, snapshot.min_angles_rad[joint], snapshot.max_angles_rad[joint]))
		angles[id] = bounded
	return {"valid":true, "angles":angles}

func _initialize_inputs(anatomy: Resource, stage: Dictionary, config: Dictionary) -> Dictionary:
	_metrics = {"candidate_steps":0, "native_surface_queries":0, "digit_ms":{},
		"solver_revision":REVISION, "section_pull_weights":SECTION_PULL_WEIGHTS,
		"contact_tracking":&"mobile_palmar_final_pose_witness", "seat_candidates":[]}
	_events.clear()
	_normal_cache.clear()
	_point_cache.clear()
	_point_cache_frames = {}
	_blocks.clear()
	_kernels.clear()
	_repairing = false
	_thumb_active = false
	if _cancelled(): return _fail("acquisition_cancelled")
	if not stage.get("valid", false) or not stage.get("object") is Dictionary:
		return _fail("missing_captured_surface_grip_stage")
	var object: Dictionary = stage.object
	for field: String in ["weapon_to_world", "grip_pivot_local", "primary_grip_span_start_local", "primary_grip_span_end_local"]:
		if not object.has(field): return _fail("missing_surface_grip_" + field)
	for field: String in ["grip_pivot_local_origin_id", "primary_grip_span_start_origin_id", "primary_grip_span_end_origin_id"]:
		if object.get(field) != WEAPON_ROOT: return _fail("invalid_surface_grip_" + field)
	if object.get("weapon_to_world_origin_id") != ROOT: return _fail("missing_weapon_root_lineage")
	_weapon = object.weapon_to_world
	var original := _weapon
	_pivot = object.grip_pivot_local
	_axis = (_weapon.basis * (object.primary_grip_span_end_local - object.primary_grip_span_start_local)).normalized()
	if not _weapon.is_finite() or _axis.length_squared() < 0.5: return _fail("invalid_weapon_station_or_axis")
	_progress(&"surface_character_preparation")
	_prepared = _anatomy.prepare(anatomy, stage, config)
	if not _prepared.get("valid", false): return _fail("surface_character_preparation_failed", _prepared)
	_surface = Surface.prepare(stage.get("saved_grip_source", {}), config)
	if not _surface.get("valid", false): return _fail("saved_surface_preparation_failed", _surface)
	_metrics["target_contract"] = _surface.target_contract
	_metrics["anatomy_preparation_ms"] = _prepared.preparation_ms
	_metrics["input_weapon_index_pinky_alignment"] = absf(_axis.dot(_prepared.references.across_world))
	_outward = _transverse(_prepared.references.palmar_out_world).normalized()
	_tangent = _axis.cross(_outward).normalized()
	if _tangent.dot(_prepared.references.knuckle_midpoint_world - _prepared.references.wrist_world) < 0.0:
		_tangent = -_tangent
	var built := _prepare_kernels(stage.saved_grip_source)
	if not built.get("valid", false): return _fail("native_surface_preparation_failed", built)
	var angles: Dictionary = _prepared.open_angles.duplicate(true)
	_palm = _pack_samples(_prepared.palm_samples)
	_safety = _pack_samples(_prepared.safety_samples)
	for id: StringName in ALL_DIGITS:
		var samples: Array = []
		for section: int in 3:
			for source: Dictionary in _prepared.digits[id].sections[section].samples:
				var tagged := source.duplicate()
				tagged["target_section"] = section
				samples.append(tagged)
		var guards: Array = _prepared.digits[id].safety_samples
		samples.append_array(guards)
		_blocks[id] = _pack_samples(samples)
	return {"valid":true, "weapon":original, "angles":angles}

func _compose_final(angles: Dictionary, best: Dictionary, original: Transform3D, started: int) -> Dictionary:
	var candidate := Candidate.new().evaluate(_prepared.adapter, angles, Vector3.ZERO, ROOT)
	if not candidate.get("valid", false): return _fail("final_surface_pose_composition_failed", candidate)
	var final_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_metrics["final_sections"] = best.sections
	_metrics["final_weapon_to_world"] = _weapon
	_metrics["orientation_unchanged"] = _weapon.basis.is_equal_approx(original.basis)
	_metrics["longitudinal_station_error_m"] = absf((_weapon.origin - original.origin).dot(_axis))
	_metrics["total_ms"] = final_ms
	_metrics["full_safety"] = best.safety
	_metrics["palm_gap_m"] = best.palm_gap_m
	_metrics["palm_engaged"] = best.palm_engaged
	_metrics["physically_engaged_sections"] = best.engaged_sections
	_metrics["maximum_depth_sections"] = best.contacts
	var complete: bool = best.contacts.size() == 14 and best.safe and best.palm_contact
	var unresolved: Array = []
	var digit_results: Array = []
	for id: StringName in ALL_DIGITS:
		var count := 0
		for key: StringName in best.contacts:
			if String(key).begins_with(String(id) + ":"): count += 1
		var expected := 2 if id == &"thumb" else 3
		if count < expected: unresolved.append(id)
		digit_results.append({"digit":id, "angles_rad":angles[id], "satisfactory":count == expected, "status":&"bounded_final_surface_fit"})
	_metrics["section_assessment"] = {"satisfactory":complete, "unresolved_digits":unresolved,
		"satisfied_count":best.contacts.size(), "required_count":14, "palm_contact":best.palm_contact}
	return {"valid":true, "revision":METHOD, "method":METHOD, "solver_revision":REVISION,
		"active_digits":ALL_DIGITS.duplicate(), "thumb_solve_enabled":true,
		"source_weapon_to_world":original, "vectors_origin_id":ROOT, "candidate":candidate,
		"selected":{"weapon_to_world":_weapon, "weapon_to_world_origin_id":ROOT, "placement_owner":&"fixed_hand_palm_surface_translation"},
		"hand_transform_unchanged":true, "material_assessed":true, "material_safe":best.safe,
		"material_validation":best.safety, "material_contact_scope":&"original_skin_carriers_and_bone_segments",
		"final_hand_material_contacts":best.contacts, "accepted_hand_material_contacts":best.contacts,
		"unresolved_digits":unresolved, "section_assessment":{"satisfactory":complete, "unresolved_digits":unresolved},
		"minimum_hand_contact_count_met":best.contacts.size() >= 3, "four_finger_contact_condition_met":complete,
		"full_hand_contact_condition_met":complete, "grip_accepted":complete, "actual_3d_grip_verified":false,
		"production_pose_written":false, "palm_seating":{"valid":true, "gap_m":best.palm_gap_m},
		"final_digit_assessments":digit_results, "reseat_attempts":2,
		"termination":&"bounded_final_pose_fit", "total_ms":final_ms, "totals":_metrics.duplicate(true),
		"events":_events.duplicate(true), "coverage":"Original-weight sampled skin and bone segments; not whole mesh collision certification."}

func _prepare_kernels(source: Dictionary) -> Dictionary:
	if not ClassDB.class_exists(&"GripPoseSurfaceKernel") or not ClassDB.class_exists(&"GripSkinPointKernel"):
		return {"valid":false, "reason":"native_pose_surface_kernel_unavailable"}
	var wrapper: Resource = source.wrapper
	var geometry := {&"physical":[source.handle_packet.vertices, source.handle_packet.indices],
		&"digit":[wrapper.get("target_vertices_m"), wrapper.get("target_indices")]}
	if int(wrapper.get("schema_version")) >= 2:
		geometry[&"non_thumb_s1"] = [wrapper.get("non_thumb_s1_target_vertices_m"), wrapper.get("non_thumb_s1_target_indices")]
	else: geometry[&"non_thumb_s1"] = geometry[&"digit"]
	var to_metric: Transform3D = Transform3D(_weapon.basis, Vector3.ZERO) * (source.source_to_weapon as Transform3D)
	for kind: StringName in geometry:
		var faces := PackedVector3Array()
		var vertices: PackedVector3Array = geometry[kind][0]
		for index: int in geometry[kind][1]: faces.append(to_metric * vertices[index])
		var kernel: Object = ClassDB.instantiate(&"GripPoseSurfaceKernel")
		var built: Dictionary = kernel.prepare(faces)
		if not built.get("valid", false): return {"valid":false, "kind":kind, "detail":built}
		_kernels[kind] = kernel
	return {"valid":true}

func _pack_samples(samples: Array) -> Array:
	var posed: Array = _anatomy.pose_samples(_prepared, samples)
	var result: Array = []
	var seen := {}
	for index: int in samples.size():
		var sample: Dictionary = samples[index]
		# Shared mesh vertices appear once for each incident triangle. Their
		# position and material cap are identical; retain one safety carrier.
		var key := ""
		if not sample.has("target_section"):
			for corner: int in 3:
				if float(sample.barycentric[corner]) == 1.0:
					key = "%s:%s" % [sample.vertex_ids[corner], sample.cap_m]
					break
		var fixed := Vector3.ZERO
		var moving := {}
		for corner: int in 3:
			var factor: float = sample.barycentric[corner]
			var vertex: Dictionary = _prepared.vertices[sample.vertex_ids[corner]]
			fixed += vertex.fixed_world * factor
			for influence: Dictionary in vertex.moving:
				var bone: StringName = influence.bone
				if not moving.has(bone): moving[bone] = [Vector3.ZERO, 0.0]
				moving[bone][0] += influence.weighted_bind_point * factor
				moving[bone][1] += influence.weight * factor
		var cap := float(sample.get("cap_m", 0.0))
		var normal: Vector3 = posed[index].normal_world
		# Unlabelled blended palm triangles use the established palm allowance;
		# dorsal and forearm skin retain their zero-overlap guard.
		var relative: Vector3 = posed[index].point_world - _prepared.references.wrist_world
		if cap == 0.0 and sample.get("digit", &"") == &"" and relative.dot(_tangent) > 0.0 and relative.dot(_outward) > 0.0 and normal.dot(_outward) > 0.0:
			cap = PALM_CAP_M
		if not key.is_empty():
			# Classification can differ at incident faces. Keep differing caps so
			# the strictest safety witness survives regardless of triangle order.
			key += ":" + str(cap)
			if seen.has(key): continue
			seen[key] = true
		var normal_bone: StringName = &""
		var digit: StringName = sample.get("digit", &"")
		var section: int = int(sample.get("section", 0)) - 1
		if _prepared.adapter.digit_inputs.has(digit) and section >= 0 and section < 3:
			normal_bone = _prepared.adapter.digit_inputs[digit].snapshot.bone_names[section]
			normal = (_prepared.open_frames_world[normal_bone] as Transform3D).basis.inverse() * normal
		result.append({"fixed":fixed, "moving":moving, "sample":sample, "cap":cap,
			"normal":normal, "normal_bone":normal_bone})
	return result

func _target_normals(block: Array, frames: Dictionary) -> Dictionary:
	var entry: Dictionary = {}
	for cached: Dictionary in _normal_cache:
		if is_same(cached.block, block) and cached.count == block.size(): entry = cached; break
	if entry.is_empty():
		var samples: Array = []
		var indices: Array[int] = []
		for i: int in block.size():
			if not block[i].sample.has("target_section"): continue
			indices.append(i)
			for corner: int in 3:
				var sample: Dictionary = block[i].sample.duplicate()
				sample.barycentric = Vector3.ZERO
				sample.barycentric[corner] = 1.0
				samples.append(sample)
		entry = {"block":block, "count":block.size(), "indices":indices, "corners":_pack_samples(samples)}
		_normal_cache.append(entry)
	var points := _points(entry.corners, frames)
	var normals := {}
	for target: int in entry.indices.size():
		var index: int = entry.indices[target]
		var start := target * 3
		var cross := (points[start+1] - points[start]).cross(points[start+2] - points[start])
		normals[index] = cross.normalized() * float(block[index].sample.normal_sign)
	return normals

func _points(block: Array, frames: Dictionary) -> PackedVector3Array:
	# Carrier coefficients are immutable after _pack_samples(). Appended safety
	# witnesses change the block size. Compare Array identity, never deep hashes.
	if not is_same(_point_cache_frames, _prepared.open_frames_world):
		_point_cache.clear()
		_point_cache_frames = _prepared.open_frames_world
	var entry: Dictionary = {}
	for cached: Dictionary in _point_cache:
		if is_same(cached.block, block): entry = cached; break
	if entry.is_empty():
		entry = {"block":block, "count":-1, "kernel":ClassDB.instantiate(&"GripSkinPointKernel")}
		_point_cache.append(entry)
	if entry.count != block.size():
		var prepared: Dictionary = entry.kernel.prepare(block, _prepared.open_frames_world)
		if not prepared.get("valid", false):
			push_error("Native skin point preparation failed: " + str(prepared))
			return PackedVector3Array()
		entry.count = block.size()
	return entry.kernel.evaluate(frames, _weapon.origin)

func _query(kind: StringName, points: PackedVector3Array) -> Dictionary:
	_metrics.native_surface_queries += 1
	return _kernels[kind].evaluate(points)

func _place_palm(states: Dictionary, tangent_offset: float) -> void:
	var target: Vector3 = _prepared.references.knuckle_midpoint_world + _tangent * tangent_offset + _outward * 0.15
	_weapon.origin += _transverse(target - _weapon * _pivot)
	var frames := _frames(states)
	for iteration: int in 14:
		var query := _query(&"physical", _points(_palm, frames))
		var nearest := INF
		var selected := -1
		for i: int in query.signed_distances.size():
			if float(query.signed_distances[i]) < nearest:
				nearest = query.signed_distances[i]
				selected = i
		var error := nearest + PALM_CAP_M - CONTACT_BAND_M
		if absf(error) < CONTACT_BAND_M: break
		var gradient := _transverse(query.normals[selected])
		if gradient.length_squared() < 0.001: break
		var move := (gradient * error / gradient.length_squared()).limit_length(0.15)
		var before := _weapon.origin
		var improved := false
		for fraction: float in [1.0, 0.5, 0.25]:
			_weapon.origin = before + move * fraction
			var trial := _query(&"physical", _points(_palm, frames))
			var next := INF
			for gap: float in trial.signed_distances: next = minf(next, gap)
			if absf(next + PALM_CAP_M - CONTACT_BAND_M) < absf(error):
				improved = true
				break
		if not improved:
			_weapon.origin = before
			break

func _digit_cost(id: StringName, angles: Dictionary) -> float:
	_metrics.candidate_steps += 1
	var states := _states(angles)
	var frames := _frames(states)
	var block: Array = _blocks[id]
	var points := _points(block, frames)
	var physical := _query(&"physical", points)
	var normals := _target_normals(block, frames)
	var targets := PackedVector3Array()
	var target_indices := {}
	for i: int in block.size():
		if block[i].sample.has("target_section"):
			target_indices[i] = targets.size()
			targets.append(points[i])
	var target := _query(&"digit", targets)
	var s1 := _query(&"non_thumb_s1", targets)
	var best := [INF, INF, INF]
	var penalty := 0.0
	for i: int in block.size():
		var carrier: Dictionary = block[i]
		var gap := float(physical.signed_distances[i])
		var excess := maxf(-gap - float(carrier.cap) + CONTACT_BAND_M, 0.0) * 1000.0
		penalty += excess * excess * (10000000.0 if _repairing else 10000.0)
		var section := int(carrier.sample.get("target_section", -1))
		if section < 0: continue
		var error := (gap + float(carrier.cap) - CONTACT_BAND_M) * 1000.0
		var separation := maxf(gap - CONTACT_BAND_M, 0.0) * 1000.0
		var bell := float(carrier.sample.get("bell", 1.0))
		var target_index: int = target_indices[i]
		var target_gap := float(s1.signed_distances[target_index] if section == 0 else target.signed_distances[target_index])
		var kind: StringName = &"non_thumb_s1" if section == 0 and id != &"thumb" else &"digit"
		var target_normal: Vector3 = s1.normals[target_index] if kind == &"non_thumb_s1" else target.normals[target_index]
		target_gap = (target_gap + _target_depth_delta(kind, target_normal)) * 1000.0
		# Close missing pads before deepening an already engaged one. Depth and
		# the saved wrapper remain soft goals behind the unchanged physical cap.
		# A bounded location term keeps the preference active at zero depth error.
		var cost := 16.0 * separation * separation + 0.15 * error * error + 0.15 * target_gap * target_gap + LOCATION_PREFERENCE_WEIGHT * (1.0 - bell)
		var normal: Vector3 = normals[i]
		var facing: float = normal.normalized().dot(physical.normals[i])
		if facing > 0.0: cost += 100.0 + 1000.0 * facing * facing
		best[section] = minf(best[section], cost)
	for section: int in 3:
		if id == &"thumb" and section == 0: continue
		penalty += float(best[section]) * SECTION_PULL_WEIGHTS[section]
	penalty += _bone_crossings(states, id) * 100000.0
	if id != &"thumb":
		var middle_bend := absf(rad_to_deg(float(angles[id][1]) - float(_prepared.open_angles[id][1])))
		var distal_bend := absf(rad_to_deg(float(angles[id][2]) - float(_prepared.open_angles[id][2])))
		penalty += DISTRIBUTED_BEND_WEIGHT * pow(distal_bend - DISTAL_TO_MIDDLE_BEND_RATIO * middle_bend, 2.0)
	return penalty

func _target_depth_delta(kind: StringName, world_normal: Vector3) -> float:
	# Saved inset distances live in source metres. Carry their normal offset
	# through the same metric basis as the saved mesh, including authored scale.
	var basis: Basis = _weapon.basis * (_surface.source_to_weapon as Transform3D).basis
	var source_normal := (basis.transposed() * world_normal).normalized()
	return float(_surface.attraction_depth_offsets_m.get(kind, 0.0)) * (basis * source_normal).dot(world_normal)

func _palm_cost(states: Dictionary) -> float:
	var result := _query(&"physical", _points(_palm, _frames(states)))
	var nearest := INF
	var penalty := 0.0
	for gap: float in result.signed_distances:
		nearest = minf(nearest, gap)
		penalty += pow(maxf(-gap - PALM_CAP_M, 0.0) * 1000.0, 2.0) * 100.0
	return penalty + 8.0 * pow((nearest + PALM_CAP_M - CONTACT_BAND_M) * 1000.0, 2.0) + 64.0 * pow(maxf(nearest - CONTACT_BAND_M,0.0) * 1000.0,2.0)

func _assess(angles: Dictionary) -> Dictionary:
	var states := _states(angles)
	var frames := _frames(states)
	var cost := _palm_cost(states)
	var contacts: Array[StringName] = []
	var engaged: Array[StringName] = []
	var sections: Array = []
	for id: StringName in (ALL_DIGITS if _thumb_active else ACTIVE):
		cost += _digit_cost(id, angles)
		var block: Array = _blocks[id]
		var query := _query(&"physical", _points(block, frames))
		var normals := _target_normals(block, frames)
		for section: int in 3:
			if id == &"thumb" and section == 0: continue
			var best := INF
			var selected := {}
			for i: int in block.size():
				var sample: Dictionary = block[i].sample
				if sample.get("target_section", -1) != section: continue
				var normal: Vector3 = normals[i]
				if normal.normalized().dot(query.normals[i]) >= 0.0: continue
				var gap := float(query.signed_distances[i])
				var error := absf(gap + float(block[i].cap))
				if error < best:
					best = error
					selected = {"section":_contact_key(id,section), "gap_m":gap, "cap_m":block[i].cap,
						"percent":sample.get("percent", -1.0), "angles_rad":angles[id], "target_valid":true,
						"physically_engaged":gap <= CONTACT_BAND_M and gap >= -float(block[i].cap) - NUMERIC_GUARD_M,
						"actual_target_hit":_at_max_contact_depth({"hit":true,"gap_m":gap}, block[i].cap)}
			if selected.get("actual_target_hit", false): contacts.append(_contact_key(id,section))
			if selected.get("physically_engaged", false): engaged.append(_contact_key(id,section))
			sections.append(selected)
	var safety_query := _query(&"physical", _points(_safety, frames))
	var worst := 0.0
	var offender := {}
	for i: int in _safety.size():
		var excess := -float(safety_query.signed_distances[i]) - float(_safety[i].cap)
		if excess > worst:
			worst = excess
			offender = {"sample":_safety[i].sample, "gap_m":safety_query.signed_distances[i], "effective_cap_m":_safety[i].cap}
	var crossings := 0
	for id: StringName in (ALL_DIGITS if _thumb_active else ACTIVE): crossings += _bone_crossings(states,id)
	var safe := worst <= NUMERIC_GUARD_M and crossings == 0
	var palm_query := _query(&"physical", _points(_palm, frames))
	var palm_gap := INF
	for gap: float in palm_query.signed_distances: palm_gap = minf(palm_gap,gap)
	return {"angles":angles.duplicate(true), "weapon":_weapon, "cost":cost, "safe":safe,
		"max_excess_m":worst, "contacts":contacts, "engaged_sections":engaged, "sections":sections, "palm_gap_m":palm_gap,
		"palm_engaged":palm_gap <= CONTACT_BAND_M and palm_gap >= -PALM_CAP_M - NUMERIC_GUARD_M,
		"palm_contact":_at_max_contact_depth({"hit":true,"gap_m":palm_gap},PALM_CAP_M),
		"safety":{"safe":safe, "max_excess_m":worst, "worst":offender, "bone_crossings":crossings, "sample_count":_safety.size()}}

func _better(candidate: Dictionary, current: Dictionary) -> bool:
	if current.is_empty(): return true
	if candidate.safe != current.safe: return candidate.safe
	if candidate.safe and bool(candidate.get("palm_engaged", false)) != bool(current.get("palm_engaged", false)):
		return candidate.get("palm_engaged", false)
	if not candidate.safe and absf(float(candidate.max_excess_m) - float(current.max_excess_m)) > NUMERIC_GUARD_M:
		return candidate.max_excess_m < current.max_excess_m
	return candidate.cost < current.cost

func _bone_crossings(states: Dictionary, id: StringName) -> int:
	var points := PackedVector3Array()
	var origins: Array = states[id].joint_origins_world
	# The prepared terminal endpoint is an axial SKIN hit, not a bone endpoint.
	# Only joint-to-joint spans are known hard bone geometry. S3 keeps all of
	# its material/side guards; treating its skin tip as bone forbids flesh give.
	for j: int in 2:
		points.append(origins[j] - _weapon.origin)
		points.append(origins[j+1] - _weapon.origin)
	var hits: PackedByteArray = _kernels[&"physical"].intersects_segments(points)
	var count := 0
	for hit: int in hits: count += int(hit != 0)
	return count

func _states(angles: Dictionary) -> Dictionary:
	var out := {}
	for id: StringName in _prepared.adapter.digit_inputs:
		var values: Array[float] = []
		for value: float in angles[id]: values.append(value)
		out[id] = _spatial._forward_kinematics(_prepared.adapter.digit_inputs[id].snapshot, values)
	return out

func _frames(states: Dictionary) -> Dictionary:
	var frames := {}
	for id: StringName in states:
		var snapshot: Dictionary = _prepared.adapter.digit_inputs[id].snapshot
		for joint: int in 3: frames[snapshot.bone_names[joint]] = states[id].joint_transforms_world[joint]
	return frames

func _contact_key(id: StringName, section: int) -> StringName:
	return StringName("%s:S%d" % [id, section + 1])

func _at_max_contact_depth(observed: Dictionary, cap_m: float) -> bool:
	if not observed.get("hit", false) or observed.get("depth_is_lower_bound", false) or cap_m <= 0.0: return false
	var gap := float(observed.get("gap_m", INF))
	return is_finite(gap) and gap >= -cap_m - NUMERIC_GUARD_M and gap <= -cap_m + CONTACT_BAND_M

func _transverse(value: Vector3) -> Vector3:
	return value - _axis * value.dot(_axis)

func _cancelled() -> bool:
	return _cancel_check.is_valid() and bool(_cancel_check.call())

func _progress(phase: StringName) -> void:
	_events.append({"phase":phase, "ticks_usec":Time.get_ticks_usec()})
	if _progress_callback.is_valid(): _progress_callback.call({"stage":phase, "phase":phase, "method":METHOD})

func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid":false, "reason":reason, "detail":detail, "method":METHOD,
		"cancelled":reason == "acquisition_cancelled", "grip_accepted":false, "material_safe":false, "thumb_solve_enabled":false}
