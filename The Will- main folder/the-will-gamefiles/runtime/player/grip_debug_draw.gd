extends RefCounted
class_name GripDebugDraw

const MARKER_RADIUS: float = 0.025

func ensure_debug_root(rig_root: Node3D) -> Node3D:
	if rig_root == null:
		return null
	var debug_root: Node3D = rig_root.get_node_or_null("GripSolveRoot") as Node3D
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = "GripSolveRoot"
		rig_root.add_child(debug_root)
	return debug_root

func update_debug_markers(debug_root: Node3D, solve_result: Dictionary, debug_visible: bool = true) -> void:
	if debug_root == null:
		return
	_update_marker(debug_root, "DominantDesiredTarget", _resolve_slot_position(solve_result, true, "desired_target"), Color(0.95, 0.75, 0.10, 0.95), debug_visible)
	_update_marker(debug_root, "DominantCorrectedTarget", _resolve_slot_position(solve_result, true, "corrected_target"), Color(0.15, 0.90, 0.25, 0.95), debug_visible)
	_update_marker(debug_root, "SupportDesiredTarget", _resolve_slot_position(solve_result, false, "desired_target"), Color(0.95, 0.45, 0.15, 0.95), debug_visible)
	var support_color: Color = Color(0.15, 0.65, 0.95, 0.95)
	var support_slot_id: StringName = _resolve_support_slot_id(solve_result)
	var support_slot_data: Dictionary = solve_result.get(support_slot_id, {})
	if bool(support_slot_data.get("weapon_body_illegal", false)):
		support_color = Color(0.95, 0.25, 0.65, 0.95)
	_update_marker(debug_root, "SupportCorrectedTarget", _resolve_slot_position(solve_result, false, "corrected_target"), support_color, debug_visible)
	_update_marker(debug_root, "DominantElbowPole", _resolve_slot_position(solve_result, true, "pole_target"), Color(0.85, 0.25, 0.90, 0.95), debug_visible)
	_update_marker(debug_root, "SupportElbowPole", _resolve_slot_position(solve_result, false, "pole_target"), Color(0.55, 0.25, 0.95, 0.95), debug_visible)
	_update_slot_proxy_markers(debug_root, "SupportWeaponProxy", support_slot_data.get("weapon_body_proxy_samples", []), Color(1.0, 0.12, 0.75, 0.90), debug_visible)
	var torso_frame: Dictionary = solve_result.get("torso_frame", {})
	var chest_origin: Vector3 = torso_frame.get("origin_world", Vector3.ZERO) as Vector3
	var chest_forward: Vector3 = torso_frame.get("forward_world", Vector3.ZERO) as Vector3
	if chest_origin.length_squared() > 0.000001 and chest_forward.length_squared() > 0.000001:
		_update_marker(debug_root, "ChestForwardMarker", chest_origin + chest_forward.normalized() * 0.35, Color(0.90, 0.90, 0.90, 0.95), debug_visible)

func _resolve_slot_position(solve_result: Dictionary, dominant: bool, key: String) -> Vector3:
	var dominant_slot_id: StringName = solve_result.get("dominant_slot_id", &"hand_right")
	var support_slot_id: StringName = &"hand_left" if dominant_slot_id == &"hand_right" else &"hand_right"
	var slot_id: StringName = dominant_slot_id if dominant else support_slot_id
	var slot_data: Dictionary = solve_result.get(slot_id, {})
	return slot_data.get(key, Vector3.ZERO) as Vector3

func _resolve_support_slot_id(solve_result: Dictionary) -> StringName:
	var dominant_slot_id: StringName = solve_result.get("dominant_slot_id", &"hand_right")
	return &"hand_left" if dominant_slot_id == &"hand_right" else &"hand_right"

func _update_marker(debug_root: Node3D, marker_name: String, world_position: Vector3, color: Color, debug_visible: bool = true) -> void:
	var marker: MeshInstance3D = debug_root.get_node_or_null(marker_name) as MeshInstance3D
	if marker == null:
		marker = MeshInstance3D.new()
		marker.name = marker_name
		debug_root.add_child(marker)
	var sphere_mesh: SphereMesh = marker.mesh as SphereMesh
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = MARKER_RADIUS
		sphere_mesh.height = MARKER_RADIUS * 2.0
		marker.mesh = sphere_mesh
	var material: StandardMaterial3D = marker.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		marker.material_override = material
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	marker.visible = debug_visible and world_position.length_squared() > 0.000001
	if marker.visible:
		marker.global_position = world_position

func _update_slot_proxy_markers(debug_root: Node3D, marker_prefix: String, sample_positions: Array, color: Color, debug_visible: bool = true) -> void:
	var marker_count: int = 4
	for sample_index: int in range(marker_count):
		var marker_name: String = "%s_%d" % [marker_prefix, sample_index]
		var sample_world: Vector3 = Vector3.ZERO
		if sample_index < sample_positions.size():
			var sample_variant: Variant = sample_positions[sample_index]
			if sample_variant is Vector3:
				sample_world = sample_variant
		_update_marker(debug_root, marker_name, sample_world, color, debug_visible)
