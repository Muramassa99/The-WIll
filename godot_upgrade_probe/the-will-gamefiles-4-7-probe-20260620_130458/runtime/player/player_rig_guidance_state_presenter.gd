extends RefCounted
class_name PlayerRigGuidanceStatePresenter

var guidance_targets := {
	&"hand_right": null,
	&"hand_left": null,
}

var arm_guidance_state := {
	&"hand_right": false,
	&"hand_left": false,
}

var support_hand_state := {
	&"hand_right": false,
	&"hand_left": false,
}

func reset_state() -> void:
	guidance_targets[&"hand_right"] = null
	guidance_targets[&"hand_left"] = null
	arm_guidance_state[&"hand_right"] = false
	arm_guidance_state[&"hand_left"] = false
	support_hand_state[&"hand_right"] = false
	support_hand_state[&"hand_left"] = false

func get_arm_guidance_target(slot_id: StringName) -> Node3D:
	var resolved_target = guidance_targets.get(_normalize_hand_slot_id(slot_id), null)
	return resolved_target as Node3D if is_instance_valid(resolved_target) else null

func is_arm_guidance_active(slot_id: StringName) -> bool:
	return bool(arm_guidance_state.get(_normalize_hand_slot_id(slot_id), false))

func is_support_hand_active(slot_id: StringName) -> bool:
	return bool(support_hand_state.get(_normalize_hand_slot_id(slot_id), false))

func set_arm_guidance_active(slot_id: StringName, active: bool) -> void:
	arm_guidance_state[_normalize_hand_slot_id(slot_id)] = active

func clear_arm_guidance_active(slot_id: StringName) -> void:
	arm_guidance_state[_normalize_hand_slot_id(slot_id)] = false

func set_support_hand_active(slot_id: StringName, active: bool) -> void:
	support_hand_state[_normalize_hand_slot_id(slot_id)] = active

func set_arm_guidance_target(slot_id: StringName, target_node: Node3D) -> void:
	var resolved_target: Node3D = target_node if is_instance_valid(target_node) else null
	guidance_targets[_normalize_hand_slot_id(slot_id)] = resolved_target

func clear_arm_guidance_target(slot_id: StringName) -> void:
	guidance_targets[_normalize_hand_slot_id(slot_id)] = null

func _normalize_hand_slot_id(slot_id: StringName) -> StringName:
	if slot_id == &"hand_left":
		return &"hand_left"
	return &"hand_right"
