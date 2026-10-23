extends SceneTree

const PresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const UIScript = preload("res://runtime/combat/combat_animation_station_ui.gd")
const RigScript = preload("res://runtime/player/player_humanoid_rig.gd")
const ClipScript = preload("res://core/models/combat_runtime_clip.gd")
const MotionScript = preload("res://core/models/combat_animation_motion_node.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")
const SeatScript = preload("res://core/resolvers/primary_grip_seat_resolver.gd")

class FixturePresenter extends PresenterScript:
	var weapon: Node3D
	func _weapon_roll_context(_viewport: SubViewport) -> Dictionary:
		return {"weapon": weapon}

class FixtureUI extends UIScript:
	func _is_active_unarmed_authoring_wip() -> bool:
		return false

var _presenter := FixturePresenter.new()
var _checks := 0
var _failures: Array[String] = []
var _start := Vector3(0.2, -0.1, 0.3)
var _span := Vector3(0.2, 0.0, 0.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mount := Node3D.new()
	root.add_child(mount)
	var weapon := Node3D.new()
	mount.add_child(weapon)
	_presenter.weapon = weapon
	_presenter.configure_preview_hand_setup(&"hand_right", false)
	weapon.set_meta("primary_grip_span_start_local", _start)
	weapon.set_meta("primary_grip_span_start_origin_id", OriginScript.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("primary_grip_span_end_local", _start + _span)
	weapon.set_meta("primary_grip_span_end_origin_id", OriginScript.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("hand_grip_spans_meters", {&"hand_right": 0.12, &"hand_left": 0.16})
	mount.scale = Vector3.ONE * 0.764
	var larger := _frame(1.0, 0.4)
	var current_bounds: Dictionary = _presenter.get_held_item_hand_end_bounds(weapon, &"hand_right")
	_check(float(current_bounds.min_ratio) > 0.4, "fixture_current_mount_rejects_anchor")
	_expect_frame(larger, true, "larger_prospective_scale_accepted")
	_expect_ui([larger], true, "ui_uses_saved_scale_before_application")
	var invalid_anchor := _frame(1.0, 0.1)
	_expect_frame(invalid_anchor, false, "invalid_primary_still_rejected", "saved_grip_outside_handle_end_bounds", &"hand_right")
	_expect_ui([invalid_anchor], false, "ui_invalid_primary_rejected")

	mount.scale = Vector3.ONE
	current_bounds = _presenter.get_held_item_hand_end_bounds(weapon, &"hand_right")
	_check(bool(current_bounds.valid), "fixture_current_scale_fits_hand")
	var smaller := _frame(0.6, 0.5)
	_expect_frame(smaller, false, "smaller_prospective_scale_rejected", "handle_shorter_than_hand_footprint")
	_expect_ui([larger, smaller], false, "ui_checks_later_frame_scale")

	var two_hand := _frame(1.0, 0.5, 0.45)
	two_hand.two_hand_state = MotionScript.TWO_HAND_STATE_TWO_HAND
	_expect_frame(two_hand, false, "larger_support_footprint_rejected", "saved_grip_outside_handle_end_bounds", &"hand_left")
	_expect_ui([two_hand], false, "ui_checks_support_with_saved_scale")
	two_hand.solved_anchor_positions_weapon_local[1] = _start + _span * 0.5
	_expect_frame(two_hand, true, "both_hands_inside_prospective_bounds")
	two_hand.primary_hand_slot = &"hand_left"
	two_hand.solved_anchor_positions_weapon_local[1] = _start + _span * 0.2
	_expect_frame(two_hand, false, "left_primary_checks_right_support", "saved_grip_outside_handle_end_bounds", &"hand_right")

	var invalid_basis := _frame(1.0, 0.5)
	invalid_basis.solved_weapon_rotation_reference_local = Quaternion(0.0, 0.0, 0.0, 0.0)
	_expect_frame(invalid_basis, false, "zero_saved_rotation_rejected", "invalid_saved_weapon_basis")
	invalid_basis.solved_weapon_rotation_reference_local = Quaternion(NAN, 0.0, 0.0, 1.0)
	_expect_frame(invalid_basis, false, "nonfinite_saved_rotation_rejected", "invalid_saved_weapon_basis")
	invalid_basis = _frame(1.0, 0.5)
	invalid_basis.solved_weapon_scale_reference_local = Vector3(1.0, INF, 1.0)
	_expect_frame(invalid_basis, false, "nonfinite_saved_scale_rejected", "invalid_saved_weapon_basis")
	var missing_anchor := _frame(1.0, 0.5)
	missing_anchor.solved_anchor_node_paths = [&"SupportGripAnchor"]
	_expect_frame(missing_anchor, false, "missing_primary_rejected", "saved_grip_end_bounds_anchor_missing")

	# Derive boundary expectations from the actual rig replay constructor,
	# including its rotation/nonuniform-scale order, rather than copying it.
	var rig := RigScript.new()
	_span = Vector3(0.2, 0.11, -0.08)
	weapon.set_meta("primary_grip_span_end_local", _start + _span)
	_presenter.get_held_item_hand_end_bounds(weapon, &"hand_right")
	for rotation: Quaternion in [
		Quaternion.from_euler(Vector3(0.4, 1.0, -0.2)),
		Quaternion.from_euler(Vector3(-0.7, 0.2, 1.1)),
	]:
		for scale_value: Vector3 in [Vector3(0.8, 1.7, 0.6), Vector3(1.9, 0.6, 1.2)]:
			var replay_transform: Transform3D = rig._build_runtime_solved_replay_transform(Vector3(2.0, -3.0, 4.0), rotation, scale_value)
			var length_meters := (replay_transform.basis * _span).length()
			var bounds: Dictionary = SeatScript.resolve_hand_end_bounds(length_meters, 0.12)
			_check(bool(bounds.valid), "nonuniform_fixture_fits_hand")
			var reference_basis := Basis.from_euler(Vector3(0.7, -0.5, 0.3))
			_check(is_equal_approx((reference_basis * replay_transform.basis * _span).length(), length_meters), "orthonormal_reference_preserves_length")
			for ratio: float in [float(bounds.min_ratio), float(bounds.max_ratio)]:
				var packet := _frame(1.0, ratio)
				packet.solved_weapon_rotation_reference_local = rotation
				packet.solved_weapon_scale_reference_local = scale_value
				_expect_frame(packet, true, "rig_nonuniform_boundary_accepted")
				_expect_ui([packet], true, "ui_packs_saved_rotation_and_nonuniform_scale")
				var outward := -0.001 if ratio < 0.5 else 0.001
				packet.solved_anchor_positions_weapon_local[0] = _start + _span * (ratio + outward)
				_expect_frame(packet, false, "rig_nonuniform_outside_rejected", "saved_grip_outside_handle_end_bounds")
				_expect_ui([packet], false, "ui_nonuniform_outside_rejected")
	rig.free()
	mount.free()
	print(JSON.stringify({"verifier": "solved_replay_end_bounds_scale", "checks": _checks, "passed": _failures.is_empty(), "failures": _failures}, "\t"))
	quit(0 if _failures.is_empty() else 1)

func _frame(scale_value: float, primary_ratio: float, support_ratio: float = 0.5) -> Dictionary:
	return {
		"primary_hand_slot": &"hand_right",
		"two_hand_state": MotionScript.TWO_HAND_STATE_ONE_HAND,
		"solved_weapon_rotation_reference_local": Quaternion.IDENTITY,
		"solved_weapon_scale_reference_local": Vector3.ONE * scale_value,
		"solved_anchor_node_paths": [&"PrimaryGripAnchor", &"SupportGripAnchor"],
		"solved_anchor_positions_weapon_local": [_start + _span * primary_ratio, _start + _span * support_ratio],
	}

func _expect_frame(frame: Dictionary, expected: bool, label: String, reason: String = "", slot: StringName = StringName()) -> void:
	var transform_before := _presenter.weapon.global_transform
	var cache_before := var_to_bytes(_presenter.weapon.get_meta("preview_handle_span_measurement", {}))
	var packet_before := var_to_bytes(frame)
	var result: Dictionary = _presenter.validate_solved_replay_hand_end_bounds(_presenter.weapon, frame)
	_check(bool(result.get("valid", false)) == expected, label + ":" + str(result))
	if not reason.is_empty():
		_check(String(result.get("reason", "")) == reason, label + ":reason")
	if slot != StringName():
		_check(result.get("slot", StringName()) == slot, label + ":slot")
	_check(_presenter.weapon.global_transform == transform_before, label + ":live_transform_unchanged")
	_check(var_to_bytes(_presenter.weapon.get_meta("preview_handle_span_measurement", {})) == cache_before, label + ":measurement_cache_unchanged")
	_check(var_to_bytes(frame) == packet_before, label + ":saved_anchors_unchanged")

func _expect_ui(frames: Array[Dictionary], expected: bool, label: String) -> void:
	var ui := FixtureUI.new()
	ui.preview_presenter = _presenter
	var clip := ClipScript.new()
	clip.baked_solved_anchor_node_paths.assign([&"PrimaryGripAnchor", &"SupportGripAnchor"])
	for frame: Dictionary in frames:
		var rotation: Quaternion = frame.solved_weapon_rotation_reference_local
		clip.baked_frame_times.append(float(clip.baked_frame_times.size()) / 60.0)
		clip.baked_solved_replay_frame_available.append(true)
		clip.baked_solved_anchor_positions_weapon_local.append(PackedVector3Array(frame.solved_anchor_positions_weapon_local))
		clip.baked_solved_weapon_rotations_reference_local.append(Vector4(rotation.x, rotation.y, rotation.z, rotation.w))
		clip.baked_solved_weapon_scales_reference_local.append(frame.solved_weapon_scale_reference_local)
		clip.baked_primary_hand_slots.append(frame.primary_hand_slot)
		clip.baked_two_hand_states.append(frame.two_hand_state)
	var transform_before := _presenter.weapon.global_transform
	var measurement_before := var_to_bytes(_presenter.weapon.get_meta("preview_handle_span_measurement", {}))
	var clip_before := _clip_bytes(clip)
	_check(ui._runtime_clip_respects_handle_ends(clip) == expected, label)
	_check(_clip_bytes(clip) == clip_before, label + ":runtime_cache_unchanged")
	_check(_presenter.weapon.global_transform == transform_before, label + ":live_transform_unchanged")
	_check(var_to_bytes(_presenter.weapon.get_meta("preview_handle_span_measurement", {})) == measurement_before, label + ":measurement_cache_unchanged")
	ui.free()

func _clip_bytes(clip: Resource) -> PackedByteArray:
	return var_to_bytes([clip.baked_frame_times, clip.baked_solved_replay_frame_available,
		clip.baked_solved_anchor_node_paths, clip.baked_solved_anchor_positions_weapon_local,
		clip.baked_solved_weapon_rotations_reference_local, clip.baked_solved_weapon_scales_reference_local,
		clip.baked_primary_hand_slots, clip.baked_two_hand_states])

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
