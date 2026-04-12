extends CanvasLayer
class_name PlayerGameplayHudOverlay

const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const PlayerHudLayoutStateScript = preload("res://core/models/player_hud_layout_state.gd")

const HP_BAR_COLOR := Color(0.82, 0.16, 0.16, 1.0)
const HP_BAR_BG_COLOR := Color(0.22, 0.06, 0.06, 1.0)
const STAMINA_BAR_COLOR := Color(0.22, 0.72, 0.32, 1.0)
const STAMINA_BAR_BG_COLOR := Color(0.06, 0.18, 0.08, 1.0)
const SLOT_EMPTY_COLOR := Color(0.14, 0.15, 0.18, 0.85)
const SLOT_ASSIGNED_COLOR := Color(0.18, 0.20, 0.26, 0.92)
const SLOT_ACTIVE_COLOR := Color(0.35, 0.28, 0.60, 1.0)
const SLOT_COOLDOWN_COLOR := Color(0.38, 0.12, 0.12, 0.80)
const SLOT_BORDER_COLOR := Color(0.42, 0.44, 0.50, 0.70)
const SLOT_KEYBIND_COLOR := Color(0.78, 0.80, 0.86, 0.95)
const SLOT_NAME_COLOR := Color(0.88, 0.90, 0.94, 1.0)
const BLOCK_SLOT_COLOR := Color(0.22, 0.42, 0.62, 0.92)
const EVADE_SLOT_COLOR := Color(0.22, 0.52, 0.38, 0.92)
const ELEMENT_ID_SKILL_BAR := &"skill_bar"
const ELEMENT_ID_BLOCK_SLOT := &"block_slot"
const ELEMENT_ID_HP_BAR := &"hp_bar"
const ELEMENT_ID_STAMINA_BAR := &"stamina_bar"
const ELEMENT_ID_TARGET_HP_BAR := &"target_hp_bar"

const SKILL_SLOT_ACTION_MAP: Dictionary = {
	&"skill_slot_1": &"skill_slot_1",
	&"skill_slot_2": &"skill_slot_2",
	&"skill_slot_3": &"skill_slot_3",
	&"skill_slot_4": &"skill_slot_4",
	&"skill_slot_5": &"skill_slot_5",
	&"skill_slot_6": &"skill_slot_6",
	&"skill_slot_7": &"skill_slot_7",
	&"skill_slot_8": &"skill_slot_8",
	&"skill_slot_9": &"skill_slot_9",
	&"skill_slot_10": &"skill_slot_10",
	&"skill_slot_11": &"skill_slot_11",
	&"skill_slot_12": &"skill_slot_12",
}

const SKILL_SLOT_KEYBIND_LABELS: Array[String] = [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=",
]

@export var slot_button_width: int = 56
@export var slot_button_height: int = 56
@export var slot_gap_px: int = 3
@export var group_gap_px: int = 14
@export var bar_bottom_margin_px: int = 24
@export var hp_bar_width: int = 280
@export var hp_bar_height: int = 18
@export var stamina_bar_width: int = 10
@export var stamina_bar_height: int = 120

var active_player: Node = null
var skill_slot_state: PlayerSkillSlotState = null
var hud_layout_state: PlayerHudLayoutState = null
var slot_panels: Array[PanelContainer] = []
var slot_keybind_labels: Array[Label] = []
var slot_name_labels: Array[Label] = []
var block_panel: PanelContainer = null
var evade_panel: PanelContainer = null
var hp_bar_fill: ColorRect = null
var stamina_bar_fill: ColorRect = null
var target_hp_container: Control = null
var target_hp_bar_fill: ColorRect = null
var target_name_label: Label = null
var skill_bar_container: HBoxContainer = null
var hud_root: Control = null
var current_hp_ratio: float = 1.0
var current_stamina_ratio: float = 1.0
var target_hp_ratio: float = 1.0
var target_visible: bool = false
var last_activated_slot_id: StringName = &""

func configure(player: Node) -> void:
	active_player = player
	skill_slot_state = PlayerSkillSlotStateScript.load_or_create() as PlayerSkillSlotState
	hud_layout_state = PlayerHudLayoutStateScript.load_or_create() as PlayerHudLayoutState
	_build_hud()
	refresh_all_slots()

