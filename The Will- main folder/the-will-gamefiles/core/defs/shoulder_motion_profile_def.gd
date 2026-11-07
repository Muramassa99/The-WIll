extends Resource
class_name ShoulderMotionProfileDef

## Active humerothoracic reference samples, not isolated glenohumeral limits.
## McCully 2005 Table I; engineering mapping into Josie's anatomical zero.
## Historical neighborhood coverage retains its original/checked donors.
## Continuous coverage is an explicit provisional engineering envelope, with
## fixed regional bounds in the same anatomical zero; not clinical calibration.
const REVISION := "chest_relative_shoulder_v1"
const SampleDef = preload("res://core/defs/shoulder_motion_sample_def.gd")

@export var plane_samples_degrees := PackedFloat64Array([0.0, 32.5, 90.0])
@export var external_samples_degrees := PackedFloat64Array([107.0, 103.0, 113.0])
@export var internal_samples_degrees := PackedFloat64Array([73.0, 65.0, 41.0])
@export var sampled_elevation_degrees: float = 90.0
@export_enum("measured_band_only", "measured_plus_provisional", "continuous_provisional") var coverage_mode: String = "measured_band_only"
@export_range(0.0, 15.0, 0.1) var maximum_borrow_angle_degrees: float = 15.0
@export var provisional_samples: Array[SampleDef] = []
## Fixed h endpoints, not extra rotation relative to the latest edited pose.
## The checked +/-10-degree poses supply conservative initial regional spans;
## they do not establish human endpoints or body-clearance certificates.
@export var lower_elevation_degrees: float = 2.0
@export var lower_minimum_degrees: float = -65.1
@export var lower_maximum_degrees: float = 66.9
@export var upper_elevation_degrees: float = 150.0
@export var upper_minimum_degrees: float = -10.0
@export var upper_maximum_degrees: float = 10.0
@export var posterior_transition_plane_degrees: float = -30.0
@export var posterior_minimum_degrees: float = -10.0
@export var posterior_maximum_degrees: float = 10.0
@export_multiline var lower_source: String = "Paired Sahara 2020 mean 2-degree abduction: external65.1/internal66.9; engineering mapping to Josie fixed arm-down/forearm-forward zero. https://www.sciencedirect.com/science/article/abs/pii/S0949265820300105"
@export_multiline var upper_source: String = "Josie R/L e150 p0/45/90 h=-10/0/+10 poses inspected 2026-11-07, provisional_pose_review. Fixed preliminary regional span, not measured anatomical endpoints; continuous extension/interpolation is provisional and not a body-clearance certificate."
@export_multiline var posterior_source: String = "Josie R/L e90 pm30 h=-10/0/+10 poses inspected 2026-11-07, provisional_pose_review. Fixed preliminary posterior span; use for unsampled posterior/medial directions is an explicit engineering fallback, not anatomical calibration or body-clearance certification."
## Provisional Josie socket swing, approved for coordinated-body tuning.
## Fixed Idle-centred half-cone; not a measured human clavicle endpoint. No extra
## clavicle axial-roll freedom: the request preserves its captured axial value.
@export var clavicle_swing_half_angle_degrees: float = 10.0
## User-confirmed Idle home, captured in Clavicle's Spine02 parent space.
## Screenshot XYZW values match fresh scene and Reset Idle on 2026-11-07.
## Immutable definition data, never captured anew from an edited pose.
@export var clavicle_idle_left_rotation: Quaternion = Quaternion(0.174668, -0.030927, -0.808198, 0.561561)
@export var clavicle_idle_right_rotation: Quaternion = Quaternion(0.160754, 0.015876, 0.821109, 0.547436)

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
		"coverage_schema": "fixed_shoulder_regions_v1" if coverage_mode == "continuous_provisional" else "fixed_shoulder_neighborhoods_v1",
		"continuous_regions": {
			"lower_elevation_radians": deg_to_rad(lower_elevation_degrees),
			"lower_minimum_radians": deg_to_rad(lower_minimum_degrees),
			"lower_maximum_radians": deg_to_rad(lower_maximum_degrees),
			"upper_elevation_radians": deg_to_rad(upper_elevation_degrees),
			"upper_minimum_radians": deg_to_rad(upper_minimum_degrees),
			"upper_maximum_radians": deg_to_rad(upper_maximum_degrees),
			"posterior_transition_plane_radians": deg_to_rad(posterior_transition_plane_degrees),
			"posterior_minimum_radians": deg_to_rad(posterior_minimum_degrees),
			"posterior_maximum_radians": deg_to_rad(posterior_maximum_degrees),
			"lower_source": lower_source, "upper_source": upper_source, "posterior_source": posterior_source,
			"zero_convention": "sideways_upperarm_forearm_forward_shortest_swing",
			"origin_id": &"CC_Base_Spine02ShoulderAnatomicalOrigin", "machine_origin_id": &"RL_BoneRoot"},
		"maximum_borrow_angle_radians": deg_to_rad(maximum_borrow_angle_degrees),
		"clavicle_swing_half_angle_degrees": clavicle_swing_half_angle_degrees,
		"clavicle_reference_rotations_by_slot": {
			&"hand_left": clavicle_idle_left_rotation.normalized(),
			&"hand_right": clavicle_idle_right_rotation.normalized()},
		"clavicle_reference_source": "fixed_idle_pose",
		"provisional_samples": samples,
		# Historical unpaired observation only; never used as an interval.
		"lowered_external_radians": deg_to_rad(-67.0),
		# Gaps in that original dataset, not the evaluated coverage of a pose.
		# Paired supplemental/checked rows above may cover parts provisionally.
		"missing_ranges": ["lowered_internal", "overhead", "behind_body"],
		"source": "McCully et al. 2005 Table I, active humerothoracic ROM"}
