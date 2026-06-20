extends SceneTree

const RESULT_FILE_PATH := "C:/WORKSPACE/combat_origin_local_field_audit_results.txt"
const SCAN_ROOTS: Array[String] = [
	"res://core",
	"res://runtime",
]
const MAX_PRINTED_FINDINGS := 300
const PAIR_CONTEXT_RADIUS := 10
const INCLUDED_PATH_FRAGMENTS: Array[String] = [
	"res://core/atoms/anchor_atom.gd",
	"res://core/models/combat_",
	"res://core/resolvers/combat_",
	"res://runtime/combat/",
	"res://runtime/player/",
]
const MIGRATED_RESOLVER_PATHS: Array[String] = [
	"res://core/resolvers/combat_animation_trajectory_volume_resolver.gd",
	"res://core/resolvers/combat_animation_retarget_resolver.gd",
	"res://core/resolvers/combat_animation_runtime_chain_compiler.gd",
	"res://core/resolvers/combat_runtime_clip_baker.gd",
]
const GROUPED_ORIGIN_SYMBOL_ALIASES := {
	"baked_solved_weapon_positions_reference_local": ["baked_solved_weapon_reference_origin_id"],
	"baked_solved_weapon_rotations_reference_local": ["baked_solved_weapon_reference_origin_id"],
	"baked_solved_weapon_scales_reference_local": ["baked_solved_weapon_reference_origin_id"],
	"baked_solved_anchor_positions_weapon_local": ["baked_solved_anchor_origin_id"],
	"baked_solved_anchor_rotations_weapon_local": ["baked_solved_anchor_origin_id"],
	"baked_solved_anchor_scales_weapon_local": ["baked_solved_anchor_origin_id"],
	"current_solved_weapon_position_reference_local": ["current_solved_weapon_reference_origin_id"],
	"current_solved_weapon_rotation_reference_local": ["current_solved_weapon_reference_origin_id"],
	"current_solved_weapon_scale_reference_local": ["current_solved_weapon_reference_origin_id"],
	"current_solved_anchor_positions_weapon_local": ["current_solved_anchor_origin_id"],
	"current_solved_anchor_rotations_weapon_local": ["current_solved_anchor_origin_id"],
	"current_solved_anchor_scales_weapon_local": ["current_solved_anchor_origin_id"],
	"solved_weapon_position_reference_local": ["solved_weapon_reference_origin_id"],
	"solved_weapon_rotation_reference_local": ["solved_weapon_reference_origin_id"],
	"solved_weapon_scale_reference_local": ["solved_weapon_reference_origin_id"],
	"solved_anchor_positions_weapon_local": ["solved_anchor_origin_id"],
	"solved_anchor_rotations_weapon_local": ["solved_anchor_origin_id"],
	"solved_anchor_scales_weapon_local": ["solved_anchor_origin_id"],
	"weapon_position_reference_local": ["weapon_reference_origin_id"],
	"weapon_rotation_reference_local": ["weapon_reference_origin_id"],
	"weapon_scale_reference_local": ["weapon_reference_origin_id"],
	"anchor_positions_weapon_local": ["anchor_origin_id"],
	"anchor_rotations_weapon_local": ["anchor_origin_id"],
	"anchor_scales_weapon_local": ["anchor_origin_id"],
}

var _local_symbol_pattern := RegEx.new()
var _findings: Array[Dictionary] = []
var _finding_keys: Dictionary = {}
var _symbol_counts: Dictionary = {}
var _file_counts: Dictionary = {}
var _category_counts: Dictionary = {}
var _severity_counts: Dictionary = {}
var _total_local_symbol_count := 0
var _paired_local_symbol_count := 0
var _temporary_local_symbol_count := 0
var _anonymous_authored_local_count := 0
var _vector_zero_without_origin_count := 0
var _migrated_resolver_unpaired_count := 0

func _init() -> void:
	call_deferred("_run_diagnostic")

