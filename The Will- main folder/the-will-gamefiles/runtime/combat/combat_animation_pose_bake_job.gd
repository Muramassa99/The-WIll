extends RefCounted

const Checkpoint = preload("res://runtime/combat/combat_animation_render_checkpoint.gd")
const Incremental = preload("res://core/resolvers/combat_runtime_clip_incremental_resolver.gd")
const CombatRuntimeClipScript = preload("res://core/models/combat_runtime_clip.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const PreviewGripAcquisition = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const GripChronology = preload("res://runtime/player/grip/grip_chronology.gd")

var p
var preview_container: SubViewportContainer
var preview_subviewport: SubViewport
var active_wip: CraftedItemWIP
var active_draft: Resource
var runtime_clip: Resource
var selected_node_index: int
var context_key: String
var done := false
var frame_index := 0
var reused_frames := 0
var checkpoints: Dictionary = {}
var seed: Dictionary = {}
var working: Dictionary = {}
var initial_editor: Dictionary = {}
var initial_camera: Dictionary = {}
var cached: Dictionary = {}
var checkpoint_interval := 30
var max_slice_usec := 0
var trace_enabled: bool
var profile: Dictionary
var result: Dictionary
var frame_count: int
var clip_motion_node_chain: Array
var state: Dictionary
var base_node_index: int
var base_motion_node: CombatAnimationMotionNode
var initial_frame: CombatAnimationMotionNode
var preview_root: Node3D
var actor_pivot: Node3D
var actor: Node3D
var held_item: Node3D
var requested_bone_names: Array
var resolved_bone_names: Array[StringName]
var captured_position_frames: Array
var captured_rotation_frames: Array
var captured_scale_frames: Array
var solved_weapon_positions: PackedVector3Array
var solved_weapon_rotations: PackedVector4Array
var solved_weapon_scales: PackedVector3Array
var solved_anchor_paths: Array[StringName]
var solved_anchor_position_frames: Array
var solved_anchor_rotation_frames: Array
var solved_anchor_scale_frames: Array
var solved_frame_available: Array
var primary_anchor_to_anatomical_grip_max: float
var primary_anchor_to_anatomical_grip_sum: float
var primary_anchor_to_anatomical_grip_count: int
var primary_anchor_to_anatomical_grip_max_frame: int

func begin(presenter, container: SubViewportContainer, viewport: SubViewport,
        wip: CraftedItemWIP, draft: Resource, clip: Resource, selection: int,
        key: String, previous: Dictionary = {}) -> void:
	p = presenter
	preview_container = container
	preview_subviewport = viewport
	active_wip = wip
	active_draft = draft
	runtime_clip = clip
	selected_node_index = selection
	context_key = key
	cached = previous
	if p == null or container == null or viewport == null:
		result = {"baked": false, "reason": "missing_preview"}
		done = true
		return
	if wip == null or draft == null or clip == null:
		result = {"baked": false, "reason": "missing_source"}
		done = true
		return
	initial_camera = p.capture_camera_state(viewport)
	var before_state: Dictionary = p._ensure_preview_nodes(container, viewport)
	initial_editor = Checkpoint.capture(p, before_state)
	if initial_editor.is_empty():
		result = {"baked": false, "reason": "editor_checkpoint_unavailable"}
		done = true
		p.restore_camera_state(preview_subviewport, initial_camera)
		return
	_initialize()
	if done:
		if not initial_editor.is_empty():
			_restore_initial_editor()
		return
	seed = Checkpoint.capture(p, state)
	working = seed
	if seed.is_empty():
		result["reason"] = "render_checkpoint_unavailable"
		done = true
		_restore_initial_editor()
		return
	_try_resume()
	if not _restore_initial_editor():
		result["reason"] = "render_initial_editor_restore_failed"
		done = true

func _restore_initial_editor() -> bool:
	var restored := Checkpoint.restore(p, initial_editor)
	p.restore_camera_state(preview_subviewport, initial_camera)
	return restored

func _initialize() -> void:
	trace_enabled = bool(p.get_meta("trace_save_latency", false))
	profile = {
		"apply_pose_ms": 0.0, "grip_ms": 0.0, "capture_ms": 0.0,
		"max_frame_ms": 0.0, "solved_relationships": 0, "reused_relationships": 0,
		"processed_frames": 0,
		"pose_components_ms": {}, "pose_component_calls": {},
	}
	result = {
		"baked": false,
		"reason": "",
		"frame_count": 0,
		"bone_count": 0,
		"anchor_count": 0,
		"solved_replay_track": false,
		"primary_anchor_to_anatomical_grip_max_meters": -1.0,
		"primary_anchor_to_anatomical_grip_avg_meters": -1.0,
		"primary_anchor_to_anatomical_grip_max_frame": -1,
	}
	if trace_enabled:
		result["profile"] = profile
	if preview_container == null or preview_subviewport == null:
		result["reason"] = "missing_preview"
		done = true
		return
	if active_wip == null or active_draft == null or runtime_clip == null:
		result["reason"] = "missing_source"
		done = true
		return
	if p._is_noncombat_idle_draft(active_draft):
		result["reason"] = "noncombat_stow_does_not_use_hand_pose"
		done = true
		return
	for grip_state: Dictionary in p.get_grip_acquisition_status(preview_subviewport).values():
		if grip_state.get("status", "") == "solving":
			result["reason"] = "grip_acquisition_pending"
			done = true
			return
	if not runtime_clip.has_method("get_frame_count"):
		result["reason"] = "runtime_clip_has_no_frames"
		done = true
		return
	frame_count = int(runtime_clip.call("get_frame_count"))
	result["frame_count"] = frame_count
	if frame_count <= 0:
		result["reason"] = "runtime_clip_empty"
		done = true
		return
	clip_motion_node_chain = runtime_clip.get("motion_node_chain") as Array
	if clip_motion_node_chain.is_empty():
		result["reason"] = "runtime_clip_has_no_motion_nodes"
		done = true
		return
	state = p._ensure_preview_nodes(preview_container, preview_subviewport)
	p._sync_preview_size(preview_container, preview_subviewport)
	base_node_index = clampi(selected_node_index, 0, clip_motion_node_chain.size() - 1)
	base_motion_node = clip_motion_node_chain[base_node_index] as CombatAnimationMotionNode
	if base_motion_node == null:
		base_motion_node = clip_motion_node_chain[0] as CombatAnimationMotionNode
	if base_motion_node == null:
		result["reason"] = "runtime_clip_has_invalid_motion_node"
		done = true
		return
	initial_frame = p._build_runtime_clip_frame_motion_node(runtime_clip, 0, base_motion_node)
	# The station compiler fixes the equipped main hand for the whole clip.
	# Reject a foreign/mixed-hand packet before the presenter can rebuild the
	# live weapon and invalidate the editor snapshot.
	var current_root: Node3D = state.get("preview_root")
	var current_slot: StringName = current_root.get_meta(p.PREVIEW_ACTIVE_SLOT_ID_META, &"hand_right")
	for slot: StringName in runtime_clip.baked_primary_hand_slots:
		if p._normalize_preview_slot_id(slot) != current_slot:
			result["reason"] = "render_requires_current_equipped_hand"
			done = true
			return
	p.configure_preview_hand_setup(initial_frame.primary_hand_slot, p.preview_default_two_hand)
	p._refresh_actor_and_weapon(state, active_wip, initial_frame, active_draft)
	p._prepare_trajectory_root_for_authoring(state)
	preview_root = state.get("preview_root", null) as Node3D
	actor_pivot = state.get("actor_pivot", null) as Node3D
	actor = actor_pivot.get_node_or_null(p.PREVIEW_ACTOR_NAME) as Node3D if actor_pivot != null else null
	if preview_root == null or actor == null:
		result["reason"] = "missing_preview_actor"
		done = true
		return
	held_item = p._get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
	if held_item == null or not is_instance_valid(held_item):
		result["reason"] = "missing_preview_weapon"
		done = true
		return
	if not actor.has_method("capture_runtime_upper_body_pose_frame"):
		result["reason"] = "actor_cannot_capture_upper_body_pose"
		done = true
		return
	if trace_enabled:
		actor.set_meta("trace_save_latency", true)
		actor.set_meta("last_save_debug_visual_ms", 0.0)
		actor.set_meta("last_save_debug_visual_count", 0)
	requested_bone_names = []
	if actor.has_method("get_runtime_upper_body_pose_bone_names"):
		requested_bone_names = actor.call("get_runtime_upper_body_pose_bone_names") as Array
	resolved_bone_names = []
	captured_position_frames = []
	captured_rotation_frames = []
	captured_scale_frames = []
	solved_weapon_positions = PackedVector3Array()
	solved_weapon_rotations = PackedVector4Array()
	solved_weapon_scales = PackedVector3Array()
	solved_anchor_paths = p._resolve_solved_replay_anchor_node_paths(held_item)
	solved_anchor_position_frames = []
	solved_anchor_rotation_frames = []
	solved_anchor_scale_frames = []
	solved_frame_available = []
	primary_anchor_to_anatomical_grip_max = 0.0
	primary_anchor_to_anatomical_grip_sum = 0.0
	primary_anchor_to_anatomical_grip_count = 0
	primary_anchor_to_anatomical_grip_max_frame = -1

func _try_resume() -> void:
	checkpoints[-1] = seed
	if cached.is_empty() or context_key.is_empty() or cached.get("context_key", "") != context_key:
		return
	if int(cached.get("grip_seat_schema", -1)) != base_motion_node.grip_seat_coordinate_schema_version:
		return
	var old_seed: Dictionary = cached.get("seed", {})
	if not Checkpoint.can_restore(old_seed):
		return
	# Both full and incremental preparation start from the same captured state.
	# Editing the current viewport pose must not change an unchanged prefix.
	seed = old_seed
	working = seed
	checkpoints[-1] = seed
	var old_clip: Resource = cached.get("clip")
	var prefix := Incremental.matching_prefix_count(old_clip, runtime_clip)
	var boundary := -1
	var old_checkpoints: Dictionary = cached.get("checkpoints", {})
	if not bool(p.get_meta("force_full_pose_render", false)):
		var candidates: Array = old_checkpoints.keys()
		candidates.sort()
		candidates.reverse()
		for index: int in candidates:
			if index >= 0 and index < prefix and Checkpoint.can_restore(old_checkpoints[index]):
				boundary = index
				break
	if boundary < 0:
		return
	var prefix_data := Incremental.solved_prefix_data(old_clip, boundary + 1)
	if prefix_data.is_empty():
		return
	resolved_bone_names = prefix_data.baked_solved_upper_body_bone_names
	requested_bone_names = resolved_bone_names.duplicate()
	captured_position_frames = prefix_data.baked_solved_upper_body_pose_positions
	captured_rotation_frames = prefix_data.baked_solved_upper_body_pose_rotations
	captured_scale_frames = prefix_data.baked_solved_upper_body_pose_scales
	solved_weapon_positions = prefix_data.baked_solved_weapon_positions_reference_local
	solved_weapon_rotations = prefix_data.baked_solved_weapon_rotations_reference_local
	solved_weapon_scales = prefix_data.baked_solved_weapon_scales_reference_local
	solved_anchor_paths = prefix_data.baked_solved_anchor_node_paths
	solved_anchor_position_frames = prefix_data.baked_solved_anchor_positions_weapon_local
	solved_anchor_rotation_frames = prefix_data.baked_solved_anchor_rotations_weapon_local
	solved_anchor_scale_frames = prefix_data.baked_solved_anchor_scales_weapon_local
	solved_frame_available = prefix_data.baked_solved_replay_frame_available
	for index: int in old_checkpoints:
		if index <= boundary:
			checkpoints[index] = old_checkpoints[index]
	working = old_checkpoints[boundary]
	var metrics: Dictionary = working.get("anchor_metrics", {})
	primary_anchor_to_anatomical_grip_max = float(metrics.get("max", 0.0))
	primary_anchor_to_anatomical_grip_sum = float(metrics.get("sum", 0.0))
	primary_anchor_to_anatomical_grip_count = int(metrics.get("count", 0))
	primary_anchor_to_anatomical_grip_max_frame = int(metrics.get("frame", -1))
	frame_index = boundary + 1
	reused_frames = frame_index

## Cooperative calls return with the editing pose restored. Synchronous Save
## keeps its existing terminal-pose handoff. No partial clip is published.
func step(budget_usec: int = 20000) -> Dictionary:
	if done:
		return _progress()
	var started := Time.get_ticks_usec()
	var editor := Checkpoint.capture(p, state)
	_record_checkpoint_time("capture_editor_ms", started)
	if editor.is_empty():
		result["reason"] = "render_context_changed"
		done = true
		return _progress()
	actor.begin_authoring_debug_visual_batch()
	var restore_started := Time.get_ticks_usec()
	if not Checkpoint.restore(p, working):
		actor.end_authoring_debug_visual_batch()
		result["reason"] = "render_context_changed"
		done = true
		return _progress()
	_record_checkpoint_time("restore_working_ms", restore_started)
	while frame_index < frame_count and not done:
		_render_frame()
		if done:
			break
		if frame_index % checkpoint_interval == 0 or frame_index == frame_count - 1:
			var checkpoint := Checkpoint.capture(p, state)
			if not checkpoint.is_empty():
				checkpoint["anchor_metrics"] = {
					"max": primary_anchor_to_anatomical_grip_max,
					"sum": primary_anchor_to_anatomical_grip_sum,
					"count": primary_anchor_to_anatomical_grip_count,
					"frame": primary_anchor_to_anatomical_grip_max_frame}
				checkpoints[frame_index] = checkpoint
		frame_index += 1
		if budget_usec > 0 and Time.get_ticks_usec() - started >= budget_usec:
			break
	if not done and frame_index >= frame_count:
		_finish()
	if not done:
		var capture_started := Time.get_ticks_usec()
		# Boundary capture already represents this exact continuation; no scene
		# mutation occurs between it and the end of the slice.
		working = checkpoints[frame_index - 1] if checkpoints.has(frame_index - 1) else Checkpoint.capture(p, state)
		_record_checkpoint_time("capture_working_ms", capture_started)
		if working.is_empty():
			result["reason"] = "render_continuation_unavailable"
			done = true
	# Cooperative F slices return to editing. Synchronous Save retains the
	# existing sequential handoff into combat-idle baking; its outer operation
	# already owns restoring the editor after all required drafts are rendered.
	restore_started = Time.get_ticks_usec()
	var restored := Checkpoint.restore(p, editor) if budget_usec > 0 else true
	_record_checkpoint_time("restore_editor_ms", restore_started)
	actor.end_authoring_debug_visual_batch()
	if not restored:
		result["reason"] = "render_editor_restore_failed"
		result["restore_failure"] = Checkpoint.describe_restore_failure(editor)
		result["baked"] = false
		result["solved_replay_track"] = false
		done = true
	max_slice_usec = maxi(max_slice_usec, Time.get_ticks_usec() - started)
	if done and bool(result.get("baked", false)):
		p._store_pose_render_cache(context_key, {"context_key": context_key,
			"clip": runtime_clip, "seed": seed, "checkpoints": checkpoints,
			"grip_seat_schema": base_motion_node.grip_seat_coordinate_schema_version})
	return _progress()

func _record_checkpoint_time(label: String, started: int) -> void:
	if trace_enabled:
		profile[label] = float(profile.get(label, 0.0)) + (Time.get_ticks_usec() - started) / 1000.0

func cancel() -> void:
	if done:
		return
	result["reason"] = "render_cancelled"
	done = true
	checkpoints = {}
	working = {}

func _progress() -> Dictionary:
	result["done"] = done
	result["processed_frames"] = frame_index - reused_frames
	result["reused_frames"] = reused_frames
	result["completed_frames"] = frame_index
	result["max_slice_ms"] = max_slice_usec / 1000.0
	return result

func _render_frame() -> void:
	var frame_started_usec = Time.get_ticks_usec() if trace_enabled else 0
	var frame_motion_node: CombatAnimationMotionNode = p._build_runtime_clip_frame_motion_node(
		runtime_clip,
		frame_index,
		base_motion_node
	)
	var frame_slot = p._normalize_preview_slot_id(frame_motion_node.primary_hand_slot)
	if frame_slot != p._resolve_preview_dominant_slot_id():
		p.configure_preview_hand_setup(frame_slot, p.preview_default_two_hand)
		p._refresh_actor_and_weapon(state, active_wip, frame_motion_node, active_draft)
		held_item = p._get_node_meta_or_default(preview_root, "preview_held_item", null) as Node3D
		if held_item == null or not is_instance_valid(held_item):
			result["reason"] = "missing_preview_weapon_after_hand_swap"
			done = true
			return
		if p._resolve_solved_replay_anchor_node_paths(held_item) != solved_anchor_paths:
			result["reason"] = "hand_swap_changes_replay_anchor_layout"
			done = true
			return
	var playback_state: Dictionary = p._build_runtime_clip_frame_playback_state(
		runtime_clip,
		frame_index,
		frame_motion_node
	)
	playback_state["runtime_clip_playback"] = true
	playback_state["prepared_grip_bake"] = true
	if GripChronology.enabled():
		playback_state["_grip_trace_frame_index"] = frame_index
		playback_state["_grip_trace_time_s"] = float(runtime_clip.baked_frame_times[frame_index])
		playback_state["_grip_trace_clip_id"] = str(runtime_clip.get_instance_id())
	p._trace_bake_pose_stage(state, playback_state, "frame_before_authored_pose")
	# Baking prepares missing grip relationships and reuses committed local
	# poses. Live playback consumes the captured bones/weapon/anchors together.
	var previous_pose_profile: Dictionary = p._save_pose_latency_profile
	if trace_enabled:
		p._save_pose_latency_profile = profile
	var applied_pose: Dictionary = p._apply_runtime_clip_preview_pose(
		state,
		frame_motion_node,
		playback_state,
		active_draft,
		true
	)
	p._save_pose_latency_profile = previous_pose_profile
	if applied_pose.has("prepared_grip_bake_failure"):
		result["reason"] = String(applied_pose.prepared_grip_bake_failure)
		result["failed_frame"] = frame_index
		done = true
		return
	var grip_started_usec = Time.get_ticks_usec() if trace_enabled else 0
	if trace_enabled:
		profile["apply_pose_ms"] += float(grip_started_usec - frame_started_usec) / 1000.0
	if not p._is_unarmed_preview_item(held_item):
		var grip_owner: Node = actor.get_node_or_null(PreviewGripAcquisition.NODE_NAME)
		if grip_owner == null:
			result["reason"] = "missing_prepared_grip_bake_owner"
			done = true
			return
		var grip_slots: Array[StringName] = [p._resolve_preview_dominant_slot_id()]
		if p._should_preview_use_support_hand(held_item, frame_motion_node):
			grip_slots.append(p._resolve_preview_support_slot_id())
		var grip_result: Dictionary = grip_owner.prepare_replay_grip(grip_slots, p._resolve_preview_dominant_slot_id())
		if trace_enabled:
			profile["solved_relationships"] += int(grip_result.get("solved_relationships", 0))
			profile["reused_relationships"] += int(grip_result.get("reused_relationships", 0))
			profile["grip_ms"] += float(Time.get_ticks_usec() - grip_started_usec) / 1000.0
		if not grip_result.get("valid", false):
			result["reason"] = String(grip_result.get("reason", "prepared_grip_bake_failed"))
			result["failed_frame"] = frame_index
			done = true
			return
	var capture_started_usec = Time.get_ticks_usec() if trace_enabled else 0
	p._trace_bake_pose_stage(state, playback_state, "frame_after_prepare_replay_grip")
	var frame_capture: Dictionary = actor.call(
		"capture_runtime_upper_body_pose_frame",
		requested_bone_names
	) as Dictionary
	var captured_names: Array = frame_capture.get("bone_names", []) as Array
	var captured_positions: PackedVector3Array = frame_capture.get("pose_positions", PackedVector3Array()) as PackedVector3Array
	var captured_rotations: PackedVector4Array = frame_capture.get("pose_rotations", PackedVector4Array()) as PackedVector4Array
	var captured_scales: PackedVector3Array = frame_capture.get("pose_scales", PackedVector3Array()) as PackedVector3Array
	if captured_positions.is_empty() or captured_rotations.is_empty() or captured_scales.is_empty():
		result["reason"] = "empty_upper_body_capture"
		done = true
		return
	if frame_index == 0:
		resolved_bone_names.clear()
		for bone_name_variant: Variant in captured_names:
			resolved_bone_names.append(StringName(bone_name_variant))
		requested_bone_names = resolved_bone_names.duplicate()
	if (
		captured_positions.size() != resolved_bone_names.size()
		or captured_rotations.size() != resolved_bone_names.size()
		or captured_scales.size() != resolved_bone_names.size()
	):
		result["reason"] = "upper_body_capture_size_mismatch"
		done = true
		return
	var reference_transform: Transform3D = p._resolve_trajectory_authoring_transform(actor)
	var weapon_reference_transform: Transform3D = reference_transform.affine_inverse() * held_item.global_transform
	var anchor_capture: Dictionary = p._capture_solved_replay_anchor_frame(held_item, solved_anchor_paths)
	var primary_anchor: Node3D = p.weapon_grip_anchor_provider.get_primary_grip_anchor(held_item)
	if primary_anchor != null and actor.has_method("resolve_hand_grip_alignment_world_position"):
		var anatomical_grip_world: Vector3 = actor.call(
			"resolve_hand_grip_alignment_world_position",
			p._resolve_preview_dominant_slot_id()
		) as Vector3
		if anatomical_grip_world.length_squared() > 0.000001:
			var anchor_error_meters: float = primary_anchor.global_position.distance_to(anatomical_grip_world)
			primary_anchor_to_anatomical_grip_sum += anchor_error_meters
			primary_anchor_to_anatomical_grip_count += 1
			if anchor_error_meters > primary_anchor_to_anatomical_grip_max:
				primary_anchor_to_anatomical_grip_max = anchor_error_meters
				primary_anchor_to_anatomical_grip_max_frame = frame_index
	var anchor_positions: PackedVector3Array = anchor_capture.get("positions", PackedVector3Array()) as PackedVector3Array
	var anchor_rotations: PackedVector4Array = anchor_capture.get("rotations", PackedVector4Array()) as PackedVector4Array
	var anchor_scales: PackedVector3Array = anchor_capture.get("scales", PackedVector3Array()) as PackedVector3Array
	if (
		anchor_positions.size() != solved_anchor_paths.size()
		or anchor_rotations.size() != solved_anchor_paths.size()
		or anchor_scales.size() != solved_anchor_paths.size()
	):
		result["reason"] = "solved_anchor_capture_size_mismatch"
		done = true
		return
	captured_position_frames.append(captured_positions)
	captured_rotation_frames.append(captured_rotations)
	captured_scale_frames.append(captured_scales)
	solved_weapon_positions.append(weapon_reference_transform.origin)
	solved_weapon_rotations.append(p._pack_quaternion(weapon_reference_transform.basis.orthonormalized().get_rotation_quaternion()))
	solved_weapon_scales.append(weapon_reference_transform.basis.get_scale())
	solved_anchor_position_frames.append(anchor_positions)
	solved_anchor_rotation_frames.append(anchor_rotations)
	solved_anchor_scale_frames.append(anchor_scales)
	solved_frame_available.append(true)
	if trace_enabled:
		var frame_finished_usec = Time.get_ticks_usec()
		profile["capture_ms"] += float(frame_finished_usec - capture_started_usec) / 1000.0
		profile["max_frame_ms"] = maxf(float(profile["max_frame_ms"]), float(frame_finished_usec - frame_started_usec) / 1000.0)
		profile["processed_frames"] += 1
		profile["debug_visual_ms"] = float(actor.get_meta("last_save_debug_visual_ms", 0.0))
		profile["debug_visual_count"] = int(actor.get_meta("last_save_debug_visual_count", 0))

func _finish() -> void:
	runtime_clip.set("baked_upper_body_bone_names", resolved_bone_names)
	runtime_clip.set("baked_upper_body_bone_pose_rotations", captured_rotation_frames)
	runtime_clip.set(
		"upper_body_pose_track_source",
		CombatRuntimeClipScript.UPPER_BODY_POSE_TRACK_SOURCE_SKILL_CRAFTER_AUTHORED_POSE
	)
	runtime_clip.set("solved_replay_track_source", CombatRuntimeClipScript.SOLVED_REPLAY_TRACK_SOURCE_SKILL_CRAFTER_F_PLAYBACK)
	runtime_clip.set("solved_replay_reference_bone_name", p.PREVIEW_ROOT_BONE)
	runtime_clip.set("solved_replay_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)
	runtime_clip.set("baked_solved_weapon_reference_origin_id", CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)
	runtime_clip.set("baked_solved_anchor_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	runtime_clip.set("baked_solved_replay_frame_available", solved_frame_available)
	runtime_clip.set("baked_solved_upper_body_bone_names", resolved_bone_names)
	runtime_clip.set("baked_solved_upper_body_pose_positions", captured_position_frames)
	runtime_clip.set("baked_solved_upper_body_pose_rotations", captured_rotation_frames)
	runtime_clip.set("baked_solved_upper_body_pose_scales", captured_scale_frames)
	runtime_clip.set("baked_solved_weapon_positions_reference_local", solved_weapon_positions)
	runtime_clip.set("baked_solved_weapon_rotations_reference_local", solved_weapon_rotations)
	runtime_clip.set("baked_solved_weapon_scales_reference_local", solved_weapon_scales)
	runtime_clip.set("baked_solved_anchor_node_paths", solved_anchor_paths)
	runtime_clip.set("baked_solved_anchor_positions_weapon_local", solved_anchor_position_frames)
	runtime_clip.set("baked_solved_anchor_rotations_weapon_local", solved_anchor_rotation_frames)
	runtime_clip.set("baked_solved_anchor_scales_weapon_local", solved_anchor_scale_frames)
	if runtime_clip.has_method("normalize"):
		runtime_clip.call("normalize")
	result["baked"] = not resolved_bone_names.is_empty() and captured_rotation_frames.size() == frame_count
	result["solved_replay_track"] = runtime_clip.has_method("has_solved_replay_track") and bool(runtime_clip.call("has_solved_replay_track"))
	result["bone_count"] = resolved_bone_names.size()
	result["anchor_count"] = solved_anchor_paths.size()
	if primary_anchor_to_anatomical_grip_count > 0:
		result["primary_anchor_to_anatomical_grip_max_meters"] = primary_anchor_to_anatomical_grip_max
		result["primary_anchor_to_anatomical_grip_avg_meters"] = primary_anchor_to_anatomical_grip_sum / float(primary_anchor_to_anatomical_grip_count)
		result["primary_anchor_to_anatomical_grip_max_frame"] = primary_anchor_to_anatomical_grip_max_frame
	if not bool(result.get("baked", false)):
		result["reason"] = "no_upper_body_bones_captured"
	done = true
