extends SceneTree

const BakedProfileScript = preload("res://core/models/baked_profile.gd")
const CombatAnimationMotionNodeScript = preload(
	"res://core/models/combat_animation_motion_node.gd"
)
const CombatAnimationDraftScript = preload(
	"res://core/models/combat_animation_draft.gd"
)
const CombatAnimationStationStateScript = preload(
	"res://core/models/combat_animation_station_state.gd"
)
const CraftedItemWIPScript = preload(
	"res://core/models/crafted_item_wip.gd"
)
const CombatAnimationStationPreviewPresenterScript = preload(
	"res://runtime/combat/combat_animation_station_preview_presenter.gd"
)
const PrimaryGripSeatResolverScript = preload(
	"res://core/resolvers/primary_grip_seat_resolver.gd"
)
const CombatOriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)
const PlayerRigGripLayoutPresenterScript = preload(
	"res://runtime/player/player_rig_grip_layout_presenter.gd"
)
const TEST_HAND_SPAN_METERS := 0.078771524
const TEST_END_CLEARANCE_METERS := 0.0472629144


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var directional := (
		BakedProfileScript
		.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
	)
	var balanced := (
		BakedProfileScript.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
	)
	_assert_close(
		PrimaryGripSeatResolverScript.display_value_to_handle_coordinate(
			-0.5,
			directional
		),
		0.0,
		"directional UI hard-clamps below Pommel"
	)
	_assert_close(
		PrimaryGripSeatResolverScript.display_value_to_handle_coordinate(
			0.0,
			balanced
		),
		0.5,
		"balanced UI zero maps to the same Handle midpoint"
	)
	_assert_close(
		PrimaryGripSeatResolverScript.handle_coordinate_to_display_value(
			0.3,
			balanced
		),
		-0.4,
		"balanced UI display is only a normalized percentage lens"
	)
	_assert_close(
		PrimaryGripSeatResolverScript.resolve_handle_coordinate_axis_ratio(
			0.25,
			1.0
		),
		0.25,
		"forward Handle order preserves normalized position"
	)
	_assert_close(
		PrimaryGripSeatResolverScript.resolve_handle_coordinate_axis_ratio(
			0.25,
			0.0
		),
		0.75,
		"reversed Handle order preserves Pommel-to-Tip meaning"
	)

	var motion_node := CombatAnimationMotionNodeScript.new()
	motion_node.grip_seat_slide_offset = -0.7
	motion_node.secondary_grip_seat_slide_offset = -0.2
	motion_node.normalize()
	_assert_close(
		motion_node.grip_seat_slide_offset,
		0.0,
		"saved primary Handle position cannot remain negative"
	)
	_assert_close(
		motion_node.secondary_grip_seat_slide_offset,
		0.0,
		"saved support Handle position cannot remain negative"
	)
	_verify_legacy_station_coordinate_migration(balanced)
	_verify_metric_hand_end_bounds(balanced)
	_verify_initial_layout_end_bounds()

	var held_item := _build_test_held_item()
	root.add_child(held_item)
	var preview_presenter := CombatAnimationStationPreviewPresenterScript.new()
	var primary_zero: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets",
		held_item,
		0.0,
		0.0
	)
	var support_zero: Dictionary = preview_presenter.call(
		"_resolve_secondary_grip_seat_state_from_offsets",
		held_item,
		0.0
	)
	_assert_close(
		float(primary_zero.get("ratio", -1.0)),
		TEST_END_CLEARANCE_METERS,
		"primary zero stops with the entire padded hand inside the Pommel end"
	)
	_assert_close(
		float(support_zero.get("ratio", -1.0)),
		TEST_END_CLEARANCE_METERS,
		"support zero observes the same physical Pommel clearance"
	)
	var support_one: Dictionary = preview_presenter.call(
		"_resolve_secondary_grip_seat_state_from_offsets",
		held_item,
		1.0
	)
	_assert_close(
		float(support_one.get("ratio", -1.0)),
		1.0 - TEST_END_CLEARANCE_METERS,
		"support one stops before the Tip end"
	)
	_verify_axial_end_limits(preview_presenter, held_item, false)
	held_item.set_meta(
		"primary_grip_handle_tip_side_axis_ratio_from_span_start",
		0.0
	)
	var reversed_primary_zero: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets",
		held_item,
		0.0,
		0.0
	)
	var reversed_support_zero: Dictionary = preview_presenter.call(
		"_resolve_secondary_grip_seat_state_from_offsets",
		held_item,
		0.0
	)
	_assert_close(
		float(reversed_primary_zero.get("ratio", -1.0)),
		1.0 - TEST_END_CLEARANCE_METERS,
		"reversed primary zero preserves physical Pommel clearance"
	)
	_assert_close(
		float(reversed_support_zero.get("ratio", -1.0)),
		1.0 - TEST_END_CLEARANCE_METERS,
		"reversed support zero preserves the same Pommel clearance"
	)
	_verify_axial_end_limits(preview_presenter, held_item, true)
	held_item.set_meta(
		"primary_grip_handle_tip_side_axis_ratio_from_span_start", 1.0
	)
	_verify_hand_size_and_transform(preview_presenter, held_item)
	_verify_replay_end_bounds(preview_presenter, held_item)
	_verify_missing_hand_measurements(preview_presenter, held_item)
	held_item.free()
	print("verify_handle_coordinate_contract: PASS")
	quit(0)


