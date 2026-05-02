extends Resource
class_name CombatAnimationDraft

const DRAFT_KIND_SKILL: StringName = &"draft_skill"
const DRAFT_KIND_IDLE: StringName = &"draft_idle"
const IDLE_CONTEXT_COMBAT: StringName = &"idle_combat"
const IDLE_CONTEXT_NONCOMBAT: StringName = &"idle_noncombat"
const STOW_ANCHOR_SHOULDER_HANGING: StringName = &"stow_shoulder_hanging"
const STOW_ANCHOR_SIDE_HIP: StringName = &"stow_side_hip"
const STOW_ANCHOR_LOWER_BACK: StringName = &"stow_lower_back"
const LEGACY_SKILL_NODE_0_TIP := Vector3.ZERO
const LEGACY_SKILL_NODE_0_POMMEL := Vector3.ZERO
const LEGACY_SKILL_NODE_0_TIP_CURVE_OUT := Vector3(0.0, 0.0, -0.04)
const LEGACY_SKILL_NODE_1_TIP := Vector3(0.0, 0.0, -0.12)
const LEGACY_SKILL_NODE_1_POMMEL := Vector3(0.0, 0.0, -0.12)
const LEGACY_SKILL_NODE_1_TIP_CURVE_IN := Vector3(0.0, 0.0, 0.04)
const LEGACY_BASELINE_EPSILON := 0.0001
const DEFAULT_NODE_TRANSITION_DURATION_SECONDS := 0.18
const DEFAULT_SPEED_ACCELERATION_PERCENT := 35.0
const DEFAULT_SPEED_DECELERATION_PERCENT := 35.0

@export var draft_id: StringName = &""
@export var display_name: String = ""
@export var draft_kind: StringName = DRAFT_KIND_SKILL
@export var context_id: StringName = StringName()
@export var owning_skill_id: StringName = &""
@export var legal_slot_id: StringName = &""
@export var preferred_grip_style_mode: StringName = &"grip_normal"
@export var stow_anchor_mode: StringName = STOW_ANCHOR_SHOULDER_HANGING
@export var authored_for_two_hand_only: bool = false
@export var motion_node_chain: Array[Resource] = []
@export var selected_motion_node_index: int = 0
@export var continuity_motion_node_index: int = 0
@export_range(0.0, 3.0, 0.01) var preview_playback_speed_scale: float = 1.0
@export var preview_loop_enabled: bool = false
@export_range(0.0, 100.0, 1.0) var speed_acceleration_percent: float = DEFAULT_SPEED_ACCELERATION_PERCENT
@export_range(0.0, 100.0, 1.0) var speed_deceleration_percent: float = DEFAULT_SPEED_DECELERATION_PERCENT
@export var skill_name: String = ""
@export var skill_icon: Texture2D
@export var skill_description: String = ""
@export_multiline var draft_notes: String = ""

static func get_draft_kind_ids() -> Array[StringName]:
	return [
		DRAFT_KIND_SKILL,
		DRAFT_KIND_IDLE,
	]

static func get_idle_context_ids() -> Array[StringName]:
	return [
		IDLE_CONTEXT_COMBAT,
		IDLE_CONTEXT_NONCOMBAT,
	]

static func get_stow_anchor_mode_ids() -> Array[StringName]:
	return [
		STOW_ANCHOR_SHOULDER_HANGING,
		STOW_ANCHOR_SIDE_HIP,
		STOW_ANCHOR_LOWER_BACK,
	]

static func normalize_stow_anchor_mode(stow_mode: StringName) -> StringName:
	if get_stow_anchor_mode_ids().has(stow_mode):
		return stow_mode
	return STOW_ANCHOR_SHOULDER_HANGING

static func create_default_skill_baseline(
	draft_id_value: StringName,
	display_name_value: String,
	skill_id: StringName,
	slot_id: StringName = StringName()
):
	var self_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft = self_script.new() if self_script != null else null
	if draft == null:
		return null
	draft.draft_id = draft_id_value
	draft.display_name = display_name_value
	draft.draft_kind = DRAFT_KIND_SKILL
	draft.owning_skill_id = skill_id
	draft.legal_slot_id = slot_id
	draft.motion_node_chain = [
		_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -0.04)),
		_build_default_motion_node(1, Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, 0.04), Vector3.ZERO),
	]
	draft.normalize()
	return draft

