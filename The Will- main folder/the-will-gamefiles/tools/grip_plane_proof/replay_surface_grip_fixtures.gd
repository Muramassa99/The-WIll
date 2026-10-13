extends "res://tools/grip_plane_proof/trace_skill_crafter_grip.gd"

## Direct solver replay of hash-checked canonical inputs. UI loading is excluded
## from solver timing. Optional isolated-rig application/capture uses the live
## owner contract; this is not a natural UI acquisition or a visual acceptance.
## THE_WILL_GRIP_REPLAY_MANIFEST: captured manifest.json.
## THE_WILL_GRIP_REPLAY_DIR: fresh workspace output directory.
## THE_WILL_GRIP_REPLAY_NAMES: optional JSON array; default first fixture only.
## THE_WILL_GRIP_REPLAY_ALL=1 selects all; REPLAY_POSE=1 captures applied skin.
## REPLAY_VALIDATE_ONLY=1 validates/reconstructs inputs without running a solve.
const ReplayRig = preload("res://scenes/player/player_humanoid_rig.tscn")
const ReplayOwner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const ReplaySource = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const ReplaySkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const REPLAY_SOLVER := "res://runtime/player/grip/surface_driven_grip_solver.gd"
const REPLAY_ROOT := &"RL_BoneRoot"
var _replay_directory := ""
var _replay_rows: Array[Dictionary] = []
var _replay_failures: Array[String] = []

class ReplayErrors extends Logger:
	var entries: Array[Dictionary] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			entries.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var _replay_errors := ReplayErrors.new()

