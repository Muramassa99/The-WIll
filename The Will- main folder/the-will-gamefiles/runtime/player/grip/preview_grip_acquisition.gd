extends Node

## One preview transaction owner. Scene reads/writes stay here on the main
## thread; acquisition owns private numerical data. Nothing is saved here.
const Acquisition = preload("res://runtime/player/grip/saved_wrapper_grip_acquisition.gd")
const CharacterData = preload("res://runtime/player/grip/character_grip_data.gd")
const Capture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")
const Assessment = preload("res://runtime/player/grip/realized_grip_assessment.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const NODE_NAME := "PreparedGripAcquisition"
const SEAT_AXIAL_GUARD_M := 0.00001
const FRAME_GUARD_M := 0.000005
const ACQUISITION_METHOD := &"saved_wrapper_contact_cpp"
signal primary_seat_applied(weapon: Node3D, actor: Node3D)

var _actor: Node3D
var _weapon: Node3D
var _data: Dictionary = {}
var _requests: Dictionary = {}
var _queue: Array[StringName] = []
var _job
var _busy := false
var _serial := 0
var _settle_ready := false
var _closing := false
var _last_key_change_frame := 0
var _running_slot := StringName()
var _started_usec := 0
var _status: Dictionary = {}
var _geometry_epoch := 0
var _meshes: Array[Mesh] = []
var _slots: Array[StringName] = []
var _dominant := StringName()
var _pose_epoch := 0
var _primary_seat: Dictionary = {}
var _skeleton: Skeleton3D

func configure(actor: Node3D, weapon: Node3D) -> bool:
	if _actor == actor and _weapon == weapon:
		Chronology.event("owner.configure_reused", {"owner_id":str(get_instance_id()),"valid":_data.get("valid",false)})
		return bool(_data.get("valid", false))
	var span := Chronology.begin("owner.configure", {"owner_id":str(get_instance_id())})
	clear()
	_actor = actor
	_weapon = weapon
	_data = CharacterData.load_for_actor(actor)
	_skeleton = actor.get("skeleton") as Skeleton3D if is_instance_valid(actor) else null
	if _skeleton != null:
		_skeleton.skeleton_updated.connect(_retain_final_skeleton_grip)
	if is_instance_valid(weapon):
		for child: Node in weapon.get_children():
			if child is MeshInstance3D and child.mesh != null and child.get_meta("visual_mesh_source", StringName()) == &"editable_mesh":
				_meshes.append(child.mesh)
				child.mesh.changed.connect(_geometry_changed)
	Chronology.finish(span, {"valid":_data.get("valid",false),"reason":_data.get("reason","")})
	return bool(_data.get("valid", false))

func synchronize(slots: Array[StringName], dominant: StringName, force_reason: StringName = StringName()) -> void:
	if not is_instance_valid(_actor) or not is_instance_valid(_weapon) or not _data.get("valid", false):
		return
	var span := Chronology.begin("owner.synchronize", {"owner_id":str(get_instance_id()),"slots":slots,"dominant":dominant,"force_reason":force_reason})
	# Primary application is the current cutover. Support keeps its existing
	# driver until its separate integration is implemented and verified.
	_slots.assign([dominant] if dominant in slots else [])
	_dominant = dominant
	for old_slot: StringName in _requests.keys():
		if old_slot not in _slots:
			_release(old_slot)
	for slot: StringName in _slots:
		var key: String = relationship_key(_weapon, slot, dominant, _data.anatomy.get("source_signature"), _geometry_epoch)
		if key.is_empty():
			_release(slot)
			continue
		var previous: Dictionary = _requests.get(slot, {})
		# A position-change notification concerns the hand whose exact station
		# changed. It must not reacquire an unchanged primary hand when only the
		# support slider moved. Other explicit reasons can request reacquisition.
		var force_reacquire := force_reason not in [StringName(), &"handle_position_changed"]
		if previous.get("key", "") == key and not force_reacquire:
			continue
		if _primary_seat.get("key", "") != key:
			_primary_seat.clear()
		if _running_slot == slot and _job != null:
			_job.cancel()
		_serial += 1
		if force_reacquire and previous.get("key", "") == key:
			_actor.release_planar_grip_pose(slot)
		var claimed: Dictionary = _actor.claim_planar_grip_pose(slot, _weapon, key)
		if not claimed.get("valid", false):
			_status[slot] = {"status": "unavailable", "reason": claimed.get("reason", "cannot_claim_hand")}
			continue
		_requests[slot] = {"key": key, "serial": _serial, "dominant": dominant}
		_record_request("owner.request_created",slot,_requests[slot])
		if slot not in _queue:
			_queue.append(slot)
		_status[slot] = {"status": "queued", "serial": _serial, "reason": force_reason}
		_last_key_change_frame = Engine.get_process_frames()
		_settle_ready = false
	_publish()
	Chronology.finish(span, {"queue_size":_queue.size(),"serial":_serial,"busy":_busy})

func _record_request(label: String, slot: StringName, request: Dictionary) -> void:
	if not Chronology.enabled(): return
	var current_key := ""
	if is_instance_valid(_weapon) and _data.get("anatomy") != null:
		current_key = relationship_key(_weapon,slot,request.get("dominant",_dominant),_data.anatomy.get("source_signature"),_geometry_epoch)
	var requested_key: String = request.get("key","")
	Chronology.event(label, {"owner_id":str(get_instance_id()),"slot":slot,"request_serial":request.get("serial",-1),"current_serial":_requests.get(slot,{}).get("serial",-1),
		"request_key_sha256":requested_key.sha256_text(),"current_key_sha256":current_key.sha256_text(),"key_matches":requested_key==current_key,
		"geometry_epoch":_geometry_epoch,"pose_epoch":_pose_epoch,"busy":_busy,"queue_size":_queue.size(),"job_id":str(_job.get_instance_id()) if _job!=null else 0})

func owns(slot: StringName) -> bool:
	return _requests.has(slot) and is_instance_valid(_weapon) and not _weapon.is_queued_for_deletion()

func settle_ready() -> void:
	_pose_changed()
	_settle_ready = true

func retain_roll() -> void:
	_pose_changed()
	if not _primary_seat.is_empty():
		# Roll already moved the seated weapon/Hand pair. Do not add the seat a
		# second time if the final-seat seam is visited without a macro rebuild.
		_primary_seat["last_applied_world"] = _weapon.global_transform
	for slot: StringName in _requests:
		if slot in _queue or (_busy and _running_slot == slot):
			if _running_slot == slot and _job != null:
				_job.cancel()
			_queue.erase(slot)
			_serial += 1
			_requests[slot]["serial"] = _serial
			var already_applied: bool = _actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false)
			_status[slot] = {"status": "preview_applied" if already_applied else "cancelled",
				"serial": _serial, "reason": "roll_precedes_grip_completion",
				"actual_assessment_current": false, "actual_3d_grip_verified": false}
	_publish()

