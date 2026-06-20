extends RefCounted
class_name CombatOriginRegistry

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const MAX_CHAIN_DEPTH := 64

var _records: Dictionary = {}

func _init(register_machine_origin: bool = true) -> void:
	if register_machine_origin:
		register_origin(_make_record(
			CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
			StringName(),
			Transform3D.IDENTITY,
			CombatOriginRecordScript.OWNER_SYSTEM_COMBAT_ORIGIN_REGISTRY,
			CombatOriginRecordScript.PHASE_POST_FINAL_POSE,
			CombatOriginRecordScript.SPACE_TYPE_MACHINE,
			true
		))

func clear() -> void:
	_records.clear()

func register_origin(origin_record: Resource) -> bool:
	if origin_record == null:
		return false
	var record = origin_record.duplicate_record()
	if record == null:
		return false
	record.normalize()
	if not record.is_valid_record():
		return false
	_records[record.origin_id] = record
	record.resolved_transform_to_machine = resolve_transform_to_machine(record.origin_id)
	_records[record.origin_id] = record
	return true

func register_default_combat_origins(owner_system: StringName = CombatOriginRecordScript.OWNER_SYSTEM_COMBAT_ORIGIN_REGISTRY) -> void:
	if not has_origin(CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT):
		register_origin(_make_record(
			CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
			StringName(),
			Transform3D.IDENTITY,
			owner_system,
			CombatOriginRecordScript.PHASE_POST_FINAL_POSE,
			CombatOriginRecordScript.SPACE_TYPE_MACHINE,
			true
		))
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_BAKE_TIME,
		CombatOriginRecordScript.SPACE_TYPE_TRAJECTORY,
		false
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_LOCOMOTION,
		CombatOriginRecordScript.SPACE_TYPE_BONE_FRAME,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_LOCOMOTION,
		CombatOriginRecordScript.SPACE_TYPE_WEAPON,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_ANCHOR,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_LOCOMOTION,
		CombatOriginRecordScript.SPACE_TYPE_ANCHOR,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_ANCHOR,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_LOCOMOTION,
		CombatOriginRecordScript.SPACE_TYPE_ANCHOR,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_FINAL_POSE,
		CombatOriginRecordScript.SPACE_TYPE_HAND_ALIGNMENT,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_EDITOR_PREVIEW,
		CombatOriginRecordScript.SPACE_TYPE_SHOULDER,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_BRIDGE_START,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_RUNTIME_BRIDGE,
		CombatOriginRecordScript.SPACE_TYPE_BRIDGE,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_BRIDGE_TARGET,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_RUNTIME_BRIDGE,
		CombatOriginRecordScript.SPACE_TYPE_BRIDGE,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_COMBAT_IDLE,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_BAKE_TIME,
		CombatOriginRecordScript.SPACE_TYPE_IDLE,
		false
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_RUNTIME_STOW,
		CombatOriginRecordScript.SPACE_TYPE_STOW,
		false
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_STOW_ANCHOR,
		CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW,
		owner_system,
		CombatOriginRecordScript.PHASE_RUNTIME_STOW,
		CombatOriginRecordScript.SPACE_TYPE_STOW,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_BODY_RESTRICTION_ATTACHMENT,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_FINAL_POSE,
		CombatOriginRecordScript.SPACE_TYPE_COLLISION,
		true
	)
	_register_identity_child(
		CombatOriginRecordScript.ORIGIN_RUNTIME_ENDPOINT_AUTHORITY_ROOT,
		CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
		owner_system,
		CombatOriginRecordScript.PHASE_POST_FINAL_POSE,
		CombatOriginRecordScript.SPACE_TYPE_PRESENTATION,
		true
	)
	_refresh_resolved_transforms()

func has_origin(origin_id: StringName) -> bool:
	return _records.has(origin_id)

func get_origin(origin_id: StringName):
	return _records.get(origin_id, null)

func get_origin_ids() -> Array:
	var ids: Array = _records.keys()
	ids.sort()
	return ids

func get_origin_count() -> int:
	return _records.size()

func resolve_chain(origin_id: StringName) -> Array:
	var validation: Dictionary = validate_origin_chain(origin_id)
	if not bool(validation.get("ok", false)):
		return []
	var chain: Array = []
	for chain_origin_id in validation.get("chain_ids", []):
		var record = get_origin(chain_origin_id as StringName)
		if record != null:
			chain.append(record)
	return chain

