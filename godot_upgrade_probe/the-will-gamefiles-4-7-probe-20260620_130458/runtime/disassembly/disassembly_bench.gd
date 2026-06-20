extends StaticBody3D
class_name DisassemblyBench

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var bench_ui: CanvasLayer = $DisassemblyBenchUI

func _ready() -> void:
	add_to_group("interactable")
	bench_ui.connect("closed", Callable(self, "_on_ui_closed"))
	_update_prompt(false)

func interact(player: PlayerController3D) -> void:
	bench_ui.call("toggle_for", player, String(name))
	_update_prompt(bool(bench_ui.call("is_open")))

func _on_ui_closed() -> void:
	_update_prompt(false)

func _update_prompt(is_open: bool) -> void:
	if is_open:
		prompt_label.text = "Disassembly Open"
		return
	prompt_label.text = "F - Use Disassembly Bench"
