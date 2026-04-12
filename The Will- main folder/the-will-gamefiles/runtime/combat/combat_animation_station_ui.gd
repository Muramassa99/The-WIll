extends CanvasLayer
class_name CombatAnimationStationUI

signal closed

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")

const AUTHORING_MODE_LABELS := {
	CombatAnimationStationStateScript.AUTHORING_MODE_IDLE: "Idle Drafts",
	CombatAnimationStationStateScript.AUTHORING_MODE_SKILL: "Skill Drafts",
}

const TWO_HAND_STATE_LABELS := {
	CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO: "Auto",
	CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND: "One Hand",
	CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND: "Two Hand",
}

const COLOR_BG_ROOT := Color(0.055, 0.063, 0.098, 0.97)
const COLOR_BG_SECTION := Color(0.078, 0.086, 0.125, 1.0)
const COLOR_BG_PREVIEW := Color(0.035, 0.040, 0.065, 1.0)
const COLOR_BG_INPUT := Color(0.065, 0.073, 0.11, 1.0)
const COLOR_BORDER := Color(0.16, 0.18, 0.25, 0.7)
const COLOR_BORDER_ACCENT := Color(0.58, 0.48, 0.22, 0.6)
const COLOR_TEXT := Color(0.78, 0.80, 0.86, 1.0)
const COLOR_TEXT_DIM := Color(0.45, 0.48, 0.56, 1.0)
const COLOR_TEXT_HEADER := Color(0.76, 0.65, 0.32, 1.0)
const COLOR_TEXT_TITLE := Color(0.88, 0.78, 0.38, 1.0)
const COLOR_BUTTON_NORMAL := Color(0.10, 0.11, 0.16, 1.0)
const COLOR_BUTTON_HOVER := Color(0.14, 0.15, 0.22, 1.0)
const COLOR_BUTTON_PRESSED := Color(0.18, 0.16, 0.12, 1.0)
const COLOR_BACKDROP := Color(0.02, 0.02, 0.04, 0.82)
const COLOR_SEPARATOR := Color(0.18, 0.20, 0.28, 0.5)
const FONT_TITLE := 20
const FONT_SECTION := 13
const FONT_BODY := 12
const FONT_HINT := 11

var backdrop: ColorRect = null
var panel: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var shortcut_hint_label: Label = null
var project_list: ItemList = null
var authoring_mode_option_button: OptionButton = null
var draft_list: ItemList = null
var new_skill_draft_button: Button = null
var point_list: ItemList = null
var add_point_button: Button = null
var duplicate_point_button: Button = null
var remove_point_button: Button = null
var set_continuity_button: Button = null
var play_preview_button: Button = null
var draft_name_edit: LineEdit = null
var skill_name_edit: LineEdit = null
var skill_slot_edit: LineEdit = null
var skill_description_edit: TextEdit = null
var preview_speed_spin_box: SpinBox = null
var preview_loop_check_box: CheckBox = null
var position_x_spin_box: SpinBox = null
var position_y_spin_box: SpinBox = null
var position_z_spin_box: SpinBox = null
var rotation_x_spin_box: SpinBox = null
var rotation_y_spin_box: SpinBox = null
var rotation_z_spin_box: SpinBox = null
var plane_vertical_spin_box: SpinBox = null
var transition_spin_box: SpinBox = null
var body_support_spin_box: SpinBox = null
var two_hand_state_option_button: OptionButton = null
var grip_mode_option_button: OptionButton = null
var preview_view_container: SubViewportContainer = null
var preview_subviewport: SubViewport = null
var curve_in_x_spin_box: SpinBox = null
var curve_in_y_spin_box: SpinBox = null
var curve_in_z_spin_box: SpinBox = null
var curve_out_x_spin_box: SpinBox = null
var curve_out_y_spin_box: SpinBox = null
var curve_out_z_spin_box: SpinBox = null
var pommel_x_spin_box: SpinBox = null
var pommel_y_spin_box: SpinBox = null
var pommel_z_spin_box: SpinBox = null
var pommel_curve_in_x_spin_box: SpinBox = null
var pommel_curve_in_y_spin_box: SpinBox = null
var pommel_curve_in_z_spin_box: SpinBox = null
var pommel_curve_out_x_spin_box: SpinBox = null
var pommel_curve_out_y_spin_box: SpinBox = null
var pommel_curve_out_z_spin_box: SpinBox = null
var weapon_roll_spin_box: SpinBox = null
var axial_reposition_spin_box: SpinBox = null
var grip_seat_slide_spin_box: SpinBox = null
var draft_notes_edit: TextEdit = null
var summary_label: Label = null
var footer_status_label: Label = null
var close_button: Button = null

var active_player = null
var active_wip_library: PlayerForgeWipLibraryState = null
var active_wip: CraftedItemWIP = null
var active_saved_wip_id: StringName = StringName()
var refreshing_controls: bool = false
var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()

func _ready() -> void:
	_build_ui()
	visible = false
	project_list.item_clicked.connect(_on_project_item_clicked)
	draft_list.item_clicked.connect(_on_draft_item_clicked)
	point_list.item_clicked.connect(_on_motion_node_item_clicked)
	authoring_mode_option_button.item_selected.connect(_on_authoring_mode_selected)
	new_skill_draft_button.pressed.connect(_on_new_skill_draft_pressed)
	add_point_button.pressed.connect(_on_add_motion_node_pressed)
	duplicate_point_button.pressed.connect(_on_duplicate_motion_node_pressed)
	remove_point_button.pressed.connect(_on_remove_motion_node_pressed)
	set_continuity_button.pressed.connect(_on_set_continuity_pressed)
	play_preview_button.pressed.connect(_on_play_preview_pressed)
	draft_name_edit.text_submitted.connect(_on_draft_name_submitted)
	draft_name_edit.focus_exited.connect(_on_draft_name_focus_exited)
	skill_name_edit.text_submitted.connect(_on_skill_name_submitted)
	skill_name_edit.focus_exited.connect(_on_skill_name_focus_exited)
	skill_slot_edit.text_submitted.connect(_on_skill_slot_submitted)
	skill_slot_edit.focus_exited.connect(_on_skill_slot_focus_exited)
	skill_description_edit.focus_exited.connect(_on_skill_description_focus_exited)
	preview_speed_spin_box.value_changed.connect(_on_preview_speed_changed)
	preview_loop_check_box.toggled.connect(_on_preview_loop_toggled)
	position_x_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(0))
	position_y_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(1))
	position_z_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(2))
	rotation_x_spin_box.value_changed.connect(_on_plane_orientation_component_changed.bind(0))
	rotation_y_spin_box.value_changed.connect(_on_plane_orientation_component_changed.bind(1))
	rotation_z_spin_box.value_changed.connect(_on_plane_orientation_component_changed.bind(2))
	plane_vertical_spin_box.value_changed.connect(_on_plane_vertical_changed)
	transition_spin_box.value_changed.connect(_on_transition_changed)
	body_support_spin_box.value_changed.connect(_on_body_support_changed)
	two_hand_state_option_button.item_selected.connect(_on_two_hand_state_selected)
	grip_mode_option_button.item_selected.connect(_on_grip_mode_selected)
	preview_view_container.resized.connect(_on_preview_container_resized)
	curve_in_x_spin_box.value_changed.connect(_on_tip_curve_in_component_changed.bind(0))
	curve_in_y_spin_box.value_changed.connect(_on_tip_curve_in_component_changed.bind(1))
	curve_in_z_spin_box.value_changed.connect(_on_tip_curve_in_component_changed.bind(2))
	curve_out_x_spin_box.value_changed.connect(_on_tip_curve_out_component_changed.bind(0))
	curve_out_y_spin_box.value_changed.connect(_on_tip_curve_out_component_changed.bind(1))
	curve_out_z_spin_box.value_changed.connect(_on_tip_curve_out_component_changed.bind(2))
	pommel_x_spin_box.value_changed.connect(_on_pommel_position_component_changed.bind(0))
	pommel_y_spin_box.value_changed.connect(_on_pommel_position_component_changed.bind(1))
	pommel_z_spin_box.value_changed.connect(_on_pommel_position_component_changed.bind(2))
	pommel_curve_in_x_spin_box.value_changed.connect(_on_pommel_curve_in_component_changed.bind(0))
	pommel_curve_in_y_spin_box.value_changed.connect(_on_pommel_curve_in_component_changed.bind(1))
	pommel_curve_in_z_spin_box.value_changed.connect(_on_pommel_curve_in_component_changed.bind(2))
	pommel_curve_out_x_spin_box.value_changed.connect(_on_pommel_curve_out_component_changed.bind(0))
	pommel_curve_out_y_spin_box.value_changed.connect(_on_pommel_curve_out_component_changed.bind(1))
	pommel_curve_out_z_spin_box.value_changed.connect(_on_pommel_curve_out_component_changed.bind(2))
	weapon_roll_spin_box.value_changed.connect(_on_weapon_roll_changed)
	axial_reposition_spin_box.value_changed.connect(_on_axial_reposition_changed)
	grip_seat_slide_spin_box.value_changed.connect(_on_grip_seat_slide_changed)
	draft_notes_edit.focus_exited.connect(_on_draft_notes_focus_exited)
	close_button.pressed.connect(close_ui)
	_register_station_input_actions()
	_populate_static_options()
	_refresh_all("Select a saved weapon WIP to begin authoring.")

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"skill_crafter_prev_node"):
		_navigate_motion_node(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"skill_crafter_next_node"):
		_navigate_motion_node(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"skill_crafter_copy_node"):
		duplicate_selected_motion_node()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"skill_crafter_delete_node"):
		remove_selected_motion_node()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"skill_crafter_cycle_focus"):
		_cycle_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"skill_crafter_play_preview"):
		_toggle_preview_playback()
		get_viewport().set_input_as_handled()
		return

