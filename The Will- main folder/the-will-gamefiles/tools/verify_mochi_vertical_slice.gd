extends SceneTree

# Material -> V2 WIP -> profile -> mesh -> saved library. No cell authoring.
const Fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
const MeshBuilder = preload("res://runtime/forge/test_print_mesh_builder.gd")
const Library = preload("res://core/models/player_forge_wip_library_state.gd")
const Wood = preload("res://core/defs/materials/base/wood.tres")
const Iron = preload("res://core/defs/materials/base/iron.tres")
const Gray = preload("res://core/defs/materials/tiers/tier_gray.tres")
const WoodProcess = preload("res://core/defs/materials/process_rules/wood_gray_process_rule.tres")
const IronProcess = preload("res://core/defs/materials/process_rules/iron_gray_process_rule.tres")
const SAVE_PATH := "user://verification/test_mochi_wip_library_state.tres"
var _failures := PackedStringArray()
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := ForgeService.new()
	var lookup := Fixture.material_lookup()
	for base: BaseMaterialDef in [Wood, Iron]:
		var variant := service.build_material_variant(base, Gray)
		var rule: ProcessRuleDef = WoodProcess if base == Wood else IronProcess
		var stack := service.build_material_stack(rule, variant)
		_expect(stack != null and stack.quantity == rule.output_count_per_input,
			"material processing retains output quantity")
		_expect(rule.output_material_variant_id == variant.variant_id,
			"processed material variant matches its recipe")
	var wood := Fixture.build(&"mat_wood_gray", lookup)
	var iron := Fixture.build(&"mat_iron_gray", lookup)
	if not _expect(wood != null and iron != null, "V2 material fixtures export"):
		_finish()
		return
	var wood_profile := service.bake_wip(wood, lookup)
	var iron_profile := service.bake_wip(iron, lookup)
	_expect(wood_profile.primary_grip_valid and iron_profile.primary_grip_valid,
		"current V2 profiles are valid")
	_expect(wood_profile.total_mass > 0.0 and iron_profile.total_mass > wood_profile.total_mass,
		"equal-volume material mass follows density")
	# Usable V2 Handle volumes can saturate final 0..1 capability scores.
	# Compare the material totals before that intentional final clamp.
	_expect(_bias(wood_profile, &"cap_flex") > _bias(iron_profile, &"cap_flex"),
		"wood flexibility material bias exceeds iron")
	_expect(_bias(iron_profile, &"cap_edge") > _bias(wood_profile, &"cap_edge"),
		"iron edge material bias exceeds wood")
	var test_print := service.build_test_print_from_wip(iron, lookup)
	var mesh: ArrayMesh = MeshBuilder.new().build_mesh_from_test_print(test_print, lookup)
	_expect(mesh != null and mesh.get_surface_count() > 0, "V2 TestPrint builds renderable mesh")
	if mesh != null:
		# Shared mesh coordinates are scaled to metres by the equipped presenter.
		var mesh_scale := float(test_print.stage2_item_state.get("cell_world_size_meters"))
		_expect(absf(mesh.get_aabb().size.x * mesh_scale - 0.2) < 0.0001,
			"V2 TestPrint retains metric Handle length")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_PATH.get_base_dir()))
	var library: PlayerForgeWipLibraryState = Library.load_or_create(SAVE_PATH)
	library.saved_wips.clear()
	library.selected_wip_id = StringName()
	iron.forge_project_name = "Mochi V2 Save Test"
	var saved: CraftedItemWIP = library.save_wip(iron)
	var reloaded_library := ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerForgeWipLibraryState
	var reloaded: CraftedItemWIP = null
	if reloaded_library != null:
		reloaded = reloaded_library.get_saved_wip_clone(reloaded_library.selected_wip_id)
	_expect(saved != null and reloaded != null, "V2 WIP library saves and reloads")
	if reloaded != null:
		_expect(CraftedItemWIP.is_forge_v2_authoring_wip(reloaded),
			"reloaded authoring belongs to V2 only")
		var rebaked := service.bake_wip(reloaded, lookup)
		_expect(rebaked.primary_grip_valid and absf(rebaked.total_mass - iron_profile.total_mass) < 0.0001,
			"reloaded V2 data reproduces valid grip and material mass")
	_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH)) == OK,
		"temporary library removed")
	_finish()


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition


func _bias(profile: BakedProfile, capability: StringName) -> float:
	var value := 0.0
	for line: StatLine in profile.resolved_capability_bias_lines:
		if line != null and line.stat_id == capability and line.is_numeric():
			value += line.value
	return value


func _finish() -> void:
	var output := FileAccess.open("C:/WORKSPACE/mochi_verify_results.txt", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}, "\t"))
	for failure: String in _failures:
		push_error(failure)
	print("Mochi V2 vertical slice: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
