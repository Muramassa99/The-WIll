extends SceneTree

const PlayerScene = preload("res://scenes/player/player_character.tscn")
const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/player_grip_hold_layout_results.txt"
const TEMP_STATE_DIR := "C:/WORKSPACE/test_artifacts"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var player_root: Node = PlayerScene.instantiate()
	root.add_child(player_root)
	await process_frame
	await process_frame

	var player = player_root as PlayerController3D
	var wip_library = PlayerForgeWipLibraryStateScript.new()
	wip_library.save_file_path = "%s/verify_player_grip_hold_layout_state.tres" % TEMP_STATE_DIR
	player.forge_wip_library_state = wip_library

	var centered_pole: CraftedItemWIP = wip_library.save_wip(_build_centered_pole_wip())
	var front_heavy_staff: CraftedItemWIP = wip_library.save_wip(_build_front_heavy_staff_wip())
	if centered_pole == null or front_heavy_staff == null:
		push_error("Both V2 grip-layout fixtures must export and save")
		quit(1)
		return

	var centered_layout: Dictionary = player.preview_saved_wip_grip_hold_layout(centered_pole.wip_id, &"hand_right")
	var front_heavy_layout: Dictionary = player.preview_saved_wip_grip_hold_layout(front_heavy_staff.wip_id, &"hand_right")
	var rig: PlayerHumanoidRig = player.humanoid_rig as PlayerHumanoidRig if player != null else null
	var character_span_meters: float = rig.get_max_model_arm_reach_combat_meters() if rig != null else 0.0

	var lines: PackedStringArray = []
	lines.append("character_two_hand_span_meters=%s" % str(snappedf(character_span_meters, 0.001)))
	lines.append("centered_valid=%s" % str(bool(centered_layout.get("valid", false))))
	lines.append("centered_two_hand_weapon_eligible=%s" % str(bool(centered_layout.get("two_hand_weapon_eligible", false))))
	lines.append("centered_two_hand_character_eligible=%s" % str(bool(centered_layout.get("two_hand_character_eligible", false))))
	lines.append("centered_effective_two_hand_span_meters=%s" % str(snappedf(float(centered_layout.get("effective_two_hand_span_meters", 0.0)), 0.001)))
	lines.append("centered_dominant_signed_ratio=%s" % str(snappedf(float(centered_layout.get("dominant_hand_signed_ratio", 0.0)), 0.001)))
	lines.append("centered_support_signed_ratio=%s" % str(snappedf(float(centered_layout.get("support_hand_signed_ratio", 0.0)), 0.001)))
	lines.append("centered_span_clamped_to_character=%s" % str(
		bool(centered_layout.get("two_hand_character_eligible", false))
		and is_equal_approx(float(centered_layout.get("effective_two_hand_span_meters", 0.0)), character_span_meters)
	))
	lines.append("front_heavy_valid=%s" % str(bool(front_heavy_layout.get("valid", false))))
	lines.append("front_heavy_center_balance_valid=%s" % str(bool(front_heavy_layout.get("center_balance_valid", false))))
	lines.append("front_heavy_two_hand_weapon_eligible=%s" % str(bool(front_heavy_layout.get("two_hand_weapon_eligible", false))))
	lines.append("front_heavy_two_hand_character_eligible=%s" % str(bool(front_heavy_layout.get("two_hand_character_eligible", false))))
	lines.append("front_heavy_dominant_contact_percent=%s" % str(snappedf(float(front_heavy_layout.get("dominant_hand_contact_percent", 0.0)), 0.001)))
	lines.append("front_heavy_support_contact_percent=%s" % str(snappedf(float(front_heavy_layout.get("support_hand_contact_percent", 0.0)), 0.001)))
	lines.append("front_heavy_support_extends_farther_than_dominant=%s" % str(
		float(front_heavy_layout.get("support_hand_contact_percent", 0.0)) < float(front_heavy_layout.get("dominant_hand_contact_percent", 0.0))
	))

	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()

	var valid := bool(centered_layout.get("valid", false)) \
		and bool(front_heavy_layout.get("valid", false)) \
		and bool(centered_layout.get("two_hand_weapon_eligible", false)) \
		and bool(centered_layout.get("two_hand_character_eligible", false)) \
		and is_equal_approx(float(centered_layout.get("effective_two_hand_span_meters", 0.0)), character_span_meters) \
		and bool(front_heavy_layout.get("two_hand_weapon_eligible", false)) \
		and not bool(front_heavy_layout.get("center_balance_valid", true)) \
		and float(front_heavy_layout.get("support_hand_contact_percent", 0.0)) < float(front_heavy_layout.get("dominant_hand_contact_percent", 0.0))
	quit(0 if valid else 1)

