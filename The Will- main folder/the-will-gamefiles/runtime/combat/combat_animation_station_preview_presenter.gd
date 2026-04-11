extends RefCounted
class_name CombatAnimationStationPreviewPresenter

const PlayerHumanoidRigScene: PackedScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const PlayerEquippedItemPresenterScript = preload("res://runtime/player/player_equipped_item_presenter.gd")
const WeaponGripAnchorProviderScript = preload("res://runtime/player/weapon_grip_anchor_provider.gd")
const MaterialPipelineServiceScript = preload("res://services/material_pipeline_service.gd")
const ForgeServiceScript = preload("res://services/forge_service.gd")
const TestPrintMeshBuilderScript = preload("res://runtime/forge/test_print_mesh_builder.gd")
const DEFAULT_FORGE_RULES_RESOURCE: ForgeRulesDef = preload("res://core/defs/forge/forge_rules_default.tres")
const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const CombatAnimationPointScript = preload("res://core/models/combat_animation_point.gd")

const PREVIEW_ROOT_NAME := "CombatAnimationPreviewRoot3D"
const PREVIEW_CAMERA_NAME := "PreviewCamera3D"
const PREVIEW_ACTOR_NAME := "PreviewActor"
const PREVIEW_ACTOR_PIVOT_NAME := "PreviewActorPivot"
const PREVIEW_FLOOR_NAME := "PreviewFloor"
const TRAJECTORY_ROOT_NAME := "TrajectoryRoot"
const TRAJECTORY_MESH_NAME := "TrajectoryMesh"
const CONTROL_LINE_MESH_NAME := "ControlLineMesh"
const MARKER_ROOT_NAME := "TrajectoryMarkerRoot"

var material_pipeline_service = MaterialPipelineServiceScript.new()
var forge_service: ForgeService = ForgeServiceScript.new(DEFAULT_FORGE_RULES_RESOURCE)
var held_item_mesh_builder: TestPrintMeshBuilder = TestPrintMeshBuilderScript.new()
var equipped_item_presenter = PlayerEquippedItemPresenterScript.new()
var weapon_grip_anchor_provider = WeaponGripAnchorProviderScript.new()
var material_lookup_cache: Dictionary = {}

func refresh_preview(
	preview_container: SubViewportContainer,
	preview_subviewport: SubViewport,
	active_wip: CraftedItemWIP,
	active_draft: Resource,
	selected_point_index: int
) -> void:
	var state: Dictionary = _ensure_preview_nodes(preview_container, preview_subviewport)
	_sync_preview_size(preview_container, preview_subviewport)
	_refresh_actor_and_weapon(state, active_wip, _resolve_selected_point(active_draft, selected_point_index))
	_refresh_trajectory_visuals(state, active_draft, selected_point_index)

func get_debug_state(preview_subviewport: SubViewport) -> Dictionary:
	var preview_root: Node3D = preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D if preview_subviewport != null else null
	if preview_root == null:
		return {}
	var actor: Node3D = preview_root.get_node_or_null(PREVIEW_ACTOR_PIVOT_NAME + "/" + PREVIEW_ACTOR_NAME) as Node3D
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var marker_root: Node3D = preview_root.find_child(MARKER_ROOT_NAME, true, false) as Node3D
	return {
		"has_preview_actor": actor != null,
		"has_preview_weapon": held_item != null and is_instance_valid(held_item),
		"has_primary_grip_anchor": weapon_grip_anchor_provider.get_primary_grip_anchor(held_item) != null if held_item != null else false,
		"draft_point_count": int(_get_node_meta_or_default(preview_root, "draft_point_count", 0)),
		"curve_baked_point_count": int(_get_node_meta_or_default(preview_root, "curve_baked_point_count", 0)),
		"point_marker_count": int(_get_node_meta_or_default(preview_root, "point_marker_count", 0)),
		"control_handle_marker_count": int(_get_node_meta_or_default(preview_root, "control_handle_marker_count", 0)),
		"selected_point_index": int(_get_node_meta_or_default(preview_root, "selected_point_index", -1)),
		"marker_root_exists": marker_root != null,
	}

