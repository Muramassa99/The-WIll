extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const TARGET_PROJECT_NAME := "Star_Handle_Testing"


class FakePlayer:
	extends Node
	var forge_wip_library_state: PlayerForgeWipLibraryState

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP = null
	for candidate: CraftedItemWIP in source_library.get_saved_wips():
		if candidate != null and candidate.forge_project_name == TARGET_PROJECT_NAME:
			source_wip = candidate
			break
	if source_wip == null:
		push_error("replay parity target WIP missing")
		quit(1)
		return
	var wip := source_wip.duplicate(true) as CraftedItemWIP
	var library := LibraryScript.new() as PlayerForgeWipLibraryState
	library.saved_wips.append(wip)
	library.selected_wip_id = wip.wip_id
	var fake := FakePlayer.new()
	fake.forge_wip_library_state = library
	root.add_child(fake)
	var ui := UIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake, "Solved replay track endpoint-parity diagnostic")
	await _frames(2)
	if not ui.open_saved_wip_with_hand_setup(wip.wip_id, &"hand_right", false, false):
		push_error("could not open WIP")
		quit(1)
		return
	await _frames(2)
	if not ui.select_skill_slot(&"skill_slot_1", true):
		push_error("could not select skill")
		quit(1)
		return
	await _frames(2)
	if not ui.reset_active_draft_to_baseline():
		push_error("could not reset draft")
		quit(1)
		return
	await _frames(2)
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var actor := preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var root_index: int = skeleton.find_bone("RL_BoneRoot")
	var root_before: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(root_index)
	)
	var cache_result: Dictionary = ui.call(
		"_refresh_active_draft_runtime_clip_cache"
	) as Dictionary
	var root_after: Transform3D = (
		skeleton.global_transform * skeleton.get_bone_global_pose(root_index)
	)
	var draft: Resource = ui.call("_get_active_draft") as Resource
	var clip: Resource = draft.get("baked_runtime_clip") as Resource
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D
	if not bool(cache_result.get("cached", false)) or clip == null or held_item == null:
		push_error("could not bake diagnostic clip")
		quit(1)
		return
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var endpoint_tips: PackedVector3Array = clip.get("baked_tip_positions_local") as PackedVector3Array
	var endpoint_pommels: PackedVector3Array = clip.get("baked_pommel_positions_local") as PackedVector3Array
	var weapon_positions: PackedVector3Array = clip.get(
		"baked_solved_weapon_positions_reference_local"
	) as PackedVector3Array
	var weapon_rotations: PackedVector4Array = clip.get(
		"baked_solved_weapon_rotations_reference_local"
	) as PackedVector4Array
	var weapon_scales: PackedVector3Array = clip.get(
		"baked_solved_weapon_scales_reference_local"
	) as PackedVector3Array
	var pose_bones: Array = clip.get("baked_solved_upper_body_bone_names") as Array
	print(
		"TRACK_HEADER cached=", cache_result.get("cached", false),
		" frames=", weapon_positions.size(),
		" reference_bone=", clip.get("solved_replay_reference_bone_name"),
		" root_in_pose_packet=", pose_bones.has(&"RL_BoneRoot"),
		" root_translation_delta_mm=", root_before.origin.distance_to(root_after.origin) * 1000.0,
		" root_rotation_delta_degrees=", rad_to_deg(
			root_before.basis.get_rotation_quaternion().angle_to(
				root_after.basis.get_rotation_quaternion()
			)
		)
	)
	var frame_count: int = mini(
		endpoint_tips.size(),
		mini(
			endpoint_pommels.size(),
			mini(weapon_positions.size(), mini(weapon_rotations.size(), weapon_scales.size()))
		)
	)
	var mismatch_count: int = 0
	var maximum_tip_error_meters: float = 0.0
	var maximum_pommel_error_meters: float = 0.0
	for frame_index: int in range(frame_count):
		var packed_rotation: Vector4 = weapon_rotations[frame_index]
		var rotation := Quaternion(
			packed_rotation.x,
			packed_rotation.y,
			packed_rotation.z,
			packed_rotation.w
		).normalized()
		var basis := Basis(rotation).scaled(weapon_scales[frame_index])
		var weapon_reference_transform := Transform3D(basis, weapon_positions[frame_index])
		var reconstructed_tip: Vector3 = weapon_reference_transform * local_tip
		var reconstructed_pommel: Vector3 = weapon_reference_transform * local_pommel
		var tip_error: float = reconstructed_tip.distance_to(endpoint_tips[frame_index])
		var pommel_error: float = reconstructed_pommel.distance_to(
			endpoint_pommels[frame_index]
		)
		maximum_tip_error_meters = maxf(maximum_tip_error_meters, tip_error)
		maximum_pommel_error_meters = maxf(maximum_pommel_error_meters, pommel_error)
		if tip_error > 0.000001 or pommel_error > 0.000001:
			mismatch_count += 1
		print(
			"TRACK_FRAME index=", frame_index,
			" tip_error_mm=", tip_error * 1000.0,
			" pommel_error_mm=", pommel_error * 1000.0,
			" translation_delta=", reconstructed_tip - endpoint_tips[frame_index]
		)
	print(
		"TRACK_RESULT mismatches=", mismatch_count,
		"/", frame_count,
		" max_tip_error_mm=", maximum_tip_error_meters * 1000.0,
		" max_pommel_error_mm=", maximum_pommel_error_meters * 1000.0
	)
	var clip_chain: Array = clip.get("motion_node_chain") as Array
	var last_frame_index: int = frame_count - 1
	if last_frame_index >= 0 and not clip_chain.is_empty():
		await _probe_endpoint_authority_mode(
			ui,
			clip,
			clip_chain[mini(1, clip_chain.size() - 1)] as Resource,
			last_frame_index,
			true
		)
		await _probe_endpoint_authority_mode(
			ui,
			clip,
			clip_chain[mini(1, clip_chain.size() - 1)] as Resource,
			last_frame_index,
			false
		)
	ui.queue_free()
	fake.queue_free()
	await _frames(2)
	quit(0)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _probe_endpoint_authority_mode(
	ui: CombatAnimationStationUI,
	clip: Resource,
	base_motion_node: Resource,
	frame_index: int,
	preserve_authoring_endpoints: bool
) -> void:
	ui.reset_active_draft_to_baseline()
	await _frames(2)
	var presenter: Object = ui.preview_presenter
	var state: Dictionary = presenter.call(
		"_ensure_preview_nodes",
		ui.preview_view_container,
		ui.preview_subviewport
	) as Dictionary
	var frame_motion_node: Resource = presenter.call(
		"_build_runtime_clip_frame_motion_node",
		clip,
		frame_index,
		base_motion_node
	) as Resource
	var playback_state: Dictionary = presenter.call(
		"_build_runtime_clip_frame_playback_state",
		clip,
		frame_index,
		frame_motion_node
	) as Dictionary
	playback_state["runtime_clip_playback"] = true
	presenter.call(
		"_apply_authored_weapon_pose",
		state,
		frame_motion_node,
		playback_state,
		false,
		1.0,
		preserve_authoring_endpoints,
		ui.call("_get_active_draft") as Resource,
		false,
		true
	)
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	var trajectory_root := preview_root.get_node_or_null("TrajectoryRoot") as Node3D
	var held_item: Node3D = preview_root.get_meta("preview_held_item", null) as Node3D
	var local_tip: Vector3 = held_item.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held_item.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	var rendered_tip: Vector3 = trajectory_root.to_local(held_item.to_global(local_tip))
	var rendered_pommel: Vector3 = trajectory_root.to_local(held_item.to_global(local_pommel))
	print(
		"AUTHORITY_PROBE preserve=", preserve_authoring_endpoints,
		" tip_error_mm=", rendered_tip.distance_to(
			playback_state.get("tip_position_local", Vector3.ZERO) as Vector3
		) * 1000.0,
		" pommel_error_mm=", rendered_pommel.distance_to(
			playback_state.get("pommel_position_local", Vector3.ZERO) as Vector3
		) * 1000.0,
		" resolved_tip_alignment_error_mm=", float(preview_root.get_meta(
			"weapon_tip_alignment_error_meters",
			-1.0
		)) * 1000.0,
		" resolved_pommel_alignment_error_mm=", float(preview_root.get_meta(
			"weapon_pommel_alignment_error_meters",
			-1.0
		)) * 1000.0
	)
