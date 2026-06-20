extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const CombatAnimationStationUIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")

const TARGET_PROJECT_NAME := "Test sword for animations"
const RESULT_FILE_PATH := "C:/WORKSPACE/grip_orientation_reset_pose_results.txt"
const TEMP_SAVE_FILE_PATH := "C:/WORKSPACE/test_artifacts/diagnose_grip_orientation_reset_pose_library.tres"

class FakePlayer:
	extends Node

	var ui_mode_enabled: bool = false
	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(enabled: bool) -> void:
		ui_mode_enabled = enabled

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	DirAccess.make_dir_recursive_absolute("C:/WORKSPACE/test_artifacts")
	var lines: PackedStringArray = []
	lines.append("target_project_name=%s" % TARGET_PROJECT_NAME)

	var source_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(source_library, TARGET_PROJECT_NAME)
	lines.append("source_library_loaded=%s" % str(source_library != null))
	lines.append("source_wip_found=%s" % str(source_wip != null))
	if source_wip == null:
		_write_results(lines)
		quit()
		return

	var temp_library: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.new()
	temp_library.save_file_path = TEMP_SAVE_FILE_PATH
	temp_library.saved_wips.clear()
	var normal_wip: CraftedItemWIP = _build_variant_wip(source_wip, &"diag_grip_normal", CraftedItemWIP.GRIP_NORMAL)
	var reverse_wip: CraftedItemWIP = _build_variant_wip(source_wip, &"diag_grip_reverse", CraftedItemWIP.GRIP_REVERSE)
	temp_library.saved_wips.append(normal_wip)
	temp_library.saved_wips.append(reverse_wip)
	temp_library.selected_wip_id = normal_wip.wip_id
	temp_library.persist()

	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = temp_library
	root.add_child(fake_player)

	var ui: CombatAnimationStationUI = CombatAnimationStationUIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await process_frame
	ui.open_for(fake_player, "Grip Orientation Reset Pose Diagnostic")
	await _wait_frames(6)

	lines.append_array(await _capture_variant(ui, normal_wip.wip_id, "normal", &"hand_right"))
	lines.append_array(await _capture_variant(ui, reverse_wip.wip_id, "reverse", &"hand_right"))

	_write_results(lines)
	quit()

func _build_variant_wip(source_wip: CraftedItemWIP, suffix: StringName, grip_style_mode: StringName) -> CraftedItemWIP:
	var variant_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	variant_wip.wip_id = StringName("%s_%s" % [String(source_wip.wip_id), String(suffix)])
	variant_wip.forge_project_name = "%s %s" % [source_wip.forge_project_name, String(suffix)]
	variant_wip.grip_style_mode = grip_style_mode
	variant_wip.ensure_combat_animation_station_state()
	return variant_wip

func _capture_variant(ui: CombatAnimationStationUI, wip_id: StringName, label: String, slot_id: StringName) -> PackedStringArray:
	var lines: PackedStringArray = []
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(wip_id, slot_id, false, false)
	await _wait_frames(6)
	var select_idle_ok: bool = ui.select_authoring_mode(CombatAnimationStationStateScript.AUTHORING_MODE_IDLE)
	await _wait_frames(3)
	var select_combat_idle_ok: bool = ui.select_draft(CombatAnimationStationStateScript.IDLE_CONTEXT_COMBAT, true)
	await _wait_frames(3)
	var reset_ok: bool = ui.reset_active_draft_to_baseline()
	await _wait_frames(8)

	lines.append("%s_open_ok=%s" % [label, str(open_ok)])
	lines.append("%s_select_idle_ok=%s" % [label, str(select_idle_ok)])
	lines.append("%s_select_combat_idle_ok=%s" % [label, str(select_combat_idle_ok)])
	lines.append("%s_reset_ok=%s" % [label, str(reset_ok)])
	lines.append("%s_active_slot=%s" % [label, String(ui.get_active_open_dominant_slot_id())])
	lines.append("%s_active_two_hand=%s" % [label, str(ui.is_active_open_two_hand())])
	lines.append_array(_build_orientation_report(ui, label, slot_id))
	return lines

