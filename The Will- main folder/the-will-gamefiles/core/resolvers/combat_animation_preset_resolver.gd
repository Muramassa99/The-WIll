extends RefCounted
class_name CombatAnimationPresetResolver

const CombatAnimationPresetRecipeScript = preload("res://core/models/combat_animation_preset_recipe.gd")
const CombatAnimationRetargetNodeScript = preload("res://core/models/combat_animation_retarget_node.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationRetargetResolverScript = preload("res://core/resolvers/combat_animation_retarget_resolver.gd")
const CombatAnimationDraftValidatorScript = preload("res://core/resolvers/combat_animation_draft_validator.gd")

const PRESET_FORWARD_CUT: StringName = &"preset_forward_cut"

var retarget_resolver = CombatAnimationRetargetResolverScript.new()
var draft_validator = CombatAnimationDraftValidatorScript.new()

func get_builtin_preset_recipes() -> Array:
	return [build_forward_cut_recipe()]

func build_forward_cut_recipe():
	var recipe = CombatAnimationPresetRecipeScript.new()
	recipe.preset_id = PRESET_FORWARD_CUT
	recipe.display_name = "Forward Cut"
	recipe.description = "Starter normalized forward cut recipe."
	recipe.speed_acceleration_percent = 30.0
	recipe.speed_deceleration_percent = 42.0
	recipe.retarget_nodes.clear()
	for retarget_node: Resource in [
		_build_recipe_retarget_node(
			Vector3(0.22, 0.08, 0.82),
			0.34,
			Vector3(0.08, 0.0, 1.0),
			0.0,
			0.01,
			&"grip_normal"
		),
		_build_recipe_retarget_node(
			Vector3(0.44, 0.18, 0.76),
			0.62,
			Vector3(0.24, -0.04, 1.0),
			12.0,
			0.22,
			&"grip_normal"
		),
		_build_recipe_retarget_node(
			Vector3(-0.34, 0.2, 0.83),
			0.56,
			Vector3(-0.22, 0.02, 1.0),
			-10.0,
			0.28,
			&"grip_normal"
		),
	]:
		recipe.retarget_nodes.append(retarget_node)
	recipe.normalize()
	return recipe

func resolve_builtin_preset_to_draft(
	preset_id: StringName,
	skill_id: StringName,
	slot_id: StringName,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {}
) -> Dictionary:
	for recipe in get_builtin_preset_recipes():
		if recipe != null and StringName(recipe.preset_id) == preset_id:
			return resolve_recipe_to_draft(recipe, skill_id, slot_id, current_weapon_length_meters, volume_config)
	return {}

func resolve_recipe_to_draft(
	recipe,
	skill_id: StringName,
	slot_id: StringName,
	current_weapon_length_meters: float,
	volume_config: Dictionary = {}
) -> Dictionary:
	if recipe == null:
		return {}
	if recipe.has_method("normalize"):
		recipe.call("normalize")
	if int(recipe.retarget_nodes.size()) < 2:
		return {
			"preset_resolved": false,
			"error": "preset_requires_at_least_two_nodes",
		}
	var draft = CombatAnimationDraftScript.new()
	if draft == null:
		return {}
	draft.draft_id = skill_id
	draft.draft_kind = CombatAnimationDraftScript.DRAFT_KIND_SKILL
	draft.owning_skill_id = skill_id
	draft.legal_slot_id = slot_id
	draft.display_name = String(recipe.display_name)
	draft.skill_name = String(recipe.display_name)
	draft.skill_description = String(recipe.description)
	draft.speed_acceleration_percent = float(recipe.speed_acceleration_percent)
	draft.speed_deceleration_percent = float(recipe.speed_deceleration_percent)
	for node_index: int in range(recipe.retarget_nodes.size()):
		var source_retarget_node: Resource = recipe.retarget_nodes[node_index] as Resource
		if source_retarget_node == null:
			continue
		var retarget_node: Resource = source_retarget_node.duplicate(true) as Resource
		var resolved_values: Dictionary = retarget_resolver.resolve_motion_values_from_retarget_node(
			retarget_node,
			current_weapon_length_meters,
			volume_config
		)
		if resolved_values.is_empty():
			continue
		var motion_node = _build_motion_node_from_resolved_values(node_index, retarget_node, resolved_values)
		if motion_node != null:
			draft.motion_node_chain.append(motion_node)
	draft.selected_motion_node_index = 0
	draft.continuity_motion_node_index = 0
	draft.normalize()
	var validation_results: Array = draft_validator.validate_draft(draft)
	var validation_error_count: int = draft_validator.get_error_count(validation_results)
	return {
		"preset_resolved": draft.motion_node_chain.size() >= 2,
		"draft": draft,
		"preset_id": recipe.preset_id,
		"node_count": draft.motion_node_chain.size(),
		"validation_results": validation_results,
		"validation_error_count": validation_error_count,
		"validation_passed": validation_error_count == 0,
	}

func _build_motion_node_from_resolved_values(
	node_index: int,
	retarget_node: Resource,
	resolved_values: Dictionary
):
	var motion_node = CombatAnimationMotionNodeScript.new()
	motion_node.node_index = node_index
	motion_node.node_id = StringName("motion_node_%02d" % node_index)
	motion_node.tip_position_local = resolved_values.get("tip_position_local", Vector3.ZERO) as Vector3
	motion_node.pommel_position_local = resolved_values.get("pommel_position_local", Vector3.ZERO) as Vector3
	motion_node.weapon_orientation_degrees = resolved_values.get("weapon_orientation_degrees", Vector3.ZERO) as Vector3
	motion_node.weapon_orientation_authored = bool(resolved_values.get("weapon_orientation_authored", false))
	motion_node.weapon_roll_degrees = float(resolved_values.get("weapon_roll_degrees", 0.0))
	motion_node.axial_reposition_offset = float(resolved_values.get("axial_reposition_offset", 0.0))
	motion_node.grip_seat_slide_offset = float(resolved_values.get(
		"grip_seat_slide_offset",
		CombatAnimationMotionNodeScript.DEFAULT_GRIP_SEAT_SLIDE_OFFSET
	))
	motion_node.body_support_blend = float(resolved_values.get("body_support_blend", 0.0))
	motion_node.right_upperarm_roll_degrees = float(resolved_values.get("right_upperarm_roll_degrees", 0.0))
	motion_node.left_upperarm_roll_degrees = float(resolved_values.get("left_upperarm_roll_degrees", 0.0))
	motion_node.transition_duration_seconds = float(resolved_values.get("transition_duration_seconds", motion_node.transition_duration_seconds))
	motion_node.preferred_grip_style_mode = StringName(resolved_values.get("preferred_grip_style_mode", &"grip_normal"))
	motion_node.two_hand_state = StringName(resolved_values.get("two_hand_state", CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO))
	motion_node.primary_hand_slot = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(StringName(resolved_values.get(
		"primary_hand_slot",
		CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO
	)))
	motion_node.tip_curve_in_handle = resolved_values.get("tip_curve_in_handle", Vector3.ZERO) as Vector3
	motion_node.tip_curve_out_handle = resolved_values.get("tip_curve_out_handle", Vector3.ZERO) as Vector3
	motion_node.pommel_curve_in_handle = resolved_values.get("pommel_curve_in_handle", Vector3.ZERO) as Vector3
	motion_node.pommel_curve_out_handle = resolved_values.get("pommel_curve_out_handle", Vector3.ZERO) as Vector3
	motion_node.retarget_node = retarget_node
	motion_node.normalize()
	return motion_node

func _build_recipe_retarget_node(
	pivot_direction_local: Vector3,
	pivot_range_percent: float,
	weapon_axis_local: Vector3,
	weapon_roll_degrees: float,
	transition_duration_seconds: float,
	grip_style_mode: StringName
) -> Resource:
	var retarget_node = CombatAnimationRetargetNodeScript.new()
	retarget_node.enabled = true
	retarget_node.origin_space = CombatAnimationRetargetNodeScript.ORIGIN_SPACE_PRIMARY_SHOULDER
	retarget_node.pivot_direction_local = pivot_direction_local
	retarget_node.pivot_range_percent = pivot_range_percent
	retarget_node.pivot_ratio_from_pommel = 0.5
	retarget_node.weapon_axis_local = weapon_axis_local
	retarget_node.weapon_orientation_degrees = Vector3.ZERO
	retarget_node.weapon_orientation_authored = false
	retarget_node.weapon_roll_degrees = weapon_roll_degrees
	retarget_node.transition_duration_seconds = transition_duration_seconds
	retarget_node.body_support_blend = 0.35
	retarget_node.preferred_grip_style_mode = grip_style_mode
	retarget_node.two_hand_state = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	retarget_node.primary_hand_slot = CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO
	retarget_node.source_weapon_length_meters = 0.5
	retarget_node.source_min_radius_meters = 0.1
	retarget_node.source_max_radius_meters = 1.0
	retarget_node.tip_curve_in_normalized = Vector3.ZERO
	retarget_node.tip_curve_out_normalized = Vector3(0.05, 0.02, 0.03)
	retarget_node.pommel_curve_in_normalized = Vector3.ZERO
	retarget_node.pommel_curve_out_normalized = Vector3(0.04, 0.01, 0.02)
	retarget_node.normalize()
	return retarget_node
