extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_open_modes_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_open_modes_library.tres"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	library_state.save_file_path = TEMP_SAVE_FILE_PATH
	library_state.saved_wips.clear()
	library_state.selected_wip_id = StringName()

	var melee_wip: CraftedItemWIP = _create_saved_wip(
		library_state,
		"Verifier Melee",
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var shield_wip: CraftedItemWIP = _create_saved_wip(
		library_state,
		"Verifier Shield",
		CraftedItemWIPScript.BUILDER_PATH_SHIELD,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var ranged_wip: CraftedItemWIP = _create_saved_wip(
		library_state,
		"Verifier Bow",
		CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL,
		CraftedItemWIPScript.BUILDER_COMPONENT_BOW
	)
	var magic_wip: CraftedItemWIP = _create_saved_wip(
		library_state,
		"Verifier Magic",
		CraftedItemWIPScript.BUILDER_PATH_MAGIC,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Verifier")
	await process_frame

	ui.call("_on_project_item_activated", 0)
	await process_frame
	var unarmed_slot: StringName = ui.get_active_open_dominant_slot_id()
	var unarmed_two_hand: bool = ui.is_active_open_two_hand()
	var unarmed_wip_id: StringName = ui.get_active_saved_wip_id()
	var unarmed_debug: Dictionary = ui.get_preview_debug_state()

	ui.call("_on_project_item_activated", 1)
	await process_frame
	var melee_slot: StringName = ui.get_active_open_dominant_slot_id()
	var melee_two_hand: bool = ui.is_active_open_two_hand()
	var melee_debug: Dictionary = ui.get_preview_debug_state()

	ui.call("_on_project_item_activated", 2)
	await process_frame
	var shield_slot: StringName = ui.get_active_open_dominant_slot_id()
	var shield_two_hand: bool = ui.is_active_open_two_hand()

	ui.call("_on_project_item_activated", 3)
	await process_frame
	var ranged_slot: StringName = ui.get_active_open_dominant_slot_id()
	var ranged_two_hand: bool = ui.is_active_open_two_hand()

	ui.call("_on_project_item_activated", 4)
	await process_frame
	var magic_slot: StringName = ui.get_active_open_dominant_slot_id()
	var magic_two_hand: bool = ui.is_active_open_two_hand()
	var magic_debug: Dictionary = ui.get_preview_debug_state()

	var custom_open_ok: bool = ui.open_saved_wip_with_hand_setup(melee_wip.wip_id, &"hand_left", true, false)
	await process_frame
	var custom_slot: StringName = ui.get_active_open_dominant_slot_id()
	var custom_two_hand: bool = ui.is_active_open_two_hand()
	var custom_debug: Dictionary = ui.get_preview_debug_state()

	ui.call("_show_weapon_open_primary_popup_for_index", 1)
	await process_frame
	var primary_popup: PopupMenu = ui.weapon_open_primary_popup
	var primary_popup_visible: bool = primary_popup != null and primary_popup.visible
	var primary_item_0: String = primary_popup.get_item_text(0) if primary_popup != null and primary_popup.get_item_count() > 0 else ""
	var primary_item_1: String = primary_popup.get_item_text(1) if primary_popup != null and primary_popup.get_item_count() > 1 else ""
	var primary_item_2: String = primary_popup.get_item_text(2) if primary_popup != null and primary_popup.get_item_count() > 2 else ""

	ui.call("_on_weapon_open_primary_popup_id_pressed", 1001)
	await process_frame
	var variant_popup: PopupMenu = ui.weapon_open_variant_popup
	var variant_popup_visible: bool = variant_popup != null and variant_popup.visible
	var variant_item_0: String = variant_popup.get_item_text(0) if variant_popup != null and variant_popup.get_item_count() > 0 else ""
	var variant_item_1: String = variant_popup.get_item_text(1) if variant_popup != null and variant_popup.get_item_count() > 1 else ""
	var variant_item_2: String = variant_popup.get_item_text(2) if variant_popup != null and variant_popup.get_item_count() > 2 else ""

	var lines: PackedStringArray = []
	lines.append("melee_wip_id=%s" % String(melee_wip.wip_id if melee_wip != null else StringName()))
	lines.append("shield_wip_id=%s" % String(shield_wip.wip_id if shield_wip != null else StringName()))
	lines.append("ranged_wip_id=%s" % String(ranged_wip.wip_id if ranged_wip != null else StringName()))
	lines.append("magic_wip_id=%s" % String(magic_wip.wip_id if magic_wip != null else StringName()))
	lines.append("unarmed_wip_id=%s" % String(unarmed_wip_id))
	lines.append("unarmed_default_slot=%s" % String(unarmed_slot))
	lines.append("unarmed_default_two_hand=%s" % str(unarmed_two_hand))
	lines.append("unarmed_preview_unarmed_proxy=%s" % str(bool(unarmed_debug.get("held_item_is_unarmed_proxy", false))))
	lines.append("melee_default_slot=%s" % String(melee_slot))
	lines.append("melee_default_two_hand=%s" % str(melee_two_hand))
	lines.append("melee_preview_slot=%s" % String(melee_debug.get("dominant_slot_id", StringName())))
	lines.append("melee_preview_two_hand=%s" % str(bool(melee_debug.get("default_two_hand", false))))
	lines.append("shield_default_slot=%s" % String(shield_slot))
	lines.append("shield_default_two_hand=%s" % str(shield_two_hand))
	lines.append("ranged_default_slot=%s" % String(ranged_slot))
	lines.append("ranged_default_two_hand=%s" % str(ranged_two_hand))
	lines.append("magic_default_slot=%s" % String(magic_slot))
	lines.append("magic_default_two_hand=%s" % str(magic_two_hand))
	lines.append("magic_preview_slot=%s" % String(magic_debug.get("dominant_slot_id", StringName())))
	lines.append("magic_preview_two_hand=%s" % str(bool(magic_debug.get("default_two_hand", false))))
	lines.append("custom_open_ok=%s" % str(custom_open_ok))
	lines.append("custom_slot=%s" % String(custom_slot))
	lines.append("custom_two_hand=%s" % str(custom_two_hand))
	lines.append("custom_preview_slot=%s" % String(custom_debug.get("dominant_slot_id", StringName())))
	lines.append("custom_preview_two_hand=%s" % str(bool(custom_debug.get("default_two_hand", false))))
	lines.append("primary_popup_visible=%s" % str(primary_popup_visible))
	lines.append("primary_popup_item_0=%s" % primary_item_0)
	lines.append("primary_popup_item_1=%s" % primary_item_1)
	lines.append("primary_popup_item_2=%s" % primary_item_2)
	lines.append("variant_popup_visible=%s" % str(variant_popup_visible))
	lines.append("variant_popup_item_0=%s" % variant_item_0)
	lines.append("variant_popup_item_1=%s" % variant_item_1)
	lines.append("variant_popup_item_2=%s" % variant_item_2)

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _create_saved_wip(
	library_state: PlayerForgeWipLibraryState,
	project_name: String,
	builder_path_id: StringName,
	builder_component_id: StringName
) -> CraftedItemWIP:
	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.forge_project_name = project_name
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		builder_path_id,
		builder_component_id
	)
	return library_state.save_wip(source_wip)
