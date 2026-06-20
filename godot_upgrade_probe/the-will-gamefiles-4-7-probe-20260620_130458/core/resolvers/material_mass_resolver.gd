extends RefCounted
class_name MaterialMassResolver

const MaterialRuntimeResolverScript = preload("res://core/resolvers/material_runtime_resolver.gd")

const DEFAULT_VOLUME_ROUNDING_STEP_CELL_EQUIVALENTS := 0.25
const MIN_CELL_WORLD_SIZE_METERS := 0.0001

var material_runtime_resolver = MaterialRuntimeResolverScript.new()

func resolve_cell_mass(
	cell: CellAtom,
	material_lookup: Dictionary,
	cell_equivalent_volume: float = 1.0
) -> float:
	if cell == null:
		return 0.0
	return resolve_mass_for_cell_equivalent_volume(
		cell.material_variant_id,
		material_lookup,
		cell_equivalent_volume,
		0.0
	)

func resolve_mass_for_volume_meters(
	material_variant_id: StringName,
	material_lookup: Dictionary,
	volume_meters_cubed: float,
	cell_world_size_meters: float,
	rounding_step_cell_equivalents: float = DEFAULT_VOLUME_ROUNDING_STEP_CELL_EQUIVALENTS
) -> float:
	var cell_equivalent_volume: float = resolve_cell_equivalent_volume_from_meters(
		volume_meters_cubed,
		cell_world_size_meters,
		rounding_step_cell_equivalents
	)
	return resolve_mass_for_cell_equivalent_volume(
		material_variant_id,
		material_lookup,
		cell_equivalent_volume,
		0.0
	)

func resolve_mass_for_cell_equivalent_volume(
	material_variant_id: StringName,
	material_lookup: Dictionary,
	cell_equivalent_volume: float,
	rounding_step_cell_equivalents: float = DEFAULT_VOLUME_ROUNDING_STEP_CELL_EQUIVALENTS
) -> float:
	var mass_per_full_cell: float = material_runtime_resolver.resolve_density_per_material_id(
		material_variant_id,
		material_lookup
	)
	var resolved_volume: float = round_cell_equivalent_volume(
		cell_equivalent_volume,
		rounding_step_cell_equivalents
	)
	return mass_per_full_cell * resolved_volume

func resolve_cell_equivalent_volume_from_meters(
	volume_meters_cubed: float,
	cell_world_size_meters: float,
	rounding_step_cell_equivalents: float = DEFAULT_VOLUME_ROUNDING_STEP_CELL_EQUIVALENTS
) -> float:
	var full_cell_volume_meters: float = get_full_cell_volume_meters(cell_world_size_meters)
	if full_cell_volume_meters <= 0.0:
		return 0.0
	var raw_cell_equivalent_volume: float = maxf(volume_meters_cubed, 0.0) / full_cell_volume_meters
	return round_cell_equivalent_volume(
		raw_cell_equivalent_volume,
		rounding_step_cell_equivalents
	)

func get_full_cell_volume_meters(cell_world_size_meters: float) -> float:
	var resolved_cell_size: float = maxf(cell_world_size_meters, MIN_CELL_WORLD_SIZE_METERS)
	return resolved_cell_size * resolved_cell_size * resolved_cell_size

func round_cell_equivalent_volume(
	cell_equivalent_volume: float,
	rounding_step_cell_equivalents: float = DEFAULT_VOLUME_ROUNDING_STEP_CELL_EQUIVALENTS
) -> float:
	var resolved_volume: float = maxf(cell_equivalent_volume, 0.0)
	if rounding_step_cell_equivalents <= 0.0 or resolved_volume <= 0.0:
		return resolved_volume
	var rounded_volume: float = roundf(resolved_volume / rounding_step_cell_equivalents) * rounding_step_cell_equivalents
	if rounded_volume <= 0.0:
		return rounding_step_cell_equivalents
	return rounded_volume