func reacquire() -> void:
	if not _slots.is_empty():
		synchronize(_slots.duplicate(), _dominant, &"reacquire")
		_settle_ready = true

func clear() -> void:
	Chronology.event("owner.clear", {"owner_id":str(get_instance_id()),"busy":_busy,"queue_size":_queue.size(),"serial":_serial})
	_pose_epoch += 1
	if is_instance_valid(_skeleton) and _skeleton.skeleton_updated.is_connected(_retain_final_skeleton_grip):
		_skeleton.skeleton_updated.disconnect(_retain_final_skeleton_grip)
	_skeleton = null
	if _job != null:
		_job.cancel()
	for slot: StringName in _requests.keys():
		_release(slot)
	_queue.clear()
	_settle_ready = false
	_status.clear()
	for mesh: Mesh in _meshes:
		if mesh.changed.is_connected(_geometry_changed):
			mesh.changed.disconnect(_geometry_changed)
	_meshes.clear()
	_slots.clear()
	_dominant = StringName()
	_geometry_epoch = 0
	_primary_seat.clear()
	_data.clear()
	_weapon = null

func _pose_changed() -> void:
	_pose_epoch += 1
	for slot: StringName in _status:
		_status[slot]["actual_assessment_current"] = false
		_status[slot]["contact_condition_met"] = false

