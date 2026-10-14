extends SceneTree

## Exercise the real request owner without a surface solve. The missing skin
## fixture deliberately stops capture before worker creation; fake arm/worker
## objects expose ordering, cancellation and primary-preservation decisions.
const Owner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const PRIMARY := "preview_primary_grip_seat"
const SUPPORT := "preview_support_grip_seat"
var checks := 0
var failures: Array[String] = []

class FixtureAnatomy:
	extends Resource
	var source_signature := "primary_support_dependency_fixture"
	var reference_skin: Dictionary = {}

class FixtureBinding:
	extends RefCounted
	var states: Dictionary = {}
	func relationship(slot: StringName, _weapon: Node3D) -> Dictionary:
		var entry: Dictionary = states.get(slot, {})
		return entry.duplicate(true) if entry.get("has_grip_pose", false) else {}

class FixtureActor:
	extends Node3D
	var skeleton: Skeleton3D
	var mesh_instance: MeshInstance3D
	var planar_grip_pose_binding := FixtureBinding.new()
	var settle_count := 0
	var released: Array[StringName] = []
	var disturb_weapon: Node3D
	func claim_planar_grip_pose(slot: StringName, _weapon: Node3D, key: String) -> Dictionary:
		if planar_grip_pose_binding.states.get(slot, {}).get("relationship_key", "") != key:
			planar_grip_pose_binding.states[slot] = {"relationship_key": key,
				"has_grip_pose": false, "rotations": {}, "hand_in_weapon": Transform3D.IDENTITY}
		return {"valid": true}
	func release_planar_grip_pose(slot: StringName) -> void:
		released.append(slot)
		planar_grip_pose_binding.states.erase(slot)
	func get_planar_grip_pose_state(slot: StringName) -> Dictionary:
		return planar_grip_pose_binding.states.get(slot, {})
	func settle_authoring_support_grip_macro_pose_now() -> void:
		settle_count += 1
		if is_instance_valid(disturb_weapon): disturb_weapon.position.x += 0.01

class FixtureWorker:
	extends RefCounted
	var cancel_count := 0
	func cancel() -> void: cancel_count += 1
	func shutdown() -> void: cancel()
	func progress() -> Dictionary: return {}

class ObservedOwner:
	extends "res://runtime/player/grip/preview_grip_acquisition.gd"
	var rejected: Array[Dictionary] = []
	func _finish_failure(slot: StringName, request: Dictionary, reason: String, details: Dictionary = {}) -> void:
		rejected.append({"slot": slot, "reason": reason})
		super._finish_failure(slot, request, reason, details)

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _weapon(scene: Node3D) -> Node3D:
	var weapon := Node3D.new()
	scene.add_child(weapon)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.set_meta("visual_mesh_source", &"editable_mesh")
	weapon.add_child(mesh)
	weapon.set_meta(PRIMARY + "_local", Vector3(0.123456789, 0.0, 0.0))
	weapon.set_meta(SUPPORT + "_local", Vector3(-0.2, 0.0, 0.0))
	for prefix: String in [PRIMARY, SUPPORT]: weapon.set_meta(prefix + "_origin_id", Origins.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("grip_style_mode", &"grip_normal")
	return weapon

func _keys(weapon: Node3D, dominant: StringName, support: StringName) -> Array[String]:
	return [Owner.relationship_key(weapon, dominant, dominant, "fixture"),
		Owner.relationship_key(weapon, support, dominant, "fixture")]

func _key_checks(weapon: Node3D, dominant: StringName, support: StringName) -> void:
	var label := String(dominant)
	var initial := _keys(weapon, dominant, support)
	var fields: Array = bytes_to_var(initial[1].hex_decode())
	_check(fields.size() == 10 and fields[5] == Vector3(-0.2, 0, 0) and fields[6] == Origins.ORIGIN_WEAPON_ROOT and fields[7] == &"grip_normal" and fields[8] is Array,
		"existing support identity field positions remain stable " + label)
	_check(fields.size() == 10 and fields[9] == [Owner._station_identity(weapon.get_meta(PRIMARY + "_local")), Origins.ORIGIN_WEAPON_ROOT], "support identity names primary station and origin " + label)
	var primary: Vector3 = weapon.get_meta(PRIMARY + "_local")
	weapon.set_meta(PRIMARY + "_local", primary + Vector3(0.002, 0, 0))
	var changed := _keys(weapon, dominant, support)
	_check(changed[0] != initial[0] and changed[1] != initial[1], "primary station invalidates both relationships " + label)
	weapon.set_meta(PRIMARY + "_local", primary)
	weapon.set_meta(SUPPORT + "_local", Vector3(-0.19, 0, 0))
	changed = _keys(weapon, dominant, support)
	_check(changed[0] == initial[0] and changed[1] != initial[1], "support-only station retains primary " + label)
	weapon.set_meta(SUPPORT + "_local", Vector3(-0.2, 0, 0))
	weapon.global_transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(3, -2, 1))
	weapon.set_meta("weapon_roll_degrees", 47.0)
	_check(_keys(weapon, dominant, support) == initial, "rigid world movement and Roll retain both identities " + label)
	weapon.transform = Transform3D.IDENTITY
	weapon.set_meta(PRIMARY + "_local", Vector3(float(PackedFloat32Array([primary.x])[0]), 0.0, -0.0))
	_check(_keys(weapon, dominant, support) == initial, "primary float32 round trip and signed zero retain support identity " + label)
	weapon.set_meta(PRIMARY + "_local", primary + Vector3(0, 0, -1.88737914186277e-15))
	_check(_keys(weapon, dominant, support) == initial, "primary arithmetic zero tail does not reacquire support " + label)
	weapon.set_meta(PRIMARY + "_local", primary)
	weapon.set_meta(PRIMARY + "_origin_id", &"WrongOrigin")
	_check(_keys(weapon, dominant, support) == ["", ""], "unnamed primary origin blocks both relationships " + label)
	weapon.set_meta(PRIMARY + "_origin_id", Origins.ORIGIN_WEAPON_ROOT)

