extends SceneTree

# Display-only policy checks. No grip acquisition, game launch or save writes.
const PROFILE = preload("res://core/models/baked_profile.gd")
const ADAPTER = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const SEAT = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const ORIGINS = preload("res://core/models/combat_origin_record.gd")
const WIP = preload("res://core/models/crafted_item_wip.gd")
const FORGE_STATE = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const SERVICE = preload("res://services/forge_service.gd")
const MOTION = preload("res://core/models/combat_animation_motion_node.gd")
const DRAFT = preload("res://core/models/combat_animation_draft.gd")
const STATION = preload("res://core/models/combat_animation_station_state.gd")
const PREVIEW = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const SIGNED := PROFILE.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED
const DIRECTIONAL := PROFILE.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
const REPORT := "C:/WORKSPACE/godot_runs/handle_display_mode_classification.json"
const LIBRARY := "user://forge/player_wip_library_state.tres"

var checks: Array[Dictionary] = []
var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for ratio: float in [0.0, 1.0, 0.1, 0.9, 0.5, 0.575059]:
		var profile := _profile(ratio)
		var protected_before := _protected_values(profile)
		ADAPTER.refresh_handle_coordinate_display_mode(profile)
		_check(profile.primary_grip_handle_coordinate_mode == SIGNED, "COM %.6f inside Handle selects signed display" % ratio)
		_check(profile.primary_grip_handle_zero_axis_ratio_from_span_start == 0.5
			and profile.primary_grip_handle_zero_position == Vector3(2.5, 2, 8),
			"COM %.6f display zero uses actual sampled Handle midpoint" % ratio)
		_check(_protected_values(profile) == protected_before,
			"COM %.6f display selection preserves balance/layout, COM, tip and grip fields" % ratio)
	for ratio: float in [-0.01, 1.01]:
		var profile := _profile(ratio)
		profile.primary_grip_handle_coordinate_mode = SIGNED
		var protected_before := _protected_values(profile)
		ADAPTER.refresh_handle_coordinate_display_mode(profile)
		_check(profile.primary_grip_handle_coordinate_mode == DIRECTIONAL
			and profile.primary_grip_handle_zero_position == profile.primary_grip_far_side_position
			and profile.primary_grip_handle_zero_axis_ratio_from_span_start == 1.0 - profile.primary_grip_handle_tip_side_axis_ratio_from_span_start,
			"COM %.2f outside Handle keeps directional zero at the Pommel side" % ratio)
		_check(_protected_values(profile) == protected_before, "outside-span display change preserves physical profile fields")
	_check(SEAT.handle_coordinate_to_display_value(0.0, SIGNED) == -1.0
		and SEAT.handle_coordinate_to_display_value(0.5, SIGNED) == 0.0
		and SEAT.handle_coordinate_to_display_value(1.0, SIGNED) == 1.0,
		"stored normalized coordinates keep -1/0/+1 display mapping")
	_check(SEAT.display_value_to_handle_coordinate(0.0, SIGNED) == 0.5,
		"signed display zero converts back to normalized midpoint")
	_test_end_bound_display_mapping()
	_test_untrusted_profiles()
	_test_cached_clone()
	var glave := {}
	if OS.get_environment("THE_WILL_HANDLE_DISPLAY_INCLUDE_GLAVE") == "1":
		glave = _test_saved_glave()
	var report := {"ok": failures.is_empty(), "checks": checks, "failures": failures, "actual_glave": glave}
	DirAccess.make_dir_recursive_absolute(REPORT.get_base_dir())
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Handle display classification: %d checks, %d failures" % [checks.size(), failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _profile(ratio: float) -> BakedProfile:
	var profile := PROFILE.new()
	profile.primary_grip_valid = true
	profile.primary_grip_authority_source = ADAPTER.GRIP_AUTHORITY_SOURCE
	profile.weapon_intrinsic_center_of_mass_spatial_material_valid = true
	profile.weapon_intrinsic_center_of_mass_authority_source = ADAPTER.WEAPON_INTRINSIC_CENTER_OF_MASS_AUTHORITY_SOURCE
	profile.center_of_mass = Vector3(1, 2, 3 + 10.0 * ratio)
	profile.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped = ratio
	profile.primary_grip_span_start = Vector3(1, 2, 3)
	profile.primary_grip_span_end = Vector3(1, 2, 13)
	profile.primary_grip_slide_axis = Vector3.BACK
	profile.primary_grip_slice_axis_ratios_from_span_start = PackedFloat32Array([0.0, 0.5, 1.0])
	profile.primary_grip_slice_centers = PackedVector3Array([Vector3(1, 2, 3), Vector3(2.5, 2, 8), Vector3(1, 2, 13)])
	profile.primary_grip_slice_centers_origin_id = ORIGINS.ORIGIN_WEAPON_ROOT
	profile.primary_grip_handle_tip_side_axis_ratio_from_span_start = 0.0 if ratio < 0.5 else 1.0
	profile.primary_grip_handle_tip_side_direction = Vector3.FORWARD if ratio < 0.5 else Vector3.BACK
	profile.primary_grip_far_side_position = profile.primary_grip_span_end if ratio < 0.5 else profile.primary_grip_span_start
	profile.primary_grip_com_side_position = profile.primary_grip_span_start if ratio < 0.5 else profile.primary_grip_span_end
	profile.primary_grip_handle_coordinate_mode = DIRECTIONAL
	profile.primary_grip_handle_zero_position = Vector3(-7, -8, -9)
	profile.primary_grip_handle_zero_axis_ratio_from_span_start = 0.0
	# Keep deliberately independent from the display policy under test.
	profile.primary_grip_center_balance_valid = false
	profile.primary_grip_center_balance_offset_percent = absf(ratio - 0.5)
	profile.primary_grip_center_balance_origin = Vector3(7, 8, 9)
	profile.primary_grip_contact_position = Vector3(1.5, 2, 6)
	profile.primary_grip_axis_ratio_from_span_start = 0.3
	profile.primary_grip_contact_percent = 0.3
	profile.weapon_tip_point = Vector3(1, 2, 25)
	profile.weapon_pommel_point = Vector3(1, 2, 1)
	return profile


