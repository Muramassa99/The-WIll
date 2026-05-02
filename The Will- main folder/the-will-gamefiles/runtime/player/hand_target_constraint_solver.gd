extends RefCounted
class_name HandTargetConstraintSolver

const ClearanceProxyBuilderScript = preload("res://runtime/player/clearance_proxy_builder.gd")

const BODY_RESTRICTION_COLLISION_LAYER := 1 << 25
const BODY_RESTRICTION_COLLISION_MASK := BODY_RESTRICTION_COLLISION_LAYER
const DEFAULT_BODY_CLEARANCE_OFFSET_METERS := 0.005

const CHEST_BONE: StringName = &"CC_Base_Spine02"
const ABDOMEN_BONE: StringName = &"CC_Base_Waist"
const HIP_BONE: StringName = &"CC_Base_Hip"
const LEFT_SHOULDER_BONE: StringName = &"CC_Base_L_Clavicle"
const RIGHT_SHOULDER_BONE: StringName = &"CC_Base_R_Clavicle"
const LEFT_UPPERARM_BONE: StringName = &"CC_Base_L_Upperarm"
const LEFT_FOREARM_BONE: StringName = &"CC_Base_L_Forearm"
const RIGHT_UPPERARM_BONE: StringName = &"CC_Base_R_Upperarm"
const RIGHT_FOREARM_BONE: StringName = &"CC_Base_R_Forearm"
const CHEST_FORWARD_FALLBACK_WORLD := Vector3(0.0, 0.0, 1.0)
const LEFT_SELF_RESTRICTION_ATTACHMENT_NAMES: Array[String] = [
	"LeftShoulderRestrictionAttachment",
	"LeftUpperarmRestrictionAttachment",
	"LeftForearmRestrictionAttachment",
]
const RIGHT_SELF_RESTRICTION_ATTACHMENT_NAMES: Array[String] = [
	"RightShoulderRestrictionAttachment",
	"RightUpperarmRestrictionAttachment",
	"RightForearmRestrictionAttachment",
]

const ANATOMICAL_NEIGHBOR_REGION_PAIRS: Array[Array] = [
	["torso_chest", "torso_abdomen"],
	["torso_chest", "left_shoulder"],
	["torso_chest", "right_shoulder"],
	["torso_chest", "left_upperarm"],
	["torso_chest", "right_upperarm"],
	["torso_chest", "head"],
	["torso_abdomen", "pelvis"],
	["pelvis", "left_thigh"],
	["pelvis", "right_thigh"],
	["left_shoulder", "right_shoulder"],
	["left_shoulder", "head"],
	["right_shoulder", "head"],
	["left_shoulder", "left_upperarm"],
	["left_upperarm", "left_forearm"],
	["right_shoulder", "right_upperarm"],
	["right_upperarm", "right_forearm"],
	["left_thigh", "right_thigh"],
	["left_thigh", "left_calf"],
	["right_thigh", "right_calf"],
]

const ANATOMICAL_SOFT_CONTACT_OVERLAP_TOLERANCE_METERS := 0.04
const ANATOMICAL_SOFT_CONTACT_REGION_PAIRS: Array[Array] = [
	["torso_chest", "left_forearm"],
	["torso_chest", "right_forearm"],
	["torso_abdomen", "left_upperarm"],
	["torso_abdomen", "right_upperarm"],
	["torso_abdomen", "left_forearm"],
	["torso_abdomen", "right_forearm"],
	["pelvis", "left_forearm"],
	["pelvis", "right_forearm"],
]

const DEFAULT_SETTINGS := {
	"safety_margin_meters": 0.08,
	"front_bias_amount": 0.18,
	"rear_threshold": -0.02,
	"orbit_radius_meters": 0.14,
	"orbit_radius_scale": 1.5,
	"orbit_vertical_bias": 0.04,
	"orbit_sample_count": 10,
	"allow_alternate_target_correction": true,
	"enforce_path_restriction": true,
	"enforce_front_bias": true,
}

func get_body_restriction_collision_mask() -> int:
	return BODY_RESTRICTION_COLLISION_MASK

