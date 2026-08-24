extends StaticBody3D
class_name CraftingBenchV2

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var stage_controller: Node = $Stage1V2Controller
@onready var preview_presenter: Node = $PreviewRoot
@onready var bench_ui: CanvasLayer = $CraftingBenchUIV2

func _ready() -> void:
	add_to_group("interactable")
	_bind_world_preview_presenter()
	bench_ui.connect("closed", Callable(self, "_on_ui_closed"))
	_update_prompt(false)

func interact(player: PlayerController3D) -> void:
	var ui_was_open := bool(bench_ui.call("is_open"))
	if not ui_was_open:
		if not _unbind_world_preview_presenter():
			_update_prompt(false)
			return
	bench_ui.call("toggle_start_menu_for", player, stage_controller, String(name), preview_presenter)
	var ui_is_open := bool(bench_ui.call("is_open"))
	if not ui_was_open and not ui_is_open:
		_bind_world_preview_presenter()
	_update_prompt(ui_is_open)

func _on_ui_closed() -> void:
	_bind_world_preview_presenter()
	_update_prompt(false)

func _bind_world_preview_presenter() -> void:
	if preview_presenter != null and preview_presenter.has_method("bind_stage_controller"):
		preview_presenter.call("bind_stage_controller", stage_controller)

func _unbind_world_preview_presenter() -> bool:
	if preview_presenter != null and preview_presenter.has_method("clear_stage_controller"):
		return bool(preview_presenter.call("clear_stage_controller"))
	return true

func _update_prompt(is_open: bool) -> void:
	if is_open:
		prompt_label.text = "Bench V2 Open"
		return
	prompt_label.text = "F - Use Crafting Bench V2"