func _ensure_preview_nodes(preview_container: SubViewportContainer, preview_subviewport: SubViewport) -> Dictionary:
	if preview_subviewport == null:
		return {}
	preview_subviewport.own_world_3d = true
	preview_subviewport.transparent_bg = false
	preview_subviewport.handle_input_locally = false
	preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if preview_container != null:
		preview_container.stretch = false
	var preview_root: Node3D = preview_subviewport.get_node_or_null(PREVIEW_ROOT_NAME) as Node3D
	if preview_root == null:
		preview_root = Node3D.new()
		preview_root.name = PREVIEW_ROOT_NAME
		preview_subviewport.add_child(preview_root)
		preview_root.set_meta("preview_held_item", null)
		preview_root.set_meta("preview_wip_id", StringName())
		preview_root.set_meta("draft_point_count", 0)
		preview_root.set_meta("curve_baked_point_count", 0)
		preview_root.set_meta("point_marker_count", 0)
		preview_root.set_meta("control_handle_marker_count", 0)
		preview_root.set_meta("selected_point_index", -1)
		var actor_pivot := Node3D.new()
		actor_pivot.name = PREVIEW_ACTOR_PIVOT_NAME
		actor_pivot.rotation_degrees = Vector3(0.0, 24.0, 0.0)
		preview_root.add_child(actor_pivot)
		var trajectory_root := Node3D.new()
		trajectory_root.name = TRAJECTORY_ROOT_NAME
		preview_root.add_child(trajectory_root)
		var marker_root := Node3D.new()
		marker_root.name = MARKER_ROOT_NAME
		trajectory_root.add_child(marker_root)
		var trajectory_mesh_instance := MeshInstance3D.new()
		trajectory_mesh_instance.name = TRAJECTORY_MESH_NAME
		trajectory_mesh_instance.mesh = ImmediateMesh.new()
		trajectory_mesh_instance.material_override = _build_line_material(Color(1.0, 0.86, 0.2, 1.0))
		trajectory_root.add_child(trajectory_mesh_instance)
		var control_mesh_instance := MeshInstance3D.new()
		control_mesh_instance.name = CONTROL_LINE_MESH_NAME
		control_mesh_instance.mesh = ImmediateMesh.new()
		control_mesh_instance.material_override = _build_line_material(Color(0.25, 0.85, 1.0, 1.0))
		trajectory_root.add_child(control_mesh_instance)
		var camera := Camera3D.new()
		camera.name = PREVIEW_CAMERA_NAME
		camera.current = true
		preview_root.add_child(camera)
		var key_light := DirectionalLight3D.new()
		key_light.name = "PreviewKeyLight"
		key_light.light_energy = 2.2
		key_light.rotation_degrees = Vector3(-42.0, 28.0, 0.0)
		preview_root.add_child(key_light)
		var fill_light := DirectionalLight3D.new()
		fill_light.name = "PreviewFillLight"
		fill_light.light_energy = 0.9
		fill_light.rotation_degrees = Vector3(-18.0, -122.0, 0.0)
		preview_root.add_child(fill_light)
		var floor := MeshInstance3D.new()
		floor.name = PREVIEW_FLOOR_NAME
		var floor_mesh := BoxMesh.new()
		floor_mesh.size = Vector3(5.5, 0.02, 5.5)
		floor.mesh = floor_mesh
		floor.position = Vector3(0.0, -0.01, 0.0)
		floor.material_override = _build_surface_material(Color(0.17, 0.19, 0.22, 1.0), 0.92)
		preview_root.add_child(floor)
	_update_camera(preview_root, null)
	return {
		"preview_root": preview_root,
		"actor_pivot": preview_root.find_child(PREVIEW_ACTOR_PIVOT_NAME, true, false) as Node3D,
		"trajectory_root": preview_root.find_child(TRAJECTORY_ROOT_NAME, true, false) as Node3D,
		"marker_root": preview_root.find_child(MARKER_ROOT_NAME, true, false) as Node3D,
		"trajectory_mesh": preview_root.find_child(TRAJECTORY_MESH_NAME, true, false) as MeshInstance3D,
		"control_mesh": preview_root.find_child(CONTROL_LINE_MESH_NAME, true, false) as MeshInstance3D,
	}

func _sync_preview_size(preview_container: SubViewportContainer, preview_subviewport: SubViewport) -> void:
	if preview_container == null or preview_subviewport == null:
		return
	var target_size := Vector2i(
		maxi(int(round(preview_container.size.x)), 1),
		maxi(int(round(preview_container.size.y)), 1)
	)
	if preview_subviewport.size != target_size:
		preview_subviewport.size = target_size

func _refresh_actor_and_weapon(state: Dictionary, active_wip: CraftedItemWIP, selected_point: CombatAnimationPoint) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var actor_pivot: Node3D = state.get("actor_pivot", null) as Node3D
	if preview_root == null or actor_pivot == null:
		return
	var actor: Node3D = actor_pivot.get_node_or_null(PREVIEW_ACTOR_NAME) as Node3D
	if actor == null:
		actor = PlayerHumanoidRigScene.instantiate() as Node3D
		if actor == null:
			return
		actor.name = PREVIEW_ACTOR_NAME
		actor_pivot.add_child(actor)
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var current_wip_id: StringName = _get_node_meta_or_default(preview_root, "preview_wip_id", StringName()) as StringName
	if active_wip == null:
		if held_item != null and is_instance_valid(held_item):
			held_item.queue_free()
		preview_root.set_meta("preview_held_item", null)
		preview_root.set_meta("preview_wip_id", StringName())
		_update_camera(preview_root, null)
		return
	if held_item == null or not is_instance_valid(held_item) or current_wip_id != active_wip.wip_id:
		if held_item != null and is_instance_valid(held_item):
			held_item.queue_free()
		held_item = _build_weapon_preview_node(actor, active_wip)
		preview_root.set_meta("preview_held_item", held_item)
		preview_root.set_meta("preview_wip_id", active_wip.wip_id)
	_apply_two_hand_preview_state(actor, held_item, selected_point)
	_update_camera(preview_root, weapon_grip_anchor_provider.get_primary_grip_anchor(held_item))

