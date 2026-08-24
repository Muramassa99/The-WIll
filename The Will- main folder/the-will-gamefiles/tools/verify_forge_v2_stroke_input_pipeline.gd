extends SceneTree

const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_stroke_input_pipeline_2026-08-10.txt"
)

var authoring_state_signal_count := 0
var material_preview_signal_count := 0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controller: Node = ForgeV2StageControllerScript.new()
	root.add_child(controller)
	controller.call("ensure_authoring_state")
	controller.authoring_state_changed.connect(_on_authoring_state_changed)
	controller.material_body_preview_changed.connect(
		_on_material_body_preview_changed
	)

	authoring_state_signal_count = 0
	material_preview_signal_count = 0
	var body_id: StringName = controller.call(
		"begin_material_body_path",
		Vector3.ZERO,
		Vector3.UP
	)
	_require(body_id != StringName(), "begin must create an active body")
	_require(
		authoring_state_signal_count == 1,
		"begin must emit one structural authoring-state update"
	)

	authoring_state_signal_count = 0
	material_preview_signal_count = 0
	var batch_positions := PackedVector3Array([
		Vector3(0.04, 0.0, 0.0),
		Vector3(0.08, 0.0, 0.0),
		Vector3(0.12, 0.0, 0.0),
	])
	var batch_normals := PackedVector3Array([
		Vector3.UP,
		Vector3.BACK,
		Vector3.RIGHT,
	])
	var accepted_count := int(controller.call(
		"extend_material_body_path_samples",
		batch_positions,
		batch_normals,
		false
	))
	_require(accepted_count == 3, "batch must accept all spaced samples")
	_require(
		authoring_state_signal_count == 0,
		"live batch must not trigger the broad UI authoring-state signal"
	)
	_require(
		material_preview_signal_count == 1,
		"live batch must trigger exactly one preview update"
	)

	var state: Resource = controller.call("get_active_authoring_state") as Resource
	var active_body := _find_body(state, body_id)
	_require(active_body != null, "active body must remain available")
	var path_points: PackedVector3Array = active_body.get("path_points")
	var path_normals: PackedVector3Array = active_body.get(
		"path_surface_normals"
	)
	_require(path_points.size() == 4, "initial point plus batch must persist")
	_require(path_normals.size() == path_points.size(), "normals must stay paired")
	_require(path_points[3].is_equal_approx(batch_positions[2]), "batch order must persist")
	_require(path_normals[2].is_equal_approx(Vector3.BACK), "middle normal must persist")
	_require(path_normals[3].is_equal_approx(Vector3.RIGHT), "final normal must persist")

	authoring_state_signal_count = 0
	material_preview_signal_count = 0
	var committed := bool(controller.call(
		"finish_material_body_path",
		Vector3.ZERO,
		false,
		Vector3.FORWARD
	))
	_require(committed, "finished nonzero path must commit")
	_require(
		authoring_state_signal_count == 1,
		"finish must emit one structural authoring-state update"
	)
	_require(
		material_preview_signal_count == 0,
		"finish must not emit an extra live-preview update"
	)
	_require(
		StringName(active_body.get("committed_layer_id")) != StringName(),
		"finished body must carry committed layer identity"
	)
	_require(
		StringName(state.get("bounded_history_suspended_reason"))
		== &"none",
		"the first capsule primitive must remain on bounded history"
	)

	var second_body_id: StringName = controller.call(
		"begin_material_body_path",
		Vector3(0.20, 0.0, 0.0),
		Vector3.UP
	)
	_require(second_body_id != StringName(), "second primitive begin failed")
	controller.call(
		"extend_material_body_path_samples",
		PackedVector3Array([
			Vector3(0.24, 0.0, 0.0),
			Vector3(0.28, 0.0, 0.0),
		]),
		PackedVector3Array([Vector3.UP, Vector3.UP]),
		true
	)
	_require(
		bool(controller.call(
			"finish_material_body_path",
			Vector3.ZERO,
			false,
			Vector3.FORWARD
		)),
		"second primitive finish failed"
	)
	var second_body := _find_body(state, second_body_id)
	var finish_result: Dictionary = controller.call(
		"get_last_material_body_finish_result"
	) as Dictionary
	_require(
		second_body != null
		and StringName(second_body.get("committed_layer_id")) != StringName(),
		"second capsule primitive remained pending"
	)
	_require(
		int(state.call("get_committed_layer_count")) == 2
		and int(state.call("get_pending_material_body_count")) == 0,
		"bounded history did not retain two committed capsule strokes"
	)
	_require(
		StringName(finish_result.get("status", StringName())) == &"committed"
		and bool(finish_result.get("committed", false)),
		"controller did not report the second primitive commit"
	)

	_write_result([
		"ok=true",
		"batched_point_normal_pairs=true",
		"one_preview_signal_per_batch=true",
		"no_broad_ui_signal_during_batch=true",
		"single_structural_finish_signal=true",
		"bounded_history_accepts_subsequent_capsules=true",
	])
	quit(0)

func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null:
		return null
	var bodies: Array = state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null

func _on_authoring_state_changed(_state: Resource) -> void:
	authoring_state_signal_count += 1

func _on_material_body_preview_changed(_state: Resource) -> void:
	material_preview_signal_count += 1

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result([
		"ok=false",
		"error=%s" % message,
	])
	push_error(message)
	quit(1)

func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
