extends SceneTree

const Resolver = preload("res://core/resolvers/combat_grip_transition_resolver.gd")
const FingerPresenter = preload("res://runtime/player/player_rig_finger_grip_presenter.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ChainPlayer = preload("res://runtime/combat/combat_animation_chain_player.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const TOLERANCE: float = 0.00001
var checks: int = 0
var failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for slot: StringName in [&"hand_right", &"hand_left"]:
		for source_style: StringName in [&"grip_normal", &"grip_reverse"]:
			_test_flip(slot, source_style)
		_test_open_packet(slot)
	_test_prepared_finger_track()
	_test_entry_clock()
	_test_chain_midpoint()
	_test_invalid_input()
	print(JSON.stringify({"checks": checks, "failures": failures, "ok": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)


func _test_flip(slot: StringName, source_style: StringName) -> void:
	var destination_style: StringName = &"grip_reverse" if source_style == &"grip_normal" else &"grip_normal"
	var side: float = 1.0 if slot == &"hand_right" else -1.0
	var start_angle: float = 0.0 if source_style == &"grip_normal" else PI * side
	var change_angle: float = PI * side if source_style == &"grip_normal" else -PI * side
	var metric_scale := Vector3(0.8, 1.1, 1.3)
	var local_pivot := Vector3(0.23, -0.012, 0.008)
	var start_pivot := Vector3(3.0, 2.0, -4.0)
	var end_pivot := start_pivot + Vector3(-0.3, 0.15, 0.09)
	var source_basis: Basis = Basis(Vector3.FORWARD, -start_angle) * Basis.from_scale(metric_scale)
	var destination_basis: Basis = Basis(Vector3.FORWARD, -(start_angle + change_angle)) * Basis.from_scale(metric_scale)
	var source := Transform3D(source_basis, start_pivot - source_basis * local_pivot)
	var destination := Transform3D(destination_basis, end_pivot - destination_basis * local_pivot)
	var finger_name: StringName = &"CC_Base_R_Index1" if slot == &"hand_right" else &"CC_Base_L_Index1"
	var closed_from := Quaternion(Vector3.RIGHT, side * 0.9)
	var closed_to := Quaternion(Vector3.RIGHT, side * 0.7)
	var input := {
		"source_weapon": source, "destination_weapon": destination,
		"handle_pivot_local": local_pivot, "weapon_axis_local": Vector3.RIGHT,
		"source_hand": Transform3D(Basis.IDENTITY, start_pivot),
		"source_forearm": Transform3D(Basis.IDENTITY, start_pivot - Vector3.UP),
		"hand_slot": slot, "source_style": source_style, "destination_style": destination_style,
		"reference_origin_id": &"test_reference", "palm_normal": Vector3.BACK,
		"source_fingers": {finger_name: closed_from}, "open_fingers": {finger_name: Quaternion.IDENTITY},
		"destination_fingers": {finger_name: closed_to},
	}
	var plan: Dictionary = Resolver.create_plan(input)
	var label: String = "%s %s" % [slot, source_style]
	_check(plan.get("valid", false), label + " creates plan")
	if not plan.get("valid", false):
		return
	var expected_axis: Vector3 = Vector3.BACK * signf(change_angle)
	_check((plan.flip_axis as Vector3).distance_to(expected_axis) < TOLERANCE, label + " hand and reverse determine signed axis")
	for step: int in range(21):
		var progress: float = float(step) / 20.0
		# Explicit normalized progress has no acquisition or animation time limit.
		var result: Dictionary = Resolver.sample_plan(plan, 0.0, {
			"weapon_progress": progress, "opening_weight": 1.0, "closing_weight": 0.0})
		var actual: Transform3D = result.weapon_transform
		var expected_basis: Basis = Basis(Vector3.BACK, start_angle + change_angle * progress) * Basis.from_scale(metric_scale)
		var pivot: Vector3 = start_pivot.lerp(end_pivot, progress)
		_check(_basis_close(actual.basis, expected_basis), label + " analytic half-turn " + str(step))
		_check((actual * local_pivot).distance_to(pivot) < TOLERANCE, label + " handle station remains pivot " + str(step))
		_check(actual.basis.get_scale().distance_to(metric_scale) < TOLERANCE, label + " metric scale " + str(step))
	var midpoint: Dictionary = Resolver.sample_plan(plan, 0.0, {"weapon_progress": 0.5})
	_check(_frame_close(midpoint.weapon_transform, plan.midpoint_weapon), label + " explicit midpoint reached")
	var initial: Dictionary = Resolver.sample_plan(plan, 0.0)
	var opened: Dictionary = Resolver.sample_plan(plan, Resolver.OPEN_COMPLETE_RATIO)
	var overlap: Dictionary = Resolver.sample_plan(plan, 0.8)
	var final: Dictionary = Resolver.sample_plan(plan, 1.0)
	_check(_frame_close(initial.weapon_transform, source), label + " exact initial frame")
	_check(_frame_close(opened.weapon_transform, source), label + " open before weapon moves")
	_check((opened.finger_rotations[finger_name] as Quaternion).angle_to(Quaternion.IDENTITY) < TOLERANCE, label + " reaches open pose")
	_check(overlap.closing_weight > 0.0 and overlap.weapon_progress < 1.0, label + " closing overlaps movement")
	_check(_frame_close(final.weapon_transform, destination), label + " exact destination")
	_check((final.finger_rotations[finger_name] as Quaternion).angle_to(closed_to) < TOLERANCE, label + " closes to prepared destination")
	_check((input.source_fingers[finger_name] as Quaternion).angle_to(closed_from) < TOLERANCE, label + " immutable source packet")
	# Holding arbitrary progress is deterministic; no elapsed-time state is read.
	var hold_a: Dictionary = Resolver.sample_plan(plan, 0.2, {"weapon_progress": 0.5, "opening_weight": 1.0, "closing_weight": 0.0})
	var hold_b: Dictionary = Resolver.sample_plan(plan, 0.9, {"weapon_progress": 0.5, "opening_weight": 1.0, "closing_weight": 0.0})
	_check(_frame_close(hold_a.weapon_transform, hold_b.weapon_transform), label + " externally controlled phase can wait")


func _test_open_packet(slot: StringName) -> void:
	var presenter = FingerPresenter.new()
	var skeleton := Skeleton3D.new()
	root.add_child(skeleton)
	var hand_name: StringName = &"CC_Base_R_Hand" if slot == &"hand_right" else &"CC_Base_L_Hand"
	skeleton.add_bone(hand_name)
	skeleton.set_bone_pose_rotation(0, Quaternion(Vector3.UP, 0.35))
	var baseline := {}
	var expected := {}
	var current := {}
	var names: Array[StringName] = Rules.get_finger_bone_names(slot)
	for i: int in range(names.size()):
		var bone_name: StringName = names[i]
		skeleton.add_bone(bone_name)
		var bone_index: int = skeleton.find_bone(bone_name)
		var section: int = i % 3
		var parent_index: int = 0 if section == 0 else bone_index - 1
		skeleton.set_bone_parent(bone_index, parent_index)
		var open_local := Quaternion(Vector3.RIGHT, 0.05 * float(section + 1))
		var closed_local := Quaternion(Vector3.RIGHT, 0.75)
		skeleton.set_bone_pose_rotation(bone_index, closed_local)
		expected[bone_name] = open_local
		current[bone_name] = closed_local
		var parent_name: StringName = StringName(skeleton.get_bone_name(parent_index))
		var parent_relative: Quaternion = baseline.get(parent_name, Quaternion.IDENTITY)
		baseline[bone_name] = parent_relative * open_local
	skeleton.force_update_all_bone_transforms()
	var observed_before: Dictionary = {}
	for bone: StringName in names:
		observed_before[bone] = skeleton.get_bone_pose_rotation(skeleton.find_bone(bone))
	presenter.animation_idle_baseline_cache = {slot: {"rotations": baseline}}
	presenter.planar_grip_rotation_lookup = {slot: current.duplicate()}
	var packet: Dictionary = presenter.capture_default_open_finger_rotations(skeleton, slot)
	_check(packet.get("valid", false), String(slot) + " default open packet available despite closed ownership")
	if packet.get("valid", false):
		_check(packet.rotations.size() == 15, String(slot) + " full finger packet")
		for bone: StringName in names:
			_check((packet.rotations[bone] as Quaternion).angle_to(expected[bone]) < TOLERANCE, String(bone) + " hierarchy converted to parent local")
			_check(skeleton.get_bone_pose_rotation(skeleton.find_bone(bone)) == observed_before[bone], String(bone) + " read-only capture")
	skeleton.queue_free()


func _test_invalid_input() -> void:
	_check(not Resolver.create_plan({}).get("valid", false), "missing plan rejected")
	_check(not Resolver.sample_plan({}, 0.5).get("valid", false), "missing prepared plan rejected")
	_check(Resolver.sample_finger_rotations({&"a": Quaternion.IDENTITY}, {}, {}, 0.5).is_empty(), "incomplete open packet rejected")
	_check(not Resolver.is_style_swap(&"grip_normal", &"grip_normal"), "same grip does not open")


func _test_prepared_finger_track() -> void:
	var names: Array[StringName] = Rules.get_finger_bone_names(&"hand_right")
	names.append(&"CC_Base_R_Hand")
	var times := PackedFloat32Array()
	var frames: Array = []
	var opened := {}
	for name: StringName in names:
		if name != &"CC_Base_R_Hand":
			opened[name] = Quaternion.IDENTITY
	for step: int in range(21):
		times.append(float(step) / 10.0)
		var rotations := PackedVector4Array()
		for bone_index: int in range(names.size()):
			var rotation := Quaternion(Vector3.RIGHT, 0.8 if bone_index < 15 else 0.3)
			rotations.append(Vector4(rotation.x, rotation.y, rotation.z, rotation.w))
		frames.append(rotations)
	var original: Array = frames.duplicate(true)
	var result: Dictionary = Resolver.build_prepared_finger_track(times, names, frames,
		[{"start_time_seconds": 0.5, "end_time_seconds": 1.5, "hand_slot": &"hand_right"}],
		{&"hand_right": {"valid": true, "rotations": opened}})
	_check(result.get("valid", false), "prepared finger overlay succeeds")
	if not result.get("valid", false):
		return
	_check(frames == original, "prepared overlay leaves original rotations unchanged")
	_check(result.rotation_frames[5] == original[5] and result.rotation_frames[15] == original[15], "prepared closed endpoints retained")
	_check(result.rotation_frames[0] == original[0] and result.rotation_frames[20] == original[20], "outside flip interval unchanged")
	for step: int in range(21):
		_check(result.rotation_frames[step][15] == original[step][15], "hand/arm bones unchanged " + str(step))
	var open_value: Vector4 = result.rotation_frames[7][0]
	_check(Vector3(open_value.x, open_value.y, open_value.z).length() < TOLERANCE, "prepared finger opens during flip")
	var closing_value: Vector4 = result.rotation_frames[13][0]
	_check(closing_value.x > 0.0 and closing_value.x < original[13][0].x, "prepared finger closes before flip endpoint")


func _test_entry_clock() -> void:
	var clip = Clip.new()
	clip.total_duration_seconds = 1.16
	clip.baked_frame_times = PackedFloat32Array([0.0, 0.16, 1.16])
	clip.baked_tip_positions_local = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.RIGHT * 2.0])
	clip.baked_pommel_positions_local = PackedVector3Array([Vector3.DOWN, Vector3.RIGHT + Vector3.DOWN, Vector3.RIGHT * 2.0 + Vector3.DOWN])
	clip.set_meta("entry_duration_seconds", 0.16)
	for speed: float in [0.11, 1.0, 4.0]:
		var player = ChainPlayer.new()
		player.prepare_runtime_clip(clip, speed)
		player.start()
		player.advance(0.08)
		_check(absf(player.get("_clip_elapsed") - 0.08) < TOLERANCE, "entry wall time speed=" + str(speed))
		player.advance(0.10)
		_check(absf(player.get("_clip_elapsed") - (0.16 + 0.02 * speed)) < TOLERANCE, "boundary preserves excess time speed=" + str(speed))
		player.advance(2.0 / speed)
		_check(not player.is_playing(), "nonloop action terminates speed=" + str(speed))
		player.prepare_runtime_clip(clip, speed, true)
		player.start()
		player.advance(0.16)
		player.advance(1.25 / speed)
		_check(absf(player.get("_clip_elapsed") - 0.41) < TOLERANCE, "loop excludes entry speed=" + str(speed))
		player.start()
		_check(absf(player.get("_clip_elapsed")) < TOLERANCE, "explicit restart includes fresh entry")
	var single = Clip.new()
	single.total_duration_seconds = 0.16
	single.baked_frame_times = PackedFloat32Array([0.0, 0.16])
	single.set_meta("entry_duration_seconds", 0.16)
	var player = ChainPlayer.new()
	player.prepare_runtime_clip(single, 0.11, true)
	player.start()
	player.advance(0.5)
	_check(absf(player.get("_clip_elapsed") - 0.16) < TOLERANCE and player.is_playing(), "entry-only loop holds destination")


func _test_chain_midpoint() -> void:
	var source = MotionNode.new()
	source.tip_position_local = Vector3(1.0, 0.0, 0.0)
	source.pommel_position_local = Vector3(-0.3, 0.0, 0.0)
	source.preferred_grip_style_mode = &"grip_normal"
	source.weapon_orientation_authored = true
	var destination = source.duplicate_node()
	var pivot := Vector3(0.2, 0.0, 0.0)
	destination.tip_position_local = Vector3(-0.6, 0.0, 0.0)
	destination.pommel_position_local = Vector3(0.7, 0.0, 0.0)
	destination.preferred_grip_style_mode = &"grip_reverse"
	destination.generated_transition_node = true
	destination.generated_transition_kind = MotionNode.TRANSITION_KIND_GRIP_STYLE_SWAP
	destination.grip_style_transition_frame_available = true
	destination.grip_style_transition_pivot_local = pivot
	destination.grip_style_transition_axis_local = Vector3.BACK
	destination.grip_style_transition_source_tip_local = source.tip_position_local
	destination.grip_style_transition_source_pommel_local = source.pommel_position_local
	destination.grip_style_transition_origin_id = source.tip_position_origin_id
	destination.transition_duration_seconds = 2.0
	var player = ChainPlayer.new()
	player.prepare([source, destination], null, null)
	player.start()
	player.advance(1.0)
	_check(player.current_tip_position.distance_to(Vector3(0.2, 0.8, 0.0)) < TOLERANCE, "authored two-second flip reaches midpoint at one second")
	_check(player.current_pommel_position.distance_to(Vector3(0.2, -0.5, 0.0)) < TOLERANCE, "Pommel follows explicit midpoint")
	var up: Vector3 = Basis.from_euler(player.current_weapon_orientation_degrees * PI / 180.0) * Vector3.UP
	_check(up.distance_to(Vector3.LEFT) < TOLERANCE, "material up rotates with weapon independently of flip axis")
	_check(player.current_preferred_grip_style_mode == &"grip_normal", "source acquisition authority retained during prescribed flip")


func _basis_close(a: Basis, b: Basis) -> bool:
	return a.x.distance_to(b.x) < TOLERANCE and a.y.distance_to(b.y) < TOLERANCE and a.z.distance_to(b.z) < TOLERANCE


func _frame_close(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < TOLERANCE and _basis_close(a.basis, b.basis)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
