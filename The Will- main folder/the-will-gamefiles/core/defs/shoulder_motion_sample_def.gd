extends Resource
class_name ShoulderMotionSampleDef

## One immutable paired interval in the fixed anatomical chest convention.
## X points outward from the selected side, Y up and Z toward the back. Only
## X is mirrored when resolving the row for the left arm. H is positive for
## internal rotation, measured from the SAME fixed zero as shoulder calibration.
## A provenance label does not certify anatomy: inspected rig rows and mapped
## published rows remain explicitly provisional where applicable.
@export var sample_id: StringName = &""
@export_enum("both", "hand_right", "hand_left") var side: String = "both"
@export var direction_side_neutral: Vector3 = Vector3.ZERO
@export var minimum_degrees: float = 0.0
@export var maximum_degrees: float = 0.0
@export var region_id: StringName = &""
@export_enum("original_reference", "checked_rig", "provisional") var provenance_kind: String = "provisional"
@export_multiline var source: String = ""
@export var provisional: bool = true
@export var can_donate: bool = false
@export var origin_id: StringName = &"CC_Base_Spine02ShoulderAnatomicalOrigin"
@export var parent_origin_id: StringName = &"CC_Base_Spine02"
@export var machine_origin_id: StringName = &"RL_BoneRoot"

func as_dictionary() -> Dictionary:
	return {"sample_id": sample_id, "side": side, "direction_side_neutral": direction_side_neutral,
		"minimum_radians": deg_to_rad(minimum_degrees), "maximum_radians": deg_to_rad(maximum_degrees),
		"region_id": region_id, "provenance_kind": provenance_kind, "source": source,
		"provisional": provisional, "can_donate": can_donate, "origin_id": origin_id,
		"parent_origin_id": parent_origin_id, "machine_origin_id": machine_origin_id,
		"zero_convention": "sideways_upperarm_forearm_forward_shortest_swing"}
