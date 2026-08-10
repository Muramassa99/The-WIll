extends Node3D
class_name ForgeV2VolumePreviewPresenter

const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")
const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialPaletteScript = preload("res://runtime/forge_v2/forge_v2_material_palette.gd")
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")

const PREVIEW_TUBE_SIDES := 12
const PREVIEW_SPHERE_RINGS := 6
const PREVIEW_SPHERE_SIDES := 12
const DEFAULT_PREVIEW_RADIUS_METERS := 0.06
const SPLINE_PREVIEW_RADIUS_METERS := 0.014
const SPLINE_POINT_RADIUS_METERS := 0.028
const SPLINE_SELECTED_POINT_RADIUS_METERS := 0.038
const SPLINE_PREVIEW_BAKE_INTERVAL_METERS := 0.015
const SPLINE_CSG_CIRCLE_SIDES := 24
const SPLINE_CSG_PATH_INTERVAL_RADIUS_RATIO_FALLBACK := 0.55
const SPLINE_CSG_PATH_INTERVAL_MIN_METERS_FALLBACK := 0.00625
const SPLINE_AUTO_CURVE_HANDLE_MIN_LENGTH_METERS := 0.025
const SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH := 0.3333333
const SPLINE_AUTO_CURVE_MIDDLE_STRENGTH := 0.1666667
const MATERIAL_SURFACE_COLLISION_LAYER := 1 << 20

var active_stage_controller: Node = null
var preview_mesh_instance: MeshInstance3D = null
var spline_preview_mesh_instance: MeshInstance3D = null
var spline_csg_path: Path3D = null
var spline_csg_polygon: CSGPolygon3D = null
var csg_material_body_root: Node3D = null
var csg_static_body_root: Node3D = null
var csg_active_body_root: Node3D = null
var placement_cursor_mesh_instance: MeshInstance3D = null
var csg_static_zone_nodes: Dictionary = {}
var csg_static_zone_signatures: Dictionary = {}
var csg_static_zone_body_ids_by_key: Dictionary = {}
var csg_static_body_zone_key_by_id: Dictionary = {}
var csg_static_zones_initialized := false

func _ready() -> void:
	_ensure_preview_mesh_instance()
	_ensure_spline_preview_mesh_instance()
	_ensure_spline_csg_nodes()
	_ensure_csg_material_body_root()
	_ensure_placement_cursor_mesh_instance()

func bind_stage_controller(stage_controller: Node) -> void:
	if active_stage_controller == stage_controller:
		_sync_from_controller()
		return
	_disconnect_stage_controller()
	active_stage_controller = stage_controller
	_connect_stage_controller()
	_sync_from_controller()

func clear_stage_controller() -> void:
	_disconnect_stage_controller()
	active_stage_controller = null
	_sync_preview_mesh(null)
	_sync_spline_preview_mesh(null)
	_sync_spline_csg_noodle(null)
	_sync_csg_material_body_preview(null)
	_sync_placement_cursor(Vector3.ZERO, false, DEFAULT_PREVIEW_RADIUS_METERS)

func _connect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.has_signal("authoring_state_changed"):
		return
	if not active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.connect(_on_authoring_state_changed)
	if active_stage_controller.has_signal("placement_cursor_changed"):
		if not active_stage_controller.placement_cursor_changed.is_connected(_on_placement_cursor_changed):
			active_stage_controller.placement_cursor_changed.connect(_on_placement_cursor_changed)
	if active_stage_controller.has_method("get_placement_cursor_state"):
		var cursor_state: Dictionary = active_stage_controller.call("get_placement_cursor_state")
		_sync_placement_cursor(
			cursor_state.get("local_position", Vector3.ZERO) as Vector3,
			bool(cursor_state.get("is_valid", false)),
			float(cursor_state.get("radius_meters", DEFAULT_PREVIEW_RADIUS_METERS))
		)

func _disconnect_stage_controller() -> void:
	if active_stage_controller == null:
		return
	if not active_stage_controller.has_signal("authoring_state_changed"):
		return
	if active_stage_controller.authoring_state_changed.is_connected(_on_authoring_state_changed):
		active_stage_controller.authoring_state_changed.disconnect(_on_authoring_state_changed)
	if active_stage_controller.has_signal("placement_cursor_changed"):
		if active_stage_controller.placement_cursor_changed.is_connected(_on_placement_cursor_changed):
			active_stage_controller.placement_cursor_changed.disconnect(_on_placement_cursor_changed)

func _on_authoring_state_changed(_state: Resource) -> void:
	_sync_from_controller()

func _on_placement_cursor_changed(local_position: Vector3, is_valid: bool, radius_meters: float) -> void:
	_sync_placement_cursor(local_position, is_valid, radius_meters)

func _sync_from_controller() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("get_active_authoring_state"):
		_sync_preview_mesh(null)
		_sync_spline_preview_mesh(null)
		_sync_spline_csg_noodle(null)
		_sync_csg_material_body_preview(null)
		return
	var authoring_state: Resource = active_stage_controller.call("get_active_authoring_state") as Resource
	_sync_preview_mesh(authoring_state)
	_sync_spline_preview_mesh(authoring_state)
	_sync_spline_csg_noodle(authoring_state)
	_sync_csg_material_body_preview(authoring_state)

func _sync_preview_mesh(authoring_state: Resource) -> void:
	_ensure_preview_mesh_instance()
	if preview_mesh_instance == null:
		return
	if authoring_state == null:
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	if _has_csg_material_body_records(authoring_state):
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	var active_preview_records: Array = _collect_active_placement_preview_records(authoring_state)
	if not active_preview_records.is_empty():
		var active_preview_mesh: ArrayMesh = _build_preview_mesh(active_preview_records)
		if active_preview_mesh != null and active_preview_mesh.get_surface_count() > 0:
			preview_mesh_instance.mesh = active_preview_mesh
			preview_mesh_instance.material_override = _build_preview_material()
			preview_mesh_instance.visible = true
			return
	var volume_records: Array = authoring_state.get("material_bodies")
	var preview_mesh: ArrayMesh = _build_preview_mesh(volume_records)
	if preview_mesh == null or preview_mesh.get_surface_count() <= 0:
		preview_mesh_instance.visible = false
		preview_mesh_instance.mesh = null
		return
	preview_mesh_instance.mesh = preview_mesh
	preview_mesh_instance.material_override = _build_preview_material()
	preview_mesh_instance.visible = true

func _sync_spline_preview_mesh(authoring_state: Resource) -> void:
	_ensure_spline_preview_mesh_instance()
	if spline_preview_mesh_instance == null:
		return
	if authoring_state == null:
		spline_preview_mesh_instance.visible = false
		spline_preview_mesh_instance.mesh = null
		return
	var spline_points: PackedVector3Array = authoring_state.get("spline_line_points")
	var selected_point_index: int = int(authoring_state.get("selected_spline_point_index"))
	var spline_finished: bool = bool(authoring_state.get("spline_line_finished"))
	var spline_mesh: ArrayMesh = _build_spline_preview_mesh(spline_points, selected_point_index, spline_finished)
	if spline_mesh == null or spline_mesh.get_surface_count() <= 0:
		spline_preview_mesh_instance.visible = false
		spline_preview_mesh_instance.mesh = null
		return
	spline_preview_mesh_instance.mesh = spline_mesh
	spline_preview_mesh_instance.material_override = _build_spline_preview_material()
	spline_preview_mesh_instance.visible = true

