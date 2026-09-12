extends SceneTree

const PlayerHumanoidRigScene: PackedScene = preload(
	"res://scenes/player/player_humanoid_rig.tscn"
)
const CombatOriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)

var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var rig: PlayerHumanoidRig = PlayerHumanoidRigScene.instantiate()
	root.add_child(rig)
	await process_frame
	var baseline_frame: Dictionary = rig.capture_runtime_upper_body_pose_frame()
	var snapshot: Dictionary = _build_snapshot(rig, baseline_frame)
	_require(
		rig.authoring_grip_transaction_slot_pose_matches_snapshot(
			&"hand_right",
			snapshot
		),
		"unchanged Right Primary pose was rejected"
	)
	_require(
		rig.authoring_grip_transaction_slot_pose_matches_snapshot(
			&"hand_left",
			snapshot
		),
		"unchanged Left Primary pose was rejected"
	)
	_mutate_bone_rotation(rig, &"CC_Base_L_Pinky3")
	_require(
		rig.authoring_grip_transaction_slot_pose_matches_snapshot(
			&"hand_right",
			snapshot
		),
		"Right Primary pose changed when only the Left Support side changed"
	)
	_require(
		not rig.authoring_grip_transaction_slot_pose_matches_snapshot(
			&"hand_left",
			snapshot
		),
		"Left-side pose mutation was not detected"
	)
	_require(
		bool(rig.call(
			"_restore_authoring_grip_transaction_pose_frame",
			baseline_frame
		)),
		"baseline pose restore failed"
	)
	snapshot = _build_snapshot(
		rig,
		rig.capture_runtime_upper_body_pose_frame()
	)
	_mutate_bone_rotation(rig, &"CC_Base_R_Thumb1")
	_require(
		rig.authoring_grip_transaction_slot_pose_matches_snapshot(
			&"hand_left",
			snapshot
		),
		"Left Primary pose changed when only the Right Support side changed"
	)
	_require(
		not rig.authoring_grip_transaction_slot_pose_matches_snapshot(
			&"hand_right",
			snapshot
		),
		"Right-side pose mutation was not detected"
	)
	if failures.is_empty():
		print("PRIMARY_POSE_IMMUTABILITY_GATE=PASS")
		quit(0)
		return
	push_error(
		"PRIMARY_POSE_IMMUTABILITY_GATE=FAIL count=%d [%s]" % [
			failures.size(),
			"; ".join(failures),
		]
	)
	quit(1)


func _build_snapshot(
	rig: PlayerHumanoidRig,
	pose_frame: Dictionary
) -> Dictionary:
	var script_constants: Dictionary = (
		(rig.get_script() as Script).get_script_constant_map()
	)
	return {
		"valid": true,
		"snapshot_version": int(script_constants.get(
			"AUTHORING_ACTIVE_GRIP_TRANSACTION_SNAPSHOT_VERSION",
			-1
		)),
		"upper_body_pose_origin_id": (
			CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT
		),
		"upper_body_pose_frame": pose_frame.duplicate(true),
	}


func _mutate_bone_rotation(
	rig: PlayerHumanoidRig,
	bone_name: StringName
) -> void:
	var bone_index: int = rig.skeleton.find_bone(String(bone_name))
	_require(bone_index >= 0, "missing test bone %s" % String(bone_name))
	if bone_index < 0:
		return
	var baseline_rotation: Quaternion = rig.skeleton.get_bone_pose_rotation(
		bone_index
	)
	rig.skeleton.set_bone_pose_rotation(
		bone_index,
		baseline_rotation * Quaternion(Vector3.RIGHT, deg_to_rad(0.125))
	)


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("ASSERT: %s" % message)
