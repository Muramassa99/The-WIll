extends RefCounted
class_name ForgeV2MaterialVolumeResolver

const ForgeV2MaterialBodyScript = preload("res://runtime/forge_v2/forge_v2_material_body.gd")
const ForgeV2MaterialCompositionPolicyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_composition_policy.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload("res://runtime/forge_v2/forge_v2_profile_shape_library.gd")
const ForgeV2VolumeStrokeScript = preload("res://runtime/forge_v2/forge_v2_volume_stroke.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")

const REFERENCE_CELL_WORLD_SIZE_METERS := ForgeV2MaterialBodyScript.REFERENCE_CELL_WORLD_SIZE_METERS
const CELL_EQUIVALENTS_PER_MATERIAL_UNIT := ForgeV2MaterialBodyScript.CELL_EQUIVALENTS_PER_MATERIAL_UNIT
const MATERIAL_UNIT_SCALE := ForgeV2MaterialBodyScript.MATERIAL_UNIT_SCALE
const SAMPLE_CELL_SIZE_MIN_METERS := REFERENCE_CELL_WORLD_SIZE_METERS
const SAMPLE_CELL_SIZE_MAX_METERS := REFERENCE_CELL_WORLD_SIZE_METERS * 2.0
const SAMPLE_RADIUS_RATIO := 0.5
const MAX_BODY_SAMPLE_SEGMENTS := 96
const SPLINE_AUTO_CURVE_HANDLE_MIN_LENGTH_METERS := 0.025
const SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH := 0.3333333
const SPLINE_AUTO_CURVE_MIDDLE_STRENGTH := 0.1666667
const MAX_INCREMENTAL_CACHE_CELL_COUNT := 1000000
const MAX_INCREMENTAL_CACHE_BODY_COUNT := 4096

var _incremental_cache_valid: bool = false
var _incremental_cache_sample_cell_size_meters: float = 0.0
var _incremental_cache_body_tokens: Array[Dictionary] = []
var _incremental_cache_cell_materials: Dictionary = {}
var _incremental_cache_protected_handle_cells: Dictionary = {}
var _incremental_cache_material_cell_counts: Dictionary = {}
var _last_incremental_cache_diagnostics: Dictionary = {}
var _incremental_cache_candidate_transaction: Dictionary = {}

func build_add_material_delta(add_bodies: Array, layer_id: StringName) -> Dictionary:
	var resolved_summary: Dictionary = build_usage_summary(add_bodies)
	var resolved_groups: Dictionary = resolved_summary.get("materials", {}) as Dictionary
	var ledger_delta: Dictionary = {}
	var total_volume_cell_equivalents := 0.0
	var total_material_centi_units := 0
	for material_variant_id: StringName in resolved_groups.keys():
		var group_entry: Dictionary = resolved_groups.get(material_variant_id, {}) as Dictionary
		var volume_cell_equivalents: float = float(group_entry.get("rough_volume_cell_equivalents", 0.0))
		var material_centi_units: int = _material_centi_units_from_volume_cell_equivalents(volume_cell_equivalents)
		var layer_ids: Array[StringName] = []
		if layer_id != StringName():
			layer_ids.append(layer_id)
		ledger_delta[material_variant_id] = {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": volume_cell_equivalents,
			"rough_material_centi_units": material_centi_units,
			"rough_material_units": float(material_centi_units) / float(MATERIAL_UNIT_SCALE),
			"layer_ids": layer_ids,
		}
		total_volume_cell_equivalents += volume_cell_equivalents
		total_material_centi_units += material_centi_units
	return {
		"ledger_delta": ledger_delta,
		"rough_volume_cell_equivalents_delta": total_volume_cell_equivalents,
		"rough_material_centi_units_delta": total_material_centi_units,
	}

func build_usage_summary(active_bodies: Array) -> Dictionary:
	if active_bodies.is_empty():
		return _build_usage_summary_from_cell_materials({}, 0.0)
	_normalize_body_entries(active_bodies)
	var sample_cell_size_meters: float = _resolve_group_sample_cell_size(active_bodies)
	var sample_volume_cell_equivalents: float = pow(sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS, 3.0)
	var cell_materials: Dictionary = {}
	var protected_handle_cells: Dictionary = {}
	_apply_body_entries_to_occupancy(
		cell_materials,
		protected_handle_cells,
		active_bodies,
		sample_cell_size_meters
	)
	return _build_usage_summary_from_cell_materials(cell_materials, sample_volume_cell_equivalents)


func build_spatial_usage_summary(active_bodies: Array) -> Dictionary:
	if active_bodies.is_empty():
		return {
			"ok": false,
			"reason": &"spatial_usage_bodies_empty",
		}
	_normalize_body_entries(active_bodies)
	var sample_cell_size_meters := _resolve_group_sample_cell_size(active_bodies)
	var cell_materials: Dictionary = {}
	var protected_handle_cells: Dictionary = {}
	_apply_body_entries_to_occupancy(
		cell_materials,
		protected_handle_cells,
		active_bodies,
		sample_cell_size_meters
	)
	return _build_spatial_usage_summary_from_cell_materials(
		cell_materials,
		sample_cell_size_meters,
		&"forge_v2_active_body_occupancy_rebuild"
	)

func build_incremental_committed_usage_summary(
	existing_committed_bodies: Array,
	new_committed_bodies: Array,
	checkpoint_token: Dictionary = {},
	transactional_candidate: bool = false
) -> Dictionary:
	if transactional_candidate and not _incremental_cache_candidate_transaction.is_empty():
		return {
			"summary": {},
			"diagnostics": {
				"cache_candidate_pending": true,
				"invalidation_reason": &"cache_candidate_already_pending",
			},
		}
	var combined_bodies: Array = []
	combined_bodies.append_array(existing_committed_bodies)
	combined_bodies.append_array(new_committed_bodies)
	_normalize_body_entries(combined_bodies)
	var sample_cell_size_meters := _resolve_group_sample_cell_size(combined_bodies)
	var checkpoint_sample_cell_size_meters := float(checkpoint_token.get(
		"resolver_sample_cell_size_meters",
		0.0
	))
	if checkpoint_sample_cell_size_meters > 0.0:
		sample_cell_size_meters = checkpoint_sample_cell_size_meters
	var existing_body_tokens := _build_body_cache_tokens(existing_committed_bodies)
	var normalized_checkpoint_token := _normalize_checkpoint_cache_token(
		checkpoint_token,
		sample_cell_size_meters
	)
	if not normalized_checkpoint_token.is_empty():
		existing_body_tokens.push_front(normalized_checkpoint_token)
	var history_matches := (
		_incremental_cache_valid
		and _incremental_cache_body_tokens == existing_body_tokens
	)
	var sample_basis_matches := (
		_incremental_cache_valid
		and _incremental_cache_sample_cell_size_meters == sample_cell_size_meters
	)
	var cache_reused := history_matches and sample_basis_matches
	var sampled_bodies: Array = (
		new_committed_bodies if cache_reused else combined_bodies
	)
	if transactional_candidate:
		_prepare_incremental_cache_candidate_transaction(
			cache_reused
		)
	var invalidation_reason := &"none"
	if not normalized_checkpoint_token.is_empty() and not cache_reused:
		# A checkpoint token without its persisted occupancy snapshot is not a
		# geometric base. Fail closed instead of silently pricing only the tail.
		reset_incremental_committed_cache(&"checkpoint_cache_requires_restore")
		_last_incremental_cache_diagnostics = {
			"cache_reused": false,
			"full_rebuild": false,
			"cache_retained": false,
			"checkpoint_cache_seeded": false,
			"invalidation_reason": &"checkpoint_cache_requires_restore",
			"resolved_sample_cell_size_meters": sample_cell_size_meters,
		}
		return {
			"summary": {},
			"diagnostics": _last_incremental_cache_diagnostics.duplicate(true),
		}
	if not cache_reused:
		if not _incremental_cache_valid:
			invalidation_reason = &"cache_empty"
		elif not history_matches:
			invalidation_reason = &"committed_history_mismatch"
		else:
			invalidation_reason = &"sample_basis_changed"
		_incremental_cache_cell_materials = {}
		_incremental_cache_protected_handle_cells = {}
		_incremental_cache_material_cell_counts = {}
	var apply_diagnostics := _apply_body_entries_to_occupancy(
		_incremental_cache_cell_materials,
		_incremental_cache_protected_handle_cells,
		sampled_bodies,
		sample_cell_size_meters,
		_incremental_cache_material_cell_counts,
		true,
		transactional_candidate and cache_reused,
		_get_incremental_cache_candidate_touched_cells()
	)
	var sample_volume_cell_equivalents := (
		0.0
		if combined_bodies.is_empty()
		else pow(
			sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS,
			3.0
		)
	)
	var authoritative_summary := _build_usage_summary_from_material_cell_counts(
		_incremental_cache_material_cell_counts,
		sample_volume_cell_equivalents
	)
	var combined_body_tokens := _build_body_cache_tokens(combined_bodies)
	if not normalized_checkpoint_token.is_empty():
		combined_body_tokens.push_front(normalized_checkpoint_token)
	var cache_retained := (
		_incremental_cache_cell_materials.size() <= MAX_INCREMENTAL_CACHE_CELL_COUNT
		and combined_body_tokens.size() <= MAX_INCREMENTAL_CACHE_BODY_COUNT
	)
	var cached_cell_count := _incremental_cache_cell_materials.size()
	var protected_handle_cell_count := (
		_incremental_cache_protected_handle_cells.size()
	)
	if cache_retained:
		_incremental_cache_valid = true
		_incremental_cache_sample_cell_size_meters = sample_cell_size_meters
		_incremental_cache_body_tokens = combined_body_tokens
	else:
		reset_incremental_committed_cache(&"capacity_exceeded")
	_last_incremental_cache_diagnostics = {
		"cache_reused": cache_reused,
		"full_rebuild": not cache_reused,
		"invalidation_reason": invalidation_reason,
		"new_body_count": new_committed_bodies.size(),
		"combined_body_count": combined_bodies.size(),
		"sampled_body_count": int(apply_diagnostics.get("sampled_body_count", 0)),
		"occupied_candidate_count": int(apply_diagnostics.get(
			"occupied_candidate_count",
			0
		)),
		"applied_candidate_count": int(apply_diagnostics.get(
			"applied_candidate_count",
			0
		)),
		"protected_skip_count": int(apply_diagnostics.get(
			"protected_skip_count",
			0
		)),
		"resolved_sample_cell_size_meters": sample_cell_size_meters,
		"cached_cell_count": cached_cell_count,
		"protected_handle_cell_count": protected_handle_cell_count,
		"cache_retained": cache_retained,
		"cache_cell_limit": MAX_INCREMENTAL_CACHE_CELL_COUNT,
		"cache_body_limit": MAX_INCREMENTAL_CACHE_BODY_COUNT,
		"checkpoint_cache_seeded": not normalized_checkpoint_token.is_empty(),
		"cache_candidate_pending": transactional_candidate,
	}
	return {
		"summary": authoritative_summary,
		"diagnostics": _last_incremental_cache_diagnostics.duplicate(true),
	}