func resolve_transform_to_machine(origin_id: StringName) -> Transform3D:
	var chain: Array = resolve_chain(origin_id)
	if chain.is_empty():
		return Transform3D.IDENTITY
	var machine_to_origin := Transform3D.IDENTITY
	chain.reverse()
	for record in chain:
		var origin_record = record
		if origin_record == null or origin_record.is_machine_origin():
			continue
		machine_to_origin = machine_to_origin * origin_record.transform_to_parent
	return machine_to_origin

func validate_all() -> Dictionary:
	var failures: Array = []
	var validations: Array = []
	for origin_id in get_origin_ids():
		var validation := validate_origin_chain(origin_id as StringName)
		validations.append(validation)
		if not bool(validation.get("ok", false)):
			failures.append(validation)
	return {
		"ok": failures.is_empty(),
		"origin_count": get_origin_count(),
		"failures": failures,
		"validations": validations,
	}

func validate_origin_chain(origin_id: StringName) -> Dictionary:
	var result := {
		"ok": false,
		"origin_id": origin_id,
		"chain_ids": [],
		"reason": &"",
		"missing_origin_id": &"",
		"cycle_origin_id": &"",
	}
	if origin_id == StringName():
		result["reason"] = &"missing_origin_id"
		return result
	if not has_origin(origin_id):
		result["reason"] = &"unregistered_origin"
		result["missing_origin_id"] = origin_id
		return result
	var visited := {}
	var current_origin_id := origin_id
	for depth_index in range(MAX_CHAIN_DEPTH):
		if visited.has(current_origin_id):
			result["reason"] = &"cycle_detected"
			result["cycle_origin_id"] = current_origin_id
			return result
		visited[current_origin_id] = true
		var record = get_origin(current_origin_id)
		if record == null:
			result["reason"] = &"unregistered_parent_origin"
			result["missing_origin_id"] = current_origin_id
			return result
		(result["chain_ids"] as Array).append(record.origin_id)
		if record.is_machine_origin():
			result["ok"] = true
			result["reason"] = &"ok"
			return result
		if record.parent_origin_id == StringName():
			result["reason"] = &"missing_parent_origin_id"
			result["missing_origin_id"] = record.origin_id
			return result
		current_origin_id = record.parent_origin_id
	result["reason"] = &"chain_depth_exceeded"
	return result

func describe_origin_chain(origin_id: StringName) -> String:
	var validation := validate_origin_chain(origin_id)
	var chain_ids: Array = validation.get("chain_ids", [])
	var chain_labels: PackedStringArray = []
	for chain_origin_id in chain_ids:
		chain_labels.append(String(chain_origin_id))
	var record = get_origin(origin_id)
	var record_text = record.describe() if record != null else "missing"
	if not bool(validation.get("ok", false)):
		return "%s INVALID chain=%s reason=%s record=%s" % [
			String(origin_id),
			" -> ".join(chain_labels),
			String(validation.get("reason", &"")),
			record_text,
		]
	return "%s chain=%s record=%s" % [
		String(origin_id),
		" -> ".join(chain_labels),
		record_text,
	]

func build_debug_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for origin_id in get_origin_ids():
		lines.append(describe_origin_chain(origin_id as StringName))
	return lines

func _register_identity_child(
	origin_id: StringName,
	parent_origin_id: StringName,
	owner_system: StringName,
	resolve_phase: StringName,
	space_type: StringName,
	is_dynamic: bool
) -> void:
	register_origin(_make_record(
		origin_id,
		parent_origin_id,
		Transform3D.IDENTITY,
		owner_system,
		resolve_phase,
		space_type,
		is_dynamic
	))

func _refresh_resolved_transforms() -> void:
	for origin_id in get_origin_ids():
		var record = get_origin(origin_id as StringName)
		if record == null:
			continue
		record.resolved_transform_to_machine = resolve_transform_to_machine(record.origin_id)

func _make_record(
	origin_id: StringName,
	parent_origin_id: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT,
	transform_to_parent: Transform3D = Transform3D.IDENTITY,
	owner_system: StringName = CombatOriginRecordScript.OWNER_SYSTEM_COMBAT_ORIGIN_REGISTRY,
	resolve_phase: StringName = CombatOriginRecordScript.PHASE_UNKNOWN,
	space_type: StringName = CombatOriginRecordScript.SPACE_TYPE_UNKNOWN,
	is_dynamic: bool = false
) -> Resource:
	var record = CombatOriginRecordScript.new()
	record.origin_id = origin_id
	record.parent_origin_id = parent_origin_id
	record.transform_to_parent = transform_to_parent
	record.owner_system = owner_system
	record.resolve_phase = resolve_phase
	record.space_type = space_type
	record.is_dynamic = is_dynamic
	record.normalize()
	return record