func _build_test_held_item() -> Node3D:
	var held_item := Node3D.new()
	held_item.set_meta("hand_grip_spans_meters", {
		&"hand_right": TEST_HAND_SPAN_METERS,
		&"hand_left": TEST_HAND_SPAN_METERS,
	})
	var origin_id := CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	held_item.set_meta("primary_grip_span_start_local", Vector3.ZERO)
	held_item.set_meta("primary_grip_span_start_origin_id", origin_id)
	held_item.set_meta("primary_grip_span_end_local", Vector3.RIGHT)
	held_item.set_meta("primary_grip_span_end_origin_id", origin_id)
	held_item.set_meta(
		"primary_grip_slice_axis_ratios_from_span_start",
		PackedFloat32Array([0.0, 0.5, 1.0])
	)
	held_item.set_meta(
		"primary_grip_slice_centers_local",
		PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.5, 0.1, 0.0),
			Vector3.RIGHT,
		])
	)
	held_item.set_meta("primary_grip_slice_center_path_origin_id", origin_id)
	held_item.set_meta("primary_grip_contact_local", Vector3.ZERO)
	held_item.set_meta("primary_grip_contact_origin_id", origin_id)
	held_item.set_meta("support_grip_contact_local", Vector3.RIGHT)
	held_item.set_meta("support_grip_contact_origin_id", origin_id)
	held_item.set_meta(
		"primary_grip_handle_tip_side_axis_ratio_from_span_start",
		1.0
	)
	return held_item