func reset_incremental_committed_cache(reason: StringName = &"explicit_reset") -> void:
	_incremental_cache_valid = false
	_incremental_cache_sample_cell_size_meters = 0.0
	_incremental_cache_body_tokens = []
	_incremental_cache_cell_materials = {}
	_incremental_cache_protected_handle_cells = {}
	_incremental_cache_material_cell_counts = {}
	_last_incremental_cache_diagnostics = {
		"cache_reused": false,
		"full_rebuild": false,
		"cache_retained": false,
		"cache_valid": false,
		"reset_reason": reason,
	}

func get_incremental_committed_cache_diagnostics() -> Dictionary:
	var diagnostics := _last_incremental_cache_diagnostics.duplicate(true)
	diagnostics["cache_valid"] = _incremental_cache_valid
	diagnostics["cache_candidate_pending"] = (
		not _incremental_cache_candidate_transaction.is_empty()
	)
	diagnostics["cached_body_count"] = _incremental_cache_body_tokens.size()
	diagnostics["cached_cell_count_current"] = (
		_incremental_cache_cell_materials.size()
	)
	return diagnostics


func build_cached_spatial_usage_summary() -> Dictionary:
	if not _incremental_cache_candidate_transaction.is_empty():
		return {
			"ok": false,
			"reason": &"spatial_usage_cache_candidate_pending",
		}
	if (
		not _incremental_cache_valid
		or _incremental_cache_sample_cell_size_meters <= 0.0
	):
		return {
			"ok": false,
			"reason": &"spatial_usage_cache_invalid",
		}
	if _incremental_cache_cell_materials.size() > MAX_INCREMENTAL_CACHE_CELL_COUNT:
		return {
			"ok": false,
			"reason": &"spatial_usage_cache_capacity_exceeded",
		}
	return _build_spatial_usage_summary_from_cell_materials(
		_incremental_cache_cell_materials,
		_incremental_cache_sample_cell_size_meters,
		&"forge_v2_checkpoint_tail_occupancy_cache"
	)

func has_pending_incremental_committed_cache_candidate() -> bool:
	return not _incremental_cache_candidate_transaction.is_empty()


func commit_incremental_committed_cache_candidate() -> bool:
	if _incremental_cache_candidate_transaction.is_empty():
		return false
	_incremental_cache_candidate_transaction = {}
	_last_incremental_cache_diagnostics["cache_candidate_pending"] = false
	_last_incremental_cache_diagnostics["cache_candidate_committed"] = true
	return true


func abort_incremental_committed_cache_candidate() -> bool:
	if _incremental_cache_candidate_transaction.is_empty():
		return false
	var transaction := _incremental_cache_candidate_transaction
	_incremental_cache_candidate_transaction = {}
	_incremental_cache_valid = bool(transaction.get("cache_valid", false))
	_incremental_cache_sample_cell_size_meters = float(transaction.get(
		"sample_cell_size_meters",
		0.0
	))
	_incremental_cache_body_tokens = transaction.get(
		"body_tokens",
		[]
	) as Array[Dictionary]
	var previous_cell_materials := transaction.get(
		"cell_materials_reference",
		{}
	) as Dictionary
	var previous_protected_cells := transaction.get(
		"protected_cells_reference",
		{}
	) as Dictionary
	if bool(transaction.get("touched_journal", false)):
		var touched_cells := transaction.get("touched_cells", {}) as Dictionary
		for cell_key: Vector3i in touched_cells.keys():
			var cell_record := touched_cells[cell_key] as Dictionary
			if bool(cell_record.get("had_material", false)):
				previous_cell_materials[cell_key] = StringName(cell_record.get(
					"material_variant_id",
					StringName()
				))
			else:
				previous_cell_materials.erase(cell_key)
			if bool(cell_record.get("was_protected", false)):
				previous_protected_cells[cell_key] = true
			else:
				previous_protected_cells.erase(cell_key)
	_incremental_cache_cell_materials = previous_cell_materials
	_incremental_cache_protected_handle_cells = previous_protected_cells
	_incremental_cache_material_cell_counts = transaction.get(
		"material_cell_counts",
		{}
	) as Dictionary
	_last_incremental_cache_diagnostics = transaction.get(
		"diagnostics",
		{}
	) as Dictionary
	return true


func _prepare_incremental_cache_candidate_transaction(
	cache_reused: bool
) -> void:
	var transaction := {
		"cache_valid": _incremental_cache_valid,
		"sample_cell_size_meters": _incremental_cache_sample_cell_size_meters,
		"body_tokens": _incremental_cache_body_tokens.duplicate(true),
		"cell_materials_reference": _incremental_cache_cell_materials,
		"protected_cells_reference": (
			_incremental_cache_protected_handle_cells
		),
		"material_cell_counts": (
			_incremental_cache_material_cell_counts.duplicate()
		),
		"diagnostics": _last_incremental_cache_diagnostics.duplicate(true),
		"touched_journal": cache_reused,
		"touched_cells": {},
	}
	_incremental_cache_candidate_transaction = transaction


func _get_incremental_cache_candidate_touched_cells() -> Dictionary:
	if (
		_incremental_cache_candidate_transaction.is_empty()
		or not bool(_incremental_cache_candidate_transaction.get(
			"touched_journal",
			false
		))
	):
		return {}
	return _incremental_cache_candidate_transaction.get(
		"touched_cells",
		{}
	) as Dictionary


func rebase_incremental_committed_cache(
	checkpoint_token: Dictionary,
	active_tail_bodies: Array
) -> Dictionary:
	var plan := build_incremental_committed_cache_rebase_plan(
		checkpoint_token,
		active_tail_bodies
	)
	if not bool(plan.get("ok", false)):
		return plan
	return commit_incremental_committed_cache_rebase(plan)


func build_incremental_committed_cache_rebase_plan(
	checkpoint_token: Dictionary,
	active_tail_bodies: Array,
	expected_pre_rebase_body_tokens: Array = [],
	expected_previous_checkpoint_token: Dictionary = {}
) -> Dictionary:
	var normalized_checkpoint_token := _normalize_checkpoint_cache_token(
		checkpoint_token,
		_incremental_cache_sample_cell_size_meters
	)
	if not _incremental_cache_valid or normalized_checkpoint_token.is_empty():
		return {
			"ok": false,
			"reason": &"cache_or_checkpoint_invalid",
		}
	if not expected_pre_rebase_body_tokens.is_empty():
		var expected_current_tokens := (
			expected_pre_rebase_body_tokens.duplicate(true)
		)
		if not expected_previous_checkpoint_token.is_empty():
			var normalized_previous_checkpoint := (
				_normalize_checkpoint_cache_token(
					expected_previous_checkpoint_token,
					_incremental_cache_sample_cell_size_meters
				)
			)
			if normalized_previous_checkpoint.is_empty():
				return {
					"ok": false,
					"reason": &"previous_checkpoint_token_invalid",
				}
			expected_current_tokens.push_front(normalized_previous_checkpoint)
		if _incremental_cache_body_tokens != expected_current_tokens:
			return {
				"ok": false,
				"reason": &"pre_rebase_history_mismatch",
			}
	var next_tokens := _build_body_cache_tokens(active_tail_bodies)
	next_tokens.push_front(normalized_checkpoint_token)
	if next_tokens.size() > MAX_INCREMENTAL_CACHE_BODY_COUNT:
		return {
			"ok": false,
			"reason": &"cache_body_capacity_exceeded",
		}
	return {
		"ok": true,
		"expected_cache_sample_cell_size_meters": (
			_incremental_cache_sample_cell_size_meters
		),
		"expected_cache_body_tokens": (
			_incremental_cache_body_tokens.duplicate(true)
		),
		"previous_diagnostics": _last_incremental_cache_diagnostics.duplicate(true),
		"next_cache_body_tokens": next_tokens,
	}