func _sync_spline_csg_noodle(authoring_state: Resource) -> void:
	_ensure_spline_csg_nodes()
	if spline_csg_path == null or spline_csg_polygon == null:
		return
	if authoring_state == null or not bool(authoring_state.get("spline_line_csg_noodle_enabled")):
		spline_csg_polygon.visible = false
		spline_csg_path.curve = null
		return
	var spline_points: PackedVector3Array = authoring_state.get("spline_line_points")
	if spline_points.size() < 2:
		spline_csg_polygon.visible = false
		spline_csg_path.curve = null
		return
	var radius_meters: float = maxf(float(authoring_state.get("active_brush_radius_meters")), 0.001)
	var path_interval_meters := _resolve_spline_csg_path_interval(radius_meters)
	spline_csg_path.curve = _build_spline_csg_curve(spline_points, path_interval_meters)
	spline_csg_polygon.mode = CSGPolygon3D.MODE_PATH
	spline_csg_polygon.path_node = spline_csg_polygon.get_path_to(spline_csg_path)
	spline_csg_polygon.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	spline_csg_polygon.path_interval = path_interval_meters
	spline_csg_polygon.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	spline_csg_polygon.path_rotation_accurate = true
	spline_csg_polygon.path_continuous_u = true
	spline_csg_polygon.path_u_distance = 0.0
	spline_csg_polygon.smooth_faces = true
	spline_csg_polygon.polygon = _build_circle_profile_polygon(radius_meters, SPLINE_CSG_CIRCLE_SIDES)
	spline_csg_polygon.material = _build_spline_csg_material(StringName(authoring_state.get("active_material_variant_id")))
	spline_csg_polygon.visible = true

func _sync_csg_material_body_preview(authoring_state: Resource) -> void:
	_ensure_csg_material_body_root()
	if csg_material_body_root == null:
		return
	if authoring_state == null:
		_clear_csg_material_body_root()
		csg_material_body_root.visible = false
		return
	var material_bodies: Array = _collect_active_csg_material_bodies(authoring_state)
	var active_body_id := _get_active_placement_body_id()
	var active_body_index := _find_body_index_by_id(material_bodies, active_body_id)
	var static_bodies := _filter_body_list_excluding_id(material_bodies, active_body_id)
	if active_body_index >= 0:
		if not csg_static_zones_initialized:
			_sync_static_csg_zones(static_bodies)
		_apply_static_zone_visibility({})
		_sync_active_csg_preview_body(material_bodies, active_body_index)
	else:
		_sync_static_csg_zones(static_bodies)
		_apply_static_zone_visibility({})
		_clear_node_children(csg_active_body_root)
		if csg_active_body_root != null:
			csg_active_body_root.visible = false
	csg_material_body_root.visible = (
		(csg_static_body_root != null and csg_static_body_root.visible)
		or (csg_active_body_root != null and csg_active_body_root.visible)
	)

func _sync_static_csg_zones(static_bodies: Array) -> void:
	if csg_static_body_root == null:
		return
	csg_static_zones_initialized = true
	var zones: Array = _build_csg_body_zones(static_bodies)
	var next_zone_keys: Dictionary = {}
	csg_static_zone_body_ids_by_key = {}
	csg_static_body_zone_key_by_id = {}
	for zone_variant: Variant in zones:
		if not (zone_variant is Dictionary):
			continue
		var zone: Dictionary = zone_variant as Dictionary
		var zone_key: String = String(zone.get("zone_key", ""))
		if zone_key.is_empty():
			continue
		next_zone_keys[zone_key] = true
		var primary_body_ids: Array = zone.get("primary_body_ids", []) as Array
		csg_static_zone_body_ids_by_key[zone_key] = primary_body_ids
		for body_id_variant: Variant in primary_body_ids:
			csg_static_body_zone_key_by_id[StringName(body_id_variant)] = zone_key
		var zone_signature: String = String(zone.get("signature", ""))
		var zone_node: Node = csg_static_zone_nodes.get(zone_key, null) as Node
		if (
			zone_node == null
			or not is_instance_valid(zone_node)
			or String(csg_static_zone_signatures.get(zone_key, "")) != zone_signature
		):
			if zone_node != null and is_instance_valid(zone_node):
				csg_static_body_root.remove_child(zone_node)
				zone_node.free()
			zone_node = _build_csg_zone_node(zone, true, "StaticZone")
			csg_static_body_root.add_child(zone_node)
			csg_static_zone_nodes[zone_key] = zone_node
			csg_static_zone_signatures[zone_key] = zone_signature
	var stale_zone_keys: Array = csg_static_zone_nodes.keys()
	for stale_key_variant: Variant in stale_zone_keys:
		var stale_key := String(stale_key_variant)
		if next_zone_keys.has(stale_key):
			continue
		var stale_node: Node = csg_static_zone_nodes.get(stale_key, null) as Node
		if stale_node != null and is_instance_valid(stale_node):
			csg_static_body_root.remove_child(stale_node)
			stale_node.free()
		csg_static_zone_nodes.erase(stale_key)
		csg_static_zone_signatures.erase(stale_key)
	csg_static_body_root.visible = not zones.is_empty()

func _sync_active_csg_preview_body(material_bodies: Array, active_body_index: int) -> void:
	if csg_active_body_root == null:
		return
	_clear_node_children(csg_active_body_root)
	if active_body_index < 0 or active_body_index >= material_bodies.size():
		csg_active_body_root.visible = false
		return
	var active_body: Resource = material_bodies[active_body_index] as Resource
	if active_body == null:
		csg_active_body_root.visible = false
		return
	var material_variant_id := StringName(active_body.get("material_variant_id"))
	var combiner := CSGCombiner3D.new()
	combiner.name = "ActivePreview_%s" % String(material_variant_id)
	combiner.operation = CSGShape3D.OPERATION_UNION
	csg_active_body_root.add_child(combiner)
	var appended := false
	if not _is_remove_material_body(active_body):
		appended = _append_csg_clipped_body_shape(
			combiner,
			active_body,
			[],
			material_variant_id,
			0,
			false
		)
	else:
		appended = _append_csg_body_shape(
			combiner,
			active_body,
			material_variant_id,
			false,
			0
		)
	_configure_material_surface_collision(combiner, material_variant_id, false)
	combiner.visible = appended
	if not appended:
		csg_active_body_root.visible = false
		return
	csg_active_body_root.visible = true

func _build_csg_zone_node(
	zone: Dictionary,
	enable_collision: bool,
	name_prefix: String
) -> CSGCombiner3D:
	var material_variant_id: StringName = StringName(zone.get("material_variant_id", StringName()))
	var primary_body_ids: Array = zone.get("primary_body_ids", []) as Array
	var combiner := CSGCombiner3D.new()
	combiner.name = "%s_%s" % [name_prefix, String(zone.get("zone_key", String(material_variant_id)))]
	combiner.operation = CSGShape3D.OPERATION_UNION
	var body_shape_index := 0
	var body_records: Array = zone.get("body_records", []) as Array
	for body_record_variant: Variant in body_records:
		if not (body_record_variant is Dictionary):
			continue
		var body_record: Dictionary = body_record_variant as Dictionary
		var body: Resource = body_record.get("body", null) as Resource
		var clip_bodies: Array = body_record.get("clip_bodies", []) as Array
		var is_active_body := bool(body_record.get("is_active_body", false))
		if _append_csg_clipped_body_shape(
			combiner,
			body,
			clip_bodies,
			material_variant_id,
				body_shape_index,
				false
			):
			body_shape_index += 1
	combiner.visible = body_shape_index > 0
	_configure_material_surface_collision(
		combiner,
		material_variant_id,
		enable_collision and body_shape_index > 0,
		_resolve_zone_collision_body_id(primary_body_ids)
	)
	return combiner

