extends RefCounted

## Opt-in instrumentation only. Callers pass small scalar diagnostics, never Nodes,
## geometry or pose resources. This observer does not participate in a grip solve.
## Every span boundary is flushed so a stalled operation retains its start record.
## This durability has a cost: recorder_write_us/flush_count are reported on close.
## Durations may include nested spans and recorder work; do not sum as wall time.

const SCHEMA := "the_will_grip_chronology"
const VERSION := 1
const MAX_ITEMS := 48
const MAX_STRING := 2048
const MAX_DEPTH := 6

static var _requested_path: String = OS.get_environment("THE_WILL_GRIP_TRACE_PATH")
static var _mutex := Mutex.new()
static var _configured := false
static var _closed := false
static var _reported_error := false
static var _file: FileAccess
static var _start_us := 0
static var _last_flush_us := 0
static var _sequence := 0
static var _next_span := 0
static var _open_spans: Dictionary = {}
static var _write_us := 0
static var _flush_count := 0


static func enabled() -> bool:
	if _requested_path.is_empty():
		return false
	_mutex.lock()
	_configure_locked()
	var result: bool = _file != null and not _closed
	_mutex.unlock()
	return result


static func begin(name: String, data: Dictionary = {}) -> int:
	if _requested_path.is_empty():
		return 0
	_mutex.lock()
	_configure_locked()
	if _file == null or _closed:
		_mutex.unlock()
		return 0
	_next_span += 1
	var span_id: int = _next_span
	var now: int = Time.get_ticks_usec()
	_open_spans[span_id] = {"name": name, "started_us": now}
	_write_locked("begin", span_id, name, now, data, -1, true)
	_mutex.unlock()
	return span_id


static func finish(span_id: int, data: Dictionary = {}) -> void:
	if span_id == 0 or _requested_path.is_empty():
		return
	_mutex.lock()
	if _file == null or _closed:
		_mutex.unlock()
		return
	var now: int = Time.get_ticks_usec()
	if not _open_spans.has(span_id):
		_write_locked("event", 0, "trace.unmatched_finish", now, {"unmatched_span_id": span_id}, -1, true)
	else:
		var span: Dictionary = _open_spans[span_id]
		_open_spans.erase(span_id)
		_write_locked("end", span_id, str(span.name), now, data, now - int(span.started_us), true)
	_mutex.unlock()


static func event(name: String, data: Dictionary = {}) -> void:
	if _requested_path.is_empty():
		return
	_mutex.lock()
	_configure_locked()
	if _file != null and not _closed:
		var terminal: bool = bool(data.get("terminal", false))
		for ending: String in [".complete", ".completed", ".failed", ".cancelled", ".timeout", ".closed", ".error"]:
			terminal = terminal or name.ends_with(ending)
		_write_locked("event", 0, name, Time.get_ticks_usec(), data, -1, terminal)
	_mutex.unlock()


static func close() -> void:
	if _requested_path.is_empty():
		return
	_mutex.lock()
	if _file != null and not _closed:
		_write_locked("event", 0, "trace.closed", Time.get_ticks_usec(), {
			"open_span_count": _open_spans.size(), "recorder_write_us": _write_us,
			"flush_count": _flush_count, "terminal": true,
			"note": "Open spans are unfinished, not successful. Nested durations overlap."
		}, -1, true)
		if _file != null:
			_file.close()
			_file = null
	_closed = true
	_mutex.unlock()


static func _configure_locked() -> void:
	if _configured or _closed:
		return
	_configured = true
	var path: String = _requested_path.replace("\\", "/").simplify_path()
	if not path.is_absolute_path() or not path.to_lower().begins_with("c:/workspace/") or path.get_extension().to_lower() != "jsonl":
		_error_locked("THE_WILL_GRIP_TRACE_PATH must be an absolute .jsonl path inside C:/WORKSPACE.")
		return
	if FileAccess.file_exists(path):
		var previous := FileAccess.open(path, FileAccess.READ)
		if previous == null or previous.get_length() > 0:
			if previous != null:
				previous.close()
			_error_locked("Grip chronology refuses to overwrite an existing trace: " + path)
			return
		previous.close()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_error_locked("Cannot create grip chronology directory: " + error_string(directory_error))
		return
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		_error_locked("Cannot open grip chronology: " + error_string(FileAccess.get_open_error()))
		return
	_start_us = Time.get_ticks_usec()
	_write_locked("event", 0, "trace.started", _start_us, {
		"schema": SCHEMA, "version": VERSION,
		"started_utc": Time.get_datetime_string_from_system(true) + "Z",
		"started_unix_seconds": Time.get_unix_time_from_system(),
		"engine_start_ticks_us": _start_us, "process_id": OS.get_process_id(),
		"timing": "Monotonic microseconds since trace start. Span boundaries flush immediately; other records flush within one second of the next call.",
		"duration_note": "Inclusive durations overlap, include recorder boundary overhead, and are not additive wall time."
	}, -1, true)


static func _write_locked(kind: String, span_id: int, name: String, now: int, data: Dictionary, duration_us: int, durable: bool) -> void:
	var write_started: int = Time.get_ticks_usec()
	_sequence += 1
	var record: Dictionary = {
		"schema_version": VERSION, "sequence": _sequence, "t_us": now - _start_us,
		"kind": kind, "span_id": span_id, "name": name.substr(0, MAX_STRING),
		"is_main_thread": Thread.is_main_thread(), "data": _small_data(data, 0),
		"recorder_write_us_before": _write_us, "flush_count_before": _flush_count
	}
	if duration_us >= 0:
		record.duration_us = duration_us
	_file.store_line(JSON.stringify(record))
	if durable or now - _last_flush_us >= 1000000:
		_file.flush()
		_last_flush_us = now
		_flush_count += 1
	_write_us += Time.get_ticks_usec() - write_started
	if _file.get_error() != OK:
		_error_locked("Grip chronology write failed: " + error_string(_file.get_error()))
		_file.close()
		_file = null
		_closed = true


static func _small_data(value: Variant, depth: int) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			return value if is_finite(value) else str(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value).substr(0, MAX_STRING)
		TYPE_DICTIONARY:
			if depth >= MAX_DEPTH:
				return "[nested dictionary omitted]"
			var result: Dictionary = {}
			var count := 0
			for key: Variant in value:
				if count >= MAX_ITEMS:
					result["_omitted_field_count"] = value.size() - count
					break
				result[str(key).substr(0, 128)] = _small_data(value[key], depth + 1)
				count += 1
			return result
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			if depth >= MAX_DEPTH:
				return "[nested array omitted]"
			var result: Array = []
			for index: int in mini(value.size(), MAX_ITEMS):
				result.append(_small_data(value[index], depth + 1))
			if value.size() > MAX_ITEMS:
				result.append("[%d more items omitted]" % (value.size() - MAX_ITEMS))
			return result
	return "[unsupported diagnostic type %s]" % type_string(typeof(value))


static func _error_locked(message: String) -> void:
	if not _reported_error:
		_reported_error = true
		push_error(message)
