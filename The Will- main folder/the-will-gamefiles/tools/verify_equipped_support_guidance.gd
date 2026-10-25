extends SceneTree

const PresenterScript = preload("res://runtime/player/player_equipped_item_presenter.gd")

class RigSpy extends Node3D:
	var arm_targets: Dictionary = {}
	var arm_active: Dictionary = {}
	var finger_targets: Dictionary = {}
	var support_active: Dictionary = {}
	var dominant_slot := StringName()
	func set_arm_guidance_target(slot: StringName, target: Node3D) -> void:
		arm_targets[slot] = target
	func clear_arm_guidance_target(slot: StringName) -> void:
		arm_targets.erase(slot)
	func set_arm_guidance_active(slot: StringName, active: bool) -> void:
		arm_active[slot] = active
	func clear_arm_guidance_active(slot: StringName) -> void:
		arm_active.erase(slot)
	func set_finger_grip_target(slot: StringName, target: Node3D) -> void:
		finger_targets[slot] = target
	func clear_finger_grip_target(slot: StringName) -> void:
		finger_targets.erase(slot)
	func set_support_hand_active(slot: StringName, active: bool) -> void:
		support_active[slot] = active
	func set_dominant_grip_slot(slot: StringName) -> void:
		dominant_slot = slot
	func clear_dominant_grip_slot() -> void:
		dominant_slot = StringName()

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var presenter := PresenterScript.new()
	var rig := RigSpy.new()
	root.add_child(rig)
	var right_item := _make_item()
	var left_item := _make_item()
	root.add_child(right_item)
	root.add_child(left_item)
	for main: StringName in [&"hand_right", &"hand_left"]:
		var support: StringName = &"hand_left" if main == &"hand_right" else &"hand_right"
		var item: Node3D = right_item if main == &"hand_right" else left_item
		var items := {main: item}
		presenter.sync_rig_weapon_guidance(rig, items, true, null)
		_check(rig.arm_targets.get(main) == item.get_node("PrimaryGripAnchor"), "%s_primary_anchor_retained" % main)
		_check(rig.finger_targets.get(main) == item.get_node("PrimaryGripGuide"), "%s_primary_guide_retained" % main)
		_check(rig.dominant_slot == main, "%s_primary_ownership_retained" % main)
		_expect_no_support(rig, support, "%s_empty_equipment_slot" % main)

		# The authored action can still deliberately engage its support hand.
		presenter.sync_single_weapon_contact_guidance(rig, item, main, true, true, true, true, false)
		_check(rig.arm_targets.get(support) == item.get_node("SupportGripAnchor"), "%s_explicit_support_anchor" % main)
		_check(rig.finger_targets.get(support) == item.get_node("SecondaryGripGuide"), "%s_explicit_support_guide" % main)
		_check(bool(rig.arm_active.get(support, false)) and bool(rig.support_active.get(support, false)), "%s_explicit_support_active" % main)
		presenter.sync_single_weapon_contact_guidance(rig, item, main, false, true, true, true, false)
		_expect_no_support(rig, support, "%s_explicit_one_hand_clears_support" % main)
		item.set_meta("two_hand_character_eligible", false)
		presenter.sync_single_weapon_contact_guidance(rig, item, main, true, true, true, true, false)
		_expect_no_support(rig, support, "%s_ineligible_handle_rejects_support" % main)
		item.set_meta("two_hand_character_eligible", true)

	presenter.sync_rig_weapon_guidance(rig, {&"hand_right": right_item, &"hand_left": left_item}, true, null)
	_check(rig.arm_targets.get(&"hand_right") == right_item.get_node("PrimaryGripAnchor"), "dual_equipment_right_primary_retained")
	_check(rig.arm_targets.get(&"hand_left") == left_item.get_node("PrimaryGripAnchor"), "dual_equipment_left_primary_retained")
	_check(not bool(rig.support_active.get(&"hand_right", false)) and not bool(rig.support_active.get(&"hand_left", false)), "dual_equipment_does_not_claim_support")
	presenter.sync_rig_weapon_guidance(rig, {&"hand_right": right_item}, false, null)
	_expect_no_support(rig, &"hand_right", "stowed_right_clear")
	_expect_no_support(rig, &"hand_left", "stowed_left_clear")
	right_item.free()
	left_item.free()
	rig.free()
	print(JSON.stringify({"verifier": "equipped_support_guidance", "checks": _checks, "passed": _failures.is_empty(), "failures": _failures}, "\t"))
	quit(0 if _failures.is_empty() else 1)

func _make_item() -> Node3D:
	var item := Node3D.new()
	item.set_meta("two_hand_character_eligible", true)
	for child_name: String in ["PrimaryGripGuide", "SecondaryGripGuide", "PrimaryGripAnchor", "SupportGripAnchor"]:
		var child := Node3D.new()
		child.name = child_name
		item.add_child(child)
	return item

func _expect_no_support(rig: RigSpy, slot: StringName, label: String) -> void:
	_check(not rig.arm_targets.has(slot) and not rig.finger_targets.has(slot), label + ":no_targets")
	_check(not bool(rig.arm_active.get(slot, false)) and not bool(rig.support_active.get(slot, false)), label + ":inactive")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
