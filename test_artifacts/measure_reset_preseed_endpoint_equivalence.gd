extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const StationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const OriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const ENDPOINT_PARITY_EPSILON_METERS := 0.000001

var failures: PackedStringArray = []


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
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = user_args[0] if not user_args.is_empty() else "default2_reset"
	var primary_slot_id: StringName = (
		&"hand_left" if mode.begins_with("left") else &"hand_right"
	)
	var use_two_hand: bool = not mode.contains("one_hand")
	var fresh_skill_entry: bool = mode.contains("fresh_skill_entry")
	var target_skill_slot_id: StringName = (
		&"skill_slot_12" if fresh_skill_entry else &"skill_slot_1"
	)
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP = null
	for candidate: CraftedItemWIP in source_library.get_saved_wips():
		if candidate != null and candidate.forge_project_name == TARGET_PROJECT_NAME:
			source_wip = candidate
			break
	if source_wip == null:
		push_error("endpoint-equivalence target WIP missing")
		quit(1)
		return
	var wip := source_wip.duplicate(true) as CraftedItemWIP
	if fresh_skill_entry:
		wip.combat_animation_station_state = StationStateScript.new()
	var library := LibraryScript.new() as PlayerForgeWipLibraryState
	library.saved_wips.append(wip)
	library.selected_wip_id = wip.wip_id
	var fake := FakePlayer.new()
	fake.forge_wip_library_state = library
	root.add_child(fake)
	var ui := UIScene.instantiate() as CombatAnimationStationUI
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake, "Reset endpoint-equivalence diagnostic")
	await _frames(2)
	print(
		"MODE mode=", mode,
		" primary=", primary_slot_id,
		" two_hand=", use_two_hand,
		" fresh_skill_entry=", fresh_skill_entry
	)
	print("open=", ui.open_saved_wip_with_hand_setup(
		wip.wip_id,
		primary_slot_id,
		use_two_hand,
		false
	))
	await _frames(2)
	if fresh_skill_entry:
		# Opening a clean station may eagerly create its default skill package. Remove
		# only the diagnostic target so `select_skill_slot()` must exercise its
		# `created_new_draft` endpoint handoff path.
		var active_station: Resource = ui.call(
			"_get_active_station_state"
		) as Resource
		if active_station != null:
			var retained_skill_drafts: Array = []
			var removed_target_count: int = 0
			for draft_variant: Variant in active_station.get("skill_drafts") as Array:
				var candidate_draft: Resource = draft_variant as Resource
				if (
					candidate_draft != null
					and StringName(candidate_draft.get("owning_skill_id"))
						== target_skill_slot_id
				):
					removed_target_count += 1
					continue
				retained_skill_drafts.append(draft_variant)
			active_station.set("skill_drafts", retained_skill_drafts)
			print(
				"FRESH_SETUP removed_target_count=", removed_target_count,
				" retained_count=", retained_skill_drafts.size(),
				" lookup_after_remove=", ui.call(
					"_find_skill_draft_by_slot_id",
					target_skill_slot_id
				)
			)
	print("select=", ui.select_skill_slot(target_skill_slot_id, true))
	await _frames(2)
	_dump_endpoints(ui, "after_select", fresh_skill_entry, fresh_skill_entry)
	_dump_chain_endpoints(ui, "after_select", fresh_skill_entry)
	_dump_primary_solve_contract(
		ui,
		"after_select",
		primary_slot_id,
		fresh_skill_entry,
		false
	)
	if not fresh_skill_entry:
		print("reset=", ui.reset_active_draft_to_baseline())
		await _frames(2)
		_dump_endpoints(ui, "after_reset", true, true)
		_dump_chain_endpoints(ui, "after_reset", true)
		_dump_primary_solve_contract(
			ui,
			"after_reset",
			primary_slot_id,
			true,
			true
		)
	if user_args.has("probe_reseat"):
		var probe_node: CombatAnimationMotionNode = ui.call(
			"_get_active_motion_node"
		) as CombatAnimationMotionNode
		var rendered_before: Dictionary = _resolve_rendered_endpoints(ui)
		var reseated: Dictionary = ui.preview_presenter.reseat_motion_node_grip_to_occupied_contact(
			ui.preview_subviewport,
			ui.active_wip,
			probe_node
		)
		var rendered_after: Dictionary = _resolve_rendered_endpoints(ui)
		print(
			"RESEAT returned_tip_to_before_mm=",
			(reseated.get("tip_position_local", Vector3.INF) as Vector3).distance_to(
				rendered_before.get("tip", Vector3.INF) as Vector3
			) * 1000.0,
			" returned_pommel_to_before_mm=",
			(reseated.get("pommel_position_local", Vector3.INF) as Vector3).distance_to(
				rendered_before.get("pommel", Vector3.INF) as Vector3
			) * 1000.0,
			" returned_tip_to_after_mm=",
			(reseated.get("tip_position_local", Vector3.INF) as Vector3).distance_to(
				rendered_after.get("tip", Vector3.INF) as Vector3
			) * 1000.0,
			" returned_pommel_to_after_mm=",
			(reseated.get("pommel_position_local", Vector3.INF) as Vector3).distance_to(
				rendered_after.get("pommel", Vector3.INF) as Vector3
			) * 1000.0,
			" grasp_current=",
			(rendered_after.get("actor") as Node3D).call(
				"has_authoring_current_surface_grip",
				&"hand_right"
			)
		)
		quit(0)
		return
	if use_two_hand:
		print("support_half=", ui.set_selected_motion_node_secondary_grip_seat_slide(
			0.5,
			false,
			false,
			false,
			true,
			false
		))
		await _frames(2)
		_dump_endpoints(ui, "after_support_half", true, true)
		_dump_chain_endpoints(ui, "after_support_half", true)
		_dump_primary_solve_contract(
			ui,
			"after_support_half",
			primary_slot_id,
			true,
			false
		)
	var root_frame_before_bake: Dictionary = _dump_root_frame(ui, "before_bake")
	var cache_result: Dictionary = ui.call("_refresh_active_draft_runtime_clip_cache") as Dictionary
	_dump_root_frame(ui, "after_bake", root_frame_before_bake)
	print(
		"CACHE cached=", cache_result.get("cached", false),
		" reason=", cache_result.get("reason", ""),
		" frames=", cache_result.get("frame_count", -1)
	)
	_require(
		bool(cache_result.get("cached", false)),
		"runtime clip cache did not bake",
		String(cache_result.get("reason", ""))
	)
	var draft: Resource = ui.call("_get_active_draft") as Resource
	var clip: Resource = draft.get("baked_runtime_clip") as Resource if draft != null else null
	if clip == null:
		_require(false, "runtime clip unavailable after successful cache request")
	else:
		var tips: PackedVector3Array = clip.get(
			"baked_tip_positions_local"
		) as PackedVector3Array
		var pommels: PackedVector3Array = clip.get(
			"baked_pommel_positions_local"
		) as PackedVector3Array
		var node: CombatAnimationMotionNode = ui.call(
			"_get_active_motion_node"
		) as CombatAnimationMotionNode
		if tips.is_empty() or pommels.is_empty() or node == null:
			_require(false, "runtime clip endpoint frames or active node unavailable")
		else:
			var final_frame_index: int = mini(tips.size(), pommels.size()) - 1
			var chain: Array = draft.get("motion_node_chain") as Array
			var entry_node: CombatAnimationMotionNode = (
				chain[0] as CombatAnimationMotionNode if not chain.is_empty() else null
			)
			print(
				"BAKE final_tip_mm=",
				node.tip_position_local.distance_to(tips[final_frame_index]) * 1000.0,
				" final_pommel_mm=",
				node.pommel_position_local.distance_to(pommels[final_frame_index]) * 1000.0,
				" node_tip=", node.tip_position_local,
				" baked_final_tip=", tips[final_frame_index],
				" node_pommel=", node.pommel_position_local,
				" baked_final_pommel=", pommels[final_frame_index],
				" frame0_tip=", tips[0],
				" frame0_pommel=", pommels[0],
				" entry_tip_mm=", (
					entry_node.tip_position_local.distance_to(tips[0]) * 1000.0
					if entry_node != null
					else INF
				),
				" entry_pommel_mm=", (
					entry_node.pommel_position_local.distance_to(pommels[0]) * 1000.0
					if entry_node != null
					else INF
				),
				" entry_frame0_exact=", (
					entry_node != null
					and entry_node.tip_position_local == tips[0]
					and entry_node.pommel_position_local == pommels[0]
				)
			)
			_require(
				node.tip_position_local == tips[final_frame_index]
				and node.pommel_position_local == pommels[final_frame_index],
				"bake final frame is not bit-identical to the active authored node",
				"tip_mm=%f pommel_mm=%f" % [
					node.tip_position_local.distance_to(tips[final_frame_index]) * 1000.0,
					node.pommel_position_local.distance_to(pommels[final_frame_index]) * 1000.0,
				]
			)
			_require(
				entry_node != null
				and entry_node.tip_position_local == tips[0]
				and entry_node.pommel_position_local == pommels[0],
				"bake frame zero is not bit-identical to the authored entry node"
			)
			_require(
				StringName(clip.get("baked_tip_positions_origin_id"))
					== OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
				and StringName(clip.get("baked_pommel_positions_origin_id"))
					== OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
				"baked endpoint origins are not TrajectoryAuthoring"
			)
			ui.chain_player.prepare_runtime_clip(clip, 1.0, false)
			ui.chain_player.start()
			ui.session_state.playback_active = true
			ui.call("_sync_preview_playback_pose_only")
			await _frames(2)
			_dump_root_frame(ui, "f_runtime_frame0", root_frame_before_bake)
			_dump_endpoints(ui, "f_runtime_frame0", true, true)
			ui.chain_player.advance(float(clip.get("total_duration_seconds")))
			ui.call("_sync_preview_playback_pose_only")
			await _frames(2)
			_dump_root_frame(ui, "f_runtime_final", root_frame_before_bake)
			_dump_endpoints(ui, "f_runtime_final", true, true)
			var active_node: CombatAnimationMotionNode = ui.call(
				"_get_active_motion_node"
			) as CombatAnimationMotionNode
			if active_node == null:
				_require(false, "F/runtime active authored node unavailable")
			else:
				print(
					"F_STATE final_chain_tip_to_authored_mm=",
					ui.chain_player.current_tip_position.distance_to(
						active_node.tip_position_local
					) * 1000.0,
					" final_chain_pommel_to_authored_mm=",
					ui.chain_player.current_pommel_position.distance_to(
						active_node.pommel_position_local
					) * 1000.0
				)
				_require(
					ui.chain_player.current_tip_position
						== active_node.tip_position_local
					and ui.chain_player.current_pommel_position
						== active_node.pommel_position_local,
					"F/runtime final endpoint state is not bit-identical to authored",
					"tip_mm=%f pommel_mm=%f" % [
						ui.chain_player.current_tip_position.distance_to(
							active_node.tip_position_local
						) * 1000.0,
						ui.chain_player.current_pommel_position.distance_to(
							active_node.pommel_position_local
						) * 1000.0,
					]
				)
	ui.queue_free()
	fake.queue_free()
	await _frames(2)
	if failures.is_empty():
		print("ENDPOINT_EQUIVALENCE_RESULT=PASS mode=", mode)
		quit(0)
	else:
		push_error(
			"ENDPOINT_EQUIVALENCE_RESULT=FAIL mode=%s failures=%d [%s]" % [
				mode,
				failures.size(),
				"; ".join(failures),
			]
		)
		quit(1)


