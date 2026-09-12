extends SceneTree

const CombatAnimationMotionNodeScript = preload(
	"res://core/models/combat_animation_motion_node.gd"
)
const CombatAnimationMotionNodeEditorScript = preload(
	"res://runtime/combat/combat_animation_motion_node_editor.gd"
)

var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var editor = CombatAnimationMotionNodeEditorScript.new()
	_check_close(
		"upper_limit_hard_stop",
		editor.resolve_bounded_weapon_roll_step(119.0, 8.0),
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MAX_DEGREES
	)
	_check_close(
		"upper_limit_does_not_wrap",
		editor.resolve_bounded_weapon_roll_step(
			CombatAnimationMotionNodeScript.WEAPON_ROLL_MAX_DEGREES,
			45.0
		),
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MAX_DEGREES
	)
	_check_close(
		"upper_limit_reverses_inward",
		editor.resolve_bounded_weapon_roll_step(
			CombatAnimationMotionNodeScript.WEAPON_ROLL_MAX_DEGREES,
			-5.0
		),
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MAX_DEGREES - 5.0
	)
	_check_close(
		"lower_limit_hard_stop",
		editor.resolve_bounded_weapon_roll_step(-119.0, -8.0),
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MIN_DEGREES
	)
	_check_close(
		"lower_limit_does_not_wrap",
		editor.resolve_bounded_weapon_roll_step(
			CombatAnimationMotionNodeScript.WEAPON_ROLL_MIN_DEGREES,
			-45.0
		),
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MIN_DEGREES
	)
	_check_close(
		"lower_limit_reverses_inward",
		editor.resolve_bounded_weapon_roll_step(
			CombatAnimationMotionNodeScript.WEAPON_ROLL_MIN_DEGREES,
			5.0
		),
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MIN_DEGREES + 5.0
	)

	var motion_node = CombatAnimationMotionNodeScript.new()
	motion_node.pommel_position_local = Vector3.ZERO
	motion_node.tip_position_local = Vector3.FORWARD
	var base_normal: Vector3 = editor.get_weapon_rotation_normal_local(motion_node)
	motion_node.weapon_roll_degrees = 90.0
	var rolled_normal: Vector3 = editor.get_weapon_rotation_normal_local(motion_node)
	var expected_normal: Vector3 = base_normal.rotated(Vector3.FORWARD, PI * 0.5)
	_check(
		"gizmo_normal_consumes_roll_scalar",
		rolled_normal.distance_to(expected_normal) <= 0.000001
	)
	_check(
		"gizmo_normal_stays_on_roll_plane",
		absf(rolled_normal.dot(Vector3.FORWARD)) <= 0.000001
	)

	motion_node.weapon_roll_degrees = 500.0
	motion_node.normalize()
	_check_close(
		"motion_node_uses_same_upper_bound",
		motion_node.weapon_roll_degrees,
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MAX_DEGREES
	)
	motion_node.weapon_roll_degrees = -500.0
	motion_node.normalize()
	_check_close(
		"motion_node_uses_same_lower_bound",
		motion_node.weapon_roll_degrees,
		CombatAnimationMotionNodeScript.WEAPON_ROLL_MIN_DEGREES
	)

	editor.begin_drag(
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION,
		Vector2.ZERO,
		motion_node
	)
	_check("roll_transaction_started", editor.is_dragging())
	_check(
		"roll_transaction_targeted",
		editor.get_drag_target()
			== CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION
	)
	editor.end_drag()
	_check("roll_transaction_ended", not editor.is_dragging())

	if failures.is_empty():
		print("skill_crafter_weapon_roll_ok=true")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	print("skill_crafter_weapon_roll_ok=false")
	quit(1)


func _check(label: String, condition: bool) -> void:
	if not condition:
		failures.append(label)


func _check_close(label: String, actual: float, expected: float) -> void:
	_check(label, is_equal_approx(actual, expected))
