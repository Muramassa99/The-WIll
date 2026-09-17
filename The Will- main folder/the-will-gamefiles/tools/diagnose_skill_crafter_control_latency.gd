extends SceneTree

const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const ProfilePresenter = preload("res://tools/skill_crafter_drag_profile_presenter.gd")
const RESULT_PREFIX = "C:/WORKSPACE/test_artifacts/skill_crafter_latency_"

class TestPlayer:
	extends Node
	var library: Resource
	func get_forge_wip_library_state() -> Resource:
		return library
	func set_ui_mode_enabled(_value: bool) -> void:
		pass

var rows: Array = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var source: Resource = load("user://forge/player_wip_library_state.tres")
	if source == null:
		quit(1)
		return
	var player := TestPlayer.new()
	player.library = source.duplicate(true)
	player.library.set("save_file_path", RESULT_PREFIX + "library.tres")
	var chosen: Resource
	for wip: Resource in player.library.get("saved_wips"):
		if wip.get("forge_project_name") == "Star_Handle_Testing":
			chosen = wip
	if chosen == null:
		print("LATENCY_ERROR=missing_weapon")
		quit(1)
		return
	root.add_child(player)
	var ui = UIScene.instantiate()
	ui.preview_presenter = ProfilePresenter.new()
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await process_frame
	ui.open_for(player, "Control latency diagnostic")
	ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"), &"hand_right", false, false)
	ui.select_skill_slot(&"skill_slot_1", true)
	await process_frame
	# Suppress automatic flush only in this diagnostic: invoke the exact flush
	# ourselves so each input/solve/refresh is timed once, without counting waits.
	ui.set_process(false)
	for control: StringName in [&"weapon", &"tip", &"pommel"]:
		ui.reset_active_draft_to_baseline()
		ui.session_state.current_focus = control
		ui.call("_refresh_preview_scene")
		await process_frame
		var motion: Resource = ui.call("_get_active_motion_node")
		var context: Dictionary = ui.preview_presenter.call("_weapon_roll_context", ui.preview_subviewport)
		var camera: Camera3D = ui.call("_get_preview_camera")
		var display: Resource = ui.call("_build_display_motion_node_for_viewport_pick", motion)
		var target: Vector3 = display.get("tip_position_local")
		if control == &"pommel":
			target = display.get("pommel_position_local")
		elif control == &"weapon":
			target = ui.motion_node_editor.get_weapon_rotation_handle_local(display)
		var pointer: Vector2 = camera.unproject_position(context["trajectory"].to_global(target))
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = pointer
		ui.call("_on_preview_gui_input", press)
		if not ui.motion_node_editor.is_dragging():
			print("LATENCY_ERROR=failed_pick_" + String(control))
			quit(1)
			return
		for sample_index: int in range(4):
			ui.preview_presenter.reset_samples()
			var started: int = Time.get_ticks_usec()
			var move := InputEventMouseMotion.new()
			move.position = pointer + Vector2(6.0 * (sample_index + 1), 2.0 * (sample_index + 1))
			move.relative = Vector2(6.0, 2.0)
			ui.call("_on_preview_gui_input", move)
			var input_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
			started = Time.get_ticks_usec()
			ui.preview_drag_last_refresh_msec = 0
			ui.preview_drag_first_pending_msec = 0
			ui.call("_flush_pending_preview_drag_refresh")
			var flush_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
			var row: Dictionary = {"control": control, "sample": sample_index, "input_ms": input_ms, "flush_ms": flush_ms, "stages": ui.preview_presenter.samples.duplicate(true)}
			row["pose"] = _pose(context)
			rows.append(row)
			print("LATENCY_SAMPLE=" + JSON.stringify({"control": control, "sample": sample_index, "input_ms": input_ms, "flush_ms": flush_ms, "stages": row["stages"]}))
			await process_frame
		ui.preview_presenter.reset_samples()
		var release_start: int = Time.get_ticks_usec()
		press.pressed = false
		ui.call("_on_preview_gui_input", press)
		rows.append({"control": control, "release_ms": float(Time.get_ticks_usec() - release_start) / 1000.0, "pose": _pose(context)})
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var file := FileAccess.open(RESULT_PREFIX + stamp + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	print("LATENCY_RESULT=" + RESULT_PREFIX + stamp + ".json")
	ui.queue_free()
	player.queue_free()
	await process_frame
	quit(0)

func _pose(context: Dictionary) -> Dictionary:
	var skeleton: Skeleton3D = context["actor"].get("skeleton")
	var bones: Array = []
	for index: int in range(skeleton.get_bone_count()):
		bones.append(var_to_str(skeleton.get_bone_pose(index)))
	return {"weapon": var_to_str(context["weapon"].global_transform), "bones": bones}
