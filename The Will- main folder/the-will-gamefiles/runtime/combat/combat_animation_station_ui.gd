extends CanvasLayer
class_name CombatAnimationStationUI

signal closed

const CraftedItemWIPScript = preload("res://core/models/crafted_item_wip.gd")
const CombatAnimationStationStateScript = preload("res://core/models/combat_animation_station_state.gd")
const CombatAnimationDraftScript = preload("res://core/models/combat_animation_draft.gd")
const CombatAnimationMotionNodeScript = preload("res://core/models/combat_animation_motion_node.gd")
const CombatAnimationStationPreviewPresenterScript = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const CombatAnimationChainPlayerScript = preload("res://runtime/combat/combat_animation_chain_player.gd")
const CombatAnimationSessionStateScript = preload("res://core/models/combat_animation_session_state.gd")
const CombatAnimationMotionNodeEditorScript = preload("res://runtime/combat/combat_animation_motion_node_editor.gd")
const CombatAnimationDraftValidatorScript = preload("res://core/resolvers/combat_animation_draft_validator.gd")
const CombatAnimationWeaponGeometryResolverScript = preload("res://core/resolvers/combat_animation_weapon_geometry_resolver.gd")
const CombatAnimationRetargetResolverScript = preload("res://core/resolvers/combat_animation_retarget_resolver.gd")
const CombatRuntimeClipBakerScript = preload("res://core/resolvers/combat_runtime_clip_baker.gd")
const CombatAnimationRuntimeChainCompilerScript = preload("res://core/resolvers/combat_animation_runtime_chain_compiler.gd")
const CombatOriginRecordScript = preload("res://core/models/combat_origin_record.gd")
const PrimaryGripSeatResolverScript = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const PlayerSkillSlotStateScript = preload("res://core/models/player_skill_slot_state.gd")
const UserSettingsStateScript = preload("res://core/models/user_settings_state.gd")
const UserSettingsRuntimeScript = preload("res://runtime/system/user_settings_runtime.gd")
const UiWindowLayerPolicyScript = preload("res://runtime/ui/ui_window_layer_policy.gd")

const AUTHORING_MODE_LABELS := {
	CombatAnimationStationStateScript.AUTHORING_MODE_IDLE: "Idle Drafts",
	CombatAnimationStationStateScript.AUTHORING_MODE_SKILL: "Skill Drafts",
}

const TWO_HAND_STATE_LABELS := {
	CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO: "Auto",
	CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND: "One Hand",
	CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND: "Two Hand",
}

const PRIMARY_HAND_LABELS := {
	CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO: "Auto Primary",
	CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT: "Right Hand Primary",
	CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT: "Left Hand Primary",
}

const STOW_ANCHOR_LABELS := {
	CombatAnimationDraftScript.STOW_ANCHOR_SHOULDER_HANGING: "Upper Back",
	CombatAnimationDraftScript.STOW_ANCHOR_LOWER_BACK: "Lower Back",
	CombatAnimationDraftScript.STOW_ANCHOR_SIDE_HIP: "Hip",
}

const GENERATED_TRANSITION_LABELS := {
	CombatAnimationMotionNodeScript.TRANSITION_KIND_GRIP_STYLE_SWAP: "grip swap",
	CombatAnimationMotionNodeScript.TRANSITION_KIND_PRIMARY_HAND_SWAP: "hand swap",
	CombatAnimationMotionNodeScript.TRANSITION_KIND_TWO_HAND_STATE_SWAP: "stance swap",
}

const WORKFLOW_STEP_WEAPON_SELECT: StringName = &"workflow_weapon_select"
const WORKFLOW_STEP_SKILL_SELECT: StringName = &"workflow_skill_select"
const WORKFLOW_STEP_EDITOR: StringName = &"workflow_editor"
const PREVIEW_GRIP_RESOLVE_REASON_HANDLE_POSITION: StringName = &"handle_position_changed"

const ACTION_PREV_NODE: StringName = &"skill_crafter_prev_motion_node"
const ACTION_NEXT_NODE: StringName = &"skill_crafter_next_motion_node"
const ACTION_NEW_NODE: StringName = &"skill_crafter_new_motion_node"
const ACTION_DELETE_NODE: StringName = &"skill_crafter_delete_motion_node"
const ACTION_CYCLE_FOCUS: StringName = &"skill_crafter_cycle_active_subcontrol"
const ACTION_PREVIEW_PLAYBACK: StringName = &"skill_crafter_play_preview"
const LEGACY_ACTION_PREV_NODE: StringName = &"skill_crafter_prev_node"
const LEGACY_ACTION_NEXT_NODE: StringName = &"skill_crafter_next_node"
const LEGACY_ACTION_COPY_NODE: StringName = &"skill_crafter_copy_node"
const LEGACY_ACTION_DELETE_NODE: StringName = &"skill_crafter_delete_node"
const LEGACY_ACTION_CYCLE_FOCUS: StringName = &"skill_crafter_cycle_focus"

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
const COLOR_SLOT_CARD := Color(0.095, 0.10, 0.15, 1.0)
const COLOR_SLOT_CARD_ACTIVE := Color(0.18, 0.16, 0.12, 1.0)
const COLOR_SLOT_CARD_READY := Color(0.11, 0.13, 0.18, 1.0)
const COLOR_SLOT_ICON_PLACEHOLDER := Color(0.13, 0.14, 0.20, 1.0)
const COLOR_BACKDROP := Color(0.02, 0.02, 0.04, 0.82)
const COLOR_SEPARATOR := Color(0.18, 0.20, 0.28, 0.5)
const FONT_TITLE := 20
const FONT_SECTION := 13
const FONT_BODY := 12
const FONT_HINT := 11
const HAND_SLOT_RIGHT: StringName = &"hand_right"
const HAND_SLOT_LEFT: StringName = &"hand_left"
const UNARMED_PROJECT_LIST_LABEL := "- Unarmed"
const UNARMED_BUILDER_SCOPE_LABEL := "Empty Hand"
const PREVIEW_RUNTIME_CLIP_SAMPLE_RATE_HZ := 60.0
const PERSIST_RUNTIME_CACHE_KEEP: StringName = &"runtime_cache_keep"
const PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE: StringName = &"runtime_cache_dirty_active"
const PERSIST_RUNTIME_CACHE_DIRTY_ALL: StringName = &"runtime_cache_dirty_all"
const PERSIST_RUNTIME_CACHE_REFRESH_ACTIVE: StringName = &"runtime_cache_refresh_active"
const PERSIST_RUNTIME_CACHE_REFRESH_ALL: StringName = &"runtime_cache_refresh_all"
const WEAPON_OPEN_PRIMARY_MENU_ID_LEFT := 1001
const WEAPON_OPEN_PRIMARY_MENU_ID_RIGHT := 1002
const WEAPON_OPEN_VARIANT_MENU_ID_ONE_HAND := 1101
const WEAPON_OPEN_VARIANT_MENU_ID_TWO_HAND := 1102
const GUARDRAIL_SEVERITY_ERROR: StringName = &"error"
const GUARDRAIL_SEVERITY_WARNING: StringName = &"warning"
const GUARDRAIL_SEVERITY_INFO: StringName = &"info"
const GUARDRAIL_SEVERE_RETARGET_RATIO_HIGH: float = 2.0
const GUARDRAIL_SEVERE_RETARGET_RATIO_LOW: float = 0.5

var backdrop: ColorRect = null
var panel: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var shortcut_hint_label: Label = null
var back_button: Button = null
var workflow_content_root: Control = null
var weapon_selection_view: PanelContainer = null
var skill_selection_view: PanelContainer = null
var editor_view: HBoxContainer = null
var skill_step_weapon_label: Label = null
var project_list: ItemList = null
var authoring_mode_option_button: OptionButton = null
var skill_slot_selector_container: VBoxContainer = null
var skill_slot_grid: GridContainer = null
var idle_draft_selector_container: VBoxContainer = null
var draft_list: ItemList = null
var new_skill_draft_button: Button = null
var point_list: ItemList = null
var add_point_button: Button = null
var duplicate_point_button: Button = null
var remove_point_button: Button = null
var reset_draft_button: Button = null
var save_button: Button = null
var play_preview_button: Button = null
var save_progress_bar: ProgressBar = null
var save_progress_label: Label = null
var draft_name_edit: LineEdit = null
var skill_name_edit: LineEdit = null
var skill_slot_edit: LineEdit = null
var skill_description_edit: TextEdit = null
var preview_speed_spin_box: SpinBox = null
var preview_loop_check_box: CheckBox = null
var speed_acceleration_spin_box: SpinBox = null
var speed_deceleration_spin_box: SpinBox = null
var stow_anchor_field_container: VBoxContainer = null
var stow_anchor_option_button: OptionButton = null
var stow_contact_ratio_spin_box: SpinBox = null
var position_x_spin_box: SpinBox = null
var position_y_spin_box: SpinBox = null
var position_z_spin_box: SpinBox = null
var weapon_rotation_x_spin_box: SpinBox = null
var weapon_rotation_y_spin_box: SpinBox = null
var weapon_rotation_z_spin_box: SpinBox = null
var transition_spin_box: SpinBox = null
var body_support_spin_box: SpinBox = null
var two_hand_state_option_button: OptionButton = null
var primary_hand_option_button: OptionButton = null
var grip_mode_option_button: OptionButton = null
var preview_view_container: SubViewportContainer = null
var preview_subviewport: SubViewport = null
var preview_shortcut_overlay: MarginContainer = null
var preview_shortcut_overlay_label: Label = null
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
var secondary_grip_seat_slide_spin_box: SpinBox = null
var right_upperarm_roll_spin_box: SpinBox = null
var left_upperarm_roll_spin_box: SpinBox = null
var draft_notes_edit: TextEdit = null
var summary_label: Label = null
var debugger_view_button: Button = null
var footer_status_label: Label = null
var close_button: Button = null
var tip_section_foldable: FoldableContainer = null
var pommel_section_foldable: FoldableContainer = null
var weapon_section_foldable: FoldableContainer = null
var arm_roll_section_foldable: FoldableContainer = null

var active_player = null
var active_wip_library: PlayerForgeWipLibraryState = null
var active_wip: CraftedItemWIP = null
var active_saved_wip_id: StringName = StringName()
var station_display_name: String = ""
var workflow_step: StringName = WORKFLOW_STEP_WEAPON_SELECT
var refreshing_controls: bool = false
var active_handle_coordinate_display_mode: StringName = (
	BakedProfile.PRIMARY_GRIP_HANDLE_COORDINATE_MODE_DIRECTIONAL_POMMEL_TO_TIP
)
var preview_presenter = CombatAnimationStationPreviewPresenterScript.new()
var chain_player: CombatAnimationChainPlayer = CombatAnimationChainPlayerScript.new()
var session_state: CombatAnimationSessionState = CombatAnimationSessionStateScript.new()
var motion_node_editor: CombatAnimationMotionNodeEditor = CombatAnimationMotionNodeEditorScript.new()
var preview_camera_orbiting: bool = false
var preview_camera_skip_next_orbit_motion: bool = false
var preview_camera_orbit_guard_until_msec: int = 0
var editor_state_dirty: bool = false
var preview_drag_override_node: CombatAnimationMotionNode = null
var preview_drag_has_moved: bool = false
var preview_drag_refresh_pending: bool = false
var preview_drag_last_refresh_msec: int = 0
var preview_drag_first_pending_msec: int = 0
var preview_drag_pommel_authority_pending: bool = false
var preview_drag_pommel_requested_local: Vector3 = Vector3.ZERO
var preview_drag_pommel_requested_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
var preview_drag_pommel_has_solved_request: bool = false
var preview_drag_pommel_last_solved_request_local: Vector3 = Vector3.ZERO
var preview_drag_pommel_last_solved_request_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
var preview_drag_pommel_last_solve_legal: bool = true
var preview_drag_pommel_last_validation_result: Dictionary = {}
var preview_drag_chain_cache_draft: Resource = null
var preview_drag_chain_cache_selected_index: int = -1
var preview_drag_effective_motion_node_chain_cache: Array = []
var preview_drag_visible_motion_node_chain_cache: Array = []
var preview_drag_visible_selected_node_index_cache: int = -1
var preview_drag_last_refresh_cost_msec: int = 0
var debugger_view_enabled: bool = false
var draft_validator: CombatAnimationDraftValidator = CombatAnimationDraftValidatorScript.new()
var weapon_geometry_resolver = CombatAnimationWeaponGeometryResolverScript.new()
var retarget_resolver = CombatAnimationRetargetResolverScript.new()
var runtime_clip_baker = CombatRuntimeClipBakerScript.new()
var runtime_chain_compiler = CombatAnimationRuntimeChainCompilerScript.new()
var cached_editor_shortcuts_signature: String = ""
var cached_active_weapon_baseline_seed: Dictionary = {}
var cached_active_weapon_baseline_seed_signature: String = ""
var weapon_open_primary_popup: PopupMenu = null
var weapon_open_variant_popup: PopupMenu = null
var pending_weapon_open_wip_id: StringName = StringName()
var pending_weapon_open_primary_slot_id: StringName = HAND_SLOT_RIGHT
var active_preview_dominant_slot_id: StringName = HAND_SLOT_RIGHT
var active_preview_default_two_hand: bool = false
var manual_save_in_progress: bool = false
var manual_save_start_msec: int = 0

const PREVIEW_DRAG_MIN_REFRESH_INTERVAL_MSEC: int = 16
const PREVIEW_DRAG_MAX_REFRESH_INTERVAL_MSEC: int = 83
const PREVIEW_DRAG_REFRESH_COST_COOLDOWN_RATIO: float = 0.5
const PREVIEW_DRAG_INITIAL_SOLVE_DELAY_MSEC: int = 16
const PREVIEW_DRAG_POMMEL_TARGET_EPSILON_METERS: float = 0.0005
const PREVIEW_CAMERA_POST_COMMIT_MOTION_GUARD_MSEC: int = 350
var last_station_retarget_result: Dictionary = {}

func _ready() -> void:
	_build_ui()
	visible = false
	project_list.item_clicked.connect(_on_project_item_clicked)
	project_list.item_activated.connect(_on_project_item_activated)
	draft_list.item_clicked.connect(_on_draft_item_clicked)
	point_list.item_clicked.connect(_on_motion_node_item_clicked)
	authoring_mode_option_button.item_selected.connect(_on_authoring_mode_selected)
	new_skill_draft_button.pressed.connect(_on_new_skill_draft_pressed)
	add_point_button.pressed.connect(_on_add_motion_node_pressed)
	duplicate_point_button.pressed.connect(_on_duplicate_motion_node_pressed)
	remove_point_button.pressed.connect(_on_remove_motion_node_pressed)
	reset_draft_button.pressed.connect(_on_reset_draft_pressed)
	save_button.pressed.connect(_on_manual_save_pressed)
	play_preview_button.pressed.connect(_on_play_preview_pressed)
	debugger_view_button.toggled.connect(_on_debugger_view_toggled)
	draft_name_edit.text_submitted.connect(_on_draft_name_submitted)
	draft_name_edit.focus_exited.connect(_on_draft_name_focus_exited)
	skill_name_edit.text_submitted.connect(_on_skill_name_submitted)
	skill_name_edit.focus_exited.connect(_on_skill_name_focus_exited)
	skill_slot_edit.text_submitted.connect(_on_skill_slot_submitted)
	skill_slot_edit.focus_exited.connect(_on_skill_slot_focus_exited)
	skill_description_edit.focus_exited.connect(_on_skill_description_focus_exited)
	preview_speed_spin_box.value_changed.connect(_on_preview_speed_changed)
	preview_loop_check_box.toggled.connect(_on_preview_loop_toggled)
	speed_acceleration_spin_box.value_changed.connect(_on_speed_acceleration_changed)
	speed_deceleration_spin_box.value_changed.connect(_on_speed_deceleration_changed)
	stow_anchor_option_button.item_selected.connect(_on_stow_anchor_selected)
	stow_contact_ratio_spin_box.value_changed.connect(_on_stow_contact_ratio_changed)
	position_x_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(0))
	position_y_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(1))
	position_z_spin_box.value_changed.connect(_on_tip_position_component_changed.bind(2))
	weapon_rotation_x_spin_box.value_changed.connect(_on_weapon_orientation_component_changed.bind(0))
	weapon_rotation_y_spin_box.value_changed.connect(_on_weapon_orientation_component_changed.bind(1))
	weapon_rotation_z_spin_box.value_changed.connect(_on_weapon_orientation_component_changed.bind(2))
	transition_spin_box.value_changed.connect(_on_transition_changed)
	body_support_spin_box.value_changed.connect(_on_body_support_changed)
	two_hand_state_option_button.item_selected.connect(_on_two_hand_state_selected)
	primary_hand_option_button.item_selected.connect(_on_primary_hand_selected)
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
	secondary_grip_seat_slide_spin_box.value_changed.connect(_on_secondary_grip_seat_slide_changed)
	right_upperarm_roll_spin_box.value_changed.connect(_on_right_upperarm_roll_changed)
	left_upperarm_roll_spin_box.value_changed.connect(_on_left_upperarm_roll_changed)
	draft_notes_edit.focus_exited.connect(_on_draft_notes_focus_exited)
	back_button.pressed.connect(_navigate_back)
	close_button.pressed.connect(close_ui)
	preview_view_container.gui_input.connect(_on_preview_gui_input)
	weapon_open_primary_popup.id_pressed.connect(_on_weapon_open_primary_popup_id_pressed)
	weapon_open_primary_popup.popup_hide.connect(_on_weapon_open_primary_popup_hide)
	weapon_open_variant_popup.id_pressed.connect(_on_weapon_open_variant_popup_id_pressed)
	weapon_open_variant_popup.popup_hide.connect(_on_weapon_open_variant_popup_hide)
	_register_station_input_actions()
	_populate_static_options()
	_refresh_all("Select a saved weapon WIP to begin authoring.")
	_refresh_live_editor_shortcuts(true)

func _process(delta: float) -> void:
	if panel != null and panel.visible and workflow_step == WORKFLOW_STEP_EDITOR:
		_refresh_live_editor_shortcuts()
		_flush_pending_preview_drag_refresh()
	if not chain_player.is_playing():
		return
	chain_player.advance(delta)
	if session_state.playback_active:
		_sync_preview_playback_pose_only()
	else:
		_refresh_preview_scene()
	if not chain_player.is_playing():
		session_state.playback_active = false
		footer_status_label.text = "Preview finished."

func _input(event: InputEvent) -> void:
	if _has_visible_weapon_open_popup():
		return
	_capture_editor_cycle_focus_event(event)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if _has_visible_weapon_open_popup():
		if event.is_action_pressed(&"ui_cancel"):
			if (
				is_instance_valid(weapon_open_variant_popup)
				and weapon_open_variant_popup.visible
			):
				weapon_open_variant_popup.hide()
			elif (
				is_instance_valid(weapon_open_primary_popup)
				and weapon_open_primary_popup.visible
			):
				weapon_open_primary_popup.hide()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mouse_button_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button_event.button_index == MOUSE_BUTTON_RIGHT and not mouse_button_event.pressed:
			preview_camera_orbiting = false
	if event.is_action_pressed(&"ui_cancel"):
		var root_window := get_window()
		if not is_instance_valid(root_window) or not root_window.has_focus():
			get_viewport().set_input_as_handled()
			return
		_navigate_back()
		get_viewport().set_input_as_handled()
		return
	if workflow_step != WORKFLOW_STEP_EDITOR:
		return
	if _event_matches_any_action(event, [ACTION_PREV_NODE, LEGACY_ACTION_PREV_NODE]):
		_navigate_motion_node(-1)
		get_viewport().set_input_as_handled()
		return
	if _event_matches_any_action(event, [ACTION_NEXT_NODE, LEGACY_ACTION_NEXT_NODE]):
		_navigate_motion_node(1)
		get_viewport().set_input_as_handled()
		return
	if _event_matches_any_action(event, [ACTION_NEW_NODE, LEGACY_ACTION_COPY_NODE]):
		insert_motion_node_after_selection()
		get_viewport().set_input_as_handled()
		return
	if _event_matches_any_action(event, [ACTION_DELETE_NODE, LEGACY_ACTION_DELETE_NODE]):
		remove_selected_motion_node()
		get_viewport().set_input_as_handled()
		return
	if _capture_editor_cycle_focus_event(event):
		return
	if _event_matches_any_action(event, [ACTION_PREVIEW_PLAYBACK]):
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
	_migrate_saved_skill_draft_baselines_if_needed()
	station_display_name = bench_name
	title_label.text = "SKILL CRAFTER"
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", true)
	visible = true
	backdrop.visible = true
	panel.visible = true
	preview_camera_orbiting = false
	editor_state_dirty = false
	preview_drag_override_node = null
	_hide_weapon_open_popups()
	_reset_active_weapon_open_config()
	session_state.reset()
	active_wip = null
	active_saved_wip_id = _resolve_initial_project_list_selection_id()
	workflow_step = WORKFLOW_STEP_WEAPON_SELECT
	_refresh_all("Select a weapon to begin.")

func close_ui() -> void:
	if not panel.visible:
		return
	chain_player.stop()
	preview_camera_orbiting = false
	if motion_node_editor.is_dragging():
		motion_node_editor.end_drag()
	_finalize_preview_drag("Motion node edit locked in.")
	editor_state_dirty = false
	_set_manual_save_progress(0.0, "", false)
	preview_drag_override_node = null
	panel.visible = false
	backdrop.visible = false
	visible = false
	if active_player != null and active_player.has_method("set_ui_mode_enabled"):
		active_player.call("set_ui_mode_enabled", false)
	active_player = null
	active_wip_library = null
	active_wip = null
	active_saved_wip_id = StringName()
	station_display_name = ""
	workflow_step = WORKFLOW_STEP_WEAPON_SELECT
	last_station_retarget_result = {}
	_hide_weapon_open_popups()
	_reset_active_weapon_open_config()
	session_state.reset()
	emit_signal("closed")

func is_open() -> bool:
	return panel.visible

func select_saved_wip(
	saved_wip_id: StringName,
	advance_workflow: bool = true,
	opening_config: Dictionary = {}
) -> bool:
	var open_perf_trace: Array = []
	var open_perf_step_usec: int = Time.get_ticks_usec()
	var trace_open_latency: bool = bool(get_meta("trace_open_latency", false))
	if _is_unarmed_authoring_wip_id(saved_wip_id):
		return select_unarmed_authoring(advance_workflow, opening_config)
	if active_wip_library == null:
		return false
	if active_wip != null and active_saved_wip_id != StringName():
		_finalize_preview_drag("Motion node edit locked in.")
	if active_wip != null and active_saved_wip_id != StringName() and active_saved_wip_id != saved_wip_id:
		editor_state_dirty = false
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "pre_clone", open_perf_step_usec)
	var reusing_active_wip: bool = active_wip != null and active_saved_wip_id == saved_wip_id
	var selected_clone: CraftedItemWIP = (
		active_wip
		if reusing_active_wip
		else active_wip_library.get_saved_wip_clone(saved_wip_id, false)
	)
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "get_saved_wip_clone", open_perf_step_usec)
	if selected_clone == null:
		return false
	selected_clone.ensure_combat_animation_station_state()
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "ensure_station_state", open_perf_step_usec)
	active_saved_wip_id = saved_wip_id
	active_wip = selected_clone
	editor_state_dirty = false
	_set_manual_save_progress(0.0, "", false)
	active_wip_library.set_selected_wip_id(saved_wip_id, false)
	session_state.current_weapon_wip_id = saved_wip_id
	_apply_active_weapon_open_config(_normalize_weapon_open_config(opening_config, selected_clone))
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "apply_open_config", open_perf_step_usec)
	var geometry_seeded: bool = false
	if not reusing_active_wip:
		geometry_seeded = _seed_active_station_drafts_from_weapon_geometry()
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "seed_station_geometry", open_perf_step_usec)
	var retarget_result: Dictionary = (
		_retarget_active_station_drafts_for_current_weapon_geometry()
		if geometry_seeded or _active_station_retarget_requires_weapon_length_update()
		else {
			"changed": false,
			"seeded_count": 0,
			"retargeted_count": 0,
			"endpoint_changed_count": 0,
			"draft_count": 0,
			"skipped": true,
			"reason": "saved_weapon_geometry_unchanged",
		}
	)
	last_station_retarget_result = retarget_result.duplicate(true)
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "retarget_station_geometry", open_perf_step_usec)
	if geometry_seeded:
		_stage_active_wip_edit("Aligned baseline motion nodes with stage-1 weapon geometry.", PERSIST_RUNTIME_CACHE_DIRTY_ALL)
		if trace_open_latency:
			open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "stage_seeded_geometry", open_perf_step_usec)
	var load_message: String = "Loaded %s." % selected_clone.forge_project_name
	if int(retarget_result.get("retargeted_count", 0)) > 0:
		load_message = "%s Retargeted motion preview to current weapon geometry." % load_message
	_refresh_all(load_message)
	if trace_open_latency:
		open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "refresh_all", open_perf_step_usec)
	if geometry_seeded and _realign_active_draft_to_preview_open_baseline(true):
		var baseline_message: String = "Aligned active draft baseline with the current hand mount."
		_stage_active_wip_edit(baseline_message, PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE)
		_refresh_all(baseline_message)
		if trace_open_latency:
			open_perf_step_usec = _append_perf_trace_elapsed(open_perf_trace, "realign_active_baseline", open_perf_step_usec)
	if advance_workflow:
		_set_workflow_step(WORKFLOW_STEP_SKILL_SELECT, "Loaded %s. Select a skill slot or idle draft." % selected_clone.forge_project_name)
	if trace_open_latency:
		_append_perf_trace_elapsed(open_perf_trace, "advance_workflow", open_perf_step_usec)
		set_meta("last_open_latency_trace", open_perf_trace)
	return true

func select_unarmed_authoring(
	advance_workflow: bool = true,
	opening_config: Dictionary = {}
) -> bool:
	if active_wip_library == null:
		return false
	var unarmed_wip_id: StringName = CraftedItemWIPScript.UNARMED_AUTHORING_WIP_ID
	if active_wip != null and active_saved_wip_id != StringName():
		_finalize_preview_drag("Motion node edit locked in.")
	if active_wip != null and active_saved_wip_id != StringName() and active_saved_wip_id != unarmed_wip_id:
		editor_state_dirty = false
	var reusing_active_wip: bool = active_wip != null and active_saved_wip_id == unarmed_wip_id
	var selected_clone: CraftedItemWIP = active_wip if reusing_active_wip else _get_or_create_unarmed_authoring_wip_clone()
	if selected_clone == null:
		return false
	_normalize_unarmed_authoring_wip(selected_clone)
	active_saved_wip_id = unarmed_wip_id
	active_wip = selected_clone
	editor_state_dirty = false
	_set_manual_save_progress(0.0, "", false)
	active_wip_library.set_selected_wip_id(unarmed_wip_id, false)
	session_state.current_weapon_wip_id = unarmed_wip_id
	_apply_active_weapon_open_config(_normalize_weapon_open_config(opening_config, selected_clone))
	var geometry_seeded: bool = false
	if not reusing_active_wip:
		_refresh_preview_scene()
		geometry_seeded = _seed_active_station_drafts_from_weapon_geometry()
	var retarget_result: Dictionary = _retarget_active_station_drafts_for_current_weapon_geometry()
	last_station_retarget_result = retarget_result.duplicate(true)
	if geometry_seeded:
		_stage_active_wip_edit("Aligned unarmed motion nodes with the hand authoring frame.", PERSIST_RUNTIME_CACHE_DIRTY_ALL)
	var load_message: String = "Loaded %s." % selected_clone.forge_project_name
	if int(retarget_result.get("retargeted_count", 0)) > 0:
		load_message = "%s Retargeted motion preview to current hand authoring frame." % load_message
	_refresh_all(load_message)
	if geometry_seeded and _realign_active_draft_to_preview_open_baseline(true):
		var baseline_message: String = "Aligned active draft baseline with the current empty-hand frame."
		_stage_active_wip_edit(baseline_message, PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE)
		_refresh_all(baseline_message)
	if advance_workflow:
		_set_workflow_step(WORKFLOW_STEP_SKILL_SELECT, "Loaded %s. Select a skill slot or idle draft." % selected_clone.forge_project_name)
	return true

func open_saved_wip_with_hand_setup(
	saved_wip_id: StringName,
	dominant_slot_id: StringName,
	use_two_hand: bool,
	advance_workflow: bool = true
) -> bool:
	if _is_unarmed_authoring_wip_id(saved_wip_id):
		return select_unarmed_authoring(advance_workflow, {
			"dominant_slot_id": dominant_slot_id,
			"use_two_hand": false,
		})
	return select_saved_wip(saved_wip_id, advance_workflow, {
		"dominant_slot_id": dominant_slot_id,
		"use_two_hand": use_two_hand,
	})

func select_authoring_mode(mode_id: StringName) -> bool:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return false
	if not CombatAnimationStationStateScript.get_authoring_mode_ids().has(mode_id):
		return false
	_finalize_preview_drag("Motion node edit locked in.")
	station_state.set("selected_authoring_mode", mode_id)
	_ensure_valid_draft_selection()
	_refresh_all("Authoring mode updated.")
	return true

func select_draft(draft_identifier: StringName, advance_workflow: bool = true) -> bool:
	var station_state: Resource = _get_active_station_state()
	var draft: Resource = _find_active_draft_by_identifier(draft_identifier)
	if station_state == null or draft == null:
		return false
	_finalize_preview_drag("Motion node edit locked in.")
	if _is_idle_mode():
		station_state.set("selected_idle_context_id", draft_identifier)
	else:
		station_state.set("selected_skill_id", draft_identifier)
	var selected_node_index: int = int(draft.get("selected_motion_node_index"))
	draft.set("selected_motion_node_index", clampi(selected_node_index, 0, maxi(int((draft.get("motion_node_chain") as Array).size()) - 1, 0)))
	session_state.current_draft_ref = draft
	if advance_workflow:
		_set_workflow_step(WORKFLOW_STEP_EDITOR)
	if _is_noncombat_idle_draft(draft):
		var stow_segment_changed: bool = _recenter_active_noncombat_stow_segment()
		if stow_segment_changed:
			_stage_active_wip_edit("Noncombat stow pivot centered.")
	_refresh_all("Draft selection updated.")
	if advance_workflow and footer_status_label != null:
		footer_status_label.text = "Editing %s." % String(draft.get("display_name"))
	return true

func select_skill_slot(slot_id: StringName, advance_workflow: bool = true) -> bool:
	if not _is_authoring_skill_slot_id(slot_id):
		return false
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return false
	_finalize_preview_drag("Motion node edit locked in.")
	station_state.set("selected_authoring_mode", CombatAnimationStationStateScript.AUTHORING_MODE_SKILL)
	var display_name: String = _get_skill_slot_display_name(slot_id)
	var draft: Resource = _find_skill_draft_by_slot_id(slot_id)
	var created_new_draft: bool = false
	if draft == null:
		created_new_draft = true
		draft = station_state.call(
			"get_or_create_skill_draft",
			slot_id,
			display_name,
			active_wip.grip_style_mode if active_wip != null else &"grip_normal",
			slot_id
		)
		if draft != null:
			_seed_draft_from_active_weapon_geometry(draft, true)
	elif StringName(draft.get("legal_slot_id")) == StringName():
		draft.set("legal_slot_id", slot_id)
	if draft == null:
		return false
	var should_realign_baseline: bool = created_new_draft or _draft_matches_raw_weapon_geometry_baseline(draft)
	station_state.set("selected_skill_id", StringName(draft.get("owning_skill_id")))
	session_state.current_draft_ref = draft
	if advance_workflow:
		_set_workflow_step(WORKFLOW_STEP_EDITOR)
	_refresh_all("Selected %s." % display_name)
	if should_realign_baseline and _realign_active_draft_to_preview_open_baseline(true):
		var baseline_message: String = "Aligned %s baseline with the active hand mount." % display_name
		_stage_active_wip_edit(baseline_message, PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE)
		_refresh_all(baseline_message)
	if advance_workflow and footer_status_label != null:
		footer_status_label.text = "Editing %s." % display_name
	return true

func create_skill_draft(skill_id: StringName = StringName(), display_name: String = "") -> StringName:
	var resolved_slot_id: StringName = skill_id if _is_authoring_skill_slot_id(skill_id) else _find_first_unassigned_skill_slot_id()
	if resolved_slot_id == StringName():
		return StringName()
	if not select_skill_slot(resolved_slot_id, true):
		return StringName()
	var resolved_display_name: String = display_name.strip_edges()
	if not resolved_display_name.is_empty():
		set_active_draft_skill_name(resolved_display_name)
	return resolved_slot_id

func select_motion_node(node_index: int) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		return false
	_finalize_preview_drag("Motion node edit locked in.")
	draft.set("selected_motion_node_index", clampi(node_index, 0, motion_node_chain.size() - 1))
	session_state.current_motion_node_index = int(draft.get("selected_motion_node_index"))
	_refresh_active_editor_surface("Motion node selection updated.")
	return true

func insert_motion_node_after_selection() -> bool:
	var trace_enabled: bool = bool(get_meta("trace_editor_action_latency", false))
	var trace: Array = []
	var trace_step_usec: int = Time.get_ticks_usec()
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	if _is_idle_draft(draft):
		return reset_active_draft_to_baseline()
	_finalize_preview_drag("Motion node edit locked in.")
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "finalize_preview_drag", trace_step_usec)
	var seed_node: CombatAnimationMotionNode = _get_active_motion_node()
	var new_node: CombatAnimationMotionNode = _duplicate_or_build_motion_node(seed_node)
	if new_node == null:
		return false
	_prepare_inserted_motion_node_identity(new_node)
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "duplicate_seed_node", trace_step_usec)
	var insert_index: int = int(draft.get("selected_motion_node_index")) + 1
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		var insert_result: Dictionary = typed_draft.insert_motion_node_after_selected(new_node)
		if not bool(insert_result.get("inserted", false)):
			return false
		insert_index = int(insert_result.get("inserted_index", insert_index))
	else:
		var motion_node_chain: Array = draft.get("motion_node_chain") as Array
		insert_index = clampi(int(draft.get("selected_motion_node_index")), 0, maxi(motion_node_chain.size() - 1, 0)) + 1
		motion_node_chain.insert(insert_index, new_node)
		draft.set("selected_motion_node_index", insert_index)
	_normalize_draft(draft)
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "insert_and_normalize", trace_step_usec)
	_stage_active_wip_edit("Inserted motion node %d." % insert_index)
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "stage_edit", trace_step_usec)
	_refresh_active_editor_surface("Inserted motion node %d." % insert_index, false)
	if trace_enabled:
		_append_perf_trace_elapsed(trace, "refresh_editor_surface", trace_step_usec)
		set_meta("last_editor_action_latency_trace", trace)
	return true

func duplicate_selected_motion_node() -> bool:
	var draft: Resource = _get_active_draft()
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if draft == null or motion_node == null:
		return false
	if _is_idle_draft(draft):
		return reset_active_draft_to_baseline()
	_finalize_preview_drag("Motion node edit locked in.")
	motion_node = _get_active_motion_node()
	if motion_node == null:
		return false
	var selected_index: int = int(draft.get("selected_motion_node_index"))
	var duplicate_node: CombatAnimationMotionNode = _duplicate_or_build_motion_node(motion_node)
	if duplicate_node == null:
		return false
	_prepare_inserted_motion_node_identity(duplicate_node)
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		var insert_result: Dictionary = typed_draft.insert_motion_node_after_selected(duplicate_node)
		if not bool(insert_result.get("inserted", false)):
			return false
		selected_index = int(insert_result.get("inserted_index", selected_index)) - 1
	else:
		var motion_node_chain: Array = draft.get("motion_node_chain") as Array
		selected_index = clampi(selected_index, 0, maxi(motion_node_chain.size() - 1, 0))
		motion_node_chain.insert(selected_index + 1, duplicate_node)
		draft.set("selected_motion_node_index", selected_index + 1)
	_normalize_draft(draft)
	_stage_active_wip_edit("Duplicated motion node %d." % selected_index)
	_refresh_active_editor_surface("Duplicated motion node %d." % selected_index, false)
	return true

func remove_selected_motion_node() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	if _is_idle_draft(draft):
		_refresh_all("Idle drafts are single locked motion nodes; use Reset to restore the pose.")
		return false
	_finalize_preview_drag("Motion node edit locked in.")
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.size() <= _get_minimum_motion_node_count(draft):
		_refresh_all("Minimum baseline motion node count reached.")
		return false
	var selected_index: int = clampi(int(draft.get("selected_motion_node_index")), 0, motion_node_chain.size() - 1)
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		var remove_result: Dictionary = typed_draft.remove_selected_motion_node_ripple(_get_minimum_motion_node_count(draft))
		if not bool(remove_result.get("removed", false)):
			_refresh_all("Minimum baseline motion node count reached.")
			return false
		selected_index = int(remove_result.get("removed_index", selected_index))
	else:
		motion_node_chain.remove_at(selected_index)
		draft.set("selected_motion_node_index", clampi(selected_index, 0, motion_node_chain.size() - 1))
		draft.set("continuity_motion_node_index", clampi(int(draft.get("continuity_motion_node_index")), 0, motion_node_chain.size() - 1))
	_normalize_draft(draft)
	_stage_active_wip_edit("Removed motion node %d." % selected_index)
	_refresh_active_editor_surface("Removed motion node %d." % selected_index)
	return true

