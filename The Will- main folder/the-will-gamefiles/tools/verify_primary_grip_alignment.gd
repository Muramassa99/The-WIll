extends SceneTree

## Pure preparation contract; does not run acquisition or claim skin contact.
## godot --headless --path . --script res://tools/verify_primary_grip_alignment.gd -- --out=<report.json>
## --out is optional. Exits nonzero on a failed check or an unwritable report.
const Seat = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const EPS := 0.00001
var checks: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base := _weapon()
	var hand := _hand(false)
	var saved_inputs := var_to_bytes([base, hand])
	var normal := _verify_case("normal", base, hand, false)
	_expect(var_to_bytes([base, hand]) == saved_inputs, "resolver_does_not_mutate_inputs")
	var reverse := _verify_case("reverse", base, hand, true)
	var mirrored := _verify_case("mirrored_index_pinky", base, _hand(true), false)
	_verify_case("mirrored_reverse", base, _hand(true), true)
	if normal.get("valid", false) and reverse.get("valid", false):
		var normal_frame: Transform3D = normal.weapon_to_machine
		var reverse_frame: Transform3D = reverse.weapon_to_machine
		_expect((normal_frame.basis.x.normalized() + reverse_frame.basis.x.normalized()).length() < EPS,
			"normal_reverse_have_opposite_length_polarity")
	if mirrored.get("valid", false) and reverse.get("valid", false):
		_expect(_frame_close(mirrored.weapon_to_machine, reverse.weapon_to_machine),
			"mirrored_axis_drives_polarity_without_an_extra_hand_side_sign")

	var swapped := base.duplicate(true)
	swapped.axis = -Vector3.RIGHT
	var swapped_result := _verify_case("swapped_handle_span", swapped, hand, false)
	if normal.get("valid", false) and swapped_result.get("valid", false):
		_expect(_frame_close(normal.weapon_to_machine, swapped_result.weapon_to_machine),
			"swapping_span_endpoints_does_not_reverse_semantic_tip")

	var chosen_roll := base.duplicate(true)
	chosen_roll.frame = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(37.0)), Vector3(3, 2, -1))
	var rolled_result := _verify_case("chosen_axial_facing", chosen_roll, hand, false)
	if rolled_result.get("valid", false):
		# The fixture is a +X to +Y turn, so a +90 degree Z rotation transports
		# the whole cross-section. No freshly selected up vector should replace it.
		var expected_basis := Basis(Vector3.BACK, PI * 0.5) * (chosen_roll.frame as Transform3D).basis
		_expect(_basis_close((rolled_result.weapon_to_machine as Transform3D).basis, expected_basis),
			"known_quarter_turn_preserves_authored_37_degree_facing")

	var scaled := chosen_roll.duplicate(true)
	scaled.frame = Transform3D((chosen_roll.frame as Transform3D).basis * Basis.from_scale(Vector3(0.7, 1.4, 2.0)), Vector3(1, -2, 3))
	_verify_case("non_unit_local_scale", scaled, hand, false)

	var other_station := base.duplicate(true)
	other_station.station = Vector3(-0.45, 0.023, -0.012)
	var other_result := _verify_case("different_handle_station", other_station, hand, false)
	if normal.get("valid", false) and other_result.get("valid", false):
		_expect(_basis_close((normal.weapon_to_machine as Transform3D).basis,
			(other_result.weapon_to_machine as Transform3D).basis), "station_change_keeps_facing")
		_expect(not (normal.weapon_to_machine as Transform3D).origin.is_equal_approx(
			(other_result.weapon_to_machine as Transform3D).origin), "station_change_moves_weapon_to_fixed_hand")

	var half_hand := _hand(false)
	half_hand.index = Vector3(-0.04, 0, 0)
	half_hand.pinky = Vector3(0.04, 0, 0)
	var half_result := _verify_case("exact_half_turn", base, half_hand, false)
	if half_result.get("valid", false):
		_expect(_basis_close((half_result.weapon_to_machine as Transform3D).basis,
			Basis(Vector3.BACK, PI)), "half_turn_uses_wrist_to_knuckle_reference")
	var repeated_half := Seat.resolve_primary_alignment(base, half_hand, false)
	_expect(half_result.get("valid", false) and repeated_half.get("valid", false)
		and _frame_close(half_result.weapon_to_machine, repeated_half.weapon_to_machine),
		"half_turn_is_repeatable")

	for field: String in ["frame_origin_id", "station_origin_id", "axis_origin_id", "tip_direction_origin_id"]:
		var bad := base.duplicate(true)
		bad[field] = &"WrongOrigin"
		_expect(not Seat.resolve_primary_alignment(bad, hand, false).get("valid", false), "reject_weapon_" + field)
	var bad_hand := hand.duplicate(true)
	bad_hand.origin_id = &"WrongOrigin"
	_expect(not Seat.resolve_primary_alignment(base, bad_hand, false).get("valid", false), "reject_hand_coordinate_origin")
	for field: String in ["index_origin_id", "pinky_origin_id", "wrist_origin_id", "target_source_origin_id"]:
		bad_hand = hand.duplicate(true)
		bad_hand.erase(field)
		_expect(not Seat.resolve_primary_alignment(base, bad_hand, false).get("valid", false), "reject_missing_" + field)
	var no_axis := base.duplicate(true)
	no_axis.axis = Vector3.ZERO
	_expect(not Seat.resolve_primary_alignment(no_axis, hand, false).get("valid", false), "reject_zero_handle_axis")
	var collapsed_hand := hand.duplicate(true)
	collapsed_hand.index = collapsed_hand.pinky
	_expect(not Seat.resolve_primary_alignment(base, collapsed_hand, false).get("valid", false), "reject_zero_index_pinky_axis")
	var no_half_reference := half_hand.duplicate(true)
	no_half_reference.wrist = Vector3.ZERO
	_expect(not Seat.resolve_primary_alignment(base, no_half_reference, false).get("valid", false), "reject_ambiguous_half_turn_without_reference")
	_finish()


