extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PrimaryGripSliceProfileLibraryScript = preload("res://core/defs/primary_grip_slice_profile_library.gd")

const TARGET_PROJECT_NAME := "Long Glave  Animation  Test"
const RESULT_FILE_PATH := "C:/WORKSPACE/workspace debug home/glave_grip_candidate_reasons.txt"

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	lines.append("diagnostic=glave_grip_candidate_reasons")
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("library_loaded=%s" % str(library_state != null))
	if library_state == null:
		_write_and_quit()
		return
	var wip: CraftedItemWIP = _find_saved_wip_by_project_name(library_state, TARGET_PROJECT_NAME)
	lines.append("target_found=%s" % str(wip != null))
	if wip == null:
		_write_and_quit()
		return
	lines.append("target_wip_id=%s" % String(wip.wip_id))
	lines.append("selected_wip_id=%s" % String(library_state.selected_wip_id))

	var cells: Array[CellAtom] = CraftedItemWIP.collect_bake_cells(wip)
	var segments: Array[SegmentAtom] = controller.get_forge_service().build_segments(cells, material_lookup)
	segments = controller.get_forge_service().classify_joint_segments(segments, material_lookup)
	var anchors: Array[AnchorAtom] = controller.get_forge_service().build_anchors(segments, material_lookup)
	var profile: BakedProfile = controller.get_forge_service().bake_wip(wip, material_lookup)
	lines.append("cell_count=%d" % cells.size())
	lines.append("segment_count=%d" % segments.size())
	lines.append("anchor_count=%d" % anchors.size())
	lines.append("profile_validation_error=%s" % (profile.validation_error if profile != null else "<null>"))
	lines.append("profile_center_of_mass=%s" % _fmt_vec(profile.center_of_mass if profile != null else Vector3.ZERO))
	lines.append("primary_grip_valid=%s" % str(profile != null and profile.primary_grip_valid))

	for segment_index: int in range(segments.size()):
		var segment: SegmentAtom = segments[segment_index]
		_append_segment_report(segment_index, segment, controller.get_forge_service().anchor_resolver, material_lookup)

	controller.free()
	_write_and_quit()

