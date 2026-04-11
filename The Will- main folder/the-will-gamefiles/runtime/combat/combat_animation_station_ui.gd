extends CanvasLayer
class_name CombatAnimationStationUI

signal closed

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationPointScript = preload("res://core/models/combat_animation_point.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")

const AUTHORING_MODE_LABELS := {
	CombatAnimationStationStateScript.AUTHORING_MODE_IDLE: "Idle Drafts",
	CombatAnimationStationStateScript.AUTHORING_MODE_SKILL: "Skill Drafts",
}

const TWO_HAND_STATE_LABELS := {
	CombatAnimationPointScript.TWO_HAND_STATE_AUTO: "Auto",
	CombatAnimationPointScript.TWO_HAND_STATE_ONE_HAND: "One Hand",
	CombatAnimationPointScript.TWO_HAND_STATE_TWO_HAND: "Two Hand",
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
	point_list.item_clicked.connect(_on_point_item_clicked)
	authoring_mode_option_button.item_selected.connect(_on_authoring_mode_selected)
	new_skill_draft_button.pressed.connect(_on_new_skill_draft_pressed)
	add_point_button.pressed.connect(_on_add_point_pressed)
	duplicate_point_button.pressed.connect(_on_duplicate_point_pressed)
	remove_point_button.pressed.connect(_on_remove_point_pressed)
	set_continuity_button.pressed.connect(_on_set_continuity_pressed)
	draft_name_edit.text_submitted.connect(_on_draft_name_submitted)
	draft_name_edit.focus_exited.connect(_on_draft_name_focus_exited)
	skill_slot_edit.text_submitted.connect(_on_skill_slot_submitted)
	skill_slot_edit.focus_exited.connect(_on_skill_slot_focus_exited)
	preview_speed_spin_box.value_changed.connect(_on_preview_speed_changed)
	preview_loop_check_box.toggled.connect(_on_preview_loop_toggled)
	position_x_spin_box.value_changed.connect(_on_position_component_changed.bind(0))
	position_y_spin_box.value_changed.connect(_on_position_component_changed.bind(1))
	position_z_spin_box.value_changed.connect(_on_position_component_changed.bind(2))
	rotation_x_spin_box.value_changed.connect(_on_rotation_component_changed.bind(0))
	rotation_y_spin_box.value_changed.connect(_on_rotation_component_changed.bind(1))
	rotation_z_spin_box.value_changed.connect(_on_rotation_component_changed.bind(2))
	transition_spin_box.value_changed.connect(_on_transition_changed)
	body_support_spin_box.value_changed.connect(_on_body_support_changed)
	two_hand_state_option_button.item_selected.connect(_on_two_hand_state_selected)
	grip_mode_option_button.item_selected.connect(_on_grip_mode_selected)
	preview_view_container.resized.connect(_on_preview_container_resized)
	curve_in_x_spin_box.value_changed.connect(_on_curve_in_component_changed.bind(0))
	curve_in_y_spin_box.value_changed.connect(_on_curve_in_component_changed.bind(1))
	curve_in_z_spin_box.value_changed.connect(_on_curve_in_component_changed.bind(2))
	curve_out_x_spin_box.value_changed.connect(_on_curve_out_component_changed.bind(0))
	curve_out_y_spin_box.value_changed.connect(_on_curve_out_component_changed.bind(1))
	curve_out_z_spin_box.value_changed.connect(_on_curve_out_component_changed.bind(2))
	draft_notes_edit.focus_exited.connect(_on_draft_notes_focus_exited)
	close_button.pressed.connect(close_ui)
	_populate_static_options()
	_refresh_all("Select a saved weapon WIP to begin authoring.")

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()

func toggle_for(player, bench_name: String) -> void:
	if panel.visible:
		close_ui()
		return
	open_for(player, bench_name)

func open_for(player, bench_name: String) -> void:
	active_player = player
	active_wip_library = _get_forge_wip_library_state()
	title_label.text = "%s Combat Animation Station" % bench_name
	subtitle_label.text = "Weapon selection -> draft selection -> point-chain authoring. This station saves runtime combat idle and skill motion truth back into the owning weapon WIP."
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
	var selected_point_index: int = int(draft.get("selected_point_index"))
	draft.set("selected_point_index", clampi(selected_point_index, 0, maxi(int((draft.get("point_chain") as Array).size()) - 1, 0)))
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

func select_point(point_index: int) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var point_chain: Array = draft.get("point_chain") as Array
	if point_chain.is_empty():
		return false
	draft.set("selected_point_index", clampi(point_index, 0, point_chain.size() - 1))
	_persist_active_wip("Point selection updated.")
	_refresh_all("Point selection updated.")
	return true

func insert_point_after_selection() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var point_chain: Array = draft.get("point_chain") as Array
	var insert_index: int = clampi(int(draft.get("selected_point_index")), 0, maxi(point_chain.size() - 1, 0)) + 1
	var seed_point: CombatAnimationPoint = _get_active_point()
	var new_point: CombatAnimationPoint = _duplicate_or_build_point(seed_point)
	if new_point == null:
		return false
	new_point.local_target_position += Vector3(0.0, 0.0, -0.08)
	new_point.active_plane_origin_local = new_point.local_target_position
	new_point.committed = false
	point_chain.insert(insert_index, new_point)
	draft.set("selected_point_index", insert_index)
	_normalize_draft(draft)
	_persist_active_wip("Inserted point %d." % insert_index)
	_refresh_all("Inserted point %d." % insert_index)
	return true

func duplicate_selected_point() -> bool:
	var draft: Resource = _get_active_draft()
	var point: CombatAnimationPoint = _get_active_point()
	if draft == null or point == null:
		return false
	var point_chain: Array = draft.get("point_chain") as Array
	var selected_index: int = clampi(int(draft.get("selected_point_index")), 0, maxi(point_chain.size() - 1, 0))
	var duplicate_point: CombatAnimationPoint = _duplicate_or_build_point(point)
	if duplicate_point == null:
		return false
	duplicate_point.local_target_position += Vector3(0.0, 0.0, -0.04)
	duplicate_point.active_plane_origin_local = duplicate_point.local_target_position
	duplicate_point.committed = false
	point_chain.insert(selected_index + 1, duplicate_point)
	draft.set("selected_point_index", selected_index + 1)
	_normalize_draft(draft)
	_persist_active_wip("Duplicated point %d." % selected_index)
	_refresh_all("Duplicated point %d." % selected_index)
	return true

func remove_selected_point() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var point_chain: Array = draft.get("point_chain") as Array
	if point_chain.size() <= _get_minimum_point_count(draft):
		_refresh_all("Minimum baseline point count reached.")
		return false
	var selected_index: int = clampi(int(draft.get("selected_point_index")), 0, point_chain.size() - 1)
	point_chain.remove_at(selected_index)
	draft.set("selected_point_index", clampi(selected_index, 0, point_chain.size() - 1))
	draft.set("continuity_point_index", clampi(int(draft.get("continuity_point_index")), 0, point_chain.size() - 1))
	_normalize_draft(draft)
	_persist_active_wip("Removed point %d." % selected_index)
	_refresh_all("Removed point %d." % selected_index)
	return true

func set_selected_point_as_continuity() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("continuity_point_index", int(draft.get("selected_point_index")))
	_persist_active_wip("Continuity point updated.")
	_refresh_all("Continuity point updated.")
	return true

func set_selected_point_local_position(local_position: Vector3) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	point.local_target_position = local_position
	point.active_plane_origin_local = local_position
	point.normalize()
	_persist_active_wip("Point position updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point position updated.")
	return true

func set_selected_point_local_rotation_degrees(local_rotation_degrees: Vector3) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	point.local_target_rotation_degrees = local_rotation_degrees
	point.normalize()
	_persist_active_wip("Point rotation updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point rotation updated.")
	return true

func set_selected_point_transition_duration(duration_seconds: float) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	point.transition_duration_seconds = maxf(duration_seconds, 0.0)
	point.normalize()
	_persist_active_wip("Point transition updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_summary("Point transition updated.")
	return true

func set_selected_point_body_support_blend(blend_ratio: float) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	point.body_support_blend = clampf(blend_ratio, 0.0, 1.0)
	point.normalize()
	_persist_active_wip("Point body-support blend updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point body-support blend updated.")
	return true

func set_selected_point_two_hand_state(state_id: StringName) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null or not CombatAnimationPointScript.get_two_hand_state_ids().has(state_id):
		return false
	point.two_hand_state = state_id
	point.normalize()
	_persist_active_wip("Point two-hand state updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point two-hand state updated.")
	return true

func set_selected_point_preferred_grip_style(grip_mode: StringName) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	var resolved_grip_mode: StringName = CraftedItemWIPScript.resolve_supported_grip_style(
		grip_mode,
		active_wip.forge_intent if active_wip != null else StringName(),
		active_wip.equipment_context if active_wip != null else StringName()
	)
	point.preferred_grip_style_mode = resolved_grip_mode
	point.normalize()
	_persist_active_wip("Point grip preference updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point grip preference updated.")
	return true

func set_selected_point_curve_in_handle_local(curve_in_handle_local: Vector3) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	point.curve_in_handle_local = curve_in_handle_local
	point.normalize()
	_persist_active_wip("Point curve-in handle updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point curve-in handle updated.")
	return true

func set_selected_point_curve_out_handle_local(curve_out_handle_local: Vector3) -> bool:
	var point: CombatAnimationPoint = _get_active_point()
	if point == null:
		return false
	point.curve_out_handle_local = curve_out_handle_local
	point.normalize()
	_persist_active_wip("Point curve-out handle updated.")
	_refresh_point_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Point curve-out handle updated.")
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

func get_selected_point_index() -> int:
	var draft: Resource = _get_active_draft()
	return int(draft.get("selected_point_index")) if draft != null else 0

func get_preview_debug_state() -> Dictionary:
	return preview_presenter.get_debug_state(preview_subviewport)

func _populate_static_options() -> void:
	authoring_mode_option_button.clear()
	for mode_id: StringName in CombatAnimationStationStateScript.get_authoring_mode_ids():
		authoring_mode_option_button.add_item(AUTHORING_MODE_LABELS.get(mode_id, String(mode_id)))
		authoring_mode_option_button.set_item_metadata(authoring_mode_option_button.get_item_count() - 1, mode_id)
	two_hand_state_option_button.clear()
	for state_id: StringName in CombatAnimationPointScript.get_two_hand_state_ids():
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
	_refresh_point_list()
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

func _refresh_point_list() -> void:
	point_list.clear()
	var draft: Resource = _get_active_draft()
	if draft == null:
		return
	var point_chain: Array = draft.get("point_chain") as Array
	var selected_point_index: int = int(draft.get("selected_point_index"))
	var continuity_point_index: int = int(draft.get("continuity_point_index"))
	for point_index: int in range(point_chain.size()):
		var point: CombatAnimationPoint = point_chain[point_index] as CombatAnimationPoint
		if point == null:
			continue
		var continuity_marker: String = " | continuity" if point_index == continuity_point_index else ""
		var item_text: String = "P%02d | %s%s" % [
			point_index + 1,
			_snapped_vector3_text(point.local_target_position, 0.001),
			continuity_marker,
		]
		point_list.add_item(item_text)
		var item_id: int = point_list.get_item_count() - 1
		point_list.set_item_metadata(item_id, point_index)
		if point_index == selected_point_index:
			point_list.select(item_id)

func _refresh_editor_fields() -> void:
	refreshing_controls = true
	var draft: Resource = _get_active_draft()
	var point: CombatAnimationPoint = _get_active_point()
	var has_draft: bool = draft != null
	var has_point: bool = point != null
	draft_name_edit.editable = has_draft
	draft_name_edit.text = String(draft.get("display_name")) if has_draft else ""
	skill_slot_edit.editable = has_draft
	skill_slot_edit.text = String(draft.get("legal_slot_id")) if has_draft else ""
	preview_speed_spin_box.editable = has_draft
	preview_speed_spin_box.value = float(draft.get("preview_playback_speed_scale")) if has_draft else 1.0
	preview_loop_check_box.disabled = not has_draft
	preview_loop_check_box.button_pressed = bool(draft.get("preview_loop_enabled")) if has_draft else false
	add_point_button.disabled = not has_draft
	duplicate_point_button.disabled = not has_point
	remove_point_button.disabled = not has_draft or (has_draft and int((draft.get("point_chain") as Array).size()) <= _get_minimum_point_count(draft))
	set_continuity_button.disabled = not has_point
	position_x_spin_box.editable = has_point
	position_y_spin_box.editable = has_point
	position_z_spin_box.editable = has_point
	rotation_x_spin_box.editable = has_point
	rotation_y_spin_box.editable = has_point
	rotation_z_spin_box.editable = has_point
	transition_spin_box.editable = has_point
	body_support_spin_box.editable = has_point
	two_hand_state_option_button.disabled = not has_point
	grip_mode_option_button.disabled = not has_point
	curve_in_x_spin_box.editable = has_point
	curve_in_y_spin_box.editable = has_point
	curve_in_z_spin_box.editable = has_point
	curve_out_x_spin_box.editable = has_point
	curve_out_y_spin_box.editable = has_point
	curve_out_z_spin_box.editable = has_point
	draft_notes_edit.editable = has_draft
	draft_notes_edit.text = String(draft.get("draft_notes")) if has_draft else ""
	if has_point:
		position_x_spin_box.value = point.local_target_position.x
		position_y_spin_box.value = point.local_target_position.y
		position_z_spin_box.value = point.local_target_position.z
		rotation_x_spin_box.value = point.local_target_rotation_degrees.x
		rotation_y_spin_box.value = point.local_target_rotation_degrees.y
		rotation_z_spin_box.value = point.local_target_rotation_degrees.z
		transition_spin_box.value = point.transition_duration_seconds
		body_support_spin_box.value = point.body_support_blend
		curve_in_x_spin_box.value = point.curve_in_handle_local.x
		curve_in_y_spin_box.value = point.curve_in_handle_local.y
		curve_in_z_spin_box.value = point.curve_in_handle_local.z
		curve_out_x_spin_box.value = point.curve_out_handle_local.x
		curve_out_y_spin_box.value = point.curve_out_handle_local.y
		curve_out_z_spin_box.value = point.curve_out_handle_local.z
		_select_option_by_metadata(two_hand_state_option_button, point.two_hand_state)
		_select_option_by_metadata(grip_mode_option_button, point.preferred_grip_style_mode)
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
		var point: CombatAnimationPoint = _get_active_point()
		lines.append("Weapon: %s" % active_wip.forge_project_name)
		lines.append("Builder Scope: %s" % CraftedItemWIPScript.get_builder_scope_label(active_wip.forge_builder_path_id, active_wip.forge_builder_component_id))
		lines.append("Grip Style: %s" % CraftedItemWIPScript.get_grip_style_label(active_wip.grip_style_mode))
		lines.append("Authoring Mode: %s" % AUTHORING_MODE_LABELS.get(station_state.get("selected_authoring_mode"), "Unknown"))
		if draft != null:
			lines.append("Draft: %s" % String(draft.get("display_name")))
			lines.append("Draft Identifier: %s" % String(_get_draft_identifier(draft)))
			lines.append("Point Count: %d" % int((draft.get("point_chain") as Array).size()))
			lines.append("Preview Loop: %s" % str(bool(draft.get("preview_loop_enabled"))))
			if _is_skill_mode():
				lines.append("Skill Slot: %s" % String(draft.get("legal_slot_id")))
		if point != null:
			lines.append("Selected Point: %s" % String(point.point_id))
			lines.append("Position: %s" % _snapped_vector3_text(point.local_target_position, 0.001))
			lines.append("Rotation: %s" % _snapped_vector3_text(point.local_target_rotation_degrees, 0.01))
			lines.append("Two-Hand State: %s" % TWO_HAND_STATE_LABELS.get(point.two_hand_state, String(point.two_hand_state)))
			lines.append("Body Support Blend: %s" % str(snapped(point.body_support_blend, 0.01)))
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
		get_selected_point_index()
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

func _get_active_point() -> CombatAnimationPoint:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return null
	var point_chain: Array = draft.get("point_chain") as Array
	if point_chain.is_empty():
		return null
	var point_index: int = clampi(int(draft.get("selected_point_index")), 0, point_chain.size() - 1)
	return point_chain[point_index] as CombatAnimationPoint

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

func _get_minimum_point_count(draft: Resource) -> int:
	if draft == null:
		return 1
	return 1 if draft.get("draft_kind") == CombatAnimationDraftScript.DRAFT_KIND_IDLE else 2

func _duplicate_or_build_point(source_point: CombatAnimationPoint) -> CombatAnimationPoint:
	if source_point != null:
		return source_point.duplicate(true) as CombatAnimationPoint
	return CombatAnimationPointScript.new()

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

func _on_point_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var point_index: int = int(point_list.get_item_metadata(index))
	select_point(point_index)

func _on_authoring_mode_selected(index: int) -> void:
	if refreshing_controls:
		return
	var mode_id: StringName = authoring_mode_option_button.get_item_metadata(index)
	select_authoring_mode(mode_id)

func _on_new_skill_draft_pressed() -> void:
	create_skill_draft()

func _on_add_point_pressed() -> void:
	insert_point_after_selection()

func _on_duplicate_point_pressed() -> void:
	duplicate_selected_point()

func _on_remove_point_pressed() -> void:
	remove_selected_point()

func _on_set_continuity_pressed() -> void:
	set_selected_point_as_continuity()

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

func _on_position_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	var position_value: Vector3 = Vector3(position_x_spin_box.value, position_y_spin_box.value, position_z_spin_box.value)
	if axis_index < 0 or axis_index > 2:
		return
	set_selected_point_local_position(position_value)

func _on_rotation_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	var rotation_value: Vector3 = Vector3(rotation_x_spin_box.value, rotation_y_spin_box.value, rotation_z_spin_box.value)
	if axis_index < 0 or axis_index > 2:
		return
	set_selected_point_local_rotation_degrees(rotation_value)

func _on_transition_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_point_transition_duration(value)

func _on_body_support_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_point_body_support_blend(value)

func _on_curve_in_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	if axis_index < 0 or axis_index > 2:
		return
	var handle_value := Vector3(curve_in_x_spin_box.value, curve_in_y_spin_box.value, curve_in_z_spin_box.value)
	set_selected_point_curve_in_handle_local(handle_value)

func _on_curve_out_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	if axis_index < 0 or axis_index > 2:
		return
	var handle_value := Vector3(curve_out_x_spin_box.value, curve_out_y_spin_box.value, curve_out_z_spin_box.value)
	set_selected_point_curve_out_handle_local(handle_value)

func _on_two_hand_state_selected(index: int) -> void:
	if refreshing_controls:
		return
	var state_id: StringName = two_hand_state_option_button.get_item_metadata(index)
	set_selected_point_two_hand_state(state_id)

func _on_grip_mode_selected(index: int) -> void:
	if refreshing_controls:
		return
	var grip_mode: StringName = grip_mode_option_button.get_item_metadata(index)
	set_selected_point_preferred_grip_style(grip_mode)

func _on_draft_notes_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_notes(draft_notes_edit.text)

func _on_preview_container_resized() -> void:
	_refresh_preview_scene()
