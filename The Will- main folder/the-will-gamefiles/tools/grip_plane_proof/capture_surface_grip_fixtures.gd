extends "res://tools/grip_plane_proof/trace_skill_crafter_grip.gd"

## Reuses the real weapon/Skill 1 activation route, then pauses the acquisition
## owner BEFORE its worker starts. This is input-fixture preparation, not a
## natural completed grip or performance run. No saved library is rewritten.
## THE_WILL_GRIP_TRACE_LIBRARY / TRACE_PATH retain their existing meanings.
## THE_WILL_GRIP_FIXTURE_DIR is a new workspace directory; optional
## THE_WILL_GRIP_FIXTURE_NAMES is a JSON array of exact saved weapon names.
var _fixture_directory := ""
var _fixture_rows: Array[Dictionary] = []
var _fixture_failures: Array[String] = []

func _run() -> void:
	_fixture_directory = OS.get_environment("THE_WILL_GRIP_FIXTURE_DIR").replace("\\", "/").simplify_path()
	if not _fixture_directory.to_lower().begins_with("c:/workspace/") or not _fixture_directory.is_absolute_path():
		push_error("Fixture output must be an absolute workspace directory."); quit(1); return
	if FileAccess.file_exists(_fixture_directory.path_join("manifest.json")):
		push_error("Refusing to overwrite an earlier fixture manifest."); quit(1); return
	if DirAccess.make_dir_recursive_absolute(_fixture_directory) != OK:
		push_error("Cannot create fixture directory."); quit(1); return
	var names: Array = ["Handle 1", "handle 2", "handle 3", "Handle 4", "handle 5", "handle 6"]
	var requested := OS.get_environment("THE_WILL_GRIP_FIXTURE_NAMES")
	if not requested.is_empty():
		var parsed: Variant = JSON.parse_string(requested)
		if not parsed is Array or parsed.is_empty():
			push_error("Fixture names must be a nonempty JSON array."); quit(1); return
		names = parsed
	for name: String in names:
		OS.set_environment("THE_WILL_GRIP_TRACE_WEAPON_NAME", name)
		_owner = null
		_context = {}
		_classification = "setup_incomplete"
		await super._run()
		if not _fixture_failures.is_empty(): break
	var report := {"schema":"surface_grip_input_fixtures_v1", "fixtures":_fixture_rows,
		"failures":_fixture_failures, "source_library":_library_path,
		"source_library_sha256":_library_sha256,
		"source_unchanged":FileAccess.get_sha256(_library_path) == _library_sha256,
		"capture_route":"real_skill_crafter_macro_pose_acquisition_paused_before_worker",
		"solver_ran":false,"natural_end_to_end_verified":false,
		"engine_version":Engine.get_version_info()}
	var path := _fixture_directory.path_join("manifest.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Cannot write fixture manifest."); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	Chronology.close()
	print("SURFACE_GRIP_FIXTURES ", path, " count=", _fixture_rows.size(), " failures=", _fixture_failures.size())
	quit(0 if _fixture_failures.is_empty() and report.source_unchanged else 1)

func _observe() -> void:
	# Called synchronously after the real UI creates the owner; no process frame
	# has been yielded since Skill 1 activation.
	if _owner.get("_job") != null or _owner.get("_busy"):
		_fixture_failures.append(_weapon_name + ": worker unexpectedly started before fixture capture")
		return
	_owner.set_process(false)
	for frame: int in 3: await process_frame
	var requests: Dictionary = _owner.get("_requests")
	var slot := StringName()
	var request := {}
	for key: StringName in requests:
		if requests[key].get("dominant") == key:
			slot = key
			request = requests[key].duplicate(true)
			break
	if slot == StringName():
		_fixture_failures.append(_weapon_name + ": missing primary-hand request"); return
	var data := GripData.load_for_actor(_context.actor)
	if not data.get("valid",false):
		_fixture_failures.append(_weapon_name + ": character preparation invalid " + str(data)); return
	var pivot := {"point_local":_context.weapon.get_meta("preview_primary_grip_seat_local"),
		"origin_id":_context.weapon.get_meta("preview_primary_grip_seat_origin_id"),"source":"preview_primary_grip_seat"}
	var stage: Dictionary = Capture.new().capture(_context.actor,_context.weapon,data.anatomy,slot,
		&"live_grip_acquisition",request.serial,0,{},pivot)
	if not stage.get("valid",false) or not stage.get("saved_grip_source",{}).get("valid",false):
		_fixture_failures.append(_weapon_name + ": stage/source invalid " + str(stage.get("reason",stage.get("saved_grip_source",{}).get("reason","")))); return
	var dimensions: Dictionary = stage.posed_character.get("source_bone_local_transforms",{})
	if dimensions.is_empty():
		_fixture_failures.append(_weapon_name + ": missing captured digit dimensions"); return
	stage.posed_character["digit_dimension_reference"] = dimensions.duplicate(true)
	# Keep get_var(false): no object deserialization. The immutable wrapper
	# Resource is reconstructed from the hash-checked saved library on replay.
	stage.saved_grip_source.erase("wrapper")
	var config: Dictionary = data.config.duplicate(true)
	config["seat_weapon"] = true
	config.erase("selected_digits")
	var fixture := {"schema":"surface_grip_replay_input_v1","weapon_name":_weapon_name,
		"stage":stage,"config":config,"anatomy_signature":data.anatomy_signature,
		"anatomy_profile":GripData.PROFILE_PATH,"slot":slot,
		"source_library":_library_path,"source_library_sha256":_library_sha256,
		"input_body_signature":_source_body_signature,"solver_ran":false,
		"capture_route":"real_ui_macro_pose_with_acquisition_paused"}
	var path := _fixture_directory.path_join("%02d_%s_%s.bin" % [_fixture_rows.size()+1,_weapon_name.validate_filename().replace(" ","_"),slot])
	if FileAccess.file_exists(path):
		_fixture_failures.append("Refusing to overwrite " + path); return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: _fixture_failures.append("Cannot write " + path); return
	file.store_var(fixture,false); file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: _fixture_failures.append("Fixture write failed " + str(error)); return
	_fixture_rows.append({"weapon_name":_weapon_name,"slot":slot,"input_path":path,
		"sha256":FileAccess.get_sha256(path),"input_body_signature":_source_body_signature,
		"source_library_sha256":_library_sha256,"anatomy_signature":data.anatomy_signature})
	_classification = "input_captured"
	print("GRIP_INPUT_CAPTURED ",_weapon_name," ",slot," ",path)

func _finish(classification: String, exit_code: int) -> void:
	if exit_code != 0 or classification != "input_captured":
		_fixture_failures.append(_weapon_name + ": " + classification)
	await _cancel_and_join()
	if is_instance_valid(_ui):
		_ui.close_ui()
		_ui.queue_free()
	if is_instance_valid(_player): _player.queue_free()
	await process_frame
	_owner = null
	_context = {}
	if not _library_sha256.is_empty() and FileAccess.get_sha256(_library_path) != _library_sha256:
		_fixture_failures.append("Source library changed during fixture capture")
