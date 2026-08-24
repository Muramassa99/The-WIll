extends SceneTree

const ForgeV2WipCompatibilityAdapterScript = preload(
	"res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd"
)
const PlayerForgeWipLibraryStateScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)

const SOURCE_LIBRARY_PATH := (
	"C:/Users/ixro1/AppData/Roaming/Godot/app_userdata/"
	+ "The Will-Gamefiles/forge/player_wip_library_state.tres"
)
const SELECTED_WIP_ID := &"player_wip_1787440141.759_11"
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "diagnose_selected_forge_v2_grip_2026-08-24.txt"
)
const FINGER_IDS: Array[String] = [
	"thumb",
	"index",
	"middle",
	"ring",
	"pinky",
]


class FakePlayer:
	extends Node

	var ui_mode_enabled := false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled


var lines := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	lines.append("scope=selected_real_v2_wip_grip_diagnostic")
	lines.append("source_library=%s" % SOURCE_LIBRARY_PATH)
	lines.append("requested_wip_id=%s" % String(SELECTED_WIP_ID))
	var source_library: PlayerForgeWipLibraryState = ResourceLoader.load(
		SOURCE_LIBRARY_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	) as PlayerForgeWipLibraryState
	if source_library == null:
		_finish("source library could not be loaded")
		return
	lines.append("library_selected_wip_id=%s" % String(source_library.selected_wip_id))
	lines.append("library_wip_count=%d" % source_library.saved_wips.size())
	var source_wip: CraftedItemWIP = source_library.get_saved_wip(SELECTED_WIP_ID)
	if source_wip == null:
		_finish("requested WIP is absent")
		return
	lines.append("project_name=%s" % source_wip.forge_project_name)
	lines.append("forge_intent=%s" % String(source_wip.forge_intent))
	lines.append("equipment_context=%s" % String(source_wip.equipment_context))
	var cached_profile: BakedProfile = source_wip.latest_baked_profile_snapshot
	_append_profile("cached", cached_profile, 0.0125)

	var raw_handle := _resolve_raw_handle(source_wip)
	if not bool(raw_handle.get("valid", false)):
		_finish("raw Handle unavailable: %s" % String(raw_handle.get("error", "unknown")))
		return
	var raw_path: PackedVector3Array = raw_handle.get("path", PackedVector3Array())
	var raw_axis := (raw_path[2] - raw_path[0]).normalized()
	lines.append("raw_handle_body_id=%s" % String(raw_handle.get("body_id", StringName())))
	lines.append("raw_handle_path_start_m=%s" % str(raw_path[0]))
	lines.append("raw_handle_path_mid_m=%s" % str(raw_path[1]))
	lines.append("raw_handle_path_end_m=%s" % str(raw_path[2]))
	lines.append("raw_handle_endpoint_span_m=%.9f" % raw_path[0].distance_to(raw_path[2]))
	lines.append("old_midpoint_expected_contact_m=%s" % str(raw_path[1]))
	lines.append("old_endpoint_expected_major_axis=%s" % str(raw_axis))

	var mesh_packet := _build_mesh_packet_from_saved_stage2(source_wip)
	if not bool(mesh_packet.get("valid", false)):
		_finish("saved Stage2 mesh unavailable: %s" % String(mesh_packet.get("error", "unknown")))
		return
	var cell_size := float(mesh_packet.get("cell_size_meters", 0.0125))
	lines.append("saved_mesh_cell_size_m=%.9f" % cell_size)
	lines.append("saved_mesh_vertex_count=%d" % (
		mesh_packet.get("vertices", PackedVector3Array()) as PackedVector3Array
	).size())
	lines.append("saved_mesh_triangle_count=%d" % int((
		mesh_packet.get("indices", PackedInt32Array()) as PackedInt32Array
	).size() / 3))

	var current_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	var contract: Dictionary = ForgeV2WipCompatibilityAdapterScript.build_runtime_contract(
		current_wip,
		{
			"vertices": mesh_packet.get("vertices", PackedVector3Array()),
			"indices": mesh_packet.get("indices", PackedInt32Array()),
		},
		cell_size
	)
	lines.append("current_contract_valid=%s" % str(bool(contract.get("valid", false))))
	lines.append("current_contract_error=%s" % String(contract.get("error", "")))
	var current_profile: BakedProfile = contract.get("baked_profile") as BakedProfile
	_append_profile("current", current_profile, cell_size)
	if not bool(contract.get("valid", false)) or current_profile == null:
		_finish("current adapter rejected selected WIP")
		return
	current_wip.stage2_item_state = contract.get("stage2_item_state") as Resource
	current_wip.latest_baked_profile_snapshot = current_profile
	if cached_profile != null:
		lines.append("cached_to_current_contact_delta_m=%.9f" % (
			cached_profile.primary_grip_contact_position * cell_size
		).distance_to(current_profile.primary_grip_contact_position * cell_size))
	lines.append("raw_midpoint_to_current_contact_delta_m=%.9f" % raw_path[1].distance_to(
		current_profile.primary_grip_contact_position * cell_size
	))

	var runtime_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	runtime_library.saved_wips = [current_wip]
	runtime_library.selected_wip_id = current_wip.wip_id
	var skill_snapshot := await _capture_skill_crafter(runtime_library, current_wip.wip_id)
	_append_skill_snapshot(skill_snapshot)
	_finish("")


