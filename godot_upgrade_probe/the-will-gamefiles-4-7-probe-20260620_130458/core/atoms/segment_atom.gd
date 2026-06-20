extends Resource
class_name SegmentAtom

@export var segment_id: StringName = &""
@export var role: String = ""
@export var member_cells: Array[CellAtom] = []
@export var material_mix: Dictionary = {}
@export var major_axis: Vector3i = Vector3i.ZERO
@export var minor_axis_a: Vector3i = Vector3i.ZERO
@export var minor_axis_b: Vector3i = Vector3i.ZERO
@export var length_voxels: int = 0
@export var cross_width_voxels: int = 0
@export var cross_thickness_voxels: int = 0
@export var anchor_material_ratio: float = 0.0
@export var joint_support_material_ratio: float = 0.0
@export var bow_string_material_ratio: float = 0.0
@export var start_slice_anchor_valid: bool = false
@export var end_slice_anchor_valid: bool = false
@export var profile_state: StringName = &""
@export var has_opposing_bevel_pair: bool = false
@export var edge_span_overlap: bool = false
@export var joint_type_hint: StringName = &"none"
@export var link_count: int = 0
@export var hinge_count: int = 0
@export var is_riser_candidate: bool = false
@export var is_upper_limb_candidate: bool = false
@export var is_lower_limb_candidate: bool = false
@export var is_bow_string_candidate: bool = false
@export var projectile_pass_candidate: bool = false

func get_cell_count() -> int:
	return member_cells.size()

func is_empty() -> bool:
	return member_cells.is_empty()

func has_material(material_variant_id: StringName) -> bool:
	return material_mix.has(material_variant_id)
