extends "res://runtime/player/grip/exact_cached_planar_skin_overlap_budget.gd"

## Same validation, exact memoization and section policy; one numerical backend
## per cache miss. Native target memory lives only for this synchronous batch.
## Each acquisition worker owns its own instance, including the native object.
var _kernel: RefCounted
var _native_requested := false
var _native_target_handle := 0
var _native_query_depth := 0
var _native_stats := {"segment_calls":0,"segment_us":0,"target_preparations":0,
	"target_preparation_us":0,"fallback_calls":0,"last_fallback_reason":""}


func configure_native_kernel(enabled: bool) -> bool:
	if _active or _native_query_depth != 0: return false
	clear_cache()
	_native_requested = enabled
	if not enabled:
		_kernel = null
		return true
	if not ClassDB.class_exists(&"GripContactKernel"):
		_kernel = null
		return false
	_kernel = ClassDB.instantiate(&"GripContactKernel") as RefCounted
	return _kernel != null


func clear_cache() -> bool:
	if not super.clear_cache(): return false
	if _kernel != null: _kernel.clear_targets()
	_native_target_handle = 0
	_native_stats = {"segment_calls":0,"segment_us":0,"target_preparations":0,
		"target_preparation_us":0,"fallback_calls":0,"last_fallback_reason":""}
	return true


func cache_statistics() -> Dictionary:
	var result := super.cache_statistics()
	result["contact_backend"] = "cpp" if _kernel != null and _native_requested else "gdscript"
	result["native_requested"] = _native_requested
	result["native_kernel"] = _native_stats.duplicate(true)
	result["native_target_lifetime"] = "one synchronous evaluate_segments batch; instance owned"
	return result


func evaluate_segments(segments: Array, target: Dictionary, plane_origin_id: StringName, config: Dictionary = {}) -> Dictionary:
	_native_query_depth += 1
	# A reentrant query uses the reference path through _cache_suspension. It
	# cannot borrow the outer batch's target or replace its prepared snapshot.
	if _native_query_depth == 1:
		_native_target_handle = 0
		if _kernel != null: _kernel.clear_targets()
	var result := super.evaluate_segments(segments, target, plane_origin_id, config)
	_native_query_depth -= 1
	if _native_query_depth == 0:
		if _kernel != null: _kernel.clear_targets()
		_native_target_handle = 0
	return result


func _solve_segment(segment: Dictionary, target: Dictionary, tolerance: float, epsilon: float, budget: int, refine_after_cap: bool, use_boundary_pruning: bool) -> Dictionary:
	if not _native_requested or _kernel == null or not _active or _cache_suspension != 0:
		if _native_requested and _kernel == null: _fallback("native_extension_unavailable")
		return super._solve_segment(segment, target, tolerance, epsilon, budget, refine_after_cap, use_boundary_pruning)
	if _native_target_handle == 0:
		var preparation_started := Time.get_ticks_usec()
		_native_target_handle = int(_kernel.prepare_target(target))
		_native_stats.target_preparations += 1
		_native_stats.target_preparation_us += Time.get_ticks_usec() - preparation_started
		if _native_target_handle == 0: _native_target_handle = -1
	if _native_target_handle < 0:
		_fallback("native_prepared_target_rejected")
		return super._solve_segment(segment, target, tolerance, epsilon, budget, refine_after_cap, use_boundary_pruning)
	var started := Time.get_ticks_usec()
	var result: Dictionary = _kernel.evaluate_segment(segment, _native_target_handle,
		tolerance, epsilon, budget, refine_after_cap, use_boundary_pruning)
	_native_stats.segment_us += Time.get_ticks_usec() - started
	_native_stats.segment_calls += 1
	if not result.get("valid", false):
		_fallback(str(result.get("reason", "native_segment_rejected")))
		return super._solve_segment(segment, target, tolerance, epsilon, budget, refine_after_cap, use_boundary_pruning)
	# Keep the established chronology honest: actual compiled calculations add
	# work, cache hits do not. Timers never enter geometric packets/cache keys.
	if not _chronology_context.is_empty():
		var phases: Dictionary = _kernel.last_phase_timings_us()
		for field: String in ["boundary_intersections_us", "depth_sampling_refinement_us", "nearest_contact_us"]:
			_chronology_context[field] += int(phases.get(field, 0))
		_chronology_context.actual_segment_calls += 1
		_chronology_context.actual_depth_evaluations += int(result.depth_evaluations)
		for field: String in result.work_counts:
			_chronology_context.actual_work_counts[field] = int(_chronology_context.actual_work_counts.get(field, 0)) + int(result.work_counts[field])
	return result


func _fallback(reason: String) -> void:
	_native_stats.fallback_calls += 1
	_native_stats.last_fallback_reason = reason
