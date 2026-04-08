extends SceneTree

const RESULT_FILE_PATH := "C:/WORKSPACE/audit_load_resources_results.txt"

var failures: PackedStringArray = []
var checked_count: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_scan_dir("res://")
	var lines: PackedStringArray = []
	lines.append("checked_count=%d" % checked_count)
	lines.append("failure_count=%d" % failures.size())
	for failure: String in failures:
		lines.append(failure)
	var file := FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	quit()

func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		failures.append("dir_open_failed=%s" % path)
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var child_path: String = path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(child_path)
			continue
		if not (child_path.ends_with(".tscn") or child_path.ends_with(".tres")):
			continue
		checked_count += 1
		var resource: Resource = load(child_path)
		if resource == null:
			failures.append("load_failed=%s" % child_path)
	dir.list_dir_end()
