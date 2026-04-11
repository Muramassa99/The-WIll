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
	var combat_animation_station: Node = root_scene.get_node_or_null("CombatAnimationStation")
	var disassembly_ui: Node = root_scene.get_node_or_null("DisassemblyBench/DisassemblyBenchUI")
	var combat_animation_ui: Node = root_scene.get_node_or_null("CombatAnimationStation/CombatAnimationStationUI")
	var player: PlayerController3D = root_scene.get_node_or_null("PlayerCharacter") as PlayerController3D

	if combat_animation_station != null and player != null:
		combat_animation_station.call("interact", player)
		await process_frame
		await process_frame

	var combat_station_open: bool = bool(combat_animation_ui.call("is_open")) if combat_animation_ui != null and combat_animation_ui.has_method("is_open") else false

	var lines: PackedStringArray = []
	lines.append("main_scene_loaded=%s" % str(root_scene != null))
	lines.append("crafting_bench_present=%s" % str(crafting_bench != null))
	lines.append("disassembly_bench_present=%s" % str(disassembly_bench != null))
	lines.append("combat_animation_station_present=%s" % str(combat_animation_station != null))
	lines.append("disassembly_ui_present=%s" % str(disassembly_ui != null))
	lines.append("combat_animation_ui_present=%s" % str(combat_animation_ui != null))
	lines.append("combat_animation_station_open=%s" % str(combat_station_open))

	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	quit()