func validate_incremental_committed_cache_rebase_plan(plan: Dictionary) -> bool:
	if (
		not bool(plan.get("ok", false))
		or not _incremental_cache_valid
		or float(plan.get(
			"expected_cache_sample_cell_size_meters",
			-1.0
		)) != _incremental_cache_sample_cell_size_meters
	):
		return false
	var expected_tokens_variant: Variant = plan.get(
		"expected_cache_body_tokens",
		[]
	)
	var next_tokens_variant: Variant = plan.get("next_cache_body_tokens", [])
	if (
		not expected_tokens_variant is Array
		or not next_tokens_variant is Array
	):
		return false
	var expected_tokens := expected_tokens_variant as Array
	var next_tokens := next_tokens_variant as Array
	return (
		_incremental_cache_body_tokens == expected_tokens
		and not next_tokens.is_empty()
		and next_tokens.size() <= MAX_INCREMENTAL_CACHE_BODY_COUNT
	)


func commit_incremental_committed_cache_rebase(
	plan: Dictionary
) -> Dictionary:
	if not validate_incremental_committed_cache_rebase_plan(plan):
		return {
			"ok": false,
			"reason": &"cache_rebase_plan_stale",
		}
	var next_tokens := plan.get(
		"next_cache_body_tokens",
		[]
	) as Array[Dictionary]
	_incremental_cache_body_tokens = next_tokens
	_last_incremental_cache_diagnostics["checkpoint_cache_seeded"] = true
	_last_incremental_cache_diagnostics["checkpoint_rebased"] = true
	_last_incremental_cache_diagnostics["cached_body_count"] = next_tokens.size()
	return {
		"ok": true,
		"cached_body_count": next_tokens.size(),
		"cached_cell_count": _incremental_cache_cell_materials.size(),
	}


func rollback_incremental_committed_cache_rebase(plan: Dictionary) -> void:
	var expected_tokens_variant: Variant = plan.get(
		"expected_cache_body_tokens",
		[]
	)
	if expected_tokens_variant is Array:
		_incremental_cache_body_tokens = (
			expected_tokens_variant as Array[Dictionary]
		)
	var previous_diagnostics_variant: Variant = plan.get(
		"previous_diagnostics",
		{}
	)
	if previous_diagnostics_variant is Dictionary:
		_last_incremental_cache_diagnostics = (
			previous_diagnostics_variant as Dictionary
		)


func get_incremental_sample_cell_size_meters() -> float:
	return _incremental_cache_sample_cell_size_meters


func build_committed_body_cache_tokens(bodies: Array) -> Array[Dictionary]:
	return _build_body_cache_tokens(bodies).duplicate(true)


func build_checkpoint_occupancy_delta(
	checkpoint_token: Dictionary,
	promoted_bodies: Array,
	sample_cell_size_meters: float
) -> Dictionary:
	if sample_cell_size_meters <= 0.0 or promoted_bodies.is_empty():
		return {"ok": false, "reason": &"sample_cell_size_invalid"}
	var checkpoint_operation_count := int(checkpoint_token.get(
		"checkpoint_operation_count",
		0
	))
	var checkpoint_sample_cell_size_meters := float(checkpoint_token.get(
		"resolver_sample_cell_size_meters",
		0.0
	))
	if (
		checkpoint_operation_count > 0
		and (
			checkpoint_sample_cell_size_meters <= 0.0
			or not is_equal_approx(
				checkpoint_sample_cell_size_meters,
				sample_cell_size_meters
			)
		)
	):
		return {"ok": false, "reason": &"checkpoint_sample_basis_mismatch"}
	var base_cell_materials: Dictionary = checkpoint_token.get(
		"checkpoint_cell_materials",
		{}
	) as Dictionary
	var base_protected_handle_cells: Dictionary = checkpoint_token.get(
		"checkpoint_protected_handle_cells",
		{}
	) as Dictionary
	var base_material_cell_counts: Dictionary = checkpoint_token.get(
		"checkpoint_material_cell_counts",
		{}
	) as Dictionary
	var base_count_total := 0
	for material_key: Variant in base_material_cell_counts.keys():
		var material_id := StringName(material_key)
		var material_cell_count := int(base_material_cell_counts[material_key])
		if material_id == StringName() or material_cell_count <= 0:
			return {"ok": false, "reason": &"checkpoint_material_counts_invalid"}
		base_count_total += material_cell_count
	if base_count_total != base_cell_materials.size():
		return {"ok": false, "reason": &"checkpoint_material_counts_stale"}
	var cell_updates: Dictionary = {}
	var protected_cell_updates: Dictionary = {}
	var next_material_cell_counts := base_material_cell_counts.duplicate()
	var sampled_body_count := 0
	var occupied_candidate_count := 0
	var applied_candidate_count := 0
	var protected_skip_count := 0
	var next_checkpoint_cell_count := base_cell_materials.size()
	for body: Variant in promoted_bodies:
		if body == null or not _is_body_entry_active(body):
			continue
		var occupied_cells := _collect_body_occupied_cells(
			body,
			sample_cell_size_meters
		)
		sampled_body_count += 1
		occupied_candidate_count += occupied_cells.size()
		if occupied_cells.is_empty():
			continue
		var is_protected_handle := (
			ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body)
		)
		var can_mutate_protected_handle_cells := (
			ForgeV2MaterialCompositionPolicyScript.can_mutate_protected_handle_cells(
				body
			)
		)
		var operation_mode := (
			ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
				body
			)
		)
		if operation_mode == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
			for cell_key: Vector3i in occupied_cells.keys():
				if _read_checkpoint_journal_protected_state(
					cell_key,
					protected_cell_updates,
					base_protected_handle_cells
				):
					protected_skip_count += 1
					continue
				var previous_material_id := _read_checkpoint_journal_material(
					cell_key,
					cell_updates,
					base_cell_materials
				)
				if previous_material_id == StringName():
					continue
				cell_updates[cell_key] = StringName()
				_decrement_material_cell_count(
					next_material_cell_counts,
					previous_material_id
				)
				next_checkpoint_cell_count -= 1
				applied_candidate_count += 1
			continue
		var material_variant_id := _read_body_string_name(
			body,
			"material_variant_id"
		)
		if material_variant_id == StringName():
			return {"ok": false, "reason": &"promoted_material_invalid"}
		var placement_policy := (
			ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(
				body
			)
		)
		for cell_key: Vector3i in occupied_cells.keys():
			if (
				_read_checkpoint_journal_protected_state(
					cell_key,
					protected_cell_updates,
					base_protected_handle_cells
				)
				and not can_mutate_protected_handle_cells
			):
				protected_skip_count += 1
				continue
			var previous_material_id := _read_checkpoint_journal_material(
				cell_key,
				cell_updates,
				base_cell_materials
			)
			if (
				placement_policy == ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
				and previous_material_id != StringName()
			):
				continue
			if previous_material_id != material_variant_id:
				cell_updates[cell_key] = material_variant_id
				_decrement_material_cell_count(
					next_material_cell_counts,
					previous_material_id
				)
				_increment_material_cell_count(
					next_material_cell_counts,
					material_variant_id
				)
				if previous_material_id == StringName():
					next_checkpoint_cell_count += 1
				applied_candidate_count += 1
			if is_protected_handle:
				protected_cell_updates[cell_key] = true
	if sampled_body_count <= 0 or occupied_candidate_count <= 0:
		return {"ok": false, "reason": &"promoted_occupancy_empty"}
	var next_count_total := 0
	for material_key: Variant in next_material_cell_counts.keys():
		var material_cell_count := int(next_material_cell_counts[material_key])
		if StringName(material_key) == StringName() or material_cell_count <= 0:
			return {"ok": false, "reason": &"next_material_counts_invalid"}
		next_count_total += material_cell_count
	if next_count_total != next_checkpoint_cell_count:
		return {"ok": false, "reason": &"next_material_counts_stale"}
	var sample_volume_cell_equivalents := pow(
		sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS,
		3.0
	)
	return {
		"ok": true,
		"base_checkpoint_id": StringName(checkpoint_token.get(
			"checkpoint_id",
			StringName()
		)),
		"base_checkpoint_revision": int(checkpoint_token.get(
			"checkpoint_revision",
			0
		)),
		"base_checkpoint_operation_count": int(checkpoint_token.get(
			"checkpoint_operation_count",
			0
		)),
		"base_checkpoint_cell_count": base_cell_materials.size(),
		"base_checkpoint_protected_cell_count": (
			base_protected_handle_cells.size()
		),
		"next_checkpoint_cell_count": next_checkpoint_cell_count,
		"cell_updates": cell_updates,
		"protected_cell_updates": protected_cell_updates,
		"next_material_cell_counts": next_material_cell_counts,
		"summary": _build_usage_summary_from_material_cell_counts(
			next_material_cell_counts,
			sample_volume_cell_equivalents
		),
		"diagnostics": {
			"sampled_body_count": sampled_body_count,
			"occupied_candidate_count": occupied_candidate_count,
			"applied_candidate_count": applied_candidate_count,
			"protected_skip_count": protected_skip_count,
			"touched_cell_count": cell_updates.size(),
		},
	}


func _read_checkpoint_journal_material(
	cell_key: Vector3i,
	cell_updates: Dictionary,
	base_cell_materials: Dictionary
) -> StringName:
	if cell_updates.has(cell_key):
		return StringName(cell_updates[cell_key])
	return StringName(base_cell_materials.get(cell_key, StringName()))


func _read_checkpoint_journal_protected_state(
	cell_key: Vector3i,
	protected_cell_updates: Dictionary,
	base_protected_handle_cells: Dictionary
) -> bool:
	if protected_cell_updates.has(cell_key):
		return bool(protected_cell_updates[cell_key])
	return base_protected_handle_cells.has(cell_key)