func _run() -> void:
	OS.add_logger(_replay_errors)
	var manifest_path := OS.get_environment("THE_WILL_GRIP_REPLAY_MANIFEST").replace("\\", "/").simplify_path()
	_replay_directory = OS.get_environment("THE_WILL_GRIP_REPLAY_DIR").replace("\\", "/").simplify_path()
	if not _replay_workspace(manifest_path) or not _replay_workspace(_replay_directory):
		push_error("Replay manifest and output directory must be workspace paths."); quit(1); return
	if FileAccess.file_exists(_replay_directory.path_join("summary.json")):
		push_error("Refusing to overwrite an earlier replay."); quit(1); return
	if DirAccess.make_dir_recursive_absolute(_replay_directory) != OK:
		push_error("Cannot create replay output directory."); quit(1); return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not raw is Dictionary or raw.get("schema") != "surface_grip_input_fixtures_v1" or not raw.get("failures", []).is_empty():
		push_error("Invalid input fixture manifest."); quit(1); return
	var manifest: Dictionary = raw
	_library_path = manifest.source_library
	_library_sha256 = manifest.source_library_sha256
	if not _replay_workspace(_library_path) or FileAccess.get_sha256(_library_path) != _library_sha256:
		push_error("Fixture source library changed."); quit(1); return
	var library: Resource = ResourceLoader.load(_library_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var names: Array = []
	var selection := OS.get_environment("THE_WILL_GRIP_REPLAY_NAMES")
	if not selection.is_empty():
		var parsed: Variant = JSON.parse_string(selection)
		if not parsed is Array or parsed.is_empty(): push_error("Replay names must be a nonempty JSON array."); quit(1); return
		names = parsed
	elif OS.get_environment("THE_WILL_GRIP_REPLAY_ALL") != "1":
		names = [manifest.fixtures[0].weapon_name]
	var solver_script: Script = load(REPLAY_SOLVER)
	var validate_only := OS.get_environment("THE_WILL_GRIP_REPLAY_VALIDATE_ONLY") == "1"
	for row: Dictionary in manifest.fixtures:
		if not names.is_empty() and row.weapon_name not in names: continue
		await _replay_case(row, library, solver_script, validate_only)
	if _replay_rows.is_empty(): _replay_failures.append("No requested fixture matched")
	if FileAccess.get_sha256(_library_path) != _library_sha256: _replay_failures.append("Source library changed")
	var summary := {"schema":"surface_grip_replay_v1","cases":_replay_rows,"failures":_replay_failures,
		"engine_errors":_replay_errors.entries,"solver_script":REPLAY_SOLVER,
		"solver_sha256":FileAccess.get_sha256(REPLAY_SOLVER),"input_manifest":manifest_path,
		"input_manifest_sha256":FileAccess.get_sha256(manifest_path),"source_library_sha256":_library_sha256,
		"validate_only":validate_only,"natural_end_to_end_verified":false,"grip_success_asserted":false,
		"engine_version":Engine.get_version_info()}
	_replay_json(_replay_directory.path_join("summary.json"), summary)
	print("SURFACE_GRIP_REPLAY ",_replay_directory.path_join("summary.json")," cases=",_replay_rows.size()," errors=",_replay_errors.entries.size())
	quit(0 if _replay_failures.is_empty() and _replay_errors.entries.is_empty() else 1)

func _replay_case(row: Dictionary, library: Resource, solver_script: Script, validate_only: bool) -> void:
	var path: String = row.input_path
	if not _replay_workspace(path) or FileAccess.get_sha256(path) != row.sha256:
		_replay_failures.append("Input changed: " + path); return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: _replay_failures.append("Cannot open " + path); return
	var input: Dictionary = file.get_var(false); file.close()
	if input.get("schema") != "surface_grip_replay_input_v1" or input.source_library_sha256 != _library_sha256:
		_replay_failures.append("Input provenance mismatch " + path); return
	_weapon_name = input.weapon_name
	_source_body_signature = input.input_body_signature
	var stage2: Resource
	for saved: Resource in library.get("saved_wips"):
		if saved != null and str(saved.get("forge_project_name")) == _weapon_name:
			if stage2 != null: _replay_failures.append("Ambiguous weapon name " + _weapon_name); return
			stage2 = saved.get("stage2_item_state")
	var stage: Dictionary = input.stage.duplicate(true)
	var frozen: Dictionary = stage.saved_grip_source
	var source := ReplaySource.from_stage2(stage2, frozen.source_to_weapon)
	if not source.get("valid",false) or source.source_body_signature != _source_body_signature or var_to_bytes(source.handle_packet) != var_to_bytes(frozen.handle_packet):
		_replay_failures.append("Saved physical source mismatch " + _weapon_name); return
	stage.saved_grip_source = source
	var profile: Resource = load(input.anatomy_profile)
	if profile == null or profile.get("anatomy").get("source_signature") != input.anatomy_signature:
		_replay_failures.append("Anatomy identity mismatch " + _weapon_name); return
	var output := {"weapon_name":_weapon_name,"input_path":path,"input_sha256":row.sha256,
		"slot":input.slot,"input_validated":true,"solver_executed":not validate_only}
	if validate_only:
		_replay_rows.append(output); print("GRIP_REPLAY_INPUT_VALID ",_weapon_name); return
	var solver: RefCounted = solver_script.new()
	var started := Time.get_ticks_usec()
	var result: Dictionary = solver.run(profile.get("anatomy"), stage, input.config.duplicate(true))
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	result.merge(solver.diagnostic_snapshot(),true)
	result["source_weapon_to_world"] = stage.object.weapon_to_world
	result["source_weapon_to_world_origin_id"] = REPLAY_ROOT
	result["vectors_origin_id"] = REPLAY_ROOT
	var prefix := _replay_directory.path_join(path.get_file().get_basename())
	var result_file := FileAccess.open(prefix + "_result.bin",FileAccess.WRITE)
	if result_file == null: _replay_failures.append("Cannot write replay result"); return
	result_file.store_var(result,false); result_file.close()
	var contacts: Array = result.get("accepted_hand_material_contacts",[])
	var state := {"solver_total_ms":elapsed,"solver_totals":result.get("totals",{}),
		"material_contacts":contacts,"sampled_material_safe":result.get("material_safe",false),
		"material_validation":result.get("material_validation",{}),"grip_accepted":false,
		"solver_termination":result.get("termination",result.get("reason","")),
		"section_assessment":result.get("section_assessment",{}),
		"thumb_solve_enabled":result.get("thumb_solve_enabled",false)}
	var status := {"weapon_name":_weapon_name,"slot":input.slot,"source_library":_library_path,
		"source_library_sha256":_library_sha256,"input_body_signature":_source_body_signature,
		"owner_status":{String(input.slot):state},"classification":"frozen_input_replay",
		"natural_end_to_end_verified":false,"grip_success_asserted":false}
	if OS.get_environment("THE_WILL_GRIP_REPLAY_POSE") == "1" and result.get("valid",false):
		OS.set_environment("THE_WILL_GRIP_TRACE_PATH",prefix + ".jsonl")
		var application := await _replay_apply(input, stage, result)
		status["application"] = application
		status.merge(_actual_capture,true)
	output.merge({"valid":result.get("valid",false),"reason":result.get("reason",""),
		"solver_ms":elapsed,"material_contacts":contacts,"sampled_material_safe":result.get("material_safe",false),
		"section_assessment":result.get("totals",{}).get("section_assessment",{}),
		"status_path":prefix + "_status.json","result_path":prefix + "_result.bin",
		"actual_capture_valid":status.get("actual_capture_valid",false)},true)
	_replay_json(prefix + "_status.json",status)
	_replay_rows.append(output)
	print("GRIP_REPLAY_RESULT ",_weapon_name," ms=",elapsed," valid=",output.valid," contacts=",contacts)

func _replay_apply(input: Dictionary, stage: Dictionary, result: Dictionary) -> Dictionary:
	_actual_capture = {}
	var rig: Node3D = ReplayRig.instantiate()
	root.add_child(rig); rig.set_process(false); rig.set_physics_process(false)
	for node: Node in rig.find_children("*","",true,false):
		if node is AnimationPlayer: node.stop()
		if node is AnimationTree: node.active = false
		if node is SkeletonModifier3D: node.active = false
	rig.get("finger_grip_presenter")._ensure_animation_grip_baseline_cache()
	var skeleton: Skeleton3D = rig.get("skeleton")
	if not _replay_restore(skeleton,stage.posed_character): rig.free(); return {"valid":false,"reason":"captured_pose_restore_failed"}
	var weapon := Node3D.new(); root.add_child(weapon)
	weapon.global_transform = stage.object.weapon_to_world
	for end: String in ["start","end"]:
		weapon.set_meta("primary_grip_span_"+end+"_local",stage.object["primary_grip_span_"+end+"_local"])
		weapon.set_meta("primary_grip_span_"+end+"_origin_id",&"WeaponRootOrigin")
	weapon.set_meta("preview_primary_grip_seat_local",stage.object.grip_pivot_local)
	weapon.set_meta("preview_primary_grip_seat_origin_id",&"WeaponRootOrigin")
	weapon.set_meta(ReplaySource.META,stage.saved_grip_source)
	var mesh_node := MeshInstance3D.new()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = stage.object.local_faces
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_node.mesh = mesh; mesh_node.set_meta("visual_mesh_source",&"editable_mesh")
	weapon.add_child(mesh_node); mesh_node.global_transform = stage.object.mesh_to_world
	_owner = ReplayOwner.new(); _owner.name = ReplayOwner.NODE_NAME; rig.add_child(_owner); _owner.set_process(false)
	var application := {"valid":false,"reason":"owner_configuration_failed"}
	if _owner.configure(rig,weapon):
		var slot := StringName(input.slot)
		var slots: Array[StringName] = [slot]
		_owner.synchronize(slots,slot)
		var requests: Dictionary = _owner.get("_requests")
		if requests.has(slot):
			requests[slot]["digit_dimension_reference"] = stage.posed_character.digit_dimension_reference.duplicate(true)
			var request: Dictionary = requests[slot].duplicate(true)
			application = _owner.apply_primary_result(slot,request,result,_owner._realization_stamp())
			if application.get("valid",false):
				_context = {"actor":rig,"weapon":weapon}
				await _capture_actual_pose()
	await _cancel_and_join()
	rig.free(); weapon.free(); _owner = null; _context = {}
	return application

func _replay_restore(skeleton: Skeleton3D, pose: Dictionary) -> bool:
	var registered := ReplaySkin.new()._registry(pose.origin_records,pose.resolve_phase)
	if not registered.get("valid",false): return false
	var root_index := skeleton.find_bone(REPLAY_ROOT)
	if root_index < 0: return false
	skeleton.global_transform = pose.machine_to_world * skeleton.get_bone_global_pose(root_index).affine_inverse()
	var entries: Array[Dictionary] = []
	for bone: StringName in pose.bone_origin_ids:
		var index := skeleton.find_bone(bone)
		if index < 0: return false
		var depth := 0; var cursor := index
		while cursor >= 0: depth += 1; cursor = skeleton.get_bone_parent(cursor)
		var frame: Transform3D = registered.registry.resolve_transform_to_machine(pose.bone_origin_ids[bone])
		entries.append({"index":index,"depth":depth,"world":pose.machine_to_world * frame})
	entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.depth < b.depth)
	for entry: Dictionary in entries:
		skeleton.set_bone_global_pose(entry.index,skeleton.global_transform.affine_inverse() * (entry.world as Transform3D))
	for entry: Dictionary in entries:
		var actual: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(entry.index)
		if actual.origin.distance_to(entry.world.origin) > 0.000005 or not actual.basis.is_equal_approx(entry.world.basis): return false
	return true

func _replay_json(path: String, report: Dictionary) -> void:
	if FileAccess.file_exists(path): _replay_failures.append("Refusing to overwrite " + path); return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: _replay_failures.append("Cannot write " + path); return
	file.store_string(JSON.stringify(report,"\t")); file.close()

func _replay_workspace(path: String) -> bool:
	return path.is_absolute_path() and path.to_lower().begins_with("c:/workspace/")