func _resolve_raw_handle(wip: CraftedItemWIP) -> Dictionary:
	if wip == null or wip.forge_v2_authoring_state == null:
		return {"valid": false, "error": "V2 authoring state missing"}
	var state: Resource = wip.forge_v2_authoring_state
	var material_bodies: Array = state.get("material_bodies") as Array
	for body_variant: Variant in material_bodies:
		var body := body_variant as Resource
		if body == null or StringName(body.get("body_kind")) != &"body_kind_handle_profile":
			continue
		var path: PackedVector3Array = body.get("path_points")
		if path.size() != 3:
			continue
		return {
			"valid": true,
			"body_id": StringName(body.get("body_id")),
			"path": path,
		}
	return {"valid": false, "error": "three-point Handle body missing"}


func _build_mesh_packet_from_saved_stage2(wip: CraftedItemWIP) -> Dictionary:
	if wip == null or wip.stage2_item_state == null:
		return {"valid": false, "error": "Stage2 item state missing"}
	var stage2: Resource = wip.stage2_item_state
	var editable: Resource = stage2.get("current_editable_mesh_state") as Resource
	if editable == null:
		return {"valid": false, "error": "current editable mesh missing"}
	var arrays: Array = editable.get("surface_arrays") as Array
	if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return {"valid": false, "error": "vertex surface array missing"}
	if arrays.size() <= Mesh.ARRAY_INDEX or arrays[Mesh.ARRAY_INDEX] is not PackedInt32Array:
		return {"valid": false, "error": "index surface array missing"}
	var cell_size := maxf(float(stage2.get("cell_world_size_meters")), 0.0001)
	var vertices_cells: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertices_meters := PackedVector3Array()
	vertices_meters.resize(vertices_cells.size())
	for vertex_index: int in range(vertices_cells.size()):
		vertices_meters[vertex_index] = vertices_cells[vertex_index] * cell_size
	return {
		"valid": true,
		"vertices": vertices_meters,
		"indices": PackedInt32Array(arrays[Mesh.ARRAY_INDEX]),
		"cell_size_meters": cell_size,
	}


