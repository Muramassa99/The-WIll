extends SceneTree

const CraftingBenchUIV2Scene = preload("res://scenes/ui_v2/crafting_bench_ui_v2.tscn")

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var failed := false
	var ui: CraftingBenchUIV2 = CraftingBenchUIV2Scene.instantiate() as CraftingBenchUIV2
	get_root().add_child(ui)
	await process_frame
	var amount_row_removed := ui.get_node_or_null("Panel/MarginContainer/RootVBox/BodyPanel/BodyMargin/BodyScroll/BodyVBox/AmountRow") == null
	var lines: PackedStringArray = [
		"ui_instantiated=%s" % str(ui != null),
		"amount_row_removed=%s" % str(amount_row_removed),
	]
	failed = failed or ui == null or not amount_row_removed
	var file: FileAccess = FileAccess.open("c:/WORKSPACE/godot_runs/verify_forge_v2_amount_ui_removed_results.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit(1 if failed else 0)
