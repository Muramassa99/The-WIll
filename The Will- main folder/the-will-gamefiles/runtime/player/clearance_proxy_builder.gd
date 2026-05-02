extends RefCounted
class_name ClearanceProxyBuilder

const SOURCE_MESH_DERIVED: StringName = &"mesh_derived"
const SOURCE_FALLBACK_ANATOMY: StringName = &"fallback_anatomy_blocks"
const DEFAULT_CLEARANCE_OFFSET_METERS := 0.005
const BODY_PROXY_OVERLAP_METERS := 0.045
const ROUNDED_BAND_COLUMN_COUNT := 3

const CHEST_BONE: StringName = &"CC_Base_Spine02"
const ABDOMEN_BONE: StringName = &"CC_Base_Waist"
const HIP_BONE: StringName = &"CC_Base_Hip"
const HEAD_BONE: StringName = &"CC_Base_Head"
const LEFT_CLAVICLE_BONE: StringName = &"CC_Base_L_Clavicle"
const RIGHT_CLAVICLE_BONE: StringName = &"CC_Base_R_Clavicle"
const LEFT_UPPERARM_BONE: StringName = &"CC_Base_L_Upperarm"
const RIGHT_UPPERARM_BONE: StringName = &"CC_Base_R_Upperarm"
const LEFT_FOREARM_BONE: StringName = &"CC_Base_L_Forearm"
const RIGHT_FOREARM_BONE: StringName = &"CC_Base_R_Forearm"
const LEFT_HAND_BONE: StringName = &"CC_Base_L_Hand"
const RIGHT_HAND_BONE: StringName = &"CC_Base_R_Hand"
const LEFT_THIGH_BONE: StringName = &"CC_Base_L_Thigh"
const RIGHT_THIGH_BONE: StringName = &"CC_Base_R_Thigh"
const LEFT_CALF_BONE: StringName = &"CC_Base_L_Calf"
const RIGHT_CALF_BONE: StringName = &"CC_Base_R_Calf"
const LEFT_FOOT_BONE: StringName = &"CC_Base_L_Foot"
const RIGHT_FOOT_BONE: StringName = &"CC_Base_R_Foot"