func reset_active_draft_to_baseline() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	chain_player.stop()
	session_state.playback_active = false
	preview_camera_orbiting = false
	if motion_node_editor.is_dragging():
		motion_node_editor.end_drag()
	_clear_preview_drag_override()
	preview_presenter.reset_preview_actor_to_mount_seed_baseline(preview_subviewport)
	var geometry_seed: Dictionary = _resolve_active_weapon_authored_baseline_seed(true)
	var used_weapon_seed: bool = not geometry_seed.is_empty()
	var reset_ok: bool = false
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		reset_ok = typed_draft.reset_authoring_baseline(geometry_seed)
	elif draft.has_method("reset_authoring_baseline"):
		reset_ok = bool(draft.call("reset_authoring_baseline", geometry_seed))
	elif used_weapon_seed:
		reset_ok = _seed_draft_from_active_weapon_geometry(draft, true)
	if not reset_ok:
		_refresh_all("Unable to reset the current draft baseline.")
		return false
	_normalize_draft(draft)
	_enforce_idle_authority(draft, false)
	var status_message: String = "Draft reset to active weapon and grip baseline." if used_weapon_seed else "Draft reset to default baseline."
	_stage_active_wip_edit(status_message)
	_refresh_active_editor_surface(status_message)
	return true

func set_selected_motion_node_as_continuity() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	if _is_motion_node_authoring_locked(_get_active_motion_node()):
		_reject_locked_motion_node_edit()
		return false
	draft.set("continuity_motion_node_index", int(draft.get("selected_motion_node_index")))
	_stage_active_wip_edit("Continuity motion node updated.")
	_refresh_active_editor_surface("Continuity motion node updated.")
	return true

