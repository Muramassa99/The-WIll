extends RefCounted

## Called by an existing live-UI diagnostic; does not reset, solve, or save.
## The production seed resolver briefly updates the trajectory frame. Restore
## that frame before returning, and leave the authored motion/cache untouched.
const FrameSolver = preload("res://runtime/combat/combat_animation_weapon_frame_solver.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

static func capture(ui, fallback_override: Dictionary = {}, label: String = "") -> Dictionary:
	var presenter = ui.preview_presenter
	var context: Dictionary = presenter._weapon_roll_context(ui.preview_subviewport)
	if context.is_empty():
		return {"available": false, "reason": "missing_preview", "label": label}
	var actor: Node3D = context.actor
	var weapon: Node3D = context.weapon
	var trajectory: Node3D = context.trajectory
	if presenter._is_unarmed_preview_item(weapon):
		return {"available": false, "reason": "handheld_weapon_only", "label": label}
	# Reject missing origins instead of allowing the mount reader to fill them.
	for key: String in ["weapon_tip_origin_id", "weapon_pommel_origin_id", "primary_grip_contact_origin_id"]:
		if not weapon.has_meta(key) or weapon.get_meta(key) != Origins.ORIGIN_WEAPON_ROOT:
			return {"available": false, "reason": "missing_or_wrong_weapon_origin", "key": key, "label": label}
	var tip_value: Variant = weapon.get_meta("weapon_tip_local", null)
	var pommel_value: Variant = weapon.get_meta("weapon_pommel_local", null)
	if not tip_value is Vector3 or not pommel_value is Vector3:
		return {"available": false, "reason": "missing_weapon_endpoints", "label": label}
	var local_tip: Vector3 = tip_value
	var local_pommel: Vector3 = pommel_value
	if local_tip.distance_squared_to(local_pommel) <= 0.00000001:
		return {"available": false, "reason": "degenerate_weapon_axis", "label": label}
	var fallback: Dictionary = fallback_override.duplicate(true)
	if fallback.is_empty():
		fallback = ui._resolve_active_weapon_geometry_seed_base()
	if fallback.is_empty():
		return {"available": false, "reason": "missing_geometry_seed", "label": label}
	var slot: StringName = presenter._resolve_preview_dominant_slot_id()
	var style: StringName = StringName(fallback.get("preferred_grip_style_mode", weapon.get_meta("grip_style_mode", &"grip_normal")))
	var style_state: Dictionary = presenter.equipped_item_presenter.resolve_held_item_grip_style_state(weapon, actor, slot, style)
	var station: Vector3 = presenter._resolve_primary_grip_seat_local_from_offsets(
		weapon, float(fallback.get("grip_seat_slide_offset", 0.0)), float(fallback.get("axial_reposition_offset", 0.0)))
	var intended: Transform3D = presenter._resolve_preview_hand_mounted_transform(
		actor, weapon, station, style_state.get("hand_mount_local_transform", null))
	var before_trajectory: Transform3D = trajectory.global_transform
	var before_weapon: Transform3D = weapon.global_transform
	var wip: Resource = ui.active_wip
	var expected_wip: StringName = StringName(wip.get("wip_id")) if wip != null else &""
	var returned: Dictionary = presenter.resolve_preview_hand_mounted_motion_seed(ui.preview_subviewport, fallback, expected_wip)
	var seed_trajectory: Transform3D = trajectory.global_transform
	trajectory.global_transform = before_trajectory
	if not bool(returned.get("hand_mount_seed_resolved", false)):
		return {"available": false, "reason": "production_seed_unresolved", "label": label}
	var local_up: Vector3 = presenter._resolve_weapon_local_up_reference(weapon, (local_tip - local_pommel).normalized())
	var solver = FrameSolver.new()
	var decoded: Transform3D = _decode(solver, returned, local_tip, local_pommel, local_up, seed_trajectory)
	# Keep the same scalar roll in this control. Its orientation is an inverse
	# representation of the mounted frame, not a proposed new facing policy.
	var roll: float = float(returned.get("weapon_roll_degrees", 0.0))
	var encoded: Dictionary = solver.encode_transform_for_authoring(intended, local_tip, local_pommel, local_up, seed_trajectory, roll)
	var control: Dictionary = {"available": bool(encoded.get("available", false)), "reason": encoded.get("reason", "")}
	if bool(encoded.get("available", false)):
		control["same_roll_degrees"] = float(encoded.weapon_roll_degrees)
		control["seed"] = _seed(encoded)
		control["error_vs_intended"] = _errors(_decode(solver, encoded, local_tip, local_pommel, local_up, seed_trajectory), intended, local_tip, local_pommel, station)
	var selected: Resource = ui._get_active_motion_node()
	var selected_authored: Dictionary = {}
	if selected != null:
		selected_authored = {"weapon_orientation_authored": selected.get("weapon_orientation_authored"),
			"weapon_orientation_degrees": _vector(selected.get("weapon_orientation_degrees")),
			"weapon_roll_degrees": selected.get("weapon_roll_degrees"),
			"note": "Observation only; Reset intentionally chooses its baseline seed rather than retaining selected motion edits."}
	var cached: Dictionary = ui.cached_active_weapon_baseline_seed
	return {"available": true, "label": label, "primary_hand": String(slot), "grip_style": String(style),
		"fallback": _seed(fallback), "production_seed": _seed(returned),
		"production_error_vs_intended": _errors(decoded, intended, local_tip, local_pommel, station),
		"same_roll_encoder_control": control,
		"intended_mounted_frame": _frame(intended), "production_reconstructed_frame": _frame(decoded),
		"trajectory_for_seed": _frame(seed_trajectory), "local_up_reference": _vector(local_up),
		"selected_motion_not_baseline": selected_authored,
		"cached_reset_seed": _seed(cached),
		"cached_signature_matches_fallback": ui.cached_active_weapon_baseline_seed_signature == ui._build_active_weapon_baseline_seed_signature(fallback),
		"cache_note": "Cached values are observational; a fresh current-actor mount is not proof of a historical cached actor frame.",
		"trajectory_restored": trajectory.global_transform == before_trajectory,
		"weapon_unchanged": weapon.global_transform == before_weapon}

static func _decode(solver, seed: Dictionary, tip: Vector3, pommel: Vector3, up: Vector3, trajectory: Transform3D) -> Transform3D:
	return solver.solve_transform_from_segment(tip, pommel,
		trajectory * (seed.tip_position_local as Vector3), trajectory * (seed.pommel_position_local as Vector3),
		up, trajectory.basis, seed.get("weapon_orientation_degrees", Vector3.ZERO), float(seed.get("weapon_roll_degrees", 0.0)))

static func _errors(actual: Transform3D, intended: Transform3D, tip: Vector3, pommel: Vector3, station: Vector3) -> Dictionary:
	return {"basis_angle_degrees": rad_to_deg(actual.basis.get_rotation_quaternion().angle_to(intended.basis.get_rotation_quaternion())),
		"origin_mm": actual.origin.distance_to(intended.origin) * 1000.0,
		"tip_mm": (actual * tip).distance_to(intended * tip) * 1000.0,
		"pommel_mm": (actual * pommel).distance_to(intended * pommel) * 1000.0,
		"selected_station_mm": (actual * station).distance_to(intended * station) * 1000.0}

static func _seed(seed: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["weapon_orientation_degrees", "weapon_orientation_authored", "weapon_roll_degrees", "tip_position_local", "pommel_position_local", "grip_seat_slide_offset", "axial_reposition_offset", "preferred_grip_style_mode", "hand_mount_seed_resolved"]:
		if seed.has(key):
			result[key] = _vector(seed[key]) if seed[key] is Vector3 else seed[key]
	return result

static func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _frame(value: Transform3D) -> Dictionary:
	return {"origin": _vector(value.origin), "x": _vector(value.basis.x), "y": _vector(value.basis.y), "z": _vector(value.basis.z)}