func _test_end_bound_display_mapping() -> void:
	# Both display conventions retain the same metric hand clearance and
	# physical end stations: directional 10..90 versus signed -80..80.
	var bounds := SEAT.resolve_hand_end_bounds(0.6, 0.1)
	_check(bool(bounds.get("valid", false)) and is_equal_approx(float(bounds.get("min_ratio", -1.0)), 0.1)
		and is_equal_approx(float(bounds.get("max_ratio", -1.0)), 0.9),
		"physical end bounds retain normalized 0.1/0.9 independently of display mode")
	_check(not bool(SEAT.resolve_hand_end_bounds(0.1, 0.1).get("valid", false)),
		"the existing hand footprint still rejects a Handle that is too short")
	var profile := _profile(0.575059)
	for key: String in ["min_ratio", "max_ratio"]:
		var normalized := float(bounds.get(key, -1.0))
		var signed_value := SEAT.handle_coordinate_to_display_value(normalized, SIGNED)
		var restored := SEAT.display_value_to_handle_coordinate(signed_value, SIGNED)
		var original_seat := SEAT.resolve_profile_seat(profile, normalized)
		var restored_seat := SEAT.resolve_profile_seat(profile, restored)
		_check(is_equal_approx(signed_value, -0.8 if key == "min_ratio" else 0.8)
			and is_equal_approx(restored, normalized)
			and bool(original_seat.get("valid", false)) and bool(restored_seat.get("valid", false))
			and (original_seat.get("position", Vector3.ZERO) as Vector3).is_equal_approx(restored_seat.get("position", Vector3.ZERO)),
			"signed %s display round-trips the same physical Handle end station" % key)
	_test_runtime_end_bounds()