func restore_incremental_committed_cache_from_checkpoint(
	checkpoint_token: Dictionary,
	active_tail_bodies: Array
) -> Dictionary:
	var sample_cell_size_meters := float(checkpoint_token.get(
		"resolver_sample_cell_size_meters",
		0.0
	))
	var normalized_checkpoint_token := _normalize_checkpoint_cache_token(
		checkpoint_token,
		sample_cell_size_meters
	)
	if normalized_checkpoint_token.is_empty() or sample_cell_size_meters <= 0.0:
		return {"ok": false, "reason": &"checkpoint_token_invalid"}
	var occupancy_validation := _validate_checkpoint_occupancy_token(
		checkpoint_token
	)
	if not bool(occupancy_validation.get("ok", false)):
		return {
			"ok": false,
			"reason": occupancy_validation.get(
				"reason",
				&"checkpoint_occupancy_invalid"
			),
		}
	_incremental_cache_cell_materials = (
		occupancy_validation.get("cell_materials", {}) as Dictionary
	).duplicate()
	_incremental_cache_protected_handle_cells = (
		occupancy_validation.get("protected_handle_cells", {}) as Dictionary
	).duplicate()
	_incremental_cache_material_cell_counts = (
		occupancy_validation.get("material_cell_counts", {}) as Dictionary
	).duplicate()
	var apply_diagnostics := _apply_body_entries_to_occupancy(
		_incremental_cache_cell_materials,
		_incremental_cache_protected_handle_cells,
		active_tail_bodies,
		sample_cell_size_meters,
		_incremental_cache_material_cell_counts,
		true
	)
	var next_tokens := _build_body_cache_tokens(active_tail_bodies)
	next_tokens.push_front(normalized_checkpoint_token)
	var cache_retained := (
		_incremental_cache_cell_materials.size() <= MAX_INCREMENTAL_CACHE_CELL_COUNT
		and next_tokens.size() <= MAX_INCREMENTAL_CACHE_BODY_COUNT
	)
	if not cache_retained:
		reset_incremental_committed_cache(&"checkpoint_restore_capacity_exceeded")
		return {"ok": false, "reason": &"checkpoint_restore_capacity_exceeded"}
	_incremental_cache_valid = true
	_incremental_cache_sample_cell_size_meters = sample_cell_size_meters
	_incremental_cache_body_tokens = next_tokens
	_last_incremental_cache_diagnostics = {
		"cache_reused": false,
		"full_rebuild": false,
		"cache_retained": true,
		"checkpoint_cache_seeded": true,
		"checkpoint_restored": true,
		"cached_body_count": next_tokens.size(),
		"cached_cell_count": _incremental_cache_cell_materials.size(),
		"sampled_body_count": int(apply_diagnostics.get(
			"sampled_body_count",
			0
		)),
		"resolved_sample_cell_size_meters": sample_cell_size_meters,
	}
	var sample_volume_cell_equivalents := pow(
		sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS,
		3.0
	)
	return {
		"ok": true,
		"summary": _build_usage_summary_from_material_cell_counts(
			_incremental_cache_material_cell_counts,
			sample_volume_cell_equivalents
		),
		"diagnostics": _last_incremental_cache_diagnostics.duplicate(true),
	}


func _validate_checkpoint_occupancy_token(
	checkpoint_token: Dictionary
) -> Dictionary:
	var cell_materials_variant: Variant = checkpoint_token.get(
		"checkpoint_cell_materials",
		{}
	)
	var protected_cells_variant: Variant = checkpoint_token.get(
		"checkpoint_protected_handle_cells",
		{}
	)
	var material_counts_variant: Variant = checkpoint_token.get(
		"checkpoint_material_cell_counts",
		{}
	)
	if (
		cell_materials_variant is not Dictionary
		or protected_cells_variant is not Dictionary
		or material_counts_variant is not Dictionary
	):
		return {"ok": false, "reason": &"checkpoint_occupancy_type_invalid"}
	var cell_materials := cell_materials_variant as Dictionary
	var protected_cells := protected_cells_variant as Dictionary
	var stored_material_counts := material_counts_variant as Dictionary
	if (
		int(checkpoint_token.get("checkpoint_operation_count", 0)) > 0
		and cell_materials.is_empty()
	):
		return {"ok": false, "reason": &"checkpoint_prefix_occupancy_missing"}

	var computed_material_counts: Dictionary = {}
	for cell_key: Variant in cell_materials.keys():
		if cell_key is not Vector3i:
			return {"ok": false, "reason": &"checkpoint_cell_key_invalid"}
		var material_id := StringName(cell_materials[cell_key])
		if material_id == StringName():
			return {"ok": false, "reason": &"checkpoint_cell_material_missing"}
		_increment_material_cell_count(computed_material_counts, material_id)
	for cell_key: Variant in protected_cells.keys():
		if cell_key is not Vector3i or not cell_materials.has(cell_key):
			return {"ok": false, "reason": &"checkpoint_protected_cell_invalid"}

	if stored_material_counts.is_empty():
		stored_material_counts = computed_material_counts
	else:
		var stored_total := 0
		for material_key: Variant in stored_material_counts.keys():
			var material_id := StringName(material_key)
			var stored_count := int(stored_material_counts[material_key])
			if material_id == StringName() or stored_count <= 0:
				return {"ok": false, "reason": &"checkpoint_material_count_invalid"}
			stored_total += stored_count
			if stored_count != int(computed_material_counts.get(material_id, -1)):
				return {"ok": false, "reason": &"checkpoint_material_count_stale"}
		if (
			stored_total != cell_materials.size()
			or stored_material_counts.size() != computed_material_counts.size()
		):
			return {"ok": false, "reason": &"checkpoint_material_count_mismatch"}
	return {
		"ok": true,
		"cell_materials": cell_materials,
		"protected_handle_cells": protected_cells,
		"material_cell_counts": stored_material_counts,
	}

func _apply_body_entries_to_occupancy(
	cell_materials: Dictionary,
	protected_handle_cells: Dictionary,
	bodies: Array,
	sample_cell_size_meters: float,
	material_cell_counts: Dictionary = {},
	track_material_cell_counts: bool = false,
	record_rollback_cells: bool = false,
	rollback_touched_cells: Dictionary = {}
) -> Dictionary:
	var sampled_body_count := 0
	var occupied_candidate_count := 0
	var applied_candidate_count := 0
	var protected_skip_count := 0
	for body: Variant in bodies:
		if body == null or not _is_body_entry_active(body):
			continue
		var occupied_cells: Dictionary = _collect_body_occupied_cells(
			body,
			sample_cell_size_meters
		)
		sampled_body_count += 1
		occupied_candidate_count += occupied_cells.size()
		if occupied_cells.is_empty():
			continue
		var is_protected_handle := (
			ForgeV2MaterialCompositionPolicyScript.is_protected_handle_entry(body)
		)
		var can_mutate_protected_handle_cells := (
			ForgeV2MaterialCompositionPolicyScript.can_mutate_protected_handle_cells(
				body
			)
		)
		var operation_mode := (
			ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
				body
			)
		)
		if operation_mode == ForgeV2VolumeStrokeScript.OPERATION_REMOVE_MATERIAL:
			for cell_key: Vector3i in occupied_cells.keys():
				if protected_handle_cells.has(cell_key):
					protected_skip_count += 1
					continue
				if not cell_materials.has(cell_key):
					continue
				if record_rollback_cells:
					_record_occupancy_rollback_cell(
						rollback_touched_cells,
						cell_materials,
						protected_handle_cells,
						cell_key
					)
				var removed_material_id := StringName(cell_materials[cell_key])
				cell_materials.erase(cell_key)
				if track_material_cell_counts:
					_decrement_material_cell_count(
						material_cell_counts,
						removed_material_id
					)
				applied_candidate_count += 1
			continue
		var material_variant_id := _read_body_string_name(
			body,
			"material_variant_id"
		)
		if material_variant_id == StringName():
			continue
		var placement_policy := (
			ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(
				body
			)
		)
		for cell_key: Vector3i in occupied_cells.keys():
			if (
				protected_handle_cells.has(cell_key)
				and not can_mutate_protected_handle_cells
			):
				protected_skip_count += 1
				continue
			if (
				placement_policy == ForgeV2VolumeStrokeScript.PLACEMENT_EMPTY_ONLY
				and cell_materials.has(cell_key)
			):
				continue
			var previous_material_id := StringName(cell_materials.get(
				cell_key,
				StringName()
			))
			if previous_material_id != material_variant_id:
				if record_rollback_cells:
					_record_occupancy_rollback_cell(
						rollback_touched_cells,
						cell_materials,
						protected_handle_cells,
						cell_key
					)
				applied_candidate_count += 1
				if track_material_cell_counts:
					_decrement_material_cell_count(
						material_cell_counts,
						previous_material_id
					)
					_increment_material_cell_count(
						material_cell_counts,
						material_variant_id
					)
			cell_materials[cell_key] = material_variant_id
			if is_protected_handle:
				if record_rollback_cells:
					_record_occupancy_rollback_cell(
						rollback_touched_cells,
						cell_materials,
						protected_handle_cells,
						cell_key
					)
				protected_handle_cells[cell_key] = true
	return {
		"sampled_body_count": sampled_body_count,
		"occupied_candidate_count": occupied_candidate_count,
		"applied_candidate_count": applied_candidate_count,
		"protected_skip_count": protected_skip_count,
	}