func build_body_proxy_descriptors(
	rig_root: Node3D,
	skeleton: Skeleton3D,
	mesh_instance: MeshInstance3D,
	clearance_offset_meters: float = DEFAULT_CLEARANCE_OFFSET_METERS
) -> Array[Dictionary]:
	var descriptors: Array[Dictionary] = []
	if rig_root == null or skeleton == null or mesh_instance == null or mesh_instance.mesh == null:
		return descriptors
	var mesh_bounds: Dictionary = _resolve_mesh_bounds_in_rig_space(rig_root, mesh_instance)
	if not bool(mesh_bounds.get("valid", false)):
		return descriptors
	var clearance: float = maxf(clearance_offset_meters, 0.0)
	var mesh_size: Vector3 = mesh_bounds.get("size", Vector3.ZERO) as Vector3
	var chest_world: Vector3 = _get_bone_world_position(skeleton, CHEST_BONE)
	var waist_world: Vector3 = _get_bone_world_position(skeleton, ABDOMEN_BONE)
	var hip_world: Vector3 = _get_bone_world_position(skeleton, HIP_BONE)
	var left_clavicle_world: Vector3 = _get_bone_world_position(skeleton, LEFT_CLAVICLE_BONE)
	var right_clavicle_world: Vector3 = _get_bone_world_position(skeleton, RIGHT_CLAVICLE_BONE)
	var left_thigh_world: Vector3 = _get_bone_world_position(skeleton, LEFT_THIGH_BONE)
	var right_thigh_world: Vector3 = _get_bone_world_position(skeleton, RIGHT_THIGH_BONE)
	var shoulder_span: float = left_clavicle_world.distance_to(right_clavicle_world)
	if shoulder_span <= 0.0001:
		shoulder_span = maxf(mesh_size.x * 0.28, 0.34)
	var hip_span: float = left_thigh_world.distance_to(right_thigh_world)
	if hip_span <= 0.0001:
		hip_span = maxf(shoulder_span * 0.65, 0.24)
	var torso_depth: float = _derive_body_depth(mesh_size, shoulder_span, clearance)
	var chest_height: float = maxf(chest_world.distance_to(waist_world) * 1.20, 0.22)
	var abdomen_height: float = maxf(waist_world.distance_to(hip_world) * 1.15, 0.18)
	var chest_band_size: Vector3 = Vector3(maxf(shoulder_span * 0.82, 0.32), chest_height, torso_depth) + Vector3.ONE * clearance * 2.0
	var spine_01_reference_band_size: Vector3 = Vector3(maxf(shoulder_span * 0.70, 0.28), abdomen_height, torso_depth * 0.86) + Vector3.ONE * clearance * 2.0
	var chest_center_volume_scale: float = pow(1.5, 1.0 / 3.0)
	var chest_center_band_size: Vector3 = spine_01_reference_band_size * chest_center_volume_scale
	_append_rounded_band_descriptors(
		descriptors,
		skeleton,
		"ChestRestrictionAttachment",
		"torso_chest",
		CHEST_BONE,
		chest_world,
		chest_band_size,
		Color(0.85, 0.20, 0.20, 0.18),
		mesh_bounds,
		clearance,
		[
			spine_01_reference_band_size,
			chest_center_band_size,
			spine_01_reference_band_size,
		]
	)
	_append_rounded_band_descriptors(
		descriptors,
		skeleton,
		"AbdomenRestrictionAttachment",
		"torso_abdomen",
		ABDOMEN_BONE,
		waist_world,
		spine_01_reference_band_size,
		Color(0.90, 0.52, 0.12, 0.18),
		mesh_bounds,
		clearance
	)
	_append_rounded_band_descriptors(
		descriptors,
		skeleton,
		"HipRestrictionAttachment",
		"pelvis",
		HIP_BONE,
		hip_world,
		Vector3(maxf(hip_span * 1.45, 0.32), maxf(abdomen_height * 0.80, 0.18), torso_depth * 0.90) + Vector3.ONE * clearance * 2.0,
		Color(0.20, 0.48, 0.90, 0.18),
		mesh_bounds,
		clearance
	)
	_append_capsule_descriptor(
		descriptors,
		skeleton,
		"LeftShoulderRestrictionAttachment",
		"left_shoulder",
		LEFT_CLAVICLE_BONE,
		left_clavicle_world,
		Vector3(maxf(shoulder_span * 0.20, 0.12), maxf(chest_height * 0.52, 0.14), torso_depth * 0.62) + Vector3.ONE * clearance * 2.0,
		Color(0.55, 0.30, 0.90, 0.16),
		mesh_bounds,
		clearance
	)
	_append_capsule_descriptor(
		descriptors,
		skeleton,
		"RightShoulderRestrictionAttachment",
		"right_shoulder",
		RIGHT_CLAVICLE_BONE,
		right_clavicle_world,
		Vector3(maxf(shoulder_span * 0.20, 0.12), maxf(chest_height * 0.52, 0.14), torso_depth * 0.62) + Vector3.ONE * clearance * 2.0,
		Color(0.55, 0.30, 0.90, 0.16),
		mesh_bounds,
		clearance
	)
	_append_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"LeftUpperarmRestrictionAttachment",
		"left_upperarm",
		LEFT_UPPERARM_BONE,
		LEFT_FOREARM_BONE,
		0.21,
		Color(0.20, 0.75, 0.45, 0.16),
		mesh_bounds,
		clearance
	)
	_append_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"LeftForearmRestrictionAttachment",
		"left_forearm",
		LEFT_FOREARM_BONE,
		LEFT_HAND_BONE,
		0.18,
		Color(0.20, 0.75, 0.45, 0.16),
		mesh_bounds,
		clearance
	)
	_append_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"RightUpperarmRestrictionAttachment",
		"right_upperarm",
		RIGHT_UPPERARM_BONE,
		RIGHT_FOREARM_BONE,
		0.21,
		Color(0.20, 0.75, 0.45, 0.16),
		mesh_bounds,
		clearance
	)
	_append_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"RightForearmRestrictionAttachment",
		"right_forearm",
		RIGHT_FOREARM_BONE,
		RIGHT_HAND_BONE,
		0.18,
		Color(0.20, 0.75, 0.45, 0.16),
		mesh_bounds,
		clearance
	)
	_append_optional_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"LeftThighRestrictionAttachment",
		"left_thigh",
		LEFT_THIGH_BONE,
		LEFT_CALF_BONE,
		0.22,
		Color(0.18, 0.55, 0.95, 0.14),
		mesh_bounds,
		clearance
	)
	_append_optional_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"RightThighRestrictionAttachment",
		"right_thigh",
		RIGHT_THIGH_BONE,
		RIGHT_CALF_BONE,
		0.22,
		Color(0.18, 0.55, 0.95, 0.14),
		mesh_bounds,
		clearance
	)
	_append_optional_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"LeftCalfRestrictionAttachment",
		"left_calf",
		LEFT_CALF_BONE,
		LEFT_FOOT_BONE,
		0.17,
		Color(0.18, 0.55, 0.95, 0.14),
		mesh_bounds,
		clearance
	)
	_append_optional_limb_capsule_descriptor(
		descriptors,
		skeleton,
		"RightCalfRestrictionAttachment",
		"right_calf",
		RIGHT_CALF_BONE,
		RIGHT_FOOT_BONE,
		0.17,
		Color(0.18, 0.55, 0.95, 0.14),
		mesh_bounds,
		clearance
	)
	if _has_bone(skeleton, HEAD_BONE):
		var head_world: Vector3 = _get_bone_world_position(skeleton, HEAD_BONE)
		_append_capsule_descriptor(
			descriptors,
			skeleton,
			"HeadRestrictionAttachment",
			"head",
			HEAD_BONE,
			head_world,
			Vector3(maxf(shoulder_span * 0.32, 0.16), maxf(mesh_size.y * 0.105, 0.18), maxf(torso_depth * 0.68, 0.14)) + Vector3.ONE * clearance * 2.0,
			Color(0.95, 0.82, 0.20, 0.14),
			mesh_bounds,
			clearance
		)
	return descriptors

