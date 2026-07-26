extends SceneTree

const UiWindowLayerPolicyScript = preload(
	"res://runtime/ui/ui_window_layer_policy.gd"
)
const CombatAnimationStationUIScene = preload(
	"res://scenes/ui/combat_animation_station_ui.tscn"
)

var failure_count: int = 0


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	_verify_shared_window_policy()
	await _verify_combat_station_window_ownership()

	if failure_count == 0:
		print("UI_WINDOW_LAYER_POLICY_VERIFY: PASS")
		quit()
		return
	push_error(
		"UI_WINDOW_LAYER_POLICY_VERIFY: FAIL (%d assertion(s))"
		% failure_count
	)
	quit(1)


func _verify_shared_window_policy() -> void:
	var major_workspace := PopupPanel.new()
	major_workspace.name = "VerifierMajorWorkspace"
	get_root().add_child(major_workspace)
	UiWindowLayerPolicyScript.configure_major_workspace(major_workspace)
	_expect(
		not major_workspace.popup_window,
		"major workspace remains visible when focus moves away"
	)
	_expect(
		not major_workspace.popup_wm_hint,
		"major workspace clears the native popup window-manager hint"
	)
	_expect(
		major_workspace.transient,
		"major workspace remains transient to its application window"
	)
	_expect(
		not major_workspace.transient_to_focused,
		"major workspace owner is explicit"
	)
	_expect(
		not major_workspace.exclusive,
		"major workspace does not block uncovered sibling surfaces"
	)

	var owned_popup := PopupMenu.new()
	owned_popup.name = "VerifierOwnedPopup"
	get_root().add_child(owned_popup)
	var attached: bool = UiWindowLayerPolicyScript.attach_owned_popup(
		major_workspace,
		owned_popup
	)
	_expect(attached, "owned popup attaches to its explicit workspace")
	_expect(
		owned_popup.get_parent() == major_workspace,
		"owned popup is physically parented to its workspace"
	)
	_expect(
		owned_popup.popup_window,
		"owned popup keeps normal dismiss-on-focus-loss behavior"
	)
	_expect(
		owned_popup.popup_wm_hint,
		"owned popup keeps the native popup window-manager hint"
	)
	_expect(owned_popup.transient, "owned popup is transient")
	_expect(
		not owned_popup.transient_to_focused,
		"owned popup does not infer a different focused owner"
	)
	_expect(
		not owned_popup.exclusive,
		"owned popup does not block uncovered sibling surfaces"
	)

	var visual_surface := Panel.new()
	visual_surface.name = "VerifierVisualInputSurface"
	visual_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual_surface.mouse_force_pass_scroll_events = true
	major_workspace.add_child(visual_surface)
	UiWindowLayerPolicyScript.configure_visual_input_surface(visual_surface)
	_expect(
		visual_surface.mouse_filter == Control.MOUSE_FILTER_STOP,
		"visible surface stops pointer input inside its rectangle"
	)
	_expect(
		not visual_surface.mouse_force_pass_scroll_events,
		"visible surface stops unhandled wheel input from reaching covered editors"
	)

	major_workspace.queue_free()


func _verify_combat_station_window_ownership() -> void:
	var station_ui: Node = CombatAnimationStationUIScene.instantiate()
	get_root().add_child(station_ui)
	await process_frame

	var primary_popup := station_ui.get(
		"weapon_open_primary_popup"
	) as PopupMenu
	var variant_popup := station_ui.get(
		"weapon_open_variant_popup"
	) as PopupMenu
	_expect(
		is_instance_valid(primary_popup),
		"Combat Station creates its Primary popup"
	)
	_expect(
		is_instance_valid(variant_popup),
		"Combat Station creates its Variant popup"
	)
	if not is_instance_valid(primary_popup) or not is_instance_valid(variant_popup):
		station_ui.queue_free()
		return

	_expect(
		primary_popup.get_parent() == station_ui,
		"Combat Station Primary popup remains owned by the station surface"
	)
	_expect(
		variant_popup.get_parent() == primary_popup,
		"Combat Station Variant popup is physically owned by Primary"
	)
	_expect(
		primary_popup.popup_window
		and primary_popup.popup_wm_hint
		and variant_popup.popup_window
		and variant_popup.popup_wm_hint,
		"Combat Station temporary popup chain keeps popup lifetime"
	)
	_expect(
		primary_popup.transient and variant_popup.transient,
		"Combat Station temporary popup chain is transient"
	)
	_expect(
		not primary_popup.transient_to_focused
		and not variant_popup.transient_to_focused,
		"Combat Station popup owners are explicit"
	)
	_expect(
		not primary_popup.exclusive and not variant_popup.exclusive,
		"Combat Station popup chain remains nonexclusive"
	)

	var backdrop := station_ui.get("backdrop") as Control
	var panel := station_ui.get("panel") as Control
	_expect(
		is_instance_valid(backdrop)
		and backdrop.mouse_filter == Control.MOUSE_FILTER_STOP
		and not backdrop.mouse_force_pass_scroll_events,
		"Combat Station backdrop owns pointer and wheel input in its rectangle"
	)
	_expect(
		is_instance_valid(panel)
		and panel.mouse_filter == Control.MOUSE_FILTER_STOP
		and not panel.mouse_force_pass_scroll_events,
		"Combat Station panel owns pointer and wheel input in its rectangle"
	)

	station_ui.queue_free()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failure_count += 1
	push_error("FAIL: %s" % description)