func _geometry_changed() -> void:
	_geometry_epoch += 1
	synchronize(_slots.duplicate(), _dominant)
	# Geometry notifications occur after the current synchronous editing action.
	_settle_ready = true

func _release(slot: StringName) -> void:
	_record_request("owner.release",slot,_requests.get(slot,{}))
	if _running_slot == slot and _job != null:
		_job.cancel()
	if is_instance_valid(_actor):
		_actor.release_planar_grip_pose(slot)
	_requests.erase(slot)
	_queue.erase(slot)
	_status.erase(slot)
	if _primary_seat.get("slot") == slot:
		_primary_seat.clear()

func _exit_tree() -> void:
	_closing = true
	if _job != null:
		_job.shutdown()
	clear()

func _process(_delta: float) -> void:
	if not is_instance_valid(_weapon) or _weapon.is_queued_for_deletion():
		if not _requests.is_empty():
			clear()
		return
	if _busy:
		if _job != null and _requests.has(_running_slot):
			var entry: Dictionary = _status.get(_running_slot, {})
			entry["progress"] = _job.progress()
			entry["elapsed_seconds"] = float(Time.get_ticks_usec() - _started_usec) / 1000000.0
			_status[_running_slot] = entry
			_publish()
		return
	if _settle_ready and not _queue.is_empty() and Engine.get_process_frames() > _last_key_change_frame:
		_run_next()

