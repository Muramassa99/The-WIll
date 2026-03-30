extends StaticBody3D
class_name StorageBox

@onready var prompt_label: Label3D = $PromptLabel3D

func _ready() -> void:
	add_to_group("interactable")
	_update_prompt()

func interact(player: PlayerController3D) -> void:
	if player != null and player.has_method("open_player_inventory_page"):
		player.call("open_player_inventory_page", &"storage", String(name))

func _update_prompt() -> void:
	prompt_label.text = "F - Use Personal Storage"
