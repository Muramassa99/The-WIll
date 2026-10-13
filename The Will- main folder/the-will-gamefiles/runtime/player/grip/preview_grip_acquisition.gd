extends Node

## One preview transaction owner. Scene reads/writes stay here on the main
## thread; acquisition owns private numerical data. Nothing is saved here.
const Acquisition = preload("res://runtime/player/grip/saved_wrapper_grip_acquisition.gd")
const CharacterData = preload("res://runtime/player/grip/character_grip_data.gd")
const Capture = preload("res://runtime/player/grip/capture_grip_placement_stage.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const HingeRules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const NODE_NAME := "PreparedGripAcquisition"
const SEAT_AXIAL_GUARD_M := 0.00001
const FRAME_GUARD_M := 0.000005
const SEAT_IDENTITY_GRID_M := 0.0000001
const ACQUISITION_METHOD := &"surface_contact_v6"
const ACTIVE_DIGITS := [&"index", &"middle", &"ring", &"pinky"]
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
var _replay_pose_cache: Dictionary = {}
var _support_motion_snapshot: Dictionary = {}
var _restoring_support_motion := false
var _support_motion_clamp_count := 0
var _last_support_motion_clamp: Dictionary = {}

## Offline clip baking uses the same acquisition and application contracts as
## editing. Rigid motion reuses a committed local grip; changed stations solve
## once per relationship instead of recording pending/open fingers.
func prepare_replay_grip(slots: Array[StringName], dominant: StringName) -> Dictionary:
	if _busy:
		return {"valid": false, "reason": "grip_acquisition_pending"}
	if not is_instance_valid(_actor) or not is_instance_valid(_weapon) or not _data.get("valid", false):
		return {"valid": false, "reason": "missing_replay_grip_context"}
	if slots.is_empty() or dominant not in slots:
		return {"valid": false, "reason": "missing_replay_grip_slots"}
	synchronize(slots, dominant)
	_settle_ready = false
	var ordered: Array[StringName] = [dominant]
	for slot: StringName in slots:
		if slot != dominant:
			ordered.append(slot)
	var solved_count := 0
	var reused_count := 0
	for slot: StringName in ordered:
		if slot != dominant and _actor.has_method("settle_authoring_support_grip_macro_pose_now"):
			_actor.settle_authoring_support_grip_macro_pose_now()
			retain_support_motion()
		var request: Dictionary = _requests.get(slot, {})
		if request.is_empty():
			return {"valid": false, "reason": "replay_grip_claim_unavailable", "slot": slot}
		var cached: Dictionary = _replay_pose_cache.get(request.key, {})
		Chronology.event("owner.replay_lookup", {"slot": slot, "cached": not cached.is_empty(),
			"snapshot_available": not _support_motion_snapshot.is_empty(), "request_serial": request.serial,
			"cached_support_matches": slot == dominant or (not cached.is_empty() and _replay_support_matches(slot, cached.packet))})
		if not cached.is_empty() and cached.get("status", {}).get("status", "") != "preview_applied":
			return {"valid": false, "reason": cached.get("status", {}).get("reason", "replay_cached_grip_unavailable"), "slot": slot}
		var reused := false
		if not cached.is_empty() and (slot == dominant or _replay_support_matches(slot, cached.packet)):
			var applied: Dictionary = _actor.apply_planar_grip_pose(slot, _weapon, request.key, cached.packet)
			if applied.get("reason", "") == "prepared_digit_dimensions_changed":
				_replay_pose_cache.erase(request.key)
			if applied.get("valid", false):
				if slot == dominant:
					_primary_seat = {"key": request.key, "slot": slot}
					var seat := recompose_primary_seat()
					if not seat.get("valid", false):
						return seat
				else:
					_capture_support_motion_snapshot(slot)
				_status[slot] = cached.status.duplicate(true)
				_queue.erase(slot)
				reused = true
				reused_count += 1
		if not reused:
			_queue.erase(slot)
			_queue.push_front(slot)
			_run_next(true)
			solved_count += 1
		if _status.get(slot, {}).get("status", "") != "preview_applied" or not _actor.get_planar_grip_pose_state(slot).get("has_grip_pose", false):
			return {"valid": false, "reason": _status.get(slot, {}).get("reason", "replay_grip_not_applied"), "slot": slot}
		if not _actor.finger_grip_presenter.apply_planar_grip_rotations(_skeleton, slot):
			return {"valid": false, "reason": "replay_grip_rotations_unavailable", "slot": slot}
	_settle_ready = false
	_publish()
	Chronology.event("owner.replay_complete", {"solved_relationships": solved_count, "reused_relationships": reused_count})
	return {"valid": true, "solved_relationships": solved_count, "reused_relationships": reused_count}

func _replay_support_matches(slot: StringName, packet: Dictionary) -> bool:
	var index := _skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand")
	if index < 0 or not packet.get("hand_in_weapon") is Transform3D:
		return false
	var actual: Transform3D = _weapon.global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(index)
	var expected: Transform3D = packet.hand_in_weapon
	var relative := (actual.basis.orthonormalized().get_rotation_quaternion().inverse() * expected.basis.orthonormalized().get_rotation_quaternion()).normalized()
	return (_weapon.global_basis * (actual.origin - expected.origin)).length() <= 0.00005 and 2.0 * atan2(Vector3(relative.x, relative.y, relative.z).length(), absf(relative.w)) <= 0.00005


## Save visits other drafts. This token belongs only to its unchanged visible
## selection; it never supplies a general cached body pose during editing.
func capture_bake_context(selection_key: String) -> Dictionary:
	if _busy or _support_motion_snapshot.is_empty() or selection_key.is_empty(): return {}
	var packets: Dictionary = {}
	var keys: Dictionary = {}
	for slot: StringName in _slots:
		var key: String = _requests.get(slot, {}).get("key", "")
		if _status.get(slot, {}).get("status", "") != "preview_applied" or not _replay_pose_cache.has(key): return {}
		keys[slot] = key
		packets[slot] = _replay_pose_cache[key].packet.duplicate(true)
	return {"selection_key": selection_key, "owner_id": get_instance_id(), "dominant": _dominant,
		"keys": keys, "packets": packets, "status": _status.duplicate(true),
		"snapshot": _support_motion_snapshot.duplicate(true)}


func restore_bake_context(context: Dictionary, selection_key: String) -> Dictionary:
	if context.is_empty() or _busy or context.selection_key != selection_key or context.owner_id != get_instance_id() or context.dominant != _dominant or context.keys.size() != _slots.size():
		return {"valid": false, "reason": "bake_preview_context_changed"}
	var saved: Dictionary = context.snapshot
	if saved.geometry_epoch != _geometry_epoch or saved.skeleton_version != _skeleton.get_version():
		return {"valid": false, "reason": "bake_preview_geometry_changed"}
	var plans: Dictionary = {}
	for slot: StringName in _slots:
		if context.keys.get(slot, "") != _requests.get(slot, {}).get("key", ""):
			return {"valid": false, "reason": "bake_preview_relationship_changed"}
		var plan: Dictionary = _actor.planar_grip_pose_binding.prepare(_skeleton, slot, _weapon, context.keys[slot], context.packets[slot])
		if not plan.get("valid", false): return plan
		plans[slot] = plan
	_restoring_support_motion = true
	_write_support_motion_snapshot(saved)
	for slot: StringName in _slots:
		_actor.finger_grip_presenter.set_planar_grip_rotations(_skeleton, slot, plans[slot].rotations)
		_actor.planar_grip_pose_binding.commit(slot, plans[slot])
		_status[slot] = context.status[slot].duplicate(true)
		_status[slot]["serial"] = _requests[slot].serial
		_replay_pose_cache[context.keys[slot]] = {"packet": context.packets[slot].duplicate(true), "status": _status[slot].duplicate(true)}
		_queue.erase(slot)
	_primary_seat = {"slot": _dominant, "key": context.keys[_dominant], "last_applied_world": saved.weapon_world}
	_support_motion_snapshot = saved
	_settle_ready = false
	_skeleton.force_update_all_bone_transforms()
	_restoring_support_motion = false
	_publish()
	primary_seat_applied.emit(_weapon, _actor)
	return {"valid": true, "restored_validated_bake_context": true, "solved_relationships": 0}


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
	# One closure owner for both hands. Existing support IK positions its Hand;
	# only primary acquisition can translate the weapon.
	_slots.assign(slots)
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
		if Chronology.enabled() and not previous.is_empty():
			var old_fields: Array = bytes_to_var(String(previous.key).hex_decode())
			var new_fields: Array = bytes_to_var(key.hex_decode())
			Chronology.event("owner.relationship_changed", {"slot": slot,
				"previous_station": str(old_fields[5]), "current_station": str(new_fields[5]),
				"station_delta_m": (old_fields[5] as Vector3).distance_to(new_fields[5]),
				"previous_style": old_fields[7], "current_style": new_fields[7],
				"geometry_equal": old_fields[8] == new_fields[8], "forced": force_reacquire})
		_support_motion_snapshot.clear()
		if slot == dominant and _primary_seat.get("key", "") != key:
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
	_replay_pose_cache.clear()
	_support_motion_snapshot.clear()
	_support_motion_clamp_count = 0
	_last_support_motion_clamp.clear()
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
	_support_motion_snapshot.clear()
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

func _run_next(synchronous: bool = false) -> void:
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
	var stage: Dictionary = Capture.new().capture(_actor, _weapon, _data.anatomy, slot, &"live_grip_acquisition", request.serial, 0, {}, pivot, false)
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
	var solve_config: Dictionary = _data.config.duplicate(true)
	# Both hands use the same fit. For support this weapon displacement is a
	# virtual relative frame: application moves the joining Hand oppositely.
	solve_config["seat_weapon"] = true
	var configured: Dictionary = _job.configure(_data.anatomy, stage, solve_config, self)
	if not configured.get("valid", false):
		_finish_failure(slot, request, configured.get("reason", "configuration_failed"), configured.get("details", configured.get("detail", {})))
		return
	_started_usec = Time.get_ticks_usec()
	_status[slot] = {"status": "solving", "serial": request.serial, "acquisition_method": ACQUISITION_METHOD}
	_publish()
	_record_request("owner.solve_started",slot,request)
	var solve_span := Chronology.begin("owner.await_solve", {"slot":slot,"request_serial":request.serial,"job_id":str(_job.get_instance_id())})
	var result: Dictionary
	if synchronous:
		result = _job._work()
	else:
		result = await _job.solve()
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
	var applied: Dictionary = apply_primary_result(slot, request, result, source_stamp) if slot == request.dominant else _apply_support_result(slot, request, result, source_stamp)
	Chronology.finish(apply_span, {"valid":applied.get("valid",false),"reason":applied.get("reason",""),"status":applied.get("status","")})
	if not applied.get("valid", false):
		_finish_failure(slot, request, applied.get("reason", "pose_application_rejected"), applied.get("details", {}))
		return
	# Support application replaces proposal metrics with the assessment of the
	# actual arm pose after its existing IK realizes the relative seat.
	result_diagnostics = _solver_diagnostics(result)
	# The V6 worker already evaluates its sampled physical caps. The old
	# five-plane reslicing assessment is not part of this surface-only path.
	# Application remains a prototype result, not a full skin certificate.
	_status[slot] = result_diagnostics.merged({
		"status": "preview_applied", "serial": request.serial,
		"elapsed_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
		"actual_3d_grip_verified": false, "realization": applied,
		"actual_assessment_current": false, "contact_condition_met": false,
		"thumb_solve_enabled": bool(result.get("thumb_solve_enabled", false)),
		"note": "Surface grip applied. Sampled physical caps; manual visual assessment pending.",
	}, true)
	if _replay_pose_cache.has(request.key):
		_replay_pose_cache[request.key]["status"] = _status[slot].duplicate(true)
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
		return {"valid": false, "reason": "no_pose_within_material_overlap_limits", "details": result.get("material_validation", {})}
	var surface_result := validate_surface_result(result)
	if not surface_result.valid:
		return surface_result
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
	_replay_pose_cache[request.key] = {"packet": packet.duplicate(true), "status": {}}
	_primary_seat = {"key": request.key, "slot": slot,
		"last_applied_world": final, "last_applied_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT}
	_weapon.global_transform = final
	var report := _seat_report(base, final)
	report["digit_application"] = applied
	_weapon.set_meta("weapon_surface_seat_state", report.duplicate(true))
	primary_seat_applied.emit(_weapon, _actor)
	return report


## One surface-only result contract; no circle flags or old Thumb fallback.
static func validate_surface_result(result: Dictionary) -> Dictionary:
	if StringName(result.get("method", StringName())) != ACQUISITION_METHOD:
		return {"valid": false, "reason": "incorrect_surface_solver_contract"}
	var states: Dictionary = result.get("candidate", {}).get("digit_states", {})
	for digit: StringName in ACTIVE_DIGITS + [&"thumb"]:
		if not states.get(digit) is Dictionary or not states[digit].get("angles_rad") is Array or states[digit].angles_rad.size() != 3:
			return {"valid": false, "reason": "missing_owned_digit_state", "details": {"digit": digit}}
	return {"valid": true}

## Invert the numerical weapon displacement into a joining-Hand request.
## Existing support IK realizes it; an actual-pose assessment owns acceptance.
func _apply_support_result(slot: StringName, request: Dictionary, result: Dictionary, source_stamp: PackedByteArray) -> Dictionary:
	if slot == _dominant or not _is_current(slot, request) or source_stamp.is_empty() or source_stamp != _realization_stamp():
		return {"valid": false, "reason": "support_source_pose_changed"}
	if not result.get("valid", false) or not result.get("material_safe", false):
		return {"valid": false, "reason": "no_support_pose_within_overlap_limits", "details": result.get("material_validation", {})}
	var checked := validate_surface_result(result)
	if not checked.valid:
		return checked
	var candidate: Dictionary = result.get("candidate", {})
	var selected: Dictionary = result.get("selected", {})
	if result.get("vectors_origin_id") != Origins.ORIGIN_RL_BONE_ROOT or result.get("source_weapon_to_world") != _weapon.global_transform or not selected.get("weapon_to_world") is Transform3D or candidate.get("translation_world") != Vector3.ZERO:
		return {"valid": false, "reason": "invalid_support_virtual_seat_frames"}
	var fixed_weapon := _weapon.global_transform
	var virtual_weapon: Transform3D = selected.weapon_to_world
	if not virtual_weapon.is_finite() or virtual_weapon.basis != fixed_weapon.basis:
		return {"valid": false, "reason": "support_virtual_seat_changes_weapon_orientation"}
	var delta := virtual_weapon.origin - fixed_weapon.origin
	for end: String in ["start", "end"]:
		if not _weapon.get_meta("primary_grip_span_" + end + "_local", null) is Vector3 or _weapon.get_meta("primary_grip_span_" + end + "_origin_id", StringName()) != Origins.ORIGIN_WEAPON_ROOT:
			return {"valid": false, "reason": "missing_named_support_weapon_axis"}
	var axis: Vector3 = fixed_weapon.basis * ((_weapon.get_meta("primary_grip_span_end_local") as Vector3) - (_weapon.get_meta("primary_grip_span_start_local") as Vector3))
	if axis.length_squared() < 1.0e-12 or absf(delta.dot(axis.normalized())) > SEAT_AXIAL_GUARD_M:
		return {"valid": false, "reason": "support_virtual_seat_changes_longitudinal_station"}
	var skeleton: Skeleton3D = _actor.get("skeleton")
	var index := skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand") if skeleton != null else -1
	if index < 0 or not candidate.get("hand_to_world") is Transform3D:
		return {"valid": false, "reason": "missing_support_hand_frame"}
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
	var proposed: Transform3D = candidate.hand_to_world
	if not hand.basis.is_equal_approx(proposed.basis) or hand.origin.distance_to(proposed.origin) > FRAME_GUARD_M:
		return {"valid": false, "reason": "support_proposal_does_not_match_captured_hand"}
	var primary_stamp := _primary_relationship_stamp()
	proposed.origin -= delta
	var realization_started := Time.get_ticks_usec()
	var realized: Dictionary = _actor.begin_prepared_support_grip_seat(slot, _weapon, proposed)
	realized["total_ms"] = float(Time.get_ticks_usec() - realization_started) / 1000.0
	if not realized.get("valid", false):
		_actor.finish_prepared_support_grip_seat(false)
		return realized
	var applied := _apply_realized_support_result(slot, request, result, fixed_weapon, primary_stamp, realized)
	_actor.finish_prepared_support_grip_seat(applied.get("valid", false))
	if applied.get("valid", false):
		_capture_support_motion_snapshot(slot)
	return applied

func _primary_relationship_stamp() -> PackedByteArray:
	if _skeleton == null: return PackedByteArray()
	var hand_index := _skeleton.find_bone("CC_Base_R_Hand" if _dominant == &"hand_right" else "CC_Base_L_Hand")
	if hand_index < 0: return PackedByteArray()
	return var_to_bytes([_weapon.global_transform, _skeleton.global_transform * _skeleton.get_bone_global_pose(hand_index),
		_actor.planar_grip_pose_binding.states.get(_dominant, {}).get("rotations", {})])

func _apply_realized_support_result(slot: StringName, request: Dictionary, result: Dictionary, fixed_weapon: Transform3D, primary_stamp: PackedByteArray, realized: Dictionary) -> Dictionary:
	if _weapon.global_transform != fixed_weapon or primary_stamp.is_empty() or _primary_relationship_stamp() != primary_stamp:
		return {"valid": false, "reason": "support_ik_changed_established_primary_relationship"}
	var pivot := {"point_local": _weapon.get_meta("preview_support_grip_seat_local"),
		"origin_id": _weapon.get_meta("preview_support_grip_seat_origin_id"), "source": "preview_support_grip_seat"}
	var stage: Dictionary = Capture.new().capture(_actor, _weapon, _data.anatomy, slot, &"support_seat_realized", request.serial, 0, {}, pivot, false)
	if not stage.get("valid", false): return stage
	stage.posed_character["digit_dimension_reference"] = _requests[slot].digit_dimension_reference.duplicate(true)
	var assessor = Acquisition.Solver.new()
	var assessed: Dictionary = assessor.assess_final_pose(_data.anatomy, stage, _data.config, result.candidate.digit_states)
	# The existing arm/wrist limits can realize a different legal Hand frame.
	# Refit the fingers once in that observed frame, keeping both the established
	# weapon and the realized arm fixed. Reuse the same solver and skin guards.
	if assessed.get("valid", false) and not assessed.get("material_safe", false):
		var assessment_ms := float(assessed.get("total_ms", 0.0))
		var fixed_config: Dictionary = _data.config.duplicate(true)
		fixed_config["seat_weapon"] = false
		fixed_config["seed_digit_states"] = result.candidate.digit_states
		var fixed_fit: Dictionary = Acquisition.Solver.new().run(_data.anatomy, stage, fixed_config)
		fixed_fit["total_ms"] = assessment_ms + float(fixed_fit.get("total_ms", 0.0))
		fixed_fit["support_fixed_seat_refit"] = true
		assessed = fixed_fit
	if not assessed.get("valid", false) or not assessed.get("material_safe", false):
		var fit_ms: float = result.get("total_ms", 0.0)
		result["total_ms"] = fit_ms + float(assessed.get("total_ms", 0.0)) + float(realized.get("total_ms", 0.0))
		result["totals"]["virtual_support_fit_ms"] = fit_ms
		result["totals"]["realized_support_assessment_ms"] = assessed.get("total_ms", 0.0)
		result["totals"]["support_arm_realization_ms"] = realized.get("total_ms", 0.0)
		result["totals"]["total_ms"] = result.total_ms
		# Failure status must describe the observed/refitted pose, not the safe
		# virtual proposal that the arm could not realize.
		assessed["total_ms"] = result.total_ms
		if not assessed.has("totals"): assessed["totals"] = {}
		assessed["totals"].merge({"virtual_support_fit_ms": fit_ms,
			"support_arm_realization_ms": realized.get("total_ms", 0.0),
			"total_ms": result.total_ms}, true)
		_status[slot].merge(_solver_diagnostics(assessed), true)
		# Status is copied each frame. Keep the actual failure evidence, not the
		# candidate's complete anatomy/skin packet and numerical search history.
		var evidence := {"valid": assessed.get("valid", false), "material_safe": assessed.get("material_safe", false),
			"reason": assessed.get("reason", assessed.get("termination", "")),
			"material_validation": assessed.get("material_validation", {}),
			"section_assessment": assessed.get("totals", {}).get("section_assessment", {}),
			"fixed_seat_refit": assessed.get("support_fixed_seat_refit", false),
			"total_ms": assessed.get("total_ms", 0.0)}
		return {"valid": false, "reason": "realized_support_pose_outside_overlap_limits",
			"details": {"realization": realized, "assessment": evidence}}
	var checked := validate_surface_result(assessed)
	if not checked.valid: return checked
	var candidate: Dictionary = assessed.candidate
	var hand: Transform3D = candidate.hand_to_world
	var virtual_totals: Dictionary = result.get("totals", {}).duplicate(true)
	var virtual_ms: float = result.get("total_ms", 0.0)
	result.merge(assessed, true)
	result["total_ms"] = virtual_ms + float(assessed.get("total_ms", 0.0)) + float(realized.get("total_ms", 0.0))
	result["totals"]["virtual_support_fit_ms"] = virtual_ms
	result["totals"]["realized_support_assessment_ms"] = assessed.get("total_ms", 0.0)
	result["totals"]["support_arm_realization_ms"] = realized.get("total_ms", 0.0)
	result["totals"]["total_ms"] = result.total_ms
	result["source_weapon_to_world"] = fixed_weapon
	result["vectors_origin_id"] = Origins.ORIGIN_RL_BONE_ROOT
	result["support_seat_realization"] = realized
	result["virtual_support_fit_totals"] = virtual_totals
	var packet := {
		"hand_in_weapon": _weapon.global_transform.affine_inverse() * hand,
		"hand_in_weapon_origin_id": Origins.ORIGIN_WEAPON_ROOT,
		"anatomy_signature": _data.anatomy.get("source_signature"),
		"source_pose_id": candidate.get("pose_packet", {}).get("pose_id", StringName()),
		"digit_states": candidate.digit_states,
	}
	var applied: Dictionary = _actor.apply_planar_grip_pose(slot, _weapon, request.key, packet)
	if applied.get("valid", false):
		_replay_pose_cache[request.key] = {"packet": packet.duplicate(true), "status": {}}
		applied["support_seat_realization"] = realized
	return applied

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
	if not _primary_seat.is_empty() and not _closing and not _restoring_support_motion:
		recompose_primary_seat()
		retain_support_motion()


## A committed support grip may follow legal body motion, but an arm/wrist
## clamp must not silently detach it. Keep the last realized body/weapon pose;
## authored controls remain requests and are never rewritten by this guard.
func retain_support_motion() -> Dictionary:
	if _support_motion_snapshot.is_empty() or _restoring_support_motion or _busy or _closing:
		return {"valid": true, "applied": false}
	var saved: Dictionary = _support_motion_snapshot
	var slot: StringName = saved.slot
	if not owns(slot) or slot == _dominant or saved.key != _requests[slot].key or saved.geometry_epoch != _geometry_epoch or saved.skeleton_version != _skeleton.get_version():
		_support_motion_snapshot.clear()
		return {"valid": false, "reason": "support_relationship_changed"}
	# A changed finger size invalidates the old safe skin pose. Its owner will
	# reacquire it rather than restoring obsolete dimensions from this snapshot.
	for bone: int in saved.digit_dimensions:
		var dimensions: Dictionary = saved.digit_dimensions[bone]
		if not _skeleton.get_bone_pose_position(bone).is_equal_approx(dimensions.position) or not _skeleton.get_bone_pose_scale(bone).is_equal_approx(dimensions.scale):
			_support_motion_snapshot.clear()
			_replay_pose_cache.clear()
			reacquire()
			return {"valid": false, "reason": "prepared_digit_dimensions_changed"}
	var binding: Dictionary = _actor.planar_grip_pose_binding.relationship(slot, _weapon)
	if binding.is_empty():
		_support_motion_snapshot.clear()
		return {"valid": false, "reason": "support_relationship_not_bound"}
	var actual: Transform3D = _weapon.global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(saved.hand_index)
	var expected: Transform3D = binding.hand_in_weapon
	var position_error := (_weapon.global_basis * (actual.origin - expected.origin)).length()
	var relative_rotation := (actual.basis.orthonormalized().get_rotation_quaternion().inverse() * expected.basis.orthonormalized().get_rotation_quaternion()).normalized()
	var orientation_error := 2.0 * atan2(Vector3(relative_rotation.x, relative_rotation.y, relative_rotation.z).length(), absf(relative_rotation.w))
	if position_error <= 0.00005 and orientation_error <= 0.00005:
		var moved: bool = not _weapon.global_transform.is_equal_approx(saved.weapon_world)
		_capture_support_motion_snapshot(slot)
		if moved and _status[slot].has("motion_retention"):
			_status[slot]["motion_retention"] = {"valid": true, "motion_clamped": false}
		return {"valid": true, "applied": false, "motion_clamped": false}
	_restoring_support_motion = true
	_write_support_motion_snapshot(saved)
	_skeleton.force_update_all_bone_transforms()
	_primary_seat["last_applied_world"] = saved.weapon_world
	_restoring_support_motion = false
	var report := {"valid": true, "applied": true, "motion_clamped": true,
		"reason": "support_arm_or_wrist_limit_preserves_grip", "position_error_m": position_error,
		"orientation_error_rad": orientation_error}
	_status[slot]["motion_retention"] = report
	_support_motion_clamp_count += 1
	_last_support_motion_clamp = report.duplicate(true)
	Chronology.event("owner.support_motion_clamped", report)
	_publish()
	primary_seat_applied.emit(_weapon, _actor)
	return report


func _write_support_motion_snapshot(saved: Dictionary) -> void:
	_actor.global_transform = saved.actor_world
	_skeleton.transform = saved.skeleton_local
	_weapon.global_transform = saved.weapon_world
	for index: int in saved.poses.size():
		if not _skeleton.get_bone_pose(index).is_equal_approx(saved.poses[index]):
			_skeleton.set_bone_pose(index, saved.poses[index])
	for control: Dictionary in saved.controls:
		if is_instance_valid(control.node): control.node.global_transform = control.world


func _capture_support_motion_snapshot(slot: StringName) -> void:
	var poses: Array[Transform3D] = []
	var dimensions: Dictionary = {}
	for index: int in _skeleton.get_bone_count():
		poses.append(_skeleton.get_bone_pose(index))
	for hand_slot: StringName in _slots:
		for bone_name: StringName in HingeRules.get_finger_bone_names(hand_slot):
			var index := _skeleton.find_bone(bone_name)
			if index < 0: continue
			dimensions[index] = {"position": _skeleton.get_bone_pose_position(index), "scale": _skeleton.get_bone_pose_scale(index)}
	var controls: Array[Dictionary] = []
	for name: String in ["left_hand_ik_target", "right_hand_ik_target", "left_hand_pole_target", "right_hand_pole_target"]:
		var control: Node3D = _actor.get(name)
		if is_instance_valid(control): controls.append({"node": control, "world": control.global_transform})
	_support_motion_snapshot = {"slot": slot, "key": _requests[slot].key, "geometry_epoch": _geometry_epoch,
		"skeleton_version": _skeleton.get_version(), "hand_index": _skeleton.find_bone("CC_Base_R_Hand" if slot == &"hand_right" else "CC_Base_L_Hand"),
		"actor_world": _actor.global_transform, "skeleton_local": _skeleton.transform, "weapon_world": _weapon.global_transform,
		"poses": poses, "controls": controls, "digit_dimensions": dimensions}


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




func _realization_stamp() -> PackedByteArray:
	if not is_instance_valid(_actor) or not is_instance_valid(_weapon):
		return PackedByteArray()
	var skeleton: Skeleton3D = _actor.get("skeleton")
	if skeleton == null:
		return PackedByteArray()
	var poses: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(index))
	# Compare once across the asynchronous solve, not per frame. An arm
	# modifier can change skin without an explicit editor-change notification.
	return var_to_bytes([skeleton.get_instance_id(), skeleton.get_version(),
		skeleton.global_transform, poses, _weapon.global_transform, _geometry_epoch])

func _is_current(slot: StringName, request: Dictionary) -> bool:
	return is_instance_valid(_actor) and is_instance_valid(_weapon) and not _weapon.is_queued_for_deletion() and _requests.get(slot, {}).get("serial", -1) == request.get("serial", -2) and relationship_key(_weapon, slot, request.dominant, _data.anatomy.get("source_signature"), _geometry_epoch) == request.key

## Sampled solver evidence is not a whole-hand skin certificate.
func _solver_diagnostics(result: Dictionary) -> Dictionary:
	return {"acquisition_method": ACQUISITION_METHOD,
		"solver_revision": result.get("solver_revision", result.get("revision", StringName())),
		"solver_termination": result.get("reason", result.get("termination", "")),
		"solver_total_ms": result.get("total_ms", 0.0),
		"solver_totals": result.get("totals", {}).duplicate(true),
		"contact_backend": result.get("contact_backend", "godot_triangle_mesh_bvh"),
		"material_contacts": result.get("accepted_hand_material_contacts", []).duplicate(),
		"sampled_material_safe": result.get("material_safe", false),
		"material_validation": result.get("material_validation", {}).duplicate(true),
		"predicted_minimum_hand_contact_count_met": result.get("minimum_hand_contact_count_met", false),
		"unresolved_digits": result.get("unresolved_digits", []).duplicate(),
		"final_digit_assessments": result.get("final_digit_assessments", []).duplicate(true),
		"thumb_solve_enabled": bool(result.get("thumb_solve_enabled", false)), "grip_accepted": false}

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
	# Baking stores authored offsets as float32. A harmless round-trip tail at
	# zero must not discard both committed hands. Canonicalize identity only,
	# 500 times finer than the 0.05 mm contact tolerance; targets stay untouched.
	var station: Vector3 = weapon.get_meta(prefix + "_local")
	station = station.snapped(Vector3.ONE * SEAT_IDENTITY_GRID_M)
	for axis: int in 3:
		if station[axis] == 0.0: station[axis] = 0.0
	# All other identity fields remain exact; world movement and Roll are absent.
	return var_to_bytes([signature, weapon.get_instance_id(), slot, dominant, geometry_epoch,
		station, weapon.get_meta(prefix + "_origin_id"),
		weapon.get_meta("grip_style_mode", StringName()), geometry]).hex_encode()
