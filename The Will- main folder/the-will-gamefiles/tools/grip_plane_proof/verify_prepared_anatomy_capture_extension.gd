extends SceneTree

const Extension = preload("res://tools/grip_plane_proof/extend_prepared_anatomy_capture.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Signature = preload("res://tools/grip_plane_proof/character_anatomy_source_signature.gd")
const Inputs = preload("res://tools/grip_plane_proof/run_prepared_skin_contact_proof.gd")
const Candidate = preload("res://tools/grip_plane_proof/prepared_hand_candidate_pose.gd")
const DIGITS: Array[StringName] = [&"middle",&"thumb",&"index",&"ring",&"pinky"]
var _checks: int = 0
var _failures: Array[String] = []
var _faults: Array = []
var _traces: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var path: String = OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH").strip_edges().simplify_path()
	if not path.begins_with("res://tools/grip_plane_proof/prepared_characters/josie/") or path.get_extension() != "tres":
		push_error("Explicit full-hand prepared anatomy resource required"); quit(1); return
	var store := Store.new()
	var previous: Dictionary = store.load_matching(Inputs.DEFINITION_PATH,Inputs.SIGNATURE,"rest_middle_thumb_surface_measurements_v1")
	var extended: Dictionary = store.load_matching(path,path.get_file().get_basename(),Store.FULL_HAND_PREPARATION_REVISION)
	if not _check(previous.get("valid",false) and extended.get("valid",false),"both immutable anatomy definitions load"):
		push_error(str(_failures)); quit(1); return
	var tool := Extension.new()
	var before_previous: PackedByteArray = _definition_bytes(previous.resource)
	var before_extended: PackedByteArray = _definition_bytes(extended.resource)
	var baseline: Dictionary = tool.validate_extension(previous.resource,extended.resource)
	_check(baseline.get("valid",false),"valid full-hand extension accepted")
	var changed: Resource = extended.resource.duplicate(true)
	changed.source_signature = "deliberately_wrong_signature"
	_reject(tool.validate_extension(previous.resource,changed),"tampered new signature")
	changed = previous.resource.duplicate(true); changed.source_signature = "deliberately_wrong_old_signature"
	_reject(tool.validate_extension(changed,extended.resource),"tampered old signature")
	for component: String in ["blend_shape_values","character_metric","skeleton_definition","surfaces","named_reference_frames"]:
		changed = extended.resource.duplicate(true)
		changed.source_manifest.component_hashes[component] = "deliberately_changed_"+component
		changed.source_signature = Signature.new()._hash({"schema":Signature.SCHEMA,"components":changed.source_manifest.component_hashes})
		_reject(tool.validate_extension(previous.resource,changed),"consistently re-signed changed "+component)
	changed = extended.resource.duplicate(true)
	changed.source_manifest.source_identity.mesh_resource_path = "res://deliberately_different_character_mesh"
	_reject(tool.validate_extension(previous.resource,changed),"changed source mesh identity")
	changed = extended.resource.duplicate(true); changed.digits[-1].digit_id = &"unknown_digit"
	_reject(tool.validate_extension(previous.resource,changed),"unknown replacement digit")
	changed = extended.resource.duplicate(true); changed.digits[-1].slot_id = &"hand_unknown"
	_reject(tool.validate_extension(previous.resource,changed),"unknown replacement slot")
	changed = extended.resource.duplicate(true); changed.digits.remove_at(changed.digits.size()-1)
	_reject(tool.validate_extension(previous.resource,changed),"missing tenth digit")
	changed = extended.resource.duplicate(true)
	# Fixture perturbation remains in the reference surface's existing named
	# vertices_origin_id; it is not a new coordinate authority.
	var vertices: PackedVector3Array = changed.reference_skin.surfaces[0].vertices
	vertices[0] += Vector3(0.000001,0.0,0.0)
	changed.reference_skin.surfaces[0].vertices = vertices
	_reject(tool.validate_extension(previous.resource,changed),"one changed original skin vertex")
	changed = extended.resource.duplicate(true)
	for digit: Dictionary in changed.digits:
		if digit.digit_id == &"middle":
			digit.section_lengths_m[0] += 0.000001
			break
	_reject(tool.validate_extension(previous.resource,changed),"changed existing measured digit")
	var paths: PackedStringArray = OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";",false)
	_check(not paths.is_empty(),"explicit original placement traces supplied")
	var slots: Dictionary = {}
	for raw_path: String in paths:
		var source: String = raw_path.strip_edges().replace("\\","/").simplify_path()
		if not _check(source.to_lower().begins_with("c:/workspace/test_artifacts/") and source.get_extension() == "bin","source trace stays in workspace test artifacts"):
			continue
		var file := FileAccess.open(source,FileAccess.READ)
		if not _check(file != null,"original trace readable"): continue
		var raw: Variant = file.get_var(false); file.close()
		if not _check(raw is Dictionary,"original trace is a dictionary"): continue
		var trace: Dictionary = raw
		var before: PackedByteArray = var_to_bytes(trace)
		var adapted: Dictionary = tool.extend_trace(previous.resource,extended.resource,trace)
		if not _check(adapted.get("valid",false),"historical trace extension: "+source): continue
		slots[trace.slot] = true
		_check(var_to_bytes(trace) == before,"original in-memory trace remains byte-identical")
		var restored: Dictionary = adapted.trace.duplicate(true)
		_restore_signature(restored,previous.resource.source_signature)
		_check(var_to_bytes(restored) == before,"only signature/provenance changed; all geometry, frames, epochs and authored metadata preserved")
		_check(adapted.verification.capture_is_historical and not adapted.verification.pose_or_weapon_frames_changed,"extension remains explicitly historical")
		var packets: Array = []; _collect_packets(adapted.trace,packets)
		_check(packets.size() == adapted.verification.pose_packet_count and not packets.is_empty(),"all nested captured packets counted")
		var candidate_checked: bool = false
		for transaction: Dictionary in adapted.trace.transactions:
			for stage: Dictionary in transaction.get("finger_inputs",[]):
				var prepared: Dictionary = Candidate.new().prepare(extended.resource,stage.posed_character,stage.slot,DIGITS)
				_check(prepared.get("valid",false),"all five selected digits retain captured contributors and serial ancestry")
				candidate_checked = true
		_check(candidate_checked,"trace contains candidate input stages")
		var broken: Dictionary = trace.duplicate(true); broken.anatomy_signature = "wrong_trace_signature"
		_reject(tool.extend_trace(previous.resource,extended.resource,broken),"wrong top-level trace signature")
		# A minimal trace isolates one genuine captured packet for fault injection.
		packets.clear(); _collect_packets(trace,packets)
		var fixture: Dictionary = {"schema":"grip_placement_trace_v1","valid":true,"anatomy_signature":previous.resource.source_signature,"packet":packets[0].duplicate(true)}
		broken = fixture.duplicate(true); broken.packet.anatomy_signature = "wrong_nested_signature"
		_reject(tool.extend_trace(previous.resource,extended.resource,broken),"wrong nested capture signature")
		broken = fixture.duplicate(true); broken.packet.machine_to_world = Transform3D(Basis.IDENTITY,Vector3(NAN,0,0))
		_reject(tool.extend_trace(previous.resource,extended.resource,broken),"nonfinite captured machine frame")
		broken = fixture.duplicate(true)
		var required_bone: StringName = previous.resource.digits[0].bone_names[0]
		_check(broken.packet.bone_origin_ids.has(required_bone),"fault fixture contains measured digit root contributor")
		broken.packet.bone_origin_ids.erase(required_bone)
		_reject(tool.extend_trace(previous.resource,extended.resource,broken),"missing captured bone contributor")
		_traces.append({"path":source,"sha256":FileAccess.get_sha256(source),"slot":trace.slot,"pose_packet_count":adapted.verification.pose_packet_count})
	_check(slots.has(&"hand_right") and slots.has(&"hand_left"),"both original hand captures covered")
	_check(_definition_bytes(previous.resource) == before_previous and _definition_bytes(extended.resource) == before_extended,"both source definitions remain unchanged after all mutations")
	var report := {"schema":"verify_prepared_anatomy_capture_extension_v1","ok":_failures.is_empty(),"checks":_checks,"failures":_failures,
		"faults":_faults,"traces":_traces,"anatomy_path":path,"anatomy_signature":extended.resource.source_signature,
		"extension_sha256":FileAccess.get_sha256("res://tools/grip_plane_proof/extend_prepared_anatomy_capture.gd"),
		"production_pose_written":false,"frozen_sources_changed":false,"captures_remain_historical":true}
	var output: String = "C:/WORKSPACE/test_artifacts/verify_prepared_anatomy_capture_extension_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	if FileAccess.file_exists(output): push_error("Refusing to replace verifier report"); quit(1); return
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: push_error("Cannot save capture extension verifier"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("CAPTURE_EXTENSION_VERIFIER="+output)
	print("CAPTURE_EXTENSION_SUMMARY="+JSON.stringify({"ok":report.ok,"checks":_checks,"failures":_failures,"faults":_faults.size()}))
	quit(0 if report.ok else 1)


func _definition_bytes(definition: Resource) -> PackedByteArray:
	var data: Dictionary = {}
	for field: String in Store.FIELDS: data[field] = definition.get(field)
	return var_to_bytes(data)


func _restore_signature(value: Variant, previous_signature: String) -> void:
	if value is Array:
		for entry: Variant in value: _restore_signature(entry,previous_signature)
	elif value is Dictionary:
		if value.has("anatomy_extension_provenance"):
			if value.anatomy_extension_provenance.has("previous_prepared_anatomy_path"):
				value.prepared_anatomy_path = value.anatomy_extension_provenance.previous_prepared_anatomy_path
			value.erase("anatomy_extension_provenance")
			value.anatomy_signature = previous_signature
		for key: Variant in value: _restore_signature(value[key],previous_signature)


func _collect_packets(value: Variant, packets: Array) -> void:
	if value is Array:
		for entry: Variant in value: _collect_packets(entry,packets)
	elif value is Dictionary:
		if value.get("schema") == &"coherent_skin_pose_capture_v1": packets.append(value); return
		for key: Variant in value: _collect_packets(value[key],packets)


func _reject(result: Dictionary, label: String) -> void:
	var rejected: bool = not result.get("valid",false)
	_check(rejected,label+" rejected")
	_faults.append({"label":label,"rejected":rejected,"reason":result.get("reason",result.get("status",""))})


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append(label)
	return condition