static func create_default_idle_baseline(
	draft_id_value: StringName,
	display_name_value: String,
	idle_context_id: StringName
):
	var self_script: Script = load("res://core/models/combat_animation_draft.gd") as Script
	var draft = self_script.new() if self_script != null else null
	if draft == null:
		return null
	draft.draft_id = draft_id_value
	draft.display_name = display_name_value
	draft.draft_kind = DRAFT_KIND_IDLE
	draft.context_id = idle_context_id
	draft.preview_loop_enabled = true
	draft.motion_node_chain = [
		_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO),
	]
	draft.normalize()
	return draft

static func _build_default_motion_node(
	index: int,
	tip_position: Vector3,
	pommel_position: Vector3,
	tip_curve_in: Vector3 = Vector3.ZERO,
	tip_curve_out: Vector3 = Vector3.ZERO
):
	var node_script: Script = load("res://core/models/combat_animation_motion_node.gd") as Script
	var motion_node = node_script.new() if node_script != null else null
	if motion_node == null:
		return null
	motion_node.node_index = index
	motion_node.node_id = StringName("motion_node_%02d" % index)
	motion_node.tip_position_local = tip_position
	motion_node.pommel_position_local = pommel_position
	motion_node.tip_curve_in_handle = tip_curve_in
	motion_node.tip_curve_out_handle = tip_curve_out
	motion_node.normalize()
	return motion_node

func normalize() -> void:
	if not get_draft_kind_ids().has(draft_kind):
		draft_kind = DRAFT_KIND_SKILL
	if draft_kind == DRAFT_KIND_IDLE and not get_idle_context_ids().has(context_id):
		context_id = IDLE_CONTEXT_COMBAT
	stow_anchor_mode = normalize_stow_anchor_mode(stow_anchor_mode)
	if preview_playback_speed_scale <= 0.0:
		preview_playback_speed_scale = 1.0
	speed_acceleration_percent = clampf(speed_acceleration_percent, 0.0, 100.0)
	speed_deceleration_percent = clampf(speed_deceleration_percent, 0.0, 100.0)
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: Resource = motion_node_chain[node_index]
		if motion_node == null:
			var node_script: Script = load("res://core/models/combat_animation_motion_node.gd") as Script
			motion_node = node_script.new() if node_script != null else null
			if motion_node == null:
				continue
			motion_node_chain[node_index] = motion_node
		motion_node.set("node_index", node_index)
		if motion_node.has_method("normalize"):
			motion_node.call("normalize")
	if draft_kind == DRAFT_KIND_IDLE and motion_node_chain.size() > 1:
		motion_node_chain = [motion_node_chain[0]]
		var idle_motion_node: Resource = motion_node_chain[0]
		if idle_motion_node != null:
			idle_motion_node.set("node_index", 0)
			if idle_motion_node.has_method("normalize"):
				idle_motion_node.call("normalize")
	selected_motion_node_index = clampi(selected_motion_node_index, 0, maxi(motion_node_chain.size() - 1, 0))
	continuity_motion_node_index = clampi(continuity_motion_node_index, 0, maxi(motion_node_chain.size() - 1, 0))

func ensure_minimum_baseline_nodes() -> void:
	if not motion_node_chain.is_empty():
		normalize()
		return
	if draft_kind == DRAFT_KIND_IDLE:
		motion_node_chain = [_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO)]
	else:
		motion_node_chain = [
			_build_default_motion_node(0, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -0.04)),
			_build_default_motion_node(1, Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, -0.12), Vector3(0.0, 0.0, 0.04), Vector3.ZERO),
		]
	normalize()

func needs_weapon_geometry_seed() -> bool:
	if motion_node_chain.is_empty():
		return true
	var minimum_node_count: int = 1 if draft_kind == DRAFT_KIND_IDLE else 2
	if motion_node_chain.size() != minimum_node_count:
		return false
	if draft_kind == DRAFT_KIND_IDLE:
		return _matches_zero_node(motion_node_chain[0] as CombatAnimationMotionNode)
	if motion_node_chain.size() < 2:
		return true
	return (
		(
			_matches_zero_node(motion_node_chain[0] as CombatAnimationMotionNode)
			and _matches_zero_node(motion_node_chain[1] as CombatAnimationMotionNode)
		)
		or _matches_legacy_skill_baseline()
	)

