extends SceneTree

const MainScene = preload("res://node_3d.tscn")

const OUTPUT_PATH := "c:/WORKSPACE/disassembly_world_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var root_scene: Node = MainScene.instantiate()
	get_root().add_child(root_scene)
	await process_frame
	await process_frame

	var disassembly_bench: Node = root_scene.get_node_or_null("DisassemblyBench")
	var crafting_bench: Node = root_scene.get_node_or_null("CraftingBench")
	var disassembly_ui: Node = root_scene.get_node_or_null("DisassemblyBench/DisassemblyBenchUI")

	var lines: PackedStringArray = []
	lines.append("main_scene_loaded=%s" % str(root_scene != null))
	lines.append("crafting_bench_present=%s" % str(crafting_bench != null))
	lines.append("disassembly_bench_present=%s" % str(disassembly_bench != null))
	lines.append("disassembly_ui_present=%s" % str(disassembly_ui != null))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
