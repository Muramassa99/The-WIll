extends RefCounted
class_name ForgeV2ActionHistory

## A chronological journal of authored actions.
##
## This container only owns action records. Callers are responsible for
## applying each record's payload before confirming an undo or redo replay.
## A capacity of zero is intentionally unbounded; domain owners may prune a
## confirmed chronological prefix when their own structural checkpoint moves.

const DEFAULT_CAPACITY := 0

const _DIRECTION_UNDO := &"undo"
const _DIRECTION_REDO := &"redo"

var _capacity: int = DEFAULT_CAPACITY
var _undo_records: Array[Dictionary] = []
var _redo_batches: Array[Array] = []
var _active_undo_batch: Array[Dictionary] = []
var _undo_batch_active := false
var _revision: int = 0
var _pending_direction: StringName = StringName()
var _pending_revision: int = -1


func _init(capacity: int = DEFAULT_CAPACITY) -> void:
	_capacity = maxi(capacity, 0)


func get_capacity() -> int:
	return _capacity


func push_action(
	kind: StringName,
	label: String,
	payload: Dictionary = {}
) -> bool:
	return push_record({
		"kind": kind,
		"label": label,
		"payload": payload,
	})


func push_record(record: Dictionary) -> bool:
	var normalized_record := _normalize_record(record)
	if normalized_record.is_empty():
		return false
	# A new authored action deliberately abandons every undone branch, including
	# a held-Undo gesture that has not received its release event yet.
	_redo_batches.clear()
	_active_undo_batch.clear()
	_undo_batch_active = false
	_undo_records.append(normalized_record)
	_trim_undo_to_capacity()
	_mark_history_changed()
	return true


func can_undo() -> bool:
	return not _undo_records.is_empty()


func can_redo() -> bool:
	return not _redo_batches.is_empty()


## Starts one user Undo gesture. Every confirmed Undo until end_undo_batch()
## becomes one atomic Redo batch while remaining individually undoable later.
func begin_undo_batch() -> bool:
	if _undo_batch_active:
		return false
	_active_undo_batch.clear()
	_undo_batch_active = true
	_cancel_pending_confirmation()
	return true


func end_undo_batch() -> bool:
	if not _undo_batch_active:
		return false
	_undo_batch_active = false
	if _active_undo_batch.is_empty():
		_cancel_pending_confirmation()
		return false
	var replay_batch: Array[Dictionary] = []
	for index in range(_active_undo_batch.size() - 1, -1, -1):
		replay_batch.append(_active_undo_batch[index])
	_redo_batches.push_front(replay_batch)
	_active_undo_batch.clear()
	_mark_history_changed()
	return true


func is_undo_batch_active() -> bool:
	return _undo_batch_active


func peek_undo() -> Dictionary:
	if _undo_records.is_empty():
		_cancel_pending_confirmation()
		return {}
	_pending_direction = _DIRECTION_UNDO
	_pending_revision = _revision
	return _copy_record(_undo_records.back())


func confirm_undo() -> bool:
	if not _can_confirm(_DIRECTION_UNDO) or _undo_records.is_empty():
		return false
	var record: Dictionary = _undo_records.pop_back()
	if _undo_batch_active:
		_active_undo_batch.append(record)
	else:
		_redo_batches.push_front([record])
	_mark_history_changed()
	return true


func peek_redo() -> Dictionary:
	var record := _get_next_redo_record()
	if record.is_empty():
		_cancel_pending_confirmation()
		return {}
	_pending_direction = _DIRECTION_REDO
	_pending_revision = _revision
	return _copy_record(record)


## Returns the complete next Redo gesture in chronological replay order.
func peek_redo_batch() -> Array[Dictionary]:
	var batch := _get_next_redo_batch()
	if batch.is_empty():
		_cancel_pending_confirmation()
		return []
	_pending_direction = _DIRECTION_REDO
	_pending_revision = _revision
	return _copy_records(batch)


