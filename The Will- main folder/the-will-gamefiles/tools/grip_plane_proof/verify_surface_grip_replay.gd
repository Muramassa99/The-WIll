extends SceneTree

## A focused replay-owner contract proof. Geometry solving is deliberately
## stubbed: this verifies committed-pose reuse, rigid transport and refusal to
## publish a pending/failed pose. Natural fixture tests exercise the real solve.
const Owner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

class AnatomyStub extends Resource:
	var source_signature := "replay-fixture-anatomy"

class BindingStub extends RefCounted:
	var packets: Dictionary = {}
	func relationship(slot: StringName, _weapon: Node3D) -> Dictionary:
		return packets.get(slot, {})

class FingerStub extends RefCounted:
	var applications := 0
	func apply_planar_grip_rotations(_skeleton: Skeleton3D, _slot: StringName) -> bool:
		applications += 1
		return true

class ActorStub extends Node3D:
	var skeleton: Skeleton3D
	var planar_grip_pose_binding := BindingStub.new()
	var finger_grip_presenter := FingerStub.new()
	var applied_count := 0
	func claim_planar_grip_pose(_slot: StringName, _weapon: Node3D, _key: String) -> Dictionary:
		return {"valid": true}
	func release_planar_grip_pose(slot: StringName) -> void:
		planar_grip_pose_binding.packets.erase(slot)
	func apply_planar_grip_pose(slot: StringName, _weapon: Node3D, key: String, packet: Dictionary) -> Dictionary:
		applied_count += 1
		planar_grip_pose_binding.packets[slot] = packet.merged({"relationship_key": key}, true)
		return {"valid": true}
	func get_planar_grip_pose_state(slot: StringName) -> Dictionary:
		return {"has_grip_pose": planar_grip_pose_binding.packets.has(slot)}
	func capture_authoring_wrist_origin(_slot: StringName) -> Dictionary:
		var record := Origins.new()
		record.resolved_transform_to_machine = skeleton.get_bone_global_pose(1)
		return {"available": true, "machine_to_world": skeleton.global_transform, "origin_record": record}

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var actor := ActorStub.new()
	root.add_child(actor)
	actor.skeleton = Skeleton3D.new()
	actor.add_child(actor.skeleton)
	actor.skeleton.add_bone("RL_BoneRoot")
	actor.skeleton.add_bone("CC_Base_R_Hand")
	actor.skeleton.set_bone_parent(1, 0)
	actor.skeleton.set_bone_pose_position(1, Vector3(0.2, 0.4, 0.1))
	actor.skeleton.force_update_all_bone_transforms()
	var weapon := Node3D.new()
	root.add_child(weapon)
	weapon.set_meta("preview_primary_grip_seat_local", Vector3.ZERO)
	weapon.set_meta("preview_primary_grip_seat_origin_id", Origins.ORIGIN_WEAPON_ROOT)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.set_meta("visual_mesh_source", &"editable_mesh")
	weapon.add_child(mesh)
	var owner := Owner.new()
	actor.add_child(owner)
	owner.set_process(false)
	owner._actor = actor
	owner._weapon = weapon
	owner._skeleton = actor.skeleton
	owner._data = {"valid": true, "anatomy": AnatomyStub.new()}
	var slots: Array[StringName] = [&"hand_right"]
	var key: String = Owner.relationship_key(weapon, slots[0], slots[0], "replay-fixture-anatomy")
	var local_hand := Transform3D(Basis(Vector3.UP, 0.2), Vector3(0.01, -0.02, 0.03))
	owner._replay_pose_cache[key] = {"packet": {"hand_in_weapon": local_hand}, "status": {"status": "preview_applied"}}
	owner._busy = true
	var pending: Dictionary = owner.prepare_replay_grip(slots, slots[0])
	_check(not pending.valid and pending.reason == "grip_acquisition_pending", "Pending acquisition must not become a saved pose")
	_check(actor.applied_count == 0, "Pending replay must not apply a stale cached pose")
	owner._busy = false
	var first: Dictionary = owner.prepare_replay_grip(slots, slots[0])
	_check(first.get("valid", false), "Committed grip should be replayable")
	_check(first.get("solved_relationships", -1) == 0 and first.get("reused_relationships", 0) == 1, "Unchanged geometry must reuse its solved grip")
	var hand := actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(1)
	_check(weapon.global_transform.is_equal_approx(hand * local_hand.affine_inverse()), "Replay must transport the complete weapon-to-hand relationship")
	actor.transform = Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(0.5, -0.3, 0.2))
	actor.skeleton.force_update_all_bone_transforms()
	var second: Dictionary = owner.prepare_replay_grip(slots, slots[0])
	hand = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(1)
	_check(second.get("solved_relationships", -1) == 0, "Rigid actor motion must not reacquire the grip")
	_check(weapon.global_transform.is_equal_approx(hand * local_hand.affine_inverse()), "Rigid transport must not detach the weapon")
	_check(actor.finger_grip_presenter.applications == 2, "Each recorded frame must restore its finger rotations")
	owner._replay_pose_cache[key].status = {"status": "unresolved", "reason": "fixture_failure"}
	var failed: Dictionary = owner.prepare_replay_grip(slots, slots[0])
	_check(not failed.valid and failed.reason == "fixture_failure", "An unresolved cached pose must not become an available replay frame")
	owner.clear()
	actor.free()
	weapon.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
