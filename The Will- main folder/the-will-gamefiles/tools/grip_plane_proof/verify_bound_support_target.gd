extends SceneTree

## Exercise real target ownership with explicit collision/path outcomes. The
## constraint fixture changes the arm target by 3 mm, independently of the
## weapon/torso collision that formerly displaced a bound support hand by 80 mm.
const Solver = preload("res://runtime/player/two_hand_pose_solver.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

class Constraints extends RefCounted:
	func project_target_to_legal_grip_space(_body: Node3D, _source: Vector3, desired: Vector3,
		_origin: Vector3, _forward: Vector3, _right: Vector3, _up: Vector3, _settings: Dictionary, _exclusions: Array) -> Dictionary:
		return {"corrected_target": desired + Vector3(0, 0.003, 0), "path_illegal": true}
	func point_inside_body_restriction(_body: Node3D, _point: Vector3, _exclusions: Array) -> bool: return true

var _scene: Node3D
var _skeleton: Skeleton3D
var _right: Node3D
var _left: Node3D
var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok: _failures.append(label); push_error(label)

func _run() -> void:
	_scene = Node3D.new(); root.add_child(_scene)
	_skeleton = Skeleton3D.new(); _scene.add_child(_skeleton)
	_right = Node3D.new(); _scene.add_child(_right); _right.position = Vector3(0.2, 1.1, 0.3)
	_left = Node3D.new(); _scene.add_child(_left); _left.position = Vector3(-0.2, 1.1, 0.3)
	var proxy := Node3D.new(); proxy.name = "WeaponBodyRestrictionProxy"; _scene.add_child(proxy)
	var marker := Node3D.new(); marker.name = "WeaponBodySample_0"; proxy.add_child(marker)
	for dominant: StringName in [&"hand_right", &"hand_left"]:
		var support := &"hand_left" if dominant == &"hand_right" else &"hand_right"
		var requested := Transform3D(Basis.IDENTITY, Vector3(0.1, 1.2, 0.2))
		var frame := {"valid": true, "hand_to_world": requested, "hand_to_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
			"hand_in_weapon": requested, "hand_in_weapon_origin_id": Origins.ORIGIN_WEAPON_ROOT}
		var bound := _solve(dominant, {support: frame})
		var unbound := _solve(dominant, {})
		var actual: Dictionary = bound[support]
		var free: Dictionary = unbound[support]
		_check(actual.desired_target.is_equal_approx(requested.origin), "bound support uses requested Hand frame " + String(support))
		_check(actual.corrected_target.distance_to(requested.origin + Vector3(0, 0.003, 0)) < 0.000001, "genuine arm path correction remains " + String(support))
		_check(actual.projection.weapon_body_illegal and actual.projection.weapon_body_displacement_deferred_to_weapon_owner, "fixed weapon collision remains reported with correct owner " + String(support))
		_check(absf((free.corrected_target - free.desired_target - Vector3(0, 0.003, 0)).length() - 0.08) < 0.000001, "unbound support retains existing weapon push " + String(support))
		_check(bound[dominant].corrected_target.is_equal_approx(unbound[dominant].corrected_target), "support ownership does not change primary target " + String(dominant))
	_scene.queue_free()
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	quit(0 if _failures.is_empty() else 1)

func _solve(dominant: StringName, frames: Dictionary) -> Dictionary:
	return Solver.new().solve_arm_targets(_skeleton, _scene, dominant, Basis.IDENTITY,
		_right, _left, null, null, &"ru", &"lu", &"rf", &"lf", &"rh", &"lh",
		_bone, Callable(), Constraints.new(), {"front_bias_amount": 0.18, "safety_margin_meters": 0.08}, frames)

func _bone(name: StringName) -> Vector3:
	match name:
		&"ru": return Vector3(0.25, 1.4, 0)
		&"lu": return Vector3(-0.25, 1.4, 0)
		&"rf": return Vector3(0.3, 1.2, 0.1)
		&"lf": return Vector3(-0.3, 1.2, 0.1)
		&"rh": return _right.global_position
		&"lh": return _left.global_position
	return Vector3(0, 1.3, 0)
