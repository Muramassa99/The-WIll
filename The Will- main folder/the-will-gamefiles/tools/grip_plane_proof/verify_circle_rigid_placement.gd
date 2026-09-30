extends "res://tools/grip_plane_proof/run_circle_hand_process_proof.gd"

## Independent full-skin oracle for the isolated rigid placement helper.
## No circle search or runtime scene writes. Two bounded poses per frozen hand.
const FROZEN_TRACES: Dictionary = {
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_right_2026-09-18T02-30-57.bin": "dab0fbd68489e84ec1196c5a0acfb383a76a8eed099779e00a0f424c65529f89",
	"C:/WORKSPACE/test_artifacts/grip_placement_trace_hand_left_2026-09-18T02-31-08.bin": "c9765e43b465f5a529a07337bc2c9865d440612788960f162e7f40e5172311aa",
}
const MAX_VERTEX_ERROR_M: float = 0.000005
var _rigid_checks: int = 0
var _rigid_failures: Array[String] = []
var _rigid_cases: Array[Dictionary] = []
var _rigid_started: int = 0


func _run() -> void:
	_rigid_started = Time.get_ticks_usec()
	var loaded: Dictionary = Store.new().load_matching(OldInputs.DEFINITION_PATH,OldInputs.SIGNATURE,"rest_middle_thumb_surface_measurements_v1")
	if not _check(loaded.get("valid",false),"load prepared anatomy without recalibration"):
		_finish_rigid(); return
	var anatomy_before := var_to_bytes(loaded.resource.reference_skin)
	for path: String in FROZEN_TRACES:
		_test_trace(loaded.resource,path)
	_check(_rigid_cases.size()==4,"four bounded open/midrange hand placements completed")
	_check(var_to_bytes(loaded.resource.reference_skin)==anatomy_before,"prepared skin and original weights unchanged")
	_finish_rigid()


func _test_trace(definition: Resource,path: String) -> void:
	if not _check(_workspace_trace_path(path) and FileAccess.get_sha256(path)==FROZEN_TRACES[path],"frozen trace path and hash"):
		return
	var file := FileAccess.open(path,FileAccess.READ)
	if not _check(file!=null,"frozen trace readable"):
		return
	var raw: Variant = file.get_var(false)
	file.close()
	if not _check(raw is Dictionary and raw.get("schema")=="grip_placement_trace_v1" and raw.get("valid",false) and raw.get("validation",{}).get("valid",false) and raw.get("capture_errors",[]).is_empty() and raw.get("anatomy_signature")==definition.source_signature,"frozen trace validation and anatomy"):
		return
	var trace: Dictionary = raw
	var chosen: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.slot==trace.slot and transaction.get("result",{}).get("applied",false) and not transaction.get("finger_inputs",[]).is_empty():
			chosen=transaction
	if not _check(not chosen.is_empty(),"captured accepted seat exists"):
		return
	var stage: Dictionary = chosen.finger_inputs[-1]
	if not _check(stage.get("valid",false) and stage.get("transaction_serial")==chosen.serial and stage.posed_character.get("transaction_serial")==chosen.serial,"coherent captured stage"):
		return
	var stage_before := var_to_bytes(stage)
	var context: Dictionary = _prepare(definition,stage)
	if not _check(context.get("valid",false),"prepare current circle context"):
		return
	var adapter_before := var_to_bytes(context.adapter)
	for case_index: int in 2:
		var parameters: Array = context.open_parameters.duplicate()
		if case_index==1:
			for i: int in 6:
				var snapshot: Dictionary = context.adapter.digit_inputs[DIGITS[i/3]].snapshot
				parameters[i]=lerpf(float(parameters[i]),float(snapshot.preferred_angles_rad[i%3]),0.5)
		parameters[6]=0.04 if case_index==0 else -0.02
		parameters[7]=-0.03 if case_index==0 else 0.06
		var translation: Vector3 = context.translation_u_world*float(parameters[6])+context.translation_v_world*float(parameters[7])
		_test_candidate(context,parameters,translation,"open" if case_index==0 else "midrange")
	_check(var_to_bytes(context.adapter)==adapter_before,"all candidate checks preserve prepared adapter and captured frames")
	_check(var_to_bytes(stage)==stage_before,"all candidate checks preserve frozen input stage")