func _build_centered_pole_wip() -> CraftedItemWIP:
	var fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
	var wip: CraftedItemWIP = fixture.build(&"mat_wood_gray", fixture.material_lookup(), 2.0)
	if wip != null:
		wip.wip_id = &"verify_player_centered_pole_layout"
		wip.forge_project_name = "Verify V2 Centered Pole Layout"
	return wip

func _build_front_heavy_staff_wip() -> CraftedItemWIP:
	var fixture = preload("res://tools/forge_v2_small_handle_fixture.gd")
	var lookup: Dictionary = fixture.material_lookup()
	var wip: CraftedItemWIP = fixture.build(&"mat_wood_gray", lookup, 0.75)
	if wip == null:
		return null
	wip.wip_id = &"verify_player_front_heavy_layout"
	wip.forge_project_name = "Verify V2 Front Heavy Layout"
	# A real V2 iron deposit moves the computed COM; no cached profile override.
	var state: Resource = wip.forge_v2_authoring_state
	state.set("bounded_history_suspended_reason", &"mixed_material_fallback")
	state.call("set_active_tool_id", preload("res://runtime/forge_v2/forge_v2_authoring_state.gd").TOOL_VOLUME_STROKE)
	state.call("set_active_material_variant_id", &"mat_iron_gray")
	var head := state.call("append_point_material_body", Vector3(0.70, 0.0, 0.0),
		0.075, 1.0, Vector3.UP, Vector3.ZERO) as Resource
	if head == null:
		return null
	var body_id := StringName(head.get("body_id"))
	if not bool(state.call("append_point_to_material_body", body_id, Vector3(1.0, 0.0, 0.0),
		0.0, true, Vector3.UP, Vector3.ZERO)):
		return null
	if state.call("commit_material_body_as_layer", body_id) == null:
		return null
	# Closed connected stepped prism, with the separately protected Handle mesh.
	var vertices := PackedVector3Array()
	for ring: Vector2 in [Vector2(0.0, 0.025), Vector2(0.70, 0.025), Vector2(0.70, 0.075), Vector2(1.0, 0.075)]:
		vertices.append_array(PackedVector3Array([
			Vector3(ring.x, -ring.y, -ring.y), Vector3(ring.x, ring.y, -ring.y),
			Vector3(ring.x, ring.y, ring.y), Vector3(ring.x, -ring.y, ring.y),
		]))
	var indices := PackedInt32Array([0, 2, 1, 0, 3, 2, 12, 13, 14, 12, 14, 15])
	for ring_index: int in range(3):
		for corner: int in range(4):
			var a := ring_index * 4 + corner
			var b := ring_index * 4 + (corner + 1) % 4
			indices.append_array(PackedInt32Array([a, b, b + 4, a, b + 4, a + 4]))
	var prepared := wip.stage2_item_state
	var protected_mesh := prepared.get("primary_grip_handle_mesh_state") as Resource
	var protected_arrays: Array = protected_mesh.get("surface_arrays") as Array
	var protected_vertices := PackedVector3Array()
	for vertex: Vector3 in protected_arrays[Mesh.ARRAY_VERTEX]:
		protected_vertices.append(vertex * 0.0125)
	var packet := {
		"ok": true, "vertices": vertices, "indices": indices, "watertight": true,
		"primary_grip_handle_vertices": protected_vertices,
		"primary_grip_handle_indices": protected_arrays[Mesh.ARRAY_INDEX],
		"primary_grip_handle_mesh_source": prepared.get("primary_grip_handle_mesh_source"),
		"primary_grip_handle_body_signature": prepared.get("primary_grip_handle_body_signature"),
		"primary_grip_handle_vertices_origin_id": prepared.get("primary_grip_handle_mesh_origin_id"),
	}
	var contract: Dictionary = preload("res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd").build_runtime_contract(wip, packet, 0.0125, lookup)
	if not bool(contract.get("valid", false)):
		push_error("V2 weighted layout fixture failed: %s" % String(contract.get("error", "unknown")))
		return null
	wip.stage2_item_state = contract.get("stage2_item_state") as Resource
	wip.latest_baked_profile_snapshot = contract.get("baked_profile") as BakedProfile
	return wip
