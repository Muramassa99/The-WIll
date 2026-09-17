extends SceneTree

const ResolverScript = preload("res://core/resolvers/combat_weapon_roll_resolver.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")
const RegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")
const TOLERANCE: float = 0.00003

var checks: int = 0
var failures: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _run() -> void:
	# The independent expected orbit is a circle in world XY about the +Z axis.
	# Nonidentity machine/hand/weapon bases expose lost scale and frame confusion.
	var wrist_world := Vector3(3.0, -2.0, 7.0)
	var tip_world := wrist_world + Vector3(0.0, 0.0, 2.0)
	var pommel_world := wrist_world + Vector3(0.3, 0.0, -0.5)
	var hand_world := Transform3D(
		Basis.from_euler(Vector3(0.27, -0.19, 0.53)).scaled(Vector3(0.71, 0.89, 1.12)), wrist_world
	)
	var weapon_world := Transform3D(
		Basis.from_euler(Vector3(-0.41, 0.33, -0.22)).scaled(Vector3(0.64, 0.81, 1.2)),
		wrist_world + Vector3(0.25, 0.12, -0.17)
	)
	var weapon_tip_origin_id: StringName = OriginScript.ORIGIN_WEAPON_ROOT
	var weapon_tip_local: Vector3 = weapon_world.affine_inverse() * tip_world
	var weapon_pommel_origin_id: StringName = weapon_tip_origin_id
	var weapon_pommel_local: Vector3 = weapon_world.affine_inverse() * pommel_world
	var original_grip: Transform3D = hand_world.affine_inverse() * weapon_world
	for wrist_id: StringName in [OriginScript.ORIGIN_RIGHT_WRIST, OriginScript.ORIGIN_LEFT_WRIST]:
		var captured: Dictionary = _capture_fixture(wrist_id, hand_world)
		var source_record = captured["origin_record"]
		var source_transform: Transform3D = source_record.transform_to_parent
		var results: Dictionary = {}
		for requested: float in [25.0, 115.0, -65.0, 385.0, -155.0, 73.0, -11.0, 73.0, 25.0]:
			var label: String = "%s requested=%s" % [wrist_id, requested]
			var result: Dictionary = ResolverScript.resolve(captured, weapon_world, weapon_tip_local, weapon_tip_origin_id, 25.0, requested)
			_check(bool(result.get("available", false)), label + " available: " + str(result.get("reason")))
			if not bool(result.get("available", false)):
				continue
			var output_hand: Transform3D = result["hand_transform_world"]
			var output_weapon: Transform3D = result["weapon_transform_world"]
			_check(output_hand.origin.distance_to(wrist_world) <= TOLERANCE, label + " fixed wrist")
			_check((output_weapon * weapon_tip_local).distance_to(tip_world) <= TOLERANCE, label + " fixed Tip")
			_check(_transform_close(output_hand.affine_inverse() * output_weapon, original_grip), label + " rigid hand/weapon relationship")
			_check(_basis_close(output_hand.basis.transposed() * output_hand.basis, hand_world.basis.transposed() * hand_world.basis), label + " hand scale/shear retained")
			_check(_basis_close(output_weapon.basis.transposed() * output_weapon.basis, weapon_world.basis.transposed() * weapon_world.basis), label + " weapon scale/shear retained")
			var angle: float = deg_to_rad(requested - 25.0)
			var expected_pommel := wrist_world + Vector3(0.3 * cos(angle), 0.3 * sin(angle), -0.5)
			var actual_pommel: Vector3 = output_weapon * weapon_pommel_local
			_check(weapon_pommel_origin_id == result["weapon_origin_id"] and actual_pommel.distance_to(expected_pommel) <= TOLERANCE, label + " analytic signed Pommel orbit")
			var pommel_offset: Vector3 = actual_pommel - wrist_world
			_check(absf(Vector2(pommel_offset.x, pommel_offset.y).length() - 0.3) <= TOLERANCE, label + " constant orbit radius")
			_check(absf(pommel_offset.z + 0.5) <= TOLERANCE, label + " constant axis projection")
			if requested == 25.0:
				_check(_transform_close(output_weapon, weapon_world) and _transform_close(output_hand, hand_world), label + " zero delta restores baseline")
			if results.has(requested):
				_check(_transform_close(output_weapon, results[requested]["weapon_transform_world"]) and _transform_close(output_hand, results[requested]["hand_transform_world"]), label + " repeated angle / A-B-A")
			results[requested] = result
			var output_registry = result["registry"]
			_check(output_registry != captured["registry"], label + " separate output registry")
			for origin_id: StringName in [wrist_id, weapon_tip_origin_id]:
				_check(bool(output_registry.validate_origin_chain(origin_id).get("ok", false)), label + " valid output chain " + String(origin_id))
				var record = output_registry.get_origin(origin_id)
				_check(record.resolve_phase == OriginScript.PHASE_EDITOR_PREVIEW and record.owner_system == &"combat_weapon_roll_resolver", label + " output phase/owner " + String(origin_id))
				var reconstructed: Transform3D = result["machine_to_world"] * output_registry.resolve_transform_to_machine(origin_id)
				_check(_transform_close(reconstructed, output_hand if origin_id == wrist_id else output_weapon), label + " full output registry round trip " + String(origin_id))
			_check(source_record.transform_to_parent == source_transform and source_record.resolve_phase == OriginScript.PHASE_POST_FINAL_POSE, label + " immutable source wrist")
			_check(captured["registry"].get_origin_count() == 2 and not captured["registry"].has_origin(weapon_tip_origin_id), label + " immutable source registry")
	var capture: Dictionary = _capture_fixture(OriginScript.ORIGIN_RIGHT_WRIST, hand_world)
	_expect_rejected({}, weapon_world, weapon_tip_local, weapon_tip_origin_id, 0.0, 15.0, "missing capture")
	_expect_rejected(capture, weapon_world, weapon_tip_local, &"", 0.0, 15.0, "missing Tip origin")
	_expect_rejected(capture, weapon_world, weapon_tip_local, OriginScript.ORIGIN_TRAJECTORY_AUTHORING, 0.0, 15.0, "wrong Tip origin")
	_expect_rejected(capture, weapon_world, weapon_world.affine_inverse() * wrist_world, weapon_tip_origin_id, 0.0, 15.0, "degenerate wrist-Tip axis")
	_expect_rejected(capture, weapon_world, Vector3(NAN, 0.0, 0.0), weapon_tip_origin_id, 0.0, 15.0, "NaN Tip")
	_expect_rejected(capture, weapon_world, weapon_tip_local, weapon_tip_origin_id, NAN, 15.0, "NaN baseline")
	_expect_rejected(capture, weapon_world, weapon_tip_local, weapon_tip_origin_id, 0.0, NAN, "NaN request")
	_expect_rejected(capture, weapon_world, weapon_tip_local, weapon_tip_origin_id, 0.0, INF, "infinite request")
	var singular_weapon := Transform3D(Basis.from_scale(Vector3(0.0, 1.0, 1.0)), weapon_world.origin)
	_expect_rejected(capture, singular_weapon, weapon_tip_local, weapon_tip_origin_id, 0.0, 15.0, "singular weapon")
	for failure_kind: String in ["missing_registry", "missing_root", "unknown_wrist", "wrong_phase", "stale_transform", "singular_machine", "nan_machine"]:
		var invalid: Dictionary = _capture_fixture(OriginScript.ORIGIN_RIGHT_WRIST, hand_world)
		match failure_kind:
			"missing_registry": invalid.erase("registry")
			"missing_root": invalid["registry"].clear()
			"unknown_wrist": invalid["wrist_origin_id"] = &"UnknownWristOrigin"
			"wrong_phase": invalid["origin_record"].resolve_phase = OriginScript.PHASE_EDITOR_PREVIEW
			"stale_transform": invalid["origin_record"].transform_to_parent.origin.x += 1.0
			"singular_machine": invalid["machine_to_world"] = Transform3D(Basis.from_scale(Vector3(0.0, 1.0, 1.0)), wrist_world)
			"nan_machine": invalid["machine_to_world"] = Transform3D(Basis(), Vector3(NAN, 0.0, 0.0))
		_expect_rejected(invalid, weapon_world, weapon_tip_local, weapon_tip_origin_id, 0.0, 15.0, failure_kind)
	print("COMBAT_WEAPON_ROLL_RESULT=" + JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _capture_fixture(wrist_id: StringName, hand_world: Transform3D) -> Dictionary:
	var machine_to_world := Transform3D(
		Basis.from_euler(Vector3(-0.27, 0.61, 0.17)).scaled(Vector3(0.764, 0.91, 1.08)),
		Vector3(4.0, -2.0, 7.0)
	)
	var registry = RegistryScript.new()
	var record = OriginScript.new()
	record.origin_id = wrist_id
	record.parent_origin_id = OriginScript.ORIGIN_RL_BONE_ROOT
	record.transform_to_parent = machine_to_world.affine_inverse() * hand_world
	record.resolve_phase = OriginScript.PHASE_POST_FINAL_POSE
	record.owner_system = &"player_humanoid_rig"
	record.space_type = OriginScript.SPACE_TYPE_BONE_FRAME
	record.is_dynamic = true
	registry.register_origin(record)
	return {
		"available": true,
		"reason": &"ok",
		"wrist_origin_id": wrist_id,
		"hand_bone_name": &"CC_Base_R_Hand" if wrist_id == OriginScript.ORIGIN_RIGHT_WRIST else &"CC_Base_L_Hand",
		"origin_record": registry.get_origin(wrist_id),
		"origin_chain": registry.resolve_chain(wrist_id),
		"origin_chain_ids": registry.validate_origin_chain(wrist_id)["chain_ids"],
		"registry": registry,
		"machine_to_world": machine_to_world,
	}

func _expect_rejected(capture: Dictionary, weapon: Transform3D, tip: Vector3, origin_id: StringName, baseline: float, requested: float, label: String) -> void:
	var result: Dictionary = ResolverScript.resolve(capture, weapon, tip, origin_id, baseline, requested)
	_check(not bool(result.get("available", false)), label + " rejected")
	_check(result.has("reason") and not result.has("weapon_transform_world") and not result.has("hand_transform_world"), label + " no fallback transforms")

func _basis_close(a: Basis, b: Basis) -> bool:
	return a.x.distance_to(b.x) <= TOLERANCE and a.y.distance_to(b.y) <= TOLERANCE and a.z.distance_to(b.z) <= TOLERANCE

func _transform_close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) <= TOLERANCE and _basis_close(a.basis, b.basis)