func ensure_body_restriction_root(
	rig_root: Node3D,
	skeleton: Skeleton3D,
	mesh_instance: MeshInstance3D = null,
	clearance_offset_meters: float = DEFAULT_BODY_CLEARANCE_OFFSET_METERS
) -> Node3D:
	if rig_root == null or skeleton == null:
		return null
	var restriction_root: Node3D = rig_root.get_node_or_null("BodyRestrictionRoot") as Node3D
	if restriction_root == null:
		restriction_root = Node3D.new()
		restriction_root.name = "BodyRestrictionRoot"
		rig_root.add_child(restriction_root)
	var clearance_offset: float = maxf(clearance_offset_meters, 0.0)
	var clearance_proxy_builder = ClearanceProxyBuilderScript.new()
	var descriptors: Array[Dictionary] = clearance_proxy_builder.build_body_proxy_descriptors(
		rig_root,
		skeleton,
		mesh_instance,
		clearance_offset
	)
	if not descriptors.is_empty():
		_apply_body_restriction_descriptors(restriction_root, descriptors)
		restriction_root.set_meta("proxy_source", ClearanceProxyBuilderScript.SOURCE_MESH_DERIVED)
		restriction_root.set_meta("clearance_offset_meters", clearance_offset)
		restriction_root.set_meta("proxy_descriptor_count", descriptors.size())
		restriction_root.set_meta("source_mesh_aabb_size", descriptors[0].get("source_mesh_aabb_size", Vector3.ZERO))
		sync_body_restriction_root(restriction_root, skeleton)
		return restriction_root
	_prune_restriction_attachments(restriction_root, [
		"ChestRestrictionAttachment",
		"AbdomenRestrictionAttachment",
		"HipRestrictionAttachment",
		"LeftShoulderRestrictionAttachment",
		"RightShoulderRestrictionAttachment",
		"LeftUpperarmRestrictionAttachment",
		"LeftForearmRestrictionAttachment",
		"RightUpperarmRestrictionAttachment",
		"RightForearmRestrictionAttachment",
	])
	restriction_root.set_meta("proxy_source", ClearanceProxyBuilderScript.SOURCE_FALLBACK_ANATOMY)
	restriction_root.set_meta("clearance_offset_meters", clearance_offset)
	restriction_root.set_meta("proxy_descriptor_count", 9)
	restriction_root.set_meta("source_mesh_aabb_size", Vector3.ZERO)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"ChestRestrictionAttachment",
		CHEST_BONE,
		Vector3(0.0, 0.02, 0.03),
		0.21,
		0.40,
		Color(0.85, 0.20, 0.20, 0.18)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"AbdomenRestrictionAttachment",
		ABDOMEN_BONE,
		Vector3(0.0, 0.00, 0.02),
		0.18,
		0.36,
		Color(0.90, 0.52, 0.12, 0.18)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"HipRestrictionAttachment",
		HIP_BONE,
		Vector3(0.0, 0.00, 0.02),
		0.20,
		0.32,
		Color(0.20, 0.48, 0.90, 0.18)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"LeftShoulderRestrictionAttachment",
		LEFT_SHOULDER_BONE,
		Vector3(0.04, -0.02, 0.00),
		0.09,
		0.22,
		Color(0.55, 0.30, 0.90, 0.16)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"RightShoulderRestrictionAttachment",
		RIGHT_SHOULDER_BONE,
		Vector3(-0.04, -0.02, 0.00),
		0.09,
		0.22,
		Color(0.55, 0.30, 0.90, 0.16)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"LeftUpperarmRestrictionAttachment",
		LEFT_UPPERARM_BONE,
		Vector3(0.0, -0.13, 0.0),
		0.055,
		0.26,
		Color(0.20, 0.75, 0.45, 0.16)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"LeftForearmRestrictionAttachment",
		LEFT_FOREARM_BONE,
		Vector3(0.0, -0.12, 0.0),
		0.045,
		0.24,
		Color(0.20, 0.75, 0.45, 0.16)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"RightUpperarmRestrictionAttachment",
		RIGHT_UPPERARM_BONE,
		Vector3(0.0, -0.13, 0.0),
		0.055,
		0.26,
		Color(0.20, 0.75, 0.45, 0.16)
	)
	_ensure_capsule_restriction_attachment(
		restriction_root,
		"RightForearmRestrictionAttachment",
		RIGHT_FOREARM_BONE,
		Vector3(0.0, -0.12, 0.0),
		0.045,
		0.24,
		Color(0.20, 0.75, 0.45, 0.16)
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
	var enforce_path_restriction: bool = bool(merged_settings.get("enforce_path_restriction", true))
	if enforce_path_restriction:
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
		chest_forward = CHEST_FORWARD_FALLBACK_WORLD
	var enforce_front_bias: bool = bool(merged_settings.get("enforce_front_bias", true))
	result["front_bias_failed"] = (
		enforce_front_bias
		and target_offset.dot(chest_forward) < float(merged_settings.get("rear_threshold", -0.02))
	)
	if not result["path_illegal"] and not result["point_illegal"] and not result["front_bias_failed"]:
		return result
	if not bool(merged_settings.get("allow_alternate_target_correction", true)):
		result["alternate_target_correction_disabled"] = true
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

func point_inside_body_restriction(body_restriction_root: Node3D, point_world: Vector3) -> bool:
	return _point_inside_body_restriction(body_restriction_root, point_world)

func segment_hits_body_restriction(
	body_restriction_root: Node3D,
	from_world: Vector3,
	to_world: Vector3,
	query_exclusions: Array = []
) -> bool:
	return _segment_hits_body_restriction(body_restriction_root, from_world, to_world, query_exclusions)

func query_point_body_restriction(body_restriction_root: Node3D, point_world: Vector3) -> Dictionary:
	var result := {
		"legal": true,
		"inside": false,
		"body_region": "",
		"attachment_name": "",
		"shape_kind": StringName(),
		"estimated_clearance_meters": INF,
		"suggested_correction_world": Vector3.ZERO,
		"point_world": point_world,
	}
	if body_restriction_root == null:
		result["estimated_clearance_meters"] = -1.0
		return result
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var area: Area3D = attachment.get_node_or_null("RestrictionArea") as Area3D
		if area == null:
			continue
		var collision_shape: CollisionShape3D = area.get_node_or_null("RestrictionShape") as CollisionShape3D
		if collision_shape == null or collision_shape.shape == null:
			continue
		var shape_result: Dictionary = _query_point_against_restriction_shape(collision_shape, point_world)
		var clearance: float = float(shape_result.get("estimated_clearance_meters", INF))
		if bool(shape_result.get("inside", false)):
			shape_result["legal"] = false
			shape_result["body_region"] = String(attachment.get_meta("proxy_region", ""))
			shape_result["attachment_name"] = String(attachment.name)
			shape_result["point_world"] = point_world
			return shape_result
		if clearance < float(result.get("estimated_clearance_meters", INF)):
			result["estimated_clearance_meters"] = clearance
			result["body_region"] = String(attachment.get_meta("proxy_region", ""))
			result["attachment_name"] = String(attachment.name)
			result["shape_kind"] = shape_result.get("shape_kind", StringName())
	if float(result.get("estimated_clearance_meters", INF)) == INF:
		result["estimated_clearance_meters"] = -1.0
	return result

func evaluate_body_self_collision(body_restriction_root: Node3D) -> Dictionary:
	var result := {
		"legal": true,
		"checked_pair_count": 0,
		"overlap_pair_count": 0,
		"allowed_overlap_pair_count": 0,
		"illegal_pair_count": 0,
		"illegal_pairs": [],
		"first_illegal_pair": {},
		"first_allowed_overlap_pair": {},
		"minimum_clearance_meters": INF,
	}
	if body_restriction_root == null:
		result["minimum_clearance_meters"] = -1.0
		return result
	var proxies: Array[Dictionary] = _collect_body_restriction_proxy_descriptors(body_restriction_root)
	for first_index: int in range(proxies.size()):
		var first_proxy: Dictionary = proxies[first_index]
		for second_index: int in range(first_index + 1, proxies.size()):
			var second_proxy: Dictionary = proxies[second_index]
			var pair_result: Dictionary = _query_body_proxy_pair_clearance(first_proxy, second_proxy)
			if pair_result.is_empty():
				continue
			result["checked_pair_count"] = int(result.get("checked_pair_count", 0)) + 1
			var clearance: float = float(pair_result.get("clearance_meters", INF))
			if clearance < float(result.get("minimum_clearance_meters", INF)):
				result["minimum_clearance_meters"] = clearance
			if not bool(pair_result.get("overlapping", false)):
				continue
			result["overlap_pair_count"] = int(result.get("overlap_pair_count", 0)) + 1
			var allowed_neighbor: bool = _body_proxy_pair_allows_anatomical_overlap(first_proxy, second_proxy, clearance)
			pair_result["allowed_anatomical_neighbor"] = allowed_neighbor
			if allowed_neighbor:
				result["allowed_overlap_pair_count"] = int(result.get("allowed_overlap_pair_count", 0)) + 1
				if (result.get("first_allowed_overlap_pair", {}) as Dictionary).is_empty():
					result["first_allowed_overlap_pair"] = pair_result
				continue
			result["legal"] = false
			result["illegal_pair_count"] = int(result.get("illegal_pair_count", 0)) + 1
			var illegal_pairs: Array = result.get("illegal_pairs", []) as Array
			if illegal_pairs.size() < 12:
				illegal_pairs.append(pair_result)
				result["illegal_pairs"] = illegal_pairs
			if (result.get("first_illegal_pair", {}) as Dictionary).is_empty():
				result["first_illegal_pair"] = pair_result
	if float(result.get("minimum_clearance_meters", INF)) == INF:
		result["minimum_clearance_meters"] = -1.0
	return result

func build_arm_self_query_exclusions(body_restriction_root: Node3D, slot_id: StringName) -> Array:
	if body_restriction_root == null:
		return []
	var attachment_names: Array[String] = (
		LEFT_SELF_RESTRICTION_ATTACHMENT_NAMES
		if slot_id == &"hand_left"
		else RIGHT_SELF_RESTRICTION_ATTACHMENT_NAMES
	)
	return _collect_attachment_area_rids(body_restriction_root, attachment_names)

func _ensure_restriction_attachment(
	restriction_root: Node3D,
	attachment_name: String,
	bone_name: StringName,
	local_offset: Vector3,
	box_size: Vector3,
	debug_color: Color,
	metadata: Dictionary = {}
) -> Node3D:
	var attachment: Node3D = restriction_root.get_node_or_null(attachment_name) as Node3D
	if attachment == null:
		attachment = Node3D.new()
		attachment.name = attachment_name
		restriction_root.add_child(attachment)
	attachment.set_meta("bone_name", bone_name)
	_apply_attachment_metadata(attachment, &"box", local_offset, metadata)
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
	debug_mesh.visible = false
	return attachment

func _ensure_capsule_restriction_attachment(
	restriction_root: Node3D,
	attachment_name: String,
	bone_name: StringName,
	local_offset: Vector3,
	capsule_radius: float,
	capsule_height: float,
	debug_color: Color,
	metadata: Dictionary = {}
) -> Node3D:
	var attachment: Node3D = restriction_root.get_node_or_null(attachment_name) as Node3D
	if attachment == null:
		attachment = Node3D.new()
		attachment.name = attachment_name
		restriction_root.add_child(attachment)
	attachment.set_meta("bone_name", bone_name)
	_apply_attachment_metadata(attachment, &"capsule", local_offset, metadata)
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
	var capsule_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if capsule_shape == null:
		capsule_shape = CapsuleShape3D.new()
		collision_shape.shape = capsule_shape
	capsule_shape.radius = capsule_radius
	capsule_shape.height = capsule_height
	collision_shape.position = local_offset
	var debug_mesh: MeshInstance3D = attachment.get_node_or_null("RestrictionDebug") as MeshInstance3D
	if debug_mesh == null:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = "RestrictionDebug"
		attachment.add_child(debug_mesh)
	var capsule_mesh: CapsuleMesh = debug_mesh.mesh as CapsuleMesh
	if capsule_mesh == null:
		capsule_mesh = CapsuleMesh.new()
		debug_mesh.mesh = capsule_mesh
	capsule_mesh.radius = capsule_radius
	capsule_mesh.height = capsule_height
	debug_mesh.position = local_offset
	var debug_material: StandardMaterial3D = debug_mesh.material_override as StandardMaterial3D
	if debug_material == null:
		debug_material = StandardMaterial3D.new()
		debug_mesh.material_override = debug_material
	debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	debug_material.albedo_color = debug_color
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.no_depth_test = true
	debug_mesh.visible = false
	return attachment

func _apply_body_restriction_descriptors(restriction_root: Node3D, descriptors: Array[Dictionary]) -> void:
	var desired_names: Array[String] = []
	for descriptor: Dictionary in descriptors:
		var attachment_name: String = String(descriptor.get("name", ""))
		if attachment_name.is_empty():
			continue
		desired_names.append(attachment_name)
	_prune_restriction_attachments(restriction_root, desired_names)
	for descriptor: Dictionary in descriptors:
		var attachment_name: String = String(descriptor.get("name", ""))
		if attachment_name.is_empty():
			continue
		var shape_kind: StringName = descriptor.get("shape", &"box") as StringName
		if shape_kind == &"capsule":
			_ensure_capsule_restriction_attachment(
				restriction_root,
				attachment_name,
				descriptor.get("bone_name", StringName()) as StringName,
				descriptor.get("local_offset", Vector3.ZERO) as Vector3,
				maxf(float(descriptor.get("capsule_radius", 0.025)), 0.005),
				maxf(float(descriptor.get("capsule_height", 0.05)), 0.01),
				descriptor.get("debug_color", Color(0.20, 0.75, 0.45, 0.16)) as Color,
				descriptor
			)
			continue
		_ensure_restriction_attachment(
			restriction_root,
			attachment_name,
			descriptor.get("bone_name", StringName()) as StringName,
			descriptor.get("local_offset", Vector3.ZERO) as Vector3,
			descriptor.get("box_size", Vector3.ONE * 0.1) as Vector3,
			descriptor.get("debug_color", Color(0.85, 0.20, 0.20, 0.18)) as Color,
			descriptor
		)

func _prune_restriction_attachments(restriction_root: Node3D, desired_names: Array[String]) -> void:
	if restriction_root == null:
		return
	for attachment_node: Node in restriction_root.get_children():
		if desired_names.has(String(attachment_node.name)):
			continue
		restriction_root.remove_child(attachment_node)
		attachment_node.queue_free()

func _apply_attachment_metadata(
	attachment: Node3D,
	shape_kind: StringName,
	local_offset: Vector3,
	metadata: Dictionary
) -> void:
	if attachment == null:
		return
	attachment.set_meta("proxy_shape", shape_kind)
	attachment.set_meta("restriction_local_offset", local_offset)
	attachment.set_meta("proxy_source", metadata.get("proxy_source", ClearanceProxyBuilderScript.SOURCE_FALLBACK_ANATOMY))
	attachment.set_meta("proxy_region", String(metadata.get("region", "")))
	attachment.set_meta("clearance_offset_meters", float(metadata.get("clearance_offset_meters", 0.0)))
	if metadata.has("source_mesh_aabb_size"):
		attachment.set_meta("source_mesh_aabb_size", metadata.get("source_mesh_aabb_size"))
	if metadata.has("end_bone_name"):
		attachment.set_meta("end_bone_name", metadata.get("end_bone_name"))

func _collect_attachment_area_rids(body_restriction_root: Node3D, attachment_names: Array[String]) -> Array:
	var exclusions: Array = []
	if body_restriction_root == null:
		return exclusions
	for attachment_name: String in attachment_names:
		var attachment: Node3D = body_restriction_root.get_node_or_null(attachment_name) as Node3D
		if attachment == null:
			continue
		var area: Area3D = attachment.get_node_or_null("RestrictionArea") as Area3D
		if area == null:
			continue
		exclusions.append(area.get_rid())
	return exclusions

func _collect_body_restriction_proxy_descriptors(body_restriction_root: Node3D) -> Array[Dictionary]:
	var proxies: Array[Dictionary] = []
	if body_restriction_root == null:
		return proxies
	for attachment_node: Node in body_restriction_root.get_children():
		var attachment: Node3D = attachment_node as Node3D
		if attachment == null:
			continue
		var area: Area3D = attachment.get_node_or_null("RestrictionArea") as Area3D
		if area == null:
			continue
		var collision_shape: CollisionShape3D = area.get_node_or_null("RestrictionShape") as CollisionShape3D
		if collision_shape == null or collision_shape.shape == null:
			continue
		proxies.append({
			"attachment": attachment,
			"attachment_name": String(attachment.name),
			"region": String(attachment.get_meta("proxy_region", "")),
			"bone_name": attachment.get_meta("bone_name", StringName()) as StringName,
			"end_bone_name": attachment.get_meta("end_bone_name", StringName()) as StringName,
			"shape": collision_shape.shape,
			"collision_shape": collision_shape,
			"shape_kind": attachment.get_meta("proxy_shape", StringName()) as StringName,
		})
	return proxies

func _query_body_proxy_pair_clearance(first_proxy: Dictionary, second_proxy: Dictionary) -> Dictionary:
	var first_shape: Shape3D = first_proxy.get("shape", null) as Shape3D
	var second_shape: Shape3D = second_proxy.get("shape", null) as Shape3D
	var first_collision_shape: CollisionShape3D = first_proxy.get("collision_shape", null) as CollisionShape3D
	var second_collision_shape: CollisionShape3D = second_proxy.get("collision_shape", null) as CollisionShape3D
	if first_shape == null or second_shape == null or first_collision_shape == null or second_collision_shape == null:
		return {}
	var first_capsule: CapsuleShape3D = first_shape as CapsuleShape3D
	var second_capsule: CapsuleShape3D = second_shape as CapsuleShape3D
	if first_capsule != null and second_capsule != null:
		return _query_capsule_proxy_pair_clearance(first_proxy, first_collision_shape, first_capsule, second_proxy, second_collision_shape, second_capsule)
	return _query_sampled_proxy_pair_clearance(first_proxy, first_collision_shape, first_shape, second_proxy, second_collision_shape, second_shape)

func _query_capsule_proxy_pair_clearance(
	first_proxy: Dictionary,
	first_collision_shape: CollisionShape3D,
	first_capsule: CapsuleShape3D,
	second_proxy: Dictionary,
	second_collision_shape: CollisionShape3D,
	second_capsule: CapsuleShape3D
) -> Dictionary:
	var first_segment: Dictionary = _resolve_capsule_axis_segment_world(first_collision_shape, first_capsule)
	var second_segment: Dictionary = _resolve_capsule_axis_segment_world(second_collision_shape, second_capsule)
	var first_start: Vector3 = first_segment.get("start", Vector3.ZERO) as Vector3
	var first_end: Vector3 = first_segment.get("end", Vector3.ZERO) as Vector3
	var second_start: Vector3 = second_segment.get("start", Vector3.ZERO) as Vector3
	var second_end: Vector3 = second_segment.get("end", Vector3.ZERO) as Vector3
	var axis_distance: float = _closest_distance_between_segments(first_start, first_end, second_start, second_end)
	var clearance: float = axis_distance - first_capsule.radius - second_capsule.radius
	return _build_body_proxy_pair_result(first_proxy, second_proxy, clearance)

func _query_sampled_proxy_pair_clearance(
	first_proxy: Dictionary,
	first_collision_shape: CollisionShape3D,
	first_shape: Shape3D,
	second_proxy: Dictionary,
	second_collision_shape: CollisionShape3D,
	second_shape: Shape3D
) -> Dictionary:
	var first_points: Array[Vector3] = _sample_restriction_shape_world_points(first_collision_shape, first_shape)
	var second_points: Array[Vector3] = _sample_restriction_shape_world_points(second_collision_shape, second_shape)
	var best_clearance: float = INF
	for first_point: Vector3 in first_points:
		var second_result: Dictionary = _query_point_against_restriction_shape(second_collision_shape, first_point)
		best_clearance = minf(best_clearance, float(second_result.get("estimated_clearance_meters", INF)))
	for second_point: Vector3 in second_points:
		var first_result: Dictionary = _query_point_against_restriction_shape(first_collision_shape, second_point)
		best_clearance = minf(best_clearance, float(first_result.get("estimated_clearance_meters", INF)))
	if best_clearance == INF:
		return {}
	return _build_body_proxy_pair_result(first_proxy, second_proxy, best_clearance)

func _build_body_proxy_pair_result(first_proxy: Dictionary, second_proxy: Dictionary, clearance: float) -> Dictionary:
	return {
		"overlapping": clearance < 0.0,
		"clearance_meters": clearance,
		"first_attachment_name": String(first_proxy.get("attachment_name", "")),
		"second_attachment_name": String(second_proxy.get("attachment_name", "")),
		"first_region": String(first_proxy.get("region", "")),
		"second_region": String(second_proxy.get("region", "")),
		"first_bone_name": String(first_proxy.get("bone_name", StringName())),
		"second_bone_name": String(second_proxy.get("bone_name", StringName())),
	}

func _resolve_capsule_axis_segment_world(collision_shape: CollisionShape3D, capsule_shape: CapsuleShape3D) -> Dictionary:
	var half_mid: float = maxf(capsule_shape.height * 0.5 - capsule_shape.radius, 0.0)
	var axis_world: Vector3 = collision_shape.global_basis.y.normalized()
	if axis_world.length_squared() <= 0.000001:
		axis_world = Vector3.UP
	var origin_world: Vector3 = collision_shape.global_position
	return {
		"start": origin_world - axis_world * half_mid,
		"end": origin_world + axis_world * half_mid,
	}

func _sample_restriction_shape_world_points(collision_shape: CollisionShape3D, shape: Shape3D) -> Array[Vector3]:
	var points: Array[Vector3] = [collision_shape.global_position]
	var capsule_shape: CapsuleShape3D = shape as CapsuleShape3D
	if capsule_shape != null:
		var segment: Dictionary = _resolve_capsule_axis_segment_world(collision_shape, capsule_shape)
		points.append(segment.get("start", collision_shape.global_position) as Vector3)
		points.append(segment.get("end", collision_shape.global_position) as Vector3)
		return points
	var box_shape: BoxShape3D = shape as BoxShape3D
	if box_shape != null:
		var half_size: Vector3 = box_shape.size * 0.5
		for x_sign: float in [-1.0, 1.0]:
			for y_sign: float in [-1.0, 1.0]:
				for z_sign: float in [-1.0, 1.0]:
					points.append(collision_shape.global_transform * Vector3(half_size.x * x_sign, half_size.y * y_sign, half_size.z * z_sign))
	return points

func _body_proxy_pair_allows_anatomical_overlap(first_proxy: Dictionary, second_proxy: Dictionary, clearance_meters: float) -> bool:
	var first_region: String = String(first_proxy.get("region", ""))
	var second_region: String = String(second_proxy.get("region", ""))
	if not first_region.is_empty() and first_region == second_region:
		return true
	var first_bone: StringName = first_proxy.get("bone_name", StringName()) as StringName
	var second_bone: StringName = second_proxy.get("bone_name", StringName()) as StringName
	var first_end_bone: StringName = first_proxy.get("end_bone_name", StringName()) as StringName
	var second_end_bone: StringName = second_proxy.get("end_bone_name", StringName()) as StringName
	if first_bone != StringName() and first_bone == second_bone:
		return true
	if first_end_bone != StringName() and first_end_bone == second_bone:
		return true
	if second_end_bone != StringName() and second_end_bone == first_bone:
		return true
	if _regions_are_anatomical_neighbors(first_region, second_region):
		return true
	if _regions_are_soft_contact_neighbors(first_region, second_region):
		return clearance_meters >= -ANATOMICAL_SOFT_CONTACT_OVERLAP_TOLERANCE_METERS
	return false

func _regions_are_anatomical_neighbors(first_region: String, second_region: String) -> bool:
	if first_region.is_empty() or second_region.is_empty():
		return false
	for pair: Array in ANATOMICAL_NEIGHBOR_REGION_PAIRS:
		if pair.size() < 2:
			continue
		var region_a: String = String(pair[0])
		var region_b: String = String(pair[1])
		if (first_region == region_a and second_region == region_b) or (first_region == region_b and second_region == region_a):
			return true
	return false

func _regions_are_soft_contact_neighbors(first_region: String, second_region: String) -> bool:
	if first_region.is_empty() or second_region.is_empty():
		return false
	for pair: Array in ANATOMICAL_SOFT_CONTACT_REGION_PAIRS:
		if pair.size() < 2:
			continue
		var region_a: String = String(pair[0])
		var region_b: String = String(pair[1])
		if (first_region == region_a and second_region == region_b) or (first_region == region_b and second_region == region_a):
			return true
	return false

func _closest_distance_between_segments(first_start: Vector3, first_end: Vector3, second_start: Vector3, second_end: Vector3) -> float:
	var first_direction: Vector3 = first_end - first_start
	var second_direction: Vector3 = second_end - second_start
	var between_start: Vector3 = first_start - second_start
	var first_length_squared: float = first_direction.length_squared()
	var second_length_squared: float = second_direction.length_squared()
	if first_length_squared <= 0.0000001 and second_length_squared <= 0.0000001:
		return first_start.distance_to(second_start)
	if first_length_squared <= 0.0000001:
		return _distance_point_to_segment(first_start, second_start, second_end)
	if second_length_squared <= 0.0000001:
		return _distance_point_to_segment(second_start, first_start, first_end)
	var first_dot_second: float = first_direction.dot(second_direction)
	var first_dot_between: float = first_direction.dot(between_start)
	var second_dot_between: float = second_direction.dot(between_start)
	var denominator: float = first_length_squared * second_length_squared - first_dot_second * first_dot_second
	var first_ratio: float = 0.0
	var second_ratio: float = 0.0
	if denominator > 0.0000001:
		first_ratio = clampf((first_dot_second * second_dot_between - second_length_squared * first_dot_between) / denominator, 0.0, 1.0)
	second_ratio = (first_dot_second * first_ratio + second_dot_between) / second_length_squared
	if second_ratio < 0.0:
		second_ratio = 0.0
		first_ratio = clampf(-first_dot_between / first_length_squared, 0.0, 1.0)
	elif second_ratio > 1.0:
		second_ratio = 1.0
		first_ratio = clampf((first_dot_second - first_dot_between) / first_length_squared, 0.0, 1.0)
	var first_closest: Vector3 = first_start + first_direction * first_ratio
	var second_closest: Vector3 = second_start + second_direction * second_ratio
	return first_closest.distance_to(second_closest)

func _distance_point_to_segment(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment: Vector3 = segment_end - segment_start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.0000001:
		return point.distance_to(segment_start)
	var ratio: float = clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(segment_start + segment * ratio)

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
		var shape: Shape3D = collision_shape.shape
		if shape == null:
			continue
		var local_point: Vector3 = collision_shape.global_transform.affine_inverse() * point_world
		var box_shape: BoxShape3D = shape as BoxShape3D
		if box_shape != null:
			var half_size: Vector3 = box_shape.size * 0.5
			if absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y and absf(local_point.z) <= half_size.z:
				return true
			continue
		var capsule_shape: CapsuleShape3D = shape as CapsuleShape3D
		if capsule_shape != null:
			var cap_radius: float = capsule_shape.radius
			var cap_half_height: float = capsule_shape.height * 0.5
			var half_mid: float = cap_half_height - cap_radius
			var clamped_y: float = clampf(local_point.y, -half_mid, half_mid)
			var closest_axis_point: Vector3 = Vector3(0.0, clamped_y, 0.0)
			if local_point.distance_to(closest_axis_point) <= cap_radius:
				return true
			continue
	return false

func _query_point_against_restriction_shape(collision_shape: CollisionShape3D, point_world: Vector3) -> Dictionary:
	var result := {
		"inside": false,
		"shape_kind": StringName(),
		"estimated_clearance_meters": INF,
		"suggested_correction_world": Vector3.ZERO,
	}
	if collision_shape == null or collision_shape.shape == null:
		result["estimated_clearance_meters"] = -1.0
		return result
	var local_point: Vector3 = collision_shape.global_transform.affine_inverse() * point_world
	var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
	if box_shape != null:
		return _query_point_against_box_shape(collision_shape, box_shape, local_point)
	var capsule_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	if capsule_shape != null:
		return _query_point_against_capsule_shape(collision_shape, capsule_shape, local_point)
	result["estimated_clearance_meters"] = -1.0
	return result

func _query_point_against_box_shape(
	collision_shape: CollisionShape3D,
	box_shape: BoxShape3D,
	local_point: Vector3
) -> Dictionary:
	var half_size: Vector3 = box_shape.size * 0.5
	var abs_point := Vector3(absf(local_point.x), absf(local_point.y), absf(local_point.z))
	var outside := Vector3(
		maxf(abs_point.x - half_size.x, 0.0),
		maxf(abs_point.y - half_size.y, 0.0),
		maxf(abs_point.z - half_size.z, 0.0)
	)
	var inside: bool = (
		abs_point.x <= half_size.x
		and abs_point.y <= half_size.y
		and abs_point.z <= half_size.z
	)
	if not inside:
		return {
			"inside": false,
			"shape_kind": &"box",
			"estimated_clearance_meters": outside.length(),
			"suggested_correction_world": Vector3.ZERO,
		}
	var x_depth: float = half_size.x - abs_point.x
	var y_depth: float = half_size.y - abs_point.y
	var z_depth: float = half_size.z - abs_point.z
	var correction_axis := Vector3(1.0 if local_point.x >= 0.0 else -1.0, 0.0, 0.0)
	var penetration_depth: float = x_depth
	if y_depth < penetration_depth:
		penetration_depth = y_depth
		correction_axis = Vector3(0.0, 1.0 if local_point.y >= 0.0 else -1.0, 0.0)
	if z_depth < penetration_depth:
		penetration_depth = z_depth
		correction_axis = Vector3(0.0, 0.0, 1.0 if local_point.z >= 0.0 else -1.0)
	return {
		"inside": true,
		"shape_kind": &"box",
		"estimated_clearance_meters": -penetration_depth,
		"suggested_correction_world": collision_shape.global_basis * correction_axis * (penetration_depth + DEFAULT_BODY_CLEARANCE_OFFSET_METERS),
	}

func _query_point_against_capsule_shape(
	collision_shape: CollisionShape3D,
	capsule_shape: CapsuleShape3D,
	local_point: Vector3
) -> Dictionary:
	var cap_radius: float = capsule_shape.radius
	var half_mid: float = maxf(capsule_shape.height * 0.5 - cap_radius, 0.0)
	var clamped_y: float = clampf(local_point.y, -half_mid, half_mid)
	var closest_axis_point := Vector3(0.0, clamped_y, 0.0)
	var radial_vector: Vector3 = local_point - closest_axis_point
	var radial_distance: float = radial_vector.length()
	if radial_distance > cap_radius:
		return {
			"inside": false,
			"shape_kind": &"capsule",
			"estimated_clearance_meters": radial_distance - cap_radius,
			"suggested_correction_world": Vector3.ZERO,
		}
	var correction_axis: Vector3 = radial_vector.normalized() if radial_distance > 0.000001 else Vector3.RIGHT
	var penetration_depth: float = cap_radius - radial_distance
	return {
		"inside": true,
		"shape_kind": &"capsule",
		"estimated_clearance_meters": -penetration_depth,
		"suggested_correction_world": collision_shape.global_basis * correction_axis * (penetration_depth + DEFAULT_BODY_CLEARANCE_OFFSET_METERS),
	}

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
