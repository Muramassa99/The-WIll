extends SceneTree

const LibraryScript = preload("res://core/models/player_forge_wip_library_state.gd")
const StationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const UIScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")

const TARGET_PROJECT_NAME := "Star_Handle_Testing"
const TARGET_SLOT_ID: StringName = &"skill_slot_12"

var failed: bool = false


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
	_require(source_wip != null, "target WIP unavailable")
	if source_wip == null:
		quit(1)
		return
	var wip := source_wip.duplicate(true) as CraftedItemWIP
	wip.combat_animation_station_state = StationStateScript.new()
	var library := LibraryScript.new() as PlayerForgeWipLibraryState
	library.save_file_path = (
		"C:/WORKSPACE/test_artifacts/"
		+ "verify_fresh_skill_entry_semantic_gate_library.tres"
	)
	library.saved_wips.append(wip)
	library.selected_wip_id = wip.wip_id
	var fake := FakePlayer.new()
	fake.forge_wip_library_state = library
	root.add_child(fake)
	var ui := UIScene.instantiate() as CombatAnimationStationUI
	ui.set_meta("verification_skip_persistence", true)
	root.add_child(ui)
	await _frames(2)
	ui.open_for(fake, "Fresh entry semantic-gate verifier")
	await _frames(2)
	_require(
		ui.open_saved_wip_with_hand_setup(wip.wip_id, &"hand_right", false, false),
		"WIP open failed"
	)
	await _frames(2)
	var draft: Resource = ui.call("_find_skill_draft_by_slot_id", TARGET_SLOT_ID) as Resource
	_require(draft != null, "target draft unavailable")
	if draft == null:
		quit(1)
		return
	_require(
		bool(ui.call("_draft_matches_raw_weapon_geometry_baseline", draft)),
		"untouched eagerly-created draft was not recognized as raw baseline"
	)
	var chain: Array = draft.get("motion_node_chain") as Array
	_require(chain.size() == 2, "raw skill topology is not the hidden/visible pair")
	if chain.size() != 2:
		quit(1)
		return
	var node_0 := chain[0] as CombatAnimationMotionNode
	var node_1 := chain[1] as CombatAnimationMotionNode
	_require(node_0 != null and node_1 != null, "raw skill nodes unavailable")
	if node_0 == null or node_1 == null:
		quit(1)
		return
	# Deliberately author fields that the historical endpoint-only predicate did
	# not cover. Selection must preserve this chain instead of treating it as fresh.
	node_0.tip_curve_out_handle = Vector3(0.031, -0.017, 0.009)
	node_1.transition_duration_seconds = 0.37
	draft.set("speed_acceleration_percent", 61.0)
	var node_0_id: int = node_0.get_instance_id()
	var node_1_id: int = node_1.get_instance_id()
	var node_0_tip: Vector3 = node_0.tip_position_local
	var node_0_pommel: Vector3 = node_0.pommel_position_local
	var node_1_tip: Vector3 = node_1.tip_position_local
	var node_1_pommel: Vector3 = node_1.pommel_position_local
	print(
		"BEFORE ids=", draft.get("owning_skill_id"), "/", draft.get("legal_slot_id"),
		" node0=", node_0_tip, "/", node_0_pommel,
		" node1=", node_1_tip, "/", node_1_pommel
	)
	_require(
		not bool(ui.call("_draft_matches_raw_weapon_geometry_baseline", draft)),
		"authored draft still passed raw-baseline identity"
	)
	var preview_root: Node3D = ui.call("_get_preview_root") as Node3D
	if preview_root != null and preview_root.has_meta("skill_entry_primary_grip_preseed_result"):
		preview_root.remove_meta("skill_entry_primary_grip_preseed_result")
	_require(ui.select_skill_slot(TARGET_SLOT_ID, true), "authored draft selection failed")
	await _frames(2)
	var selected_draft: Resource = ui.call("_get_active_draft") as Resource
	var selected_chain: Array = selected_draft.get("motion_node_chain") as Array
	var selected_node_0 := selected_chain[0] as CombatAnimationMotionNode
	var selected_node_1 := selected_chain[1] as CombatAnimationMotionNode
	print(
		"AFTER same_draft=", selected_draft == draft,
		" ids=", selected_draft.get("owning_skill_id"), "/", selected_draft.get("legal_slot_id"),
		" node0=", selected_node_0.tip_position_local, "/", selected_node_0.pommel_position_local,
		" node1=", selected_node_1.tip_position_local, "/", selected_node_1.pommel_position_local
	)
	_require(selected_node_0.get_instance_id() == node_0_id, "authored hidden node was replaced")
	_require(selected_node_1.get_instance_id() == node_1_id, "authored visible node was replaced")
	_require(selected_node_0.tip_position_local == node_0_tip, "authored hidden Tip moved")
	_require(selected_node_0.pommel_position_local == node_0_pommel, "authored hidden Pommel moved")
	# The existing ordinary selection transaction may reseat the selected visible
	# node under its fixed-Primary weapon authority. That is not fresh-entry
	# flattening; the fresh gate must preserve topology and the user's unrelated
	# authored fields, and must not copy that result back across the pair.
	_require(
		selected_node_0.tip_curve_out_handle == Vector3(0.031, -0.017, 0.009),
		"authored curve was flattened"
	)
	_require(
		is_equal_approx(selected_node_1.transition_duration_seconds, 0.37),
		"authored transition timing was flattened"
	)
	_require(
		is_equal_approx(float(selected_draft.get("speed_acceleration_percent")), 61.0),
		"authored draft timing was flattened"
	)
	preview_root = ui.call("_get_preview_root") as Node3D
	_require(
		preview_root == null
			or not preview_root.has_meta("skill_entry_primary_grip_preseed_result"),
		"authored draft incorrectly entered fresh-entry handoff"
	)
	if not failed:
		print("FRESH_SKILL_ENTRY_SEMANTIC_GATE=PASS")
	quit(1 if failed else 0)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("ASSERT: %s" % message)