func _build_orientation_report(ui: CombatAnimationStationUI, label: String, slot_id: StringName) -> PackedStringArray:
	var lines: PackedStringArray = []
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D if ui.preview_subviewport != null else null
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D if preview_root != null else null
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D if preview_root != null else null
	var trajectory_root: Node3D = preview_root.find_child("TrajectoryRoot", true, false) as Node3D if preview_root != null else null
	var motion_node: CombatAnimationMotionNode = _get_first_motion_node(ui)
	if actor == null or held_item == null or trajectory_root == null:
		lines.append("%s_capture_complete=false" % label)
		return lines
	var hand_anchor: Node3D = actor.get_right_hand_item_anchor() if slot_id == &"hand_right" else actor.get_left_hand_item_anchor()
	var hand_parent: Node3D = hand_anchor.get_parent() as Node3D if hand_anchor != null else null
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var local_grip: Vector3 = held_item.get_meta("primary_grip_contact_local", Vector3.ZERO) as Vector3
	var tip_world: Vector3 = held_item.global_transform * local_tip
	var pommel_world: Vector3 = held_item.global_transform * local_pommel
	var grip_world: Vector3 = held_item.global_transform * local_grip
	var weapon_axis_world: Vector3 = _safe_axis(tip_world - pommel_world)
	var grip_to_tip_world: Vector3 = _safe_axis(tip_world - grip_world)
	var hand_x: Vector3 = hand_anchor.global_basis.x.normalized() if hand_anchor != null else Vector3.ZERO
	var hand_y: Vector3 = hand_anchor.global_basis.y.normalized() if hand_anchor != null else Vector3.ZERO
	var hand_z: Vector3 = hand_anchor.global_basis.z.normalized() if hand_anchor != null else Vector3.ZERO
	var parent_x: Vector3 = hand_parent.global_basis.x.normalized() if hand_parent != null else Vector3.ZERO
	var parent_y: Vector3 = hand_parent.global_basis.y.normalized() if hand_parent != null else Vector3.ZERO
	var parent_z: Vector3 = hand_parent.global_basis.z.normalized() if hand_parent != null else Vector3.ZERO
	var actor_x: Vector3 = actor.global_basis.x.normalized()
	var actor_y: Vector3 = actor.global_basis.y.normalized()
	var actor_z: Vector3 = actor.global_basis.z.normalized()
	var basis_anchor: Node3D = held_item.get_node_or_null("PrimaryGripAnchor/PrimaryGripBasisAnchor") as Node3D
	var basis_y: Vector3 = basis_anchor.global_basis.y.normalized() if basis_anchor != null else Vector3.ZERO
	var basis_z: Vector3 = basis_anchor.global_basis.z.normalized() if basis_anchor != null else Vector3.ZERO
	var authored_baseline_seed: Dictionary = ui.call("_resolve_active_weapon_authored_baseline_seed") as Dictionary

	lines.append("%s_capture_complete=true" % label)
	lines.append("%s_grip_style=%s" % [label, String(held_item.get_meta("grip_style_mode", StringName()))])
	lines.append("%s_tip_world=%s" % [label, str(tip_world)])
	lines.append("%s_pommel_world=%s" % [label, str(pommel_world)])
	lines.append("%s_grip_world=%s" % [label, str(grip_world)])
	lines.append("%s_weapon_axis_world=%s" % [label, str(weapon_axis_world)])
	lines.append("%s_grip_to_tip_world=%s" % [label, str(grip_to_tip_world)])
	lines.append("%s_hand_x_world=%s" % [label, str(hand_x)])
	lines.append("%s_hand_y_world=%s" % [label, str(hand_y)])
	lines.append("%s_hand_z_world=%s" % [label, str(hand_z)])
	lines.append("%s_parent_x_world=%s" % [label, str(parent_x)])
	lines.append("%s_parent_y_world=%s" % [label, str(parent_y)])
	lines.append("%s_parent_z_world=%s" % [label, str(parent_z)])
	lines.append("%s_actor_x_world=%s" % [label, str(actor_x)])
	lines.append("%s_actor_y_world=%s" % [label, str(actor_y)])
	lines.append("%s_actor_z_world=%s" % [label, str(actor_z)])
	lines.append("%s_weapon_dot_hand_x=%.6f" % [label, weapon_axis_world.dot(hand_x)])
	lines.append("%s_weapon_dot_hand_y=%.6f" % [label, weapon_axis_world.dot(hand_y)])
	lines.append("%s_weapon_dot_hand_z=%.6f" % [label, weapon_axis_world.dot(hand_z)])
	lines.append("%s_weapon_dot_parent_x=%.6f" % [label, weapon_axis_world.dot(parent_x)])
	lines.append("%s_weapon_dot_parent_y=%.6f" % [label, weapon_axis_world.dot(parent_y)])
	lines.append("%s_weapon_dot_parent_z=%.6f" % [label, weapon_axis_world.dot(parent_z)])
	lines.append("%s_weapon_dot_actor_x=%.6f" % [label, weapon_axis_world.dot(actor_x)])
	lines.append("%s_weapon_dot_actor_y=%.6f" % [label, weapon_axis_world.dot(actor_y)])
	lines.append("%s_weapon_dot_actor_z=%.6f" % [label, weapon_axis_world.dot(actor_z)])
	lines.append("%s_basis_y_world=%s" % [label, str(basis_y)])
	lines.append("%s_basis_z_world=%s" % [label, str(basis_z)])
	lines.append("%s_basis_z_dot_weapon=%.6f" % [label, basis_z.dot(weapon_axis_world)])
	lines.append("%s_basis_y_dot_up=%.6f" % [label, basis_y.dot(Vector3.UP)])
	lines.append("%s_seed_tip=%s" % [label, str(authored_baseline_seed.get("tip_position_local", Vector3.ZERO))])
	lines.append("%s_seed_pommel=%s" % [label, str(authored_baseline_seed.get("pommel_position_local", Vector3.ZERO))])
	lines.append("%s_seed_orientation=%s" % [label, str(authored_baseline_seed.get("weapon_orientation_degrees", Vector3.ZERO))])
	lines.append("%s_node_tip=%s" % [label, str(motion_node.tip_position_local if motion_node != null else Vector3.ZERO)])
	lines.append("%s_node_pommel=%s" % [label, str(motion_node.pommel_position_local if motion_node != null else Vector3.ZERO)])
	lines.append("%s_node_orientation=%s" % [label, str(motion_node.weapon_orientation_degrees if motion_node != null else Vector3.ZERO)])
	return lines

func _get_first_motion_node(ui: CombatAnimationStationUI) -> CombatAnimationMotionNode:
	var draft: CombatAnimationDraft = ui.call("_get_active_draft") as CombatAnimationDraft
	if draft == null or draft.motion_node_chain.is_empty():
		return null
	return draft.motion_node_chain[0] as CombatAnimationMotionNode

func _safe_axis(vector: Vector3) -> Vector3:
	if vector.length_squared() <= 0.000001:
		return Vector3.ZERO
	return vector.normalized()

func _find_saved_wip_by_project_name(library_state: PlayerForgeWipLibraryState, project_name: String) -> CraftedItemWIP:
	if library_state == null:
		return null
	for saved_wip: CraftedItemWIP in library_state.get_saved_wips():
		if saved_wip == null:
			continue
		if saved_wip.forge_project_name == project_name:
			return saved_wip
	return null

func _wait_frames(frame_count: int) -> void:
	for _frame_index: int in range(maxi(frame_count, 0)):
		await process_frame

func _write_results(lines: PackedStringArray) -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