func _test_runtime_end_bounds() -> void:
	var held := Node3D.new()
	held.set_meta("primary_grip_span_start_local", Vector3.ZERO)
	held.set_meta("primary_grip_span_end_local", Vector3(0, 0, 0.6))
	held.set_meta("primary_grip_span_start_origin_id", ORIGINS.ORIGIN_WEAPON_ROOT)
	held.set_meta("primary_grip_span_end_origin_id", ORIGINS.ORIGIN_WEAPON_ROOT)
	held.set_meta("hand_grip_spans_meters", {&"hand_right": 0.1})
	held.set_meta("primary_grip_handle_coordinate_mode", SIGNED)
	var presenter := PREVIEW.new()
	var bounds: Dictionary = presenter.get_held_item_hand_end_bounds(held, &"hand_right")
	_check(bool(bounds.get("valid", false)) and is_equal_approx(float(bounds.get("min_ratio", -1.0)), 0.1)
		and is_equal_approx(float(bounds.get("max_ratio", -1.0)), 0.9),
		"runtime signed display retains the existing physical end bounds")
	var playback := {
		"primary_hand_slot": &"hand_right", "two_hand_state": MOTION.TWO_HAND_STATE_ONE_HAND,
		"solved_anchor_node_paths": [&"PrimaryGripAnchor"],
		"solved_anchor_positions_weapon_local": [Vector3(0, 0, 0.045)],
		"solved_weapon_rotation_reference_local": Quaternion.IDENTITY,
		"solved_weapon_scale_reference_local": Vector3.ONE,
	}
	for mode: StringName in [SIGNED, DIRECTIONAL]:
		held.set_meta("primary_grip_handle_coordinate_mode", mode)
		var runtime_bounds: Dictionary = presenter.get_held_item_hand_end_bounds(held, &"hand_right")
		_check(runtime_bounds == bounds, "%s display uses identical runtime physical bounds" % mode)
		playback["solved_anchor_positions_weapon_local"] = [Vector3(0, 0, 0.045)]
		var outside: Dictionary = presenter.validate_solved_replay_hand_end_bounds(held, playback)
		_check(not bool(outside.get("valid", false)) and outside.get("reason") == "saved_grip_outside_handle_end_bounds",
			"%s replay retains the physical end-bound warning at normalized 0.075" % mode)
		for ratio: float in [0.1, 0.9]:
			playback["solved_anchor_positions_weapon_local"] = [Vector3(0, 0, 0.6 * ratio)]
			var accepted: Dictionary = presenter.validate_solved_replay_hand_end_bounds(held, playback)
			_check(bool(accepted.get("valid", false)), "%s replay accepts the same physical end station %.1f" % [mode, ratio])
	held.free()


func _test_untrusted_profiles() -> void:
	var variants: Array[Dictionary] = [
		{"field": "weapon_intrinsic_center_of_mass_spatial_material_valid", "value": false},
		{"field": "weapon_intrinsic_center_of_mass_authority_source", "value": &""},
		{"field": "primary_grip_valid", "value": false},
		{"field": "weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped", "value": NAN},
		{"field": "center_of_mass", "value": Vector3(NAN, 0, 0)},
		{"field": "primary_grip_span_start", "value": Vector3(INF, 0, 0)},
		{"field": "primary_grip_span_end", "value": Vector3(1, 2, 3)},
	]
	for fixture: Dictionary in variants:
		var profile := _profile(0.575059)
		profile.set(fixture.field, fixture.value)
		var before := var_to_bytes(_stored_values(profile))
		ADAPTER.refresh_handle_coordinate_display_mode(profile)
		_check(var_to_bytes(_stored_values(profile)) == before,
			"missing or invalid authority leaves display untouched: " + String(fixture.field))


func _test_cached_clone() -> void:
	var weapon := WIP.new()
	weapon.forge_v2_authoring_state = FORGE_STATE.new()
	weapon.forge_intent = &"intent_melee"
	weapon.equipment_context = &"ctx_weapon"
	weapon.latest_baked_profile_snapshot = _profile(0.575059)
	var draft := DRAFT.new()
	for coordinate: float in [0.2, 0.5, 0.9]:
		var motion := MOTION.new()
		motion.grip_seat_slide_offset = coordinate
		motion.secondary_grip_seat_slide_offset = 1.0 - coordinate
		draft.motion_node_chain.append(motion)
	var station := STATION.new()
	station.skill_drafts.append(draft)
	weapon.combat_animation_station_state = station
	var source := weapon.latest_baked_profile_snapshot
	var profile_before := var_to_bytes(_stored_values(source))
	var nodes_before := _node_grip_values(weapon)
	var service := SERVICE.new()
	var refreshed: BakedProfile = service.get_cached_profile_for_runtime(weapon)
	_check(refreshed != null and refreshed != source and refreshed.primary_grip_handle_coordinate_mode == SIGNED,
		"cached runtime profile refresh updates only a private clone")
	if refreshed != null:
		_check(refreshed.primary_grip_handle_zero_position == Vector3(2.5, 2, 8)
			and refreshed.primary_grip_handle_zero_axis_ratio_from_span_start == 0.5,
			"cached runtime clone uses sampled midpoint zero")
		_check(_protected_values(refreshed) == _protected_values(source),
			"cached display refresh preserves center-balance verdict, tip, COM and grip values")
	_check(var_to_bytes(_stored_values(source)) == profile_before and weapon.latest_baked_profile_snapshot == source,
		"cached refresh leaves the saved source profile unchanged")
	_check(_node_grip_values(weapon) == nodes_before, "display reclassification does not rewrite existing motion-node grip coordinates")


