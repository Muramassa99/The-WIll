extends RefCounted
class_name RuntimeBoneDebugDraw

const ROOT_NAME := "RuntimeBoneDebugRoot"
const BONE_LINES_NAME := "BoneLines"
const BONE_AXES_NAME := "BoneAxes"
const LABEL_ROOT_NAME := "BoneLabels"
const AXIS_LENGTH_METERS := 0.075
const JOINT_TICK_METERS := 0.018

const KEY_AXIS_BONES: Array[StringName] = [
	&"RL_BoneRoot",
	&"CC_Base_Hip",
	&"CC_Base_Waist",
	&"CC_Base_Spine01",
	&"CC_Base_Spine02",
	&"CC_Base_R_Clavicle",
	&"CC_Base_L_Clavicle",
	&"CC_Base_R_Upperarm",
	&"CC_Base_L_Upperarm",
	&"CC_Base_R_Forearm",
	&"CC_Base_L_Forearm",
	&"CC_Base_R_Hand",
	&"CC_Base_L_Hand",
]

const KEY_LABEL_BONES: Array[StringName] = [
	&"RL_BoneRoot",
	&"CC_Base_R_Hand",
	&"CC_Base_L_Hand",
	&"CC_Base_R_Forearm",
	&"CC_Base_L_Forearm",
]

func ensure_debug_root(rig_root: Node3D) -> Node3D:
	if rig_root == null:
		return null
	var debug_root: Node3D = rig_root.get_node_or_null(ROOT_NAME) as Node3D
	if debug_root == null:
		debug_root = Node3D.new()
		debug_root.name = ROOT_NAME
		rig_root.add_child(debug_root)
	debug_root.top_level = true
	debug_root.global_transform = Transform3D.IDENTITY
	_ensure_debug_mesh_instance(debug_root, BONE_LINES_NAME)
	_ensure_debug_mesh_instance(debug_root, BONE_AXES_NAME)
	_ensure_named_node3d(debug_root, LABEL_ROOT_NAME)
	return debug_root

func update_debug_skeleton(
	debug_root: Node3D,
	skeleton: Skeleton3D,
	debug_visible: bool,
	upper_body_bones: Array,
	reference_bone_name: StringName,
	draw_all_bones: bool,
	draw_labels: bool
) -> Dictionary:
	var state := {
		"visible": false,
		"bone_count": 0,
		"line_segment_count": 0,
		"axis_bone_count": 0,
		"reference_bone_name": String(reference_bone_name),
		"reference_bone_found": false,
		"reference_bone_world": Transform3D.IDENTITY,
	}
	if debug_root == null:
		return state
	debug_root.visible = debug_visible and skeleton != null
	if not debug_root.visible:
		_clear_debug_mesh(debug_root, BONE_LINES_NAME)
		_clear_debug_mesh(debug_root, BONE_AXES_NAME)
		_sync_labels(debug_root, skeleton, false, [])
		return state
	debug_root.top_level = true
	debug_root.global_transform = Transform3D.IDENTITY
	var upper_lookup: Dictionary = _build_string_name_lookup(upper_body_bones)
	var line_vertices := PackedVector3Array()
	var line_colors := PackedColorArray()
	var axis_vertices := PackedVector3Array()
	var axis_colors := PackedColorArray()
	var bone_count: int = skeleton.get_bone_count()
	for bone_index: int in range(bone_count):
		var parent_index: int = skeleton.get_bone_parent(bone_index)
		if parent_index < 0:
			continue
		var bone_name := StringName(skeleton.get_bone_name(bone_index))
		var parent_name := StringName(skeleton.get_bone_name(parent_index))
		var should_draw_segment: bool = draw_all_bones or upper_lookup.has(bone_name) or upper_lookup.has(parent_name)
		if not should_draw_segment:
			continue
		var parent_world: Vector3 = _get_bone_world_position(skeleton, parent_index)
		var bone_world: Vector3 = _get_bone_world_position(skeleton, bone_index)
		var color: Color = _resolve_bone_segment_color(bone_name, parent_name, upper_lookup)
		_append_debug_line(line_vertices, line_colors, parent_world, bone_world, color)
		state["line_segment_count"] = int(state.get("line_segment_count", 0)) + 1
	for axis_bone: StringName in KEY_AXIS_BONES:
		var axis_index: int = skeleton.find_bone(String(axis_bone))
		if axis_index < 0:
			continue
		var axis_transform: Transform3D = _get_bone_world_transform(skeleton, axis_index)
		var axis_length: float = AXIS_LENGTH_METERS * (1.45 if axis_bone == reference_bone_name else 1.0)
		_append_transform_axes(axis_vertices, axis_colors, axis_transform, axis_length)
		_append_joint_tick(axis_vertices, axis_colors, axis_transform.origin, Color(1.0, 1.0, 1.0, 0.82))
		state["axis_bone_count"] = int(state.get("axis_bone_count", 0)) + 1
	var reference_index: int = skeleton.find_bone(String(reference_bone_name))
	if reference_index >= 0:
		state["reference_bone_found"] = true
		state["reference_bone_world"] = _get_bone_world_transform(skeleton, reference_index)
	state["visible"] = true
	state["bone_count"] = bone_count
	_update_debug_mesh(debug_root, BONE_LINES_NAME, Mesh.PRIMITIVE_LINES, line_vertices, line_colors)
	_update_debug_mesh(debug_root, BONE_AXES_NAME, Mesh.PRIMITIVE_LINES, axis_vertices, axis_colors)
	_sync_labels(debug_root, skeleton, draw_labels, KEY_LABEL_BONES)
	return state