func _ensure_preview_mesh_instance() -> void:
	if preview_mesh_instance != null and is_instance_valid(preview_mesh_instance):
		return
	preview_mesh_instance = get_node_or_null("VolumeStrokePreviewMesh") as MeshInstance3D
	if preview_mesh_instance != null:
		return
	preview_mesh_instance = MeshInstance3D.new()
	preview_mesh_instance.name = "VolumeStrokePreviewMesh"
	add_child(preview_mesh_instance)

func _ensure_spline_preview_mesh_instance() -> void:
	if spline_preview_mesh_instance != null and is_instance_valid(spline_preview_mesh_instance):
		return
	spline_preview_mesh_instance = get_node_or_null("SplineLinePreviewMesh") as MeshInstance3D
	if spline_preview_mesh_instance != null:
		return
	spline_preview_mesh_instance = MeshInstance3D.new()
	spline_preview_mesh_instance.name = "SplineLinePreviewMesh"
	add_child(spline_preview_mesh_instance)

func _ensure_spline_csg_nodes() -> void:
	if spline_csg_path == null or not is_instance_valid(spline_csg_path):
		spline_csg_path = get_node_or_null("SplineCsgPath") as Path3D
		if spline_csg_path == null:
			spline_csg_path = Path3D.new()
			spline_csg_path.name = "SplineCsgPath"
			add_child(spline_csg_path)
	if spline_csg_polygon == null or not is_instance_valid(spline_csg_polygon):
		spline_csg_polygon = get_node_or_null("SplineCsgNoodle") as CSGPolygon3D
		if spline_csg_polygon == null:
			spline_csg_polygon = CSGPolygon3D.new()
			spline_csg_polygon.name = "SplineCsgNoodle"
			add_child(spline_csg_polygon)
	spline_csg_polygon.visible = false

func _ensure_csg_material_body_root() -> void:
	if csg_material_body_root != null and is_instance_valid(csg_material_body_root):
		_ensure_csg_material_body_branch_roots()
		return
	csg_material_body_root = get_node_or_null("MaterialBodyCsgRoot") as Node3D
	if csg_material_body_root == null:
		csg_material_body_root = Node3D.new()
		csg_material_body_root.name = "MaterialBodyCsgRoot"
		add_child(csg_material_body_root)
	_ensure_csg_material_body_branch_roots()

func _ensure_csg_material_body_branch_roots() -> void:
	if csg_material_body_root == null:
		return
	if csg_static_body_root == null or not is_instance_valid(csg_static_body_root):
		csg_static_body_root = csg_material_body_root.get_node_or_null("StaticMaterialBodyCsgRoot") as Node3D
		if csg_static_body_root == null:
			csg_static_body_root = Node3D.new()
			csg_static_body_root.name = "StaticMaterialBodyCsgRoot"
			csg_material_body_root.add_child(csg_static_body_root)
	if csg_active_body_root == null or not is_instance_valid(csg_active_body_root):
		csg_active_body_root = csg_material_body_root.get_node_or_null("ActiveMaterialBodyCsgRoot") as Node3D
		if csg_active_body_root == null:
			csg_active_body_root = Node3D.new()
			csg_active_body_root.name = "ActiveMaterialBodyCsgRoot"
			csg_material_body_root.add_child(csg_active_body_root)

func _clear_csg_material_body_root() -> void:
	if csg_material_body_root == null:
		return
	for child: Node in csg_material_body_root.get_children():
		csg_material_body_root.remove_child(child)
		child.free()
	csg_static_body_root = null
	csg_active_body_root = null
	csg_static_zone_nodes = {}
	csg_static_zone_signatures = {}
	csg_static_zone_body_ids_by_key = {}
	csg_static_body_zone_key_by_id = {}
	csg_static_zones_initialized = false
	_ensure_csg_material_body_branch_roots()

func _clear_node_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()

func _configure_material_surface_collision(
	shape: CSGShape3D,
	material_variant_id: StringName,
	enabled: bool,
	body_id: StringName = StringName()
) -> void:
	if shape == null:
		return
	shape.use_collision = enabled
	shape.collision_layer = MATERIAL_SURFACE_COLLISION_LAYER if enabled else 0
	shape.collision_mask = 0
	shape.set_meta("forge_v2_material_surface", enabled)
	shape.set_meta("forge_v2_material_variant_id", material_variant_id)
	shape.set_meta("forge_v2_body_id", body_id)

func _get_active_placement_body_id() -> StringName:
	if active_stage_controller == null or not active_stage_controller.has_method("get_active_placement_body_id"):
		return StringName()
	return StringName(active_stage_controller.call("get_active_placement_body_id"))

func _collect_active_placement_preview_records(authoring_state: Resource) -> Array:
	var active_body_id := _get_active_placement_body_id()
	if active_body_id == StringName() or authoring_state == null:
		return []
	var preview_records: Array = []
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if StringName(body.get("body_id")) != active_body_id:
			continue
		if body.has_method("normalize"):
			body.call("normalize")
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			continue
		preview_records.append(body)
		return preview_records
	return preview_records

func _has_csg_material_body_records(authoring_state: Resource) -> bool:
	if authoring_state == null:
		return false
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if body.has_method("normalize"):
			body.call("normalize")
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			continue
		var path_points: PackedVector3Array = body.get("path_points")
		if not path_points.is_empty():
			return true
	return false

func _collect_csg_material_body_groups(authoring_state: Resource) -> Dictionary:
	if authoring_state == null:
		return {}
	var material_bodies: Array = _collect_active_csg_material_bodies(authoring_state)
	return _collect_csg_material_body_groups_from_bodies(material_bodies)

func _collect_csg_material_body_groups_from_bodies(material_bodies: Array) -> Dictionary:
	var material_groups: Dictionary = {}
	var active_body_id := _get_active_placement_body_id()
	for body_index in range(material_bodies.size()):
		var body: Resource = material_bodies[body_index] as Resource
		if _is_remove_material_body(body):
			continue
		var material_variant_id: StringName = StringName(body.get("material_variant_id"))
		var group_record: Dictionary = material_groups.get(material_variant_id, {
			"body_records": [],
		}) as Dictionary
		var body_records: Array = group_record.get("body_records", []) as Array
		body_records.append({
			"body": body,
			"clip_bodies": _collect_csg_clip_bodies_for_add_body(material_bodies, body_index),
			"is_active_body": active_body_id != StringName() and StringName(body.get("body_id")) == active_body_id,
		})
		group_record["body_records"] = body_records
		material_groups[material_variant_id] = group_record
	return material_groups