func _dump_endpoints(
	ui: CombatAnimationStationUI,
	label: String,
	enforce_parity: bool = false,
	require_exact: bool = false
) -> void:
	var rendered_state: Dictionary = _resolve_rendered_endpoints(ui)
	var node: CombatAnimationMotionNode = ui.call("_get_active_motion_node") as CombatAnimationMotionNode
	if rendered_state.is_empty() or node == null:
		print("ENDPOINT stage=", label, " available=false")
		if enforce_parity:
			_require(false, "%s rendered/authored endpoints unavailable" % label)
		return
	var rendered_tip: Vector3 = rendered_state.get("tip", Vector3.ZERO) as Vector3
	var rendered_pommel: Vector3 = rendered_state.get("pommel", Vector3.ZERO) as Vector3
	var debug_state: Dictionary = ui.get_preview_debug_state()
	print(
		"ENDPOINT stage=", label,
		" selected_index=", node.node_index,
		" tip_mm=", node.tip_position_local.distance_to(rendered_tip) * 1000.0,
		" pommel_mm=", node.pommel_position_local.distance_to(rendered_pommel) * 1000.0,
		" authored_tip=", node.tip_position_local,
		" rendered_tip=", rendered_tip,
		" authored_pommel=", node.pommel_position_local,
		" rendered_pommel=", rendered_pommel,
		" debug_resolved_tip_mm=", (
			node.tip_position_local.distance_to(
				debug_state.get("resolved_tip_position_local", Vector3.INF) as Vector3
			) * 1000.0
		),
		" debug_resolved_pommel_mm=", (
			node.pommel_position_local.distance_to(
				debug_state.get("resolved_pommel_position_local", Vector3.INF) as Vector3
			) * 1000.0
		)
	)
	if enforce_parity:
		_require(
			node.tip_position_local.distance_to(rendered_tip)
				<= ENDPOINT_PARITY_EPSILON_METERS
			and node.pommel_position_local.distance_to(rendered_pommel)
				<= ENDPOINT_PARITY_EPSILON_METERS,
			"%s authored/rendered endpoint drift" % label,
			"tip_mm=%f pommel_mm=%f" % [
				node.tip_position_local.distance_to(rendered_tip) * 1000.0,
				node.pommel_position_local.distance_to(rendered_pommel) * 1000.0,
			]
		)
	if require_exact:
		_require(
			node.tip_position_local == rendered_tip
			and node.pommel_position_local == rendered_pommel,
			"%s authored/rendered endpoints are not bit-identical" % label,
			"tip_mm=%f pommel_mm=%f" % [
				node.tip_position_local.distance_to(rendered_tip) * 1000.0,
				node.pommel_position_local.distance_to(rendered_pommel) * 1000.0,
			]
		)