func _run_next() -> void:
	_busy = true
	_running_slot = _queue.pop_front()
	var slot: StringName = _running_slot
	var request: Dictionary = _requests.get(slot, {}).duplicate()
	if request.is_empty():
		_busy = false
		return
	_record_request("owner.job_start",slot,request)
	# Macro positioning is finished. Numerical work keeps the captured Hand fixed
	# and returns the final weapon frame after transverse seating.
	var prefix := "preview_primary_grip_seat" if slot == request.dominant else "preview_support_grip_seat"
	var pivot := {"point_local": _weapon.get_meta(prefix + "_local"),
		"origin_id": _weapon.get_meta(prefix + "_origin_id"), "source": prefix}
	var capture_span := Chronology.begin("owner.capture_input", {"slot":slot,"request_serial":request.serial})
	var stage: Dictionary = Capture.new().capture(_actor, _weapon, _data.anatomy, slot, &"live_grip_acquisition", request.serial, 0, {}, pivot)
	Chronology.finish(capture_span, {"valid":stage.get("valid",false),"reason":stage.get("reason","")})
	if not stage.get("valid", false):
		_finish_failure(slot, request, stage.get("reason", "capture_failed"), stage.get("details", {}))
		return
	# Animation may provide authored local translations different from imported
	# rest. Freeze these existing dimensions for this transaction; both the
	# numerical proposal and later observed-pose check use this same reference.
	var dimensions: Dictionary = stage.posed_character.get("source_bone_local_transforms",{})
	if dimensions.is_empty():
		_finish_failure(slot,request,"missing_captured_digit_dimensions")
		return
	stage.posed_character["digit_dimension_reference"]=dimensions.duplicate(true)
	_requests[slot]["digit_dimension_reference"]=dimensions.duplicate(true)
	var source_stamp := _realization_stamp()
	_job = Acquisition.new()
	var configured: Dictionary = _job.configure(_data.anatomy, stage, _data.config, self)
	if not configured.get("valid", false):
		_finish_failure(slot, request, configured.get("reason", "configuration_failed"), configured.get("details", configured.get("detail", {})))
		return
	_started_usec = Time.get_ticks_usec()
	_status[slot] = {"status": "solving", "serial": request.serial, "acquisition_method": ACQUISITION_METHOD}
	_publish()
	_record_request("owner.solve_started",slot,request)
	var solve_span := Chronology.begin("owner.await_solve", {"slot":slot,"request_serial":request.serial,"job_id":str(_job.get_instance_id())})
	var result: Dictionary = await _job.solve()
	Chronology.finish(solve_span, {"valid":result.get("valid",false),"reason":result.get("reason",result.get("termination","")),"cancelled":result.get("cancelled",false)})
	_job = null
	if _closing:
		return
	if not _is_current(slot, request):
		_record_request("owner.solve_discarded_stale",slot,request)
		_busy = false
		_running_slot = StringName()
		return
	var result_diagnostics := _solver_diagnostics(result)
	_status[slot].merge(result_diagnostics, true)
	if not result.get("valid", false) or result.get("cancelled", false):
		_finish_failure(slot, request, result.get("reason", "acquisition_unresolved"), result.get("details", result.get("detail", {})))
		return
	var apply_span := Chronology.begin("owner.apply_result", {"slot":slot,"request_serial":request.serial})
	var applied: Dictionary = apply_primary_result(slot, request, result, source_stamp)
	Chronology.finish(apply_span, {"valid":applied.get("valid",false),"reason":applied.get("reason",""),"status":applied.get("status","")})
	if not applied.get("valid", false):
		_finish_failure(slot, request, applied.get("reason", "pose_application_rejected"))
		return
	var realized: Dictionary = applied
	_status[slot].merge({"status": "assessing", "serial": request.serial}, true)
	Chronology.event("owner.assessment_started", {"slot":slot,"request_serial":request.serial})
	var assessment_span := Chronology.begin("owner.assess_realized", {"slot":slot,"request_serial":request.serial})
	var actual: Dictionary = await _capture_realized(slot, request, pivot)
	var capture_epoch: int = actual.get("preview_pose_epoch", -1)
	var capture_stamp: PackedByteArray = actual.get("preview_realization_stamp", PackedByteArray())
	var assessed: Dictionary = actual
	if _is_current(slot, request) and actual.get("valid", false):
		actual.posed_character["digit_dimension_reference"]=dimensions.duplicate(true)
		_job = Assessment.new()
		assessed = await _job.assess(_data.anatomy, actual, _data.config, self)
		_job = null
	if _closing:
		return
	if not _is_current(slot, request):
		_record_request("owner.assessment_discarded_stale",slot,request)
		Chronology.finish(assessment_span, {"discarded":true,"reason":"stale_request"})
		_busy = false
		_running_slot = StringName()
		return
	var assessment_current: bool = capture_epoch == _pose_epoch and not capture_stamp.is_empty() and capture_stamp == _realization_stamp()
	Chronology.finish(assessment_span, {"valid":assessed.get("valid",false),"reason":assessed.get("reason",""),"assessment_current":assessment_current,"contact_condition":assessed.get("planar_material_contact_condition",false)})
	_status[slot] = result_diagnostics.merged({
		"status": "preview_applied", "serial": request.serial,
		"elapsed_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"actual_3d_grip_verified": false, "realization": realized,
		"actual_material_query_valid": assessed.get("material_query_valid", false),
		"actual_material_safe": assessed.get("actual_material_safe", false),
		"actual_material_contacts": assessed.get("actual_material_contacts", []),
		"actual_articulation_valid": assessed.get("articulation_valid", false),
		"actual_articulation": assessed.get("actual_articulation", {}),
		"actual_assessment_reason": assessed.get("reason", ""),
		"actual_assessment_current": assessment_current,
		"contact_condition_met": assessment_current and assessed.get("articulation_valid", false) and assessed.get("planar_material_contact_condition", false),
		"actual_pose_id": assessed.get("source_pose_id", StringName()),
		"note": "Actual skin assessed on the five digit planes; whole-hand 3D contact is not certified.",
	}, true)
	_busy = false
	_running_slot = StringName()
	_record_request("owner.preview_applied",slot,request)
	_publish()