func _find_body_index_by_id(material_bodies: Array, body_id: StringName) -> int:
	if body_id == StringName():
		return -1
	for body_index in range(material_bodies.size()):
		var body: Resource = material_bodies[body_index] as Resource
		if body != null and StringName(body.get("body_id")) == body_id:
			return body_index
	return -1

func _filter_body_list_excluding_id(material_bodies: Array, excluded_body_id: StringName) -> Array:
	var filtered_bodies: Array = []
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if excluded_body_id != StringName() and StringName(body.get("body_id")) == excluded_body_id:
			continue
		filtered_bodies.append(body)
	return filtered_bodies

func _collect_direct_dirty_primary_body_ids(material_bodies: Array, active_body_index: int) -> Array[StringName]:
	var dirty_body_ids: Array[StringName] = []
	if active_body_index < 0 or active_body_index >= material_bodies.size():
		return dirty_body_ids
	var active_body: Resource = material_bodies[active_body_index] as Resource
	var active_bounds: AABB = _build_csg_body_bounds(active_body)
	for body_index in range(material_bodies.size()):
		if body_index == active_body_index:
			continue
		var body: Resource = material_bodies[body_index] as Resource
		if body == null or _is_remove_material_body(body):
			continue
		if _csg_body_bounds_intersect(active_bounds, _build_csg_body_bounds(body)):
			dirty_body_ids.append(StringName(body.get("body_id")))
	return dirty_body_ids

func _resolve_static_zone_keys_for_body_ids(body_ids: Array[StringName]) -> Dictionary:
	var zone_keys: Dictionary = {}
	for body_id: StringName in body_ids:
		var zone_key := String(csg_static_body_zone_key_by_id.get(body_id, ""))
		if not zone_key.is_empty():
			zone_keys[zone_key] = true
	return zone_keys

func _resolve_static_primary_body_ids_for_zone_keys(zone_keys: Dictionary) -> Array[StringName]:
	var body_ids: Array[StringName] = []
	for zone_key_variant: Variant in zone_keys.keys():
		var zone_key := String(zone_key_variant)
		var zone_body_ids: Array = csg_static_zone_body_ids_by_key.get(zone_key, []) as Array
		for body_id_variant: Variant in zone_body_ids:
			var body_id := StringName(body_id_variant)
			if not body_ids.has(body_id):
				body_ids.append(body_id)
	return body_ids

func _apply_static_zone_visibility(hidden_zone_keys: Dictionary) -> void:
	if csg_static_body_root == null:
		return
	var has_visible_zone := false
	for zone_key_variant: Variant in csg_static_zone_nodes.keys():
		var zone_key := String(zone_key_variant)
		var zone_node: Node = csg_static_zone_nodes.get(zone_key, null) as Node
		if zone_node == null or not is_instance_valid(zone_node):
			continue
		var is_visible := not hidden_zone_keys.has(zone_key)
		zone_node.visible = is_visible
		has_visible_zone = has_visible_zone or is_visible
	csg_static_body_root.visible = has_visible_zone

func _collect_active_dirty_zone_bodies(
	material_bodies: Array,
	active_body_index: int,
	dirty_primary_body_ids: Array[StringName]
) -> Array:
	var dirty_bodies: Array = []
	if active_body_index < 0 or active_body_index >= material_bodies.size():
		return dirty_bodies
	var dirty_bounds: Array[AABB] = []
	var active_body: Resource = material_bodies[active_body_index] as Resource
	if active_body == null:
		return dirty_bodies
	dirty_bodies.append(active_body)
	dirty_bounds.append(_build_csg_body_bounds(active_body))
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		var body_id := StringName(body.get("body_id"))
		if body_id == StringName(active_body.get("body_id")):
			continue
		if dirty_primary_body_ids.has(body_id):
			dirty_bodies.append(body)
			dirty_bounds.append(_build_csg_body_bounds(body))
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if dirty_bodies.has(body):
			continue
		if _csg_body_intersects_any_bounds(body, dirty_bounds):
			dirty_bodies.append(body)
	return dirty_bodies

func _build_csg_body_zones(material_bodies: Array) -> Array:
	var records: Array = []
	var active_body_id := _get_active_placement_body_id()
	for body_index in range(material_bodies.size()):
		var body: Resource = material_bodies[body_index] as Resource
		if body == null or _is_remove_material_body(body):
			continue
		records.append({
			"body": body,
			"body_index": body_index,
			"material_variant_id": StringName(body.get("material_variant_id")),
			"bounds": _build_csg_body_bounds(body),
			"clip_bodies": _collect_csg_clip_bodies_for_add_body(material_bodies, body_index),
			"is_active_body": active_body_id != StringName() and StringName(body.get("body_id")) == active_body_id,
		})
	if records.is_empty():
		return []
	var parents: Array[int] = []
	for record_index in range(records.size()):
		parents.append(record_index)
	for first_index in range(records.size()):
		var first_record: Dictionary = records[first_index] as Dictionary
		for second_index in range(first_index + 1, records.size()):
			var second_record: Dictionary = records[second_index] as Dictionary
			if StringName(first_record.get("material_variant_id")) != StringName(second_record.get("material_variant_id")):
				continue
			if _csg_bounds_intersect(
				first_record.get("bounds", AABB()) as AABB,
				second_record.get("bounds", AABB()) as AABB
			):
				_union_zone_parent(parents, first_index, second_index)
	var grouped_records: Dictionary = {}
	for record_index in range(records.size()):
		var root_index := _find_zone_parent(parents, record_index)
		var group_records: Array = grouped_records.get(root_index, []) as Array
		group_records.append(records[record_index])
		grouped_records[root_index] = group_records
	var zones: Array = []
	for root_key: Variant in grouped_records.keys():
		var group_records: Array = grouped_records[root_key] as Array
		zones.append(_build_csg_zone_from_records(group_records))
	return zones

func _build_csg_zone_from_records(records: Array) -> Dictionary:
	var primary_body_ids: Array[StringName] = []
	var body_records: Array = []
	var material_variant_id := StringName()
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant as Dictionary
		var body: Resource = record.get("body", null) as Resource
		if body == null:
			continue
		material_variant_id = StringName(record.get("material_variant_id", material_variant_id))
		var body_id := StringName(body.get("body_id"))
		if not primary_body_ids.has(body_id):
			primary_body_ids.append(body_id)
		body_records.append({
			"body": body,
			"clip_bodies": record.get("clip_bodies", []) as Array,
			"is_active_body": bool(record.get("is_active_body", false)),
		})
	primary_body_ids.sort()
	var id_parts: PackedStringArray = []
	for body_id: StringName in primary_body_ids:
		id_parts.append(String(body_id))
	var zone_key := "%s:%s" % [String(material_variant_id), ",".join(id_parts)]
	return {
		"zone_key": zone_key,
		"material_variant_id": material_variant_id,
		"primary_body_ids": primary_body_ids,
		"body_records": body_records,
		"signature": _build_csg_zone_signature(body_records),
	}

func _build_csg_zone_signature(body_records: Array) -> String:
	var parts: PackedStringArray = []
	for body_record_variant: Variant in body_records:
		if not (body_record_variant is Dictionary):
			continue
		var body_record: Dictionary = body_record_variant as Dictionary
		var body: Resource = body_record.get("body", null) as Resource
		var clip_bodies: Array = body_record.get("clip_bodies", []) as Array
		var clip_parts: PackedStringArray = []
		for clip_body_variant: Variant in clip_bodies:
			if clip_body_variant is Resource:
				clip_parts.append(_build_csg_body_signature(clip_body_variant as Resource))
		parts.append("%s clips[%s]" % [_build_csg_body_signature(body), " / ".join(clip_parts)])
	return "\n".join(parts)

