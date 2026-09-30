extends SceneTree

const Envelope = preload("res://tools/grip_plane_proof/planar_contact_envelope.gd")
const INPUT_PATH: String = "C:/WORKSPACE/test_artifacts/contact_envelope_input_2026-09-26.json"
const OUTPUT_PATH: String = "C:/WORKSPACE/test_artifacts/contact_envelope_output_2026-09-26.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	if not parsed is Dictionary or parsed.get("schema") != "contact_envelope_input_v1" or not parsed.get("cases") is Array:
		push_error("Invalid envelope proof input")
		quit(1)
		return
	var cases: Array = []
	var ok: bool = true
	for input: Dictionary in parsed.cases:
		var polygon: PackedVector2Array = PackedVector2Array()
		for point: Array in input.polygon_m:
			polygon.append(Vector2(float(point[0]), float(point[1])))
		var result: Dictionary = Envelope.new().build(polygon, StringName(input.origin_id), StringName(input.source_id), float(input.radius_m), bool(input.complete), float(input.units_per_meter))
		cases.append({"input": input, "result": result})
		ok = ok and bool(result.valid) == bool(input.expected_valid)
	var report: Dictionary = {"schema": "contact_envelope_output_v1", "ok": ok,
		"input_sha256": FileAccess.get_sha256(INPUT_PATH), "cases": cases,
		"engine": Engine.get_version_info(), "total_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"production_pose_written": false, "grip_accepted": false}
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write envelope proof report")
		quit(1)
		return
	file.store_string(JSON.stringify(_json(report), "\t", true, true))
	file.close()
	print("Envelope construction cases: ", cases.size(), "; expected validity matched: ", ok, "; report: ", OUTPUT_PATH)
	quit(0 if ok else 1)


func _json(value: Variant) -> Variant:
	if value is Vector2:
		return [value.x, value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = _json(value[key])
		return result
	if value is Array or value is PackedVector2Array or value is PackedFloat64Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_json(item))
		return result
	if value is float and not is_finite(value):
		return str(value)
	return value
