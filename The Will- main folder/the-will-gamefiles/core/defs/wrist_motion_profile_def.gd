extends Resource
class_name WristMotionProfileDef

## Authored engineering limits from the wrist guide, not universal human ROM.
## Treat shared .tres instances as immutable; captures store value dictionaries.
const REVISION := "semantic_forearm_wrist_v1"

@export var forearm_roll_limit_degrees: float = 90.0
@export var flexion_limit_degrees: float = 65.0
@export var extension_limit_degrees: float = 60.0
@export var ulnar_limit_degrees: float = 30.0
@export var radial_limit_degrees: float = 15.0
@export var orientation_tolerance_degrees: float = 0.025
@export var angle_epsilon_degrees: float = 0.05

func as_dictionary() -> Dictionary:
	return {
		"revision": REVISION,
		"forearm_roll_limit_radians": deg_to_rad(forearm_roll_limit_degrees),
		"flexion_limit_radians": deg_to_rad(flexion_limit_degrees),
		"extension_limit_radians": deg_to_rad(extension_limit_degrees),
		"ulnar_limit_radians": deg_to_rad(ulnar_limit_degrees),
		"radial_limit_radians": deg_to_rad(radial_limit_degrees),
		"orientation_tolerance_radians": deg_to_rad(orientation_tolerance_degrees),
		"angle_epsilon_radians": deg_to_rad(angle_epsilon_degrees),
	}
