extends SceneTree

# Read-only runtime verifier for the Skill Crafter grip relationship contracts.
#
# Production data is never saved: each case operates on a deep duplicate of the
# real Star_Handle_Testing WIP inside a temporary in-memory player library.
#
# Covered contracts:
# - fresh Right/Left Primary acquisition starts with no active execution path;
# - each fresh acquisition commits one current 15-bone Primary packet;
# - fresh hidden entry and visible authored nodes receive one exact endpoint frame;
# - adding/removing Support never changes the WeaponRoot or any Primary limb/digit
#   pose value, and never re-queries/re-solves the Primary relationship;
# - rejected Primary acquisition restores the complete pre-transaction actor,
#   weapon, contact-tree, endpoint, and playback snapshot exactly.
#
# The rejection case uses an existing production gate instead of a production
# test hook: after taking the transaction snapshot, the verifier temporarily
# marks Support active and corrupts one WeaponRoot endpoint-origin marker. The
# acquisition must reject at its support-active-at-entry gate and restore both
# injected changes from the supplied snapshot.

const LibraryScript = preload(
	"res://core/models/player_forge_wip_library_state.gd"
)
const StationStateScript = preload(
	"res://core/models/combat_animation_station_state.gd"
)
const MotionNodeScript = preload(
	"res://core/models/combat_animation_motion_node.gd"
)
const OriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)
const StationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)

const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const FRESH_SKILL_SLOT_ID: StringName = &"skill_slot_12"
const SLOT_RIGHT: StringName = &"hand_right"
const SLOT_LEFT: StringName = &"hand_left"
const EXPECTED_GRIP_PACKET_BONE_COUNT: int = 15
const SUPPORT_TEST_HANDLE_COORDINATE: float = 0.5
const TEMP_LIBRARY_SAVE_PATH := (
	"C:/WORKSPACE/test_artifacts/primary_support_atomicity_library.tres"
)

const RIGHT_PRIMARY_BONES: Array[StringName] = [
	&"CC_Base_R_Clavicle",
	&"CC_Base_R_Upperarm",
	&"CC_Base_R_UpperarmTwist01",
	&"CC_Base_R_UpperarmTwist02",
	&"CC_Base_R_Forearm",
	&"CC_Base_R_ForearmTwist01",
	&"CC_Base_R_ForearmTwist02",
	&"CC_Base_R_Hand",
	&"CC_Base_R_Thumb1",
	&"CC_Base_R_Thumb2",
	&"CC_Base_R_Thumb3",
	&"CC_Base_R_Index1",
	&"CC_Base_R_Index2",
	&"CC_Base_R_Index3",
	&"CC_Base_R_Mid1",
	&"CC_Base_R_Mid2",
	&"CC_Base_R_Mid3",
	&"CC_Base_R_Ring1",
	&"CC_Base_R_Ring2",
	&"CC_Base_R_Ring3",
	&"CC_Base_R_Pinky1",
	&"CC_Base_R_Pinky2",
	&"CC_Base_R_Pinky3",
]
const LEFT_PRIMARY_BONES: Array[StringName] = [
	&"CC_Base_L_Clavicle",
	&"CC_Base_L_Upperarm",
	&"CC_Base_L_UpperarmTwist01",
	&"CC_Base_L_UpperarmTwist02",
	&"CC_Base_L_Forearm",
	&"CC_Base_L_ForearmTwist01",
	&"CC_Base_L_ForearmTwist02",
	&"CC_Base_L_Hand",
	&"CC_Base_L_Thumb1",
	&"CC_Base_L_Thumb2",
	&"CC_Base_L_Thumb3",
	&"CC_Base_L_Index1",
	&"CC_Base_L_Index2",
	&"CC_Base_L_Index3",
	&"CC_Base_L_Mid1",
	&"CC_Base_L_Mid2",
	&"CC_Base_L_Mid3",
	&"CC_Base_L_Ring1",
	&"CC_Base_L_Ring2",
	&"CC_Base_L_Ring3",
	&"CC_Base_L_Pinky1",
	&"CC_Base_L_Pinky2",
	&"CC_Base_L_Pinky3",
]

var failures: PackedStringArray = []


class FakePlayer:
	extends Node

	var forge_wip_library_state: PlayerForgeWipLibraryState = null

	func get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
		return forge_wip_library_state

	func set_ui_mode_enabled(_enabled: bool) -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_library: PlayerForgeWipLibraryState = LibraryScript.load_or_create()
	var source_wip: CraftedItemWIP = _find_saved_wip_by_project_name(
		source_library,
		TARGET_PROJECT_NAME
	)
	if source_wip == null:
		_fail("Star_Handle_Testing is absent from the real WIP library")
		_finish()
		return
	var requested_slots: Array[StringName] = _resolve_requested_primary_slots()
	for primary_slot_id: StringName in requested_slots:
		await _run_primary_slot_case(source_wip, primary_slot_id)
	_finish()


