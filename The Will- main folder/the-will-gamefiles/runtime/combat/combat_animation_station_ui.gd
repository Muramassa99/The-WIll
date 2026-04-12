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

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootVBox/HeaderBox/SubtitleLabel
@onready var project_list: ItemList = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/WeaponPanel/MarginContainer/WeaponVBox/ProjectList
@onready var authoring_mode_option_button: OptionButton = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/WeaponPanel/MarginContainer/WeaponVBox/AuthoringModeOptionButton
@onready var draft_list: ItemList = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/WeaponPanel/MarginContainer/WeaponVBox/DraftList
@onready var new_skill_draft_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/WeaponPanel/MarginContainer/WeaponVBox/DraftHeaderRow/NewSkillDraftButton
@onready var point_list: ItemList = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/PointList
@onready var add_point_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/PointActionRow/AddPointButton
@onready var duplicate_point_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/PointActionRow/DuplicatePointButton
@onready var remove_point_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/PointActionRow/RemovePointButton
@onready var set_continuity_button: Button = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/SecondaryActionRow/SetContinuityButton
@onready var draft_name_edit: LineEdit = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/DraftSettingsPanel/MarginContainer/DraftSettingsVBox/DraftNameEdit
@onready var skill_slot_edit: LineEdit = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/DraftSettingsPanel/MarginContainer/DraftSettingsVBox/SkillSlotEdit
@onready var preview_speed_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/DraftSettingsPanel/MarginContainer/DraftSettingsVBox/PreviewSpeedSpinBox
@onready var preview_loop_check_box: CheckBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/TimelinePanel/MarginContainer/TimelineVBox/DraftSettingsPanel/MarginContainer/DraftSettingsVBox/PreviewLoopCheckBox
@onready var position_x_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/PositionRow/PositionXSpinBox
@onready var position_y_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/PositionRow/PositionYSpinBox
@onready var position_z_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/PositionRow/PositionZSpinBox
@onready var rotation_x_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/RotationRow/RotationXSpinBox
@onready var rotation_y_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/RotationRow/RotationYSpinBox
@onready var rotation_z_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/RotationRow/RotationZSpinBox
@onready var transition_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/TransitionSpinBox
@onready var body_support_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/BodySupportSpinBox
@onready var two_hand_state_option_button: OptionButton = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/TwoHandStateOptionButton
@onready var grip_mode_option_button: OptionButton = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/GripModeOptionButton
@onready var preview_view_container: SubViewportContainer = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/PreviewPanel/MarginContainer/PreviewVBox/PreviewViewContainer
@onready var preview_subviewport: SubViewport = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/PreviewPanel/MarginContainer/PreviewVBox/PreviewViewContainer/PreviewSubViewport
@onready var curve_in_x_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/CurveInRow/CurveInXSpinBox
@onready var curve_in_y_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/CurveInRow/CurveInYSpinBox
@onready var curve_in_z_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/CurveInRow/CurveInZSpinBox
@onready var curve_out_x_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/CurveOutRow/CurveOutXSpinBox
@onready var curve_out_y_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/CurveOutRow/CurveOutYSpinBox
@onready var curve_out_z_spin_box: SpinBox = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/CurveOutRow/CurveOutZSpinBox
@onready var draft_notes_edit: TextEdit = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/DraftNotesEdit
@onready var summary_label: Label = $Panel/MarginContainer/RootVBox/MainScroll/MainHBox/DetailPanel/MarginContainer/DetailVBox/SummaryPanel/MarginContainer/SummaryLabel
@onready var footer_status_label: Label = $Panel/MarginContainer/RootVBox/FooterRow/FooterStatusLabel
@onready var close_button: Button = $Panel/MarginContainer/RootVBox/FooterRow/CloseButton

var active_player = null
var active_wip_library: PlayerForgeWipLibraryState = null
var active_wip: CraftedItemWIP = null
var active_saved_wip_id: StringName = StringName()
var refreshing_controls: bool = false
var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()

