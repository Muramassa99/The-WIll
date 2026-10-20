extends "res://tools/diagnose_skill_crafter_arm_solver_trace.gd"

# Isolated experiment, never installed on the runtime rig. Preserve the incoming
# bend branch during CCD/style forearm writes, using the existing angle cap.
# This tests continuity, not anatomical validity of the starting branch.
var _candidate_enabled := false
var _candidate_correcting := false
var _candidate_before: Dictionary = {}
var _candidate_events: Array[Dictionary] = []

func _run_thrust(ui: CombatAnimationStationUI, side: String, elevation: float) -> Dictionary:
	_candidate_enabled = false
	_candidate_before.clear()
	_candidate_events.clear()
	var result: Dictionary = await super._run_thrust(ui, side, elevation)
	_candidate_enabled = false
	result["continuity_candidate"] = {"events": _candidate_events.duplicate(true), "scope": "Diagnostic-only incoming bend-branch protection; no anatomical certification or production activation."}
	return result

func _record_stage(ui: CombatAnimationStationUI, sk: Skeleton3D, side: String, phase: String, extra: Dictionary = {}) -> void:
	if phase == "initial":
		_candidate_enabled = true
	await super._record_stage(ui, sk, side, phase, extra)

func _on_arm_solver_trace(event: StringName, details: Dictionary) -> void:
	if _candidate_correcting:
		details["diagnostic_branch_correction"] = true
	if _candidate_enabled and not _candidate_correcting:
		_probe_forearm_write(event, details)
	super._on_arm_solver_trace(event, details)

func _probe_forearm_write(event: StringName, details: Dictionary) -> void:
	var joint := String(details.get("joint_bone", ""))
	if joint != "CC_Base_%s_Forearm" % _trace_side or String(details.get("scope", "")) not in ["ccd", "spline"]:
		return
	var prefix: String = joint.trim_suffix("Forearm")
	var upper: int = _trace_sk.find_bone(prefix + "Upperarm")
	var elbow: int = _trace_sk.find_bone(joint)
	var hand: int = _trace_sk.find_bone(prefix + "Hand")
	if mini(upper, mini(elbow, hand)) < 0:
		return
	if event == &"before_bone_rotate":
		var shoulder_pos: Vector3 = _trace_sk.get_bone_global_pose(upper).origin
		var elbow_pos: Vector3 = _trace_sk.get_bone_global_pose(elbow).origin
		var hand_pos: Vector3 = _trace_sk.get_bone_global_pose(hand).origin
		_candidate_before = {"joint": joint, "shoulder": shoulder_pos, "elbow": elbow_pos, "hand": hand_pos, "rotation": _trace_sk.get_bone_pose_rotation(elbow)}
		return
	if event != &"after_bone_rotate" or _candidate_before.get("joint", "") != joint:
		return
	var before: Dictionary = _candidate_before
	_candidate_before = {}
	var u: Vector3 = (before.shoulder as Vector3) - (before.elbow as Vector3)
	var v: Vector3 = (before.hand as Vector3) - (before.elbow as Vector3)
	var n: Vector3 = u.cross(v)
	if n.length_squared() < 1.0e-12:
		return
	u = u.normalized()
	n = n.normalized()
	var proposed: Vector3 = _trace_sk.get_bone_global_pose(hand).origin - (before.elbow as Vector3)
	if proposed.length_squared() < 1.0e-12:
		return
	var before_angle: float = u.angle_to(v.normalized())
	var proposed_angle: float = atan2(n.dot(u.cross(proposed.normalized())), u.dot(proposed.normalized()))
	var continuous_angle: float = before_angle + wrapf(proposed_angle - before_angle, -PI, PI)
	var limit: float = deg_to_rad(clampf(_trace_actor.authoring_elbow_max_plane_angle_degrees, 1.0, 179.0))
	# Only the near-straight/maximum-extension question is tested. Do not invent
	# a lower flexion limit or collapse the elbow to a fully folded singularity.
	if continuous_angle <= limit + 0.000001:
		return
	var chosen_angle: float = limit
	var target: Vector3 = (before.elbow as Vector3) + Basis(n, chosen_angle) * u * v.length()
	var raw_rotation: Quaternion = _trace_sk.get_bone_pose_rotation(elbow)
	var raw_hand: Vector3 = _trace_sk.get_bone_global_pose(hand).origin
	details["candidate_intervention"] = true
	details["raw_proposed_rotation"] = raw_rotation
	details["raw_proposed_hand_skeleton"] = raw_hand
	_candidate_correcting = true
	_trace_sk.set_bone_pose_rotation(elbow, before.rotation as Quaternion)
	_trace_sk.force_update_all_bone_transforms()
	_trace_actor.call("_rotate_bone_toward_end_target", StringName(joint), StringName(prefix + "Hand"), target, 1.0)
	_candidate_correcting = false
	_candidate_events.append({"sample": correction_step, "phase": _trace_next_phase, "scope": details.get("scope"), "joint": joint, "incoming_degrees": rad_to_deg(before_angle), "proposed_degrees": rad_to_deg(continuous_angle), "chosen_degrees": rad_to_deg(chosen_angle), "before_rotation": _trace_quat(before.rotation as Quaternion), "raw_rotation": _trace_quat(raw_rotation), "raw_hand_skeleton": _vec(raw_hand), "incoming_plane_skeleton": _vec(n), "chosen_hand_skeleton": _vec(target)})