func _resolve_mesh_bounds_in_rig_space(rig_root: Node3D, mesh_instance: MeshInstance3D) -> Dictionary:
	if rig_root == null or mesh_instance == null or mesh_instance.mesh == null:
		return {"valid": false}
	var aabb: AABB = mesh_instance.get_aabb()
	if aabb.size.length_squared() <= 0.000001:
		return {"valid": false}
	var min_local := Vector3(INF, INF, INF)
	var max_local := Vector3(-INF, -INF, -INF)
	var rig_inverse: Transform3D = rig_root.global_transform.affine_inverse()
	for x_index: int in range(2):
		for y_index: int in range(2):
			for z_index: int in range(2):
				var corner: Vector3 = aabb.position + Vector3(
					aabb.size.x if x_index == 1 else 0.0,
					aabb.size.y if y_index == 1 else 0.0,
					aabb.size.z if z_index == 1 else 0.0
				)
				var rig_local: Vector3 = rig_inverse * (mesh_instance.global_transform * corner)
				min_local = Vector3(
					minf(min_local.x, rig_local.x),
					minf(min_local.y, rig_local.y),
					minf(min_local.z, rig_local.z)
				)
				max_local = Vector3(
					maxf(max_local.x, rig_local.x),
					maxf(max_local.y, rig_local.y),
					maxf(max_local.z, rig_local.z)
				)
	var size: Vector3 = max_local - min_local
	if size.length_squared() <= 0.000001:
		return {"valid": false}
	return {
		"valid": true,
		"source": SOURCE_MESH_DERIVED,
		"position": min_local,
		"size": size,
		"center": min_local + size * 0.5,
	}

func _append_box_descriptor(
	descriptors: Array[Dictionary],
	skeleton: Skeleton3D,
	attachment_name: String,
	region_name: String,
	bone_name: StringName,
	center_world: Vector3,
	box_size: Vector3,
	debug_color: Color,
	mesh_bounds: Dictionary,
	clearance_offset_meters: float
) -> void:
	if not _has_bone(skeleton, bone_name):
		return
	descriptors.append({
		"name": attachment_name,
		"shape": &"box",
		"region": region_name,
		"bone_name": bone_name,
		"local_offset": _resolve_bone_local_offset(skeleton, bone_name, center_world),
		"box_size": _sanitize_box_size(box_size),
		"debug_color": debug_color,
		"proxy_source": SOURCE_MESH_DERIVED,
		"clearance_offset_meters": clearance_offset_meters,
		"source_mesh_aabb_size": mesh_bounds.get("size", Vector3.ZERO),
	})

