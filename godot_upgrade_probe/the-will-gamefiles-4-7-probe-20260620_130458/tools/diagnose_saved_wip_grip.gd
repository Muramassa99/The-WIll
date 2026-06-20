extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")

const OUTPUT_PATH := "c:/WORKSPACE/saved_wip_grip_diagnosis.txt"
const TARGET_PROJECT_NAME := "test_sword"

func _init() -> void:
	call_deferred("_run_diagnosis")

func _run_diagnosis() -> void:
	var library_state = PlayerForgeWipLibraryStateScript.load_or_create()
	var target_wip: CraftedItemWIP = _find_target_wip(library_state)
	var lines: PackedStringArray = []

	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("saved_wip_count=%d" % (library_state.saved_wips.size() if library_state != null else 0))
	lines.append("selected_wip_id=%s" % String(library_state.selected_wip_id if library_state != null else StringName()))
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)
	lines.append("target_wip_found=%s" % str(target_wip != null))

	if target_wip != null:
		var controller = ForgeGridControllerScript.new()
		var forge_service: ForgeService = controller.get_forge_service()
		var material_lookup: Dictionary = controller.build_default_material_lookup()
		var cells: Array[CellAtom] = _collect_wip_cells(target_wip)
		var segments: Array[SegmentAtom] = forge_service.build_segments(cells, material_lookup)
		segments = forge_service.classify_joint_segments(segments, material_lookup)
		var anchors: Array[AnchorAtom] = forge_service.build_anchors(segments, material_lookup)
		var profile: BakedProfile = forge_service.bake_wip(target_wip, material_lookup)
		var rules: ForgeRulesDef = controller.forge_rules

		lines.append("target_wip_id=%s" % String(target_wip.wip_id))
		lines.append("target_project_label=%s" % target_wip.forge_project_name)
		lines.append("target_layer_count=%d" % target_wip.layers.size())
		lines.append("target_cell_count=%d" % cells.size())
		lines.append("segment_count=%d" % segments.size())
		lines.append("anchor_count=%d" % anchors.size())
		lines.append("profile_primary_grip_valid=%s" % str(profile.primary_grip_valid if profile != null else false))
		lines.append("profile_validation_error=%s" % String(profile.validation_error if profile != null else ""))
		lines.append("profile_reach=%s" % str(profile.reach if profile != null else 0.0))
		lines.append("profile_balance_score=%s" % str(profile.balance_score if profile != null else 0.0))
		lines.append("profile_front_heavy_score=%s" % str(profile.front_heavy_score if profile != null else 0.0))
		lines.append("grip_rule_min_length=%d" % rules.primary_grip_min_length_voxels)
		lines.append("grip_rule_thickness_range=%d..%d" % [rules.primary_grip_min_thickness_voxels, rules.primary_grip_max_thickness_voxels])
		lines.append("grip_rule_width_range=%d..%d" % [rules.primary_grip_min_width_voxels, rules.primary_grip_max_width_voxels])
		lines.append("grip_rule_min_anchor_ratio=%s" % str(rules.primary_grip_min_anchor_ratio))

		for segment_index: int in range(segments.size()):
			var segment: SegmentAtom = segments[segment_index]
			if segment == null:
				continue
			var envelope_ok: bool = (
				segment.length_voxels >= rules.primary_grip_min_length_voxels
				and segment.cross_thickness_voxels >= rules.primary_grip_min_thickness_voxels
				and segment.cross_thickness_voxels <= rules.primary_grip_max_thickness_voxels
				and segment.cross_width_voxels >= rules.primary_grip_min_width_voxels
				and segment.cross_width_voxels <= rules.primary_grip_max_width_voxels
			)
			var anchor_ratio_ok: bool = segment.anchor_material_ratio >= rules.primary_grip_min_anchor_ratio
			var endcaps_ok: bool = segment.start_slice_anchor_valid and segment.end_slice_anchor_valid
			var profile_ok: bool = (
				segment.profile_state == &"square"
				or segment.profile_state == &"chamfered_hex"
				or segment.profile_state == &"rounded"
			)
			var edge_overlap_ok: bool = not segment.edge_span_overlap

			lines.append("--- segment_%d ---" % segment_index)
			lines.append("segment_id=%s" % String(segment.segment_id))
			lines.append("cell_count=%d" % segment.member_cells.size())
			lines.append("major_axis=%s" % str(segment.major_axis))
			lines.append("length_voxels=%d" % segment.length_voxels)
			lines.append("cross_width_voxels=%d" % segment.cross_width_voxels)
			lines.append("cross_thickness_voxels=%d" % segment.cross_thickness_voxels)
			lines.append("anchor_material_ratio=%s" % str(segment.anchor_material_ratio))
			lines.append("start_slice_anchor_valid=%s" % str(segment.start_slice_anchor_valid))
			lines.append("end_slice_anchor_valid=%s" % str(segment.end_slice_anchor_valid))
			lines.append("profile_state=%s" % String(segment.profile_state))
			lines.append("has_opposing_bevel_pair=%s" % str(segment.has_opposing_bevel_pair))
			lines.append("edge_span_overlap=%s" % str(segment.edge_span_overlap))
			lines.append("grip_envelope_ok=%s" % str(envelope_ok))
			lines.append("grip_anchor_ratio_ok=%s" % str(anchor_ratio_ok))
			lines.append("grip_endcaps_ok=%s" % str(endcaps_ok))
			lines.append("grip_profile_ok=%s" % str(profile_ok))
			lines.append("grip_edge_overlap_ok=%s" % str(edge_overlap_ok))
			lines.append("grip_candidate_passes_all=%s" % str(
				envelope_ok
				and anchor_ratio_ok
				and endcaps_ok
				and profile_ok
				and edge_overlap_ok
			))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _find_target_wip(library_state) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.saved_wips:
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name.strip_edges().to_lower() == TARGET_PROJECT_NAME:
			return saved_wip
	if library_state.selected_wip_id != StringName():
		return library_state.get_saved_wip(library_state.selected_wip_id)
	return null

func _collect_wip_cells(wip: CraftedItemWIP) -> Array[CellAtom]:
	var cells: Array[CellAtom] = []
	if wip == null:
		return cells
	for layer: LayerAtom in wip.layers:
		if layer == null:
			continue
		for cell: CellAtom in layer.cells:
			if cell == null:
				continue
			cells.append(cell)
	return cells
