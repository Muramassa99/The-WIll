extends Resource
class_name ShoulderMotionProfileDef

## Active humerothoracic reference samples, not isolated glenohumeral limits.
## McCully 2005 Table I; engineering mapping into Josie's anatomical zero.
## Missing ranges are never inferred globally. Opt-in provisional coverage uses
## fixed original/checked samples and a bounded local neighborhood per donor.
const REVISION := "chest_relative_shoulder_v1"
const SampleDef = preload("res://core/defs/shoulder_motion_sample_def.gd")

@export var plane_samples_degrees := PackedFloat64Array([0.0, 32.5, 90.0])
@export var external_samples_degrees := PackedFloat64Array([107.0, 103.0, 113.0])
@export var internal_samples_degrees := PackedFloat64Array([73.0, 65.0, 41.0])
@export var sampled_elevation_degrees: float = 90.0
@export_enum("measured_band_only", "measured_plus_provisional") var coverage_mode: String = "measured_band_only"
@export_range(0.0, 15.0, 0.1) var maximum_borrow_angle_degrees: float = 15.0
@export var provisional_samples: Array[SampleDef] = []

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
	var samples: Array[Dictionary] = []
	for sample: SampleDef in provisional_samples:
		samples.append(sample.as_dictionary() if sample != null else {})
	return {"revision": REVISION, "plane_samples_radians": planes,
		"minimum_samples_radians": minimums, "maximum_samples_radians": maximums,
		"sampled_elevation_radians": deg_to_rad(sampled_elevation_degrees),
		# Numerical angle comparison epsilon, not extra anatomical travel.
		"angle_epsilon_radians": 0.00001, "coverage_mode": coverage_mode,
		"coverage_schema": "fixed_shoulder_neighborhoods_v1",
		"maximum_borrow_angle_radians": deg_to_rad(maximum_borrow_angle_degrees),
		"provisional_samples": samples,
		# Historical unpaired observation only; never used as an interval.
		"lowered_external_radians": deg_to_rad(-67.0),
		# Gaps in that original dataset, not the evaluated coverage of a pose.
		# Paired supplemental/checked rows above may cover parts provisionally.
		"missing_ranges": ["lowered_internal", "overhead", "behind_body"],
		"source": "McCully et al. 2005 Table I, active humerothoracic ROM"}