## Atomic primary application: only fifteen digit rotations and one transverse
## weapon translation. No arm target, wrist write, modifier advance or await.
func apply_primary_result(slot: StringName, request: Dictionary, result: Dictionary, source_stamp: PackedByteArray) -> Dictionary:
	if slot != _dominant or not _is_current(slot, request):
		return {"valid": false, "reason": "primary_request_changed"}
	if source_stamp.is_empty() or source_stamp != _realization_stamp():
		return {"valid": false, "reason": "source_pose_changed_during_acquisition"}
	if not result.get("valid", false) or not result.get("material_safe", false):
		return {"valid": false, "reason": "no_pose_within_material_overlap_limits"}
	var candidate: Dictionary = result.get("candidate", {})
	var selected: Dictionary = result.get("selected", {})
	if not result.get("source_weapon_to_world") is Transform3D or result.get("vectors_origin_id") != Origins.ORIGIN_RL_BONE_ROOT or not selected.get("weapon_to_world") is Transform3D or selected.get("weapon_to_world_origin_id") != Origins.ORIGIN_RL_BONE_ROOT or not candidate.get("translation_world") is Vector3 or not candidate.get("hand_to_world") is Transform3D or not candidate.get("pose_packet") is Dictionary:
		return {"valid": false, "reason": "missing_named_fixed_hand_weapon_proposal"}
	var base: Transform3D = result.source_weapon_to_world
	var final: Transform3D = selected.weapon_to_world
	var candidate_hand: Transform3D = candidate.hand_to_world
	if base != _weapon.global_transform or not base.is_finite() or not final.is_finite() or not candidate_hand.is_finite() or base.basis.determinant() <= 0.0 or final.basis.determinant() <= 0.0 or final.basis != base.basis:
		return {"valid": false, "reason": "invalid_or_stale_proposal_frames"}
	if candidate.translation_world != Vector3.ZERO:
		return {"valid": false, "reason": "proposal_moves_fixed_hand"}
	var skeleton: Skeleton3D = _actor.get("skeleton")
	if skeleton == null:
		return {"valid": false, "reason": "missing_live_skeleton"}
	var hand_index := skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	var root_index := skeleton.find_bone(Origins.ORIGIN_RL_BONE_ROOT)
	if hand_index < 0 or root_index < 0:
		return {"valid": false, "reason": "missing_hand_or_machine_root"}
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	if not hand.basis.is_equal_approx(candidate_hand.basis) or hand.origin.distance_to(candidate_hand.origin) > FRAME_GUARD_M:
		return {"valid": false, "reason": "proposal_does_not_preserve_fixed_hand"}
	for end: String in ["start", "end"]:
		if not _weapon.get_meta("primary_grip_span_" + end + "_local", null) is Vector3 or _weapon.get_meta("primary_grip_span_" + end + "_origin_id", StringName()) != Origins.ORIGIN_WEAPON_ROOT:
			return {"valid": false, "reason": "missing_named_weapon_axis"}
	var axis: Vector3 = base.basis * ((_weapon.get_meta("primary_grip_span_end_local") as Vector3) - (_weapon.get_meta("primary_grip_span_start_local") as Vector3))
	var translation: Vector3 = final.origin - base.origin
	if not axis.is_finite() or axis.length_squared() < 1.0e-12 or absf(translation.dot(axis.normalized())) > SEAT_AXIAL_GUARD_M:
		return {"valid": false, "reason": "weapon_seat_axial_displacement_forbidden"}
	var packet := {
		"hand_in_weapon": final.affine_inverse() * hand,
		"hand_in_weapon_origin_id": Origins.ORIGIN_WEAPON_ROOT,
		"anatomy_signature": _data.anatomy.get("source_signature"),
		"source_pose_id": candidate.pose_packet.get("pose_id", StringName()),
		"digit_states": candidate.get("digit_states", {}),
	}
	var applied: Dictionary = _actor.apply_planar_grip_pose(slot, _weapon, request.key, packet)
	if not applied.get("valid", false):
		return applied
	_primary_seat = {"key": request.key, "slot": slot,
		"last_applied_world": final, "last_applied_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT}
	_weapon.global_transform = final
	var report := _seat_report(base, final)
	report["digit_application"] = applied
	_weapon.set_meta("weapon_surface_seat_state", report.duplicate(true))
	primary_seat_applied.emit(_weapon, _actor)
	return report


## Controls request a pose; the existing arm/wrist solver limits that pose.
## Its realized Hand carries the complete immutable grip, not merely a cached
## translation. This writer never changes bones or invokes an IK/grip solve.
func recompose_primary_seat() -> Dictionary:
	if not owns(_dominant):
		return {"valid": false, "applied": false, "reason": "primary_grip_not_owned"}
	if _primary_seat.is_empty():
		return {"valid": true, "applied": true, "status": &"prepared_grip_pending", "weapon_moved": false}
	var binding: Dictionary = _actor.planar_grip_pose_binding.relationship(_dominant, _weapon)
	if binding.is_empty() or binding.relationship_key != _primary_seat.key:
		return {"valid": false, "applied": false, "reason": "primary_relationship_not_bound"}
	var wrist: Dictionary = _actor.capture_authoring_wrist_origin(_dominant)
	if not wrist.get("available", false):
		return {"valid": false, "applied": false, "reason": "missing_named_final_wrist"}
	var hand: Transform3D = wrist.machine_to_world * wrist.origin_record.resolved_transform_to_machine
	var base: Transform3D = _weapon.global_transform
	var final: Transform3D = hand * (binding.hand_in_weapon as Transform3D).affine_inverse()
	if base.is_equal_approx(final):
		return _seat_report(base, base)
	_weapon.global_transform = final
	_primary_seat.last_applied_world = final
	primary_seat_applied.emit(_weapon, _actor)
	return _seat_report(base, final)

func _retain_final_skeleton_grip() -> void:
	# Godot emits this after modifiers finish. A deferred wrist update must not
	# detach a grip that was correctly retained by the synchronous UI pass.
	if not _primary_seat.is_empty() and not _closing:
		recompose_primary_seat()


func _seat_report(base: Transform3D, final: Transform3D) -> Dictionary:
	var skeleton: Skeleton3D = _actor.get("skeleton")
	var machine: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(Origins.ORIGIN_RL_BONE_ROOT))
	var record := Origins.new()
	record.origin_id = Origins.ORIGIN_WEAPON_ROOT
	record.parent_origin_id = Origins.ORIGIN_RL_BONE_ROOT
	record.transform_to_parent = machine.affine_inverse() * final
	record.owner_system = &"preview_grip_acquisition"
	record.resolve_phase = Origins.PHASE_EDITOR_PREVIEW
	record.space_type = Origins.SPACE_TYPE_WEAPON
	record.is_dynamic = true
	return {"valid": true, "applied": true, "status": &"prepared_primary_weapon_seated",
		"weapon_moved": base != final, "weapon_basis_preserved": base.basis == final.basis,
		"solved_relationship_retained": true,
		"upstream_ik_invoked": false, "grip_accepted": false,
		"base_weapon_transform_world": base, "base_weapon_transform_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"resolved_weapon_transform_world": final, "resolved_weapon_transform_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"machine_to_world": machine, "weapon_origin_record": record,
		"seat_correction_grip_local": base.affine_inverse() * final,
		"seat_correction_grip_local_origin_id": Origins.ORIGIN_WEAPON_ROOT}