func _verify_metric_hand_end_bounds(balanced_mode: StringName) -> void:
	var bounds: Dictionary = PrimaryGripSeatResolverScript.resolve_hand_end_bounds(
		0.1, TEST_HAND_SPAN_METERS
	)
	assert(bool(bounds.get("valid", false)), "a 100 mm handle fits the prepared hand")
	_assert_close(float(bounds.get("min_ratio", -1.0)), 0.472629144,
		"100 mm handle keeps 47.2629144 mm clear at the Pommel end")
	_assert_close(float(bounds.get("max_ratio", -1.0)), 0.527370856,
		"100 mm handle keeps the same clearance at the Tip end")
	for end_key: String in ["min_ratio", "max_ratio"]:
		var ratio := float(bounds[end_key])
		var signed_display: float = PrimaryGripSeatResolverScript.handle_coordinate_to_display_value(
			ratio, balanced_mode
		)
		var restored: float = PrimaryGripSeatResolverScript.display_value_to_handle_coordinate(
			signed_display, balanced_mode
		)
		_assert_close(restored * 0.1, ratio * 0.1,
			"signed display retains the same physical %s position" % end_key)
		_assert_close(signed_display, -0.054741712 if end_key == "min_ratio" else 0.054741712,
			"signed display doubles percentage-point offsets from the midpoint")
	var exact_fit: Dictionary = PrimaryGripSeatResolverScript.resolve_hand_end_bounds(
		TEST_HAND_SPAN_METERS * 1.2, TEST_HAND_SPAN_METERS
	)
	assert(bool(exact_fit.get("valid", false)), "an exactly fitting hand has one legal midpoint")
	_assert_close(float(exact_fit.get("min_ratio", -1.0)), 0.5, "exact fit minimum")
	_assert_close(float(exact_fit.get("max_ratio", -1.0)), 0.5, "exact fit maximum")
	for invalid_pair: Array in [
		[0.09, TEST_HAND_SPAN_METERS],
		[0.0, TEST_HAND_SPAN_METERS],
		[-0.1, TEST_HAND_SPAN_METERS],
		[0.1, 0.0],
		[0.1, -TEST_HAND_SPAN_METERS],
		[NAN, TEST_HAND_SPAN_METERS],
		[0.1, NAN],
		[INF, TEST_HAND_SPAN_METERS],
		[0.1, INF],
	]:
		var invalid_bounds: Dictionary = PrimaryGripSeatResolverScript.resolve_hand_end_bounds(
			float(invalid_pair[0]), float(invalid_pair[1])
		)
		assert(not bool(invalid_bounds.get("valid", false)),
			"a short handle or unavailable/non-finite metric cannot permit endcap placement: %s" % str(invalid_pair))


func _verify_axial_end_limits(
	preview_presenter: RefCounted, held_item: Node3D, reversed_path: bool
) -> void:
	var near_end := TEST_END_CLEARANCE_METERS
	var far_end := 1.0 - TEST_END_CLEARANCE_METERS
	var tip_state: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets", held_item, 0.75, 1.0
	)
	var pommel_state: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets", held_item, 0.25, -1.0
	)
	_assert_close(float(tip_state.get("ratio", -1.0)), near_end if reversed_path else far_end,
		"positive axial adjustment cannot push the hand beyond the Tip clearance")
	_assert_close(float(pommel_state.get("ratio", -1.0)), far_end if reversed_path else near_end,
		"negative axial adjustment cannot push the hand beyond the Pommel clearance")
	var cancelled_state: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets", held_item, 0.0, 1.0
	)
	_assert_close(float(cancelled_state.get("ratio", -1.0)), 0.5,
		"base and axial adjustment combine before the single final end-bound clamp")
	var ordinary_state: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets", held_item, 0.3, 0.2
	)
	_assert_close(float(ordinary_state.get("ratio", -1.0)), 0.6 if reversed_path else 0.4,
		"ordinary in-range base plus axial positions remain unchanged")


