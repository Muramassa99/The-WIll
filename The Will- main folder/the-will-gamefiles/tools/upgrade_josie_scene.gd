extends SceneTree

const JOSIE_SCENE_PATH := "res://Josie/josie.tscn"
const RESULT_FILE_PATH := "C:/WORKSPACE/josie_scene_upgrade_results.txt"

func _init() -> void:
	call_deferred("_run_upgrade")

func _run_upgrade() -> void:
	var source_scene: PackedScene = load(JOSIE_SCENE_PATH) as PackedScene
	var result_lines: PackedStringArray = []
	result_lines.append("source_scene_loaded=%s" % str(source_scene != null))
	if source_scene == null:
		_write_results(result_lines)
		quit()
		return

	var root_node: Node = source_scene.instantiate()
	result_lines.append("instantiated=%s" % str(root_node != null))
	if root_node == null:
		_write_results(result_lines)
		quit()
		return

	var repacked_scene: PackedScene = PackedScene.new()
	var pack_error: Error = repacked_scene.pack(root_node)
	result_lines.append("pack_error=%d" % int(pack_error))
	if pack_error == OK:
		var save_error: Error = ResourceSaver.save(repacked_scene, JOSIE_SCENE_PATH)
		result_lines.append("save_error=%d" % int(save_error))
	root_node.queue_free()

	_write_results(result_lines)
	quit()

func _write_results(lines: PackedStringArray) -> void:
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()
