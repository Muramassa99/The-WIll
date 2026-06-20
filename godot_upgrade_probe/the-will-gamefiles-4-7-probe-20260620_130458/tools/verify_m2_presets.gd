extends SceneTree

func _init() -> void:
	var controller: ForgeGridController = ForgeGridController.new()
	var preset_ids: Array[StringName] = controller.get_sample_preset_ids()
	var lines: PackedStringArray = []
	lines.append("preset_count=%d" % preset_ids.size())
	lines.append("has_presets=%s" % str(not preset_ids.is_empty()))
	var output: String = "\n".join(lines)
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_m2_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string(output)
		file.close()
	controller.free()
	quit()
