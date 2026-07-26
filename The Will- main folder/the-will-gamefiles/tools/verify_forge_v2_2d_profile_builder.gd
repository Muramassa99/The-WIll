extends SceneTree

const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const PlayerToolProfileLibraryStateScript = preload("res://core/models/player_tool_profile_library_state.gd")

const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_2d_profile_builder_2026-07-26.txt"
const LIBRARY_PATH_PREFIX := "C:/WORKSPACE/godot_runs/verify_2d_profile_builder_library_state"
const EPSILON := 0.00001

var result_lines: PackedStringArray = []

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())

	var view_state: Resource = ForgeV2AuthoringStateScript.new()
	view_state.call("reset_new_draft", "Forge V2 2D Profile Builder Verify")
	view_state.call("reset_active_basic_profile_builder")
	var summary: Dictionary = view_state.call("get_status_summary") as Dictionary
	var profile_settings := _profile_settings(summary)
	var builder_settings := _builder_settings(profile_settings)
	if not bool(builder_settings.get("is_active", false)):
		_fail("2D profile builder was not active")
		return
	if (
		StringName(builder_settings.get("family", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	):
		_fail("2D profile builder did not report the basic profile family")
		return
	if not _basic_builder_uses_full_canvas(builder_settings):
		_fail("Basic builder still exposed a finite guide polygon, grid segment set, or snap-point set")
		return
	if StringName(builder_settings.get("temporary_guide_profile_id", StringName())) != StringName():
		_fail("Basic builder still reported a temporary finite guide profile")
		return
	var grid_step := float(builder_settings.get("guide_grid_step_meters", 0.0))
	if (
		grid_step <= 0.0
		or not is_equal_approx(
			grid_step,
			ForgeV2ProfileShapeLibraryScript.BASIC_BUILDER_GRID_STEP_METERS
		)
	):
		_fail("Basic builder did not report its analytical grid step")
		return

	view_state.call("set_active_basic_grid_snapping_enabled", false)
	view_state.call("set_active_profile_rotation_degrees", 0.0)
	summary = view_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	var original_control_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var original_metadata: Array = builder_settings.get("corner_metadata", []) as Array
	if original_control_points.size() != 4:
		_fail("default 2D builder did not start with 4 control points")
		return
	if (
		original_metadata.size() != original_control_points.size()
		or not _metadata_has_unique_stable_ids(original_metadata)
	):
		_fail("default 2D builder did not create one unique stable corner ID per point")
		return

	var moved_point := Vector2(-0.02, -0.02)
	if not bool(view_state.call("set_active_basic_control_point_2d_meters", 0, moved_point)):
		_fail("moving a valid 2D control point was rejected")
		return
	summary = view_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	var edited_control_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	if edited_control_points.size() != original_control_points.size():
		_fail("moving one 2D control point changed the control point count")
		return
	if edited_control_points[0].distance_to(moved_point) > EPSILON:
		_fail("moved 2D control point did not stay where it was placed")
		return
	for point_index in range(1, edited_control_points.size()):
		if edited_control_points[point_index].distance_to(original_control_points[point_index]) > EPSILON:
			_fail("moving one 2D control point displaced another control point")
			return
	if not _packed_points_match(
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
		edited_control_points
	):
		_fail("sharp 2D blue profile polygon did not follow its yellow control points")
		return

	var anchor_local := Vector2(0.005, 0.0)
	view_state.call("set_active_profile_anchor_2d_meters", anchor_local)
	summary = view_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	if _preview_anchor(profile_settings).distance_to(anchor_local) > EPSILON:
		_fail("2D anchor did not stay at the requested unrotated position")
		return
	if (
		(builder_settings.get("base_anchor_2d_meters", Vector2.ZERO) as Vector2)
		.distance_to(anchor_local) > EPSILON
	):
		_fail("2D anchor local storage did not match the requested unrotated position")
		return

	view_state.call("set_active_profile_rotation_degrees", 90.0)
	summary = view_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	var rotated_control_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var expected_rotated_control_points := _rotate_points(edited_control_points, 90.0)
	if not _packed_points_match(rotated_control_points, expected_rotated_control_points):
		_fail("2D control points did not rotate with the profile")
		return
	if not _packed_points_match(
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
		expected_rotated_control_points
	):
		_fail("2D blue profile polygon did not rotate with its yellow points")
		return
	var expected_rotated_anchor := anchor_local.rotated(deg_to_rad(90.0))
	if _preview_anchor(profile_settings).distance_to(expected_rotated_anchor) > EPSILON:
		_fail("2D red anchor did not rotate with the profile")
		return
	if not _basic_builder_uses_full_canvas(builder_settings):
		_fail("rotating Basic builder reintroduced finite guide data")
		return

	view_state.call("set_active_basic_grid_snapping_enabled", true)
	var off_grid_point := Vector2(0.3417, -0.2179)
	var expected_snapped_point: Vector2 = ForgeV2ProfileShapeLibraryScript.snap_point_to_grid(
		off_grid_point,
		grid_step,
		90.0
	)
	if not bool(view_state.call(
		"set_active_basic_control_point_2d_meters",
		0,
		off_grid_point
	)):
		_fail("analytical grid rejected an unrestricted full-canvas point")
		return
	summary = view_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	if not bool(builder_settings.get("grid_snapping_enabled", false)):
		_fail("2D analytical grid snapping did not enable")
		return
	var snapped_preview_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var snapped_base_points: PackedVector2Array = builder_settings.get(
		"base_control_points_2d_meters",
		PackedVector2Array()
	)
	if (
		snapped_preview_points.is_empty()
		or snapped_preview_points[0].distance_to(expected_snapped_point) > EPSILON
	):
		_fail("Basic point did not analytically snap in rotated preview space")
		return
	var expected_snapped_base := expected_snapped_point.rotated(deg_to_rad(-90.0))
	if (
		snapped_base_points.is_empty()
		or snapped_base_points[0].distance_to(expected_snapped_base) > EPSILON
	):
		_fail("analytically snapped Basic point was not stored in base space")
		return
	if not _point_is_grid_aligned(snapped_base_points[0], grid_step):
		_fail("analytically snapped Basic point did not land on the base grid lattice")
		return
	if maxf(absf(snapped_preview_points[0].x), absf(snapped_preview_points[0].y)) < 0.1:
		_fail("Basic point was still constrained to the former finite Hex 24 area")
		return
	if not _basic_builder_uses_full_canvas(builder_settings):
		_fail("analytical snapping unexpectedly generated finite guide data")
		return

	var topology_state: Resource = ForgeV2AuthoringStateScript.new()
	topology_state.call("reset_new_draft", "Forge V2 Basic Topology Verify")
	topology_state.call("reset_active_basic_profile_builder")
	topology_state.call("set_active_basic_grid_snapping_enabled", false)
	topology_state.call("set_active_profile_rotation_degrees", 0.0)
	summary = topology_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	var topology_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var topology_metadata: Array = builder_settings.get("corner_metadata", []) as Array
	var original_corner_ids := _corner_ids(topology_metadata)
	if (
		topology_points.size() != 4
		or original_corner_ids.size() != 4
		or not _metadata_has_unique_stable_ids(topology_metadata)
	):
		_fail("Basic topology did not start with four stable corners")
		return

	var fillet_corner_id: StringName = original_corner_ids[2]
	var fillet_settings: Dictionary = topology_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if (
		bool(fillet_settings.get("has_fillet", true))
		or StringName(fillet_settings.get("status", StringName()))
		!= &"sharp_missing_radius"
	):
		_fail("Basic corner did not begin as an explicit sharp corner")
		return
	if not bool(topology_state.call("add_active_basic_corner_fillet", fillet_corner_id)):
		_fail("adding the default Basic corner fillet failed")
		return
	if bool(topology_state.call("add_active_basic_corner_fillet", fillet_corner_id)):
		_fail("adding a duplicate Basic corner fillet unexpectedly succeeded")
		return
	fillet_settings = topology_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if (
		not bool(fillet_settings.get("has_fillet", false))
		or not is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_DEFAULT_METERS
		)
		or StringName(fillet_settings.get("status", StringName())) != &"fillet_convex"
		or float(fillet_settings.get("effective_radius_meters", 0.0)) <= 0.0
	):
		_fail("default Basic corner fillet did not resolve as a convex rounded corner")
		return
	summary = topology_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	if (
		not bool(builder_settings.get("rounded_enabled", false))
		or (
			profile_settings.get("preview_polygon_2d_meters", PackedVector2Array())
			as PackedVector2Array
		).size() <= topology_points.size()
	):
		_fail("default fillet did not expand the preview polygon")
		return

	var edited_fillet_radius := 0.02
	if not bool(topology_state.call(
		"set_active_basic_corner_fillet_radius",
		fillet_corner_id,
		edited_fillet_radius
	)):
		_fail("editing the Basic corner fillet radius failed")
		return
	fillet_settings = topology_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if (
		not is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			edited_fillet_radius
		)
		or float(fillet_settings.get("effective_radius_meters", 0.0)) <= 0.0
	):
		_fail("edited Basic corner fillet radius was not retained")
		return

	summary = topology_state.call("get_status_summary") as Dictionary
	builder_settings = _builder_settings(_profile_settings(summary))
	topology_points = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var first_segment_midpoint := (
		topology_points[0] + topology_points[1]
	) * 0.5
	var first_segment_direction := topology_points[1] - topology_points[0]
	var arbitrary_first_click := (
		first_segment_midpoint
		+ Vector2(-first_segment_direction.y, first_segment_direction.x).normalized()
		* 0.009
	)
	var inserted_corner_id: StringName = topology_state.call(
		"insert_active_basic_control_point_on_segment",
		original_corner_ids[0],
		arbitrary_first_click
	)
	if inserted_corner_id == StringName():
		_fail("arbitrary point insertion on a Basic segment failed")
		return
	summary = topology_state.call("get_status_summary") as Dictionary
	builder_settings = _builder_settings(_profile_settings(summary))
	topology_points = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	topology_metadata = builder_settings.get("corner_metadata", []) as Array
	var ids_after_first_insert := _corner_ids(topology_metadata)
	var expected_ids_after_first_insert: Array[StringName] = [
		original_corner_ids[0],
		inserted_corner_id,
		original_corner_ids[1],
		original_corner_ids[2],
		original_corner_ids[3],
	]
	if (
		topology_points.size() != 5
		or not _string_name_arrays_match(
			ids_after_first_insert,
			expected_ids_after_first_insert
		)
		or topology_points[1].distance_to(first_segment_midpoint) > EPSILON
		or not _metadata_has_unique_stable_ids(topology_metadata)
	):
		_fail("arbitrary Basic insertion did not project onto the segment with stable ordering")
		return
	fillet_settings = topology_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if (
		int(fillet_settings.get("point_index", -1)) != 3
		or not is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			edited_fillet_radius
		)
	):
		_fail("existing fillet metadata did not follow its stable corner after insertion")
		return

	var closing_start_index := ids_after_first_insert.find(original_corner_ids[3])
	var closing_segment_midpoint := (
		topology_points[closing_start_index] + topology_points[0]
	) * 0.5
	var closing_segment_direction := topology_points[0] - topology_points[closing_start_index]
	var arbitrary_closing_click := (
		closing_segment_midpoint
		+ Vector2(-closing_segment_direction.y, closing_segment_direction.x).normalized()
		* 0.007
	)
	var closing_corner_id: StringName = topology_state.call(
		"insert_active_basic_control_point_on_segment",
		original_corner_ids[3],
		arbitrary_closing_click
	)
	if closing_corner_id == StringName():
		_fail("arbitrary point insertion on the closing Basic segment failed")
		return
	summary = topology_state.call("get_status_summary") as Dictionary
	builder_settings = _builder_settings(_profile_settings(summary))
	topology_points = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	topology_metadata = builder_settings.get("corner_metadata", []) as Array
	var ids_after_closing_insert := _corner_ids(topology_metadata)
	var expected_ids_after_closing_insert: Array[StringName] = [
		original_corner_ids[0],
		inserted_corner_id,
		original_corner_ids[1],
		original_corner_ids[2],
		original_corner_ids[3],
		closing_corner_id,
	]
	if (
		topology_points.size() != 6
		or not _string_name_arrays_match(
			ids_after_closing_insert,
			expected_ids_after_closing_insert
		)
		or topology_points[5].distance_to(closing_segment_midpoint) > EPSILON
		or not _metadata_has_unique_stable_ids(topology_metadata)
	):
		_fail("closing-edge insertion did not append a stable projected Basic corner")
		return

	if not bool(topology_state.call(
		"remove_active_basic_control_point",
		inserted_corner_id
	)):
		_fail("removing an inserted Basic point by stable corner ID failed")
		return
	if bool(topology_state.call(
		"remove_active_basic_control_point",
		inserted_corner_id
	)):
		_fail("removing the same Basic point twice unexpectedly succeeded")
		return
	summary = topology_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	topology_points = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	topology_metadata = builder_settings.get("corner_metadata", []) as Array
	var ids_after_remove := _corner_ids(topology_metadata)
	var expected_ids_after_remove: Array[StringName] = [
		original_corner_ids[0],
		original_corner_ids[1],
		original_corner_ids[2],
		original_corner_ids[3],
		closing_corner_id,
	]
	if (
		topology_points.size() != 5
		or not _string_name_arrays_match(ids_after_remove, expected_ids_after_remove)
		or not _metadata_has_unique_stable_ids(topology_metadata)
	):
		_fail("Basic remove did not preserve all remaining stable corner identities")
		return
	fillet_settings = topology_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if (
		int(fillet_settings.get("point_index", -1)) != 2
		or not is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			edited_fillet_radius
		)
	):
		_fail("fillet metadata did not remain attached to its corner after remove")
		return

	if not bool(topology_state.call(
		"remove_active_basic_corner_fillet",
		fillet_corner_id
	)):
		_fail("removing an existing Basic corner fillet failed")
		return
	if bool(topology_state.call(
		"remove_active_basic_corner_fillet",
		fillet_corner_id
	)):
		_fail("removing the same Basic corner fillet twice unexpectedly succeeded")
		return
	fillet_settings = topology_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	summary = topology_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	if (
		bool(fillet_settings.get("has_fillet", true))
		or StringName(fillet_settings.get("status", StringName()))
		!= &"sharp_missing_radius"
		or bool(builder_settings.get("rounded_enabled", true))
		or not _packed_points_match(
			profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
			topology_points
		)
	):
		_fail("removing the fillet did not restore the all-sharp Basic polygon")
		return

	var minimum_state: Resource = ForgeV2AuthoringStateScript.new()
	minimum_state.call("reset_new_draft", "Forge V2 Basic Minimum Verify")
	minimum_state.call("reset_active_basic_profile_builder")
	summary = minimum_state.call("get_status_summary") as Dictionary
	builder_settings = _builder_settings(_profile_settings(summary))
	var minimum_metadata: Array = builder_settings.get("corner_metadata", []) as Array
	var minimum_ids := _corner_ids(minimum_metadata)
	if (
		minimum_ids.size() != 4
		or not bool(minimum_state.call(
			"remove_active_basic_control_point",
			minimum_ids[0]
		))
	):
		_fail("Basic topology could not reduce from four points to its three-point minimum")
		return
	if bool(minimum_state.call(
		"remove_active_basic_control_point",
		minimum_ids[1]
	)):
		_fail("Basic topology removed a point below its three-point minimum")
		return
	summary = minimum_state.call("get_status_summary") as Dictionary
	builder_settings = _builder_settings(_profile_settings(summary))
	var minimum_points: PackedVector2Array = builder_settings.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	minimum_metadata = builder_settings.get("corner_metadata", []) as Array
	if (
		minimum_points.size() != 3
		or minimum_metadata.size() != 3
		or not _metadata_has_unique_stable_ids(minimum_metadata)
	):
		_fail("failed remove below minimum changed three-point Basic state")
		return

	if not bool(topology_state.call("add_active_basic_corner_fillet", fillet_corner_id)):
		_fail("re-adding a Basic fillet for persistence coverage failed")
		return
	var persisted_fillet_radius := 0.012
	if not bool(topology_state.call(
		"set_active_basic_corner_fillet_radius",
		fillet_corner_id,
		persisted_fillet_radius
	)):
		_fail("editing the persisted Basic fillet radius failed")
		return
	topology_state.call("set_active_basic_grid_snapping_enabled", true)
	summary = topology_state.call("get_status_summary") as Dictionary
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	var persisted_points: PackedVector2Array = builder_settings.get(
		"base_control_points_2d_meters",
		PackedVector2Array()
	)
	var persisted_metadata: Array = builder_settings.get("corner_metadata", []) as Array
	var persisted_preview_polygon: PackedVector2Array = profile_settings.get(
		"preview_polygon_2d_meters",
		PackedVector2Array()
	)
	var persisted_next_corner_serial := int(
		topology_state.get("active_basic_next_corner_serial")
	)

	var profile_library: Resource = PlayerToolProfileLibraryStateScript.new()
	var library_path := "%s_%s.tres" % [
		LIBRARY_PATH_PREFIX,
		str(Time.get_unix_time_from_system()).replace(".", "_")
	]
	profile_library.set("save_file_path", library_path)
	var preset_data: Dictionary = topology_state.call(
		"build_active_tool_profile_preset_data",
		""
	) as Dictionary
	if (
		StringName(preset_data.get("family", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
	):
		_fail("2D profile preset data was not saved as basic family")
		return
	var saved_first: Dictionary = profile_library.call(
		"save_profile",
		preset_data,
		""
	) as Dictionary
	var saved_second: Dictionary = profile_library.call(
		"save_profile",
		preset_data,
		""
	) as Dictionary
	if String(saved_first.get("label", "")) != "tool profile 1":
		_fail("first default saved 2D profile name was not tool profile 1")
		return
	if String(saved_second.get("label", "")) != "tool profile 2":
		_fail("second default saved 2D profile name was not tool profile 2")
		return

	var disk_library: Resource = ResourceLoader.load(
		library_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if disk_library == null:
		_fail("saved Basic profile library could not be loaded from disk")
		return
	var reloaded_saved_second: Dictionary = disk_library.call(
		"get_saved_profile",
		StringName(saved_second.get("profile_id", StringName()))
	) as Dictionary
	if reloaded_saved_second.is_empty():
		_fail("second Basic profile was missing after disk reload")
		return
	var reloaded_points: PackedVector2Array = reloaded_saved_second.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var reloaded_metadata: Array = reloaded_saved_second.get(
		"basic_corner_metadata",
		[]
	) as Array
	if (
		not _packed_points_match(reloaded_points, persisted_points)
		or not _metadata_arrays_match(reloaded_metadata, persisted_metadata)
		or int(reloaded_saved_second.get("basic_next_corner_serial", 0))
		!= persisted_next_corner_serial
		or not bool(reloaded_saved_second.get("grid_snapping_enabled", false))
	):
		_fail("Basic points, corner metadata, serial, or grid state changed on disk roundtrip")
		return

	if not bool(profile_library.call(
		"remove_profile",
		StringName(saved_first.get("profile_id", StringName()))
	)):
		_fail("first saved 2D profile did not remove")
		return
	var saved_third: Dictionary = profile_library.call(
		"save_profile",
		preset_data,
		""
	) as Dictionary
	if String(saved_third.get("label", "")) != "tool profile 1":
		_fail("default saved 2D profile did not reuse removed profile 1 name")
		return

	var applied_state: Resource = ForgeV2AuthoringStateScript.new()
	applied_state.call("reset_new_draft", "Forge V2 Basic Reload Apply Verify")
	applied_state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_HANDLES)
	if not bool(applied_state.call(
		"apply_tool_profile_preset",
		reloaded_saved_second
	)):
		_fail("disk-reloaded 2D profile did not apply from handle tool")
		return
	summary = applied_state.call("get_status_summary") as Dictionary
	if (
		StringName(summary.get("active_tool", StringName()))
		!= ForgeV2AuthoringStateScript.TOOL_VOLUME_STROKE
	):
		_fail("applying saved 2D profile from handles did not return to the volume stroke tool")
		return
	profile_settings = _profile_settings(summary)
	builder_settings = _builder_settings(profile_settings)
	var applied_points: PackedVector2Array = builder_settings.get(
		"base_control_points_2d_meters",
		PackedVector2Array()
	)
	var applied_metadata: Array = builder_settings.get("corner_metadata", []) as Array
	if (
		StringName(profile_settings.get("profile_id", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.PROFILE_2D_BUILDER
		or StringName(builder_settings.get("family", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC
		or not _packed_points_match(applied_points, persisted_points)
		or not _metadata_arrays_match(applied_metadata, persisted_metadata)
		or not _packed_points_match(
			profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
			persisted_preview_polygon
		)
		or int(applied_state.get("active_basic_next_corner_serial"))
		!= persisted_next_corner_serial
		or not bool(builder_settings.get("grid_snapping_enabled", false))
	):
		_fail("applying disk-reloaded Basic profile did not restore its full builder state")
		return
	fillet_settings = applied_state.call(
		"get_active_basic_corner_fillet_settings",
		fillet_corner_id
	) as Dictionary
	if (
		not bool(fillet_settings.get("has_fillet", false))
		or not is_equal_approx(
			float(fillet_settings.get("radius_meters", 0.0)),
			persisted_fillet_radius
		)
		or float(fillet_settings.get("effective_radius_meters", 0.0)) <= 0.0
	):
		_fail("disk-reloaded Basic fillet did not remain attached to its stable corner")
		return

	applied_state.call("set_active_tool_id", ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE)
	if not bool(applied_state.call(
		"apply_tool_profile_preset",
		reloaded_saved_second
	)):
		_fail("disk-reloaded 2D profile did not apply from spline tool")
		return
	summary = applied_state.call("get_status_summary") as Dictionary
	if (
		StringName(summary.get("active_tool", StringName()))
		!= ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE
	):
		_fail("applying saved 2D profile from spline did not preserve the spline tool")
		return

	var invalid_raw_polygon := PackedVector2Array([
		Vector2(-0.02, -0.02),
		Vector2(0.02, 0.02),
		Vector2(-0.02, 0.02),
		Vector2(0.02, -0.02),
	])
	var invalid_raw_metadata: Array = [
		{
			"corner_id": &"fallback_corner_0",
			"radius_meters": ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_DEFAULT_METERS,
		},
		{"corner_id": &"fallback_corner_1"},
		{"corner_id": &"fallback_corner_2"},
		{"corner_id": &"fallback_corner_3"},
	]
	var fallback_geometry: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.resolve_basic_builder_fillet_geometry(
			invalid_raw_polygon,
			invalid_raw_metadata
		)
	)
	var fallback_results: Array = fallback_geometry.get("corner_results", []) as Array
	var requested_fallback_result := _find_corner_result(
		fallback_results,
		&"fallback_corner_0"
	)
	if (
		bool(fallback_geometry.get("raw_polygon_valid", true))
		or not bool(fallback_geometry.get("used_all_sharp_fallback", false))
		or not _packed_points_match(
			fallback_geometry.get("polygon", PackedVector2Array()),
			invalid_raw_polygon
		)
		or StringName(requested_fallback_result.get("status", StringName()))
		!= &"sharp_invalid_raw_polygon"
		or float(requested_fallback_result.get("effective_radius_meters", -1.0))
		!= 0.0
		or not (
			requested_fallback_result.get("arc_points", PackedVector2Array())
			as PackedVector2Array
		).is_empty()
	):
		_fail("invalid Basic polygon did not safely fall back to all-sharp raw geometry")
		return

	var concave_polygon := PackedVector2Array([
		Vector2(-0.04, -0.04),
		Vector2(0.04, -0.04),
		Vector2(0.04, 0.04),
		Vector2(0.0, 0.0),
		Vector2(-0.04, 0.04),
	])
	var concave_metadata: Array = [
		{"corner_id": &"concave_corner_0"},
		{"corner_id": &"concave_corner_1"},
		{"corner_id": &"concave_corner_2"},
		{
			"corner_id": &"concave_corner_3",
			"radius_meters": 0.003,
		},
		{"corner_id": &"concave_corner_4"},
	]
	var concave_geometry: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.resolve_basic_builder_fillet_geometry(
			concave_polygon,
			concave_metadata
		)
	)
	var concave_results: Array = concave_geometry.get("corner_results", []) as Array
	var concave_corner_result := _find_corner_result(
		concave_results,
		&"concave_corner_3"
	)
	var concave_arc: PackedVector2Array = concave_corner_result.get(
		"arc_points",
		PackedVector2Array()
	)
	var resolved_concave_polygon: PackedVector2Array = concave_geometry.get(
		"polygon",
		PackedVector2Array()
	)
	if (
		not bool(concave_geometry.get("raw_polygon_valid", false))
		or not bool(concave_geometry.get("output_valid", false))
		or bool(concave_geometry.get("used_all_sharp_fallback", true))
		or StringName(concave_corner_result.get("status", StringName()))
		!= &"fillet_concave"
		or float(concave_corner_result.get("effective_radius_meters", 0.0)) <= 0.0
		or concave_arc.is_empty()
		or resolved_concave_polygon.size() <= concave_polygon.size()
	):
		_fail("valid reflex Basic corner did not resolve to a nonempty concave fillet")
		return

	var budget_polygon := PackedVector2Array([
		Vector2(-0.02, -0.02),
		Vector2(0.02, -0.02),
		Vector2(0.02, 0.02),
		Vector2(-0.02, 0.02),
	])
	var budget_metadata: Array = [
		{
			"corner_id": &"budget_corner_0",
			"radius_meters": ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS,
		},
		{
			"corner_id": &"budget_corner_1",
			"radius_meters": ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS,
		},
		{"corner_id": &"budget_corner_2"},
		{"corner_id": &"budget_corner_3"},
	]
	var budget_geometry: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.resolve_basic_builder_fillet_geometry(
			budget_polygon,
			budget_metadata
		)
	)
	var budget_results: Array = budget_geometry.get("corner_results", []) as Array
	var budget_corner_0 := _find_corner_result(
		budget_results,
		&"budget_corner_0"
	)
	var budget_corner_1 := _find_corner_result(
		budget_results,
		&"budget_corner_1"
	)
	var budget_effective_radius_0 := float(
		budget_corner_0.get("effective_radius_meters", 0.0)
	)
	var budget_effective_radius_1 := float(
		budget_corner_1.get("effective_radius_meters", 0.0)
	)
	var shared_edge_length := budget_polygon[0].distance_to(budget_polygon[1])
	var shared_effective_tangent_use := (
		_effective_corner_tangent_use(
			budget_polygon,
			0,
			budget_effective_radius_0
		)
		+ _effective_corner_tangent_use(
			budget_polygon,
			1,
			budget_effective_radius_1
		)
	)
	var shared_edge_budget := (
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_EDGE_BUDGET_RATIO
		* shared_edge_length
	)
	if (
		not bool(budget_geometry.get("output_valid", false))
		or bool(budget_geometry.get("used_all_sharp_fallback", true))
		or StringName(budget_corner_0.get("status", StringName()))
		!= &"fillet_convex"
		or StringName(budget_corner_1.get("status", StringName()))
		!= &"fillet_convex"
		or budget_effective_radius_0 <= 0.0
		or budget_effective_radius_1 <= 0.0
		or budget_effective_radius_0
		>= ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
		or budget_effective_radius_1
		>= ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
		or shared_effective_tangent_use > shared_edge_budget + EPSILON
		or not is_equal_approx(shared_effective_tangent_use, shared_edge_budget)
	):
		_fail("adjacent large Basic fillets did not share their edge within the 99% budget")
		return

	var clamp_state: Resource = ForgeV2AuthoringStateScript.new()
	clamp_state.call("reset_new_draft", "Forge V2 Basic Fillet Clamp Verify")
	clamp_state.call("reset_active_basic_profile_builder")
	summary = clamp_state.call("get_status_summary") as Dictionary
	builder_settings = _builder_settings(_profile_settings(summary))
	var clamp_metadata: Array = builder_settings.get("corner_metadata", []) as Array
	var clamp_corner_ids := _corner_ids(clamp_metadata)
	if (
		clamp_corner_ids.is_empty()
		or not bool(clamp_state.call(
			"add_active_basic_corner_fillet",
			clamp_corner_ids[0]
		))
		or not bool(clamp_state.call(
			"set_active_basic_corner_fillet_radius",
			clamp_corner_ids[0],
			0.0001
		))
	):
		_fail("Basic fillet lower-clamp setup failed")
		return
	var clamp_settings: Dictionary = clamp_state.call(
		"get_active_basic_corner_fillet_settings",
		clamp_corner_ids[0]
	) as Dictionary
	if not is_equal_approx(
		float(clamp_settings.get("radius_meters", 0.0)),
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_MIN_METERS
	):
		_fail("Basic fillet input did not clamp to the 0.001m minimum")
		return
	if not bool(clamp_state.call(
		"set_active_basic_corner_fillet_radius",
		clamp_corner_ids[0],
		0.9
	)):
		_fail("Basic fillet upper-clamp edit failed")
		return
	clamp_settings = clamp_state.call(
		"get_active_basic_corner_fillet_settings",
		clamp_corner_ids[0]
	) as Dictionary
	if not is_equal_approx(
		float(clamp_settings.get("radius_meters", 0.0)),
		ForgeV2ProfileShapeLibraryScript.BASIC_FILLET_RADIUS_INPUT_MAX_METERS
	):
		_fail("Basic fillet input did not clamp to the 0.3m maximum")
		return

	result_lines.append("ok=true")
	result_lines.append("basic_full_canvas=true")
	result_lines.append("analytical_grid_snap=true")
	result_lines.append("control_points_after_topology=%d" % persisted_points.size())
	result_lines.append("stable_corner_metadata=true")
	result_lines.append("fillet_add_edit_remove=true")
	result_lines.append("fillet_concave=true")
	result_lines.append("fillet_shared_edge_budget=true")
	result_lines.append("fillet_input_clamp=true")
	result_lines.append("minimum_control_points=%d" % minimum_points.size())
	result_lines.append("save_load_roundtrip=true")
	result_lines.append("sharp_fallback=true")
	result_lines.append("saved_first=%s" % String(saved_first.get("label", "")))
	result_lines.append("saved_second=%s" % String(saved_second.get("label", "")))
	result_lines.append("saved_third=%s" % String(saved_third.get("label", "")))
	result_lines.append("library_path=%s" % library_path)
	_write_results()
	quit(0)

func _profile_settings(summary: Dictionary) -> Dictionary:
	return summary.get("active_profile_settings", {}) as Dictionary

func _builder_settings(profile_settings: Dictionary) -> Dictionary:
	return profile_settings.get("profile_builder", {}) as Dictionary

func _basic_builder_uses_full_canvas(builder_settings: Dictionary) -> bool:
	var guide_polygon: PackedVector2Array = builder_settings.get(
		"guide_polygon_2d_meters",
		PackedVector2Array()
	)
	var guide_grid_segments: Array = builder_settings.get(
		"guide_grid_segments_2d_meters",
		[]
	) as Array
	var guide_snap_points: PackedVector2Array = builder_settings.get(
		"guide_grid_snap_points_2d_meters",
		PackedVector2Array()
	)
	return (
		guide_polygon.is_empty()
		and guide_grid_segments.is_empty()
		and guide_snap_points.is_empty()
	)

func _preview_anchor(profile_settings: Dictionary) -> Vector2:
	return Vector2(
		float(profile_settings.get("anchor_x_meters", 0.0)),
		float(profile_settings.get("anchor_y_meters", 0.0))
	)

func _corner_ids(metadata_array: Array) -> Array[StringName]:
	var corner_ids: Array[StringName] = []
	for metadata_variant: Variant in metadata_array:
		if not metadata_variant is Dictionary:
			corner_ids.append(StringName())
			continue
		var metadata := metadata_variant as Dictionary
		corner_ids.append(StringName(metadata.get("corner_id", StringName())))
	return corner_ids

func _metadata_has_unique_stable_ids(metadata_array: Array) -> bool:
	var corner_ids := _corner_ids(metadata_array)
	var used_ids: Dictionary = {}
	for corner_id: StringName in corner_ids:
		if corner_id == StringName() or used_ids.has(corner_id):
			return false
		used_ids[corner_id] = true
	return true

func _metadata_arrays_match(first_metadata: Array, second_metadata: Array) -> bool:
	if first_metadata.size() != second_metadata.size():
		return false
	for metadata_index in range(first_metadata.size()):
		if (
			not first_metadata[metadata_index] is Dictionary
			or not second_metadata[metadata_index] is Dictionary
		):
			return false
		var first_corner := first_metadata[metadata_index] as Dictionary
		var second_corner := second_metadata[metadata_index] as Dictionary
		if (
			StringName(first_corner.get("corner_id", StringName()))
			!= StringName(second_corner.get("corner_id", StringName()))
		):
			return false
		if first_corner.has("radius_meters") != second_corner.has("radius_meters"):
			return false
		if (
			first_corner.has("radius_meters")
			and absf(
				float(first_corner.get("radius_meters", 0.0))
				- float(second_corner.get("radius_meters", 0.0))
			) > EPSILON
		):
			return false
	return true

func _string_name_arrays_match(
	first_names: Array[StringName],
	second_names: Array[StringName]
) -> bool:
	if first_names.size() != second_names.size():
		return false
	for name_index in range(first_names.size()):
		if first_names[name_index] != second_names[name_index]:
			return false
	return true

func _find_corner_result(
	corner_results: Array,
	corner_id: StringName
) -> Dictionary:
	for result_variant: Variant in corner_results:
		if not result_variant is Dictionary:
			continue
		var corner_result := result_variant as Dictionary
		if StringName(corner_result.get("corner_id", StringName())) == corner_id:
			return corner_result
	return {}

func _point_is_grid_aligned(point: Vector2, grid_step: float) -> bool:
	if grid_step <= 0.0:
		return false
	return (
		absf(point.x / grid_step - roundf(point.x / grid_step)) <= EPSILON
		and absf(point.y / grid_step - roundf(point.y / grid_step)) <= EPSILON
	)

func _effective_corner_tangent_use(
	points: PackedVector2Array,
	point_index: int,
	effective_radius: float
) -> float:
	if (
		points.size() < 3
		or point_index < 0
		or point_index >= points.size()
		or effective_radius <= 0.0
	):
		return 0.0
	var previous_point := points[
		(point_index - 1 + points.size()) % points.size()
	]
	var current_point := points[point_index]
	var next_point := points[(point_index + 1) % points.size()]
	var incoming_direction := (current_point - previous_point).normalized()
	var outgoing_direction := (next_point - current_point).normalized()
	var signed_turn := atan2(
		incoming_direction.cross(outgoing_direction),
		incoming_direction.dot(outgoing_direction)
	)
	return effective_radius * tan(absf(signed_turn) * 0.5)

func _packed_points_match(
	first_points: PackedVector2Array,
	second_points: PackedVector2Array
) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if first_points[point_index].distance_to(second_points[point_index]) > EPSILON:
			return false
	return true

func _rotate_points(
	points: PackedVector2Array,
	rotation_degrees: float
) -> PackedVector2Array:
	var rotated := PackedVector2Array()
	for point: Vector2 in points:
		rotated.append(point.rotated(deg_to_rad(rotation_degrees)))
	return rotated

func _fail(message: String) -> void:
	result_lines.append("ok=false")
	result_lines.append("error=%s" % message)
	_write_results()
	push_error(message)
	quit(1)

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines))
		file.close()
