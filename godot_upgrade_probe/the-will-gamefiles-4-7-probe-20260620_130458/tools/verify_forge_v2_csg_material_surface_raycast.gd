extends SceneTree

const ForgeV2StageControllerScript = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const ForgeV2WorkspacePreviewScript = preload("res://runtime/forge_v2/forge_v2_workspace_preview.gd")
const ForgeV2PlacementTargetResolverScript = preload("res://runtime/forge_v2/forge_v2_placement_target_resolver.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var controller: ForgeV2StageController = ForgeV2StageControllerScript.new()
	controller.default_project_name = "CSG Material Surface Raycast Verifier"
	var preview: ForgeV2WorkspacePreview = ForgeV2WorkspacePreviewScript.new()
	get_root().add_child(controller)
	get_root().add_child(preview)
	await process_frame
	preview.bind_stage_controller(controller)
	preview.fit_view()

	controller.begin_material_body_path(Vector3(-0.15, 0.0, 0.0))
	controller.extend_material_body_path(Vector3(0.15, 0.0, 0.0))
	controller.finish_material_body_path(Vector3(0.15, 0.0, 0.0), true)
	await process_frame
	await physics_frame
	await physics_frame

	var screen_position: Vector2 = preview.camera.unproject_position(preview.to_global(Vector3.ZERO))
	var placement_result: Dictionary = preview.screen_to_workspace_local(screen_position)
	var hit_material_surface := (
		bool(placement_result.get("valid", false))
		and StringName(placement_result.get("target_kind", StringName())) == ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
	)
	var committed_layer_count := 0
	if controller.has_method("get_status_summary"):
		var summary: Dictionary = controller.get_status_summary() as Dictionary
		committed_layer_count = int(summary.get("committed_layer_count", 0))

	var lines: PackedStringArray = []
	lines.append("hit_material_surface=%s" % str(hit_material_surface))
	lines.append("placement_valid=%s" % str(bool(placement_result.get("valid", false))))
	lines.append("target_kind=%s" % String(placement_result.get("target_kind", StringName())))
	lines.append("source_body_id=%s" % String(placement_result.get("source_body_id", StringName())))
	lines.append("source_record_id=%s" % String(placement_result.get("source_record_id", StringName())))
	lines.append("local_position=%s" % str(placement_result.get("local_position", Vector3.ZERO)))
	lines.append("committed_layer_count=%s" % str(committed_layer_count))

	var failed := not hit_material_surface or committed_layer_count <= 0
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_csg_material_surface_raycast_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(1 if failed else 0)
