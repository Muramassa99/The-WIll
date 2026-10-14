extends SceneTree

const MainScene = preload("res://node_3d.tscn")
const Settings = preload("res://runtime/system/user_settings_runtime.gd")
const Fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
const MeshBuilder = preload("res://runtime/forge/test_print_mesh_builder.gd")
const RESULT_PATH := "C:/WORKSPACE/godot_runs/verify_forge_v1_retirement_2026-10-14.json"
var _failures := PackedStringArray()
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Instantiate the real scene without entering its tree: validates resource
	# dependencies and live station topology without loading player save data.
	var world := MainScene.instantiate()
	_expect(world.get_node_or_null("CraftingBench") == null, "retired V1 bench absent")
	_expect(world.get_node_or_null("CraftingBenchV2/Stage1V2Controller") != null,
		"V2 authoring controller remains in main scene")
	_expect(world.get_node_or_null("CraftingBenchV2/CraftingBenchUIV2") != null,
		"V2 UI remains in main scene")
	_expect(world.get_node_or_null("CombatAnimationStation") != null,
		"Skill Crafter remains in main scene")
	_expect(world.get_node_or_null("DisassemblyBench") != null,
		"Disassembly remains in main scene")
	world.free()
	_expect(Settings.get_actions_for_category("forge").is_empty(), "retired V1 input definitions absent")
	_expect(not Settings.get_actions_for_category("skill_crafter").is_empty(),
		"Skill Crafter input definitions preserved")
	var service := ForgeService.new()
	var old := CraftedItemWIP.new()
	old.wip_id = &"verify_retired_v1"
	_expect(not _has_property(old, &"layers"), "WIP has no retired cell layer field")
	_expect(not _has_property(old, &"builder_marker_positions"), "WIP has no retired grid marker field")
	old.latest_baked_profile_snapshot = BakedProfile.new()
	old.latest_baked_profile_snapshot.primary_grip_valid = true
	var rejected := service.bake_wip(old)
	_expect(not rejected.primary_grip_valid and rejected.validation_error == "forge_v1_authoring_removed",
		"WIP without V2 authoring explicitly rejected")
	var rejected_cache := service.get_cached_profile_for_runtime(old)
	_expect(not rejected_cache.primary_grip_valid
		and rejected_cache.validation_error == "forge_v1_authoring_removed",
		"old cached success cannot bypass V1 retirement")
	_expect(old.latest_baked_profile_snapshot.primary_grip_valid,
		"rejection preserves old saved resource")
	var current := Fixture.build()
	if _expect(current != null, "200 mm V2 Handle fixture exports"):
		var valid := service.bake_wip(current)
		_expect(valid.primary_grip_valid and valid.primary_grip_two_hand_eligible,
			"V2 metric Handle remains usable after pruning")
		var test_print := service.build_test_print_from_wip(current, Fixture.material_lookup())
		var builder := MeshBuilder.new()
		_expect(not _has_property(test_print, &"display_cells")
			and not _has_property(test_print, &"canonical_solid"),
			"TestPrint has no retired cell or solid fields")
		_expect(builder.build_mesh_from_test_print(test_print).get_surface_count() > 0,
			"prepared V2 editable mesh still renders")
		_expect(test_print.canonical_geometry != null and not test_print.canonical_geometry.is_empty(),
			"V2 canonical geometry remains available for bounds")
		test_print.stage2_item_state = null
		_expect(builder.build_mesh_from_test_print(test_print).get_surface_count() == 0,
			"missing prepared mesh cannot fall back to canonical geometry")
		_expect(builder.build_mesh_from_test_print(null).get_surface_count() == 0,
			"missing TestPrint returns an empty mesh")
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var output := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}, "\t"))
	for failure: String in _failures:
		push_error(failure)
	print("Forge V1 retirement: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition


func _has_property(value: Object, property_name: StringName) -> bool:
	if value == null:
		return false
	for entry: Dictionary in value.get_property_list():
		if StringName(entry.get("name", "")) == property_name:
			return true
	return false
