extends "res://runtime/player/grip/planar_skin_overlap_budget.gd"

## Opt-in exact memoization, with unchanged parent validation,
## geometry arithmetic, budgets, returned work counts, and acceptance rules.
## Consumers explicitly begin an acquisition; calls without an epoch bypass reuse.
const CACHE_REVISION := &"exact_planar_segment_memoization_v2"
var cache_enabled: bool = true
var maximum_entries: int = 8192
var maximum_accounted_bytes: int = 32 * 1024 * 1024
var maximum_targets: int = 128
var maximum_target_bytes: int = 8 * 1024 * 1024
var _acquisition_id: StringName = &""
var _active: bool = false
var _cache_suspension: int = 0
var _target_key: String = ""
var _target_exact_key: String = ""
var _target_accounted_bytes: int = 0
var _target_is_new: bool = false
var _targets: Dictionary = {}
var _next_target_id: int = 1
var _retained_target_bytes: int = 0
var _entries: Dictionary = {}
var _fifo: Array[String] = []
var _retained_bytes: int = 0
var _pending: Dictionary = {}
var _pending_bytes: int = 0
var _statistics: Dictionary = {}

func _init() -> void:
	_reset_statistics()

func begin_acquisition(identity: StringName) -> bool:
	if _active or identity==&"": return false
	clear_cache()
	_acquisition_id=identity
	return true

func configure_cache(entry_limit: int, byte_limit: int, target_limit: int = 128, target_byte_limit: int = 8 * 1024 * 1024) -> bool:
	if _active or entry_limit<1 or byte_limit<1 or target_limit<1 or target_byte_limit<1: return false
	clear_cache()
	maximum_entries=entry_limit; maximum_accounted_bytes=byte_limit
	maximum_targets=target_limit; maximum_target_bytes=target_byte_limit
	return true

func clear_cache() -> bool:
	if _active: return false
	_entries.clear(); _fifo.clear(); _pending.clear()
	_retained_bytes=0; _pending_bytes=0; _target_key=""; _acquisition_id=&""
	_targets.clear(); _retained_target_bytes=0; _next_target_id=1
	_target_exact_key=""; _target_accounted_bytes=0; _target_is_new=false
	_reset_statistics()
	return true

func cache_statistics() -> Dictionary:
	var out: Dictionary = _statistics.duplicate(true)
	out["revision"]=CACHE_REVISION; out["acquisition_id"]=_acquisition_id
	out["cache_enabled"]=cache_enabled; out["entry_count"]=_entries.size(); out["pending_entry_count"]=_pending.size()
	out["accounted_bytes"]=_retained_bytes; out["pending_accounted_bytes"]=_pending_bytes
	out["maximum_entries_per_store"]=maximum_entries; out["maximum_accounted_bytes_per_store"]=maximum_accounted_bytes
	out["target_count"]=_targets.size(); out["target_accounted_bytes"]=_retained_target_bytes
	out["active_target_key_accounted_bytes"]=_target_accounted_bytes
	out["pending_new_target"]=_target_is_new
	out["maximum_targets"]=maximum_targets; out["maximum_target_bytes"]=maximum_target_bytes
	out["target_identity"]="complete_serialized_target_as_exact_String_dictionary_key; no_digest_identity; compact_monotonic_ID_in_edge_key"
	out["memory_accounting"]="UTF32_key_bytes_plus_serialized_payload; dictionary/container overhead separately bounded by entry count"
	out["peak_store_bound"]="persistent and transactional edge stores each obey edge limits; target table plus at most one pending target each obey target byte limit"
	return out

func evaluate_segments(segments: Array, target: Dictionary, plane_origin_id: StringName, config: Dictionary = {}) -> Dictionary:
	# This interface is synchronous. Direct/reentrant segment calls bypass caching.
	if _active:
		_cache_suspension+=1
		var nested: Dictionary = super.evaluate_segments(segments,target,plane_origin_id,config)
		_cache_suspension-=1
		return nested
	_statistics.outer_calls+=1
	var started: int = Time.get_ticks_usec()
	_active=true; _pending.clear(); _pending_bytes=0
	_select_target(target)
	# Parent performs every target, plane, configuration and segment check.
	var result: Dictionary = super.evaluate_segments(segments,target,plane_origin_id,config)
	if result.get("valid",false):
		if not _pending.is_empty():
			_commit_target()
			for key: String in _pending: _retain(key,_pending[key])
	else:
		_statistics.invalid_outer_calls+=1
		_statistics.discarded_pending_entries+=_pending.size()
	_pending.clear(); _pending_bytes=0; _target_key=""; _active=false
	_target_exact_key=""; _target_accounted_bytes=0; _target_is_new=false
	_statistics.outer_elapsed_us+=Time.get_ticks_usec()-started
	return result

func _select_target(target: Dictionary) -> void:
	_target_key=""; _target_exact_key=""; _target_accounted_bytes=0; _target_is_new=false
	if not cache_enabled or _acquisition_id==&"": return
	var started: int = Time.get_ticks_usec()
	# Full bytes are represented exactly, not replaced by a collision-prone
	# digest. Dictionary lookup resolves its internal hash collisions by complete
	# String equality. Each target body is retained once, never in edge keys.
	_target_exact_key=var_to_bytes(target).hex_encode()
	_statistics.target_serialization_us+=Time.get_ticks_usec()-started
	_statistics.target_serialization_calls+=1
	_target_accounted_bytes=_target_exact_key.length()*4+8
	if _target_accounted_bytes>maximum_target_bytes:
		_statistics.target_storage_bypasses+=1
		_target_exact_key=""; _target_accounted_bytes=0
		return
	started=Time.get_ticks_usec()
	if _targets.has(_target_exact_key):
		_target_key=str(_targets[_target_exact_key].id)
		_statistics.target_intern_hits+=1
	else:
		# The proposed identity becomes persistent only after outer validation.
		_target_key=str(_next_target_id); _target_is_new=true
		_statistics.target_intern_misses+=1
	_statistics.target_intern_lookup_us+=Time.get_ticks_usec()-started

