extends Resource
class_name TestPrintInstance

@export var test_id: StringName = &""
@export var source_wip_id: StringName = &""
@export var baked_profile: BakedProfile
@export var display_cells: Array[CellAtom] = []
@export var stage2_item_state: Resource
var canonical_solid = null
var canonical_geometry = null
