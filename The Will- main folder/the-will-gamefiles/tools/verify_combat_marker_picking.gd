extends SceneTree

const Presenter = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const Editor = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")
const Draft = preload("res://core/models/combat_animation_draft.gd")
const Motion = preload("res://core/models/combat_animation_motion_node.gd")

# Only the actor's displayed elbow-control reference is supplied here. Marker
# creation, refresh, deletion, focus filtering and picking use production code.
class GizmoActor extends Node3D:
	func get_authoring_upperarm_roll_control_state(slot: StringName) -> Dictionary:
		return {"axis_global": Vector3.UP,
			"center_global": Vector3(-0.25 if slot == &"hand_right" else 0.25, 0, 0),
			"radial_length_meters": 0.12, "initial_normal_global": Vector3.RIGHT,
			"initial_roll_degrees": 0.0, "reference_global": Vector3.RIGHT}

var checks: Array = []
var presenter = Presenter.new()
var viewport: SubViewport
var camera: Camera3D
var markers: Node3D

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	root.add_child(viewport)
	var preview := Node3D.new()
	preview.name = Presenter.PREVIEW_ROOT_NAME
	viewport.add_child(preview)
	markers = Node3D.new()
	markers.name = Presenter.MARKER_ROOT_NAME
	preview.add_child(markers)
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 0, 5)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.current = true
	await process_frame
	presenter._create_point_marker(markers, Vector3.ZERO, true)
	presenter._create_handle_marker(markers, Vector3(0.10, 0, 0), Color.WHITE, "TipOut")
	var point := markers.get_child(0) as MeshInstance3D
	var cube := markers.get_child(1) as MeshInstance3D
	_check("visible_sphere_center", _pick(point.global_position, &"tip") == &"tip")
	_check("adjacent_cube_center", _pick(cube.global_position, &"tip") == &"tip_curve_out")
	var cube_edge: Vector3 = cube.global_position + Vector3((cube.mesh as BoxMesh).size.x * 0.45, 0, 0)
	_check("cube_visible_edge", _pick(cube_edge, &"tip") == &"tip_curve_out")
	_check("outside_cube_no_34px_halo", _pick(cube.global_position + Vector3(0.06, 0, 0), &"tip") == StringName())
	_check("inactive_curve_not_pickable", _pick(cube.global_position, &"pommel") == StringName())
	cube.visible = false
	_check("hidden_cube_not_pickable", _pick(cube.global_position, &"tip") == StringName())
	cube.visible = true
	cube.position = Vector3(0, 0, 1)
	_check("front_cube_wins_overlap", _pick(Vector3.ZERO, &"tip") == &"tip_curve_out")
	cube.position.z = -1.0
	_check("front_sphere_wins_overlap", _pick(Vector3.ZERO, &"tip") == &"tip")
	cube.queue_free()
	_check("queued_visual_ignored", presenter._authoring_marker_candidates(viewport, &"tip").size() == 1)
	await process_frame
	_clear_markers()
	presenter._update_drag_point_marker(markers, "DragTipMarker", Vector3(-0.3, 0, 0), true)
	presenter._update_drag_point_marker(markers, "DragPommelMarker", Vector3(0.3, 0, 0), false)
	presenter._update_drag_handle_marker(markers, "DragTipInHandle", Vector3(-0.1, 0, 0), Color.WHITE, true)
	_check("lightweight_tip", _pick(Vector3(-0.3, 0, 0), &"tip") == &"tip")
	_check("lightweight_curve", _pick(Vector3(-0.1, 0, 0), &"tip") == &"tip_curve_in")
	_check("inactive_pommel", _pick(Vector3(0.3, 0, 0), &"pommel") == StringName())
	_clear_markers()
	for marker_name: String in ["WeaponFacing", "DragWeaponFacingMarker"]:
		presenter._update_weapon_facing_marker(markers, marker_name, Vector3.ZERO, true)
		_check(marker_name + "_pick", _pick(Vector3.ZERO, &"weapon_facing") == &"weapon_facing")
		_check(marker_name + "_return_position", presenter.get_authoring_marker_screen_position(viewport, camera, &"weapon_facing") is Vector2)
		_clear_markers()
	var configurations := [
		["RightHandProxyTip", &"right_hand_proxy", &"right_hand_proxy_tip"],
		["RightHandProxyPommel", &"right_hand_proxy", &"right_hand_proxy_pommel"],
		["LeftHandProxyTip", &"left_hand_proxy", &"left_hand_proxy_tip"],
		["LeftHandProxyPommel", &"left_hand_proxy", &"left_hand_proxy_pommel"],
		["RightUpperarmRollHandle", &"right_arm_roll", &"right_upperarm_roll"],
		["LeftUpperarmRollHandle", &"left_arm_roll", &"left_upperarm_roll"],
		["WeaponNormal", &"weapon", &"weapon_rotation"],
		["WeaponCenter", &"weapon", &"weapon_rotation"],
	]
	for entry: Array in configurations:
		presenter._create_control_gizmo_marker(markers, Vector3.ZERO, Color.WHITE, 0.02, entry[0])
		_check(String(entry[0]) + "_pick", _pick(Vector3.ZERO, entry[1]) == entry[2])
		_check(String(entry[0]) + "_cursor", presenter.get_authoring_marker_screen_position(viewport, camera, entry[2]) is Vector2)
		_clear_markers()
	presenter._create_control_gizmo_marker(markers, Vector3.ZERO, Color.WHITE, 0.02, "RightUpperarmRollHandle")
	preview.set_meta("upperarm_roll_gizmo_state", {&"hand_right": {"drag_target": &"right_upperarm_roll", "handle_global": Vector3.ZERO}})
	_check("arm_state_precise_pick", not presenter.resolve_upperarm_roll_drag_state(viewport, camera, camera.unproject_position(Vector3.ZERO), &"right_arm_roll").is_empty())
	_check("arm_state_outside_shape", presenter.resolve_upperarm_roll_drag_state(viewport, camera, camera.unproject_position(Vector3(0.15, 0, 0)), &"right_arm_roll").is_empty())
	_clear_markers()
	presenter._create_playback_marker(markers, Vector3.ZERO, Color.WHITE, "PlaybackTip")
	_check("playback_decoration_not_pickable", _pick(Vector3.ZERO, &"tip") == StringName())
	_clear_markers()
	presenter._create_point_marker(markers, Vector3.ZERO, true)
	point = markers.get_child(0) as MeshInstance3D
	markers.rotation = Vector3(0.2, -0.3, 0.1)
	markers.scale = Vector3(1.8, 0.7, 1.1)
	markers.position = Vector3(0.2, 0.1, 0)
	_check("transformed_parent_sphere", _pick(point.global_position, &"tip") == &"tip")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_check("perspective_sphere", _pick(point.global_position, &"tip") == &"tip")
	point.position = markers.to_local(Vector3(0, 0, 7))
	_check("behind_camera_ignored", presenter.pick_authoring_marker(viewport, camera, Vector2(400, 300), &"tip") == StringName())
	await _check_refresh_lifecycle()
	var failed: Array = checks.filter(func(check: Dictionary) -> bool: return not check.passed)
	var result := {"passed": failed.is_empty(), "check_count": checks.size(), "failed": failed, "checks": checks}
	var output := "C:/WORKSPACE/godot_runs/combat_marker_picking_20261105.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit(0 if failed.is_empty() else 1)