func set_selected_motion_node_tip_position(
	tip_position: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var baseline_motion_node: CombatAnimationMotionNode = _build_motion_node_segment_baseline_for_direct_edit(motion_node)
	if (
		motion_node.tip_position_local.is_equal_approx(tip_position)
		and baseline_motion_node != null
		and baseline_motion_node.tip_position_local.is_equal_approx(tip_position)
	):
		return false
	var resolved_segment: Dictionary = _resolve_motion_node_segment_for_tip_target(
		baseline_motion_node,
		tip_position
	)
	var changed: bool = _apply_resolved_segment_to_motion_node(motion_node, resolved_segment)
	if not changed:
		return false
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node tip position updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_weapon_orientation(
	weapon_degrees: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.weapon_orientation_degrees.is_equal_approx(weapon_degrees) and motion_node.weapon_orientation_authored:
		return false
	motion_node.weapon_orientation_degrees = weapon_degrees
	motion_node.weapon_orientation_authored = true
	motion_node.normalize()
	_apply_motion_node_change(
		"Weapon orientation updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_transition_duration(
	duration_seconds: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = false,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var resolved_duration: float = maxf(duration_seconds, 0.0)
	if is_equal_approx(motion_node.transition_duration_seconds, resolved_duration):
		return false
	motion_node.transition_duration_seconds = resolved_duration
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node transition updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_body_support_blend(
	blend_ratio: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var resolved_blend: float = clampf(blend_ratio, 0.0, 1.0)
	if is_equal_approx(motion_node.body_support_blend, resolved_blend):
		return false
	motion_node.body_support_blend = resolved_blend
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node body-support blend updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_upperarm_roll(
	slot_id: StringName,
	roll_degrees: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var resolved_roll: float = _wrap_degrees_signed(roll_degrees)
	var previous_roll: float = motion_node.left_upperarm_roll_degrees if slot_id == HAND_SLOT_LEFT else motion_node.right_upperarm_roll_degrees
	if is_equal_approx(previous_roll, resolved_roll):
		return false
	if slot_id == HAND_SLOT_LEFT:
		motion_node.left_upperarm_roll_degrees = resolved_roll
	else:
		motion_node.right_upperarm_roll_degrees = resolved_roll
	motion_node.normalize()
	_apply_motion_node_change(
		"Upper arm roll updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_hand_proxy_segment(
	slot_id: StringName,
	tip_position: Vector3,
	pommel_position: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if not _resolve_available_hand_proxy_slots(motion_node).has(slot_id):
		return false
	var changed: bool = _apply_hand_proxy_segment_to_motion_node(motion_node, slot_id, tip_position, pommel_position)
	if not changed:
		return false
	motion_node.normalize()
	_apply_motion_node_change(
		"%s hand position updated." % ("Left" if slot_id == HAND_SLOT_LEFT else "Right"),
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func clear_selected_motion_node_hand_proxy_segment(
	slot_id: StringName,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var changed: bool = false
	if slot_id == HAND_SLOT_LEFT and motion_node.left_hand_proxy_authored:
		motion_node.left_hand_proxy_authored = false
		changed = true
	elif slot_id != HAND_SLOT_LEFT and motion_node.right_hand_proxy_authored:
		motion_node.right_hand_proxy_authored = false
		changed = true
	if not changed:
		return false
	motion_node.normalize()
	_apply_motion_node_change(
		"%s hand position cleared." % ("Left" if slot_id == HAND_SLOT_LEFT else "Right"),
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_two_hand_state(
	state_id: StringName,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null or not CombatAnimationMotionNodeScript.get_two_hand_state_ids().has(state_id):
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.two_hand_state == state_id:
		return false
	motion_node.two_hand_state = state_id
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node two-hand state updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_primary_hand_slot(
	slot_id: StringName,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var draft: Resource = _get_active_draft()
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	var resolved_slot_id: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(slot_id)
	if motion_node == null:
		return false
	if not _is_active_unarmed_authoring_wip():
		var equipment_authority_slot_id: StringName = _resolve_active_authoring_primary_slot_id()
		if motion_node.primary_hand_slot != equipment_authority_slot_id:
			motion_node.primary_hand_slot = equipment_authority_slot_id
			motion_node.normalize()
		_refresh_editor_fields()
		footer_status_label.text = "Weapon primary hand is locked to its equipped/open slot."
		return false
	if _is_idle_draft(draft):
		_enforce_idle_authority(draft, true)
		_refresh_all("Idle primary hand is locked from equipment/open hand context.")
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.primary_hand_slot == resolved_slot_id:
		return false
	_clear_active_weapon_baseline_seed_cache()
	motion_node.primary_hand_slot = resolved_slot_id
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node primary hand updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_preferred_grip_style(
	grip_mode: StringName,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if not _can_insert_grip_style_transition_from_motion_node(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var resolved_grip_mode: StringName = CraftedItemWIPScript.resolve_supported_grip_style(
		grip_mode,
		active_wip.forge_intent if active_wip != null else StringName(),
		active_wip.equipment_context if active_wip != null else StringName()
	)
	if motion_node.preferred_grip_style_mode == resolved_grip_mode:
		return false
	_clear_active_weapon_baseline_seed_cache()
	return _insert_generated_grip_style_transition_after_selection(
		resolved_grip_mode,
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)

func _insert_generated_grip_style_transition_after_selection(
	target_grip_mode: StringName,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var draft: Resource = _get_active_draft()
	var source_node: CombatAnimationMotionNode = _get_active_motion_node()
	if draft == null or source_node == null:
		return false
	var bridge_node: CombatAnimationMotionNode = source_node.duplicate_node()
	if bridge_node == null:
		return false
	var pivot_local: Vector3 = _resolve_primary_grip_pivot_for_motion_node(source_node)
	bridge_node.tip_position_local = _reflect_point_across_pivot(source_node.tip_position_local, pivot_local)
	bridge_node.pommel_position_local = _reflect_point_across_pivot(source_node.pommel_position_local, pivot_local)
	bridge_node.tip_curve_in_handle = Vector3.ZERO
	bridge_node.tip_curve_out_handle = Vector3.ZERO
	bridge_node.pommel_curve_in_handle = Vector3.ZERO
	bridge_node.pommel_curve_out_handle = Vector3.ZERO
	bridge_node.preferred_grip_style_mode = target_grip_mode
	_apply_grip_style_bridge_weapon_frame(bridge_node, target_grip_mode)
	bridge_node.generated_transition_node = true
	bridge_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_GRIP_STYLE_SWAP
	bridge_node.locked_for_authoring = true
	bridge_node.draft_notes = "Generated grip-style swap bridge. Endpoints stay locked; Bezier path handles can be shaped."
	bridge_node.normalize()
	var insert_index: int = int(draft.get("selected_motion_node_index")) + 1
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		var insert_result: Dictionary = typed_draft.insert_motion_node_after_selected(bridge_node)
		if not bool(insert_result.get("inserted", false)):
			return false
		insert_index = int(insert_result.get("inserted_index", insert_index))
	else:
		var motion_node_chain: Array = draft.get("motion_node_chain") as Array
		insert_index = clampi(int(draft.get("selected_motion_node_index")), 0, maxi(motion_node_chain.size() - 1, 0)) + 1
		motion_node_chain.insert(insert_index, bridge_node)
		draft.set("selected_motion_node_index", insert_index)
	_normalize_draft(draft)
	_apply_motion_node_change(
		"Generated %s grip-swap bridge at motion node %d." % [
			CraftedItemWIPScript.get_grip_style_label(target_grip_mode),
			insert_index,
		],
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func _apply_grip_style_bridge_weapon_frame(bridge_node: CombatAnimationMotionNode, target_grip_mode: StringName) -> void:
	if bridge_node == null:
		return
	var target_seed: Dictionary = _resolve_active_weapon_motion_seed(false, target_grip_mode)
	if target_seed.is_empty():
		return
	bridge_node.weapon_orientation_degrees = target_seed.get(
		"weapon_orientation_degrees",
		bridge_node.weapon_orientation_degrees
	) as Vector3
	bridge_node.weapon_orientation_authored = bool(target_seed.get("weapon_orientation_authored", true))
	bridge_node.weapon_roll_degrees = float(target_seed.get("weapon_roll_degrees", bridge_node.weapon_roll_degrees))

func _resolve_primary_grip_pivot_for_motion_node(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node == null:
		return Vector3.ZERO
	var preview_pivot: Variant = preview_presenter.resolve_motion_node_primary_grip_seat_local(
		preview_subviewport,
		motion_node
	)
	if preview_pivot != null:
		return preview_pivot as Vector3
	var geometry_seed: Dictionary = _resolve_active_weapon_geometry_seed_base()
	var seed_tip: Vector3 = geometry_seed.get("tip_position_local", motion_node.tip_position_local) as Vector3
	var seed_pommel: Vector3 = geometry_seed.get("pommel_position_local", motion_node.pommel_position_local) as Vector3
	var seed_axis: Vector3 = seed_tip - seed_pommel
	if seed_axis.length_squared() <= 0.000001:
		return motion_node.pommel_position_local.lerp(motion_node.tip_position_local, 0.5)
	var grip_ratio_from_pommel: float = clampf((-seed_pommel).dot(seed_axis) / seed_axis.length_squared(), 0.0, 1.0)
	return motion_node.pommel_position_local.lerp(motion_node.tip_position_local, grip_ratio_from_pommel)

func _reflect_point_across_pivot(point_local: Vector3, pivot_local: Vector3) -> Vector3:
	return pivot_local + (pivot_local - point_local)

func set_selected_motion_node_tip_curve_in(
	curve_in_handle: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if not _can_author_motion_node_curve_handles(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.tip_curve_in_handle.is_equal_approx(curve_in_handle):
		return false
	motion_node.tip_curve_in_handle = curve_in_handle
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node tip curve-in handle updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_tip_curve_out(
	curve_out_handle: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if not _can_author_motion_node_curve_handles(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.tip_curve_out_handle.is_equal_approx(curve_out_handle):
		return false
	motion_node.tip_curve_out_handle = curve_out_handle
	motion_node.normalize()
	_apply_motion_node_change(
		"Motion node tip curve-out handle updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_active_draft_display_name(display_name: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("display_name", display_name.strip_edges())
	_normalize_draft(draft)
	_stage_active_wip_edit("Draft display name updated.", PERSIST_RUNTIME_CACHE_KEEP)
	_refresh_draft_list()
	_refresh_editor_fields()
	_refresh_summary("Draft display name updated.")
	return true

func set_active_draft_slot_id(slot_id: StringName) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	if slot_id != StringName() and not _is_authoring_skill_slot_id(slot_id):
		return false
	draft.set("legal_slot_id", slot_id)
	_normalize_draft(draft)
	_stage_active_wip_edit("Draft slot updated.")
	_refresh_draft_list()
	_refresh_skill_slot_selector()
	_refresh_editor_fields()
	_refresh_summary("Draft slot updated.")
	return true

func set_active_draft_preview_speed(speed_scale: float) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("preview_playback_speed_scale", maxf(speed_scale, 0.01))
	_normalize_draft(draft)
	_stage_active_wip_edit("Preview speed updated.")
	_refresh_editor_fields()
	_refresh_summary("Preview speed updated.")
	return true

func set_active_draft_speed_acceleration_percent(percent_value: float) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("speed_acceleration_percent", clampf(percent_value, 0.0, 100.0))
	_normalize_draft(draft)
	_stage_active_wip_edit("Acceleration tuning updated.")
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Acceleration tuning updated.")
	return true

func set_active_draft_speed_deceleration_percent(percent_value: float) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("speed_deceleration_percent", clampf(percent_value, 0.0, 100.0))
	_normalize_draft(draft)
	_stage_active_wip_edit("Deceleration tuning updated.")
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Deceleration tuning updated.")
	return true

func set_active_draft_stow_anchor_mode(stow_mode: StringName) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null or not _is_noncombat_idle_draft(draft):
		return false
	var resolved_stow_mode: StringName = CombatAnimationDraftScript.normalize_stow_anchor_mode(stow_mode)
	if StringName(draft.get("stow_anchor_mode")) == resolved_stow_mode:
		return false
	draft.set("stow_anchor_mode", resolved_stow_mode)
	_normalize_draft(draft)
	_recenter_active_noncombat_stow_segment()
	_stage_active_wip_edit("Noncombat stow anchor updated.")
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Noncombat stow anchor updated.")
	return true

func set_active_draft_stow_contact_ratio(contact_ratio: float) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null or not _is_noncombat_idle_draft(draft):
		return false
	var resolved_contact_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(contact_ratio)
	if is_equal_approx(float(draft.get("stow_contact_ratio")), resolved_contact_ratio):
		return false
	draft.set("stow_contact_ratio", resolved_contact_ratio)
	_normalize_draft(draft)
	_recenter_active_noncombat_stow_segment()
	_stage_active_wip_edit("Noncombat stow contact updated.")
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary("Noncombat stow contact updated.")
	return true

func set_active_draft_preview_loop(loop_enabled: bool) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("preview_loop_enabled", loop_enabled)
	_normalize_draft(draft)
	_stage_active_wip_edit("Preview loop updated.")
	_refresh_editor_fields()
	_refresh_summary("Preview loop updated.")
	return true

func set_active_draft_notes(notes_text: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("draft_notes", notes_text)
	_normalize_draft(draft)
	_stage_active_wip_edit("Draft notes updated.", PERSIST_RUNTIME_CACHE_KEEP)
	_refresh_summary("Draft notes updated.")
	return true

func get_active_saved_wip_id() -> StringName:
	return active_saved_wip_id

func get_active_open_dominant_slot_id() -> StringName:
	return active_preview_dominant_slot_id

func get_active_motion_node_primary_slot_id() -> StringName:
	return _resolve_active_motion_node_primary_slot_id()

func is_active_open_two_hand() -> bool:
	return active_preview_default_two_hand

func get_active_draft_identifier() -> StringName:
	var draft: Resource = _get_active_draft()
	return _get_draft_identifier(draft)

func get_selected_motion_node_index() -> int:
	var draft: Resource = _get_active_draft()
	return int(draft.get("selected_motion_node_index")) if draft != null else 0

func get_preview_debug_state() -> Dictionary:
	var debug_state: Dictionary = preview_presenter.get_debug_state(preview_subviewport)
	debug_state["editor_guardrail_state"] = _build_editor_guardrail_state(debug_state)
	return debug_state

func get_editor_guardrail_state() -> Dictionary:
	return _build_editor_guardrail_state(preview_presenter.get_debug_state(preview_subviewport))

func orbit_preview_camera(relative_pixels: Vector2) -> bool:
	return preview_presenter.orbit_camera(preview_subviewport, relative_pixels)

func zoom_preview_camera(step_count: int) -> bool:
	return preview_presenter.zoom_camera(preview_subviewport, step_count)

func _event_matches_any_action(event: InputEvent, action_names: Array[StringName]) -> bool:
	for action_name: StringName in action_names:
		if action_name == StringName():
			continue
		if not InputMap.has_action(action_name):
			continue
		if event.is_action_pressed(action_name):
			return true
	return false

func _capture_editor_cycle_focus_event(event: InputEvent) -> bool:
	if not _should_capture_editor_cycle_focus_event(event):
		return false
	_cycle_focus()
	get_viewport().set_input_as_handled()
	return true

func _should_capture_editor_cycle_focus_event(event: InputEvent) -> bool:
	if panel == null or not panel.visible or workflow_step != WORKFLOW_STEP_EDITOR:
		return false
	if not _event_matches_any_action(event, [ACTION_CYCLE_FOCUS, LEGACY_ACTION_CYCLE_FOCUS]):
		return false
	if _is_text_entry_focus_active() or _is_editor_option_popup_visible():
		return false
	return true

func _is_text_entry_focus_active() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit or focus_owner is TextEdit

func _is_editor_option_popup_visible() -> bool:
	for option_button in [
		authoring_mode_option_button,
		two_hand_state_option_button,
		primary_hand_option_button,
		grip_mode_option_button,
		stow_anchor_option_button,
	]:
		if option_button == null:
			continue
		var popup: PopupMenu = option_button.get_popup()
		if popup != null and popup.visible:
			return true
	return false

func _set_workflow_step(step_id: StringName, status_message: String = "") -> void:
	if step_id == StringName():
		return
	workflow_step = step_id
	if workflow_step != WORKFLOW_STEP_EDITOR:
		chain_player.stop()
		session_state.playback_active = false
	_refresh_workflow_visibility()
	_refresh_header_state()
	if not status_message.strip_edges().is_empty() and footer_status_label != null:
		footer_status_label.text = status_message

func _navigate_back() -> void:
	match workflow_step:
		WORKFLOW_STEP_EDITOR:
			_finalize_preview_drag("Motion node edit locked in.")
			_set_workflow_step(WORKFLOW_STEP_SKILL_SELECT, "Returned to draft selection.")
		WORKFLOW_STEP_SKILL_SELECT:
			_set_workflow_step(WORKFLOW_STEP_WEAPON_SELECT, "Returned to weapon selection.")
		_:
			close_ui()

func _refresh_workflow_visibility() -> void:
	if weapon_selection_view != null:
		weapon_selection_view.visible = workflow_step == WORKFLOW_STEP_WEAPON_SELECT
	if skill_selection_view != null:
		skill_selection_view.visible = workflow_step == WORKFLOW_STEP_SKILL_SELECT
	if editor_view != null:
		editor_view.visible = workflow_step == WORKFLOW_STEP_EDITOR
	if back_button != null:
		back_button.visible = workflow_step != WORKFLOW_STEP_WEAPON_SELECT
	if preview_shortcut_overlay != null:
		preview_shortcut_overlay.visible = workflow_step == WORKFLOW_STEP_EDITOR

func _refresh_header_state() -> void:
	var step_label: String = "Select Weapon"
	var hint_text: String = "Double-click a saved weapon WIP to open it with defaults, or right-click it to choose hand setup."
	match workflow_step:
		WORKFLOW_STEP_SKILL_SELECT:
			step_label = "Select Skill Slot" if _is_skill_mode() else "Select Idle Draft"
			hint_text = (
				"Choose the combat slot to author. Slot labels follow Options -> Keybinding -> Combat."
				if _is_skill_mode()
				else "Choose the idle draft to author."
			)
		WORKFLOW_STEP_EDITOR:
			step_label = "Editor"
			hint_text = _build_editor_shortcut_hint_text()
	var subtitle_parts: PackedStringArray = []
	if not station_display_name.strip_edges().is_empty():
		subtitle_parts.append(station_display_name)
	if active_wip != null:
		subtitle_parts.append(active_wip.forge_project_name)
	if workflow_step == WORKFLOW_STEP_EDITOR:
		var active_draft: Resource = _get_active_draft()
		if active_draft != null:
			subtitle_parts.append(String(active_draft.get("display_name")))
	else:
		subtitle_parts.append(step_label)
	if subtitle_label != null:
		subtitle_label.text = " | ".join(subtitle_parts)
	if shortcut_hint_label != null:
		shortcut_hint_label.text = hint_text
	if skill_step_weapon_label != null:
		if active_wip == null:
			skill_step_weapon_label.text = "No weapon selected."
		else:
			skill_step_weapon_label.text = "Weapon: %s\nBuilder Scope: %s" % [
				active_wip.forge_project_name,
				CraftedItemWIPScript.get_builder_scope_label(active_wip.forge_builder_path_id, active_wip.forge_builder_component_id),
			]

func _build_editor_shortcut_hint_text() -> String:
	return "%s/%s nav  %s new node  %s del  %s cycle  %s preview" % [
		_get_action_binding_label(ACTION_PREV_NODE),
		_get_action_binding_label(ACTION_NEXT_NODE),
		_get_action_binding_label(ACTION_NEW_NODE),
		_get_action_binding_label(ACTION_DELETE_NODE),
		_get_action_binding_label(ACTION_CYCLE_FOCUS),
		_get_action_binding_label(ACTION_PREVIEW_PLAYBACK),
	]

func _build_preview_shortcut_overlay_text() -> String:
	var lines: PackedStringArray = []
	lines.append("%s / %s  Prev / Next Node" % [
		_get_action_binding_label(ACTION_PREV_NODE),
		_get_action_binding_label(ACTION_NEXT_NODE),
	])
	lines.append("%s / %s  Add / Delete Node" % [
		_get_action_binding_label(ACTION_NEW_NODE),
		_get_action_binding_label(ACTION_DELETE_NODE),
	])
	lines.append("%s  Cycle Tip / Pommel / Weapon / Arms / Free Hands" % _get_action_binding_label(ACTION_CYCLE_FOCUS))
	lines.append("%s  Preview / Stop" % _get_action_binding_label(ACTION_PREVIEW_PLAYBACK))
	lines.append("LMB  Drag Active Control / Bezier Handles")
	lines.append("Weapon Center  Rotate  |  Green Orb  Weapon Orientation")
	lines.append("RMB  Orbit Camera")
	lines.append("Wheel  Zoom")
	return "\n".join(lines)

func _get_focus_display_name(focus_id: StringName) -> String:
	match focus_id:
		CombatAnimationSessionStateScript.FOCUS_TIP:
			return "Tip"
		CombatAnimationSessionStateScript.FOCUS_POMMEL:
			return "Pommel"
		CombatAnimationSessionStateScript.FOCUS_WEAPON:
			return "Weapon Orientation"
		CombatAnimationSessionStateScript.FOCUS_ARM_ROLL:
			return "Upper Arm Roll"
		CombatAnimationSessionStateScript.FOCUS_RIGHT_ARM_ROLL:
			return "Right Upper Arm Roll"
		CombatAnimationSessionStateScript.FOCUS_LEFT_ARM_ROLL:
			return "Left Upper Arm Roll"
		CombatAnimationSessionStateScript.FOCUS_RIGHT_HAND_PROXY:
			return "Right Hand"
		CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY:
			return "Left Hand"
		_:
			return String(focus_id)

func _get_action_binding_label(action_name: StringName) -> String:
	return UserSettingsRuntimeScript.get_action_binding_label(action_name)

func _refresh_live_editor_shortcuts(force: bool = false) -> void:
	var overlay_text: String = _build_preview_shortcut_overlay_text()
	var header_text: String = _build_editor_shortcut_hint_text()
	var add_button_text: String = "+ Add [%s]" % _get_action_binding_label(ACTION_NEW_NODE)
	var remove_button_text: String = "Delete [%s]" % _get_action_binding_label(ACTION_DELETE_NODE)
	var preview_button_text: String = "%s [%s]" % [
		"Stop" if chain_player.is_playing() else "Play",
		_get_action_binding_label(ACTION_PREVIEW_PLAYBACK),
	]
	var signature: String = "\n".join([
		overlay_text,
		header_text,
		add_button_text,
		remove_button_text,
		preview_button_text,
	])
	if not force and signature == cached_editor_shortcuts_signature:
		return
	cached_editor_shortcuts_signature = signature
	if preview_shortcut_overlay_label != null:
		preview_shortcut_overlay_label.text = overlay_text
	if shortcut_hint_label != null and workflow_step == WORKFLOW_STEP_EDITOR:
		shortcut_hint_label.text = header_text
	if add_point_button != null:
		add_point_button.text = add_button_text
	if remove_point_button != null:
		remove_point_button.text = remove_button_text
	if play_preview_button != null:
		play_preview_button.text = preview_button_text

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.visible = false
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = COLOR_BACKDROP
	UiWindowLayerPolicyScript.configure_visual_input_surface(backdrop)
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 16
	panel.offset_right = -24
	panel.offset_bottom = -16
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = COLOR_BG_ROOT
	root_style.set_border_width_all(1)
	root_style.border_color = COLOR_BORDER
	root_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", root_style)
	panel.clip_contents = true
	UiWindowLayerPolicyScript.configure_visual_input_surface(panel)
	add_child(panel)
	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 10)
	root_margin.add_theme_constant_override("margin_right", 10)
	root_margin.add_theme_constant_override("margin_top", 8)
	root_margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(root_margin)
	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 4)
	root_margin.add_child(root_vbox)
	_build_header(root_vbox)
	var header_sep := HSeparator.new()
	header_sep.add_theme_constant_override("separation", 2)
	header_sep.add_theme_stylebox_override("separator", _make_separator_style())
	root_vbox.add_child(header_sep)
	workflow_content_root = Control.new()
	workflow_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workflow_content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(workflow_content_root)
	_build_weapon_selection_view(workflow_content_root)
	_build_skill_selection_view(workflow_content_root)
	_build_editor_view(workflow_content_root)
	_build_footer(root_vbox)
	_ensure_weapon_open_popups()

func _ensure_weapon_open_popups() -> void:
	if is_instance_valid(weapon_open_primary_popup) and is_instance_valid(weapon_open_variant_popup):
		return
	weapon_open_primary_popup = PopupMenu.new()
	weapon_open_primary_popup.name = "WeaponOpenPrimaryPopup"
	weapon_open_primary_popup.hide_on_item_selection = false
	weapon_open_primary_popup.hide_on_checkable_item_selection = false
	weapon_open_primary_popup.add_theme_font_size_override("font_size", FONT_BODY)
	UiWindowLayerPolicyScript.configure_owned_popup(
		weapon_open_primary_popup
	)
	add_child(weapon_open_primary_popup)
	weapon_open_variant_popup = PopupMenu.new()
	weapon_open_variant_popup.name = "WeaponOpenVariantPopup"
	weapon_open_variant_popup.hide_on_item_selection = true
	weapon_open_variant_popup.hide_on_checkable_item_selection = true
	weapon_open_variant_popup.add_theme_font_size_override("font_size", FONT_BODY)
	UiWindowLayerPolicyScript.attach_owned_popup(
		weapon_open_primary_popup,
		weapon_open_variant_popup
	)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	back_button = _build_styled_button(row, "< Back")
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_label = Label.new()
	title_label.text = "SKILL CRAFTER"
	title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_TITLE)
	row.add_child(title_label)
	var divider := Label.new()
	divider.text = "|"
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
	shortcut_hint_label.text = "Double-click a saved weapon WIP to open it with defaults, or right-click it to choose hand setup."
	shortcut_hint_label.add_theme_font_size_override("font_size", FONT_HINT)
	shortcut_hint_label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.32, 0.7))
	row.add_child(shortcut_hint_label)
	close_button = _build_styled_button(row, "X")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END

func _build_weapon_selection_view(parent: Control) -> void:
	weapon_selection_view = PanelContainer.new()
	weapon_selection_view.visible = false
	weapon_selection_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_selection_view.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_SECTION, COLOR_BORDER, 1, 4))
	parent.add_child(weapon_selection_view)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	weapon_selection_view.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	_build_section_header(vbox, "SELECT WEAPON")
	var helper := Label.new()
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	helper.add_theme_font_size_override("font_size", FONT_BODY)
	helper.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	helper.text = "Double-click a saved forge weapon WIP to open it with class defaults, or right-click it to choose the primary hand and one-hand / two-hand baseline."
	vbox.add_child(helper)
	project_list = ItemList.new()
	project_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	project_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	project_list.allow_reselect = true
	_style_item_list(project_list)
	vbox.add_child(project_list)

func _build_skill_selection_view(parent: Control) -> void:
	skill_selection_view = PanelContainer.new()
	skill_selection_view.visible = false
	skill_selection_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_selection_view.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_SECTION, COLOR_BORDER, 1, 4))
	parent.add_child(skill_selection_view)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	skill_selection_view.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	_build_section_header(vbox, "SELECT TARGET")
	skill_step_weapon_label = Label.new()
	skill_step_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_step_weapon_label.add_theme_font_size_override("font_size", FONT_BODY)
	skill_step_weapon_label.add_theme_color_override("font_color", COLOR_TEXT)
	skill_step_weapon_label.text = "No weapon selected."
	vbox.add_child(skill_step_weapon_label)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	vbox.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = "Authoring Mode"
	mode_label.add_theme_font_size_override("font_size", FONT_SECTION)
	mode_label.add_theme_color_override("font_color", COLOR_TEXT_HEADER)
	mode_row.add_child(mode_label)
	authoring_mode_option_button = OptionButton.new()
	authoring_mode_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option_button(authoring_mode_option_button)
	mode_row.add_child(authoring_mode_option_button)
	new_skill_draft_button = _build_styled_button(mode_row, "+ New Skill")
	new_skill_draft_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var helper := Label.new()
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	helper.add_theme_font_size_override("font_size", FONT_BODY)
	helper.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	helper.text = "Skill mode uses the combat-slot backbone. Idle mode keeps the dedicated idle draft list."
	vbox.add_child(helper)
	skill_slot_selector_container = VBoxContainer.new()
	skill_slot_selector_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_slot_selector_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skill_slot_selector_container.add_theme_constant_override("separation", 8)
	vbox.add_child(skill_slot_selector_container)
	var slot_helper := Label.new()
	slot_helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot_helper.add_theme_font_size_override("font_size", FONT_HINT)
	slot_helper.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	slot_helper.text = "Select a skill slot. The button shown on each tile always follows the current combat keybinding."
	skill_slot_selector_container.add_child(slot_helper)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 4
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_grid.add_theme_constant_override("h_separation", 10)
	slot_grid.add_theme_constant_override("v_separation", 10)
	skill_slot_selector_container.add_child(slot_grid)
	skill_slot_grid = slot_grid
	idle_draft_selector_container = VBoxContainer.new()
	idle_draft_selector_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idle_draft_selector_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	idle_draft_selector_container.add_theme_constant_override("separation", 6)
	vbox.add_child(idle_draft_selector_container)
	var idle_helper := Label.new()
	idle_helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	idle_helper.add_theme_font_size_override("font_size", FONT_HINT)
	idle_helper.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	idle_helper.text = "Idle mode uses weapon-owned idle drafts. Select one to continue."
	idle_draft_selector_container.add_child(idle_helper)
	draft_list = ItemList.new()
	draft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draft_list.allow_reselect = true
	_style_item_list(draft_list)
	idle_draft_selector_container.add_child(draft_list)

func _build_editor_view(parent: Control) -> void:
	editor_view = HBoxContainer.new()
	editor_view.visible = false
	editor_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor_view.add_theme_constant_override("separation", 4)
	parent.add_child(editor_view)
	_build_center_column(editor_view)
	_build_right_inspector(editor_view)

func _build_left_sidebar(parent: HBoxContainer) -> void:
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = 0.18
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
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 1.0
	center.add_theme_constant_override("separation", 4)
	parent.add_child(center)
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 3.0
	var pv_style := _make_panel_style(COLOR_BG_PREVIEW, COLOR_BORDER_ACCENT, 2, 4)
	preview_panel.add_theme_stylebox_override("panel", pv_style)
	center.add_child(preview_panel)
	var pv_vbox := VBoxContainer.new()
	pv_vbox.add_theme_constant_override("separation", 0)
	preview_panel.add_child(pv_vbox)
	preview_view_container = SubViewportContainer.new()
	preview_view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_view_container.stretch = true
	pv_vbox.add_child(preview_view_container)
	preview_subviewport = SubViewport.new()
	preview_subviewport.size = Vector2i(int(preview_view_container.size.x) if preview_view_container.size.x > 1.0 else 480, int(preview_view_container.size.y) if preview_view_container.size.y > 1.0 else 320)
	preview_subviewport.transparent_bg = false
	preview_subviewport.handle_input_locally = false
	preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_view_container.add_child(preview_subviewport)
	preview_shortcut_overlay = MarginContainer.new()
	preview_shortcut_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shortcut_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_shortcut_overlay.add_theme_constant_override("margin_left", 14)
	preview_shortcut_overlay.add_theme_constant_override("margin_top", 14)
	preview_shortcut_overlay.add_theme_constant_override("margin_right", 14)
	preview_shortcut_overlay.add_theme_constant_override("margin_bottom", 14)
	preview_panel.add_child(preview_shortcut_overlay)
	var preview_shortcut_layout := VBoxContainer.new()
	preview_shortcut_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shortcut_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_shortcut_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_shortcut_overlay.add_child(preview_shortcut_layout)
	var preview_shortcut_spacer := Control.new()
	preview_shortcut_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shortcut_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_shortcut_layout.add_child(preview_shortcut_spacer)
	var preview_shortcut_row := HBoxContainer.new()
	preview_shortcut_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shortcut_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_shortcut_layout.add_child(preview_shortcut_row)
	var preview_shortcut_row_spacer := Control.new()
	preview_shortcut_row_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shortcut_row_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_shortcut_row.add_child(preview_shortcut_row_spacer)
	preview_shortcut_overlay_label = Label.new()
	preview_shortcut_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_shortcut_overlay_label.custom_minimum_size = Vector2(240.0, 0.0)
	preview_shortcut_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preview_shortcut_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	preview_shortcut_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_shortcut_overlay_label.add_theme_font_size_override("font_size", FONT_HINT)
	preview_shortcut_overlay_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78, 0.88))
	preview_shortcut_overlay_label.text = ""
	preview_shortcut_row.add_child(preview_shortcut_overlay_label)
	var tl_panel := PanelContainer.new()
	tl_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tl_panel.size_flags_stretch_ratio = 1.0
	tl_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_SECTION, COLOR_BORDER, 1, 4))
	center.add_child(tl_panel)
	var tl_vbox := VBoxContainer.new()
	tl_vbox.add_theme_constant_override("separation", 3)
	tl_panel.add_child(tl_vbox)
	_build_section_header(tl_vbox, "MOTION NODE CHAIN")
	point_list = ItemList.new()
	point_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	point_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	point_list.allow_reselect = true
	_style_item_list(point_list)
	tl_vbox.add_child(point_list)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	tl_vbox.add_child(action_row)
	add_point_button = _build_styled_button(action_row, "+ Add [R]")
	duplicate_point_button = _build_styled_button(action_row, "Duplicate")
	remove_point_button = _build_styled_button(action_row, "Delete [T]")
	reset_draft_button = _build_styled_button(action_row, "Reset")
	reset_draft_button.tooltip_text = "Reset the current draft to the active weapon and grip baseline when available, otherwise fall back to the default baseline."
	save_button = _build_styled_button(action_row, "Save")
	save_button.tooltip_text = "Save current skill edits and rebuild the preview playback cache."
	play_preview_button = _build_styled_button(action_row, "Play [F]")

func _build_right_inspector(parent: HBoxContainer) -> void:
	var inspector_panel := PanelContainer.new()
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_stretch_ratio = 0.60
	inspector_panel.clip_contents = true
	inspector_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_SECTION, COLOR_BORDER, 1, 4))
	parent.add_child(inspector_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inspector_panel.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	var summary_section: Dictionary = _build_foldable_section(vbox, "CURRENT CONTEXT", true)
	var summary_content: VBoxContainer = summary_section.get("content", null) as VBoxContainer
	summary_label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", FONT_HINT)
	summary_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	summary_label.text = "No weapon selected."
	summary_content.add_child(summary_label)
	debugger_view_button = _build_styled_button(summary_content, "Debug View: OFF")
	debugger_view_button.toggle_mode = true
	debugger_view_button.button_pressed = debugger_view_enabled
	debugger_view_button.tooltip_text = "Show or hide editor-only collision, joint range, and grip debug visuals."
	var tip_section: Dictionary = _build_foldable_section(vbox, "TIP POSITION", true)
	tip_section_foldable = tip_section.get("foldable", null) as FoldableContainer
	var tip_content: VBoxContainer = tip_section.get("content", null) as VBoxContainer
	_build_field_label(tip_content, "Position (X / Y / Z)")
	var tip_pos: Array[SpinBox] = _build_vec3_row(tip_content, -4.0, 4.0, 0.01)
	position_x_spin_box = tip_pos[0]
	position_y_spin_box = tip_pos[1]
	position_z_spin_box = tip_pos[2]
	_build_field_label(tip_content, "Curve In (X / Y / Z)")
	var tip_ci: Array[SpinBox] = _build_vec3_row(tip_content, -2.0, 2.0, 0.01)
	curve_in_x_spin_box = tip_ci[0]
	curve_in_y_spin_box = tip_ci[1]
	curve_in_z_spin_box = tip_ci[2]
	_build_field_label(tip_content, "Curve Out (X / Y / Z)")
	var tip_co: Array[SpinBox] = _build_vec3_row(tip_content, -2.0, 2.0, 0.01)
	curve_out_x_spin_box = tip_co[0]
	curve_out_y_spin_box = tip_co[1]
	curve_out_z_spin_box = tip_co[2]
	var pommel_section: Dictionary = _build_foldable_section(vbox, "POMMEL POSITION", true)
	pommel_section_foldable = pommel_section.get("foldable", null) as FoldableContainer
	var pommel_content: VBoxContainer = pommel_section.get("content", null) as VBoxContainer
	_build_helper_text(pommel_content, "Pommel translates the whole weapon. Tip orbits the pommel at the solved weapon length.")
	_build_field_label(pommel_content, "Position (X / Y / Z)")
	var pom_pos: Array[SpinBox] = _build_vec3_row(pommel_content, -4.0, 4.0, 0.01)
	pommel_x_spin_box = pom_pos[0]
	pommel_y_spin_box = pom_pos[1]
	pommel_z_spin_box = pom_pos[2]
	_build_field_label(pommel_content, "Curve In (X / Y / Z)")
	var pom_ci: Array[SpinBox] = _build_vec3_row(pommel_content, -2.0, 2.0, 0.01)
	pommel_curve_in_x_spin_box = pom_ci[0]
	pommel_curve_in_y_spin_box = pom_ci[1]
	pommel_curve_in_z_spin_box = pom_ci[2]
	_build_field_label(pommel_content, "Curve Out (X / Y / Z)")
	var pom_co: Array[SpinBox] = _build_vec3_row(pommel_content, -2.0, 2.0, 0.01)
	pommel_curve_out_x_spin_box = pom_co[0]
	pommel_curve_out_y_spin_box = pom_co[1]
	pommel_curve_out_z_spin_box = pom_co[2]
	var orientation_section: Dictionary = _build_foldable_section(vbox, "WEAPON ORIENTATION", true)
	weapon_section_foldable = orientation_section.get("foldable", null) as FoldableContainer
	var orientation_content: VBoxContainer = orientation_section.get("content", null) as VBoxContainer
	_build_field_label(orientation_content, "Weapon Orientation (X / Y / Z)")
	var weapon_plane: Array[SpinBox] = _build_vec3_row(orientation_content, -360.0, 360.0, 0.5)
	weapon_rotation_x_spin_box = weapon_plane[0]
	weapon_rotation_y_spin_box = weapon_plane[1]
	weapon_rotation_z_spin_box = weapon_plane[2]
	weapon_roll_spin_box = _build_labeled_spinbox(orientation_content, "Weapon Roll (deg)", -120.0, 120.0, 1.0)
	axial_reposition_spin_box = _build_labeled_spinbox(orientation_content, "Axial Reposition", -1.0, 1.0, 0.01)
	grip_seat_slide_spin_box = _build_labeled_spinbox(orientation_content, "Primary Handle Position", 0.0, 1.0, 0.01)
	secondary_grip_seat_slide_spin_box = _build_labeled_spinbox(orientation_content, "Support Handle Position", 0.0, 1.0, 0.01)
	var timing_section: Dictionary = _build_foldable_section(vbox, "TIMING & BEHAVIOR", true)
	var timing_content: VBoxContainer = timing_section.get("content", null) as VBoxContainer
	_build_helper_text(timing_content, "Transition time is the travel time from the previous motion node into the selected node. Node 01 is the starting baseline, so its transition value is not used during preview.")
	transition_spin_box = _build_labeled_spinbox(timing_content, "Time From Previous Node (s)", 0.0, 2.0, 0.01)
	body_support_spin_box = _build_labeled_spinbox(timing_content, "Body Support", 0.0, 1.0, 0.05)
	var arm_roll_section: Dictionary = _build_foldable_section(timing_content, "UPPER ARM ROLL", true)
	arm_roll_section_foldable = arm_roll_section.get("foldable", null) as FoldableContainer
	var arm_roll_content: VBoxContainer = arm_roll_section.get("content", null) as VBoxContainer
	right_upperarm_roll_spin_box = _build_labeled_spinbox(arm_roll_content, "Right Upper Arm Roll (deg)", -180.0, 180.0, 1.0)
	left_upperarm_roll_spin_box = _build_labeled_spinbox(arm_roll_content, "Left Upper Arm Roll (deg)", -180.0, 180.0, 1.0)
	_build_field_label(timing_content, "Two-Hand State")
	two_hand_state_option_button = OptionButton.new()
	_style_option_button(two_hand_state_option_button)
	timing_content.add_child(two_hand_state_option_button)
	_build_field_label(timing_content, "Primary Hand")
	primary_hand_option_button = OptionButton.new()
	_style_option_button(primary_hand_option_button)
	timing_content.add_child(primary_hand_option_button)
	_build_field_label(timing_content, "Grip Mode")
	grip_mode_option_button = OptionButton.new()
	_style_option_button(grip_mode_option_button)
	timing_content.add_child(grip_mode_option_button)
	var draft_section: Dictionary = _build_foldable_section(vbox, "DRAFT SETTINGS", false)
	var draft_content: VBoxContainer = draft_section.get("content", null) as VBoxContainer
	_build_field_label(draft_content, "Draft Name")
	_build_helper_text(draft_content, "Internal draft label used inside the station. Keep it short and identifiable.")
	draft_name_edit = LineEdit.new()
	draft_name_edit.placeholder_text = "Unnamed Draft"
	draft_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(draft_name_edit)
	draft_content.add_child(draft_name_edit)
	_build_field_label(draft_content, "Skill Name")
	_build_helper_text(draft_content, "Display name shown to the player for this authored skill or idle draft.")
	skill_name_edit = LineEdit.new()
	skill_name_edit.placeholder_text = "Display name"
	skill_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(skill_name_edit)
	draft_content.add_child(skill_name_edit)
	_build_field_label(draft_content, "Skill Slot")
	_build_helper_text(draft_content, "Assigned by the selected slot in the selector step. This field is read-only.")
	skill_slot_edit = LineEdit.new()
	skill_slot_edit.placeholder_text = "skill_slot_1"
	skill_slot_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(skill_slot_edit)
	draft_content.add_child(skill_slot_edit)
	_build_field_label(draft_content, "Preview Speed")
	_build_helper_text(draft_content, "Playback speed multiplier for the preview only. This does not rename or move motion nodes.")
	preview_speed_spin_box = SpinBox.new()
	preview_speed_spin_box.min_value = 0.01
	preview_speed_spin_box.max_value = 3.0
	preview_speed_spin_box.step = 0.05
	preview_speed_spin_box.value = 1.0
	preview_speed_spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_spinbox(preview_speed_spin_box)
	draft_content.add_child(preview_speed_spin_box)
	speed_acceleration_spin_box = _build_labeled_spinbox(draft_content, "Acceleration Tuning (%)", 0.0, 100.0, 1.0)
	speed_deceleration_spin_box = _build_labeled_spinbox(draft_content, "Deceleration / Reset Band (%)", 0.0, 100.0, 1.0)
	stow_anchor_field_container = VBoxContainer.new()
	stow_anchor_field_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stow_anchor_field_container.add_theme_constant_override("separation", 6)
	draft_content.add_child(stow_anchor_field_container)
	_build_field_label(stow_anchor_field_container, "Noncombat Stow Anchor")
	stow_anchor_option_button = OptionButton.new()
	_style_option_button(stow_anchor_option_button)
	stow_anchor_field_container.add_child(stow_anchor_option_button)
	stow_contact_ratio_spin_box = _build_labeled_spinbox(stow_anchor_field_container, "Weapon Contact", 0.0, 1.0, 0.01)
	preview_loop_check_box = CheckBox.new()
	preview_loop_check_box.text = "Loop Preview"
	preview_loop_check_box.add_theme_color_override("font_color", COLOR_TEXT)
	preview_loop_check_box.add_theme_font_size_override("font_size", FONT_BODY)
	draft_content.add_child(preview_loop_check_box)
	_build_field_label(draft_content, "Description")
	_build_helper_text(draft_content, "Player-facing skill description. Use a few lines if needed.")
	skill_description_edit = TextEdit.new()
	skill_description_edit.custom_minimum_size = Vector2(0, 84.0)
	skill_description_edit.placeholder_text = "Skill description..."
	_style_text_edit(skill_description_edit)
	draft_content.add_child(skill_description_edit)
	_build_field_label(draft_content, "Notes")
	_build_helper_text(draft_content, "Author notes for testing, validation, or future revision work.")
	draft_notes_edit = TextEdit.new()
	draft_notes_edit.custom_minimum_size = Vector2(0, 84.0)
	_style_text_edit(draft_notes_edit)
	draft_content.add_child(draft_notes_edit)

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
	save_progress_bar = ProgressBar.new()
	save_progress_bar.min_value = 0.0
	save_progress_bar.max_value = 100.0
	save_progress_bar.value = 0.0
	save_progress_bar.visible = false
	save_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(save_progress_bar)
	save_progress_label = Label.new()
	save_progress_label.text = ""
	save_progress_label.visible = false
	save_progress_label.add_theme_font_size_override("font_size", FONT_HINT)
	save_progress_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	save_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(save_progress_label)

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

func _build_foldable_section(parent: Control, section_title: String, initially_expanded: bool) -> Dictionary:
	var fc := FoldableContainer.new()
	fc.title = section_title
	fc.folded = not initially_expanded
	fc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fc.add_theme_constant_override("title_font_size", FONT_SECTION)
	fc.add_theme_color_override("font_color", COLOR_TEXT_HEADER)
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.06, 0.07, 0.10, 0.5)
	title_style.set_corner_radius_all(2)
	title_style.content_margin_left = 6.0
	title_style.content_margin_top = 5.0
	title_style.content_margin_right = 6.0
	title_style.content_margin_bottom = 5.0
	fc.add_theme_stylebox_override("title_panel", title_style)
	fc.add_theme_stylebox_override("title_collapsed_panel", title_style)
	fc.add_theme_stylebox_override("title_hover_panel", title_style)
	fc.add_theme_stylebox_override("title_collapsed_hover_panel", title_style)
	fc.add_theme_constant_override("separation", 6)
	parent.add_child(fc)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	fc.add_child(content)
	return {
		"foldable": fc,
		"content": content,
	}


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
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(0.0, 34.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_BODY)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(lbl)
	return lbl

func _build_helper_text(parent: Control, text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(0.0, 30.0)
	lbl.add_theme_font_size_override("font_size", FONT_HINT)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	parent.add_child(lbl)
	return lbl

func _build_vec3_row(parent: Control, min_val: float, max_val: float, step_val: float) -> Array[SpinBox]:
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 4)
	parent.add_child(stack)
	var result: Array[SpinBox] = []
	var axis_labels := ["X", "Y", "Z"]
	for i: int in range(3):
		var axis_row := HBoxContainer.new()
		axis_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		axis_row.add_theme_constant_override("separation", 6)
		stack.add_child(axis_row)
		var axis_label := Label.new()
		axis_label.text = axis_labels[i]
		axis_label.custom_minimum_size = Vector2(24.0, 0.0)
		axis_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		axis_label.add_theme_font_size_override("font_size", FONT_HINT)
		axis_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		axis_row.add_child(axis_label)
		var sb := SpinBox.new()
		sb.min_value = min_val
		sb.max_value = max_val
		sb.step = step_val
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_spinbox(sb)
		axis_row.add_child(sb)
		result.append(sb)
	return result

func _build_labeled_spinbox(parent: Control, label_text: String, min_val: float, max_val: float, step_val: float) -> SpinBox:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(0.0, 34.0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_BODY)
	lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	column.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.step = step_val
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_spinbox(sb)
	column.add_child(sb)
	return sb

func _build_styled_button(parent: Control, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.begin_bulk_theme_override()
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
	btn.end_bulk_theme_override()
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
	sb.custom_minimum_size = Vector2(0.0, 30.0)
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
		le.add_theme_stylebox_override("focus", le_style)
		le.add_theme_color_override("font_color", COLOR_TEXT)
		le.add_theme_font_size_override("font_size", FONT_BODY)

func _style_line_edit(le: LineEdit) -> void:
	le.custom_minimum_size = Vector2(0.0, 30.0)
	le.begin_bulk_theme_override()
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
	le.end_bulk_theme_override()

func _style_text_edit(te: TextEdit) -> void:
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.begin_bulk_theme_override()
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
	te.end_bulk_theme_override()

func _style_option_button(ob: OptionButton) -> void:
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.custom_minimum_size = Vector2(0.0, 30.0)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	ob.add_theme_stylebox_override("normal", style)
	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = COLOR_BORDER_ACCENT
	ob.add_theme_stylebox_override("hover", focus_style)
	ob.add_theme_stylebox_override("pressed", focus_style)
	ob.add_theme_stylebox_override("focus", focus_style)
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
	primary_hand_option_button.clear()
	for slot_id: StringName in CombatAnimationMotionNodeScript.get_primary_hand_slot_ids():
		primary_hand_option_button.add_item(PRIMARY_HAND_LABELS.get(slot_id, String(slot_id)))
		primary_hand_option_button.set_item_metadata(primary_hand_option_button.get_item_count() - 1, slot_id)
	grip_mode_option_button.clear()
	for grip_mode: StringName in CraftedItemWIPScript.get_grip_style_modes():
		grip_mode_option_button.add_item(CraftedItemWIPScript.get_grip_style_label(grip_mode))
		grip_mode_option_button.set_item_metadata(grip_mode_option_button.get_item_count() - 1, grip_mode)
	stow_anchor_option_button.clear()
	for stow_mode: StringName in CombatAnimationDraftScript.get_stow_anchor_mode_ids():
		stow_anchor_option_button.add_item(STOW_ANCHOR_LABELS.get(stow_mode, String(stow_mode)))
		stow_anchor_option_button.set_item_metadata(stow_anchor_option_button.get_item_count() - 1, stow_mode)

func _select_initial_wip() -> void:
	active_wip = null
	active_saved_wip_id = StringName()
	_reset_active_weapon_open_config()
	if active_wip_library == null:
		return
	var selected_id: StringName = active_wip_library.selected_wip_id
	if _is_unarmed_authoring_wip_id(selected_id):
		select_unarmed_authoring(false)
		return
	if selected_id == StringName():
		var saved_wips: Array[CraftedItemWIP] = active_wip_library.get_saved_wips()
		for saved_wip: CraftedItemWIP in saved_wips:
			if saved_wip == null or _is_unarmed_authoring_wip_id(saved_wip.wip_id):
				continue
			selected_id = saved_wip.wip_id
			break
	if selected_id != StringName():
		select_saved_wip(selected_id, false)
	else:
		select_unarmed_authoring(false)

func _resolve_initial_project_list_selection_id() -> StringName:
	if active_wip_library == null:
		return StringName()
	var selected_id: StringName = active_wip_library.selected_wip_id
	if _is_unarmed_authoring_wip_id(selected_id):
		return selected_id
	if selected_id != StringName() and active_wip_library.get_saved_wip(selected_id) != null:
		return selected_id
	return StringName()

func _refresh_all(status_message: String = "") -> void:
	_ensure_valid_editor_motion_node_selection()
	_enforce_active_idle_authority(true)
	_refresh_debugger_view_button()
	_refresh_project_list()
	if workflow_step == WORKFLOW_STEP_WEAPON_SELECT and active_wip == null:
		_refresh_summary(status_message)
		_refresh_workflow_visibility()
		_refresh_header_state()
		return
	_refresh_authoring_mode_selector()
	_refresh_draft_list()
	_refresh_skill_slot_selector()
	if workflow_step != WORKFLOW_STEP_EDITOR:
		_refresh_summary(status_message)
		_refresh_workflow_visibility()
		_refresh_header_state()
		return
	_refresh_motion_node_list()
	_refresh_editor_fields()
	_refresh_preview_scene()
	_refresh_summary(status_message)
	_refresh_workflow_visibility()
	_refresh_header_state()

func _refresh_active_editor_surface(status_message: String = "", refresh_pose: bool = true) -> void:
	var trace_enabled: bool = bool(get_meta("trace_editor_surface_latency", false))
	var trace: Array = []
	var trace_step_usec: int = Time.get_ticks_usec()
	_ensure_valid_editor_motion_node_selection()
	_enforce_active_idle_authority(true)
	_refresh_debugger_view_button()
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "selection_authority_debug_button", trace_step_usec)
	_refresh_motion_node_list()
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "refresh_motion_node_list", trace_step_usec)
	_refresh_editor_fields()
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "refresh_editor_fields", trace_step_usec)
	if refresh_pose:
		_refresh_preview_scene()
	else:
		_refresh_preview_focus_visuals()
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "refresh_preview", trace_step_usec)
	_refresh_summary(status_message)
	if trace_enabled:
		trace_step_usec = _append_perf_trace_elapsed(trace, "refresh_summary", trace_step_usec)
	_refresh_header_state()
	if trace_enabled:
		_append_perf_trace_elapsed(trace, "refresh_header_state", trace_step_usec)
		set_meta("last_editor_surface_latency_trace", trace)

func _refresh_debugger_view_button() -> void:
	if debugger_view_button == null:
		return
	debugger_view_button.set_pressed_no_signal(debugger_view_enabled)
	debugger_view_button.text = "Debug View: ON" if debugger_view_enabled else "Debug View: OFF"

func _refresh_project_list() -> void:
	project_list.clear()
	if active_wip_library == null:
		return
	_add_unarmed_project_list_item()
	var saved_wips: Array[CraftedItemWIP] = active_wip_library.get_saved_wips()
	for saved_wip: CraftedItemWIP in saved_wips:
		if saved_wip == null:
			continue
		if _is_unarmed_authoring_wip_id(saved_wip.wip_id):
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
	if idle_draft_selector_container != null:
		idle_draft_selector_container.visible = not _is_skill_mode()
	new_skill_draft_button.visible = false
	new_skill_draft_button.disabled = _get_active_station_state() == null

func _refresh_skill_slot_selector() -> void:
	if skill_slot_selector_container != null:
		skill_slot_selector_container.visible = _is_skill_mode()
	if not is_instance_valid(skill_slot_grid):
		return
	for child: Node in skill_slot_grid.get_children():
		skill_slot_grid.remove_child(child)
		child.queue_free()
	if not _is_skill_mode():
		return
	for slot_id: StringName in CombatAnimationStationStateScript.get_authoring_skill_slot_ids():
		skill_slot_grid.add_child(_build_skill_slot_selector_button(slot_id))

func _build_skill_slot_selector_button(slot_id: StringName) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(132.0, 148.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.button_pressed = _get_active_skill_slot_id() == slot_id
	var draft: Resource = _find_skill_draft_by_slot_id(slot_id)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_CARD_ACTIVE if button.button_pressed else (
		COLOR_SLOT_CARD_READY if draft != null else COLOR_SLOT_CARD
	)
	style.border_color = COLOR_BORDER_ACCENT if button.button_pressed else COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = hover_style.bg_color.lightened(0.08)
	hover_style.border_color = COLOR_BORDER_ACCENT
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	var card_vbox := VBoxContainer.new()
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 6)
	button.add_child(card_vbox)
	var binding_label := Label.new()
	binding_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	binding_label.text = _get_skill_slot_binding_label(slot_id)
	binding_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	binding_label.add_theme_font_size_override("font_size", FONT_HINT)
	binding_label.add_theme_color_override("font_color", COLOR_TEXT_HEADER)
	card_vbox.add_child(binding_label)
	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(0.0, 60.0)
	icon_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_frame.add_theme_stylebox_override("panel", _make_panel_style(COLOR_SLOT_ICON_PLACEHOLDER, COLOR_BORDER, 1, 3))
	card_vbox.add_child(icon_frame)
	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_frame.add_child(icon_center)
	var icon_texture := TextureRect.new()
	icon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_texture.custom_minimum_size = Vector2(40.0, 40.0)
	icon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_texture.texture = draft.get("skill_icon") as Texture2D if draft != null else null
	icon_center.add_child(icon_texture)
	if icon_texture.texture == null:
		var placeholder_label := Label.new()
		placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder_label.text = "ICON"
		placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder_label.add_theme_font_size_override("font_size", FONT_HINT)
		placeholder_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		icon_center.add_child(placeholder_label)
	var title_label_local := Label.new()
	title_label_local.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label_local.text = _get_skill_slot_card_title(slot_id, draft)
	title_label_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label_local.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label_local.custom_minimum_size = Vector2(0.0, 32.0)
	title_label_local.add_theme_font_size_override("font_size", FONT_BODY)
	title_label_local.add_theme_color_override("font_color", COLOR_TEXT)
	card_vbox.add_child(title_label_local)
	var subtitle_label_local := Label.new()
	subtitle_label_local.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label_local.text = _get_skill_slot_display_name(slot_id)
	subtitle_label_local.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label_local.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label_local.custom_minimum_size = Vector2(0.0, 28.0)
	subtitle_label_local.add_theme_font_size_override("font_size", FONT_HINT)
	subtitle_label_local.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	card_vbox.add_child(subtitle_label_local)
	button.tooltip_text = "%s [%s]" % [_get_skill_slot_display_name(slot_id), _get_skill_slot_binding_label(slot_id)]
	button.pressed.connect(_on_skill_slot_selector_pressed.bind(slot_id))
	return button

func _get_skill_slot_card_title(slot_id: StringName, draft: Resource) -> String:
	if draft != null:
		var authored_name: String = String(draft.get("skill_name")).strip_edges()
		if not authored_name.is_empty():
			return authored_name
	return _get_skill_slot_display_name(slot_id)

func _refresh_motion_node_list() -> void:
	point_list.clear()
	var draft: Resource = _get_active_draft()
	if draft == null:
		return
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var selected_node_index: int = int(draft.get("selected_motion_node_index"))
	var continuity_node_index: int = int(draft.get("continuity_motion_node_index"))
	var visible_start_index: int = _get_user_visible_motion_node_start_index(draft)
	var node_timestamps: Array[float] = []
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		node_timestamps = typed_draft.get_motion_node_timestamps()
	var display_index: int = 1
	for node_index: int in range(visible_start_index, motion_node_chain.size()):
		var motion_node: CombatAnimationMotionNode = motion_node_chain[node_index] as CombatAnimationMotionNode
		if motion_node == null:
			continue
		var continuity_marker: String = " | continuity" if node_index == continuity_node_index else ""
		var generated_marker: String = ""
		if bool(motion_node.generated_transition_node):
			generated_marker = " | generated %s" % GENERATED_TRANSITION_LABELS.get(
				motion_node.generated_transition_kind,
				"transition"
			)
		var timestamp_seconds: float = float(node_timestamps[node_index]) if node_index < node_timestamps.size() else 0.0
		var item_text: String = "N%02d | %.2fs | tip %s%s%s" % [
			display_index,
			snapped(timestamp_seconds, 0.01),
			_snapped_vector3_text(motion_node.tip_position_local, 0.001),
			continuity_marker,
			generated_marker,
		]
		point_list.add_item(item_text)
		var item_id: int = point_list.get_item_count() - 1
		point_list.set_item_metadata(item_id, node_index)
		if node_index == selected_node_index:
			point_list.select(item_id)
		display_index += 1

func _refresh_editor_fields() -> void:
	refreshing_controls = true
	_refresh_focus_indicators()
	var draft: Resource = _get_active_draft()
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	var has_draft: bool = draft != null
	var motion_node_available: bool = motion_node != null
	var motion_node_editable: bool = motion_node_available and not _is_motion_node_authoring_locked(motion_node)
	var motion_node_curve_editable: bool = motion_node_available and _can_author_motion_node_curve_handles(motion_node)
	var motion_node_grip_transition_editable: bool = (
		motion_node_available
		and _can_insert_grip_style_transition_from_motion_node(motion_node)
	)
	var idle_draft_locked: bool = _is_idle_draft(draft)
	var noncombat_idle_draft: bool = _is_noncombat_idle_draft(draft)
	var active_slot_id: StringName = _get_active_skill_slot_id()
	active_handle_coordinate_display_mode = (
		_resolve_active_handle_coordinate_display_mode()
	)
	var migrated_grip_node_count := (
		_migrate_active_station_grip_coordinates_if_needed(
			active_handle_coordinate_display_mode
		)
	)
	if migrated_grip_node_count > 0:
		_stage_active_wip_edit(
			"Migrated legacy Handle positions to normalized coordinates.",
			PERSIST_RUNTIME_CACHE_DIRTY_ALL
		)
	var handle_coordinate_display_minimum := (
		PrimaryGripSeatResolverScript.get_handle_coordinate_display_minimum(
			active_handle_coordinate_display_mode
		)
	)
	grip_seat_slide_spin_box.min_value = handle_coordinate_display_minimum
	grip_seat_slide_spin_box.max_value = 1.0
	secondary_grip_seat_slide_spin_box.min_value = (
		handle_coordinate_display_minimum
	)
	secondary_grip_seat_slide_spin_box.max_value = 1.0
	draft_name_edit.editable = has_draft
	draft_name_edit.text = String(draft.get("display_name")) if has_draft else ""
	skill_name_edit.editable = has_draft
	skill_name_edit.text = String(draft.get("skill_name")) if has_draft else ""
	skill_slot_edit.editable = false
	skill_slot_edit.text = String(active_slot_id if active_slot_id != StringName() else draft.get("legal_slot_id")) if has_draft else ""
	skill_description_edit.editable = has_draft
	skill_description_edit.text = String(draft.get("skill_description")) if has_draft else ""
	preview_speed_spin_box.editable = has_draft
	preview_speed_spin_box.value = float(draft.get("preview_playback_speed_scale")) if has_draft else 1.0
	speed_acceleration_spin_box.editable = has_draft
	speed_acceleration_spin_box.value = float(draft.get("speed_acceleration_percent")) if has_draft else CombatAnimationDraftScript.DEFAULT_SPEED_ACCELERATION_PERCENT
	speed_deceleration_spin_box.editable = has_draft
	speed_deceleration_spin_box.value = float(draft.get("speed_deceleration_percent")) if has_draft else CombatAnimationDraftScript.DEFAULT_SPEED_DECELERATION_PERCENT
	if stow_anchor_field_container != null:
		stow_anchor_field_container.visible = noncombat_idle_draft
	stow_anchor_option_button.disabled = not noncombat_idle_draft
	stow_contact_ratio_spin_box.editable = noncombat_idle_draft
	if noncombat_idle_draft:
		_select_option_by_metadata(
			stow_anchor_option_button,
			CombatAnimationDraftScript.normalize_stow_anchor_mode(StringName(draft.get("stow_anchor_mode")))
		)
		stow_contact_ratio_spin_box.set_value_no_signal(CombatAnimationDraftScript.normalize_stow_contact_ratio(float(draft.get("stow_contact_ratio"))))
	else:
		stow_contact_ratio_spin_box.set_value_no_signal(CombatAnimationDraftScript.DEFAULT_STOW_CONTACT_RATIO)
	preview_loop_check_box.disabled = not has_draft
	preview_loop_check_box.button_pressed = bool(draft.get("preview_loop_enabled")) if has_draft else false
	add_point_button.disabled = not has_draft or idle_draft_locked
	duplicate_point_button.disabled = not motion_node_available or idle_draft_locked
	remove_point_button.disabled = (
		idle_draft_locked
		or not has_draft
		or (has_draft and int((draft.get("motion_node_chain") as Array).size()) <= _get_minimum_motion_node_count(draft))
	)
	reset_draft_button.disabled = not has_draft
	_refresh_manual_save_controls(draft)
	position_x_spin_box.editable = motion_node_editable
	position_y_spin_box.editable = motion_node_editable
	position_z_spin_box.editable = motion_node_editable
	weapon_rotation_x_spin_box.editable = motion_node_editable
	weapon_rotation_y_spin_box.editable = motion_node_editable
	weapon_rotation_z_spin_box.editable = motion_node_editable
	transition_spin_box.editable = motion_node_editable and not idle_draft_locked and get_selected_motion_node_index() > 0
	body_support_spin_box.editable = motion_node_editable
	two_hand_state_option_button.disabled = not motion_node_editable
	primary_hand_option_button.disabled = (
		not motion_node_editable
		or idle_draft_locked
		or not _is_active_unarmed_authoring_wip()
	)
	grip_mode_option_button.disabled = not motion_node_grip_transition_editable
	curve_in_x_spin_box.editable = motion_node_curve_editable
	curve_in_y_spin_box.editable = motion_node_curve_editable
	curve_in_z_spin_box.editable = motion_node_curve_editable
	curve_out_x_spin_box.editable = motion_node_curve_editable
	curve_out_y_spin_box.editable = motion_node_curve_editable
	curve_out_z_spin_box.editable = motion_node_curve_editable
	pommel_x_spin_box.editable = motion_node_editable
	pommel_y_spin_box.editable = motion_node_editable
	pommel_z_spin_box.editable = motion_node_editable
	pommel_curve_in_x_spin_box.editable = motion_node_curve_editable
	pommel_curve_in_y_spin_box.editable = motion_node_curve_editable
	pommel_curve_in_z_spin_box.editable = motion_node_curve_editable
	pommel_curve_out_x_spin_box.editable = motion_node_curve_editable
	pommel_curve_out_y_spin_box.editable = motion_node_curve_editable
	pommel_curve_out_z_spin_box.editable = motion_node_curve_editable
	weapon_roll_spin_box.editable = motion_node_editable
	axial_reposition_spin_box.editable = motion_node_editable
	grip_seat_slide_spin_box.editable = motion_node_editable
	secondary_grip_seat_slide_spin_box.editable = motion_node_editable
	right_upperarm_roll_spin_box.editable = motion_node_editable
	left_upperarm_roll_spin_box.editable = motion_node_editable
	draft_notes_edit.editable = has_draft
	draft_notes_edit.text = String(draft.get("draft_notes")) if has_draft else ""
	if motion_node_available:
		position_x_spin_box.value = motion_node.tip_position_local.x
		position_y_spin_box.value = motion_node.tip_position_local.y
		position_z_spin_box.value = motion_node.tip_position_local.z
		weapon_rotation_x_spin_box.value = motion_node.weapon_orientation_degrees.x
		weapon_rotation_y_spin_box.value = motion_node.weapon_orientation_degrees.y
		weapon_rotation_z_spin_box.value = motion_node.weapon_orientation_degrees.z
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
		grip_seat_slide_spin_box.value = (
			PrimaryGripSeatResolverScript.handle_coordinate_to_display_value(
				motion_node.grip_seat_slide_offset,
				active_handle_coordinate_display_mode
			)
		)
		secondary_grip_seat_slide_spin_box.value = (
			PrimaryGripSeatResolverScript.handle_coordinate_to_display_value(
				motion_node.secondary_grip_seat_slide_offset,
				active_handle_coordinate_display_mode
			)
		)
		right_upperarm_roll_spin_box.value = motion_node.right_upperarm_roll_degrees
		left_upperarm_roll_spin_box.value = motion_node.left_upperarm_roll_degrees
		_select_option_by_metadata(two_hand_state_option_button, motion_node.two_hand_state)
		_select_option_by_metadata(
			primary_hand_option_button,
			motion_node.primary_hand_slot
			if _is_active_unarmed_authoring_wip()
			else _resolve_active_authoring_primary_slot_id()
		)
		_select_option_by_metadata(grip_mode_option_button, motion_node.preferred_grip_style_mode)
	else:
		position_x_spin_box.value = 0.0
		position_y_spin_box.value = 0.0
		position_z_spin_box.value = 0.0
		weapon_rotation_x_spin_box.value = 0.0
		weapon_rotation_y_spin_box.value = 0.0
		weapon_rotation_z_spin_box.value = 0.0
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
		secondary_grip_seat_slide_spin_box.value = 0.0
		right_upperarm_roll_spin_box.value = 0.0
		left_upperarm_roll_spin_box.value = 0.0
		_select_option_by_metadata(primary_hand_option_button, CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO)
	refreshing_controls = false

func _build_editor_guardrail_state(preview_debug_state: Dictionary = {}) -> Dictionary:
	var entries: Array[Dictionary] = []
	var draft: CombatAnimationDraft = _get_active_draft() as CombatAnimationDraft
	if draft != null:
		for validation_result: Dictionary in draft_validator.validate_draft(draft):
			_append_guardrail_entry(
				entries,
				StringName(validation_result.get("severity", GUARDRAIL_SEVERITY_WARNING)),
				StringName(validation_result.get("code", &"draft_validation")),
				String(validation_result.get("message", "")),
				int(validation_result.get("node_index", -1))
			)
	_append_collision_guardrails(entries, preview_debug_state)
	_append_reach_guardrails(entries, preview_debug_state.get("authoring_contact_tether_metrics", {}) as Dictionary)
	_append_stance_guardrails(entries, preview_debug_state)
	_append_retarget_guardrails(entries)
	var debug_views: Dictionary = _build_guardrail_debug_view_state(preview_debug_state)
	var error_count: int = _count_guardrail_entries_by_severity(entries, GUARDRAIL_SEVERITY_ERROR)
	var warning_count: int = _count_guardrail_entries_by_severity(entries, GUARDRAIL_SEVERITY_WARNING)
	var info_count: int = _count_guardrail_entries_by_severity(entries, GUARDRAIL_SEVERITY_INFO)
	return {
		"entries": entries,
		"entry_count": entries.size(),
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"blocking": error_count > 0,
		"debug_views": debug_views,
		"debug_view_ready_count": _count_ready_guardrail_debug_views(debug_views),
	}

func _append_collision_guardrails(entries: Array[Dictionary], preview_debug_state: Dictionary) -> void:
	if not bool(preview_debug_state.get("body_self_collision_legal", true)):
		var illegal_pair: Dictionary = preview_debug_state.get("body_self_collision_first_illegal_pair", {}) as Dictionary
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"body_self_collision",
			"Body self-collision between %s and %s." % [
				String(illegal_pair.get("first_region", "body")),
				String(illegal_pair.get("second_region", "body")),
			],
			int(preview_debug_state.get("selected_motion_node_index", -1)),
			{
				"first_attachment": String(illegal_pair.get("first_attachment_name", "")),
				"second_attachment": String(illegal_pair.get("second_attachment_name", "")),
				"clearance_meters": float(illegal_pair.get("clearance_meters", -1.0)),
				"illegal_pair_count": int(preview_debug_state.get("body_self_collision_illegal_pair_count", 0)),
			}
		)
	if not bool(preview_debug_state.get("collision_pose_legal", true)):
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"body_collision_pose",
			"Selected pose intersects body clearance near %s." % String(preview_debug_state.get("collision_pose_region", "body")),
			int(preview_debug_state.get("selected_motion_node_index", -1)),
			{
				"region": String(preview_debug_state.get("collision_pose_region", "")),
				"sample": String(preview_debug_state.get("collision_pose_sample", "")),
				"clearance_meters": float(preview_debug_state.get("collision_pose_clearance_meters", -1.0)),
			}
		)
	if int(preview_debug_state.get("collision_path_sample_count", 0)) > 0 and not bool(preview_debug_state.get("collision_path_legal", true)):
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"body_collision_path",
			"Trajectory path intersects body clearance near %s." % String(preview_debug_state.get("collision_path_region", "body")),
			int(preview_debug_state.get("collision_path_first_illegal_index", -1)),
			{
				"region": String(preview_debug_state.get("collision_path_region", "")),
				"illegal_pose_count": int(preview_debug_state.get("collision_path_illegal_pose_count", 0)),
				"sample_count": int(preview_debug_state.get("collision_path_sample_count", 0)),
			}
		)

func _append_reach_guardrails(entries: Array[Dictionary], tether_metrics: Dictionary) -> void:
	if tether_metrics.is_empty():
		return
	var dominant_excess: float = _resolve_reach_excess_meters(tether_metrics, "dominant")
	var support_excess: float = _resolve_reach_excess_meters(tether_metrics, "support")
	var max_excess: float = maxf(dominant_excess, support_excess)
	if bool(tether_metrics.get("clamped", false)) or max_excess > 0.001:
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"overreach_clamped",
			"Contact reach exceeded the legal arm volume and was clamped.",
			get_selected_motion_node_index(),
			{
				"dominant_excess_meters": dominant_excess,
				"support_excess_meters": support_excess,
				"translation_delta_meters": float(tether_metrics.get("translation_delta_meters", 0.0)),
				"pivot_delta_meters": float(tether_metrics.get("pivot_delta_meters", 0.0)),
			}
		)