func _accept_primary(owner: Node, actor: FixtureActor, dominant: StringName) -> void:
	var request: Dictionary = owner._requests[dominant]
	actor.planar_grip_pose_binding.states[dominant].has_grip_pose = true
	owner._status[dominant] = {"status": "preview_applied", "serial": request.serial}
	owner._primary_seat = {"key": request.key, "slot": dominant}
	owner._queue.erase(dominant)

func _lifecycle_checks(scene: Node3D, weapon: Node3D, dominant: StringName, support: StringName) -> void:
	var label := String(dominant)
	var actor := FixtureActor.new()
	scene.add_child(actor)
	actor.skeleton = Skeleton3D.new()
	actor.add_child(actor.skeleton)
	actor.skeleton.add_bone("CC_Base_R_Hand")
	actor.skeleton.add_bone("CC_Base_L_Hand")
	var owner := ObservedOwner.new()
	actor.add_child(owner)
	owner.set_process(false)
	owner._actor = actor
	owner._weapon = weapon
	owner._skeleton = actor.skeleton
	owner._data = {"valid": true, "anatomy": FixtureAnatomy.new(), "config": {}}
	var slots: Array[StringName] = [support, dominant]
	owner.synchronize(slots, dominant)
	_check(not owner._primary_ready_for_support(), "pending primary cannot release support " + label)
	owner.settle_ready(true)
	_check(owner._support_macro_primary_serial == -1, "UI cannot acknowledge support against a pending primary " + label)
	_accept_primary(owner, actor, dominant)
	_check(owner._primary_ready_for_support(), "matching applied primary seat releases support " + label)
	owner._primary_seat.key = "stale"
	_check(not owner._primary_ready_for_support(), "stale primary seat cannot release support " + label)
	owner._primary_seat.key = owner._requests[dominant].key
	actor.planar_grip_pose_binding.states[dominant].relationship_key = "stale"
	_check(not owner._primary_ready_for_support(), "stale primary binding cannot release support " + label)
	actor.planar_grip_pose_binding.states[dominant].relationship_key = owner._requests[dominant].key
	# The UI reports that its own macro pass already aligned this support. Real
	# owner scheduling must capture directly, not invoke the arm macro again.
	owner.settle_ready(true)
	var acknowledged_primary: int = owner._requests[dominant].serial
	owner._queue.assign([support])
	owner._run_next(false)
	_check(owner._support_macro_primary_serial == acknowledged_primary and actor.settle_count == 0 and owner.rejected.back().reason == "coherent_pose_capture_failed", "acknowledged UI macro is not repeated during support capture " + label)
	weapon.set_meta(SUPPORT + "_local", Vector3(-0.18, 0, 0))
	owner.synchronize(slots, dominant, &"handle_position_changed")
	_check(owner._requests[dominant].serial == acknowledged_primary and owner._support_macro_primary_serial == -1, "support-only station change requires a new alignment acknowledgment " + label)
	owner.settle_ready(false)
	owner._run_next(false)
	_check(actor.settle_count == 1 and owner.rejected.back().reason == "coherent_pose_capture_failed", "false UI acknowledgment performs the missing support alignment " + label)
	weapon.set_meta(SUPPORT + "_local", Vector3(-0.17, 0, 0))
	owner.synchronize(slots, dominant, &"handle_position_changed")
	owner.settle_ready(true)
	owner._run_next(false)
	_check(actor.settle_count == 1 and owner.rejected.back().reason == "coherent_pose_capture_failed", "fresh UI acknowledgment avoids duplicate macro after support-only edit " + label)
	var prior_settle_count := actor.settle_count
	var old_support: Dictionary = owner._requests[support].duplicate(true)
	var worker := FixtureWorker.new()
	owner._job = worker
	owner._busy = true
	owner._running_slot = support
	owner._queue.erase(support)
	for step: int in 2:
		weapon.set_meta(PRIMARY + "_local", Vector3(0.14 + step * 0.01, 0, 0))
		owner.synchronize(slots, dominant, &"handle_position_changed")
	_check(worker.cancel_count == 2 and not owner._is_current(support, old_support), "rapid primary edits cancel stale support and reject its result " + label)
	_check(owner._queue.size() == 2 and owner._queue.count(dominant) == 1 and owner._queue.count(support) == 1, "rapid edits queue only one current request per hand " + label)
	_check(not owner._primary_ready_for_support() and not actor.get_planar_grip_pose_state(support).has_grip_pose, "new primary dependency clears support's old binding " + label)
	_check(owner._requests[dominant].serial != acknowledged_primary and owner._support_macro_primary_serial != owner._requests[dominant].serial, "new primary request invalidates earlier macro acknowledgment " + label)
	# Simulate the cancelled worker finishing. Execute the real queue selection;
	# missing skin stops capture without constructing an acquisition worker.
	owner._job = null
	owner._busy = false
	owner._running_slot = StringName()
	owner._queue.assign([support, dominant])
	owner._run_next(true)
	_check(owner.rejected.back().slot == dominant and owner.rejected.back().reason == "coherent_pose_capture_failed" and owner._queue == [support], "primary is selected ahead of older queued support " + label)
	owner._run_next(true)
	_check(owner.rejected.back().slot == support and owner.rejected.back().reason == "primary_grip_not_ready" and owner._job == null and actor.settle_count == prior_settle_count, "failed primary blocks support before arm preparation or worker creation " + label)
	_accept_primary(owner, actor, dominant)
	owner._queue.assign([support])
	owner._run_next(false)
	_check(actor.settle_count == prior_settle_count + 1 and owner._support_macro_primary_serial == owner._requests[dominant].serial and owner.rejected.back().reason == "coherent_pose_capture_failed", "newly committed primary requires one support settle before capture " + label)
	actor.disturb_weapon = weapon
	var prepared: Dictionary = owner._prepare_support_acquisition()
	_check(not prepared.get("valid", true) and prepared.get("reason") == "support_preparation_changed_primary_relationship", "support preparation rejects mutation of the established primary weapon " + label)
	actor.disturb_weapon = null
	weapon.position.x -= 0.01
	var latest: Dictionary = owner._requests[support].duplicate(true)
	worker = FixtureWorker.new()
	owner._job = worker
	owner._busy = true
	owner._running_slot = support
	owner._queue.assign([support])
	var one_hand: Array[StringName] = [dominant]
	owner.synchronize(one_hand, dominant)
	_check(worker.cancel_count == 1 and not owner._requests.has(support) and support not in owner._queue and support in actor.released and owner._support_macro_primary_serial == -1, "removing support cancels work and clears its alignment acknowledgment " + label)
	owner._finish_failure(support, latest, "cancelled")
	_check(not owner._status.has(support) and not owner._is_current(support, latest), "late removed-support result cannot restore its status or ownership " + label)
	actor.free()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	for dominant: StringName in [&"hand_right", &"hand_left"]:
		var support: StringName = &"hand_left" if dominant == &"hand_right" else &"hand_right"
		var weapon := _weapon(scene)
		_key_checks(weapon, dominant, support)
		_lifecycle_checks(scene, weapon, dominant, support)
		weapon.free()
	scene.free()
	print(JSON.stringify({"checks": checks, "failures": failures, "surface_solver_runs": 0}))
	quit(0 if failures.is_empty() else 1)