func _test_candidate(context: Dictionary,parameters: Array,translation: Vector3,label_suffix: String) -> void:
	var label := str(context.slot)+"/"+label_suffix
	var baseline: Dictionary = _builder.evaluate(context.adapter,_angles(parameters),Vector3.ZERO,ROOT)
	var candidate: Dictionary = _rigid_candidate(context,parameters,translation)
	if not _check(baseline.get("valid",false) and candidate.get("valid",false),label+": candidate and zero-placement reference valid"):
		return
	var packet: Dictionary = candidate.pose_packet
	_check(candidate.posed.machine_to_world==packet.machine_to_world,label+": posed and packet machine frames agree exactly")
	_check(candidate.posed.pose_id==packet.pose_id,label+": posed and packet pose IDs agree")
	_check(candidate.translation_world==translation and packet.translation_world==translation,label+": explicit world translation preserved")
	_check(packet.machine_to_world.basis==baseline.pose_packet.machine_to_world.basis,label+": rigid placement does not change presentation basis")
	_check((packet.machine_to_world.origin as Vector3).distance_to((baseline.pose_packet.machine_to_world.origin as Vector3)+translation)<MAX_VERTEX_ERROR_M,label+": presentation origin translated by requested amount")
	_check(var_to_bytes(packet.origin_records)==var_to_bytes(baseline.pose_packet.origin_records),label+": named bone-to-machine origin records unchanged by rigid placement")
	_check(var_to_bytes(candidate.posed.bone_transforms_to_machine)==var_to_bytes(baseline.posed.bone_transforms_to_machine),label+": rigid placement preserves every machine bone transform")
	var oracle: Dictionary = HandSkin.new().pose(context.adapter.skin_prepared,packet)
	if not _check(oracle.get("valid",false),label+": independent full original-weight skin pose succeeds: "+str(oracle.get("reason",""))):
		return
	_check(oracle.vertices_world.size()==candidate.posed.vertices_world.size() and oracle.vertices_machine.size()==candidate.posed.vertices_machine.size(),label+": full skin vertex coverage matches")
	var world_error: float = _vertex_error(oracle.vertices_world,candidate.posed.vertices_world)
	var machine_error: float = _vertex_error(oracle.vertices_machine,candidate.posed.vertices_machine)
	var rigid_error: float = 0.0
	# Matrix-on-array transform preserves all original vertices, independent of
	# which joints influence them. The full-skin oracle above recomputes weights.
	var shift := Transform3D(Basis.IDENTITY,translation)
	rigid_error=_vertex_error(shift*(baseline.posed.vertices_world as PackedVector3Array),candidate.posed.vertices_world)
	_check(world_error<=MAX_VERTEX_ERROR_M,label+": all world vertices agree with independent full weighted-skin oracle")
	_check(machine_error<=MAX_VERTEX_ERROR_M,label+": all machine vertices agree with independent full weighted-skin oracle")
	_check(rigid_error==0.0,label+": every world vertex receives identical rigid translation")
	_check(var_to_bytes(candidate.posed.vertices_machine)==var_to_bytes(baseline.posed.vertices_machine),label+": rigid placement leaves all machine vertices unchanged")
	_check(not oracle.weights_normalized_by_tool and not candidate.posed.weights_normalized_by_tool,label+": original weights not normalized")
	var registry_packet: Dictionary = HandSkin.new()._registry(packet.origin_records,packet.resolve_phase)
	if not _check(registry_packet.get("valid",false),label+": candidate origin registry valid"):
		return
	var registry: RefCounted = registry_packet.registry
	var resolved_hand: Transform3D = packet.machine_to_world*registry.resolve_transform_to_machine(packet.bone_origin_ids[context.adapter.hand_bone_name])
	_check(_frame_distance(resolved_hand,candidate.hand_to_world)<=MAX_VERTEX_ERROR_M,label+": Hand world frame matches named registry")
	for digit: StringName in DIGITS:
		var state: Dictionary = candidate.digit_states[digit]
		var unshifted: Dictionary = baseline.digit_states[digit]
		var plane: Transform3D = packet.machine_to_world*registry.resolve_transform_to_machine(state.plane_origin_id)
		_check(_frame_distance(plane,state.plane_to_world)<=MAX_VERTEX_ERROR_M,label+"/"+str(digit)+": plane world frame matches named registry")
		_check(_frame_distance(shift*(unshifted.hand_to_world as Transform3D),state.hand_to_world)<=MAX_VERTEX_ERROR_M,label+"/"+str(digit)+": digit Hand frame shifted")
		_check(_frame_distance(shift*(unshifted.snapshot.root_parent_world as Transform3D),state.snapshot.root_parent_world)<=MAX_VERTEX_ERROR_M,label+"/"+str(digit)+": FK parent frame shifted")
		for joint: int in 3:
			var named: Transform3D = packet.machine_to_world*registry.resolve_transform_to_machine(packet.bone_origin_ids[state.snapshot.bone_names[joint]])
			_check(_frame_distance(named,state.joint_transforms_world[joint])<=MAX_VERTEX_ERROR_M,label+"/"+str(digit)+": joint frame resolves "+str(joint))
			_check((state.joint_origins_world[joint] as Vector3).distance_to(named.origin)<=MAX_VERTEX_ERROR_M,label+"/"+str(digit)+": joint origin resolves "+str(joint))
		_check((state.tip_world as Vector3).distance_to((unshifted.tip_world as Vector3)+translation)<=MAX_VERTEX_ERROR_M,label+"/"+str(digit)+": terminal skin reference shifts rigidly")
	var upstream_count: int = 0
	for name: Variant in context.adapter.base_frames:
		if not context.adapter.descendant_bones.has(name):
			upstream_count+=1
			_check(_frame_distance(candidate.posed.bone_transforms_to_machine[name],context.adapter.base_frames[name])<=MAX_VERTEX_ERROR_M,label+": upstream machine bone unchanged "+str(name))
	_check(upstream_count>0,label+": upstream comparison was exercised")
	_rigid_cases.append({"slot":context.slot,"pose":label_suffix,"vertices":oracle.vertices_world.size(),
		"world_oracle_error_m":world_error,"machine_oracle_error_m":machine_error,"rigid_vertex_error_m":rigid_error,
		"upstream_machine_bones_checked":upstream_count,"production_pose_written":false})


