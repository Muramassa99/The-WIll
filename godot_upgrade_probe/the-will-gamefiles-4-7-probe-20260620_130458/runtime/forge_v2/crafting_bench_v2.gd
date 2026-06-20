extends StaticBody3D
class_name CraftingBenchV2

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var stage_controller: Node = $Stage1V2Controller
@onready var preview_presenter: Node = $PreviewRoot
@onready var bench_ui: CanvasLayer = $CraftingBenchUIV2

func _ready() -> void:
	add_to_group("interactable")
	if preview_presenter != null and preview_presenter.has_method("bind_stage_controller"):
		preview_presenter.call("bind_stage_controller", stage_controller)
	bench_ui.connect("closed", Callable(self, "_on_ui_closed"))
	_update_prompt(false)

func interact(player: PlayerController3D) -> void:
	bench_ui.call("toggle_start_menu_for", player, stage_controller, String(name), preview_presenter)
	_update_prompt(bool(bench_ui.call("is_open")))

func _on_ui_closed() -> void:
	_update_prompt(false)

func _update_prompt(is_open: bool) -> void:
	if is_open:
		prompt_label.text = "Bench V2 Open"
		return
	prompt_label.text = "F - Use Crafting Bench V2"
