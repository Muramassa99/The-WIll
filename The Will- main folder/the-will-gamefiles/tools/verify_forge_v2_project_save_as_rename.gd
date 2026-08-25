extends SceneTree

const CraftingBenchUIV2Scene = preload(
	"res://scenes/ui_v2/crafting_bench_ui_v2.tscn"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2KeybindingStateScript = preload(
	"res://runtime/forge_v2/forge_v2_keybinding_state.gd"
)
const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const PlayerToolProfileLibraryStateScript = preload(
	"res://core/models/player_tool_profile_library_state.gd"
)
const CombatRuntimeClipScript = preload(
	"res://core/models/combat_runtime_clip.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_project_save_as_rename_2026-08-25.txt"
)
const TEMP_LIBRARY_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_project_save_as_rename_library.tres"
)
const TEMP_PROFILE_LIBRARY_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_project_save_as_rename_profiles.tres"
)
const TEMP_KEYBINDING_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_project_save_as_rename_keybindings.json"
)
const TEMP_FAILURE_LIBRARY_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_project_save_as_rename_rollback_seed.tres"
)
const TEMP_FAILURE_BLOCKER_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_project_save_as_rename_not_a_directory"
)

const SOURCE_NAME := "Source Alpha"
const FIRST_COPY_NAME := "Rapid Copy One"
const SECOND_COPY_NAME := "Rapid Copy Two"
const RENAMED_SOURCE_NAME := "Renamed Source Alpha"
const SOURCE_NOTES := "source-persisted-marker"
const COPY_NOTES := "copy-only-unsaved-marker"
const ORDINARY_SAVE_NOTES := "ordinary-save-marker"
const CAS_TEST_SKILL_ID := &"skill_slot_12"
const CAS_TEST_DRAFT_ID := &"verify_save_as_sidecar_draft"
const CAS_TEST_DISPLAY_NAME := "Verifier Sidecar Skill"
const CAS_TEST_STATION_NOTES := "recognizable-station-authoring-marker"
const CAS_TEST_DRAFT_NOTES := "recognizable-draft-authoring-marker"
const CAS_TEST_SKILL_NAME := "Verifier Preserved Skill"
const CAS_TEST_SKILL_DESCRIPTION := "Save As must preserve this authoring"
const CAS_TEST_RUNTIME_SIGNATURE := "stale-runtime-signature-must-not-fork"
const CAS_TEST_RUNTIME_CLIP_ID := &"stale_runtime_clip_must_not_fork"


class FakePlayer:
	extends Node

	var ui_mode_enabled := false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled


