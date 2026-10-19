extends SceneTree

const Checkpoint = preload("res://runtime/forge_v2/forge_v2_history_checkpoint.gd")
const Ledger = preload("res://runtime/forge_v2/forge_v2_material_ledger.gd")
const Layer = preload("res://runtime/forge_v2/forge_v2_layer_data.gd")
const Resolver = preload("res://runtime/forge_v2/forge_v2_material_volume_resolver.gd")
const Body = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const REPORT := "C:/WORKSPACE/test_artifacts/forge_v2_remove_accounting_20261018.json"
const MATERIAL := &"mat_iron"

var checks: Array[Dictionary] = []
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_verify_empty_checkpoint()
	_verify_checkpoint_erasure_journal()
	_verify_bounded_cut_ledger()
	_verify_removal_and_protection()
	var report := {"ok": failures == 0, "check_count": checks.size(), "failures": failures, "checks": checks}
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("Forge V2 Remove accounting: %s/%s checks passed" % [checks.size() - failures, checks.size()])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks.append({"ok": condition, "label": label})
	if not condition:
		failures += 1
		push_error(label)

func _empty_packet(count: int) -> Dictionary:
	return {
		"ok": true, "empty": true, "checkpoint_initialized": true,
		"checkpoint_operation_count": count,
		"vertices": PackedVector3Array(), "indices": PackedInt32Array(),
		"source_original_ids": PackedInt32Array(), "source_face_ids": PackedInt32Array(),
		"checkpoint_vertex_count": 0, "checkpoint_triangle_count": 0,
		"checkpoint_volume_m3": 0.0,
	}

func _verify_empty_checkpoint() -> void:
	var checkpoint := Checkpoint.new()
	_check(checkpoint.advance_logical_checkpoint(1, StringName(), {}, 1, 0.01, {}, {}, {}), "Leading no-op Remove can own a material-free logical checkpoint")
	_check(not checkpoint.is_restore_ready(), "Logical empty checkpoint waits for native acknowledgement")
	_check(checkpoint.to_native_packet().get("checkpoint_occupancy_empty", false), "Empty logical occupancy is explicitly marked")
	var resolver := Resolver.new()
	var restored := resolver.restore_incremental_committed_cache_from_checkpoint(checkpoint.to_native_packet(), [])
	_check(restored.get("ok", false), "Empty logical occupancy restores before native materialization")
	_check(int((restored.get("summary", {}) as Dictionary).get("total_rough_material_centi_units", -1)) == 0, "Empty occupancy retains zero material amount")
	var invalid := checkpoint.to_native_packet()
	invalid.erase("checkpoint_occupancy_empty")
	_check(not bool(resolver.restore_incremental_committed_cache_from_checkpoint(invalid, []).get("ok", false)), "Missing occupancy snapshot is not silently treated as erasure")
	invalid = checkpoint.to_native_packet()
	invalid["checkpoint_cell_materials"] = {Vector3i.ZERO: MATERIAL}
	_check(not bool(resolver.restore_incremental_committed_cache_from_checkpoint(invalid, []).get("ok", false)), "Empty marker rejects contradictory occupancy")
	var packet := _empty_packet(1)
	_check(checkpoint.materialize_from_native_packet(packet, 1), "Validated native empty result materializes")
	_check(checkpoint.is_restore_ready() and checkpoint.has_materialized_mesh(), "Materialized empty checkpoint is restore ready")
	_check(bool(checkpoint.to_native_packet().get("empty", false)), "Native empty flag survives export")
	var before := checkpoint.to_native_packet().duplicate(true)
	for field: String in ["empty", "checkpoint_volume_m3", "checkpoint_vertex_count", "source_face_ids"]:
		var malformed := packet.duplicate(true)
		if field == "empty":
			malformed[field] = false
		elif field == "source_face_ids":
			malformed[field] = PackedInt32Array([1])
		else:
			malformed[field] = 1
		_check(not checkpoint.materialize_from_native_packet(malformed, 1), "Inconsistent empty packet rejected: " + field)
		_check(checkpoint.to_native_packet() == before, "Rejected packet leaves checkpoint unchanged: " + field)
	var save_path := "C:/WORKSPACE/test_artifacts/forge_v2_remove_empty_checkpoint_20261018.tres"
	_check(ResourceSaver.save(checkpoint, save_path) == OK, "Empty checkpoint Resource saves")
	var loaded := ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
	_check(loaded != null and bool(loaded.call("is_restore_ready")), "Empty checkpoint Resource reloads ready")
	if loaded != null:
		loaded.call("normalize")
		_check(bool(loaded.call("is_restore_ready")), "Normalization preserves materialized empty readiness")
		_check(bool(resolver.restore_incremental_committed_cache_from_checkpoint(loaded.call("to_native_packet"), []).get("ok", false)), "Reloaded empty occupancy remains restorable")
	var materialless := Checkpoint.new()
	_check(not materialless.advance_logical_checkpoint(1, StringName(), {}, 1, 0.01, {Vector3i.ZERO: MATERIAL}, {}, {MATERIAL: 1}), "Nonempty checkpoint cannot lose its material identity")

