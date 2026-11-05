extends Resource
class_name ShoulderMotionProfileDef

## Active humerothoracic reference samples, not isolated glenohumeral limits.
## McCully 2005 Table I; engineering mapping into Josie's anatomical zero.
## Missing lowered/internal, overhead and behind-body ranges are NOT inferred.
const REVISION := "chest_relative_shoulder_v1"

@export var plane_samples_degrees := PackedFloat64Array([0.0, 32.5, 90.0])
@export var external_samples_degrees := PackedFloat64Array([107.0, 103.0, 113.0])
@export var internal_samples_degrees := PackedFloat64Array([73.0, 65.0, 41.0])
@export var sampled_elevation_degrees: float = 90.0

func as_dictionary() -> Dictionary:
	var planes := PackedFloat64Array()
	var minimums := PackedFloat64Array()
	var maximums := PackedFloat64Array()
	for value: float in plane_samples_degrees:
		planes.append(deg_to_rad(value))
	for value: float in external_samples_degrees:
		minimums.append(-deg_to_rad(value))
	for value: float in internal_samples_degrees:
		maximums.append(deg_to_rad(value))
	return {"revision": REVISION, "plane_samples_radians": planes,
		"minimum_samples_radians": minimums, "maximum_samples_radians": maximums,
		"sampled_elevation_radians": deg_to_rad(sampled_elevation_degrees),
		# Numerical angle comparison epsilon, not extra anatomical travel.
		"angle_epsilon_radians": 0.00001, "coverage_mode": "measured_band_only",
		"lowered_external_radians": deg_to_rad(-67.0),
		"missing_ranges": ["lowered_internal", "overhead", "behind_body"],
		"source": "McCully et al. 2005 Table I, active humerothoracic ROM"}