func _record_occupancy_rollback_cell(
	rollback_touched_cells: Dictionary,
	cell_materials: Dictionary,
	protected_handle_cells: Dictionary,
	cell_key: Vector3i
) -> void:
	if rollback_touched_cells.has(cell_key):
		return
	rollback_touched_cells[cell_key] = {
		"had_material": cell_materials.has(cell_key),
		"material_variant_id": StringName(cell_materials.get(
			cell_key,
			StringName()
		)),
		"was_protected": protected_handle_cells.has(cell_key),
	}


func _increment_material_cell_count(
	material_cell_counts: Dictionary,
	material_variant_id: StringName
) -> void:
	if material_variant_id == StringName():
		return
	material_cell_counts[material_variant_id] = int(material_cell_counts.get(
		material_variant_id,
		0
	)) + 1

func _decrement_material_cell_count(
	material_cell_counts: Dictionary,
	material_variant_id: StringName
) -> void:
	if material_variant_id == StringName():
		return
	var next_count := int(material_cell_counts.get(material_variant_id, 0)) - 1
	if next_count <= 0:
		material_cell_counts.erase(material_variant_id)
	else:
		material_cell_counts[material_variant_id] = next_count

func _normalize_body_entries(bodies: Array) -> void:
	for body: Variant in bodies:
		if body != null:
			_normalize_body_entry(body)

func _build_body_cache_tokens(bodies: Array) -> Array[Dictionary]:
	var tokens: Array[Dictionary] = []
	for body: Variant in bodies:
		if body == null:
			continue
		tokens.append({
			"body_id": _read_body_string_name(body, "body_id"),
			"created_timestamp": _read_body_float(body, "created_timestamp"),
			"updated_timestamp": _read_body_float(body, "updated_timestamp"),
			"body_kind": _read_body_string_name(body, "body_kind"),
			"material_variant_id": _read_body_string_name(
				body,
				"material_variant_id"
			),
			"operation_mode": _read_body_string_name(body, "operation_mode"),
			"effective_operation_mode": (
				ForgeV2MaterialCompositionPolicyScript.resolve_effective_operation_mode(
					body
				)
			),
			"placement_policy": _read_body_string_name(body, "placement_policy"),
			"effective_placement_policy": (
				ForgeV2MaterialCompositionPolicyScript.resolve_effective_placement_policy(
					body
				)
			),
			"shape_kind": _read_body_string_name(body, "shape_kind"),
			"radius_meters": _read_body_float(body, "radius_meters"),
			"profile_id": _read_body_string_name(body, "profile_id"),
			"profile_runtime_schema_version": int(_read_body_variant(
				body,
				"profile_runtime_schema_version",
				0
			)),
			"profile_rotation_bias_degrees": _read_body_float(
				body,
				"profile_rotation_bias_degrees"
			),
			"profile_twist_degrees_per_meter": _read_body_float(
				body,
				"profile_twist_degrees_per_meter"
			),
			"path_point_count": _read_body_path_points(body).size(),
			"path_contact_direction_count": _read_body_vector3_array(
				body,
				"path_contact_directions"
			).size(),
			"profile_point_count": _read_body_vector2_array(
				body,
				"profile_polygon_2d_meters"
			).size(),
			"layer_active": _is_body_entry_active(body),
		})
	return tokens

func _normalize_checkpoint_cache_token(
	checkpoint_token: Dictionary,
	sample_cell_size_meters: float
) -> Dictionary:
	var checkpoint_sample_cell_size_meters := float(checkpoint_token.get(
		"resolver_sample_cell_size_meters",
		0.0
	))
	if (
		checkpoint_token.is_empty()
		or not bool(checkpoint_token.get("checkpoint_initialized", false))
		or int(checkpoint_token.get("checkpoint_operation_count", 0)) <= 0
		or StringName(checkpoint_token.get(
			"checkpoint_id",
			StringName()
		)) == StringName()
		or checkpoint_sample_cell_size_meters <= 0.0
		or sample_cell_size_meters <= 0.0
		or not is_equal_approx(
			checkpoint_sample_cell_size_meters,
			sample_cell_size_meters
		)
	):
		return {}
	return {
		"checkpoint": true,
		"checkpoint_id": StringName(checkpoint_token.get(
			"checkpoint_id",
			StringName()
		)),
		"checkpoint_revision": int(checkpoint_token.get(
			"checkpoint_revision",
			0
		)),
		"checkpoint_operation_count": int(checkpoint_token.get(
			"checkpoint_operation_count",
			0
		)),
		"material_variant_id": StringName(checkpoint_token.get(
			"material_variant_id",
			StringName()
		)),
		"resolver_sample_cell_size_meters": (
			checkpoint_sample_cell_size_meters
		),
	}

func _build_usage_summary_from_cell_materials(
	cell_materials: Dictionary,
	sample_volume_cell_equivalents: float
) -> Dictionary:
	var material_entries: Dictionary = {}
	for cell_key: Vector3i in cell_materials.keys():
		var material_variant_id: StringName = StringName(cell_materials.get(cell_key, StringName()))
		if material_variant_id == StringName():
			continue
		var material_entry: Dictionary = material_entries.get(material_variant_id, {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": 0.0,
			"rough_material_centi_units": 0,
			"rough_material_units": 0.0,
			"ratio": 0.0,
		}) as Dictionary
		material_entry["rough_volume_cell_equivalents"] = (
			float(material_entry.get("rough_volume_cell_equivalents", 0.0))
			+ sample_volume_cell_equivalents
		)
		material_entries[material_variant_id] = material_entry
	var total_centi_units := 0
	var total_volume_cell_equivalents := 0.0
	for material_variant_id: StringName in material_entries.keys():
		var material_entry: Dictionary = material_entries[material_variant_id]
		var volume_cell_equivalents: float = float(material_entry.get("rough_volume_cell_equivalents", 0.0))
		var material_centi_units: int = _material_centi_units_from_volume_cell_equivalents(volume_cell_equivalents)
		material_entry["rough_material_centi_units"] = material_centi_units
		material_entry["rough_material_units"] = float(material_centi_units) / float(MATERIAL_UNIT_SCALE)
		material_entries[material_variant_id] = material_entry
		total_centi_units += material_centi_units
		total_volume_cell_equivalents += volume_cell_equivalents
	for material_variant_id: StringName in material_entries.keys():
		var entry: Dictionary = material_entries[material_variant_id]
		entry["ratio"] = float(entry.get("rough_material_centi_units", 0)) / float(total_centi_units) if total_centi_units > 0 else 0.0
		material_entries[material_variant_id] = entry
	return {
		"total_rough_volume_cell_equivalents": total_volume_cell_equivalents,
		"total_rough_material_centi_units": total_centi_units,
		"total_rough_material_units": float(total_centi_units) / float(MATERIAL_UNIT_SCALE),
		"materials": material_entries,
	}


func _build_spatial_usage_summary_from_cell_materials(
	cell_materials: Dictionary,
	sample_cell_size_meters: float,
	authority_source: StringName
) -> Dictionary:
	if sample_cell_size_meters <= 0.0 or cell_materials.is_empty():
		return {
			"ok": false,
			"reason": &"spatial_usage_occupancy_empty",
		}
	var sample_volume_cell_equivalents := pow(
		sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS,
		3.0
	)
	var material_entries: Dictionary = {}
	var occupied_cell_count := 0
	for cell_key_variant: Variant in cell_materials.keys():
		if cell_key_variant is not Vector3i:
			continue
		var cell_key := cell_key_variant as Vector3i
		var material_variant_id := StringName(cell_materials.get(
			cell_key,
			StringName()
		))
		if material_variant_id == StringName():
			continue
		var cell_center_meters := _sample_center_from_index(
			cell_key.x,
			cell_key.y,
			cell_key.z,
			sample_cell_size_meters
		)
		var material_entry: Dictionary = material_entries.get(
			material_variant_id,
			{
				"material_variant_id": material_variant_id,
				"rough_spatial_sample_count": 0,
				"rough_volume_cell_equivalents": 0.0,
				"rough_spatial_position_sum_meters": Vector3.ZERO,
				"rough_spatial_centroid_meters": Vector3.ZERO,
				"rough_spatial_position_origin_id": (
					CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
				),
			}
		) as Dictionary
		var next_sample_count := int(material_entry.get(
			"rough_spatial_sample_count",
			0
		)) + 1
		var next_position_sum := (
			material_entry.get(
				"rough_spatial_position_sum_meters",
				Vector3.ZERO
			) as Vector3
		) + cell_center_meters
		material_entry["rough_spatial_sample_count"] = next_sample_count
		material_entry["rough_volume_cell_equivalents"] = (
			float(next_sample_count) * sample_volume_cell_equivalents
		)
		material_entry["rough_spatial_position_sum_meters"] = next_position_sum
		material_entry["rough_spatial_centroid_meters"] = (
			next_position_sum / float(next_sample_count)
		)
		material_entries[material_variant_id] = material_entry
		occupied_cell_count += 1
	if material_entries.is_empty() or occupied_cell_count <= 0:
		return {
			"ok": false,
			"reason": &"spatial_usage_materials_empty",
		}
	return {
		"ok": true,
		"reason": &"none",
		"spatial_material_positions_valid": true,
		"spatial_authority_source": authority_source,
		"spatial_positions_origin_id": CombatOriginRecordScript.ORIGIN_WEAPON_ROOT,
		"resolver_sample_cell_size_meters": sample_cell_size_meters,
		"spatial_occupied_cell_count": occupied_cell_count,
		"total_rough_volume_cell_equivalents": (
			float(occupied_cell_count) * sample_volume_cell_equivalents
		),
		"materials": material_entries,
	}