func _ready() -> void:
	visible = false
	backdrop.visible = false
	panel.visible = false
	project_list.item_clicked.connect(_on_project_item_clicked)
	draft_list.item_clicked.connect(_on_draft_item_clicked)
	point_list.item_clicked.connect(_on_motion_node_item_clicked)
	authoring_mode_option_button.item_selected.connect(_on_authoring_mode_selected)
	new_skill_draft_button.pressed.connect(_on_new_skill_draft_pressed)
	add_point_button.pressed.connect(_on_add_motion_node_pressed)
	duplicate_point_button.pressed.connect(_on_duplicate_motion_node_pressed)
	remove_point_button.pressed.connect(_on_remove_motion_node_pressed)
	set_continuity_button.pressed.connect(_on_set_continuity_pressed)
	draft_name_edit.text_submitted.connect(_on_draft_name_submitted)
	draft_name_edit.focus_exited.connect(_on_draft_name_focus_exited)
	skill_slot_edit.text_submitted.connect(_on_skill_slot_submitted)
	skill_slot_edit.focus_exited.connect(_on_skill_slot_focus_exited)
	preview_speed_spin_box.value_changed.connect(_on_preview_speed_changed)
	preview_loop_check_box.toggled.connect(_on_preview_loop_toggled)
	position_x_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(0))
	position_y_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(1))
	position_z_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(2))
	rotation_x_spin_box.value_changed.connect(_on_plane_orientation_component_changed.bind(0))
	rotation_y_spin_box.value_changed.connect(_on_plane_orientation_component_changed.bind(1))
	rotation_z_spin_box.value_changed.connect(_on_plane_orientation_component_changed.bind(2))
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
	title_label.text = "%s Combat Animation Station" % bench_name
	subtitle_label.text = "Weapon selection -> draft selection -> motion-node authoring. This station saves runtime combat idle and skill motion truth back into the owning weapon WIP."
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
	skill_slot_edit.editable = has_draft
	skill_slot_edit.text = String(draft.get("legal_slot_id")) if has_draft else ""
	preview_speed_spin_box.editable = has_draft
	preview_speed_spin_box.value = float(draft.get("preview_playback_speed_scale")) if has_draft else 1.0
	preview_loop_check_box.disabled = not has_draft
	preview_loop_check_box.button_pressed = bool(draft.get("preview_loop_enabled")) if has_draft else false
	add_point_button.disabled = not has_draft
	duplicate_point_button.disabled = not has_node
	remove_point_button.disabled = not has_draft or (has_draft and int((draft.get("motion_node_chain") as Array).size()) <= _get_minimum_motion_node_count(draft))
	set_continuity_button.disabled = not has_node
	position_x_spin_box.editable = has_node
	position_y_spin_box.editable = has_node
	position_z_spin_box.editable = has_node
	rotation_x_spin_box.editable = has_node
	rotation_y_spin_box.editable = has_node
	rotation_z_spin_box.editable = has_node
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
	draft_notes_edit.editable = has_draft
	draft_notes_edit.text = String(draft.get("draft_notes")) if has_draft else ""
	if has_node:
		position_x_spin_box.value = motion_node.tip_position_local.x
		position_y_spin_box.value = motion_node.tip_position_local.y
		position_z_spin_box.value = motion_node.tip_position_local.z
		rotation_x_spin_box.value = motion_node.trajectory_plane_orientation_degrees.x
		rotation_y_spin_box.value = motion_node.trajectory_plane_orientation_degrees.y
		rotation_z_spin_box.value = motion_node.trajectory_plane_orientation_degrees.z
		transition_spin_box.value = motion_node.transition_duration_seconds
		body_support_spin_box.value = motion_node.body_support_blend
		curve_in_x_spin_box.value = motion_node.tip_curve_in_handle.x
		curve_in_y_spin_box.value = motion_node.tip_curve_in_handle.y
		curve_in_z_spin_box.value = motion_node.tip_curve_in_handle.z
		curve_out_x_spin_box.value = motion_node.tip_curve_out_handle.x
		curve_out_y_spin_box.value = motion_node.tip_curve_out_handle.y
		curve_out_z_spin_box.value = motion_node.tip_curve_out_handle.z
		_select_option_by_metadata(two_hand_state_option_button, motion_node.two_hand_state)
		_select_option_by_metadata(grip_mode_option_button, motion_node.preferred_grip_style_mode)
	else:
		position_x_spin_box.value = 0.0
		position_y_spin_box.value = 0.0
		position_z_spin_box.value = 0.0
		rotation_x_spin_box.value = 0.0
		rotation_y_spin_box.value = 0.0
		rotation_z_spin_box.value = 0.0
		transition_spin_box.value = 0.18
		body_support_spin_box.value = 0.0
		curve_in_x_spin_box.value = 0.0
		curve_in_y_spin_box.value = 0.0
		curve_in_z_spin_box.value = 0.0
		curve_out_x_spin_box.value = 0.0
		curve_out_y_spin_box.value = 0.0
		curve_out_z_spin_box.value = 0.0
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