func _append_segment_report(segment_index: int, segment: SegmentAtom, anchor_resolver: AnchorResolver, material_lookup: Dictionary) -> void:
	lines.append("")
	lines.append("[segment_%d]" % segment_index)
	if segment == null:
		lines.append("segment_null=true")
		return
	var bounds: Dictionary = _build_bounds(segment.member_cells)
	lines.append("segment_id=%s" % String(segment.segment_id))
	lines.append("member_cell_count=%d" % segment.member_cells.size())
	lines.append("bounds_min=%s" % str(bounds.get("min", Vector3i.ZERO)))
	lines.append("bounds_max=%s" % str(bounds.get("max", Vector3i.ZERO)))
	lines.append("major_axis=%s" % _axis_name(segment.major_axis))
	lines.append("minor_axis_a=%s" % _axis_name(segment.minor_axis_a))
	lines.append("minor_axis_b=%s" % _axis_name(segment.minor_axis_b))
	lines.append("length_voxels=%d" % segment.length_voxels)
	lines.append("cross_width_voxels=%d" % segment.cross_width_voxels)
	lines.append("cross_thickness_voxels=%d" % segment.cross_thickness_voxels)
	lines.append("anchor_material_ratio=%s" % _fmt_float(segment.anchor_material_ratio))
	lines.append("material_mix=%s" % _format_mix(segment.material_mix))

	var spans: Array = anchor_resolver._build_primary_grip_spans(segment, material_lookup)
	var slice_lookup: Dictionary = anchor_resolver._build_slice_grip_data(segment, material_lookup)
	lines.append("resolved_primary_grip_span_count=%d" % spans.size())
	for span_index: int in range(spans.size()):
		var span: Dictionary = spans[span_index]
		lines.append("span_%d=%d..%d length=%d ratio=%s start=%s end=%s" % [
			span_index,
			int(span.get("start_index", -1)),
			int(span.get("end_index", -1)),
			int(span.get("span_length", 0)),
			_fmt_float(float(span.get("anchor_material_ratio", 0.0))),
			_fmt_vec(span.get("start_position", Vector3.ZERO)),
			_fmt_vec(span.get("end_position", Vector3.ZERO)),
		])

	var reason_counts := {
		"eligible": 0,
		"count_lt_4": 0,
		"anchor_ratio_low": 0,
		"invalid_shape": 0,
		"clearance_blocked": 0,
	}
	var valid_slice_indices: Array[int] = []
	var full_anchor_valid_slice_indices: Array[int] = []
	var candidate_examples: Array[String] = []
	var invalid_shape_patterns: Dictionary = {}
	var clearance_examples: Array[String] = []
	var ratio_examples: Array[String] = []
	var ordered_slices: Array = slice_lookup.keys()
	ordered_slices.sort()
	for slice_index_value in ordered_slices:
		var slice_index: int = int(slice_index_value)
		var slice_data: Dictionary = slice_lookup.get(slice_index, {})
		var grip_candidates: Array = slice_data.get("grip_candidates", [])
		if not grip_candidates.is_empty():
			valid_slice_indices.append(slice_index)
			for candidate: Dictionary in grip_candidates:
				if bool(candidate.get("slice_anchor_valid", false)):
					full_anchor_valid_slice_indices.append(slice_index)
					break
			if candidate_examples.size() < 12:
				candidate_examples.append(_format_candidate_example(slice_index, grip_candidates[0]))
		var components: Array = slice_data.get("components", [])
		for component: Dictionary in components:
			var reason: String = _resolve_component_failure_reason(component, slice_data, anchor_resolver)
			reason_counts[reason] = int(reason_counts.get(reason, 0)) + 1
			if reason == "invalid_shape":
				var key: String = _component_pattern_key(component)
				invalid_shape_patterns[key] = int(invalid_shape_patterns.get(key, 0)) + 1
			elif reason == "clearance_blocked" and clearance_examples.size() < 8:
				clearance_examples.append(_format_component_example(slice_index, component))
			elif reason == "anchor_ratio_low" and ratio_examples.size() < 8:
				ratio_examples.append(_format_component_example(slice_index, component))

	lines.append("slice_count=%d" % ordered_slices.size())
	lines.append("valid_grip_candidate_slice_count=%d" % valid_slice_indices.size())
	lines.append("valid_grip_candidate_slice_ranges=%s" % _format_ranges(valid_slice_indices))
	lines.append("full_anchor_valid_candidate_slice_count=%d" % full_anchor_valid_slice_indices.size())
	lines.append("full_anchor_valid_candidate_slice_ranges=%s" % _format_ranges(full_anchor_valid_slice_indices))
	lines.append("candidate_examples=%s" % " | ".join(candidate_examples))
	lines.append("component_reason_counts=%s" % _format_reason_counts(reason_counts))
	lines.append("top_invalid_shape_patterns=%s" % _format_top_patterns(invalid_shape_patterns, 8))
	lines.append("anchor_ratio_low_examples=%s" % " | ".join(ratio_examples))
	lines.append("clearance_blocked_examples=%s" % " | ".join(clearance_examples))

func _resolve_component_failure_reason(component: Dictionary, slice_data: Dictionary, anchor_resolver: AnchorResolver) -> String:
	if component.is_empty():
		return "count_lt_4"
	if int(component.get("count", 0)) < 4:
		return "count_lt_4"
	if anchor_resolver._get_grip_surface_anchor_ratio(component) < anchor_resolver.forge_rules.primary_grip_min_anchor_ratio:
		return "anchor_ratio_low"
	if not anchor_resolver._is_grip_slice_shape_valid(component):
		return "invalid_shape"
	if not anchor_resolver._has_slice_component_clearance(component, slice_data.get("occupied", {})):
		return "clearance_blocked"
	return "eligible"

func _component_pattern_key(component: Dictionary) -> String:
	var positions: Array[Vector2i] = component.get("positions", [])
	var key: String = PrimaryGripSliceProfileLibraryScript.build_canonical_mask_key_from_positions(positions)
	return "%dx%d count=%d key=[%s]" % [
		int(component.get("width", 0)),
		int(component.get("thickness", 0)),
		int(component.get("count", 0)),
		key.replace("\n", "/"),
	]