func _capture_realized(slot: StringName, request: Dictionary, pivot: Dictionary) -> Dictionary:
	var skeleton: Skeleton3D = _actor.get("skeleton")
	var captured: Dictionary = {}
	var receive := func() -> void:
		if _is_current(slot, request):
			captured.merge(Capture.new().capture(_actor, _weapon, _data.anatomy, slot, &"live_grip_realized", request.serial, 0, {}, pivot))
			captured["preview_pose_epoch"] = _pose_epoch
			captured["preview_realization_stamp"] = _realization_stamp()
		else:
			captured.merge({"valid": false, "reason": "request_replaced_during_capture"})
	skeleton.skeleton_updated.connect(receive, CONNECT_ONE_SHOT)
	skeleton.advance(0.0)
	for _frame: int in 3:
		if not captured.is_empty() or _closing:
			break
		await get_tree().process_frame
	if is_instance_valid(skeleton) and skeleton.skeleton_updated.is_connected(receive):
		skeleton.skeleton_updated.disconnect(receive)
	return captured if not captured.is_empty() else {"valid": false, "reason": "no_final_skin_signal"}

func _realization_stamp() -> PackedByteArray:
	if not is_instance_valid(_actor) or not is_instance_valid(_weapon):
		return PackedByteArray()
	var skeleton: Skeleton3D = _actor.get("skeleton")
	if skeleton == null:
		return PackedByteArray()
	var poses: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(index))
	# Compare once across the asynchronous assessment, not per frame. An arm
	# modifier can change skin without an explicit editor-change notification.
	return var_to_bytes([skeleton.get_instance_id(), skeleton.get_version(),
		skeleton.global_transform, poses, _weapon.global_transform, _geometry_epoch])

