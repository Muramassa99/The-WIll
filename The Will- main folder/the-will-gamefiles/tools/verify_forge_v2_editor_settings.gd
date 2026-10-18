extends SceneTree

## Run seed, zero and reload in three separate engine processes to exclude the
## ResourceLoader cache from persistence evidence. Only diagnostic preferences
## are written; normal player settings are never changed.
const SETTINGS = preload("res://core/models/forge_v2_editor_settings_state.gd")
const CONTROLLER = preload("res://runtime/forge_v2/forge_v2_stage_controller.gd")
const SAVE_PATH := "user://diagnostics/forge_editor_settings/preferences.tres"
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase := args[0] if not args.is_empty() else "seed"
	var controller := CONTROLLER.new()
	controller.editor_settings = SETTINGS.load_or_create(SAVE_PATH)
	root.add_child(controller)
	match phase:
		"seed":
			_check(not FileAccess.file_exists(SAVE_PATH), "fresh diagnostic preferences")
			_check(controller.get_freehand_smoothing_steps() == 4, "first start defaults to 4")
			_check(controller.set_freehand_smoothing_steps(0), "explicit zero saved")
			_check(controller.get_freehand_smoothing_steps() == 0, "zero stays selectable")
		"zero":
			_check(FileAccess.file_exists(SAVE_PATH), "previous process wrote preferences")
			_check(controller.get_freehand_smoothing_steps() == 0, "fresh process restores zero without replacing it with default")
			_check(controller.set_freehand_smoothing_steps(7), "chosen strength saved")
			controller.start_new_draft("Preference retention")
			_check(controller.get_freehand_smoothing_steps() == 7, "new draft retains chosen strength")
		"reload":
			_check(controller.get_freehand_smoothing_steps() == 7, "fresh process restores chosen strength")
			_check(controller.set_freehand_smoothing_steps(99), "upper bound saved")
			_check(controller.get_freehand_smoothing_steps() == 10, "strength clamps to 10")
			_check(controller.set_freehand_smoothing_steps(-5), "lower bound saved")
			_check(controller.get_freehand_smoothing_steps() == 0, "strength clamps to 0")
			_check(controller.set_freehand_smoothing_steps(7), "final chosen strength saved")
			var disk := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Resource
			_check(disk != null and int(disk.get("freehand_smoothing_steps")) == 7, "uncached disk contents match choice")
		_:
			_check(false, "unknown verification phase")
	controller.queue_free()
	await process_frame
	print("FORGE_EDITOR_SETTINGS %s: %d/%d passed" % [phase, checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