func apply_weapon_geometry_seed(seed_data: Dictionary, force_reseed: bool = false) -> bool:
	if seed_data.is_empty():
		return false
	if not force_reseed and not needs_weapon_geometry_seed():
		return false
	var tip_position: Vector3 = seed_data.get("tip_position_local", Vector3.ZERO) as Vector3
	var pommel_position: Vector3 = seed_data.get("pommel_position_local", Vector3.ZERO) as Vector3
	var weapon_orientation_degrees: Vector3 = seed_data.get("weapon_orientation_degrees", Vector3.ZERO) as Vector3
	var weapon_orientation_authored: bool = bool(seed_data.get("weapon_orientation_authored", false))
	var weapon_roll_degrees: float = float(seed_data.get("weapon_roll_degrees", 0.0))
	var axial_reposition_offset: float = float(seed_data.get("axial_reposition_offset", 0.0))
	var grip_seat_slide_offset: float = float(seed_data.get("grip_seat_slide_offset", 0.0))
	var body_support_blend: float = clampf(float(seed_data.get("body_support_blend", 0.0)), 0.0, 1.0)
	var preferred_grip_mode: StringName = StringName(seed_data.get("preferred_grip_style_mode", preferred_grip_style_mode))
	var node_two_hand_state: StringName = StringName(seed_data.get("two_hand_state", CombatAnimationMotionNode.TWO_HAND_STATE_AUTO))
	var node_primary_hand_slot: StringName = CombatAnimationMotionNode.normalize_primary_hand_slot(StringName(seed_data.get(
		"primary_hand_slot",
		CombatAnimationMotionNode.PRIMARY_HAND_AUTO
	)))
	var authored_two_hand_only: bool = bool(seed_data.get("authored_for_two_hand_only", false))
	var baseline_count: int = 1 if draft_kind == DRAFT_KIND_IDLE else 2
	preferred_grip_style_mode = preferred_grip_mode
	authored_for_two_hand_only = authored_two_hand_only
	motion_node_chain.clear()
	for node_index: int in range(baseline_count):
		var motion_node = _build_default_motion_node(node_index, tip_position, pommel_position)
		if motion_node == null:
			continue
		motion_node.weapon_orientation_degrees = weapon_orientation_degrees
		motion_node.weapon_orientation_authored = weapon_orientation_authored
		motion_node.weapon_roll_degrees = weapon_roll_degrees
		motion_node.axial_reposition_offset = axial_reposition_offset
		motion_node.grip_seat_slide_offset = grip_seat_slide_offset
		motion_node.body_support_blend = body_support_blend
		motion_node.tip_curve_in_handle = Vector3.ZERO
		motion_node.tip_curve_out_handle = Vector3.ZERO
		motion_node.pommel_curve_in_handle = Vector3.ZERO
		motion_node.pommel_curve_out_handle = Vector3.ZERO
		motion_node.preferred_grip_style_mode = preferred_grip_mode
		motion_node.two_hand_state = node_two_hand_state
		motion_node.primary_hand_slot = node_primary_hand_slot
		motion_node.normalize()
		motion_node_chain.append(motion_node)
	selected_motion_node_index = 0
	continuity_motion_node_index = 0
	normalize()
	return not motion_node_chain.is_empty()

func reset_authoring_baseline(seed_data: Dictionary = {}) -> bool:
	selected_motion_node_index = 0
	continuity_motion_node_index = 0
	preview_playback_speed_scale = 1.0
	speed_acceleration_percent = DEFAULT_SPEED_ACCELERATION_PERCENT
	speed_deceleration_percent = DEFAULT_SPEED_DECELERATION_PERCENT
	preview_loop_enabled = draft_kind == DRAFT_KIND_IDLE
	if not seed_data.is_empty() and apply_weapon_geometry_seed(seed_data, true):
		normalize()
		return true
	return reset_to_default_baseline()