func _dump_chain_endpoints(
	ui: CombatAnimationStationUI,
	label: String,
	enforce_entry_identity: bool = false
) -> void:
	var rendered_state: Dictionary = _resolve_rendered_endpoints(ui)
	var draft: Resource = ui.call("_get_active_draft") as Resource
	if rendered_state.is_empty() or draft == null:
		print("CHAIN stage=", label, " available=false")
		if enforce_entry_identity:
			_require(false, "%s rendered endpoint or draft chain unavailable" % label)
		return
	var rendered_tip: Vector3 = rendered_state.get("tip", Vector3.ZERO) as Vector3
	var rendered_pommel: Vector3 = rendered_state.get("pommel", Vector3.ZERO) as Vector3
	var chain: Array = draft.get("motion_node_chain") as Array
	for node_index: int in range(chain.size()):
		var node: CombatAnimationMotionNode = chain[node_index] as CombatAnimationMotionNode
		if node == null:
			print("CHAIN stage=", label, " node=", node_index, " available=false")
			continue
		print(
			"CHAIN stage=", label,
			" node=", node_index,
			" tip_mm=", node.tip_position_local.distance_to(rendered_tip) * 1000.0,
			" pommel_mm=", node.pommel_position_local.distance_to(rendered_pommel) * 1000.0,
			" tip_origin=", node.tip_position_origin_id,
			" pommel_origin=", node.pommel_position_origin_id,
			" two_hand=", node.two_hand_state
		)
	if chain.size() >= 2:
		var entry_node: CombatAnimationMotionNode = chain[0] as CombatAnimationMotionNode
		var visible_node: CombatAnimationMotionNode = chain[1] as CombatAnimationMotionNode
		print(
			"CHAIN_IDENTITY stage=", label,
			" endpoints_exact=", (
				entry_node != null
				and visible_node != null
				and entry_node.tip_position_local == visible_node.tip_position_local
				and entry_node.tip_position_origin_id == visible_node.tip_position_origin_id
				and entry_node.pommel_position_local == visible_node.pommel_position_local
				and entry_node.pommel_position_origin_id
					== visible_node.pommel_position_origin_id
			),
			" tip_delta_mm=", (
				entry_node.tip_position_local.distance_to(visible_node.tip_position_local)
					* 1000.0
				if entry_node != null and visible_node != null
				else INF
			),
			" pommel_delta_mm=", (
				entry_node.pommel_position_local.distance_to(
					visible_node.pommel_position_local
				) * 1000.0
				if entry_node != null and visible_node != null
				else INF
			)
		)
		if enforce_entry_identity:
			_require(
				entry_node != null
				and visible_node != null
				and entry_node.tip_position_local == visible_node.tip_position_local
				and entry_node.tip_position_origin_id
					== visible_node.tip_position_origin_id
				and entry_node.pommel_position_local
					== visible_node.pommel_position_local
				and entry_node.pommel_position_origin_id
					== visible_node.pommel_position_origin_id,
				"%s hidden/visible endpoint handoff is not bit-identical" % label
			)
			_require(
				entry_node != null
				and visible_node != null
				and entry_node.tip_position_origin_id
					== OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
				and entry_node.pommel_position_origin_id
					== OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
				"%s endpoint origins are not TrajectoryAuthoring" % label
			)
	elif enforce_entry_identity:
		_require(false, "%s fresh skill baseline does not contain node0/node1" % label)