func _build_string_name_lookup(values: Array) -> Dictionary:
	var lookup: Dictionary = {}
	for value: Variant in values:
		lookup[StringName(value)] = true
	return lookup

func _resolve_bone_segment_color(bone_name: StringName, parent_name: StringName, upper_lookup: Dictionary) -> Color:
	var bone_text := String(bone_name)
	var parent_text := String(parent_name)
	if bone_text == "RL_BoneRoot" or parent_text == "RL_BoneRoot":
		return Color(1.0, 1.0, 1.0, 0.95)
	if bone_text.begins_with("CC_Base_R_") or parent_text.begins_with("CC_Base_R_"):
		return Color(1.0, 0.72, 0.18, 0.96)
	if bone_text.begins_with("CC_Base_L_") or parent_text.begins_with("CC_Base_L_"):
		return Color(0.12, 0.78, 1.0, 0.96)
	if upper_lookup.has(bone_name) or upper_lookup.has(parent_name):
		return Color(0.28, 1.0, 0.54, 0.92)
	return Color(0.82, 0.86, 0.90, 0.38)

func _get_bone_world_position(skeleton: Skeleton3D, bone_index: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)).origin

func _get_bone_world_transform(skeleton: Skeleton3D, bone_index: int) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone_index)

func _append_transform_axes(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	transform: Transform3D,
	axis_length: float
) -> void:
	var basis: Basis = transform.basis.orthonormalized()
	var origin: Vector3 = transform.origin
	_append_debug_line(vertices, colors, origin, origin + basis.x.normalized() * axis_length, Color(1.0, 0.18, 0.14, 0.98))
	_append_debug_line(vertices, colors, origin, origin + basis.y.normalized() * axis_length, Color(0.18, 1.0, 0.26, 0.98))
	_append_debug_line(vertices, colors, origin, origin + basis.z.normalized() * axis_length, Color(0.16, 0.44, 1.0, 0.98))

func _append_joint_tick(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	origin: Vector3,
	color: Color
) -> void:
	_append_debug_line(vertices, colors, origin - Vector3.RIGHT * JOINT_TICK_METERS, origin + Vector3.RIGHT * JOINT_TICK_METERS, color)
	_append_debug_line(vertices, colors, origin - Vector3.UP * JOINT_TICK_METERS, origin + Vector3.UP * JOINT_TICK_METERS, color)
	_append_debug_line(vertices, colors, origin - Vector3.FORWARD * JOINT_TICK_METERS, origin + Vector3.FORWARD * JOINT_TICK_METERS, color)

func _append_debug_line(
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	from_world: Vector3,
	to_world: Vector3,
	color: Color
) -> void:
	vertices.append(from_world)
	vertices.append(to_world)
	colors.append(color)
	colors.append(color)

func _update_debug_mesh(
	debug_root: Node3D,
	instance_name: String,
	primitive: Mesh.PrimitiveType,
	vertices: PackedVector3Array,
	colors: PackedColorArray
) -> void:
	var instance: MeshInstance3D = _ensure_debug_mesh_instance(debug_root, instance_name)
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(primitive, arrays)
	instance.mesh = mesh
	instance.material_override = _build_debug_vertex_material()
	instance.visible = not vertices.is_empty()

func _clear_debug_mesh(debug_root: Node3D, instance_name: String) -> void:
	var instance: MeshInstance3D = debug_root.get_node_or_null(instance_name) as MeshInstance3D
	if instance == null:
		return
	instance.mesh = ArrayMesh.new()
	instance.visible = false

func _sync_labels(debug_root: Node3D, skeleton: Skeleton3D, labels_visible: bool, label_bones: Array[StringName]) -> void:
	var label_root: Node3D = _ensure_named_node3d(debug_root, LABEL_ROOT_NAME)
	label_root.visible = labels_visible and skeleton != null
	for child: Node in label_root.get_children():
		var label: Label3D = child as Label3D
		if label != null:
			label.visible = false
	if not label_root.visible:
		return
	for bone_name: StringName in label_bones:
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			continue
		var label_name: String = "Label_%s" % String(bone_name).replace(":", "_")
		var label: Label3D = label_root.get_node_or_null(label_name) as Label3D
		if label == null:
			label = Label3D.new()
			label.name = label_name
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 20
			label.pixel_size = 0.0025
			label.no_depth_test = true
			label_root.add_child(label)
		label.text = String(bone_name)
		label.modulate = Color(1.0, 1.0, 1.0, 0.92)
		label.position = _get_bone_world_position(skeleton, bone_index) + Vector3(0.0, 0.04, 0.0)
		label.visible = true

func _ensure_named_node3d(parent: Node3D, node_name: String) -> Node3D:
	var node: Node3D = parent.get_node_or_null(node_name) as Node3D if parent != null else null
	if node == null:
		node = Node3D.new()
		node.name = node_name
		parent.add_child(node)
	return node

func _ensure_debug_mesh_instance(parent: Node3D, instance_name: String) -> MeshInstance3D:
	var instance: MeshInstance3D = parent.get_node_or_null(instance_name) as MeshInstance3D
	if instance == null:
		instance = MeshInstance3D.new()
		instance.name = instance_name
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	return instance

func _build_debug_vertex_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material
