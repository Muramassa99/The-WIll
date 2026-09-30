extends SceneTree

# Standalone persisted-data proof: no rig, mesh bake, rays or pose solving.
# Requires THE_WILL_ANATOMY_RESOURCE_PATH; never saves to a new location.
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Origin = preload("res://core/models/combat_origin_record.gd")
const Registry = preload("res://core/resolvers/combat_origin_registry.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const LOOKUP_ITERATIONS := 10000
const PRECISION_M := 0.000001
var checks: Array[Dictionary] = []
var report: Dictionary = {"schema": "character_hand_anatomy_store_verification_v1", "anatomy_recomputed": false, "contact_shape_validated": false}


func _init() -> void:
	var path := OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH").strip_edges()
	_check(not path.is_empty() and FileAccess.file_exists(path), "explicit existing anatomy Resource path")
	if path.is_empty() or not FileAccess.file_exists(path):
		_finish()
		return
	report["path"] = path
	var original_hash := FileAccess.get_sha256(path)
	var original_modified := FileAccess.get_modified_time(path)
	var started := Time.get_ticks_usec()
	var standalone := ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	report["standalone_resource_load_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_check(standalone != null, "Resource loads without character scene instantiation")
	if standalone == null:
		_finish()
		return
	var store := Store.new()
	started = Time.get_ticks_usec()
	var validation: Dictionary = store.validate(standalone)
	report["standalone_validation_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_check(bool(validation.get("valid", false)), "stored structure and declared origin chains validate", validation)
	if not bool(validation.get("valid", false)):
		_finish()
		return
	var signature := String(standalone.get("source_signature"))
	var revision := String(standalone.get("preparation_revision"))
	started = Time.get_ticks_usec()
	var matching: Dictionary = store.load_matching(path, signature, revision)
	report["matching_fresh_load_and_validation_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	_check(bool(matching.get("valid", false)), "matching signature and revision load")
	if not bool(matching.get("valid", false)):
		_finish()
		return
	var loaded: Resource = matching["resource"]
	_check(loaded != standalone, "cache-ignore returns an independent Resource")
	var pristine := var_to_bytes(_payload(loaded))
	_check(pristine == var_to_bytes(_payload(standalone)), "all stored data, including source metadata and skin weights, agree across independent loads")
	var wrong_signature: Dictionary = store.load_matching(path, signature + "_wrong", revision)
	_check(not bool(wrong_signature.valid) and wrong_signature.status == "source_signature_mismatch", "wrong source signature rejected")
	var wrong_revision: Dictionary = store.load_matching(path, signature, revision + "_wrong")
	_check(not bool(wrong_revision.valid) and wrong_revision.status == "preparation_revision_mismatch", "wrong preparation revision rejected")
	var duplicate_save: Dictionary = store.save_new(loaded, path)
	_check(not bool(duplicate_save.valid) and duplicate_save.status == "definition_already_exists", "save_new refuses the existing Resource path")
	_test_mutations(loaded, store)
	_check(pristine == var_to_bytes(_payload(loaded)), "nested duplicate mutations and negative validation leave the loaded definition unchanged")
	_check(pristine == var_to_bytes(_payload(standalone)), "independently loaded reference remains unchanged")
	_check(not _has_proxy_dimensions(_payload(loaded)), "persisted data contain no fitted capsule radii or legacy terminal length fields")
	_check(loaded.get("root_origin_id") == &"RL_BoneRoot" and loaded.get("measurement_status") == &"measured_anatomy_proof" and not bool(loaded.get("contact_shape_validated")), "anatomy remains measured proof with explicit machine origin and unvalidated contact")
	_check_digits(loaded)
	_measure_lookups(loaded.get("digits"))
	_check(FileAccess.get_sha256(path) == original_hash and FileAccess.get_modified_time(path) == original_modified, "Resource file SHA-256 and modified time remain unchanged")
	report["file_sha256"] = original_hash
	report["source_signature"] = signature
	report["preparation_revision"] = revision
	_finish()


func _test_mutations(loaded: Resource, store: RefCounted) -> void:
	var copy: Resource = loaded.duplicate(true)
	copy.get("digits")[0]["section_lengths_m"][0] += 0.001
	copy.get("digits")[0]["outline_samples"][0]["angles_rad"][0] += 0.01
	var weights: PackedFloat32Array = copy.get("reference_skin")["surfaces"][0]["weights"]
	weights[0] += 0.125
	copy.get("reference_skin")["surfaces"][0]["weights"] = weights
	_check(var_to_bytes(_payload(copy)) != var_to_bytes(_payload(loaded)), "deep duplicate accepts isolated nested measurement, outline and weight edits")
	copy = loaded.duplicate(true)
	var plane_id: StringName = copy.get("digits")[0]["plane_origin_id"]
	for record: Dictionary in copy.get("origin_records"):
		if record["origin_id"] == plane_id:
			record["parent_origin_id"] = &"VerifierMissingParentOrigin"
	_check(not bool(store.validate(copy).get("valid", true)), "malformed plane origin parent chain rejected")
	copy = loaded.duplicate(true)
	copy.get("digits")[0]["section_lengths_m"][0] = NAN
	_check(not bool(store.validate(copy).get("valid", true)), "nonfinite section length rejected")
	copy = loaded.duplicate(true)
	copy.get("character_measurements")["elapsed_milliseconds"] = 1.0
	_check(not bool(store.validate(copy).get("valid", true)), "injected transient timing field rejected without creating a runtime Timer")
	copy = loaded.duplicate(true)
	copy.get("digits")[0].erase("hinge_axis_origin_ids")
	_check(not bool(store.validate(copy).get("valid", true)), "missing companion origin IDs for hinge axes rejected")
	copy = loaded.duplicate(true)
	copy.get("digits")[0]["relative_transform_origin_ids"][0] = copy.get("digits")[0]["bone_names"][0]
	_check(not bool(store.validate(copy).get("valid", true)), "wrong but registered relative-transform parent origin rejected")
	if String(loaded.get("preparation_revision")) == Store.FULL_HAND_PREPARATION_REVISION:
		for index: int in range(loaded.get("digits").size()):
			copy = loaded.duplicate(true)
			var missing: Dictionary = copy.get("digits")[index]
			copy.get("digits").remove_at(index)
			var missing_result: Dictionary = store.validate(copy)
			_check(not bool(missing_result.get("valid", true)) and missing_result.get("status") == "incomplete_full_hand_digit_coverage", "full-hand revision rejects missing " + String(missing.slot_id) + "/" + String(missing.digit_id))
		copy = loaded.duplicate(true)
		copy.get("digits")[0]["digit_id"] = &"unknown_digit"
		var unknown_result: Dictionary = store.validate(copy)
		_check(not bool(unknown_result.get("valid", true)) and unknown_result.get("status") == "incomplete_full_hand_digit_coverage", "ten entries with an unknown digit do not satisfy full-hand coverage")


func _check_digits(loaded: Resource) -> void:
	var digits: Array = loaded.get("digits")
	var registry := Registry.new(false)
	for data: Dictionary in loaded.get("origin_records"):
		var record := Origin.new()
		for key: String in ["origin_id", "parent_origin_id", "transform_to_parent", "owner_system", "resolve_phase", "is_dynamic"]:
			record.set(key, data[key])
		registry.register_origin(record)
	var selected: Array[StringName] = [&"middle", &"thumb"]
	var revision := String(loaded.get("preparation_revision"))
	if revision == Store.FULL_HAND_PREPARATION_REVISION:
		selected = Rules.DIGIT_IDS.duplicate()
	_check(revision in ["rest_middle_thumb_surface_measurements_v1", Store.FULL_HAND_PREPARATION_REVISION], "explicit historical or full-hand preparation revision")
	var expected := {}
	for slot: StringName in [Rules.SLOT_RIGHT, Rules.SLOT_LEFT]:
		for digit_id: StringName in selected:
			expected[String(slot) + "/" + String(digit_id)] = false
	var outline_count := 0
	var measured_ray_count := 0
	var largest_length_error := 0.0
	for digit: Dictionary in digits:
		var identity := String(digit["slot_id"]) + "/" + String(digit["digit_id"])
		if expected.has(identity):
			expected[identity] = true
		var authored: Dictionary = {}
		for candidate: Dictionary in Rules.get_surface_solver_side_rules(digit.slot_id).get("digits", []):
			if candidate.get("digit_id") == digit.digit_id:
				authored = candidate
		var rules_match := not authored.is_empty()
		for key: String in ["bone_names", "hinge_axes_local", "hinge_axis_origin_ids", "min_angles_rad", "max_angles_rad", "preferred_angles_rad"]:
			rules_match = rules_match and var_to_bytes(digit.get(key)) == var_to_bytes(authored.get(key))
		_check(rules_match, identity + " retains authored bone names, hinge axes and joint ranges without retuning")
		var plane_to_machine: Transform3D = digit["plane_to_machine"]
		var machine_to_plane := plane_to_machine.affine_inverse()
		# Every measured point remains in this digit's declared plane origin.
		var joint_points_in_plane_m: Array[Vector3] = []
		for id: StringName in digit["calibrated_joint_origin_ids"]:
			var joint_to_machine: Transform3D = registry.resolve_transform_to_machine(id)
			joint_points_in_plane_m.append(machine_to_plane * joint_to_machine.origin)
		var lengths_match := joint_points_in_plane_m.size() == 3
		for joint: int in range(2):
			var error := absf(joint_points_in_plane_m[joint].distance_to(joint_points_in_plane_m[joint + 1]) - float(digit["section_lengths_m"][joint]))
			largest_length_error = maxf(largest_length_error, error)
			lengths_match = lengths_match and error <= PRECISION_M
		_check(lengths_match, identity + " first two stored lengths agree with resolved calibrated joint origins within 0.001 mm")
		_check(bool(digit.get("terminal_length_is_axial_skin_extent", false)) and not bool(digit.get("contact_shape_validated", true)) and bool(digit.get("outline_samples_are_not_all_angle_envelopes", false)), identity + " records skin-derived terminal extent and limited proof coverage")
		var pose_ids := {&"zero": false, &"half_preferred": false, &"preferred": false}
		var samples_valid: bool = digit.get("outline_samples", []).size() == 3
		for sample: Dictionary in digit.get("outline_samples", []):
			outline_count += 1
			if pose_ids.has(sample.get("pose_id")) and not bool(pose_ids[sample["pose_id"]]):
				pose_ids[sample["pose_id"]] = true
			else:
				samples_valid = false
			samples_valid = samples_valid and sample.get("origin_id") == digit["plane_origin_id"] and sample.get("angles_rad", []).size() == 3 and not sample.get("segments_m", []).is_empty()
			for segment: Variant in sample.get("segments_m", []):
				samples_valid = samples_valid and segment.size() == 2
				for point: Variant in segment:
					samples_valid = samples_valid and point is Vector2 and point.is_finite() and point.length() <= float(digit["outline_window_m"]) + PRECISION_M
		_check(samples_valid and not pose_ids.values().has(false), identity + " has three actual outline poses with finite, reach-window-bounded segments in its named plane")
		var rays_valid: bool = digit.get("skin_cross_sections", []).size() == 3
		for section: Dictionary in digit.get("skin_cross_sections", []):
			rays_valid = rays_valid and section.get("origin_id") == digit["plane_origin_id"] and section.get("cross_sections", []).size() == 3
			for cross_section: Dictionary in section.get("cross_sections", []):
				for name: String in ["u_plus", "u_minus", "normal_plus", "normal_minus"]:
					var ray: Dictionary = cross_section.get("rays", {}).get(name, {})
					measured_ray_count += 1
					rays_valid = rays_valid and float(ray.get("distance_m", -1.0)) > 0.0 and ray.get("position_in_plane_m") is Vector3 and int(ray.get("surface_triangle_index", -1)) >= 0
		_check(rays_valid, identity + " retains measured asymmetric skin ray hits and source triangles")
	_check(digits.size() == expected.size() and not expected.values().has(false), "exactly the preparation revision's declared digits on both sides are persisted")
	_check(outline_count == expected.size() * 3 and measured_ray_count == expected.size() * 36, "each prepared digit has three outline poses and 36 measured skin rays")
	report["digit_count"] = digits.size()
	report["outline_pose_count"] = outline_count
	report["measured_ray_count"] = measured_ray_count
	report["largest_resolved_section_length_error_m"] = largest_length_error


func _measure_lookups(digits: Array) -> void:
	var checksum := 0.0
	var started := Time.get_ticks_usec()
	for iteration: int in range(LOOKUP_ITERATIONS):
		var digit: Dictionary = digits[iteration % digits.size()]
		var joint := iteration % 3
		checksum += float(digit["section_lengths_m"][joint]) + float(digit["min_angles_rad"][joint]) + float(digit["max_angles_rad"][joint])
	var elapsed := Time.get_ticks_usec() - started
	report["prepared_scalar_lookup"] = {"iterations": LOOKUP_ITERATIONS, "scalar_reads_per_iteration": 3, "elapsed_ms": float(elapsed) / 1000.0, "microseconds_per_iteration": float(elapsed) / LOOKUP_ITERATIONS, "checksum": checksum, "scope": "dictionary and array reads only; excludes all grip solving, preparation and validation"}
	_check(is_finite(checksum), "bounded prepared-scalar lookup checksum is finite")


func _payload(definition: Resource) -> Dictionary:
	var result := {}
	for key: String in Store.FIELDS:
		result[key] = definition.get(key)
	return result


func _has_proxy_dimensions(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if str(key) in ["capsule_radii_m", "radii_m", "radius_m", "terminal_length_m"] or _has_proxy_dimensions(value[key]):
				return true
	elif value is Array:
		for item: Variant in value:
			if _has_proxy_dimensions(item):
				return true
	return false


func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "label": label, "details": details})
	print("%s: %s" % ["PASS" if passed else "FAIL", label])


func _finish() -> void:
	var failures := 0
	for item: Dictionary in checks:
		if not bool(item["passed"]):
			failures += 1
	report["checks"] = checks
	report["failures"] = failures
	print("CHARACTER_HAND_ANATOMY_STORE_VERIFICATION=" + JSON.stringify(report))
	quit(0 if failures == 0 else 1)