func _verify_hand_size_and_transform(
	preview_presenter: RefCounted, held_item: Node3D
) -> void:
	held_item.set_meta("hand_grip_spans_meters", {
		&"hand_right": TEST_HAND_SPAN_METERS,
		&"hand_left": 0.1,
	})
	# Projection is shared by initial primary legality and support placement.
	# Its footprint must belong to the queried hand, independent of dominance.
	for dominant: StringName in [&"hand_right", &"hand_left"]:
		preview_presenter.call("configure_preview_hand_setup", dominant, false)
		for slot: StringName in [&"hand_right", &"hand_left"]:
			var clearance: float = TEST_END_CLEARANCE_METERS if slot == &"hand_right" else 0.06
			for end: float in [0.0, 1.0]:
				var projected: Dictionary = preview_presenter.call(
					"_project_world_target_to_held_item_grip_span", held_item,
					Transform3D.IDENTITY, Vector3.RIGHT * end, slot
				)
				_assert_close(float(projected.get("projected_ratio", -1.0)),
					clearance if end == 0.0 else 1.0 - clearance,
					"%s projection uses its own end clearance with %s primary" % [slot, dominant])
	preview_presenter.call("configure_preview_hand_setup", &"hand_right", false)
	var stationary_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	for angle: float in [0.13, 0.59, 1.14, 1.76, 2.91, 3.17, 4.56, 5.92]:
		held_item.basis = Basis.from_euler(Vector3(angle * 0.37, angle, angle * -0.21))
		var rotated_bounds: Dictionary = preview_presenter.call(
			"get_held_item_hand_end_bounds", held_item, &"hand_right")
		assert(rotated_bounds.min_ratio == stationary_bounds.min_ratio,
			"rigid rotation must not move the end station across an identity rounding boundary")
	held_item.transform = Transform3D.IDENTITY
	held_item.set_meta("primary_grip_span_end_local", Vector3.RIGHT * 2.0)
	var longer_span_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(longer_span_bounds.min_ratio), TEST_END_CLEARANCE_METERS / 2.0,
		"changing the authored span invalidates the cached physical length")
	held_item.set_meta("primary_grip_span_end_local", Vector3.RIGHT)
	var restored_span_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(restored_span_bounds.min_ratio), TEST_END_CLEARANCE_METERS,
		"restoring the authored span restores its original end clearance")
	held_item.scale = Vector3.ONE * 2.0
	var scaled_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(scaled_bounds.min_ratio), TEST_END_CLEARANCE_METERS / 2.0,
		"physical item scaling invalidates the cached length")
	held_item.transform = Transform3D.IDENTITY
	var restored_scale_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(restored_scale_bounds.min_ratio), TEST_END_CLEARANCE_METERS,
		"removing item scale restores the original physical length")
	held_item.set_meta("hand_grip_spans_meters", {&"hand_right": TEST_HAND_SPAN_METERS * 0.001, &"hand_left": 0.1})
	held_item.scale = Vector3.ONE * 0.001
	var tiny_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(tiny_bounds.min_ratio), TEST_END_CLEARANCE_METERS,
		"proportionally scaled miniature item and hand retain the same clearance ratio")
	held_item.scale = Vector3.ONE * 0.002
	var resized_tiny_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(resized_tiny_bounds.min_ratio), TEST_END_CLEARANCE_METERS / 2.0,
		"relative resizing at miniature scale invalidates the cached metric")
	held_item.transform = Transform3D.IDENTITY
	held_item.set_meta("hand_grip_spans_meters", {&"hand_right": TEST_HAND_SPAN_METERS, &"hand_left": 0.1})
	var left_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_left"
	)
	_assert_close(float(left_bounds.get("min_ratio", -1.0)), 0.06,
		"left hand uses its own measured span")
	preview_presenter.call("configure_preview_hand_setup", &"hand_left", true)
	var primary_left: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets", held_item, 0.0, 0.0
	)
	var support_right: Dictionary = preview_presenter.call(
		"_resolve_secondary_grip_seat_state_from_offsets", held_item, 0.0
	)
	_assert_close(float(primary_left.get("ratio", -1.0)), 0.06,
		"left-primary setup reserves the left hand footprint")
	_assert_close(float(support_right.get("ratio", -1.0)), TEST_END_CLEARANCE_METERS,
		"right support keeps its own footprint when primary changes sides")
	preview_presenter.call("configure_preview_hand_setup", &"hand_right", false)
	var scale_parent := Node3D.new()
	root.add_child(scale_parent)
	scale_parent.scale = Vector3(2.0, 3.0, 4.0)
	held_item.reparent(scale_parent, false)
	held_item.rotation.z = PI * 0.5
	held_item.position = Vector3(4.0, 7.0, -2.0)
	var transformed_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right"
	)
	_assert_close(float(transformed_bounds.get("min_ratio", -1.0)), TEST_END_CLEARANCE_METERS / 3.0,
		"clearance uses the world span after parent scale and item rotation, not local units")
	held_item.rotation = Vector3.ZERO
	var reoriented_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(reoriented_bounds.min_ratio), TEST_END_CLEARANCE_METERS / 2.0,
		"item rotation under a nonuniform parent invalidates changed physical length")
	scale_parent.scale = Vector3(5.0, 3.0, 4.0)
	var rescaled_parent_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right")
	_assert_close(float(rescaled_parent_bounds.min_ratio), TEST_END_CLEARANCE_METERS / 5.0,
		"changing parent scale invalidates the cached physical length")
	held_item.reparent(root, false)
	held_item.transform = Transform3D.IDENTITY
	scale_parent.free()