func _resolve_zone_collision_body_id(primary_body_ids: Array) -> StringName:
	if primary_body_ids.size() == 1:
		return StringName(primary_body_ids[0])
	return StringName()

func _find_zone_parent(parents: Array[int], index: int) -> int:
	var current := index
	while parents[current] != current:
		current = parents[current]
	var root := current
	current = index
	while parents[current] != current:
		var next := parents[current]
		parents[current] = root
		current = next
	return root

func _union_zone_parent(parents: Array[int], first_index: int, second_index: int) -> void:
	var first_root := _find_zone_parent(parents, first_index)
	var second_root := _find_zone_parent(parents, second_index)
	if first_root != second_root:
		parents[second_root] = first_root

func _build_csg_body_bounds(body: Resource) -> AABB:
	if body == null:
		return AABB()
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.is_empty():
		return AABB()
	var min_point: Vector3 = path_points[0]
	var max_point: Vector3 = path_points[0]
	for point: Vector3 in path_points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		min_point.z = minf(min_point.z, point.z)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
		max_point.z = maxf(max_point.z, point.z)
	var radius := maxf(float(body.get("radius_meters")), 0.001)
	var margin := Vector3.ONE * radius
	return AABB(min_point - margin, (max_point - min_point) + (margin * 2.0))

func _csg_body_intersects_any_bounds(body: Resource, bounds_list: Array[AABB]) -> bool:
	var body_bounds := _build_csg_body_bounds(body)
	for bounds: AABB in bounds_list:
		if _csg_bounds_intersect(body_bounds, bounds):
			return true
	return false

func _csg_body_bounds_intersect(first_bounds: AABB, second_bounds: AABB) -> bool:
	return _csg_bounds_intersect(first_bounds, second_bounds)

func _csg_bounds_intersect(first_bounds: AABB, second_bounds: AABB) -> bool:
	var margin := 0.0001
	var grown_first := AABB(
		first_bounds.position - (Vector3.ONE * margin),
		first_bounds.size + (Vector3.ONE * margin * 2.0)
	)
	var grown_second := AABB(
		second_bounds.position - (Vector3.ONE * margin),
		second_bounds.size + (Vector3.ONE * margin * 2.0)
	)
	return grown_first.intersects(grown_second)

func _build_csg_body_list_signature(material_bodies: Array) -> String:
	if material_bodies.is_empty():
		return ""
	var parts: PackedStringArray = []
	for body_variant: Variant in material_bodies:
		if body_variant is Resource:
			parts.append(_build_csg_body_signature(body_variant as Resource))
	return "\n".join(parts)

func _build_csg_body_signature(body: Resource) -> String:
	if body == null:
		return ""
	var path_points: PackedVector3Array = body.get("path_points")
	var point_parts: PackedStringArray = []
	for point: Vector3 in path_points:
		point_parts.append("%.5f,%.5f,%.5f" % [point.x, point.y, point.z])
	var profile_polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	var profile_point_parts: PackedStringArray = []
	for profile_point: Vector2 in profile_polygon:
		profile_point_parts.append("%.5f,%.5f" % [profile_point.x, profile_point.y])
	var profile_anchor_value: Variant = body.get("profile_anchor_2d_meters")
	var profile_anchor := Vector2.ZERO
	if profile_anchor_value is Vector2:
		profile_anchor = profile_anchor_value as Vector2
	var path_surface_normals: PackedVector3Array = body.get(
		"path_surface_normals"
	)
	var normal_parts: PackedStringArray = []
	for surface_normal: Vector3 in path_surface_normals:
		normal_parts.append("%.5f,%.5f,%.5f" % [
			surface_normal.x,
			surface_normal.y,
			surface_normal.z,
		])
	var profile_contact_direction: Vector2 = body.get(
		"profile_contact_direction_2d"
	)
	return "|".join([
		String(body.get("body_id")),
		String(body.get("body_kind")),
		String(body.get("material_variant_id")),
		String(body.get("operation_mode")),
		String(body.get("placement_policy")),
		String(body.get("shape_kind")),
		str(float(body.get("radius_meters"))),
		String(body.get("profile_id")),
		String(body.get("profile_role")),
		"%.5f,%.5f" % [profile_anchor.x, profile_anchor.y],
		"%.5f,%.5f" % [
			profile_contact_direction.x,
			profile_contact_direction.y,
		],
		str(int(body.get("profile_runtime_schema_version"))),
		str(float(body.get("profile_rotation_bias_degrees"))),
		str(float(body.get("profile_twist_degrees_per_meter"))),
		str(StringName(body.get("committed_layer_id"))),
		str(bool(body.get("layer_active"))),
		str(float(body.get("updated_timestamp"))),
		";".join(point_parts),
		";".join(normal_parts),
		";".join(profile_point_parts),
	])

func _collect_active_csg_material_bodies(authoring_state: Resource) -> Array:
	var active_bodies: Array = []
	if authoring_state == null:
		return active_bodies
	var material_bodies: Array = authoring_state.get("material_bodies")
	for body_variant: Variant in material_bodies:
		if not (body_variant is Resource):
			continue
		var body: Resource = body_variant as Resource
		if body.has_method("normalize"):
			body.call("normalize")
		if body.get("layer_active") is bool and not bool(body.get("layer_active")):
			continue
		var path_points: PackedVector3Array = body.get("path_points")
		if path_points.is_empty():
			continue
		active_bodies.append(body)
	return active_bodies

func _collect_csg_clip_bodies_for_add_body(material_bodies: Array, body_index: int) -> Array:
	var clip_bodies: Array = []
	if body_index < 0 or body_index >= material_bodies.size():
		return clip_bodies
	var body: Resource = material_bodies[body_index] as Resource
	var body_bounds := _build_csg_body_bounds(body)
	var material_variant_id: StringName = StringName(body.get("material_variant_id"))
	if StringName(body.get("placement_policy")) == ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY:
		for previous_index in range(body_index):
			var previous_body: Resource = material_bodies[previous_index] as Resource
			if (
				previous_body != null
				and not _is_remove_material_body(previous_body)
				and _csg_body_bounds_intersect(body_bounds, _build_csg_body_bounds(previous_body))
			):
				clip_bodies.append(previous_body)
	for next_index in range(body_index + 1, material_bodies.size()):
		var next_body: Resource = material_bodies[next_index] as Resource
		if next_body == null:
			continue
		if not _csg_body_bounds_intersect(body_bounds, _build_csg_body_bounds(next_body)):
			continue
		if _is_remove_material_body(next_body):
			clip_bodies.append(next_body)
			continue
		var next_policy: StringName = StringName(next_body.get("placement_policy"))
		var next_material_variant_id: StringName = StringName(next_body.get("material_variant_id"))
		if (
			next_policy == ForgeV2VolumeStrokeScript.PLACEMENT_REPLACE_EXISTING
			and next_material_variant_id != material_variant_id
		):
			clip_bodies.append(next_body)
	return clip_bodies

func _is_remove_material_body(body: Resource) -> bool:
	return body != null and StringName(body.get("operation_mode")) == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL

func _append_csg_clipped_body_shape(
	parent: Node,
	body: Resource,
	clip_bodies: Array,
	material_variant_id: StringName,
	body_shape_index: int,
	enable_collision: bool
) -> bool:
	if parent == null or body == null:
		return false
	var body_combiner := CSGCombiner3D.new()
	body_combiner.name = "BodyResolved_%03d" % body_shape_index
	body_combiner.operation = CSGShape3D.OPERATION_UNION
	parent.add_child(body_combiner)
	var child_shape_index := 0
	if not _append_csg_body_shape(body_combiner, body, material_variant_id, false, child_shape_index):
		parent.remove_child(body_combiner)
		body_combiner.free()
		return false
	child_shape_index += 1
	for clip_body_variant: Variant in clip_bodies:
		if not (clip_body_variant is Resource):
			continue
		var clip_body: Resource = clip_body_variant as Resource
		if _append_csg_body_shape(body_combiner, clip_body, material_variant_id, true, child_shape_index):
			child_shape_index += 1
	body_combiner.visible = true
	_configure_material_surface_collision(
		body_combiner,
		material_variant_id,
		enable_collision,
		StringName(body.get("body_id"))
	)
	return true

func _append_csg_body_shape(
	parent: Node,
	body: Resource,
	material_variant_id: StringName,
	is_subtraction: bool,
	body_shape_index: int
) -> bool:
	if parent == null or body == null:
		return false
	var path_points: PackedVector3Array = body.get("path_points")
	if path_points.is_empty():
		return false
	var radius_meters: float = maxf(float(body.get("radius_meters")), 0.001)
	var operation := CSGShape3D.OPERATION_SUBTRACTION if is_subtraction else CSGShape3D.OPERATION_UNION
	var shape_kind: StringName = StringName(body.get("shape_kind"))
	if _is_profile_shape_kind(shape_kind) and path_points.size() < 2:
		return false
	if path_points.size() == 1:
		var sphere := CSGSphere3D.new()
		sphere.name = "BodySphere_%03d" % body_shape_index
		sphere.operation = operation
		sphere.radius = radius_meters
		sphere.position = path_points[0]
		sphere.material = _build_csg_body_material(material_variant_id, is_subtraction)
		parent.add_child(sphere)
		return true
	var path_sampling_radius_meters := radius_meters
	if int(body.get("profile_runtime_schema_version")) > 0:
		path_sampling_radius_meters = maxf(
			float(body.get("profile_contact_distance_meters")),
			ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_ANCHOR_CLEARANCE_METERS
		)
	var path_interval_meters := _resolve_spline_csg_path_interval(
		path_sampling_radius_meters
	)
	if _is_profile_shape_kind(shape_kind):
		var profile_polygon := _resolve_body_profile_polygon(body)
		var curve: Curve3D = (
			_build_spline_csg_curve(path_points, path_interval_meters)
			if shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
			else _build_linear_csg_curve(path_points, path_interval_meters)
		)
		if int(body.get("profile_runtime_schema_version")) > 0:
			_apply_profile_curve_orientation(
				curve,
				path_points,
				body.get("path_surface_normals") as PackedVector3Array,
				body.get("profile_contact_direction_2d") as Vector2,
				float(body.get("profile_rotation_bias_degrees"))
			)
		return _append_csg_body_path_shape(
			parent,
			curve,
			radius_meters,
			material_variant_id,
			is_subtraction,
			operation,
			body_shape_index,
			0,
			profile_polygon
		)
	if shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH:
		return _append_csg_body_path_shape(
			parent,
			_build_spline_csg_curve(path_points, path_interval_meters),
			radius_meters,
			material_variant_id,
			is_subtraction,
			operation,
			body_shape_index,
			0
		)
	return _append_csg_body_path_shape(
		parent,
		_build_linear_csg_curve(path_points, path_interval_meters),
		radius_meters,
		material_variant_id,
		is_subtraction,
		operation,
		body_shape_index,
		0
	)

func _append_csg_body_path_shape(
	parent: Node,
	curve: Curve3D,
	radius_meters: float,
	material_variant_id: StringName,
	is_subtraction: bool,
	operation: int,
	body_shape_index: int,
	span_index: int,
	profile_polygon_2d_meters: PackedVector2Array = PackedVector2Array()
) -> bool:
	if parent == null or curve == null or curve.point_count < 2:
		return false
	var path := Path3D.new()
	path.name = "BodyPath_%03d_%03d" % [body_shape_index, span_index]
	path.curve = curve
	parent.add_child(path)
	var polygon := CSGPolygon3D.new()
	polygon.name = "BodyNoodle_%03d_%03d" % [body_shape_index, span_index]
	parent.add_child(polygon)
	polygon.operation = operation
	polygon.mode = CSGPolygon3D.MODE_PATH
	polygon.path_node = polygon.get_path_to(path)
	polygon.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	polygon.path_interval = maxf(curve.bake_interval, 0.001)
	polygon.path_rotation = CSGPolygon3D.PATH_ROTATION_PATH_FOLLOW
	polygon.path_rotation_accurate = true
	polygon.path_continuous_u = true
	polygon.path_u_distance = 0.0
	polygon.smooth_faces = true
	if profile_polygon_2d_meters.size() >= 3:
		polygon.polygon = profile_polygon_2d_meters
	else:
		polygon.polygon = _build_circle_profile_polygon(radius_meters, SPLINE_CSG_CIRCLE_SIDES)
	polygon.material = _build_csg_body_material(material_variant_id, is_subtraction)
	return true

func _ensure_placement_cursor_mesh_instance() -> void:
	if placement_cursor_mesh_instance != null and is_instance_valid(placement_cursor_mesh_instance):
		return
	placement_cursor_mesh_instance = get_node_or_null("PlacementCursorMesh") as MeshInstance3D
	if placement_cursor_mesh_instance == null:
		placement_cursor_mesh_instance = MeshInstance3D.new()
		placement_cursor_mesh_instance.name = "PlacementCursorMesh"
		add_child(placement_cursor_mesh_instance)
	placement_cursor_mesh_instance.visible = false
	placement_cursor_mesh_instance.material_override = _build_placement_cursor_material()

func _sync_placement_cursor(local_position: Vector3, is_valid: bool, radius_meters: float) -> void:
	_ensure_placement_cursor_mesh_instance()
	if placement_cursor_mesh_instance == null:
		return
	placement_cursor_mesh_instance.visible = is_valid
	if not is_valid:
		return
	var sphere_mesh: SphereMesh = placement_cursor_mesh_instance.mesh as SphereMesh
	if sphere_mesh == null:
		sphere_mesh = SphereMesh.new()
		placement_cursor_mesh_instance.mesh = sphere_mesh
	var cursor_radius: float = maxf(radius_meters, 0.004)
	sphere_mesh.radius = cursor_radius
	sphere_mesh.height = cursor_radius * 2.0
	placement_cursor_mesh_instance.position = local_position

