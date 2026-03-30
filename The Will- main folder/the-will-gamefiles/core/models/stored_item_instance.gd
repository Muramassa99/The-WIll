extends Resource
class_name StoredItemInstance

@export var item_instance_id: StringName = &""
@export var item_kind: StringName = &""
@export var display_name: String = ""
@export var stack_count: int = 1
@export var raw_drop_id: StringName = &""
@export var finalized_item: Resource
@export var is_disassemblable: bool = false

func is_raw_drop_item() -> bool:
	return item_kind == &"raw_drop" and raw_drop_id != StringName()

func is_finalized_item() -> bool:
	return item_kind == &"finalized_item" and finalized_item != null

func get_resolved_display_name() -> String:
	var cleaned_display_name: String = display_name.strip_edges()
	if not cleaned_display_name.is_empty():
		return cleaned_display_name
	var finalized_item_instance = finalized_item
	if finalized_item_instance != null and not String(finalized_item_instance.final_item_name).strip_edges().is_empty():
		return String(finalized_item_instance.final_item_name).strip_edges()
	if raw_drop_id != StringName():
		return _format_raw_drop_display_name(raw_drop_id)
	if item_instance_id != StringName():
		return String(item_instance_id)
	return "Unnamed Stored Item"

func is_stack_equivalent_to(other) -> bool:
	if other == null:
		return false
	if finalized_item != null or other.finalized_item != null:
		return false
	return (
		item_kind == other.item_kind
		and raw_drop_id == other.raw_drop_id
		and get_resolved_display_name() == other.get_resolved_display_name()
		and is_disassemblable == other.is_disassemblable
	)

func matches_exact_state(other) -> bool:
	if other == null:
		return false
	return (
		item_instance_id == other.item_instance_id
		and item_kind == other.item_kind
		and display_name == other.display_name
		and stack_count == other.stack_count
		and raw_drop_id == other.raw_drop_id
		and is_disassemblable == other.is_disassemblable
		and _build_finalized_signature(finalized_item) == _build_finalized_signature(other.finalized_item)
	)

func _format_raw_drop_display_name(drop_id: StringName) -> String:
	var drop_id_text: String = String(drop_id)
	if drop_id_text.is_empty():
		return ""
	var cleaned_text: String = drop_id_text.trim_prefix("drop_")
	if cleaned_text.ends_with("_raw_gray"):
		var material_text: String = _format_title_words(cleaned_text.trim_suffix("_raw_gray"))
		return "%s Raw (Gray)" % material_text
	if cleaned_text.ends_with("_raw"):
		var material_text_legacy: String = _format_title_words(cleaned_text.trim_suffix("_raw"))
		return "%s Raw" % material_text_legacy
	return _format_title_words(cleaned_text)

func _format_title_words(value: String) -> String:
	var words: PackedStringArray = value.replace("_", " ").split(" ", false)
	var formatted_words: PackedStringArray = []
	for word in words:
		formatted_words.append(word.capitalize())
	return " ".join(formatted_words)

func _build_finalized_signature(finalized_item_instance: Resource) -> String:
	if finalized_item_instance == null:
		return ""
	return "%s|%s|%s|%s" % [
		String(finalized_item_instance.finalized_item_id),
		String(finalized_item_instance.final_item_name),
		String(finalized_item_instance.source_wip_id),
		str(finalized_item_instance.finalized_timestamp),
	]