func set_hud_visible(enabled: bool) -> void:
	if hud_root != null:
		hud_root.visible = enabled

func is_hud_visible() -> bool:
	return hud_root != null and hud_root.visible

func refresh_all_slots() -> void:
	for slot_index: int in range(PlayerSkillSlotStateScript.SKILL_SLOT_IDS.size()):
		_refresh_skill_slot_visual(slot_index)
	_refresh_block_slot_visual()
	_refresh_evade_slot_visual()

func activate_skill_slot(slot_id: StringName) -> void:
	last_activated_slot_id = slot_id
	_flash_slot_activation(slot_id)

func update_hp(ratio: float) -> void:
	current_hp_ratio = clampf(ratio, 0.0, 1.0)
	if hp_bar_fill != null:
		hp_bar_fill.custom_minimum_size.x = roundi(float(hp_bar_width - 4) * current_hp_ratio)
		hp_bar_fill.size.x = hp_bar_fill.custom_minimum_size.x

func update_stamina(ratio: float) -> void:
	current_stamina_ratio = clampf(ratio, 0.0, 1.0)
	if stamina_bar_fill != null:
		var fill_height: int = roundi(float(stamina_bar_height - 4) * current_stamina_ratio)
		stamina_bar_fill.custom_minimum_size.y = fill_height
		stamina_bar_fill.size.y = fill_height
		stamina_bar_fill.position.y = (stamina_bar_height - 4) - fill_height

func update_target_hp(target_name: String, ratio: float) -> void:
	target_hp_ratio = clampf(ratio, 0.0, 1.0)
	target_visible = true
	if target_hp_container != null:
		target_hp_container.visible = true
	if target_name_label != null:
		target_name_label.text = target_name
	if target_hp_bar_fill != null:
		target_hp_bar_fill.custom_minimum_size.x = roundi(float(hp_bar_width - 4) * target_hp_ratio)
		target_hp_bar_fill.size.x = target_hp_bar_fill.custom_minimum_size.x

func hide_target_hp() -> void:
	target_visible = false
	if target_hp_container != null:
		target_hp_container.visible = false

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.name = "HudRoot"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	_build_skill_bar()
	_build_hp_bar()
	_build_stamina_bar()
	_build_target_hp_bar()