func _dump_primary_solve_contract(
	ui: CombatAnimationStationUI,
	label: String,
	primary_slot_id: StringName,
	enforce_contract: bool = false,
	require_reset_handoff: bool = false
) -> void:
	var rendered_state: Dictionary = _resolve_rendered_endpoints(ui)
	if rendered_state.is_empty():
		print("CONTRACT stage=", label, " available=false")
		if enforce_contract:
			_require(false, "%s Primary contract rendered state unavailable" % label)
		return
	var actor: Node3D = rendered_state.get("actor", null) as Node3D
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	if actor == null or preview_root == null:
		print("CONTRACT stage=", label, " available=false")
		if enforce_contract:
			_require(false, "%s Primary contract actor/root unavailable" % label)
		return
	var transaction: Dictionary = preview_root.get_meta(
		"primary_surface_grip_transaction_result",
		{}
	) as Dictionary
	var preseed: Dictionary = preview_root.get_meta(
		"reset_primary_grip_preseed_result",
		{}
	) as Dictionary
	var refresh: Dictionary = preview_root.get_meta(
		"reset_primary_grip_preseed_refresh_result",
		{}
	) as Dictionary
	var reuse: Dictionary = preview_root.get_meta(
		"primary_grip_preseed_reuse_result",
		{}
	) as Dictionary
	var skill_entry: Dictionary = preview_root.get_meta(
		"skill_entry_primary_grip_preseed_result",
		{}
	) as Dictionary
	var seat: Dictionary = actor.call(
		"get_authoring_current_weapon_surface_seat",
		primary_slot_id
	) as Dictionary
	var grasp: Dictionary = actor.call(
		"get_authoring_surface_grasp_debug_state",
		primary_slot_id
	) as Dictionary
	var committed_packet_valid: bool = bool(actor.call(
		"has_authoring_committed_surface_grip",
		primary_slot_id
	))
	var current_grasp_valid: bool = bool(actor.call(
		"has_authoring_current_surface_grip",
		primary_slot_id
	))
	var committed_rotation_count: int = int((grasp.get(
		"rotations",
		{}
	) as Dictionary).size())
	print(
		"CONTRACT stage=", label,
		" transaction_status=", transaction.get("status", &""),
		" transaction_committed=", transaction.get("committed", false),
		" transaction_seat_solve_count=", transaction.get(
			"committed_surface_seat_solve_count",
			-1
		),
		" transaction_grasp_solve_count=", transaction.get(
			"committed_grasp_solve_count",
			-1
		),
		" current_seat_solve_count=", seat.get("solve_count", -1),
		" current_grasp_solve_count=", grasp.get("solve_count", -1),
		" seat_solve_delta=", (
			int(seat.get("solve_count", -1))
				- int(transaction.get("committed_surface_seat_solve_count", -1))
		),
		" grasp_solve_delta=", (
			int(grasp.get("solve_count", -1))
				- int(transaction.get("committed_grasp_solve_count", -1))
		),
		" preseed_valid=", preseed.get("valid", false),
		" final_handoff_valid=", preseed.get("final_handoff_valid", false),
		" refresh_valid=", refresh.get("valid", false),
		" reuse_valid=", reuse.get("valid", false),
		" skill_entry_valid=", skill_entry.get("valid", false),
		" skill_entry_status=", skill_entry.get("status", &""),
		" reuse_surface_requeried=", reuse.get("surface_seat_requeried", true),
		" reuse_digit_resolved=", reuse.get("digit_packet_resolved", true),
		" committed_packet_valid=", committed_packet_valid,
		" current_grasp_valid=", current_grasp_valid,
		" committed_rotation_count=", committed_rotation_count
	)
	if not enforce_contract:
		return
	var transaction_committed: bool = (
		bool(transaction.get("attempted", false))
		and bool(transaction.get("valid", false))
		and bool(transaction.get("applied", false))
		and bool(transaction.get("committed", false))
		and StringName(transaction.get("status", StringName()))
			== &"primary_surface_grip_transaction_committed"
	)
	_require(transaction_committed, "%s Primary transaction did not commit" % label)
	_require(
		bool(seat.get("valid", false))
		and committed_packet_valid
		and current_grasp_valid
		and committed_rotation_count == 15,
		"%s Primary seat/15-bone packet is not current" % label,
		"seat=%s committed=%s current=%s bones=%d" % [
			str(bool(seat.get("valid", false))),
			str(committed_packet_valid),
			str(current_grasp_valid),
			committed_rotation_count,
		]
	)
	_require(
		int(seat.get("solve_count", -1))
			== int(transaction.get("committed_surface_seat_solve_count", -2))
		and int(grasp.get("solve_count", -1))
			== int(transaction.get("committed_grasp_solve_count", -2)),
		"%s added a second Primary seat or digit solve" % label,
		"seat_delta=%d grasp_delta=%d" % [
			int(seat.get("solve_count", -1))
				- int(transaction.get("committed_surface_seat_solve_count", -1)),
			int(grasp.get("solve_count", -1))
				- int(transaction.get("committed_grasp_solve_count", -1)),
		]
	)
	if require_reset_handoff:
		_require(
			bool(preseed.get("final_handoff_valid", false))
			and bool(refresh.get("valid", false))
			and bool(reuse.get("valid", false)),
			"%s Reset preseed final handoff is invalid" % label,
			"preseed=%s refresh=%s reuse=%s" % [
				String(preseed.get("status", &"")),
				String(refresh.get("status", &"")),
				String(reuse.get("status", &"")),
			]
		)
		_require(
			not bool(reuse.get("surface_seat_requeried", true))
			and not bool(reuse.get("digit_packet_resolved", true)),
			"%s final preseed reuse performed new geometry work" % label
		)


