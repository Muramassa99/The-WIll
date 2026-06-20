extends SceneTree

const ForgeV2WorkspacePreviewScript = preload("res://runtime/forge_v2/forge_v2_workspace_preview.gd")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	get_root().size = Vector2i(1280, 720)

	var preview: ForgeV2WorkspacePreview = ForgeV2WorkspacePreviewScript.new()
	get_root().add_child(preview)
	await process_frame
	await process_frame
	preview.fit_view()
	await process_frame

	var contract = preview.workspace_contract
	contract.normalize()
	var plane_z := float(contract.get("placement_plane_z"))
	var inside_screen := preview.camera.unproject_position(preview.to_global(Vector3(0.0, 0.0, plane_z)))
	var edge_screen := preview.camera.unproject_position(preview.to_global(Vector3(contract.local_max.x, 0.0, plane_z)))
	var outside_screen := preview.camera.unproject_position(preview.to_global(Vector3(contract.local_max.x + 0.25, 0.0, plane_z)))

	var inside_result: Dictionary = preview.screen_to_workspace_local(inside_screen)
	var edge_result: Dictionary = preview.screen_to_workspace_local(edge_screen)
	var outside_result: Dictionary = preview.screen_to_workspace_local(outside_screen)

	var inside_valid := bool(inside_result.get("valid", false))
	var edge_valid := bool(edge_result.get("valid", false))
	var outside_invalid := not bool(outside_result.get("valid", false))
	var outside_rejects_build_area := StringName(outside_result.get("reject_reason", StringName())) == &"reject_outside_build_area"
	var outside_not_clamped_to_edge := not (outside_result.get("local_position", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(contract.local_max.x, 0.0, plane_z))
	var outside_screen_in_view := (
		outside_screen.x >= 0.0
		and outside_screen.x <= float(get_root().size.x)
		and outside_screen.y >= 0.0
		and outside_screen.y <= float(get_root().size.y)
	)

	var lines: PackedStringArray = []
	lines.append("inside_valid=%s" % str(inside_valid))
	lines.append("edge_valid=%s" % str(edge_valid))
	lines.append("outside_invalid=%s" % str(outside_invalid))
	lines.append("outside_rejects_build_area=%s" % str(outside_rejects_build_area))
	lines.append("outside_not_clamped_to_edge=%s" % str(outside_not_clamped_to_edge))
	lines.append("outside_screen_in_view=%s" % str(outside_screen_in_view))
	lines.append("outside_screen=%s" % str(outside_screen))
	lines.append("outside_reject_reason=%s" % String(outside_result.get("reject_reason", StringName())))

	var failed := (
		not inside_valid
		or not edge_valid
		or not outside_invalid
		or not outside_rejects_build_area
		or not outside_not_clamped_to_edge
		or not outside_screen_in_view
	)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_outside_build_area_rejects_placement_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(1 if failed else 0)
