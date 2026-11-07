extends Resource
class_name WristMotionProfileDef

## Authored engineering limits from the wrist guide, not universal human ROM.
## Treat shared .tres instances as immutable; captures store value dictionaries.
const REVISION := "semantic_forearm_wrist_v1"
const FOREARM_INTERVAL_REVISION := "elbow_conditioned_forearm_v1"
const BEND_FRAME_REST_ANATOMICAL := "rest_anatomical"
const BEND_FRAME_HAND_PARENT_LOCAL_XZ := "hand_parent_local_xz"

# Saved captures without bend_frame retain their original palm/rest mapping.
# Josie's X/Z frame is the Hand bone's parent-local identity shown in the
# calibration recordings, downstream of the existing forearm axial rotation.
@export_enum("rest_anatomical", "hand_parent_local_xz") var bend_frame: String = BEND_FRAME_REST_ANATOMICAL
@export var hand_local_x_minimum_degrees: float = -65.0
@export var hand_local_x_maximum_degrees: float = 35.0
@export var hand_local_z_minimum_degrees: float = -55.0
@export var hand_local_z_maximum_degrees: float = 55.0

# Legacy saved profiles still read this field. New profiles use the asymmetric
# elbow-dependent interval; this scalar does not intersect or cap that interval.
@export var forearm_roll_limit_degrees: float = 90.0
@export var forearm_elbow_samples_degrees := PackedFloat64Array([0.0, 45.0, 90.0, 145.0])
@export var forearm_pronation_limits_degrees := PackedFloat64Array([109.0, 96.0, 80.0, 54.0])
@export var forearm_supination_limits_degrees := PackedFloat64Array([39.0, 73.0, 85.0, 95.0])
@export var flexion_limit_degrees: float = 65.0
@export var extension_limit_degrees: float = 60.0
@export var ulnar_limit_degrees: float = 30.0
@export var radial_limit_degrees: float = 15.0
@export var orientation_tolerance_degrees: float = 0.025
@export var angle_epsilon_degrees: float = 0.05

func as_dictionary() -> Dictionary:
	var local_xz: bool = bend_frame == BEND_FRAME_HAND_PARENT_LOCAL_XZ
	return {
		"revision": REVISION,
		"bend_frame": bend_frame,
		"forearm_roll_limit_radians": deg_to_rad(forearm_roll_limit_degrees),
		"forearm_interval_revision": FOREARM_INTERVAL_REVISION,
		"forearm_elbow_samples_radians": _radians(forearm_elbow_samples_degrees),
		"forearm_pronation_limits_radians": _radians(forearm_pronation_limits_degrees),
		"forearm_supination_limits_radians": _radians(forearm_supination_limits_degrees),
		# Existing numeric keys encode the negative/positive beta and gamma
		# bounds. Their frame is explicit; no new independent wrist Y exists.
		"flexion_limit_radians": deg_to_rad(-hand_local_x_minimum_degrees if local_xz else flexion_limit_degrees),
		"extension_limit_radians": deg_to_rad(hand_local_x_maximum_degrees if local_xz else extension_limit_degrees),
		"ulnar_limit_radians": deg_to_rad(-hand_local_z_minimum_degrees if local_xz else ulnar_limit_degrees),
		"radial_limit_radians": deg_to_rad(hand_local_z_maximum_degrees if local_xz else radial_limit_degrees),
		"orientation_tolerance_radians": deg_to_rad(orientation_tolerance_degrees),
		"angle_epsilon_radians": deg_to_rad(angle_epsilon_degrees),
	}

static func _radians(degrees: PackedFloat64Array) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for value: float in degrees: result.append(deg_to_rad(value))
	return result