func _verify_missing_hand_measurements(
	preview_presenter: RefCounted, held_item: Node3D
) -> void:
	held_item.remove_meta("hand_grip_spans_meters")
	var missing_bounds: Dictionary = preview_presenter.call(
		"get_held_item_hand_end_bounds", held_item, &"hand_right"
	)
	assert(not bool(missing_bounds.get("valid", false)),
		"missing character measurements cannot silently restore full endcap usage")
	var missing_seat: Dictionary = preview_presenter.call(
		"_resolve_primary_grip_seat_state_from_offsets", held_item, 0.0, 0.0
	)
	assert(not bool(missing_seat.get("valid", false)),
		"a seat without measured end bounds is rejected")
	held_item.set_meta("hand_grip_spans_meters", {&"hand_right": TEST_HAND_SPAN_METERS})
	var missing_support: Dictionary = preview_presenter.call(
		"_resolve_secondary_grip_seat_state_from_offsets", held_item, 1.0
	)
	assert(not bool(missing_support.get("valid", false)),
		"a missing support measurement cannot borrow primary hand size")


func _verify_replay_end_bounds(preview_presenter: RefCounted, held_item: Node3D) -> void:
	# Previous transform test leaves actual right/left spans different on purpose.
	preview_presenter.call("configure_preview_hand_setup", &"hand_right", false)
	var playback := {
		"two_hand_state": CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND,
		"solved_anchor_node_paths": [&"PrimaryGripAnchor", &"SupportGripAnchor"],
		"solved_anchor_positions_weapon_local": [Vector3(0.5, 0.1, 0.0), Vector3.RIGHT],
	}
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"one-hand replay accepts its midpoint and ignores an inactive support anchor")
	playback.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"explicit two-hand replay checks the actual support anchor")
	playback.solved_anchor_positions_weapon_local[1] = Vector3(0.94, 0.0, 0.0)
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"two-hand replay accepts the left hand exactly at its own padded Tip boundary")
	playback.solved_anchor_positions_weapon_local[1] = Vector3(0.95, 0.0, 0.0)
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"larger left support cannot borrow the smaller right hand end allowance")
	playback.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"automatic one-hand preview ignores inactive support")
	preview_presenter.call("configure_preview_hand_setup", &"hand_right", true)
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"automatic two-hand preview validates support")
	playback.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"an explicit one-hand frame overrides the two-hand preview default")
	playback.solved_anchor_positions_weapon_local[0] = Vector3(0.05, 0.0, 0.0)
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"right primary can use a location inside its own smaller footprint bounds")
	preview_presenter.call("configure_preview_hand_setup", &"hand_left", true)
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"switching to larger left primary rechecks its different footprint")
	playback.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
	playback.solved_anchor_positions_weapon_local = [Vector3(0.5, 0.0, 0.0), Vector3(0.05, 0.0, 0.0)]
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"left-primary two-hand replay validates support using the right hand span")
	preview_presenter.call("configure_preview_hand_setup", &"hand_right", false)
	playback.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	for boundary: float in [TEST_END_CLEARANCE_METERS, 1.0 - TEST_END_CLEARANCE_METERS]:
		var outward := -1.0 if boundary < 0.5 else 1.0
		playback.solved_anchor_positions_weapon_local[0] = Vector3(boundary, 0.0, 0.0)
		_expect_replay_validity(preview_presenter, held_item, playback, true,
			"saved primary at either exact boundary remains replayable")
		playback.solved_anchor_positions_weapon_local[0] = Vector3(boundary + outward * 0.0000005, 0.0, 0.0)
		_expect_replay_validity(preview_presenter, held_item, playback, true,
			"sub-epsilon float projection noise does not invalidate a saved boundary pose")
		playback.solved_anchor_positions_weapon_local[0] = Vector3(boundary + outward * 0.000002, 0.0, 0.0)
		_expect_replay_validity(preview_presenter, held_item, playback, false,
			"actual travel beyond the boundary epsilon invalidates saved replay")
	playback.solved_anchor_positions_weapon_local[0] = Vector3(NAN, 0.0, 0.0)
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"non-finite saved anchor cannot enter solved replay")
	playback.solved_anchor_node_paths = ["SupportGripAnchor"]
	playback.solved_anchor_positions_weapon_local = [Vector3(0.5, 0.0, 0.0)]
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"saved replay requires its participating primary anchor")
	playback.solved_anchor_node_paths = ["PrimaryGripAnchor"]
	playback.solved_anchor_positions_weapon_local = []
	_expect_replay_validity(preview_presenter, held_item, playback, false,
		"a saved anchor path without its position is invalid")
	playback.solved_anchor_positions_weapon_local = [Vector3(0.5, 0.0, 0.0)]
	_expect_replay_validity(preview_presenter, held_item, playback, true,
		"serialized String anchor paths retain the same interpretation as StringName paths")