var result_lines: PackedStringArray = []
var finished := false


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_cleanup_temp_files()
	result_lines.append("scope=forge_v2_save_as_rmb_rename_delete")

	var library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	library.save_file_path = TEMP_LIBRARY_PATH
	library.saved_wips.clear()
	library.selected_wip_id = StringName()
	if not _check(library.persist(), "isolated WIP library did not persist"):
		return

	var player := FakePlayer.new()
	player.forge_wip_library_state = library
	get_root().add_child(player)

	var controller: Node = ForgeV2StageControllerScript.new()
	get_root().add_child(controller)
	controller.call("start_new_draft", SOURCE_NAME)
	var initial_state := controller.call("get_active_authoring_state") as Resource
	initial_state.set("project_name", SOURCE_NAME)
	initial_state.set("project_notes", SOURCE_NOTES)
	initial_state.set("active_tool_id", &"tool_spline_line")

	var ui: CanvasLayer = CraftingBenchUIV2Scene.instantiate() as CanvasLayer
	var profile_library: Resource = PlayerToolProfileLibraryStateScript.new()
	profile_library.set("save_file_path", TEMP_PROFILE_LIBRARY_PATH)
	ui.set("tool_profile_library_state", profile_library)
	var keybinding_state: Resource = ForgeV2KeybindingStateScript.new()
	keybinding_state.set("save_file_path", TEMP_KEYBINDING_PATH)
	ui.set("keybinding_state", keybinding_state)
	get_root().add_child(ui)
	await process_frame
	ui.call("open_for", player, controller, "Project Action Verify", null)
	await process_frame

	if not _verify_draft_menu_contract(ui):
		return

	_set_runtime_mesh_provider(controller)
	if not _check(
		bool(ui.call("_save_current_v2_draft")),
		"initial ordinary Save did not establish a stable saved identity"
	):
		return
	var source_id := StringName(controller.call("get_active_saved_wip_id"))
	var source_wip: CraftedItemWIP = library.get_saved_wip_clone(source_id, true)
	if not _check(
		source_id != StringName()
		and source_wip != null
		and library.saved_wips.size() == 1,
		"initial Save did not establish exactly one stable source identity"
	):
		return
	source_wip = _seed_source_combat_authoring(library, source_id)
	if not _check(
		source_wip != null and library.saved_wips.size() == 1,
		"could not seed source Combat Animation Station authoring/cache"
	):
		return
	if not _verify_wip_identity(source_wip, source_id, "source after Save"):
		return
	if not _verify_combat_sidecar(source_wip, true, "seeded source"):
		return
	var source_snapshot := _capture_wip_snapshot(source_wip)
	var source_combat_snapshot := _capture_combat_sidecar(source_wip)
	result_lines.append("source_id=%s" % String(source_id))

	var active_state := controller.call("get_active_authoring_state") as Resource
	active_state.set("project_notes", COPY_NOTES)
	_set_runtime_mesh_provider(controller)
	ui.call("_rebuild_v2_action_menus")
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := draft_button.get_popup()
	var save_as_index := _find_popup_item_index(draft_popup, "Save As...")
	if not _check(save_as_index >= 0, "Save As menu item disappeared before use"):
		return
	ui.call("_on_v2_menu_id_pressed", draft_popup.get_item_id(save_as_index))
	await process_frame
	var name_popup := ui.get("v2_wip_name_popup") as PopupPanel
	var name_line_edit := ui.get("v2_wip_name_line_edit") as LineEdit
	var name_save_button := ui.get("v2_wip_name_confirm_button") as Button
	var name_cancel_button := _find_button_by_text(name_popup, "Cancel")
	if not _check(
		is_instance_valid(name_popup)
		and name_popup.visible
		and is_instance_valid(name_line_edit)
		and is_instance_valid(name_save_button)
		and name_save_button.text == "Save"
		and is_instance_valid(name_cancel_button),
		"Save As dialog did not expose Save/Cancel controls"
	):
		return
	name_line_edit.text = "  %s  " % FIRST_COPY_NAME
	var rapid_save_as_started_msec := Time.get_ticks_msec()
	name_save_button.emit_signal("pressed")
	var first_copy_id := StringName(controller.call("get_active_saved_wip_id"))
	_set_runtime_mesh_provider(controller)
	if not _check(
		bool(ui.call("_save_current_v2_draft_as", SECOND_COPY_NAME)),
		"second immediate Save As failed"
	):
		return
	var rapid_save_as_elapsed_msec := (
		Time.get_ticks_msec() - rapid_save_as_started_msec
	)
	var second_copy_id := StringName(controller.call("get_active_saved_wip_id"))
	result_lines.append(
		"rapid_save_as_elapsed_msec=%d" % rapid_save_as_elapsed_msec
	)
	result_lines.append("first_copy_id=%s" % String(first_copy_id))
	result_lines.append("second_copy_id=%s" % String(second_copy_id))
	if not _check(
		first_copy_id != StringName()
		and second_copy_id != StringName()
		and first_copy_id != source_id
		and second_copy_id != source_id
		and second_copy_id != first_copy_id
		and library.saved_wips.size() == 3,
		"rapid consecutive Save As collided with or overwrote a stable WIP ID"
	):
		return

	var source_after_save_as := library.get_saved_wip_clone(source_id, true)
	var first_copy_wip := library.get_saved_wip_clone(first_copy_id, true)
	var second_copy_wip := library.get_saved_wip_clone(second_copy_id, true)
	if not _check(
		_capture_wip_snapshot(source_after_save_as) == source_snapshot,
		"Save As mutated the saved source WIP"
	):
		return
	if not _check(
		_capture_combat_sidecar(source_after_save_as)
		== source_combat_snapshot,
		"Save As mutated the source Combat Animation authoring/cache"
	):
		return
	if not _verify_wip_identity(
		first_copy_wip,
		first_copy_id,
		"first rapid Save As copy"
	):
		return
	if not _verify_wip_identity(
		second_copy_wip,
		second_copy_id,
		"second rapid Save As copy"
	):
		return
	if not _verify_combat_sidecar(
		first_copy_wip,
		false,
		"first rapid Save As copy"
	):
		return
	if not _verify_combat_sidecar(
		second_copy_wip,
		false,
		"second rapid Save As copy"
	):
		return
	if not _check(
		first_copy_wip.forge_project_name == FIRST_COPY_NAME
		and second_copy_wip.forge_project_name == SECOND_COPY_NAME
		and String(
			first_copy_wip.forge_v2_authoring_state.get("project_name")
		) == FIRST_COPY_NAME
		and String(
			second_copy_wip.forge_v2_authoring_state.get("project_name")
		) == SECOND_COPY_NAME
		and first_copy_wip.forge_project_notes == COPY_NOTES
		and second_copy_wip.forge_project_notes == COPY_NOTES,
		"Save As did not align requested outer/nested names and active content"
	):
		return
	var source_draft_id := StringName(
		source_after_save_as.forge_v2_authoring_state.get("draft_id")
	)
	var first_copy_draft_id := StringName(
		first_copy_wip.forge_v2_authoring_state.get("draft_id")
	)
	var second_copy_draft_id := StringName(
		second_copy_wip.forge_v2_authoring_state.get("draft_id")
	)
	result_lines.append(
		"draft_ids=source:%s first:%s second:%s"
		% [
			String(source_draft_id),
			String(first_copy_draft_id),
			String(second_copy_draft_id),
		]
	)
	if not _check(
		source_draft_id != StringName()
		and first_copy_draft_id != StringName()
		and second_copy_draft_id != StringName()
		and source_draft_id != first_copy_draft_id
		and source_draft_id != second_copy_draft_id
		and first_copy_draft_id != second_copy_draft_id,
		"source and rapid Save As copies did not receive distinct V2 draft IDs"
	):
		return
	var first_copy_snapshot := _capture_wip_snapshot(first_copy_wip)
	var first_copy_combat_snapshot := _capture_combat_sidecar(first_copy_wip)

	active_state = controller.call("get_active_authoring_state") as Resource
	active_state.set("project_notes", ORDINARY_SAVE_NOTES)
	_set_runtime_mesh_provider(controller)
	if not _check(
		bool(ui.call("_save_current_v2_draft")),
		"ordinary Save after Save As failed"
	):
		return
	if not _check(
		library.saved_wips.size() == 3
		and StringName(controller.call("get_active_saved_wip_id"))
		== second_copy_id
		and library.selected_wip_id == second_copy_id,
		"ordinary Save after Save As created or selected the wrong WIP"
	):
		return
	if not _check(
		_capture_wip_snapshot(library.get_saved_wip_clone(source_id, true))
		== source_snapshot
		and _capture_wip_snapshot(
			library.get_saved_wip_clone(first_copy_id, true)
		) == first_copy_snapshot,
		"ordinary Save after Save As mutated an earlier WIP"
	):
		return
	if not _check(
		_capture_combat_sidecar(
			library.get_saved_wip_clone(source_id, true)
		) == source_combat_snapshot
		and _capture_combat_sidecar(
			library.get_saved_wip_clone(first_copy_id, true)
		) == first_copy_combat_snapshot,
		"ordinary Save mutated an earlier Combat Animation sidecar"
	):
		return
	second_copy_wip = library.get_saved_wip_clone(second_copy_id, true)
	if not _verify_wip_identity(
		second_copy_wip,
		second_copy_id,
		"ordinary-saved second copy"
	):
		return
	if not _check(
		second_copy_wip.forge_project_notes == ORDINARY_SAVE_NOTES,
		"ordinary Save did not update the active Save As target"
	):
		return
	if not _verify_combat_sidecar(
		second_copy_wip,
		false,
		"ordinary-saved second copy"
	):
		return

	if not _verify_disk_state(
		[source_id, first_copy_id, second_copy_id],
		second_copy_id,
		{
			source_id: SOURCE_NAME,
			first_copy_id: FIRST_COPY_NAME,
			second_copy_id: SECOND_COPY_NAME,
		}
	):
		return
	if not _verify_disk_combat_sidecars(
		source_id,
		first_copy_id,
		second_copy_id,
		source_combat_snapshot
	):
		return

	if not await _verify_rmb_rename_flow(
		ui,
		controller,
		library,
		source_id,
		second_copy_id
	):
		return
	if not await _verify_delete_flow(
		ui,
		controller,
		library,
		source_id,
		first_copy_id,
		second_copy_id
	):
		return
	if not _verify_persistence_failure_rollbacks():
		return

	_finish(true)


