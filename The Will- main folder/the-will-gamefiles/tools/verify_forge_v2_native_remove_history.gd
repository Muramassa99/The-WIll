extends SceneTree

# Exact box-volume oracles exercise chronological cutting independently of the
# presenter and its material/voxel accounting. All changes stay in memory.
const RESULT_PATH := "C:/WORKSPACE/test_artifacts/forge_v2_native_remove_history_20261018.json"
const EXTENSION_PATH := "res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
const HISTORY_KEYS := [
	"state_revision", "state_initialized", "state_empty", "state_volume_m3",
	"state_vertex_count", "state_triangle_count", "active_tail_cursor",
	"checkpoint_operation_count", "tail_timeline_count", "redo_count",
	"retained_state_count", "retained_total_vertices", "retained_total_triangles",
	"boolean_count", "export_count", "promotion_count", "last_mode",
]

var _checks: Array[Dictionary] = []
var _errors: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var extension: Resource = load(EXTENSION_PATH)
	if not _check(extension != null and ClassDB.class_exists(&"ForgeV2ManifoldBoolean"), "native available"):
		_finish()
		return
	var backend := _backend()
	if not _check(backend.has_method("subtract_mesh"), "stateful subtraction bound"):
		_finish()
		return
	_check(bool((backend.call("get_backend_info") as Dictionary).get("empty_result_supported", false)), "empty capability")
	var unit := _box(Vector3.ZERO, Vector3.ONE)
	var half := _box(Vector3(0.5, -1, -1), Vector3(1.5, 3, 3))
	var extend := _box(Vector3(0.25, 0, 0), Vector3(0.5, 1, 1))
	var erase := _box(Vector3(-1, -1, -1), Vector3(3, 3, 3))
	var outside := _box(Vector3(5, 5, 5), Vector3.ONE)
	var methods := ["reset_mesh", "subtract_mesh", "add_mesh", "subtract_mesh", "subtract_mesh", "add_mesh", "subtract_mesh", "add_mesh", "subtract_mesh"]
	var operands := [unit, half, extend, erase, outside, unit, half, extend, erase]
	var volumes := [1.0, 0.5, 0.75, 0.0, 0.0, 1.0, 0.5, 0.75, 0.0]
	var packets: Array[Dictionary] = []
	for i in methods.size():
		var before := backend.call("get_history_info") as Dictionary
		var packet := _call_mesh(backend, methods[i], operands[i])
		packets.append(packet)
		var label := "operation %d" % (i + 1)
		_assert_packet(packet, volumes[i], label)
		_check(int(packet.get("state_revision", -1)) == int(before.get("state_revision", -1)) + 1, label + " revision")
		_check(int(packet.get("retained_state_count", -1)) == mini(i + 2, 6), label + " bounded states")
		_check(int(packet.get("checkpoint_operation_count", -1)) == maxi(i - 4, 0), label + " checkpoint count")
		if i > 0:
			_check(int(packet.get("boolean_count", -1)) == int(before.get("boolean_count", -1)) + 1, label + " one Boolean")
			_check(int(packet.get("export_count", -1)) == int(before.get("export_count", -1)) + 1, label + " one export")
		if i >= 5:
			_check(int(packet.get("promotion_boolean_delta", -1)) == 0 and int(packet.get("promotion_export_delta", -1)) == 0, label + " promotion no replay")
			var checkpoint := backend.call("export_checkpoint_mesh") as Dictionary
			_assert_packet(checkpoint, volumes[i - 5], label + " exported checkpoint")
	_check((packets[1].get("source_original_ids", PackedInt32Array()) as PackedInt32Array).has(1), "partial cut has cutter surface provenance")
	_check(bool(packets[3].get("state_initialized", false)), "complete erasure keeps initialization")

	# S4 (empty) becomes the checkpoint; every older source may be discarded.
	var empty_checkpoint := backend.call("export_checkpoint_mesh") as Dictionary
	_assert_packet(empty_checkpoint, 0.0, "empty promoted checkpoint")
	_check(int(empty_checkpoint.get("checkpoint_operation_count", -1)) == 4, "empty checkpoint preserves count")
	var restored := _backend()
	var restored_packet := restored.call("reset_checkpoint_mesh", empty_checkpoint["vertices"], empty_checkpoint["indices"], 4) as Dictionary
	_assert_packet(restored_packet, 0.0, "restore erased prefix")
	_check(bool(restored_packet.get("state_initialized", false)), "restored erased prefix initialized")
	for i in range(4, methods.size()):
		_assert_packet(_call_mesh(restored, methods[i], operands[i]), volumes[i], "restored replay %d" % (i + 1))
	_check(int((restored.call("get_history_info") as Dictionary).get("checkpoint_operation_count", -1)) == 4, "restored replay retains prefix floor")

	for i in range(7, 2, -1):
		var packet := backend.call("undo_state") as Dictionary
		_assert_packet(packet, volumes[i], "undo to %d" % (i + 1))
		_check(packet["vertices"] == packets[i]["vertices"] and packet["indices"] == packets[i]["indices"], "undo restores exact geometry %d" % (i + 1))
	var floor_before := backend.call("get_history_info") as Dictionary
	_check(not bool((backend.call("undo_state") as Dictionary).get("ok", true)), "sixth Undo unavailable")
	_assert_unchanged(backend, floor_before, "unavailable Undo atomic")
	for i in range(4, 9):
		var packet := backend.call("redo_state") as Dictionary
		_assert_packet(packet, volumes[i], "redo to %d" % (i + 1))
		_check(packet["vertices"] == packets[i]["vertices"] and packet["indices"] == packets[i]["indices"], "redo restores exact geometry %d" % (i + 1))
	_check(not bool((backend.call("redo_state") as Dictionary).get("ok", true)), "Redo unavailable at end")

	# The protected Handle stays outside ordinary subtraction and history.
	var protected_box := _box(Vector3(0.2, 0.2, 0.2), Vector3(0.2, 0.2, 0.2))
	var protected_before := backend.call("get_history_info") as Dictionary
	var composed := backend.call("compose_current_state_with_protected_mesh", protected_box["vertices"], protected_box["indices"]) as Dictionary
	_assert_packet(composed, 0.008, "protected Handle after complete erase")
	for source in composed.get("source_original_ids", PackedInt32Array()):
		_check(source == 1, "remaining surface belongs to protected Handle")
	var clipped := backend.call("clip_current_state_with_protected_mesh", protected_box["vertices"], protected_box["indices"]) as Dictionary
	_assert_packet(clipped, 0.0, "clip erased ordinary state")
	_assert_unchanged(backend, protected_before, "protected composition leaves history untouched")

	backend.call("undo_state")
	backend.call("undo_state")
	var branch_before := backend.call("get_history_info") as Dictionary
	var invalid := {"vertices": unit["vertices"], "indices": PackedInt32Array([0, 1, 99])}
	_check(not bool(_call_mesh(backend, "subtract_mesh", invalid).get("ok", true)), "invalid cutter rejected")
	_assert_unchanged(backend, branch_before, "invalid cutter preserves redo and counters")
	_check(not bool(_call_mesh(backend, "subtract_mesh", {"vertices": PackedVector3Array(), "indices": PackedInt32Array()}).get("ok", true)), "empty cutter rejected")
	_assert_unchanged(backend, branch_before, "empty cutter preserves redo and counters")
	var branch := _call_mesh(backend, "subtract_mesh", outside)
	_assert_packet(branch, 0.5, "outside cut branch")
	_check(int(branch.get("redo_count", -1)) == 0 and int(branch.get("checkpoint_operation_count", -1)) == 4, "branch clears redo and keeps floor")
	_check(int(branch.get("active_tail_cursor", -1)) == 4, "no-op cut occupies one history slot")

	# An initial cut and branching from blank S0 are valid bounded operations.
	var initial := _backend()
	_assert_packet(_call_mesh(initial, "subtract_mesh", unit), 0.0, "initial no-op cut")
	_assert_packet(initial.call("undo_state") as Dictionary, 0.0, "initial cut Undo")
	_assert_packet(initial.call("redo_state") as Dictionary, 0.0, "initial cut Redo")
	_assert_packet(_call_mesh(initial, "add_mesh", unit), 1.0, "Add after initial no-op")
	initial.call("undo_state")
	initial.call("undo_state")
	var first_branch := _call_mesh(initial, "add_mesh", extend)
	_assert_packet(first_branch, 0.5, "Add branch from blank S0")
	_check(int(first_branch.get("active_tail_cursor", -1)) == 1 and int(first_branch.get("redo_count", -1)) == 0, "empty branch keeps new one-operation history")
	var invalid_restore_before := initial.call("get_history_info") as Dictionary
	_check(not bool((initial.call("reset_checkpoint_mesh", PackedVector3Array(), unit["indices"], 4) as Dictionary).get("ok", true)), "half-empty checkpoint rejected")
	_assert_unchanged(initial, invalid_restore_before, "invalid checkpoint atomic")
	_finish()