func _append_profile(prefix: String, profile: BakedProfile, cell_size: float) -> void:
	if profile == null:
		lines.append("%s_profile_present=false" % prefix)
		return
	lines.append("%s_profile_present=true" % prefix)
	lines.append("%s_primary_grip_valid=%s" % [prefix, str(profile.primary_grip_valid)])
	lines.append("%s_validation_error=%s" % [prefix, profile.validation_error])
	lines.append("%s_contact_m=%s" % [prefix, str(
		profile.primary_grip_contact_position * cell_size
	)])
	lines.append("%s_span_start_m=%s" % [prefix, str(
		profile.primary_grip_span_start * cell_size
	)])
	lines.append("%s_span_end_m=%s" % [prefix, str(
		profile.primary_grip_span_end * cell_size
	)])
	lines.append("%s_major_axis=%s" % [prefix, str(profile.primary_grip_slide_axis)])
	lines.append("%s_minor_axis_a=%s" % [prefix, str(profile.primary_grip_minor_axis_a)])
	lines.append("%s_minor_axis_b=%s" % [prefix, str(profile.primary_grip_minor_axis_b)])
	lines.append("%s_frame_handedness=%.9f" % [prefix, _frame_handedness(profile)])
	lines.append("%s_tip_m=%s" % [prefix, str(profile.weapon_tip_point * cell_size)])
	lines.append("%s_pommel_m=%s" % [prefix, str(profile.weapon_pommel_point * cell_size)])
	lines.append("%s_tip_distance_m=%.9f" % [prefix, profile.weapon_tip_distance_meters])
	lines.append("%s_pommel_distance_m=%.9f" % [prefix, profile.weapon_pommel_distance_meters])
	lines.append("%s_profile_offset_count=%d" % [
		prefix,
		profile.primary_grip_profile_offsets_minor_meters.size(),
	])
	lines.append("%s_profile_offset_mean_m=%s" % [
		prefix,
		str(_mean_offsets(profile.primary_grip_profile_offsets_minor_meters)),
	])


func _frame_handedness(profile: BakedProfile) -> float:
	var major := profile.primary_grip_slide_axis.normalized()
	var minor_a := profile.primary_grip_minor_axis_a.normalized()
	var minor_b := profile.primary_grip_minor_axis_b.normalized()
	return minor_a.cross(minor_b).dot(major)


func _mean_offsets(offsets: PackedVector2Array) -> Vector2:
	if offsets.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for offset: Vector2 in offsets:
		total += offset
	return total / float(offsets.size())


func _capture_skill_crafter(
	library: PlayerForgeWipLibraryState,
	wip_id: StringName
) -> Dictionary:
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library
	root.add_child(fake_player)
	var ui := CombatAnimationStationUIScene.instantiate()
	root.add_child(ui)
	await _wait_process_frames(3)
	ui.open_for(fake_player, "Selected V2 Grip Diagnostic")
	await _wait_process_frames(5)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(
		wip_id,
		&"hand_right",
		false,
		true
	)
	await _wait_process_frames(8)
	var slot_ok: bool = ui.select_skill_slot(&"skill_slot_1", true)
	await _wait_process_frames(8)
	var authored_pose_ok: bool = ui.set_selected_motion_node_weapon_orientation(
		Vector3(0.0, 0.0, 12.0),
		false,
		true,
		true,
		true,
		true
	)
	await _wait_process_frames(10)
	await _wait_physics_frames(3)
	var snapshot := _read_skill_crafter(ui)
	snapshot["open_ok"] = open_ok
	snapshot["slot_ok"] = slot_ok
	snapshot["authored_pose_ok"] = authored_pose_ok
	ui.free()
	fake_player.free()
	await process_frame
	return snapshot


func _read_skill_crafter(ui: Node) -> Dictionary:
	var snapshot := {"valid": false}
	if ui == null or ui.get("preview_subviewport") == null:
		return snapshot
	var viewport: SubViewport = ui.get("preview_subviewport") as SubViewport
	var preview_root: Node3D = viewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var held_item: Node3D = preview_root.get_meta(
		"preview_held_item",
		null
	) as Node3D if preview_root != null else null
	var grip_center: Node3D = held_item.get_node_or_null(
		"PrimaryGripGuide/GripShellCenter"
	) as Node3D if held_item != null else null
	var grip_area: Area3D = grip_center.get_node_or_null(
		"GripContactArea"
	) as Area3D if grip_center != null else null
	if preview_root == null or held_item == null or grip_center == null or grip_area == null:
		return snapshot
	var debug_state: Dictionary = ui.get_preview_debug_state()
	var dominant_rays: Array = debug_state.get(
		"dominant_finger_contact_ray_debug",
		[]
	) as Array
	var support_rays: Array = debug_state.get(
		"support_finger_contact_ray_debug",
		[]
	) as Array
	var collision_shape_count := 0
	for child: Node in grip_area.get_children():
		if child is CollisionShape3D:
			collision_shape_count += 1
	return {
		"valid": true,
		"held_item_name": held_item.name,
		"grip_center_held_local": held_item.to_local(grip_center.global_position),
		"collision_shape_count": collision_shape_count,
		"collision_layer": grip_area.collision_layer,
		"collision_mask_meta": int(grip_center.get_meta("grip_shell_collision_layer", 0)),
		"dominant_rays": dominant_rays,
		"support_rays": support_rays,
		"dominant_readiness": float(debug_state.get(
			"dominant_finger_contact_readiness",
			-1.0
		)),
		"dominant_contact_distance_m": float(debug_state.get(
			"dominant_finger_contact_distance_meters",
			-1.0
		)),
	}


