extends Resource
class_name BakedProfile

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const PRIMARY_GRIP_HANDLE_COORDINATE_MODE_BALANCED_SIGNED := &"balanced_signed"
const PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP := (
	&"directional_pommel_to_tip"
)
const PRIMARY_GRIP_HANDLE_COORDINATE_MODE_AUTHORITY_WEAPON_INTRINSIC_COM := (
	&"weapon_intrinsic_center_of_mass"
)

@export var profile_id: StringName = &""
@export var total_mass: float = 0.0
@export var total_volume_cell_equivalents: float = 0.0
# Legacy serialized storage name retained while V1 profiles and saved WIPs are
# supported. Semantically this is always the immutable, density-weighted weapon
# COM in the baked geometry interpretation of WeaponRoot cell units. Runtime
# equip code may re-express this point relative to a grip frame, but grip
# placement must never mutate this backing value.
@export var center_of_mass: Vector3 = Vector3.ZERO
@export var weapon_intrinsic_center_of_mass_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
@export var weapon_intrinsic_center_of_mass_authority_source: StringName = StringName()
@export var weapon_intrinsic_center_of_mass_spatial_material_valid: bool = false
@export var reach: float = 0.0
# Baked default-contact -> intrinsic-COM vector. This is not an active-grip
# state and must not be reused as the future runtime handling lever arm.
@export var primary_grip_offset: Vector3 = Vector3.ZERO
@export var primary_grip_contact_position: Vector3 = Vector3.ZERO
@export var primary_grip_axis_ratio_from_span_start: float = 0.0
@export var weapon_intrinsic_center_of_mass_handle_axis_ratio_from_span_start_unclamped: float = 0.0
@export var primary_grip_handle_tip_side_axis_ratio_from_span_start: float = 1.0
@export var primary_grip_handle_tip_side_direction: Vector3 = Vector3.ZERO
@export var primary_grip_handle_tip_side_direction_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
# Authoring-display hint only. Grip positions remain normalized 0..1 in saved
# and runtime data. balanced_signed merely asks the UI to display that same
# percentage as -1..1 so the Handle midpoint reads as zero.
@export var primary_grip_handle_coordinate_mode: StringName = StringName()
@export var primary_grip_handle_coordinate_mode_authority_source: StringName = StringName()
@export var primary_grip_handle_zero_axis_ratio_from_span_start: float = 0.0
@export var primary_grip_handle_zero_position: Vector3 = Vector3.ZERO
@export var primary_grip_handle_zero_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
@export var primary_grip_contact_percent: float = 0.0
# Legacy field names retained for saved-profile compatibility. Their "com" and
# "center_balance" values are derived only from weapon-intrinsic COM; they are
# not active-grip or runtime handling state.
@export var primary_grip_com_side_position: Vector3 = Vector3.ZERO
@export var primary_grip_far_side_position: Vector3 = Vector3.ZERO
@export var primary_grip_span_start: Vector3 = Vector3.ZERO
@export var primary_grip_span_end: Vector3 = Vector3.ZERO
@export var primary_grip_span_length_voxels: int = 0
@export var primary_grip_slide_axis: Vector3 = Vector3.ZERO
@export var primary_grip_slice_axis_ratios_from_span_start: PackedFloat32Array = PackedFloat32Array()
@export var primary_grip_slice_centers: PackedVector3Array = PackedVector3Array()
@export var primary_grip_slice_centers_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
@export var primary_grip_minor_axis_a: Vector3 = Vector3.ZERO
@export var primary_grip_minor_axis_b: Vector3 = Vector3.ZERO
@export var primary_grip_profile_offsets_minor_meters: PackedVector2Array = PackedVector2Array()
@export var primary_grip_authority_source: StringName = StringName()
@export var primary_grip_source_body_id: StringName = StringName()
@export var primary_grip_center_balance_valid: bool = false
@export var primary_grip_center_balance_origin: Vector3 = Vector3.ZERO
@export var primary_grip_center_balance_origin_id: StringName = CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
@export var primary_grip_center_balance_offset_percent: float = 0.0
@export var primary_grip_two_hand_eligible: bool = false
@export var primary_grip_two_hand_negative_limit: float = 0.0
@export var primary_grip_two_hand_positive_limit: float = 0.0
@export var front_heavy_score: float = 0.0
@export var balance_score: float = 0.0
@export var edge_score: float = 0.0
@export var blunt_score: float = 0.0
@export var pierce_score: float = 0.0
@export var guard_score: float = 0.0
@export var flex_score: float = 0.0
@export var launch_score: float = 0.0
@export var capability_scores: Dictionary[StringName, float] = {}
@export var material_variant_mix: Dictionary = {}
@export var material_volume_mix: Dictionary = {}
@export var resolved_material_stat_lines: Array[StatLine] = []
@export var resolved_capability_bias_lines: Array[StatLine] = []
@export var resolved_skill_family_bias_lines: Array[StatLine] = []
@export var resolved_elemental_affinity_lines: Array[StatLine] = []
@export var resolved_equipment_context_bias_lines: Array[StatLine] = []
@export var material_runtime_data_resolved: bool = false
@export var weapon_total_length_meters: float = 0.0
@export var weapon_tip_point: Vector3 = Vector3.ZERO
@export var weapon_pommel_point: Vector3 = Vector3.ZERO
@export var weapon_tip_distance_meters: float = 0.0
@export var weapon_pommel_distance_meters: float = 0.0
@export var primary_grip_valid: bool = false
@export var validation_error: String = ""


func get_weapon_intrinsic_center_of_mass_weapon_root_cells() -> Vector3:
	return center_of_mass


func set_weapon_intrinsic_center_of_mass_weapon_root_cells(
	position_weapon_root_cells: Vector3,
	authority_source: StringName,
	spatial_material_valid: bool
) -> void:
	center_of_mass = position_weapon_root_cells
	weapon_intrinsic_center_of_mass_origin_id = (
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	weapon_intrinsic_center_of_mass_authority_source = authority_source
	weapon_intrinsic_center_of_mass_spatial_material_valid = spatial_material_valid