func _check_refresh_lifecycle() -> void:
	var refresh_view := SubViewport.new()
	refresh_view.size = Vector2i(800, 600)
	root.add_child(refresh_view)
	var state: Dictionary = presenter._ensure_preview_nodes(null, refresh_view)
	var actor := GizmoActor.new()
	actor.name = Presenter.PREVIEW_ACTOR_NAME
	(state.actor_pivot as Node3D).add_child(actor)
	var model := Node3D.new()
	model.name = "JosieModel"
	actor.add_child(model)
	var rig := Node3D.new()
	rig.name = "Josie"
	model.add_child(rig)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	rig.add_child(skeleton)
	var motion := Motion.new()
	motion.tip_position_local = Vector3(-0.4, 0, 0)
	motion.pommel_position_local = Vector3(0.4, 0, 0)
	motion.left_hand_proxy_authored = true
	motion.left_hand_proxy_tip_position_local = Vector3(0.2, 0.2, 0)
	motion.left_hand_proxy_pommel_position_local = Vector3(0.2, -0.2, 0)
	var draft := Draft.new()
	draft.motion_node_chain.append(motion)
	var refresh_camera := (state.preview_root as Node3D).get_node(Presenter.PREVIEW_CAMERA_NAME) as Camera3D
	refresh_camera.position = Vector3(0, 0, 5)
	refresh_camera.rotation = Vector3.ZERO
	refresh_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	refresh_camera.size = 4.0
	var cases := [
		[&"weapon_facing", &"weapon_facing"],
		[&"weapon", &"weapon_rotation"],
		[&"right_arm_roll", &"right_upperarm_roll"],
		[&"left_hand_proxy", &"left_hand_proxy_pommel"],
	]
	for entry: Array in cases:
		var focus: StringName = entry[0]
		var target: StringName = entry[1]
		# No frame boundary between refreshes: the old queued fixed-name cube
		# used to be reused here and was then deleted at the end of this frame.
		presenter.refresh_focus_visuals(null, refresh_view, draft, 0, focus)
		presenter.refresh_focus_visuals(null, refresh_view, draft, 0, focus)
		_check_refreshed_target(refresh_view, refresh_camera, focus, target, "repeat_focus_now")
		await process_frame
		_check_refreshed_target(refresh_view, refresh_camera, focus, target, "repeat_focus_next_frame")
		presenter.refresh_selection_visuals(null, refresh_view, draft, 0, focus)
		presenter.refresh_selection_visuals(null, refresh_view, draft, 0, focus)
		_check_refreshed_target(refresh_view, refresh_camera, focus, target, "repeat_selection_now")
		await process_frame
		_check_refreshed_target(refresh_view, refresh_camera, focus, target, "repeat_selection_next_frame")
	# Switching a freshly cleared drag root back into lightweight mode must
	# replace, rather than reuse, the previous same-name drag marker as well.
	presenter.refresh_authoring_motion_visuals(null, refresh_view, draft, 0, &"tip", null, motion)
	(state.preview_root as Node3D).set_meta("drag_budgeted_markers_active", false)
	presenter.refresh_authoring_motion_visuals(null, refresh_view, draft, 0, &"tip", null, motion)
	await process_frame
	_check_refreshed_target(refresh_view, refresh_camera, &"tip", &"tip", "replaced_lightweight_next_frame")
	refresh_view.queue_free()

func _check_refreshed_target(refresh_view: SubViewport, refresh_camera: Camera3D,
		focus: StringName, target: StringName, label: String) -> void:
	var screen: Variant = presenter.get_authoring_marker_screen_position(refresh_view, refresh_camera, target)
	_check(String(target) + "_" + label, screen is Vector2 and
		presenter.pick_authoring_marker(refresh_view, refresh_camera, screen, focus) == target)

func _pick(world_position: Vector3, focus: StringName) -> StringName:
	return presenter.pick_authoring_marker(viewport, camera, camera.unproject_position(world_position), focus)

func _check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})

func _clear_markers() -> void:
	for child: Node in markers.get_children():
		markers.remove_child(child)
		child.free()
