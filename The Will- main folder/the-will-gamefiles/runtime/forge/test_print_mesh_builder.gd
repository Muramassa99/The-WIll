extends RefCounted
class_name TestPrintMeshBuilder

const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")

var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE

func set_view_tuning(value: ForgeViewTuningDef) -> void:
	forge_view_tuning = value if value != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE

func build_mesh(cells: Array[CellAtom], material_lookup: Dictionary = {}) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	var occupied: Dictionary = {}
	var emitted_vertex_count: int = 0

	for cell: CellAtom in cells:
		if cell == null:
			continue
		occupied[cell.grid_position] = true

	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: CellAtom in cells:
		if cell == null:
			continue
		var color: Color = _resolve_cell_color(cell.material_variant_id, material_lookup)
		emitted_vertex_count += _append_visible_faces(surface_tool, cell, occupied, color)

	if emitted_vertex_count == 0:
		return ArrayMesh.new()

	return surface_tool.commit()

func _append_visible_faces(surface_tool: SurfaceTool, cell: CellAtom, occupied: Dictionary, color: Color) -> int:
	var emitted_vertex_count: int = 0
	var directions: Array[Vector3i] = [
		Vector3i.RIGHT,
		Vector3i.LEFT,
		Vector3i.UP,
		Vector3i.DOWN,
		Vector3i.FORWARD,
		Vector3i.BACK
	]

	for direction: Vector3i in directions:
		if occupied.has(cell.grid_position + direction):
			continue
		emitted_vertex_count += _append_face(surface_tool, cell.get_center_position(), direction, color)

	return emitted_vertex_count

func _append_face(surface_tool: SurfaceTool, center: Vector3, direction: Vector3i, color: Color) -> int:
	var corners: Array[Vector3] = _get_face_corners(direction)
	var normal: Vector3 = Vector3(direction)
	var indices: Array[int] = [0, 1, 2, 0, 2, 3]

	for vertex_index: int in indices:
		surface_tool.set_color(color)
		surface_tool.set_normal(normal)
		surface_tool.add_vertex(center + corners[vertex_index])

	return 6

func _get_face_corners(direction: Vector3i) -> Array[Vector3]:
	match direction:
		Vector3i.RIGHT:
			return [
				Vector3(0.5, -0.5, -0.5),
				Vector3(0.5, -0.5, 0.5),
				Vector3(0.5, 0.5, 0.5),
				Vector3(0.5, 0.5, -0.5)
			]
		Vector3i.LEFT:
			return [
				Vector3(-0.5, -0.5, 0.5),
				Vector3(-0.5, -0.5, -0.5),
				Vector3(-0.5, 0.5, -0.5),
				Vector3(-0.5, 0.5, 0.5)
			]
		Vector3i.UP:
			return [
				Vector3(-0.5, 0.5, -0.5),
				Vector3(0.5, 0.5, -0.5),
				Vector3(0.5, 0.5, 0.5),
				Vector3(-0.5, 0.5, 0.5)
			]
		Vector3i.DOWN:
			return [
				Vector3(-0.5, -0.5, 0.5),
				Vector3(0.5, -0.5, 0.5),
				Vector3(0.5, -0.5, -0.5),
				Vector3(-0.5, -0.5, -0.5)
			]
		Vector3i.FORWARD:
			return [
				Vector3(0.5, -0.5, 0.5),
				Vector3(-0.5, -0.5, 0.5),
				Vector3(-0.5, 0.5, 0.5),
				Vector3(0.5, 0.5, 0.5)
			]
		_:
			return [
				Vector3(-0.5, -0.5, -0.5),
				Vector3(0.5, -0.5, -0.5),
				Vector3(0.5, 0.5, -0.5),
				Vector3(-0.5, 0.5, -0.5)
			]

func _resolve_cell_color(material_variant_id: StringName, material_lookup: Dictionary) -> Color:
	var base_material: BaseMaterialDef = material_lookup.get(material_variant_id) as BaseMaterialDef
	if base_material != null:
		return base_material.albedo_color
	return forge_view_tuning.test_print_fallback_color