func reset_to_default_baseline() -> bool:
	motion_node_chain.clear()
	selected_motion_node_index = 0
	continuity_motion_node_index = 0
	preview_playback_speed_scale = 1.0
	speed_acceleration_percent = DEFAULT_SPEED_ACCELERATION_PERCENT
	speed_deceleration_percent = DEFAULT_SPEED_DECELERATION_PERCENT
	preview_loop_enabled = draft_kind == DRAFT_KIND_IDLE
	ensure_minimum_baseline_nodes()
	normalize()
	return not motion_node_chain.is_empty()

func get_motion_node_count() -> int:
	return motion_node_chain.size()

func get_motion_node_timestamps() -> Array[float]:
	var timestamps: Array[float] = []
	var elapsed_seconds: float = 0.0
	for node_index: int in range(motion_node_chain.size()):
		if node_index > 0:
			var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
			elapsed_seconds += _get_motion_node_transition_duration(motion_node)
		timestamps.append(elapsed_seconds)
	return timestamps

func get_total_transition_duration_seconds() -> float:
	var timestamps: Array[float] = get_motion_node_timestamps()
	if timestamps.is_empty():
		return 0.0
	return float(timestamps[timestamps.size() - 1])

func insert_motion_node_after_selected(motion_node: CombatAnimationMotionNode) -> Dictionary:
	var result: Dictionary = {
		"inserted": false,
		"inserted_index": -1,
		"timeline_shift_seconds": 0.0,
	}
	if motion_node == null:
		return result
	if draft_kind == DRAFT_KIND_IDLE:
		normalize()
		return result
	if motion_node_chain.is_empty():
		ensure_minimum_baseline_nodes()
	if motion_node_chain.is_empty():
		return result
	var insert_after_index: int = clampi(selected_motion_node_index, 0, motion_node_chain.size() - 1)
	var insert_index: int = insert_after_index + 1
	motion_node_chain.insert(insert_index, motion_node)
	selected_motion_node_index = insert_index
	if continuity_motion_node_index >= insert_index:
		continuity_motion_node_index += 1
	normalize()
	result.inserted = true
	result.inserted_index = insert_index
	result.timeline_shift_seconds = _get_motion_node_transition_duration(motion_node)
	return result

func remove_selected_motion_node_ripple(minimum_node_count: int = 1) -> Dictionary:
	var result: Dictionary = {
		"removed": false,
		"removed_index": -1,
		"selected_index": selected_motion_node_index,
		"continuity_index": continuity_motion_node_index,
		"timeline_shift_seconds": 0.0,
	}
	if motion_node_chain.size() <= minimum_node_count:
		return result
	var remove_index: int = clampi(selected_motion_node_index, 0, motion_node_chain.size() - 1)
	var removed_node: CombatAnimationMotionNode = motion_node_chain[remove_index] as CombatAnimationMotionNode
	result.timeline_shift_seconds = _get_motion_node_transition_duration(removed_node)
	motion_node_chain.remove_at(remove_index)
	if motion_node_chain.is_empty():
		selected_motion_node_index = 0
		continuity_motion_node_index = 0
	else:
		selected_motion_node_index = clampi(remove_index, 0, motion_node_chain.size() - 1)
		if continuity_motion_node_index > remove_index:
			continuity_motion_node_index -= 1
		elif continuity_motion_node_index == remove_index:
			continuity_motion_node_index = clampi(remove_index, 0, motion_node_chain.size() - 1)
	normalize()
	result.removed = true
	result.removed_index = remove_index
	result.selected_index = selected_motion_node_index
	result.continuity_index = continuity_motion_node_index
	return result

func duplicate_draft():
	return duplicate(true)

func is_publishable_skill_draft() -> bool:
	if draft_kind != DRAFT_KIND_SKILL:
		return false
	if not String(skill_name).strip_edges().is_empty():
		return true
	if not String(skill_description).strip_edges().is_empty():
		return true
	if not String(draft_notes).strip_edges().is_empty():
		return true
	if _matches_legacy_skill_baseline():
		return false
	if motion_node_chain.size() != 2:
		return motion_node_chain.size() >= 2
	var node_0: CombatAnimationMotionNode = motion_node_chain[0] as CombatAnimationMotionNode
	var node_1: CombatAnimationMotionNode = motion_node_chain[1] as CombatAnimationMotionNode
	if node_0 == null or node_1 == null:
		return false
	return not _matches_clean_skill_seed_pair(node_0, node_1)

