extends RefCounted
class_name ForgeWorkspacePlanePresenter

func get_default_layer_for_plane(
	forge_controller: ForgeGridController,
	plane_id: StringName,
	plane_zx: StringName,
	plane_zy: StringName
) -> int:
	if forge_controller == null:
		return 0
	match plane_id:
		plane_zx:
			return forge_controller.grid_size.y >> 1
		plane_zy:
			return forge_controller.grid_size.x >> 1
		_:
			return forge_controller.get_default_active_layer()

func get_max_layer_for_plane(
	forge_controller: ForgeGridController,
	plane_id: StringName,
	plane_zx: StringName,
	plane_zy: StringName
) -> int:
	if forge_controller == null:
		return 0
	match plane_id:
		plane_zx:
			return forge_controller.grid_size.y - 1
		plane_zy:
			return forge_controller.grid_size.x - 1
		_:
			return forge_controller.grid_size.z - 1
