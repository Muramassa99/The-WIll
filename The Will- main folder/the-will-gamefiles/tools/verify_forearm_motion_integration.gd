extends "res://tools/verify_combat_weapon_motion_rig.gd"

## Focused shared/independent callers of the new forearm clearance adapter.
## Uses the actual Idle pose and declared rigid bindings, not grip acquisition.
func _run() -> void:
	actor_parent = Node3D.new()
	root.add_child(actor_parent)
	rig = RigScene.instantiate() as PlayerHumanoidRig
	actor_parent.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.reset_authoring_preview_baseline_pose()
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	skeleton = rig.skeleton
	_check(skeleton != null, "actual_idle_rig_present")
	if skeleton == null:
		_finish()
		return
	base_poses = _poses()
	for side: String in ["R", "L"]:
		_exercise_independent_arm(side)
	_exercise_two_hands()
	_finish()

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("rig_report.json"), FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "samples": samples,
		"scope": "Actual Idle R/L rig, independent arms under a transformed root and shared two-hand rigid prop. Default forearm clearance enabled. No finger acquisition or saved skill lifecycle certification."}, "\t"))
	file.close()
	print("FOREARM_MOTION_INTEGRATION passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