func _verify_checkpoint_erasure_journal() -> void:
	var checkpoint := Checkpoint.new()
	_check(checkpoint.advance_logical_checkpoint(1, MATERIAL, {}, 1, 0.01, {Vector3i.ZERO: MATERIAL}, {}, {MATERIAL: 1}), "Occupied checkpoint starts with solid identity")
	var resolver := Resolver.new()
	var cutter := _body(&"cut", true, 0.10)
	var delta := resolver.build_checkpoint_occupancy_delta(checkpoint.to_native_packet(), [cutter], 0.01)
	_check(bool(delta.get("ok", false)) and int(delta.get("next_checkpoint_cell_count", -1)) == 0, "Cut journal erases final occupied cell")
	var identity := checkpoint.build_next_identity_descriptor(2)
	_check(checkpoint.advance_logical_checkpoint_with_occupancy_delta(2, identity, MATERIAL, {}, 2, 0.01, delta), "Erasure journal promotes atomically")
	_check(checkpoint.material_variant_id == MATERIAL and checkpoint.checkpoint_occupancy_empty, "Erased checkpoint retains its material and marks empty occupancy")
	_check(checkpoint.materialize_from_native_packet(_empty_packet(2), 2), "Erased checkpoint accepts native empty mesh")
	var after_restore := resolver.restore_incremental_committed_cache_from_checkpoint(checkpoint.to_native_packet(), [_body(&"added_after_empty", false, 0.02)])
	_check(bool(after_restore.get("ok", false)), "Add replays on an erased checkpoint")
	_check(float((after_restore.get("summary", {}) as Dictionary).get("total_rough_volume_cell_equivalents", 0.0)) > 0.0, "Add after erasure restores occupied material")

func _cut_layer(index: int) -> Resource:
	var layer := Layer.new()
	layer.layer_id = StringName("cut_%d" % index)
	layer.operation_type = Layer.OPERATION_SUBTRACT_VOID
	layer.operation_material_id = Layer.MATERIAL_VOID
	layer.csg_operation = Layer.CSG_OPERATION_SUBTRACTION
	layer.removed_material_records = [{
		"layer_id": layer.layer_id,
		"material_variant_id": Layer.MATERIAL_UNKNOWN_REMOVED,
		"operation_material_id": Layer.MATERIAL_VOID,
		"requested_material_hint": MATERIAL,
		"rough_volume_cell_equivalents": 3.25,
		"rough_material_centi_units": 7,
		"rough_material_units": 0.07,
	}]
	layer.ledger_delta = {MATERIAL: {"rough_material_centi_units": -1, "rough_volume_cell_equivalents": -0.25}}
	return layer