func _build_skill_bar() -> void:
	skill_bar_container = HBoxContainer.new()
	skill_bar_container.name = "SkillBarContainer"
	skill_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_bar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_bar_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skill_bar_container.add_theme_constant_override("separation", 0)
	hud_root.add_child(skill_bar_container)
	var left_group: HBoxContainer = _build_slot_group("LeftGroup")
	skill_bar_container.add_child(left_group)
	_build_block_evade_group()
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(group_gap_px, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_bar_container.add_child(spacer)
	var right_group: HBoxContainer = _build_slot_group("RightGroup")
	skill_bar_container.add_child(right_group)
	slot_panels.clear()
	slot_keybind_labels.clear()
	slot_name_labels.clear()
	for slot_index: int in range(6):
		var panel: PanelContainer = _build_single_slot_panel(slot_index)
		left_group.add_child(panel)
		slot_panels.append(panel)
	for slot_index: int in range(6, 12):
		var panel: PanelContainer = _build_single_slot_panel(slot_index)
		right_group.add_child(panel)
		slot_panels.append(panel)
	_position_skill_bar()

func _build_slot_group(group_name: String) -> HBoxContainer:
	var group: HBoxContainer = HBoxContainer.new()
	group.name = group_name
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", slot_gap_px)
	return group

func _build_single_slot_panel(slot_index: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "SkillSlot_%02d" % (slot_index + 1)
	panel.custom_minimum_size = Vector2(slot_button_width, slot_button_height)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = SLOT_EMPTY_COLOR
	stylebox.border_color = SLOT_BORDER_COLOR
	stylebox.set_border_width_all(1)
	stylebox.set_corner_radius_all(4)
	stylebox.content_margin_left = 3.0
	stylebox.content_margin_right = 3.0
	stylebox.content_margin_top = 2.0
	stylebox.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", stylebox)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	var keybind_label: Label = Label.new()
	keybind_label.name = "KeybindLabel"
	keybind_label.text = SKILL_SLOT_KEYBIND_LABELS[slot_index]
	keybind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keybind_label.add_theme_font_size_override("font_size", 11)
	keybind_label.add_theme_color_override("font_color", SLOT_KEYBIND_COLOR)
	keybind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(keybind_label)
	slot_keybind_labels.append(keybind_label)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = ""
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", SLOT_NAME_COLOR)
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	slot_name_labels.append(name_label)
	return panel

func _build_block_evade_group() -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.name = "BlockEvadeGroup"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", slot_gap_px)
	skill_bar_container.add_child(group)
	block_panel = _build_special_slot_panel("BlockSlot", "Q", "Block", BLOCK_SLOT_COLOR)
	group.add_child(block_panel)
	evade_panel = _build_special_slot_panel("EvadeSlot", "E", "Evade", EVADE_SLOT_COLOR)
	group.add_child(evade_panel)

func _build_special_slot_panel(panel_name: String, keybind_text: String, display_text: String, bg_color: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = panel_name
	panel.custom_minimum_size = Vector2(slot_button_width, (slot_button_height - slot_gap_px) / 2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox: StyleBoxFlat = StyleBoxFlat.new()
	stylebox.bg_color = bg_color
	stylebox.border_color = SLOT_BORDER_COLOR
	stylebox.set_border_width_all(1)
	stylebox.set_corner_radius_all(3)
	stylebox.content_margin_left = 2.0
	stylebox.content_margin_right = 2.0
	stylebox.content_margin_top = 1.0
	stylebox.content_margin_bottom = 1.0
	panel.add_theme_stylebox_override("panel", stylebox)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 3)
	panel.add_child(hbox)
	var key_label: Label = Label.new()
	key_label.text = keybind_text
	key_label.add_theme_font_size_override("font_size", 10)
	key_label.add_theme_color_override("font_color", SLOT_KEYBIND_COLOR)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(key_label)
	var name_label: Label = Label.new()
	name_label.text = display_text
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", SLOT_NAME_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)
	return panel

func _build_hp_bar() -> void:
	var hp_container: Control = Control.new()
	hp_container.name = "HpBarContainer"
	hp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hp_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hp_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hp_container.custom_minimum_size = Vector2(hp_bar_width, hp_bar_height)
	hp_container.size = hp_container.custom_minimum_size
	hp_container.position = Vector2(-hp_bar_width * 0.5, -(bar_bottom_margin_px + slot_button_height + 12 + hp_bar_height))
	hud_root.add_child(hp_container)
	var hp_bg: ColorRect = ColorRect.new()
	hp_bg.name = "HpBarBg"
	hp_bg.color = HP_BAR_BG_COLOR
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(hp_bg)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.name = "HpBarFill"
	hp_bar_fill.color = HP_BAR_COLOR
	hp_bar_fill.position = Vector2(2, 2)
	hp_bar_fill.custom_minimum_size = Vector2(hp_bar_width - 4, hp_bar_height - 4)
	hp_bar_fill.size = hp_bar_fill.custom_minimum_size
	hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(hp_bar_fill)
	var hp_label: Label = Label.new()
	hp_label.name = "HpLabel"
	hp_label.text = "HP"
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(hp_label)

func _build_stamina_bar() -> void:
	var stamina_container: Control = Control.new()
	stamina_container.name = "StaminaBarContainer"
	stamina_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_container.custom_minimum_size = Vector2(stamina_bar_width, stamina_bar_height)
	stamina_container.size = stamina_container.custom_minimum_size
	hud_root.add_child(stamina_container)
	stamina_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stamina_container.grow_horizontal = Control.GROW_DIRECTION_END
	stamina_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var total_skill_bar_width: int = (slot_button_width * 12) + (slot_gap_px * 10) + (group_gap_px * 2) + slot_button_width
	stamina_container.position = Vector2(
		(total_skill_bar_width / 2) + 14,
		-(bar_bottom_margin_px + stamina_bar_height)
	)
	var stamina_bg: ColorRect = ColorRect.new()
	stamina_bg.name = "StaminaBarBg"
	stamina_bg.color = STAMINA_BAR_BG_COLOR
	stamina_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_container.add_child(stamina_bg)
	stamina_bar_fill = ColorRect.new()
	stamina_bar_fill.name = "StaminaBarFill"
	stamina_bar_fill.color = STAMINA_BAR_COLOR
	stamina_bar_fill.position = Vector2(2, 2)
	stamina_bar_fill.custom_minimum_size = Vector2(stamina_bar_width - 4, stamina_bar_height - 4)
	stamina_bar_fill.size = stamina_bar_fill.custom_minimum_size
	stamina_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_container.add_child(stamina_bar_fill)

func _build_target_hp_bar() -> void:
	target_hp_container = Control.new()
	target_hp_container.name = "TargetHpContainer"
	target_hp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hp_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_hp_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	target_hp_container.grow_vertical = Control.GROW_DIRECTION_END
	target_hp_container.custom_minimum_size = Vector2(hp_bar_width, hp_bar_height + 18)
	target_hp_container.size = target_hp_container.custom_minimum_size
	target_hp_container.position = Vector2(-hp_bar_width * 0.5, 32)
	target_hp_container.visible = false
	hud_root.add_child(target_hp_container)
	target_name_label = Label.new()
	target_name_label.name = "TargetNameLabel"
	target_name_label.text = ""
	target_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_name_label.add_theme_font_size_override("font_size", 12)
	target_name_label.add_theme_color_override("font_color", Color(0.92, 0.30, 0.22, 1.0))
	target_name_label.custom_minimum_size = Vector2(hp_bar_width, 16)
	target_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hp_container.add_child(target_name_label)
	var bar_root: Control = Control.new()
	bar_root.name = "TargetBarRoot"
	bar_root.position = Vector2(0, 18)
	bar_root.custom_minimum_size = Vector2(hp_bar_width, hp_bar_height)
	bar_root.size = bar_root.custom_minimum_size
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_hp_container.add_child(bar_root)
	var target_bg: ColorRect = ColorRect.new()
	target_bg.name = "TargetHpBg"
	target_bg.color = Color(0.28, 0.06, 0.06, 1.0)
	target_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(target_bg)
	target_hp_bar_fill = ColorRect.new()
	target_hp_bar_fill.name = "TargetHpFill"
	target_hp_bar_fill.color = Color(0.88, 0.22, 0.16, 1.0)
	target_hp_bar_fill.position = Vector2(2, 2)
	target_hp_bar_fill.custom_minimum_size = Vector2(hp_bar_width - 4, hp_bar_height - 4)
	target_hp_bar_fill.size = target_hp_bar_fill.custom_minimum_size
	target_hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(target_hp_bar_fill)

func _position_skill_bar() -> void:
	if skill_bar_container == null:
		return
	skill_bar_container.position = Vector2(
		-skill_bar_container.size.x * 0.5,
		-(bar_bottom_margin_px + slot_button_height)
	)

func _refresh_skill_slot_visual(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_panels.size():
		return
	var slot_id: StringName = PlayerSkillSlotStateScript.SKILL_SLOT_IDS[slot_index]
	var panel: PanelContainer = slot_panels[slot_index]
	var name_label: Label = slot_name_labels[slot_index]
	var stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if skill_slot_state != null and skill_slot_state.is_slot_assigned(slot_id):
		name_label.text = skill_slot_state.get_slot_display_name(slot_id)
		if stylebox != null:
			stylebox.bg_color = SLOT_ASSIGNED_COLOR
	else:
		name_label.text = ""
		if stylebox != null:
			stylebox.bg_color = SLOT_EMPTY_COLOR

func _refresh_block_slot_visual() -> void:
	pass

func _refresh_evade_slot_visual() -> void:
	pass

func _flash_slot_activation(slot_id: StringName) -> void:
	var slot_index: int = -1
	for index: int in range(PlayerSkillSlotStateScript.SKILL_SLOT_IDS.size()):
		if PlayerSkillSlotStateScript.SKILL_SLOT_IDS[index] == slot_id:
			slot_index = index
			break
	if slot_index < 0 or slot_index >= slot_panels.size():
		return
	var panel: PanelContainer = slot_panels[slot_index]
	var stylebox: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if stylebox != null:
		stylebox.bg_color = SLOT_ACTIVE_COLOR
	var tween: Tween = create_tween()
	tween.tween_callback(_refresh_skill_slot_visual.bind(slot_index)).set_delay(0.18)