func _commit_target() -> void:
	if not _target_is_new: return
	if _targets.size()>=maximum_targets or _retained_target_bytes+_target_accounted_bytes>maximum_target_bytes:
		# Deterministic all-table flush cannot leave edges referring to reused
		# identities. IDs remain monotonic until explicit acquisition reset.
		_statistics.target_table_flushes+=1
		_statistics.target_flush_evicted_entries+=_entries.size()
		_statistics.evictions+=_entries.size()
		_entries.clear(); _fifo.clear(); _retained_bytes=0
		_targets.clear(); _retained_target_bytes=0
	_targets[_target_exact_key]={"id":_next_target_id,"accounted_bytes":_target_accounted_bytes}
	_retained_target_bytes+=_target_accounted_bytes; _next_target_id+=1
	_statistics.targets_interned+=1

func _segment(segment: Dictionary, target: Dictionary, tolerance: float, epsilon: float, budget: int, refine_after_cap: bool, use_boundary_pruning: bool) -> Dictionary:
	_statistics.logical_segment_calls+=1
	var use_cache: bool = cache_enabled and _active and _cache_suspension==0 and not _target_key.is_empty() and _acquisition_id!=&""
	var key: String = ""
	if use_cache:
		var started: int = Time.get_ticks_usec()
		key=_target_key+"/"+var_to_bytes([segment,tolerance,epsilon,budget,refine_after_cap,use_boundary_pruning]).hex_encode()
		_statistics.maximum_edge_key_characters=maxi(_statistics.maximum_edge_key_characters,key.length())
		_statistics.segment_key_us+=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec()
		var stored: Dictionary = _entries.get(key,_pending.get(key,{}))
		_statistics.lookup_us+=Time.get_ticks_usec()-started
		if not stored.is_empty():
			_statistics.cache_hits+=1
			started=Time.get_ticks_usec()
			# Deserialization creates independent nested dictionaries/arrays. The
			# parent then appends this call's segment_index to this detached copy.
			var decoded: Dictionary = bytes_to_var(stored.payload)
			_statistics.record_decode_us+=Time.get_ticks_usec()-started
			return decoded
		_statistics.cache_misses+=1
	else:
		_statistics.cache_bypasses+=1
	var solve_started: int = Time.get_ticks_usec()
	var result: Dictionary = _solve_segment(segment,target,tolerance,epsilon,budget,refine_after_cap,use_boundary_pruning)
	_statistics.actual_segment_calls+=1
	_statistics.actual_segment_us+=Time.get_ticks_usec()-solve_started
	_statistics.actual_depth_evaluations+=int(result.get("depth_evaluations",0))
	for name: String in result.get("work_counts",{}):
		var field: String = "actual_"+name
		_statistics[field]=_statistics.get(field,0)+int(result.work_counts[name])
	if use_cache and result.get("valid",false):
		var copy_started: int = Time.get_ticks_usec()
		var detached: Dictionary = result.duplicate(true)
		detached.erase("segment_index")
		var payload: PackedByteArray = var_to_bytes(detached)
		var accounted: int = key.length()*4+payload.size()
		_statistics.record_encode_us+=Time.get_ticks_usec()-copy_started
		if accounted<=maximum_accounted_bytes and _pending.size()<maximum_entries and _pending_bytes+accounted<=maximum_accounted_bytes:
			_pending[key]={"payload":payload,"accounted_bytes":accounted}
			_pending_bytes+=accounted
			_statistics.staged_entries+=1
		else:
			_statistics.unretained_entries+=1
	return result

## Numerical backend seam only. Validation, exact keys and transactional cache
## ownership stay here; the default remains the original script calculation.
func _solve_segment(segment: Dictionary, target: Dictionary, tolerance: float, epsilon: float, budget: int, refine_after_cap: bool, use_boundary_pruning: bool) -> Dictionary:
	return super._segment(segment,target,tolerance,epsilon,budget,refine_after_cap,use_boundary_pruning)

func _retain(key: String, item: Dictionary) -> void:
	if _entries.has(key): return
	var size: int = item.accounted_bytes
	while not _fifo.is_empty() and (_entries.size()>=maximum_entries or _retained_bytes+size>maximum_accounted_bytes):
		var oldest: String = _fifo.pop_front()
		_retained_bytes-=int(_entries[oldest].accounted_bytes)
		_entries.erase(oldest); _statistics.evictions+=1
	_entries[key]=item; _fifo.append(key); _retained_bytes+=size

func _reset_statistics() -> void:
	_statistics={"outer_calls":0,"invalid_outer_calls":0,"logical_segment_calls":0,"actual_segment_calls":0,
		"cache_hits":0,"cache_misses":0,"cache_bypasses":0,"evictions":0,"staged_entries":0,"unretained_entries":0,
		"discarded_pending_entries":0,"target_serialization_us":0,"segment_key_us":0,"lookup_us":0,
		"target_serialization_calls":0,"target_intern_hits":0,"target_intern_misses":0,"targets_interned":0,
		"target_intern_lookup_us":0,"target_storage_bypasses":0,"target_table_flushes":0,"target_flush_evicted_entries":0,"maximum_edge_key_characters":0,
		"record_decode_us":0,"record_encode_us":0,"actual_segment_us":0,"actual_depth_evaluations":0,"outer_elapsed_us":0}
