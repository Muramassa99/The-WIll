extends SceneTree

## Exercise the production reach operator at submillimetre angular steps.
const Rig = preload("res://runtime/player/player_humanoid_rig.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _run() -> void:
	var rig = Rig.new()
	var skeleton := Skeleton3D.new()
	root.add_child(skeleton)
	rig.skeleton = skeleton
	skeleton.add_bone("joint")
	skeleton.add_bone("end")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_pose_position(1, Vector3.UP * 0.5)
	for angle: float in [0.0001, -0.0001, 0.001, 0.2, PI]:
		for weight: float in [1.0, 0.5]:
			skeleton.set_bone_pose_rotation(0, Quaternion.IDENTITY)
			skeleton.force_update_all_bone_transforms()
			var target := Basis(Vector3.RIGHT, angle) * Vector3.UP * 0.5
			rig._rotate_bone_toward_end_target(&"joint", &"end", target, weight)
			var actual: Vector3 = skeleton.get_bone_global_pose(1).origin
			if absf(angle) < PI:
				var expected := Basis(Vector3.RIGHT, angle * weight) * Vector3.UP * 0.5
				_check(actual.distance_to(expected) < 0.000001, "weighted endpoint angle %s weight %s" % [angle, weight])
			elif weight == 1.0:
				_check(actual.distance_to(target) < 0.000001, "antiparallel endpoint remains supported")
			_check(absf(actual.length() - 0.5) < 0.000001, "bone length preserved")
	rig.skeleton = null
	rig.free()
	skeleton.queue_free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