func toggle_for(player, bench_name: String) -> void:
	if panel.visible:
		close_ui()
		return
	open_for(player, bench_name)

func open_for(player, bench_name: String) -> void:
	active_player = player
	active_wip_library = _get_forge_wip_library_state()
	title_label.text = "SKILL CRAFTER"
	subtitle_label.text = bench_name
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)
	visible = true
	backdrop.visible = true
	panel.visible = true
	_select_initial_wip()
	_refresh_all("Select a weapon and authored draft to continue.")

func close_ui() -> void:
	if not panel.visible:
		return
	_persist_active_wip("Combat animation station closed.")
	panel.visible = false
	backdrop.visible = false
	visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	active_player = null
	active_wip_library = null
	active_wip = null
	active_saved_wip_id = StringName()
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func select_saved_wip(saved_wip_id: StringName) -> bool:
	if active_wip_library == null:
		return false
	var selected_clone: CraftedItemWIP = active_wip_library.get_saved_wip_clone(saved_wip_id)
	if selected_clone == null:
		return false
	selected_clone.ensure_combat_animation_station_state()
	active_saved_wip_id = saved_wip_id
	active_wip = selected_clone
	active_wip_library.set_selected_wip_id(saved_wip_id)
	_refresh_all("Loaded %s." % selected_clone.forge_project_name)
	return true

func select_authoring_mode(mode_id: StringName) -> bool:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return false
	if not CombatAnimationStationStateScript.get_authoring_mode_ids().has(mode_id):
		return false
	station_state.set("selected_authoring_mode", mode_id)
	_ensure_valid_draft_selection()
	_persist_active_wip("Authoring mode updated.")
	_refresh_all("Authoring mode updated.")
	return true

func select_draft(draft_identifier: StringName) -> bool:
	var station_state: Resource = _get_active_station_state()
	var draft: Resource = _find_active_draft_by_identifier(draft_identifier)
	if station_state == null or draft == null:
		return false
	if _is_idle_mode():
		station_state.set("selected_idle_context_id", draft_identifier)
	else:
		station_state.set("selected_skill_id", draft_identifier)
	var selected_node_index: int = int(draft.get("selected_motion_node_index"))
	draft.set("selected_motion_node_index", clampi(selected_node_index, 0, maxi(int((draft.get("motion_node_chain") as Array).size()) - 1, 0)))
	_persist_active_wip("Draft selection updated.")
	_refresh_all("Draft selection updated.")
	return true

func create_skill_draft(skill_id: StringName = StringName(), display_name: String = "") -> StringName:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return StringName()
	station_state.set("selected_authoring_mode", CombatAnimationStationStateScript.AUTHORING_MODE_SKILL)
	var resolved_skill_id: StringName = skill_id if skill_id != StringName() else _build_unique_skill_draft_id()
	var resolved_display_name: String = display_name if not display_name.strip_edges().is_empty() else _build_skill_display_name(resolved_skill_id)
	var draft: Resource = station_state.call(
		"get_or_create_skill_draft",
		resolved_skill_id,
		resolved_display_name,
		active_wip.grip_style_mode if active_wip != null else &"grip_normal"
	)
	if draft == null:
		return StringName()
	station_state.set("selected_skill_id", resolved_skill_id)
	_persist_active_wip("Created %s." % resolved_display_name)
	_refresh_all("Created %s." % resolved_display_name)
	return resolved_skill_id

func select_motion_node(node_index: int) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		return false
	draft.set("selected_motion_node_index", clampi(node_index, 0, motion_node_chain.size() - 1))
	_persist_active_wip("Motion node selection updated.")
	_refresh_all("Motion node selection updated.")
	return true

func insert_motion_node_after_selection() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var insert_index: int = clampi(int(draft.get("selected_motion_node_index")), 0, maxi(motion_node_chain.size() - 1, 0)) + 1
	var seed_node: CombatAnimationMotionNode = _get_active_motion_node()
	var new_node: CombatAnimationMotionNode = _duplicate_or_build_motion_node(seed_node)
	if new_node == null:
		return false
	motion_node_chain.insert(insert_index, new_node)
	draft.set("selected_motion_node_index", insert_index)
	_normalize_draft(draft)
	_persist_active_wip("Inserted motion node %d." % insert_index)
	_refresh_all("Inserted motion node %d." % insert_index)
	return true

func duplicate_selected_motion_node() -> bool:
	var draft: Resource = _get_active_draft()
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if draft == null or motion_node == null:
		return false
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var selected_index: int = clampi(int(draft.get("selected_motion_node_index")), 0, maxi(motion_node_chain.size() - 1, 0))
	var duplicate_node: CombatAnimationMotionNode = _duplicate_or_build_motion_node(motion_node)
	if duplicate_node == null:
		return false
	motion_node_chain.insert(selected_index + 1, duplicate_node)
	draft.set("selected_motion_node_index", selected_index + 1)
	_normalize_draft(draft)
	_persist_active_wip("Duplicated motion node %d." % selected_index)
	_refresh_all("Duplicated motion node %d." % selected_index)
	return true

func remove_selected_motion_node() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.size() <= _get_minimum_motion_node_count(draft):
		_refresh_all("Minimum baseline motion node count reached.")
		return false
	var selected_index: int = clampi(int(draft.get("selected_motion_node_index")), 0, motion_node_chain.size() - 1)
	motion_node_chain.remove_at(selected_index)
	draft.set("selected_motion_node_index", clampi(selected_index, 0, motion_node_chain.size() - 1))
	draft.set("continuity_motion_node_index", clampi(int(draft.get("continuity_motion_node_index")), 0, motion_node_chain.size() - 1))
	_normalize_draft(draft)
	_persist_active_wip("Removed motion node %d." % selected_index)
	_refresh_all("Removed motion node %d." % selected_index)
	return true

func set_selected_motion_node_as_continuity() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("continuity_motion_node_index", int(draft.get("selected_motion_node_index")))
	_persist_active_wip("Continuity motion node updated.")
	_refresh_all("Continuity motion node updated.")
	return true