func _append_rounded_band_descriptors(
	descriptors: Array[Dictionary],
	skeleton: Skeleton3D,
	attachment_name: String,
	region_name: String,
	bone_name: StringName,
	center_world: Vector3,
	band_size: Vector3,
	debug_color: Color,
	mesh_bounds: Dictionary,
	clearance_offset_meters: float,
	column_size_overrides: Array = []
) -> void:
	if not _has_bone(skeleton, bone_name):
		return
	var sanitized_size: Vector3 = _sanitize_box_size(band_size)
	var column_count: int = maxi(ROUNDED_BAND_COLUMN_COUNT, 1)
	var half_width: float = maxf(sanitized_size.x * 0.5, 0.01)
	var right_world: Vector3 = _resolve_body_right_world(skeleton)
	var base_capsule_radius: float = _resolve_rounded_band_capsule_radius(sanitized_size, column_count)
	var max_column_offset: float = maxf(half_width - base_capsule_radius * 0.72, 0.0)
	for column_index: int in range(column_count):
		var column_alpha: float = 0.0 if column_count == 1 else float(column_index) / float(column_count - 1)
		var lateral_offset: float = lerpf(-max_column_offset, max_column_offset, column_alpha)
		var column_name: String = attachment_name
		if column_count > 1:
			column_name = "%s_%s" % [attachment_name, _resolve_column_suffix(column_index, column_count)]
		var column_size: Vector3 = sanitized_size
		if column_index < column_size_overrides.size() and column_size_overrides[column_index] is Vector3:
			column_size = _sanitize_box_size(column_size_overrides[column_index] as Vector3)
		var capsule_radius: float = _resolve_rounded_band_capsule_radius(column_size, column_count)
		var capsule_height: float = maxf(column_size.y + BODY_PROXY_OVERLAP_METERS, capsule_radius * 2.05)
		descriptors.append({
			"name": column_name,
			"shape": &"capsule",
			"region": region_name,
			"bone_name": bone_name,
			"local_offset": _resolve_bone_local_offset(skeleton, bone_name, center_world + right_world * lateral_offset),
			"capsule_radius": capsule_radius,
			"capsule_height": capsule_height,
			"debug_color": debug_color,
			"proxy_source": SOURCE_MESH_DERIVED,
			"clearance_offset_meters": clearance_offset_meters,
			"source_mesh_aabb_size": mesh_bounds.get("size", Vector3.ZERO),
		})

func _resolve_rounded_band_capsule_radius(sanitized_size: Vector3, column_count: int) -> float:
	var radius_from_depth: float = maxf(sanitized_size.z * 0.55, 0.025)
	var radius_from_width: float = maxf(sanitized_size.x / float(column_count + 1), 0.025)
	return maxf(radius_from_depth, radius_from_width)

func _append_capsule_descriptor(
	descriptors: Array[Dictionary],
	skeleton: Skeleton3D,
	attachment_name: String,
	region_name: String,
	bone_name: StringName,
	center_world: Vector3,
	proxy_size: Vector3,
	debug_color: Color,
	mesh_bounds: Dictionary,
	clearance_offset_meters: float
) -> void:
	if not _has_bone(skeleton, bone_name):
		return
	var sanitized_size: Vector3 = _sanitize_box_size(proxy_size)
	var capsule_radius: float = maxf(maxf(sanitized_size.x, sanitized_size.z) * 0.5, 0.025)
	var capsule_height: float = maxf(sanitized_size.y + BODY_PROXY_OVERLAP_METERS, capsule_radius * 2.05)
	descriptors.append({
		"name": attachment_name,
		"shape": &"capsule",
		"region": region_name,
		"bone_name": bone_name,
		"local_offset": _resolve_bone_local_offset(skeleton, bone_name, center_world),
		"capsule_radius": capsule_radius,
		"capsule_height": capsule_height,
		"debug_color": debug_color,
		"proxy_source": SOURCE_MESH_DERIVED,
		"clearance_offset_meters": clearance_offset_meters,
		"source_mesh_aabb_size": mesh_bounds.get("size", Vector3.ZERO),
	})

