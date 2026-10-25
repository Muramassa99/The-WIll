extends RefCounted

## Records missing authored endpoints through the normal editor presenter.
## This is a migration/repair path, not a sampled-frame replay renderer. The
## visible editor keeps its own rig, camera, selection and pending controls.
const PreviewPresenter = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")


func record(station: Node, drafts: Array, request_current: Callable) -> Dictionary:
	if not _request_is_current(station, request_current):
		return _failure("endpoint_recording_cancelled")
	var expected: Dictionary = _live_context(station)
	if not bool(expected.get("valid", false)):
		return expected
	var gathered: Dictionary = _gather_missing(drafts, String(expected.context_signature))
	if not bool(gathered.get("valid", false)):
		return gathered
	var pending: Array = gathered.pending
	if pending.is_empty():
		return {"valid": true, "reason": "", "recorded_node_count": 0}
	var source_wip: CraftedItemWIP = station.get("active_wip") as CraftedItemWIP
	if source_wip == null:
		return _failure("endpoint_recording_missing_weapon")
	# The presenter may normalize/bake its weapon data. Neither those changes nor
	# its endpoint normalization may leak into the user's authored resources.
	var work_wip: CraftedItemWIP = source_wip.duplicate(true) as CraftedItemWIP
	var presenter = PreviewPresenter.new()
	var container := SubViewportContainer.new()
	container.name = "EndpointRecordingPreview"
	container.size = Vector2(64.0, 64.0)
	container.position = Vector2(-8192.0, -8192.0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	container.visible = false
	var viewport := SubViewport.new()
	viewport.name = "EndpointRecordingViewport"
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	station.add_child(container)
	var result: Dictionary = await _record_pending(station, request_current, presenter,
		container, viewport, work_wip, pending, gathered.sources, String(expected.context_signature))
	# The acquisition owner's _exit_tree cancels/shuts down a worker on a
	# cancelled request. All successful/failed/cancelled paths meet here.
	if is_instance_valid(container):
		container.queue_free()
	return result


func _record_pending(station: Node, request_current: Callable, presenter,
		container: SubViewportContainer, viewport: SubViewport, work_wip: CraftedItemWIP,
		pending: Array, sources: Array, expected_context: String) -> Dictionary:
	var started_usec: int = Time.get_ticks_usec()
	var staged: Array = []
	var opening_slot: StringName = StringName(station.call("_resolve_active_authoring_primary_slot_id"))
	var default_two_hand: bool = bool(station.get("active_preview_default_two_hand"))
	var playback_state: Dictionary = station.call("_build_preview_playback_state")
	# The helper presents authored endpoints, never the current playback frame.
	playback_state = {"debugger_view_enabled": false,
		"open_mount_seed": playback_state.get("open_mount_seed", {}).duplicate(true),
		"grip_resolve_reason": PreviewPresenter.GRIP_RESOLVE_REASON_HANDLE_POSITION}
	for item: Dictionary in pending:
		if not _request_is_current(station, request_current):
			return _failure("endpoint_recording_cancelled")
		var motion: CombatAnimationMotionNode = item.copy_node as CombatAnimationMotionNode
		var dominant: StringName = opening_slot
		if CraftedItemWIP.is_unarmed_authoring_wip(work_wip) and motion.primary_hand_slot in [&"hand_right", &"hand_left"]:
			dominant = motion.primary_hand_slot
		presenter.configure_preview_hand_setup(dominant, default_two_hand)
		item.copy_draft.set("selected_motion_node_index", item.editor_index)
		_report_progress(station, staged.size(), pending.size(), item, "preparing")
		presenter.refresh_preview(container, viewport, work_wip, item.copy_draft,
			int(item.editor_index), &"tip", work_wip.latest_baked_profile_snapshot, playback_state)
		if PreparedPose.node_pose_signature(motion) != String(item.signature):
			return _failure("endpoint_recording_copy_inputs_changed", item)
		var candidate_key: String = ""
		var candidate_frame: int = -1
		var next_progress_usec: int = 0
		while true:
			await station.get_tree().process_frame
			if not _request_is_current(station, request_current) or not is_instance_valid(viewport):
				return _failure("endpoint_recording_cancelled")
			var states: Dictionary = presenter.get_grip_acquisition_status(viewport)
			if Time.get_ticks_usec() >= next_progress_usec:
				_report_progress(station, staged.size(), pending.size(), item, _acquisition_label(states))
				next_progress_usec = Time.get_ticks_usec() + 250000
			if presenter.is_grip_acquisition_pending(viewport):
				candidate_key = ""
				candidate_frame = -1
				continue
			var context: Dictionary = presenter.get_prepared_pose_capture_context(viewport, motion)
			if not bool(context.get("valid", false)):
				return _failure(String(context.get("reason", "endpoint_recording_pose_unavailable")), item, states)
			var context_signature: String = String(station.call("_prepared_pose_context_signature", context))
			if context_signature != expected_context:
				return _failure("endpoint_recording_context_mismatch", item)
			var key: String = context_signature + ":" + str(context.get("settle_serial", 0))
			var frame: int = Engine.get_process_frames()
			if candidate_key != key:
				candidate_key = key
				candidate_frame = frame
				continue
			if frame - candidate_frame < 2:
				continue
			if PreparedPose.node_pose_signature(motion) != String(item.signature):
				return _failure("endpoint_recording_copy_inputs_changed", item)
			var snapshot: Dictionary = presenter.capture_prepared_authoring_pose(context, context_signature)
			var validation: Dictionary = PreparedPose.validate(snapshot, expected_context)
			if not bool(validation.get("valid", false)):
				return _failure(String(validation.get("reason", "endpoint_recording_capture_failed")), item)
			staged.append({"node": item.node, "signature": item.signature, "pose": snapshot})
			break
	# Validate the complete original input set before any publication. A camera
	# move is allowed, but a node edit/reorder/removal or context change cancels.
	if not _request_is_current(station, request_current) or not _sources_unchanged(sources):
		return _failure("endpoint_recording_inputs_changed")
	var live: Dictionary = _live_context(station)
	if not bool(live.get("valid", false)) or String(live.get("context_signature", "")) != expected_context:
		return _failure("endpoint_recording_live_context_changed")
	# No yields during publication: either every requested endpoint becomes
	# available together, or none of the staged packets replaces existing data.
	for packet: Dictionary in staged:
		packet.node.prepared_pose = packet.pose
		packet.node.prepared_pose_signature = packet.signature
	return {"valid": true, "reason": "", "recorded_node_count": staged.size(),
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0}


func _gather_missing(drafts: Array, context_signature: String) -> Dictionary:
	var pending: Array = []
	var sources: Array = []
	var seen: Dictionary = {}
	for draft: Resource in drafts:
		if draft == null or not draft.has_method("get_action_motion_node_chain"):
			return _failure("endpoint_recording_missing_draft")
		if seen.has(draft.get_instance_id()):
			continue
		seen[draft.get_instance_id()] = true
		var action_chain: Array = draft.call("get_action_motion_node_chain")
		var editor_chain: Array = draft.get("motion_node_chain")
		var copy_draft: Resource = null
		var copy_chain: Array[Resource] = []
		var signatures: Array[String] = []
		for node: CombatAnimationMotionNode in action_chain:
			if node == null:
				return _failure("endpoint_recording_missing_node")
			var signature: String = PreparedPose.node_pose_signature(node)
			signatures.append(signature)
			if node.prepared_pose_signature == signature and bool(PreparedPose.validate(node.prepared_pose, context_signature).get("valid", false)):
				continue
			if copy_draft == null:
				copy_draft = draft.duplicate(false)
				for source: Resource in editor_chain:
					copy_chain.append(source.duplicate(true) if source != null else null)
				copy_draft.set("motion_node_chain", copy_chain)
			var editor_index: int = editor_chain.find(node)
			if editor_index < 0:
				return _failure("endpoint_recording_node_not_in_editor")
			pending.append({"node": node, "signature": signature, "editor_index": editor_index,
				"visible_index": action_chain.find(node) + 1, "draft_name": String(draft.get("display_name")),
				"copy_draft": copy_draft, "copy_node": copy_chain[editor_index]})
		sources.append({"draft": draft, "nodes": action_chain.duplicate(), "signatures": signatures})
	return {"valid": true, "pending": pending, "sources": sources}


func _sources_unchanged(sources: Array) -> bool:
	for source: Dictionary in sources:
		var current: Array = source.draft.call("get_action_motion_node_chain")
		if current != source.nodes:
			return false
		for index: int in current.size():
			if PreparedPose.node_pose_signature(current[index]) != source.signatures[index]:
				return false
	return true


func _live_context(station: Node) -> Dictionary:
	var presenter: Variant = station.get("preview_presenter")
	var viewport: SubViewport = station.get("preview_subviewport") as SubViewport
	var motion: CombatAnimationMotionNode = station.call("_get_active_motion_node") as CombatAnimationMotionNode
	var context: Dictionary = presenter.get_prepared_pose_capture_context(viewport, motion, false)
	if not bool(context.get("valid", false)):
		return _failure(String(context.get("reason", "endpoint_recording_live_context_unavailable")))
	return {"valid": true, "context_signature": String(station.call("_prepared_pose_context_signature", context))}


func _request_is_current(station: Node, request_current: Callable) -> bool:
	return is_instance_valid(station) and station.is_inside_tree() and not station.is_queued_for_deletion() \
		and request_current.is_valid() and bool(request_current.call())


func _report_progress(station: Node, completed: int, total: int, item: Dictionary, phase: String) -> void:
	var message := "Recording motion pose %d/%d (%s, node %d): %s" % [completed + 1, total,
		String(item.draft_name), int(item.visible_index), phase]
	station.call("_set_manual_save_progress", 100.0 * float(completed) / float(maxi(total, 1)), message, true)
	var footer: Label = station.get("footer_status_label") as Label
	if footer != null:
		footer.text = message


func _acquisition_label(states: Dictionary) -> String:
	for state: Dictionary in states.values():
		var status: String = String(state.get("status", ""))
		if status in ["queued", "solving", "assessing"]:
			return status
	return "settling"


func _failure(reason: String, item: Dictionary = {}, states: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "recorded_node_count": 0,
		"node_index": int(item.get("visible_index", -1)), "draft_name": String(item.get("draft_name", "")),
		"grip_status": states}
