extends RefCounted
class_name ForgeV2PlatformContract

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")

const HANDLE_USER_AUTHORED := &"handle_user_authored"
const HANDLE_FIXED_INTERNAL := &"handle_fixed_internal"
const HANDLE_FOCUS_ANCHOR := &"handle_focus_anchor"

const DELIVERY_DIRECT_MOTION := &"delivery_direct_motion"
const DELIVERY_DEFENSIVE_VOLUME := &"delivery_defensive_volume"
const DELIVERY_PROJECTILE := &"delivery_projectile"
const DELIVERY_EFFECT := &"delivery_effect"

const EDITOR_MELEE_MOTION := &"editor_melee_motion"
const EDITOR_SHIELD_DEFENSE := &"editor_shield_defense"
const EDITOR_RANGED_PHYSICAL := &"editor_ranged_physical"
const EDITOR_MAGIC_FOCUS := &"editor_magic_focus"

static func build_contract(builder_path_id: StringName, builder_component_id: StringName = StringName()) -> Dictionary:
	var normalized_builder_path_id: StringName = CraftedItemWIPScript.normalize_builder_path_id(builder_path_id)
	var normalized_builder_component_id: StringName = CraftedItemWIPScript.normalize_builder_component_id(
		normalized_builder_path_id,
		builder_component_id
	)
	var contract: Dictionary = {
		"builder_path_id": normalized_builder_path_id,
		"builder_component_id": normalized_builder_component_id,
		"builder_scope_label": CraftedItemWIPScript.get_builder_scope_label(
			normalized_builder_path_id,
			normalized_builder_component_id
		),
		"forge_intent": CraftedItemWIPScript.get_default_forge_intent_for_builder_path(normalized_builder_path_id),
		"equipment_context": CraftedItemWIPScript.get_default_equipment_context_for_builder_path(normalized_builder_path_id),
		"builder_marker_count": CraftedItemWIPScript.get_builder_marker_catalog_entries(
			normalized_builder_path_id,
			normalized_builder_component_id
		).size(),
	}
	match normalized_builder_path_id:
		CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL:
			_apply_ranged_physical_contract(contract, normalized_builder_component_id)
		CraftedItemWIPScript.BUILDER_PATH_SHIELD:
			contract.merge({
				"handle_policy": HANDLE_FIXED_INTERNAL,
				"handle_label": "Fixed Internal Handle",
				"delivery_policy": DELIVERY_DEFENSIVE_VOLUME,
				"delivery_label": "Defensive Collision",
				"editor_family": EDITOR_SHIELD_DEFENSE,
				"editor_label": "Shield Defense",
				"component_label": "Primary",
				"validation_note": "Stable internal anchor plus outward defensive body.",
			}, true)
		CraftedItemWIPScript.BUILDER_PATH_MAGIC:
			contract.merge({
				"handle_policy": HANDLE_FOCUS_ANCHOR,
				"handle_label": "Focus Anchor",
				"delivery_policy": DELIVERY_EFFECT,
				"delivery_label": "Effect Delivery",
				"editor_family": EDITOR_MAGIC_FOCUS,
				"editor_label": "Magic Focus",
				"component_label": "Primary",
				"validation_note": "Focus/channel object; hurt delivery belongs to effect systems.",
			}, true)
		_:
			contract.merge({
				"handle_policy": HANDLE_USER_AUTHORED,
				"handle_label": "User Handle",
				"delivery_policy": DELIVERY_DIRECT_MOTION,
				"delivery_label": "Direct Motion",
				"editor_family": EDITOR_MELEE_MOTION,
				"editor_label": "Melee Motion",
				"component_label": "Primary",
				"validation_note": "Held authored body with player-created valid grip.",
			}, true)
	return contract

static func build_compact_summary(builder_path_id: StringName, builder_component_id: StringName = StringName()) -> String:
	var contract: Dictionary = build_contract(builder_path_id, builder_component_id)
	var parts: Array[String] = [
		String(contract.get("builder_scope_label", "")),
		"intent %s" % String(contract.get("forge_intent", "")),
		"context %s" % String(contract.get("equipment_context", "")),
		String(contract.get("handle_label", "")),
		String(contract.get("delivery_label", "")),
	]
	var marker_count := int(contract.get("builder_marker_count", 0))
	if marker_count > 0:
		parts.append("%d markers" % marker_count)
	return " | ".join(parts)

static func _apply_ranged_physical_contract(contract: Dictionary, builder_component_id: StringName) -> void:
	var component_label: String = CraftedItemWIPScript.get_builder_component_label(
		CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL,
		builder_component_id
	)
	var validation_note := "Physical projectile platform with launcher/package responsibilities."
	if builder_component_id == CraftedItemWIPScript.BUILDER_COMPONENT_BOW:
		validation_note = "Bow body uses authored string-anchor marker pairs for launch geometry."
	elif builder_component_id == CraftedItemWIPScript.BUILDER_COMPONENT_QUIVER:
		validation_note = "Quiver stores carried projectile support as a paired ranged component."
	contract.merge({
		"handle_policy": HANDLE_USER_AUTHORED,
		"handle_label": "User Handle",
		"delivery_policy": DELIVERY_PROJECTILE,
		"delivery_label": "Projectile Delivery",
		"editor_family": EDITOR_RANGED_PHYSICAL,
		"editor_label": "Ranged Physical",
		"component_label": component_label,
		"validation_note": validation_note,
	}, true)