func _expect_replay_validity(
	preview_presenter: RefCounted, held_item: Node3D,
	playback: Dictionary, expected_valid: bool, label: String
) -> void:
	var before := playback.duplicate(true)
	var result: Dictionary = preview_presenter.call(
		"validate_solved_replay_hand_end_bounds", held_item, playback
	)
	assert(bool(result.get("valid", false)) == expected_valid,
		"%s: %s" % [label, str(result)])
	# NaN is not equal to itself, so only compare finite snapshots here.
	var finite_positions := true
	for position: Vector3 in before.get("solved_anchor_positions_weapon_local", []):
		finite_positions = finite_positions and position.is_finite()
	if finite_positions:
		assert(playback == before, "replay validation must not move solved anchors away from solved fingers")


func _verify_initial_layout_end_bounds() -> void:
	var profile := BakedProfileScript.new()
	profile.primary_grip_valid = true
	profile.primary_grip_axis_ratio_from_span_start = 0.0
	profile.primary_grip_span_start = Vector3.ZERO
	profile.primary_grip_span_end = Vector3(10.0, 0.0, 0.0)
	profile.primary_grip_slide_axis = Vector3.RIGHT
	profile.primary_grip_slice_axis_ratios_from_span_start = PackedFloat32Array([0.0, 0.5, 1.0])
	profile.primary_grip_slice_centers = PackedVector3Array([
		Vector3.ZERO, Vector3(5.0, 1.0, 0.0), Vector3(10.0, 0.0, 0.0),
	])
	profile.primary_grip_slice_centers_origin_id = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	var presenter := PlayerRigGripLayoutPresenterScript.new()
	var spans := {&"hand_right": TEST_HAND_SPAN_METERS, &"hand_left": 0.1}
	var layout: Dictionary = presenter.resolve_grip_hold_layout(profile, &"hand_right", 0.01, 1.0, spans)
	assert(bool(layout.get("valid", false)), "initial equipment layout fits the prepared right hand on 100 mm")
	_assert_close(float(layout.dominant_hand_axis_ratio_from_span_start), 0.472629144,
		"initial layout converts saved coordinate units to physical meters before clamping")
	_assert_close((layout.dominant_hand_local_position as Vector3).x * 0.01, TEST_END_CLEARANCE_METERS,
		"initial anchor sits on the authoritative sampled path at the physical end clearance")
	var missing_layout: Dictionary = presenter.resolve_grip_hold_layout(profile, &"hand_right", 0.01, 1.0)
	assert(not bool(missing_layout.get("valid", false)), "initial layout cannot omit character measurements")
	var short_layout: Dictionary = presenter.resolve_grip_hold_layout(profile, &"hand_right", 0.009, 1.0, spans)
	assert(not bool(short_layout.get("valid", false)), "unit conversion reveals a handle shorter than the hand footprint")
	profile.primary_grip_two_hand_eligible = true
	profile.primary_grip_far_side_position = profile.primary_grip_span_end
	layout = presenter.resolve_grip_hold_layout(profile, &"hand_right", 0.1, 1.0, spans)
	assert(bool(layout.get("valid", false)) and bool(layout.get("two_hand_character_eligible", false)),
		"initial two-hand layout remains available when both hands fit")
	_assert_close(float(layout.dominant_hand_axis_ratio_from_span_start), TEST_END_CLEARANCE_METERS,
		"initial two-hand main endpoint uses the right hand")
	_assert_close(float(layout.support_hand_axis_ratio_from_span_start), 0.94,
		"initial two-hand support endpoint uses the larger left hand")
	layout = presenter.resolve_grip_hold_layout(profile, &"hand_left", 0.1, 1.0, spans)
	_assert_close(float(layout.dominant_hand_axis_ratio_from_span_start), 0.06,
		"initial left-primary layout swaps measured roles")
	_assert_close(float(layout.support_hand_axis_ratio_from_span_start), 1.0 - TEST_END_CLEARANCE_METERS,
		"initial left-primary layout retains right support footprint")


