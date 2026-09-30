extends RefCounted

## Per-slot ownership of the fifteen acquired digit rotations. The recorded
## Hand-in-WeaponRoot relationship is fixed after acquisition. Movement may use
## it as a target; acquisition itself never moves the arm or wrist.
const Origins = preload("res://core/models/combat_origin_record.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const DIGITS: Array[StringName] = [&"middle",&"thumb",&"index",&"ring",&"pinky"]
const FRAME_GUARD: float = 0.000005
var states: Dictionary = {}

func claim(skeleton: Skeleton3D, slot: StringName, weapon: Node3D, relationship_key: String) -> Dictionary:
	if skeleton==null or slot not in [&"hand_right",&"hand_left"] or weapon==null or not is_instance_valid(weapon) or relationship_key.is_empty():
		return _fail("invalid_planar_grip_claim")
	var rotations: Dictionary = {}
	for name: StringName in Rules.get_finger_bone_names(slot):
		var index: int = skeleton.find_bone(name)
		if index<0: return _fail("missing_digit_bone")
		var rotation: Quaternion = skeleton.get_bone_pose_rotation(index)
		if not rotation.is_finite() or rotation.length_squared()<0.000001: return _fail("invalid_current_digit_rotation")
		rotations[name]=rotation.normalized()
	if rotations.size()!=15: return _fail("incomplete_finger_ownership")
	if matches(slot,weapon,relationship_key): return {"valid":true,"state":state(slot),"rotations":states[slot].rotations.duplicate()}
	release(slot)
	states[slot]={"weapon_ref":weakref(weapon),"weapon_instance_id":weapon.get_instance_id(),"relationship_key":relationship_key,
		"status":&"planar_grip_pending","rotations":rotations,"has_grip_pose":false,"grip_accepted":false}
	return {"valid":true,"state":state(slot),"rotations":rotations.duplicate()}

func matches(slot: StringName, weapon: Node3D, relationship_key: String) -> bool:
	return owns(slot) and states[slot].weapon_ref.get_ref()==weapon and states[slot].relationship_key==relationship_key

func owns(slot: StringName) -> bool:
	if not states.has(slot): return false
	var weapon: Variant = states[slot].weapon_ref.get_ref()
	if weapon==null or not is_instance_valid(weapon): release(slot); return false
	return true

func release(slot: StringName) -> void:
	states.erase(slot)

## Small read-only packet for movement, without copying anatomy/diagnostics.
func relationship(slot: StringName, weapon: Node3D) -> Dictionary:
	if not owns(slot) or states[slot].weapon_ref.get_ref() != weapon or not states[slot].get("has_grip_pose", false):
		return {}
	var entry: Dictionary = states[slot]
	if entry.get("hand_in_weapon_origin_id") != Origins.ORIGIN_WEAPON_ROOT:
		return {}
	return {"valid": true, "hand_in_weapon": entry.hand_in_weapon,
		"hand_in_weapon_origin_id": entry.hand_in_weapon_origin_id,
		"relationship_key": entry.relationship_key}

func state(slot: StringName) -> Dictionary:
	if not owns(slot): return {"owned":false,"has_grip_pose":false,"grip_accepted":false}
	var out: Dictionary = states[slot].duplicate(true)
	out.erase("weapon_ref"); out.erase("rotations")
	out["owned"]=true
	return out

func prepare(skeleton: Skeleton3D, slot: StringName, weapon: Node3D, key: String, packet: Dictionary) -> Dictionary:
	if not matches(slot,weapon,key): return _fail("planar_grip_claim_changed")
	if packet.get("hand_in_weapon_origin_id")!=Origins.ORIGIN_WEAPON_ROOT or not packet.get("hand_in_weapon") is Transform3D:
		return _fail("missing_named_hand_in_weapon_frame")
	var hand_local: Transform3D = packet.hand_in_weapon
	if not _frame_valid(hand_local) or str(packet.get("anatomy_signature","")).is_empty() or str(packet.get("source_pose_id","")).is_empty():
		return _fail("missing_planar_grip_pose_provenance")
	if not packet.get("digit_states") is Dictionary or packet.digit_states.size()!=DIGITS.size(): return _fail("requires_five_digits")
	var hand_name: StringName = &"CC_Base_R_Hand" if slot==&"hand_right" else &"CC_Base_L_Hand"
	var hand_index: int = skeleton.find_bone(hand_name)
	if hand_index<0: return _fail("missing_hand_bone")
	var actual_hand: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)
	var desired_hand: Transform3D = weapon.global_transform*hand_local
	if not _frame_valid(desired_hand) or desired_hand.basis.get_scale().distance_to(actual_hand.basis.get_scale())>FRAME_GUARD:
		return _fail("grip_relationship_changes_character_metric")
	var rotations: Dictionary = {}
	var geometry: Array = []
	var dimensions: Dictionary = {}
	var matches_geometry: bool = true
	for digit_id: StringName in DIGITS:
		var item: Variant = packet.digit_states.get(digit_id)
		if not item is Dictionary or not item.get("snapshot") is Dictionary or not item.get("digit") is Dictionary: return _fail("missing_digit_snapshot")
		if item.digit.get("slot_id")!=slot or item.digit.get("digit_id")!=digit_id or item.digit.get("hand_bone_name")!=hand_name: return _fail("digit_identity_mismatch")
		var snapshot: Dictionary = item.snapshot
		for field: String in ["bone_names","relative_transforms","neutral_local_rotations","hinge_axes_local","min_angles_rad","max_angles_rad","relative_transform_origin_ids","neutral_local_rotation_origin_ids","hinge_axis_origin_ids"]:
			if not snapshot.get(field) is Array or snapshot[field].size()!=3: return _fail("incomplete_digit_"+field)
		if not item.get("angles_rad") is Array or item.angles_rad.size()!=3: return _fail("missing_three_hinge_angles")
		var rules: Array = Rules.get_chain_rules(slot,digit_id)
		var parent_name: StringName = hand_name
		var parent_world: Transform3D = actual_hand
		for joint: int in 3:
			var name: StringName = snapshot.bone_names[joint]
			if rules.size()!=3 or name!=rules[joint].bone: return _fail("unexpected_digit_bone")
			var index: int = skeleton.find_bone(name)
			if index<0 or skeleton.get_bone_parent(index)<0 or skeleton.get_bone_name(skeleton.get_bone_parent(index))!=parent_name: return _fail("actual_digit_parent_mismatch")
			for field: String in ["relative_transform_origin_ids","neutral_local_rotation_origin_ids","hinge_axis_origin_ids"]:
				if str(snapshot[field][joint]).is_empty(): return _fail("missing_digit_value_origin")
			if not snapshot.relative_transforms[joint] is Transform3D or not snapshot.neutral_local_rotations[joint] is Quaternion or not snapshot.hinge_axes_local[joint] is Vector3: return _fail("invalid_digit_frame_types")
			var relative: Transform3D = snapshot.relative_transforms[joint]
			var neutral: Quaternion = snapshot.neutral_local_rotations[joint]
			var axis: Vector3 = snapshot.hinge_axes_local[joint]
			var angle: float = float(item.angles_rad[joint])
			var low: float = float(snapshot.min_angles_rad[joint]); var high: float = float(snapshot.max_angles_rad[joint])
			var rule_low: float = deg_to_rad(minf(rules[joint].open_degrees,rules[joint].closed_degrees))
			var rule_high: float = deg_to_rad(maxf(rules[joint].open_degrees,rules[joint].closed_degrees))
			if not _frame_valid(relative) or not neutral.is_finite() or neutral.length_squared()<0.000001 or not axis.is_finite() or axis.length_squared()<0.000001 or not is_finite(angle) or not is_finite(low) or not is_finite(high) or low>high or angle<low or angle>high or angle<rule_low-0.0000001 or angle>rule_high+0.0000001:
				return _fail("invalid_or_out_of_range_prepared_hinge")
			var basis: Basis = relative.basis*Basis(neutral.normalized())*Basis(axis.normalized(),angle)
			var local: Transform3D = skeleton.get_bone_pose(index)
			if not _frame_valid(local): return _fail("invalid_current_digit_pose")
			var position_error: float = (parent_world.basis*(local.origin-relative.origin)).length()
			var scale_error: float = local.basis.get_scale().distance_to(basis.get_scale())
			var matched: bool = position_error<=FRAME_GUARD and scale_error<=FRAME_GUARD
			matches_geometry=matches_geometry and matched
			geometry.append({"bone":name,"local_position_error_world_m":position_error,"local_scale_error":scale_error,"numeric_guard":FRAME_GUARD,"matches_prepared":matched})
			rotations[name]=basis.orthonormalized().get_rotation_quaternion().normalized()
			dimensions[name]={"position":skeleton.get_bone_pose_position(index),"scale":skeleton.get_bone_pose_scale(index)}
			parent_name=name; parent_world=skeleton.global_transform*skeleton.get_bone_global_pose(index)
	return {"valid":true,"rotations":rotations,"dimensions":dimensions,"hand_in_weapon":hand_local,
		"hand_in_weapon_origin_id":Origins.ORIGIN_WEAPON_ROOT,
		"anatomy_signature":packet.anatomy_signature,"source_pose_id":packet.source_pose_id,
		"geometry_checks":geometry,"prepared_geometry_matches_live":matches_geometry,"grip_accepted":false}

func commit(slot: StringName, plan: Dictionary) -> void:
	var entry: Dictionary = states[slot]
	for key: String in ["rotations","dimensions","hand_in_weapon","hand_in_weapon_origin_id","anatomy_signature","source_pose_id","geometry_checks","prepared_geometry_matches_live"]: entry[key]=plan[key]
	entry.has_grip_pose=true; entry.status=&"planar_grip_pose_bound"

func _frame_valid(value: Transform3D) -> bool:
	return value.is_finite() and value.basis.determinant()>0.000000000001

func _fail(reason: String) -> Dictionary:
	return {"valid":false,"status":StringName(reason),"reason":reason,"grip_accepted":false}