func confirm_redo() -> bool:
	if not _can_confirm(_DIRECTION_REDO) or _redo_batches.is_empty():
		return false
	var batch: Array = _redo_batches.pop_front()
	for record_variant: Variant in batch:
		if record_variant is Dictionary:
			_undo_records.append(record_variant as Dictionary)
	_trim_undo_to_capacity()
	_mark_history_changed()
	return true


func confirm_redo_batch() -> bool:
	return confirm_redo()


func cancel_pending_confirmation() -> void:
	_cancel_pending_confirmation()


## Replaces exactly one chronological undo record without moving its neighbors.
## Redo is retained unless the caller explicitly declares it stale.
func replace_undo_record_at(
	index: int,
	replacement_record: Dictionary,
	clear_redo: bool = false
) -> bool:
	if index < 0 or index >= _undo_records.size():
		return false
	var normalized_record := _normalize_record(replacement_record)
	if normalized_record.is_empty():
		return false
	_undo_records[index] = normalized_record
	if clear_redo:
		_clear_redo_state()
	_mark_history_changed()
	return true


## Removes exactly one chronological undo record without moving the remaining
## records relative to one another. Redo is retained unless requested.
func remove_undo_record_at(index: int, clear_redo: bool = false) -> bool:
	if index < 0 or index >= _undo_records.size():
		return false
	_undo_records.remove_at(index)
	if clear_redo:
		_clear_redo_state()
	_mark_history_changed()
	return true


## Replaces the chronological undo tail [index, end) with one atomic record.
## index == get_undo_count() is valid and appends the replacement record.
func collapse_undo_since(index: int, replacement_record: Dictionary) -> bool:
	if index < 0 or index > _undo_records.size():
		return false
	var normalized_record := _normalize_record(replacement_record)
	if normalized_record.is_empty():
		return false
	_undo_records.resize(index)
	_undo_records.append(normalized_record)
	_clear_redo_state()
	_trim_undo_to_capacity()
	_mark_history_changed()
	return true


## Discards the chronological undo tail [index, end).
func truncate_undo_since(index: int) -> bool:
	if index < 0 or index > _undo_records.size():
		return false
	_undo_records.resize(index)
	# Once the authored undo branch is edited, its old redo branch is stale.
	_clear_redo_state()
	_mark_history_changed()
	return true


## Discards the chronological undo prefix [0, index], inclusively. The method
## is domain-neutral: the caller decides which acknowledged checkpoint owns
## that boundary.
func discard_undo_prefix_through(index: int, clear_redo: bool = true) -> bool:
	if index < 0 or index >= _undo_records.size():
		return false
	_undo_records = _undo_records.slice(index + 1)
	if clear_redo:
		_clear_redo_state()
	_mark_history_changed()
	return true


func clear() -> void:
	_undo_records.clear()
	_clear_redo_state()
	_mark_history_changed()


func get_undo_count() -> int:
	return _undo_records.size()


func get_redo_count() -> int:
	return _redo_batches.size()


## Returns undo records oldest-to-newest.
func get_undo_records() -> Array[Dictionary]:
	return _copy_records(_undo_records)


## Returns redo records next-to-last in replay order.
func get_redo_records() -> Array[Dictionary]:
	var flattened: Array[Dictionary] = []
	for batch_variant: Variant in _redo_batches:
		if not batch_variant is Array:
			continue
		for record_variant: Variant in batch_variant as Array:
			if record_variant is Dictionary:
				flattened.append(_copy_record(record_variant as Dictionary))
	return flattened


func get_redo_batches() -> Array[Array]:
	var copies: Array[Array] = []
	for batch_variant: Variant in _redo_batches:
		if batch_variant is Array:
			copies.append(_copy_records(batch_variant as Array[Dictionary]))
	return copies


func get_undo_label() -> String:
	if _undo_records.is_empty():
		return ""
	return String(_undo_records.back().get("label", ""))