func _verify_legacy_station_coordinate_migration(
	balanced_mode: StringName
) -> void:
	var legacy_node := CombatAnimationMotionNodeScript.new()
	legacy_node.grip_seat_slide_offset = -0.4
	legacy_node.secondary_grip_seat_slide_offset = 0.2
	legacy_node.retarget_node = Resource.new()
	var legacy_draft := CombatAnimationDraftScript.new()
	legacy_draft.draft_kind = CombatAnimationDraftScript.DRAFT_KIND_IDLE
	legacy_draft.context_id = CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT
	legacy_draft.motion_node_chain.append(legacy_node)
	legacy_draft.baked_runtime_clip = Resource.new()
	legacy_draft.runtime_cache_signature = "legacy_coordinate_cache"
	var legacy_station := CombatAnimationStationStateScript.new()
	assert(
		legacy_station.station_version
		== CombatAnimationStationStateScript
		.SKILL_BASELINE_DESTRUCTIVE_RESET_VERSION,
		"an omitted legacy station_version loads as the last shipped schema"
	)
	legacy_station.idle_drafts.append(legacy_draft)
	legacy_station.normalize()
	assert(
		legacy_node.grip_seat_coordinate_schema_version
		== CombatAnimationMotionNodeScript
		.GRIP_SEAT_COORDINATE_SCHEMA_LEGACY_DISPLAY_VALUE,
		"station v3 marks persisted UI values for deliberate migration"
	)
	_assert_close(
		legacy_node.grip_seat_slide_offset,
		-0.4,
		"station normalization preserves legacy primary display value"
	)
	_assert_close(
		legacy_node.secondary_grip_seat_slide_offset,
		0.2,
		"station normalization preserves legacy support display value"
	)
	var balanced_profile := BakedProfileScript.new()
	balanced_profile.primary_grip_handle_coordinate_mode = balanced_mode
	var owning_wip := CraftedItemWIPScript.new()
	owning_wip.combat_animation_station_state = legacy_station
	owning_wip.latest_baked_profile_snapshot = balanced_profile
	owning_wip.ensure_combat_animation_station_state()
	_assert_close(
		legacy_node.grip_seat_slide_offset,
		0.3,
		"balanced legacy -0.4 becomes canonical Handle 0.3"
	)
	_assert_close(
		legacy_node.secondary_grip_seat_slide_offset,
		0.6,
		"balanced legacy +0.2 becomes canonical Handle 0.6"
	)
	assert(
		legacy_node.grip_seat_coordinate_schema_version
		== CombatAnimationMotionNodeScript
		.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE,
		"runtime WIP load promotes the node to canonical Handle coordinates"
	)
	assert(
		legacy_node.retarget_node == null,
		"legacy retarget projection is discarded for canonical regeneration"
	)
	assert(
		legacy_draft.baked_runtime_clip == null
		and legacy_draft.runtime_cache_signature.is_empty(),
		"legacy coordinate migration invalidates only the derived runtime cache"
	)
	assert(
		not PrimaryGripSeatResolverScript.migrate_legacy_display_coordinates(
			legacy_node,
			balanced_mode
		),
		"canonical Handle positions are never migrated twice"
	)


func _assert_close(actual: float, expected: float, label: String) -> void:
	assert(
		is_equal_approx(actual, expected),
		"%s: expected %.6f, got %.6f" % [label, expected, actual]
	)