func _refresh_trajectory_visuals(state: Dictionary, active_draft: Resource, selected_point_index: int) -> void:
	var preview_root: Node3D = state.get("preview_root", null) as Node3D
	var trajectory_root: Node3D = state.get("trajectory_root", null) as Node3D
	var marker_root: Node3D = state.get("marker_root", null) as Node3D
	var trajectory_mesh_instance: MeshInstance3D = state.get("trajectory_mesh", null) as MeshInstance3D
	var control_mesh_instance: MeshInstance3D = state.get("control_mesh", null) as MeshInstance3D
	if preview_root == null or trajectory_root == null or marker_root == null or trajectory_mesh_instance == null or control_mesh_instance == null:
		return
	var held_item: Node3D = _get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	var primary_anchor: Node3D = weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	if primary_anchor != null and trajectory_root.get_parent() != primary_anchor:
		var old_parent: Node = trajectory_root.get_parent()
		if old_parent != null:
			old_parent.remove_child(trajectory_root)
		primary_anchor.add_child(trajectory_root)
		trajectory_root.transform = Transform3D.IDENTITY
	elif primary_anchor == null and trajectory_root.get_parent() != preview_root:
		var current_parent: Node = trajectory_root.get_parent()
		if current_parent != null:
			current_parent.remove_child(trajectory_root)
		preview_root.add_child(trajectory_root)
		trajectory_root.transform = Transform3D.IDENTITY
	for child_node: Node in marker_root.get_children():
		child_node.queue_free()
	var point_chain: Array = active_draft.get("point_chain") as Array if active_draft != null else []
	var curve := Curve3D.new()
	curve.bake_interval = 0.015
	var point_marker_count: int = 0
	var handle_marker_count: int = 0
	for point_index: int in range(point_chain.size()):
		var point: CombatAnimationPoint = point_chain[point_index] as CombatAnimationPoint
		if point == null:
			continue
		curve.add_point(point.local_target_position, point.curve_in_handle_local, point.curve_out_handle_local)
		_create_point_marker(marker_root, point.local_target_position, point_index == selected_point_index)
		_create_handle_marker(marker_root, point.local_target_position + point.curve_in_handle_local, Color(0.2, 0.75, 1.0, 1.0), "In")
		_create_handle_marker(marker_root, point.local_target_position + point.curve_out_handle_local, Color(1.0, 0.55, 0.12, 1.0), "Out")
		point_marker_count += 1
		handle_marker_count += 2
	_render_curve_mesh(trajectory_mesh_instance.mesh as ImmediateMesh, curve)
	_render_control_lines(control_mesh_instance.mesh as ImmediateMesh, point_chain)
	preview_root.set_meta("draft_point_count", point_chain.size())
	preview_root.set_meta("curve_baked_point_count", curve.get_baked_points().size())
	preview_root.set_meta("point_marker_count", point_marker_count)
	preview_root.set_meta("control_handle_marker_count", handle_marker_count)
	preview_root.set_meta("selected_point_index", selected_point_index)

func _resolve_selected_point(active_draft: Resource, selected_point_index: int) -> CombatAnimationPoint:
	if active_draft == null:
		return null
	var point_chain: Array = active_draft.get("point_chain") as Array
	if point_chain.is_empty():
		return null
	var resolved_index: int = clampi(selected_point_index, 0, point_chain.size() - 1)
	return point_chain[resolved_index] as CombatAnimationPoint

func _build_weapon_preview_node(actor: Node3D, active_wip: CraftedItemWIP) -> Node3D:
	if actor == null or active_wip == null:
		return null
	var hand_anchor: Node3D = actor.call("get_right_hand_item_anchor") as Node3D if actor.has_method("get_right_hand_item_anchor") else null
	if hand_anchor == null:
		return null
	var held_item: Node3D = equipped_item_presenter.build_equipped_item_node(
		active_wip,
		&"hand_right",
		forge_service,
		_get_material_lookup(),
		held_item_mesh_builder,
		actor,
		DEFAULT_FORGE_RULES_RESOURCE,
		DEFAULT_FORGE_VIEW_TUNING_RESOURCE
	)
	if held_item == null:
		return null
	hand_anchor.add_child(held_item)
	return held_item

