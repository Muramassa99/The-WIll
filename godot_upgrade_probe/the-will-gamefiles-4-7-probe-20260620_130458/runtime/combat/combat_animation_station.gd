extends StaticBody3D
class_name CombatAnimationStation

@onready var prompt_label: Label3D = $PromptLabel3D
@onready var station_ui: CanvasLayer = $CombatAnimationStationUI

func _ready() -> void:
	add_to_group("interactable")
	if station_ui != null and not station_ui.closed.is_connected(_on_ui_closed):
		station_ui.closed.connect(_on_ui_closed)
	_update_prompt(false)

func interact(player: PlayerController3D) -> void:
	if station_ui == null:
		return
	station_ui.call("toggle_for", player, String(name))
	_update_prompt(bool(station_ui.call("is_open")))

func _on_ui_closed() -> void:
	_update_prompt(false)

func _update_prompt(is_open: bool) -> void:
	if prompt_label == null:
		return
	if is_open:
		prompt_label.text = "Combat Animation Station Open"
		return
	prompt_label.text = "F - Use Combat Animation Station"