func set_selected_motion_node_tip_position(tip_position: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.tip_position_local = tip_position
	motion_node.normalize()
	_persist_active_wip("Motion node tip position updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node tip position updated.")
	return true

func set_selected_motion_node_plane_orientation(plane_degrees: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.trajectory_plane_orientation_degrees = plane_degrees
	motion_node.normalize()
	_persist_active_wip("Motion node plane orientation updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node plane orientation updated.")
	return true

func set_selected_motion_node_transition_duration(duration_seconds: float) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.transition_duration_seconds = maxf(duration_seconds, 0.0)
	motion_node.normalize()
	_persist_active_wip("Motion node transition updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_summary("Motion node transition updated.")
	return true

func set_selected_motion_node_body_support_blend(blend_ratio: float) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.body_support_blend = clampf(blend_ratio, 0.0, 1.0)
	motion_node.normalize()
	_persist_active_wip("Motion node body-support blend updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node body-support blend updated.")
	return true

func set_selected_motion_node_two_hand_state(state_id: StringName) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null or not CombatAnimationMotionNodeScript.get_two_hand_state_ids().has(state_id):
		return false
	motion_node.two_hand_state = state_id
	motion_node.normalize()
	_persist_active_wip("Motion node two-hand state updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node two-hand state updated.")
	return true

func set_selected_motion_node_preferred_grip_style(grip_mode: StringName) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	var resolved_grip_mode: StringName = CraftedItemWIPScript.resolve_supported_grip_style(
		grip_mode,
		active_wip.forge_intent if active_wip != null else StringName(),
		active_wip.equipment_context if active_wip != null else StringName()
	)
	motion_node.preferred_grip_style_mode = resolved_grip_mode
	motion_node.normalize()
	_persist_active_wip("Motion node grip preference updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node grip preference updated.")
	return true

func set_selected_motion_node_tip_curve_in(curve_in_handle: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.tip_curve_in_handle = curve_in_handle
	motion_node.normalize()
	_persist_active_wip("Motion node tip curve-in handle updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node tip curve-in handle updated.")
	return true

func set_selected_motion_node_tip_curve_out(curve_out_handle: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.tip_curve_out_handle = curve_out_handle
	motion_node.normalize()
	_persist_active_wip("Motion node tip curve-out handle updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Motion node tip curve-out handle updated.")
	return true

func set_active_draft_display_name(display_name: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("display_name", display_name.strip_edges())
	_normalize_draft(draft)
	_persist_active_wip("Draft display name updated.")
	_refresh_draft_list()
	_refresh_editor_fields()
	_refresh_summary("Draft display name updated.")
	return true

func set_active_draft_slot_id(slot_id: StringName) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("legal_slot_id", slot_id)
	_normalize_draft(draft)
	_persist_active_wip("Draft slot updated.")
	_refresh_draft_list()
	_refresh_editor_fields()
	_refresh_summary("Draft slot updated.")
	return true

func set_active_draft_preview_speed(speed_scale: float) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("preview_playback_speed_scale", maxf(speed_scale, 0.01))
	_normalize_draft(draft)
	_persist_active_wip("Preview speed updated.")
	_refresh_editor_fields()
	_refresh_summary("Preview speed updated.")
	return true

func set_active_draft_preview_loop(loop_enabled: bool) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("preview_loop_enabled", loop_enabled)
	_normalize_draft(draft)
	_persist_active_wip("Preview loop updated.")
	_refresh_editor_fields()
	_refresh_summary("Preview loop updated.")
	return true

func set_active_draft_notes(notes_text: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("draft_notes", notes_text)
	_normalize_draft(draft)
	_persist_active_wip("Draft notes updated.")
	_refresh_summary("Draft notes updated.")
	return true

func get_active_saved_wip_id() -> StringName:
	return active_saved_wip_id

func get_active_draft_identifier() -> StringName:
	var draft: Resource = _get_active_draft()
	return _get_draft_identifier(draft)

func get_selected_motion_node_index() -> int:
	var draft: Resource = _get_active_draft()
	return int(draft.get("selected_motion_node_index")) if draft != null else 0

func get_preview_debug_state() -> Dictionary:
	return preview_presenter.get_debug_state(preview_subviewport)

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.visible = false
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COLOR_BACKDROP
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	var safe_margin_h := 24
	var safe_margin_v := 16
	panel.offset_left = safe_margin_h
	panel.offset_top = safe_margin_v
	panel.offset_right = -safe_margin_h
	panel.offset_bottom = -safe_margin_v
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = COLOR_BG_ROOT
	root_style.set_border_width_all(1)
	root_style.border_color = COLOR_BORDER
	root_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", root_style)
	add_child(panel)
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["margin_left", "margin_right"]:
		root_margin.add_theme_constant_override(side, 10)
	for side: String in ["margin_top", "margin_bottom"]:
		root_margin.add_theme_constant_override(side, 8)
	panel.add_child(root_margin)
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	root_margin.add_child(root_vbox)
	_build_header(root_vbox)
	var header_sep := HSeparator.new()
	header_sep.add_theme_constant_override("separation", 2)
	header_sep.add_theme_stylebox_override("separator", _make_separator_style())
	root_vbox.add_child(header_sep)
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 4)
	root_vbox.add_child(content_hbox)
	_build_left_sidebar(content_hbox)
	_build_center_column(content_hbox)
	_build_right_inspector(content_hbox)
	_build_footer(root_vbox)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	title_label = Label.new()
	title_label.text = "SKILL CRAFTER"
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_TITLE)
	row.add_child(title_label)
	var divider := Label.new()
	divider.text = "—"
	divider.add_theme_color_override("font_color", COLOR_BORDER_ACCENT)
	row.add_child(divider)
	subtitle_label = Label.new()
	subtitle_label.text = ""
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle_label.add_theme_font_size_override("font_size", FONT_BODY)
	subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	subtitle_label.clip_text = true
	row.add_child(subtitle_label)
	shortcut_hint_label = Label.new()
	shortcut_hint_label.text = "Q/E nav  R copy  T del  Space cycle  F preview"
	shortcut_hint_label.add_theme_font_size_override("font_size", FONT_HINT)
	shortcut_hint_label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.32, 0.7))
	row.add_child(shortcut_hint_label)
	close_button = _build_styled_button(row, "✕")
	close_button.custom_minimum_size = Vector2(32, 0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END

func _build_left_sidebar(parent: HBoxContainer) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(180, 0)
	sidebar.size_flags_horizontal = Control.SIZE_FILL
	sidebar.size_flags_stretch_ratio = 0.22
	sidebar.add_theme_constant_override("separation", 4)
	parent.add_child(sidebar)
	var w_vbox := _build_section_panel(sidebar, true)
	_build_section_header(w_vbox, "WEAPONS")
	project_list = ItemList.new()
	project_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	project_list.allow_reselect = true
	_style_item_list(project_list)
	w_vbox.add_child(project_list)
	var m_vbox := _build_section_panel(sidebar, false)
	_build_section_header(m_vbox, "AUTHORING MODE")
	authoring_mode_option_button = OptionButton.new()
	_style_option_button(authoring_mode_option_button)
	m_vbox.add_child(authoring_mode_option_button)
	var d_vbox := _build_section_panel(sidebar, true)
	var d_row := HBoxContainer.new()
	d_row.add_theme_constant_override("separation", 4)
	d_vbox.add_child(d_row)
	var d_label := Label.new()
	d_label.text = "DRAFTS"
	d_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_label.add_theme_font_size_override("font_size", FONT_SECTION)
	d_label.add_theme_color_override("font_color", COLOR_TEXT_HEADER)
	d_row.add_child(d_label)
	new_skill_draft_button = _build_styled_button(d_row, "+ New")
	new_skill_draft_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	draft_list = ItemList.new()
	draft_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draft_list.allow_reselect = true
	_style_item_list(draft_list)
	d_vbox.add_child(draft_list)
	var s_vbox := _build_section_panel(sidebar, false)
	_build_section_header(s_vbox, "SUMMARY")
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", FONT_HINT)
	summary_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	summary_label.text = "No weapon selected."
	s_vbox.add_child(summary_label)

func _build_center_column(parent: HBoxContainer) -> void:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1.0
	center.add_theme_constant_override("separation", 4)
	parent.add_child(center)
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pv_style := _make_panel_style(COLOR_BG_PREVIEW, COLOR_BORDER_ACCENT, 2, 4)
	preview_panel.add_theme_stylebox_override("panel", pv_style)
	center.add_child(preview_panel)
	var pv_vbox := VBoxContainer.new()
	pv_vbox.add_theme_constant_override("separation", 0)
	preview_panel.add_child(pv_vbox)
	preview_view_container = SubViewportContainer.new()
	preview_view_container.custom_minimum_size = Vector2(280, 180)
	preview_view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_view_container.stretch = true
	pv_vbox.add_child(preview_view_container)
	preview_subviewport = SubViewport.new()
	preview_subviewport.size = Vector2i(480, 320)
	preview_subviewport.transparent_bg = false
	preview_subviewport.handle_input_locally = false
	preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_view_container.add_child(preview_subviewport)
	var tl_vbox := _build_section_panel(center, false)
	_build_section_header(tl_vbox, "MOTION NODE CHAIN")
	point_list = ItemList.new()
	point_list.custom_minimum_size = Vector2(0, 64)
	point_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	point_list.allow_reselect = true
	_style_item_list(point_list)
	tl_vbox.add_child(point_list)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	tl_vbox.add_child(action_row)
	add_point_button = _build_styled_button(action_row, "+ Add")
	duplicate_point_button = _build_styled_button(action_row, "Copy [R]")
	remove_point_button = _build_styled_button(action_row, "Delete [T]")
	set_continuity_button = _build_styled_button(action_row, "Continuity")
	play_preview_button = _build_styled_button(action_row, "▶ Play [F]")
	var ds_vbox := _build_section_panel(center, false)
	_build_section_header(ds_vbox, "DRAFT SETTINGS")
	var ds_cols := HBoxContainer.new()
	ds_cols.add_theme_constant_override("separation", 12)
	ds_vbox.add_child(ds_cols)
	var ds_left := VBoxContainer.new()
	ds_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds_left.add_theme_constant_override("separation", 3)
	ds_cols.add_child(ds_left)
	_build_field_label(ds_left, "Draft Name")
	draft_name_edit = LineEdit.new()
	draft_name_edit.placeholder_text = "Unnamed Draft"
	_style_line_edit(draft_name_edit)
	ds_left.add_child(draft_name_edit)
	_build_field_label(ds_left, "Skill Name")
	skill_name_edit = LineEdit.new()
	skill_name_edit.placeholder_text = "Display name"
	_style_line_edit(skill_name_edit)
	ds_left.add_child(skill_name_edit)
	_build_field_label(ds_left, "Skill Slot")
	skill_slot_edit = LineEdit.new()
	skill_slot_edit.placeholder_text = "slot_damage / slot_block"
	_style_line_edit(skill_slot_edit)
	ds_left.add_child(skill_slot_edit)
	var ds_right := VBoxContainer.new()
	ds_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds_right.add_theme_constant_override("separation", 3)
	ds_cols.add_child(ds_right)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	ds_right.add_child(speed_row)
	var speed_lbl := Label.new()
	speed_lbl.text = "Speed"
	speed_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	speed_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	speed_row.add_child(speed_lbl)
	preview_speed_spin_box = SpinBox.new()
	preview_speed_spin_box.min_value = 0.01
	preview_speed_spin_box.max_value = 3.0
	preview_speed_spin_box.step = 0.05
	preview_speed_spin_box.value = 1.0
	preview_speed_spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_spinbox(preview_speed_spin_box)
	speed_row.add_child(preview_speed_spin_box)
	preview_loop_check_box = CheckBox.new()
	preview_loop_check_box.text = "Loop Preview"
	preview_loop_check_box.add_theme_color_override("font_color", COLOR_TEXT)
	preview_loop_check_box.add_theme_font_size_override("font_size", FONT_BODY)
	ds_right.add_child(preview_loop_check_box)
	_build_field_label(ds_right, "Description")
	skill_description_edit = TextEdit.new()
	skill_description_edit.custom_minimum_size = Vector2(0, 34)
	skill_description_edit.placeholder_text = "Skill description..."
	_style_text_edit(skill_description_edit)
	ds_right.add_child(skill_description_edit)
	_build_field_label(ds_right, "Notes")
	draft_notes_edit = TextEdit.new()
	draft_notes_edit.custom_minimum_size = Vector2(0, 34)
	_style_text_edit(draft_notes_edit)
	ds_right.add_child(draft_notes_edit)

func _build_right_inspector(parent: HBoxContainer) -> void:
	var inspector_panel := PanelContainer.new()
	inspector_panel.custom_minimum_size = Vector2(210, 0)
	inspector_panel.size_flags_horizontal = Control.SIZE_FILL
	inspector_panel.size_flags_stretch_ratio = 0.26
	inspector_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_SECTION, COLOR_BORDER, 1, 4))
	parent.add_child(inspector_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(vbox)
	_build_section_header(vbox, "TIP POSITION")
	_build_field_label(vbox, "Position (X / Y / Z)")
	var tip_pos: Array[SpinBox] = _build_vec3_row(vbox, -4.0, 4.0, 0.01)
	position_x_spin_box = tip_pos[0]
	position_y_spin_box = tip_pos[1]
	position_z_spin_box = tip_pos[2]
	_build_field_label(vbox, "Curve In (X / Y / Z)")
	var tip_ci: Array[SpinBox] = _build_vec3_row(vbox, -2.0, 2.0, 0.01)
	curve_in_x_spin_box = tip_ci[0]
	curve_in_y_spin_box = tip_ci[1]
	curve_in_z_spin_box = tip_ci[2]
	_build_field_label(vbox, "Curve Out (X / Y / Z)")
	var tip_co: Array[SpinBox] = _build_vec3_row(vbox, -2.0, 2.0, 0.01)
	curve_out_x_spin_box = tip_co[0]
	curve_out_y_spin_box = tip_co[1]
	curve_out_z_spin_box = tip_co[2]
	_build_inspector_separator(vbox)
	_build_section_header(vbox, "TRAJECTORY PLANE")
	_build_field_label(vbox, "Orientation (X / Y / Z)")
	var plane: Array[SpinBox] = _build_vec3_row(vbox, -360.0, 360.0, 0.5)
	rotation_x_spin_box = plane[0]
	rotation_y_spin_box = plane[1]
	rotation_z_spin_box = plane[2]
	plane_vertical_spin_box = _build_labeled_spinbox(vbox, "Vertical Offset", -2.0, 2.0, 0.01)
	_build_inspector_separator(vbox)
	_build_section_header(vbox, "POMMEL POSITION")
	_build_field_label(vbox, "Position (X / Y / Z)")
	var pom_pos: Array[SpinBox] = _build_vec3_row(vbox, -4.0, 4.0, 0.01)
	pommel_x_spin_box = pom_pos[0]
	pommel_y_spin_box = pom_pos[1]
	pommel_z_spin_box = pom_pos[2]
	_build_field_label(vbox, "Curve In (X / Y / Z)")
	var pom_ci: Array[SpinBox] = _build_vec3_row(vbox, -2.0, 2.0, 0.01)
	pommel_curve_in_x_spin_box = pom_ci[0]
	pommel_curve_in_y_spin_box = pom_ci[1]
	pommel_curve_in_z_spin_box = pom_ci[2]
	_build_field_label(vbox, "Curve Out (X / Y / Z)")
	var pom_co: Array[SpinBox] = _build_vec3_row(vbox, -2.0, 2.0, 0.01)
	pommel_curve_out_x_spin_box = pom_co[0]
	pommel_curve_out_y_spin_box = pom_co[1]
	pommel_curve_out_z_spin_box = pom_co[2]
	_build_inspector_separator(vbox)
	_build_section_header(vbox, "WEAPON ORIENTATION")
	weapon_roll_spin_box = _build_labeled_spinbox(vbox, "Weapon Roll (°)", -120.0, 120.0, 1.0)
	axial_reposition_spin_box = _build_labeled_spinbox(vbox, "Axial Reposition", -1.0, 1.0, 0.01)
	grip_seat_slide_spin_box = _build_labeled_spinbox(vbox, "Grip Seat Slide", -1.0, 1.0, 0.01)
	_build_inspector_separator(vbox)
	_build_section_header(vbox, "TIMING & BEHAVIOR")
	transition_spin_box = _build_labeled_spinbox(vbox, "Transition (s)", 0.0, 2.0, 0.01)
	body_support_spin_box = _build_labeled_spinbox(vbox, "Body Support", 0.0, 1.0, 0.05)
	_build_field_label(vbox, "Two-Hand State")
	two_hand_state_option_button = OptionButton.new()
	_style_option_button(two_hand_state_option_button)
	vbox.add_child(two_hand_state_option_button)
	_build_field_label(vbox, "Grip Mode")
	grip_mode_option_button = OptionButton.new()
	_style_option_button(grip_mode_option_button)
	vbox.add_child(grip_mode_option_button)

func _build_footer(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	sep.add_theme_stylebox_override("separator", _make_separator_style())
	parent.add_child(sep)
	footer_status_label = Label.new()
	footer_status_label.text = "Select a saved weapon WIP to begin authoring."
	footer_status_label.add_theme_font_size_override("font_size", FONT_BODY)
	footer_status_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	footer_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(footer_status_label)

func _build_section_panel(parent: Control, expand: bool) -> VBoxContainer:
	var section := PanelContainer.new()
	section.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_SECTION, COLOR_BORDER, 1, 4))
	if expand:
		section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	section.add_child(vbox)
	return vbox

func _build_section_header(parent: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SECTION)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_HEADER)
	parent.add_child(lbl)
	return lbl

func _build_field_label(parent: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_BODY)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(lbl)
	return lbl

func _build_vec3_row(parent: Control, min_val: float, max_val: float, step_val: float) -> Array[SpinBox]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var result: Array[SpinBox] = []
	for i: int in range(3):
		var sb := SpinBox.new()
		sb.min_value = min_val
		sb.max_value = max_val
		sb.step = step_val
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_spinbox(sb)
		row.add_child(sb)
		result.append(sb)
	return result

func _build_labeled_spinbox(parent: Control, label_text: String, min_val: float, max_val: float, step_val: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", FONT_BODY)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step_val
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_spinbox(sb)
	row.add_child(sb)
	return sb

func _build_styled_button(parent: Control, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_BUTTON_NORMAL
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 4.0
	normal.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = COLOR_BUTTON_HOVER
	hover.border_color = COLOR_BORDER_ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = COLOR_BUTTON_PRESSED
	btn.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.07, 0.10, 0.7)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_TITLE)
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
	parent.add_child(btn)
	return btn

func _build_inspector_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	sep.add_theme_stylebox_override("separator", _make_separator_style())
	parent.add_child(sep)

func _make_panel_style(bg: Color, border: Color, border_w: int = 1, corner: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style

func _make_separator_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SEPARATOR
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	return style

func _style_item_list(il: ItemList) -> void:
	var ps := StyleBoxFlat.new()
	ps.bg_color = COLOR_BG_INPUT
	ps.border_color = COLOR_BORDER
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(3)
	ps.content_margin_left = 4.0
	ps.content_margin_top = 4.0
	ps.content_margin_right = 4.0
	ps.content_margin_bottom = 4.0
	il.add_theme_stylebox_override("panel", ps)
	il.add_theme_color_override("font_color", COLOR_TEXT)
	il.add_theme_color_override("font_selected_color", COLOR_TEXT_TITLE)
	il.add_theme_font_size_override("font_size", FONT_BODY)

func _style_spinbox(sb: SpinBox) -> void:
	sb.add_theme_font_size_override("font_size", FONT_BODY)
	var le: LineEdit = sb.get_line_edit()
	if le != null:
		var le_style := StyleBoxFlat.new()
		le_style.bg_color = COLOR_BG_INPUT
		le_style.border_color = COLOR_BORDER
		le_style.set_border_width_all(1)
		le_style.set_corner_radius_all(2)
		le_style.content_margin_left = 4.0
		le_style.content_margin_right = 4.0
		le.add_theme_stylebox_override("normal", le_style)
		le.add_theme_color_override("font_color", COLOR_TEXT)
		le.add_theme_font_size_override("font_size", FONT_BODY)

func _style_line_edit(le: LineEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	le.add_theme_stylebox_override("normal", style)
	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = COLOR_BORDER_ACCENT
	le.add_theme_stylebox_override("focus", focus_style)
	le.add_theme_color_override("font_color", COLOR_TEXT)
	le.add_theme_color_override("font_placeholder_color", COLOR_TEXT_DIM)
	le.add_theme_font_size_override("font_size", FONT_BODY)

func _style_text_edit(te: TextEdit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	te.add_theme_stylebox_override("normal", style)
	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = COLOR_BORDER_ACCENT
	te.add_theme_stylebox_override("focus", focus_style)
	te.add_theme_color_override("font_color", COLOR_TEXT)
	te.add_theme_color_override("font_placeholder_color", COLOR_TEXT_DIM)
	te.add_theme_font_size_override("font_size", FONT_BODY)

func _style_option_button(ob: OptionButton) -> void:
	ob.add_theme_font_size_override("font_size", FONT_BODY)
	ob.add_theme_color_override("font_color", COLOR_TEXT)

func _populate_static_options() -> void:
	authoring_mode_option_button.clear()
	for mode_id: StringName in CombatAnimationStationStateScript.get_authoring_mode_ids():
		authoring_mode_option_button.add_item(AUTHORING_MODE_LABELS.get(mode_id, String(mode_id)))
		authoring_mode_option_button.set_item_metadata(authoring_mode_option_button.get_item_count() - 1, mode_id)
	two_hand_state_option_button.clear()
	for state_id: StringName in CombatAnimationMotionNodeScript.get_two_hand_state_ids():
		two_hand_state_option_button.add_item(TWO_HAND_STATE_LABELS.get(state_id, String(state_id)))
		two_hand_state_option_button.set_item_metadata(two_hand_state_option_button.get_item_count() - 1, state_id)
	grip_mode_option_button.clear()
	for grip_mode: StringName in CraftedItemWIPScript.get_grip_style_modes():
		grip_mode_option_button.add_item(CraftedItemWIPScript.get_grip_style_label(grip_mode))
		grip_mode_option_button.set_item_metadata(grip_mode_option_button.get_item_count() - 1, grip_mode)

func _select_initial_wip() -> void:
	active_wip = null
	active_saved_wip_id = StringName()
	if active_wip_library == null or not active_wip_library.has_saved_wips():
		return
	var selected_id: StringName = active_wip_library.selected_wip_id
	if selected_id == StringName():
		var saved_wips: Array[CraftedItemWIP] = active_wip_library.get_saved_wips()
		selected_id = saved_wips[0].wip_id if not saved_wips.is_empty() and saved_wips[0] != null else StringName()
	if selected_id != StringName():
		select_saved_wip(selected_id)

func _refresh_all(status_message: String = "") -> void:
	_refresh_project_list()
	_refresh_authoring_mode_selector()
	_refresh_draft_list()
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary(status_message)

func _refresh_project_list() -> void:
	project_list.clear()
	if active_wip_library == null:
		return
	var saved_wips: Array[CraftedItemWIP] = active_wip_library.get_saved_wips()
	for saved_wip: CraftedItemWIP in saved_wips:
		if saved_wip == null:
			continue
		var builder_scope_label: String = CraftedItemWIPScript.get_builder_scope_label(
			saved_wip.forge_builder_path_id,
			saved_wip.forge_builder_component_id
		)
		var item_text: String = "%s | %s" % [saved_wip.forge_project_name, builder_scope_label]
		project_list.add_item(item_text)
		var item_index: int = project_list.get_item_count() - 1
		project_list.set_item_metadata(item_index, saved_wip.wip_id)
		if saved_wip.wip_id == active_saved_wip_id:
			project_list.select(item_index)

func _refresh_authoring_mode_selector() -> void:
	var station_state: Resource = _get_active_station_state()
	authoring_mode_option_button.disabled = station_state == null
	if station_state == null:
		return
	var selected_mode: StringName = station_state.get("selected_authoring_mode")
	for item_index: int in range(authoring_mode_option_button.get_item_count()):
		if authoring_mode_option_button.get_item_metadata(item_index) == selected_mode:
			authoring_mode_option_button.select(item_index)
			break

func _refresh_draft_list() -> void:
	draft_list.clear()
	var drafts: Array[Resource] = _get_active_drafts()
	for draft: Resource in drafts:
		if draft == null:
			continue
		draft_list.add_item(_build_draft_list_label(draft))
		var item_index: int = draft_list.get_item_count() - 1
		draft_list.set_item_metadata(item_index, _get_draft_identifier(draft))
		if _get_draft_identifier(draft) == get_active_draft_identifier():
			draft_list.select(item_index)
	new_skill_draft_button.visible = _is_skill_mode()
	new_skill_draft_button.disabled = _get_active_station_state() == null

func _refresh_motion_node_list() -> void:
	point_list.clear()
	var draft: Resource = _get_active_draft()
	if draft == null:
		return
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var selected_node_index: int = int(draft.get("selected_motion_node_index"))
	var continuity_node_index: int = int(draft.get("continuity_motion_node_index"))
	for node_index: int in range(motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var continuity_marker: String = " | continuity" if node_index == continuity_node_index else ""
		var item_text: String = "N%02d | tip %s%s" % [
			node_index + 1,
			_snapped_vector3_text(motion_node.tip_position_local, 0.001),
			continuity_marker,
		]
		point_list.add_item(item_text)
		var item_id: int = point_list.get_item_count() - 1
		point_list.set_item_metadata(item_id, node_index)
		if node_index == selected_node_index:
			point_list.select(item_id)

func _refresh_editor_fields() -> void:
	refreshing_controls = true
	var draft: Resource = _get_active_draft()
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	var has_draft: bool = draft != null
	var has_node: bool = motion_node != null
	draft_name_edit.editable = has_draft
	draft_name_edit.text = String(draft.get("display_name")) if has_draft else ""
	skill_name_edit.editable = has_draft
	skill_name_edit.text = String(draft.get("skill_name")) if has_draft else ""
	skill_slot_edit.editable = has_draft
	skill_slot_edit.text = String(draft.get("legal_slot_id")) if has_draft else ""
	skill_description_edit.editable = has_draft
	skill_description_edit.text = String(draft.get("skill_description")) if has_draft else ""
	preview_speed_spin_box.editable = has_draft
	preview_speed_spin_box.value = float(draft.get("preview_playback_speed_scale")) if has_draft else 1.0
	preview_loop_check_box.disabled = not has_draft
	preview_loop_check_box.button_pressed = bool(draft.get("preview_loop_enabled")) if has_draft else false
	add_point_button.disabled = not has_draft
	duplicate_point_button.disabled = not has_node
	remove_point_button.disabled = not has_draft or (has_draft and int((draft.get("motion_node_chain") as Array).size()) <= _get_minimum_motion_node_count(draft))
	set_continuity_button.disabled = not has_node
	play_preview_button.disabled = not has_draft
	position_x_spin_box.editable = has_node
	position_y_spin_box.editable = has_node
	position_z_spin_box.editable = has_node
	rotation_x_spin_box.editable = has_node
	rotation_y_spin_box.editable = has_node
	rotation_z_spin_box.editable = has_node
	plane_vertical_spin_box.editable = has_node
	transition_spin_box.editable = has_node
	body_support_spin_box.editable = has_node
	two_hand_state_option_button.disabled = not has_node
	grip_mode_option_button.disabled = not has_node
	curve_in_x_spin_box.editable = has_node
	curve_in_y_spin_box.editable = has_node
	curve_in_z_spin_box.editable = has_node
	curve_out_x_spin_box.editable = has_node
	curve_out_y_spin_box.editable = has_node
	curve_out_z_spin_box.editable = has_node
	pommel_x_spin_box.editable = has_node
	pommel_y_spin_box.editable = has_node
	pommel_z_spin_box.editable = has_node
	pommel_curve_in_x_spin_box.editable = has_node
	pommel_curve_in_y_spin_box.editable = has_node
	pommel_curve_in_z_spin_box.editable = has_node
	pommel_curve_out_x_spin_box.editable = has_node
	pommel_curve_out_y_spin_box.editable = has_node
	pommel_curve_out_z_spin_box.editable = has_node
	weapon_roll_spin_box.editable = has_node
	axial_reposition_spin_box.editable = has_node
	grip_seat_slide_spin_box.editable = has_node
	draft_notes_edit.editable = has_draft
	draft_notes_edit.text = String(draft.get("draft_notes")) if has_draft else ""
	if has_node:
		position_x_spin_box.value = motion_node.tip_position_local.x
		position_y_spin_box.value = motion_node.tip_position_local.y
		position_z_spin_box.value = motion_node.tip_position_local.z
		rotation_x_spin_box.value = motion_node.trajectory_plane_orientation_degrees.x
		rotation_y_spin_box.value = motion_node.trajectory_plane_orientation_degrees.y
		rotation_z_spin_box.value = motion_node.trajectory_plane_orientation_degrees.z
		plane_vertical_spin_box.value = motion_node.trajectory_plane_vertical_offset
		transition_spin_box.value = motion_node.transition_duration_seconds
		body_support_spin_box.value = motion_node.body_support_blend
		curve_in_x_spin_box.value = motion_node.tip_curve_in_handle.x
		curve_in_y_spin_box.value = motion_node.tip_curve_in_handle.y
		curve_in_z_spin_box.value = motion_node.tip_curve_in_handle.z
		curve_out_x_spin_box.value = motion_node.tip_curve_out_handle.x
		curve_out_y_spin_box.value = motion_node.tip_curve_out_handle.y
		curve_out_z_spin_box.value = motion_node.tip_curve_out_handle.z
		pommel_x_spin_box.value = motion_node.pommel_position_local.x
		pommel_y_spin_box.value = motion_node.pommel_position_local.y
		pommel_z_spin_box.value = motion_node.pommel_position_local.z
		pommel_curve_in_x_spin_box.value = motion_node.pommel_curve_in_handle.x
		pommel_curve_in_y_spin_box.value = motion_node.pommel_curve_in_handle.y
		pommel_curve_in_z_spin_box.value = motion_node.pommel_curve_in_handle.z
		pommel_curve_out_x_spin_box.value = motion_node.pommel_curve_out_handle.x
		pommel_curve_out_y_spin_box.value = motion_node.pommel_curve_out_handle.y
		pommel_curve_out_z_spin_box.value = motion_node.pommel_curve_out_handle.z
		weapon_roll_spin_box.value = motion_node.weapon_roll_degrees
		axial_reposition_spin_box.value = motion_node.axial_reposition_offset
		grip_seat_slide_spin_box.value = motion_node.grip_seat_slide_offset
		_select_option_by_metadata(two_hand_state_option_button, motion_node.two_hand_state)
		_select_option_by_metadata(grip_mode_option_button, motion_node.preferred_grip_style_mode)
	else:
		position_x_spin_box.value = 0.0
		position_y_spin_box.value = 0.0
		position_z_spin_box.value = 0.0
		rotation_x_spin_box.value = 0.0
		rotation_y_spin_box.value = 0.0
		rotation_z_spin_box.value = 0.0
		plane_vertical_spin_box.value = 0.0
		transition_spin_box.value = 0.18
		body_support_spin_box.value = 0.0
		curve_in_x_spin_box.value = 0.0
		curve_in_y_spin_box.value = 0.0
		curve_in_z_spin_box.value = 0.0
		curve_out_x_spin_box.value = 0.0
		curve_out_y_spin_box.value = 0.0
		curve_out_z_spin_box.value = 0.0
		pommel_x_spin_box.value = 0.0
		pommel_y_spin_box.value = 0.0
		pommel_z_spin_box.value = 0.0
		pommel_curve_in_x_spin_box.value = 0.0
		pommel_curve_in_y_spin_box.value = 0.0
		pommel_curve_in_z_spin_box.value = 0.0
		pommel_curve_out_x_spin_box.value = 0.0
		pommel_curve_out_y_spin_box.value = 0.0
		pommel_curve_out_z_spin_box.value = 0.0
		weapon_roll_spin_box.value = 0.0
		axial_reposition_spin_box.value = 0.0
		grip_seat_slide_spin_box.value = 0.0
	refreshing_controls = false

func _refresh_summary(status_message: String = "") -> void:
	var lines: PackedStringArray = []
	if active_wip == null:
		lines.append("No saved forge WIP selected.")
		lines.append("Create or save a weapon in the forge branch first, then reopen this station.")
	else:
		var station_state: Resource = _get_active_station_state()
		var draft: Resource = _get_active_draft()
		var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
		lines.append("Weapon: %s" % active_wip.forge_project_name)
		lines.append("Builder Scope: %s" % CraftedItemWIPScript.get_builder_scope_label(active_wip.forge_builder_path_id, active_wip.forge_builder_component_id))
		lines.append("Grip Style: %s" % CraftedItemWIPScript.get_grip_style_label(active_wip.grip_style_mode))
		lines.append("Authoring Mode: %s" % AUTHORING_MODE_LABELS.get(station_state.get("selected_authoring_mode"), "Unknown"))
		if draft != null:
			lines.append("Draft: %s" % String(draft.get("display_name")))
			lines.append("Draft Identifier: %s" % String(_get_draft_identifier(draft)))
			lines.append("Motion Node Count: %d" % int((draft.get("motion_node_chain") as Array).size()))
			lines.append("Preview Loop: %s" % str(bool(draft.get("preview_loop_enabled"))))
			if _is_skill_mode():
				lines.append("Skill Slot: %s" % String(draft.get("legal_slot_id")))
		if motion_node != null:
			lines.append("Selected Node: %s" % String(motion_node.node_id))
			lines.append("Tip Position: %s" % _snapped_vector3_text(motion_node.tip_position_local, 0.001))
			lines.append("Plane Orientation: %s" % _snapped_vector3_text(motion_node.trajectory_plane_orientation_degrees, 0.01))
			lines.append("Two-Hand State: %s" % TWO_HAND_STATE_LABELS.get(motion_node.two_hand_state, String(motion_node.two_hand_state)))
			lines.append("Body Support Blend: %s" % str(snapped(motion_node.body_support_blend, 0.01)))
			lines.append("Weapon Roll: %s°" % str(snapped(motion_node.weapon_roll_degrees, 0.1)))
		lines.append("Station Truth: Stage 1 = %s | Stage 2 = %s" % [
			str(bool(station_state.get("uses_stage1_geometry_truth"))),
			str(bool(station_state.get("uses_stage2_geometry_truth"))),
		])
	if not status_message.strip_edges().is_empty():
		footer_status_label.text = status_message
	summary_label.text = "\n".join(lines)

func _refresh_preview_scene() -> void:
	preview_presenter.refresh_preview(
		preview_view_container,
		preview_subviewport,
		active_wip,
		_get_active_draft(),
		get_selected_motion_node_index()
	)

func _get_forge_wip_library_state() -> PlayerForgeWipLibraryState:
	if active_player == null or not active_player.has_method("get_forge_wip_library_state"):
		return null
	return active_player.call("get_forge_wip_library_state")

func _get_active_station_state() -> Resource:
	if active_wip == null:
		return null
	return active_wip.ensure_combat_animation_station_state()

func _get_active_drafts() -> Array[Resource]:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return []
	var draft_variant: Variant = station_state.get("idle_drafts") if _is_idle_mode() else station_state.get("skill_drafts")
	var drafts: Array[Resource] = []
	for draft_entry: Variant in (draft_variant as Array):
		var draft: Resource = draft_entry as Resource
		if draft != null:
			drafts.append(draft)
	return drafts

func _get_active_draft() -> Resource:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return null
	_ensure_valid_draft_selection()
	var target_identifier: StringName = station_state.get("selected_idle_context_id") if _is_idle_mode() else station_state.get("selected_skill_id")
	return _find_active_draft_by_identifier(target_identifier)

func _get_active_motion_node() -> CombatAnimationMotionNode:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return null
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		return null
	var node_index: int = clampi(int(draft.get("selected_motion_node_index")), 0, motion_node_chain.size() - 1)
	return motion_node_chain[node_index] as CombatAnimationMotionNode

func _find_active_draft_by_identifier(draft_identifier: StringName) -> Resource:
	for draft: Resource in _get_active_drafts():
		if _get_draft_identifier(draft) == draft_identifier:
			return draft
	return null

func _ensure_valid_draft_selection() -> void:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return
	var drafts: Array[Resource] = _get_active_drafts()
	if drafts.is_empty():
		return
	var current_identifier: StringName = station_state.get("selected_idle_context_id") if _is_idle_mode() else station_state.get("selected_skill_id")
	if _find_active_draft_by_identifier(current_identifier) != null:
		return
	var first_identifier: StringName = _get_draft_identifier(drafts[0])
	if _is_idle_mode():
		station_state.set("selected_idle_context_id", first_identifier)
	else:
		station_state.set("selected_skill_id", first_identifier)

func _persist_active_wip(status_message: String = "") -> void:
	if active_wip_library == null or active_wip == null:
		return
	active_wip.ensure_combat_animation_station_state()
	var saved_clone: CraftedItemWIP = active_wip_library.save_wip(active_wip)
	if saved_clone != null:
		active_saved_wip_id = saved_clone.wip_id
		active_wip.wip_id = saved_clone.wip_id
	if not status_message.strip_edges().is_empty():
		footer_status_label.text = status_message

func _get_draft_identifier(draft: Resource) -> StringName:
	if draft == null:
		return StringName()
	return draft.get("context_id") if _is_idle_mode() else draft.get("owning_skill_id")

func _build_draft_list_label(draft: Resource) -> String:
	var label_text: String = String(draft.get("display_name"))
	if _is_idle_mode():
		return "%s | %s" % [label_text, String(draft.get("context_id"))]
	var slot_suffix: String = String(draft.get("legal_slot_id"))
	if slot_suffix.is_empty():
		return "%s | %s" % [label_text, String(draft.get("owning_skill_id"))]
	return "%s | %s | %s" % [label_text, String(draft.get("owning_skill_id")), slot_suffix]

func _is_idle_mode() -> bool:
	var station_state: Resource = _get_active_station_state()
	return station_state != null and station_state.get("selected_authoring_mode") == CombatAnimationStationStateScript.AUTHORING_MODE_IDLE

func _is_skill_mode() -> bool:
	var station_state: Resource = _get_active_station_state()
	return station_state != null and station_state.get("selected_authoring_mode") == CombatAnimationStationStateScript.AUTHORING_MODE_SKILL

func _get_minimum_motion_node_count(draft: Resource) -> int:
	if draft == null:
		return 1
	return 1 if draft.get("draft_kind") == CombatAnimationDraftScript.DRAFT_KIND_IDLE else 2

func _duplicate_or_build_motion_node(source_node: CombatAnimationMotionNode) -> CombatAnimationMotionNode:
	if source_node != null:
		return source_node.duplicate_node()
	return CombatAnimationMotionNodeScript.new()

func _normalize_draft(draft: Resource) -> void:
	if draft == null:
		return
	if draft.has_method("normalize"):
		draft.call("normalize")

func _build_unique_skill_draft_id() -> StringName:
	var suffix: int = 1
	while true:
		var candidate_id: StringName = StringName("custom_skill_%02d" % suffix)
		if _find_skill_draft_by_skill_id(candidate_id) == null:
			return candidate_id
		suffix += 1
	return StringName()

func _find_skill_draft_by_skill_id(skill_id: StringName) -> Resource:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return null
	var skill_drafts: Array = station_state.get("skill_drafts") as Array
	for draft_variant: Variant in skill_drafts:
		var draft: Resource = draft_variant as Resource
		if draft != null and draft.get("owning_skill_id") == skill_id:
			return draft
	return null

func _build_skill_display_name(skill_id: StringName) -> String:
	var label_text: String = String(skill_id).replace("_", " ").strip_edges()
	return label_text.capitalize() if not label_text.is_empty() else "Custom Skill"

func _select_option_by_metadata(option_button: OptionButton, target_metadata: Variant) -> void:
	for item_index: int in range(option_button.get_item_count()):
		if option_button.get_item_metadata(item_index) == target_metadata:
			option_button.select(item_index)
			return

func _snapped_vector3_text(value: Vector3, step_value: float) -> String:
	return "(%s, %s, %s)" % [
		str(snapped(value.x, step_value)),
		str(snapped(value.y, step_value)),
		str(snapped(value.z, step_value)),
	]

func _on_project_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var saved_wip_id: StringName = project_list.get_item_metadata(index)
	select_saved_wip(saved_wip_id)

func _on_draft_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var draft_identifier: StringName = draft_list.get_item_metadata(index)
	select_draft(draft_identifier)

func _on_motion_node_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var node_index: int = int(point_list.get_item_metadata(index))
	select_motion_node(node_index)

func _on_authoring_mode_selected(index: int) -> void:
	if refreshing_controls:
		return
	var mode_id: StringName = authoring_mode_option_button.get_item_metadata(index)
	select_authoring_mode(mode_id)

func _on_new_skill_draft_pressed() -> void:
	create_skill_draft()

func _on_add_motion_node_pressed() -> void:
	insert_motion_node_after_selection()

func _on_duplicate_motion_node_pressed() -> void:
	duplicate_selected_motion_node()

func _on_remove_motion_node_pressed() -> void:
	remove_selected_motion_node()

func _on_set_continuity_pressed() -> void:
	set_selected_motion_node_as_continuity()

func _on_draft_name_submitted(new_text: String) -> void:
	if refreshing_controls:
		return
	set_active_draft_display_name(new_text)

func _on_draft_name_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_display_name(draft_name_edit.text)

func _on_skill_slot_submitted(new_text: String) -> void:
	if refreshing_controls:
		return
	set_active_draft_slot_id(StringName(new_text.strip_edges()))

func _on_skill_slot_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_slot_id(StringName(skill_slot_edit.text.strip_edges()))

func _on_preview_speed_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_active_draft_preview_speed(value)

func _on_preview_loop_toggled(enabled: bool) -> void:
	if refreshing_controls:
		return
	set_active_draft_preview_loop(enabled)

func _on_tip_position_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	var position_value: Vector3 = Vector3(position_x_spin_box.value, position_y_spin_box.value, position_z_spin_box.value)
	if axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_tip_position(position_value)

func _on_plane_orientation_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	var orientation_value: Vector3 = Vector3(rotation_x_spin_box.value, rotation_y_spin_box.value, rotation_z_spin_box.value)
	if axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_plane_orientation(orientation_value)

func _on_transition_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_transition_duration(value)

func _on_body_support_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_body_support_blend(value)

func _on_tip_curve_in_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	if axis_index < 0 or axis_index > 2:
		return
	var handle_value := Vector3(curve_in_x_spin_box.value, curve_in_y_spin_box.value, curve_in_z_spin_box.value)
	set_selected_motion_node_tip_curve_in(handle_value)

func _on_tip_curve_out_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	if axis_index < 0 or axis_index > 2:
		return
	var handle_value := Vector3(curve_out_x_spin_box.value, curve_out_y_spin_box.value, curve_out_z_spin_box.value)
	set_selected_motion_node_tip_curve_out(handle_value)

func _on_two_hand_state_selected(index: int) -> void:
	if refreshing_controls:
		return
	var state_id: StringName = two_hand_state_option_button.get_item_metadata(index)
	set_selected_motion_node_two_hand_state(state_id)

func _on_grip_mode_selected(index: int) -> void:
	if refreshing_controls:
		return
	var grip_mode: StringName = grip_mode_option_button.get_item_metadata(index)
	set_selected_motion_node_preferred_grip_style(grip_mode)

func _on_draft_notes_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_notes(draft_notes_edit.text)

func _on_preview_container_resized() -> void:
	_refresh_preview_scene()

func _register_station_input_actions() -> void:
	var action_key_map: Dictionary = {
		&"skill_crafter_prev_node": KEY_Q,
		&"skill_crafter_next_node": KEY_E,
		&"skill_crafter_copy_node": KEY_R,
		&"skill_crafter_delete_node": KEY_T,
		&"skill_crafter_cycle_focus": KEY_SPACE,
		&"skill_crafter_play_preview": KEY_F,
	}
	for action_name: StringName in action_key_map:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var key_event := InputEventKey.new()
		key_event.keycode = action_key_map[action_name] as Key
		InputMap.action_add_event(action_name, key_event)

func _navigate_motion_node(direction: int) -> void:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return
	var current_index: int = int(draft.get("selected_motion_node_index"))
	var chain_size: int = int((draft.get("motion_node_chain") as Array).size())
	if chain_size <= 0:
		return
	var new_index: int = clampi(current_index + direction, 0, chain_size - 1)
	if new_index != current_index:
		select_motion_node(new_index)

func _cycle_focus() -> void:
	footer_status_label.text = "Focus cycling (tip/pommel) — future feature placeholder."

func _toggle_preview_playback() -> void:
	footer_status_label.text = "Preview playback toggle — future feature placeholder."

func set_active_draft_skill_name(name_text: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("skill_name", name_text.strip_edges())
	_normalize_draft(draft)
	_persist_active_wip("Skill name updated.")
	_refresh_draft_list()
	_refresh_editor_fields()
	_refresh_summary("Skill name updated.")
	return true

func set_active_draft_skill_description(description_text: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("skill_description", description_text)
	_normalize_draft(draft)
	_persist_active_wip("Skill description updated.")
	_refresh_summary("Skill description updated.")
	return true

func set_selected_motion_node_pommel_position(pommel_position: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.pommel_position_local = pommel_position
	motion_node.normalize()
	_persist_active_wip("Pommel position updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Pommel position updated.")
	return true

func set_selected_motion_node_pommel_curve_in(curve_in: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.pommel_curve_in_handle = curve_in
	motion_node.normalize()
	_persist_active_wip("Pommel curve-in updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Pommel curve-in updated.")
	return true

func set_selected_motion_node_pommel_curve_out(curve_out: Vector3) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.pommel_curve_out_handle = curve_out
	motion_node.normalize()
	_persist_active_wip("Pommel curve-out updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Pommel curve-out updated.")
	return true

func set_selected_motion_node_plane_vertical(vertical_offset: float) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.trajectory_plane_vertical_offset = vertical_offset
	motion_node.normalize()
	_persist_active_wip("Plane vertical offset updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Plane vertical offset updated.")
	return true

func set_selected_motion_node_weapon_roll(roll_degrees: float) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.weapon_roll_degrees = clampf(roll_degrees, -120.0, 120.0)
	motion_node.normalize()
	_persist_active_wip("Weapon roll updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Weapon roll updated.")
	return true

func set_selected_motion_node_axial_reposition(offset: float) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.axial_reposition_offset = offset
	motion_node.normalize()
	_persist_active_wip("Axial reposition updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Axial reposition updated.")
	return true

func set_selected_motion_node_grip_seat_slide(offset: float) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	motion_node.grip_seat_slide_offset = offset
	motion_node.normalize()
	_persist_active_wip("Grip seat slide updated.")
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Grip seat slide updated.")
	return true

func _on_skill_name_submitted(new_text: String) -> void:
	if refreshing_controls:
		return
	set_active_draft_skill_name(new_text)

func _on_skill_name_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_skill_name(skill_name_edit.text)

func _on_skill_description_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_skill_description(skill_description_edit.text)

func _on_pommel_position_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls or axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_pommel_position(Vector3(pommel_x_spin_box.value, pommel_y_spin_box.value, pommel_z_spin_box.value))

func _on_pommel_curve_in_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls or axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_pommel_curve_in(Vector3(pommel_curve_in_x_spin_box.value, pommel_curve_in_y_spin_box.value, pommel_curve_in_z_spin_box.value))

func _on_pommel_curve_out_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls or axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_pommel_curve_out(Vector3(pommel_curve_out_x_spin_box.value, pommel_curve_out_y_spin_box.value, pommel_curve_out_z_spin_box.value))

func _on_plane_vertical_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_plane_vertical(value)

func _on_weapon_roll_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_weapon_roll(value)

func _on_axial_reposition_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_axial_reposition(value)

func _on_grip_seat_slide_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_grip_seat_slide(value)

func _on_play_preview_pressed() -> void:
	_toggle_preview_playback()
