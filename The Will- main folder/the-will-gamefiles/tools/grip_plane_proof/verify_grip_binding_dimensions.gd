extends SceneTree

## Real Skeleton3D transforms exercise the cached-packet preflight. This checks
## geometry ownership, not visual grip quality or the surface optimizer.
const Binding = preload("res://runtime/player/grip/hand_grip_pose_binding.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _poses(skeleton: Skeleton3D) -> PackedByteArray:
	var out: Array[Transform3D] = []
	for index: int in skeleton.get_bone_count(): out.append(skeleton.get_bone_pose(index))
	return var_to_bytes(out)

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var weapon := Node3D.new()
	scene.add_child(weapon)
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var skeleton := Skeleton3D.new()
		scene.add_child(skeleton)
		var hand_name := &"CC_Base_R_Hand" if slot == &"hand_right" else &"CC_Base_L_Hand"
		var hand_index := skeleton.add_bone(hand_name)
		var packet := {"hand_in_weapon":Transform3D.IDENTITY,
			"hand_in_weapon_origin_id":Origins.ORIGIN_WEAPON_ROOT,
			"anatomy_signature":"dimension_fixture", "source_pose_id":&"dimension_fixture",
			"digit_states":{}}
		for digit: StringName in Binding.DIGITS:
			var rules := Rules.get_chain_rules(slot, digit)
			var snapshot := {"bone_names":[], "relative_transforms":[], "neutral_local_rotations":[],
				"hinge_axes_local":[], "min_angles_rad":[], "max_angles_rad":[],
				"relative_transform_origin_ids":[], "neutral_local_rotation_origin_ids":[], "hinge_axis_origin_ids":[]}
			var angles: Array[float] = []
			var parent := hand_index
			for joint: int in 3:
				var name: StringName = rules[joint].bone
				var index := skeleton.add_bone(name)
				skeleton.set_bone_parent(index, parent)
				var relative := Transform3D(Basis.IDENTITY, Vector3(0, 0.02 + joint * 0.003, 0))
				skeleton.set_bone_pose(index, relative)
				snapshot.bone_names.append(name)
				snapshot.relative_transforms.append(relative)
				snapshot.neutral_local_rotations.append(Quaternion.IDENTITY)
				snapshot.hinge_axes_local.append(Rules.HINGE_AXIS_LOCAL)
				var low := deg_to_rad(minf(rules[joint].open_degrees, rules[joint].closed_degrees))
				var high := deg_to_rad(maxf(rules[joint].open_degrees, rules[joint].closed_degrees))
				snapshot.min_angles_rad.append(low)
				snapshot.max_angles_rad.append(high)
				for field: String in ["relative_transform_origin_ids", "neutral_local_rotation_origin_ids", "hinge_axis_origin_ids"]:
					snapshot[field].append(name)
				angles.append((low + high) * 0.5)
				parent = index
			packet.digit_states[digit] = {"digit":{"slot_id":slot, "digit_id":digit, "hand_bone_name":hand_name},
				"snapshot":snapshot, "angles_rad":angles}
		var binding := Binding.new()
		_check(binding.claim(skeleton, slot, weapon, "fixed_key").valid, "claim all digit bones " + String(slot))
		var ready := binding.prepare(skeleton, slot, weapon, "fixed_key", packet)
		_check(ready.valid and ready.prepared_geometry_matches_live, "matching dimensions are accepted " + String(slot))
		if ready.valid: binding.commit(slot, ready)
		var committed := var_to_bytes(binding.state(slot))
		var middle: Array = Rules.get_chain_rules(slot, &"middle")
		var changed_index := skeleton.find_bone(middle[1].bone)
		var original := skeleton.get_bone_pose(changed_index)
		for change: String in ["position", "scale"]:
			if change == "position": skeleton.set_bone_pose_position(changed_index, original.origin + Vector3(0.002, 0, 0))
			else: skeleton.set_bone_pose_scale(changed_index, Vector3(1.02, 1, 1))
			var before := _poses(skeleton)
			var rejected := binding.prepare(skeleton, slot, weapon, "fixed_key", packet)
			var label := String(slot) + " " + change
			_check(not rejected.valid and rejected.reason == "prepared_digit_dimensions_changed", "changed dimensions rejected " + label)
			_check(not rejected.prepared_geometry_matches_live, "mismatch diagnostics retained " + label)
			_check(_poses(skeleton) == before, "rejection leaves every bone unchanged " + label)
			_check(var_to_bytes(binding.state(slot)) == committed, "rejection leaves committed packet unchanged " + label)
			skeleton.set_bone_pose(changed_index, original)
		_check(binding.prepare(skeleton, slot, weapon, "fixed_key", packet).valid, "restored dimensions remain reusable " + String(slot))
		skeleton.free()
	scene.free()
	print(JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
