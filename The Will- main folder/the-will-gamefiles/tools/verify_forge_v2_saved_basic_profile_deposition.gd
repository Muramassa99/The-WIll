extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2LayerDataScript = preload(
	"res://runtime/forge_v2/forge_v2_layer_data.gd"
)
const ForgeV2MaterialVolumeResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_material_volume_resolver.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_saved_basic_profile_deposition_2026-07-31.txt"
)
const PROFILE_LIBRARY_PATH_PREFIX := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_saved_basic_profile_deposition_library"
)
const AUTHORING_STATE_PATH_PREFIX := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_saved_basic_profile_authoring_state"
)
const EPSILON := 0.000001

var result_lines: PackedStringArray = []

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())

	var centered_square := PackedVector2Array([
		Vector2(-0.02, -0.02),
		Vector2(0.02, -0.02),
		Vector2(0.02, 0.02),
		Vector2(-0.02, 0.02),
	])
	var centered_contact := (
		ForgeV2ProfileShapeLibraryScript.resolve_profile_anchor_contact(
			centered_square,
			Vector2.ZERO
		)
	)
	if (
		not bool(centered_contact.get("valid", false))
		or not _vector2_close(
			centered_contact.get("point", Vector2.ZERO) as Vector2,
			Vector2(0.0, -0.02)
		)
		or not _vector2_close(
			centered_contact.get("direction", Vector2.ZERO) as Vector2,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
		)
	):
		_fail("centered square contact did not resolve to local 6 o'clock")
		return

	var centered_diamond := PackedVector2Array([
		Vector2(0.0, -0.02),
		Vector2(0.02, 0.0),
		Vector2(0.0, 0.02),
		Vector2(-0.02, 0.0),
	])
	var diamond_contact := (
		ForgeV2ProfileShapeLibraryScript.resolve_profile_anchor_contact(
			centered_diamond,
			Vector2.ZERO
		)
	)
	if (
		not bool(diamond_contact.get("valid", false))
		or not _vector2_close(
			diamond_contact.get("point", Vector2.ZERO) as Vector2,
			Vector2(-0.01, -0.01)
		)
	):
		_fail("equal-distance contact did not prefer bottom, then local left")
		return

	var source_profile := {
		"profile_id": &"verifier_saved_basic_profile",
		"id": &"verifier_saved_basic_profile",
		"label": "Verifier Fixed Profile",
		"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": centered_square,
		"polygon_2d_meters": _rotate_points(centered_square, 30.0),
		"base_anchor_2d_meters": Vector2(0.0, -0.02),
		"anchor_x_meters": 0.0,
		"anchor_y_meters": -0.02,
		"rotation_degrees": 30.0,
	}
	var compiled_profile := (
		ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data(
			source_profile
		)
	)
	var compiled_runtime: Dictionary = compiled_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	var compiled_anchor := compiled_profile.get(
		"base_anchor_2d_meters",
		Vector2.ZERO
	) as Vector2
	var deposition_polygon: PackedVector2Array = compiled_runtime.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	if (
		int(compiled_profile.get("record_schema_version", 0))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_RECORD_SCHEMA_VERSION
		or int(compiled_runtime.get("schema_version", 0))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_RUNTIME_SCHEMA_VERSION
		or StringName(compiled_runtime.get("rule_id", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_CONTACT_RULE_ID
		or StringName(compiled_runtime.get("coordinate_space", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_COORDINATE_SPACE
		or not bool(compiled_runtime.get("valid", false))
	):
		_fail("valid Basic profile did not compile with the current runtime contract")
		return
	if (
		compiled_anchor.distance_to(Vector2(0.0, -0.02)) <= EPSILON
		or float(compiled_runtime.get("contact_distance_meters", 0.0))
		+ ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_CONTACT_DISTANCE_EPSILON
		< ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
	):
		_fail("tangent anchor was not moved to the mandatory 0.5 mm inset")
		return
	var expected_deposition_polygon := PackedVector2Array()
	for point: Vector2 in centered_square:
		expected_deposition_polygon.append(point - compiled_anchor)
	if not _packed_vector2_arrays_match(
		deposition_polygon,
		expected_deposition_polygon
	):
		_fail("compiled deposition polygon was not stored anchor-relative")
		return

	var too_thin_polygon := PackedVector2Array([
		Vector2(-0.0004, -0.0004),
		Vector2(0.0004, -0.0004),
		Vector2(0.0004, 0.0004),
		Vector2(-0.0004, 0.0004),
	])
	var too_thin_profile := (
		ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data({
			"profile_id": &"too_thin_profile",
			"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
			"base_polygon_2d_meters": too_thin_polygon,
			"polygon_2d_meters": too_thin_polygon,
			"base_anchor_2d_meters": Vector2.ZERO,
		})
	)
	var too_thin_runtime: Dictionary = too_thin_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	if (
		ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			too_thin_profile
		)
		or StringName(too_thin_runtime.get("error", StringName()))
		!= &"anchor_clearance_unavailable"
	):
		_fail("profile without a 0.5 mm inset silently reduced the clearance")
		return

	var profile_library: Resource = PlayerToolProfileLibraryStateScript.new()
	var library_path := "%s_%s.tres" % [
		PROFILE_LIBRARY_PATH_PREFIX,
		str(Time.get_ticks_usec()),
	]
	profile_library.set("save_file_path", library_path)
	var saved_profile: Dictionary = profile_library.call(
		"save_profile",
		compiled_profile,
		"Verifier Fixed Profile"
	) as Dictionary
	var saved_profile_id := StringName(saved_profile.get(
		"profile_id",
		StringName()
	))
	if (
		saved_profile_id == StringName()
		or not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			saved_profile
		)
	):
		_fail("compiled Basic profile did not save as a usable library record")
		return
	var disk_library: Resource = ResourceLoader.load(
		library_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if disk_library == null:
		_fail("saved Basic profile library could not be reloaded")
		return
	var disk_profile: Dictionary = disk_library.call(
		"get_saved_profile",
		saved_profile_id
	) as Dictionary
	var disk_runtime: Dictionary = disk_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	if (
		not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			disk_profile
		)
		or not _packed_vector2_arrays_match(
			disk_runtime.get(
				"deposition_polygon_2d_meters",
				PackedVector2Array()
			) as PackedVector2Array,
			deposition_polygon
		)
		or not _vector2_close(
			disk_runtime.get(
				"contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2,
			compiled_runtime.get(
				"contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2
		)
	):
		_fail("compiled profile data changed during the disk roundtrip")
		return

	var builder_state: Resource = ForgeV2AuthoringStateScript.new()
	builder_state.call(
		"reset_new_draft",
		"Saved Basic Builder Fillet Chain Verify"
	)
	builder_state.call("reset_active_basic_profile_builder")
	var builder_metadata: Array = builder_state.get(
		"active_basic_corner_metadata"
	) as Array
	if (
		builder_metadata.is_empty()
		or not builder_metadata[0] is Dictionary
	):
		_fail("real 2D builder did not expose a corner for fillet setup")
		return
	var builder_fillet_corner_id := StringName(
		(builder_metadata[0] as Dictionary).get(
			"corner_id",
			StringName()
		)
	)
	if (
		builder_fillet_corner_id == StringName()
		or not bool(builder_state.call(
			"add_active_basic_corner_fillet",
			builder_fillet_corner_id
		))
	):
		_fail("real 2D builder could not add the verifier fillet")
		return
	var builder_preset: Dictionary = builder_state.call(
		"build_active_tool_profile_preset_data",
		"Verifier Builder Fillet"
	) as Dictionary
	var builder_runtime: Dictionary = builder_preset.get(
		"compiled_profile",
		{}
	) as Dictionary
	var builder_control_points: PackedVector2Array = builder_preset.get(
		"control_points_2d_meters",
		PackedVector2Array()
	)
	var builder_base_polygon: PackedVector2Array = builder_preset.get(
		"base_polygon_2d_meters",
		PackedVector2Array()
	)
	var builder_deposition_polygon: PackedVector2Array = builder_runtime.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	var builder_compiled_anchor := builder_preset.get(
		"base_anchor_2d_meters",
		Vector2.ZERO
	) as Vector2
	var expected_builder_deposition_polygon := PackedVector2Array()
	for point: Vector2 in builder_base_polygon:
		expected_builder_deposition_polygon.append(
			point - builder_compiled_anchor
		)
	if (
		not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			builder_preset
		)
		or builder_base_polygon.size() <= builder_control_points.size()
		or not _packed_vector2_arrays_match(
			builder_deposition_polygon,
			expected_builder_deposition_polygon
		)
	):
		_fail("real builder fillet was not compiled from its resolved outline")
		return
	var saved_builder_profile: Dictionary = profile_library.call(
		"save_profile",
		builder_preset,
		"Verifier Builder Fillet"
	) as Dictionary
	var saved_builder_profile_id := StringName(saved_builder_profile.get(
		"profile_id",
		StringName()
	))
	var builder_disk_library: Resource = ResourceLoader.load(
		library_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	var disk_builder_profile: Dictionary = {}
	if (
		builder_disk_library != null
		and builder_disk_library.has_method("get_saved_profile")
	):
		disk_builder_profile = builder_disk_library.call(
			"get_saved_profile",
			saved_builder_profile_id
		) as Dictionary
	var builder_shape_state: Resource = ForgeV2AuthoringStateScript.new()
	builder_shape_state.call(
		"reset_new_draft",
		"Saved Basic Builder Fillet Deposit Verify"
	)
	if (
		saved_builder_profile_id == StringName()
		or disk_builder_profile.is_empty()
		or not bool(builder_shape_state.call(
			"select_active_saved_basic_profile",
			disk_builder_profile
		))
	):
		_fail("builder-generated fillet profile did not reach Shape selection")
		return
	var builder_profile_body: Resource = builder_shape_state.call(
		"append_point_material_body",
		Vector3.ZERO,
		-1.0,
		-1.0,
		Vector3.UP,
		Vector3.DOWN
	) as Resource
	if (
		builder_profile_body == null
		or not bool(builder_shape_state.call(
			"append_point_to_material_body",
			StringName(builder_profile_body.get("body_id")),
			Vector3(0.05, 0.0, 0.0),
			0.0,
			false,
			Vector3.UP,
			Vector3.DOWN
		))
		or StringName(builder_profile_body.get("profile_id"))
		!= saved_builder_profile_id
		or not _packed_vector2_arrays_match(
			builder_profile_body.get(
				"profile_polygon_2d_meters"
			) as PackedVector2Array,
			builder_deposition_polygon
		)
		or (
			builder_profile_body.get(
				"profile_polygon_2d_meters"
			) as PackedVector2Array
		).size() <= builder_control_points.size()
	):
		_fail("builder fillet changed between Profiles, Shape, and deposition")
		return

	var legacy_library = PlayerToolProfileLibraryStateScript.new()
	var legacy_profile := source_profile.duplicate(true)
	legacy_profile.erase("record_schema_version")
	legacy_profile.erase("compiled_profile")
	legacy_library.saved_profiles.append(legacy_profile)
	if not bool(legacy_library.call("upgrade_saved_profiles_once")):
		_fail("legacy Basic profile was not upgraded")
		return
	var migrated_profiles: Array = legacy_library.get("saved_profiles") as Array
	if (
		migrated_profiles.size() != 1
		or not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			migrated_profiles[0] as Dictionary
		)
		or bool(legacy_library.call("upgrade_saved_profiles_once"))
	):
		_fail("Basic profile migration was not valid and one-shot")
		return

	var forged_current_profile := compiled_profile.duplicate(true)
	var forged_current_runtime: Dictionary = (
		forged_current_profile.get("compiled_profile", {}) as Dictionary
	).duplicate(true)
	forged_current_runtime["rule_id"] = &"forged_contact_rule"
	forged_current_runtime["coordinate_space"] = &"forged_coordinate_space"
	forged_current_runtime["contact_point_2d_meters"] = Vector2(9.0, 9.0)
	forged_current_runtime["contact_point_relative_2d_meters"] = Vector2.ZERO
	forged_current_runtime["contact_direction_2d"] = Vector2.ZERO
	forged_current_profile["compiled_profile"] = forged_current_runtime
	if ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
		forged_current_profile
	):
		_fail("forged current-schema runtime contract was accepted as valid")
		return
	var forged_current_library = PlayerToolProfileLibraryStateScript.new()
	forged_current_library.saved_profiles.append(
		forged_current_profile
	)
	if not bool(forged_current_library.call(
		"upgrade_saved_profiles_once"
	)):
		_fail("forged current-schema profile was not repaired")
		return
	var repaired_profiles: Array = forged_current_library.get(
		"saved_profiles"
	) as Array
	var repaired_profile: Dictionary = (
		repaired_profiles[0] as Dictionary
		if repaired_profiles.size() == 1
		else {}
	)
	var repaired_runtime: Dictionary = repaired_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	if (
		not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			repaired_profile
		)
		or StringName(repaired_runtime.get("rule_id", StringName()))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_CONTACT_RULE_ID
		or StringName(repaired_runtime.get(
			"coordinate_space",
			StringName()
		)) != ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_COORDINATE_SPACE
		or not _vector2_close(
			repaired_runtime.get(
				"contact_point_2d_meters",
				Vector2.ZERO
			) as Vector2,
			compiled_runtime.get(
				"contact_point_2d_meters",
				Vector2.ZERO
			) as Vector2
		)
		or not _vector2_close(
			repaired_runtime.get(
				"contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2,
			compiled_runtime.get(
				"contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2
		)
		or not _vector2_close(
			repaired_runtime.get(
				"contact_direction_2d",
				Vector2.ZERO
			) as Vector2,
			compiled_runtime.get(
				"contact_direction_2d",
				Vector2.ZERO
			) as Vector2
		)
		or bool(forged_current_library.call(
			"upgrade_saved_profiles_once"
		))
	):
		_fail("current-schema contract repair was not complete and one-shot")
		return

	var forged_snapshot_state: Resource = ForgeV2AuthoringStateScript.new()
	forged_snapshot_state.call(
		"reset_new_draft",
		"Forged Saved Basic Snapshot Repair Verify"
	)
	forged_snapshot_state.set(
		"active_basic_shape_source_id",
		ForgeV2AuthoringStateScript.BASIC_SHAPE_SOURCE_SAVED_PROFILE
	)
	forged_snapshot_state.set(
		"active_saved_basic_profile_id",
		StringName(forged_current_profile.get(
			"profile_id",
			StringName()
		))
	)
	forged_snapshot_state.set(
		"active_saved_basic_profile_data",
		forged_current_profile.duplicate(true)
	)
	var forged_snapshot_path := "%s_forged_snapshot_%s.tres" % [
		AUTHORING_STATE_PATH_PREFIX,
		str(Time.get_ticks_usec()),
	]
	if ResourceSaver.save(
		forged_snapshot_state,
		forged_snapshot_path
	) != OK:
		_fail("forged active Shape snapshot could not be persisted")
		return
	var repaired_snapshot_state: Resource = ResourceLoader.load(
		forged_snapshot_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if repaired_snapshot_state == null:
		_fail("forged active Shape snapshot could not be reloaded")
		return
	repaired_snapshot_state.call("normalize")
	var repaired_snapshot_profile: Dictionary = repaired_snapshot_state.get(
		"active_saved_basic_profile_data"
	) as Dictionary
	var repaired_snapshot_runtime: Dictionary = repaired_snapshot_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	if (
		StringName(repaired_snapshot_state.get(
			"active_basic_shape_source_id"
		)) != ForgeV2AuthoringStateScript.BASIC_SHAPE_SOURCE_SAVED_PROFILE
		or StringName(repaired_snapshot_state.get(
			"active_saved_basic_profile_id"
		)) != StringName(compiled_profile.get(
			"profile_id",
			StringName()
		))
		or not ForgeV2ProfileShapeLibraryScript.is_compiled_basic_profile_runtime_valid(
			repaired_snapshot_profile
		)
		or StringName(repaired_snapshot_runtime.get(
			"rule_id",
			StringName()
		)) != ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_CONTACT_RULE_ID
		or StringName(repaired_snapshot_runtime.get(
			"coordinate_space",
			StringName()
		)) != ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_COORDINATE_SPACE
		or not _vector2_close(
			repaired_snapshot_runtime.get(
				"contact_point_2d_meters",
				Vector2.ZERO
			) as Vector2,
			compiled_runtime.get(
				"contact_point_2d_meters",
				Vector2.ZERO
			) as Vector2
		)
		or not _vector2_close(
			repaired_snapshot_runtime.get(
				"contact_direction_2d",
				Vector2.ZERO
			) as Vector2,
			compiled_runtime.get(
				"contact_direction_2d",
				Vector2.ZERO
			) as Vector2
		)
	):
		_fail("authoring-state normalization cleared or retained a forged Shape snapshot")
		return

	var state: Resource = ForgeV2AuthoringStateScript.new()
	state.call("reset_new_draft", "Saved Basic Profile Authority Verify")
	if (
		StringName(state.get("active_basic_shape_source_id"))
		!= ForgeV2AuthoringStateScript.BASIC_SHAPE_SOURCE_PRIMITIVE
	):
		_fail("new Forge V2 draft did not default to primitive Shape authority")
		return
	if not bool(state.call(
		"select_active_saved_basic_profile",
		disk_profile
	)):
		_fail("explicit saved Basic Shape selection failed")
		return
	var selected_snapshot: Dictionary = (
		state.get("active_saved_basic_profile_data") as Dictionary
	).duplicate(true)
	var selected_runtime: Dictionary = selected_snapshot.get(
		"compiled_profile",
		{}
	) as Dictionary
	var selected_polygon: PackedVector2Array = selected_runtime.get(
		"deposition_polygon_2d_meters",
		PackedVector2Array()
	)
	var caller_runtime: Dictionary = disk_profile.get(
		"compiled_profile",
		{}
	) as Dictionary
	caller_runtime["deposition_polygon_2d_meters"] = PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT,
		Vector2.DOWN,
	])
	disk_profile["compiled_profile"] = caller_runtime
	disk_profile["label"] = "Caller Mutated"
	profile_library.call(
		"rename_profile",
		saved_profile_id,
		"Library Renamed"
	)
	profile_library.call("remove_profile", saved_profile_id)
	var retained_snapshot: Dictionary = (
		state.get("active_saved_basic_profile_data") as Dictionary
	)
	var retained_runtime: Dictionary = retained_snapshot.get(
		"compiled_profile",
		{}
	) as Dictionary
	if (
		String(retained_snapshot.get("label", ""))
		!= "Verifier Fixed Profile"
		or not _packed_vector2_arrays_match(
			retained_runtime.get(
				"deposition_polygon_2d_meters",
				PackedVector2Array()
			) as PackedVector2Array,
			selected_polygon
		)
	):
		_fail("active Shape did not retain its deep saved-profile snapshot")
		return

	var editor_profile := saved_profile.duplicate(true)
	editor_profile["profile_id"] = &"editor_only_profile"
	editor_profile["id"] = &"editor_only_profile"
	editor_profile["label"] = "Editor Only Profile"
	if not bool(state.call("apply_tool_profile_preset", editor_profile)):
		_fail("editor-only profile setup failed")
		return
	if (
		StringName(state.get("active_basic_shape_source_id"))
		!= ForgeV2AuthoringStateScript.BASIC_SHAPE_SOURCE_SAVED_PROFILE
		or StringName(state.get("active_saved_basic_profile_id"))
		!= saved_profile_id
		or not _packed_vector2_arrays_match(
			(
				state.get("active_saved_basic_profile_data") as Dictionary
			).get("compiled_profile", {})["deposition_polygon_2d_meters"]
			as PackedVector2Array,
			selected_polygon
		)
	):
		_fail("loading a profile into the editor changed active Shape authority")
		return

	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE
	)
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_HANDLES
	)
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_VOLUME_STROKE
	)
	if (
		StringName(state.get("active_saved_basic_profile_id"))
		!= saved_profile_id
		or not bool(state.call("is_saved_basic_profile_shape_active"))
	):
		_fail("saved Basic Shape did not persist across tool switching")
		return
	var authoring_state_path := "%s_%s.tres" % [
		AUTHORING_STATE_PATH_PREFIX,
		str(Time.get_ticks_usec()),
	]
	if ResourceSaver.save(state, authoring_state_path) != OK:
		_fail("active saved-profile Shape state could not be persisted")
		return
	var reloaded_state: Resource = ResourceLoader.load(
		authoring_state_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if reloaded_state == null:
		_fail("active saved-profile Shape state could not be reloaded")
		return
	reloaded_state.call("normalize")
	var reloaded_shape_data: Dictionary = reloaded_state.get(
		"active_saved_basic_profile_data"
	) as Dictionary
	var reloaded_shape_runtime: Dictionary = reloaded_shape_data.get(
		"compiled_profile",
		{}
	) as Dictionary
	if (
		StringName(reloaded_state.get("active_basic_shape_source_id"))
		!= ForgeV2AuthoringStateScript.BASIC_SHAPE_SOURCE_SAVED_PROFILE
		or StringName(reloaded_state.get("active_saved_basic_profile_id"))
		!= saved_profile_id
		or not _packed_vector2_arrays_match(
			reloaded_shape_runtime.get(
				"deposition_polygon_2d_meters",
				PackedVector2Array()
			) as PackedVector2Array,
			selected_polygon
		)
	):
		_fail("active saved-profile Shape authority changed on state roundtrip")
		return
	var protected_brush_radius := float(state.get(
		"active_brush_radius_meters"
	))
	state.call("set_brush_radius_meters", 0.2)
	if not is_equal_approx(
		float(state.get("active_brush_radius_meters")),
		protected_brush_radius
	):
		_fail("brush radius rescaled an active fixed saved profile")
		return
	var sample_radius := float(state.call(
		"get_active_deposition_sample_radius_meters"
	))
	var envelope_radius := float(state.call(
		"get_active_deposition_envelope_radius_meters"
	))
	var expected_sample_radius := maxf(
		float(selected_runtime.get(
			"contact_distance_meters",
			0.0
		)),
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
	)
	if (
		not is_equal_approx(sample_radius, expected_sample_radius)
		or sample_radius >= envelope_radius
	):
		_fail("fixed-profile path sampling still used the full bounding radius")
		return
	state.call(
		"set_active_primitive_id",
		ForgeV2AuthoringStateScript.DEFAULT_ACTIVE_PRIMITIVE_ID
	)
	state.call("set_brush_radius_meters", 0.2)
	if (
		StringName(state.get("active_basic_shape_source_id"))
		!= ForgeV2AuthoringStateScript.BASIC_SHAPE_SOURCE_PRIMITIVE
		or not (state.get("active_saved_basic_profile_data") as Dictionary).is_empty()
		or not is_equal_approx(
			float(state.get("active_brush_radius_meters")),
			0.2
		)
	):
		_fail("primitive selection did not restore primitive size authority")
		return

	var click_controller = ForgeV2StageControllerScript.new()
	var click_state: Resource = click_controller.call(
		"ensure_authoring_state",
		"Saved Basic Click Guard Verify"
	) as Resource
	if (
		not bool(click_controller.call(
			"select_active_saved_basic_profile",
			saved_profile
		))
		or StringName(click_controller.call(
			"begin_material_body_path",
			Vector3.ZERO,
			Vector3.UP,
			Vector3.DOWN
		)) == StringName()
	):
		click_controller.free()
		_fail("saved-profile click guard setup failed")
		return
	click_controller.call(
		"finish_material_body_path",
		Vector3.ZERO,
		true,
		Vector3.UP,
		Vector3.DOWN
	)
	if (
		int(click_state.call("get_pending_material_body_count")) != 0
		or int(click_state.call("get_committed_layer_count")) != 0
		or StringName(click_controller.call(
			"get_active_placement_body_id"
		)) != StringName()
		or StringName(click_state.get("selected_material_body_id"))
		!= StringName()
	):
		click_controller.free()
		_fail("click-only saved profile did not clear its zero-volume placement")
		return
	click_controller.free()

	if not bool(state.call(
		"select_active_saved_basic_profile",
		saved_profile
	)):
		_fail("saved Basic profile could not be reselected for Volume Stroke")
		return
	state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_VOLUME_STROKE
	)
	var current_material_id := StringName(state.get(
		"active_material_variant_id"
	))
	var alternate_material_id := StringName()
	var material_options: Array = state.call(
		"get_material_palette_options"
	) as Array
	for option_variant: Variant in material_options:
		if not option_variant is Dictionary:
			continue
		var option := option_variant as Dictionary
		var option_id := StringName(option.get("id", StringName()))
		if (
			option_id != StringName()
			and option_id != current_material_id
		):
			alternate_material_id = option_id
			break
	if alternate_material_id == StringName():
		_fail("material catalog did not expose a non-default verifier material")
		return
	state.call(
		"set_active_material_variant_id",
		alternate_material_id
	)
	state.call(
		"set_placement_policy",
		ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY
	)
	var volume_body: Resource = state.call(
		"append_point_material_body",
		Vector3.ZERO,
		0.35,
		-1.0,
		Vector3.UP,
		Vector3.DOWN
	) as Resource
	if volume_body == null:
		_fail("saved Basic Volume Stroke did not create a material body")
		return
	var volume_body_id := StringName(volume_body.get("body_id"))
	if not bool(state.call(
		"append_point_to_material_body",
		volume_body_id,
		Vector3(0.075, 0.0, 0.0),
		0.0,
		false,
		Vector3.BACK,
		Vector3.FORWARD
	)):
		_fail("saved Basic Volume Stroke did not accept a second path point")
		return
	volume_body.call("normalize")
	var expected_radius := (
		ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(
			selected_polygon
		)
	)
	if (
		StringName(volume_body.get("shape_kind"))
		!= ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		or StringName(volume_body.get("body_kind"))
		!= ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
		or StringName(volume_body.get("profile_id")) != saved_profile_id
		or String(volume_body.get("profile_display_name"))
		!= "Verifier Fixed Profile"
		or not _packed_vector2_arrays_match(
			volume_body.get("profile_polygon_2d_meters")
			as PackedVector2Array,
			selected_polygon
		)
		or not is_equal_approx(
			float(volume_body.get("radius_meters")),
			expected_radius
		)
		or int(volume_body.get("profile_runtime_schema_version"))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_RUNTIME_SCHEMA_VERSION
		or StringName(volume_body.get("material_variant_id"))
		!= alternate_material_id
		or StringName(volume_body.get("placement_policy"))
		!= ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY
		or StringName(volume_body.get("operation_mode"))
		!= ForgeV2AuthoringStateScript.OPERATION_ADD_MATERIAL
		or float(volume_body.get("rough_volume_cell_equivalents")) <= 0.0
	):
		_fail("saved Basic Volume body lost fixed profile geometry or identity")
		return
	var volume_normals: PackedVector3Array = volume_body.get(
		"path_surface_normals"
	)
	if not _packed_vector3_arrays_match(
		volume_normals,
		PackedVector3Array([Vector3.UP, Vector3.BACK])
	):
		_fail("Volume body did not retain one surface normal per path point")
		return
	if (
		not _vector2_close(
			volume_body.get(
				"profile_contact_point_relative_2d_meters"
			) as Vector2,
			selected_runtime.get(
				"contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2
		)
		or not _vector2_close(
			volume_body.get("profile_contact_direction_2d") as Vector2,
			selected_runtime.get(
				"contact_direction_2d",
				Vector2.ZERO
			) as Vector2
		)
		or not is_equal_approx(
			float(volume_body.get("profile_rotation_bias_degrees")),
			30.0
		)
	):
		_fail("Volume body lost compiled contact or rotation-bias data")
		return
	var usage_resolver = ForgeV2MaterialVolumeResolverScript.new()
	var usage_summary: Dictionary = usage_resolver.call(
		"build_usage_summary",
		[volume_body]
	) as Dictionary
	if float(usage_summary.get(
		"total_rough_volume_cell_equivalents",
		0.0
	)) <= 0.0:
		_fail("material-volume resolver ignored saved Basic profile geometry")
		return

	var committed_layer: Resource = state.call(
		"commit_material_body_as_layer",
		volume_body_id
	) as Resource
	if committed_layer == null:
		_fail("saved Basic Volume body did not commit to a layer")
		return
	var input_records: Array = committed_layer.get(
		"input_shape_records"
	) as Array
	if (
		input_records.size() != 1
		or StringName(committed_layer.get("input_shape_type"))
		!= ForgeV2LayerDataScript.INPUT_SHAPE_MATERIAL_BODY_BUNDLE
	):
		_fail("committed saved-profile layer did not retain one input record")
		return
	var input_record: Dictionary = input_records[0] as Dictionary
	if (
		StringName(input_record.get("profile_id", StringName()))
		!= saved_profile_id
		or String(input_record.get("profile_display_name", ""))
		!= "Verifier Fixed Profile"
		or not _packed_vector2_arrays_match(
			input_record.get(
				"profile_polygon_2d_meters",
				PackedVector2Array()
			) as PackedVector2Array,
			selected_polygon
		)
		or not _packed_vector3_arrays_match(
			input_record.get(
				"path_surface_normals",
				PackedVector3Array()
			) as PackedVector3Array,
			volume_normals
		)
		or not _vector2_close(
			input_record.get(
				"profile_contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2,
			volume_body.get(
				"profile_contact_point_relative_2d_meters"
			) as Vector2
		)
		or not _vector2_close(
			input_record.get(
				"profile_contact_direction_2d",
				Vector2.ZERO
			) as Vector2,
			volume_body.get("profile_contact_direction_2d") as Vector2
		)
		or not is_equal_approx(
			float(input_record.get(
				"profile_contact_distance_meters",
				0.0
			)),
			float(volume_body.get("profile_contact_distance_meters"))
		)
		or int(input_record.get("profile_runtime_schema_version", 0))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_RUNTIME_SCHEMA_VERSION
		or not is_equal_approx(
			float(input_record.get(
				"profile_rotation_bias_degrees",
				0.0
			)),
			float(volume_body.get("profile_rotation_bias_degrees"))
		)
		or StringName(input_record.get("material_variant_id", StringName()))
		!= StringName(volume_body.get("material_variant_id"))
		or StringName(input_record.get("operation_mode", StringName()))
		!= StringName(volume_body.get("operation_mode"))
		or StringName(input_record.get("placement_policy", StringName()))
		!= StringName(volume_body.get("placement_policy"))
	):
		_fail("committed layer did not preserve saved-profile body authority")
		return

	var body_layer_state_path := "%s_body_layer_%s.tres" % [
		AUTHORING_STATE_PATH_PREFIX,
		str(Time.get_ticks_usec()),
	]
	if ResourceSaver.save(state, body_layer_state_path) != OK:
		_fail("committed saved-profile body state could not be persisted")
		return
	var reloaded_body_state: Resource = ResourceLoader.load(
		body_layer_state_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as Resource
	if reloaded_body_state == null:
		_fail("committed saved-profile body state could not be reloaded")
		return
	reloaded_body_state.call("normalize")
	var reloaded_volume_body: Resource = null
	var reloaded_material_bodies: Array = reloaded_body_state.get(
		"material_bodies"
	) as Array
	for body_variant: Variant in reloaded_material_bodies:
		var candidate_body := body_variant as Resource
		if (
			candidate_body != null
			and StringName(candidate_body.get("body_id"))
			== volume_body_id
		):
			reloaded_volume_body = candidate_body
			break
	if (
		reloaded_volume_body == null
		or StringName(reloaded_volume_body.get("profile_id"))
		!= saved_profile_id
		or not _packed_vector2_arrays_match(
			reloaded_volume_body.get(
				"profile_polygon_2d_meters"
			) as PackedVector2Array,
			selected_polygon
		)
		or not _packed_vector3_arrays_match(
			reloaded_volume_body.get(
				"path_surface_normals"
			) as PackedVector3Array,
			volume_normals
		)
		or not _vector2_close(
			reloaded_volume_body.get(
				"profile_contact_point_relative_2d_meters"
			) as Vector2,
			volume_body.get(
				"profile_contact_point_relative_2d_meters"
			) as Vector2
		)
		or not _vector2_close(
			reloaded_volume_body.get(
				"profile_contact_direction_2d"
			) as Vector2,
			volume_body.get("profile_contact_direction_2d") as Vector2
		)
		or not is_equal_approx(
			float(reloaded_volume_body.get(
				"profile_contact_distance_meters"
			)),
			float(volume_body.get("profile_contact_distance_meters"))
		)
		or int(reloaded_volume_body.get(
			"profile_runtime_schema_version"
		))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_RUNTIME_SCHEMA_VERSION
		or not is_equal_approx(
			float(reloaded_volume_body.get(
				"profile_rotation_bias_degrees"
			)),
			float(volume_body.get("profile_rotation_bias_degrees"))
		)
		or StringName(reloaded_volume_body.get("material_variant_id"))
		!= alternate_material_id
		or StringName(reloaded_volume_body.get("placement_policy"))
		!= ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY
	):
		_fail("saved-profile material body changed on state disk roundtrip")
		return
	var reloaded_layers: Array = reloaded_body_state.get(
		"forge_layers"
	) as Array
	if reloaded_layers.size() != 1:
		_fail("saved-profile committed layer count changed on disk roundtrip")
		return
	var reloaded_layer := reloaded_layers[0] as Resource
	var reloaded_input_records: Array = reloaded_layer.get(
		"input_shape_records"
	) as Array
	if (
		reloaded_input_records.size() != 1
		or not reloaded_input_records[0] is Dictionary
	):
		_fail("saved-profile layer input record was lost on disk roundtrip")
		return
	var reloaded_input_record := (
		reloaded_input_records[0] as Dictionary
	)
	if (
		StringName(reloaded_input_record.get("body_id", StringName()))
		!= volume_body_id
		or StringName(reloaded_input_record.get(
			"profile_id",
			StringName()
		)) != saved_profile_id
		or not _packed_vector2_arrays_match(
			reloaded_input_record.get(
				"profile_polygon_2d_meters",
				PackedVector2Array()
			) as PackedVector2Array,
			selected_polygon
		)
		or not _packed_vector3_arrays_match(
			reloaded_input_record.get(
				"path_surface_normals",
				PackedVector3Array()
			) as PackedVector3Array,
			volume_normals
		)
		or not _vector2_close(
			reloaded_input_record.get(
				"profile_contact_point_relative_2d_meters",
				Vector2.ZERO
			) as Vector2,
			volume_body.get(
				"profile_contact_point_relative_2d_meters"
			) as Vector2
		)
		or not _vector2_close(
			reloaded_input_record.get(
				"profile_contact_direction_2d",
				Vector2.ZERO
			) as Vector2,
			volume_body.get("profile_contact_direction_2d") as Vector2
		)
		or not is_equal_approx(
			float(reloaded_input_record.get(
				"profile_contact_distance_meters",
				0.0
			)),
			float(volume_body.get("profile_contact_distance_meters"))
		)
		or int(reloaded_input_record.get(
			"profile_runtime_schema_version",
			0
		))
		!= ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_RUNTIME_SCHEMA_VERSION
		or not is_equal_approx(
			float(reloaded_input_record.get(
				"profile_rotation_bias_degrees",
				0.0
			)),
			float(volume_body.get("profile_rotation_bias_degrees"))
		)
		or StringName(reloaded_input_record.get(
			"material_variant_id",
			StringName()
		)) != alternate_material_id
		or StringName(reloaded_input_record.get(
			"placement_policy",
			StringName()
		)) != ForgeV2AuthoringStateScript.PLACEMENT_EMPTY_ONLY
	):
		_fail("saved-profile layer contract changed on state disk roundtrip")
		return

	var spline_state: Resource = ForgeV2AuthoringStateScript.new()
	spline_state.call("reset_new_draft", "Saved Basic Spline Verify")
	if not bool(spline_state.call(
		"select_active_saved_basic_profile",
		saved_profile
	)):
		_fail("saved Basic profile could not be selected for Spline Line")
		return
	spline_state.call(
		"set_active_tool_id",
		ForgeV2AuthoringStateScript.TOOL_SPLINE_LINE
	)
	spline_state.call(
		"append_spline_line_point",
		Vector3.ZERO,
		Vector3.UP
	)
	spline_state.call(
		"append_spline_line_point",
		Vector3(0.075, 0.01, 0.0),
		Vector3.BACK
	)
	if not bool(spline_state.call("generate_spline_line_csg_noodle")):
		_fail("saved Basic Spline Line did not generate")
		return
	var spline_body: Resource = spline_state.call(
		"get_selected_material_body"
	) as Resource
	if (
		spline_body == null
		or StringName(spline_body.get("shape_kind"))
		!= ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
		or StringName(spline_body.get("profile_id")) != saved_profile_id
		or not _packed_vector2_arrays_match(
			spline_body.get("profile_polygon_2d_meters")
			as PackedVector2Array,
			selected_polygon
		)
		or not _packed_vector3_arrays_match(
			spline_body.get("path_surface_normals")
			as PackedVector3Array,
			PackedVector3Array([Vector3.UP, Vector3.BACK])
		)
		or not (
			spline_state.get("spline_line_points")
			as PackedVector3Array
		).is_empty()
		or not (
			spline_state.get("spline_line_surface_normals")
			as PackedVector3Array
		).is_empty()
	):
		_fail("saved Basic Spline body lost its fixed profile or normal data")
		return

	var shared_mid_normal := (
		ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
			Vector3(0.5, 0.0, 0.0),
			PackedVector3Array([
				Vector3.ZERO,
				Vector3.RIGHT,
			]),
			PackedVector3Array([
				Vector3.UP,
				Vector3.BACK,
			])
		)
	)
	if not _vector3_close(
		shared_mid_normal,
		(Vector3.UP + Vector3.BACK).normalized()
	):
		_fail("shared path-normal interpolation did not resolve the segment midpoint")
		return

	var frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			Vector3.RIGHT,
			Vector3.UP,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX,
			0.0
		)
	)
	var frame_axis_x := frame.get("axis_x", Vector3.ZERO) as Vector3
	var frame_axis_y := frame.get("axis_y", Vector3.ZERO) as Vector3
	if (
		not is_equal_approx(frame_axis_x.length(), 1.0)
		or not is_equal_approx(frame_axis_y.length(), 1.0)
		or absf(frame_axis_x.dot(Vector3.RIGHT)) > EPSILON
		or absf(frame_axis_y.dot(Vector3.RIGHT)) > EPSILON
		or not _vector3_close(
			frame.get("resolved_contact", Vector3.ZERO) as Vector3,
			Vector3.DOWN
		)
	):
		_fail("profile frame did not align contact inward and remain perpendicular")
		return
	var biased_frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			Vector3.RIGHT,
			Vector3.UP,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX,
			90.0
		)
	)
	var expected_biased_contact := (
		Basis(Vector3.RIGHT, deg_to_rad(90.0))
		* (frame.get("resolved_contact", Vector3.ZERO) as Vector3)
	)
	if not _vector3_close(
		biased_frame.get("resolved_contact", Vector3.ZERO) as Vector3,
		expected_biased_contact
	):
		_fail("profile rotation bias was not applied once after auto alignment")
		return

	var presenter = ForgeV2VolumePreviewPresenterScript.new()
	var orientation_curve := Curve3D.new()
	orientation_curve.add_point(Vector3.ZERO)
	orientation_curve.add_point(Vector3.RIGHT)
	presenter.call(
		"_apply_profile_curve_orientation",
		orientation_curve,
		PackedVector3Array([Vector3.ZERO, Vector3.RIGHT]),
		PackedVector3Array([Vector3.UP, Vector3.BACK]),
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX,
		30.0
	)
	var expected_first_tilt := float(
		ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			Vector3.RIGHT,
			Vector3.UP,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX,
			30.0
		).get("tilt_radians", 0.0)
	)
	var expected_second_tilt := float(
		ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			Vector3.RIGHT,
			Vector3.BACK,
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX,
			30.0
		).get("tilt_radians", 0.0)
	)
	while expected_second_tilt - expected_first_tilt > PI:
		expected_second_tilt -= TAU
	while expected_second_tilt - expected_first_tilt < -PI:
		expected_second_tilt += TAU
	var actual_first_tilt := orientation_curve.get_point_tilt(0)
	var actual_second_tilt := orientation_curve.get_point_tilt(1)
	if (
		absf(actual_first_tilt - expected_first_tilt) > EPSILON
		or absf(actual_second_tilt - expected_second_tilt) > EPSILON
		or absf(actual_second_tilt - actual_first_tilt) <= EPSILON
	):
		presenter.free()
		_fail("CSG presenter did not apply both endpoint surface normals")
		return
	presenter.free()

	result_lines.append("ok=true")
	result_lines.append("contact_clock_rule=true")
	result_lines.append("anchor_clearance_meters=%.4f" % (
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
	))
	result_lines.append("profile_migration_one_shot=true")
	result_lines.append("current_schema_contract_repair=true")
	result_lines.append("embedded_shape_snapshot_repair=true")
	result_lines.append("builder_fillet_deposition_chain=true")
	result_lines.append("shape_authority_separated=true")
	result_lines.append("deep_snapshot=true")
	result_lines.append("authoring_state_roundtrip=true")
	result_lines.append("body_layer_roundtrip=true")
	result_lines.append("fixed_volume_profile=true")
	result_lines.append("fixed_spline_profile=true")
	result_lines.append("non_default_material_placement=true")
	result_lines.append("surface_normals_persisted=true")
	result_lines.append("material_volume_positive=true")
	result_lines.append("layer_profile_contract=true")
	result_lines.append("shared_orientation_frame=true")
	result_lines.append("profile_sampling_separated=true")
	result_lines.append("click_only_profile_guard=true")
	result_lines.append("library_path=%s" % library_path)
	_write_results()
	quit(0)

func _rotate_points(
	points: PackedVector2Array,
	rotation_degrees: float
) -> PackedVector2Array:
	var rotated := PackedVector2Array()
	for point: Vector2 in points:
		rotated.append(point.rotated(deg_to_rad(rotation_degrees)))
	return rotated

func _packed_vector2_arrays_match(
	first_points: PackedVector2Array,
	second_points: PackedVector2Array
) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if not _vector2_close(
			first_points[point_index],
			second_points[point_index]
		):
			return false
	return true

func _packed_vector3_arrays_match(
	first_points: PackedVector3Array,
	second_points: PackedVector3Array
) -> bool:
	if first_points.size() != second_points.size():
		return false
	for point_index in range(first_points.size()):
		if not _vector3_close(
			first_points[point_index],
			second_points[point_index]
		):
			return false
	return true

func _vector2_close(first_value: Vector2, second_value: Vector2) -> bool:
	return first_value.distance_to(second_value) <= EPSILON

func _vector3_close(first_value: Vector3, second_value: Vector3) -> bool:
	return first_value.distance_to(second_value) <= EPSILON

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
