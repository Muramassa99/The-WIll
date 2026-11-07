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
## Finite travel costs allow coordinated recruitment before a distal joint hits
## its boundary. These are controller preferences, never anatomical limits.
## Lexicographic is retained for counterfactual diagnostics and older fixtures.
@export_enum("weighted", "lexicographic") var posture_preference_mode: String = "weighted"
@export var posture_group_costs_by_mode: Dictionary = {
	"tip": {"forearm": 1.0, "wrist": 2.0, "elbow": 6.0, "shoulder": 12.0,
		"shoulder_swing": 12.0, "shoulder_roll": 12.0, "girdle": 24.0, "shoulder_girdle": 24.0, "torso": 48.0},
	"pommel": {"forearm": 6.0, "wrist": 8.0, "elbow": 1.0, "shoulder": 1.0,
		"shoulder_swing": 1.0, "shoulder_roll": 6.0, "girdle": 8.0, "shoulder_girdle": 8.0, "torso": 16.0},
	"roll": {"forearm": 1.0, "wrist": 3.0, "elbow": 6.0, "shoulder": 12.0,
		"shoulder_swing": 8.0, "shoulder_roll": 12.0, "girdle": 24.0, "shoulder_girdle": 24.0, "torso": 48.0},
}

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
		"posture_preference_mode": posture_preference_mode,
		"posture_group_costs_by_mode": posture_group_costs_by_mode.duplicate(true),
	}
