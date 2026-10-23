extends RefCounted
class_name CombatPreparedAttachmentResolver

## Carry the captured grip frame with the existing rigid weapon path. Fingers
## remain the authored tween; this only realizes the arm which carries them.
const Arm = preload("res://core/resolvers/combat_prepared_arm_frame_resolver.gd")
const Seat = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const GripTransition = preload("res://core/resolvers/combat_grip_transition_resolver.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

static func apply(sample: Dictionary, from: Dictionary, to: Dictionary, weight: float, from_node: Resource = null, to_node: Resource = null) -> Dictionary:
	var result := {"valid": true, "reason": "", "pose_rotations": sample.pose_rotations,
		"ik_calls": 0, "relations": {}, "diagnostics": {}}
	# Authored destinations and the actual incoming pose are not new targets to
	# optimize. Keeping their captured values also avoids endpoint drift.
	if weight <= 0.0 or weight >= 1.0:
		return result
	if not bool(from.get("attachment_required", true)) and not bool(to.get("attachment_required", true)):
		return result
	if from_node != null and to_node != null and GripTransition.is_style_swap(from_node.preferred_grip_style_mode, to_node.preferred_grip_style_mode):
		result.diagnostics["released_for_style_change"] = true
		return result
	var pose: Dictionary = from.duplicate()
	for field: String in ["pose_positions", "pose_rotations", "pose_scales", "parent_reference_transforms"]:
		pose[field] = sample[field]
	for kind: String in ["primary", "support"]:
		if kind == "support" and not (bool(from.get("support_enabled", false)) and bool(to.get("support_enabled", false))):
			continue
		if from.get(kind + "_hand_bone_name") != to.get(kind + "_hand_bone_name"):
			# A hand-off is a transition between different hands, not a rigid mate
			# imposed on both of them throughout the transfer.
			result.diagnostics[kind + "_hand_transfer"] = true
			continue
		if not bool(from.get("transient_entry_source", false)) and from_node != null and to_node != null:
			var seat_field: String = "grip_seat_slide_offset" if kind == "primary" else "secondary_grip_seat_slide_offset"
			var authored_slide: bool = not is_equal_approx(float(from_node.get(seat_field)), float(to_node.get(seat_field))) or not is_equal_approx(float(from_node.axial_reposition_offset), float(to_node.axial_reposition_offset))
			if authored_slide and (not bool(from.get(kind + "_handle_seat", {}).get("valid", false)) or not bool(to.get(kind + "_handle_seat", {}).get("valid", false))):
				return {"valid": false, "reason": "prepared_slide_missing_authored_seat", "hand": kind}
		var slot: StringName = from.get(kind + "_hand_slot", &"")
		var constraints: Dictionary = from.get("arm_constraints_by_slot", {}).get(slot, {})
		var destination_constraints: Dictionary = to.get("arm_constraints_by_slot", {}).get(slot, {})
		if not bool(constraints.get("valid", false)) or not bool(destination_constraints.get("valid", false)):
			return {"valid": false, "reason": "missing_prepared_attachment_constraints", "hand": kind}
		constraints = constraints.duplicate(true)
		var up: Vector3 = constraints.reference_up.lerp(destination_constraints.reference_up, weight)
		if up.length_squared() > 0.000001:
			constraints.reference_up = up.normalized()
		var relation: Dictionary = sample_relationship(from, to, kind, weight)
		if not relation.valid:
			return relation.merged({"hand": kind})
		var target: Transform3D = sample.weapon_transform * relation.transform
		var followed: Dictionary = Arm.resolve(pose, target, constraints)
		if not bool(followed.get("valid", false)):
			return followed.merged({"hand": kind, "reason": "prepared_attachment_" + String(followed.get("reason", "unavailable"))})
		pose.pose_rotations = followed.pose_rotations
		result.pose_rotations = followed.pose_rotations
		result.ik_calls += 1
		result.relations[kind] = relation.transform
		var metrics: Dictionary = followed.duplicate()
		metrics.erase("pose_rotations")
		metrics["handle_path_used"] = relation.get("handle_path_used", false)
		result.diagnostics[kind] = metrics
	return result

static func sample_relationship(from: Dictionary, to: Dictionary, kind: String, weight: float) -> Dictionary:
	var a: Transform3D = from[kind + "_hand_in_weapon"]
	var b: Transform3D = to[kind + "_hand_in_weapon"]
	if weight <= 0.0:
		return {"valid": true, "transform": a, "handle_path_used": false}
	if weight >= 1.0:
		return {"valid": true, "transform": b, "handle_path_used": false}
	var relation: Transform3D = a.interpolate_with(b, weight)
	var result := {"valid": true, "transform": relation, "handle_path_used": false}
	var seat_a: Dictionary = from.get(kind + "_handle_seat", {})
	var seat_b: Dictionary = to.get(kind + "_handle_seat", {})
	if not bool(seat_a.get("valid", false)) or not bool(seat_b.get("valid", false)):
		# Entry can start from any already displayed relation. Its full captured
		# A/B frames still provide a transition when no authored seat is present.
		return result
	if is_equal_approx(float(seat_a.ratio), float(seat_b.ratio)):
		return result
	var path: Dictionary = from.get("handle_path", {})
	var other: Dictionary = to.get("handle_path", {})
	if not bool(path.get("valid", false)) or not bool(other.get("valid", false)) or path.get("origin_id") != Origins.ORIGIN_WEAPON_ROOT or path.get("ratios") != other.get("ratios") or path.get("centers") != other.get("centers"):
		return {"valid": false, "reason": "prepared_slide_handle_path_changed_or_missing"}
	var current: Dictionary = Seat.resolve_sampled_seat(path.ratios, path.centers, path.origin_id, lerpf(float(seat_a.ratio), float(seat_b.ratio), weight))
	if not bool(current.get("valid", false)):
		return {"valid": false, "reason": "prepared_slide_handle_path_invalid"}
	# Replace the endpoint-center chord with the existing handle center path.
	# Equal acquired offsets stay constant; distinct acquired endpoint offsets
	# remain an A/B transition rather than a new contact search.
	relation.origin += current.position - (seat_a.position as Vector3).lerp(seat_b.position, weight)
	result.transform = relation
	result.handle_path_used = true
	return result