func _run_primary_slot_case(
	source_wip: CraftedItemWIP,
	primary_slot_id: StringName
) -> void:
	var support_slot_id: StringName = _opposite_slot(primary_slot_id)
	var case_label := "primary_%s" % String(primary_slot_id)
	print("CASE_BEGIN ", case_label)
	var diagnostic_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	_require(diagnostic_wip != null, "%s WIP duplicate failed" % case_label)
	if diagnostic_wip == null:
		return
	diagnostic_wip.wip_id = StringName(
		"%s_atomic_%s" % [String(source_wip.wip_id), String(primary_slot_id)]
	)
	# A new state guarantees that skill_slot_12 has no inherited authored grip
	# relationship and no stale execution-path cache from the source WIP.
	diagnostic_wip.combat_animation_station_state = StationStateScript.new()
	var library := LibraryScript.new() as PlayerForgeWipLibraryState
	library.save_file_path = TEMP_LIBRARY_SAVE_PATH
	library.saved_wips.clear()
	library.saved_wips.append(diagnostic_wip)
	library.selected_wip_id = diagnostic_wip.wip_id
	var fake_player := FakePlayer.new()
	fake_player.forge_wip_library_state = library
	root.add_child(fake_player)
	var ui := StationUIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake_player, "Primary/Support transaction atomicity")
	await _frames(2)
	var open_ok: bool = ui.open_saved_wip_with_hand_setup(
		diagnostic_wip.wip_id,
		primary_slot_id,
		false,
		false
	)
	await _frames(2)
	_require(open_ok, "%s WIP open failed" % case_label)
	var select_ok: bool = ui.select_skill_slot(FRESH_SKILL_SLOT_ID, true)
	await _frames(4)
	_require(select_ok, "%s fresh skill selection failed" % case_label)
	var selected_state: Dictionary = _resolve_preview_state(ui)
	_require(
		not selected_state.is_empty(),
		"%s preview disappeared after fresh skill selection" % case_label
	)
	if selected_state.is_empty():
		await _dispose_case(ui, fake_player)
		return
	var actor: Node3D = selected_state.get("actor", null) as Node3D
	var held_item: Node3D = selected_state.get("held_item", null) as Node3D
	var preview_root: Node3D = selected_state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = selected_state.get(
		"trajectory_root",
		null
	) as Node3D
	var motion_node: CombatAnimationMotionNode = ui.call(
		"_get_active_motion_node"
	) as CombatAnimationMotionNode
	_require(motion_node != null, "%s active motion node is absent" % case_label)
	if motion_node == null:
		await _dispose_case(ui, fake_player)
		return
	var fresh_primary_ready: bool = _verify_fresh_primary_acquisition(
		ui,
		actor,
		held_item,
		preview_root,
		trajectory_root,
		motion_node,
		primary_slot_id,
		support_slot_id,
		case_label,
		true
	)
	if not fresh_primary_ready:
		print("CASE_BLOCKED ", case_label, " reason=fresh_primary_not_current")
		await _dispose_case(ui, fake_player)
		return
	_verify_rejected_primary_transaction_rollback(
		ui,
		actor,
		held_item,
		preview_root,
		trajectory_root,
		motion_node,
		primary_slot_id,
		support_slot_id,
		case_label
	)
	# Explicit absent-path acquisition case. Skill selection is what creates the
	# actor/held-item graph, so clear its execution paths after the independent
	# support and rollback checks, then call the same Primary bootstrap used by a
	# relationship refresh at the already-valid authored Handle coordinate.
	actor.call("clear_finger_grip_target", primary_slot_id)
	actor.call("clear_finger_grip_target", support_slot_id)
	actor.call("set_support_hand_active", SLOT_RIGHT, false)
	actor.call("set_support_hand_active", SLOT_LEFT, false)
	var absent_path_lookup: Dictionary = _capture_active_path_lookup(
		actor,
		primary_slot_id
	)
	_require(
		not absent_path_lookup.has(primary_slot_id)
			and not absent_path_lookup.has(support_slot_id)
			and not bool(actor.call(
				"has_authoring_current_surface_grip",
				primary_slot_id
			)),
		"%s could not establish the absent active-path precondition" % case_label,
		var_to_str(absent_path_lookup)
	)
	var bootstrap_state := {
		"preview_root": preview_root,
		"actor_pivot": preview_root.get_node_or_null("PreviewActorPivot"),
		"trajectory_root": trajectory_root,
	}
	var bootstrap_playback: Dictionary = (
		preview_root.get_meta("resolved_playback_state", {}) as Dictionary
	).duplicate(true)
	bootstrap_playback["grip_resolve_reason"] = &"handle_position"
	var active_draft: Resource = ui.call("_get_active_draft") as Resource
	var absent_bootstrap: Dictionary = ui.preview_presenter.call(
		"_bootstrap_preview_primary_grip_relationship",
		bootstrap_state,
		motion_node,
		bootstrap_playback,
		1.0,
		active_draft,
		false
	) as Dictionary
	await _frames(2)
	_require(
		StringName(absent_bootstrap.get("disposition", StringName()))
			== &"committed",
		"%s absent-path Primary bootstrap did not commit" % case_label,
		_transaction_summary(absent_bootstrap)
	)
	_verify_fresh_primary_acquisition(
		ui,
		actor,
		held_item,
		preview_root,
		trajectory_root,
		motion_node,
		primary_slot_id,
		support_slot_id,
		"%s_absent_path" % case_label,
		false
	)
	await _verify_support_add_remove(
		ui,
		actor,
		held_item,
		preview_root,
		motion_node,
		primary_slot_id,
		support_slot_id,
		case_label
	)
	print("CASE_END ", case_label)
	await _dispose_case(ui, fake_player)