func _get_motion_node_transition_duration(motion_node: CombatAnimationMotionNode) -> float:
	if motion_node == null:
		return 0.0
	return maxf(motion_node.transition_duration_seconds, 0.0)

func _matches_zero_node(motion_node: CombatAnimationMotionNode) -> bool:
	if motion_node == null:
		return false
	return (
		motion_node.tip_position_local.is_zero_approx()
		and motion_node.pommel_position_local.is_zero_approx()
		and motion_node.tip_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and motion_node.tip_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and motion_node.pommel_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and motion_node.pommel_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
	)

func _matches_legacy_skill_baseline() -> bool:
	if draft_kind != DRAFT_KIND_SKILL or motion_node_chain.size() != 2:
		return false
	var node_0: CombatAnimationMotionNode = motion_node_chain[0] as CombatAnimationMotionNode
	var node_1: CombatAnimationMotionNode = motion_node_chain[1] as CombatAnimationMotionNode
	if node_0 == null or node_1 == null:
		return false
	return (
		node_0.tip_position_local.is_equal_approx(LEGACY_SKILL_NODE_0_TIP)
		and node_0.pommel_position_local.is_equal_approx(LEGACY_SKILL_NODE_0_POMMEL)
		and node_0.tip_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_0.tip_curve_out_handle.is_equal_approx(LEGACY_SKILL_NODE_0_TIP_CURVE_OUT)
		and node_0.pommel_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_0.pommel_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.tip_position_local.is_equal_approx(LEGACY_SKILL_NODE_1_TIP)
		and node_1.pommel_position_local.is_equal_approx(LEGACY_SKILL_NODE_1_POMMEL)
		and node_1.tip_curve_in_handle.is_equal_approx(LEGACY_SKILL_NODE_1_TIP_CURVE_IN)
		and node_1.tip_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.pommel_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.pommel_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
	)

func _matches_clean_skill_seed_pair(node_0: CombatAnimationMotionNode, node_1: CombatAnimationMotionNode) -> bool:
	if node_0 == null or node_1 == null:
		return false
	return (
		node_0.tip_position_local.is_equal_approx(node_1.tip_position_local)
		and node_0.pommel_position_local.is_equal_approx(node_1.pommel_position_local)
		and node_0.tip_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_0.tip_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_0.pommel_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_0.pommel_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.tip_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.tip_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.pommel_curve_in_handle.length() <= LEGACY_BASELINE_EPSILON
		and node_1.pommel_curve_out_handle.length() <= LEGACY_BASELINE_EPSILON
		and absf(node_0.weapon_roll_degrees) <= LEGACY_BASELINE_EPSILON
		and absf(node_1.weapon_roll_degrees) <= LEGACY_BASELINE_EPSILON
		and absf(node_0.axial_reposition_offset) <= LEGACY_BASELINE_EPSILON
		and absf(node_1.axial_reposition_offset) <= LEGACY_BASELINE_EPSILON
		and absf(node_0.grip_seat_slide_offset) <= LEGACY_BASELINE_EPSILON
		and absf(node_1.grip_seat_slide_offset) <= LEGACY_BASELINE_EPSILON
		and absf(node_0.body_support_blend) <= LEGACY_BASELINE_EPSILON
		and absf(node_1.body_support_blend) <= LEGACY_BASELINE_EPSILON
		and node_0.two_hand_state == CombatAnimationMotionNode.TWO_HAND_STATE_AUTO
		and node_1.two_hand_state == CombatAnimationMotionNode.TWO_HAND_STATE_AUTO
		and node_0.primary_hand_slot == CombatAnimationMotionNode.PRIMARY_HAND_AUTO
		and node_1.primary_hand_slot == CombatAnimationMotionNode.PRIMARY_HAND_AUTO
		and node_0.preferred_grip_style_mode == &"grip_normal"
		and node_1.preferred_grip_style_mode == &"grip_normal"
		and absf(node_0.transition_duration_seconds - DEFAULT_NODE_TRANSITION_DURATION_SECONDS) <= LEGACY_BASELINE_EPSILON
		and absf(node_1.transition_duration_seconds - DEFAULT_NODE_TRANSITION_DURATION_SECONDS) <= LEGACY_BASELINE_EPSILON
	)
