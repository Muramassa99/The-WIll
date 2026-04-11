extends RefCounted
class_name HandTargetConstraintSolver

const BODY_RESTRICTION_COLLISION_LAYER := 1 << 25
const BODY_RESTRICTION_COLLISION_MASK := BODY_RESTRICTION_COLLISION_LAYER

const CHEST_BONE: StringName = &"CC_Base_Spine02"
const ABDOMEN_BONE: StringName = &"CC_Base_Waist"
const HIP_BONE: StringName = &"CC_Base_Hip"
const LEFT_SHOULDER_BONE: StringName = &"CC_Base_L_Clavicle"
const RIGHT_SHOULDER_BONE: StringName = &"CC_Base_R_Clavicle"

const DEFAULT_SETTINGS := {
	"safety_margin_meters": 0.08,
	"front_bias_amount": 0.18,
	"rear_threshold": -0.02,
	"orbit_radius_meters": 0.14,
	"orbit_radius_scale": 1.5,
	"orbit_vertical_bias": 0.04,
	"orbit_sample_count": 10,
}

func get_body_restriction_collision_mask() -> int:
	return BODY_RESTRICTION_COLLISION_MASK

func ensure_body_restriction_root(rig_root: Node3D, skeleton: Skeleton3D) -> Node3D:
	if rig_root == null or skeleton == null:
		return null
	var restriction_root: Node3D = rig_root.get_node_or_null("BodyRestrictionRoot") as Node3D
	if restriction_root == null:
		restriction_root = Node3D.new()
		restriction_root.name = "BodyRestrictionRoot"
		rig_root.add_child(restriction_root)
	_ensure_restriction_attachment(
		restriction_root,
		"ChestRestrictionAttachment",
		CHEST_BONE,
		Vector3(0.0, 0.02, 0.03),
		Vector3(0.40, 0.34, 0.28),
		Color(0.85, 0.20, 0.20, 0.18)
	)
	_ensure_restriction_attachment(
		restriction_root,
		"AbdomenRestrictionAttachment",
		ABDOMEN_BONE,
		Vector3(0.0, 0.00, 0.02),
		Vector3(0.34, 0.30, 0.24),
		Color(0.90, 0.52, 0.12, 0.18)
	)
	_ensure_restriction_attachment(
		restriction_root,
		"HipRestrictionAttachment",
		HIP_BONE,
		Vector3(0.0, 0.00, 0.02),
		Vector3(0.38, 0.24, 0.24),
		Color(0.20, 0.48, 0.90, 0.18)
	)
	_ensure_restriction_attachment(
		restriction_root,
		"LeftShoulderRestrictionAttachment",
		LEFT_SHOULDER_BONE,
		Vector3(0.04, -0.02, 0.00),
		Vector3(0.14, 0.18, 0.16),
		Color(0.55, 0.30, 0.90, 0.16)
	)
	_ensure_restriction_attachment(
		restriction_root,
		"RightShoulderRestrictionAttachment",
		RIGHT_SHOULDER_BONE,
		Vector3(-0.04, -0.02, 0.00),
		Vector3(0.14, 0.18, 0.16),
		Color(0.55, 0.30, 0.90, 0.16)
	)
	sync_body_restriction_root(restriction_root, skeleton)
	return restriction_root

func sync_body_restriction_root(restriction_root: Node3D, skeleton: Skeleton3D) -> void:
	if restriction_root == null or skeleton == null:
		return
	for attachment_node: Node in restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var bone_name: StringName = attachment.get_meta("bone_name", StringName()) as StringName
		if bone_name == StringName():
			continue
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var bone_pose: Transform3D = skeleton.get_bone_global_pose(bone_index)
		attachment.global_transform = skeleton.global_transform * bone_pose

func project_target_to_legal_grip_space(
	body_restriction_root: Node3D,
	source_world: Vector3,
	desired_world: Vector3,
	chest_origin_world: Vector3,
	chest_forward_world: Vector3,
	chest_right_world: Vector3,
	chest_up_world: Vector3,
	settings: Dictionary = {},
	query_exclusions: Array = []
) -> Dictionary:
	var merged_settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	for key_variant: Variant in settings.keys():
		merged_settings[key_variant] = settings.get(key_variant)
	var result := {
		"desired_target": desired_world,
		"corrected_target": desired_world,
		"path_illegal": false,
		"point_illegal": false,
		"front_bias_failed": false,
		"used_orbit": false,
	}
	if body_restriction_root == null:
		return result
	result["path_illegal"] = _segment_hits_body_restriction(
		body_restriction_root,
		source_world,
		desired_world,
		query_exclusions
	)
	result["point_illegal"] = _point_inside_body_restriction(body_restriction_root, desired_world)
	var target_offset: Vector3 = desired_world - chest_origin_world
	var chest_forward: Vector3 = chest_forward_world.normalized()
	if chest_forward.length_squared() <= 0.000001:
		chest_forward = Vector3.FORWARD
	result["front_bias_failed"] = target_offset.dot(chest_forward) < float(merged_settings.get("rear_threshold", -0.02))
	if not result["path_illegal"] and not result["point_illegal"] and not result["front_bias_failed"]:
		return result
	var corrected_target: Vector3 = _resolve_best_orbit_candidate(
		body_restriction_root,
		source_world,
		desired_world,
		chest_origin_world,
		chest_forward,
		chest_right_world.normalized(),
		chest_up_world.normalized(),
		merged_settings,
		query_exclusions
	)
	if corrected_target.length_squared() > 0.000001:
		result["corrected_target"] = corrected_target
		result["used_orbit"] = true
		return result
	var front_offset: float = maxf(float(merged_settings.get("front_bias_amount", 0.18)), float(merged_settings.get("safety_margin_meters", 0.08)))
	result["corrected_target"] = desired_world + chest_forward * front_offset
	return result