func _run_diagnostic() -> void:
	_local_symbol_pattern.compile("\\b[A-Za-z0-9_]*local[A-Za-z0-9_]*\\b")
	for root_path in SCAN_ROOTS:
		_scan_directory(root_path)
	var lines: PackedStringArray = []
	lines.append("total_local_symbol_count=%d" % _total_local_symbol_count)
	lines.append("paired_local_symbol_count=%d" % _paired_local_symbol_count)
	lines.append("temporary_local_symbol_count=%d" % _temporary_local_symbol_count)
	lines.append("anonymous_authored_local_count=%d" % _anonymous_authored_local_count)
	lines.append("vector_zero_without_origin_count=%d" % _vector_zero_without_origin_count)
	lines.append("migrated_resolver_unpaired_count=%d" % _migrated_resolver_unpaired_count)
	lines.append("migrated_resolver_annotations_ok=%s" % str(_migrated_resolver_unpaired_count == 0))
	lines.append("scan_roots=%s" % ", ".join(PackedStringArray(SCAN_ROOTS)))
	lines.append("path_filter=combat_player_weapon_origin_relevant")
	lines.append("note=diagnostic_only_intelligent_origin_law_audit")
	_append_top_count_lines(lines, "category_counts", _category_counts, 16)
	_append_top_count_lines(lines, "severity_counts", _severity_counts, 8)
	_append_top_count_lines(lines, "top_symbols", _symbol_counts, 24)
	_append_top_count_lines(lines, "top_files", _file_counts, 24)
	_append_priority_findings(lines)
	var printed_count: int = mini(_findings.size(), MAX_PRINTED_FINDINGS)
	for index in range(printed_count):
		var finding: Dictionary = _findings[index]
		lines.append("%s:%d severity=%s category=%s symbol=%s expected_origin=%s text=%s" % [
			String(finding.get("path", "")),
			int(finding.get("line_number", 0)),
			String(finding.get("severity", "")),
			String(finding.get("category", "")),
			String(finding.get("symbol", "")),
			String(finding.get("expected_origin_symbol", "")),
			String(finding.get("text", "")),
		])
	if _findings.size() > printed_count:
		lines.append("truncated_remaining_count=%d" % int(_findings.size() - printed_count))
	var file: FileAccess = FileAccess.open(RESULT_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	for line in lines:
		print(line)
	quit(0)

func _scan_directory(directory_path: String) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = directory.get_next()
			continue
		var entry_path := directory_path.path_join(entry_name)
		if directory.current_is_dir():
			_scan_directory(entry_path)
		elif entry_name.ends_with(".gd"):
			_scan_file(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()

func _scan_file(file_path: String) -> void:
	if not _is_combat_relevant_path(file_path):
		return
	var content := FileAccess.get_file_as_string(file_path)
	if content.is_empty():
		return
	var source_lines := content.split("\n")
	for line_index in range(source_lines.size()):
		_scan_line(file_path, source_lines, line_index)

func _scan_line(file_path: String, source_lines: PackedStringArray, line_index: int) -> void:
	var stripped := source_lines[line_index].strip_edges()
	if stripped.is_empty() or stripped.begins_with("#"):
		return
	if not _is_local_candidate_line(stripped):
		return
	var matches := _local_symbol_pattern.search_all(stripped)
	for match_result in matches:
		var symbol := match_result.get_string()
		if _should_skip_symbol(symbol):
			continue
		_total_local_symbol_count += 1
		var expected_origin_symbols: Array[String] = _expected_origin_symbols(symbol)
		var expected_origin_symbol: String = _format_expected_origin_symbols(expected_origin_symbols)
		var has_origin_pair: bool = _has_origin_pair(source_lines, line_index, symbol, expected_origin_symbols)
		var category: String = _classify_local_symbol(stripped, symbol, has_origin_pair)
		var severity: String = _severity_for_category(category)
		_increment_count(_category_counts, category)
		if has_origin_pair:
			_paired_local_symbol_count += 1
		if category == "temporary_math_local":
			_temporary_local_symbol_count += 1
		if category == "anonymous_authored_local":
			_anonymous_authored_local_count += 1
		if category == "vector_zero_without_origin":
			_vector_zero_without_origin_count += 1
		if _is_migrated_resolver_path(file_path) and _is_unpaired_migrated_category(category):
			_migrated_resolver_unpaired_count += 1
		if severity == "ignore":
			continue
		_record_finding(file_path, line_index + 1, stripped, symbol, expected_origin_symbol, category, severity)

func _record_finding(
	file_path: String,
	line_number: int,
	text: String,
	symbol: String,
	expected_origin_symbol: String,
	category: String,
	severity: String
) -> void:
	var finding_key := "%s:%d:%s:%s" % [file_path, line_number, symbol, category]
	if _finding_keys.has(finding_key):
		return
	_finding_keys[finding_key] = true
	_increment_count(_symbol_counts, symbol)
	_increment_count(_file_counts, file_path)
	_increment_count(_severity_counts, severity)
	_findings.append({
		"path": file_path,
		"line_number": line_number,
		"symbol": symbol,
		"expected_origin_symbol": expected_origin_symbol,
		"category": category,
		"severity": severity,
		"text": text,
	})

func _classify_local_symbol(stripped: String, symbol: String, has_origin_pair: bool) -> String:
	if has_origin_pair:
		return "paired_local"
	if _is_grouped_origin_alias_line(stripped, symbol):
		return "paired_grouped_origin"
	if _is_paired_resource_read_line(stripped, symbol):
		return "paired_resource_read"
	if _is_paired_persistent_track_line(stripped, symbol):
		return "paired_persistent_track"
	if _is_temporary_math_line(stripped, symbol):
		return "temporary_math_local"
	if stripped.contains("Vector3.ZERO"):
		return "vector_zero_without_origin"
	if _is_authored_or_persistent_line(stripped):
		return "anonymous_authored_local"
	if _is_read_line(stripped):
		return "anonymous_read_local"
	return "unpaired_local_reference"

func _severity_for_category(category: String) -> String:
	match category:
		"vector_zero_without_origin":
			return "error"
		"anonymous_authored_local":
			return "warning"
		"anonymous_read_local":
			return "info"
		"unpaired_local_reference":
			return "info"
		_:
			return "ignore"

func _is_paired_resource_read_line(stripped: String, symbol: String) -> bool:
	var resource_tokens: Array[String] = [
		"motion_node",
		"source_node",
		"chain_node",
		"from_node",
		"to_node",
		"retarget_node",
		"chain_player",
		"source_chain_player",
		"runtime_clip",
		"target_clip",
		"clip",
	]
	for resource_token in resource_tokens:
		var property_access := "%s.%s" % [resource_token, symbol]
		if not stripped.contains(property_access):
			continue
		if stripped.contains("%s =" % property_access):
			return false
		if stripped.contains("%s.append(" % property_access):
			return false
		if stripped.contains("%s.clear(" % property_access):
			return false
		return true
	return false

func _is_paired_persistent_track_line(stripped: String, symbol: String) -> bool:
	if not (
		symbol.begins_with("baked_")
		or symbol.begins_with("current_")
		or symbol.begins_with("solved_")
	):
		return false
	return (
		stripped.contains(".%s.append(" % symbol)
		or stripped.contains(".%s.clear(" % symbol)
		or stripped.contains(".%s = " % symbol)
		or stripped.contains(".%s =" % symbol)
		or stripped.contains("%s.size()" % symbol)
	)

func _is_grouped_origin_alias_line(_stripped: String, symbol: String) -> bool:
	return GROUPED_ORIGIN_SYMBOL_ALIASES.has(symbol)

func _has_origin_pair(
	source_lines: PackedStringArray,
	line_index: int,
	symbol: String,
	expected_origin_symbols: Array[String]
) -> bool:
	var start_index: int = maxi(0, line_index - PAIR_CONTEXT_RADIUS)
	var end_index: int = mini(source_lines.size() - 1, line_index + PAIR_CONTEXT_RADIUS)
	for nearby_index in range(start_index, end_index + 1):
		var nearby_line := source_lines[nearby_index].strip_edges()
		if nearby_line.begins_with("#"):
			continue
		for expected_origin_symbol: String in expected_origin_symbols:
			if not expected_origin_symbol.is_empty() and nearby_line.contains(expected_origin_symbol):
				return true
		if _line_has_generic_origin_pair(nearby_line, symbol):
			return true
	return false

func _line_has_generic_origin_pair(source_line: String, symbol: String) -> bool:
	if not source_line.contains("origin_id"):
		return false
	if source_line.contains("origin_local_origin_id") and symbol == "origin_local":
		return true
	var root_token: String = _root_token_for_symbol(symbol)
	return root_token != "" and source_line.contains(root_token)

func _root_token_for_symbol(symbol: String) -> String:
	if symbol.ends_with("_local"):
		return symbol.substr(0, symbol.length() - "_local".length())
	if symbol.contains("_local_"):
		return symbol.split("_local_")[0]
	if symbol.begins_with("local_"):
		return symbol.substr("local_".length())
	return ""

func _expected_origin_symbols(symbol: String) -> Array[String]:
	var symbols: Array[String] = []
	if GROUPED_ORIGIN_SYMBOL_ALIASES.has(symbol):
		for alias_variant: Variant in GROUPED_ORIGIN_SYMBOL_ALIASES.get(symbol, []):
			var alias_symbol: String = String(alias_variant)
			if not alias_symbol.is_empty() and not symbols.has(alias_symbol):
				symbols.append(alias_symbol)
	var inferred_symbol: String = _infer_expected_origin_symbol(symbol)
	if not inferred_symbol.is_empty() and not symbols.has(inferred_symbol):
		symbols.append(inferred_symbol)
	return symbols

func _format_expected_origin_symbols(symbols: Array[String]) -> String:
	var parts := PackedStringArray()
	for symbol: String in symbols:
		if not symbol.is_empty():
			parts.append(symbol)
	return ", ".join(parts)

func _infer_expected_origin_symbol(symbol: String) -> String:
	if symbol == "origin_local":
		return "origin_local_origin_id"
	if symbol.ends_with("_local"):
		return "%s_origin_id" % symbol.substr(0, symbol.length() - "_local".length())
	if symbol.contains("_local_"):
		return "%s_origin_id" % symbol.replace("_local_", "_")
	if symbol.begins_with("local_"):
		return "%s_origin_id" % symbol.substr("local_".length())
	return ""

func _is_temporary_math_line(stripped: String, _symbol: String) -> bool:
	if stripped.begins_with("func "):
		return true
	return (
		stripped.begins_with("var ")
		and not stripped.contains(".get(")
		and not stripped.contains(".get_meta(")
		and not stripped.contains(".set(")
		and not stripped.contains(".set_meta(")
		and not stripped.contains("[\"")
		and not stripped.contains("@export")
		and not stripped.contains("return {")
		and not stripped.contains("motion_node.")
		and not stripped.contains("clip.")
	)

func _is_authored_or_persistent_line(stripped: String) -> bool:
	return (
		stripped.contains("@export")
		or stripped.contains(".set_meta(")
		or stripped.contains(".set(")
		or stripped.contains("set_meta(\"")
		or stripped.contains("[\"")
		or stripped.contains("] =")
		or stripped.contains("return {")
		or stripped.contains("motion_node.")
		or stripped.contains("clip.")
		or stripped.contains("target_clip.")
		or stripped.contains("config[")
	)

func _is_read_line(stripped: String) -> bool:
	return (
		stripped.contains(".get(")
		or stripped.contains(".get_meta(")
		or stripped.contains("get_meta(\"")
		or stripped.contains(".has(")
		or stripped.contains(".has_meta(")
	)

func _is_unpaired_migrated_category(category: String) -> bool:
	return category == "vector_zero_without_origin"

func _is_local_candidate_line(stripped: String) -> bool:
	return (
		stripped.contains("_local")
		or stripped.contains("local_")
		or stripped.contains("\"local")
		or stripped.contains("'local")
	)

func _should_skip_symbol(symbol: String) -> bool:
	return (
		symbol == "local"
		or symbol == "locals"
		or symbol == "local_position"
		or symbol == "local_rotation"
		or symbol == "local_scale"
		or symbol == "local_ratio"
		or symbol == "to_local"
		or symbol.begins_with("_")
	)

func _is_combat_relevant_path(file_path: String) -> bool:
	for path_fragment in INCLUDED_PATH_FRAGMENTS:
		if file_path.contains(path_fragment):
			return true
	return false

func _is_migrated_resolver_path(file_path: String) -> bool:
	for path in MIGRATED_RESOLVER_PATHS:
		if file_path == path:
			return true
	return false

func _increment_count(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

func _append_top_count_lines(lines: PackedStringArray, title: String, counts: Dictionary, limit: int) -> void:
	lines.append("%s:" % title)
	var entries: Array = []
	for key in counts.keys():
		entries.append({
			"key": String(key),
			"count": int(counts.get(key, 0)),
		})
	var printed_count: int = mini(limit, entries.size())
	for _index in range(printed_count):
		var best_index: int = _find_highest_count_index(entries)
		if best_index < 0:
			return
		var entry: Dictionary = entries.pop_at(best_index)
		lines.append("  %s=%d" % [String(entry.get("key", "")), int(entry.get("count", 0))])

func _append_priority_findings(lines: PackedStringArray) -> void:
	lines.append("priority_findings:")
	var priority_count := 0
	for finding: Dictionary in _findings:
		var severity := String(finding.get("severity", ""))
		if severity != "error" and severity != "warning":
			continue
		priority_count += 1
		lines.append("  %s:%d severity=%s category=%s symbol=%s expected_origin=%s text=%s" % [
			String(finding.get("path", "")),
			int(finding.get("line_number", 0)),
			severity,
			String(finding.get("category", "")),
			String(finding.get("symbol", "")),
			String(finding.get("expected_origin_symbol", "")),
			String(finding.get("text", "")),
		])
	if priority_count == 0:
		lines.append("  none")

func _find_highest_count_index(entries: Array) -> int:
	var best_index := -1
	var best_count := -1
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var entry_count: int = int(entry.get("count", 0))
		if entry_count > best_count:
			best_index = index
			best_count = entry_count
	return best_index
