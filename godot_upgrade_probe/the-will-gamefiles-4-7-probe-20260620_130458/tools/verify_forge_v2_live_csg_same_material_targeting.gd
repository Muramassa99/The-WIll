extends SceneTree

const ForgeV2StageControllerScript = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const ForgeV2VolumePreviewPresenterScript = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var controller: ForgeV2StageController = ForgeV2StageControllerScript.new()
	controller.default_project_name = "Live CSG Same Material Targeting Verifier"
	var presenter: ForgeV2VolumePreviewPresenter = ForgeV2VolumePreviewPresenterScript.new()
	get_root().add_child(controller)
	get_root().add_child(presenter)
	await process_frame
	presenter.bind_stage_controller(controller)

	var first_body_id := controller.begin_material_body_path(Vector3(-0.2, 0.0, 0.0))
	controller.extend_material_body_path(Vector3(0.2, 0.0, 0.0))
	controller.finish_material_body_path(Vector3(0.2, 0.0, 0.0), true)
	await process_frame

	var first_body_collision_ready_after_finish := _has_material_surface_collision_for_body(
		presenter.csg_material_body_root,
		first_body_id
	)

	var second_body_id := controller.begin_material_body_path(Vector3(-0.1, 0.025, 0.0))
	controller.extend_material_body_path(Vector3(0.1, 0.025, 0.0))
	await process_frame

	var authoring_state: Resource = controller.get_active_authoring_state()
	var material_groups: Dictionary = presenter.call("_collect_csg_material_body_groups", authoring_state) as Dictionary
	var csg_visible_while_second_dragging := (
		presenter.csg_material_body_root != null
		and presenter.csg_material_body_root.visible
		and presenter.csg_material_body_root.get_child_count() > 0
	)
	var rounded_preview_hidden_while_second_dragging := presenter.preview_mesh_instance == null or not presenter.preview_mesh_instance.visible
	var same_material_group_contains_both_bodies := _largest_group_body_count(material_groups) >= 2
	var first_body_still_targetable_while_second_dragging := _has_material_surface_collision_for_body(
		presenter.csg_material_body_root,
		first_body_id
	)
	var second_body_not_self_targetable_while_dragging := not _has_material_surface_collision_for_body(
		presenter.csg_material_body_root,
		second_body_id
	)

	controller.finish_material_body_path(Vector3(0.1, 0.025, 0.0), true)
	await process_frame

	var second_body_targetable_after_finish := _has_material_surface_collision(presenter.csg_material_body_root)

	var lines: PackedStringArray = []
	lines.append("first_body_collision_ready_after_finish=%s" % str(first_body_collision_ready_after_finish))
	lines.append("csg_visible_while_second_dragging=%s" % str(csg_visible_while_second_dragging))
	lines.append("rounded_preview_hidden_while_second_dragging=%s" % str(rounded_preview_hidden_while_second_dragging))
	lines.append("same_material_group_contains_both_bodies=%s" % str(same_material_group_contains_both_bodies))
	lines.append("first_body_still_targetable_while_second_dragging=%s" % str(first_body_still_targetable_while_second_dragging))
	lines.append("second_body_not_self_targetable_while_dragging=%s" % str(second_body_not_self_targetable_while_dragging))
	lines.append("second_body_targetable_after_finish=%s" % str(second_body_targetable_after_finish))
	lines.append("first_body_id=%s" % String(first_body_id))
	lines.append("second_body_id=%s" % String(second_body_id))
	lines.append("csg_child_count=%s" % str(_child_count(presenter.csg_material_body_root)))

	var failed := (
		not first_body_collision_ready_after_finish
		or not csg_visible_while_second_dragging
		or not rounded_preview_hidden_while_second_dragging
		or not same_material_group_contains_both_bodies
		or not first_body_still_targetable_while_second_dragging
		or not second_body_not_self_targetable_while_dragging
		or not second_body_targetable_after_finish
	)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_live_csg_same_material_targeting_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(1 if failed else 0)

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

func _largest_group_body_count(material_groups: Dictionary) -> int:
	var largest_count := 0
	for group_key: Variant in material_groups.keys():
		var group_record: Dictionary = material_groups.get(group_key, {}) as Dictionary
		var body_records: Array = group_record.get("body_records", []) as Array
		largest_count = maxi(largest_count, body_records.size())
	return largest_count

func _child_count(node: Node) -> int:
	if node == null:
		return 0
	return node.get_child_count()