func _build_preview_mesh(volume_strokes: Array) -> ArrayMesh:
	if volume_strokes.is_empty():
		return ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added_vertices := 0
	for stroke: Resource in volume_strokes:
		if stroke == null:
			continue
		if stroke.has_method("normalize"):
			stroke.call("normalize")
		if stroke.get("layer_active") is bool and not bool(stroke.get("layer_active")):
			continue
		added_vertices += _append_stroke_preview(surface_tool, stroke)
	if added_vertices <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _build_spline_preview_mesh(
	spline_points: PackedVector3Array,
	selected_point_index: int,
	spline_finished: bool
) -> ArrayMesh:
	if spline_points.is_empty():
		return ArrayMesh.new()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added_vertices := 0
	var line_color := Color(0.18, 0.52, 1.0, 0.92) if not spline_finished else Color(0.42, 0.92, 0.78, 0.94)
	var point_color := Color(0.76, 0.9, 1.0, 1.0)
	var selected_color := Color(1.0, 0.88, 0.22, 1.0)
	if spline_points.size() >= 2:
		var spline_curve: Curve3D = _build_spline_curve(spline_points, SPLINE_PREVIEW_BAKE_INTERVAL_METERS)
		var baked_points: PackedVector3Array = spline_curve.get_baked_points()
		if baked_points.size() < 2:
			baked_points = _deduplicate_spline_points(spline_points)
		for point_index in range(baked_points.size() - 1):
			var from_point: Vector3 = baked_points[point_index]
			var to_point: Vector3 = baked_points[point_index + 1]
			if from_point.distance_squared_to(to_point) <= 0.000001:
				continue
			added_vertices += _append_tube_segment(
				surface_tool,
				from_point,
				to_point,
				SPLINE_PREVIEW_RADIUS_METERS,
				line_color
			)
	for point_index in range(spline_points.size()):
		var point_radius := SPLINE_SELECTED_POINT_RADIUS_METERS if point_index == selected_point_index else SPLINE_POINT_RADIUS_METERS
		var color := selected_color if point_index == selected_point_index else point_color
		added_vertices += _append_sphere(surface_tool, spline_points[point_index], point_radius, color)
	if added_vertices <= 0:
		return ArrayMesh.new()
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()

func _build_spline_csg_curve(spline_points: PackedVector3Array, path_interval_meters: float) -> Curve3D:
	return _build_spline_curve(spline_points, maxf(path_interval_meters, 0.001))

func _build_linear_csg_curve(path_points: PackedVector3Array, path_interval_meters: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = maxf(path_interval_meters, 0.001)
	var control_points := _deduplicate_spline_points(path_points)
	for point: Vector3 in control_points:
		curve.add_point(point)
	return curve

func _apply_profile_curve_orientation(
	curve: Curve3D,
	source_points: PackedVector3Array,
	source_surface_normals: PackedVector3Array,
	contact_direction_2d: Vector2,
	rotation_bias_degrees: float
) -> void:
	if curve == null or curve.point_count < 2:
		return
	var previous_tilt := 0.0
	var has_previous_tilt := false
	for point_index in range(curve.point_count):
		var tangent := _resolve_curve_point_tangent(curve, point_index)
		var point_position := curve.get_point_position(point_index)
		var surface_normal := (
			ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
			point_position,
			source_points,
			source_surface_normals
			)
		)
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			surface_normal,
			contact_direction_2d,
			rotation_bias_degrees
		)
		var tilt := float(frame.get("tilt_radians", 0.0))
		if has_previous_tilt:
			while tilt - previous_tilt > PI:
				tilt -= TAU
			while tilt - previous_tilt < -PI:
				tilt += TAU
		curve.set_point_tilt(point_index, tilt)
		previous_tilt = tilt
		has_previous_tilt = true

func _resolve_curve_point_tangent(
	curve: Curve3D,
	point_index: int
) -> Vector3:
	if curve == null or curve.point_count < 2:
		return Vector3.RIGHT
	var current_position := curve.get_point_position(point_index)
	var tangent := Vector3.ZERO
	if point_index > 0:
		tangent += current_position - curve.get_point_position(point_index - 1)
	if point_index < curve.point_count - 1:
		tangent += curve.get_point_position(point_index + 1) - current_position
	if tangent.length_squared() <= 0.000001:
		return Vector3.RIGHT
	return tangent.normalized()

func _resolve_spline_csg_path_interval(radius_meters: float) -> float:
	if active_stage_controller != null and active_stage_controller.has_method("get_workspace_contract"):
		var contract: Object = active_stage_controller.call("get_workspace_contract") as Object
		if contract != null and contract.has_method("resolve_stroke_sample_spacing"):
			return maxf(float(contract.call("resolve_stroke_sample_spacing", radius_meters)), 0.001)
	return maxf(
		maxf(radius_meters, 0.001) * SPLINE_CSG_PATH_INTERVAL_RADIUS_RATIO_FALLBACK,
		SPLINE_CSG_PATH_INTERVAL_MIN_METERS_FALLBACK
	)

