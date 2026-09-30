extends SceneTree

const Baker = preload("res://tools/grip_plane_proof/prepare_character_palmar_contact.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const HandSkin = preload("res://tools/grip_plane_proof/prepared_hand_skin_query.gd")
const SIGNATURE := "0fb9e5dbe88cd71e342f4efe106676026345d283374abede7dc98853dd784bf5"
const ANATOMY_PATH := "res://tools/grip_plane_proof/prepared_characters/josie/" + SIGNATURE + ".tres"
const OUTPUT_FOLDER := "res://tools/grip_plane_proof/prepared_characters/josie"
const ROOT := &"RL_BoneRoot"
const POSITION_EPSILON_M := 0.00001

var _assertions := 0
var _failures: Array[String] = []
var _cases: Array[Dictionary] = []
var _resource_path := ""
var _resource_for_save: Resource


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_usec()
	var loaded: Dictionary = Store.new().load_matching(ANATOMY_PATH, SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if _check(loaded.get("valid", false), "existing anatomy loads with matching source signature"):
		_verify_character(loaded.resource)
	_test_first_hit_rejections()
	if _resource_for_save != null and _failures.is_empty():
		_save_new_resource(_resource_for_save)
	var report := {"schema": "prepared_palmar_core_verifier_v1", "ok": _failures.is_empty(),
		"assertion_count": _assertions, "failures": _failures, "cases": _cases,
		"anatomy_path": ANATOMY_PATH, "source_signature": SIGNATURE, "saved_resource_path": _resource_path,
		"scope": "reference_rest_core_sample_preparation_not_whole_palm_or_grip",
		"captured_articulation_used": false, "weapon_input_used": false,
		"palm_overlap_policy_defined": false, "solid_enclosure_verified": false,
		"actual_3d_grip_verified": false, "production_pose_written": false,
		"total_verifier_ms": float(Time.get_ticks_usec() - started) / 1000.0}
	var output := "C:/WORKSPACE/test_artifacts/verify_prepared_palmar_contact_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write palmar preparation verifier report"); quit(1); return
	file.store_string(JSON.stringify(_numbers(report), "\t")); file.close()
	print("PREPARED_PALMAR_CONTACT_RESULT=" + output)
	print("PREPARED_PALMAR_CONTACT_SUMMARY=" + JSON.stringify({"ok": report.ok, "assertions": _assertions, "failures": _failures, "resource": _resource_path}))
	quit(0 if _failures.is_empty() else 1)


func _verify_character(definition: Resource) -> void:
	var reference_before := var_to_bytes([definition.reference_skin, definition.digits, definition.origin_records, definition.source_manifest])
	var source_sha := FileAccess.get_sha256(ANATOMY_PATH)
	var requested := OS.get_environment("THE_WILL_COHERENT_CAPTURE_PATHS").split(";", false)
	if not _check(not requested.is_empty(), "explicit coherent captures supply character metric presentation"):
		return
	var baseline: Resource
	var first_presentation := Transform3D.IDENTITY
	var baker := Baker.new()
	for raw_path: String in requested:
		var path := _capture_path(raw_path)
		if not _check(not path.is_empty(), "capture path is an existing workspace artifact: " + raw_path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if not _check(file != null, "capture opens read-only"): continue
		var value: Variant = file.get_var(false)
		file.close()
		if not _check(value is Dictionary and value.get("posed_character") is Dictionary, "capture contains coherent pose header"): continue
		var packet: Dictionary = value.posed_character
		if not _check(packet.get("valid", false) and packet.get("schema") == &"coherent_skin_pose_capture_v1" and packet.get("anatomy_signature") == SIGNATURE and packet.get("machine_to_world") is Transform3D, "capture signature and presentation are declared"): continue
		var packet_before := var_to_bytes(packet)
		# Only this transform enters bake. Captured bone poses and weapons cannot
		# influence character-owned sample membership through this API.
		var presentation: Transform3D = packet.machine_to_world
		var result: Dictionary = baker.bake(definition, presentation)
		_cases.append({"capture_path": path, "capture_sha256": FileAccess.get_sha256(path),
			"valid": result.get("valid", false), "reason": result.get("reason", ""),
			"preparation_ms": result.get("preparation_ms"), "slot_metadata": result.get("slot_metadata", {})})
		if not _check(result.get("valid", false), "both hands produce nine paired core samples: " + str(result.get("reason", ""))): continue
		var resource: Resource = result.resource
		_validate_output(resource, definition, presentation)
		if baseline == null:
			baseline = resource
			first_presentation = presentation
		else:
			_compare_preparations(baseline, resource, "different capture presentations retain character samples")
		_check(var_to_bytes(packet) == packet_before, "capture packet remains byte-identical")
	if baseline != null:
		var rigid := Transform3D(Basis.from_euler(Vector3(0.31, -0.57, 0.23)), Vector3(0.27, -0.18, 0.41))
		var covariant: Dictionary = baker.bake(definition, rigid * first_presentation)
		if _check(covariant.get("valid", false), "rigidly moved metric presentation remains valid"):
			_compare_preparations(baseline, covariant.resource, "rigid covariance")
			_validate_output(covariant.resource, definition, rigid * first_presentation)
		var scaled := first_presentation
		scaled.basis *= 1.2
		_check(not baker.bake(definition, scaled).get("valid", false), "changed character metric is rejected")
		var mirrored := first_presentation
		mirrored.basis.x = -mirrored.basis.x
		_check(not baker.bake(definition, mirrored).get("valid", false), "unprepared reflection is rejected")
		var damaged: Resource = definition.duplicate(true)
		damaged.reference_skin.bone_origin_records.erase(&"CC_Base_R_Mid1")
		_check(not baker.bake(damaged, first_presentation).get("valid", false), "changed or missing reference origin is rejected")
		_check(not baseline.palm_overlap_policy_defined and not baseline.solid_enclosure_verified and not baseline.complete_palm_partition_verified, "core preparation does not invent cap, enclosure or full partition")
	_check(var_to_bytes([definition.reference_skin, definition.digits, definition.origin_records, definition.source_manifest]) == reference_before, "source anatomy values remain byte-identical")
	_check(FileAccess.get_sha256(ANATOMY_PATH) == source_sha, "existing anatomy file remains unchanged")
	if baseline != null and _failures.is_empty():
		_resource_for_save = baseline


func _validate_output(resource: Resource, definition: Resource, presentation: Transform3D) -> void:
	_check(resource.complete and resource.anatomy_signature == SIGNATURE and resource.recipe_fingerprint.length() == 64, "output declares complete core sampling and source fingerprint")
	var registered: Dictionary = HandSkin.new()._registry(resource.origin_records, &"bake_time")
	if not _check(registered.get("valid", false), "all saved core frame chains resolve to machine root"): return
	var query := HandSkin.new()
	var prepared: Dictionary = query.prepare(definition.reference_skin, SIGNATURE)
	var mapping := {}
	for name: StringName in definition.reference_skin.bind_bone_names: mapping[name] = name
	var posed: Dictionary = query.pose(prepared, {"anatomy_signature": SIGNATURE, "root_origin_id": ROOT,
		"pose_id": &"PalmarVerifierReferenceRest", "resolve_phase": &"bake_time", "machine_to_world": presentation,
		"origin_records": prepared.reference_origin_records, "bone_origin_ids": mapping,
		"mesh_origin_id": definition.reference_skin.vertices_origin_id})
	if not _check(posed.get("valid", false), "reference geometry reconstructs for source-hit checks"): return
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var samples: Array = resource.samples_by_slot.get(slot, [])
		_check(samples.size() == 9 and resource.slot_metadata[slot].complete and resource.slot_metadata[slot].rejected_samples.is_empty(), String(slot) + " has all nine strictly interior paired samples")
		for sample: Dictionary in samples:
			var bary: Vector3 = sample.footprint_barycentric
			_check(minf(bary.x, minf(bary.y, bary.z)) > 0.0 and absf(bary.x + bary.y + bary.z - 1.0) < 0.000001, "footprint sample is strictly interior")
			for side: String in ["palmar_hit", "dorsal_hit"]:
				var hit: Dictionary = sample[side]
				var surface: Dictionary = definition.reference_skin.surfaces[hit.surface_index]
				var first_vertex: int = prepared.surface_ranges[hit.surface_index].first_vertex
				var reconstructed := Vector3.ZERO
				for corner: int in range(3):
					var source_vertex: int = surface.indices[hit.surface_triangle_index * 3 + corner]
					_check(source_vertex == hit.source_vertex_indices[corner], "sample preserves source topology indices")
					reconstructed += posed.vertices_world[first_vertex + source_vertex] * hit.barycentric[corner]
				var frame: Transform3D = presentation * registered.registry.resolve_transform_to_machine(hit.reference_point_origin_id)
				_check(reconstructed.distance_to(frame * (hit.reference_point_m as Vector3)) <= POSITION_EPSILON_M, "source barycentrics round-trip through named reference frame")
				_check(2.0 * float(hit.hand_weight) > float(hit.total_weight) + Baker.BARYCENTRIC_EPSILON, "paired first hit has strict original Hand majority")


func _compare_preparations(a: Resource, b: Resource, label: String) -> void:
	_check(a.recipe_fingerprint == b.recipe_fingerprint, label + " fingerprint is placement independent")
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var first: Array = a.samples_by_slot[slot]
		var second: Array = b.samples_by_slot[slot]
		if not _check(first.size() == second.size(), label + " sample count agrees"): continue
		for index: int in range(first.size()):
			for side: String in ["palmar_hit", "dorsal_hit"]:
				var x: Dictionary = first[index][side]
				var y: Dictionary = second[index][side]
				_check(x.surface_index == y.surface_index and x.surface_triangle_index == y.surface_triangle_index, label + " source face remains the same")
				_check((x.reference_point_m as Vector3).distance_to(y.reference_point_m) <= POSITION_EPSILON_M, label + " measured physical point covaries")
				_check((x.barycentric as Vector3).distance_to(y.barycentric) < 0.0001, label + " source barycentrics agree within numerical tolerance")


func _test_first_hit_rejections() -> void:
	var hand := &"FixtureHand"
	var prepared := {"triangle_indices": PackedInt32Array([0, 1, 2]), "triangle_surface_ids": PackedInt32Array([0]),
		"triangle_local_ids": PackedInt32Array([0]), "surface_ranges": [{"first_vertex": 0}],
		"vertex_offsets": PackedInt32Array([0, 2, 4, 6]), "influence_binds": PackedInt32Array([0, 1, 0, 1, 0, 1]),
		"bind_bone_names": [hand, &"FixtureOther"], "influence_weights": PackedFloat64Array([0.4, 0.6, 0.4, 0.6, 0.4, 0.6])}
	var posed := {"vertices_world": PackedVector3Array([Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(0, 1, 1)])}
	var baker := Baker.new()
	var minority: Dictionary = baker._first_hit(prepared, posed, PackedInt32Array([0]), Vector3.ZERO, Vector3(0, 0, 1), hand, Transform3D.IDENTITY, &"FixturePlane")
	_check(not minority.valid and minority.reason == "first_hit_not_strict_Hand_majority", "Hand minority cannot become a palm sample")
	prepared.influence_weights = PackedFloat64Array([0.75, 0.5, 0.75, 0.5, 0.75, 0.5])
	var majority: Dictionary = baker._first_hit(prepared, posed, PackedInt32Array([0]), Vector3.ZERO, Vector3(0, 0, 1), hand, Transform3D.IDENTITY, &"FixturePlane")
	_check(majority.valid and absf(float(majority.total_weight) - 1.25) < 0.000001, "nonunit original weights remain unchanged in contact attribution")
	var absent: Dictionary = baker._first_hit(prepared, posed, PackedInt32Array([0]), Vector3.ZERO, Vector3(0, 0, -1), hand, Transform3D.IDENTITY, &"FixturePlane")
	_check(not absent.valid, "missing opposite surface cannot establish paired bracketing")
	var on_surface: Dictionary = baker._first_hit(prepared, posed, PackedInt32Array([0]), Vector3(0, 0, 1), Vector3(0, 0, 1), hand, Transform3D.IDENTITY, &"FixturePlane")
	_check(not on_surface.valid and on_surface.reason == "core_seed_on_reference_surface", "a seed on skin is rejected as ambiguous")


func _save_new_resource(resource: Resource) -> void:
	var destination := OUTPUT_FOLDER.path_join("palmar_core_" + resource.recipe_fingerprint + ".tres")
	if FileAccess.file_exists(destination):
		var existing := ResourceLoader.load(destination, "", ResourceLoader.CACHE_MODE_IGNORE)
		if _check(existing != null and existing.get("recipe_fingerprint") == resource.recipe_fingerprint and existing.get("anatomy_signature") == SIGNATURE and existing.get("complete") == true, "existing matching palmar resource is reused without overwrite"):
			_compare_preparations(resource, existing, "existing resource correspondence")
			_resource_path = destination
		return
	if _check(ResourceSaver.save(resource, destination) == OK, "new fingerprinted palmar resource saves without replacing old anatomy"):
		_resource_path = destination
		var saved := ResourceLoader.load(destination, "", ResourceLoader.CACHE_MODE_IGNORE)
		if _check(saved != null and saved.get("complete") == true, "saved palmar resource reloads complete"):
			_compare_preparations(resource, saved, "save/reload correspondence")


func _capture_path(raw: String) -> String:
	var path := raw.strip_edges().replace("\\", "/").simplify_path()
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/test_artifacts/") or path.get_extension().to_lower() != "bin" or path.substr(3).contains(":"):
		return ""
	var workspace := DirAccess.open("C:/WORKSPACE")
	if workspace == null or workspace.is_link("C:/WORKSPACE"): return ""
	var checked := "C:/WORKSPACE"
	for part: String in path.substr("C:/WORKSPACE/".length()).split("/", false):
		checked = checked.path_join(part)
		if workspace.is_link(checked): return ""
	return path if FileAccess.file_exists(path) else ""


func _check(condition: bool, label: String) -> bool:
	_assertions += 1
	if not condition: _failures.append(label)
	return condition


func _numbers(value: Variant) -> Variant:
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Transform3D: return {"basis_columns": [_numbers(value.basis.x), _numbers(value.basis.y), _numbers(value.basis.z)], "origin_m": _numbers(value.origin)}
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = _numbers(value[key])
		return out
	if value is Array or value is PackedInt32Array or value is PackedFloat64Array:
		var out: Array = []
		for item: Variant in value: out.append(_numbers(item))
		return out
	return value
