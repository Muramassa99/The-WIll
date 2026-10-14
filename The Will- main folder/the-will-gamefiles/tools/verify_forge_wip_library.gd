extends SceneTree

const Library = preload("res://core/models/player_forge_wip_library_state.gd")
const Fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const TEST_DIR := "user://verification/forge_v2_library_retirement"
const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_wip_library_2026-10-14.json"
var _failures := PackedStringArray()
var _checks := 0


class RejectingLibrary:
	extends PlayerForgeWipLibraryState

	func persist() -> bool:
		return false


func _init() -> void:
	_run()
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}, "\t"))
	for failure: String in _failures:
		push_error(failure)
	print("V2 WIP library: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var library := Library.new()
	library.save_file_path = TEST_DIR.path_join("valid_roundtrip.tres")
	var source := Fixture.build(&"mat_iron_gray", Fixture.material_lookup())
	if not _expect(source != null, "V2 fixture exports"):
		return
	source.wip_id = &"verify_v2_saved"
	source.forge_project_name = "Forge V2 Alpha"
	source.forge_project_notes = "initial notes"
	source.creator_id = &"test_runner"
	var saved: CraftedItemWIP = library.save_wip(source)
	if not _expect(saved != null, "V2 save succeeds"):
		return
	source.forge_project_notes = "unsaved source edit"
	saved.forge_project_notes = "unsaved returned-copy edit"
	var read_copy: CraftedItemWIP = library.get_saved_wip_clone(saved.wip_id)
	_expect(read_copy != null and read_copy.forge_project_notes == "initial notes",
		"source and returned copies do not mutate library metadata")
	if read_copy != null:
		read_copy.latest_baked_profile_snapshot.validation_error = "copy-only"
	_expect(library.get_saved_wip(saved.wip_id).latest_baked_profile_snapshot.validation_error != "copy-only",
		"reader clone keeps cached profile changes private")
	var duplicate: CraftedItemWIP = library.duplicate_saved_wip(saved.wip_id)
	_expect(duplicate != null and duplicate.wip_id != saved.wip_id, "duplicate gets its own ID")
	_expect(duplicate != null and library.delete_saved_wip(duplicate.wip_id), "duplicate can be deleted")
	var unfinished := _unfinished_v2(&"verify_v2_unfinished")
	_expect(library.save_wip(unfinished) != null, "unfinished V2 draft saves without successful grip or mesh")
	var unsupported := CraftedItemWIP.new()
	unsupported.wip_id = &"verify_retired"
	var before_count := library.saved_wips.size()
	var before_selection := library.selected_wip_id
	_expect(library.save_wip(unsupported) == null, "unsupported old authoring cannot be saved")
	_expect(library.saved_wips.size() == before_count and library.selected_wip_id == before_selection,
		"rejected save preserves entries and selection")
	var unarmed := CraftedItemWIP.new()
	unarmed.wip_id = CraftedItemWIP.UNARMED_AUTHORING_WIP_ID
	_expect(library.save_wip(unarmed) != null, "unarmed authoring saves separately")
	var reloaded: PlayerForgeWipLibraryState = Library.load_or_create(library.save_file_path)
	if not _expect(reloaded != null, "library reload succeeds"):
		return
	var restored: CraftedItemWIP = reloaded.get_saved_wip(saved.wip_id)
	_expect(restored != null and restored.forge_project_name == "Forge V2 Alpha"
		and restored.forge_project_notes == "initial notes" and restored.creator_id == &"test_runner",
		"V2 project metadata survives serialization")
	_expect(restored != null and CraftedItemWIP.is_forge_v2_authoring_wip(restored)
		and restored.stage2_item_state != null and restored.latest_baked_profile_snapshot.primary_grip_valid,
		"V2 authoring, prepared mesh, and cached profile survive serialization")
	_expect(reloaded.get_saved_wip(unfinished.wip_id) != null, "unfinished V2 draft survives reload")
	_expect(reloaded.get_unarmed_authoring_wip() != null and reloaded.saved_wips.size() == 2,
		"unarmed remains available outside ordinary weapon entries")
	_verify_mixed_old_library(false)
	_verify_mixed_old_library(true)
	_verify_failed_save_rollback()


func _verify_failed_save_rollback() -> void:
	var library := RejectingLibrary.new()
	var retired := CraftedItemWIP.new()
	retired.wip_id = &"rollback_retired"
	var existing := _unfinished_v2(&"rollback_existing")
	existing.forge_project_notes = "original"
	var neighbour := _unfinished_v2(&"rollback_neighbour")
	library.saved_wips.assign([retired, existing, neighbour])
	library.selected_wip_id = neighbour.wip_id
	var replacement := existing.duplicate(true) as CraftedItemWIP
	replacement.forge_project_notes = "must not be persisted"
	_expect(library.save_wip(replacement) == null, "failed replacement reports failure")
	_expect(library.saved_wips.size() == 2 and library.saved_wips[0] == existing
		and library.saved_wips[1] == neighbour and existing.forge_project_notes == "original",
		"replacement rollback uses indexes after retired rows are filtered")
	_expect(library.selected_wip_id == neighbour.wip_id, "replacement rollback preserves selection")
	library.saved_wips.insert(0, retired)
	var added := _unfinished_v2(&"rollback_added")
	_expect(library.save_wip(added) == null, "failed append reports failure")
	_expect(library.saved_wips.size() == 2 and library.saved_wips[0] == existing
		and library.saved_wips[1] == neighbour and library.get_saved_wip(added.wip_id) == null,
		"append rollback preserves surviving V2 entries")
	_expect(library.selected_wip_id == neighbour.wip_id, "append rollback preserves selection")


func _verify_mixed_old_library(select_retired: bool) -> void:
	# Bypass the new save gate to model a previously serialized mixed library.
	# All files are isolated verification data; never use the player's library.
	var file_path := TEST_DIR.path_join("mixed_selected_%s.tres" % str(select_retired))
	var raw := Library.new()
	raw.save_file_path = file_path
	var valid := _unfinished_v2(&"mixed_v2_draft")
	var retired := CraftedItemWIP.new()
	retired.wip_id = &"mixed_retired"
	retired.latest_baked_profile_snapshot = BakedProfile.new()
	retired.latest_baked_profile_snapshot.primary_grip_valid = true
	var legacy_unarmed := CraftedItemWIP.new()
	legacy_unarmed.wip_id = CraftedItemWIP.UNARMED_AUTHORING_WIP_ID
	raw.saved_wips.assign([retired, valid, legacy_unarmed])
	raw.selected_wip_id = retired.wip_id if select_retired else valid.wip_id
	if not _expect(ResourceSaver.save(raw, file_path) == OK, "isolated mixed library fixture saves"):
		return
	var serialized := FileAccess.get_file_as_string(file_path)
	var marker := "wip_id = &\"mixed_retired\""
	if not _expect(serialized.contains(marker), "serialized retired resource located"):
		return
	serialized = serialized.replace(marker,
		marker + "\nlayers = []\nbuilder_marker_positions = {\"old_marker\": Vector3i(1, 2, 3)}")
	var writer := FileAccess.open(file_path, FileAccess.WRITE)
	if not _expect(writer != null, "old serialized field fixture opens"):
		return
	writer.store_string(serialized)
	writer.close()
	var loaded: PlayerForgeWipLibraryState = Library.load_or_create(file_path)
	if not _expect(loaded != null, "mixed library with retired properties still deserializes"):
		return
	_expect(loaded.get_saved_wip(retired.wip_id) == null, "retired record filtered from loaded library")
	_expect(loaded.get_saved_wip(valid.wip_id) != null, "valid unfinished V2 record retained")
	_expect(loaded.get_unarmed_authoring_wip() != null, "legacy unarmed fallback retained")
	_expect(loaded.selected_wip_id == (StringName() if select_retired else valid.wip_id),
		"selection clears only when its record was retired")
	_expect(FileAccess.get_file_as_string(file_path) == serialized, "loading does not rewrite old saved data")
	loaded.saved_wips.append(retired)
	_expect(loaded.persist(), "ordinary persist succeeds")
	_expect(loaded.get_saved_wip(retired.wip_id) == null, "persist also filters injected retired records")
	var persisted := FileAccess.get_file_as_string(file_path)
	_expect(not persisted.contains(marker) and not persisted.contains("builder_marker_positions"),
		"explicit persistence drops retired records and old fields")


func _unfinished_v2(id: StringName) -> CraftedItemWIP:
	var wip := CraftedItemWIP.new()
	wip.wip_id = id
	wip.forge_v2_authoring_state = Authoring.new()
	wip.forge_v2_authoring_state.call("reset_new_draft", "Unfinished verification draft")
	return wip


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition
