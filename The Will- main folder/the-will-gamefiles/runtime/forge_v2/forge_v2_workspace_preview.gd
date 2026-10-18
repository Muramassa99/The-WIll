extends Node3D
class_name ForgeV2WorkspacePreview

signal view_state_changed

const DEFAULT_FORGE_VIEW_TUNING_RESOURCE: ForgeViewTuningDef = preload("res://core/defs/forge/forge_view_tuning_default.tres")
const ForgeV2PlacementTargetResolverScript = preload("res://runtime/forge_v2/forge_v2_placement_target_resolver.gd")
const ForgeV2WorkspaceContractScript = preload("res://runtime/forge_v2/forge_v2_workspace_contract.gd")
const ForgeV2VolumePreviewPresenterScript = preload("res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd")

const REJECT_SURFACE_TARGET_KIND_MISMATCH := &"reject_surface_target_kind_mismatch"
const REJECT_SURFACE_TARGET_ID_MISMATCH := &"reject_surface_target_id_mismatch"
const REJECT_SURFACE_PROJECTION_NO_CAMERA := &"reject_surface_projection_no_camera"
const REJECT_SURFACE_PROJECTION_BEHIND_CAMERA := &"reject_surface_projection_behind_camera"

var forge_view_tuning: ForgeViewTuningDef = DEFAULT_FORGE_VIEW_TUNING_RESOURCE
var placement_target_resolver = ForgeV2PlacementTargetResolverScript.new()
var workspace_contract = ForgeV2WorkspaceContractScript.new()
var active_stage_controller: Node = null
var camera_pivot: Node3D = null
var camera_pitch: Node3D = null
var camera: Camera3D = null
var light: DirectionalLight3D = null
var workspace_plane_instance: MeshInstance3D = null
var workspace_grid_instance: MeshInstance3D = null
var workspace_axes_instance: MeshInstance3D = null
var workspace_bounds_instance: MeshInstance3D = null
var volume_preview_presenter: Node3D = null
var view_initialized := false
var _axis_face: StringName = &""
var _view_tween: Tween
var _spline_work_plane_enabled := false
var _spline_work_plane_origin := Vector3.ZERO

func _ready() -> void:
	_build_scene()
	_apply_view_defaults()

func bind_stage_controller(stage_controller: Node) -> void:
	active_stage_controller = stage_controller
	_sync_workspace_contract_from_controller()
	_build_scene()
	_refresh_workspace_contract_visuals()
	if volume_preview_presenter != null and volume_preview_presenter.has_method("bind_stage_controller"):
		volume_preview_presenter.call("bind_stage_controller", active_stage_controller)

func clear_stage_controller() -> bool:
	if volume_preview_presenter != null and volume_preview_presenter.has_method("clear_stage_controller"):
		if not bool(volume_preview_presenter.call("clear_stage_controller")):
			return false
	active_stage_controller = null
	return true

func orbit_by(delta: Vector2) -> void:
	if camera_pivot == null or camera_pitch == null:
		return
	if delta.is_zero_approx():
		return
	_cancel_view_transition()
	_axis_face = &""
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var orientation := camera_pivot.basis * camera_pitch.basis
	orientation = Basis(Vector3.UP, -delta.x * tuning.workspace_orbit_sensitivity) * orientation
	var pitch := asin(clampf(-orientation.z.y, -1.0, 1.0))
	# Starting from a pole view must not jump to the old +/-80-degree orbit bound.
	var next_pitch := clampf(pitch - delta.y * tuning.workspace_orbit_sensitivity,
		minf(pitch, deg_to_rad(tuning.workspace_pitch_min_degrees)),
		maxf(pitch, deg_to_rad(tuning.workspace_pitch_max_degrees)))
	camera_pivot.basis = (orientation * Basis(Vector3.RIGHT, next_pitch - pitch)).orthonormalized()
	camera_pitch.basis = Basis.IDENTITY
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_sync_light_anchor()
	_refresh_spline_work_plane_visuals()
	view_state_changed.emit()
	view_initialized = true

func pan_by(delta: Vector2) -> void:
	if camera_pivot == null or camera == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var camera_basis: Basis = camera.global_transform.basis
	var reference_distance: float = maxf(absf(camera.position.z), tuning.workspace_pan_min_distance)
	var pan_offset: Vector3 = (
		-camera_basis.x.normalized() * delta.x
		+ camera_basis.y.normalized() * delta.y
	) * reference_distance * tuning.workspace_pan_sensitivity
	camera_pivot.global_position += pan_offset
	view_initialized = true

func zoom_by(amount: float) -> void:
	if camera == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	camera.position.z = clampf(
		camera.position.z + amount,
		tuning.workspace_zoom_min_distance,
		tuning.workspace_zoom_max_distance
	)
	_sync_orthographic_size()
	view_initialized = true

func fit_view() -> void:
	if camera == null or camera_pivot == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var contract = _get_workspace_contract()
	camera_pivot.position = Vector3.ZERO
	camera.position = Vector3(
		0.0,
		0.0,
		clampf(
			contract.fit_size_meters * tuning.workspace_fit_distance_multiplier,
			tuning.workspace_fit_min_distance,
			tuning.workspace_fit_max_distance
		)
	)
	_sync_orthographic_size()
	view_initialized = true

func reset_view() -> void:
	_apply_view_defaults()
	view_initialized = true

func set_axis_view(face: StringName) -> void:
	var orientation: Basis
	match face:
		&"front": orientation = Basis.IDENTITY
		&"back": orientation = Basis(Vector3.UP, PI)
		&"right": orientation = Basis(Vector3.UP, PI * 0.5)
		&"left": orientation = Basis(Vector3.UP, -PI * 0.5)
		&"top": orientation = Basis(Vector3.RIGHT, -PI * 0.5)
		&"bottom": orientation = Basis(Vector3.RIGHT, PI * 0.5)
		_: return
	if camera == null:
		return
	_cancel_view_transition()
	var start := (camera_pivot.basis * camera_pitch.basis).get_rotation_quaternion().normalized()
	var target := orientation.get_rotation_quaternion().normalized()
	camera_pivot.quaternion = start
	camera_pitch.basis = Basis.IDENTITY
	_axis_face = face
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_sync_orthographic_size()
	var angle := start.angle_to(target)
	if angle < 0.00001:
		_finish_axis_view(target)
		return
	var duration := angle / deg_to_rad(maxf(_get_view_tuning().workspace_axis_view_speed_degrees, 1.0))
	_view_tween = create_tween()
	_view_tween.set_trans(Tween.TRANS_LINEAR)
	_view_tween.tween_method(_interpolate_axis_view.bind(start, target), 0.0, 1.0, duration)
	_view_tween.tween_callback(_finish_axis_view.bind(target))
	view_state_changed.emit()

func align_to_nearest_axis() -> void:
	if camera == null:
		return
	var direction := (global_basis.inverse() * camera.global_basis.z).normalized()
	var axis := direction.abs().max_axis_index()
	var faces := [[&"left", &"right"], [&"bottom", &"top"], [&"back", &"front"]]
	set_axis_view(faces[axis][1 if direction[axis] >= 0.0 else 0])

func is_view_transitioning() -> bool:
	return _view_tween != null and _view_tween.is_running()

func get_view_state() -> Dictionary:
	var plane_name := "Free plane"
	match _axis_face:
		&"front", &"back": plane_name = "XY"
		&"right", &"left": plane_name = "YZ"
		&"top", &"bottom": plane_name = "XZ"
	var orthographic := camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var label := "%s | %s | %s" % [String(_axis_face).capitalize() if _axis_face != &"" else "Free view",
		"Orthographic" if orthographic else "Perspective", plane_name]
	if is_view_transitioning():
		label += " | Moving..."
	return {"face_id": _axis_face, "orthographic": orthographic,
		"transitioning": is_view_transitioning(), "status_label": label}

func _interpolate_axis_view(weight: float, start: Quaternion, target: Quaternion) -> void:
	camera_pivot.quaternion = start.slerp(target, weight)
	_refresh_spline_work_plane_visuals()

func _finish_axis_view(target: Quaternion) -> void:
	camera_pivot.quaternion = target
	_view_tween = null
	_sync_light_anchor()
	_refresh_spline_work_plane_visuals()
	view_initialized = true
	view_state_changed.emit()

func _cancel_view_transition() -> void:
	if _view_tween != null:
		_view_tween.kill()
		_view_tween = null

func _sync_orthographic_size() -> void:
	if camera != null:
		camera.size = maxf(0.001, 2.0 * camera.position.z * tan(deg_to_rad(camera.fov) * 0.5))

func build_spline_point_drag_plane(local_origin: Vector3) -> Dictionary:
	if is_view_transitioning():
		return {"valid": false}
	return build_camera_facing_drag_plane(local_origin)

func resolve_spline_placement_target(screen_position: Vector2, points: PackedVector3Array) -> Dictionary:
	if is_view_transitioning():
		return {"valid": false, "reject_reason": &"view_transition"}
	if points.is_empty() and _axis_face == &"":
		return resolve_placement_target(screen_position)
	var origin: Vector3 = points[points.size() - 1] if not points.is_empty() else _get_workspace_contract().get_placement_plane_origin_local()
	var plane := build_spline_point_drag_plane(origin)
	if not bool(plane.get("valid", false)):
		return plane
	return screen_to_workspace_local_on_spline_plane(screen_position, origin, plane["normal_local"])

func screen_to_workspace_local_on_spline_plane(screen_position: Vector2, origin: Vector3, normal: Vector3) -> Dictionary:
	if is_view_transitioning():
		return {"valid": false, "reject_reason": &"view_transition"}
	var result := screen_to_workspace_local_on_drag_plane(screen_position, origin, normal)
	if bool(result.get("valid", false)):
		# Independent XYZ clamping would move an oblique hit off its guide plane.
		if not _get_workspace_contract().contains_local_position(result["raw_local_position"]):
			result["valid"] = false
			result["reject_reason"] = &"outside_build_area"
		else:
			result["local_position"] = result["raw_local_position"]
			result["local_normal"] = normal.normalized()
			result["target_kind"] = &"spline_guide_plane"
	return result

func set_spline_work_plane_context(enabled: bool, origin: Vector3) -> void:
	if _spline_work_plane_enabled == enabled and _spline_work_plane_origin.is_equal_approx(origin):
		return
	_spline_work_plane_enabled = enabled
	_spline_work_plane_origin = origin
	if enabled:
		_refresh_spline_work_plane_visuals()
	else:
		_refresh_workspace_contract_visuals()

func resolve_placement_target(screen_position: Vector2) -> Dictionary:
	return _get_placement_target_resolver().resolve_from_camera(
		camera,
		screen_position,
		self,
		_get_workspace_contract(),
		_get_view_tuning().workspace_ray_plane_epsilon
	)

func resolve_material_surface_target(screen_position: Vector2) -> Dictionary:
	return _get_placement_target_resolver().resolve_material_surface_from_camera(
		camera,
		screen_position,
		self,
		_get_workspace_contract()
	)

func set_retained_edit_selection_enabled(enabled: bool) -> void:
	if is_instance_valid(volume_preview_presenter):
		volume_preview_presenter.call("set_retained_edit_selection_enabled", enabled)

func set_retained_edit_cursor_suppressed(suppressed: bool) -> void:
	if is_instance_valid(volume_preview_presenter):
		volume_preview_presenter.call("set_retained_edit_cursor_suppressed", suppressed)

func set_retained_edit_hover(body_id: StringName) -> void:
	if is_instance_valid(volume_preview_presenter):
		volume_preview_presenter.call("set_retained_edit_hover", body_id)

func resolve_retained_edit_selection(screen_position: Vector2) -> Dictionary:
	if camera == null or not is_instance_valid(volume_preview_presenter) or is_view_transitioning():
		return {"valid": false}
	# The provenance owner operates in its own mesh space, in either camera mode.
	var origin := volume_preview_presenter.to_local(camera.project_ray_origin(screen_position))
	var direction := (volume_preview_presenter.global_basis.inverse() * camera.project_ray_normal(screen_position)).normalized()
	return volume_preview_presenter.call("resolve_retained_edit_selection", origin, direction) as Dictionary

func resolve_placement_plane_target(screen_position: Vector2) -> Dictionary:
	return _get_placement_target_resolver().resolve_placement_plane_from_camera(
		camera,
		screen_position,
		self,
		_get_workspace_contract(),
		_get_view_tuning().workspace_ray_plane_epsilon
	)

func resolve_strict_surface_target(
	screen_position: Vector2,
	required_target_kind: StringName = StringName(),
	required_surface_target_id: StringName = StringName()
) -> Dictionary:
	var result: Dictionary
	match required_target_kind:
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE:
			result = resolve_material_surface_target(screen_position)
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_PLACEMENT_PLANE:
			result = resolve_placement_plane_target(screen_position)
		_:
			result = resolve_placement_target(screen_position)
	if not bool(result.get("valid", false)):
		return result
	var actual_target_kind := StringName(result.get(
		"target_kind",
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_NONE
	))
	var actual_surface_target_id := StringName(result.get(
		"surface_target_id",
		StringName()
	))
	if (
		required_target_kind != StringName()
		and actual_target_kind != required_target_kind
	):
		return _build_strict_surface_rejection(
			result,
			REJECT_SURFACE_TARGET_KIND_MISMATCH,
			required_target_kind,
			required_surface_target_id
		)
	if (
		required_surface_target_id != StringName()
		and actual_surface_target_id != required_surface_target_id
	):
		return _build_strict_surface_rejection(
			result,
			REJECT_SURFACE_TARGET_ID_MISMATCH,
			required_target_kind,
			required_surface_target_id
		)
	return result

func project_workspace_local_to_screen(local_position: Vector3) -> Dictionary:
	if camera == null:
		return {
			"valid": false,
			"reject_reason": REJECT_SURFACE_PROJECTION_NO_CAMERA,
			"local_position": local_position,
		}
	var world_position: Vector3 = to_global(local_position)
	if camera.is_position_behind(world_position):
		return {
			"valid": false,
			"reject_reason": REJECT_SURFACE_PROJECTION_BEHIND_CAMERA,
			"local_position": local_position,
			"world_position": world_position,
		}
	return {
		"valid": true,
		"local_position": local_position,
		"world_position": world_position,
		"screen_position": camera.unproject_position(world_position),
	}

func screen_to_workspace_local(screen_position: Vector2) -> Dictionary:
	return resolve_placement_target(screen_position)

func set_spline_roll_gizmo_active(active: bool) -> void:
	if volume_preview_presenter != null:
		volume_preview_presenter.call("set_spline_roll_gizmo_active", active)

func get_spline_roll_gizmo() -> Dictionary:
	if (
		volume_preview_presenter == null
		or not volume_preview_presenter.has_method("get_spline_roll_gizmo")
	):
		return {}
	return volume_preview_presenter.call("get_spline_roll_gizmo") as Dictionary

func _build_strict_surface_rejection(
	resolved_result: Dictionary,
	reject_reason: StringName,
	required_target_kind: StringName,
	required_surface_target_id: StringName
) -> Dictionary:
	var rejected_result := resolved_result.duplicate(true)
	rejected_result["valid"] = false
	rejected_result["reject_reason"] = reject_reason
	rejected_result["required_target_kind"] = required_target_kind
	rejected_result["required_surface_target_id"] = required_surface_target_id
	return rejected_result

func build_camera_facing_drag_plane(local_origin: Vector3) -> Dictionary:
	if camera == null:
		return {"valid": false}
	var world_normal: Vector3 = camera.global_transform.basis.z.normalized()
	if world_normal.length_squared() <= 0.000001:
		return {"valid": false}
	return {
		"valid": true,
		"origin_local": local_origin,
		"normal_local": (global_transform.basis.inverse() * world_normal).normalized(),
	}

func screen_to_workspace_local_on_drag_plane(
	screen_position: Vector2,
	plane_origin_local: Vector3,
	plane_normal_local: Vector3
) -> Dictionary:
	if camera == null or plane_normal_local.length_squared() <= 0.000001:
		return {"valid": false}
	var world_normal: Vector3 = (global_transform.basis * plane_normal_local).normalized()
	var world_origin: Vector3 = global_transform * plane_origin_local
	var hit_plane := Plane(world_normal, world_origin)
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var intersection: Variant = hit_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return {"valid": false}
	var raw_local_position: Vector3 = global_transform.affine_inverse() * (intersection as Vector3)
	var local_position: Vector3 = _get_workspace_contract().clamp_local_position(raw_local_position)
	return {
		"valid": true,
		"local_position": local_position,
		"raw_local_position": raw_local_position,
		"target_kind": &"camera_facing_drag_plane",
	}

func find_nearest_local_point_by_screen(
	local_points: PackedVector3Array,
	screen_position: Vector2,
	max_distance_pixels: float
) -> int:
	if camera == null or local_points.is_empty() or max_distance_pixels <= 0.0:
		return -1
	var nearest_index := -1
	var nearest_distance := max_distance_pixels
	for point_index in range(local_points.size()):
		var world_position: Vector3 = global_transform * local_points[point_index]
		var projected_position: Vector2 = camera.unproject_position(world_position)
		var distance := projected_position.distance_to(screen_position)
		if distance > nearest_distance:
			continue
		nearest_distance = distance
		nearest_index = point_index
	return nearest_index

func _build_scene() -> void:
	if camera_pivot != null:
		return
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	add_child(camera_pivot)

	camera_pitch = Node3D.new()
	camera_pitch.name = "CameraPitch"
	camera_pivot.add_child(camera_pitch)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera_pitch.add_child(camera)

	light = DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	camera.add_child(light)

	workspace_plane_instance = MeshInstance3D.new()
	workspace_plane_instance.name = "AuthoringPlane"
	workspace_plane_instance.mesh = _build_workspace_plane_mesh()
	workspace_plane_instance.material_override = _build_workspace_plane_material()
	workspace_plane_instance.position.z = _get_workspace_contract().plane_visual_z_offset
	add_child(workspace_plane_instance)

	workspace_grid_instance = MeshInstance3D.new()
	workspace_grid_instance.name = "AuthoringGrid"
	workspace_grid_instance.mesh = _build_workspace_grid_mesh()
	workspace_grid_instance.material_override = _build_line_material(Color(0.42, 0.58, 0.62, 0.32))
	workspace_grid_instance.position.z = _get_workspace_contract().grid_visual_z_offset
	add_child(workspace_grid_instance)

	workspace_axes_instance = MeshInstance3D.new()
	workspace_axes_instance.name = "AuthoringAxes"
	workspace_axes_instance.mesh = _build_workspace_axes_mesh()
	workspace_axes_instance.material_override = _build_line_material(Color.WHITE)
	workspace_axes_instance.position.z = _get_workspace_contract().axes_visual_z_offset
	add_child(workspace_axes_instance)

	workspace_bounds_instance = MeshInstance3D.new()
	workspace_bounds_instance.name = "AuthoringBounds"
	workspace_bounds_instance.mesh = _build_workspace_bounds_mesh()
	workspace_bounds_instance.material_override = _build_line_material(Color(0.35, 0.86, 0.78, 0.56))
	workspace_bounds_instance.visible = _get_workspace_contract().show_bounds_box
	add_child(workspace_bounds_instance)

	volume_preview_presenter = ForgeV2VolumePreviewPresenterScript.new()
	volume_preview_presenter.name = "VolumePreviewPresenter"
	add_child(volume_preview_presenter)
	if active_stage_controller != null and volume_preview_presenter.has_method("bind_stage_controller"):
		volume_preview_presenter.call("bind_stage_controller", active_stage_controller)

	_apply_view_tuning()

func _apply_view_defaults() -> void:
	if camera_pivot == null or camera_pitch == null:
		return
	_cancel_view_transition()
	_axis_face = &""
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera_pivot.basis = Basis.IDENTITY
	camera_pitch.basis = Basis.IDENTITY
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	camera_pivot.position = Vector3.ZERO
	camera_pivot.rotation_degrees.y = tuning.workspace_default_yaw_degrees
	camera_pitch.rotation_degrees.x = tuning.workspace_default_pitch_degrees
	_sync_light_anchor()
	fit_view()
	_refresh_spline_work_plane_visuals()
	view_state_changed.emit()

func _apply_view_tuning() -> void:
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	if camera != null:
		camera.fov = tuning.workspace_camera_fov_degrees
		camera.near = tuning.workspace_camera_near
		camera.far = tuning.workspace_camera_far
	if light != null:
		light.light_energy = tuning.workspace_light_energy
		_sync_light_anchor()

func _sync_light_anchor() -> void:
	if light == null or camera == null:
		return
	var tuning: ForgeViewTuningDef = _get_view_tuning()
	var target_parent: Node = camera if tuning.workspace_light_follows_camera else self
	if light.get_parent() != target_parent:
		light.reparent(target_parent)
	light.position = Vector3.ZERO
	light.rotation_degrees = (
		tuning.workspace_light_follow_offset_degrees
		if tuning.workspace_light_follows_camera
		else tuning.workspace_light_rotation_degrees
	)

func _get_view_tuning() -> ForgeViewTuningDef:
	return forge_view_tuning if forge_view_tuning != null else DEFAULT_FORGE_VIEW_TUNING_RESOURCE

func _get_workspace_contract():
	if workspace_contract == null:
		workspace_contract = ForgeV2WorkspaceContractScript.new()
	workspace_contract.normalize()
	return workspace_contract

func _get_placement_target_resolver():
	if placement_target_resolver == null:
		placement_target_resolver = ForgeV2PlacementTargetResolverScript.new()
	return placement_target_resolver

func _sync_workspace_contract_from_controller() -> void:
	if active_stage_controller == null or not active_stage_controller.has_method("get_workspace_contract"):
		return
	var next_contract = active_stage_controller.call("get_workspace_contract")
	if next_contract == null:
		return
	workspace_contract = next_contract
	workspace_contract.normalize()

func _refresh_workspace_contract_visuals() -> void:
	var contract = _get_workspace_contract()
	if workspace_plane_instance != null:
		workspace_plane_instance.visible = true
		workspace_plane_instance.mesh = _build_workspace_plane_mesh()
		workspace_plane_instance.position.z = contract.plane_visual_z_offset
	if workspace_grid_instance != null:
		workspace_grid_instance.mesh = _build_workspace_grid_mesh()
		workspace_grid_instance.position.z = contract.grid_visual_z_offset
	if workspace_axes_instance != null:
		workspace_axes_instance.mesh = _build_workspace_axes_mesh()
		workspace_axes_instance.position.z = contract.axes_visual_z_offset
	if workspace_bounds_instance != null:
		workspace_bounds_instance.mesh = _build_workspace_bounds_mesh()
		workspace_bounds_instance.visible = contract.show_bounds_box
	_refresh_spline_work_plane_visuals()

func _refresh_spline_work_plane_visuals() -> void:
	if not _spline_work_plane_enabled or camera == null or workspace_grid_instance == null:
		return
	# The guide is clipped to the real box, including oblique free placement planes.
	# Keep the world axes fixed; only the work grid follows the point reference.
	workspace_plane_instance.visible = false
	workspace_grid_instance.position = Vector3.ZERO
	var contract = _get_workspace_contract()
	var orientation := (global_basis.inverse() * camera.global_basis).orthonormalized()
	var origin := _spline_work_plane_origin
	var extent: float = contract.get_local_size().length()
	var spacing: float = contract.grid_step_meters
	var mesh := ImmediateMesh.new()
	var segments: Array[PackedVector3Array] = []
	for step in range(-int(ceil(extent / spacing)), int(ceil(extent / spacing)) + 1):
		for direction_index in range(2):
			var along: Vector3 = orientation.x if direction_index == 0 else orientation.y
			var across: Vector3 = orientation.y if direction_index == 0 else orientation.x
			var start := origin + across * float(step) * spacing - along * extent
			var segment := _clip_grid_segment(start, along * extent * 2.0, contract)
			if not segment.is_empty():
				segments.append(segment)
	if not segments.is_empty():
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for segment: PackedVector3Array in segments:
			_add_line(mesh, segment[0], segment[1], Color(0.42, 0.58, 0.62, 0.32))
		mesh.surface_end()
	workspace_grid_instance.mesh = mesh

