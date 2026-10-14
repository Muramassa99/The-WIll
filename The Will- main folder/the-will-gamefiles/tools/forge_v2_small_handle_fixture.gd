extends RefCounted

# Shared test fixture: a committed V2 Handle and a tiny exact-mesh export packet.
const Authoring = preload("res://runtime/forge_v2/forge_v2_authoring_state.gd")
const Profiles = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const Adapter = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd")
const Packet = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Catalog = preload("res://core/defs/forge/forge_material_catalog_default.tres")
const GrayTier = preload("res://core/defs/materials/tiers/tier_gray.tres")


static func material_lookup() -> Dictionary:
	var service := ForgeService.new()
	var lookup: Dictionary = {}
	for entry: Resource in Catalog.entries:
		var base := entry.get("material_def") as BaseMaterialDef
		if base == null:
			continue
		lookup[base.base_material_id] = base
		var variant := service.build_material_variant(base, GrayTier)
		lookup[variant.variant_id] = variant
	return lookup


static func build(
	material_id: StringName = &"mat_iron_gray",
	lookup: Dictionary = {},
	length_meters: float = 0.2
) -> CraftedItemWIP:
	var state: Resource = Authoring.new()
	state.call("reset_new_draft", "Small V2 verification Handle")
	state.call("set_active_tool_id", Authoring.TOOL_HANDLES)
	state.call("set_active_profile_id", Profiles.PROFILE_HANDLE_BUILDER)
	state.call("set_active_handle_path_mode_id", Authoring.HANDLE_PATH_MODE_TWO_POINT_LINEAR)
	state.call("append_spline_line_point", Vector3.ZERO, Vector3.UP)
	state.call("append_spline_line_point", Vector3(length_meters, 0.0, 0.0), Vector3.UP)
	if not bool(state.call("generate_profile_extrusion_from_spline")):
		return null
	var body := state.call("get_selected_material_body") as Resource
	body.set("material_variant_id", material_id)
	if state.call("commit_material_body_as_layer", body.get("body_id")) == null:
		return null
	var wip := CraftedItemWIP.new()
	wip.wip_id = &"small_v2_fixture"
	wip.forge_project_name = "Small V2 verification Handle"
	wip.forge_builder_path_id = CraftedItemWIP.BUILDER_PATH_MELEE
	wip.forge_builder_component_id = CraftedItemWIP.BUILDER_COMPONENT_PRIMARY
	wip.forge_intent = &"intent_melee"
	wip.equipment_context = &"ctx_weapon"
	wip.forge_v2_authoring_state = state
	var vertices := PackedVector3Array([
		Vector3(0.0,-0.025,-0.025), Vector3(length_meters,-0.025,-0.025),
		Vector3(length_meters,0.025,-0.025), Vector3(0.0,0.025,-0.025),
		Vector3(0.0,-0.025,0.025), Vector3(length_meters,-0.025,0.025),
		Vector3(length_meters,0.025,0.025), Vector3(0.0,0.025,0.025),
	])
	var indices := PackedInt32Array([
		0,2,1,0,3,2,4,5,6,4,6,7,0,4,7,0,7,3,
		1,2,6,1,6,5,0,1,5,0,5,4,3,7,6,3,6,2,
	])
	var packet := {
		"ok": true, "vertices": vertices, "indices": indices,
		"primary_grip_handle_vertices": vertices, "primary_grip_handle_indices": indices,
		"primary_grip_handle_vertices_origin_id": Packet.VERTICES_ORIGIN_ID,
		"primary_grip_handle_mesh_source": Packet.SOURCE,
		"primary_grip_handle_body_signature": Packet.build_body_signature(body),
		"watertight": true, "material_variant_id": material_id,
	}
	var result: Dictionary = Adapter.build_runtime_contract(wip, packet, 0.0125, lookup)
	if not bool(result.get("valid", false)):
		push_error("Small V2 fixture: %s" % String(result.get("error", "unknown")))
		return null
	wip.latest_baked_profile_snapshot = result.get("baked_profile") as BakedProfile
	wip.stage2_item_state = result.get("stage2_item_state") as Resource
	return wip
