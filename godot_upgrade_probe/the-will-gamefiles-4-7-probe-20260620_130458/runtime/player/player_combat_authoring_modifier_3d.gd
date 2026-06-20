extends SkeletonModifier3D
class_name PlayerCombatAuthoringModifier3D

var humanoid_rig: Node = null

func _process_modification_with_delta(delta: float) -> void:
	_process_combat_authoring(delta)

func _process_combat_authoring(delta: float) -> void:
	if humanoid_rig == null or not is_instance_valid(humanoid_rig):
		return
	if not humanoid_rig.has_method("process_combat_authoring_modifier_frame"):
		return
	humanoid_rig.call("process_combat_authoring_modifier_frame", maxf(delta, 0.0))
