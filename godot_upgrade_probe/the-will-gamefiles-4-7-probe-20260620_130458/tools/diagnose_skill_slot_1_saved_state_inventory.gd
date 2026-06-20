extends SceneTree

const PlayerForgeWipLibraryStateScript = preload("res://core/models/player_forge_wip_library_state.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/DEBUG-LOGS/skill_slot_1_saved_state_inventory_2026-05-10.log"
const TARGET_SLOT_ID: StringName = &"skill_slot_1"

var lines: PackedStringArray = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_FILE_PATH.get_base_dir())
	var library_state: PlayerForgeWipLibraryState = PlayerForgeWipLibraryStateScript.load_or_create()
	var skill_slot_state: PlayerSkillSlotState = PlayerSkillSlotStateScript.load_or_create()
	lines.append("diagnostic=skill_slot_1_saved_state_inventory")
	lines.append("library_loaded=%s" % str(library_state != null))
	lines.append("skill_slot_state_loaded=%s" % str(skill_slot_state != null))
	if skill_slot_state != null:
		var assignment: Resource = skill_slot_state.get_slot_assignment(TARGET_SLOT_ID)
		lines.append("assignment_exists=%s" % str(assignment != null))
		if assignment != null:
			lines.append("assignment_source_weapon_wip_id=%s" % str(assignment.get("source_weapon_wip_id")))
			lines.append("assignment_source_skill_id=%s" % str(assignment.get("source_skill_id")))
	if library_state == null:
		_write()
		quit()
		return
	lines.append("selected_wip_id=%s" % String(library_state.selected_wip_id))
	var saved_wips: Array[CraftedItemWIP] = library_state.get_saved_wips()
	lines.append("saved_wip_count=%d" % saved_wips.size())
	for wip_index: int in range(saved_wips.size()):
		var saved_wip: CraftedItemWIP = saved_wips[wip_index]
		if saved_wip == null:
			continue
		saved_wip.ensure_combat_animation_station_state()
		lines.append("")
		lines.append("[wip_%d]" % wip_index)
		lines.append("wip_%d_id=%s" % [wip_index, String(saved_wip.wip_id)])
		lines.append("wip_%d_name=%s" % [wip_index, saved_wip.forge_project_name])
		var station_state: Resource = saved_wip.combat_animation_station_state
		if station_state == null:
			lines.append("wip_%d_station_state=false" % wip_index)
			continue
		var skill_drafts: Array = station_state.get("skill_drafts") as Array
		lines.append("wip_%d_skill_draft_count=%d" % [wip_index, skill_drafts.size()])
		for draft_index: int in range(skill_drafts.size()):
			var draft: CombatAnimationDraft = skill_drafts[draft_index] as CombatAnimationDraft
			if draft == null:
				continue
			if StringName(draft.owning_skill_id) != TARGET_SLOT_ID and StringName(draft.legal_slot_id) != TARGET_SLOT_ID:
				continue
			lines.append("wip_%d_slot_draft_%d_id=%s" % [wip_index, draft_index, String(draft.draft_id)])
			lines.append("wip_%d_slot_draft_%d_display=%s" % [wip_index, draft_index, draft.display_name])
			lines.append("wip_%d_slot_draft_%d_owning=%s" % [wip_index, draft_index, String(draft.owning_skill_id)])
			lines.append("wip_%d_slot_draft_%d_legal=%s" % [wip_index, draft_index, String(draft.legal_slot_id)])
			lines.append("wip_%d_slot_draft_%d_selected=%d" % [wip_index, draft_index, draft.selected_motion_node_index])
			lines.append("wip_%d_slot_draft_%d_node_count=%d" % [wip_index, draft_index, draft.motion_node_chain.size()])
			for node_index: int in range(draft.motion_node_chain.size()):
				var motion_node: CombatAnimationMotionNode = draft.motion_node_chain[node_index] as CombatAnimationMotionNode
				if motion_node == null:
					continue
				lines.append("wip_%d_slot_draft_%d_node_%d id=%s selected=%s two_hand=%s primary=%s grip=%s tip=%s pommel=%s right_upper=%.3f left_upper=%.3f" % [
					wip_index,
					draft_index,
					node_index,
					String(motion_node.node_id),
					str(node_index == draft.selected_motion_node_index),
					String(motion_node.two_hand_state),
					String(motion_node.primary_hand_slot),
					String(motion_node.preferred_grip_style_mode),
					_fmt_vec(motion_node.tip_position_local),
					_fmt_vec(motion_node.pommel_position_local),
					motion_node.right_upperarm_roll_degrees,
					motion_node.left_upperarm_roll_degrees,
				])
	_write()
	quit()

func _fmt_vec(value: Vector3) -> String:
	return "(%.6f, %.6f, %.6f)" % [value.x, value.y, value.z]

func _write() -> void:
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