func _resolve_column_suffix(column_index: int, column_count: int) -> String:
	if column_count == 3:
		if column_index == 0:
			return "Left"
		if column_index == 1:
			return "Center"
		return "Right"
	return "Column%02d" % column_index

func _resolve_body_right_world(skeleton: Skeleton3D) -> Vector3:
	if skeleton == null:
		return Vector3.RIGHT
	var right_world: Vector3 = skeleton.global_basis.x
	if right_world.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return right_world.normalized()

func _append_optional_limb_capsule_descriptor(
	descriptors: Array[Dictionary],
	skeleton: Skeleton3D,
	attachment_name: String,
	region_name: String,
	bone_name: StringName,
	end_bone_name: StringName,
	radius_to_length_ratio: float,
	debug_color: Color,
	mesh_bounds: Dictionary,
	clearance_offset_meters: float
) -> void:
	if not _has_bone(skeleton, bone_name) or not _has_bone(skeleton, end_bone_name):
		return
	_append_limb_capsule_descriptor(
		descriptors,
		skeleton,
		attachment_name,
		region_name,
		bone_name,
		end_bone_name,
		radius_to_length_ratio,
		debug_color,
		mesh_bounds,
		clearance_offset_meters
	)

func _append_limb_capsule_descriptor(
	descriptors: Array[Dictionary],
	skeleton: Skeleton3D,
	attachment_name: String,
	region_name: String,
	bone_name: StringName,
	end_bone_name: StringName,
	radius_to_length_ratio: float,
	debug_color: Color,
	mesh_bounds: Dictionary,
	clearance_offset_meters: float
) -> void:
	if not _has_bone(skeleton, bone_name) or not _has_bone(skeleton, end_bone_name):
		return
	var start_world: Vector3 = _get_bone_world_position(skeleton, bone_name)
	var end_world: Vector3 = _get_bone_world_position(skeleton, end_bone_name)
	var length: float = start_world.distance_to(end_world)
	if length <= 0.0001:
		return
	var center_world: Vector3 = start_world.lerp(end_world, 0.5)
	var capsule_radius: float = maxf(length * radius_to_length_ratio, 0.025) + clearance_offset_meters
	descriptors.append({
		"name": attachment_name,
		"shape": &"capsule",
		"region": region_name,
		"bone_name": bone_name,
		"end_bone_name": end_bone_name,
		"local_offset": _resolve_bone_local_offset(skeleton, bone_name, center_world),
		"capsule_radius": capsule_radius,
		"capsule_height": length + clearance_offset_meters * 2.0 + BODY_PROXY_OVERLAP_METERS,
		"debug_color": debug_color,
		"proxy_source": SOURCE_MESH_DERIVED,
		"clearance_offset_meters": clearance_offset_meters,
		"source_mesh_aabb_size": mesh_bounds.get("size", Vector3.ZERO),
	})

func _derive_body_depth(mesh_size: Vector3, shoulder_span: float, clearance_offset_meters: float) -> float:
	var mesh_depth: float = maxf(mesh_size.z, 0.12)
	return maxf(minf(mesh_depth * 0.62, shoulder_span * 0.72), 0.16) + clearance_offset_meters * 2.0

func _sanitize_box_size(box_size: Vector3) -> Vector3:
	return Vector3(
		maxf(box_size.x, 0.01),
		maxf(box_size.y, 0.01),
		maxf(box_size.z, 0.01)
	)

func _resolve_bone_local_offset(skeleton: Skeleton3D, bone_name: StringName, point_world: Vector3) -> Vector3:
	var bone_transform: Transform3D = _get_bone_world_transform(skeleton, bone_name)
	return bone_transform.affine_inverse() * point_world

func _get_bone_world_position(skeleton: Skeleton3D, bone_name: StringName) -> Vector3:
	return _get_bone_world_transform(skeleton, bone_name).origin

func _get_bone_world_transform(skeleton: Skeleton3D, bone_name: StringName) -> Transform3D:
	if skeleton == null:
		return Transform3D.IDENTITY
	var bone_index: int = skeleton.find_bone(String(bone_name))
	if bone_index < 0:
		return Transform3D.IDENTITY
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)

func _has_bone(skeleton: Skeleton3D, bone_name: StringName) -> bool:
	return skeleton != null and skeleton.find_bone(String(bone_name)) >= 0
