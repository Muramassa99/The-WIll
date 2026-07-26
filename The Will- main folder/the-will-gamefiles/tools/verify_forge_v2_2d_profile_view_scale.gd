extends SceneTree

const CraftingBenchUIV2Script = preload("res://runtime/forge_v2/crafting_bench_ui_v2.gd")
const ForgeV2AuthoringStateScript = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const ForgeV2KeybindingStateScript = preload("res://runtime/forge_v2/forge_v2_keybinding_state.gd")
const ForgeV2StageControllerScript = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const MetricScaleRulerControlScript = preload("res://runtime/ui/metric_scale_ruler_control.gd")
const CraftingBenchUIV2Scene = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")

const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v2_2d_profile_view_scale_2026-07-25.txt"
const EPSILON := 0.00001
const PIXEL_EPSILON := 0.01

var result_lines: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var authoring_state: Resource = ForgeV2AuthoringStateScript.new()
	authoring_state.call("reset_new_draft", "Forge V2 2D Profile View Scale Verify")
	authoring_state.call("reset_active_basic_profile_builder")
	var summary: Dictionary = authoring_state.call("get_status_summary") as Dictionary
	var profile_settings: Dictionary = summary.get("active_profile_settings", {}) as Dictionary
	var builder_settings: Dictionary = profile_settings.get("profile_builder", {}) as Dictionary
	var minimum_scale_distance_meters := float(profile_settings.get("size_min_meters", 0.0))
	var guide_polygon: PackedVector2Array = builder_settings.get(
		"guide_polygon_2d_meters",
		PackedVector2Array()
	) as PackedVector2Array
	var guide_grid_segments: Array = builder_settings.get(
		"guide_grid_segments_2d_meters",
		[]
	) as Array
	var guide_snap_points: PackedVector2Array = builder_settings.get(
		"guide_grid_snap_points_2d_meters",
		PackedVector2Array()
	) as PackedVector2Array
	var guide_grid_step_meters := float(builder_settings.get("guide_grid_step_meters", 0.0))
	if minimum_scale_distance_meters <= 0.0:
		_fail("profile settings did not expose a positive minimum scale distance")
		return
	if (
		not guide_polygon.is_empty()
		or not guide_grid_segments.is_empty()
		or not guide_snap_points.is_empty()
	):
		_fail("Basic profile settings retained obsolete finite guide or snap data")
		return
	if guide_grid_step_meters <= 0.0:
		_fail("Basic profile settings did not expose a positive procedural grid step")
		return

	var preview: Control = CraftingBenchUIV2Script.ProfileBuilderPreviewControl.new()
	preview.name = "VerifiedProfilePreview"
	preview.size = Vector2(420.0, 420.0)
	get_root().add_child(preview)

	var ruler: Control = MetricScaleRulerControlScript.new()
	ruler.name = "VerifiedMetricScaleRuler"
	preview.add_child(ruler)
	preview.call("attach_metric_scale_ruler", ruler)
	preview.call(
		"set_profile_guide",
		guide_polygon,
		guide_grid_segments,
		guide_snap_points,
		true,
		guide_grid_step_meters,
		0.0
	)
	preview.call(
		"set_profile_geometry",
		profile_settings.get("preview_polygon_2d_meters", PackedVector2Array()),
		builder_settings.get("control_points_2d_meters", PackedVector2Array()),
		bool(builder_settings.get("rounded_enabled", false)),
		Vector2(
			float(profile_settings.get("anchor_x_meters", 0.0)),
			float(profile_settings.get("anchor_y_meters", 0.0))
		)
	)
	preview.call("configure_metric_view", true, minimum_scale_distance_meters)
	await process_frame

	var view_state: Dictionary = preview.call("get_metric_view_state") as Dictionary
	var ruler_state: Dictionary = preview.call("get_metric_scale_ruler_state") as Dictionary
	var grid_state: Dictionary = preview.call("get_metric_grid_state") as Dictionary
	if not preview.clip_contents:
		_fail("profile preview did not clip zoomed drawing to its viewport bounds")
		return
	if not bool(view_state.get("enabled", false)):
		_fail("metric view did not enable for the 2D profile builder")
		return
	if not ruler.visible:
		_fail("metric scale ruler was not visible for the 2D profile builder")
		return
	var grid_error := _validate_metric_grid_state(grid_state, preview)
	if not grid_error.is_empty():
		_fail("initial procedural grid: %s" % grid_error)
		return
	if int(grid_state.get("lod_multiplier", 0)) != 1:
		_fail("maximum magnification unexpectedly simplified the authored grid")
		return
	if absf(
		float(grid_state.get("base_step_meters", 0.0))
		- guide_grid_step_meters
	) > EPSILON:
		_fail("procedural grid did not preserve the authored base grid step")
		return
	if absf(float(ruler_state.get("a_value_meters", 0.0)) - minimum_scale_distance_meters) > EPSILON:
		_fail("maximum magnification ruler A did not equal the profile minimum scale distance")
		return
	if absf(
		float(ruler_state.get("b_value_meters", 0.0))
		- float(ruler_state.get("a_value_meters", 0.0)) * 2.0
	) > EPSILON:
		_fail("ruler B was not two equal A-length sections from zero")
		return
	if absf(
		float(ruler_state.get("a_x", 0.0)) - float(ruler_state.get("zero_x", 0.0))
		- (float(ruler_state.get("b_x", 0.0)) - float(ruler_state.get("a_x", 0.0)))
	) > PIXEL_EPSILON:
		_fail("ruler 0-A and A-B screen lengths were not equal")
		return
	var black_rect: Rect2 = ruler_state.get("black_rect", Rect2())
	if absf(black_rect.position.x - float(ruler_state.get("a_x", 0.0))) > PIXEL_EPSILON:
		_fail("dark ruler segment did not begin at A")
		return
	if absf(black_rect.size.x - float(ruler_state.get("segment_width_pixels", 0.0))) > PIXEL_EPSILON:
		_fail("dark ruler segment width did not equal A-B")
		return
	if not _ruler_remainder_is_bounded(ruler_state):
		_fail("ruler remainder exceeded one measured segment at maximum magnification")
		return
	if not String(ruler_state.get("b_label", "")).ends_with(" m"):
		_fail("ruler did not identify its total distance in meters")
		return

	var sweep_ruler: Control = MetricScaleRulerControlScript.new()
	var sweep_maximum_scale := float(view_state.get("maximum_pixels_per_meter", 0.0))
	var sweep_minimum_scale := float(view_state.get("minimum_pixels_per_meter", 0.0))
	var previous_sweep_distance := 0.0
	for sample_index in range(513):
		var sample_weight := float(sample_index) / 512.0
		var sampled_scale := exp(lerpf(
			log(sweep_maximum_scale),
			log(sweep_minimum_scale),
			sample_weight
		))
		sweep_ruler.call("configure_scale", sampled_scale, minimum_scale_distance_meters)
		var sweep_state: Dictionary = sweep_ruler.call("get_ruler_state") as Dictionary
		if not _ruler_remainder_is_bounded(sweep_state):
			_fail("ruler remainder escaped its segment bound during continuous scale sweep")
			return
		var sweep_segment_width := float(sweep_state.get("segment_width_pixels", 0.0))
		if (
			sweep_segment_width + PIXEL_EPSILON
			< float(sweep_state.get("minimum_segment_width_pixels", 0.0))
			or sweep_segment_width
			> MetricScaleRulerControlScript.MAX_SEGMENT_WIDTH_PIXELS + PIXEL_EPSILON
		):
			_fail("ruler segment width escaped its permitted visual band")
			return
		var sweep_distance := float(sweep_state.get("segment_distance_meters", 0.0))
		if sweep_distance + EPSILON < previous_sweep_distance:
			_fail("ruler distance moved backward during continuous zoom-out sweep")
			return
		previous_sweep_distance = sweep_distance
	sweep_ruler.free()

	var pointer := Vector2(84.0, 126.0)
	var profile_before_zoom: Vector2 = preview.call("_screen_to_profile", pointer) as Vector2
	if not bool(preview.call("zoom_metric_view_at", pointer, false)):
		_fail("profile view did not zoom out")
		return
	var profile_after_zoom: Vector2 = preview.call("_screen_to_profile", pointer) as Vector2
	if profile_before_zoom.distance_to(profile_after_zoom) > EPSILON:
		_fail("profile coordinate under the mouse moved during pointer-focused zoom")
		return
	var origin_screen_after_zoom: Vector2 = preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		float((preview.call("get_metric_view_state") as Dictionary).get("pixels_per_meter", 0.0))
	) as Vector2
	if origin_screen_after_zoom.distance_to(preview.size * 0.5) <= PIXEL_EPSILON:
		_fail("profile origin stayed falsely fixed at viewport center after off-center zoom")
		return
	if (preview.call("_screen_to_profile", origin_screen_after_zoom) as Vector2).length() > EPSILON:
		_fail("transformed profile origin no longer mapped back to zero")
		return

	var previous_a_value := float((preview.call("get_metric_scale_ruler_state") as Dictionary).get("a_value_meters", 0.0))
	var scale_step_increased := false
	var previous_grid_lod := int((preview.call("get_metric_grid_state") as Dictionary).get("lod_multiplier", 0))
	var grid_lod_increased := false
	for zoom_index in range(48):
		var focused_profile_before: Vector2 = preview.call("_screen_to_profile", pointer) as Vector2
		var zoom_changed := bool(preview.call("zoom_metric_view_at", pointer, false))
		var focused_profile_after: Vector2 = preview.call("_screen_to_profile", pointer) as Vector2
		if zoom_changed and focused_profile_before.distance_to(focused_profile_after) > EPSILON:
			_fail("pointer focus drifted during zoom-out step %d" % zoom_index)
			return
		var stepped_ruler_state: Dictionary = preview.call("get_metric_scale_ruler_state") as Dictionary
		var stepped_grid_state: Dictionary = preview.call("get_metric_grid_state") as Dictionary
		var next_a_value := float(stepped_ruler_state.get("a_value_meters", 0.0))
		if next_a_value + EPSILON < previous_a_value:
			_fail("ruler distance decreased while zooming out")
			return
		if next_a_value > previous_a_value + EPSILON:
			scale_step_increased = true
		previous_a_value = next_a_value
		if absf(float(stepped_ruler_state.get("b_value_meters", 0.0)) - next_a_value * 2.0) > EPSILON:
			_fail("ruler lost its two equal sections after a scale step")
			return
		if not _ruler_remainder_is_bounded(stepped_ruler_state):
			_fail(
				"ruler remainder exceeded one measured segment at zoom step %d" % zoom_index
			)
			return
		grid_error = _validate_metric_grid_state(stepped_grid_state, preview)
		if not grid_error.is_empty():
			_fail("procedural grid at zoom step %d: %s" % [zoom_index, grid_error])
			return
		var next_grid_lod := int(stepped_grid_state.get("lod_multiplier", 0))
		if not _is_power_of_two(next_grid_lod):
			_fail("procedural grid LOD was not a power-of-two multiple")
			return
		if next_grid_lod < previous_grid_lod:
			_fail("procedural grid LOD became finer while zooming out")
			return
		if next_grid_lod > previous_grid_lod:
			grid_lod_increased = true
		previous_grid_lod = next_grid_lod
	if not scale_step_increased:
		_fail("ruler never advanced to a larger fixed distance while zooming out")
		return
	if not grid_lod_increased:
		_fail("procedural grid never simplified while zooming out")
		return
	view_state = preview.call("get_metric_view_state") as Dictionary
	grid_state = preview.call("get_metric_grid_state") as Dictionary
	var maximum_visible_width_meters := float(
		view_state.get("maximum_visible_width_meters", 0.0)
	)
	var visible_span_meters: Vector2 = view_state.get(
		"visible_span_meters",
		Vector2.ZERO
	) as Vector2
	if absf(maximum_visible_width_meters - 1.2) > EPSILON:
		_fail("profile view did not expose the requested 1.2 meter width authority")
		return
	if absf(visible_span_meters.x - maximum_visible_width_meters) > EPSILON:
		_fail("maximum zoom-out did not show exactly the requested visible width")
		return
	if absf(
		float(view_state.get("pixels_per_meter", 0.0))
		- float(view_state.get("minimum_pixels_per_meter", 0.0))
	) > PIXEL_EPSILON:
		_fail("profile view did not stop at its 1.2 meter zoom-out cap")
		return
	grid_error = _validate_metric_grid_state(grid_state, preview)
	if not grid_error.is_empty():
		_fail("procedural grid at maximum zoom-out: %s" % grid_error)
		return
	if int(grid_state.get("lod_multiplier", 0)) <= 1:
		_fail("maximum zoom-out did not simplify the visual grid")
		return

	var cap_scale_before := float(view_state.get("pixels_per_meter", 0.0))
	var cap_center_before: Vector2 = view_state.get(
		"view_center_profile_meters",
		Vector2(INF, INF)
	) as Vector2
	var cap_profile_before: Vector2 = preview.call("_screen_to_profile", pointer) as Vector2
	if bool(preview.call("zoom_metric_view_at", pointer, false)):
		_fail("zoom-out reported a change after reaching the 1.2 meter cap")
		return
	var cap_view_after: Dictionary = preview.call("get_metric_view_state") as Dictionary
	if (
		absf(float(cap_view_after.get("pixels_per_meter", 0.0)) - cap_scale_before)
		> PIXEL_EPSILON
		or (
			cap_view_after.get("view_center_profile_meters", Vector2(INF, INF)) as Vector2
		).distance_to(cap_center_before) > EPSILON
		or (
			preview.call("_screen_to_profile", pointer) as Vector2
		).distance_to(cap_profile_before) > EPSILON
	):
		_fail("zoom-out cap changed scale, center, or pointer focus")
		return

	var coarse_visual_step := float(grid_state.get("visual_step_meters", 0.0))
	var procedural_snap_probe := Vector2(
		guide_grid_step_meters * 1.2,
		guide_grid_step_meters * -2.2
	)
	var fine_snap_point := _snap_point_to_procedural_grid_for_verification(
		procedural_snap_probe,
		guide_grid_step_meters,
		0.0
	)
	if (
		absf(fine_snap_point.x / coarse_visual_step - roundf(
			fine_snap_point.x / coarse_visual_step
		)) <= EPSILON
		and absf(fine_snap_point.y / coarse_visual_step - roundf(
			fine_snap_point.y / coarse_visual_step
		)) <= EPSILON
	):
		_fail("procedural snap probe did not distinguish the base grid from visual LOD")
		return
	var snap_result_before_navigation: Vector2 = preview.call(
		"_constrain_control_point_position",
		procedural_snap_probe
	) as Vector2
	if snap_result_before_navigation.distance_to(fine_snap_point) > EPSILON:
		_fail("coarse visual LOD replaced the procedural base-grid snap authority")
		return

	var rotated_grid_degrees := 27.0
	preview.call(
		"set_profile_guide",
		guide_polygon,
		guide_grid_segments,
		guide_snap_points,
		true,
		guide_grid_step_meters,
		rotated_grid_degrees
	)
	var rotated_grid_before_pan: Dictionary = preview.call("get_metric_grid_state") as Dictionary
	grid_error = _validate_metric_grid_state(rotated_grid_before_pan, preview)
	if not grid_error.is_empty():
		_fail("rotated procedural grid: %s" % grid_error)
		return
	if absf(
		float(rotated_grid_before_pan.get("rotation_degrees", 0.0))
		- rotated_grid_degrees
	) > EPSILON:
		_fail("procedural grid discarded the active profile rotation")
		return
	var expected_rotated_snap := _snap_point_to_procedural_grid_for_verification(
		procedural_snap_probe,
		guide_grid_step_meters,
		rotated_grid_degrees
	)
	var rotated_snap_before_pan: Vector2 = preview.call(
		"_constrain_control_point_position",
		procedural_snap_probe
	) as Vector2
	if rotated_snap_before_pan.distance_to(expected_rotated_snap) > EPSILON:
		_fail("procedural snap authority did not follow the active grid rotation")
		return
	var grid_origin_before_pan: Vector2 = preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		cap_scale_before
	) as Vector2
	var grid_pan_delta := Vector2(37.0, -23.0)
	if not bool(preview.call("pan_metric_view_by", grid_pan_delta)):
		_fail("procedural grid verification pan was rejected")
		return
	var rotated_grid_after_pan: Dictionary = preview.call("get_metric_grid_state") as Dictionary
	grid_error = _validate_metric_grid_state(rotated_grid_after_pan, preview)
	if not grid_error.is_empty():
		_fail("rotated procedural grid after pan: %s" % grid_error)
		return
	var grid_origin_after_pan: Vector2 = preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		cap_scale_before
	) as Vector2
	if (grid_origin_after_pan - grid_origin_before_pan).distance_to(grid_pan_delta) > PIXEL_EPSILON:
		_fail("procedural grid origin did not follow pan one-to-one")
		return
	if (
		int(rotated_grid_after_pan.get("lod_multiplier", 0))
		!= int(rotated_grid_before_pan.get("lod_multiplier", 0))
		or absf(
			float(rotated_grid_after_pan.get("visual_step_meters", 0.0))
			- float(rotated_grid_before_pan.get("visual_step_meters", 0.0))
		) > EPSILON
	):
		_fail("panning changed procedural grid LOD or spacing")
		return
	var guide_polygon_after_navigation: PackedVector2Array = preview.get(
		"guide_polygon"
	) as PackedVector2Array
	var guide_segments_after_navigation: Array = preview.get(
		"guide_grid_segments"
	) as Array
	var snap_points_after_navigation: PackedVector2Array = preview.get(
		"guide_snap_points"
	) as PackedVector2Array
	var snap_result_after_navigation: Vector2 = preview.call(
		"_constrain_control_point_position",
		procedural_snap_probe
	) as Vector2
	if (
		not guide_polygon_after_navigation.is_empty()
		or not guide_segments_after_navigation.is_empty()
		or not snap_points_after_navigation.is_empty()
		or snap_result_after_navigation.distance_to(expected_rotated_snap) > EPSILON
	):
		_fail("zoom, rotation, or pan invalidated the procedural grid contract")
		return
	preview.call("center_metric_view")
	preview.call(
		"set_profile_guide",
		guide_polygon,
		guide_grid_segments,
		guide_snap_points,
		true,
		guide_grid_step_meters,
		0.0
	)
	if (
		preview.call(
			"_constrain_control_point_position",
			procedural_snap_probe
		) as Vector2
	).distance_to(snap_result_before_navigation) > EPSILON:
		_fail("restoring zero grid rotation did not restore procedural snapping")
		return

	for zoom_index in range(96):
		preview.call("zoom_metric_view_at", pointer, true)
	view_state = preview.call("get_metric_view_state") as Dictionary
	ruler_state = preview.call("get_metric_scale_ruler_state") as Dictionary
	if absf(
		float(view_state.get("pixels_per_meter", 0.0))
		- float(view_state.get("maximum_pixels_per_meter", 0.0))
	) > PIXEL_EPSILON:
		_fail("profile view did not stop at its maximum magnification")
		return
	if absf(float(ruler_state.get("a_value_meters", 0.0)) - minimum_scale_distance_meters) > EPSILON:
		_fail("ruler did not return to the minimum scale distance at maximum magnification")
		return
	var scale_at_cap := float(view_state.get("pixels_per_meter", 0.0))
	if bool(preview.call("zoom_metric_view_at", pointer, true)):
		_fail("zoom-in reported a change after reaching the magnification cap")
		return
	view_state = preview.call("get_metric_view_state") as Dictionary
	if absf(float(view_state.get("pixels_per_meter", 0.0)) - scale_at_cap) > PIXEL_EPSILON:
		_fail("zoom-in moved past the magnification cap")
		return

	preview.call("center_metric_view")
	view_state = preview.call("get_metric_view_state") as Dictionary
	var pan_scale := float(view_state.get("pixels_per_meter", 0.0))
	var pan_center_before: Vector2 = view_state.get(
		"view_center_profile_meters",
		Vector2(INF, INF)
	) as Vector2
	if not pan_center_before.is_zero_approx():
		_fail("profile view did not establish a centered pan baseline")
		return
	var pan_ruler_before: Dictionary = preview.call("get_metric_scale_ruler_state") as Dictionary
	var origin_before_pan: Vector2 = preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		pan_scale
	) as Vector2
	var pan_screen_delta := Vector2(36.0, -24.0)
	if not bool(preview.call("pan_metric_view_by", pan_screen_delta)):
		_fail("metric profile view rejected a valid pan delta")
		return
	var pan_view_after: Dictionary = preview.call("get_metric_view_state") as Dictionary
	var expected_pan_center := Vector2(
		-pan_screen_delta.x / pan_scale,
		pan_screen_delta.y / pan_scale
	)
	var actual_pan_center: Vector2 = pan_view_after.get(
		"view_center_profile_meters",
		Vector2(INF, INF)
	) as Vector2
	if actual_pan_center.distance_to(expected_pan_center) > EPSILON:
		_fail("metric profile pan did not convert screen delta into profile meters correctly")
		return
	var origin_after_pan: Vector2 = preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		pan_scale
	) as Vector2
	if (origin_after_pan - origin_before_pan).distance_to(pan_screen_delta) > PIXEL_EPSILON:
		_fail("metric profile content did not follow the pan pointer one-to-one")
		return
	if absf(float(pan_view_after.get("pixels_per_meter", 0.0)) - pan_scale) > PIXEL_EPSILON:
		_fail("panning changed profile magnification")
		return
	if not bool(preview.call("center_metric_view")):
		_fail("metric profile view did not center after a pan")
		return
	var centered_view_state: Dictionary = preview.call("get_metric_view_state") as Dictionary
	var centered_ruler_state: Dictionary = preview.call("get_metric_scale_ruler_state") as Dictionary
	if not (centered_view_state.get("view_center_profile_meters", Vector2(INF, INF)) as Vector2).is_zero_approx():
		_fail("metric profile center command did not return profile origin to center")
		return
	if absf(float(centered_view_state.get("pixels_per_meter", 0.0)) - pan_scale) > PIXEL_EPSILON:
		_fail("metric profile center command changed magnification")
		return
	if absf(
		float(centered_ruler_state.get("a_value_meters", 0.0))
		- float(pan_ruler_before.get("a_value_meters", 0.0))
	) > EPSILON:
		_fail("metric profile center command changed ruler scale")
		return
	if bool(preview.call("center_metric_view")):
		_fail("metric profile center command reported a change while already centered")
		return

	var keybinding_state: Resource = ForgeV2KeybindingStateScript.new()
	keybinding_state.call("normalize")
	var zoom_in_event := InputEventMouseButton.new()
	zoom_in_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_in_event.pressed = true
	if not bool(keybinding_state.call(
		"event_matches_action",
		ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_IN,
		zoom_in_event
	)):
		_fail("existing Forge V2 zoom-in keybinding did not recognize its default wheel event")
		return
	var pan_press_event := InputEventMouseButton.new()
	pan_press_event.button_index = MOUSE_BUTTON_MIDDLE
	pan_press_event.pressed = true
	if not bool(keybinding_state.call(
		"event_matches_action",
		ForgeV2KeybindingStateScript.ACTION_VIEW_PAN,
		pan_press_event
	)):
		_fail("existing Forge V2 pan keybinding did not recognize its default MMB event")
		return
	var secondary_pan_binding: Dictionary = keybinding_state.call(
		"get_binding_data",
		ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY
	) as Dictionary
	if (
		int(secondary_pan_binding.get("mouse_button", MOUSE_BUTTON_NONE)) != MOUSE_BUTTON_RIGHT
		or (
			int(secondary_pan_binding.get("physical_keycode", KEY_NONE)) != KEY_C
			and int(secondary_pan_binding.get("keycode", KEY_NONE)) != KEY_C
		)
	):
		_fail("existing Forge V2 alternate pan binding was not C + RMB")
		return

	preview.size = Vector2(520.0, 460.0)
	await process_frame
	var right_inset := preview.size.x - (ruler.position.x + ruler.size.x)
	var bottom_inset := preview.size.y - (ruler.position.y + ruler.size.y)
	if absf(right_inset - MetricScaleRulerControlScript.VIEWPORT_INSET_PIXELS) > PIXEL_EPSILON:
		_fail("ruler did not preserve its right viewport inset after resize")
		return
	if absf(bottom_inset - MetricScaleRulerControlScript.VIEWPORT_INSET_PIXELS) > PIXEL_EPSILON:
		_fail("ruler did not preserve its bottom viewport inset after resize")
		return
	preview.call("center_metric_view")
	var resized_pointer := preview.size * 0.5
	for zoom_index in range(64):
		preview.call("zoom_metric_view_at", resized_pointer, false)
	var resized_view_state: Dictionary = preview.call("get_metric_view_state") as Dictionary
	var resized_visible_span: Vector2 = resized_view_state.get(
		"visible_span_meters",
		Vector2.ZERO
	) as Vector2
	if absf(
		float(resized_view_state.get("minimum_pixels_per_meter", 0.0))
		- preview.size.x / maximum_visible_width_meters
	) > PIXEL_EPSILON:
		_fail("resize did not derive its zoom-out limit from the new viewport width")
		return
	if (
		absf(resized_visible_span.x - maximum_visible_width_meters) > EPSILON
		or absf(
			float(resized_view_state.get("pixels_per_meter", 0.0))
			- float(resized_view_state.get("minimum_pixels_per_meter", 0.0))
		) > PIXEL_EPSILON
	):
		_fail("resized profile view did not stop at the same 1.2 meter width cap")
		return
	if not (
		resized_view_state.get("view_center_profile_meters", Vector2(INF, INF)) as Vector2
	).is_zero_approx():
		_fail("centered resize zoom changed the profile-space center")
		return
	var resized_grid_state: Dictionary = preview.call("get_metric_grid_state") as Dictionary
	grid_error = _validate_metric_grid_state(resized_grid_state, preview)
	if not grid_error.is_empty():
		_fail("procedural grid after resize: %s" % grid_error)
		return
	if (
		preview.call(
			"_constrain_control_point_position",
			procedural_snap_probe
		) as Vector2
	).distance_to(snap_result_before_navigation) > EPSILON:
		_fail("resize or adaptive grid LOD changed procedural base-grid snapping")
		return

	preview.call("configure_metric_view", false, minimum_scale_distance_meters)
	if ruler.visible:
		_fail("2D metric ruler stayed visible outside its enabled builder scope")
		return
	if bool((preview.call("get_metric_grid_state") as Dictionary).get("enabled", false)):
		_fail("procedural Basic grid stayed enabled outside its metric builder scope")
		return
	if bool(preview.call("pan_metric_view_by", Vector2(12.0, 8.0))):
		_fail("metric pan remained active after the metric builder scope was disabled")
		return
	if bool(preview.call("center_metric_view")):
		_fail("metric center remained active after the metric builder scope was disabled")
		return

	var integrated_controller: Node = ForgeV2StageControllerScript.new()
	get_root().add_child(integrated_controller)
	var integrated_ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	get_root().add_child(integrated_ui)
	await process_frame
	integrated_ui.set("keybinding_state", keybinding_state)
	var integrated_state: Resource = integrated_controller.call("get_active_authoring_state") as Resource
	integrated_state.call("reset_active_basic_profile_builder")
	integrated_ui.call("open_for", null, integrated_controller, "Profile Scale Verify", null)
	integrated_ui.call("_open_profile_builder_popup")
	await process_frame
	var integrated_preview: Control = integrated_ui.get("profile_builder_preview") as Control
	var integrated_ruler: Control = integrated_ui.get("profile_metric_scale_ruler") as Control
	if integrated_preview == null or integrated_ruler == null:
		_fail("real Forge V2 profile popup did not construct its metric ruler")
		return
	if not bool(integrated_preview.call("is_metric_view_active")) or not integrated_ruler.visible:
		_fail("real Forge V2 2D profile popup did not activate its metric ruler")
		return
	var integrated_grid_state: Dictionary = integrated_preview.call(
		"get_metric_grid_state"
	) as Dictionary
	grid_error = _validate_metric_grid_state(integrated_grid_state, integrated_preview)
	if not grid_error.is_empty():
		_fail("real Forge V2 profile popup procedural grid: %s" % grid_error)
		return
	var integrated_view_handler: Callable = integrated_preview.get("metric_view_input_handler") as Callable
	if not integrated_view_handler.is_valid():
		_fail("real Forge V2 profile preview did not receive its local view input route")
		return

	var integrated_pointer := integrated_preview.size * 0.37
	var integrated_profile_before: Vector2 = integrated_preview.call(
		"_screen_to_profile",
		integrated_pointer
	) as Vector2
	var integrated_view_before: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	var zoom_out_event := InputEventMouseButton.new()
	zoom_out_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_out_event.pressed = true
	zoom_out_event.position = integrated_pointer
	integrated_preview.call("_gui_input", zoom_out_event)
	var integrated_view_after: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	if (
		float(integrated_view_after.get("pixels_per_meter", 0.0))
		>= float(integrated_view_before.get("pixels_per_meter", 0.0))
	):
		_fail("real Forge V2 profile popup zoom-out input did not reduce magnification")
		return
	var integrated_profile_after: Vector2 = integrated_preview.call(
		"_screen_to_profile",
		integrated_pointer
	) as Vector2
	if integrated_profile_before.distance_to(integrated_profile_after) > EPSILON:
		_fail("real Forge V2 profile popup input did not preserve pointer focus")
		return

	keybinding_state.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_VIEW_ZOOM_OUT,
		{"physical_keycode": KEY_Z, "keycode": KEY_Z}
	)
	var rebound_zoom_event := InputEventKey.new()
	rebound_zoom_event.physical_keycode = KEY_Z
	rebound_zoom_event.keycode = KEY_Z
	rebound_zoom_event.pressed = true
	var rebound_scale_before := float(integrated_view_after.get("pixels_per_meter", 0.0))
	if not bool(integrated_ui.call(
		"_handle_profile_builder_metric_view_input",
		rebound_zoom_event,
		integrated_pointer
	)):
		_fail("real Forge V2 profile popup did not honor a rebound keyboard zoom action")
		return
	var rebound_view_after: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	if float(rebound_view_after.get("pixels_per_meter", 0.0)) >= rebound_scale_before:
		_fail("rebound keyboard zoom action did not reduce magnification")
		return

	var integrated_pan_scale := float(rebound_view_after.get("pixels_per_meter", 0.0))
	var integrated_origin_before_pan: Vector2 = integrated_preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		integrated_pan_scale
	) as Vector2
	var integrated_pan_press := InputEventMouseButton.new()
	integrated_pan_press.button_index = MOUSE_BUTTON_MIDDLE
	integrated_pan_press.pressed = true
	integrated_pan_press.position = integrated_pointer
	integrated_preview.call("_gui_input", integrated_pan_press)
	if not bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("real Forge V2 profile popup did not retain active pan ownership")
		return
	var integrated_pan_delta := Vector2(28.0, -16.0)
	var integrated_pan_motion := InputEventMouseMotion.new()
	integrated_pan_motion.position = integrated_pointer + integrated_pan_delta
	integrated_pan_motion.relative = integrated_pan_delta
	integrated_preview.call("_gui_input", integrated_pan_motion)
	var integrated_origin_after_pan: Vector2 = integrated_preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		integrated_pan_scale
	) as Vector2
	if (
		integrated_origin_after_pan - integrated_origin_before_pan
	).distance_to(integrated_pan_delta) > PIXEL_EPSILON:
		_fail("real Forge V2 profile popup pan did not follow mouse motion one-to-one")
		return
	var integrated_pan_view: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	if absf(
		float(integrated_pan_view.get("pixels_per_meter", 0.0))
		- integrated_pan_scale
	) > PIXEL_EPSILON:
		_fail("real Forge V2 profile popup pan changed magnification")
		return
	var integrated_pan_release := InputEventMouseButton.new()
	integrated_pan_release.button_index = MOUSE_BUTTON_MIDDLE
	integrated_pan_release.pressed = false
	integrated_pan_release.position = integrated_pan_motion.position
	integrated_preview.call("_gui_input", integrated_pan_release)
	if bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("real Forge V2 profile popup retained pan ownership after release")
		return
	var center_after_release: Vector2 = (
		integrated_preview.call("get_metric_view_state") as Dictionary
	).get("view_center_profile_meters", Vector2(INF, INF)) as Vector2
	var inactive_pan_motion := InputEventMouseMotion.new()
	inactive_pan_motion.position = integrated_pointer
	inactive_pan_motion.relative = Vector2(9.0, 7.0)
	integrated_preview.call("_gui_input", inactive_pan_motion)
	var center_after_inactive_motion: Vector2 = (
		integrated_preview.call("get_metric_view_state") as Dictionary
	).get("view_center_profile_meters", Vector2(INF, INF)) as Vector2
	if center_after_inactive_motion.distance_to(center_after_release) > EPSILON:
		_fail("profile popup continued panning after the pan release")
		return

	keybinding_state.call(
		"set_binding_data",
		ForgeV2KeybindingStateScript.ACTION_VIEW_PAN_SECONDARY,
		{"mouse_button": MOUSE_BUTTON_XBUTTON1}
	)
	var rebound_pan_origin_before: Vector2 = integrated_preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		integrated_pan_scale
	) as Vector2
	var rebound_pan_press := InputEventMouseButton.new()
	rebound_pan_press.button_index = MOUSE_BUTTON_XBUTTON1
	rebound_pan_press.pressed = true
	rebound_pan_press.position = integrated_pointer
	integrated_preview.call("_gui_input", rebound_pan_press)
	if not bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("real Forge V2 profile popup did not honor a rebound alternate pan button")
		return
	var rebound_pan_delta := Vector2(-13.0, 11.0)
	var rebound_pan_motion := InputEventMouseMotion.new()
	rebound_pan_motion.position = integrated_pointer + rebound_pan_delta
	rebound_pan_motion.relative = rebound_pan_delta
	integrated_preview.call("_gui_input", rebound_pan_motion)
	var rebound_pan_release := InputEventMouseButton.new()
	rebound_pan_release.button_index = MOUSE_BUTTON_XBUTTON1
	rebound_pan_release.pressed = false
	rebound_pan_release.position = rebound_pan_motion.position
	integrated_preview.call("_gui_input", rebound_pan_release)
	var rebound_pan_origin_after: Vector2 = integrated_preview.call(
		"_profile_to_screen",
		Vector2.ZERO,
		integrated_pan_scale
	) as Vector2
	if (
		rebound_pan_origin_after - rebound_pan_origin_before
	).distance_to(rebound_pan_delta) > PIXEL_EPSILON:
		_fail("rebound alternate pan did not follow its mouse motion")
		return
	if bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("rebound alternate pan remained active after release")
		return

	var ruler_before_space: Dictionary = integrated_preview.call("get_metric_scale_ruler_state") as Dictionary
	var space_event := InputEventKey.new()
	space_event.physical_keycode = KEY_SPACE
	space_event.keycode = KEY_SPACE
	space_event.pressed = true
	if not bool(integrated_ui.call(
		"_handle_profile_builder_metric_view_input",
		space_event,
		integrated_pointer
	)):
		_fail("real Forge V2 profile popup did not route Space to center")
		return
	var centered_integrated_view: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	var centered_integrated_ruler: Dictionary = integrated_preview.call("get_metric_scale_ruler_state") as Dictionary
	if not (
		centered_integrated_view.get("view_center_profile_meters", Vector2(INF, INF)) as Vector2
	).is_zero_approx():
		_fail("Space did not center the real Forge V2 profile view")
		return
	if absf(
		float(centered_integrated_view.get("pixels_per_meter", 0.0))
		- integrated_pan_scale
	) > PIXEL_EPSILON:
		_fail("Space changed profile magnification while centering")
		return
	if absf(
		float(centered_integrated_ruler.get("a_value_meters", 0.0))
		- float(ruler_before_space.get("a_value_meters", 0.0))
	) > EPSILON:
		_fail("Space changed ruler scale while centering")
		return

	integrated_preview.call("_gui_input", integrated_pan_press)
	if not bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("real Forge V2 profile popup could not start pan before Handles switch")
		return
	integrated_ui.call("_select_profile_builder_handle_builder")
	await process_frame
	if bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("switching from Basic to Handles did not cancel active profile pan")
		return
	if bool(integrated_preview.call("is_metric_view_active")) or integrated_ruler.visible:
		_fail("Handles unexpectedly retained the Basic metric view")
		return
	if bool(
		(integrated_preview.call("get_metric_grid_state") as Dictionary).get("enabled", false)
	):
		_fail("Handles unexpectedly enabled the Basic procedural viewport grid")
		return
	var handle_guide_segments: Array = integrated_preview.get("guide_grid_segments") as Array
	var handle_snap_points: PackedVector2Array = integrated_preview.get(
		"guide_snap_points"
	) as PackedVector2Array
	if handle_guide_segments.is_empty() or handle_snap_points.is_empty():
		_fail("Handles lost its existing bounded guide or snap data")
		return
	var handle_view_before: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	if bool(integrated_preview.call("pan_metric_view_by", Vector2(18.0, 12.0))):
		_fail("Handles accepted Basic metric pan")
		return
	if bool(integrated_ui.call(
		"_handle_profile_builder_metric_view_input",
		integrated_pan_press,
		integrated_pointer
	)):
		_fail("Handles routed the Basic metric pan binding")
		return
	if bool(integrated_ui.call(
		"_handle_profile_builder_metric_view_input",
		space_event,
		integrated_pointer
	)):
		_fail("Handles routed the Basic metric Space center command")
		return
	var handle_view_after: Dictionary = integrated_preview.call("get_metric_view_state") as Dictionary
	if (
		(handle_view_after.get("view_center_profile_meters", Vector2(INF, INF)) as Vector2).distance_to(
			handle_view_before.get("view_center_profile_meters", Vector2(INF, INF)) as Vector2
		) > EPSILON
		or absf(
			float(handle_view_after.get("pixels_per_meter", 0.0))
			- float(handle_view_before.get("pixels_per_meter", 0.0))
		) > PIXEL_EPSILON
	):
		_fail("Handles view changed during Basic-only pan and center input")
		return

	integrated_ui.call("_select_profile_builder_basic_builder")
	await process_frame
	if not bool(integrated_preview.call("is_metric_view_active")):
		_fail("real Forge V2 profile popup did not restore Basic metric view")
		return
	grid_error = _validate_metric_grid_state(
		integrated_preview.call("get_metric_grid_state") as Dictionary,
		integrated_preview
	)
	if not grid_error.is_empty():
		_fail("Basic procedural grid did not restore after Handles: %s" % grid_error)
		return
	integrated_preview.call("_gui_input", integrated_pan_press)
	if not bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("real Forge V2 profile popup could not restart pan before popup-hide check")
		return
	var integrated_popup: PopupPanel = integrated_ui.get("profile_builder_popup") as PopupPanel
	integrated_popup.hide()
	await process_frame
	if bool(integrated_ui.get("profile_builder_metric_pan_active")):
		_fail("profile pan remained active after its popup was hidden")
		return

	result_lines.append("ok=true")
	result_lines.append("minimum_scale_distance_meters=%.6f" % minimum_scale_distance_meters)
	result_lines.append("maximum_pixels_per_meter=%.3f" % float(view_state.get("maximum_pixels_per_meter", 0.0)))
	result_lines.append("pointer_focus_preserved=true")
	result_lines.append("origin_guides_follow_view=true")
	result_lines.append("viewport_drawing_clipped=true")
	result_lines.append("ruler_equal_sections=true")
	result_lines.append("ruler_remainder_never_exceeds_segment=true")
	result_lines.append("ruler_continuous_scale_sweep=true")
	result_lines.append("ruler_scale_steps=true")
	result_lines.append("maximum_visible_width_meters=%.6f" % maximum_visible_width_meters)
	result_lines.append("zoom_out_1_2_meter_cap=true")
	result_lines.append("procedural_grid_viewport_coverage=true")
	result_lines.append("procedural_grid_power_of_two_lod=true")
	result_lines.append("procedural_grid_line_counts_bounded=true")
	result_lines.append("procedural_grid_rotation_safe=true")
	result_lines.append("procedural_grid_pan_stable=true")
	result_lines.append("procedural_grid_resize_cap=true")
	result_lines.append("procedural_snap_grid_authority=true")
	result_lines.append("ruler_bottom_right_anchor=true")
	result_lines.append("existing_zoom_keybinding_reused=true")
	result_lines.append("existing_pan_keybindings_reused=true")
	result_lines.append("integrated_profile_popup=true")
	result_lines.append("integrated_zoom_input_route=true")
	result_lines.append("rebound_zoom_keybinding=true")
	result_lines.append("metric_pan_screen_delta=true")
	result_lines.append("metric_pan_meter_conversion=true")
	result_lines.append("rebound_pan_keybinding=true")
	result_lines.append("space_center_preserves_zoom=true")
	result_lines.append("handles_pan_center_unaffected=true")
	result_lines.append("handles_procedural_grid_unaffected=true")
	result_lines.append("pan_cancelled_on_handles_switch=true")
	result_lines.append("pan_cancelled_on_popup_hide=true")
	_write_results()
	quit(0)