func _build_usage_summary_from_material_cell_counts(
	material_cell_counts: Dictionary,
	sample_volume_cell_equivalents: float
) -> Dictionary:
	var material_entries: Dictionary = {}
	var total_centi_units := 0
	var total_volume_cell_equivalents := 0.0
	for material_variant: Variant in material_cell_counts.keys():
		var material_variant_id := StringName(material_variant)
		var cell_count := maxi(int(material_cell_counts[material_variant]), 0)
		if material_variant_id == StringName() or cell_count <= 0:
			continue
		var volume_cell_equivalents := (
			float(cell_count) * sample_volume_cell_equivalents
		)
		var material_centi_units := (
			_material_centi_units_from_volume_cell_equivalents(
				volume_cell_equivalents
			)
		)
		material_entries[material_variant_id] = {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": volume_cell_equivalents,
			"rough_material_centi_units": material_centi_units,
			"rough_material_units": (
				float(material_centi_units) / float(MATERIAL_UNIT_SCALE)
			),
			"ratio": 0.0,
		}
		total_centi_units += material_centi_units
		total_volume_cell_equivalents += volume_cell_equivalents
	for material_variant_id: StringName in material_entries.keys():
		var entry: Dictionary = material_entries[material_variant_id]
		entry["ratio"] = (
			float(entry.get("rough_material_centi_units", 0))
			/ float(total_centi_units)
			if total_centi_units > 0
			else 0.0
		)
		material_entries[material_variant_id] = entry
	return {
		"total_rough_volume_cell_equivalents": total_volume_cell_equivalents,
		"total_rough_material_centi_units": total_centi_units,
		"total_rough_material_units": (
			float(total_centi_units) / float(MATERIAL_UNIT_SCALE)
		),
		"materials": material_entries,
	}

func resolve_add_material_groups(add_bodies: Array) -> Dictionary:
	var add_bodies_by_material: Dictionary = {}
	for body: Variant in add_bodies:
		if body == null:
			continue
		_normalize_body_entry(body)
		var material_variant_id: StringName = _read_body_string_name(body, "material_variant_id")
		var grouped_bodies: Array = add_bodies_by_material.get(material_variant_id, []) as Array
		grouped_bodies.append(body)
		add_bodies_by_material[material_variant_id] = grouped_bodies
	return resolve_grouped_add_material_bodies(add_bodies_by_material)

func resolve_grouped_add_material_bodies(add_bodies_by_material: Dictionary) -> Dictionary:
	var resolved_groups: Dictionary = {}
	for material_variant_id: StringName in add_bodies_by_material.keys():
		var add_bodies: Array = add_bodies_by_material.get(material_variant_id, []) as Array
		var volume_cell_equivalents: float = estimate_same_material_union_volume_cell_equivalents(add_bodies)
		resolved_groups[material_variant_id] = {
			"material_variant_id": material_variant_id,
			"rough_volume_cell_equivalents": volume_cell_equivalents,
		}
	return resolved_groups

func estimate_same_material_union_volume_cell_equivalents(add_bodies: Array) -> float:
	if add_bodies.is_empty():
		return 0.0
	var sample_cell_size_meters: float = _resolve_group_sample_cell_size(add_bodies)
	var sample_volume_cell_equivalents: float = pow(sample_cell_size_meters / REFERENCE_CELL_WORLD_SIZE_METERS, 3.0)
	var occupied_cells: Dictionary = {}
	for body: Variant in add_bodies:
		if body == null:
			continue
		_normalize_body_entry(body)
		var amount_ratio: float = 1.0
		if _is_profile_body_shape(body):
			_mark_profile_path_cells(occupied_cells, body, amount_ratio, sample_cell_size_meters)
			continue
		var radius_meters: float = maxf(_read_body_float(body, "radius_meters", 0.001), 0.001)
		var body_points: PackedVector3Array = _resolve_body_sample_points(body, sample_cell_size_meters)
		if body_points.is_empty():
			continue
		if body_points.size() == 1:
			_mark_sphere_cells(occupied_cells, body_points[0], radius_meters, amount_ratio, sample_cell_size_meters)
			continue
		for point_index in range(body_points.size() - 1):
			_mark_capsule_segment_cells(
				occupied_cells,
				body_points[point_index],
				body_points[point_index + 1],
				radius_meters,
				amount_ratio,
				sample_cell_size_meters
			)
	var volume_cell_equivalents := 0.0
	for cell_key: Vector3i in occupied_cells.keys():
		volume_cell_equivalents += float(occupied_cells.get(cell_key, 0.0)) * sample_volume_cell_equivalents
	return volume_cell_equivalents

func _resolve_group_sample_cell_size(add_bodies: Array) -> float:
	var min_radius_meters := INF
	for body: Variant in add_bodies:
		if body == null:
			continue
		min_radius_meters = minf(min_radius_meters, maxf(_read_body_float(body, "radius_meters", 0.001), 0.001))
	if min_radius_meters == INF:
		min_radius_meters = REFERENCE_CELL_WORLD_SIZE_METERS
	return clampf(
		min_radius_meters * SAMPLE_RADIUS_RATIO,
		SAMPLE_CELL_SIZE_MIN_METERS,
		SAMPLE_CELL_SIZE_MAX_METERS
	)

func _collect_body_occupied_cells(body: Variant, sample_cell_size_meters: float) -> Dictionary:
	var occupied_cells: Dictionary = {}
	if _is_profile_body_shape(body):
		_mark_profile_path_cells(occupied_cells, body, 1.0, sample_cell_size_meters)
		return occupied_cells
	var radius_meters: float = maxf(_read_body_float(body, "radius_meters", 0.001), 0.001)
	var body_points: PackedVector3Array = _resolve_body_sample_points(body, sample_cell_size_meters)
	if body_points.is_empty():
		return occupied_cells
	if body_points.size() == 1:
		_mark_sphere_cells(occupied_cells, body_points[0], radius_meters, 1.0, sample_cell_size_meters)
		return occupied_cells
	for point_index in range(body_points.size() - 1):
		_mark_capsule_segment_cells(
			occupied_cells,
			body_points[point_index],
			body_points[point_index + 1],
			radius_meters,
			1.0,
			sample_cell_size_meters
		)
	return occupied_cells

func _resolve_body_sample_points(body: Variant, sample_cell_size_meters: float) -> PackedVector3Array:
	if body == null:
		return PackedVector3Array()
	var path_points: PackedVector3Array = _read_body_path_points(body)
	if path_points.size() < 2:
		return _deduplicate_points(path_points)
	var shape_kind: StringName = _read_body_string_name(body, "shape_kind")
	if (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_CAPSULE_PATH
		or shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	):
		var curve: Curve3D = _build_spline_curve(path_points, _resolve_body_bake_interval(path_points, sample_cell_size_meters))
		var baked_points: PackedVector3Array = curve.get_baked_points()
		if baked_points.size() >= 2:
			return _deduplicate_points(baked_points)
	return _deduplicate_points(path_points)

func _is_profile_body_shape(body: Variant) -> bool:
	var shape_kind: StringName = _read_body_string_name(body, "shape_kind")
	return (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		or shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH
	)

func _mark_profile_path_cells(
	occupied_cells: Dictionary,
	body: Variant,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	var body_points: PackedVector3Array = _resolve_body_sample_points(body, sample_cell_size_meters)
	if body_points.size() < 2:
		return
	var profile_polygon: PackedVector2Array = _resolve_body_profile_polygon(body)
	if profile_polygon.size() < 3:
		return
	var source_points: PackedVector3Array = _read_body_path_points(body)
	var source_surface_normals: PackedVector3Array = _read_body_vector3_array(
		body,
		"path_surface_normals"
	)
	var source_contact_directions: PackedVector3Array = _read_body_vector3_array(
		body,
		"path_contact_directions"
	)
	var contact_direction := _read_body_vector2(
		body,
		"profile_contact_direction_2d",
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	)
	var rotation_bias_degrees := _read_body_float(
		body,
		"profile_rotation_bias_degrees",
		0.0
	)
	var contact_point_relative := _read_body_vector2(
		body,
		"profile_contact_point_relative_2d_meters",
		Vector2.ZERO
	)
	var use_compiled_orientation := (
		int(_read_body_variant(
			body,
			"profile_runtime_schema_version",
			0
		)) > 0
	)
	var shape_kind := _read_body_string_name(body, "shape_kind")
	var body_kind := _read_body_string_name(body, "body_kind")
	var uses_explicit_surface_frame := (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		and use_compiled_orientation
		and (
			body_kind == ForgeV2MaterialBodyScript.BODY_KIND_VOLUME_STROKE
			or body_kind
			== ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH
		)
		and source_contact_directions.size() >= source_points.size()
	)
	var has_aligned_linear_normals := (
		shape_kind == ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH
		and body_points.size() == source_points.size()
		and source_surface_normals.size() >= source_points.size()
	)
	for point_index in range(body_points.size() - 1):
		var surface_normal := Vector3.FORWARD
		var explicit_contact_direction := Vector3.ZERO
		var explicit_from_axis_x := Vector3.ZERO
		var explicit_from_axis_y := Vector3.ZERO
		var explicit_to_axis_x := Vector3.ZERO
		var explicit_to_axis_y := Vector3.ZERO
		var uses_aligned_segment := false
		if use_compiled_orientation:
			uses_aligned_segment = (
				has_aligned_linear_normals
				and body_points[point_index].is_equal_approx(
					source_points[point_index]
				)
				and body_points[point_index + 1].is_equal_approx(
					source_points[point_index + 1]
				)
			)
			if uses_aligned_segment:
				surface_normal = (
					ForgeV2ProfileShapeLibraryScript.interpolate_path_surface_normal(
						source_surface_normals,
						point_index,
						0.5
					)
				)
			else:
				surface_normal = (
					ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
						(
							body_points[point_index]
							+ body_points[point_index + 1]
						) * 0.5,
						source_points,
						source_surface_normals
					)
				)
			if uses_explicit_surface_frame:
				if uses_aligned_segment:
					var from_frame := (
						ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
							ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
								source_points,
								point_index
							),
							source_surface_normals[point_index],
							contact_direction,
							contact_point_relative,
							source_contact_directions[point_index],
							rotation_bias_degrees
						)
					)
					var to_frame := (
						ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
							ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
								source_points,
								point_index + 1
							),
							source_surface_normals[point_index + 1],
							contact_direction,
							contact_point_relative,
							source_contact_directions[point_index + 1],
							rotation_bias_degrees
						)
					)
					explicit_from_axis_x = from_frame.get(
						"axis_x",
						Vector3.ZERO
					) as Vector3
					explicit_from_axis_y = from_frame.get(
						"axis_y",
						Vector3.ZERO
					) as Vector3
					explicit_to_axis_x = to_frame.get(
						"axis_x",
						Vector3.ZERO
					) as Vector3
					explicit_to_axis_y = to_frame.get(
						"axis_y",
						Vector3.ZERO
					) as Vector3
				else:
					explicit_contact_direction = (
						ForgeV2ProfileShapeLibraryScript.resolve_path_surface_normal(
							(
								body_points[point_index]
								+ body_points[point_index + 1]
							) * 0.5,
							source_points,
							source_contact_directions
						)
					)
		_mark_profile_segment_cells(
			occupied_cells,
			body_points[point_index],
			body_points[point_index + 1],
			profile_polygon,
			amount_ratio,
			sample_cell_size_meters,
			surface_normal,
			contact_direction,
			contact_point_relative,
			explicit_contact_direction,
			rotation_bias_degrees,
			use_compiled_orientation,
			uses_explicit_surface_frame,
			explicit_from_axis_x,
			explicit_from_axis_y,
			explicit_to_axis_x,
			explicit_to_axis_y
		)