func _verify_bounded_cut_ledger() -> void:
	var ledger := Ledger.new()
	var summary: Dictionary = {"materials": {MATERIAL: {"rough_material_centi_units": 1000, "rough_volume_cell_equivalents": 250.0}}}
	for index in range(1000):
		summary = ledger.build_checkpoint_summary_after_layer(summary, _cut_layer(index))
	var records: Array = summary.get("removed_material_records", [])
	_check(records.size() == 1, "One thousand promoted cuts retain one aggregate record")
	_check(int(summary.get("removed_material_record_count", -1)) == 1000, "Cut count survives repeated checkpoint compaction")
	_check(int(summary.get("total_rough_material_centi_units", -1)) == 0 and is_zero_approx(float(summary.get("total_rough_volume_cell_equivalents", -1.0))), "Signed deltas can remove the entire material balance")
	if records.size() == 1:
		var aggregate := records[0] as Dictionary
		_check(not aggregate.has("layer_id") and not aggregate.has("requested_material_hint"), "Promoted aggregate retains no stale source identities")
		_check(int(aggregate.get("rough_material_centi_units", 0)) == 7000 and float(aggregate.get("rough_volume_cell_equivalents", 0.0)) == 3250.0, "Compaction preserves rough cutter amounts separately from occupied-material deltas")
	ledger.replace_with_summary(summary)
	var active := _cut_layer(1000)
	active.ledger_delta = {}
	ledger.apply_layer(active)
	var with_tail := ledger.get_summary()
	_check((with_tail.get("removed_material_records", []) as Array).size() == 2, "Active cut retains its individual record beside compacted prefix")
	_check(int(with_tail.get("removed_material_record_count", -1)) == 1001, "Combined cut count includes prefix and active tail")
	var promoted := ledger.get_checkpoint_summary()
	_check((promoted.get("removed_material_records", []) as Array).size() == 1 and int(promoted.get("removed_material_record_count", -1)) == 1001, "Next promotion stays bounded without resetting count")
	_check((ledger.get_summary().get("removed_material_records", []) as Array).size() == 2, "Building compact summary does not mutate live retained records")

func _body(id: StringName, remove: bool, radius: float) -> Dictionary:
	return {
		"body_id": id, "source_record_id": id, "layer_active": true,
		"material_variant_id": MATERIAL, "radius_meters": radius,
		"operation_mode": &"operation_remove_material" if remove else &"operation_add_material",
		"placement_policy": &"placement_replace_existing",
		"path_points": PackedVector3Array([Vector3.ZERO]),
	}

func _verify_removal_and_protection() -> void:
	var resolver := Resolver.new()
	var solid := _body(&"ordinary", false, 0.025)
	var cutter := _body(&"large_cut", true, 0.1)
	var baseline := resolver.build_usage_summary([solid])
	_check(float(baseline.get("total_rough_volume_cell_equivalents", 0.0)) > 0.0, "Ordinary fixture occupies volume")
	var erased := resolver.build_usage_summary([solid, cutter])
	_check(float(erased.get("total_rough_volume_cell_equivalents", -1.0)) == 0.0, "Remove resolves complete ordinary erasure")
	var handle := _body(&"protected", false, 0.0125)
	handle["body_kind"] = Body.BODY_KIND_HANDLE_PROFILE
	handle["material_variant_id"] = &"mat_wood"
	var protected_before := resolver.build_usage_summary([handle])
	var protected_after := resolver.build_usage_summary([solid, handle, cutter])
	_check(protected_before.get("materials", {}) == protected_after.get("materials", {}), "Cut preserves all protected Handle occupancy and removes ordinary material")
	resolver.build_incremental_committed_usage_summary([], [solid])
	var candidate := resolver.build_incremental_committed_usage_summary([solid], [cutter], {}, true)
	_check(float((candidate.get("summary", {}) as Dictionary).get("total_rough_volume_cell_equivalents", -1.0)) == 0.0, "Transactional Remove candidate reaches empty occupancy")
	_check(resolver.abort_incremental_committed_cache_candidate(), "Remove candidate rollback succeeds")
	var recovered := resolver.build_incremental_committed_usage_summary([solid], [])
	_check((recovered.get("summary", {}) as Dictionary).get("materials", {}) == baseline.get("materials", {}), "Rollback restores the exact material balance after full erasure")