func _append_stance_guardrails(entries: Array[Dictionary], preview_debug_state: Dictionary) -> void:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return
	var selected_index: int = get_selected_motion_node_index()
	var wants_two_hand: bool = motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
	if wants_two_hand and motion_node.preferred_grip_style_mode == CraftedItemWIPScript.GRIP_REVERSE:
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"reverse_grip_two_hand_unsupported",
			"Reverse grip suppresses two-hand support for this weapon state.",
			selected_index
		)
	if wants_two_hand and int(preview_debug_state.get("secondary_grip_debug_count", 0)) <= 0:
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"two_hand_support_contact_missing",
			"Two-hand stance has no visible support contact guide.",
			selected_index
		)

func _append_retarget_guardrails(entries: Array[Dictionary]) -> void:
	var distortion_state: Dictionary = _resolve_active_retarget_distortion_state()
	if bool(distortion_state.get("severe", false)):
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_WARNING,
			&"severe_retarget_distortion",
			"Weapon shape changed enough that retargeted motion may need review.",
			int(distortion_state.get("node_index", -1)),
			distortion_state
		)
	elif int(last_station_retarget_result.get("retargeted_count", 0)) > 0:
		_append_guardrail_entry(
			entries,
			GUARDRAIL_SEVERITY_INFO,
			&"retarget_preview_applied",
			"Motion preview retargeted to the current weapon geometry.",
			-1,
			last_station_retarget_result.duplicate(true)
		)

func _append_guardrail_entry(
	entries: Array[Dictionary],
	severity: StringName,
	code: StringName,
	message: String,
	node_index: int = -1,
	details: Dictionary = {}
) -> void:
	entries.append({
		"severity": severity,
		"code": code,
		"message": message,
		"node_index": node_index,
		"details": details.duplicate(true),
	})

func _resolve_reach_excess_meters(tether_metrics: Dictionary, prefix: String) -> float:
	var before_meters: float = float(tether_metrics.get("%s_reach_before_meters" % prefix, -1.0))
	var limit_meters: float = float(tether_metrics.get("%s_reach_limit_meters" % prefix, -1.0))
	if before_meters < 0.0 or limit_meters <= 0.0:
		return 0.0
	return maxf(before_meters - limit_meters, 0.0)

func _resolve_active_retarget_distortion_state() -> Dictionary:
	var state: Dictionary = {
		"severe": false,
		"max_shape_ratio": 1.0,
		"current_weapon_length_meters": _get_active_weapon_total_length(),
		"source_weapon_length_meters": 0.0,
		"node_index": -1,
	}
	var current_length: float = float(state.get("current_weapon_length_meters", 0.0))
	if current_length <= 0.001:
		return state
	var draft: Resource = _get_active_draft()
	if draft == null:
		return state
	var chain: Array = draft.get("motion_node_chain") as Array
	for node_index: int in range(chain.size()):
		var motion_node: CombatAnimationMotionNode = chain[node_index] as CombatAnimationMotionNode
		if motion_node == null or motion_node.retarget_node == null:
			continue
		var source_length: float = float(motion_node.retarget_node.get("source_weapon_length_meters"))
		if source_length <= 0.001:
			continue
		var direct_ratio: float = current_length / source_length
		var shape_ratio: float = maxf(direct_ratio, 1.0 / maxf(direct_ratio, 0.0001))
		if shape_ratio > float(state.get("max_shape_ratio", 1.0)):
			state["max_shape_ratio"] = shape_ratio
			state["source_weapon_length_meters"] = source_length
			state["node_index"] = node_index
		if direct_ratio >= GUARDRAIL_SEVERE_RETARGET_RATIO_HIGH or direct_ratio <= GUARDRAIL_SEVERE_RETARGET_RATIO_LOW:
			state["severe"] = true
	return state

func _build_guardrail_debug_view_state(preview_debug_state: Dictionary) -> Dictionary:
	var tether_metrics: Dictionary = preview_debug_state.get("authoring_contact_tether_metrics", {}) as Dictionary
	return {
		"body_clearance_proxy_visible": int(preview_debug_state.get("body_restriction_debug_mesh_count", 0)) > 0,
		"weapon_clearance_proxy_visible": int(preview_debug_state.get("weapon_proxy_debug_count", 0)) > 0,
		"max_reach_boundary_available": (
			float(tether_metrics.get("dominant_reach_limit_meters", -1.0)) > 0.0
			or float(tether_metrics.get("support_reach_limit_meters", -1.0)) > 0.0
		),
		"min_clearance_boundary_available": int(preview_debug_state.get("collision_path_sample_count", 0)) > 0,
		"anatomical_self_collision_available": int(preview_debug_state.get("body_self_collision_checked_pair_count", 0)) > 0,
		"joint_range_plane_available": int(preview_debug_state.get("digit_range_debug_visual_count", 0)) == 30,
		"normalized_pivot_path_available": _active_draft_has_retarget_nodes(),
		"speed_state_coloring_available": int(preview_debug_state.get("speed_state_sample_count", 0)) > 0,
	}

func _active_draft_has_retarget_nodes() -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var chain: Array = draft.get("motion_node_chain") as Array
	for node_variant: Variant in chain:
		var motion_node: CombatAnimationMotionNode = node_variant as CombatAnimationMotionNode
		if motion_node != null and motion_node.retarget_node != null:
			return true
	return false

func _count_guardrail_entries_by_severity(entries: Array[Dictionary], severity: StringName) -> int:
	var count: int = 0
	for entry: Dictionary in entries:
		if entry.get("severity", StringName()) == severity:
			count += 1
	return count

func _count_ready_guardrail_debug_views(debug_views: Dictionary) -> int:
	var ready_count: int = 0
	for key: Variant in debug_views.keys():
		if bool(debug_views.get(key, false)):
			ready_count += 1
	return ready_count

func _guardrail_flag_text(enabled: bool) -> String:
	return "on" if enabled else "off"

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
		lines.append("Open Baseline: %s" % _get_active_weapon_open_summary_label())
		lines.append("Authoring Mode: %s" % AUTHORING_MODE_LABELS.get(station_state.get("selected_authoring_mode"), "Unknown"))
		if draft != null:
			lines.append("Draft: %s" % String(draft.get("display_name")))
			lines.append("Draft Identifier: %s" % String(_get_draft_identifier(draft)))
			lines.append("Motion Node Count: %d" % _get_user_visible_motion_node_count(draft))
			var validation_results: Array[Dictionary] = draft_validator.validate_draft(draft as CombatAnimationDraft)
			var error_count: int = draft_validator.get_error_count(validation_results)
			if error_count > 0:
				lines.append("Validation: %d error(s)" % error_count)
			elif validation_results.size() > 0:
				lines.append("Validation: %d warning(s)" % validation_results.size())
			else:
				lines.append("Validation: OK")
			lines.append("Preview Loop: %s" % str(bool(draft.get("preview_loop_enabled"))))
			lines.append("Speed Tuning: accel %d%% / decel %d%%" % [
				int(round(float(draft.get("speed_acceleration_percent")))),
				int(round(float(draft.get("speed_deceleration_percent")))),
			])
			if _is_noncombat_idle_draft(draft):
				var stow_mode: StringName = CombatAnimationDraftScript.normalize_stow_anchor_mode(StringName(draft.get("stow_anchor_mode")))
				lines.append("Stow Anchor: %s" % STOW_ANCHOR_LABELS.get(stow_mode, String(stow_mode)))
			if _is_skill_mode():
				var slot_id: StringName = _get_active_skill_slot_id()
				if slot_id != StringName():
					lines.append("Skill Slot: %s [%s]" % [
						_get_skill_slot_display_name(slot_id),
						_get_skill_slot_binding_label(slot_id),
					])
				else:
					lines.append("Skill Slot: Unassigned")
		if motion_node != null:
			lines.append("Selected Node: %s" % _get_selected_user_visible_motion_node_label(draft, motion_node))
			if bool(motion_node.generated_transition_node):
				lines.append("Generated Transition: %s (locked, deletable)" % GENERATED_TRANSITION_LABELS.get(
					motion_node.generated_transition_kind,
					"transition"
				))
			lines.append("Tip Position: %s" % _snapped_vector3_text(motion_node.tip_position_local, 0.001))
			lines.append("Weapon Orientation: %s" % _snapped_vector3_text(motion_node.weapon_orientation_degrees, 0.01))
			lines.append("Two-Hand State: %s" % TWO_HAND_STATE_LABELS.get(motion_node.two_hand_state, String(motion_node.two_hand_state)))
			lines.append("Primary Hand: %s" % PRIMARY_HAND_LABELS.get(motion_node.primary_hand_slot, String(motion_node.primary_hand_slot)))
			lines.append("Handle Position P/S: %s / %s" % [
				str(snapped(
					PrimaryGripSeatResolverScript.handle_coordinate_to_display_value(
						motion_node.grip_seat_slide_offset,
						active_handle_coordinate_display_mode
					),
					0.01
				)),
				str(snapped(
					PrimaryGripSeatResolverScript.handle_coordinate_to_display_value(
						motion_node.secondary_grip_seat_slide_offset,
						active_handle_coordinate_display_mode
					),
					0.01
				)),
			])
			lines.append("Body Support Blend: %s" % str(snapped(motion_node.body_support_blend, 0.01)))
			lines.append("Weapon Roll: %s deg" % str(snapped(motion_node.weapon_roll_degrees, 0.1)))
			lines.append("Upper Arm Roll R/L: %s / %s deg" % [
				str(snapped(motion_node.right_upperarm_roll_degrees, 0.1)),
				str(snapped(motion_node.left_upperarm_roll_degrees, 0.1)),
			])
		lines.append("Station Truth: Stage 1 = %s | Stage 2 = %s" % [
			str(bool(station_state.get("uses_stage1_geometry_truth"))),
			str(bool(station_state.get("uses_stage2_geometry_truth"))),
		])
		if workflow_step == WORKFLOW_STEP_EDITOR:
			var preview_debug_state: Dictionary = get_preview_debug_state()
			if int(preview_debug_state.get("speed_state_sample_count", 0)) > 0:
				lines.append("Speed Samples: %d total | armed %d | reset %d" % [
					int(preview_debug_state.get("speed_state_sample_count", 0)),
					int(preview_debug_state.get("speed_state_armed_sample_count", 0)),
					int(preview_debug_state.get("speed_state_reset_sample_count", 0)),
				])
			if int(preview_debug_state.get("collision_path_sample_count", 0)) > 0:
				var pose_legal_text: String = "legal" if bool(preview_debug_state.get("collision_pose_legal", true)) else "blocked"
				var path_legal_text: String = "legal" if bool(preview_debug_state.get("collision_path_legal", true)) else "blocked"
				lines.append("Collision: pose %s | path %s" % [pose_legal_text, path_legal_text])
				if not bool(preview_debug_state.get("collision_pose_legal", true)):
					lines.append("Collision Region: %s" % String(preview_debug_state.get("collision_pose_region", "")))
			if int(preview_debug_state.get("body_self_collision_checked_pair_count", 0)) > 0:
				var self_collision_text: String = "legal" if bool(preview_debug_state.get("body_self_collision_legal", true)) else "blocked"
				lines.append("Body Self: %s | allowed overlaps %d | illegal %d" % [
					self_collision_text,
					int(preview_debug_state.get("body_self_collision_allowed_overlap_pair_count", 0)),
					int(preview_debug_state.get("body_self_collision_illegal_pair_count", 0)),
				])
			var guardrail_state: Dictionary = preview_debug_state.get("editor_guardrail_state", {}) as Dictionary
			if not guardrail_state.is_empty():
				var guardrail_error_count: int = int(guardrail_state.get("error_count", 0))
				var guardrail_warning_count: int = int(guardrail_state.get("warning_count", 0))
				var guardrail_info_count: int = int(guardrail_state.get("info_count", 0))
				if guardrail_error_count > 0 or guardrail_warning_count > 0:
					lines.append("Guardrails: %d error(s) / %d warning(s)" % [guardrail_error_count, guardrail_warning_count])
				else:
					lines.append("Guardrails: OK (%d info)" % guardrail_info_count)
				var guardrail_entries: Array = guardrail_state.get("entries", []) as Array
				var appended_guardrail_count: int = 0
				for entry_variant: Variant in guardrail_entries:
					if appended_guardrail_count >= 3:
						break
					var entry: Dictionary = entry_variant as Dictionary
					if entry.is_empty():
						continue
					var severity: StringName = StringName(entry.get("severity", StringName()))
					if severity == GUARDRAIL_SEVERITY_INFO and (guardrail_error_count > 0 or guardrail_warning_count > 0):
						continue
					lines.append("Guardrail: %s" % String(entry.get("message", "")))
					appended_guardrail_count += 1
				var debug_views: Dictionary = guardrail_state.get("debug_views", {}) as Dictionary
				if not debug_views.is_empty():
					lines.append("Debug Views: body %s | weapon %s | joint %s | reach %s | clearance %s | pivot %s" % [
						_guardrail_flag_text(bool(debug_views.get("body_clearance_proxy_visible", false))),
						_guardrail_flag_text(bool(debug_views.get("weapon_clearance_proxy_visible", false))),
						_guardrail_flag_text(bool(debug_views.get("joint_range_plane_available", false))),
						_guardrail_flag_text(bool(debug_views.get("max_reach_boundary_available", false))),
						_guardrail_flag_text(bool(debug_views.get("min_clearance_boundary_available", false))),
						_guardrail_flag_text(bool(debug_views.get("normalized_pivot_path_available", false))),
					])
			_append_contact_ray_summary_lines(
				lines,
				"Dominant",
				preview_debug_state.get("dominant_finger_contact_ray_debug", []) as Array
			)
			_append_contact_ray_summary_lines(
				lines,
				"Support",
				preview_debug_state.get("support_finger_contact_ray_debug", []) as Array
			)
	if not status_message.strip_edges().is_empty():
		footer_status_label.text = status_message
	summary_label.text = "\n".join(lines)

func _refresh_preview_scene(
	grip_resolve_reason: StringName = StringName()
) -> void:
	_ensure_current_focus_available()
	var baked_profile: BakedProfile = _get_active_baked_profile()
	var playback_state: Dictionary = _build_preview_playback_state()
	if grip_resolve_reason != StringName():
		# This cause belongs to this synchronous refresh only. It must never survive
		# into a later debug, endpoint, focus, or unrelated authoring refresh.
		playback_state["grip_resolve_reason"] = grip_resolve_reason
	if motion_node_editor.is_dragging() and preview_drag_override_node != null:
		playback_state["authoring_drag_active"] = true
		playback_state["authoring_drag_lightweight"] = false
		playback_state["authoring_drag_budgeted_visuals"] = true
		playback_state["authoring_drag_target"] = motion_node_editor.get_drag_target()
		var drag_chain_cache: Dictionary = _ensure_preview_drag_motion_chain_cache()
		if not drag_chain_cache.is_empty():
			playback_state["authoring_drag_effective_motion_node_chain"] = drag_chain_cache.get("effective_motion_node_chain", [])
			playback_state["authoring_drag_visible_motion_node_chain"] = drag_chain_cache.get("visible_motion_node_chain", [])
			playback_state["authoring_drag_visible_selected_node_index"] = int(drag_chain_cache.get("visible_selected_node_index", -1))
		if _can_reuse_pommel_drag_authority_commit():
			playback_state["authoring_drag_endpoint_authority_prevalidated"] = true
			playback_state["authoring_drag_endpoint_validation_result"] = preview_drag_pommel_last_validation_result
	preview_presenter.configure_preview_hand_setup(_resolve_active_motion_node_primary_slot_id(), active_preview_default_two_hand)
	preview_presenter.refresh_preview(
		preview_view_container,
		preview_subviewport,
		active_wip,
		_get_active_draft(),
		get_selected_motion_node_index(),
		session_state.current_focus,
		baked_profile,
		playback_state,
		preview_drag_override_node
	)

func _refresh_preview_focus_visuals() -> void:
	_ensure_current_focus_available()
	preview_presenter.refresh_selection_visuals(
		preview_view_container,
		preview_subviewport,
		_get_active_draft(),
		get_selected_motion_node_index(),
		session_state.current_focus
	)

func _queue_preview_drag_refresh() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if not preview_drag_refresh_pending:
		preview_drag_first_pending_msec = now_msec
	preview_drag_refresh_pending = true

func _get_preview_drag_refresh_interval_msec() -> int:
	if preview_drag_last_refresh_cost_msec <= 0:
		return PREVIEW_DRAG_MIN_REFRESH_INTERVAL_MSEC
	var cost_weighted_interval: int = int(round(float(preview_drag_last_refresh_cost_msec) * PREVIEW_DRAG_REFRESH_COST_COOLDOWN_RATIO))
	return clampi(
		cost_weighted_interval,
		PREVIEW_DRAG_MIN_REFRESH_INTERVAL_MSEC,
		PREVIEW_DRAG_MAX_REFRESH_INTERVAL_MSEC
	)

func _is_pommel_drag_authority_active() -> bool:
	return (
		preview_drag_override_node != null
		and (
			motion_node_editor.get_drag_target() == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL
			or preview_drag_pommel_authority_pending
			or preview_drag_pommel_has_solved_request
		)
	)