func _mark_profile_segment_cells(
	occupied_cells: Dictionary,
	from_point: Vector3,
	to_point: Vector3,
	profile_polygon: PackedVector2Array,
	amount_ratio: float,
	sample_cell_size_meters: float,
	surface_normal: Vector3 = Vector3.FORWARD,
	contact_direction_2d: Vector2 = (
		ForgeV2ProfileShapeLibraryScript.BASIC_PROFILE_LOCAL_SIX
	),
	contact_point_relative_2d_meters: Vector2 = Vector2.ZERO,
	explicit_contact_direction: Vector3 = Vector3.ZERO,
	rotation_bias_degrees: float = 0.0,
	use_compiled_orientation: bool = false,
	use_explicit_surface_frame: bool = false,
	explicit_from_axis_x: Vector3 = Vector3.ZERO,
	explicit_from_axis_y: Vector3 = Vector3.ZERO,
	explicit_to_axis_x: Vector3 = Vector3.ZERO,
	explicit_to_axis_y: Vector3 = Vector3.ZERO
) -> void:
	var segment: Vector3 = to_point - from_point
	var segment_length: float = segment.length()
	if segment_length <= 0.000001:
		return
	var tangent: Vector3 = segment / segment_length
	var normal: Vector3 = _resolve_perpendicular_normal(tangent)
	var binormal: Vector3 = tangent.cross(normal).normalized()
	var use_interpolated_explicit_frames := (
		use_explicit_surface_frame
		and explicit_from_axis_x.length_squared() > 0.000001
		and explicit_from_axis_y.length_squared() > 0.000001
		and explicit_to_axis_x.length_squared() > 0.000001
		and explicit_to_axis_y.length_squared() > 0.000001
	)
	if use_explicit_surface_frame and not use_interpolated_explicit_frames:
		var explicit_frame := (
			ForgeV2ProfileShapeLibraryScript.resolve_explicit_surface_profile_path_frame(
				tangent,
				surface_normal,
				contact_direction_2d,
				contact_point_relative_2d_meters,
				explicit_contact_direction,
				rotation_bias_degrees
			)
		)
		normal = explicit_frame.get("axis_x", normal) as Vector3
		binormal = explicit_frame.get("axis_y", binormal) as Vector3
	elif use_compiled_orientation:
		var frame := ForgeV2ProfileShapeLibraryScript.resolve_profile_path_frame(
			tangent,
			surface_normal,
			contact_direction_2d,
			rotation_bias_degrees
		)
		normal = frame.get("axis_x", normal) as Vector3
		binormal = frame.get("axis_y", binormal) as Vector3
	var profile_radius: float = maxf(
		ForgeV2ProfileShapeLibraryScript.calculate_polygon_max_radius_meters(profile_polygon),
		0.001
	)
	var min_point: Vector3
	var max_point: Vector3
	if use_interpolated_explicit_frames:
		min_point = Vector3(INF, INF, INF)
		max_point = Vector3(-INF, -INF, -INF)
		for profile_point: Vector2 in profile_polygon:
			for ring_point: Vector3 in [
				(
					from_point
					+ explicit_from_axis_x * profile_point.x
					+ explicit_from_axis_y * profile_point.y
				),
				(
					to_point
					+ explicit_to_axis_x * profile_point.x
					+ explicit_to_axis_y * profile_point.y
				),
			]:
				min_point.x = minf(min_point.x, ring_point.x)
				min_point.y = minf(min_point.y, ring_point.y)
				min_point.z = minf(min_point.z, ring_point.z)
				max_point.x = maxf(max_point.x, ring_point.x)
				max_point.y = maxf(max_point.y, ring_point.y)
				max_point.z = maxf(max_point.z, ring_point.z)
	else:
		min_point = Vector3(
			minf(from_point.x, to_point.x) - profile_radius,
			minf(from_point.y, to_point.y) - profile_radius,
			minf(from_point.z, to_point.z) - profile_radius
		)
		max_point = Vector3(
			maxf(from_point.x, to_point.x) + profile_radius,
			maxf(from_point.y, to_point.y) + profile_radius,
			maxf(from_point.z, to_point.z) + profile_radius
		)
	var min_index: Vector3i = _sample_index_floor(min_point, sample_cell_size_meters)
	var max_index: Vector3i = _sample_index_floor(max_point, sample_cell_size_meters)
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(x_index, y_index, z_index, sample_cell_size_meters)
				var relative_position: Vector3 = sample_position - from_point
				var distance_along_path: float = relative_position.dot(tangent)
				if distance_along_path < 0.0 or distance_along_path > segment_length:
					continue
				var profile_center: Vector3 = from_point + tangent * distance_along_path
				var lateral_position: Vector3 = sample_position - profile_center
				var profile_point: Vector2
				if use_interpolated_explicit_frames:
					var segment_ratio := clampf(
						distance_along_path / segment_length,
						0.0,
						1.0
					)
					var axis_x := explicit_from_axis_x.lerp(
						explicit_to_axis_x,
						segment_ratio
					)
					var axis_y := explicit_from_axis_y.lerp(
						explicit_to_axis_y,
						segment_ratio
					)
					var axis_x_squared := axis_x.dot(axis_x)
					var axis_x_axis_y := axis_x.dot(axis_y)
					var axis_y_squared := axis_y.dot(axis_y)
					var gram_determinant := (
						axis_x_squared * axis_y_squared
						- axis_x_axis_y * axis_x_axis_y
					)
					if gram_determinant <= 0.000000000001:
						continue
					var lateral_axis_x := lateral_position.dot(axis_x)
					var lateral_axis_y := lateral_position.dot(axis_y)
					profile_point = Vector2(
						(
							lateral_axis_x * axis_y_squared
							- lateral_axis_y * axis_x_axis_y
						) / gram_determinant,
						(
							lateral_axis_y * axis_x_squared
							- lateral_axis_x * axis_x_axis_y
						) / gram_determinant
					)
				else:
					profile_point = Vector2(
						lateral_position.dot(normal),
						lateral_position.dot(binormal)
					)
				if not _profile_polygon_contains_point(profile_polygon, profile_point):
					continue
				_mark_cell(occupied_cells, x_index, y_index, z_index, amount_ratio)

func _resolve_body_profile_polygon(body: Variant) -> PackedVector2Array:
	var profile_polygon: PackedVector2Array = _read_body_vector2_array(body, "profile_polygon_2d_meters")
	if profile_polygon.size() >= 3:
		return profile_polygon
	var radius_meters: float = maxf(_read_body_float(body, "radius_meters", 0.001), 0.001)
	var profile_id: StringName = _read_body_string_name(body, "profile_id")
	if profile_id != StringName():
		return ForgeV2ProfileShapeLibraryScript.resolve_profile_polygon(profile_id, radius_meters)
	return ForgeV2ProfileShapeLibraryScript.build_circle_polygon(radius_meters)

func _resolve_perpendicular_normal(tangent: Vector3) -> Vector3:
	var reference_axis := Vector3.UP
	if absf(tangent.normalized().dot(reference_axis)) > 0.95:
		reference_axis = Vector3.RIGHT
	var normal := reference_axis.cross(tangent).normalized()
	if normal.length_squared() <= 0.000001:
		return Vector3.FORWARD
	return normal

