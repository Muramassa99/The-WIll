extends SceneTree

const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const CombatOriginRegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_origin_registry_results.txt"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	var registry = CombatOriginRegistryScript.new()
	registry.register_default_combat_origins(&"verify_combat_origin_registry")
	var validation: Dictionary = registry.validate_all()
	var weapon_chain: Array = registry.resolve_chain(CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_ANCHOR)
	var primary_contact_surface_chain: Array = registry.resolve_chain(
		CombatOriginRecordScript.ORIGIN_PRIMARY_GRIP_CONTACT_SURFACE
	)
	var support_contact_surface_chain: Array = registry.resolve_chain(
		CombatOriginRecordScript.ORIGIN_SUPPORT_GRIP_CONTACT_SURFACE
	)
	var bridge_chain: Array = registry.resolve_chain(CombatOriginRecordScript.ORIGIN_BRIDGE_TARGET)
	var stow_chain: Array = registry.resolve_chain(CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	var all_checks_passed: bool = (
		bool(validation.get("ok", false))
		and registry.get_origin_count() >= 17
		and _chain_ends_at_machine(weapon_chain)
		and _chain_ends_at_machine(primary_contact_surface_chain)
		and _chain_ends_at_machine(support_contact_surface_chain)
		and _chain_ends_at_machine(bridge_chain)
		and _chain_ends_at_machine(stow_chain)
		and _origin_has_parent(registry, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT, CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)
		and _origin_has_parent(registry, CombatOriginRecordScript.ORIGIN_STOW_ANCHOR, CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW)
	)
	var lines: PackedStringArray = []
	lines.append("origin_count=%d" % registry.get_origin_count())
	lines.append("all_chains_ok=%s" % str(bool(validation.get("ok", false))))
	lines.append("primary_grip_chain=%s" % _chain_to_text(weapon_chain))
	lines.append("primary_contact_surface_chain=%s" % _chain_to_text(primary_contact_surface_chain))
	lines.append("support_contact_surface_chain=%s" % _chain_to_text(support_contact_surface_chain))
	lines.append("bridge_target_chain=%s" % _chain_to_text(bridge_chain))
	lines.append("stow_anchor_chain=%s" % _chain_to_text(stow_chain))
	lines.append("weapon_root_parent_ok=%s" % str(_origin_has_parent(registry, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT, CombatOriginRecordScript.ORIGIN_SOLVED_REPLAY_REFERENCE)))
	lines.append("stow_anchor_parent_ok=%s" % str(_origin_has_parent(registry, CombatOriginRecordScript.ORIGIN_STOW_ANCHOR, CombatOriginRecordScript.ORIGIN_NONCOMBAT_STOW)))
	lines.append("all_checks_passed=%s" % str(all_checks_passed))
	lines.append("")
	lines.append_array(registry.build_debug_lines())
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	for line in lines:
		print(line)
	quit(0 if all_checks_passed else 1)

func _chain_ends_at_machine(chain: Array) -> bool:
	if chain.is_empty():
		return false
	var final_record = chain[chain.size() - 1]
	return final_record != null and final_record.origin_id == CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT

func _chain_to_text(chain: Array) -> String:
	var labels: PackedStringArray = []
	for record in chain:
		var origin_record = record
		if origin_record != null:
			labels.append(String(origin_record.origin_id))
	return " -> ".join(labels)

func _origin_has_parent(registry, origin_id: StringName, parent_origin_id: StringName) -> bool:
	var record = registry.get_origin(origin_id)
	return record != null and record.parent_origin_id == parent_origin_id