func _seed_source_combat_authoring(
	library: PlayerForgeWipLibraryState,
	source_id: StringName
) -> CraftedItemWIP:
	var source_wip := library.get_saved_wip_clone(source_id, true)
	if source_wip == null:
		return null
	var station_state := source_wip.ensure_combat_animation_station_state()
	if station_state == null:
		return null
	station_state.set("station_notes", CAS_TEST_STATION_NOTES)
	station_state.set("selected_authoring_mode", &"author_skill")
	station_state.set("selected_skill_id", CAS_TEST_SKILL_ID)
	var draft := station_state.call(
		"get_or_create_skill_draft",
		CAS_TEST_SKILL_ID,
		CAS_TEST_DISPLAY_NAME,
		&"grip_reverse",
		CAS_TEST_SKILL_ID
	) as Resource
	if draft == null:
		return null
	draft.set("draft_id", CAS_TEST_DRAFT_ID)
	draft.set("display_name", CAS_TEST_DISPLAY_NAME)
	draft.set("draft_notes", CAS_TEST_DRAFT_NOTES)
	draft.set("skill_name", CAS_TEST_SKILL_NAME)
	draft.set("skill_description", CAS_TEST_SKILL_DESCRIPTION)
	draft.set("preview_playback_speed_scale", 1.37)
	var stale_runtime_clip := CombatRuntimeClipScript.new() as Resource
	stale_runtime_clip.set("clip_id", CAS_TEST_RUNTIME_CLIP_ID)
	stale_runtime_clip.set("source_draft_id", CAS_TEST_DRAFT_ID)
	stale_runtime_clip.set("source_skill_slot_id", CAS_TEST_SKILL_ID)
	stale_runtime_clip.set("baked_frame_times", PackedFloat32Array([0.0]))
	draft.set("baked_runtime_clip", stale_runtime_clip)
	draft.set("runtime_cache_signature", CAS_TEST_RUNTIME_SIGNATURE)
	return library.save_wip(source_wip)


func _capture_combat_sidecar(wip: CraftedItemWIP) -> Dictionary:
	if wip == null or wip.combat_animation_station_state == null:
		return {}
	var station_state := wip.combat_animation_station_state as Resource
	var test_draft: Resource = null
	var skill_drafts := station_state.get("skill_drafts") as Array
	for draft_variant: Variant in skill_drafts:
		var draft := draft_variant as Resource
		if (
			draft != null
			and StringName(draft.get("owning_skill_id"))
			== CAS_TEST_SKILL_ID
		):
			test_draft = draft
			break
	if test_draft == null:
		return {
			"station_notes": String(station_state.get("station_notes")),
			"selected_skill_id": StringName(
				station_state.get("selected_skill_id")
			),
			"draft_present": false,
		}
	var runtime_clip := test_draft.get("baked_runtime_clip") as Resource
	return {
		"station_notes": String(station_state.get("station_notes")),
		"selected_authoring_mode": StringName(
			station_state.get("selected_authoring_mode")
		),
		"selected_skill_id": StringName(
			station_state.get("selected_skill_id")
		),
		"draft_present": true,
		"draft_id": StringName(test_draft.get("draft_id")),
		"display_name": String(test_draft.get("display_name")),
		"owning_skill_id": StringName(test_draft.get("owning_skill_id")),
		"legal_slot_id": StringName(test_draft.get("legal_slot_id")),
		"preferred_grip_style_mode": StringName(
			test_draft.get("preferred_grip_style_mode")
		),
		"draft_notes": String(test_draft.get("draft_notes")),
		"skill_name": String(test_draft.get("skill_name")),
		"skill_description": String(test_draft.get("skill_description")),
		"preview_playback_speed_scale": float(
			test_draft.get("preview_playback_speed_scale")
		),
		"runtime_clip_present": runtime_clip != null,
		"runtime_clip_id": (
			StringName(runtime_clip.get("clip_id"))
			if runtime_clip != null
			else StringName()
		),
		"runtime_cache_signature": String(
			test_draft.get("runtime_cache_signature")
		),
	}


func _verify_combat_sidecar(
	wip: CraftedItemWIP,
	expect_stale_runtime_cache: bool,
	label: String
) -> bool:
	var snapshot := _capture_combat_sidecar(wip)
	var expected_cache_present := expect_stale_runtime_cache
	result_lines.append(
		"combat_sidecar[%s]=draft:%s authoring:%s cache:%s signature:%s"
		% [
			label,
			String(snapshot.get("draft_id", StringName())),
			String(snapshot.get("draft_notes", "")),
			str(snapshot.get("runtime_clip_present", false)),
			String(snapshot.get("runtime_cache_signature", "")),
		]
	)
	return _check(
		bool(snapshot.get("draft_present", false))
		and String(snapshot.get("station_notes", ""))
		== CAS_TEST_STATION_NOTES
		and StringName(snapshot.get("selected_authoring_mode", StringName()))
		== &"author_skill"
		and StringName(snapshot.get("selected_skill_id", StringName()))
		== CAS_TEST_SKILL_ID
		and StringName(snapshot.get("draft_id", StringName()))
		== CAS_TEST_DRAFT_ID
		and String(snapshot.get("display_name", ""))
		== CAS_TEST_DISPLAY_NAME
		and StringName(snapshot.get("owning_skill_id", StringName()))
		== CAS_TEST_SKILL_ID
		and StringName(snapshot.get("legal_slot_id", StringName()))
		== CAS_TEST_SKILL_ID
		and StringName(
			snapshot.get("preferred_grip_style_mode", StringName())
		) == &"grip_reverse"
		and String(snapshot.get("draft_notes", ""))
		== CAS_TEST_DRAFT_NOTES
		and String(snapshot.get("skill_name", "")) == CAS_TEST_SKILL_NAME
		and String(snapshot.get("skill_description", ""))
		== CAS_TEST_SKILL_DESCRIPTION
		and is_equal_approx(
			float(snapshot.get("preview_playback_speed_scale", 0.0)),
			1.37
		)
		and bool(snapshot.get("runtime_clip_present", false))
		== expected_cache_present
		and (
			StringName(snapshot.get("runtime_clip_id", StringName()))
			== CAS_TEST_RUNTIME_CLIP_ID
			if expected_cache_present
			else StringName(snapshot.get(
				"runtime_clip_id",
				StringName()
			)) == StringName()
		)
		and (
			String(snapshot.get("runtime_cache_signature", ""))
			== CAS_TEST_RUNTIME_SIGNATURE
			if expected_cache_present
			else String(snapshot.get(
				"runtime_cache_signature",
				""
			)).is_empty()
		),
		"%s did not preserve Combat Animation authoring while applying the expected runtime-cache policy"
		% label
	)