func _verify_case(label: String, weapon: Dictionary, hand: Dictionary, reverse: bool) -> Dictionary:
	var result: Dictionary = Seat.resolve_primary_alignment(weapon, hand, reverse)
	_expect(result.get("valid", false), label + "_accepted")
	if not result.get("valid", false):
		return result
	var original: Transform3D = weapon.frame
	var final: Transform3D = result.weapon_to_machine
	_expect(final.is_finite() and final.basis.determinant() > 0.0, label + "_finite_proper_frame")
	_expect((final * (weapon.station as Vector3)).distance_to(hand.target) < EPS,
		label + "_selected_station_reaches_fixed_hand_reference")
	var expected_axis: Vector3 = ((hand.index as Vector3) - (hand.pinky as Vector3)).normalized()
	if reverse:
		expected_axis = -expected_axis
	# These fixtures use Tip along local +X even when the authored span is swapped.
	_expect((final.basis * Vector3.RIGHT).normalized().dot(expected_axis) > 1.0 - EPS,
		label + "_tip_polarity_parallel_to_index_pinky")
	var old_columns: Array[Vector3] = [original.basis.x, original.basis.y, original.basis.z]
	var new_columns: Array[Vector3] = [final.basis.x, final.basis.y, final.basis.z]
	var metric_preserved := true
	for i: int in 3:
		for j: int in 3:
			metric_preserved = metric_preserved and absf(old_columns[i].dot(old_columns[j]) - new_columns[i].dot(new_columns[j])) < EPS
	_expect(metric_preserved, label + "_scale_and_cross_section_metric_preserved")
	var rotation := final.basis * original.basis.inverse()
	var angle := rotation.get_rotation_quaternion().get_angle()
	if angle > PI:
		angle = TAU - angle
	var necessary_angle := (original.basis * Vector3.RIGHT).normalized().angle_to(expected_axis)
	_expect(absf(angle - necessary_angle) < 0.0005, label + "_no_unrequested_extra_rotation")
	var again_input := weapon.duplicate(true)
	again_input.frame = final
	var again: Dictionary = Seat.resolve_primary_alignment(again_input, hand, reverse)
	_expect(again.get("valid", false) and _frame_close(final, again.get("weapon_to_machine", Transform3D.IDENTITY)),
		label + "_idempotent")
	_expect(result.get("weapon_to_machine_origin_id") == &"RL_BoneRoot"
		and result.get("selected_station_origin_id") == &"WeaponRootOrigin", label + "_output_origin_chain")
	return result


func _weapon() -> Dictionary:
	return {"frame": Transform3D(Basis.IDENTITY, Vector3(2, -3, 4)), "frame_origin_id": &"RL_BoneRoot",
		"station": Vector3(0.3, 0.015, -0.008), "station_origin_id": &"WeaponRootOrigin",
		"axis": Vector3.RIGHT, "axis_origin_id": &"WeaponRootOrigin",
		"tip_direction": Vector3.RIGHT, "tip_direction_origin_id": &"WeaponRootOrigin"}


func _hand(mirrored: bool) -> Dictionary:
	var side := "L" if mirrored else "R"
	var index := Vector3(0, -0.04 if mirrored else 0.04, 0)
	return {"origin_id": &"RL_BoneRoot", "index": index, "pinky": -index,
		"wrist": Vector3(0, 0, -0.1), "target": Vector3(0, 0, 0.025),
		"index_origin_id": StringName("CC_Base_%s_Index1" % side),
		"pinky_origin_id": StringName("CC_Base_%s_Pinky1" % side),
		"wrist_origin_id": StringName("CC_Base_%s_Hand" % side),
		"target_source_origin_id": &"HandGripAlignmentOrigin"}


func _basis_close(a: Basis, b: Basis) -> bool:
	return a.x.distance_to(b.x) < EPS and a.y.distance_to(b.y) < EPS and a.z.distance_to(b.z) < EPS


func _frame_close(a: Transform3D, b: Transform3D) -> bool:
	return _basis_close(a.basis, b.basis) and a.origin.distance_to(b.origin) < EPS


func _expect(passed: bool, label: String) -> void:
	checks.append({"check": label, "passed": passed})
	if not passed:
		push_error("Primary alignment verification failed: " + label)


func _finish() -> void:
	var failures := 0
	for entry: Dictionary in checks:
		if not entry.passed:
			failures += 1
	var report := {"valid": failures == 0, "total": checks.size(), "passed": checks.size() - failures,
		"failed": failures, "checks": checks, "scope": "pure prealignment; no acquisition or contact certification"}
	var output := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			output = argument.trim_prefix("--out=")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write alignment report: " + output)
			quit(2)
			return
		file.store_string(JSON.stringify(report, "\t"))
	print("Primary alignment verification: %d/%d passed" % [report.passed, report.total])
	quit(0 if failures == 0 else 1)