func _queue_pommel_drag_authority_target(
	requested_pommel_position_local: Vector3,
	requested_pommel_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
) -> void:
	if preview_drag_override_node == null:
		return
	var resolved_requested_origin_id: StringName = _normalize_seed_origin_id(
		requested_pommel_position_origin_id,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var target_changed: bool = (
		not preview_drag_pommel_authority_pending
		or preview_drag_pommel_requested_origin_id != resolved_requested_origin_id
		or preview_drag_pommel_requested_local.distance_to(requested_pommel_position_local) > PREVIEW_DRAG_POMMEL_TARGET_EPSILON_METERS
	)
	var authored_delta: float = preview_drag_override_node.pommel_position_local.distance_to(requested_pommel_position_local)
	if not target_changed and authored_delta <= PREVIEW_DRAG_POMMEL_TARGET_EPSILON_METERS:
		return
	preview_drag_pommel_requested_local = requested_pommel_position_local
	preview_drag_pommel_requested_origin_id = resolved_requested_origin_id
	preview_drag_pommel_authority_pending = true
	preview_drag_has_moved = true
	_queue_preview_drag_refresh()

func _resolve_pending_pommel_drag_authority(force: bool = false) -> Dictionary:
	if not _is_pommel_drag_authority_active():
		return {
			"solved": false,
			"legal": true,
			"reason": "inactive",
		}
	if not preview_drag_pommel_authority_pending:
		return {
			"solved": false,
			"legal": preview_drag_pommel_last_solve_legal,
			"reason": "no_pending_target",
		}
	var requested_pommel_position_local: Vector3 = preview_drag_pommel_requested_local
	var requested_pommel_position_origin_id: StringName = preview_drag_pommel_requested_origin_id
	if (
		preview_drag_pommel_has_solved_request
		and preview_drag_pommel_last_solved_request_origin_id == requested_pommel_position_origin_id
		and preview_drag_pommel_last_solved_request_local.distance_to(requested_pommel_position_local) <= PREVIEW_DRAG_POMMEL_TARGET_EPSILON_METERS
	):
		preview_drag_pommel_authority_pending = false
		return {
			"solved": false,
			"legal": preview_drag_pommel_last_solve_legal,
			"reason": "target_unchanged",
		}
	if not force and preview_drag_last_refresh_msec > 0:
		var now_msec: int = Time.get_ticks_msec()
		if now_msec - preview_drag_last_refresh_msec < _get_preview_drag_refresh_interval_msec():
			return {
				"solved": false,
				"legal": preview_drag_pommel_last_solve_legal,
				"reason": "budget_wait",
			}
	var requested_segment: Dictionary = _resolve_motion_node_segment_for_pommel_target(
		preview_drag_override_node,
		requested_pommel_position_local,
		false,
		requested_pommel_position_origin_id
	)
	if requested_segment.is_empty():
		return {
			"solved": false,
			"legal": false,
			"reason": "empty_requested_segment",
		}
	var constrained_segment: Dictionary = _apply_contact_tether_to_segment(
		preview_drag_override_node,
		requested_segment,
		&"translate"
	)
	preview_drag_pommel_authority_pending = false
	preview_drag_pommel_has_solved_request = true
	preview_drag_pommel_last_solved_request_local = requested_pommel_position_local
	preview_drag_pommel_last_solved_request_origin_id = requested_pommel_position_origin_id
	preview_drag_pommel_last_validation_result = constrained_segment.duplicate(true)
	preview_drag_pommel_last_solve_legal = bool(constrained_segment.get("legal", true))
	if not preview_drag_pommel_last_solve_legal:
		_set_preview_drag_blocked_status(constrained_segment)
		return {
			"solved": true,
			"legal": false,
			"changed": false,
			"validation_result": constrained_segment,
		}
	var changed: bool = _apply_resolved_segment_to_motion_node(preview_drag_override_node, constrained_segment)
	if changed:
		preview_drag_has_moved = true
		preview_drag_override_node.normalize()
	return {
		"solved": true,
		"legal": true,
		"changed": changed,
		"validation_result": constrained_segment,
	}

func _can_reuse_pommel_drag_authority_commit() -> bool:
	return (
		preview_drag_pommel_has_solved_request
		and not preview_drag_pommel_authority_pending
		and preview_drag_pommel_last_solve_legal
	)

func _flush_pending_preview_drag_refresh() -> void:
	if not preview_drag_refresh_pending:
		return
	if not motion_node_editor.is_dragging():
		preview_drag_refresh_pending = false
		preview_drag_first_pending_msec = 0
		return
	var now_msec: int = Time.get_ticks_msec()
	if (
		preview_drag_last_refresh_msec <= 0
		and preview_drag_first_pending_msec > 0
		and now_msec - preview_drag_first_pending_msec < PREVIEW_DRAG_INITIAL_SOLVE_DELAY_MSEC
	):
		return
	if preview_drag_last_refresh_msec > 0 and now_msec - preview_drag_last_refresh_msec < _get_preview_drag_refresh_interval_msec():
		return
	var refresh_start_msec: int = Time.get_ticks_msec()
	if _is_pommel_drag_authority_active():
		_resolve_pending_pommel_drag_authority()
	preview_drag_refresh_pending = false
	preview_drag_first_pending_msec = 0
	_refresh_preview_scene()
	preview_drag_last_refresh_msec = Time.get_ticks_msec()
	preview_drag_last_refresh_cost_msec = maxi(preview_drag_last_refresh_msec - refresh_start_msec, 0)

func _sync_preview_pose_only() -> void:
	_ensure_current_focus_available()
	preview_presenter.configure_preview_hand_setup(_resolve_active_motion_node_primary_slot_id(), active_preview_default_two_hand)
	preview_presenter.sync_preview_pose(
		preview_view_container,
		preview_subviewport,
		active_wip,
		_get_active_draft(),
		get_selected_motion_node_index(),
		_build_preview_playback_state(),
		preview_drag_override_node,
		session_state.current_focus,
		_get_active_baked_profile()
	)

func _sync_preview_playback_pose_only() -> void:
	preview_presenter.configure_preview_hand_setup(_resolve_active_motion_node_primary_slot_id(), active_preview_default_two_hand)
	preview_presenter.sync_playback_pose(
		preview_view_container,
		preview_subviewport,
		active_wip,
		_get_active_draft(),
		get_selected_motion_node_index(),
		_build_preview_playback_state(),
		preview_drag_override_node
	)

func _get_active_baked_profile() -> BakedProfile:
	if active_wip == null:
		return null
	return preview_presenter.ensure_baked_profile_snapshot(active_wip)


func _resolve_active_handle_coordinate_display_mode() -> StringName:
	return PrimaryGripSeatResolverScript.resolve_profile_handle_coordinate_mode(
		_get_active_baked_profile()
	)


func _migrate_active_station_grip_coordinates_if_needed(
	coordinate_mode: StringName
) -> int:
	var station_state: Resource = _get_active_station_state()
	if (
		station_state == null
		or not station_state.has_method("migrate_legacy_grip_coordinates")
	):
		return 0
	return int(station_state.call(
		"migrate_legacy_grip_coordinates",
		coordinate_mode
	))


func _normalize_seed_origin_id(origin_id: StringName, fallback_origin_id: StringName) -> StringName:
	if origin_id != StringName():
		return origin_id
	if fallback_origin_id != StringName():
		return fallback_origin_id
	return CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT

func _resolve_seed_origin_id(seed_data: Dictionary, origin_key: String, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = _normalize_seed_origin_id(
		StringName(seed_data.get(origin_key, StringName())),
		fallback_origin_id
	)
	seed_data[origin_key] = resolved_origin_id
	return resolved_origin_id

func _ensure_motion_seed_position_origins(seed_data: Dictionary, fallback_origin_id: StringName) -> void:
	if seed_data.is_empty():
		return
	_resolve_seed_origin_id(seed_data, "tip_position_origin_id", fallback_origin_id)
	_resolve_seed_origin_id(seed_data, "pommel_position_origin_id", fallback_origin_id)

func _get_origin_tracked_seed_vector3(
	seed_data: Dictionary,
	value_key: String,
	origin_key: String,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_seed_origin_id(seed_data, origin_key, fallback_origin_id)
	var stored_value: Variant = seed_data.get(value_key, fallback_value)
	if stored_value is Vector3:
		return stored_value as Vector3
	return fallback_value

func _resolve_origin_meta_value(target: Object, origin_meta_name: StringName, fallback_origin_id: StringName) -> StringName:
	var resolved_origin_id: StringName = _normalize_seed_origin_id(StringName(), fallback_origin_id)
	if target == null:
		return resolved_origin_id
	var stored_origin_id: StringName = StringName(target.get_meta(origin_meta_name, StringName()))
	if stored_origin_id != StringName():
		return stored_origin_id
	target.set_meta(origin_meta_name, resolved_origin_id)
	return resolved_origin_id

func _get_origin_tracked_vector3_meta(
	target: Object,
	value_meta_name: StringName,
	origin_meta_name: StringName,
	fallback_value: Vector3,
	fallback_origin_id: StringName
) -> Vector3:
	_resolve_origin_meta_value(target, origin_meta_name, fallback_origin_id)
	if target == null or not target.has_meta(value_meta_name):
		return fallback_value
	var stored_value: Variant = target.get_meta(value_meta_name)
	if stored_value is Vector3:
		return stored_value as Vector3
	return fallback_value

func _resolve_active_weapon_motion_seed(
	use_cached_baseline_seed: bool = false,
	preferred_grip_style_override: StringName = StringName()
) -> Dictionary:
	if _is_active_unarmed_authoring_wip():
		return _resolve_active_unarmed_motion_seed(use_cached_baseline_seed, preferred_grip_style_override)
	var baked_profile: BakedProfile = _get_active_baked_profile()
	if baked_profile == null:
		return {}
	var geometry_seed: Dictionary = _resolve_active_weapon_geometry_seed_base(baked_profile)
	if geometry_seed.is_empty():
		return {}
	_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	if preferred_grip_style_override != StringName():
		geometry_seed["preferred_grip_style_mode"] = CraftedItemWIPScript.resolve_supported_grip_style(
			preferred_grip_style_override,
			active_wip.forge_intent if active_wip != null else StringName(),
			active_wip.equipment_context if active_wip != null else StringName()
		)
	var seed_signature: String = _build_active_weapon_baseline_seed_signature(geometry_seed)
	if (
		use_cached_baseline_seed
		and not cached_active_weapon_baseline_seed.is_empty()
		and cached_active_weapon_baseline_seed_signature == seed_signature
		and _is_hand_mounted_motion_seed_resolved(cached_active_weapon_baseline_seed)
	):
		return cached_active_weapon_baseline_seed.duplicate(true)
	var resolved_seed: Dictionary = preview_presenter.resolve_preview_hand_mounted_motion_seed(
		preview_subviewport,
		geometry_seed,
		active_wip.wip_id if active_wip != null else StringName()
	)
	_ensure_motion_seed_position_origins(resolved_seed, CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
	if use_cached_baseline_seed and _is_hand_mounted_motion_seed_resolved(resolved_seed):
		cached_active_weapon_baseline_seed = resolved_seed.duplicate(true)
		cached_active_weapon_baseline_seed_signature = seed_signature
	return resolved_seed

func _resolve_active_unarmed_motion_seed(
	use_cached_baseline_seed: bool = false,
	_preferred_grip_style_override: StringName = StringName()
) -> Dictionary:
	var geometry_seed: Dictionary = _resolve_active_unarmed_geometry_seed_base()
	if geometry_seed.is_empty():
		return {}
	_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	var seed_signature: String = _build_active_weapon_baseline_seed_signature(geometry_seed)
	if (
		use_cached_baseline_seed
		and not cached_active_weapon_baseline_seed.is_empty()
		and cached_active_weapon_baseline_seed_signature == seed_signature
		and _is_hand_mounted_motion_seed_resolved(cached_active_weapon_baseline_seed)
	):
		return cached_active_weapon_baseline_seed.duplicate(true)
	var resolved_seed: Dictionary = preview_presenter.resolve_preview_hand_mounted_motion_seed(
		preview_subviewport,
		geometry_seed,
		active_wip.wip_id if active_wip != null else StringName()
	)
	if resolved_seed.is_empty():
		resolved_seed = geometry_seed.duplicate(true)
	_ensure_motion_seed_position_origins(resolved_seed, CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
	var seeded_tip: Vector3 = _get_origin_tracked_seed_vector3(
		resolved_seed,
		"tip_position_local",
		"tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var seeded_pommel: Vector3 = _get_origin_tracked_seed_vector3(
		resolved_seed,
		"pommel_position_local",
		"pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	resolved_seed["weapon_total_length_meters"] = maxf(seeded_tip.distance_to(seeded_pommel), 0.001)
	if use_cached_baseline_seed and _is_hand_mounted_motion_seed_resolved(resolved_seed):
		cached_active_weapon_baseline_seed = resolved_seed.duplicate(true)
		cached_active_weapon_baseline_seed_signature = seed_signature
	return resolved_seed

func _resolve_active_weapon_authored_baseline_seed(
	use_cached_baseline_seed: bool = true,
	preferred_grip_style_override: StringName = StringName()
) -> Dictionary:
	return _resolve_active_weapon_motion_seed(use_cached_baseline_seed, preferred_grip_style_override)

func _build_active_weapon_baseline_seed_signature(geometry_seed: Dictionary) -> String:
	return "|".join(PackedStringArray([
		String(active_wip.wip_id) if active_wip != null else "",
		String(_resolve_active_motion_node_primary_slot_id()),
		str(active_preview_default_two_hand),
		str(geometry_seed),
	]))

func _clear_active_weapon_baseline_seed_cache() -> void:
	cached_active_weapon_baseline_seed.clear()
	cached_active_weapon_baseline_seed_signature = ""

func _is_hand_mounted_motion_seed_resolved(seed_data: Dictionary) -> bool:
	return bool(seed_data.get("hand_mount_seed_resolved", false))

func _motion_seed_matches_base_geometry_seed(motion_seed: Dictionary, geometry_seed: Dictionary) -> bool:
	if motion_seed.is_empty() or geometry_seed.is_empty():
		return false
	_ensure_motion_seed_position_origins(motion_seed, CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
	_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	return (
		_get_origin_tracked_seed_vector3(
			motion_seed,
			"tip_position_local",
			"tip_position_origin_id",
			Vector3.INF,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		).is_equal_approx(
			_get_origin_tracked_seed_vector3(
				geometry_seed,
				"tip_position_local",
				"tip_position_origin_id",
				Vector3.ZERO,
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
		)
		and _get_origin_tracked_seed_vector3(
			motion_seed,
			"pommel_position_local",
			"pommel_position_origin_id",
			Vector3.INF,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		).is_equal_approx(
			_get_origin_tracked_seed_vector3(
				geometry_seed,
				"pommel_position_local",
				"pommel_position_origin_id",
				Vector3.ZERO,
				CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
			)
		)
		and (motion_seed.get("weapon_orientation_degrees", Vector3.INF) as Vector3).is_equal_approx(
			geometry_seed.get("weapon_orientation_degrees", Vector3.ZERO) as Vector3
		)
	)

func _resolve_active_weapon_geometry_seed_base(baked_profile: BakedProfile = null) -> Dictionary:
	if _is_active_unarmed_authoring_wip():
		return _resolve_active_unarmed_geometry_seed_base()
	var resolved_profile: BakedProfile = baked_profile if baked_profile != null else _get_active_baked_profile()
	if resolved_profile == null:
		return {}
	var geometry_seed: Dictionary = weapon_geometry_resolver.resolve_motion_seed_data(resolved_profile)
	if geometry_seed.is_empty():
		return {}
	_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	geometry_seed["preferred_grip_style_mode"] = active_wip.grip_style_mode if active_wip != null else &"grip_normal"
	geometry_seed["two_hand_state"] = (
		CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND
		if active_preview_default_two_hand
		else CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	)
	geometry_seed["primary_hand_slot"] = _resolve_active_authoring_primary_slot_id()
	geometry_seed["authored_for_two_hand_only"] = active_preview_default_two_hand
	return geometry_seed

func _resolve_active_unarmed_geometry_seed_base() -> Dictionary:
	var unarmed_geometry_seed: Dictionary = preview_presenter.resolve_unarmed_hand_authoring_seed(
		preview_subviewport,
		active_wip.wip_id if active_wip != null else CraftedItemWIPScript.UNARMED_AUTHORING_WIP_ID,
		_resolve_active_authoring_primary_slot_id()
	)
	if unarmed_geometry_seed.is_empty():
		unarmed_geometry_seed = _build_fallback_unarmed_geometry_seed()
	_ensure_motion_seed_position_origins(unarmed_geometry_seed, CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT)
	unarmed_geometry_seed["preferred_grip_style_mode"] = CraftedItemWIPScript.GRIP_NORMAL
	unarmed_geometry_seed["two_hand_state"] = CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND
	unarmed_geometry_seed["primary_hand_slot"] = _resolve_active_authoring_primary_slot_id()
	unarmed_geometry_seed["authored_for_two_hand_only"] = false
	unarmed_geometry_seed["weapon_orientation_degrees"] = Vector3.ZERO
	unarmed_geometry_seed["weapon_orientation_authored"] = false
	unarmed_geometry_seed["weapon_roll_degrees"] = 0.0
	unarmed_geometry_seed["axial_reposition_offset"] = 0.0
	unarmed_geometry_seed["grip_seat_slide_offset"] = 0.0
	unarmed_geometry_seed["secondary_grip_seat_slide_offset"] = CombatAnimationMotionNodeScript.DEFAULT_SECONDARY_GRIP_SEAT_SLIDE_OFFSET
	unarmed_geometry_seed["body_support_blend"] = 0.0
	unarmed_geometry_seed["unarmed_hand_proxy"] = true
	var seeded_tip: Vector3 = _get_origin_tracked_seed_vector3(
		unarmed_geometry_seed,
		"tip_position_local",
		"tip_position_origin_id",
		Vector3(0.12, 0.0, 0.0),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	var seeded_pommel: Vector3 = _get_origin_tracked_seed_vector3(
		unarmed_geometry_seed,
		"pommel_position_local",
		"pommel_position_origin_id",
		Vector3(-0.12, 0.0, 0.0),
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
	)
	unarmed_geometry_seed["weapon_total_length_meters"] = maxf(seeded_tip.distance_to(seeded_pommel), 0.001)
	return unarmed_geometry_seed

func _build_fallback_unarmed_geometry_seed() -> Dictionary:
	return {
		"tip_position_local": Vector3(0.12, 0.0, 0.0),
		"tip_position_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"pommel_position_local": Vector3(-0.12, 0.0, 0.0),
		"pommel_position_origin_id": CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT,
		"weapon_total_length_meters": 0.24,
	}

func _draft_matches_raw_weapon_geometry_baseline(draft: Resource) -> bool:
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft == null or typed_draft.motion_node_chain.is_empty():
		return false
	var draft_kind: StringName = StringName(typed_draft.get("draft_kind"))
	var expected_baseline_count: int = 1 if draft_kind == CombatAnimationDraftScript.DRAFT_KIND_IDLE else 2
	if typed_draft.motion_node_chain.size() != expected_baseline_count:
		return false
	var raw_seed: Dictionary = _resolve_active_weapon_geometry_seed_base()
	if raw_seed.is_empty():
		return false
	var raw_origin_id: StringName = (
		CombatOriginRecordScript.ORIGIN_HAND_GRIP_ALIGNMENT
		if _is_active_unarmed_authoring_wip()
		else CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	_ensure_motion_seed_position_origins(raw_seed, raw_origin_id)
	var seeded_tip: Vector3 = _get_origin_tracked_seed_vector3(
		raw_seed,
		"tip_position_local",
		"tip_position_origin_id",
		Vector3.ZERO,
		raw_origin_id
	)
	var seeded_pommel: Vector3 = _get_origin_tracked_seed_vector3(
		raw_seed,
		"pommel_position_local",
		"pommel_position_origin_id",
		Vector3.ZERO,
		raw_origin_id
	)
	var seeded_weapon_orientation: Vector3 = raw_seed.get("weapon_orientation_degrees", Vector3.ZERO) as Vector3
	var seeded_weapon_orientation_authored: bool = bool(raw_seed.get("weapon_orientation_authored", false))
	var seeded_weapon_roll: float = float(raw_seed.get("weapon_roll_degrees", 0.0))
	var seeded_axial_reposition: float = float(raw_seed.get("axial_reposition_offset", 0.0))
	var seeded_grip_slide: float = float(raw_seed.get("grip_seat_slide_offset", 0.0))
	var seeded_secondary_grip_slide: float = float(raw_seed.get(
		"secondary_grip_seat_slide_offset",
		CombatAnimationMotionNodeScript.DEFAULT_SECONDARY_GRIP_SEAT_SLIDE_OFFSET
	))
	var seeded_body_support_blend: float = clampf(float(raw_seed.get("body_support_blend", 0.0)), 0.0, 1.0)
	var seeded_grip_mode: StringName = StringName(raw_seed.get("preferred_grip_style_mode", typed_draft.preferred_grip_style_mode))
	var seeded_two_hand_state: StringName = StringName(raw_seed.get("two_hand_state", CombatAnimationMotionNodeScript.TWO_HAND_STATE_AUTO))
	var seeded_primary_hand_slot: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(StringName(raw_seed.get(
		"primary_hand_slot",
		CombatAnimationMotionNodeScript.PRIMARY_HAND_AUTO
	)))
	var seeded_two_hand_only: bool = bool(raw_seed.get("authored_for_two_hand_only", typed_draft.authored_for_two_hand_only))
	if typed_draft.preferred_grip_style_mode != seeded_grip_mode or typed_draft.authored_for_two_hand_only != seeded_two_hand_only:
		return false
	for motion_node_variant: Variant in typed_draft.motion_node_chain:
		var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
		if motion_node == null:
			return false
		if not (
			motion_node.tip_position_local.is_equal_approx(seeded_tip)
			and motion_node.pommel_position_local.is_equal_approx(seeded_pommel)
			and motion_node.weapon_orientation_degrees.is_equal_approx(seeded_weapon_orientation)
			and motion_node.weapon_orientation_authored == seeded_weapon_orientation_authored
			and is_equal_approx(motion_node.weapon_roll_degrees, seeded_weapon_roll)
			and is_equal_approx(motion_node.axial_reposition_offset, seeded_axial_reposition)
			and is_equal_approx(motion_node.grip_seat_slide_offset, seeded_grip_slide)
			and is_equal_approx(motion_node.secondary_grip_seat_slide_offset, seeded_secondary_grip_slide)
			and is_equal_approx(motion_node.body_support_blend, seeded_body_support_blend)
			and motion_node.preferred_grip_style_mode == seeded_grip_mode
			and motion_node.two_hand_state == seeded_two_hand_state
			and motion_node.primary_hand_slot == seeded_primary_hand_slot
		):
			return false
	return true

func _migrate_saved_skill_draft_baselines_if_needed() -> void:
	if active_wip_library == null:
		return
	var migrated: bool = false
	for saved_wip: CraftedItemWIP in active_wip_library.get_saved_wips():
		if saved_wip == null:
			continue
		var station_state: Resource = saved_wip.combat_animation_station_state
		var version_before: int = int(station_state.get("station_version")) if station_state != null else 0
		if version_before >= CombatAnimationStationStateScript.SKILL_BASELINE_SCHEMA_VERSION:
			continue
		saved_wip.ensure_combat_animation_station_state()
		migrated = true
	if migrated:
		active_wip_library.persist()

func _reset_active_weapon_open_config() -> void:
	_apply_active_weapon_open_config(_normalize_weapon_open_config({}, null))

func _apply_active_weapon_open_config(open_config: Dictionary) -> void:
	_clear_active_weapon_baseline_seed_cache()
	active_preview_dominant_slot_id = StringName(open_config.get("dominant_slot_id", HAND_SLOT_RIGHT))
	active_preview_default_two_hand = bool(open_config.get("use_two_hand", false))
	preview_presenter.configure_preview_hand_setup(_resolve_active_motion_node_primary_slot_id(), active_preview_default_two_hand)

func _is_combat_idle_draft(draft: Resource) -> bool:
	return (
		draft != null
		and StringName(draft.get("draft_kind")) == CombatAnimationDraftScript.DRAFT_KIND_IDLE
		and StringName(draft.get("context_id")) == CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT
	)

func _is_noncombat_idle_draft(draft: Resource) -> bool:
	return (
		draft != null
		and StringName(draft.get("draft_kind")) == CombatAnimationDraftScript.DRAFT_KIND_IDLE
		and StringName(draft.get("context_id")) == CombatAnimationDraftScript.IDLE_CONTEXT_NONCOMBAT
	)

func _is_idle_draft(draft: Resource) -> bool:
	return draft != null and StringName(draft.get("draft_kind")) == CombatAnimationDraftScript.DRAFT_KIND_IDLE

func _enforce_active_idle_authority(mark_dirty: bool = false) -> bool:
	return _enforce_idle_authority(_get_active_draft(), mark_dirty)

func _enforce_idle_authority(draft: Resource, mark_dirty: bool = false) -> bool:
	if not _is_idle_draft(draft):
		return false
	var draft_changed: bool = false
	var selected_index_before: int = int(draft.get("selected_motion_node_index"))
	var continuity_index_before: int = int(draft.get("continuity_motion_node_index"))
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		var chain_size_before: int = typed_draft.motion_node_chain.size()
		typed_draft.ensure_minimum_baseline_nodes()
		typed_draft.normalize()
		draft_changed = draft_changed or typed_draft.motion_node_chain.size() != chain_size_before
	else:
		var raw_chain: Array = draft.get("motion_node_chain") as Array
		if raw_chain.is_empty():
			raw_chain.append(CombatAnimationMotionNodeScript.new())
			draft_changed = true
		while raw_chain.size() > 1:
			raw_chain.remove_at(raw_chain.size() - 1)
			draft_changed = true
		for node_index: int in range(raw_chain.size()):
			var raw_node: Resource = raw_chain[node_index] as Resource
			if raw_node == null:
				continue
			raw_node.set("node_index", node_index)
			if raw_node.has_method("normalize"):
				raw_node.call("normalize")
	if selected_index_before != 0:
		draft.set("selected_motion_node_index", 0)
		draft_changed = true
	if continuity_index_before != 0:
		draft.set("continuity_motion_node_index", 0)
		draft_changed = true
	session_state.current_motion_node_index = 0
	var resolved_primary_slot_id: StringName = _resolve_active_authoring_primary_slot_id()
	if resolved_primary_slot_id != HAND_SLOT_LEFT:
		resolved_primary_slot_id = HAND_SLOT_RIGHT
	if active_preview_dominant_slot_id != resolved_primary_slot_id:
		active_preview_dominant_slot_id = resolved_primary_slot_id
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var first_motion_node: CombatAnimationMotionNode = null
	if not motion_node_chain.is_empty():
		first_motion_node = motion_node_chain[0] as CombatAnimationMotionNode
	if first_motion_node != null and first_motion_node.primary_hand_slot != resolved_primary_slot_id:
		first_motion_node.primary_hand_slot = resolved_primary_slot_id
		first_motion_node.normalize()
		draft_changed = true
	if _is_combat_idle_draft(draft):
		preview_presenter.configure_preview_hand_setup(resolved_primary_slot_id, active_preview_default_two_hand)
	if draft_changed and mark_dirty:
		_stage_active_wip_edit("", PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE)
	return draft_changed

func _resolve_active_authoring_primary_slot_id() -> StringName:
	var equipped_slot_id: StringName = _resolve_equipped_slot_for_active_wip()
	if equipped_slot_id == HAND_SLOT_LEFT or equipped_slot_id == HAND_SLOT_RIGHT:
		return equipped_slot_id
	return active_preview_dominant_slot_id if active_preview_dominant_slot_id == HAND_SLOT_LEFT else HAND_SLOT_RIGHT

func _resolve_equipped_slot_for_active_wip() -> StringName:
	var target_wip_id: StringName = active_saved_wip_id
	if target_wip_id == StringName() and active_wip != null:
		target_wip_id = active_wip.wip_id
	return _resolve_equipped_slot_for_wip_id(target_wip_id)

func _resolve_equipped_slot_for_wip_id(target_wip_id: StringName) -> StringName:
	if active_player == null or target_wip_id == StringName():
		return StringName()
	if not active_player.has_method("get_equipment_state"):
		return StringName()
	var equipment_state = active_player.call("get_equipment_state")
	if equipment_state == null or not equipment_state.has_method("get_equipped_slots"):
		return StringName()
	var equipped_slots_variant: Variant = equipment_state.call("get_equipped_slots")
	if not (equipped_slots_variant is Array):
		return StringName()
	for equipped_slot_variant: Variant in (equipped_slots_variant as Array):
		var equipped_slot: Resource = equipped_slot_variant as Resource
		if equipped_slot == null:
			continue
		if StringName(equipped_slot.get("source_wip_id")) != target_wip_id:
			continue
		var slot_id: StringName = StringName(equipped_slot.get("slot_id"))
		if slot_id == HAND_SLOT_LEFT or slot_id == HAND_SLOT_RIGHT:
			return slot_id
	return StringName()

func _resolve_active_motion_node_primary_slot_id() -> StringName:
	# A weapon's equipped/open slot is the upstream primary-hand authority.
	# Per-node hand selection remains meaningful only for unarmed authoring.
	if not _is_active_unarmed_authoring_wip():
		return _resolve_active_authoring_primary_slot_id()
	if session_state.playback_active and chain_player.is_playing():
		var playback_slot_id: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(chain_player.current_primary_hand_slot)
		if playback_slot_id == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT:
			return HAND_SLOT_LEFT
		if playback_slot_id == CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT:
			return HAND_SLOT_RIGHT
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return active_preview_dominant_slot_id
	var requested_slot_id: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(motion_node.primary_hand_slot)
	if requested_slot_id == CombatAnimationMotionNodeScript.PRIMARY_HAND_LEFT:
		return HAND_SLOT_LEFT
	if requested_slot_id == CombatAnimationMotionNodeScript.PRIMARY_HAND_RIGHT:
		return HAND_SLOT_RIGHT
	return active_preview_dominant_slot_id

func _add_unarmed_project_list_item() -> void:
	project_list.add_item("%s | %s" % [UNARMED_PROJECT_LIST_LABEL, UNARMED_BUILDER_SCOPE_LABEL])
	var item_index: int = project_list.get_item_count() - 1
	project_list.set_item_metadata(item_index, CraftedItemWIPScript.UNARMED_AUTHORING_WIP_ID)
	if _is_unarmed_authoring_wip_id(active_saved_wip_id):
		project_list.select(item_index)

func _get_or_create_unarmed_authoring_wip_clone() -> CraftedItemWIP:
	if active_wip_library != null:
		var saved_clone: CraftedItemWIP = active_wip_library.get_unarmed_authoring_wip_clone(false)
		if saved_clone != null:
			_normalize_unarmed_authoring_wip(saved_clone)
			return saved_clone
	var unarmed_wip: CraftedItemWIP = CraftedItemWIPScript.new()
	_normalize_unarmed_authoring_wip(unarmed_wip)
	return unarmed_wip

func _normalize_unarmed_authoring_wip(unarmed_wip: CraftedItemWIP) -> void:
	if unarmed_wip == null:
		return
	unarmed_wip.wip_id = CraftedItemWIPScript.UNARMED_AUTHORING_WIP_ID
	unarmed_wip.forge_project_name = "- Unarmed"
	unarmed_wip.forge_builder_path_id = CraftedItemWIPScript.BUILDER_PATH_MELEE
	unarmed_wip.forge_builder_component_id = CraftedItemWIPScript.BUILDER_COMPONENT_PRIMARY
	unarmed_wip.forge_intent = CraftedItemWIPScript.FORGE_INTENT_UNARMED
	unarmed_wip.equipment_context = CraftedItemWIPScript.EQUIPMENT_CONTEXT_UNARMED
	unarmed_wip.grip_style_mode = CraftedItemWIPScript.GRIP_NORMAL
	unarmed_wip.latest_baked_profile_snapshot = null
	unarmed_wip.layers.clear()
	var station_state: Resource = unarmed_wip.combat_animation_station_state
	if station_state == null or not station_state.has_method("ensure_default_baseline_content"):
		station_state = CombatAnimationStationStateScript.new()
		unarmed_wip.combat_animation_station_state = station_state
	station_state.set("uses_stage1_geometry_truth", false)
	station_state.set("uses_stage2_geometry_truth", false)
	unarmed_wip.ensure_combat_animation_station_state()

func _is_unarmed_authoring_wip_id(wip_id: StringName) -> bool:
	return wip_id == CraftedItemWIPScript.UNARMED_AUTHORING_WIP_ID

func _is_active_unarmed_authoring_wip() -> bool:
	return CraftedItemWIPScript.is_unarmed_authoring_wip(active_wip)

func _normalize_weapon_open_config(open_config: Dictionary, saved_wip: CraftedItemWIP) -> Dictionary:
	var default_config: Dictionary = _build_default_weapon_open_config(saved_wip)
	var dominant_slot_id: StringName = StringName(open_config.get(
		"dominant_slot_id",
		default_config.get("dominant_slot_id", HAND_SLOT_RIGHT)
	))
	if dominant_slot_id != HAND_SLOT_LEFT:
		dominant_slot_id = HAND_SLOT_RIGHT
	if saved_wip != null and not CraftedItemWIPScript.is_unarmed_authoring_wip(saved_wip):
		var equipped_slot_id: StringName = _resolve_equipped_slot_for_wip_id(saved_wip.wip_id)
		if equipped_slot_id == HAND_SLOT_LEFT or equipped_slot_id == HAND_SLOT_RIGHT:
			dominant_slot_id = equipped_slot_id
	return {
		"dominant_slot_id": dominant_slot_id,
		"use_two_hand": bool(open_config.get(
			"use_two_hand",
			default_config.get("use_two_hand", false)
		)) and not CraftedItemWIPScript.is_unarmed_authoring_wip(saved_wip),
	}

func _build_default_weapon_open_config(saved_wip: CraftedItemWIP) -> Dictionary:
	var config := {
		"dominant_slot_id": HAND_SLOT_RIGHT,
		"use_two_hand": false,
	}
	if saved_wip == null:
		return config
	if CraftedItemWIPScript.is_unarmed_authoring_wip(saved_wip):
		return config
	var equipped_slot_id: StringName = _resolve_equipped_slot_for_wip_id(saved_wip.wip_id)
	match CraftedItemWIPScript.normalize_builder_path_id(saved_wip.forge_builder_path_id):
		CraftedItemWIPScript.BUILDER_PATH_SHIELD:
			config["dominant_slot_id"] = HAND_SLOT_LEFT
		CraftedItemWIPScript.BUILDER_PATH_RANGED_PHYSICAL:
			config["dominant_slot_id"] = HAND_SLOT_LEFT
		CraftedItemWIPScript.BUILDER_PATH_MAGIC:
			config["dominant_slot_id"] = HAND_SLOT_RIGHT
			config["use_two_hand"] = true
		_:
			config["dominant_slot_id"] = HAND_SLOT_RIGHT
			config["use_two_hand"] = false
	if equipped_slot_id == HAND_SLOT_LEFT or equipped_slot_id == HAND_SLOT_RIGHT:
		config["dominant_slot_id"] = equipped_slot_id
	return config

func _get_active_weapon_open_summary_label() -> String:
	var hand_label: String = "Left hand primary" if active_preview_dominant_slot_id == HAND_SLOT_LEFT else "Right hand primary"
	var grip_label: String = "Two handed" if active_preview_default_two_hand else "One handed"
	return "%s | %s" % [hand_label, grip_label]

func _resolve_saved_wip_from_list_index(index: int) -> CraftedItemWIP:
	if active_wip_library == null or index < 0 or index >= project_list.get_item_count():
		return null
	var saved_wip_id: StringName = StringName(project_list.get_item_metadata(index))
	if _is_unarmed_authoring_wip_id(saved_wip_id):
		return _get_or_create_unarmed_authoring_wip_clone()
	return active_wip_library.get_saved_wip(saved_wip_id)

func _show_weapon_popup(popup: PopupMenu, desired_position: Vector2, popup_size_hint: Vector2 = Vector2(240.0, 108.0)) -> void:
	if popup == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2.ZERO
	var popup_position: Vector2 = desired_position
	popup_position.x = clampf(popup_position.x, 8.0, maxf(8.0, viewport_size.x - popup_size_hint.x - 8.0))
	popup_position.y = clampf(popup_position.y, 8.0, maxf(8.0, viewport_size.y - popup_size_hint.y - 8.0))
	popup.position = Vector2i(roundi(popup_position.x), roundi(popup_position.y))
	popup.reset_size()
	popup.popup()

func _rebuild_weapon_open_primary_popup() -> void:
	if weapon_open_primary_popup == null:
		return
	weapon_open_primary_popup.clear()
	weapon_open_primary_popup.add_item("Open With")
	weapon_open_primary_popup.set_item_disabled(weapon_open_primary_popup.get_item_count() - 1, true)
	weapon_open_primary_popup.add_item("Equip Left hand primary", WEAPON_OPEN_PRIMARY_MENU_ID_LEFT)
	weapon_open_primary_popup.add_item("Equip Right hand primary", WEAPON_OPEN_PRIMARY_MENU_ID_RIGHT)

func _rebuild_weapon_open_variant_popup(primary_slot_id: StringName) -> void:
	if weapon_open_variant_popup == null:
		return
	var hand_label: String = "Equip Left hand primary" if primary_slot_id == HAND_SLOT_LEFT else "Equip Right hand primary"
	weapon_open_variant_popup.clear()
	weapon_open_variant_popup.add_item(hand_label)
	weapon_open_variant_popup.set_item_disabled(weapon_open_variant_popup.get_item_count() - 1, true)
	weapon_open_variant_popup.add_item("One handed", WEAPON_OPEN_VARIANT_MENU_ID_ONE_HAND)
	weapon_open_variant_popup.add_item("Two handed", WEAPON_OPEN_VARIANT_MENU_ID_TWO_HAND)
	if _is_unarmed_authoring_wip_id(pending_weapon_open_wip_id):
		weapon_open_variant_popup.set_item_disabled(weapon_open_variant_popup.get_item_count() - 1, true)

func _hide_weapon_open_popups() -> void:
	if weapon_open_variant_popup != null:
		weapon_open_variant_popup.hide()
	if weapon_open_primary_popup != null:
		weapon_open_primary_popup.hide()
	pending_weapon_open_wip_id = StringName()
	pending_weapon_open_primary_slot_id = HAND_SLOT_RIGHT

func _has_visible_weapon_open_popup() -> bool:
	return (
		is_instance_valid(weapon_open_variant_popup)
		and weapon_open_variant_popup.visible
	) or (
		is_instance_valid(weapon_open_primary_popup)
		and weapon_open_primary_popup.visible
	)

func _show_weapon_open_primary_popup_for_index(index: int) -> void:
	if active_wip_library == null or index < 0 or index >= project_list.get_item_count():
		return
	var saved_wip_id: StringName = StringName(project_list.get_item_metadata(index))
	if saved_wip_id == StringName():
		return
	pending_weapon_open_wip_id = saved_wip_id
	pending_weapon_open_primary_slot_id = HAND_SLOT_RIGHT
	project_list.select(index)
	_rebuild_weapon_open_primary_popup()
	_show_weapon_popup(
		weapon_open_primary_popup,
		get_viewport().get_mouse_position() + Vector2(12.0, 4.0),
		Vector2(240.0, 96.0)
	)

func _show_weapon_open_variant_popup(primary_slot_id: StringName) -> void:
	if pending_weapon_open_wip_id == StringName():
		return
	pending_weapon_open_primary_slot_id = primary_slot_id
	_rebuild_weapon_open_variant_popup(primary_slot_id)
	var base_position: Vector2 = Vector2(weapon_open_primary_popup.position) + Vector2(maxf(float(weapon_open_primary_popup.size.x), 210.0) + 4.0, 0.0)
	_show_weapon_popup(weapon_open_variant_popup, base_position, Vector2(220.0, 96.0))

func _seed_active_station_drafts_from_weapon_geometry() -> bool:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return false
	var geometry_seed: Dictionary = _resolve_active_weapon_motion_seed()
	if geometry_seed.is_empty():
		return false
	var changed: bool = false
	for property_name in [&"idle_drafts", &"skill_drafts"]:
		var drafts: Array = station_state.get(property_name) as Array
		for draft_variant: Variant in drafts:
			var draft: Resource = draft_variant as Resource
			if _seed_draft_from_active_weapon_geometry(draft):
				changed = true
	return changed

func _seed_draft_from_active_weapon_geometry(draft: Resource, force_reseed: bool = false) -> bool:
	if draft == null:
		return false
	var geometry_seed: Dictionary = _resolve_active_weapon_authored_baseline_seed()
	if geometry_seed.is_empty():
		return false
	var typed_draft: CombatAnimationDraft = draft as CombatAnimationDraft
	if typed_draft != null:
		return typed_draft.apply_weapon_geometry_seed(geometry_seed, force_reseed)
	if draft.has_method("apply_weapon_geometry_seed"):
		return bool(draft.call("apply_weapon_geometry_seed", geometry_seed, force_reseed))
	return false

func _realign_active_draft_to_preview_open_baseline(force_reseed: bool = false) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	return _seed_draft_from_active_weapon_geometry(draft, force_reseed)

func _active_station_retarget_requires_weapon_length_update() -> bool:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return false
	var current_weapon_length: float = _get_active_weapon_total_length()
	if current_weapon_length <= 0.001:
		return false
	var motion_node_count: int = 0
	for property_name in [&"idle_drafts", &"skill_drafts"]:
		var drafts: Array = station_state.get(property_name) as Array
		for draft_variant: Variant in drafts:
			var draft: Resource = draft_variant as Resource
			if draft == null:
				continue
			var motion_node_chain: Array = draft.get("motion_node_chain") as Array
			for motion_node_variant: Variant in motion_node_chain:
				var motion_node: CombatAnimationMotionNode = motion_node_variant as CombatAnimationMotionNode
				if motion_node == null:
					continue
				motion_node_count += 1
				var retarget_node: Resource = motion_node.retarget_node
				if retarget_node == null:
					return true
				var source_length: float = maxf(float(retarget_node.get("source_weapon_length_meters")), 0.0)
				if source_length <= 0.001:
					return true
				if absf(source_length - current_weapon_length) > 0.001:
					return true
	return motion_node_count <= 0

func _retarget_active_station_drafts_for_current_weapon_geometry() -> Dictionary:
	var result: Dictionary = {
		"changed": false,
		"seeded_count": 0,
		"retargeted_count": 0,
		"endpoint_changed_count": 0,
		"draft_count": 0,
	}
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return result
	var current_weapon_length: float = _get_active_weapon_total_length()
	if current_weapon_length <= 0.001:
		return result
	var volume_config: Dictionary = _resolve_active_retarget_volume_config()
	for property_name in [&"idle_drafts", &"skill_drafts"]:
		var drafts: Array = station_state.get(property_name) as Array
		for draft_variant: Variant in drafts:
			var draft: Resource = draft_variant as Resource
			if draft == null:
				continue
			var draft_result: Dictionary = retarget_resolver.retarget_draft_for_weapon_length(
				draft,
				current_weapon_length,
				volume_config,
				0.001,
				true
			)
			_accumulate_retarget_result(result, draft_result)
			result["draft_count"] = int(result.get("draft_count", 0)) + 1
	return result

func _refresh_active_station_retarget_authoring_snapshot() -> Dictionary:
	var result: Dictionary = {
		"changed": false,
		"refreshed_count": 0,
		"draft_count": 0,
	}
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return result
	var volume_config: Dictionary = _resolve_active_retarget_volume_config()
	for property_name in [&"idle_drafts", &"skill_drafts"]:
		var drafts: Array = station_state.get(property_name) as Array
		for draft_variant: Variant in drafts:
			var draft: Resource = draft_variant as Resource
			if draft == null:
				continue
			var draft_result: Dictionary = retarget_resolver.refresh_draft_retarget_authoring_snapshot(
				draft,
				volume_config
			)
			if bool(draft_result.get("changed", false)):
				result["changed"] = true
			result["refreshed_count"] = int(result.get("refreshed_count", 0)) + int(draft_result.get("refreshed_count", 0))
			result["draft_count"] = int(result.get("draft_count", 0)) + 1
	return result

func _resolve_active_retarget_volume_config() -> Dictionary:
	var preview_config: Dictionary = _resolve_preview_trajectory_volume_config()
	var config: Dictionary = preview_config.duplicate(true) if not preview_config.is_empty() else {}
	var geometry_seed: Dictionary = _resolve_active_weapon_geometry_seed_base()
	var pivot_ratio: float = _resolve_retarget_pivot_ratio_from_geometry_seed(geometry_seed)
	config["origin_space"] = &"primary_shoulder"
	config["origin_id"] = _normalize_seed_origin_id(
		StringName(config.get("origin_id", CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER)),
		CombatOriginRecordScript.ORIGIN_PRIMARY_SHOULDER
	)
	config["parent_origin_id"] = _normalize_seed_origin_id(
		StringName(config.get("parent_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	config["origin_local_origin_id"] = _normalize_seed_origin_id(
		StringName(config.get("origin_local_origin_id", config["parent_origin_id"])),
		StringName(config["parent_origin_id"])
	)
	config["pivot_ratio_from_pommel"] = pivot_ratio
	if not config.has("origin_local"):
		config["origin_local"] = Vector3.ZERO
	if not config.has("min_radius_meters"):
		config["min_radius_meters"] = 0.0
	if not config.has("max_radius_meters") or float(config.get("max_radius_meters", 0.0)) <= 0.0:
		_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
		var tip_position: Vector3 = _get_origin_tracked_seed_vector3(
			geometry_seed,
			"tip_position_local",
			"tip_position_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var pommel_position: Vector3 = _get_origin_tracked_seed_vector3(
			geometry_seed,
			"pommel_position_local",
			"pommel_position_origin_id",
			Vector3.ZERO,
			CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
		)
		var segment_length: float = tip_position.distance_to(pommel_position)
		var weapon_length: float = float(geometry_seed.get("weapon_total_length_meters", segment_length))
		var pivot_position: Vector3 = pommel_position.lerp(tip_position, pivot_ratio)
		var fallback_max: float = maxf(1.0, pivot_position.length() + maxf(segment_length, weapon_length))
		fallback_max = maxf(fallback_max, maxf(segment_length, weapon_length) * 3.0)
		config["max_radius_meters"] = fallback_max
	return config

func _resolve_retarget_pivot_ratio_from_geometry_seed(geometry_seed: Dictionary) -> float:
	if geometry_seed.is_empty():
		return 0.5
	_ensure_motion_seed_position_origins(geometry_seed, CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var tip_position: Vector3 = _get_origin_tracked_seed_vector3(
		geometry_seed,
		"tip_position_local",
		"tip_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var pommel_position: Vector3 = _get_origin_tracked_seed_vector3(
		geometry_seed,
		"pommel_position_local",
		"pommel_position_origin_id",
		Vector3.ZERO,
		CombatOriginRecordScript.ORIGIN_WEAPON_ROOT
	)
	var axis: Vector3 = tip_position - pommel_position
	var axis_length_squared: float = axis.length_squared()
	if axis_length_squared <= 0.000001:
		return 0.5
	_resolve_seed_origin_id(geometry_seed, "pivot_target_position_origin_id", CombatOriginRecordScript.ORIGIN_WEAPON_ROOT)
	var pivot_target_position: Vector3 = Vector3.ZERO
	return clampf((pivot_target_position - pommel_position).dot(axis) / axis_length_squared, 0.0, 1.0)

func _accumulate_retarget_result(total: Dictionary, next_result: Dictionary) -> void:
	if bool(next_result.get("changed", false)):
		total["changed"] = true
	total["seeded_count"] = int(total.get("seeded_count", 0)) + int(next_result.get("seeded_count", 0))
	total["retargeted_count"] = int(total.get("retargeted_count", 0)) + int(next_result.get("retargeted_count", 0))
	total["endpoint_changed_count"] = int(total.get("endpoint_changed_count", 0)) + int(next_result.get("endpoint_changed_count", 0))

func _build_preview_playback_state() -> Dictionary:
	var playback_state: Dictionary = {
		"debugger_view_enabled": debugger_view_enabled,
	}
	if not session_state.playback_active or not chain_player.is_playing():
		playback_state["open_mount_seed"] = _resolve_active_weapon_authored_baseline_seed(true)
		return playback_state
	playback_state["active"] = true
	playback_state["runtime_clip_playback"] = chain_player.current_trajectory_volume_state.get("source", StringName()) == &"baked_runtime_clip"
	playback_state["tip_position_local"] = chain_player.current_tip_position
	playback_state["tip_position_origin_id"] = chain_player.current_tip_position_origin_id
	playback_state["pommel_position_local"] = chain_player.current_pommel_position
	playback_state["pommel_position_origin_id"] = chain_player.current_pommel_position_origin_id
	playback_state["weapon_orientation_degrees"] = chain_player.current_weapon_orientation_degrees
	playback_state["weapon_roll_degrees"] = chain_player.current_weapon_roll
	playback_state["axial_reposition_offset"] = chain_player.current_axial_reposition
	playback_state["grip_seat_slide_offset"] = chain_player.current_grip_seat_slide
	playback_state["secondary_grip_seat_slide_offset"] = chain_player.current_secondary_grip_seat_slide
	playback_state["body_support_blend"] = chain_player.current_body_support_blend
	playback_state["right_upperarm_roll_degrees"] = chain_player.current_right_upperarm_roll
	playback_state["left_upperarm_roll_degrees"] = chain_player.current_left_upperarm_roll
	playback_state["right_hand_proxy_authored"] = chain_player.current_right_hand_proxy_authored
	playback_state["right_hand_proxy_tip_position_local"] = chain_player.current_right_hand_proxy_tip_position
	playback_state["right_hand_proxy_tip_position_origin_id"] = chain_player.current_right_hand_proxy_tip_position_origin_id
	playback_state["right_hand_proxy_pommel_position_local"] = chain_player.current_right_hand_proxy_pommel_position
	playback_state["right_hand_proxy_pommel_position_origin_id"] = chain_player.current_right_hand_proxy_pommel_position_origin_id
	playback_state["left_hand_proxy_authored"] = chain_player.current_left_hand_proxy_authored
	playback_state["left_hand_proxy_tip_position_local"] = chain_player.current_left_hand_proxy_tip_position
	playback_state["left_hand_proxy_tip_position_origin_id"] = chain_player.current_left_hand_proxy_tip_position_origin_id
	playback_state["left_hand_proxy_pommel_position_local"] = chain_player.current_left_hand_proxy_pommel_position
	playback_state["left_hand_proxy_pommel_position_origin_id"] = chain_player.current_left_hand_proxy_pommel_position_origin_id
	playback_state["two_hand_state"] = chain_player.current_two_hand_state
	playback_state["primary_hand_slot"] = chain_player.current_primary_hand_slot
	playback_state["preferred_grip_style_mode"] = chain_player.current_preferred_grip_style_mode
	playback_state["contact_grip_axis_local"] = chain_player.current_contact_grip_axis_local
	playback_state["contact_grip_axis_origin_id"] = chain_player.current_contact_grip_axis_origin_id
	playback_state["contact_grip_axis_local_override_active"] = chain_player.current_contact_grip_axis_local_override_active
	playback_state["upper_body_pose_available"] = chain_player.current_upper_body_pose_available
	playback_state["upper_body_bone_names"] = chain_player.current_upper_body_bone_names
	playback_state["upper_body_bone_pose_rotations"] = chain_player.current_upper_body_bone_pose_rotations
	playback_state["solved_replay_available"] = chain_player.current_solved_replay_available
	playback_state["solved_replay_reference_bone_name"] = chain_player.current_solved_replay_reference_bone_name
	playback_state["solved_replay_reference_origin_id"] = chain_player.current_solved_replay_reference_origin_id
	playback_state["solved_upper_body_bone_names"] = chain_player.current_solved_upper_body_bone_names
	playback_state["solved_upper_body_pose_positions"] = chain_player.current_solved_upper_body_pose_positions
	playback_state["solved_upper_body_pose_rotations"] = chain_player.current_solved_upper_body_pose_rotations
	playback_state["solved_upper_body_pose_scales"] = chain_player.current_solved_upper_body_pose_scales
	playback_state["solved_weapon_position_reference_local"] = chain_player.current_solved_weapon_position_reference_local
	playback_state["solved_weapon_rotation_reference_local"] = chain_player.current_solved_weapon_rotation_reference_local
	playback_state["solved_weapon_scale_reference_local"] = chain_player.current_solved_weapon_scale_reference_local
	playback_state["solved_weapon_reference_origin_id"] = chain_player.current_solved_weapon_reference_origin_id
	playback_state["solved_anchor_node_paths"] = chain_player.current_solved_anchor_node_paths
	playback_state["solved_anchor_positions_weapon_local"] = chain_player.current_solved_anchor_positions_weapon_local
	playback_state["solved_anchor_rotations_weapon_local"] = chain_player.current_solved_anchor_rotations_weapon_local
	playback_state["solved_anchor_scales_weapon_local"] = chain_player.current_solved_anchor_scales_weapon_local
	playback_state["solved_anchor_origin_id"] = chain_player.current_solved_anchor_origin_id
	playback_state["solved_replay_bridge_frame"] = chain_player.current_solved_replay_bridge_frame
	playback_state["trajectory_volume_state"] = chain_player.current_trajectory_volume_state
	return playback_state

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
		if draft == null:
			continue
		if _is_idle_mode() and not CombatAnimationStationStateScript.is_authoring_idle_context_id(StringName(draft.get("context_id"))):
			continue
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

func _is_motion_node_authoring_locked(motion_node: CombatAnimationMotionNode) -> bool:
	return motion_node != null and bool(motion_node.locked_for_authoring)

func _is_generated_grip_style_transition_node(motion_node: CombatAnimationMotionNode) -> bool:
	return (
		motion_node != null
		and bool(motion_node.generated_transition_node)
		and motion_node.generated_transition_kind == CombatAnimationMotionNodeScript.TRANSITION_KIND_GRIP_STYLE_SWAP
	)

func _can_author_motion_node_curve_handles(motion_node: CombatAnimationMotionNode) -> bool:
	if motion_node == null:
		return false
	return not _is_motion_node_authoring_locked(motion_node) or _is_generated_grip_style_transition_node(motion_node)

func _can_insert_grip_style_transition_from_motion_node(motion_node: CombatAnimationMotionNode) -> bool:
	if motion_node == null:
		return false
	return not _is_motion_node_authoring_locked(motion_node) or _is_generated_grip_style_transition_node(motion_node)

func _reject_locked_motion_node_edit() -> void:
	footer_status_label.text = "Generated transition nodes keep their endpoints locked; grip-swap bridge curves can still be shaped."

func _draft_uses_hidden_entry_motion_node(draft: Resource) -> bool:
	if draft == null:
		return false
	if StringName(draft.get("draft_kind")) != CombatAnimationDraftScript.DRAFT_KIND_SKILL:
		return false
	return int((draft.get("motion_node_chain") as Array).size()) >= 2

func _get_user_visible_motion_node_start_index(draft: Resource) -> int:
	return 1 if _draft_uses_hidden_entry_motion_node(draft) else 0

func _get_user_visible_motion_node_count(draft: Resource) -> int:
	if draft == null:
		return 0
	var chain_size: int = int((draft.get("motion_node_chain") as Array).size())
	return maxi(chain_size - _get_user_visible_motion_node_start_index(draft), 0)

func _ensure_valid_editor_motion_node_selection() -> void:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		return
	var minimum_index: int = _get_user_visible_motion_node_start_index(draft)
	var selected_index: int = int(draft.get("selected_motion_node_index"))
	var resolved_index: int = clampi(selected_index, minimum_index, motion_node_chain.size() - 1)
	if resolved_index != selected_index:
		draft.set("selected_motion_node_index", resolved_index)
	session_state.current_motion_node_index = resolved_index

func _get_selected_user_visible_motion_node_label(draft: Resource, motion_node: CombatAnimationMotionNode) -> String:
	if motion_node == null:
		return ""
	var visible_start_index: int = _get_user_visible_motion_node_start_index(draft)
	var actual_index: int = motion_node.node_index
	var visible_index: int = actual_index - visible_start_index + 1
	if visible_index < 1:
		return String(motion_node.node_id)
	return "N%02d (%s)" % [visible_index, String(motion_node.node_id)]

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

func _persist_active_wip(
	status_message: String = "",
	runtime_cache_mode: StringName = PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE,
	refresh_retarget_authoring_snapshot: bool = true
) -> void:
	if bool(get_meta("verification_skip_persistence", false)):
		editor_state_dirty = false
		if footer_status_label != null and not status_message.strip_edges().is_empty():
			footer_status_label.text = status_message
		_refresh_manual_save_controls()
		return
	if active_wip_library == null or active_wip == null:
		return
	active_wip.ensure_combat_animation_station_state()
	if refresh_retarget_authoring_snapshot:
		_refresh_active_station_retarget_authoring_snapshot()
	_apply_runtime_cache_persistence_mode(runtime_cache_mode)
	if _is_active_unarmed_authoring_wip():
		_normalize_unarmed_authoring_wip(active_wip)
		var saved_unarmed_clone: CraftedItemWIP = active_wip_library.save_unarmed_authoring_wip(active_wip)
		if saved_unarmed_clone != null:
			active_saved_wip_id = CraftedItemWIPScript.UNARMED_AUTHORING_WIP_ID
			active_wip = saved_unarmed_clone
		editor_state_dirty = false
		_refresh_manual_save_controls()
		if not status_message.strip_edges().is_empty():
			footer_status_label.text = status_message
		return
	var saved_clone: CraftedItemWIP = active_wip_library.save_wip(active_wip)
	if saved_clone != null:
		active_saved_wip_id = saved_clone.wip_id
		active_wip.wip_id = saved_clone.wip_id
	editor_state_dirty = false
	_refresh_manual_save_controls()
	if not status_message.strip_edges().is_empty():
		footer_status_label.text = status_message

func _stage_active_wip_edit(
	status_message: String = "",
	runtime_cache_mode: StringName = PERSIST_RUNTIME_CACHE_DIRTY_ACTIVE
) -> void:
	if active_wip == null:
		return
	active_wip.ensure_combat_animation_station_state()
	_apply_runtime_cache_persistence_mode(runtime_cache_mode)
	if bool(get_meta("verification_skip_persistence", false)):
		editor_state_dirty = false
		if footer_status_label != null and not status_message.strip_edges().is_empty():
			footer_status_label.text = status_message
		_refresh_manual_save_controls()
		return
	editor_state_dirty = true
	_refresh_manual_save_controls()
	if footer_status_label != null and not status_message.strip_edges().is_empty():
		footer_status_label.text = status_message

func _apply_runtime_cache_persistence_mode(runtime_cache_mode: StringName) -> void:
	match runtime_cache_mode:
		PERSIST_RUNTIME_CACHE_KEEP:
			return
		PERSIST_RUNTIME_CACHE_DIRTY_ALL:
			_mark_all_runtime_clip_caches_dirty()
		PERSIST_RUNTIME_CACHE_REFRESH_ACTIVE:
			_refresh_active_draft_runtime_clip_cache()
		PERSIST_RUNTIME_CACHE_REFRESH_ALL:
			_refresh_station_runtime_clip_cache()
		_:
			_mark_active_draft_runtime_clip_cache_dirty()

func _mark_active_draft_runtime_clip_cache_dirty() -> void:
	_mark_draft_runtime_clip_cache_dirty(_get_active_draft())

func _mark_all_runtime_clip_caches_dirty() -> void:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return
	for property_name in [&"skill_drafts", &"idle_drafts"]:
		var drafts: Array = station_state.get(property_name) as Array
		for draft_variant: Variant in drafts:
			_mark_draft_runtime_clip_cache_dirty(draft_variant as Resource)

func _mark_draft_runtime_clip_cache_dirty(draft: Resource) -> void:
	if draft == null:
		return
	draft.set("baked_runtime_clip", null)
	if _object_has_property(draft, "runtime_cache_signature"):
		draft.set("runtime_cache_signature", "")

func _object_has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	for property_info: Dictionary in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

func _refresh_station_runtime_clip_cache() -> Dictionary:
	var result := {
		"cached_count": 0,
		"skipped_count": 0,
		"failed_count": 0,
		"cleared_noncombat_count": 0,
		"results": [],
		"reason": "",
	}
	if active_wip == null or runtime_clip_baker == null:
		result["reason"] = "missing_runtime_clip_context"
		return result
	var drafts: Array[Resource] = _collect_runtime_clip_cache_drafts()
	if drafts.is_empty():
		result["reason"] = "no_runtime_clip_drafts"
		return result
	for draft: Resource in drafts:
		var cache_result: Dictionary = _refresh_runtime_clip_cache_for_draft(draft)
		(result["results"] as Array).append(cache_result)
		if bool(cache_result.get("cached", false)):
			result["cached_count"] = int(result.get("cached_count", 0)) + 1
			if bool(cache_result.get("skipped", false)):
				result["skipped_count"] = int(result.get("skipped_count", 0)) + 1
			continue
		var reason: String = String(cache_result.get("reason", ""))
		if reason == "noncombat_stow_uses_body_anchor_not_hand_pose":
			result["cleared_noncombat_count"] = int(result.get("cleared_noncombat_count", 0)) + 1
		else:
			result["failed_count"] = int(result.get("failed_count", 0)) + 1
	return result

func _collect_runtime_clip_cache_drafts() -> Array[Resource]:
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return []
	var drafts: Array[Resource] = []
	var seen_keys: Dictionary = {}
	var active_draft: Resource = _get_active_draft()
	if active_draft != null:
		_append_unique_runtime_clip_cache_draft(drafts, seen_keys, active_draft)
	var skill_drafts: Array = station_state.get("skill_drafts") as Array
	for draft_variant: Variant in skill_drafts:
		var draft: Resource = draft_variant as Resource
		if draft == null:
			continue
		_append_unique_runtime_clip_cache_draft(drafts, seen_keys, draft)
	var idle_drafts: Array = station_state.get("idle_drafts") as Array
	for draft_variant: Variant in idle_drafts:
		var draft: Resource = draft_variant as Resource
		if draft == null:
			continue
		var context_id: StringName = StringName(draft.get("context_id"))
		if (
			context_id != CombatAnimationDraftScript.IDLE_CONTEXT_COMBAT
			and context_id != CombatAnimationDraftScript.IDLE_CONTEXT_NONCOMBAT
		):
			continue
		_append_unique_runtime_clip_cache_draft(drafts, seen_keys, draft)
	return drafts

func _append_unique_runtime_clip_cache_draft(
	drafts: Array[Resource],
	seen_keys: Dictionary,
	draft: Resource
) -> void:
	var draft_key: String = _build_runtime_clip_cache_draft_key(draft)
	if draft_key.is_empty() or seen_keys.has(draft_key):
		return
	seen_keys[draft_key] = true
	drafts.append(draft)

func _build_runtime_clip_cache_draft_key(draft: Resource) -> String:
	if draft == null:
		return ""
	if _is_idle_draft(draft):
		return "idle:%s" % String(draft.get("context_id"))
	var slot_id: StringName = _resolve_draft_skill_slot_id_for_runtime_cache(draft)
	if slot_id != StringName():
		return "skill:%s" % String(slot_id)
	return "draft:%s" % String(draft.get("draft_id"))

func _refresh_active_draft_runtime_clip_cache() -> Dictionary:
	return _refresh_runtime_clip_cache_for_draft(_get_active_draft())

func _refresh_runtime_clip_cache_for_draft(draft: Resource) -> Dictionary:
	var result := {
		"cached": false,
		"skipped": false,
		"reason": "",
		"frame_count": 0,
		"upper_body_pose_track": false,
		"solved_replay_track": false,
	}
	if active_wip == null or runtime_clip_baker == null or preview_presenter == null:
		result["reason"] = "missing_runtime_clip_context"
		return result
	if draft == null:
		result["reason"] = "no_draft"
		return result
	if _is_noncombat_idle_draft(draft):
		draft.set("baked_runtime_clip", null)
		_set_draft_runtime_cache_signature(draft, "")
		result["reason"] = "noncombat_stow_uses_body_anchor_not_hand_pose"
		return result
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		draft.set("baked_runtime_clip", null)
		_set_draft_runtime_cache_signature(draft, "")
		result["reason"] = "empty_motion_node_chain"
		return result
	var cache_signature: String = _build_runtime_clip_cache_signature(draft)
	var existing_runtime_clip = draft.get("baked_runtime_clip")
	if _can_reuse_runtime_clip_cache(draft, existing_runtime_clip, cache_signature):
		_set_draft_runtime_cache_signature(draft, cache_signature)
		if _runtime_clip_has_solved_replay_track(existing_runtime_clip):
			result["cached"] = true
			result["skipped"] = true
			result["frame_count"] = int(existing_runtime_clip.call("get_frame_count"))
			result["upper_body_pose_track"] = (
				existing_runtime_clip.has_method("has_upper_body_pose_track")
				and bool(existing_runtime_clip.call("has_upper_body_pose_track"))
			)
			result["solved_replay_track"] = true
			return result
	var trajectory_volume_config: Dictionary = _resolve_preview_trajectory_volume_config()
	var runtime_chain_result: Dictionary = {}
	var playable_motion_node_chain: Array = motion_node_chain
	var runtime_clip = existing_runtime_clip if _can_reuse_runtime_clip_cache(draft, existing_runtime_clip, cache_signature) else null
	if runtime_clip == null:
		if motion_node_chain.size() >= 2:
			runtime_chain_result = _build_preview_runtime_motion_chain(motion_node_chain, trajectory_volume_config)
			playable_motion_node_chain = runtime_chain_result.get("motion_node_chain", motion_node_chain) as Array
		if playable_motion_node_chain.is_empty():
			draft.set("baked_runtime_clip", null)
			_set_draft_runtime_cache_signature(draft, "")
			result["reason"] = "runtime_chain_empty"
			return result
		var clip_kind: StringName = &"skill_playback"
		if _is_idle_draft(draft):
			clip_kind = &"idle"
		runtime_clip = runtime_clip_baker.bake_from_motion_node_chain(
			playable_motion_node_chain,
			{
				"clip_kind": clip_kind,
				"source_draft_id": StringName(draft.get("draft_id")),
				"source_skill_slot_id": _resolve_draft_skill_slot_id_for_runtime_cache(draft) if not _is_idle_draft(draft) else StringName(),
				"source_idle_context_id": StringName(draft.get("context_id")) if _is_idle_draft(draft) else StringName(),
				"source_weapon_wip_id": active_wip.wip_id,
				"source_weapon_length_meters": _get_active_weapon_total_length(),
				"playback_speed_scale": float(draft.get("preview_playback_speed_scale")),
				"loop_enabled": bool(draft.get("preview_loop_enabled")),
				"sample_rate_hz": PREVIEW_RUNTIME_CLIP_SAMPLE_RATE_HZ,
				"trajectory_volume_config": trajectory_volume_config,
				"compile_diagnostics": runtime_chain_result.get("diagnostics", []),
				"degraded_node_count": int(runtime_chain_result.get("degraded_node_count", 0)),
				"hand_swap_bridge_count": int(runtime_chain_result.get("hand_swap_bridge_count", 0)),
				"retargeted_count": int(runtime_chain_result.get("retargeted_count", 0)),
			}
		)
	if runtime_clip == null or not runtime_clip.has_method("get_frame_count") or int(runtime_clip.call("get_frame_count")) <= 0:
		draft.set("baked_runtime_clip", null)
		_set_draft_runtime_cache_signature(draft, "")
		result["reason"] = "runtime_clip_bake_failed"
		return result
	var selected_node_index: int = clampi(
		int(draft.get("selected_motion_node_index")),
		0,
		maxi(playable_motion_node_chain.size() - 1, 0)
	)
	var pose_track_result: Dictionary = preview_presenter.bake_runtime_clip_upper_body_pose_track(
		preview_view_container,
		preview_subviewport,
		active_wip,
		draft,
		runtime_clip,
		selected_node_index
	)
	draft.set("baked_runtime_clip", runtime_clip)
	_set_draft_runtime_cache_signature(draft, cache_signature)
	result["cached"] = true
	result["frame_count"] = int(runtime_clip.call("get_frame_count"))
	result["upper_body_pose_track"] = bool(pose_track_result.get("baked", false))
	result["solved_replay_track"] = bool(pose_track_result.get("solved_replay_track", false))
	result["reason"] = String(pose_track_result.get("reason", ""))
	return result

func _can_reuse_runtime_clip_cache(draft: Resource, runtime_clip, cache_signature: String) -> bool:
	if draft == null or runtime_clip == null or cache_signature.is_empty():
		return false
	if not runtime_clip.has_method("get_frame_count") or int(runtime_clip.call("get_frame_count")) <= 0:
		return false
	var stored_signature: String = _get_draft_runtime_cache_signature(draft)
	if not stored_signature.is_empty() and stored_signature != cache_signature:
		return false
	var source_weapon_wip_id: StringName = StringName(runtime_clip.get("source_weapon_wip_id"))
	if (
		active_wip != null
		and source_weapon_wip_id != StringName()
		and source_weapon_wip_id != active_wip.wip_id
	):
		return false
	if _is_idle_draft(draft):
		var idle_context_id: StringName = StringName(draft.get("context_id"))
		var clip_idle_context_id: StringName = StringName(runtime_clip.get("source_idle_context_id"))
		return clip_idle_context_id == StringName() or clip_idle_context_id == idle_context_id
	var draft_id: StringName = StringName(draft.get("draft_id"))
	var clip_draft_id: StringName = StringName(runtime_clip.get("source_draft_id"))
	if clip_draft_id != StringName() and clip_draft_id != draft_id:
		return false
	var slot_id: StringName = _resolve_draft_skill_slot_id_for_runtime_cache(draft)
	var clip_slot_id: StringName = StringName(runtime_clip.get("source_skill_slot_id"))
	return clip_slot_id == StringName() or slot_id == StringName() or clip_slot_id == slot_id

func _refresh_manual_save_controls(draft: Resource = null) -> void:
	var active_draft: Resource = draft if draft != null else _get_active_draft()
	var has_draft: bool = active_draft != null
	var save_required: bool = has_draft and _active_draft_requires_manual_save(active_draft)
	var can_save: bool = has_draft and save_required and not manual_save_in_progress and not chain_player.is_playing()
	if save_button != null:
		save_button.disabled = not can_save
	if play_preview_button != null:
		play_preview_button.disabled = (
			manual_save_in_progress
			or (
				not chain_player.is_playing()
				and (not has_draft or save_required)
			)
		)

func _active_draft_requires_manual_save(draft: Resource = null) -> bool:
	var active_draft: Resource = draft if draft != null else _get_active_draft()
	if active_draft == null:
		return false
	if editor_state_dirty:
		return true
	return not _active_draft_has_valid_preview_cache(active_draft)

func _active_draft_has_valid_preview_cache(draft: Resource) -> bool:
	if draft == null:
		return false
	var cache_signature: String = _build_runtime_clip_cache_signature(draft)
	if cache_signature.is_empty():
		return false
	var runtime_clip = draft.get("baked_runtime_clip")
	if _can_reuse_runtime_clip_cache(draft, runtime_clip, cache_signature):
		return true
	return _saved_draft_runtime_clip_cache_matches(draft, cache_signature)

func _saved_draft_runtime_clip_cache_matches(draft: Resource, cache_signature: String) -> bool:
	if active_wip_library == null or active_wip == null or draft == null or cache_signature.is_empty():
		return false
	var saved_wip_id: StringName = active_saved_wip_id
	if saved_wip_id == StringName():
		saved_wip_id = active_wip.wip_id
	var draft_identifier: StringName = _resolve_draft_identifier_for_saved_cache(draft)
	if saved_wip_id == StringName() or draft_identifier == StringName():
		return false
	var cache_data: Dictionary = active_wip_library.get_saved_draft_runtime_clip_cache(
		saved_wip_id,
		draft_identifier,
		_is_idle_draft(draft)
	)
	if not bool(cache_data.get("found", false)):
		return false
	var stored_signature: String = String(cache_data.get("runtime_cache_signature", ""))
	if stored_signature.is_empty() or stored_signature != cache_signature:
		return false
	var runtime_clip = cache_data.get("runtime_clip")
	return _can_reuse_runtime_clip_cache(draft, runtime_clip, cache_signature)

func _resolve_draft_identifier_for_saved_cache(draft: Resource) -> StringName:
	if draft == null:
		return StringName()
	return StringName(draft.get("context_id")) if _is_idle_draft(draft) else StringName(draft.get("owning_skill_id"))

func _prepare_cached_preview_playback(draft: Resource, playback_speed: float, should_loop: bool) -> bool:
	if draft == null:
		return false
	var cache_signature: String = _build_runtime_clip_cache_signature(draft)
	var runtime_clip = draft.get("baked_runtime_clip")
	if not _can_reuse_runtime_clip_cache(draft, runtime_clip, cache_signature):
		if not _restore_active_draft_runtime_clip_cache(draft, cache_signature):
			return false
		runtime_clip = draft.get("baked_runtime_clip")
	if not _can_reuse_runtime_clip_cache(draft, runtime_clip, cache_signature):
		return false
	_set_draft_runtime_cache_signature(draft, cache_signature)
	chain_player.prepare_runtime_clip(runtime_clip, playback_speed, should_loop)
	return true

func _restore_active_draft_runtime_clip_cache(draft: Resource, cache_signature: String) -> bool:
	if active_wip_library == null or active_wip == null or draft == null or cache_signature.is_empty():
		return false
	var saved_wip_id: StringName = active_saved_wip_id
	if saved_wip_id == StringName():
		saved_wip_id = active_wip.wip_id
	var draft_identifier: StringName = _resolve_draft_identifier_for_saved_cache(draft)
	if saved_wip_id == StringName() or draft_identifier == StringName():
		return false
	var cache_data: Dictionary = active_wip_library.get_saved_draft_runtime_clip_cache(
		saved_wip_id,
		draft_identifier,
		_is_idle_draft(draft)
	)
	if not bool(cache_data.get("found", false)):
		return false
	var stored_signature: String = String(cache_data.get("runtime_cache_signature", ""))
	if stored_signature.is_empty() or stored_signature != cache_signature:
		return false
	var runtime_clip = cache_data.get("runtime_clip")
	if not _can_reuse_runtime_clip_cache(draft, runtime_clip, cache_signature):
		return false
	draft.set("baked_runtime_clip", runtime_clip)
	_set_draft_runtime_cache_signature(draft, stored_signature)
	return true

func _runtime_clip_has_solved_replay_track(runtime_clip) -> bool:
	return (
		runtime_clip != null
		and runtime_clip.has_method("has_solved_replay_track")
		and bool(runtime_clip.call("has_solved_replay_track"))
	)

func _get_draft_runtime_cache_signature(draft: Resource) -> String:
	if draft == null or not _object_has_property(draft, "runtime_cache_signature"):
		return ""
	return String(draft.get("runtime_cache_signature"))

func _set_draft_runtime_cache_signature(draft: Resource, cache_signature: String) -> void:
	if draft == null or not _object_has_property(draft, "runtime_cache_signature"):
		return
	draft.set("runtime_cache_signature", cache_signature)

func _build_runtime_clip_cache_signature(draft: Resource) -> String:
	if draft == null:
		return ""
	var parts := PackedStringArray()
	# V6 invalidates replay poses that encoded grip-seat fields as signed relative
	# offsets. Saved authoring values are normalized on load; only the derived
	# Skill Crafter runtime track must be rebuilt with canonical 0..1 Handle data.
	parts.append("runtime_cache_v6_normalized_handle_coordinates")
	parts.append(String(active_wip.wip_id) if active_wip != null else "")
	parts.append(String(draft.get("draft_id")))
	parts.append(String(draft.get("draft_kind")))
	parts.append(String(draft.get("context_id")))
	parts.append(String(draft.get("owning_skill_id")))
	parts.append(String(draft.get("legal_slot_id")))
	parts.append(String(draft.get("preferred_grip_style_mode")))
	parts.append(String(draft.get("stow_anchor_mode")))
	parts.append(str(snapped(float(draft.get("stow_contact_ratio")), 0.0001)))
	parts.append(str(bool(draft.get("authored_for_two_hand_only"))))
	parts.append(str(snapped(float(draft.get("preview_playback_speed_scale")), 0.0001)))
	parts.append(str(bool(draft.get("preview_loop_enabled"))))
	parts.append(str(snapped(float(draft.get("speed_acceleration_percent")), 0.0001)))
	parts.append(str(snapped(float(draft.get("speed_deceleration_percent")), 0.0001)))
	parts.append(str(snapped(_get_active_weapon_total_length(), 0.0001)))
	parts.append(_build_active_primary_grip_path_cache_signature())
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	parts.append(str(motion_node_chain.size()))
	for motion_node_variant: Variant in motion_node_chain:
		parts.append(_build_motion_node_runtime_cache_signature(motion_node_variant as CombatAnimationMotionNode))
	return "|".join(parts)

func _build_active_primary_grip_path_cache_signature() -> String:
	if active_wip == null or active_wip.latest_baked_profile_snapshot == null:
		return "grip_slice:none"
	var profile: BakedProfile = active_wip.latest_baked_profile_snapshot
	var ratios := profile.primary_grip_slice_axis_ratios_from_span_start
	var centers := profile.primary_grip_slice_centers
	var centers_origin_id := profile.primary_grip_slice_centers_origin_id
	if (
		ratios.size() < 2
		or ratios.size() != centers.size()
		or centers_origin_id == StringName()
	):
		return "grip_slice:invalid"
	return "grip_slice:v2:%s" % var_to_bytes([
		profile.primary_grip_source_body_id,
		centers_origin_id,
		profile.primary_grip_span_start,
		profile.primary_grip_span_end,
		profile.primary_grip_slide_axis,
		ratios,
		centers,
	]).hex_encode().sha256_text()

func _build_motion_node_runtime_cache_signature(motion_node: CombatAnimationMotionNode) -> String:
	if motion_node == null:
		return "null_node"
	var parts := PackedStringArray()
	parts.append(String(motion_node.node_id))
	parts.append(str(motion_node.node_index))
	parts.append(str(motion_node.weapon_orientation_degrees.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.weapon_orientation_authored))
	parts.append(str(motion_node.tip_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.tip_position_origin_id))
	parts.append(str(motion_node.tip_curve_in_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.tip_curve_out_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.pommel_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.pommel_position_origin_id))
	parts.append(str(motion_node.pommel_curve_in_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(motion_node.pommel_curve_out_handle.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(str(snapped(motion_node.weapon_roll_degrees, 0.0001)))
	parts.append(str(snapped(motion_node.axial_reposition_offset, 0.0001)))
	parts.append(str(snapped(motion_node.grip_seat_slide_offset, 0.0001)))
	parts.append(str(snapped(motion_node.secondary_grip_seat_slide_offset, 0.0001)))
	parts.append(str(snapped(motion_node.transition_duration_seconds, 0.0001)))
	parts.append(str(snapped(motion_node.body_support_blend, 0.0001)))
	parts.append(str(snapped(motion_node.right_upperarm_roll_degrees, 0.0001)))
	parts.append(str(snapped(motion_node.left_upperarm_roll_degrees, 0.0001)))
	parts.append(str(motion_node.right_hand_proxy_authored))
	parts.append(str(motion_node.right_hand_proxy_tip_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.right_hand_proxy_tip_position_origin_id))
	parts.append(str(motion_node.right_hand_proxy_pommel_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.right_hand_proxy_pommel_position_origin_id))
	parts.append(str(motion_node.left_hand_proxy_authored))
	parts.append(str(motion_node.left_hand_proxy_tip_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.left_hand_proxy_tip_position_origin_id))
	parts.append(str(motion_node.left_hand_proxy_pommel_position_local.snapped(Vector3(0.0001, 0.0001, 0.0001))))
	parts.append(String(motion_node.left_hand_proxy_pommel_position_origin_id))
	parts.append(String(motion_node.preferred_grip_style_mode))
	parts.append(String(motion_node.two_hand_state))
	parts.append(String(motion_node.primary_hand_slot))
	parts.append(str(motion_node.generated_transition_node))
	parts.append(String(motion_node.generated_transition_kind))
	parts.append(str(motion_node.locked_for_authoring))
	parts.append(_build_retarget_node_runtime_cache_signature(motion_node.retarget_node))
	return ",".join(parts)

func _build_retarget_node_runtime_cache_signature(retarget_node: Resource) -> String:
	if retarget_node == null:
		return "retarget:none"
	var parts := PackedStringArray()
	parts.append("retarget")
	for property_name in [
		"enabled",
		"origin_space",
		"origin_id",
		"parent_origin_id",
		"pivot_direction_local",
		"pivot_direction_origin_id",
		"pivot_range_percent",
		"pivot_ratio_from_pommel",
		"weapon_axis_local",
		"weapon_axis_origin_id",
		"weapon_orientation_degrees",
		"weapon_orientation_authored",
		"weapon_roll_degrees",
		"axial_reposition_offset",
		"grip_seat_slide_offset",
		"secondary_grip_seat_slide_offset",
		"body_support_blend",
		"right_upperarm_roll_degrees",
		"left_upperarm_roll_degrees",
		"transition_duration_seconds",
		"preferred_grip_style_mode",
		"two_hand_state",
		"primary_hand_slot",
		"source_weapon_length_meters",
		"source_min_radius_meters",
		"source_max_radius_meters",
		"tip_curve_in_normalized",
		"tip_curve_out_normalized",
		"pommel_curve_in_normalized",
		"pommel_curve_out_normalized",
	]:
		parts.append("%s=%s" % [property_name, str(retarget_node.get(StringName(property_name)))])
	return ",".join(parts)

func _resolve_draft_skill_slot_id_for_runtime_cache(draft: Resource) -> StringName:
	if draft == null or _is_idle_draft(draft):
		return StringName()
	var slot_id: StringName = StringName(draft.get("legal_slot_id"))
	if _is_authoring_skill_slot_id(slot_id):
		return slot_id
	var owning_skill_id: StringName = StringName(draft.get("owning_skill_id"))
	if _is_authoring_skill_slot_id(owning_skill_id):
		return owning_skill_id
	return StringName()

func _apply_motion_node_change(
	status_message: String,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true,
	preview_grip_resolve_reason: StringName = StringName()
) -> void:
	if persist_change:
		_stage_active_wip_edit(status_message)
	else:
		_stage_active_wip_edit(status_message)
	if refresh_list:
		_refresh_motion_node_list()
	if refresh_fields:
		_refresh_editor_fields()
	if refresh_preview:
		_refresh_preview_scene(preview_grip_resolve_reason)
	if refresh_summary:
		_refresh_summary(status_message)

func _manual_save_active_editor_state() -> void:
	if manual_save_in_progress:
		return
	var draft: Resource = _get_active_draft()
	if active_wip == null or active_wip_library == null or draft == null:
		if footer_status_label != null:
			footer_status_label.text = "No active skill draft to save."
		return
	if chain_player.is_playing():
		if footer_status_label != null:
			footer_status_label.text = "Stop preview playback before saving."
		return
	if not _active_draft_requires_manual_save(draft):
		_refresh_manual_save_controls(draft)
		_set_manual_save_progress(100.0, "Already saved. Preview ready.", true)
		if footer_status_label != null:
			footer_status_label.text = "Already saved. Preview ready."
		return
	manual_save_in_progress = true
	manual_save_start_msec = Time.get_ticks_msec()
	_refresh_manual_save_controls(draft)
	_set_manual_save_progress(5.0, "Preparing save...")
	await get_tree().process_frame
	if motion_node_editor.is_dragging():
		motion_node_editor.end_drag()
	_finalize_preview_drag("")
	draft = _get_active_draft()
	if draft == null:
		manual_save_in_progress = false
		_set_manual_save_progress(0.0, "", false)
		_refresh_manual_save_controls()
		if footer_status_label != null:
			footer_status_label.text = "No active skill draft to save."
		return
	_set_manual_save_progress(20.0, "Refreshing authoring data...")
	active_wip.ensure_combat_animation_station_state()
	_refresh_active_station_retarget_authoring_snapshot()
	await get_tree().process_frame
	_set_manual_save_progress(45.0, "Building preview cache...")
	var cache_result: Dictionary = _refresh_active_draft_runtime_clip_cache()
	await get_tree().process_frame
	_set_manual_save_progress(85.0, "Writing save file...")
	_persist_active_wip("", PERSIST_RUNTIME_CACHE_KEEP, false)
	await get_tree().process_frame
	manual_save_in_progress = false
	var elapsed_seconds: float = float(Time.get_ticks_msec() - manual_save_start_msec) / 1000.0
	var cache_ready: bool = bool(cache_result.get("cached", false))
	var completion_text: String = (
		"Saved in %.2fs. Preview ready." % elapsed_seconds
		if cache_ready
		else "Saved in %.2fs. Preview cache needs review: %s" % [elapsed_seconds, String(cache_result.get("reason", "unknown"))]
	)
	_set_manual_save_progress(100.0, completion_text, true)
	editor_state_dirty = false
	_refresh_manual_save_controls(draft)
	_refresh_editor_fields()
	_refresh_summary(completion_text)
	if footer_status_label != null:
		footer_status_label.text = completion_text

func _set_manual_save_progress(percent: float, status_text: String = "", visible: bool = true) -> void:
	if save_progress_bar != null:
		save_progress_bar.visible = visible
		save_progress_bar.value = clampf(percent, 0.0, 100.0)
	if save_progress_label != null:
		save_progress_label.visible = visible
		save_progress_label.text = status_text

func _append_perf_trace_elapsed(trace: Array, label: String, start_usec: int) -> int:
	var now_usec: int = Time.get_ticks_usec()
	trace.append("%s_ms=%.3f" % [label, float(now_usec - start_usec) / 1000.0])
	return now_usec

func _reset_preview_drag_authority_state() -> void:
	preview_drag_pommel_authority_pending = false
	preview_drag_pommel_requested_local = Vector3.ZERO
	preview_drag_pommel_requested_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	preview_drag_pommel_has_solved_request = false
	preview_drag_pommel_last_solved_request_local = Vector3.ZERO
	preview_drag_pommel_last_solved_request_origin_id = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	preview_drag_pommel_last_solve_legal = true
	preview_drag_pommel_last_validation_result = {}

func _invalidate_preview_drag_motion_chain_cache() -> void:
	preview_drag_chain_cache_draft = null
	preview_drag_chain_cache_selected_index = -1
	preview_drag_effective_motion_node_chain_cache = []
	preview_drag_visible_motion_node_chain_cache = []
	preview_drag_visible_selected_node_index_cache = -1

func _ensure_preview_drag_motion_chain_cache() -> Dictionary:
	if preview_drag_override_node == null:
		return {}
	var draft: Resource = _get_active_draft()
	var selected_node_index: int = get_selected_motion_node_index()
	if (
		preview_drag_chain_cache_draft == draft
		and preview_drag_chain_cache_selected_index == selected_node_index
		and not preview_drag_effective_motion_node_chain_cache.is_empty()
		and not preview_drag_visible_motion_node_chain_cache.is_empty()
	):
		return {
			"effective_motion_node_chain": preview_drag_effective_motion_node_chain_cache,
			"visible_motion_node_chain": preview_drag_visible_motion_node_chain_cache,
			"visible_selected_node_index": preview_drag_visible_selected_node_index_cache,
		}
	if draft == null:
		_invalidate_preview_drag_motion_chain_cache()
		return {}
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.is_empty():
		_invalidate_preview_drag_motion_chain_cache()
		return {}
	var resolved_index: int = clampi(selected_node_index, 0, motion_node_chain.size() - 1)
	var effective_chain: Array = motion_node_chain.duplicate()
	effective_chain[resolved_index] = preview_drag_override_node
	var visible_chain: Array = preview_presenter.call("_build_visible_motion_node_chain", draft, effective_chain) as Array
	var visible_selected_index: int = int(preview_presenter.call(
		"_resolve_visible_selected_motion_node_index",
		draft,
		selected_node_index,
		visible_chain.size()
	))
	preview_drag_chain_cache_draft = draft
	preview_drag_chain_cache_selected_index = selected_node_index
	preview_drag_effective_motion_node_chain_cache = effective_chain
	preview_drag_visible_motion_node_chain_cache = visible_chain
	preview_drag_visible_selected_node_index_cache = visible_selected_index
	return {
		"effective_motion_node_chain": preview_drag_effective_motion_node_chain_cache,
		"visible_motion_node_chain": preview_drag_visible_motion_node_chain_cache,
		"visible_selected_node_index": preview_drag_visible_selected_node_index_cache,
	}

func _clear_preview_drag_override() -> void:
	preview_drag_override_node = null
	preview_drag_has_moved = false
	preview_drag_refresh_pending = false
	preview_drag_last_refresh_msec = 0
	preview_drag_first_pending_msec = 0
	preview_drag_last_refresh_cost_msec = 0
	_reset_preview_drag_authority_state()
	_invalidate_preview_drag_motion_chain_cache()

func _begin_preview_drag_override(source_motion_node: CombatAnimationMotionNode) -> void:
	if source_motion_node == null:
		preview_drag_override_node = null
		preview_drag_has_moved = false
		preview_drag_refresh_pending = false
		preview_drag_last_refresh_msec = 0
		preview_drag_first_pending_msec = 0
		preview_drag_last_refresh_cost_msec = 0
		_reset_preview_drag_authority_state()
		_invalidate_preview_drag_motion_chain_cache()
		return
	preview_drag_override_node = source_motion_node.duplicate(true) as CombatAnimationMotionNode
	preview_drag_has_moved = false
	preview_drag_refresh_pending = false
	preview_drag_last_refresh_msec = 0
	preview_drag_first_pending_msec = 0
	preview_drag_last_refresh_cost_msec = 0
	_reset_preview_drag_authority_state()
	_invalidate_preview_drag_motion_chain_cache()
	if preview_drag_override_node != null:
		preview_drag_override_node.normalize()

func _get_effective_preview_motion_node() -> CombatAnimationMotionNode:
	if preview_drag_override_node != null:
		return preview_drag_override_node
	return _get_active_motion_node()

func _build_authoring_motion_node_baseline(source_motion_node: CombatAnimationMotionNode) -> CombatAnimationMotionNode:
	if source_motion_node == null:
		return null
	var display_motion_node: CombatAnimationMotionNode = _build_display_motion_node_for_viewport_pick(source_motion_node)
	if display_motion_node != null:
		return display_motion_node
	var fallback_motion_node: CombatAnimationMotionNode = source_motion_node.duplicate_node()
	if fallback_motion_node != null:
		fallback_motion_node.normalize()
	return fallback_motion_node

func _build_motion_node_segment_baseline_for_direct_edit(source_motion_node: CombatAnimationMotionNode) -> CombatAnimationMotionNode:
	if source_motion_node == null:
		return null
	if not _is_noncombat_idle_draft(_get_active_draft()):
		return _build_authoring_motion_node_baseline(source_motion_node)
	var stored_motion_node: CombatAnimationMotionNode = source_motion_node.duplicate_node()
	if stored_motion_node != null:
		stored_motion_node.normalize()
	return stored_motion_node

func _build_display_motion_node_for_viewport_pick(source_motion_node: CombatAnimationMotionNode) -> CombatAnimationMotionNode:
	if source_motion_node == null:
		return null
	var display_motion_node: CombatAnimationMotionNode = source_motion_node.duplicate(true) as CombatAnimationMotionNode
	if display_motion_node == null:
		return source_motion_node
	var preview_root: Node3D = _get_preview_root()
	if preview_root == null:
		display_motion_node.normalize()
		return display_motion_node
	if not _preview_display_meta_matches_selected_motion_node(preview_root):
		display_motion_node.normalize()
		return display_motion_node
	if preview_root.has_meta("display_selected_tip_position_local"):
		display_motion_node.tip_position_origin_id = _resolve_origin_meta_value(
			preview_root,
			"display_selected_tip_position_origin_id",
			display_motion_node.tip_position_origin_id
		)
		display_motion_node.tip_position_local = _get_origin_tracked_vector3_meta(
			preview_root,
			"display_selected_tip_position_local",
			"display_selected_tip_position_origin_id",
			display_motion_node.tip_position_local,
			display_motion_node.tip_position_origin_id
		)
	if preview_root.has_meta("display_selected_pommel_position_local"):
		display_motion_node.pommel_position_origin_id = _resolve_origin_meta_value(
			preview_root,
			"display_selected_pommel_position_origin_id",
			display_motion_node.pommel_position_origin_id
		)
		display_motion_node.pommel_position_local = _get_origin_tracked_vector3_meta(
			preview_root,
			"display_selected_pommel_position_local",
			"display_selected_pommel_position_origin_id",
			display_motion_node.pommel_position_local,
			display_motion_node.pommel_position_origin_id
		)
	var draft: Resource = _get_active_draft()
	if draft != null:
		var visible_chain: Array = _get_visible_motion_node_chain_for_draft(draft)
		var visible_index: int = get_selected_motion_node_index() - _get_user_visible_motion_node_start_index(draft)
		if visible_index >= 0 and visible_index < visible_chain.size():
			visible_chain = visible_chain.duplicate()
			visible_chain[visible_index] = display_motion_node
			motion_node_editor.apply_effective_curve_handles_to_motion_node(display_motion_node, visible_chain, visible_index)
	display_motion_node.normalize()
	return display_motion_node

func _preview_display_meta_matches_selected_motion_node(preview_root: Node3D) -> bool:
	if preview_root == null or not preview_root.has_meta("selected_motion_node_index"):
		return false
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	var selected_index: int = get_selected_motion_node_index()
	var expected_visible_index: int = selected_index - _get_user_visible_motion_node_start_index(draft)
	return int(preview_root.get_meta("selected_motion_node_index", -999)) == expected_visible_index

func _get_visible_motion_node_chain_for_draft(draft: Resource) -> Array:
	if draft == null:
		return []
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	var visible_start_index: int = _get_user_visible_motion_node_start_index(draft)
	var visible_chain: Array = []
	for node_index: int in range(visible_start_index, motion_node_chain.size()):
		visible_chain.append(motion_node_chain[node_index])
	return visible_chain

func _synchronize_motion_node_derived_segment(motion_node: CombatAnimationMotionNode) -> bool:
	if motion_node == null:
		return false
	# Authored endpoints are now the editor truth. Grip/contact legality belongs
	# to playback/validation, not to silently rewriting motion-node positions.
	motion_node.normalize()
	return false

func _reseat_motion_node_grip_to_occupied_contact(motion_node: CombatAnimationMotionNode) -> bool:
	if motion_node == null:
		return false
	var resolved_segment: Dictionary = preview_presenter.reseat_motion_node_grip_to_occupied_contact(
		preview_subviewport,
		active_wip,
		motion_node
	)
	return _apply_resolved_segment_to_motion_node(motion_node, resolved_segment)

func _recenter_active_noncombat_stow_segment() -> bool:
	var draft: Resource = _get_active_draft()
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if draft == null or motion_node == null or not _is_noncombat_idle_draft(draft):
		return false
	var contact_ratio: float = _resolve_active_noncombat_stow_contact_ratio()
	var current_axis: Vector3 = _resolve_motion_node_axis_or_default(motion_node)
	var resolved_segment: Dictionary = _build_noncombat_stow_segment_from_axis(
		Vector3.ZERO,
		current_axis,
		contact_ratio
	)
	var changed: bool = _apply_resolved_segment_to_motion_node(motion_node, resolved_segment)
	if changed:
		motion_node.normalize()
		editor_state_dirty = true
	return changed

func _resolve_active_noncombat_stow_contact_ratio() -> float:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return CombatAnimationDraftScript.DEFAULT_STOW_CONTACT_RATIO
	return CombatAnimationDraftScript.normalize_stow_contact_ratio(float(draft.get("stow_contact_ratio")))

func _resolve_motion_node_axis_or_default(motion_node: CombatAnimationMotionNode) -> Vector3:
	if motion_node != null:
		var axis: Vector3 = motion_node.tip_position_local - motion_node.pommel_position_local
		if axis.length_squared() > 0.000001:
			return axis.normalized()
	return Vector3.FORWARD

func _build_noncombat_stow_segment_from_axis(
	pivot_position_local: Vector3,
	axis_direction: Vector3,
	contact_ratio: float,
	pivot_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
) -> Dictionary:
	var resolved_pivot_origin_id: StringName = _normalize_seed_origin_id(pivot_position_origin_id, CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	var resolved_axis: Vector3 = axis_direction.normalized() if axis_direction.length_squared() > 0.000001 else Vector3.FORWARD
	var resolved_ratio: float = CombatAnimationDraftScript.normalize_stow_contact_ratio(contact_ratio)
	var weapon_total_length: float = maxf(_get_active_weapon_total_length(), 0.01)
	return {
		"pivot_position_origin_id": resolved_pivot_origin_id,
		"tip_position_local": pivot_position_local + resolved_axis * weapon_total_length * (1.0 - resolved_ratio),
		"tip_position_origin_id": resolved_pivot_origin_id,
		"pommel_position_local": pivot_position_local - resolved_axis * weapon_total_length * resolved_ratio,
		"pommel_position_origin_id": resolved_pivot_origin_id,
		"progress": 1.0,
	}

func _resolve_noncombat_stow_segment_for_tip_target(
	motion_node: CombatAnimationMotionNode,
	requested_tip_position_local: Vector3,
	requested_tip_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
) -> Dictionary:
	if motion_node == null:
		return {}
	var resolved_requested_tip_origin_id: StringName = _normalize_seed_origin_id(requested_tip_position_origin_id, CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	var contact_ratio: float = _resolve_active_noncombat_stow_contact_ratio()
	var pivot_position: Vector3 = motion_node.pommel_position_local.lerp(motion_node.tip_position_local, contact_ratio)
	var requested_axis: Vector3 = requested_tip_position_local - pivot_position
	if requested_axis.length_squared() <= 0.000001:
		requested_axis = _resolve_motion_node_axis_or_default(motion_node)
	return _build_noncombat_stow_segment_from_axis(pivot_position, requested_axis, contact_ratio, resolved_requested_tip_origin_id)

func _resolve_noncombat_stow_segment_for_pommel_target(
	motion_node: CombatAnimationMotionNode,
	requested_pommel_position_local: Vector3,
	requested_pommel_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
) -> Dictionary:
	if motion_node == null:
		return {}
	var resolved_requested_pommel_origin_id: StringName = _normalize_seed_origin_id(requested_pommel_position_origin_id, CombatOriginRecordScript.ORIGIN_STOW_ANCHOR)
	var contact_ratio: float = _resolve_active_noncombat_stow_contact_ratio()
	var pivot_position: Vector3 = motion_node.pommel_position_local.lerp(motion_node.tip_position_local, contact_ratio)
	var requested_axis: Vector3 = pivot_position - requested_pommel_position_local
	if requested_axis.length_squared() <= 0.000001:
		requested_axis = _resolve_motion_node_axis_or_default(motion_node)
	return _build_noncombat_stow_segment_from_axis(pivot_position, requested_axis, contact_ratio, resolved_requested_pommel_origin_id)

func _apply_resolved_segment_to_motion_node(
	motion_node: CombatAnimationMotionNode,
	resolved_segment: Dictionary
) -> bool:
	if motion_node == null:
		return false
	var resolved_tip: Vector3 = resolved_segment.get("tip_position_local", motion_node.tip_position_local) as Vector3
	var resolved_pommel: Vector3 = resolved_segment.get("pommel_position_local", motion_node.pommel_position_local) as Vector3
	var resolved_tip_origin_id: StringName = StringName(resolved_segment.get("tip_position_origin_id", motion_node.tip_position_origin_id))
	var resolved_pommel_origin_id: StringName = StringName(resolved_segment.get("pommel_position_origin_id", motion_node.pommel_position_origin_id))
	var changed: bool = false
	if not motion_node.tip_position_local.is_equal_approx(resolved_tip):
		motion_node.tip_position_local = resolved_tip
		changed = true
	if motion_node.tip_position_origin_id != resolved_tip_origin_id:
		motion_node.tip_position_origin_id = resolved_tip_origin_id
		changed = true
	if not motion_node.pommel_position_local.is_equal_approx(resolved_pommel):
		motion_node.pommel_position_local = resolved_pommel
		changed = true
	if motion_node.pommel_position_origin_id != resolved_pommel_origin_id:
		motion_node.pommel_position_origin_id = resolved_pommel_origin_id
		changed = true
	return changed

func _apply_contact_tether_to_segment(
	motion_node: CombatAnimationMotionNode,
	resolved_segment: Dictionary,
	_tether_mode: StringName = &"translate"
) -> Dictionary:
	if motion_node == null or resolved_segment.is_empty():
		return resolved_segment
	var tip_position: Vector3 = resolved_segment.get("tip_position_local", motion_node.tip_position_local) as Vector3
	var pommel_position: Vector3 = resolved_segment.get("pommel_position_local", motion_node.pommel_position_local) as Vector3
	var constrained_segment: Dictionary = preview_presenter.constrain_authored_segment_to_endpoint_authority(
		preview_subviewport,
		active_wip,
		motion_node,
		tip_position,
		pommel_position
	)
	if not bool(constrained_segment.get("legal", true)):
		constrained_segment["tip_position_local"] = motion_node.tip_position_local
		constrained_segment["pommel_position_local"] = motion_node.pommel_position_local
		constrained_segment["body_clearance_rejected"] = true
	return constrained_segment

func _resolve_motion_node_segment_for_tip_target(
	motion_node: CombatAnimationMotionNode,
	requested_tip_position_local: Vector3,
	apply_endpoint_authority: bool = true,
	requested_tip_position_origin_id: StringName = StringName()
) -> Dictionary:
	if motion_node == null:
		return {}
	if _is_noncombat_idle_draft(_get_active_draft()):
		return _resolve_noncombat_stow_segment_for_tip_target(motion_node, requested_tip_position_local)
	var current_tip_origin_id: StringName = _normalize_seed_origin_id(motion_node.tip_position_origin_id, CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
	var resolved_tip_origin_id: StringName = _normalize_seed_origin_id(requested_tip_position_origin_id, current_tip_origin_id)
	var resolved_pommel_origin_id: StringName = _normalize_seed_origin_id(motion_node.pommel_position_origin_id, resolved_tip_origin_id)
	var constrained_tip: Vector3 = motion_node_editor.constrain_tip_to_sphere(
		motion_node.pommel_position_local,
		requested_tip_position_local,
		_get_active_weapon_total_length()
	)
	var resolved_segment := {
		"tip_position_local": constrained_tip,
		"tip_position_origin_id": resolved_tip_origin_id,
		"pommel_position_local": motion_node.pommel_position_local,
		"pommel_position_origin_id": resolved_pommel_origin_id,
		"progress": 1.0,
	}
	if not apply_endpoint_authority:
		resolved_segment["endpoint_authority_deferred"] = true
		return resolved_segment
	return _apply_contact_tether_to_segment(motion_node, resolved_segment, &"tip_pivot")

func _resolve_motion_node_segment_for_pommel_target(
	motion_node: CombatAnimationMotionNode,
	requested_pommel_position_local: Vector3,
	apply_endpoint_authority: bool = true,
	requested_pommel_position_origin_id: StringName = StringName()
) -> Dictionary:
	if motion_node == null:
		return {}
	if _is_noncombat_idle_draft(_get_active_draft()):
		return _resolve_noncombat_stow_segment_for_pommel_target(motion_node, requested_pommel_position_local)
	var current_pommel_origin_id: StringName = _normalize_seed_origin_id(motion_node.pommel_position_origin_id, CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)
	var resolved_pommel_origin_id: StringName = _normalize_seed_origin_id(requested_pommel_position_origin_id, current_pommel_origin_id)
	var resolved_tip_origin_id: StringName = _normalize_seed_origin_id(motion_node.tip_position_origin_id, resolved_pommel_origin_id)
	var pommel_translation: Vector3 = requested_pommel_position_local - motion_node.pommel_position_local
	var resolved_segment := {
		"tip_position_local": motion_node.tip_position_local + pommel_translation,
		"tip_position_origin_id": resolved_tip_origin_id,
		"pommel_position_local": requested_pommel_position_local,
		"pommel_position_origin_id": resolved_pommel_origin_id,
		"progress": 1.0,
	}
	if not apply_endpoint_authority:
		resolved_segment["endpoint_authority_deferred"] = true
		return resolved_segment
	return _apply_contact_tether_to_segment(motion_node, resolved_segment, &"translate")

func _apply_motion_node_state(target: CombatAnimationMotionNode, source: CombatAnimationMotionNode) -> bool:
	if target == null or source == null:
		return false
	if _is_motion_node_authoring_locked(target):
		if not _can_author_motion_node_curve_handles(target):
			return false
		return _apply_motion_node_curve_handle_state(target, source)
	var stored_source: CombatAnimationMotionNode = _build_stored_motion_node_state_from_preview_state(source)
	var changed: bool = false
	if not target.weapon_orientation_degrees.is_equal_approx(stored_source.weapon_orientation_degrees):
		target.weapon_orientation_degrees = stored_source.weapon_orientation_degrees
		changed = true
	if target.weapon_orientation_authored != stored_source.weapon_orientation_authored:
		target.weapon_orientation_authored = stored_source.weapon_orientation_authored
		changed = true
	if not target.tip_position_local.is_equal_approx(stored_source.tip_position_local):
		target.tip_position_local = stored_source.tip_position_local
		changed = true
	if not target.pommel_position_local.is_equal_approx(stored_source.pommel_position_local):
		target.pommel_position_local = stored_source.pommel_position_local
		changed = true
	if not target.tip_curve_in_handle.is_equal_approx(stored_source.tip_curve_in_handle):
		target.tip_curve_in_handle = stored_source.tip_curve_in_handle
		changed = true
	if not target.tip_curve_out_handle.is_equal_approx(stored_source.tip_curve_out_handle):
		target.tip_curve_out_handle = stored_source.tip_curve_out_handle
		changed = true
	if not target.pommel_curve_in_handle.is_equal_approx(stored_source.pommel_curve_in_handle):
		target.pommel_curve_in_handle = stored_source.pommel_curve_in_handle
		changed = true
	if not target.pommel_curve_out_handle.is_equal_approx(stored_source.pommel_curve_out_handle):
		target.pommel_curve_out_handle = stored_source.pommel_curve_out_handle
		changed = true
	if not is_equal_approx(target.right_upperarm_roll_degrees, stored_source.right_upperarm_roll_degrees):
		target.right_upperarm_roll_degrees = stored_source.right_upperarm_roll_degrees
		changed = true
	if not is_equal_approx(target.left_upperarm_roll_degrees, stored_source.left_upperarm_roll_degrees):
		target.left_upperarm_roll_degrees = stored_source.left_upperarm_roll_degrees
		changed = true
	if target.right_hand_proxy_authored != stored_source.right_hand_proxy_authored:
		target.right_hand_proxy_authored = stored_source.right_hand_proxy_authored
		changed = true
	if not target.right_hand_proxy_tip_position_local.is_equal_approx(stored_source.right_hand_proxy_tip_position_local):
		target.right_hand_proxy_tip_position_local = stored_source.right_hand_proxy_tip_position_local
		changed = true
	if target.right_hand_proxy_tip_position_origin_id != stored_source.right_hand_proxy_tip_position_origin_id:
		target.right_hand_proxy_tip_position_origin_id = stored_source.right_hand_proxy_tip_position_origin_id
		changed = true
	if not target.right_hand_proxy_pommel_position_local.is_equal_approx(stored_source.right_hand_proxy_pommel_position_local):
		target.right_hand_proxy_pommel_position_local = stored_source.right_hand_proxy_pommel_position_local
		changed = true
	if target.right_hand_proxy_pommel_position_origin_id != stored_source.right_hand_proxy_pommel_position_origin_id:
		target.right_hand_proxy_pommel_position_origin_id = stored_source.right_hand_proxy_pommel_position_origin_id
		changed = true
	if target.left_hand_proxy_authored != stored_source.left_hand_proxy_authored:
		target.left_hand_proxy_authored = stored_source.left_hand_proxy_authored
		changed = true
	if not target.left_hand_proxy_tip_position_local.is_equal_approx(stored_source.left_hand_proxy_tip_position_local):
		target.left_hand_proxy_tip_position_local = stored_source.left_hand_proxy_tip_position_local
		changed = true
	if target.left_hand_proxy_tip_position_origin_id != stored_source.left_hand_proxy_tip_position_origin_id:
		target.left_hand_proxy_tip_position_origin_id = stored_source.left_hand_proxy_tip_position_origin_id
		changed = true
	if not target.left_hand_proxy_pommel_position_local.is_equal_approx(stored_source.left_hand_proxy_pommel_position_local):
		target.left_hand_proxy_pommel_position_local = stored_source.left_hand_proxy_pommel_position_local
		changed = true
	if target.left_hand_proxy_pommel_position_origin_id != stored_source.left_hand_proxy_pommel_position_origin_id:
		target.left_hand_proxy_pommel_position_origin_id = stored_source.left_hand_proxy_pommel_position_origin_id
		changed = true
	target.normalize()
	return changed

func _build_stored_motion_node_state_from_preview_state(source: CombatAnimationMotionNode) -> CombatAnimationMotionNode:
	var stored_source: CombatAnimationMotionNode = source.duplicate(true) as CombatAnimationMotionNode if source != null else null
	if stored_source == null:
		return source
	if not _is_noncombat_idle_draft(_get_active_draft()):
		stored_source.normalize()
		return stored_source
	var stow_anchor_offset_local: Vector3 = _resolve_selected_noncombat_stow_anchor_offset_local()
	if stow_anchor_offset_local.length_squared() > 0.000001:
		stored_source.tip_position_local -= stow_anchor_offset_local
		stored_source.pommel_position_local -= stow_anchor_offset_local
	stored_source.tip_position_origin_id = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	stored_source.pommel_position_origin_id = CombatOriginRecordScript.ORIGIN_STOW_ANCHOR
	stored_source.normalize()
	return stored_source

func _resolve_selected_noncombat_stow_anchor_offset_local() -> Vector3:
	var preview_debug_state: Dictionary = get_preview_debug_state()
	var selected_anchor_id: StringName = preview_debug_state.get("selected_stow_anchor_marker_id", StringName()) as StringName
	var marker_positions: Dictionary = preview_debug_state.get("stow_anchor_marker_positions_local", {}) as Dictionary
	var marker_positions_origin_id: StringName = _normalize_seed_origin_id(
		StringName(preview_debug_state.get("stow_anchor_marker_positions_origin_id", CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING)),
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	preview_debug_state["stow_anchor_marker_positions_origin_id"] = marker_positions_origin_id
	if selected_anchor_id == StringName() or not marker_positions.has(selected_anchor_id):
		return Vector3.ZERO
	return marker_positions.get(selected_anchor_id, Vector3.ZERO) as Vector3

func _apply_motion_node_curve_handle_state(target: CombatAnimationMotionNode, source: CombatAnimationMotionNode) -> bool:
	if target == null or source == null:
		return false
	var changed: bool = false
	if not target.tip_curve_in_handle.is_equal_approx(source.tip_curve_in_handle):
		target.tip_curve_in_handle = source.tip_curve_in_handle
		changed = true
	if not target.tip_curve_out_handle.is_equal_approx(source.tip_curve_out_handle):
		target.tip_curve_out_handle = source.tip_curve_out_handle
		changed = true
	if not target.pommel_curve_in_handle.is_equal_approx(source.pommel_curve_in_handle):
		target.pommel_curve_in_handle = source.pommel_curve_in_handle
		changed = true
	if not target.pommel_curve_out_handle.is_equal_approx(source.pommel_curve_out_handle):
		target.pommel_curve_out_handle = source.pommel_curve_out_handle
		changed = true
	target.normalize()
	return changed

func _finalize_preview_drag(status_message: String = "Motion node edit locked in.") -> void:
	if preview_drag_override_node == null:
		if not status_message.strip_edges().is_empty():
			footer_status_label.text = status_message
		return
	if not preview_drag_has_moved:
		_clear_preview_drag_override()
		if not status_message.strip_edges().is_empty():
			footer_status_label.text = status_message
		return
	if _is_pommel_drag_authority_active():
		_resolve_pending_pommel_drag_authority(true)
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	var preserved_camera_state: Dictionary = preview_presenter.capture_camera_state(preview_subviewport)
	var commit_result: Dictionary = _resolve_preview_drag_commit_motion_node(motion_node)
	if not bool(commit_result.get("legal", true)):
		var validation_result: Dictionary = commit_result.get("validation_result", {}) as Dictionary
		_clear_preview_drag_override()
		_refresh_preview_scene()
		_restore_preview_camera_after_drag_commit(preserved_camera_state)
		_set_preview_drag_blocked_status(validation_result)
		return
	var commit_motion_node: CombatAnimationMotionNode = commit_result.get("motion_node", preview_drag_override_node) as CombatAnimationMotionNode
	var changed: bool = _apply_motion_node_state(motion_node, commit_motion_node)
	_clear_preview_drag_override()
	if changed:
		_stage_active_wip_edit(status_message)
		_refresh_motion_node_list()
		_refresh_editor_fields()
		_refresh_preview_scene()
		_restore_preview_camera_after_drag_commit(preserved_camera_state)
		_refresh_summary(status_message)
	else:
		_restore_preview_camera_after_drag_commit(preserved_camera_state)
		if not status_message.strip_edges().is_empty():
			footer_status_label.text = status_message

func _restore_preview_camera_after_drag_commit(camera_state: Dictionary) -> void:
	if preview_presenter.restore_camera_state(preview_subviewport, camera_state):
		preview_camera_skip_next_orbit_motion = true
		preview_camera_orbit_guard_until_msec = Time.get_ticks_msec() + PREVIEW_CAMERA_POST_COMMIT_MOTION_GUARD_MSEC

func _should_suppress_post_commit_camera_motion() -> bool:
	if not preview_camera_skip_next_orbit_motion:
		return false
	var now_msec: int = Time.get_ticks_msec()
	if now_msec > preview_camera_orbit_guard_until_msec:
		preview_camera_skip_next_orbit_motion = false
		preview_camera_orbit_guard_until_msec = 0
		return false
	preview_camera_skip_next_orbit_motion = false
	preview_camera_orbit_guard_until_msec = 0
	return true

func _resolve_preview_drag_commit_motion_node(source_motion_node: CombatAnimationMotionNode) -> Dictionary:
	if source_motion_node == null or preview_drag_override_node == null:
		return {"legal": true, "motion_node": preview_drag_override_node}
	var proposed_motion_node: CombatAnimationMotionNode = preview_drag_override_node.duplicate(true) as CombatAnimationMotionNode
	if proposed_motion_node == null:
		return {"legal": true, "motion_node": preview_drag_override_node}
	proposed_motion_node.normalize()
	if _is_motion_node_authoring_locked(source_motion_node):
		return {"legal": true, "motion_node": proposed_motion_node}
	var endpoint_or_orientation_changed: bool = (
		not source_motion_node.tip_position_local.is_equal_approx(proposed_motion_node.tip_position_local)
		or not source_motion_node.pommel_position_local.is_equal_approx(proposed_motion_node.pommel_position_local)
		or not source_motion_node.weapon_orientation_degrees.is_equal_approx(proposed_motion_node.weapon_orientation_degrees)
		or source_motion_node.weapon_orientation_authored != proposed_motion_node.weapon_orientation_authored
	)
	if not endpoint_or_orientation_changed:
		return {"legal": true, "motion_node": proposed_motion_node}
	if _is_noncombat_idle_draft(_get_active_draft()):
		return {"legal": true, "motion_node": proposed_motion_node}
	if _can_reuse_pommel_drag_authority_commit():
		return {
			"legal": true,
			"motion_node": proposed_motion_node,
			"validation_result": preview_drag_pommel_last_validation_result,
			"reused_drag_authority": true,
		}
	var validation_result: Dictionary = preview_presenter.constrain_authored_segment_to_endpoint_authority(
		preview_subviewport,
		active_wip,
		proposed_motion_node,
		proposed_motion_node.tip_position_local,
		proposed_motion_node.pommel_position_local
	)
	if not bool(validation_result.get("legal", true)):
		return {
			"legal": false,
			"motion_node": proposed_motion_node,
			"validation_result": validation_result,
		}
	_apply_resolved_segment_to_motion_node(proposed_motion_node, validation_result)
	proposed_motion_node.normalize()
	return {
		"legal": true,
		"motion_node": proposed_motion_node,
		"validation_result": validation_result,
	}

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
	var new_node: CombatAnimationMotionNode = null
	if source_node != null:
		new_node = source_node.duplicate_node()
	else:
		new_node = CombatAnimationMotionNodeScript.new()
		var geometry_seed: Dictionary = _resolve_active_weapon_authored_baseline_seed()
		_apply_motion_seed_to_motion_node(new_node, geometry_seed)
	if new_node != null:
		new_node.generated_transition_node = false
		new_node.generated_transition_kind = CombatAnimationMotionNodeScript.TRANSITION_KIND_NONE
		new_node.locked_for_authoring = false
		new_node.normalize()
	return new_node

func _prepare_inserted_motion_node_identity(motion_node: CombatAnimationMotionNode) -> void:
	if motion_node == null:
		return
	# Draft normalization will assign the node id from the final inserted index.
	motion_node.node_id = StringName()

func _apply_grip_axis_default_orientation(motion_node: CombatAnimationMotionNode) -> void:
	if active_wip == null or motion_node == null:
		return
	var geometry_seed: Dictionary = _resolve_active_weapon_authored_baseline_seed()
	if geometry_seed.is_empty():
		return
	if not motion_node.weapon_orientation_authored:
		motion_node.weapon_orientation_degrees = geometry_seed.get(
			"weapon_orientation_degrees",
			motion_node.weapon_orientation_degrees
		) as Vector3
	motion_node.normalize()

func _apply_motion_seed_to_motion_node(
	motion_node: CombatAnimationMotionNode,
	geometry_seed: Dictionary
) -> void:
	if motion_node == null or geometry_seed.is_empty():
		return
	var seed_tip_origin_id: StringName = _resolve_seed_origin_id(
		geometry_seed,
		"tip_position_origin_id",
		motion_node.tip_position_origin_id
	)
	motion_node.tip_position_local = _get_origin_tracked_seed_vector3(
		geometry_seed,
		"tip_position_local",
		"tip_position_origin_id",
		motion_node.tip_position_local,
		seed_tip_origin_id
	)
	motion_node.tip_position_origin_id = seed_tip_origin_id
	var seed_pommel_origin_id: StringName = _resolve_seed_origin_id(
		geometry_seed,
		"pommel_position_origin_id",
		motion_node.pommel_position_origin_id
	)
	motion_node.pommel_position_local = _get_origin_tracked_seed_vector3(
		geometry_seed,
		"pommel_position_local",
		"pommel_position_origin_id",
		motion_node.pommel_position_local,
		seed_pommel_origin_id
	)
	motion_node.pommel_position_origin_id = seed_pommel_origin_id
	if not motion_node.weapon_orientation_authored:
		motion_node.weapon_orientation_degrees = geometry_seed.get(
			"weapon_orientation_degrees",
			motion_node.weapon_orientation_degrees
		) as Vector3
		motion_node.weapon_orientation_authored = bool(geometry_seed.get(
			"weapon_orientation_authored",
			motion_node.weapon_orientation_authored
		))
	motion_node.weapon_roll_degrees = float(geometry_seed.get("weapon_roll_degrees", motion_node.weapon_roll_degrees))
	motion_node.axial_reposition_offset = float(geometry_seed.get("axial_reposition_offset", motion_node.axial_reposition_offset))
	motion_node.grip_seat_slide_offset = float(geometry_seed.get("grip_seat_slide_offset", motion_node.grip_seat_slide_offset))
	motion_node.secondary_grip_seat_slide_offset = float(geometry_seed.get(
		"secondary_grip_seat_slide_offset",
		motion_node.secondary_grip_seat_slide_offset
	))
	motion_node.body_support_blend = float(geometry_seed.get("body_support_blend", motion_node.body_support_blend))
	motion_node.preferred_grip_style_mode = StringName(geometry_seed.get(
		"preferred_grip_style_mode",
		motion_node.preferred_grip_style_mode
	))
	var resolved_two_hand_state: StringName = StringName(geometry_seed.get("two_hand_state", motion_node.two_hand_state))
	if CombatAnimationMotionNode.get_two_hand_state_ids().has(resolved_two_hand_state):
		motion_node.two_hand_state = resolved_two_hand_state
	var resolved_primary_hand_slot: StringName = CombatAnimationMotionNodeScript.normalize_primary_hand_slot(StringName(geometry_seed.get(
		"primary_hand_slot",
		motion_node.primary_hand_slot
	)))
	motion_node.primary_hand_slot = resolved_primary_hand_slot
	motion_node.normalize()

func _normalize_draft(draft: Resource) -> void:
	if draft == null:
		return
	if draft.has_method("normalize"):
		draft.call("normalize")

func _find_skill_draft_by_slot_id(slot_id: StringName) -> Resource:
	if slot_id == StringName():
		return null
	var station_state: Resource = _get_active_station_state()
	if station_state == null:
		return null
	var skill_drafts: Array = station_state.get("skill_drafts") as Array
	for draft_variant: Variant in skill_drafts:
		var draft: Resource = draft_variant as Resource
		if draft == null:
			continue
		if StringName(draft.get("legal_slot_id")) == slot_id:
			return draft
		if StringName(draft.get("owning_skill_id")) == slot_id:
			return draft
	return null

func _find_first_unassigned_skill_slot_id() -> StringName:
	for slot_id: StringName in CombatAnimationStationStateScript.get_authoring_skill_slot_ids():
		if _find_skill_draft_by_slot_id(slot_id) == null:
			return slot_id
	return StringName()

func _get_active_skill_slot_id() -> StringName:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return StringName()
	var slot_id: StringName = StringName(draft.get("legal_slot_id"))
	if slot_id != StringName():
		return slot_id
	var owning_skill_id: StringName = StringName(draft.get("owning_skill_id"))
	return owning_skill_id if _is_authoring_skill_slot_id(owning_skill_id) else StringName()

func _is_authoring_skill_slot_id(slot_id: StringName) -> bool:
	return CombatAnimationStationStateScript.get_authoring_skill_slot_ids().has(slot_id)

func _get_skill_slot_action_name(slot_id: StringName) -> StringName:
	if slot_id == PlayerSkillSlotStateScript.BLOCK_SLOT_ID:
		return &"skill_block"
	return slot_id

func _get_skill_slot_display_name(slot_id: StringName) -> String:
	var action_name: StringName = _get_skill_slot_action_name(slot_id)
	var display_name: String = UserSettingsRuntimeScript.get_action_display_name(action_name)
	if not display_name.strip_edges().is_empty():
		return display_name
	var slot_text: String = String(slot_id).replace("_", " ").strip_edges()
	return slot_text.capitalize() if not slot_text.is_empty() else "Skill Slot"

func _get_skill_slot_binding_label(slot_id: StringName) -> String:
	return UserSettingsRuntimeScript.get_action_binding_label(_get_skill_slot_action_name(slot_id))

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

func _append_contact_ray_summary_lines(lines: PackedStringArray, label: String, ray_entries: Array) -> void:
	if ray_entries.is_empty():
		lines.append("%s Contact Rays: none yet" % label)
		return
	var last_entry: Dictionary = {}
	var first_hit_entry: Dictionary = {}
	var hit_count: int = 0
	for entry_variant: Variant in ray_entries:
		var entry: Dictionary = entry_variant as Dictionary
		if not entry.is_empty():
			last_entry = entry
		if bool(entry.get("hit", false)):
			hit_count += 1
			if first_hit_entry.is_empty():
				first_hit_entry = entry
	var last_context: String = String(last_entry.get("context", ""))
	var last_finger: String = String(last_entry.get("finger_id", ""))
	var last_mask: int = int(last_entry.get("collision_mask", 0))
	lines.append("%s Contact Rays: %d cast | %d hit | last %s:%s mask %d" % [
		label,
		ray_entries.size(),
		hit_count,
		last_context,
		last_finger,
		last_mask,
	])
	if first_hit_entry.is_empty():
		lines.append("%s Contact Hit: none" % label)
	else:
		var hit_name: String = String(first_hit_entry.get("collider_name", ""))
		var hit_path: String = String(first_hit_entry.get("collider_path", ""))
		var hit_layer: int = int(first_hit_entry.get("collider_layer", -1))
		lines.append("%s Contact Hit: %s layer %d" % [
			label,
			hit_name if not hit_name.is_empty() else hit_path,
			hit_layer,
		])

func _on_project_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	project_list.select(index)
	if _mouse_button_index == MOUSE_BUTTON_RIGHT:
		_show_weapon_open_primary_popup_for_index(index)
		return
	if _mouse_button_index == MOUSE_BUTTON_LEFT:
		_hide_weapon_open_popups()
		footer_status_label.text = "Double-click to open with class defaults, or right-click to choose the hand setup."

func _on_project_item_activated(index: int) -> void:
	var saved_wip: CraftedItemWIP = _resolve_saved_wip_from_list_index(index)
	if saved_wip == null:
		return
	_hide_weapon_open_popups()
	var default_open_config: Dictionary = _build_default_weapon_open_config(saved_wip)
	open_saved_wip_with_hand_setup(
		saved_wip.wip_id,
		StringName(default_open_config.get("dominant_slot_id", HAND_SLOT_RIGHT)),
		bool(default_open_config.get("use_two_hand", false))
	)

func _on_weapon_open_primary_popup_id_pressed(item_id: int) -> void:
	match item_id:
		WEAPON_OPEN_PRIMARY_MENU_ID_LEFT:
			_show_weapon_open_variant_popup(HAND_SLOT_LEFT)
		WEAPON_OPEN_PRIMARY_MENU_ID_RIGHT:
			_show_weapon_open_variant_popup(HAND_SLOT_RIGHT)

func _on_weapon_open_primary_popup_hide() -> void:
	if weapon_open_variant_popup != null and weapon_open_variant_popup.visible:
		weapon_open_variant_popup.hide()
	if weapon_open_variant_popup != null and not weapon_open_variant_popup.visible:
		pending_weapon_open_wip_id = StringName()
		pending_weapon_open_primary_slot_id = HAND_SLOT_RIGHT

func _on_weapon_open_variant_popup_id_pressed(item_id: int) -> void:
	if pending_weapon_open_wip_id == StringName():
		return
	var use_two_hand: bool = (
		item_id == WEAPON_OPEN_VARIANT_MENU_ID_TWO_HAND
		and not _is_unarmed_authoring_wip_id(pending_weapon_open_wip_id)
	)
	open_saved_wip_with_hand_setup(
		pending_weapon_open_wip_id,
		pending_weapon_open_primary_slot_id,
		use_two_hand
	)
	_hide_weapon_open_popups()

func _on_weapon_open_variant_popup_hide() -> void:
	if weapon_open_primary_popup != null and not weapon_open_primary_popup.visible:
		pending_weapon_open_wip_id = StringName()
		pending_weapon_open_primary_slot_id = HAND_SLOT_RIGHT

func _on_draft_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var draft_identifier: StringName = draft_list.get_item_metadata(index)
	select_draft(draft_identifier)

func _on_skill_slot_selector_pressed(slot_id: StringName) -> void:
	select_skill_slot(slot_id)

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

func _on_reset_draft_pressed() -> void:
	reset_active_draft_to_baseline()

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
	if refreshing_controls or not skill_slot_edit.editable:
		return
	set_active_draft_slot_id(StringName(new_text.strip_edges()))

func _on_skill_slot_focus_exited() -> void:
	if refreshing_controls or not skill_slot_edit.editable:
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

func _on_speed_acceleration_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_active_draft_speed_acceleration_percent(value)

func _on_speed_deceleration_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_active_draft_speed_deceleration_percent(value)

func _on_stow_anchor_selected(index: int) -> void:
	if refreshing_controls:
		return
	var stow_mode: StringName = stow_anchor_option_button.get_item_metadata(index)
	set_active_draft_stow_anchor_mode(stow_mode)

func _on_stow_contact_ratio_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_active_draft_stow_contact_ratio(value)

func _on_tip_position_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	var position_value: Vector3 = Vector3(position_x_spin_box.value, position_y_spin_box.value, position_z_spin_box.value)
	if axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_tip_position(position_value, false)

func _on_weapon_orientation_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	var orientation_value: Vector3 = Vector3(weapon_rotation_x_spin_box.value, weapon_rotation_y_spin_box.value, weapon_rotation_z_spin_box.value)
	if axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_weapon_orientation(orientation_value, false)

func _on_transition_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_transition_duration(value, false)

func _on_body_support_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_body_support_blend(value, false)

func _on_tip_curve_in_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	if axis_index < 0 or axis_index > 2:
		return
	var handle_value := Vector3(curve_in_x_spin_box.value, curve_in_y_spin_box.value, curve_in_z_spin_box.value)
	set_selected_motion_node_tip_curve_in(handle_value, false)

func _on_tip_curve_out_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls:
		return
	if axis_index < 0 or axis_index > 2:
		return
	var handle_value := Vector3(curve_out_x_spin_box.value, curve_out_y_spin_box.value, curve_out_z_spin_box.value)
	set_selected_motion_node_tip_curve_out(handle_value, false)

func _on_two_hand_state_selected(index: int) -> void:
	if refreshing_controls:
		return
	var state_id: StringName = two_hand_state_option_button.get_item_metadata(index)
	set_selected_motion_node_two_hand_state(state_id, false)

func _on_primary_hand_selected(index: int) -> void:
	if refreshing_controls:
		return
	var slot_id: StringName = primary_hand_option_button.get_item_metadata(index)
	set_selected_motion_node_primary_hand_slot(slot_id, false)

func _on_grip_mode_selected(index: int) -> void:
	if refreshing_controls:
		return
	var grip_mode: StringName = grip_mode_option_button.get_item_metadata(index)
	set_selected_motion_node_preferred_grip_style(grip_mode, false)

func _on_draft_notes_focus_exited() -> void:
	if refreshing_controls:
		return
	set_active_draft_notes(draft_notes_edit.text)

func _on_preview_container_resized() -> void:
	_refresh_preview_scene()

func _register_station_input_actions() -> void:
	UserSettingsRuntimeScript.ensure_input_actions(UserSettingsStateScript.load_or_create())

func _navigate_motion_node(direction: int) -> void:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return
	var current_index: int = int(draft.get("selected_motion_node_index"))
	var chain_size: int = int((draft.get("motion_node_chain") as Array).size())
	if chain_size <= 0:
		return
	var minimum_index: int = _get_user_visible_motion_node_start_index(draft)
	var new_index: int = clampi(current_index + direction, minimum_index, chain_size - 1)
	if new_index != current_index:
		select_motion_node(new_index)

func _cycle_focus() -> void:
	session_state.cycle_focus(_resolve_available_focus_ids())
	_refresh_focus_indicators()
	preview_presenter.refresh_focus_visuals(
		preview_view_container,
		preview_subviewport,
		_get_active_draft(),
		get_selected_motion_node_index(),
		session_state.current_focus,
		_get_active_baked_profile()
	)
	footer_status_label.text = "Active focus: %s" % _get_focus_display_name(session_state.current_focus)

func _refresh_focus_indicators() -> void:
	_ensure_current_focus_available()
	var tip_active: bool = session_state.is_tip_focused()
	var pommel_active: bool = session_state.is_pommel_focused()
	var weapon_active: bool = session_state.is_weapon_focused()
	var right_arm_roll_active: bool = session_state.current_focus == CombatAnimationSessionStateScript.FOCUS_RIGHT_ARM_ROLL or session_state.current_focus == CombatAnimationSessionStateScript.FOCUS_ARM_ROLL
	var left_arm_roll_active: bool = session_state.current_focus == CombatAnimationSessionStateScript.FOCUS_LEFT_ARM_ROLL
	var arm_roll_active: bool = right_arm_roll_active or left_arm_roll_active
	if tip_section_foldable != null:
		tip_section_foldable.title = "TIP POSITION [ACTIVE]" if tip_active else "TIP POSITION"
		tip_section_foldable.add_theme_color_override("font_color", COLOR_TEXT_TITLE if tip_active else COLOR_TEXT_HEADER)
	if pommel_section_foldable != null:
		pommel_section_foldable.title = "POMMEL POSITION [ACTIVE]" if pommel_active else "POMMEL POSITION"
		pommel_section_foldable.add_theme_color_override("font_color", COLOR_TEXT_TITLE if pommel_active else COLOR_TEXT_HEADER)
	if weapon_section_foldable != null:
		weapon_section_foldable.title = "WEAPON ORIENTATION [ACTIVE]" if weapon_active else "WEAPON ORIENTATION"
		weapon_section_foldable.add_theme_color_override("font_color", COLOR_TEXT_TITLE if weapon_active else COLOR_TEXT_HEADER)
	if arm_roll_section_foldable != null:
		var arm_title: String = "UPPER ARM ROLL"
		if right_arm_roll_active:
			arm_title = "UPPER ARM ROLL [RIGHT ACTIVE]"
		elif left_arm_roll_active:
			arm_title = "UPPER ARM ROLL [LEFT ACTIVE]"
		arm_roll_section_foldable.title = arm_title
		arm_roll_section_foldable.add_theme_color_override("font_color", COLOR_TEXT_TITLE if arm_roll_active else COLOR_TEXT_HEADER)

func _resolve_available_focus_ids() -> Array[StringName]:
	var focus_ids: Array[StringName] = [
		CombatAnimationSessionStateScript.FOCUS_TIP,
		CombatAnimationSessionStateScript.FOCUS_POMMEL,
		CombatAnimationSessionStateScript.FOCUS_WEAPON,
		CombatAnimationSessionStateScript.FOCUS_RIGHT_ARM_ROLL,
		CombatAnimationSessionStateScript.FOCUS_LEFT_ARM_ROLL,
	]
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	for slot_id: StringName in _resolve_available_hand_proxy_slots(motion_node):
		focus_ids.append(
			CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY
			if slot_id == HAND_SLOT_LEFT
			else CombatAnimationSessionStateScript.FOCUS_RIGHT_HAND_PROXY
		)
	return focus_ids

func _ensure_current_focus_available() -> void:
	var focus_ids: Array[StringName] = _resolve_available_focus_ids()
	if focus_ids.is_empty():
		session_state.current_focus = CombatAnimationSessionStateScript.FOCUS_TIP
		return
	if session_state.current_focus == CombatAnimationSessionStateScript.FOCUS_ARM_ROLL:
		session_state.current_focus = CombatAnimationSessionStateScript.FOCUS_RIGHT_ARM_ROLL
	if not focus_ids.has(session_state.current_focus):
		session_state.current_focus = focus_ids[0]

func _resolve_available_hand_proxy_slots(motion_node: CombatAnimationMotionNode) -> Array[StringName]:
	var slots: Array[StringName] = []
	if motion_node == null:
		return slots
	for slot_id: StringName in [HAND_SLOT_RIGHT, HAND_SLOT_LEFT]:
		if _is_authoring_hand_slot_occupied_by_external_equipment(slot_id):
			continue
		if _is_active_unarmed_authoring_wip():
			slots.append(slot_id)
			continue
		if slot_id == _resolve_active_motion_node_primary_slot_id():
			continue
		if _motion_node_uses_two_hand(motion_node):
			continue
		slots.append(slot_id)
	return slots

func _motion_node_uses_two_hand(motion_node: CombatAnimationMotionNode) -> bool:
	if motion_node == null or _is_active_unarmed_authoring_wip():
		return false
	if motion_node.preferred_grip_style_mode == CraftedItemWIPScript.GRIP_REVERSE:
		return false
	if motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_TWO_HAND:
		return true
	if motion_node.two_hand_state == CombatAnimationMotionNodeScript.TWO_HAND_STATE_ONE_HAND:
		return false
	return active_preview_default_two_hand

func _is_authoring_hand_slot_occupied_by_external_equipment(slot_id: StringName) -> bool:
	if active_player == null or not active_player.has_method("get_equipment_state"):
		return false
	var target_wip_id: StringName = active_saved_wip_id
	if target_wip_id == StringName() and active_wip != null:
		target_wip_id = active_wip.wip_id
	var equipment_state = active_player.call("get_equipment_state")
	if equipment_state == null or not equipment_state.has_method("get_equipped_slots"):
		return false
	var equipped_slots_variant: Variant = equipment_state.call("get_equipped_slots")
	if not (equipped_slots_variant is Array):
		return false
	for equipped_slot_variant: Variant in (equipped_slots_variant as Array):
		var equipped_slot: Resource = equipped_slot_variant as Resource
		if equipped_slot == null:
			continue
		if StringName(equipped_slot.get("slot_id")) != slot_id:
			continue
		var equipped_wip_id: StringName = StringName(equipped_slot.get("source_wip_id"))
		if equipped_wip_id != StringName() and equipped_wip_id != target_wip_id:
			return true
	return false

func _toggle_preview_playback() -> void:
	if chain_player.is_playing():
		chain_player.stop()
		session_state.playback_active = false
		footer_status_label.text = "Preview stopped."
		return
	var draft: Resource = _get_active_draft()
	if draft == null:
		footer_status_label.text = "No active draft to preview."
		return
	var motion_node_chain: Array = draft.get("motion_node_chain") as Array
	if motion_node_chain.size() < 2:
		footer_status_label.text = "Need at least 2 motion nodes to preview."
		return
	var playback_speed: float = float(draft.get("preview_playback_speed_scale"))
	var should_loop: bool = bool(draft.get("preview_loop_enabled"))
	if _active_draft_requires_manual_save(draft):
		_refresh_manual_save_controls(draft)
		footer_status_label.text = "Save current edits before previewing."
		return
	if not _prepare_cached_preview_playback(draft, playback_speed, should_loop):
		_refresh_manual_save_controls(draft)
		footer_status_label.text = "Preview cache is missing or stale. Save current edits before previewing."
		return
	chain_player.start()
	session_state.playback_active = true
	_sync_preview_playback_pose_only()
	footer_status_label.text = "Preview playing... (F to stop)"

func _build_preview_runtime_motion_chain(motion_node_chain: Array, trajectory_volume_config: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"compiled": false,
		"motion_node_chain": motion_node_chain,
		"diagnostics": [],
		"degraded_node_count": 0,
		"hand_swap_bridge_count": 0,
		"retargeted_count": 0,
	}
	if runtime_chain_compiler == null or motion_node_chain.size() < 2:
		return result
	var dominant_slot_id: StringName = active_preview_dominant_slot_id
	if dominant_slot_id == StringName():
		dominant_slot_id = HAND_SLOT_RIGHT
	var support_slot_id: StringName = HAND_SLOT_LEFT if dominant_slot_id == HAND_SLOT_RIGHT else HAND_SLOT_RIGHT
	var support_hand_available: bool = true
	var compile_result: Dictionary = runtime_chain_compiler.compile_skill_chain(
		motion_node_chain,
		_get_active_weapon_total_length(),
		trajectory_volume_config,
		{
			"support_hand_available": support_hand_available,
			"two_hand_allowed": active_preview_default_two_hand and support_hand_available,
			"dominant_slot_id": dominant_slot_id,
			"support_slot_id": support_slot_id,
		}
	)
	if bool(compile_result.get("compiled", false)):
		return compile_result
	return result

func _resolve_preview_trajectory_volume_config() -> Dictionary:
	var preview_root: Node3D = _get_preview_root()
	var trajectory_root: Node3D = _get_preview_trajectory_root()
	if preview_root == null or trajectory_root == null:
		return {}
	var actor: Node3D = preview_root.get_node_or_null("PreviewActorPivot/PreviewActor") as Node3D
	var held_item: Node3D = preview_root.get_meta("preview_held_item") as Node3D if preview_root.has_meta("preview_held_item") else null
	if actor == null or held_item == null:
		return {}
	return preview_presenter.build_trajectory_volume_config_for_actor(
		actor,
		trajectory_root,
		held_item,
		_resolve_active_motion_node_primary_slot_id()
	)

func set_active_draft_skill_name(name_text: String) -> bool:
	var draft: Resource = _get_active_draft()
	if draft == null:
		return false
	draft.set("skill_name", name_text.strip_edges())
	_normalize_draft(draft)
	_stage_active_wip_edit("Skill name updated.", PERSIST_RUNTIME_CACHE_KEEP)
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
	_stage_active_wip_edit("Skill description updated.", PERSIST_RUNTIME_CACHE_KEEP)
	_refresh_summary("Skill description updated.")
	return true

func set_selected_motion_node_pommel_position(
	pommel_position: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var baseline_motion_node: CombatAnimationMotionNode = _build_motion_node_segment_baseline_for_direct_edit(motion_node)
	if (
		motion_node.pommel_position_local.is_equal_approx(pommel_position)
		and baseline_motion_node != null
		and baseline_motion_node.pommel_position_local.is_equal_approx(pommel_position)
	):
		return false
	var resolved_segment: Dictionary = _resolve_motion_node_segment_for_pommel_target(
		baseline_motion_node,
		pommel_position
	)
	var changed: bool = _apply_resolved_segment_to_motion_node(motion_node, resolved_segment)
	if not changed:
		return false
	motion_node.normalize()
	_apply_motion_node_change(
		"Pommel position updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_pommel_curve_in(
	curve_in: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if not _can_author_motion_node_curve_handles(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.pommel_curve_in_handle.is_equal_approx(curve_in):
		return false
	motion_node.pommel_curve_in_handle = curve_in
	motion_node.normalize()
	_apply_motion_node_change(
		"Pommel curve-in updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_pommel_curve_out(
	curve_out: Vector3,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if not _can_author_motion_node_curve_handles(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if motion_node.pommel_curve_out_handle.is_equal_approx(curve_out):
		return false
	motion_node.pommel_curve_out_handle = curve_out
	motion_node.normalize()
	_apply_motion_node_change(
		"Pommel curve-out updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_weapon_roll(
	roll_degrees: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	var resolved_roll: float = clampf(roll_degrees, -120.0, 120.0)
	if is_equal_approx(motion_node.weapon_roll_degrees, resolved_roll):
		return false
	motion_node.weapon_roll_degrees = resolved_roll
	motion_node.normalize()
	_apply_motion_node_change(
		"Weapon roll updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_axial_reposition(
	reposition_value: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	if is_equal_approx(motion_node.axial_reposition_offset, reposition_value):
		return false
	# The static preview actor does not receive a fresh animation base every frame.
	# Start this intentional Handle-position solve from the established authoring
	# baseline so repeated A -> B -> A requests cannot accumulate prior IK output.
	preview_presenter.reset_preview_actor_to_mount_seed_baseline(
		preview_subviewport,
		motion_node
	)
	motion_node.axial_reposition_offset = reposition_value
	# The Handle-position control selects a new weapon-local contact slice. The
	# resulting grip may move the hand/IK relationship, but it must not feed back
	# into the macro tip/pommel authority and accumulate endpoint displacement.
	motion_node.normalize()
	_apply_motion_node_change(
		"Axial reposition updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary,
		PREVIEW_GRIP_RESOLVE_REASON_HANDLE_POSITION
	)
	return true

func set_selected_motion_node_grip_seat_slide(
	handle_coordinate_normalized: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	PrimaryGripSeatResolverScript.migrate_legacy_display_coordinates(
		motion_node,
		active_handle_coordinate_display_mode
	)
	var resolved_handle_coordinate := clampf(
		handle_coordinate_normalized,
		0.0,
		1.0
	)
	if (
		motion_node.grip_seat_coordinate_schema_version
		>= CombatAnimationMotionNodeScript
		.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
		and is_equal_approx(
			motion_node.grip_seat_slide_offset,
			resolved_handle_coordinate
		)
	):
		return false
	motion_node.grip_seat_coordinate_schema_version = (
		CombatAnimationMotionNodeScript
		.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
	)
	motion_node.grip_seat_slide_offset = resolved_handle_coordinate
	_reseat_motion_node_grip_to_occupied_contact(motion_node)
	motion_node.normalize()
	_apply_motion_node_change(
		"Grip seat slide updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
	return true

func set_selected_motion_node_secondary_grip_seat_slide(
	handle_coordinate_normalized: float,
	persist_change: bool = true,
	refresh_list: bool = true,
	refresh_fields: bool = true,
	refresh_preview: bool = true,
	refresh_summary: bool = true
) -> bool:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if motion_node == null:
		return false
	if _is_motion_node_authoring_locked(motion_node):
		_reject_locked_motion_node_edit()
		return false
	PrimaryGripSeatResolverScript.migrate_legacy_display_coordinates(
		motion_node,
		active_handle_coordinate_display_mode
	)
	var resolved_handle_coordinate := clampf(
		handle_coordinate_normalized,
		0.0,
		1.0
	)
	if (
		motion_node.grip_seat_coordinate_schema_version
		>= CombatAnimationMotionNodeScript
		.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
		and is_equal_approx(
			motion_node.secondary_grip_seat_slide_offset,
			resolved_handle_coordinate
		)
	):
		return false
	motion_node.grip_seat_coordinate_schema_version = (
		CombatAnimationMotionNodeScript
		.GRIP_SEAT_COORDINATE_SCHEMA_NORMALIZED_HANDLE
	)
	motion_node.secondary_grip_seat_slide_offset = resolved_handle_coordinate
	motion_node.normalize()
	_apply_motion_node_change(
		"Secondary grip seat slide updated.",
		persist_change,
		refresh_list,
		refresh_fields,
		refresh_preview,
		refresh_summary
	)
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
	set_selected_motion_node_pommel_position(Vector3(pommel_x_spin_box.value, pommel_y_spin_box.value, pommel_z_spin_box.value), false)

func _on_pommel_curve_in_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls or axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_pommel_curve_in(Vector3(pommel_curve_in_x_spin_box.value, pommel_curve_in_y_spin_box.value, pommel_curve_in_z_spin_box.value), false)

func _on_pommel_curve_out_component_changed(_value: float, axis_index: int) -> void:
	if refreshing_controls or axis_index < 0 or axis_index > 2:
		return
	set_selected_motion_node_pommel_curve_out(Vector3(pommel_curve_out_x_spin_box.value, pommel_curve_out_y_spin_box.value, pommel_curve_out_z_spin_box.value), false)

func _on_weapon_roll_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_weapon_roll(value, false)

func _on_axial_reposition_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_axial_reposition(value, false)

func _on_grip_seat_slide_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_grip_seat_slide(
		PrimaryGripSeatResolverScript.display_value_to_handle_coordinate(
			value,
			active_handle_coordinate_display_mode
		),
		false
	)

func _on_secondary_grip_seat_slide_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_secondary_grip_seat_slide(
		PrimaryGripSeatResolverScript.display_value_to_handle_coordinate(
			value,
			active_handle_coordinate_display_mode
		),
		false
	)

func _on_right_upperarm_roll_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_upperarm_roll(HAND_SLOT_RIGHT, value, false)

func _on_left_upperarm_roll_changed(value: float) -> void:
	if refreshing_controls:
		return
	set_selected_motion_node_upperarm_roll(HAND_SLOT_LEFT, value, false)

func _on_play_preview_pressed() -> void:
	_toggle_preview_playback()

func _on_manual_save_pressed() -> void:
	_manual_save_active_editor_state()

func _on_debugger_view_toggled(enabled: bool) -> void:
	debugger_view_enabled = enabled
	_refresh_debugger_view_button()
	preview_presenter.set_debugger_view_enabled(
		preview_subviewport,
		debugger_view_enabled
	)

func _on_preview_gui_input(event: InputEvent) -> void:
	var motion_node: CombatAnimationMotionNode = _get_active_motion_node()
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			preview_camera_orbiting = mb.pressed
			if preview_camera_orbiting and motion_node_editor.is_dragging():
				motion_node_editor.end_drag()
				_finalize_preview_drag()
			preview_view_container.accept_event()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			if zoom_preview_camera(-1):
				preview_view_container.accept_event()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if zoom_preview_camera(1):
				preview_view_container.accept_event()
			return
		if chain_player.is_playing() or motion_node == null:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var camera: Camera3D = _get_preview_camera()
				var trajectory_root: Node3D = _get_preview_trajectory_root()
				var pick_motion_node: CombatAnimationMotionNode = _build_display_motion_node_for_viewport_pick(motion_node)
				var arm_roll_pick: Dictionary = {}
				var hand_proxy_pick_state: Dictionary = {}
				var drag_target: StringName = StringName()
				if _is_arm_roll_focus(session_state.current_focus):
					arm_roll_pick = preview_presenter.resolve_upperarm_roll_drag_state(
						preview_subviewport,
						camera,
						mb.position,
						session_state.current_focus
					)
					drag_target = arm_roll_pick.get("drag_target", StringName()) as StringName
				elif _is_hand_proxy_focus(session_state.current_focus):
					var hand_proxy_slot_id: StringName = _resolve_hand_proxy_focus_slot(session_state.current_focus)
					hand_proxy_pick_state = preview_presenter.resolve_hand_proxy_authoring_segment_state(
						preview_subviewport,
						pick_motion_node,
						hand_proxy_slot_id
					)
					drag_target = motion_node_editor.pick_hand_proxy_drag_target(
						camera,
						mb.position,
						hand_proxy_pick_state,
						trajectory_root,
						hand_proxy_slot_id
					)
				else:
					drag_target = motion_node_editor.pick_drag_target(
						camera,
						mb.position,
						pick_motion_node,
						trajectory_root,
						session_state.current_focus
					)
				if drag_target == StringName():
					return
				if (
					_is_motion_node_authoring_locked(motion_node)
					and (
						not _can_author_motion_node_curve_handles(motion_node)
						or not _is_curve_handle_drag_target(drag_target)
					)
				):
					_reject_locked_motion_node_edit()
					preview_view_container.accept_event()
					return
				_begin_preview_drag_override(pick_motion_node)
				if _is_arm_roll_focus(session_state.current_focus):
					motion_node_editor.begin_upperarm_roll_drag(drag_target, arm_roll_pick.get("roll_state", {}) as Dictionary)
				elif _is_hand_proxy_focus(session_state.current_focus):
					_seed_preview_drag_hand_proxy_segment(_resolve_hand_proxy_focus_slot(session_state.current_focus), hand_proxy_pick_state)
					motion_node_editor.begin_drag(drag_target, mb.position, pick_motion_node)
				else:
					motion_node_editor.begin_drag(drag_target, mb.position, pick_motion_node)
				match drag_target:
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_UPPERARM_ROLL:
						footer_status_label.text = "Dragging right upper arm roll."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_UPPERARM_ROLL:
						footer_status_label.text = "Dragging left upper arm roll."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_HAND_PROXY_TIP:
						footer_status_label.text = "Dragging right hand tip."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_HAND_PROXY_POMMEL:
						footer_status_label.text = "Dragging right hand."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_TIP:
						footer_status_label.text = "Dragging left hand tip."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_POMMEL:
						footer_status_label.text = "Dragging left hand."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL:
						footer_status_label.text = "Dragging pommel control."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION:
						footer_status_label.text = "Dragging weapon orientation."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_IN, CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_OUT:
						footer_status_label.text = "Dragging tip Bezier handle."
					CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL_CURVE_IN, CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL_CURVE_OUT:
						footer_status_label.text = "Dragging pommel Bezier handle."
					_:
						footer_status_label.text = "Dragging tip control."
				preview_view_container.accept_event()
			else:
				if motion_node_editor.is_dragging():
					motion_node_editor.end_drag()
					_finalize_preview_drag()
					preview_view_container.accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if preview_camera_orbiting:
			if _should_suppress_post_commit_camera_motion():
				preview_view_container.accept_event()
				return
			if orbit_preview_camera(mm.relative):
				preview_view_container.accept_event()
			return
		if chain_player.is_playing() or motion_node == null:
			return
		if motion_node_editor.is_dragging():
			_handle_preview_drag(mm.position)
			preview_view_container.accept_event()

func _handle_preview_drag(screen_position: Vector2) -> void:
	var camera: Camera3D = _get_preview_camera()
	var trajectory_root: Node3D = _get_preview_trajectory_root()
	if camera == null or trajectory_root == null:
		return
	var editable_motion_node: CombatAnimationMotionNode = _get_effective_preview_motion_node()
	if editable_motion_node == null:
		return
	var drag_target: StringName = motion_node_editor.get_drag_target()
	if (
		_is_motion_node_authoring_locked(editable_motion_node)
		and (
			not _can_author_motion_node_curve_handles(editable_motion_node)
			or not _is_curve_handle_drag_target(drag_target)
		)
	):
		return
	if (
		drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_UPPERARM_ROLL
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_UPPERARM_ROLL
	):
		var resolved_upperarm_roll: Variant = motion_node_editor.resolve_upperarm_roll_drag(camera, screen_position)
		if resolved_upperarm_roll != null:
			var slot_id: StringName = HAND_SLOT_LEFT if drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_UPPERARM_ROLL else HAND_SLOT_RIGHT
			var next_roll: float = _wrap_degrees_signed(float(resolved_upperarm_roll))
			var previous_roll: float = editable_motion_node.left_upperarm_roll_degrees if slot_id == HAND_SLOT_LEFT else editable_motion_node.right_upperarm_roll_degrees
			if not is_equal_approx(previous_roll, next_roll):
				if slot_id == HAND_SLOT_LEFT:
					editable_motion_node.left_upperarm_roll_degrees = next_roll
				else:
					editable_motion_node.right_upperarm_roll_degrees = next_roll
				preview_drag_has_moved = true
				editable_motion_node.normalize()
				_queue_preview_drag_refresh()
	elif _is_hand_proxy_drag_target(drag_target):
		var hand_slot_id: StringName = _resolve_hand_proxy_drag_slot(drag_target)
		var hand_state: Dictionary = _resolve_motion_node_hand_proxy_segment(editable_motion_node, hand_slot_id)
		if hand_state.is_empty():
			return
		var current_tip_origin_id: StringName = _resolve_seed_origin_id(
			hand_state,
			"tip_position_origin_id",
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		)
		var current_pommel_origin_id: StringName = _resolve_seed_origin_id(
			hand_state,
			"pommel_position_origin_id",
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		)
		var current_tip: Vector3 = _get_origin_tracked_seed_vector3(
			hand_state,
			"tip_position_local",
			"tip_position_origin_id",
			editable_motion_node.tip_position_local,
			current_tip_origin_id
		)
		var current_pommel: Vector3 = _get_origin_tracked_seed_vector3(
			hand_state,
			"pommel_position_local",
			"pommel_position_origin_id",
			editable_motion_node.pommel_position_local,
			current_pommel_origin_id
		)
		var use_tip_endpoint: bool = _is_hand_proxy_tip_drag_target(drag_target)
		var endpoint_local: Vector3 = current_tip if use_tip_endpoint else current_pommel
		var hand_hit: Variant = motion_node_editor.raycast_local_point_on_view_drag_plane(
			camera,
			screen_position,
			trajectory_root,
			endpoint_local
		)
		if hand_hit != null:
			var next_tip: Vector3 = current_tip
			var next_pommel: Vector3 = current_pommel
			if use_tip_endpoint:
				next_tip = motion_node_editor.constrain_tip_to_sphere(
					current_pommel,
					hand_hit as Vector3,
					maxf(current_tip.distance_to(current_pommel), 0.01)
				)
			else:
				var hand_delta: Vector3 = (hand_hit as Vector3) - current_pommel
				next_tip = current_tip + hand_delta
				next_pommel = hand_hit as Vector3
			if _apply_hand_proxy_segment_to_motion_node(
				editable_motion_node,
				hand_slot_id,
				next_tip,
				next_pommel,
				true,
				current_tip_origin_id,
				current_pommel_origin_id
			):
				preview_drag_has_moved = true
				editable_motion_node.normalize()
				_queue_preview_drag_refresh()
	elif drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP:
		var hit: Variant = motion_node_editor.raycast_tip_on_view_drag_plane(
			camera,
			screen_position,
			editable_motion_node,
			trajectory_root
		)
		if hit != null:
			var resolved_segment: Dictionary = _resolve_motion_node_segment_for_tip_target(
				editable_motion_node,
				hit as Vector3,
				false
			)
			if _apply_resolved_segment_to_motion_node(editable_motion_node, resolved_segment):
				preview_drag_has_moved = true
				editable_motion_node.normalize()
				_queue_preview_drag_refresh()
	elif drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL:
		var hit_pommel: Variant = motion_node_editor.raycast_pommel_on_view_drag_plane(
			camera,
			screen_position,
			editable_motion_node,
			trajectory_root
		)
		if hit_pommel != null:
			_queue_pommel_drag_authority_target(hit_pommel as Vector3)
	elif drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_WEAPON_ROTATION:
		var resolved_weapon_orientation: Variant = motion_node_editor.resolve_weapon_orientation_drag(camera, screen_position, editable_motion_node, trajectory_root)
		if resolved_weapon_orientation != null:
			var resolved_weapon_plane: Vector3 = resolved_weapon_orientation as Vector3
			if not editable_motion_node.weapon_orientation_degrees.is_equal_approx(resolved_weapon_plane) or not editable_motion_node.weapon_orientation_authored:
				editable_motion_node.weapon_orientation_degrees = resolved_weapon_plane
				editable_motion_node.weapon_orientation_authored = true
				preview_drag_has_moved = true
				editable_motion_node.normalize()
				_queue_preview_drag_refresh()
	elif _is_curve_handle_drag_target(drag_target):
		var hit_handle: Variant = motion_node_editor.raycast_curve_handle_on_view_drag_plane(
			camera,
			screen_position,
			editable_motion_node,
			trajectory_root,
			drag_target
		)
		if hit_handle != null and _apply_curve_handle_drag(editable_motion_node, drag_target, hit_handle as Vector3):
			preview_drag_has_moved = true
			editable_motion_node.normalize()
			_queue_preview_drag_refresh()

func _set_preview_drag_blocked_status(resolved_segment: Dictionary) -> void:
	if footer_status_label == null:
		return
	var region: String = String(resolved_segment.get("collision_region", ""))
	if region.is_empty():
		region = String(resolved_segment.get("colliding_body_region", ""))
	if region.is_empty():
		footer_status_label.text = "Blocked by body clearance."
		return
	footer_status_label.text = "Blocked by body clearance near %s." % region

func _wrap_degrees_signed(degrees: float) -> float:
	return wrapf(degrees + 180.0, 0.0, 360.0) - 180.0

func _is_curve_handle_drag_target(drag_target: StringName) -> bool:
	return (
		drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_IN
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_OUT
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL_CURVE_IN
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL_CURVE_OUT
	)

func _is_arm_roll_focus(focus_id: StringName) -> bool:
	return (
		focus_id == CombatAnimationSessionStateScript.FOCUS_ARM_ROLL
		or focus_id == CombatAnimationSessionStateScript.FOCUS_RIGHT_ARM_ROLL
		or focus_id == CombatAnimationSessionStateScript.FOCUS_LEFT_ARM_ROLL
	)

func _is_hand_proxy_focus(focus_id: StringName) -> bool:
	return (
		focus_id == CombatAnimationSessionStateScript.FOCUS_RIGHT_HAND_PROXY
		or focus_id == CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY
	)

func _resolve_hand_proxy_focus_slot(focus_id: StringName) -> StringName:
	return HAND_SLOT_LEFT if focus_id == CombatAnimationSessionStateScript.FOCUS_LEFT_HAND_PROXY else HAND_SLOT_RIGHT

func _is_hand_proxy_drag_target(drag_target: StringName) -> bool:
	return (
		drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_HAND_PROXY_TIP
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_HAND_PROXY_POMMEL
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_TIP
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_POMMEL
	)

func _is_hand_proxy_tip_drag_target(drag_target: StringName) -> bool:
	return (
		drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_RIGHT_HAND_PROXY_TIP
		or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_TIP
	)

func _resolve_hand_proxy_drag_slot(drag_target: StringName) -> StringName:
	if drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_TIP or drag_target == CombatAnimationMotionNodeEditorScript.DRAG_TARGET_LEFT_HAND_PROXY_POMMEL:
		return HAND_SLOT_LEFT
	return HAND_SLOT_RIGHT

func _seed_preview_drag_hand_proxy_segment(slot_id: StringName, segment_state: Dictionary) -> void:
	if preview_drag_override_node == null or segment_state.is_empty():
		return
	var tip_position_origin_id: StringName = _resolve_seed_origin_id(
		segment_state,
		"tip_position_origin_id",
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var pommel_position_origin_id: StringName = _resolve_seed_origin_id(
		segment_state,
		"pommel_position_origin_id",
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var tip_position: Vector3 = _get_origin_tracked_seed_vector3(
		segment_state,
		"tip_position_local",
		"tip_position_origin_id",
		preview_drag_override_node.tip_position_local,
		tip_position_origin_id
	)
	var pommel_position: Vector3 = _get_origin_tracked_seed_vector3(
		segment_state,
		"pommel_position_local",
		"pommel_position_origin_id",
		preview_drag_override_node.pommel_position_local,
		pommel_position_origin_id
	)
	_apply_hand_proxy_segment_to_motion_node(
		preview_drag_override_node,
		slot_id,
		tip_position,
		pommel_position,
		false,
		tip_position_origin_id,
		pommel_position_origin_id
	)

func _resolve_motion_node_hand_proxy_segment(motion_node: CombatAnimationMotionNode, slot_id: StringName) -> Dictionary:
	if motion_node == null:
		return {}
	if _hand_proxy_slot_uses_primary_motion_segment(slot_id):
		return {
			"tip_position_local": motion_node.tip_position_local,
			"tip_position_origin_id": motion_node.tip_position_origin_id,
			"pommel_position_local": motion_node.pommel_position_local,
			"pommel_position_origin_id": motion_node.pommel_position_origin_id,
		}
	if slot_id == HAND_SLOT_LEFT:
		return {
			"tip_position_local": motion_node.left_hand_proxy_tip_position_local,
			"tip_position_origin_id": motion_node.left_hand_proxy_tip_position_origin_id,
			"pommel_position_local": motion_node.left_hand_proxy_pommel_position_local,
			"pommel_position_origin_id": motion_node.left_hand_proxy_pommel_position_origin_id,
		}
	return {
		"tip_position_local": motion_node.right_hand_proxy_tip_position_local,
		"tip_position_origin_id": motion_node.right_hand_proxy_tip_position_origin_id,
		"pommel_position_local": motion_node.right_hand_proxy_pommel_position_local,
		"pommel_position_origin_id": motion_node.right_hand_proxy_pommel_position_origin_id,
	}

func _apply_hand_proxy_segment_to_motion_node(
	motion_node: CombatAnimationMotionNode,
	slot_id: StringName,
	tip_position_local: Vector3,
	pommel_position_local: Vector3,
	mark_authored: bool = true,
	tip_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING,
	pommel_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
) -> bool:
	if motion_node == null:
		return false
	var resolved_tip_origin_id: StringName = _normalize_seed_origin_id(
		tip_position_origin_id,
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var resolved_pommel_origin_id: StringName = _normalize_seed_origin_id(
		pommel_position_origin_id,
		resolved_tip_origin_id
	)
	if _hand_proxy_slot_uses_primary_motion_segment(slot_id):
		return _apply_resolved_segment_to_motion_node(motion_node, {
			"tip_position_local": tip_position_local,
			"tip_position_origin_id": resolved_tip_origin_id,
			"pommel_position_local": pommel_position_local,
			"pommel_position_origin_id": resolved_pommel_origin_id,
		})
	var changed: bool = false
	if slot_id == HAND_SLOT_LEFT:
		if mark_authored and not motion_node.left_hand_proxy_authored:
			motion_node.left_hand_proxy_authored = true
			changed = true
		if not motion_node.left_hand_proxy_tip_position_local.is_equal_approx(tip_position_local):
			motion_node.left_hand_proxy_tip_position_local = tip_position_local
			changed = true
		if motion_node.left_hand_proxy_tip_position_origin_id != resolved_tip_origin_id:
			motion_node.left_hand_proxy_tip_position_origin_id = resolved_tip_origin_id
			changed = true
		if not motion_node.left_hand_proxy_pommel_position_local.is_equal_approx(pommel_position_local):
			motion_node.left_hand_proxy_pommel_position_local = pommel_position_local
			changed = true
		if motion_node.left_hand_proxy_pommel_position_origin_id != resolved_pommel_origin_id:
			motion_node.left_hand_proxy_pommel_position_origin_id = resolved_pommel_origin_id
			changed = true
		return changed
	if mark_authored and not motion_node.right_hand_proxy_authored:
		motion_node.right_hand_proxy_authored = true
		changed = true
	if not motion_node.right_hand_proxy_tip_position_local.is_equal_approx(tip_position_local):
		motion_node.right_hand_proxy_tip_position_local = tip_position_local
		changed = true
	if motion_node.right_hand_proxy_tip_position_origin_id != resolved_tip_origin_id:
		motion_node.right_hand_proxy_tip_position_origin_id = resolved_tip_origin_id
		changed = true
	if not motion_node.right_hand_proxy_pommel_position_local.is_equal_approx(pommel_position_local):
		motion_node.right_hand_proxy_pommel_position_local = pommel_position_local
		changed = true
	if motion_node.right_hand_proxy_pommel_position_origin_id != resolved_pommel_origin_id:
		motion_node.right_hand_proxy_pommel_position_origin_id = resolved_pommel_origin_id
		changed = true
	return changed

func _hand_proxy_slot_uses_primary_motion_segment(slot_id: StringName) -> bool:
	return _is_active_unarmed_authoring_wip() and slot_id == _resolve_active_motion_node_primary_slot_id()

func _apply_curve_handle_drag(
	motion_node: CombatAnimationMotionNode,
	drag_target: StringName,
	handle_position_local: Vector3,
	handle_position_origin_id: StringName = CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
) -> bool:
	if motion_node == null:
		return false
	var handle_position_state := {
		"handle_position_local": handle_position_local,
		"handle_position_origin_id": _normalize_seed_origin_id(
			handle_position_origin_id,
			CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
		),
	}
	var resolved_handle_position_origin_id: StringName = _resolve_seed_origin_id(
		handle_position_state,
		"handle_position_origin_id",
		CombatOriginRecordScript.ORIGIN_TRAJECTORY_AUTHORING
	)
	var resolved_handle_position: Vector3 = _get_origin_tracked_seed_vector3(
		handle_position_state,
		"handle_position_local",
		"handle_position_origin_id",
		handle_position_local,
		resolved_handle_position_origin_id
	)
	match drag_target:
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_IN:
			var next_tip_in: Vector3 = resolved_handle_position - motion_node.tip_position_local
			if motion_node.tip_curve_in_handle.is_equal_approx(next_tip_in):
				return false
			motion_node.tip_curve_in_handle = next_tip_in
			return true
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_TIP_CURVE_OUT:
			var next_tip_out: Vector3 = resolved_handle_position - motion_node.tip_position_local
			if motion_node.tip_curve_out_handle.is_equal_approx(next_tip_out):
				return false
			motion_node.tip_curve_out_handle = next_tip_out
			return true
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL_CURVE_IN:
			var next_pommel_in: Vector3 = resolved_handle_position - motion_node.pommel_position_local
			if motion_node.pommel_curve_in_handle.is_equal_approx(next_pommel_in):
				return false
			motion_node.pommel_curve_in_handle = next_pommel_in
			return true
		CombatAnimationMotionNodeEditorScript.DRAG_TARGET_POMMEL_CURVE_OUT:
			var next_pommel_out: Vector3 = resolved_handle_position - motion_node.pommel_position_local
			if motion_node.pommel_curve_out_handle.is_equal_approx(next_pommel_out):
				return false
			motion_node.pommel_curve_out_handle = next_pommel_out
			return true
		_:
			return false

func _get_preview_camera() -> Camera3D:
	var preview_root: Node3D = _get_preview_root()
	if preview_root == null:
		return null
	return preview_root.get_node_or_null("PreviewCamera3D") as Camera3D

func _get_preview_trajectory_root() -> Node3D:
	var preview_root: Node3D = _get_preview_root()
	if preview_root == null:
		return null
	return preview_root.find_child("TrajectoryRoot", true, false) as Node3D

func _get_preview_root() -> Node3D:
	if preview_subviewport == null:
		return null
	return preview_subviewport.get_node_or_null("CombatAnimationPreviewRoot3D") as Node3D

func _get_active_weapon_total_length() -> float:
	var geometry_seed: Dictionary = _resolve_active_weapon_motion_seed()
	if not geometry_seed.is_empty():
		var weapon_total_length_meters: float = float(geometry_seed.get("weapon_total_length_meters", 0.0))
		if weapon_total_length_meters > 0.001:
			return weapon_total_length_meters
	return 0.5
