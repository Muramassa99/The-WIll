extends Resource
class_name WeaponMotionPolicyDef

## Controller preferences and numerical budgets, never anatomical range limits.
## Shared definitions remain immutable; a solve consumes a value snapshot.
@export var position_tolerance_m: float = 0.00005
@export var orientation_tolerance_degrees: float = 0.025
@export var max_rotation_step_degrees: float = 5.0
@export var max_translation_step_m: float = 0.01
@export var max_joint_step_degrees: float = 8.0
@export var max_substeps: int = 12
@export var max_iterations: int = 12
@export var scale_search_steps: int = 7
@export var finite_difference_radians: float = 0.0001

func as_dictionary(character_scale: float = 1.0) -> Dictionary:
	return {
		"position_tolerance": position_tolerance_m * character_scale,
		"orientation_tolerance": deg_to_rad(orientation_tolerance_degrees),
		"max_rotation_step": deg_to_rad(max_rotation_step_degrees),
		"max_translation_step": max_translation_step_m * character_scale,
		"max_joint_step": deg_to_rad(max_joint_step_degrees),
		"position_normalization": 0.25 * character_scale,
		"max_substeps": max_substeps, "max_iterations": max_iterations,
		"scale_search_steps": scale_search_steps,
		"finite_difference": finite_difference_radians,
	}
