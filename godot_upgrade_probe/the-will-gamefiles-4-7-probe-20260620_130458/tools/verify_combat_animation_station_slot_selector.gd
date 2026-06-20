extends SceneTree

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_animation_station_slot_selector_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/verify_combat_animation_station_slot_selector_library.tres"

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

	var source_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	source_wip.forge_project_name = "Combat Slot Selector Test WIP"
	CraftedItemWIPScript.apply_builder_path_defaults(
		source_wip,
		CraftedItemWIPScript.BUILDER_PATH_MELEE,
		CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	)
	var station_state: Resource = source_wip.ensure_combat_animation_station_state()
	var legacy_draft: Resource = CombatAnimationDraftScript.new()
	if legacy_draft != null:
		legacy_draft.set("draft_id", &"legacy_custom_skill_draft")
		legacy_draft.set("display_name", "Legacy Custom")
		legacy_draft.set("draft_kind", CombatAnimationDraftScript.DRAFT_KIND_SKILL)
		legacy_draft.set("owning_skill_id", &"skill_legacy_custom")
		legacy_draft.call("ensure_minimum_baseline_nodes")
	if station_state != null and legacy_draft != null:
		var seeded_skill_drafts: Array = station_state.get("skill_drafts") as Array
		seeded_skill_drafts.append(legacy_draft)
		station_state.set("skill_drafts", seeded_skill_drafts)
		station_state.set("selected_skill_id", &"skill_legacy_custom")
	var saved_wip: CraftedItemWIP = library_state.save_wip(source_wip)

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library_state
	get_root().add_child(fake_player)

	var ui = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(ui)
	await process_frame
	ui.open_for(fake_player, "SlotSelectorVerifier")
	await process_frame
	ui.select_saved_wip(saved_wip.wip_id)
	await process_frame

	var slot_grid: GridContainer = ui.get("skill_slot_grid") as GridContainer
	var slot_grid_count: int = slot_grid.get_child_count() if slot_grid != null else 0
	var first_slot_tooltip: String = ""
	if slot_grid != null and slot_grid.get_child_count() > 0:
		var first_button: Button = slot_grid.get_child(0) as Button
		first_slot_tooltip = first_button.tooltip_text if first_button != null else ""

	var select_skill_slot_ok: bool = ui.select_skill_slot(&"skill_slot_4")
	await process_frame
	var active_draft_after_skill_slot: Resource = ui.call("_get_active_draft") as Resource
	var active_slot_after_skill_slot: StringName = StringName(active_draft_after_skill_slot.get("legal_slot_id")) if active_draft_after_skill_slot != null else StringName()
	var active_identifier_after_skill_slot: StringName = ui.get_active_draft_identifier()

	var select_block_slot_ok: bool = ui.select_skill_slot(&"skill_block")
	await process_frame
	var active_draft_after_block: Resource = ui.call("_get_active_draft") as Resource
	var active_slot_after_block: StringName = StringName(active_draft_after_block.get("legal_slot_id")) if active_draft_after_block != null else StringName()
	var active_identifier_after_block: StringName = ui.get_active_draft_identifier()
	var reloaded_wip: CraftedItemWIP = library_state.get_saved_wip_clone(saved_wip.wip_id)
	var reloaded_station_state: Resource = reloaded_wip.ensure_combat_animation_station_state() if reloaded_wip != null else null
	var reloaded_skill_drafts: Array = reloaded_station_state.get("skill_drafts") as Array if reloaded_station_state != null else []
	var legacy_custom_removed: bool = true
	for draft_variant: Variant in reloaded_skill_drafts:
		var draft: Resource = draft_variant as Resource
		if draft == null:
			continue
		if StringName(draft.get("owning_skill_id")) == &"skill_legacy_custom":
			legacy_custom_removed = false
			break

	var lines: PackedStringArray = []
	lines.append("slot_grid_exists=%s" % str(slot_grid != null))
	lines.append("slot_grid_count=%d" % slot_grid_count)
	lines.append("first_slot_tooltip=%s" % first_slot_tooltip)
	lines.append("select_skill_slot_ok=%s" % str(select_skill_slot_ok))
	lines.append("active_identifier_after_skill_slot=%s" % String(active_identifier_after_skill_slot))
	lines.append("active_slot_after_skill_slot=%s" % String(active_slot_after_skill_slot))
	lines.append("select_block_slot_ok=%s" % str(select_block_slot_ok))
	lines.append("active_identifier_after_block=%s" % String(active_identifier_after_block))
	lines.append("active_slot_after_block=%s" % String(active_slot_after_block))
	lines.append("legacy_custom_removed=%s" % str(legacy_custom_removed))
	lines.append("reloaded_skill_draft_count=%d" % reloaded_skill_drafts.size())

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