func _verify_disk_combat_sidecars(
	source_id: StringName,
	first_copy_id: StringName,
	second_copy_id: StringName,
	source_combat_snapshot: Dictionary
) -> bool:
	var reloaded := ResourceLoader.load(
		TEMP_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if not _check(reloaded != null, "could not reload Combat sidecars from disk"):
		return false
	if not _check(
		_capture_combat_sidecar(reloaded.get_saved_wip(source_id))
		== source_combat_snapshot,
		"source Combat authoring/cache changed in persisted library"
	):
		return false
	if not _verify_combat_sidecar(
		reloaded.get_saved_wip(first_copy_id),
		false,
		"disk-reloaded first Save As copy"
	):
		return false
	return _verify_combat_sidecar(
		reloaded.get_saved_wip(second_copy_id),
		false,
		"disk-reloaded ordinary-saved copy"
	)


func _verify_persistence_failure_rollbacks() -> bool:
	for stale_path: String in [
		TEMP_FAILURE_LIBRARY_PATH,
		TEMP_FAILURE_BLOCKER_PATH,
	]:
		if FileAccess.file_exists(stale_path) or DirAccess.dir_exists_absolute(
			stale_path
		):
			DirAccess.remove_absolute(stale_path)
	var failure_library: PlayerForgeWipLibraryState = (
		PlayerForgeWipLibraryStateScript.new()
	)
	failure_library.save_file_path = TEMP_FAILURE_LIBRARY_PATH
	if not _check(
		failure_library.persist(),
		"rollback fixture could not persist its initial empty library"
	):
		return false
	var seed_wip := CraftedItemWIP.new()
	seed_wip.wip_id = &"rollback_seed_wip"
	seed_wip.forge_project_name = "Rollback Source"
	seed_wip.forge_project_notes = "must-survive-failed-persistence"
	var saved_seed := failure_library.save_wip(seed_wip)
	if not _check(
		saved_seed != null
		and failure_library.saved_wips.size() == 1
		and failure_library.selected_wip_id == seed_wip.wip_id,
		"rollback fixture could not establish its stable source WIP"
	):
		return false
	var seed_snapshot := _capture_wip_snapshot(
		failure_library.get_saved_wip_clone(seed_wip.wip_id, true)
	)
	var blocker_file := FileAccess.open(
		TEMP_FAILURE_BLOCKER_PATH,
		FileAccess.WRITE
	)
	if not _check(
		blocker_file != null,
		"could not create deterministic persistence-failure blocker file"
	):
		return false
	blocker_file.store_string("this file intentionally blocks a child path")
	blocker_file = null
	failure_library.save_file_path = (
		TEMP_FAILURE_BLOCKER_PATH + "/library.tres"
	)
	var selection_before := failure_library.selected_wip_id
	var renamed := failure_library.rename_saved_wip(
		seed_wip.wip_id,
		"Rename Must Roll Back"
	)
	if not _check(
		renamed == null
		and failure_library.saved_wips.size() == 1
		and failure_library.selected_wip_id == selection_before
		and _capture_wip_snapshot(
			failure_library.get_saved_wip_clone(seed_wip.wip_id, true)
		) == seed_snapshot,
		"failed Rename did not roll its in-memory record/selection back"
	):
		return false
	if not _check(
		not failure_library.delete_saved_wip(seed_wip.wip_id)
		and failure_library.saved_wips.size() == 1
		and failure_library.selected_wip_id == selection_before
		and _capture_wip_snapshot(
			failure_library.get_saved_wip_clone(seed_wip.wip_id, true)
		) == seed_snapshot,
		"failed Delete did not roll its record/selection back"
	):
		return false
	var failure_controller: Node = ForgeV2StageControllerScript.new()
	get_root().add_child(failure_controller)
	failure_controller.call("start_new_draft", "Rollback Unsaved Draft")
	_set_runtime_mesh_provider(failure_controller)
	var failed_save := failure_controller.call(
		"save_current_wip",
		failure_library
	) as CraftedItemWIP
	if not _check(
		failed_save == null
		and failure_library.saved_wips.size() == 1
		and failure_library.selected_wip_id == selection_before
		and failure_library.get_saved_wip(seed_wip.wip_id) != null
		and StringName(
			failure_controller.call("get_active_saved_wip_id")
		) == StringName(),
		"failed ordinary Save added/selected a WIP or attached the draft"
	):
		failure_controller.queue_free()
		return false
	_set_runtime_mesh_provider(failure_controller)
	var failed_save_as := failure_controller.call(
		"save_current_wip_as",
		failure_library,
		"Rollback Save As"
	) as CraftedItemWIP
	var rollback_ok := _check(
		failed_save_as == null
		and failure_library.saved_wips.size() == 1
		and failure_library.selected_wip_id == selection_before
		and _capture_wip_snapshot(
			failure_library.get_saved_wip_clone(seed_wip.wip_id, true)
		) == seed_snapshot
		and StringName(
			failure_controller.call("get_active_saved_wip_id")
		) == StringName(),
		"failed Save As added/selected a WIP, mutated source, or attached the draft"
	)
	failure_controller.queue_free()
	if rollback_ok:
		result_lines.append(
			"persistence_failure_rollbacks=rename,delete,save,save_as"
		)
	return rollback_ok


func _verify_draft_menu_contract(ui: CanvasLayer) -> bool:
	ui.call("_rebuild_v2_action_menus")
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := draft_button.get_popup() if draft_button != null else null
	if not _check(is_instance_valid(draft_popup), "Draft menu was not constructed"):
		return false
	var save_index := _find_popup_item_index(draft_popup, "Save Draft (Ctrl+S)")
	var save_as_index := _find_popup_item_index(draft_popup, "Save As...")
	var saved_submenu := draft_popup.get_node_or_null(
		"SavedV2DraftSubmenu"
	) as PopupMenu
	return _check(
		save_index >= 0
		and save_as_index == save_index + 1
		and is_instance_valid(saved_submenu)
		and _find_popup_item_index(draft_popup, "Saved V2 Drafts") >= 0,
		"Draft menu did not keep Save As directly below Save and the existing SavedV2DraftSubmenu"
	)


func _verify_rmb_rename_flow(
	ui: CanvasLayer,
	controller: Node,
	library: PlayerForgeWipLibraryState,
	source_id: StringName,
	active_id: StringName
) -> bool:
	if not await _verify_blank_rmb_noop(ui, controller, library, active_id):
		return false
	var context_panel := await _open_rmb_context_for_wip(ui, source_id)
	if not _check(
		is_instance_valid(context_panel)
		and bool(context_panel.visible)
		and StringName(ui.get("saved_v2_drafts_context_wip_id")) == source_id,
		"hovered saved-row RMB did not open the exact WIP context"
	):
		return false
	if not _check(
		StringName(controller.call("get_active_saved_wip_id")) == active_id
		and library.selected_wip_id == active_id,
		"RMB loaded the hovered WIP instead of opening its context"
	):
		return false
	var rename_button := _find_button_by_text(context_panel, "Rename")
	var delete_button := _find_button_by_text(context_panel, "Delete")
	if not _check(
		is_instance_valid(rename_button)
		and is_instance_valid(delete_button),
		"saved WIP mini context did not expose Rename/Delete"
	):
		return false
	rename_button.emit_signal("pressed")
	await process_frame
	var name_popup := ui.get("v2_wip_name_popup") as PopupPanel
	var name_edit := ui.get("v2_wip_name_line_edit") as LineEdit
	var save_button := ui.get("v2_wip_name_confirm_button") as Button
	var cancel_button := _find_button_by_text(name_popup, "Cancel")
	if not _verify_v2_wip_dialog_front_layer(
		ui,
		name_popup,
		name_edit,
		"Rename"
	):
		return false
	if not _check(
		is_instance_valid(name_popup)
		and name_popup.visible
		and name_edit.text == SOURCE_NAME
		and save_button.text == "Save"
		and is_instance_valid(cancel_button),
		"Rename dialog did not open with the exact name and Save/Cancel"
	):
		return false
	name_edit.text = "cancel-must-not-persist"
	cancel_button.emit_signal("pressed")
	await process_frame
	if not _check(
		library.get_saved_wip(source_id).forge_project_name == SOURCE_NAME,
		"Rename Cancel mutated the saved WIP"
	):
		return false

	context_panel = await _open_rmb_context_for_wip(ui, source_id)
	if not _check(is_instance_valid(context_panel), "RMB context did not reopen"):
		return false
	rename_button = _find_button_by_text(context_panel, "Rename")
	rename_button.emit_signal("pressed")
	await process_frame
	name_edit = ui.get("v2_wip_name_line_edit") as LineEdit
	save_button = ui.get("v2_wip_name_confirm_button") as Button
	name_edit.text = "  %s  " % RENAMED_SOURCE_NAME
	save_button.emit_signal("pressed")
	await process_frame
	var renamed_source := library.get_saved_wip_clone(source_id, true)
	if not _check(
		renamed_source != null
		and renamed_source.wip_id == source_id
		and renamed_source.forge_project_name == RENAMED_SOURCE_NAME
		and String(renamed_source.forge_v2_authoring_state.get("project_name"))
		== RENAMED_SOURCE_NAME
		and StringName(controller.call("get_active_saved_wip_id")) == active_id
		and library.selected_wip_id == active_id
		and library.saved_wips.size() == 3,
		"Rename changed identity/count/active authority or failed to persist both names"
	):
		return false
	return _verify_wip_identity(renamed_source, source_id, "renamed source")


func _verify_blank_rmb_noop(
	ui: CanvasLayer,
	controller: Node,
	library: PlayerForgeWipLibraryState,
	active_id: StringName
) -> bool:
	ui.call("_hide_saved_v2_draft_context_menu")
	ui.call("_rebuild_v2_action_menus")
	var selected_before := library.selected_wip_id
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := draft_button.get_popup()
	var saved_submenu := draft_popup.get_node_or_null(
		"SavedV2DraftSubmenu"
	) as PopupMenu
	if not _check(
		is_instance_valid(saved_submenu)
		and saved_submenu.has_method("set_focused_item"),
		"saved submenu cannot exercise blank focused-row RMB"
	):
		return false
	draft_button.show_popup()
	saved_submenu.popup(Rect2i(120, 120, 240, 120))
	await process_frame
	saved_submenu.call("set_focused_item", -1)
	await process_frame
	if not _check(
		saved_submenu.get_focused_item() == -1,
		"saved submenu retained a stale focused row after set_focused_item(-1)"
	):
		return false
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	right_click.position = Vector2(-100.0, -100.0)
	right_click.global_position = Vector2(-100.0, -100.0)
	saved_submenu.window_input.emit(right_click)
	await process_frame
	var context_panel := ui.get("saved_v2_drafts_context_panel") as PopupPanel
	return _check(
		(not is_instance_valid(context_panel) or not context_panel.visible)
		and StringName(ui.get("saved_v2_drafts_context_wip_id"))
		== StringName()
		and StringName(controller.call("get_active_saved_wip_id"))
		== active_id
		and library.selected_wip_id == selected_before,
		"blank-row RMB opened a stale context or mutated the active selection"
	)


func _verify_delete_flow(
	ui: CanvasLayer,
	controller: Node,
	library: PlayerForgeWipLibraryState,
	source_id: StringName,
	first_copy_id: StringName,
	active_id: StringName
) -> bool:
	var context_panel := await _open_rmb_context_for_wip(ui, source_id)
	if not _check(is_instance_valid(context_panel), "delete context did not open"):
		return false
	var delete_button := _find_button_by_text(context_panel, "Delete")
	delete_button.emit_signal("pressed")
	await process_frame
	var delete_popup := ui.get("v2_wip_delete_popup") as PopupPanel
	var prompt_label := ui.get("v2_wip_delete_prompt_label") as Label
	var no_button := _find_button_by_text(delete_popup, "No")
	var yes_button := _find_button_by_text(delete_popup, "Yes")
	if not _verify_v2_wip_dialog_front_layer(
		ui,
		delete_popup,
		no_button,
		"Delete"
	):
		return false
	var expected_prompt := (
		"Do you want to permanently delete %s?" % RENAMED_SOURCE_NAME
	)
	if not _check(
		is_instance_valid(delete_popup)
		and delete_popup.visible
		and prompt_label.text == expected_prompt
		and is_instance_valid(no_button)
		and is_instance_valid(yes_button)
		and yes_button.get_index() < no_button.get_index()
		and no_button.has_focus(),
		"Delete confirmation did not show Yes | No with safe default focus on No"
	):
		return false
	no_button.emit_signal("pressed")
	await process_frame
	if not _check(
		library.get_saved_wip(source_id) != null
		and StringName(controller.call("get_active_saved_wip_id")) == active_id,
		"Delete No removed or loaded a WIP"
	):
		return false

	context_panel = await _open_rmb_context_for_wip(ui, source_id)
	delete_button = _find_button_by_text(context_panel, "Delete")
	delete_button.emit_signal("pressed")
	await process_frame
	delete_popup = ui.get("v2_wip_delete_popup") as PopupPanel
	yes_button = _find_button_by_text(delete_popup, "Yes")
	yes_button.emit_signal("pressed")
	await process_frame
	if not _check(
		library.get_saved_wip(source_id) == null
		and library.saved_wips.size() == 2
		and library.get_saved_wip(first_copy_id) != null
		and library.get_saved_wip(active_id) != null
		and StringName(controller.call("get_active_saved_wip_id")) == active_id,
		"confirmed inactive Delete was not a permanent exact-record removal"
	):
		return false
	if not await _verify_deleted_v2_wip_absent_everywhere(
		ui,
		controller,
		library,
		source_id,
		"inactive"
	):
		return false

	var active_state := controller.call("get_active_authoring_state") as Resource
	var discarded_project_marker := "Delete Must Discard This Project"
	var discarded_notes_marker := "delete-must-not-leave-recovery-notes"
	active_state.set("project_name", discarded_project_marker)
	active_state.set("project_notes", discarded_notes_marker)
	var discarded_body := active_state.call(
		"append_sample_material_body"
	) as Resource
	active_state.set("spline_line_points", PackedVector3Array([
		Vector3(0.03, 0.04, 0.05),
		Vector3(0.11, 0.12, 0.13),
	]))
	active_state.set("spline_line_surface_normals", PackedVector3Array([
		Vector3.UP,
		Vector3.UP,
	]))
	active_state.set("detailing_resolved_path_points", PackedVector3Array([
		Vector3(0.02, 0.03, 0.04),
	]))
	if not _check(
		discarded_body != null
		and not (active_state.get("material_bodies") as Array).is_empty()
		and not (
			active_state.get("spline_line_points") as PackedVector3Array
		).is_empty(),
		"active-delete fixture did not contain disposable body/geometry data"
	):
		return false
	var active_state_instance_id := active_state.get_instance_id()
	var active_draft_id := StringName(active_state.get("draft_id"))
	context_panel = await _open_rmb_context_for_wip(ui, active_id)
	delete_button = _find_button_by_text(context_panel, "Delete")
	delete_button.emit_signal("pressed")
	await process_frame
	delete_popup = ui.get("v2_wip_delete_popup") as PopupPanel
	prompt_label = ui.get("v2_wip_delete_prompt_label") as Label
	if not _check(
		prompt_label.text
		== "Do you want to permanently delete %s?" % SECOND_COPY_NAME,
		"active-WIP Delete confirmation did not name the exact target"
	):
		return false
	yes_button = _find_button_by_text(delete_popup, "Yes")
	yes_button.emit_signal("pressed")
	await process_frame
	active_state = controller.call("get_active_authoring_state") as Resource
	var blank_summary := controller.call("get_status_summary") as Dictionary
	if not _check(
		library.get_saved_wip(active_id) == null
		and library.saved_wips.size() == 1
		and library.get_saved_wip(first_copy_id) != null
		and StringName(controller.call("get_active_saved_wip_id"))
		== StringName()
		and library.selected_wip_id == StringName()
		and StringName(active_state.get("source_wip_id")) == StringName()
		and active_state.get_instance_id() != active_state_instance_id
		and StringName(active_state.get("draft_id")) != active_draft_id
		and String(active_state.get("project_name"))
		== String(controller.get("default_project_name"))
		and String(active_state.get("project_name"))
		!= discarded_project_marker
		and String(active_state.get("project_notes")).is_empty()
		and String(active_state.get("project_notes"))
		!= discarded_notes_marker
		and StringName(active_state.get("selected_material_body_id"))
		== StringName()
		and (active_state.get("material_bodies") as Array).is_empty()
		and (active_state.get("volume_strokes") as Array).is_empty()
		and (
			active_state.get("spline_line_points") as PackedVector3Array
		).is_empty()
		and (
			active_state.get(
				"spline_line_surface_normals"
			) as PackedVector3Array
		).is_empty()
		and (
			active_state.get(
				"detailing_resolved_path_points"
			) as PackedVector3Array
		).is_empty()
		and (
			active_state.get(
				"active_handle_control_points_2d_meters"
			) as PackedVector2Array
		).is_empty()
		and (
			active_state.get(
				"active_basic_control_points_2d_meters"
			) as PackedVector2Array
		).is_empty()
		and (active_state.get("forge_layers") as Array).is_empty()
		and (active_state.get("undone_forge_layers") as Array).is_empty()
		and (active_state.get("protected_forge_layers") as Array).is_empty()
		and int(blank_summary.get("material_body_count", -1)) == 0
		and int(blank_summary.get("user_material_body_count", -1)) == 0
		and int(blank_summary.get("pending_material_body_count", -1)) == 0
		and int(blank_summary.get("committed_layer_count", -1)) == 0,
		"permanent active Delete left a recovery state, project metadata, body, or geometry behind"
	):
		return false
	if not await _verify_deleted_v2_wip_absent_everywhere(
		ui,
		controller,
		library,
		active_id,
		"active"
	):
		return false

	_set_runtime_mesh_provider(controller)
	var ctrl_s_event := InputEventKey.new()
	ctrl_s_event.pressed = true
	ctrl_s_event.ctrl_pressed = true
	ctrl_s_event.keycode = KEY_S
	ctrl_s_event.physical_keycode = KEY_S
	ui.call("_unhandled_input", ctrl_s_event)
	await process_frame
	var replacement_saved_id := StringName(
		controller.call("get_active_saved_wip_id")
	)
	var replacement_wip := library.get_saved_wip_clone(
		replacement_saved_id,
		true
	)
	if not _check(
		replacement_saved_id != StringName()
		and replacement_saved_id != active_id
		and replacement_saved_id != source_id
		and replacement_saved_id != first_copy_id
		and library.selected_wip_id == replacement_saved_id
		and library.saved_wips.size() == 2
		and library.get_saved_wip(active_id) == null
		and library.get_saved_wip(source_id) == null
		and replacement_wip != null
		and replacement_wip.forge_project_name
		== String(controller.get("default_project_name"))
		and replacement_wip.forge_project_notes.is_empty()
		and (
			replacement_wip.forge_v2_authoring_state.get(
				"material_bodies"
			) as Array
		).is_empty(),
		"Ctrl+S after permanent active Delete did not create a fresh unrelated blank WIP identity"
	):
		return false
	if not _verify_wip_identity(
		replacement_wip,
		replacement_saved_id,
		"Ctrl+S replacement after active Delete"
	):
		return false
	ui.call("_rebuild_v2_action_menus")
	if not _verify_deleted_v2_wip_absent_from_menu(
		ui,
		library,
		active_id,
		"post-Ctrl+S active delete"
	):
		return false
	if not _verify_deleted_v2_wip_absent_from_menu(
		ui,
		library,
		source_id,
		"post-Ctrl+S inactive delete"
	):
		return false
	result_lines.append(
		(
			"active_delete_blank_replacement=state_changed:true "
			+ "metadata_empty:true geometry_empty:true ctrl_s_new_id:%s"
		)
		% String(replacement_saved_id)
	)

	var reloaded := ResourceLoader.load(
		TEMP_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	return _check(
		reloaded != null
		and reloaded.saved_wips.size() == 2
		and reloaded.get_saved_wip(source_id) == null
		and reloaded.get_saved_wip(active_id) == null
		and reloaded.get_saved_wip(first_copy_id) != null
		and reloaded.get_saved_wip(replacement_saved_id) != null
		and reloaded.selected_wip_id == replacement_saved_id,
		"permanent Delete absence or fresh Ctrl+S identity did not persist to disk"
	)


func _verify_deleted_v2_wip_absent_everywhere(
	ui: CanvasLayer,
	controller: Node,
	library: PlayerForgeWipLibraryState,
	deleted_wip_id: StringName,
	deletion_label: String
) -> bool:
	if not _verify_deleted_v2_wip_absent_from_menu(
		ui,
		library,
		deleted_wip_id,
		"%s immediate rebuild" % deletion_label
	):
		return false
	var active_id_before := StringName(
		controller.call("get_active_saved_wip_id")
	)
	var selected_id_before := library.selected_wip_id
	if not _check(
		not bool(ui.call("_load_saved_v2_draft", deleted_wip_id))
		and StringName(controller.call("get_active_saved_wip_id"))
		== active_id_before
		and library.selected_wip_id == selected_id_before,
		"%s deleted WIP remained directly loadable or changed active authority"
		% deletion_label
	):
		return false

	ui.call("_rebuild_v2_action_menus")
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := (
		draft_button.get_popup()
		if is_instance_valid(draft_button)
		else null
	)
	var saved_submenu := (
		draft_popup.get_node_or_null("SavedV2DraftSubmenu") as PopupMenu
		if is_instance_valid(draft_popup)
		else null
	)
	if not _check(
		is_instance_valid(draft_popup)
		and is_instance_valid(saved_submenu),
		"%s delete could not rebuild/reopen the Saved V2 Drafts submenu"
		% deletion_label
	):
		return false
	draft_button.show_popup()
	saved_submenu.popup(Rect2i(120, 120, 260, 140))
	await process_frame
	if not _verify_deleted_v2_wip_absent_from_menu(
		ui,
		library,
		deleted_wip_id,
		"%s reopened rebuild" % deletion_label
	):
		return false
	ui.call("_close_v2_top_menu_popup_trees")
	await process_frame

	var reloaded := ResourceLoader.load(
		TEMP_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if not _check(
		reloaded != null
		and reloaded.get_saved_wip(deleted_wip_id) == null,
		"%s deleted WIP reappeared during uncached disk reload"
		% deletion_label
	):
		return false
	result_lines.append(
		(
			"deleted_%s_absence=id:%s menu:true direct_load:false "
			+ "reopen:true disk:true"
		)
		% [deletion_label, String(deleted_wip_id)]
	)
	return true


func _verify_deleted_v2_wip_absent_from_menu(
	ui: CanvasLayer,
	library: PlayerForgeWipLibraryState,
	deleted_wip_id: StringName,
	verification_label: String
) -> bool:
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := (
		draft_button.get_popup()
		if is_instance_valid(draft_button)
		else null
	)
	var saved_submenu := (
		draft_popup.get_node_or_null("SavedV2DraftSubmenu") as PopupMenu
		if is_instance_valid(draft_popup)
		else null
	)
	if not _check(
		is_instance_valid(saved_submenu),
		"%s has no SavedV2DraftSubmenu" % verification_label
	):
		return false
	var expected_live_ids: Dictionary = {}
	for saved_wip: CraftedItemWIP in library.get_saved_wips():
		if saved_wip == null or saved_wip.forge_v2_authoring_state == null:
			continue
		expected_live_ids[saved_wip.wip_id] = true
	var action_lookup := ui.get("menu_action_lookup") as Dictionary
	var submenu_live_ids: Dictionary = {}
	var submenu_has_deleted_id := false
	for item_index in range(saved_submenu.get_item_count()):
		var menu_id := saved_submenu.get_item_id(item_index)
		var menu_entry := action_lookup.get(menu_id, {}) as Dictionary
		if (
			StringName(menu_entry.get("action", StringName()))
			!= &"draft_load_saved"
		):
			continue
		var entry_wip_id := StringName(
			menu_entry.get("value", StringName())
		)
		submenu_live_ids[entry_wip_id] = true
		if entry_wip_id == deleted_wip_id:
			submenu_has_deleted_id = true
	var lookup_live_ids: Dictionary = {}
	for entry_variant: Variant in action_lookup.values():
		var action_entry := entry_variant as Dictionary
		if (
			StringName(action_entry.get("action", StringName()))
			!= &"draft_load_saved"
		):
			continue
		lookup_live_ids[StringName(
			action_entry.get("value", StringName())
		)] = true
	var live_sets_match := (
		submenu_live_ids.size() == expected_live_ids.size()
		and lookup_live_ids.size() == expected_live_ids.size()
	)
	for expected_wip_id: Variant in expected_live_ids.keys():
		live_sets_match = (
			live_sets_match
			and submenu_live_ids.has(expected_wip_id)
			and lookup_live_ids.has(expected_wip_id)
		)
	return _check(
		not expected_live_ids.has(deleted_wip_id)
		and not submenu_has_deleted_id
		and not lookup_live_ids.has(deleted_wip_id)
		and live_sets_match,
		"%s kept the deleted stable ID in the visible Saved V2 Drafts rows/action lookup, or lost a live row"
		% verification_label
	)


func _verify_v2_wip_dialog_front_layer(
	ui: CanvasLayer,
	dialog: PopupPanel,
	expected_focus_owner: Control,
	action_label: String
) -> bool:
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := (
		draft_button.get_popup()
		if is_instance_valid(draft_button)
		else null
	)
	var saved_submenu := (
		draft_popup.get_node_or_null("SavedV2DraftSubmenu") as PopupMenu
		if is_instance_valid(draft_popup)
		else null
	)
	var context_panel := ui.get(
		"saved_v2_drafts_context_panel"
	) as PopupPanel
	var dialog_focus_owner := (
		dialog.gui_get_focus_owner()
		if is_instance_valid(dialog)
		else null
	)
	result_lines.append(
		(
			"%s_layer=draft:%s saved:%s context:%s dialog:%s "
			+ "window_focus:%s child_focus:%s"
		)
		% [
			action_label.to_lower(),
			str(is_instance_valid(draft_popup) and draft_popup.visible),
			str(is_instance_valid(saved_submenu) and saved_submenu.visible),
			str(is_instance_valid(context_panel) and context_panel.visible),
			str(is_instance_valid(dialog) and dialog.visible),
			str(is_instance_valid(dialog) and dialog.has_focus()),
			str(dialog_focus_owner == expected_focus_owner),
		]
	)
	return _check(
		is_instance_valid(draft_popup)
		and not draft_popup.visible
		and is_instance_valid(saved_submenu)
		and not saved_submenu.visible
		and (
			not is_instance_valid(context_panel)
			or not context_panel.visible
		)
		and is_instance_valid(dialog)
		and dialog.visible
		and dialog.has_focus()
		and is_instance_valid(expected_focus_owner)
		and expected_focus_owner.has_focus()
		and dialog_focus_owner == expected_focus_owner,
		"%s needed a second click: its Draft popup tree stayed above it or its intended control did not receive foreground focus"
		% action_label
	)


func _open_rmb_context_for_wip(
	ui: CanvasLayer,
	saved_wip_id: StringName
) -> PopupPanel:
	ui.call("_hide_saved_v2_draft_context_menu")
	ui.call("_rebuild_v2_action_menus")
	var draft_button := ui.get("draft_menu_button") as MenuButton
	var draft_popup := draft_button.get_popup()
	var saved_submenu := draft_popup.get_node_or_null(
		"SavedV2DraftSubmenu"
	) as PopupMenu
	if not is_instance_valid(saved_submenu):
		return null
	var item_index := _find_saved_wip_menu_index(
		ui,
		saved_submenu,
		saved_wip_id
	)
	if item_index < 0 or not saved_submenu.has_method("set_focused_item"):
		return null
	draft_button.show_popup()
	saved_submenu.popup(Rect2i(120, 120, 240, 120))
	await process_frame
	saved_submenu.call("set_focused_item", item_index)
	await process_frame
	if saved_submenu.get_focused_item() != item_index:
		return null
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	# Deliberately do not place the pointer over the row: focused-row authority
	# must select the context target.
	right_click.position = Vector2(-100.0, -100.0)
	right_click.global_position = Vector2(-100.0, -100.0)
	saved_submenu.window_input.emit(right_click)
	await process_frame
	return ui.get("saved_v2_drafts_context_panel") as PopupPanel


func _find_saved_wip_menu_index(
	ui: CanvasLayer,
	submenu: PopupMenu,
	saved_wip_id: StringName
) -> int:
	var action_lookup := ui.get("menu_action_lookup") as Dictionary
	for item_index in range(submenu.get_item_count()):
		var menu_id := submenu.get_item_id(item_index)
		var entry := action_lookup.get(menu_id, {}) as Dictionary
		if (
			StringName(entry.get("action", StringName()))
			== &"draft_load_saved"
			and StringName(entry.get("value", StringName()))
			== saved_wip_id
		):
			return item_index
	return -1


func _verify_wip_identity(
	wip: CraftedItemWIP,
	expected_wip_id: StringName,
	label: String
) -> bool:
	if not _check(wip != null, "%s is null" % label):
		return false
	var authoring_state := wip.forge_v2_authoring_state
	var stage2_state := wip.stage2_item_state
	var baked_profile := wip.latest_baked_profile_snapshot
	var authoring_id := (
		StringName(authoring_state.get("source_wip_id"))
		if authoring_state != null
		else StringName()
	)
	var stage2_id := (
		StringName(stage2_state.get("source_wip_id"))
		if stage2_state != null
		else StringName()
	)
	var baked_id := (
		baked_profile.profile_id
		if baked_profile != null
		else StringName()
	)
	result_lines.append(
		"identity[%s]=expected:%s outer:%s authoring:%s stage2:%s baked:%s"
		% [
			label,
			String(expected_wip_id),
			String(wip.wip_id),
			String(authoring_id),
			String(stage2_id),
			String(baked_id),
		]
	)
	return _check(
		wip.wip_id == expected_wip_id
		and authoring_state != null
		and authoring_id == expected_wip_id
		and stage2_state != null
		and stage2_id == expected_wip_id
		and baked_profile != null
		and baked_id
		== StringName("profile_%s" % String(expected_wip_id)),
		"%s did not align outer, authoring, Stage2, and baked-profile identity"
		% label
	)


func _capture_wip_snapshot(wip: CraftedItemWIP) -> Dictionary:
	if wip == null:
		return {}
	var authoring_state := wip.forge_v2_authoring_state
	var stage2_state := wip.stage2_item_state
	var baked_profile := wip.latest_baked_profile_snapshot
	return {
		"wip_id": wip.wip_id,
		"project_name": wip.forge_project_name,
		"project_notes": wip.forge_project_notes,
		"authoring_source_wip_id": (
			StringName(authoring_state.get("source_wip_id"))
			if authoring_state != null
			else StringName()
		),
		"authoring_project_name": (
			String(authoring_state.get("project_name"))
			if authoring_state != null
			else ""
		),
		"authoring_project_notes": (
			String(authoring_state.get("project_notes"))
			if authoring_state != null
			else ""
		),
		"authoring_draft_id": (
			StringName(authoring_state.get("draft_id"))
			if authoring_state != null
			else StringName()
		),
		"authoring_active_tool_id": (
			StringName(authoring_state.get("active_tool_id"))
			if authoring_state != null
			else StringName()
		),
		"stage2_source_wip_id": (
			StringName(stage2_state.get("source_wip_id"))
			if stage2_state != null
			else StringName()
		),
		"stage2_source_cell_count": (
			int(stage2_state.get("source_stage1_cell_count"))
			if stage2_state != null
			else -1
		),
		"baked_profile_id": (
			baked_profile.profile_id
			if baked_profile != null
			else StringName()
		),
		"baked_total_mass": (
			baked_profile.total_mass if baked_profile != null else -1.0
		),
		"baked_validation_error": (
			baked_profile.validation_error if baked_profile != null else "missing"
		),
	}


func _verify_disk_state(
	expected_ids: Array,
	expected_selected_id: StringName,
	expected_names: Dictionary
) -> bool:
	var reloaded := ResourceLoader.load(
		TEMP_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if not _check(
		reloaded != null
		and reloaded.saved_wips.size() == expected_ids.size()
		and reloaded.selected_wip_id == expected_selected_id,
		"Save As library count/selection did not survive an uncached disk reload"
	):
		return false
	for id_variant: Variant in expected_ids:
		var saved_wip_id := StringName(id_variant)
		var saved_wip := reloaded.get_saved_wip(saved_wip_id)
		if not _verify_wip_identity(
			saved_wip,
			saved_wip_id,
			"disk-reloaded %s" % String(saved_wip_id)
		):
			return false
		if not _check(
			saved_wip.forge_project_name
			== String(expected_names.get(saved_wip_id, "")),
			"disk-reloaded WIP name did not match its stable ID"
		):
			return false
	return true


func _set_runtime_mesh_provider(controller: Node) -> void:
	var state := controller.call("get_active_authoring_state") as Resource
	state.call(
		"set_runtime_contract_mesh_export_provider",
		Callable(self, "_build_runtime_mesh_packet")
	)


func _build_runtime_mesh_packet() -> Dictionary:
	return {
		"ok": true,
		"vertices": PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.12, 0.0, 0.0),
			Vector3(0.0, 0.08, 0.0),
			Vector3(0.0, 0.0, 0.06),
		]),
		"indices": PackedInt32Array([
			0, 2, 1,
			0, 1, 3,
			0, 3, 2,
			1, 2, 3,
		]),
	}


func _find_popup_item_index(popup: PopupMenu, label: String) -> int:
	if not is_instance_valid(popup):
		return -1
	for item_index in range(popup.get_item_count()):
		if popup.get_item_text(item_index) == label:
			return item_index
	return -1


func _find_button_by_text(parent: Node, button_text: String) -> Button:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text == button_text:
			return child as Button
		var nested_button := _find_button_by_text(child, button_text)
		if nested_button != null:
			return nested_button
	return null


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_finish(false, message)
	return false


func _finish(passed: bool, message: String = "") -> void:
	if finished:
		return
	finished = true
	var output_lines := PackedStringArray([
		"ok=true" if passed else "ok=false",
	])
	output_lines.append_array(result_lines)
	if not passed:
		output_lines.append("failure=%s" % message)
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(output_lines) + "\n")
	_cleanup_temp_files()
	if passed:
		print("FORGE_V2_PROJECT_SAVE_AS_RENAME_VERIFY: PASS")
		quit()
		return
	push_error("FORGE_V2_PROJECT_SAVE_AS_RENAME_VERIFY: FAIL: %s" % message)
	quit(1)


func _cleanup_temp_files() -> void:
	for file_path: String in [
		TEMP_LIBRARY_PATH,
		TEMP_PROFILE_LIBRARY_PATH,
		TEMP_KEYBINDING_PATH,
		TEMP_FAILURE_LIBRARY_PATH,
		TEMP_FAILURE_BLOCKER_PATH + "/library.tres",
		TEMP_FAILURE_BLOCKER_PATH,
	]:
		if (
			FileAccess.file_exists(file_path)
			or DirAccess.dir_exists_absolute(file_path)
		):
			DirAccess.remove_absolute(file_path)
