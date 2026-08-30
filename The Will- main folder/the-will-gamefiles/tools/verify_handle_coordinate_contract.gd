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


func _init() -> void:
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

	var held_item := _build_test_held_item()
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
		0.0,
		"primary zero is the Pommel end"
	)
	_assert_close(
		float(support_zero.get("ratio", -1.0)),
		0.0,
		"support zero is the same Pommel end"
	)
	var support_one: Dictionary = preview_presenter.call(
		"_resolve_secondary_grip_seat_state_from_offsets",
		held_item,
		1.0
	)
	_assert_close(
		float(support_one.get("ratio", -1.0)),
		1.0,
		"support one is the Tip end"
	)
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
		1.0,
		"reversed primary zero remains the Pommel end"
	)
	_assert_close(
		float(reversed_support_zero.get("ratio", -1.0)),
		1.0,
		"reversed support zero remains the same Pommel end"
	)
	held_item.free()
	print("verify_handle_coordinate_contract: PASS")
	quit(0)


func _build_test_held_item() -> Node3D:
	var held_item := Node3D.new()
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
