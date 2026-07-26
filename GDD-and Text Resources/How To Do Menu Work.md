# How To Do Menu Work

This note defines the menu behavior expected for Forge V2 and future tool menus.
It was written after the profile builder saved-profile menu work, because that
work exposed several rules that should stay consistent across the project.

Current live code reference:

`The Will- main folder/the-will-gamefiles/runtime/forge_v2/crafting_bench_ui_v2.gd`

## Core Rule

Menus must preserve the user's current work context unless the user clearly
chooses an action that changes that context.

If the user is inside an editing workspace, menu actions should keep them inside
that workspace. A small action such as rename, delete, save, or cancel should
close only the smallest relevant popup, refresh the visible data, and return the
user to the same working place.

Do not boot the user back to the main forge editing view just because a nested
menu action finished.

## Workspace Meaning

The same data can be shown in different menus, but the meaning changes based on
where the user opened it.

`Profiles` means profile editing.

When the user is inside `Profiles`, they are editing, reviewing, creating,
renaming, deleting, or refining profiles. Selecting a saved profile from
`Profiles -> Saved Profiles` means "open this saved profile for editing here".
It must not mean "select this for forge deposition and close the profile editor".

`Shape` means forge-use selection.

When the user is inside `Shape -> Tool -> Handles -> Handle Profiles`, selecting
a saved profile means "use this profile as the active handle/profile shape for
drawing or deposition". That is the place where saved profiles are chosen for
actual forge work.

In short:

```text
Profiles menu = edit saved data.
Shape menu    = use saved data.
```

## Menu Layer Types

Treat menus as layers. Closing should happen from the smallest active layer
outward.

Main workspace popup:

The large menu/editor space, such as the profile builder popup.

Sub-workspace popup:

A secondary working list or panel inside the main workspace, such as
`Profiles -> Saved Profiles`.

Temporary context popup:

A short-lived right-click action popup, such as `Rename` and `Delete`.

Name/action dialog:

A focused dialog used to type a name, confirm a save name, or rename an item.

The expected close order is:

```text
temporary context popup
name/action dialog
sub-workspace popup
main workspace popup
main forge UI
```

## Saved Profile List Behavior

Saved profile lists should show the saved item names as the primary content.
Do not replace the list with direct action entries such as:

```text
Rename
Delete
```

The list itself should remain visible, and the action menu should appear only as
a temporary context popup.

Correct saved profile list shape:

```text
Saved Profiles

handle profile 1
thin grip test
wide octagon profile
```

Left click on a saved profile while inside `Profiles -> Saved Profiles`:

```text
1. Select that profile.
2. Load it into the profile editor.
3. Keep the Profiles workspace open.
4. Keep the Saved Profiles list open.
5. Refresh the list in place so the active item can remain selected.
```

Right click on a saved profile row:

```text
1. Close/free any old saved-profile context popup.
2. Select the row under the mouse.
3. Store that row profile_id as the active context target.
4. Create a new Rename/Delete popup.
5. Open it at the current mouse position.
```

Right click on blank space inside the saved profile list:

```text
1. Close/free the current context popup if one exists.
2. Do not open a new context popup.
3. Do not change the current profile selection.
```

Repeated right click on the same row or a different valid row must feel fluid.
Each valid right click should close/free the old context popup and create a new
one at the new mouse position for the row that was right-clicked.

## Right-Click Context Menus

Right-click context menus should behave like desktop file context menus:

```text
right click item -> action popup appears at mouse
right click another item -> old popup closes, new popup appears at mouse
right click blank space -> popup closes
left click elsewhere -> popup closes
```

The popup should appear with its top-left corner at the mouse cursor unless a
specific menu has a strong reason to do otherwise.

The action popup must be visually above the menu it belongs to. In Godot, normal
`Control` nodes can render behind a `PopupPanel`, so right-click action popups
that need to appear above another popup should also use `PopupPanel` or another
proper popup/window layer.

## Popup Lifetime

Rare-use context popups should not be kept around as hidden long-lived UI.
Create them when needed, then free them when they are dismissed or used.

Use "hidden" only for larger reusable workspace popups when that reuse is
intentional. A tiny right-click Rename/Delete popup is not a workspace. It is a
short-lived action layer.

For temporary context popups, the target data must also be cleared when the popup
is closed.

Current Forge V2 example:

```gdscript
func _hide_saved_profile_context_menu() -> void:
	profile_saved_profiles_context_profile_id = StringName()
	if is_instance_valid(profile_saved_profiles_context_panel):
		profile_saved_profiles_context_panel.queue_free()
	profile_saved_profiles_context_panel = null
```

This keeps the Rename/Delete context popup from lingering as concealed UI and
prevents stale target ids from being reused later.

## Rename, Delete, Save, And Cancel

Rename:

```text
1. Right click a valid item.
2. Open the Rename/Delete context popup.
3. Choose Rename.
4. Close/free only the context popup.
5. Open the rename dialog.
6. Confirm or cancel.
7. Close only the rename dialog.
8. Restore the previous Profiles workspace and Saved Profiles list.
9. Refresh the list in place.
```

Delete:

```text
1. Right click a valid item.
2. Choose Delete.
3. Close/free only the context popup.
4. Delete the selected saved profile.
5. Refresh controller/profile state.
6. Refresh the Saved Profiles list in place.
7. Do not close the Profiles workspace.
```

Save:

If the user opened an existing profile from the saved list, saving should update
that existing profile unless the specific action is "save as new". Saving an
opened file should feel like saving text into an existing `.txt` file, not like
being forced to create a new file every time.

Cancel:

Cancel should close the focused dialog only. It should not close the parent
profile editor or saved profile list.

## Restoring The Parent Workspace

Godot popups can affect each other when a nested popup opens. Before opening a
name/rename dialog from inside a menu workspace, capture the workspace that
should be restored afterward.

Current Forge V2 example:

```gdscript
func _capture_profile_name_return_workspace() -> void:
	profile_name_restore_profile_builder = is_instance_valid(profile_builder_popup) and profile_builder_popup.visible
	profile_name_restore_saved_profiles = is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible

func _close_profile_name_popup(restore_workspace: bool = true) -> void:
	var should_restore_profile_builder := profile_name_restore_profile_builder
	var should_restore_saved_profiles := profile_name_restore_saved_profiles
	profile_name_pending_action = StringName()
	profile_name_pending_profile_id = StringName()
	profile_name_restore_profile_builder = false
	profile_name_restore_saved_profiles = false
	if is_instance_valid(profile_name_popup):
		profile_name_popup.hide()
	if restore_workspace and (should_restore_profile_builder or should_restore_saved_profiles):
		call_deferred(
			"_restore_profile_workspace_after_profile_name_popup",
			should_restore_profile_builder,
			should_restore_saved_profiles
		)
```

The important behavior is not the exact variable names. The important behavior
is:

```text
remember where the user was
perform the small dialog action
close the small dialog
restore the same workspace
refresh the affected visible data
```

## ItemList Pattern For Saved Data

Use `ItemList` for simple saved-data lists where the user needs to left click
items and right click specific rows.

Current Forge V2 setup:

```gdscript
profile_saved_profiles_item_list = ItemList.new()
profile_saved_profiles_item_list.name = "SavedProfilesItemList"
profile_saved_profiles_item_list.select_mode = ItemList.SELECT_SINGLE
profile_saved_profiles_item_list.allow_reselect = true
profile_saved_profiles_item_list.allow_rmb_select = true
profile_saved_profiles_item_list.item_clicked.connect(_on_profile_saved_profile_item_clicked)
profile_saved_profiles_item_list.gui_input.connect(_on_profile_saved_profiles_list_gui_input)
```

Use metadata to bind each row to the actual saved data id:

```gdscript
var item_index := profile_saved_profiles_item_list.add_item(label)
profile_saved_profiles_item_list.set_item_metadata(item_index, profile_id)
```

Do not infer identity from visible text. Names can be changed, duplicated by
pattern, or localized later. Use stable ids for actions.

## Left Click Versus Right Click

Left click and right click must not share ambiguous behavior.

Current Forge V2 saved-profile behavior:

```gdscript
if mouse_button_index == MOUSE_BUTTON_LEFT:
	_hide_saved_profile_context_menu()
	_load_saved_handle_profile(profile_id)
	if is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible:
		_refresh_profile_saved_profiles_popup()
```

This means left click loads the profile for editing and refreshes the list. It
does not close `Profiles`.

Right click uses list hit testing and opens the context menu only when the mouse
is over a valid item:

```gdscript
if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
	var item_index := _get_saved_profile_item_index_at_position(mouse_event.position)
	if item_index < 0:
		_hide_saved_profile_context_menu()
		return
	_open_saved_profile_context_menu_for_item_index(item_index)
	profile_saved_profiles_item_list.accept_event()
```

## Context Popup Creation

When opening a context popup, always close the existing context popup first.
This makes repeated right clicks behave properly.

Current Forge V2 example:

```gdscript
func _open_saved_profile_context_menu(profile_id: StringName) -> void:
	if profile_id == StringName():
		return
	_ensure_profile_saved_profiles_popup()
	_hide_saved_profile_context_menu()
	profile_saved_profiles_context_profile_id = profile_id
	profile_saved_profiles_context_panel = _build_saved_profile_context_panel()
	add_child(profile_saved_profiles_context_panel)
	var mouse_position := get_viewport().get_mouse_position()
	var popup_size := Vector2i(124, 64)
	profile_saved_profiles_context_panel.popup(Rect2i(
		Vector2i(roundi(mouse_position.x), roundi(mouse_position.y)),
		popup_size
	))
```

This is the pattern to reuse:

```text
validate target
close old temporary popup
store target id
build fresh popup
add to popup-capable parent/root
popup at mouse position
```

## Shape Menu Routing

The shape menu is where active forge tools select what they will use.

For handles, the expected route is:

```text
Shape -> Tool -> Handles -> Handle Profiles -> Saved Profiles
Shape -> Tool -> Handles -> Handle Profiles -> Presets
```

Saved profiles are user-made profiles. Presets are future built-in profiles that
should eventually be non-removable.

Current Forge V2 reference:

```gdscript
if active_tool_id == &"tool_handles":
	_add_v2_disabled_line(popup, "Profile: %s" % String(summary.get("active_profile_label", "None")))
	var handle_profiles_submenu: PopupMenu = _prepare_v2_submenu(popup, "HandleProfilesSubmenu")
	var saved_profiles_submenu: PopupMenu = _prepare_v2_submenu(handle_profiles_submenu, "HandleSavedProfilesSubmenu")
	_add_v2_saved_profile_items(
		saved_profiles_submenu,
		_get_saved_handle_profiles(),
		&"handle_saved_profile",
		active_saved_profile_id
	)
	handle_profiles_submenu.add_submenu_item("Saved Profiles", String(saved_profiles_submenu.name))
```

Do not use the profile editor's saved-profile list as the place to choose active
forge brush data. That belongs in the `Shape` workflow.

## Escape And Back-Out Behavior

Escape should close the smallest active layer first.

Current Forge V2 ordering:

```gdscript
if is_instance_valid(profile_name_popup) and profile_name_popup.visible:
	_close_profile_name_popup()
	return
if is_instance_valid(profile_saved_profiles_context_panel) and profile_saved_profiles_context_panel.visible:
	_hide_saved_profile_context_menu()
	return
if is_instance_valid(profile_saved_profiles_popup) and profile_saved_profiles_popup.visible:
	_close_profile_saved_profiles_popup()
	return
if is_instance_valid(profile_builder_popup) and profile_builder_popup.visible:
	profile_builder_popup.hide()
	return
```

The exact order can change per UI, but the rule stays the same:

```text
close the smallest focused thing first
do not close parent workspaces unless the user backs out to that layer
```

## Wording Rules

Prefer names that match what the user is doing.

Use `Saved Profiles` for user-created saved profile files.

Use `Presets` for built-in or curated profile files.

Use `Delete` in the right-click action popup instead of `Remove` when the action
deletes saved user data. This is clearer in a short context menu.

Avoid generic buttons such as `Manage` when the user is acting on one concrete
row. Per-item right click should expose per-item actions directly.

## Checklist Before Menu Work Is Done

Before marking menu work as complete, check these points:

```text
Does the menu preserve the user's workspace after a small action?
Does left click do the primary action only?
Does right click open a temporary action popup only on valid items?
Does repeated right click on valid items reopen/reposition the popup cleanly?
Does right click on blank space close the context popup?
Does cancel close only the focused dialog?
Does save/rename/delete refresh visible lists in place?
Does deleting/renaming avoid booting the user out to the main forge view?
Is temporary context UI freed instead of kept hidden forever?
Are actions bound to stable ids instead of visible labels?
Is the popup visually on top of the menu it belongs to?
Is `Profiles` still treated as editing, and `Shape` still treated as forge-use selection?
```

If any answer is no, the menu behavior is not finished.