func _build_spline_curve(spline_points: PackedVector3Array, bake_interval: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = maxf(bake_interval, 0.001)
	var control_points := _deduplicate_spline_points(spline_points)
	for point_index in range(control_points.size()):
		curve.add_point(
			control_points[point_index],
			_resolve_spline_effective_curve_handle(control_points, point_index, true),
			_resolve_spline_effective_curve_handle(control_points, point_index, false)
		)
	return curve

func _resolve_spline_effective_curve_handle(
	points: PackedVector3Array,
	point_index: int,
	use_in_handle: bool
) -> Vector3:
	if point_index < 0 or point_index >= points.size():
		return Vector3.ZERO
	# Forge V2 spline points do not store authored handles yet.
	return _resolve_spline_auto_curve_handle(points, point_index, use_in_handle)

func _resolve_spline_auto_curve_handle(
	points: PackedVector3Array,
	point_index: int,
	use_in_handle: bool
) -> Vector3:
	if point_index < 0 or point_index >= points.size():
		return Vector3.ZERO
	var current_position: Vector3 = points[point_index]
	var previous_position: Variant = null
	var next_position: Variant = null
	if point_index > 0:
		previous_position = points[point_index - 1]
	if point_index < points.size() - 1:
		next_position = points[point_index + 1]
	var auto_handle := Vector3.ZERO
	if previous_position is Vector3 and next_position is Vector3:
		var smooth_tangent: Vector3 = ((next_position as Vector3) - (previous_position as Vector3)) * SPLINE_AUTO_CURVE_MIDDLE_STRENGTH
		auto_handle = -smooth_tangent if use_in_handle else smooth_tangent
	elif use_in_handle and previous_position is Vector3:
		auto_handle = ((previous_position as Vector3) - current_position) * SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH
	elif not use_in_handle and next_position is Vector3:
		auto_handle = ((next_position as Vector3) - current_position) * SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH
	if auto_handle.length() < SPLINE_AUTO_CURVE_HANDLE_MIN_LENGTH_METERS:
		return Vector3.ZERO
	return auto_handle

func _build_circle_profile_polygon(radius_meters: float, side_count: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var resolved_side_count := maxi(side_count, 8)
	var resolved_radius := maxf(radius_meters, 0.001)
	for side_index in range(resolved_side_count):
		var angle := TAU * float(side_index) / float(resolved_side_count)
		polygon.append(Vector2(cos(angle), sin(angle)) * resolved_radius)
	return polygon

func _is_profile_shape_kind(shape_kind: StringName) -> bool:
	return (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		or shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	)

func _resolve_body_profile_polygon(body: Resource) -> PackedVector2Array:
	if body == null:
		return PackedVector2Array()
	var profile_polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if profile_polygon.size() >= 3:
		return profile_polygon
	var radius_meters: float = maxf(float(body.get("radius_meters")), 0.001)
	var profile_id: StringName = StringName(body.get("profile_id"))
	if profile_id != StringName():
		return ForgeV2ProfileShapeLibraryScript.resolve_profile_polygon(profile_id, radius_meters)
	return ForgeV2ProfileShapeLibraryScript.build_circle_polygon(radius_meters)

func _deduplicate_spline_points(points: PackedVector3Array) -> PackedVector3Array:
	var deduplicated := PackedVector3Array()
	for point: Vector3 in points:
		if not deduplicated.is_empty() and deduplicated[deduplicated.size() - 1].distance_squared_to(point) <= 0.000001:
			continue
		deduplicated.append(point)
	return deduplicated

func _append_stroke_preview(surface_tool: SurfaceTool, stroke: Resource) -> int:
	var path_points: PackedVector3Array = stroke.get("path_points")
	if path_points.is_empty():
		return 0
	var raw_radius_meters := float(stroke.get("radius_meters"))
	var radius_meters := raw_radius_meters if raw_radius_meters > 0.0 else DEFAULT_PREVIEW_RADIUS_METERS
	var color: Color = _resolve_stroke_color(stroke)
	var added_vertices := 0
	if path_points.size() == 1:
		return _append_sphere(surface_tool, path_points[0], radius_meters, color)
	for point_index in range(path_points.size() - 1):
		var from_point: Vector3 = path_points[point_index]
		var to_point: Vector3 = path_points[point_index + 1]
		if from_point.distance_squared_to(to_point) <= 0.000001:
			continue
		added_vertices += _append_tube_segment(surface_tool, from_point, to_point, radius_meters, color)
	for point: Vector3 in path_points:
		added_vertices += _append_sphere(surface_tool, point, radius_meters, color)
	return added_vertices

func _append_tube_segment(
	surface_tool: SurfaceTool,
	from_point: Vector3,
	to_point: Vector3,
	radius_meters: float,
	color: Color
) -> int:
	var tangent: Vector3 = (to_point - from_point).normalized()
	if tangent == Vector3.ZERO:
		return 0
	var normal: Vector3 = _resolve_perpendicular_normal(tangent)
	var binormal: Vector3 = tangent.cross(normal).normalized()
	var added_vertices := 0
	for side_index in range(PREVIEW_TUBE_SIDES):
		var next_side_index := (side_index + 1) % PREVIEW_TUBE_SIDES
		var angle_a := TAU * float(side_index) / float(PREVIEW_TUBE_SIDES)
		var angle_b := TAU * float(next_side_index) / float(PREVIEW_TUBE_SIDES)
		var offset_a: Vector3 = (normal * cos(angle_a) + binormal * sin(angle_a)) * radius_meters
		var offset_b: Vector3 = (normal * cos(angle_b) + binormal * sin(angle_b)) * radius_meters
		var from_a: Vector3 = from_point + offset_a
		var from_b: Vector3 = from_point + offset_b
		var to_a: Vector3 = to_point + offset_a
		var to_b: Vector3 = to_point + offset_b
		added_vertices += _append_triangle(surface_tool, from_a, to_a, to_b, color)
		added_vertices += _append_triangle(surface_tool, from_a, to_b, from_b, color)
	return added_vertices

func _append_sphere(
	surface_tool: SurfaceTool,
	center_point: Vector3,
	radius_meters: float,
	color: Color
) -> int:
	var added_vertices := 0
	for ring_index in range(PREVIEW_SPHERE_RINGS):
		var theta_a := PI * float(ring_index) / float(PREVIEW_SPHERE_RINGS)
		var theta_b := PI * float(ring_index + 1) / float(PREVIEW_SPHERE_RINGS)
		for side_index in range(PREVIEW_SPHERE_SIDES):
			var next_side_index := (side_index + 1) % PREVIEW_SPHERE_SIDES
			var phi_a := TAU * float(side_index) / float(PREVIEW_SPHERE_SIDES)
			var phi_b := TAU * float(next_side_index) / float(PREVIEW_SPHERE_SIDES)
			var point_aa: Vector3 = center_point + _sphere_offset(theta_a, phi_a, radius_meters)
			var point_ab: Vector3 = center_point + _sphere_offset(theta_a, phi_b, radius_meters)
			var point_ba: Vector3 = center_point + _sphere_offset(theta_b, phi_a, radius_meters)
			var point_bb: Vector3 = center_point + _sphere_offset(theta_b, phi_b, radius_meters)
			added_vertices += _append_triangle(surface_tool, point_aa, point_ba, point_bb, color)
			added_vertices += _append_triangle(surface_tool, point_aa, point_bb, point_ab, color)
	return added_vertices

func _append_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color: Color
) -> int:
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_a)
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_b)
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_c)
	return 3

func _sphere_offset(theta: float, phi: float, radius_meters: float) -> Vector3:
	var sin_theta := sin(theta)
	return Vector3(
		sin_theta * cos(phi),
		cos(theta),
		sin_theta * sin(phi)
	) * radius_meters

func _resolve_perpendicular_normal(tangent: Vector3) -> Vector3:
	var reference := Vector3.UP
	if absf(tangent.dot(reference)) > 0.92:
		reference = Vector3.RIGHT
	var normal: Vector3 = reference.cross(tangent).normalized()
	if normal == Vector3.ZERO:
		return Vector3.FORWARD
	return normal

func _resolve_stroke_color(stroke: Resource) -> Color:
	if stroke.get("operation_mode") == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
		return Color(0.95, 0.22, 0.18, 0.74)
	var material_variant_id: StringName = stroke.get("material_variant_id")
	if material_variant_id == &"mat_iron_gray" or material_variant_id == &"iron_gray":
		return Color(0.62, 0.66, 0.67, 1.0)
	return Color(0.35, 0.78, 0.7, 1.0)

func _resolve_material_color(material_variant_id: StringName) -> Color:
	for entry: Dictionary in ForgeV2MaterialPaletteScript.build_palette_entries():
		if StringName(entry.get("id", StringName())) == material_variant_id:
			return entry.get("albedo_color", Color(0.8, 0.82, 0.84, 1.0)) as Color
	return Color(0.8, 0.82, 0.84, 1.0)

func _build_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.64
	material.metallic = 0.08
	return material

func _build_placement_cursor_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.86, 0.78, 0.46)
	material.emission_enabled = true
	material.emission = Color(0.16, 0.62, 0.58, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_spline_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.12, 0.36, 0.9, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.52
	return material

func _build_csg_body_material(material_variant_id: StringName, is_subtraction: bool) -> StandardMaterial3D:
	var base_color := Color(0.95, 0.22, 0.18, 0.78) if is_subtraction else _resolve_material_color(material_variant_id)
	if not is_subtraction:
		base_color.a = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = base_color.darkened(0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_subtraction else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.54
	material.metallic = 0.12 if not is_subtraction else 0.0
	return material

func _build_spline_csg_material(material_variant_id: StringName) -> StandardMaterial3D:
	var base_color := _resolve_material_color(material_variant_id)
	base_color.a = 0.72
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = base_color.darkened(0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.54
	material.metallic = 0.12
	return material