func _ensure_restriction_attachment(
	restriction_root: Node3D,
	attachment_name: String,
	bone_name: StringName,
	local_offset: Vector3,
	box_size: Vector3,
	debug_color: Color
) -> void:
	var attachment: Node3D = restriction_root.get_node_or_null(attachment_name) as Node3D
	if attachment == null:
		attachment = Node3D.new()
		attachment.name = attachment_name
		restriction_root.add_child(attachment)
	attachment.set_meta("bone_name", bone_name)
	attachment.position = Vector3.ZERO
	attachment.rotation = Vector3.ZERO
	var area: Area3D = attachment.get_node_or_null("RestrictionArea") as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "RestrictionArea"
		attachment.add_child(area)
	area.collision_layer = BODY_RESTRICTION_COLLISION_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var collision_shape: CollisionShape3D = area.get_node_or_null("RestrictionShape") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "RestrictionShape"
		area.add_child(collision_shape)
	var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
	if box_shape == null:
		box_shape = BoxShape3D.new()
		collision_shape.shape = box_shape
	box_shape.size = box_size
	collision_shape.position = local_offset
	var debug_mesh: MeshInstance3D = attachment.get_node_or_null("RestrictionDebug") as MeshInstance3D
	if debug_mesh == null:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = "RestrictionDebug"
		attachment.add_child(debug_mesh)
	var box_mesh: BoxMesh = debug_mesh.mesh as BoxMesh
	if box_mesh == null:
		box_mesh = BoxMesh.new()
		debug_mesh.mesh = box_mesh
	box_mesh.size = box_size
	debug_mesh.position = local_offset
	var debug_material: StandardMaterial3D = debug_mesh.material_override as StandardMaterial3D
	if debug_material == null:
		debug_material = StandardMaterial3D.new()
		debug_mesh.material_override = debug_material
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color = debug_color
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.no_depth_test = true

func _segment_hits_body_restriction(
	body_restriction_root: Node3D,
	from_world: Vector3,
	to_world: Vector3,
	query_exclusions: Array
) -> bool:
	if body_restriction_root == null or from_world.distance_to(to_world) <= 0.000001:
		return false
	var world_3d: World3D = body_restriction_root.get_world_3d()
	if world_3d == null:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_world,
		to_world,
		BODY_RESTRICTION_COLLISION_MASK
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.hit_from_inside = true
	if not query_exclusions.is_empty():
		query.exclude = query_exclusions
	var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _point_inside_body_restriction(body_restriction_root: Node3D, point_world: Vector3) -> bool:
	if body_restriction_root == null:
		return false
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var area: Area3D = attachment.get_node_or_null("RestrictionArea") as Area3D
		if area == null:
			continue
		var collision_shape: CollisionShape3D = area.get_node_or_null("RestrictionShape") as CollisionShape3D
		if collision_shape == null:
			continue
		var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
		if box_shape == null:
			continue
		var local_point: Vector3 = collision_shape.global_transform.affine_inverse() * point_world
		var half_size: Vector3 = box_shape.size * 0.5
		if absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y and absf(local_point.z) <= half_size.z:
			return true
	return false

func _resolve_best_orbit_candidate(
	body_restriction_root: Node3D,
	source_world: Vector3,
	desired_world: Vector3,
	chest_origin_world: Vector3,
	chest_forward_world: Vector3,
	chest_right_world: Vector3,
	chest_up_world: Vector3,
	settings: Dictionary,
	query_exclusions: Array
) -> Vector3:
	var best_candidate: Vector3 = Vector3.ZERO
	var best_score: float = INF
	var safety_margin: float = float(settings.get("safety_margin_meters", 0.08))
	var orbit_radius: float = maxf(float(settings.get("orbit_radius_meters", 0.14)), safety_margin)
	var orbit_radius_scale: float = maxf(float(settings.get("orbit_radius_scale", 1.5)), 1.0)
	var vertical_bias: float = float(settings.get("orbit_vertical_bias", 0.04))
	var sample_count: int = max(4, int(settings.get("orbit_sample_count", 10)))
	for radius_scale: float in [1.0, orbit_radius_scale]:
		var radius: float = orbit_radius * radius_scale
		for sample_index: int in range(sample_count):
			var angle: float = (TAU / float(sample_count)) * float(sample_index)
			var orbit_offset: Vector3 = (
				chest_right_world * cos(angle) * radius
				+ chest_up_world * sin(angle) * radius * 0.45
				+ chest_forward_world * vertical_bias
			)
			var candidate: Vector3 = desired_world + orbit_offset
			if _point_inside_body_restriction(body_restriction_root, candidate):
				continue
			if _segment_hits_body_restriction(body_restriction_root, source_world, candidate, query_exclusions):
				continue
			var forward_score: float = maxf(0.0, -(candidate - chest_origin_world).dot(chest_forward_world)) * 4.0
			var distance_score: float = candidate.distance_squared_to(desired_world)
			var score: float = distance_score + forward_score
			if score < best_score:
				best_score = score
				best_candidate = candidate
	return best_candidate