func _append_skill_snapshot(snapshot: Dictionary) -> void:
	lines.append("skill_crafter_snapshot_valid=%s" % str(bool(snapshot.get("valid", false))))
	lines.append("skill_crafter_open_ok=%s" % str(bool(snapshot.get("open_ok", false))))
	lines.append("skill_crafter_slot_ok=%s" % str(bool(snapshot.get("slot_ok", false))))
	lines.append("skill_crafter_authored_pose_ok=%s" % str(bool(snapshot.get("authored_pose_ok", false))))
	if not bool(snapshot.get("valid", false)):
		return
	lines.append("skill_crafter_held_item_name=%s" % String(snapshot.get("held_item_name", "")))
	lines.append("skill_crafter_grip_center_held_local=%s" % str(
		snapshot.get("grip_center_held_local", Vector3.INF)
	))
	lines.append("skill_crafter_grip_collision_shape_count=%d" % int(
		snapshot.get("collision_shape_count", 0)
	))
	lines.append("skill_crafter_grip_collision_layer=%d" % int(
		snapshot.get("collision_layer", 0)
	))
	lines.append("skill_crafter_grip_collision_mask_meta=%d" % int(
		snapshot.get("collision_mask_meta", 0)
	))
	lines.append("skill_crafter_dominant_readiness=%.9f" % float(
		snapshot.get("dominant_readiness", -1.0)
	))
	lines.append("skill_crafter_dominant_contact_distance_m=%.9f" % float(
		snapshot.get("dominant_contact_distance_m", -1.0)
	))
	var dominant: Array = snapshot.get("dominant_rays", []) as Array
	var support: Array = snapshot.get("support_rays", []) as Array
	lines.append("skill_crafter_dominant_hit_colliders=%s" % str(
		_collect_hit_field_values(dominant, "collider_name")
	))
	lines.append("skill_crafter_dominant_hit_layers=%s" % str(
		_collect_hit_field_values(dominant, "collider_layer")
	))
	lines.append("skill_crafter_dominant_hit_contexts=%s" % str(
		_collect_hit_field_values(dominant, "context")
	))
	for finger_id: String in FINGER_IDS:
		lines.append("skill_crafter_dominant_%s_rays=%d" % [
			finger_id,
			_count_finger_rays(dominant, finger_id, false),
		])
		lines.append("skill_crafter_dominant_%s_hits=%d" % [
			finger_id,
			_count_finger_rays(dominant, finger_id, true),
		])
		lines.append("skill_crafter_support_%s_rays=%d" % [
			finger_id,
			_count_finger_rays(support, finger_id, false),
		])
		lines.append("skill_crafter_support_%s_hits=%d" % [
			finger_id,
			_count_finger_rays(support, finger_id, true),
		])


func _count_finger_rays(entries: Array, finger_id: String, hits_only: bool) -> int:
	var count := 0
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		if String(entry.get("finger_id", "")) != finger_id:
			continue
		if hits_only and not bool(entry.get("hit", false)):
			continue
		count += 1
	return count


func _collect_hit_field_values(entries: Array, field_name: String) -> Array:
	var unique: Dictionary = {}
	for entry_variant: Variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		if not bool(entry.get("hit", false)):
			continue
		var value: Variant = entry.get(field_name, null)
		unique[value] = true
	return unique.keys()


func _wait_process_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await process_frame


func _wait_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame


func _finish(error: String) -> void:
	lines.append("error=%s" % error)
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
	print("\n".join(lines))
	quit(0 if error.is_empty() else 1)
