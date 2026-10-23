extends RefCounted

## In-memory continuation state for the existing preview rig. Never serialized.
## Camera state deliberately does not participate in pose suspension.
static func capture(presenter, state: Dictionary) -> Dictionary:
	var root: Node3D = state.get("preview_root")
	var pivot: Node3D = state.get("actor_pivot")
	if not is_instance_valid(root) or not is_instance_valid(pivot):
		return {}
	var actor: Node3D = pivot.get_node_or_null(presenter.PREVIEW_ACTOR_NAME)
	var weapon: Node3D = root.get_meta("preview_held_item", null)
	if not is_instance_valid(actor) or not is_instance_valid(weapon):
		return {}
	var rig: Dictionary = actor.capture_render_checkpoint()
	if rig.is_empty():
		return {}
	var owner: Node = actor.get_node_or_null("PreparedGripAcquisition")
	var grip: Dictionary = owner.capture_render_checkpoint() if owner != null else {}
	if owner != null and grip.is_empty():
		return {}
	var nodes: Array = []
	_capture_node(weapon, nodes, true)
	for slot: String in ["hand_right", "hand_left"]:
		var proxy := root.get_node_or_null("HandAuthoringProxy_" + slot) as Node3D
		if proxy != null and proxy != weapon:
			_capture_node(proxy, nodes, true)
	for key in ["actor_pivot", "trajectory_root"]:
		var node: Node3D = state.get(key)
		if is_instance_valid(node):
			_capture_node(node, nodes, false)
	return {"root": weakref(root), "actor": weakref(actor), "weapon": weakref(weapon),
		"rig": rig, "owner": weakref(owner) if owner != null else null, "grip": grip,
		"nodes": nodes, "root_meta": _capture_meta(root, true),
		"slot": presenter.preview_dominant_slot_id, "two_hand": presenter.preview_default_two_hand}

static func can_restore(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var root = snapshot.root.get_ref()
	var actor = snapshot.actor.get_ref()
	var weapon = snapshot.weapon.get_ref()
	if not is_instance_valid(root) or not is_instance_valid(actor) or not is_instance_valid(weapon):
		return false
	if root.get_meta("preview_held_item", null) != weapon or not actor.can_restore_render_checkpoint(snapshot.rig):
		return false
	if snapshot.owner != null:
		var owner = snapshot.owner.get_ref()
		if not is_instance_valid(owner) or not owner.can_restore_render_checkpoint(snapshot.grip):
			return false
	for entry: Dictionary in snapshot.nodes:
		var node = entry.node.get_ref()
		if not is_instance_valid(node) or node.get_parent() != entry.parent.get_ref():
			return false
	return true

static func restore(presenter, snapshot: Dictionary) -> bool:
	if not can_restore(snapshot):
		return false
	# One complete preflight protects this synchronous commit. The internal
	# helpers never yield, solve, advance modifiers or emit ownership signals.
	for entry: Dictionary in snapshot.nodes:
		var node = entry.node.get_ref()
		node.transform = entry.transform
		_restore_meta(node, entry.meta, false)
	_restore_meta(snapshot.root.get_ref(), snapshot.root_meta, true)
	if snapshot.owner != null:
		snapshot.owner.get_ref()._restore_render_checkpoint_after_preflight(snapshot.grip)
	snapshot.actor.get_ref()._restore_render_checkpoint_after_preflight(snapshot.rig)
	presenter.configure_preview_hand_setup(snapshot.slot, snapshot.two_hand)
	return true

## Failure-only diagnostics. This never restores, configures or relaxes a guard.
static func describe_restore_failure(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {"reason": "empty_checkpoint"}
	var root = snapshot.root.get_ref()
	var actor = snapshot.actor.get_ref()
	var weapon = snapshot.weapon.get_ref()
	if not is_instance_valid(root) or not is_instance_valid(actor) or not is_instance_valid(weapon):
		return {"reason": "checkpoint_object_unavailable"}
	var details: Dictionary = {"reason": "", "weapon_matches": root.get_meta("preview_held_item", null) == weapon}
	details["rig_compatible"] = actor.can_restore_render_checkpoint(snapshot.rig)
	if not details.rig_compatible:
		if is_instance_valid(actor.get("skeleton")):
			details["rig_identity_changed_fields"] = _changed_identity_fields(
				snapshot.rig.get("identity", {}), actor._render_checkpoint_rig_identity())
		else:
			details["rig_identity_changed_fields"] = ["skeleton_unavailable"]
	if snapshot.owner != null:
		var owner = snapshot.owner.get_ref()
		details["owner_available"] = is_instance_valid(owner)
		if is_instance_valid(owner):
			var previous_identity: Dictionary = snapshot.grip.get("identity", {})
			var current_identity: Dictionary = owner._render_checkpoint_identity()
			details["owner_idle"] = owner.is_render_checkpoint_idle()
			details["owner_compatible"] = owner.can_restore_render_checkpoint(snapshot.grip)
			details["owner_was_configured"] = previous_identity.get("configured", true)
			details["owner_is_configured"] = current_identity.get("configured", true)
			details["owner_identity_changed_fields"] = _changed_identity_fields(previous_identity, current_identity)
	var invalid_nodes: Array[String] = []
	for entry: Dictionary in snapshot.nodes:
		var node = entry.node.get_ref()
		if not is_instance_valid(node):
			invalid_nodes.append("freed_node")
		elif node.get_parent() != entry.parent.get_ref():
			invalid_nodes.append(String(node.get_path()))
	details["invalid_nodes"] = invalid_nodes
	if not details.weapon_matches:
		details["reason"] = "preview_weapon_changed"
	elif not details.rig_compatible:
		details["reason"] = "rig_checkpoint_rejected"
	elif not bool(details.get("owner_available", true)) or not bool(details.get("owner_compatible", true)):
		details["reason"] = "grip_owner_checkpoint_rejected"
	elif not invalid_nodes.is_empty():
		details["reason"] = "checkpoint_node_hierarchy_changed"
	return details

static func _changed_identity_fields(previous: Dictionary, current: Dictionary) -> Array[String]:
	var changed: Array[String] = []
	for key: Variant in previous.keys() + current.keys():
		if (not previous.has(key) or not current.has(key) or previous[key] != current[key]) and String(key) not in changed:
			changed.append(String(key))
	return changed

static func _capture_node(node: Node3D, output: Array, recursive: bool) -> void:
	output.append({"node": weakref(node), "parent": weakref(node.get_parent()),
		"transform": node.transform, "meta": _capture_meta(node, false)})
	if recursive:
		for child in node.get_children():
			if child is Node3D:
				_capture_node(child, output, true)

static func _camera_key(key: StringName) -> bool:
	return String(key).contains("camera")

static func _capture_meta(node: Object, exclude_camera: bool) -> Dictionary:
	var values: Dictionary = {}
	for key in node.get_meta_list():
		if not exclude_camera or not _camera_key(key):
			values[key] = node.get_meta(key)
	return values.duplicate(true)

static func _restore_meta(node: Object, values: Dictionary, exclude_camera: bool) -> void:
	for key in node.get_meta_list():
		if (not exclude_camera or not _camera_key(key)) and not values.has(key):
			node.remove_meta(key)
	for key in values:
		var value: Variant = values[key]
		node.set_meta(key, value.duplicate(true) if value is Dictionary or value is Array else value)