func _validate_metric_grid_state(grid_state: Dictionary, preview: Control) -> String:
	if not bool(grid_state.get("enabled", false)):
		return "grid state was disabled"
	var base_step := float(grid_state.get("base_step_meters", 0.0))
	var visual_step := float(grid_state.get("visual_step_meters", 0.0))
	var lod_multiplier := int(grid_state.get("lod_multiplier", 0))
	var spacing_pixels := float(grid_state.get("spacing_pixels", 0.0))
	var minimum_spacing_pixels := float(grid_state.get("minimum_spacing_pixels", 0.0))
	if base_step <= 0.0 or visual_step <= 0.0:
		return "grid step was not positive"
	if not _is_power_of_two(lod_multiplier):
		return "LOD multiplier was not a positive power of two"
	if absf(visual_step - base_step * float(lod_multiplier)) > EPSILON:
		return "visual step diverged from its base-step LOD multiple"
	if spacing_pixels + PIXEL_EPSILON < minimum_spacing_pixels:
		return "visual line spacing fell below its readability floor"
	var view_scale := float(preview.call("_calculate_view_scale"))
	if absf(spacing_pixels - visual_step * view_scale) > PIXEL_EPSILON:
		return "grid world step and screen spacing diverged"

	var rotation_degrees := float(grid_state.get("rotation_degrees", 0.0))
	var inverse_rotation := -deg_to_rad(rotation_degrees)
	var expected_visible_min := Vector2(INF, INF)
	var expected_visible_max := Vector2(-INF, -INF)
	var viewport_corners := PackedVector2Array([
		Vector2.ZERO,
		Vector2(preview.size.x, 0.0),
		preview.size,
		Vector2(0.0, preview.size.y),
	])
	for screen_corner: Vector2 in viewport_corners:
		var profile_corner: Vector2 = preview.call(
			"_screen_to_profile",
			screen_corner
		) as Vector2
		var local_corner := profile_corner.rotated(inverse_rotation)
		expected_visible_min.x = minf(expected_visible_min.x, local_corner.x)
		expected_visible_min.y = minf(expected_visible_min.y, local_corner.y)
		expected_visible_max.x = maxf(expected_visible_max.x, local_corner.x)
		expected_visible_max.y = maxf(expected_visible_max.y, local_corner.y)
	var visible_bounds: Rect2 = grid_state.get(
		"visible_grid_local_bounds",
		Rect2()
	) as Rect2
	var expected_visible_bounds := Rect2(
		expected_visible_min,
		expected_visible_max - expected_visible_min
	)
	if (
		visible_bounds.position.distance_to(expected_visible_bounds.position) > EPSILON
		or visible_bounds.size.distance_to(expected_visible_bounds.size) > EPSILON
	):
		return "grid-local visible bounds did not match the rotated viewport"

	var draw_bounds: Rect2 = grid_state.get("draw_grid_local_bounds", Rect2()) as Rect2
	var visible_end := visible_bounds.position + visible_bounds.size
	var draw_end := draw_bounds.position + draw_bounds.size
	if (
		draw_bounds.position.x > visible_bounds.position.x + EPSILON
		or draw_bounds.position.y > visible_bounds.position.y + EPSILON
		or draw_end.x < visible_end.x - EPSILON
		or draw_end.y < visible_end.y - EPSILON
	):
		return "generated grid did not overfill every viewport edge"
	var coverage_margins := PackedFloat32Array([
		visible_bounds.position.x - draw_bounds.position.x,
		visible_bounds.position.y - draw_bounds.position.y,
		draw_end.x - visible_end.x,
		draw_end.y - visible_end.y,
	])
	for margin: float in coverage_margins:
		if margin + EPSILON < visual_step or margin > visual_step * 2.0 + EPSILON:
			return "grid overfill margin escaped its one-to-two-step bound"

	var minimum_x_index := int(grid_state.get("minimum_x_index", 0))
	var maximum_x_index := int(grid_state.get("maximum_x_index", -1))
	var minimum_y_index := int(grid_state.get("minimum_y_index", 0))
	var maximum_y_index := int(grid_state.get("maximum_y_index", -1))
	var vertical_line_count := int(grid_state.get("vertical_line_count", 0))
	var horizontal_line_count := int(grid_state.get("horizontal_line_count", 0))
	if (
		vertical_line_count != maximum_x_index - minimum_x_index + 1
		or horizontal_line_count != maximum_y_index - minimum_y_index + 1
	):
		return "line counts did not match their generated index bounds"
	var maximum_vertical_count := ceili(visible_bounds.size.x / visual_step) + 4
	var maximum_horizontal_count := ceili(visible_bounds.size.y / visual_step) + 4
	if (
		vertical_line_count <= 0
		or horizontal_line_count <= 0
		or vertical_line_count > maximum_vertical_count
		or horizontal_line_count > maximum_horizontal_count
	):
		return "procedural grid generated an unbounded line count"

	var segments: Array = grid_state.get("segments_profile_meters", []) as Array
	if segments.size() != vertical_line_count + horizontal_line_count:
		return "generated segment count did not match vertical plus horizontal lines"
	for segment_index in range(segments.size()):
		var segment: PackedVector2Array = segments[segment_index] as PackedVector2Array
		if segment.size() != 2:
			return "generated grid segment did not contain exactly two endpoints"
		var local_a := segment[0].rotated(inverse_rotation)
		var local_b := segment[1].rotated(inverse_rotation)
		if segment_index < vertical_line_count:
			var expected_x := float(minimum_x_index + segment_index) * visual_step
			if (
				absf(local_a.x - expected_x) > EPSILON
				or absf(local_b.x - expected_x) > EPSILON
				or absf(local_a.y - draw_bounds.position.y) > EPSILON
				or absf(local_b.y - draw_end.y) > EPSILON
			):
				return "rotated vertical grid line escaped its local-grid coordinate"
		else:
			var horizontal_index := segment_index - vertical_line_count
			var expected_y := float(minimum_y_index + horizontal_index) * visual_step
			if (
				absf(local_a.y - expected_y) > EPSILON
				or absf(local_b.y - expected_y) > EPSILON
				or absf(local_a.x - draw_bounds.position.x) > EPSILON
				or absf(local_b.x - draw_end.x) > EPSILON
			):
				return "rotated horizontal grid line escaped its local-grid coordinate"
	return ""


