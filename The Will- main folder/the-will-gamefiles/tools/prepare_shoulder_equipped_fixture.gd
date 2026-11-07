extends "res://tools/verify_skill_grip_reopen.gd"

## Isolated fixture prerequisite: prepare Combat Idle through its own SC page.
## This neither bundles idle with Skill Save nor edits/fabricates Skill 3 data.
## --phase=write --input=<isolated_R_library.tres> --weapon=Broken_Balde_v1
## --hands=R --slot=skill_slot_3 --out=<fresh C:/WORKSPACE/godot_runs directory>

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	var source := ResourceLoader.load(String(allocation_report.source), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	var source_item: CraftedItemWIP
	if source != null:
		for item: CraftedItemWIP in source.saved_wips:
			if item.wip_id == ui.active_wip.wip_id:
				source_item = item
				break
	var expected := _fixture_skill3_stamp(source_item)
	allocation_report["skill3_source_stamp"] = expected
	_check_allocation(not expected.is_empty(), "fixture_source_has_skill3")
	if expected.is_empty(): return
	_check_allocation(_fixture_skill3_stamp(ui.active_wip) == expected, "opening_preserves_skill3")
	var mode_selected := ui.select_authoring_mode(&"author_idle")
	var draft_selected := ui.select_draft(&"idle_combat", true)
	_check_allocation(mode_selected and draft_selected, "combat_idle_selected_through_own_UI")
	if not mode_selected or not draft_selected: return
	var reset := ui.reset_active_draft_to_baseline()
	_check_allocation(reset, "combat_idle_Reset_through_UI")
	if not reset: return
	var ready := await _await_recorded_reset_baseline(ui)
	_check_allocation(ready.get("ready", false), "combat_idle_normal_acquisition_recorded", ready)
	if not ready.get("ready", false): return
	var bound := await _reopen_await_bound(ui, side)
	_check_allocation(bound.ready, "combat_idle_has_live_grip_binding", bound)
	if not bound.ready: return
	await _reopen_capture(ui)
	await _reopen_save(ui)
	allocation_report["skill3_live_stamp_after_idle_Save"] = _fixture_skill3_stamp(ui.active_wip)
	_check_allocation(_fixture_skill3_stamp(ui.active_wip) == expected, "idle_preparation_does_not_change_live_skill3")
	var disk := ResourceLoader.load(ui.active_wip_library.save_file_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PlayerForgeWipLibraryState
	_check_allocation(disk != null, "isolated_fixture_reloads_from_disk")
	if disk == null: return
	var saved_item: CraftedItemWIP
	for item: CraftedItemWIP in disk.saved_wips:
		if item.wip_id == ui.active_wip.wip_id:
			saved_item = item
			break
	var actual := _fixture_skill3_stamp(saved_item)
	allocation_report["skill3_disk_stamp_after_idle_Save"] = actual
	_check_allocation(actual == expected, "idle_Save_preserves_skill3_authored_content_and_node_packets")
	var idle: CombatAnimationDraft
	if saved_item != null and saved_item.combat_animation_station_state != null:
		for draft: CombatAnimationDraft in saved_item.combat_animation_station_state.idle_drafts:
			if draft.context_id == &"idle_combat": idle = draft
	_check_allocation(idle != null, "isolated_combat_idle_saved")
	if idle == null: return
	var nodes := idle.get_action_motion_node_chain()
	var packets_present := not nodes.is_empty()
	for node: CombatAnimationMotionNode in nodes: packets_present = packets_present and _reopen_has_packet(node)
	_check_allocation(packets_present and idle.baked_runtime_clip != null, "saved_idle_contains_acquired_grip_and_runtime_clip",
		{"nodes": nodes.size(), "runtime_clip": idle.baked_runtime_clip != null})
	allocation_report["scope"] = "Independent Combat Idle Reset/acquisition/Save in isolated library; Skill 3 unchanged; prerequisite for equipped replay verification."

func _fixture_skill3_stamp(item: CraftedItemWIP) -> Dictionary:
	if item == null or item.combat_animation_station_state == null: return {}
	for draft: CombatAnimationDraft in item.combat_animation_station_state.skill_drafts:
		if draft.legal_slot_id != &"skill_slot_3": continue
		var packets: Array = []
		for node: CombatAnimationMotionNode in draft.get_action_motion_node_chain():
			packets.append([node.prepared_pose_signature, node.prepared_pose])
		return {"authored_content_signature": draft.get_saved_content_signature(), "visible_nodes": packets.size(),
			"node_packet_sha256": var_to_bytes(packets).hex_encode().sha256_text()}
	return {}
