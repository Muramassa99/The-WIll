extends SceneTree

const PreviewPresenterScript = preload(
	"res://runtime/combat/combat_animation_station_preview_presenter.gd"
)

var failures: PackedStringArray = []


class CollisionStateActor:
	extends Node3D

	var collision_state: Dictionary = {}

	func get_body_self_collision_debug_state(
		_include_all_illegal_pairs: bool = false
	) -> Dictionary:
		return collision_state.duplicate(true)


func _init() -> void:
	var presenter := PreviewPresenterScript.new()
	var actor := CollisionStateActor.new()
	root.add_child(actor)
	var baseline_pairs: Array = [
		_pair("Torso", "torso_abdomen", "LeftForearm", "left_forearm", -0.020),
		_pair("Torso", "torso_abdomen", "RightForearm", "right_forearm", -0.030),
	]
	var snapshot := {
		"valid": true,
		"body_self_collision_state": _state(baseline_pairs),
	}

	actor.collision_state = _state(baseline_pairs)
	_expect_gate(
		presenter,
		actor,
		snapshot,
		&"hand_left",
		true,
		&"support_surface_grip_body_collision_delta_legal",
		"unchanged Support pair"
	)

	actor.collision_state = _state([
		_pair("Torso", "torso_abdomen", "LeftForearm", "left_forearm", -0.010),
		_pair("Torso", "torso_abdomen", "RightForearm", "right_forearm", -0.030),
	])
	_expect_gate(
		presenter,
		actor,
		snapshot,
		&"hand_left",
		true,
		&"support_surface_grip_body_collision_delta_legal",
		"improved Support pair"
	)

	actor.collision_state = _state(baseline_pairs + [
		_pair("Chest", "torso_chest", "RightUpperarm", "right_upperarm", -0.050),
	])
	_expect_gate(
		presenter,
		actor,
		snapshot,
		&"hand_left",
		true,
		&"support_surface_grip_body_collision_delta_legal",
		"new Primary-only pair ignored"
	)

	actor.collision_state = _state(baseline_pairs + [
		_pair("Chest", "torso_chest", "LeftUpperarm", "left_upperarm", -0.005),
	])
	_expect_gate(
		presenter,
		actor,
		snapshot,
		&"hand_left",
		false,
		&"support_surface_grip_body_collision_new_illegal_pair",
		"new Support pair rejected"
	)

	actor.collision_state = _state([
		_pair("Torso", "torso_abdomen", "LeftForearm", "left_forearm", -0.022),
		_pair("Torso", "torso_abdomen", "RightForearm", "right_forearm", -0.030),
	])
	_expect_gate(
		presenter,
		actor,
		snapshot,
		&"hand_left",
		false,
		&"support_surface_grip_body_collision_worsened_illegal_pair",
		"worsened Support pair rejected"
	)

	actor.collision_state = _state([
		_pair(
			"Torso",
			"torso_abdomen",
			"LeftForearm",
			"left_forearm",
			-0.0200005
		),
		_pair("Torso", "torso_abdomen", "RightForearm", "right_forearm", -0.030),
	])
	_expect_gate(
		presenter,
		actor,
		snapshot,
		&"hand_left",
		true,
		&"support_surface_grip_body_collision_delta_legal",
		"sub-micrometer numeric drift ignored"
	)

	actor.collision_state = _state(baseline_pairs)
	actor.collision_state["illegal_pairs_complete"] = false
	var incomplete: Dictionary = presenter.call(
		"_evaluate_preview_support_body_self_collision_delta",
		actor,
		snapshot,
		&"hand_left"
	) as Dictionary
	_require(
		not bool(incomplete.get("valid", false))
			and not bool(incomplete.get("legal", false))
			and StringName(incomplete.get("status", StringName()))
				== &"support_surface_grip_body_collision_state_incomplete",
		"incomplete collision report fails closed",
		str(incomplete)
	)

	actor.queue_free()
	if failures.is_empty():
		print("PREVIEW_SUPPORT_BODY_COLLISION_DELTA=PASS")
		quit(0)
		return
	push_error(
		"PREVIEW_SUPPORT_BODY_COLLISION_DELTA=FAIL count=%d [%s]"
		% [failures.size(), "; ".join(failures)]
	)
	quit(1)


func _expect_gate(
	presenter: RefCounted,
	actor: Node3D,
	snapshot: Dictionary,
	slot_id: StringName,
	expected_legal: bool,
	expected_status: StringName,
	label: String
) -> void:
	var result: Dictionary = presenter.call(
		"_evaluate_preview_support_body_self_collision_delta",
		actor,
		snapshot,
		slot_id
	) as Dictionary
	_require(
		bool(result.get("valid", false))
			and bool(result.get("legal", false)) == expected_legal
			and StringName(result.get("status", StringName())) == expected_status,
		label,
		str(result)
	)


func _state(illegal_pairs: Array) -> Dictionary:
	return {
		"legal": illegal_pairs.is_empty(),
		"checked_pair_count": 190,
		"illegal_pair_count": illegal_pairs.size(),
		"illegal_pairs": illegal_pairs.duplicate(true),
		"illegal_pairs_complete": true,
	}


func _pair(
	first_attachment: String,
	first_region: String,
	second_attachment: String,
	second_region: String,
	clearance_meters: float
) -> Dictionary:
	return {
		"overlapping": true,
		"clearance_meters": clearance_meters,
		"first_attachment_name": first_attachment,
		"second_attachment_name": second_attachment,
		"first_region": first_region,
		"second_region": second_region,
		"first_bone_name": "%sBone" % first_attachment,
		"second_bone_name": "%sBone" % second_attachment,
		"allowed_anatomical_neighbor": false,
	}


func _require(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		return
	failures.append("%s%s" % [label, " (%s)" % detail if not detail.is_empty() else ""])