func _vertex_error(first: PackedVector3Array,second: PackedVector3Array) -> float:
	if first.size()!=second.size(): return INF
	var maximum: float = 0.0
	for i: int in first.size():
		maximum=maxf(maximum,first[i].distance_to(second[i]))
	return maximum


func _frame_distance(first: Transform3D,second: Transform3D) -> float:
	return maxf(first.origin.distance_to(second.origin),maxf(first.basis.x.distance_to(second.basis.x),maxf(first.basis.y.distance_to(second.basis.y),first.basis.z.distance_to(second.basis.z))))


func _check(condition: bool,label: String) -> bool:
	_rigid_checks+=1
	if not condition:
		_rigid_failures.append(label)
		push_error(label)
	return condition


func _finish_rigid() -> void:
	var report := {"schema":"circle_rigid_placement_verifier_v1","ok":_rigid_failures.is_empty(),"checks":_rigid_checks,
		"failures":_rigid_failures,"cases":_rigid_cases,"vertex_tolerance_m":MAX_VERTEX_ERROR_M,
		"elapsed_ms":float(Time.get_ticks_usec()-_rigid_started)/1000.0,"production_pose_written":false,
		"actual_3d_grip_verified":false,"grip_accepted":false}
	var path := "C:/WORKSPACE/test_artifacts/verify_circle_rigid_placement_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		push_error("Cannot save rigid placement verifier");quit(1);return
	file.store_string(JSON.stringify(_json(report),"\t"));file.close()
	print("CIRCLE_RIGID_PLACEMENT_RESULT="+path)
	print("CIRCLE_RIGID_PLACEMENT_SUMMARY="+JSON.stringify({"ok":report.ok,"checks":report.checks,"failures":report.failures,"cases":report.cases.size()}))
	quit(0 if report.ok else 1)