func _resolve_rendered_endpoints(ui: CombatAnimationStationUI) -> Dictionary:
	var preview_root := ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	if preview_root == null:
		return {}
	var trajectory_root := preview_root.find_child("TrajectoryRoot", true, false) as Node3D
	var held := preview_root.get_meta("preview_held_item", null) as Node3D
	var actor := preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
	if trajectory_root == null or held == null or actor == null:
		return {}
	var local_tip: Vector3 = held.get_meta("weapon_tip_local", Vector3.ZERO) as Vector3
	var local_pommel: Vector3 = held.get_meta("weapon_pommel_local", Vector3.ZERO) as Vector3
	return {
		"tip": trajectory_root.to_local(held.to_global(local_tip)),
		"pommel": trajectory_root.to_local(held.to_global(local_pommel)),
		"actor": actor,
	}


func _dump_root_frame(
	ui: CombatAnimationStationUI,
	label: String,
	reference: Dictionary = {}
) -> Dictionary:
	var rendered_state: Dictionary = _resolve_rendered_endpoints(ui)
	var actor: Node3D = rendered_state.get("actor", null) as Node3D
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	if actor == null or preview_root == null:
		print("ROOT_FRAME stage=", label, " available=false")
		return {}
	var skeleton: Skeleton3D = actor.get("skeleton") as Skeleton3D
	var rl_bone_root_world: Transform3D = Transform3D.IDENTITY
	var rl_bone_root_index: int = -1
	if skeleton != null:
		rl_bone_root_index = skeleton.find_bone("RL_BoneRoot")
		if rl_bone_root_index >= 0:
			rl_bone_root_world = (
				skeleton.global_transform
				* skeleton.get_bone_global_pose(rl_bone_root_index)
			)
	var held_item: Node3D = preview_root.get_meta(
		"preview_held_item",
		null
	) as Node3D
	var current: Dictionary = {
		"actor_transform": actor.global_transform,
		"skeleton_transform": (
			skeleton.global_transform if skeleton != null else Transform3D.IDENTITY
		),
		"rl_bone_root_world": rl_bone_root_world,
		"held_transform": (
			held_item.global_transform
			if held_item != null
			else Transform3D.IDENTITY
		),
	}
	var reference_rl: Transform3D = reference.get(
		"rl_bone_root_world",
		rl_bone_root_world
	) as Transform3D
	var reference_held: Transform3D = reference.get(
		"held_transform",
		current.get("held_transform")
	) as Transform3D
	var held_transform: Transform3D = current.get(
		"held_transform",
		Transform3D.IDENTITY
	) as Transform3D
	var resolved_playback_state: Dictionary = preview_root.get_meta(
		"resolved_playback_state",
		{}
	) as Dictionary
	print(
		"ROOT_FRAME stage=", label,
		" rl_index=", rl_bone_root_index,
		" baseline_animation=", actor.get("authoring_preview_baseline_animation_name"),
		" default_animation=", actor.get("default_animation_name"),
		" authoring_preview=", actor.get("authoring_preview_mode_enabled"),
		" pose_mode=", preview_root.get_meta("preview_pose_mode", &""),
		" playback_active=", ui.session_state.playback_active,
		" chain_playing=", ui.chain_player.is_playing(),
		" playback_state_active=", resolved_playback_state.get("active", false),
		" runtime_clip=", resolved_playback_state.get("runtime_clip_playback", false),
		" rl_origin=", rl_bone_root_world.origin,
		" rl_delta_mm=", rl_bone_root_world.origin.distance_to(
			reference_rl.origin
		) * 1000.0,
		" rl_delta_degrees=", rad_to_deg(
			rl_bone_root_world.basis.get_rotation_quaternion().angle_to(
				reference_rl.basis.get_rotation_quaternion()
			)
		),
		" held_origin=", held_transform.origin,
		" held_delta_mm=", held_transform.origin.distance_to(
			reference_held.origin
		) * 1000.0,
		" held_delta_degrees=", rad_to_deg(
			held_transform.basis.get_rotation_quaternion().angle_to(
				reference_held.basis.get_rotation_quaternion()
			)
		)
	)
	return current


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _require(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		return
	var failure: String = label
	if not detail.is_empty():
		failure = "%s (%s)" % [failure, detail]
	failures.append(failure)
	push_error("ASSERT: %s" % failure)