func _profile_polygon_contains_point(polygon: PackedVector2Array, point: Vector2) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for point_index in range(polygon.size()):
		var current_point: Vector2 = polygon[point_index]
		var previous_point: Vector2 = polygon[previous_index]
		if _distance_squared_to_2d_segment(point, current_point, previous_point) <= 0.00000001:
			return true
		var crosses_y := (current_point.y > point.y) != (previous_point.y > point.y)
		if crosses_y:
			var denominator := previous_point.y - current_point.y
			if absf(denominator) > 0.000001:
				var intersect_x := (
					(previous_point.x - current_point.x)
					* (point.y - current_point.y)
					/ denominator
					+ current_point.x
				)
				if point.x < intersect_x:
					inside = not inside
		previous_index = point_index
	return inside

func _distance_squared_to_2d_segment(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment: Vector2 = to_point - from_point
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.000001:
		return point.distance_squared_to(from_point)
	var segment_ratio: float = clampf((point - from_point).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_squared_to(from_point + segment * segment_ratio)

func _resolve_body_bake_interval(path_points: PackedVector3Array, sample_cell_size_meters: float) -> float:
	var path_length: float = _calculate_polyline_length(path_points)
	if path_length <= 0.0:
		return maxf(sample_cell_size_meters, 0.001)
	return maxf(sample_cell_size_meters, path_length / float(MAX_BODY_SAMPLE_SEGMENTS))

func _calculate_polyline_length(path_points: PackedVector3Array) -> float:
	var path_length := 0.0
	for point_index in range(path_points.size() - 1):
		path_length += path_points[point_index].distance_to(path_points[point_index + 1])
	return path_length

func _mark_capsule_segment_cells(
	occupied_cells: Dictionary,
	from_point: Vector3,
	to_point: Vector3,
	radius_meters: float,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	if from_point.distance_squared_to(to_point) <= 0.000001:
		_mark_sphere_cells(occupied_cells, from_point, radius_meters, amount_ratio, sample_cell_size_meters)
		return
	var min_point: Vector3 = Vector3(
		minf(from_point.x, to_point.x) - radius_meters,
		minf(from_point.y, to_point.y) - radius_meters,
		minf(from_point.z, to_point.z) - radius_meters
	)
	var max_point: Vector3 = Vector3(
		maxf(from_point.x, to_point.x) + radius_meters,
		maxf(from_point.y, to_point.y) + radius_meters,
		maxf(from_point.z, to_point.z) + radius_meters
	)
	var min_index: Vector3i = _sample_index_floor(min_point, sample_cell_size_meters)
	var max_index: Vector3i = _sample_index_floor(max_point, sample_cell_size_meters)
	var radius_squared: float = radius_meters * radius_meters
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(x_index, y_index, z_index, sample_cell_size_meters)
				if _distance_squared_to_segment(sample_position, from_point, to_point) > radius_squared:
					continue
				_mark_cell(occupied_cells, x_index, y_index, z_index, amount_ratio)

func _mark_sphere_cells(
	occupied_cells: Dictionary,
	center_point: Vector3,
	radius_meters: float,
	amount_ratio: float,
	sample_cell_size_meters: float
) -> void:
	var min_index: Vector3i = _sample_index_floor(center_point - Vector3.ONE * radius_meters, sample_cell_size_meters)
	var max_index: Vector3i = _sample_index_floor(center_point + Vector3.ONE * radius_meters, sample_cell_size_meters)
	var radius_squared: float = radius_meters * radius_meters
	for x_index in range(min_index.x, max_index.x + 1):
		for y_index in range(min_index.y, max_index.y + 1):
			for z_index in range(min_index.z, max_index.z + 1):
				var sample_position := _sample_center_from_index(x_index, y_index, z_index, sample_cell_size_meters)
				if sample_position.distance_squared_to(center_point) > radius_squared:
					continue
				_mark_cell(occupied_cells, x_index, y_index, z_index, amount_ratio)

func _mark_cell(
	occupied_cells: Dictionary,
	x_index: int,
	y_index: int,
	z_index: int,
	amount_ratio: float
) -> void:
	var key := Vector3i(x_index, y_index, z_index)
	occupied_cells[key] = maxf(float(occupied_cells.get(key, 0.0)), amount_ratio)

func _sample_index_floor(point: Vector3, sample_cell_size_meters: float) -> Vector3i:
	return Vector3i(
		int(floor(point.x / sample_cell_size_meters)),
		int(floor(point.y / sample_cell_size_meters)),
		int(floor(point.z / sample_cell_size_meters))
	)

func _sample_center_from_index(x_index: int, y_index: int, z_index: int, sample_cell_size_meters: float) -> Vector3:
	return Vector3(
		(float(x_index) + 0.5) * sample_cell_size_meters,
		(float(y_index) + 0.5) * sample_cell_size_meters,
		(float(z_index) + 0.5) * sample_cell_size_meters
	)

func _distance_squared_to_segment(point: Vector3, from_point: Vector3, to_point: Vector3) -> float:
	var segment: Vector3 = to_point - from_point
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.000001:
		return point.distance_squared_to(from_point)
	var segment_ratio: float = clampf((point - from_point).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_squared_to(from_point + segment * segment_ratio)

func _build_spline_curve(spline_points: PackedVector3Array, bake_interval: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = maxf(bake_interval, 0.001)
	var control_points := _deduplicate_points(spline_points)
	for point_index in range(control_points.size()):
		curve.add_point(
			control_points[point_index],
			_resolve_spline_auto_curve_handle(control_points, point_index, true),
			_resolve_spline_auto_curve_handle(control_points, point_index, false)
		)
	return curve

func _resolve_spline_auto_curve_handle(
	points: PackedVector3Array,
	point_index: int,
	use_in_handle: bool
) -> Vector3:
	if point_index < 0 or point_index >= points.size():
		return Vector3.ZERO
	var current_position: Vector3 = points[point_index]
	var previous_position: Variant = null
	var next_position: Variant = null
	if point_index > 0:
		previous_position = points[point_index - 1]
	if point_index < points.size() - 1:
		next_position = points[point_index + 1]
	var auto_handle := Vector3.ZERO
	if previous_position is Vector3 and next_position is Vector3:
		var smooth_tangent: Vector3 = ((next_position as Vector3) - (previous_position as Vector3)) * SPLINE_AUTO_CURVE_MIDDLE_STRENGTH
		auto_handle = -smooth_tangent if use_in_handle else smooth_tangent
	elif use_in_handle and previous_position is Vector3:
		auto_handle = ((previous_position as Vector3) - current_position) * SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH
	elif not use_in_handle and next_position is Vector3:
		auto_handle = ((next_position as Vector3) - current_position) * SPLINE_AUTO_CURVE_ENDPOINT_STRENGTH
	if auto_handle.length() < SPLINE_AUTO_CURVE_HANDLE_MIN_LENGTH_METERS:
		return Vector3.ZERO
	return auto_handle

func _deduplicate_points(points: PackedVector3Array) -> PackedVector3Array:
	var deduplicated := PackedVector3Array()
	for point: Vector3 in points:
		if not deduplicated.is_empty() and deduplicated[deduplicated.size() - 1].distance_squared_to(point) <= 0.000001:
			continue
		deduplicated.append(point)
	return deduplicated

func _normalize_body_entry(body: Variant) -> void:
	if body is Resource and body.has_method("normalize"):
		body.call("normalize")

func _is_body_entry_active(body: Variant) -> bool:
	var layer_active_value: Variant = _read_body_variant(body, "layer_active", true)
	return not (layer_active_value is bool) or bool(layer_active_value)

func _read_body_variant(body: Variant, field_name: String, default_value: Variant = null) -> Variant:
	if body is Resource:
		var resource := body as Resource
		var value: Variant = resource.get(field_name)
		return default_value if value == null else value
	if body is Dictionary:
		return (body as Dictionary).get(field_name, default_value)
	return default_value

func _read_body_string_name(body: Variant, field_name: String, default_value: StringName = StringName()) -> StringName:
	return StringName(_read_body_variant(body, field_name, default_value))

func _read_body_float(body: Variant, field_name: String, default_value: float = 0.0) -> float:
	return float(_read_body_variant(body, field_name, default_value))

func _read_body_path_points(body: Variant) -> PackedVector3Array:
	var value: Variant = _read_body_variant(body, "path_points", PackedVector3Array())
	if value is PackedVector3Array:
		return value as PackedVector3Array
	return PackedVector3Array()

func _read_body_vector2_array(body: Variant, field_name: String) -> PackedVector2Array:
	var value: Variant = _read_body_variant(body, field_name, PackedVector2Array())
	if value is PackedVector2Array:
		return value as PackedVector2Array
	return PackedVector2Array()

func _read_body_vector3_array(
	body: Variant,
	field_name: String
) -> PackedVector3Array:
	var value: Variant = _read_body_variant(
		body,
		field_name,
		PackedVector3Array()
	)
	if value is PackedVector3Array:
		return value as PackedVector3Array
	return PackedVector3Array()

func _read_body_vector2(
	body: Variant,
	field_name: String,
	default_value: Vector2 = Vector2.ZERO
) -> Vector2:
	var value: Variant = _read_body_variant(body, field_name, default_value)
	return value as Vector2 if value is Vector2 else default_value

func _material_centi_units_from_volume_cell_equivalents(volume_cell_equivalents: float) -> int:
	var raw_material_units: float = maxf(volume_cell_equivalents, 0.0) / CELL_EQUIVALENTS_PER_MATERIAL_UNIT
	var material_centi_units: int = int(round(raw_material_units * float(MATERIAL_UNIT_SCALE)))
	if volume_cell_equivalents > 0.0:
		material_centi_units = maxi(material_centi_units, 1)
	return material_centi_units