func _is_current(slot: StringName, request: Dictionary) -> bool:
	return is_instance_valid(_actor) and is_instance_valid(_weapon) and not _weapon.is_queued_for_deletion() and _requests.get(slot, {}).get("serial", -1) == request.get("serial", -2) and relationship_key(_weapon, slot, request.dominant, _data.anatomy.get("source_signature"), _geometry_epoch) == request.key

## Predicted full-hand results remain separate from recaptured rig assessment.
## A native backend or an applied pose alone is never a successful grip verdict.
func _solver_diagnostics(result: Dictionary) -> Dictionary:
	var totals: Dictionary = result.get("totals", {})
	var contact: Dictionary = totals.get("saved_contact_cache_statistics", {})
	var unresolved: Array=[]
	for follower: Dictionary in result.get("followers",[]):
		if not follower.get("accepted_contact_response",false): unresolved.append(follower.get("digit",&"unknown"))
	return {"acquisition_method": ACQUISITION_METHOD,
		"solver_revision": result.get("revision", StringName()),
		"solver_termination": result.get("reason", result.get("termination", "")),
		"solver_total_ms": result.get("total_ms", 0.0),
		"solver_totals": totals.duplicate(true),
		"contact_backend": result.get("contact_backend", contact.get("contact_backend", "unreported")),
		"native_contact_batch_enabled": contact.get("native_batch_enabled", false),
		"material_contacts": result.get("accepted_hand_material_contacts", []).duplicate(),
		"planar_material_safe": result.get("material_safe", false),
		"predicted_minimum_hand_contact_count_met": result.get("minimum_hand_contact_count_met", false),
		"predicted_material_contact_scope": result.get("material_contact_scope", StringName()),
		"follower_results": result.get("followers", []).duplicate(true),
		"unresolved_digits":unresolved,
		"final_digit_assessments": result.get("final_digit_assessments", []).duplicate(true),
		"grip_accepted": false}

func _finish_failure(slot: StringName, request: Dictionary, reason: String, details: Dictionary = {}) -> void:
	_record_request("owner.failure",slot,request)
	Chronology.event("owner.failure_reason", {"slot":slot,"request_serial":request.get("serial",-1),"reason":reason})
	if _is_current(slot, request):
		var entry: Dictionary = _status.get(slot, {})
		entry.merge({"status": "unresolved", "serial": request.serial, "reason": reason,
			"acquisition_method": ACQUISITION_METHOD, "actual_3d_grip_verified": false,
			"actual_assessment_current": false, "contact_condition_met": false,
			"failure_details": details.duplicate(true)}, true)
		_status[slot] = entry
	_job = null
	_busy = false
	_running_slot = StringName()
	_publish()

func _publish() -> void:
	if is_instance_valid(_weapon):
		_weapon.set_meta("prepared_grip_status", _status.duplicate(true))

func status() -> Dictionary:
	return _status.duplicate(true)

static func relationship_key(weapon: Node3D, slot: StringName, dominant: StringName, signature: String, geometry_epoch: int = 0) -> String:
	if not is_instance_valid(weapon):
		return ""
	var prefix := "preview_primary_grip_seat" if slot == dominant else "preview_support_grip_seat"
	if not weapon.get_meta(prefix + "_local", null) is Vector3 or weapon.get_meta(prefix + "_origin_id", StringName()) != Origins.ORIGIN_WEAPON_ROOT:
		return ""
	var geometry: Array = []
	for child: Node in weapon.get_children():
		if child is MeshInstance3D and child.get_meta("visual_mesh_source", StringName()) == &"editable_mesh" and child.mesh != null:
			geometry.append([child.get_instance_id(), child.mesh.get_instance_id(), child.transform])
	if geometry.is_empty():
		return ""
	# Exact serialized identity; world movement and Roll are deliberately absent.
	return var_to_bytes([signature, weapon.get_instance_id(), slot, dominant, geometry_epoch,
		weapon.get_meta(prefix + "_local"), weapon.get_meta(prefix + "_origin_id"),
		weapon.get_meta("grip_style_mode", StringName()), geometry]).hex_encode()
