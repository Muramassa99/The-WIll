extends SceneTree

func _init() -> void:
	var controller: ForgeGridController = ForgeGridController.new()
	var preset_ids: Array[StringName] = controller.get_sample_preset_ids()
	var lines: PackedStringArray = []
	for preset_id: StringName in preset_ids:
		_append_preset_report(lines, controller, preset_id)
	var output: String = "\n".join(lines)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_m2_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
		file.close()
	controller.free()
	quit()

func _append_preset_report(lines: PackedStringArray, controller: ForgeGridController, preset_id: StringName) -> void:
	controller.load_debug_sample_preset(preset_id)
	var forge_service: ForgeService = controller.get_forge_service()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var test_print: TestPrintInstance = controller.spawn_test_print_from_active_wip(material_lookup)
	var wip: CraftedItemWIP = controller.active_wip
	var profile: BakedProfile = null
	if wip != null:
		profile = controller.get_active_baked_profile()

	var cells: Array[CellAtom] = []
	if wip != null:
		for layer_atom: LayerAtom in wip.layers:
			if layer_atom == null:
				continue
			for cell: CellAtom in layer_atom.cells:
				if cell != null:
					cells.append(cell)

	var segments: Array[SegmentAtom] = forge_service.build_segments(cells, material_lookup)
	segments = forge_service.classify_joint_segments(segments, material_lookup)
	var joint_data: Dictionary = forge_service.build_joint_data(segments, material_lookup)
	var bow_data: Dictionary = forge_service.build_bow_data(
		segments,
		material_lookup,
		wip.forge_intent if wip != null else &"",
		wip.equipment_context if wip != null else &""
	)

	lines.append("=== PRESET %s ===" % String(preset_id))
	if profile == null:
		lines.append("profile=null")
		return
	lines.append("validation_error=%s" % String(profile.validation_error))
	lines.append("primary_grip_valid=%s" % str(profile.primary_grip_valid))
	lines.append("total_mass=%s" % String.num(profile.total_mass))
	lines.append("balance_score=%s" % String.num(profile.balance_score))
	lines.append("flex_score=%s" % String.num(profile.flex_score))
	lines.append("launch_score=%s" % String.num(profile.launch_score))
	lines.append("joint_valid=%s" % str(joint_data.get("joint_chain_valid", false)))
	lines.append("joint_type=%s" % String(joint_data.get("joint_type", &"none")))
	lines.append("bow_valid=%s" % str(bow_data.get("bow_valid", false)))
	lines.append("bow_error=%s" % String(bow_data.get("validation_error", &"")))
	lines.append("string_tension=%s" % String.num(bow_data.get("string_tension_score", 0.0)))
	lines.append("test_print_id=%s" % String(test_print.test_id if test_print != null else &"none"))
	lines.append("")