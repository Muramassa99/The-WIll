extends SceneTree

## Production transition/frame conversion with small scene fixtures. No body
## solver, saved library, or grip optimization is run by this focused proof.
const UI = preload("res://runtime/combat/combat_animation_station_ui.gd")
const Presenter = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const RuntimePlayback = preload("res://runtime/player/player_runtime_skill_playback_presenter.gd")
const Chain = preload("res://runtime/combat/combat_animation_chain_player.gd")
const Retarget = preload("res://core/resolvers/combat_animation_retarget_resolver.gd")
const Motion = preload("res://core/models/combat_animation_motion_node.gd")
const Draft = preload("res://core/models/combat_animation_draft.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")

class FixturePresenter extends Presenter:
	var context: Dictionary = {}
	func _weapon_roll_context(_viewport: SubViewport) -> Dictionary: return context

class FixtureUI extends UI:
	var fixture_draft: Resource
	func _get_active_draft() -> Resource: return fixture_draft
	func _apply_motion_node_change(_status: String, _persist: bool = true, _list: bool = true,
			_fields: bool = true, _preview: bool = true, _summary: bool = true, _reason: StringName = &"") -> void: pass
	func _reseat_motion_node_grip_to_occupied_contact(_motion: CombatAnimationMotionNode) -> bool: return false

var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _run() -> void:
	# Right is the reported failure. Left is an independent symmetry regression.
	for slot: StringName in [&"hand_right", &"hand_left"]:
		_case(slot)
	print(JSON.stringify({"checks": checks, "failures": failures,
		"scope": "rigid style flip, authored follow-on, and support eligibility"}))
	quit(0 if failures.is_empty() else 1)