func _apply_two_hand_preview_state(actor: Node3D, held_item: Node3D, selected_point: CombatAnimationPoint) -> void:
	if actor == null:
		return
	var held_items: Dictionary = {}
	if held_item != null:
		held_items[&"hand_right"] = held_item
	equipped_item_presenter.sync_rig_weapon_guidance(actor, held_items, true, null)
	var point_two_hand_state: StringName = selected_point.two_hand_state if selected_point != null else CombatAnimationPointScript.TWO_HAND_STATE_AUTO
	if point_two_hand_state == CombatAnimationPointScript.TWO_HAND_STATE_ONE_HAND:
		if actor.has_method("clear_arm_guidance_target"):
			actor.call("clear_arm_guidance_target", &"hand_left")
		if actor.has_method("clear_finger_grip_target"):
			actor.call("clear_finger_grip_target", &"hand_left")
		if actor.has_method("set_support_hand_active"):
			actor.call("set_support_hand_active", &"hand_left", false)
	if actor.has_method("update_locomotion_state"):
		actor.call("update_locomotion_state", 0.0, 0.0, true, 0.0, false)

func _update_camera(preview_root: Node3D, primary_anchor: Node3D) -> void:
	if preview_root == null:
		return
	var camera: Camera3D = preview_root.get_node_or_null(PREVIEW_CAMERA_NAME) as Camera3D
	if camera == null:
		return
	var focus_point: Vector3 = Vector3(0.0, 1.1, 0.0)
	if primary_anchor != null:
		focus_point = focus_point.lerp(primary_anchor.global_position, 0.5)
	camera.look_at_from_position(focus_point + Vector3(1.15, 0.7, 2.35), focus_point, Vector3.UP)

func _render_curve_mesh(immediate_mesh: ImmediateMesh, curve: Curve3D) -> void:
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	var baked_points: PackedVector3Array = curve.get_baked_points()
	if baked_points.size() < 2:
		return
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point_index: int in range(baked_points.size() - 1):
		immediate_mesh.surface_set_color(Color(1.0, 0.86, 0.2, 1.0))
		immediate_mesh.surface_add_vertex(baked_points[point_index])
		immediate_mesh.surface_set_color(Color(1.0, 0.86, 0.2, 1.0))
		immediate_mesh.surface_add_vertex(baked_points[point_index + 1])
	immediate_mesh.surface_end()

func _render_control_lines(immediate_mesh: ImmediateMesh, point_chain: Array) -> void:
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	if point_chain.is_empty():
		return
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point_variant: Variant in point_chain:
		var point: CombatAnimationPoint = point_variant as CombatAnimationPoint
		if point == null:
			continue
		var point_position: Vector3 = point.local_target_position
		immediate_mesh.surface_set_color(Color(0.2, 0.75, 1.0, 1.0))
		immediate_mesh.surface_add_vertex(point_position)
		immediate_mesh.surface_set_color(Color(0.2, 0.75, 1.0, 1.0))
		immediate_mesh.surface_add_vertex(point_position + point.curve_in_handle_local)
		immediate_mesh.surface_set_color(Color(1.0, 0.55, 0.12, 1.0))
		immediate_mesh.surface_add_vertex(point_position)
		immediate_mesh.surface_set_color(Color(1.0, 0.55, 0.12, 1.0))
		immediate_mesh.surface_add_vertex(point_position + point.curve_out_handle_local)
	immediate_mesh.surface_end()

func _create_point_marker(marker_root: Node3D, local_position: Vector3, active: bool) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "PointMarker_%d" % marker_root.get_child_count()
	var mesh := SphereMesh.new()
	mesh.radius = 0.022 if active else 0.016
	mesh.height = mesh.radius * 2.0
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_surface_material(Color(1.0, 0.33, 0.24, 1.0) if active else Color(0.92, 0.92, 0.92, 1.0), 0.35)
	marker_root.add_child(marker)

func _create_handle_marker(marker_root: Node3D, local_position: Vector3, color: Color, prefix: String) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "%sHandleMarker_%d" % [prefix, marker_root.get_child_count()]
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.022
	marker.mesh = mesh
	marker.position = local_position
	marker.material_override = _build_surface_material(color, 0.45)
	marker_root.add_child(marker)

func _build_line_material(albedo_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = albedo_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_surface_material(albedo_color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo_color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _get_material_lookup() -> Dictionary:
	if material_lookup_cache.is_empty():
		material_lookup_cache = material_pipeline_service.build_base_material_lookup()
	return material_lookup_cache

func _get_node_meta_or_default(node: Object, key: StringName, default_value: Variant) -> Variant:
	if node == null or not node.has_meta(key):
		return default_value
	return node.get_meta(key)
