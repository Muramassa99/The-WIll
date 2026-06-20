extends Resource
class_name ForgeAuthoringSandboxDef

const ForgeSamplePresetDefScript = preload("res://core/defs/forge/forge_sample_preset_def.gd")

@export var sandbox_id: StringName = &"forge_authoring_sandbox_default"

@export_group("Authoring Samples")
@export var default_sample_preset_id: StringName = &"sample_grip"
@export var sample_grip_preset_id: StringName = &"sample_grip"
@export var sample_flex_preset_id: StringName = &"sample_flex"
@export var sample_bow_preset_id: StringName = &"sample_bow"
@export var sample_presets: Array[ForgeSamplePresetDef] = []

@export_group("Sandbox Inventory")
@export var inventory_seed_def: Resource
@export var inventory_seed_quantity: int = 96
@export var inventory_seed_bonus_quantity: int = 0