func _is_power_of_two(value: int) -> bool:
	return value > 0 and (value & (value - 1)) == 0


func _snap_point_to_procedural_grid_for_verification(
	point: Vector2,
	grid_step_meters: float,
	grid_rotation_degrees: float
) -> Vector2:
	var inverse_rotation := -deg_to_rad(grid_rotation_degrees)
	var grid_local_point := point.rotated(inverse_rotation)
	var snapped_grid_local_point := Vector2(
		roundf(grid_local_point.x / grid_step_meters) * grid_step_meters,
		roundf(grid_local_point.y / grid_step_meters) * grid_step_meters
	)
	return snapped_grid_local_point.rotated(-inverse_rotation)


func _ruler_remainder_is_bounded(ruler_state: Dictionary) -> bool:
	var segment_width := float(ruler_state.get("segment_width_pixels", 0.0))
	var remaining_width := float(ruler_state.get("remaining_width_pixels", -INF))
	return (
		remaining_width >= -PIXEL_EPSILON
		and remaining_width <= segment_width + PIXEL_EPSILON
	)


func _fail(message: String) -> void:
	result_lines.append("ok=false")
	result_lines.append("error=%s" % message)
	_write_results()
	push_error(message)
	quit(1)


func _write_results() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(result_lines))
		file.close()