func _clip_grid_segment(start: Vector3, delta: Vector3, contract: Resource) -> PackedVector3Array:
	var enter := 0.0
	var leave := 1.0
	for axis in range(3):
		if absf(delta[axis]) < 0.000001:
			if start[axis] < contract.local_min[axis] or start[axis] > contract.local_max[axis]:
				return PackedVector3Array()
			continue
		var first: float = (contract.local_min[axis] - start[axis]) / delta[axis]
		var last: float = (contract.local_max[axis] - start[axis]) / delta[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if leave <= enter:
			return PackedVector3Array()
	return PackedVector3Array([start + delta * enter, start + delta * leave])

func _build_workspace_plane_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = _get_workspace_contract().get_plane_size()
	return mesh

func _build_workspace_plane_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.10, 0.13, 0.15, 0.78)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_workspace_grid_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var contract = _get_workspace_contract()
	var plane_size: Vector2 = contract.get_plane_size()
	var grid_step: float = contract.grid_step_meters
	var half_width := plane_size.x * 0.5
	var half_height := plane_size.y * 0.5
	var x := -half_width
	while x <= half_width + 0.0001:
		mesh.surface_set_color(Color(0.42, 0.58, 0.62, 0.32))
		mesh.surface_add_vertex(Vector3(x, -half_height, 0.0))
		mesh.surface_set_color(Color(0.42, 0.58, 0.62, 0.32))
		mesh.surface_add_vertex(Vector3(x, half_height, 0.0))
		x += grid_step
	var y := -half_height
	while y <= half_height + 0.0001:
		mesh.surface_set_color(Color(0.42, 0.58, 0.62, 0.32))
		mesh.surface_add_vertex(Vector3(-half_width, y, 0.0))
		mesh.surface_set_color(Color(0.42, 0.58, 0.62, 0.32))
		mesh.surface_add_vertex(Vector3(half_width, y, 0.0))
		y += grid_step
	mesh.surface_end()
	return mesh

func _build_workspace_axes_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var contract = _get_workspace_contract()
	_add_line(mesh, Vector3(contract.local_min.x, 0.0, 0.0), Vector3(contract.local_max.x, 0.0, 0.0), Color(0.92, 0.24, 0.2, 0.95))
	_add_line(mesh, Vector3(0.0, contract.local_min.y, 0.0), Vector3(0.0, contract.local_max.y, 0.0), Color(0.34, 0.86, 0.42, 0.95))
	_add_line(mesh, Vector3(0.0, 0.0, contract.local_min.z), Vector3(0.0, 0.0, contract.local_max.z), Color(0.28, 0.48, 0.96, 0.95))
	mesh.surface_end()
	return mesh

func _build_workspace_bounds_mesh() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var contract = _get_workspace_contract()
	var min_point: Vector3 = contract.local_min
	var max_point: Vector3 = contract.local_max
	var color := Color(0.35, 0.86, 0.78, 0.56)
	var corners := [
		Vector3(min_point.x, min_point.y, min_point.z),
		Vector3(max_point.x, min_point.y, min_point.z),
		Vector3(max_point.x, max_point.y, min_point.z),
		Vector3(min_point.x, max_point.y, min_point.z),
		Vector3(min_point.x, min_point.y, max_point.z),
		Vector3(max_point.x, min_point.y, max_point.z),
		Vector3(max_point.x, max_point.y, max_point.z),
		Vector3(min_point.x, max_point.y, max_point.z),
	]
	_add_line(mesh, corners[0], corners[1], color)
	_add_line(mesh, corners[1], corners[2], color)
	_add_line(mesh, corners[2], corners[3], color)
	_add_line(mesh, corners[3], corners[0], color)
	_add_line(mesh, corners[4], corners[5], color)
	_add_line(mesh, corners[5], corners[6], color)
	_add_line(mesh, corners[6], corners[7], color)
	_add_line(mesh, corners[7], corners[4], color)
	_add_line(mesh, corners[0], corners[4], color)
	_add_line(mesh, corners[1], corners[5], color)
	_add_line(mesh, corners[2], corners[6], color)
	_add_line(mesh, corners[3], corners[7], color)
	mesh.surface_end()
	return mesh

func _add_line(mesh: ImmediateMesh, from_point: Vector3, to_point: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(from_point)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(to_point)

func _build_line_material(default_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = default_color
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