func _case(slot: StringName) -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var weapon := Node3D.new()
	scene.add_child(weapon)
	var trajectory := Node3D.new()
	scene.add_child(trajectory)
	trajectory.transform = Transform3D(Basis.from_euler(Vector3(0.1,0.2,-0.1)),Vector3(0.3,-0.2,0.4))
	var original := Transform3D(Basis.from_euler(Vector3(0.25,0.55,-0.3)),Vector3(-0.2,0.5,0.1))
	if slot == &"hand_left": original.basis = Basis(Vector3.UP,0.6) * original.basis
	weapon.global_transform = original
	var tip := Vector3(0.07,0.02,0.7)
	var pommel := Vector3(0.07,0.02,-0.3)
	var span_start := Vector3(0.04,0.025,-0.2)
	var span_end := Vector3(0.06,0.03,0.1)
	for key: String in ["weapon_tip","weapon_pommel","primary_grip_contact","primary_grip_span_start","primary_grip_span_end"]:
		weapon.set_meta(key+"_origin_id",Origins.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("weapon_tip_local",tip)
	weapon.set_meta("weapon_pommel_local",pommel)
	weapon.set_meta("primary_grip_contact_local",span_start.lerp(span_end,0.5))
	weapon.set_meta("primary_grip_span_start_local",span_start)
	weapon.set_meta("primary_grip_span_end_local",span_end)
	weapon.set_meta("primary_grip_handle_tip_side_axis_ratio_from_span_start",1.0)
	weapon.set_meta("primary_grip_slice_axis_ratios_from_span_start",PackedFloat32Array([0.0,1.0]))
	weapon.set_meta("primary_grip_slice_centers_local",PackedVector3Array([span_start,span_end]))
	weapon.set_meta("primary_grip_slice_center_path_origin_id",Origins.ORIGIN_WEAPON_ROOT)
	weapon.set_meta("two_hand_character_eligible",true)
	var support := Node3D.new()
	support.name = "SupportGripAnchor"
	weapon.add_child(support)
	var presenter := FixturePresenter.new()
	presenter.context = {"weapon":weapon,"trajectory":trajectory}
	presenter.configure_preview_hand_setup(slot,false)
	var ui := FixtureUI.new()
	ui.preview_presenter = presenter
	ui.active_wip = Wip.new()
	Wip.apply_builder_path_defaults(ui.active_wip,Wip.BUILDER_PATH_MELEE,Wip.BUILDER_COMPONENT_PRIMARY)
	ui.active_preview_dominant_slot_id = slot
	ui.footer_status_label = Label.new()
	ui.add_child(ui.footer_status_label)
	var source := Motion.new()
	source.primary_hand_slot = slot
	source.grip_seat_coordinate_schema_version = Motion.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
	source.grip_seat_slide_offset = 0.73
	source.secondary_grip_seat_slide_offset = 0.22
	source.axial_reposition_offset = -0.12
	source.weapon_roll_degrees = 37.0
	source.weapon_orientation_degrees = Vector3(15,24,-18)
	source.weapon_orientation_authored = true
	source.preferred_grip_style_mode = Wip.GRIP_NORMAL
	source.two_hand_state = Motion.TWO_HAND_STATE_TWO_HAND
	# Authored request deliberately differs from the realized seated frame.
	source.tip_position_local = Vector3(4,5,6)
	source.pommel_position_local = Vector3(4,5,5)
	var draft := Draft.new()
	draft.draft_kind = Draft.DRAFT_KIND_SKILL
	draft.motion_node_chain.assign([source.duplicate_node(),source])
	draft.selected_motion_node_index = 1
	ui.fixture_draft = draft
	var station := span_start.lerp(span_end,0.73-0.12*0.5)
	var pivot := original * station
	_check(ui.set_selected_motion_node_preferred_grip_style(Wip.GRIP_REVERSE,false,false,false,false,false),String(slot)+": style swap inserts")
	_check(draft.motion_node_chain.size() == 4 and draft.selected_motion_node_index == 3,String(slot)+": editable follow-on selected after bridge")
	var bridge: Resource = draft.motion_node_chain[2]
	var follow: Resource = draft.motion_node_chain[3]
	_check(bridge.generated_transition_node and bridge.locked_for_authoring
		and bridge.generated_transition_kind == Motion.TRANSITION_KIND_GRIP_STYLE_SWAP,String(slot)+": generated bridge remains locked")
	_check(not follow.generated_transition_node and not follow.locked_for_authoring,String(slot)+": authored controls remain editable")
	_check(follow.primary_hand_slot == slot and follow.grip_seat_slide_offset == source.grip_seat_slide_offset
		and follow.secondary_grip_seat_slide_offset == source.secondary_grip_seat_slide_offset
		and follow.axial_reposition_offset == source.axial_reposition_offset,String(slot)+": both stations and primary hand retained")
	_check(follow.weapon_roll_degrees == 37.0 and bridge.weapon_roll_degrees == 37.0,String(slot)+": authored roll retained")
	var reversed := _decode(presenter,weapon,trajectory,follow)
	_check((reversed * station).distance_to(pivot) < 0.00001,String(slot)+": selected physical station is the flip pivot")
	_check((reversed.basis * Vector3.BACK).dot(original.basis * Vector3.BACK) < -0.99999,String(slot)+": weapon direction reverses")
	_check((reversed.basis * Vector3.UP).distance_to(original.basis * Vector3.UP) < 0.00001
		and reversed.basis.determinant() > 0.99999,String(slot)+": rigid flip retains up axis without reflection")
	_check(weapon.global_transform == original and source.tip_position_local == Vector3(4,5,6),String(slot)+": seed conversion does not write scene/source pose")
	_verify_arc(presenter,weapon,trajectory,source,bridge,follow,station,pivot,original,slot)
	_check(ui._motion_node_uses_two_hand(follow) and presenter._should_preview_use_support_hand(weapon,follow),String(slot)+": reverse retains eligible requested support")
	var runtime := RuntimePlayback.new()
	var support_slot: StringName = &"hand_left" if slot == &"hand_right" else &"hand_right"
	_check(runtime._resolve_support_hand_requested_from_values(weapon,{},support_slot,false,
		Wip.GRIP_REVERSE,Motion.TWO_HAND_STATE_TWO_HAND),String(slot)+": equipped reverse accepts eligible free support")
	_check(not runtime._resolve_support_hand_requested_from_values(weapon,{support_slot:support},support_slot,true,
		Wip.GRIP_REVERSE,Motion.TWO_HAND_STATE_TWO_HAND),String(slot)+": equipped occupied support remains unavailable")
	_check(not runtime._resolve_support_hand_requested_from_values(weapon,{},&"",true,
		Wip.GRIP_REVERSE,Motion.TWO_HAND_STATE_TWO_HAND),String(slot)+": equipped missing support slot remains unavailable")
	weapon.set_meta("two_hand_character_eligible",false)
	_check(not presenter._should_preview_use_support_hand(weapon,follow),String(slot)+": anatomical eligibility still enforced")
	_check(not runtime._resolve_support_hand_requested_from_values(weapon,{},support_slot,true,
		Wip.GRIP_REVERSE,Motion.TWO_HAND_STATE_TWO_HAND),String(slot)+": equipped anatomical eligibility still enforced")
	weapon.set_meta("two_hand_character_eligible",true)
	follow.two_hand_state = Motion.TWO_HAND_STATE_ONE_HAND
	_check(not ui._motion_node_uses_two_hand(follow) and not presenter._should_preview_use_support_hand(weapon,follow),String(slot)+": explicit one-hand choice still enforced")
	_check(not runtime._resolve_support_hand_requested_from_values(weapon,{},support_slot,true,
		Wip.GRIP_REVERSE,Motion.TWO_HAND_STATE_ONE_HAND),String(slot)+": equipped explicit one-hand choice still enforced")
	follow.two_hand_state = Motion.TWO_HAND_STATE_TWO_HAND
	weapon.global_transform = reversed
	_check(ui.set_selected_motion_node_preferred_grip_style(Wip.GRIP_NORMAL,false,false,false,false,false),String(slot)+": return style swap inserts")
	var returned: Resource = ui._get_active_motion_node()
	var restored := _decode(presenter,weapon,trajectory,returned)
	_check(restored.is_equal_approx(original) and (restored * station).distance_to(pivot) < 0.00001,String(slot)+": normal/reverse/normal roundtrip preserves seated frame")
	_check(ui.set_selected_motion_node_grip_seat_slide(0.61,false,false,false,false,false),String(slot)+": follow-on accepts handle percentage edits")
	draft.selected_motion_node_index = 2
	_check(not ui.set_selected_motion_node_grip_seat_slide(0.51,false,false,false,false,false),String(slot)+": generated bridge still rejects station edits")
	_check(ui._can_author_motion_node_curve_handles(bridge),String(slot)+": bridge curve handles stay editable")
	ui.free()
	scene.free()

func _verify_arc(presenter: RefCounted, weapon: Node3D, trajectory: Node3D,
		source: Resource, bridge: Resource, follow: Resource, station: Vector3,
		pivot: Vector3, original: Transform3D, slot: StringName) -> void:
	var chain := Chain.new()
	chain.motion_node_chain = [source,bridge]
	var fixed_station := true
	var rigid_length := true
	var continuous := true
	var exact_endpoints := true
	var previous := original
	var maximum_step := 0.0
	for index: int in range(21):
		chain._interpolate_between_nodes(0,1,float(index)/20.0)
		var sampled: Resource = bridge.duplicate_node()
		sampled.tip_position_local = chain.current_tip_position
		sampled.pommel_position_local = chain.current_pommel_position
		sampled.weapon_orientation_degrees = chain.current_weapon_orientation_degrees
		sampled.weapon_roll_degrees = chain.current_weapon_roll
		var frame := _decode(presenter,weapon,trajectory,sampled)
		fixed_station = fixed_station and (frame * station).distance_to(pivot) < 0.00005
		rigid_length = rigid_length and absf(chain.current_tip_position.distance_to(chain.current_pommel_position)-1.0) < 0.00005
		var step := previous.basis.get_rotation_quaternion().angle_to(frame.basis.get_rotation_quaternion())
		maximum_step = maxf(maximum_step,step)
		continuous = continuous and step <= PI/20.0+0.001
		if index == 0: exact_endpoints = exact_endpoints and frame.is_equal_approx(original)
		if index == 20: exact_endpoints = exact_endpoints and frame.is_equal_approx(_decode(presenter,weapon,trajectory,bridge))
		previous = frame
	_check(bridge.has_valid_grip_style_transition_frame() and not follow.grip_style_transition_frame_available,String(slot)+": only generated bridge owns realized source frame")
	_check(fixed_station,String(slot)+": every reversal sample retains off-axis selected station")
	_check(rigid_length,String(slot)+": every reversal sample retains rigid weapon length")
	_check(continuous,String(slot)+": reversal has no zero-axis midpoint jump (max %.4f deg)" % rad_to_deg(maximum_step))
	_check(exact_endpoints,String(slot)+": arc starts at actual source and ends at exact target frame")
	var custom: Resource = bridge.duplicate_node()
	custom.tip_curve_in_handle = Vector3(0.03,0.07,-0.01)
	_check(chain._resolve_unshaped_grip_swap_arc(source,custom,0.5).is_empty(),String(slot)+": explicit Bezier shaping retains existing path policy")
	var legacy_source: Resource = source.duplicate_node()
	var encoded: Dictionary = presenter.weapon_frame_solver.encode_transform_for_authoring(original,
		weapon.get_meta("weapon_tip_local"),weapon.get_meta("weapon_pommel_local"),Vector3.UP,
		trajectory.global_transform,source.weapon_roll_degrees)
	legacy_source.tip_position_local = encoded.tip_position_local
	legacy_source.pommel_position_local = encoded.pommel_position_local
	legacy_source.weapon_orientation_degrees = encoded.weapon_orientation_degrees
	var legacy_bridge: Resource = bridge.duplicate_node()
	legacy_bridge.clear_grip_style_transition_frame()
	# A legacy off-axis station is unknowable; this tests its original inferred
	# on-segment pivot rather than pretending it preserves the new captured seat.
	var legacy_pivot: Vector3 = legacy_source.pommel_position_local.lerp(legacy_source.tip_position_local,0.3)
	var legacy_axis: Vector3 = trajectory.global_basis.inverse() * (original.basis * Vector3.UP)
	legacy_bridge.tip_position_local = legacy_pivot + Basis(legacy_axis.normalized(),PI) * (legacy_source.tip_position_local-legacy_pivot)
	legacy_bridge.pommel_position_local = legacy_pivot + Basis(legacy_axis.normalized(),PI) * (legacy_source.pommel_position_local-legacy_pivot)
	_check(not chain._resolve_unshaped_grip_swap_arc(legacy_source,legacy_bridge,0.5).is_empty(),String(slot)+": compatible legacy half-turn gets continuous inferred arc")
	var retargeted: Resource = bridge.duplicate_node()
	var resolver := Retarget.new()
	var intent: Resource = resolver.build_retarget_node_from_legacy_motion_node(retargeted)
	_check(resolver.apply_retarget_node_to_motion_node(retargeted,intent,1.2)
		and retargeted.has_valid_grip_style_transition_frame(),String(slot)+": length retarget transports pivot and source frame")
	var invalid: Resource = bridge.duplicate_node()
	invalid.grip_style_transition_axis_local = Vector3.ZERO
	invalid.normalize()
	_check(not invalid.grip_style_transition_frame_available,String(slot)+": invalid captured transition metadata is cleared")

func _decode(presenter: RefCounted, weapon: Node3D, trajectory: Node3D, motion: Resource) -> Transform3D:
	return presenter._solve_weapon_segment_transform(weapon,trajectory,motion,
		weapon.get_meta("weapon_tip_local"),weapon.get_meta("weapon_pommel_local"),
		trajectory.to_global(motion.tip_position_local),trajectory.to_global(motion.pommel_position_local),
		motion.weapon_orientation_degrees)
