extends SceneTree

const ForgeV2StageControllerScript = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const ForgeV2VolumePreviewPresenterScript = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")

var state_change_count := 0

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var controller: ForgeV2StageController = ForgeV2StageControllerScript.new()
	controller.default_project_name = "Stroke Finish CSG Promotion Verifier"
	var presenter: ForgeV2VolumePreviewPresenter = ForgeV2VolumePreviewPresenterScript.new()
	get_root().add_child(controller)
	get_root().add_child(presenter)
	await process_frame
	presenter.bind_stage_controller(controller)
	controller.authoring_state_changed.connect(_on_authoring_state_changed)

	var start_position := Vector3.ZERO
	var end_position := Vector3(0.2, 0.0, 0.0)
	var active_body_id := controller.begin_material_body_path(start_position)
	var extend_changed := controller.extend_material_body_path(end_position)
	await process_frame

	var authoring_state: Resource = controller.get_active_authoring_state()
	var active_preview_while_dragging: Array = presenter.call("_collect_active_placement_preview_records", authoring_state) as Array
	var csg_groups_while_dragging: Dictionary = presenter.call("_collect_csg_material_body_groups", authoring_state) as Dictionary
	var csg_children_while_dragging := _child_count(presenter.csg_material_body_root)
	var rounded_preview_hidden_while_dragging := presenter.preview_mesh_instance == null or not presenter.preview_mesh_instance.visible
	var active_id_present_while_dragging := active_body_id != StringName() and controller.get_active_placement_body_id() == active_body_id
	var active_preview_record_available_while_dragging := not active_preview_while_dragging.is_empty()
	var csg_ready_while_dragging := not csg_groups_while_dragging.is_empty() and csg_children_while_dragging > 0
	var csg_noodle_created_while_dragging := _has_descendant_prefix(presenter.csg_material_body_root, "BodyNoodle")
	var active_body_collision_disabled_while_dragging := not _has_material_surface_collision_for_body(presenter.csg_material_body_root, active_body_id)

	var events_before_finish := state_change_count
	var finish_result := controller.finish_material_body_path(end_position, true)
	await process_frame

	authoring_state = controller.get_active_authoring_state()
	var active_preview_after_finish: Array = presenter.call("_collect_active_placement_preview_records", authoring_state) as Array
	var csg_groups_after_finish: Dictionary = presenter.call("_collect_csg_material_body_groups", authoring_state) as Dictionary
	var active_id_cleared_after_finish := controller.get_active_placement_body_id() == StringName()
	var finish_emitted_state_change := state_change_count > events_before_finish
	var active_preview_removed_after_finish := active_preview_after_finish.is_empty()
	var csg_groups_ready_after_finish := not csg_groups_after_finish.is_empty()
	var csg_visible_after_finish := (
		presenter.csg_material_body_root != null
		and presenter.csg_material_body_root.visible
		and presenter.csg_material_body_root.get_child_count() > 0
	)
	var csg_noodle_created_after_finish := _has_descendant_prefix(presenter.csg_material_body_root, "BodyNoodle")
	var material_surface_collision_ready := _has_material_surface_collision(presenter.csg_material_body_root)
	var rounded_preview_hidden_after_finish := presenter.preview_mesh_instance == null or not presenter.preview_mesh_instance.visible

	var lines: PackedStringArray = []
	lines.append("active_id_present_while_dragging=%s" % str(active_id_present_while_dragging))
	lines.append("extend_changed=%s" % str(extend_changed))
	lines.append("rounded_preview_hidden_while_dragging=%s" % str(rounded_preview_hidden_while_dragging))
	lines.append("active_preview_record_available_while_dragging=%s" % str(active_preview_record_available_while_dragging))
	lines.append("csg_ready_while_dragging=%s" % str(csg_ready_while_dragging))
	lines.append("csg_noodle_created_while_dragging=%s" % str(csg_noodle_created_while_dragging))
	lines.append("active_body_collision_disabled_while_dragging=%s" % str(active_body_collision_disabled_while_dragging))
	lines.append("finish_result=%s" % str(finish_result))
	lines.append("finish_emitted_state_change=%s" % str(finish_emitted_state_change))
	lines.append("active_id_cleared_after_finish=%s" % str(active_id_cleared_after_finish))
	lines.append("active_preview_removed_after_finish=%s" % str(active_preview_removed_after_finish))
	lines.append("rounded_preview_hidden_after_finish=%s" % str(rounded_preview_hidden_after_finish))
	lines.append("csg_groups_ready_after_finish=%s" % str(csg_groups_ready_after_finish))
	lines.append("csg_visible_after_finish=%s" % str(csg_visible_after_finish))
	lines.append("csg_noodle_created_after_finish=%s" % str(csg_noodle_created_after_finish))
	lines.append("material_surface_collision_ready=%s" % str(material_surface_collision_ready))
	lines.append("state_change_count=%s" % str(state_change_count))
	lines.append("events_before_finish=%s" % str(events_before_finish))
	lines.append("csg_children_while_dragging=%s" % str(csg_children_while_dragging))
	lines.append("csg_children_after_finish=%s" % str(_child_count(presenter.csg_material_body_root)))

	var failed := (
		not active_id_present_while_dragging
		or not extend_changed
		or not rounded_preview_hidden_while_dragging
		or not active_preview_record_available_while_dragging
		or not csg_ready_while_dragging
		or not csg_noodle_created_while_dragging
		or not active_body_collision_disabled_while_dragging
		or not finish_result
		or not finish_emitted_state_change
		or not active_id_cleared_after_finish
		or not active_preview_removed_after_finish
		or not rounded_preview_hidden_after_finish
		or not csg_groups_ready_after_finish
		or not csg_visible_after_finish
		or not csg_noodle_created_after_finish
		or not material_surface_collision_ready
	)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_stroke_finish_promotes_csg_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(1 if failed else 0)

func _on_authoring_state_changed(_state: Resource) -> void:
	state_change_count += 1

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

func _has_material_surface_collision(node: Node) -> bool:
	if node == null:
		return false
	if node is CSGShape3D:
		var shape := node as CSGShape3D
		if shape.use_collision and bool(shape.get_meta("forge_v2_material_surface", false)):
			return true
	for child: Node in node.get_children():
		if _has_material_surface_collision(child):
			return true
	return false

func _has_material_surface_collision_for_body(node: Node, body_id: StringName) -> bool:
	if node == null or body_id == StringName():
		return false
	if node is CSGShape3D:
		var shape := node as CSGShape3D
		if (
			shape.use_collision
			and bool(shape.get_meta("forge_v2_material_surface", false))
			and StringName(shape.get_meta("forge_v2_body_id", StringName())) == body_id
		):
			return true
	for child: Node in node.get_children():
		if _has_material_surface_collision_for_body(child, body_id):
			return true
	return false
