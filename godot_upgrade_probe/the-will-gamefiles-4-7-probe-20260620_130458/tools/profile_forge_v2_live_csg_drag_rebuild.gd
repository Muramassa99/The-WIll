extends SceneTree

const ForgeV2StageControllerScript = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const ForgeV2VolumePreviewPresenterScript = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")

const STATIC_BODY_COUNT := 8
const SAMPLE_COUNT := 96
const SAMPLE_STEP_METERS := 0.02

func _init() -> void:
	call_deferred("_run_profile")

func _run_profile() -> void:
	var controller: ForgeV2StageController = ForgeV2StageControllerScript.new()
	controller.default_project_name = "Live CSG Drag Rebuild Profile"
	var presenter: ForgeV2VolumePreviewPresenter = ForgeV2VolumePreviewPresenterScript.new()
	get_root().add_child(controller)
	get_root().add_child(presenter)
	await process_frame
	presenter.bind_stage_controller(controller)

	for body_index in range(STATIC_BODY_COUNT):
		var y := (float(body_index) - 3.0) * 0.16
		controller.begin_material_body_path(Vector3(-0.52, y, 0.0))
		controller.extend_material_body_path(Vector3(-0.20, y, 0.0))
		controller.finish_material_body_path(Vector3(-0.20, y, 0.0), true)
	await process_frame

	var active_y := 0.0
	controller.begin_material_body_path(Vector3(-0.45, active_y, 0.0))
	await process_frame

	var changed_count := 0
	var total_usec := 0
	var max_usec := 0
	for sample_index in range(1, SAMPLE_COUNT + 1):
		var next_position := Vector3(-0.45 + (float(sample_index) * SAMPLE_STEP_METERS), active_y, 0.0)
		var started_usec := Time.get_ticks_usec()
		var changed := controller.extend_material_body_path(next_position)
		var elapsed_usec := Time.get_ticks_usec() - started_usec
		if changed:
			changed_count += 1
		total_usec += elapsed_usec
		max_usec = maxi(max_usec, elapsed_usec)

	var finish_started_usec := Time.get_ticks_usec()
	controller.finish_material_body_path(Vector3(-0.45 + (float(SAMPLE_COUNT) * SAMPLE_STEP_METERS), active_y, 0.0), true)
	var finish_elapsed_usec := Time.get_ticks_usec() - finish_started_usec
	await process_frame

	var authoring_state: Resource = controller.get_active_authoring_state()
	var material_bodies: Array = authoring_state.get("material_bodies")
	var path_point_count := 0
	if not material_bodies.is_empty() and material_bodies[material_bodies.size() - 1] is Resource:
		var body: Resource = material_bodies[material_bodies.size() - 1] as Resource
		var path_points: PackedVector3Array = body.get("path_points")
		path_point_count = path_points.size()

	var average_usec := float(total_usec) / float(SAMPLE_COUNT)
	var lines: PackedStringArray = []
	lines.append("static_body_count=%s" % str(STATIC_BODY_COUNT))
	lines.append("sample_count=%s" % str(SAMPLE_COUNT))
	lines.append("sample_step_meters=%s" % str(SAMPLE_STEP_METERS))
	lines.append("changed_count=%s" % str(changed_count))
	lines.append("path_point_count=%s" % str(path_point_count))
	lines.append("total_extend_usec=%s" % str(total_usec))
	lines.append("average_extend_usec=%s" % str(average_usec))
	lines.append("max_extend_usec=%s" % str(max_usec))
	lines.append("finish_elapsed_usec=%s" % str(finish_elapsed_usec))
	lines.append("csg_root_child_count=%s" % str(_child_count(presenter.csg_material_body_root)))
	lines.append("static_zone_count=%s" % str(presenter.csg_static_zone_nodes.size()))
	lines.append("static_root_child_count=%s" % str(_child_count(presenter.csg_static_body_root)))
	lines.append("active_root_child_count=%s" % str(_child_count(presenter.csg_active_body_root)))
	lines.append("csg_noodle_created=%s" % str(_has_descendant_prefix(presenter.csg_material_body_root, "BodyNoodle")))

	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/profile_forge_v2_live_csg_drag_rebuild_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(0)

func _child_count(node: Node) -> int:
	if node == null:
		return 0
	return node.get_child_count()

func _has_descendant_prefix(node: Node, name_prefix: String) -> bool:
	if node == null:
		return false
	if node.name.begins_with(name_prefix):
		return true
	for child: Node in node.get_children():
		if _has_descendant_prefix(child, name_prefix):
			return true
	return false
