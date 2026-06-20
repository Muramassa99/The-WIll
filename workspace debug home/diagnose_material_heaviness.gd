extends SceneTree

const ForgeGridControllerScript = preload("res://runtime/forge/forge_grid_controller.gd")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

const NAMED_PROJECT_NAME := "Long Glave  Animation  Test"
const RESULT_FILE_PATH := "C:/WORKSPACE/workspace debug home/material_heaviness_results.txt"

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var controller: ForgeGridController = ForgeGridControllerScript.new()
	var material_lookup: Dictionary = controller.build_default_material_lookup()
	var material_resolver := MaterialRuntimeResolverScript.new()
	lines.append("diagnostic=material_heaviness")
	if library_state == null:
		lines.append("library_loaded=false")
		_write_and_quit()
		return
	lines.append("library_loaded=true")

	var named_wip: CraftedItemWIP = _find_saved_wip_by_project_name(library_state, NAMED_PROJECT_NAME)
	var selected_wip: CraftedItemWIP = library_state.get_saved_wip(library_state.selected_wip_id)
	_append_wip_materials("named_glave", named_wip, controller, material_lookup, material_resolver)
	_append_wip_materials("selected", selected_wip, controller, material_lookup, material_resolver)
	controller.free()
	_write_and_quit()

func _append_wip_materials(
	label: String,
	wip: CraftedItemWIP,
	controller: ForgeGridController,
	material_lookup: Dictionary,
	material_resolver: MaterialRuntimeResolver
) -> void:
	lines.append("")
	lines.append("[%s]" % label)
	lines.append("%s_found=%s" % [label, str(wip != null)])
	if wip == null:
		return
	lines.append("%s_wip_id=%s" % [label, String(wip.wip_id)])
	lines.append("%s_project_name=%s" % [label, wip.forge_project_name])
	var profile: BakedProfile = controller.get_forge_service().bake_wip(wip, material_lookup)
	lines.append("%s_profile_baked=%s" % [label, str(profile != null)])
	if profile == null:
		return
	lines.append("%s_total_mass=%s" % [label, _fmt_float(profile.total_mass)])
	lines.append("%s_validation_error=%s" % [label, profile.validation_error])
	lines.append("%s_material_variant_mix=%s" % [label, _format_mix(profile.material_variant_mix)])
	for material_id_variant: Variant in profile.material_variant_mix.keys():
		var material_id: StringName = StringName(material_id_variant)
		var count: int = int(profile.material_variant_mix.get(material_id, 0))
		var material_variant: MaterialVariantDef = material_resolver.resolve_material_variant_for_material_id(material_id, material_lookup)
		var density: float = material_variant.resolved_density_per_cell if material_variant != null else 0.0
		var base_material: BaseMaterialDef = material_resolver.resolve_base_material_for_material_id(material_id, material_lookup)
		var display_name: String = base_material.display_name if base_material != null else String(material_id)
		lines.append("%s_material_%s_display_name=%s" % [label, String(material_id), display_name])
		lines.append("%s_material_%s_count=%d" % [label, String(material_id), count])
		lines.append("%s_material_%s_density_per_cell=%s" % [label, String(material_id), _fmt_float(density)])
		lines.append("%s_material_%s_mass_contribution=%s" % [label, String(material_id), _fmt_float(float(count) * density)])

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _format_mix(mix: Dictionary) -> String:
	var pieces: PackedStringArray = []
	for material_id: Variant in mix.keys():
		pieces.append("%s:%d" % [String(material_id), int(mix.get(material_id, 0))])
	return ", ".join(pieces)

func _fmt_float(value: float) -> String:
	return "%.6f" % value

func _write_and_quit() -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()
