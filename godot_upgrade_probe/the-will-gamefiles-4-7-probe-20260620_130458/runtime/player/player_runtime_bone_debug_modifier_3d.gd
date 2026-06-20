extends SkeletonModifier3D
class_name PlayerRuntimeBoneDebugModifier3D

var humanoid_rig: Node = null

func _process_modification_with_delta(delta: float) -> void:
	if humanoid_rig == null or not is_instance_valid(humanoid_rig):
		return
	if not humanoid_rig.has_method("process_runtime_bone_debug_modifier_frame"):
		return
	humanoid_rig.call("process_runtime_bone_debug_modifier_frame", maxf(delta, 0.0))