func _format_component_example(slice_index: int, component: Dictionary) -> String:
	return "slice=%d count=%d surface_ratio=%s total_ratio=%s width=%d thickness=%d mats=%s" % [
		slice_index,
		int(component.get("count", 0)),
		_fmt_float(float(component.get("surface_anchor_material_ratio", component.get("anchor_material_ratio", 0.0)))),
		_fmt_float(float(component.get("anchor_material_ratio", 0.0))),
		int(component.get("width", 0)),
		int(component.get("thickness", 0)),
		_format_component_materials(component),
	]

func _format_candidate_example(slice_index: int, candidate: Dictionary) -> String:
	return "slice=%d count=%d surface_ratio=%s total_ratio=%s surface_valid=%s width=%d thickness=%d mats=%s" % [
		slice_index,
		int(candidate.get("count", 0)),
		_fmt_float(float(candidate.get("surface_anchor_material_ratio", candidate.get("anchor_material_ratio", 0.0)))),
		_fmt_float(float(candidate.get("anchor_material_ratio", 0.0))),
		str(bool(candidate.get("slice_anchor_valid", false))),
		int(candidate.get("width", 0)),
		int(candidate.get("thickness", 0)),
		_format_component_materials(candidate),
	]

func _format_component_materials(component: Dictionary) -> String:
	var mix := {}
	for cell: CellAtom in component.get("cells", []):
		if cell == null:
			continue
		mix[cell.material_variant_id] = int(mix.get(cell.material_variant_id, 0)) + 1
	return _format_mix(mix)

func _format_ranges(indices: Array[int]) -> String:
	if indices.is_empty():
		return "<none>"
	indices.sort()
	var ranges: PackedStringArray = []
	var start: int = indices[0]
	var previous: int = indices[0]
	for i: int in range(1, indices.size()):
		var value: int = indices[i]
		if value == previous + 1:
			previous = value
			continue
		ranges.append("%d..%d" % [start, previous])
		start = value
		previous = value
	ranges.append("%d..%d" % [start, previous])
	return ", ".join(ranges)

func _format_reason_counts(reason_counts: Dictionary) -> String:
	var pieces: PackedStringArray = []
	for key: String in ["eligible", "count_lt_4", "anchor_ratio_low", "invalid_shape", "clearance_blocked"]:
		pieces.append("%s:%d" % [key, int(reason_counts.get(key, 0))])
	return ", ".join(pieces)

func _format_top_patterns(pattern_counts: Dictionary, limit: int) -> String:
	var keys: Array = pattern_counts.keys()
	keys.sort_custom(func(a, b): return int(pattern_counts.get(a, 0)) > int(pattern_counts.get(b, 0)))
	var pieces: PackedStringArray = []
	for i: int in range(mini(keys.size(), limit)):
		var key: String = keys[i]
		pieces.append("%s x%d" % [key, int(pattern_counts.get(key, 0))])
	return " | ".join(pieces)

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _build_bounds(cells: Array[CellAtom]) -> Dictionary:
	if cells.is_empty():
		return {"min": Vector3i.ZERO, "max": Vector3i.ZERO}
	var min_pos: Vector3i = cells[0].grid_position
	var max_pos: Vector3i = cells[0].grid_position
	for cell: CellAtom in cells:
		if cell == null:
			continue
		var pos: Vector3i = cell.grid_position
		min_pos.x = mini(min_pos.x, pos.x)
		min_pos.y = mini(min_pos.y, pos.y)
		min_pos.z = mini(min_pos.z, pos.z)
		max_pos.x = maxi(max_pos.x, pos.x)
		max_pos.y = maxi(max_pos.y, pos.y)
		max_pos.z = maxi(max_pos.z, pos.z)
	return {"min": min_pos, "max": max_pos}

func _format_mix(mix: Dictionary) -> String:
	var keys: Array = mix.keys()
	keys.sort()
	var pieces: PackedStringArray = []
	for key in keys:
		pieces.append("%s:%d" % [String(key), int(mix.get(key, 0))])
	return ", ".join(pieces)

func _axis_name(axis: Vector3i) -> String:
	if axis == Vector3i.RIGHT:
		return "RIGHT/X"
	if axis == Vector3i.UP:
		return "UP/Y"
	if axis == Vector3i.BACK:
		return "BACK/Z"
	return str(axis)

func _fmt_vec(value: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]

func _fmt_float(value: float) -> String:
	return "%.4f" % value

func _write_and_quit() -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