func _test_saved_glave() -> Dictionary:
	var before_hash := FileAccess.get_sha256(LIBRARY)
	var library := ResourceLoader.load(LIBRARY, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as Resource
	var weapon := library.call("get_saved_wip", &"player_wip_1794179018.538_16") as CraftedItemWIP if library != null else null
	if weapon == null or weapon.forge_project_name != "Broken_Glave_v1" or weapon.latest_baked_profile_snapshot == null:
		_check(false, "optional real Glave saved profile exists")
		return {"error": "saved_glave_unavailable"}
	var source := weapon.latest_baked_profile_snapshot
	var source_before := var_to_bytes(_stored_values(source))
	var nodes_before := _node_grip_values(weapon)
	var refreshed: BakedProfile = SERVICE.new().get_cached_profile_for_runtime(weapon)
	var midpoint := SEAT.resolve_profile_seat(source, 0.5)
	var ratio := source.weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped
	_check(ratio >= 0.0 and ratio <= 1.0 and refreshed != null and refreshed.primary_grip_handle_coordinate_mode == SIGNED,
		"actual Glave COM inside Handle selects signed runtime display")
	if refreshed != null:
		_check(bool(midpoint.get("valid", false)) and refreshed.primary_grip_handle_zero_position == midpoint.get("position")
			and refreshed.primary_grip_handle_zero_axis_ratio_from_span_start == 0.5,
			"actual Glave signed zero is the sampled Handle midpoint")
		_check(refreshed.primary_grip_center_balance_valid == source.primary_grip_center_balance_valid
			and refreshed.center_of_mass == source.center_of_mass and refreshed.weapon_tip_point == source.weapon_tip_point,
			"actual Glave display change leaves balance verdict and physical references unchanged")
	_check(var_to_bytes(_stored_values(source)) == source_before and _node_grip_values(weapon) == nodes_before
		and FileAccess.get_sha256(LIBRARY) == before_hash, "actual Glave cached refresh leaves source profile, nodes and disk bytes unchanged")
	return {"com_axis_ratio": ratio, "source_mode": source.primary_grip_handle_coordinate_mode,
		"runtime_mode": refreshed.primary_grip_handle_coordinate_mode if refreshed != null else &"", "source_sha256": before_hash}


func _stored_values(resource: Resource) -> Dictionary:
	var result := {}
	for property: Dictionary in resource.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) != 0 and String(property.name) != "script":
			result[property.name] = resource.get(property.name)
	return result


func _protected_values(profile: BakedProfile) -> Dictionary:
	var result := _stored_values(profile)
	for key: String in ["primary_grip_handle_coordinate_mode", "primary_grip_handle_coordinate_mode_authority_source",
		"primary_grip_handle_zero_axis_ratio_from_span_start", "primary_grip_handle_zero_position", "primary_grip_handle_zero_position_origin_id"]:
		result.erase(key)
	return result


func _node_grip_values(weapon: CraftedItemWIP) -> Array:
	var result := []
	var station := weapon.combat_animation_station_state
	if station != null:
		for draft: Resource in station.get("skill_drafts"):
			if draft != null:
				for motion: Resource in draft.get("motion_node_chain"):
					if motion != null:
						result.append([motion.get("grip_seat_slide_offset"), motion.get("secondary_grip_seat_slide_offset")])
	return result


func _check(passed: bool, label: String) -> void:
	checks.append({"ok": passed, "label": label})
	if not passed:
		failures.append(label)