func _backend() -> Object:
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	backend.call("set_history_window_enabled", true)
	return backend


func _call_mesh(backend: Object, method: String, mesh: Dictionary) -> Dictionary:
	return backend.call(method, mesh["vertices"], mesh["indices"]) as Dictionary


func _assert_packet(packet: Dictionary, expected_volume: float, label: String) -> void:
	if not _check(bool(packet.get("ok", false)), label + " succeeds", packet.get("error_code", "")):
		return
	_check(absf(float(packet.get("manifold_volume_m3", -1)) - expected_volume) < 0.0000001, label + " analytic volume")
	var vertices: PackedVector3Array = packet.get("vertices", PackedVector3Array())
	var indices: PackedInt32Array = packet.get("indices", PackedInt32Array())
	_check(bool(packet.get("empty", false)) == is_zero_approx(expected_volume), label + " empty flag")
	if is_zero_approx(expected_volume):
		_check(vertices.is_empty() and indices.is_empty(), label + " empty arrays")
		_check((packet.get("source_original_ids", PackedInt32Array()) as PackedInt32Array).is_empty() and (packet.get("source_face_ids", PackedInt32Array()) as PackedInt32Array).is_empty(), label + " empty provenance")
	else:
		_check(vertices.size() >= 4 and indices.size() >= 12 and indices.size() % 3 == 0, label + " solid arrays")
		var edges: Dictionary = {}
		for triangle in range(0, indices.size(), 3):
			for edge in 3:
				var a := indices[triangle + edge]
				var b := indices[triangle + (edge + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				edges[key] = int(edges.get(key, 0)) + 1
		var closed := true
		for count in edges.values():
			closed = closed and int(count) == 2
		_check(closed, label + " closed manifold topology")


func _assert_unchanged(backend: Object, before: Dictionary, label: String) -> void:
	var after := backend.call("get_history_info") as Dictionary
	for key in HISTORY_KEYS:
		_check(before.get(key) == after.get(key), label + " " + key)


func _box(origin: Vector3, size: Vector3) -> Dictionary:
	var vertices := PackedVector3Array([
		origin, origin + Vector3(size.x, 0, 0), origin + Vector3(size.x, size.y, 0), origin + Vector3(0, size.y, 0),
		origin + Vector3(0, 0, size.z), origin + Vector3(size.x, 0, size.z), origin + size, origin + Vector3(0, size.y, size.z),
	])
	return {"vertices": vertices, "indices": PackedInt32Array([
		0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4,
		3, 7, 6, 3, 6, 2, 0, 4, 7, 0, 7, 3, 1, 2, 6, 1, 6, 5,
	])}


func _check(condition: bool, label: String, detail: Variant = "") -> bool:
	_checks.append({"check": label, "ok": condition, "detail": detail})
	if not condition:
		_errors.append(label + ": " + str(detail))
	return condition


func _finish() -> void:
	var report := {"ok": _errors.is_empty(), "checks": _checks.size(), "failures": _errors, "results": _checks}
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("Native Remove history: %d checks, %d failures" % [_checks.size(), _errors.size()])
	for error in _errors:
		printerr(error)
	quit(0 if _errors.is_empty() else 1)