func _verify_fresh_primary_acquisition(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	held_item: Node3D,
	preview_root: Node3D,
	trajectory_root: Node3D,
	motion_node: CombatAnimationMotionNode,
	primary_slot_id: StringName,
	support_slot_id: StringName,
	case_label: String,
	verify_chain_handoff: bool
) -> bool:
	var transaction: Dictionary = preview_root.get_meta(
		"primary_surface_grip_transaction_result",
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
	var rotations: Dictionary = grasp.get("rotations", {}) as Dictionary
	var active_paths: Dictionary = _capture_active_path_lookup(
		actor,
		primary_slot_id
	)
	var expected_primary_path: StringName = (
		&"left_primary" if primary_slot_id == SLOT_LEFT else &"right_primary"
	)
	var rendered: Dictionary = _resolve_rendered_endpoints(
		held_item,
		trajectory_root
	)
	_require(
		bool(transaction.get("attempted", false))
			and bool(transaction.get("valid", false))
			and bool(transaction.get("applied", false))
			and bool(transaction.get("committed", false))
			and StringName(transaction.get("status", StringName()))
				== &"primary_surface_grip_transaction_committed"
			and StringName(transaction.get(
				"bootstrap_disposition",
				StringName()
			)) == &"committed",
		"%s fresh Primary transaction did not commit" % case_label,
		_transaction_summary(transaction)
	)
	_require(
		int(transaction.get("committed_packet_bone_count", 0))
			== EXPECTED_GRIP_PACKET_BONE_COUNT
			and rotations.size() == EXPECTED_GRIP_PACKET_BONE_COUNT,
		"%s fresh Primary transaction did not publish 15 bones" % case_label,
		"transaction=%d current=%d" % [
			int(transaction.get("committed_packet_bone_count", 0)),
			rotations.size(),
		]
	)
	_require(
		bool(seat.get("valid", false))
			and bool(actor.call(
				"has_authoring_current_surface_grip",
				primary_slot_id
			)),
		"%s fresh Primary seat/packet is not current" % case_label
	)
	_require(
		StringName(active_paths.get(primary_slot_id, StringName()))
			== expected_primary_path
			and not active_paths.has(support_slot_id),
		"%s fresh execution-path roles are wrong" % case_label,
		var_to_str(active_paths)
	)
	_require(
		int(seat.get("solve_count", -1))
			== int(transaction.get("committed_surface_seat_solve_count", -2))
			and int(grasp.get("solve_count", -1))
				== int(transaction.get("committed_grasp_solve_count", -2)),
		"%s performed geometry work after its committed Primary transaction"
			% case_label,
		"seat=%d/%d grasp=%d/%d" % [
			int(seat.get("solve_count", -1)),
			int(transaction.get("committed_surface_seat_solve_count", -2)),
			int(grasp.get("solve_count", -1)),
			int(transaction.get("committed_grasp_solve_count", -2)),
		]
	)
	_require(
		motion_node.tip_position_local == rendered.get("tip", Vector3.INF)
			and motion_node.pommel_position_local
				== rendered.get("pommel", Vector3.INF)
			and motion_node.tip_position_origin_id
				== OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
			and motion_node.pommel_position_origin_id
				== OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"%s fresh authored/rendered endpoint frame is not exact" % case_label,
		_endpoint_detail(motion_node, rendered)
	)
	_require(
		transaction.get("tip_position_local", Vector3.INF)
			== rendered.get("tip", Vector3.ZERO)
			and transaction.get("pommel_position_local", Vector3.INF)
				== rendered.get("pommel", Vector3.ZERO)
			and StringName(transaction.get(
				"tip_position_origin_id",
				StringName()
			)) == OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
			and StringName(transaction.get(
				"pommel_position_origin_id",
				StringName()
			)) == OriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
		"%s transaction endpoint authority differs from rendered WeaponRoot"
			% case_label
	)
	if verify_chain_handoff:
		_verify_fresh_chain_handoff(ui, case_label)
	return (
		bool(transaction.get("attempted", false))
		and bool(transaction.get("valid", false))
		and bool(transaction.get("applied", false))
		and bool(transaction.get("committed", false))
		and StringName(transaction.get("status", StringName()))
			== &"primary_surface_grip_transaction_committed"
		and bool(seat.get("valid", false))
		and bool(actor.call(
			"has_authoring_current_surface_grip",
			primary_slot_id
		))
		and rotations.size() == EXPECTED_GRIP_PACKET_BONE_COUNT
		and motion_node.tip_position_local == rendered.get("tip", Vector3.INF)
		and motion_node.pommel_position_local
			== rendered.get("pommel", Vector3.INF)
	)


func _verify_fresh_chain_handoff(
	ui: CombatAnimationStationUI,
	case_label: String
) -> void:
	var draft: Resource = ui.call("_get_active_draft") as Resource
	_require(draft != null, "%s fresh draft is absent" % case_label)
	if draft == null:
		return
	var chain: Array = draft.get("motion_node_chain") as Array
	_require(
		chain.size() >= 2,
		"%s fresh skill does not contain hidden-entry + visible nodes" % case_label,
		"chain_size=%d" % chain.size()
	)
	if chain.size() < 2:
		return
	var entry_node: CombatAnimationMotionNode = chain[0] as CombatAnimationMotionNode
	var visible_node: CombatAnimationMotionNode = chain[1] as CombatAnimationMotionNode
	_require(
		entry_node != null
			and visible_node != null
			and entry_node.tip_position_local == visible_node.tip_position_local
			and entry_node.tip_position_origin_id == visible_node.tip_position_origin_id
			and entry_node.pommel_position_local == visible_node.pommel_position_local
			and entry_node.pommel_position_origin_id
				== visible_node.pommel_position_origin_id,
		"%s fresh hidden/visible endpoint handoff is not bit-identical" % case_label,
		(
			"tip_mm=%f pommel_mm=%f entry_tip_origin=%s visible_tip_origin=%s "
			+ "entry_pommel_origin=%s visible_pommel_origin=%s"
		) % [
			entry_node.tip_position_local.distance_to(
				visible_node.tip_position_local
			) * 1000.0 if entry_node != null and visible_node != null else INF,
			entry_node.pommel_position_local.distance_to(
				visible_node.pommel_position_local
			) * 1000.0 if entry_node != null and visible_node != null else INF,
			String(entry_node.tip_position_origin_id) if entry_node != null else "",
			String(visible_node.tip_position_origin_id) if visible_node != null else "",
			String(entry_node.pommel_position_origin_id) if entry_node != null else "",
			String(visible_node.pommel_position_origin_id) if visible_node != null else "",
		]
	)


func _verify_support_add_remove(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	held_item: Node3D,
	preview_root: Node3D,
	motion_node: CombatAnimationMotionNode,
	primary_slot_id: StringName,
	support_slot_id: StringName,
	case_label: String
) -> void:
	# Configure the desired Support coordinate before entering 2H. This is test
	# setup only; the relationship-changing call under test remains the 1H -> 2H
	# transition and therefore must resolve Support exactly once at 0.5.
	motion_node.secondary_grip_seat_slide_offset = _resolve_support_test_coordinate()
	motion_node.normalize()
	var primary_baseline: Dictionary = _capture_primary_unit(
		actor,
		held_item,
		motion_node,
		primary_slot_id
	)
	var add_ok: bool = ui.set_selected_motion_node_two_hand_state(
		MotionNodeScript.TWO_HAND_STATE_TWO_HAND,
		false,
		false,
		false,
		true,
		false
	)
	_require(add_ok, "%s 1H -> 2H call was rejected" % case_label)
	_verify_primary_unit_exact(
		primary_baseline,
		_capture_primary_unit(actor, held_item, motion_node, primary_slot_id),
		"%s support-add immediate" % case_label
	)
	await _frames(2)
	_verify_primary_unit_exact(
		primary_baseline,
		_capture_primary_unit(actor, held_item, motion_node, primary_slot_id),
		"%s support-add settled" % case_label
	)
	var support_transaction: Dictionary = preview_root.get_meta(
		"support_grip_transaction_result",
		{}
	) as Dictionary
	var support_grasp: Dictionary = actor.call(
		"get_authoring_surface_grasp_debug_state",
		support_slot_id
	) as Dictionary
	var support_rotations: Dictionary = support_grasp.get(
		"rotations",
		{}
	) as Dictionary
	var paths_after_add: Dictionary = _capture_active_path_lookup(
		actor,
		primary_slot_id
	)
	var expected_support_path: StringName = (
		&"left_support" if support_slot_id == SLOT_LEFT else &"right_support"
	)
	var support_committed: bool = (
		bool(support_transaction.get("valid", false))
			and bool(support_transaction.get("applied", false))
			and bool(support_transaction.get("committed", false))
			and StringName(support_transaction.get("status", StringName()))
				== &"support_surface_grip_transaction_committed"
	)
	_require(
		support_committed,
		"%s Support acquisition did not commit" % case_label,
		_transaction_summary(support_transaction)
	)
	_require(
		bool(actor.call("is_support_hand_active", support_slot_id))
			and bool(actor.call(
				"has_authoring_current_surface_grip",
				support_slot_id
			))
			and support_rotations.size() == EXPECTED_GRIP_PACKET_BONE_COUNT
			and StringName(paths_after_add.get(
				support_slot_id,
				StringName()
			)) == expected_support_path,
		"%s Support role/current 15-bone packet is invalid" % case_label,
		"paths=%s rotations=%d" % [
			var_to_str(paths_after_add),
			support_rotations.size(),
		]
	)
	if not support_committed:
		print(
			"CASE_BLOCKED ",
			case_label,
			" phase=support_remove reason=support_add_not_committed"
		)
		return
	var remove_ok: bool = ui.set_selected_motion_node_two_hand_state(
		MotionNodeScript.TWO_HAND_STATE_ONE_HAND,
		false,
		false,
		false,
		true,
		false
	)
	_require(remove_ok, "%s 2H -> 1H call was rejected" % case_label)
	_verify_primary_unit_exact(
		primary_baseline,
		_capture_primary_unit(actor, held_item, motion_node, primary_slot_id),
		"%s support-remove immediate" % case_label
	)
	await _frames(2)
	_verify_primary_unit_exact(
		primary_baseline,
		_capture_primary_unit(actor, held_item, motion_node, primary_slot_id),
		"%s support-remove settled" % case_label
	)
	var paths_after_remove: Dictionary = _capture_active_path_lookup(
		actor,
		primary_slot_id
	)
	_require(
		not bool(actor.call("is_support_hand_active", support_slot_id))
			and not bool(actor.call(
				"has_authoring_current_surface_grip",
				support_slot_id
			))
			and not paths_after_remove.has(support_slot_id),
		"%s Support state/path survived 2H -> 1H" % case_label,
		var_to_str(paths_after_remove)
	)


func _verify_rejected_primary_transaction_rollback(
	ui: CombatAnimationStationUI,
	actor: Node3D,
	held_item: Node3D,
	preview_root: Node3D,
	trajectory_root: Node3D,
	motion_node: CombatAnimationMotionNode,
	primary_slot_id: StringName,
	support_slot_id: StringName,
	case_label: String
) -> void:
	var presenter: Object = ui.preview_presenter
	var primary_guide: Node3D = held_item.get_node_or_null(
		"PrimaryGripGuide"
	) as Node3D
	var primary_anchor: Node3D = held_item.find_child(
		"PrimaryGripAnchor",
		true,
		false
	) as Node3D
	_require(
		presenter != null
			and primary_guide != null
			and primary_anchor != null,
		"%s rollback test contract is unavailable" % case_label
	)
	if presenter == null or primary_guide == null or primary_anchor == null:
		return
	var playback_state: Dictionary = (
		preview_root.get_meta("resolved_playback_state", {}) as Dictionary
	).duplicate(true)
	var actor_transaction_before: Dictionary = actor.call(
		"capture_authoring_active_grip_transaction_state",
		primary_slot_id
	) as Dictionary
	var primary_pose_before: Dictionary = _capture_primary_pose(
		actor,
		primary_slot_id
	)
	var weapon_transform_before: Transform3D = held_item.global_transform
	var held_meta_before: Dictionary = _capture_all_meta(held_item)
	var actor_meta_before: Dictionary = _capture_all_meta(actor)
	var preview_meta_before: Dictionary = _capture_all_meta(
		preview_root,
		[&"primary_surface_grip_transaction_result"]
	)
	var contact_tree_before: Dictionary = _capture_contact_trees(held_item)
	var tip_before: Vector3 = motion_node.tip_position_local
	var tip_origin_before: StringName = motion_node.tip_position_origin_id
	var pommel_before: Vector3 = motion_node.pommel_position_local
	var pommel_origin_before: StringName = motion_node.pommel_position_origin_id
	var playback_before: Dictionary = playback_state.duplicate(true)
	var transaction_snapshot: Dictionary = presenter.call(
		"_capture_preview_primary_grip_transaction_snapshot",
		preview_root,
		actor,
		held_item,
		primary_guide,
		primary_anchor,
		primary_slot_id,
		motion_node,
		playback_state
	) as Dictionary
	_require(
		bool(transaction_snapshot.get("valid", false)),
		"%s could not capture the rollback transaction snapshot" % case_label
	)
	if not bool(transaction_snapshot.get("valid", false)):
		return
	# Deterministic test-only fault after the snapshot boundary. The first change
	# hits the existing support-active gate; the second proves held-item metadata is
	# restored even when it was not the rejection cause.
	actor.call("set_support_hand_active", support_slot_id, true)
	held_item.set_meta("weapon_tip_origin_id", &"InjectedInvalidOrigin")
	var rejection: Dictionary = presenter.call(
		"_acquire_preview_primary_surface_grip_transaction",
		preview_root,
		actor,
		held_item,
		trajectory_root,
		motion_node,
		playback_state,
		transaction_snapshot
	) as Dictionary
	var actor_transaction_after: Dictionary = actor.call(
		"capture_authoring_active_grip_transaction_state",
		primary_slot_id
	) as Dictionary
	_require(
		bool(rejection.get("attempted", false))
			and not bool(rejection.get("valid", true))
			and not bool(rejection.get("applied", true))
			and not bool(rejection.get("committed", true))
			and bool(rejection.get("rollback_succeeded", false))
			and StringName(rejection.get("status", StringName()))
				== &"primary_surface_grip_support_active_at_entry",
		"%s injected rejection did not report a successful rollback" % case_label,
		_transaction_summary(rejection)
	)
	_require(
		not rejection.has("tip_position_local")
			and not rejection.has("tip_position_origin_id")
			and not rejection.has("pommel_position_local")
			and not rejection.has("pommel_position_origin_id"),
		"%s rejected transaction leaked endpoint authority" % case_label
	)
	_require(
		actor_transaction_after == actor_transaction_before,
		"%s rollback did not restore the full rig/presenter transaction state"
			% case_label,
		_dictionary_difference_summary(
			actor_transaction_before,
			actor_transaction_after
		)
	)
	_require(
		_capture_primary_pose(actor, primary_slot_id) == primary_pose_before,
		"%s rollback did not restore Primary limb/digit poses exactly" % case_label
	)
	_require(
		held_item.global_transform == weapon_transform_before,
		"%s rollback did not restore WeaponRoot exactly" % case_label,
		_transform_delta_detail(weapon_transform_before, held_item.global_transform)
	)
	_require(
		_capture_all_meta(held_item) == held_meta_before,
		"%s rollback did not restore all held-item metadata" % case_label
	)
	_require(
		_capture_all_meta(actor) == actor_meta_before,
		"%s rollback did not restore all actor metadata" % case_label
	)
	_require(
		_capture_all_meta(
			preview_root,
			[&"primary_surface_grip_transaction_result"]
		) == preview_meta_before,
		"%s rollback changed preview metadata outside its rejection result"
			% case_label
	)
	_require(
		_capture_contact_trees(held_item) == contact_tree_before,
		"%s rollback did not restore Primary/Support contact trees" % case_label
	)
	_require(
		motion_node.tip_position_local == tip_before
			and motion_node.tip_position_origin_id == tip_origin_before
			and motion_node.pommel_position_local == pommel_before
			and motion_node.pommel_position_origin_id == pommel_origin_before,
		"%s rollback changed authored endpoint fields" % case_label
	)
	_require(
		playback_state == playback_before,
		"%s rollback changed supplied playback state" % case_label
	)
	_require(
		not bool(actor.call("is_support_hand_active", support_slot_id))
			and bool(actor.call(
				"has_authoring_current_surface_grip",
				primary_slot_id
			)),
		"%s rollback did not restore 1H Primary/Support authority" % case_label
	)


func _capture_primary_unit(
	actor: Node3D,
	held_item: Node3D,
	motion_node: CombatAnimationMotionNode,
	primary_slot_id: StringName
) -> Dictionary:
	return {
		"weapon_transform": held_item.global_transform,
		"primary_pose": _capture_primary_pose(actor, primary_slot_id),
		"primary_seat": actor.call(
			"get_authoring_current_weapon_surface_seat",
			primary_slot_id
		) as Dictionary,
		"primary_grasp": actor.call(
			"get_authoring_surface_grasp_debug_state",
			primary_slot_id
		) as Dictionary,
		"tip": motion_node.tip_position_local,
		"tip_origin": motion_node.tip_position_origin_id,
		"pommel": motion_node.pommel_position_local,
		"pommel_origin": motion_node.pommel_position_origin_id,
	}


func _verify_primary_unit_exact(
	baseline: Dictionary,
	current: Dictionary,
	label: String
) -> void:
	var baseline_weapon: Transform3D = baseline.get(
		"weapon_transform",
		Transform3D.IDENTITY
	) as Transform3D
	var current_weapon: Transform3D = current.get(
		"weapon_transform",
		Transform3D.IDENTITY
	) as Transform3D
	_require(
		current_weapon == baseline_weapon,
		"%s moved WeaponRoot" % label,
		_transform_delta_detail(baseline_weapon, current_weapon)
	)
	_require(
		current.get("primary_pose", {}) == baseline.get("primary_pose", {}),
		"%s changed Primary limb/digit poses" % label,
		_pose_difference_summary(
			baseline.get("primary_pose", {}) as Dictionary,
			current.get("primary_pose", {}) as Dictionary
		)
	)
	_require(
		current.get("primary_seat", {}) == baseline.get("primary_seat", {}),
		"%s changed/re-queried the Primary seat packet" % label
	)
	_require(
		current.get("primary_grasp", {}) == baseline.get("primary_grasp", {}),
		"%s changed/re-solved the Primary digit packet" % label
	)
	_require(
		current.get("tip", Vector3.INF) == baseline.get("tip", Vector3.ZERO)
			and current.get("tip_origin", StringName())
				== baseline.get("tip_origin", StringName())
			and current.get("pommel", Vector3.INF)
				== baseline.get("pommel", Vector3.ZERO)
			and current.get("pommel_origin", StringName())
				== baseline.get("pommel_origin", StringName()),
		"%s changed authored Tip/Pommel authority" % label
	)


func _capture_primary_pose(
	actor: Node3D,
	primary_slot_id: StringName
) -> Dictionary:
	var bone_names: Array[StringName] = (
		LEFT_PRIMARY_BONES if primary_slot_id == SLOT_LEFT else RIGHT_PRIMARY_BONES
	)
	return actor.call(
		"capture_runtime_upper_body_pose_frame",
		bone_names
	) as Dictionary


func _capture_active_path_lookup(
	actor: Node3D,
	primary_slot_id: StringName
) -> Dictionary:
	var snapshot: Dictionary = actor.call(
		"capture_authoring_active_grip_transaction_state",
		primary_slot_id
	) as Dictionary
	var finger_snapshot: Dictionary = snapshot.get(
		"finger_grip_snapshot",
		{}
	) as Dictionary
	return (
		finger_snapshot.get("active_grip_execution_path_lookup", {}) as Dictionary
	).duplicate(true)


func _capture_contact_trees(held_item: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for root_name: String in [
		"PrimaryGripGuide",
		"PrimaryGripAnchor",
		"SecondaryGripGuide",
		"SecondaryGripAnchor",
	]:
		var contact_root: Node = held_item.find_child(root_name, true, false)
		if contact_root != null:
			_capture_contact_tree_node(held_item, contact_root, result)
	return result


func _capture_contact_tree_node(
	held_item: Node3D,
	node: Node,
	result: Dictionary
) -> void:
	var relative_path: String = String(held_item.get_path_to(node))
	result[relative_path] = {
		"instance_id": node.get_instance_id(),
		"transform": (
			(node as Node3D).transform if node is Node3D else Transform3D.IDENTITY
		),
		"meta": _capture_all_meta(node),
	}
	for child: Node in node.get_children():
		_capture_contact_tree_node(held_item, child, result)


func _capture_all_meta(
	node: Object,
	excluded_keys: Array[StringName] = []
) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in node.get_meta_list():
		var key: StringName = StringName(key_variant)
		if key in excluded_keys:
			continue
		result[key] = node.get_meta(key)
	return result.duplicate(true)


func _resolve_preview_state(ui: CombatAnimationStationUI) -> Dictionary:
	var preview_root: Node3D = ui.preview_subviewport.get_node_or_null(
		"CombatAnimationPreviewRoot3D"
	) as Node3D
	if preview_root == null:
		return {}
	var actor: Node3D = preview_root.get_node_or_null(
		"PreviewActorPivot/PreviewActor"
	) as Node3D
	var held_item: Node3D = preview_root.get_meta(
		"preview_held_item",
		null
	) as Node3D
	var trajectory_root: Node3D = preview_root.find_child(
		"TrajectoryRoot",
		true,
		false
	) as Node3D
	if actor == null or held_item == null or trajectory_root == null:
		return {}
	return {
		"preview_root": preview_root,
		"actor": actor,
		"held_item": held_item,
		"trajectory_root": trajectory_root,
	}


func _resolve_rendered_endpoints(
	held_item: Node3D,
	trajectory_root: Node3D
) -> Dictionary:
	var local_tip_variant: Variant = held_item.get_meta("weapon_tip_local", null)
	var local_pommel_variant: Variant = held_item.get_meta(
		"weapon_pommel_local",
		null
	)
	if local_tip_variant is not Vector3 or local_pommel_variant is not Vector3:
		return {}
	return {
		"tip": trajectory_root.to_local(held_item.to_global(
			local_tip_variant as Vector3
		)),
		"pommel": trajectory_root.to_local(held_item.to_global(
			local_pommel_variant as Vector3
		)),
	}


func _endpoint_detail(
	motion_node: CombatAnimationMotionNode,
	rendered: Dictionary
) -> String:
	return "tip_mm=%f pommel_mm=%f" % [
		motion_node.tip_position_local.distance_to(
			rendered.get("tip", Vector3.INF) as Vector3
		) * 1000.0,
		motion_node.pommel_position_local.distance_to(
			rendered.get("pommel", Vector3.INF) as Vector3
		) * 1000.0,
	]


func _transform_delta_detail(
	baseline: Transform3D,
	current: Transform3D
) -> String:
	var delta: Transform3D = baseline.affine_inverse() * current
	var angle_radians: float = delta.basis.orthonormalized().get_rotation_quaternion().get_angle()
	angle_radians = minf(angle_radians, TAU - angle_radians)
	return "position_mm=%f rotation_deg=%f" % [
		delta.origin.length() * 1000.0,
		rad_to_deg(angle_radians),
	]


func _transaction_summary(result: Dictionary) -> String:
	return (
		"status=%s disposition=%s attempted=%s valid=%s applied=%s "
		+ "committed=%s rollback=%s packet=%d corrections=%d"
	) % [
		String(result.get("status", StringName())),
		String(result.get("disposition", result.get(
			"bootstrap_disposition",
			StringName()
		))),
		str(bool(result.get("attempted", false))),
		str(bool(result.get("valid", false))),
		str(bool(result.get("applied", false))),
		str(bool(result.get("committed", false))),
		str(bool(result.get("rollback_succeeded", false))),
		int(result.get("committed_packet_bone_count", -1)),
		int(result.get("applied_correction_count", -1)),
	]


func _dictionary_difference_summary(
	baseline: Dictionary,
	current: Dictionary
) -> String:
	var keys: Array = baseline.keys()
	for current_key: Variant in current.keys():
		if current_key not in keys:
			keys.append(current_key)
	var differing: PackedStringArray = []
	for key: Variant in keys:
		var baseline_has: bool = baseline.has(key)
		var current_has: bool = current.has(key)
		if (
			baseline_has != current_has
			or (
				baseline_has
				and current_has
				and baseline.get(key) != current.get(key)
			)
		):
			differing.append(String(key))
	return "different_top_level_keys=[%s]" % ", ".join(differing)


func _pose_difference_summary(
	baseline: Dictionary,
	current: Dictionary
) -> String:
	var baseline_names: Array = baseline.get("bone_names", []) as Array
	var current_names: Array = current.get("bone_names", []) as Array
	if baseline_names != current_names:
		return "bone_names_changed baseline=%s current=%s" % [
			str(baseline_names),
			str(current_names),
		]
	var baseline_positions: PackedVector3Array = baseline.get(
		"pose_positions",
		PackedVector3Array()
	) as PackedVector3Array
	var current_positions: PackedVector3Array = current.get(
		"pose_positions",
		PackedVector3Array()
	) as PackedVector3Array
	var baseline_rotations: PackedVector4Array = baseline.get(
		"pose_rotations",
		PackedVector4Array()
	) as PackedVector4Array
	var current_rotations: PackedVector4Array = current.get(
		"pose_rotations",
		PackedVector4Array()
	) as PackedVector4Array
	var baseline_scales: PackedVector3Array = baseline.get(
		"pose_scales",
		PackedVector3Array()
	) as PackedVector3Array
	var current_scales: PackedVector3Array = current.get(
		"pose_scales",
		PackedVector3Array()
	) as PackedVector3Array
	var changed: PackedStringArray = []
	var count: int = mini(
		baseline_names.size(),
		mini(
			baseline_positions.size(),
			mini(baseline_rotations.size(), baseline_scales.size())
		)
	)
	count = mini(
		count,
		mini(
			current_positions.size(),
			mini(current_rotations.size(), current_scales.size())
		)
	)
	for index: int in range(count):
		if (
			baseline_positions[index] == current_positions[index]
			and baseline_rotations[index] == current_rotations[index]
			and baseline_scales[index] == current_scales[index]
		):
			continue
		var before_rotation: Vector4 = baseline_rotations[index]
		var after_rotation: Vector4 = current_rotations[index]
		var before_quaternion := Quaternion(
			before_rotation.x,
			before_rotation.y,
			before_rotation.z,
			before_rotation.w
		).normalized()
		var after_quaternion := Quaternion(
			after_rotation.x,
			after_rotation.y,
			after_rotation.z,
			after_rotation.w
		).normalized()
		var delta_angle: float = before_quaternion.angle_to(after_quaternion)
		var rotation_component_delta: float = maxf(
			absf(before_rotation.x - after_rotation.x),
			maxf(
				absf(before_rotation.y - after_rotation.y),
				maxf(
					absf(before_rotation.z - after_rotation.z),
					absf(before_rotation.w - after_rotation.w)
				)
			)
		)
		changed.append("%s(pos_mm=%.9g rot_deg=%.9g rot_component=%.9g scale=%.9g)" % [
			String(baseline_names[index]),
			baseline_positions[index].distance_to(current_positions[index]) * 1000.0,
			rad_to_deg(delta_angle),
			rotation_component_delta,
			baseline_scales[index].distance_to(current_scales[index]),
		])
		if changed.size() >= 12:
			break
	return "changed=[%s]" % ", ".join(changed)


func _find_saved_wip_by_project_name(
	library: PlayerForgeWipLibraryState,
	project_name: String
) -> CraftedItemWIP:
	if library == null:
		return null
	for saved_wip: CraftedItemWIP in library.get_saved_wips():
		if saved_wip != null and saved_wip.forge_project_name == project_name:
			return saved_wip
	return null


func _resolve_requested_primary_slots() -> Array[StringName]:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("right"):
		return [SLOT_RIGHT]
	if args.has("left"):
		return [SLOT_LEFT]
	return [SLOT_RIGHT, SLOT_LEFT]


func _resolve_support_test_coordinate() -> float:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("coord="):
			return clampf(float(argument.trim_prefix("coord=")), 0.0, 1.0)
	return SUPPORT_TEST_HANDLE_COORDINATE


func _opposite_slot(slot_id: StringName) -> StringName:
	return SLOT_RIGHT if slot_id == SLOT_LEFT else SLOT_LEFT


func _dispose_case(ui: Node, fake_player: Node) -> void:
	ui.queue_free()
	fake_player.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for _frame_index: int in range(count):
		await process_frame


func _require(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		return
	var failure: String = label
	if not detail.is_empty():
		failure = "%s (%s)" % [label, detail]
	_fail(failure)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("ASSERT: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("PRIMARY_SUPPORT_TRANSACTION_ATOMICITY=PASS")
		quit(0)
		return
	push_error(
		"PRIMARY_SUPPORT_TRANSACTION_ATOMICITY=FAIL count=%d [%s]" % [
			failures.size(),
			"; ".join(failures),
		]
	)
	quit(1)
