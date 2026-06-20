extends Resource
class_name PlayerSkillSlotState

const PersistentResourceStateIOScript = preload("res://core/models/persistent_resource_state_io.gd")
const DEFAULT_SAVE_FILE_PATH := "user://skills/player_skill_slot_state.tres"

const SKILL_SLOT_IDS: Array[StringName] = [
	&"skill_slot_1",
	&"skill_slot_2",
	&"skill_slot_3",
	&"skill_slot_4",
	&"skill_slot_5",
	&"skill_slot_6",
	&"skill_slot_7",
	&"skill_slot_8",
	&"skill_slot_9",
	&"skill_slot_10",
	&"skill_slot_11",
	&"skill_slot_12",
]

const BLOCK_SLOT_ID: StringName = &"skill_block"
const EVADE_SLOT_ID: StringName = &"skill_evade"

@export var slot_assignments: Array[Resource] = []
@export var save_file_path: String = DEFAULT_SAVE_FILE_PATH

static func load_or_create(save_path: String = DEFAULT_SAVE_FILE_PATH) -> Resource:
	return PersistentResourceStateIOScript.load_or_create(save_path, "res://core/models/player_skill_slot_state.gd")

static func get_all_slot_ids() -> Array[StringName]:
	var all_ids: Array[StringName] = SKILL_SLOT_IDS.duplicate()
	all_ids.append(BLOCK_SLOT_ID)
	all_ids.append(EVADE_SLOT_ID)
	return all_ids

func get_slot_assignment(slot_id: StringName) -> Resource:
	for assignment: Resource in slot_assignments:
		if assignment == null:
			continue
		if assignment.get("slot_id") == slot_id:
			return assignment
	return null

func set_slot_assignment(
	slot_id: StringName,
	source_weapon_wip_id: StringName,
	source_skill_draft_id: StringName,
	display_name: String,
	persist_changes: bool = true
) -> void:
	if slot_id == StringName():
		return
	var assignment: Resource = get_slot_assignment(slot_id)
	if assignment == null:
		assignment = SkillSlotAssignment.new()
		slot_assignments.append(assignment)
	assignment.set("slot_id", slot_id)
	assignment.set("source_weapon_wip_id", source_weapon_wip_id)
	assignment.set("source_skill_draft_id", source_skill_draft_id)
	assignment.set("display_name", display_name)
	if persist_changes:
		persist()

func clear_slot(slot_id: StringName, persist_changes: bool = true) -> void:
	for index: int in range(slot_assignments.size()):
		var assignment: Resource = slot_assignments[index]
		if assignment == null:
			continue
		if assignment.get("slot_id") == slot_id:
			slot_assignments.remove_at(index)
			if persist_changes:
				persist()
			return

func clear_slots(slot_ids: Array[StringName], persist_changes: bool = true) -> void:
	if slot_ids.is_empty():
		return
	var slots_removed: bool = false
	for index: int in range(slot_assignments.size() - 1, -1, -1):
		var assignment: Resource = slot_assignments[index]
		if assignment == null:
			continue
		var slot_id: StringName = assignment.get("slot_id") as StringName
		if not slot_ids.has(slot_id):
			continue
		slot_assignments.remove_at(index)
		slots_removed = true
	if slots_removed and persist_changes:
		persist()

func get_slot_display_name(slot_id: StringName) -> String:
	var assignment: Resource = get_slot_assignment(slot_id)
	if assignment == null:
		return ""
	return String(assignment.get("display_name"))

func is_slot_assigned(slot_id: StringName) -> bool:
	return get_slot_assignment(slot_id) != null

func persist() -> bool:
	return PersistentResourceStateIOScript.persist_resource(self, save_file_path)