func get_redo_label() -> String:
	if _redo_batches.is_empty():
		return ""
	var batch_variant: Variant = _redo_batches.front()
	if not batch_variant is Array:
		return ""
	var batch := batch_variant as Array
	if batch.is_empty():
		return ""
	if batch.size() == 1 and batch.front() is Dictionary:
		return String((batch.front() as Dictionary).get("label", ""))
	return "%d actions" % batch.size()


func get_undo_labels() -> PackedStringArray:
	return _collect_labels(_undo_records)


func get_redo_labels() -> PackedStringArray:
	return _collect_labels(get_redo_records())


func get_status_summary() -> Dictionary:
	# Keep the hot UI/status path constant-time. Full chronological label lists
	# remain available through get_undo_labels()/get_redo_labels() for explicit
	# diagnostics, but walking thousands of point actions on every state refresh
	# would turn an otherwise compact point journal into O(N^2) interaction work.
	return {
		"capacity": _capacity,
		"undo_count": get_undo_count(),
		"redo_count": get_redo_count(),
		"can_undo": can_undo(),
		"can_redo": can_redo(),
		"undo_label": get_undo_label(),
		"redo_label": get_redo_label(),
	}


func _trim_undo_to_capacity() -> void:
	if _capacity <= 0:
		return
	while _undo_records.size() > _capacity:
		_undo_records.pop_front()


func _get_next_redo_batch() -> Array[Dictionary]:
	if _redo_batches.is_empty():
		return []
	var batch_variant: Variant = _redo_batches.front()
	if not batch_variant is Array:
		return []
	var batch: Array[Dictionary] = []
	for record_variant: Variant in batch_variant as Array:
		if record_variant is Dictionary:
			batch.append(record_variant as Dictionary)
	return batch


func _get_next_redo_record() -> Dictionary:
	if _redo_batches.is_empty():
		return {}
	var batch_variant: Variant = _redo_batches.front()
	if not batch_variant is Array:
		return {}
	var batch := batch_variant as Array
	if batch.is_empty() or not batch.front() is Dictionary:
		return {}
	return batch.front() as Dictionary


func _clear_redo_state() -> void:
	_redo_batches.clear()
	_active_undo_batch.clear()
	_undo_batch_active = false


func _can_confirm(direction: StringName) -> bool:
	return (
		_pending_direction == direction
		and _pending_revision == _revision
	)


func _mark_history_changed() -> void:
	_revision += 1
	_cancel_pending_confirmation()


func _cancel_pending_confirmation() -> void:
	_pending_direction = StringName()
	_pending_revision = -1


static func _normalize_record(record: Dictionary) -> Dictionary:
	if not record.has("kind") or not record.has("label") or not record.has("payload"):
		return {}
	var kind_variant: Variant = record.get("kind")
	var label_variant: Variant = record.get("label")
	var payload_variant: Variant = record.get("payload")
	if (
		not kind_variant is String
		and not kind_variant is StringName
	):
		return {}
	if (
		not label_variant is String
		and not label_variant is StringName
	):
		return {}
	if not payload_variant is Dictionary:
		return {}
	var kind := StringName(kind_variant)
	if kind == StringName():
		return {}
	return {
		"kind": kind,
		"label": String(label_variant),
		# duplicate(true) recursively copies Array/Dictionary containers while
		# intentionally retaining Object and Resource references.
		"payload": (payload_variant as Dictionary).duplicate(true),
	}


static func _copy_record(record: Dictionary) -> Dictionary:
	return {
		"kind": StringName(record.get("kind", StringName())),
		"label": String(record.get("label", "")),
		"payload": (record.get("payload", {}) as Dictionary).duplicate(true),
	}


static func _copy_records(records: Array[Dictionary]) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	copies.resize(records.size())
	for index in range(records.size()):
		copies[index] = _copy_record(records[index])
	return copies


static func _collect_labels(records: Array[Dictionary]) -> PackedStringArray:
	var labels := PackedStringArray()
	for record: Dictionary in records:
		labels.append(String(record.get("label", "")))
	return labels
