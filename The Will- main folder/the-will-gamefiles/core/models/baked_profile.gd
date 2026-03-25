extends Resource
class_name BakedProfile

@export var profile_id: StringName = &""
@export var total_mass: float = 0.0
@export var center_of_mass: Vector3 = Vector3.ZERO
@export var reach: float = 0.0
@export var primary_grip_offset: Vector3 = Vector3.ZERO
@export var front_heavy_score: float = 0.0
@export var balance_score: float = 0.0
@export var edge_score: float = 0.0
@export var blunt_score: float = 0.0
@export var pierce_score: float = 0.0
@export var guard_score: float = 0.0
@export var flex_score: float = 0.0
@export var launch_score: float = 0.0
@export var capability_scores: Dictionary[StringName, float] = {}
@export var primary_grip_valid: bool = false
@export var validation_error: String = ""
