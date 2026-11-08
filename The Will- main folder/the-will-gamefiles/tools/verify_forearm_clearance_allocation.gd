extends SceneTree

const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var slide := _move(Vector2(-0.005, 0.0), Vector2(0.025, 0.04))
	_expect(bool(slide.get("valid", false)), "diagonal contact remains movable")
	var actual := Vector2(slide.accepted_q[0], slide.accepted_q[1])
	_expect(actual.x <= 0.000001, "capsule boundary prevents inward movement")
	_expect(actual.y > 0.003, "contact preserves tangential progress")
	_expect(bool(slide.get("clearance_slide", false)), "contact-guided response is explicit")
	var outside := _move(Vector2(0.02, 0.0), Vector2(-0.02, 0.0))
	_expect(bool(outside.get("valid", false)) and outside.accepted_q[0] < 0.0, "intersecting start can escape immediately")
	var start := Vector2(0.02, 0.0)
	for index: int in 5:
		var recovery := _move(start, start + Vector2(0.01, 0.01))
		var reached := Vector2(recovery.accepted_q[0], recovery.accepted_q[1])
		_expect(reached.x <= start.x + 0.0000001, "repeat cannot grant deeper penetration " + str(index))
		_expect(reached.y > start.y, "existing overlap retains sideways correction " + str(index))
		start = reached
	var head_on := _move(Vector2.ZERO, Vector2(0.03, 0.0))
	_expect(float(head_on.accepted_q[0]) <= 0.000001, "direct inward demand stays outside")
	var ordinary := _move(Vector2(-0.06, 0.0), Vector2(-0.03, 0.02))
	_expect(bool(ordinary.valid) and not bool(ordinary.get("clearance_slide", false)), "clear motion retains exact task route")
	var physical_start := {"q": PackedFloat64Array([0.02]), "lower": PackedFloat64Array([-1.0]), "upper": PackedFloat64Array([1.0])}
	var physical := {"constraints": PackedFloat64Array([2.0]), "constraint_reasons": PackedStringArray(["FOREARM_CLEARANCE:arm:chest"]), "constraint_tolerances": PackedFloat64Array([0.005])}
	var allowance := Allocator.build_start_allowance(physical_start, physical)
	var at_start := Allocator.apply_start_allowance(physical, allowance)
	_expect(Allocator._legal(physical_start.q, at_start, physical_start.lower, physical_start.upper), "physical slop accepts exact inherited deep start despite subtraction rounding")
	var deeper := physical.duplicate(true)
	deeper.constraints = PackedFloat64Array([2.001])
	_expect(not Allocator._legal(physical_start.q, Allocator.apply_start_allowance(deeper, allowance), physical_start.lower, physical_start.upper), "surface tolerance is not an additional deep-overlap budget")
	var next := Allocator.build_start_allowance(physical_start, physical)
	_expect(next.offsets == allowance.offsets, "unchanged starting penetration has unchanged allowance")
	var coupled := _coupled_pose_move(true)
	_expect(bool(coupled.get("valid", false)) and bool(coupled.get("clearance_slide", false)), "coupled pose uses explicit contact slide")
	var coupled_q := PackedFloat64Array(coupled.get("accepted_q", []))
	_expect(coupled_q.size() == 3 and coupled_q[1] > 0.02, "coupled pose retains useful reachable translation")
	_expect(coupled_q.size() == 3 and coupled_q[0] <= 0.000001 and absf(coupled_q[2]) <= 0.050001, "coupled slide preserves clearance and angular bound")
	_expect(float(coupled.get("orientation_error", INF)) <= deg_to_rad(0.025), "coupled slide preserves original commanded orientation")
	var constant := _coupled_pose_move(false)
	_expect(not bool(constant.get("clearance_slide", false)), "constant unrelated clearance row cannot enable a slide")
	print(JSON.stringify({"checks": checks, "failures": failures, "slide": _summary(slide), "head_on": _summary(head_on),
		"coupled": _summary(coupled), "coupled_slide_attempts": coupled.get("clearance_slide_attempts", [])}))
	quit(0 if failures.is_empty() else 1)

func _move(from: Vector2, target: Vector2) -> Dictionary:
	return Allocator.solve({"q": PackedFloat64Array([from.x, from.y]),
		"lower": PackedFloat64Array([-1.0, -1.0]), "upper": PackedFloat64Array([1.0, 1.0]),
		"joint_groups": PackedStringArray(["elbow", "shoulder"]), "origin_id": "test_root",
		"mode": "position", "contact_local": Vector3.ZERO,
		"previous_weapon": Transform3D(Basis.IDENTITY, Vector3(from.x, from.y, 0.0)),
		"target_weapon": Transform3D(Basis.IDENTITY, Vector3(target.x, target.y, 0.0)),
		"allow_forearm_slide": true}, _evaluate)

func _evaluate(q: PackedFloat64Array) -> Dictionary:
	return {"valid": true, "weapon_frame": Transform3D(Basis.IDENTITY, Vector3(q[0], q[1], 0.0)),
		"constraints": PackedFloat64Array([q[0] / 0.01]),
		"constraint_reasons": PackedStringArray(["FOREARM_CLEARANCE:forearm_right:chest"]), "payload": {}}

func _coupled_pose_move(moving_clearance: bool) -> Dictionary:
	var evaluator := func(q: PackedFloat64Array) -> Dictionary:
		return {"valid": true,
			"weapon_frame": Transform3D(Basis(Vector3.BACK, q[2] + 2.0 * q[1]), Vector3(q[0], q[1], 0.0)),
			"constraints": PackedFloat64Array([q[0] / 0.01 if moving_clearance else 0.0]),
			"constraint_reasons": PackedStringArray(["FOREARM_CLEARANCE:forearm_right:chest"]), "payload": {}}
	return Allocator.solve({"q": PackedFloat64Array([-0.005, 0.0, 0.0]),
		"lower": PackedFloat64Array([-1.0, -1.0, -0.05]), "upper": PackedFloat64Array([1.0, 1.0, 0.05]),
		"joint_groups": PackedStringArray(["elbow", "shoulder", "forearm"]), "origin_id": "test_root",
		"mode": "pommel", "contact_local": Vector3.ZERO,
		"previous_weapon": Transform3D(Basis.IDENTITY, Vector3(-0.005, 0.0, 0.0)),
		"target_weapon": Transform3D(Basis.IDENTITY, Vector3(0.025, 0.04, 0.0)),
		"allow_forearm_slide": true}, evaluator, {"max_translation_step": 0.1})

func _summary(result: Dictionary) -> Dictionary:
	return {"status": result.status, "reason": result.reason, "q": Array(result.accepted_q), "scale": result.task_scale}

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
