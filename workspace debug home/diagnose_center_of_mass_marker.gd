extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/workspace debug home/center_of_mass_marker_results.txt"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Center Of Mass Marker Diagnosis")
	await process_frame
	var selected_wip_id: StringName = library_state.selected_wip_id
	ui.open_saved_wip_with_hand_setup(selected_wip_id, &"hand_right", false, true)
	await process_frame
	ui.debugger_view_enabled = true
	ui.call("_refresh_debugger_view_button")
	ui.call("_refresh_preview_scene")
	await process_frame
	await process_frame
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var lines: PackedStringArray = []
	lines.append("selected_wip_id=%s" % String(selected_wip_id))
	lines.append("debugger_view_enabled=%s" % str(bool(debug_state.get("debugger_view_enabled", false))))
	lines.append("preview_weapon_exists=%s" % str(bool(debug_state.get("has_preview_weapon", false))))
	lines.append("center_of_mass_debug_visible=%s" % str(bool(debug_state.get("center_of_mass_debug_visible", false))))
	lines.append("center_of_mass_debug_local=%s" % str(debug_state.get("center_of_mass_debug_local", Vector3.ZERO)))
	lines.append("center_of_mass_debug_origin_id=%s" % String(debug_state.get("center_of_mass_debug_origin_id", StringName())))
	lines.append("collision_debug_visual_count=%d" % int(debug_state.get("collision_debug_visual_count", 0)))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
