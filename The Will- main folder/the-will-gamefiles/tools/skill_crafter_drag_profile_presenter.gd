extends "res://runtime/combat/combat_animation_station_preview_presenter.gd"

# Diagnostic-only wrapper: timings include nested calls. Production code is unchanged.
var samples: Dictionary = {}

func reset_samples() -> void:
	samples.clear()

func _record(label: String, start: int) -> void:
	var row: Dictionary = samples.get(label, {"calls": 0, "ms": 0.0})
	row["calls"] += 1
	row["ms"] += float(Time.get_ticks_usec() - start) / 1000.0
	samples[label] = row

func _refresh_actor_and_weapon(
	state: Dictionary,
	active_wip: CraftedItemWIP,
	selected_motion_node: CombatAnimationMotionNode,
	active_draft: Resource = null
) -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_actor_and_weapon(state, active_wip, selected_motion_node, active_draft)
	_record("_refresh_actor_and_weapon", started)

func _apply_authored_weapon_pose(
	state: Dictionary,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	update_camera: bool = true,
	dominant_seat_lock_strength: float = 1.0,
	preserve_authoring_endpoints: bool = true,
	active_draft: Resource = null,
	stow_endpoints_already_display_local: bool = false,
	allow_exact_surface_solve: bool = true
) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._apply_authored_weapon_pose(state, selected_motion_node, playback_state, update_camera, dominant_seat_lock_strength, preserve_authoring_endpoints, active_draft, stow_endpoints_already_display_local, allow_exact_surface_solve)
	_record("_apply_authored_weapon_pose", started)
	return result

func _apply_preview_open_mount_pose(
	state: Dictionary,
	selected_motion_node: CombatAnimationMotionNode,
	playback_state: Dictionary,
	update_camera: bool = true
) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._apply_preview_open_mount_pose(state, selected_motion_node, playback_state, update_camera)
	_record("_apply_preview_open_mount_pose", started)
	return result

func _refresh_drag_budgeted_visuals(
	state: Dictionary,
	motion_node_chain: Array,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	active_draft: Resource = null
) -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_drag_budgeted_visuals(state, motion_node_chain, selected_node_index, active_focus, active_draft)
	_record("_refresh_drag_budgeted_visuals", started)

func _refresh_trajectory_visuals(
	state: Dictionary,
	motion_node_chain: Array,
	selected_node_index: int,
	active_focus: StringName = &"tip",
	playback_state: Dictionary = {},
	speed_state_config: Dictionary = {},
	active_draft: Resource = null
) -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_trajectory_visuals(state, motion_node_chain, selected_node_index, active_focus, playback_state, speed_state_config, active_draft)
	_record("_refresh_trajectory_visuals", started)

func _refresh_weapon_and_sphere_visuals(state: Dictionary, motion_node_chain: Array, selected_node_index: int, active_focus: StringName, baked_profile: BakedProfile) -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_weapon_and_sphere_visuals(state, motion_node_chain, selected_node_index, active_focus, baked_profile)
	_record("_refresh_weapon_and_sphere_visuals", started)

func _refresh_collision_debug_visuals(state: Dictionary) -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_collision_debug_visuals(state)
	_record("_refresh_collision_debug_visuals", started)

func _evaluate_preview_collision_pose(
	actor: Node3D,
	held_item: Node3D,
	solved_transform: Transform3D
) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._evaluate_preview_collision_pose(actor, held_item, solved_transform)
	_record("_evaluate_preview_collision_pose", started)
	return result

func _apply_preview_actor_upper_body_pose_now(
	actor: Node3D,
	use_drag_frame: bool = false,
	allow_exact_surface_solve: bool = false
) -> void:
	var started: int = Time.get_ticks_usec()
	super._apply_preview_actor_upper_body_pose_now(actor, use_drag_frame, allow_exact_surface_solve)
	_record("_apply_preview_actor_upper_body_pose_now", started)

func _apply_preview_weapon_surface_seat(
	actor: Node3D,
	held_item: Node3D,
	allow_surface_solve: bool
) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._apply_preview_weapon_surface_seat(actor, held_item, allow_surface_solve)
	_record("_apply_preview_weapon_surface_seat", started)
	samples["seat_result"] = {"valid": result.get("valid", false), "status": result.get("status", ""), "solve_count": result.get("solve_count", 0), "geometry_load_count": result.get("surface_geometry_load_count", 0), "solver_ms": (result.get("diagnostics", {}) as Dictionary).get("solve_time_msec", 0.0)}
	return result

func _settle_preview_digits_on_resolved_weapon(
	actor: Node3D,
	held_item: Node3D,
	allow_exact_surface_solve: bool
) -> void:
	var started: int = Time.get_ticks_usec()
	super._settle_preview_digits_on_resolved_weapon(actor, held_item, allow_exact_surface_solve)
	_record("_settle_preview_digits_on_resolved_weapon", started)
