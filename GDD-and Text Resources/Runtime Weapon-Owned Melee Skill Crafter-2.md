Absolutely. That addition fits very well.

You are right: if the **F preview chain player** already exists, then the same authored chain playback logic should also be reusable outside the editor as a **runtime skill presentation view**.

Not an actual video file.
A **live looped presentation playback** of:

* player model
* wielding the weapon
* performing the finished authored chain
* used in skill inspection / trading / presentation contexts

That should be treated as a direct reuse target of the same chain playback logic, not a separate fake system.

So below is the stricter implementation brief with that folded in.

---

# CODEX IMPLEMENTATION PROMPT

## The Will — Runtime Weapon-Owned Melee Skill Crafter

### Strict implementation brief

### Godot 4.6.1

### First-pass melee only

Build a runtime in-game melee skill crafting system for **The Will** with the exact rules below.

Do not reinterpret the design into a generic animation editor.
Do not replace the point-chain model with dense keyframe editing.
Do not detach skill drafts from weapon ownership.

---

# 1. Core ownership rules

1. Every melee weapon owns its own skill profile.
2. Every editable melee skill draft belongs to exactly one owning weapon.
3. Draft state must persist inside the owning weapon’s stored data.
4. Reopening the same weapon later must restore that weapon’s draft state.
5. Newly created melee weapons must receive a simple default baseline skill package so they are immediately usable and editable.
6. Developer-made starter weapons and starter skillsets must be authorable using this same system.

---

# 2. Top-level menu flow

Implement the skill crafter as a 3-step runtime flow:

1. **Weapon List**

   * show editable weapons
   * player selects one weapon

2. **Skill List**

   * show the selected weapon’s owned skills
   * player selects one skill

3. **Editor**

   * open the 3D editor for that exact weapon-owned skill draft

Do not open the editor without:

* one selected weapon
* one selected skill

---

# 3. Required controls

Use explicit InputMap actions.
Default bindings must be:

* Q = previous point
* E = next point
* R = add new point after current point
* T = delete current editable point
* Space = commit current point
* F = preview full chain from beginning to end once

Create these actions:

* `skill_crafter_prev_point`
* `skill_crafter_next_point`
* `skill_crafter_new_point`
* `skill_crafter_delete_point`
* `skill_crafter_commit_point`
* `skill_crafter_play_preview`

Optional:

* `skill_crafter_drag_target`
* `skill_crafter_rotate_plane_modifier`
* `skill_crafter_cancel_edit`

---

# 4. Point-chain authoring model

Implement authored melee skills as an ordered chain of committed motion points.

Do not build first pass as a full dense frame/bone timeline.

A point is a committed motion checkpoint.
A draft is an ordered list of these points.

The player workflow must be:

* navigate points
* add new point after current
* edit point on active plane
* commit point
* delete point if needed
* preview full chain
* leave and return later

---

# 5. Exact control behavior

## Q — previous point

When Q is pressed:

* move selection to previous committed point if one exists
* do not create data
* do not destroy data
* update local context visuals
* update active edit target

## E — next point

When E is pressed:

* move selection to next committed point if one exists
* do not create data
* do not destroy data
* update local context visuals
* update active edit target

## R — add point

When R is pressed:

* insert a new temporary editable point after the current selected point
* new point becomes current active point
* do not auto-commit it
* require Space to commit

## T — delete point

When T is pressed:

* delete the current editable/selected point
* after deletion, move selection backward using Q-like behavior
* update point ordering
* update local point visibility
* update trajectory line
* update active edit state safely

If deletion of the required root/start point is illegal, block it cleanly.

## Space — commit point

When Space is pressed:

* if editing a new temporary point, commit it into the chain
* if editing an existing point, commit its modified state
* update visuals and point chain state
* preserve stable navigation behavior

## F — preview chain once

When F is pressed:

* preview always starts from point 0
* play the full committed instruction list from beginning to end once
* if F is pressed again during playback, restart cleanly from point 0
* playback must not mutate committed draft data

---

# 6. 3D editor requirements

Build a 3D runtime editor scene for the selected weapon-owned skill draft.

The editor must show:

* preview actor
* preview weapon
* current editable point
* local onion skin points
* active action plane
* trajectory line
* current weapon and skill context

The player must be able to:

* drag the active point in 3D constrained to the active plane
* rotate/adjust the active plane
* navigate through committed points
* add/delete/commit points
* preview the full authored chain

---

# 7. Onion skin rules

Implement a local 5-point neighborhood around the current selected point whenever enough points exist.

Display:

* current point
* point -1
* point -2
* point +1
* point +2

Transparency rules:

* ±1 points: 50% transparency
* ±2 points: 25% transparency
* current point: full primary focus

If fewer points exist:

* show all valid available neighbors
* do not attempt invalid indices

Update this display live when:

* navigating with Q/E
* adding with R
* deleting with T
* committing with Space
* changing current selection
* editing point position

---

# 8. Trajectory line rules

Implement a spline-like trajectory visualization through the local visible chain.

Requirements:

* it must update live
* it must help show incoming and outgoing path shape
* it must remain readable during point editing
* it must update after navigation, add, delete, drag, and commit

This path is a visual guide.
It does not need to be a final exact production spline in first pass, but it must behave like a stable readable trajectory preview.

---

# 9. Plane editing rules

Implement active action plane editing in the 3D workflow.

Requirements:

* display the active plane or a useful visible plane representation
* allow the player to rotate/adjust the plane
* constrain active point dragging to that plane
* preserve plane state in the authored draft data

Do not hide plane control behind text-only editing.

---

# 10. Session state rules

Separate temporary editor session state from committed draft state.

Session state must track:

* current weapon
* current skill
* current draft
* current point index
* temporary current point edit state
* active plane state
* playback state

Dragging and adjustment should happen in temporary session state first.
Commit with Space writes into the committed draft chain.

Do not mutate committed point data blindly during raw drag interaction unless you intentionally design that behavior and can still preserve stable edit semantics.

---

# 11. Playback requirements inside editor

Implement editor playback as an authoring preview system.

Rules:

* preview starts from point 0 every time F is used
* pressing F again during playback restarts from beginning
* playback runs once then stops
* playback must not overwrite draft data
* playback should use the real or near-real motion solving path used by runtime execution wherever practical
* preview must work on valid incomplete drafts
* if draft is too incomplete for meaningful preview, show clear feedback

---

# 12. Reusable playback rule outside editor

The chain playback logic used by F inside the editor must be reusable outside the editor as a **runtime skill presentation view**.

This is required.

Implement the preview/playback logic so it can drive:

1. **Editor preview playback**

   * one-shot full-chain playback triggered by F

2. **Runtime skill presentation playback**

   * looped playback of a completed/finalized or presentable skill chain
   * shown on a player model wielding the weapon
   * used for skill presentation, inspection, and trading contexts
   * not a pre-rendered video file
   * live runtime playback of the authored chain

Design requirement:

* do not hard-bake F preview into editor-only code
* extract chain playback into a reusable runtime-capable playback component/service

The same authored motion chain should be viewable in:

* crafter preview
* skill presentation UI
* trading/inspection presentation contexts

Use loop mode or repeat mode for presentation view.

---

# 13. Auto-save and restore rules

Implement automatic draft persistence.

Rules:

* leaving the editor auto-saves the current draft into the owning weapon
* returning later with the same weapon restores that draft
* multiple weapons must preserve their own drafts independently
* player must be able to leave, test in gameplay, return, and continue editing later

Do not rely on manual save to preserve work.

---

# 14. Validation rules

Implement validation for at least:

* slot law mismatch
* weapon class mismatch
* use-state illegality
* gear modifier illegality if relevant
* invalid/incomplete draft chain
* protected point deletion if start/root point cannot be deleted

Illegal or incomplete states must not be invisible.

---

# 15. Default baseline rules

When a new melee weapon is created:

* assign a default baseline melee skill package
* baseline should be simple and generic
* example acceptable first-pass baseline: simple 2-point attack chain
* baseline must be editable later through the crafter

This baseline exists so new weapons are immediately usable.

---

# 16. Runtime presentation requirements

Implement a reusable “view skill” style playback mode for finished/presentable authored chains.

Requirements:

* use live runtime chain playback, not video
* show player model wielding the weapon
* play the authored chain on loop
* support skill inspection/presentation contexts
* support trade/presentation contexts
* use the same or shared playback infrastructure as the F preview system

The purpose is to let players visually judge or show off a skill/weapon package.

---

# 17. Functional success conditions

The implementation is successful when all of the following are true:

1. weapon list opens and weapon can be selected
2. skill list opens and skill can be selected
3. editor opens on exact weapon-owned skill draft
4. existing draft restores correctly
5. Q navigates backward safely
6. E navigates forward safely
7. R adds new point after current
8. T deletes current point and moves selection backward safely
9. Space commits point changes
10. current point can be dragged on active plane
11. active plane can be adjusted
12. 5-point local onion skin context displays correctly
13. spline-like trajectory line updates correctly
14. F previews chain from beginning to end once
15. F restarts preview cleanly if pressed again during playback
16. exiting editor auto-saves draft
17. reopening same weapon restores draft
18. new melee weapons receive editable default baseline skill package
19. playback logic is reusable for runtime looped skill presentation view
20. finished skill presentation can show the weapon being wielded and loop the authored chain

---

# 18. Recommended implementation architecture

Use or adapt the following structure.

## Browser / menu flow

* `res://combat/skill_crafter/browser/weapon_skill_crafter_browser.gd`
* `res://combat/skill_crafter/browser/weapon_list_panel.gd`
* `res://combat/skill_crafter/browser/weapon_skill_list_panel.gd`

## Crafter root

* `res://combat/skill_crafter/skill_crafter_root.tscn`
* `res://combat/skill_crafter/skill_crafter_root.gd`

## Session

* `res://combat/skill_crafter/session/skill_crafter_session.gd`
* `res://combat/skill_crafter/session/skill_crafter_selection_state.gd`
* `res://combat/skill_crafter/session/skill_crafter_input_router.gd`

## Data

* `res://combat/skill_crafter/data/weapon_skill_draft.gd`
* `res://combat/skill_crafter/data/weapon_skill_point.gd`
* `res://combat/skill_crafter/data/weapon_skill_plane_state.gd`
* `res://combat/skill_crafter/data/weapon_skill_preview_state.gd`

## Authoring

* `res://combat/skill_crafter/authoring/skill_point_chain_editor.gd`
* `res://combat/skill_crafter/authoring/skill_plane_editor.gd`
* `res://combat/skill_crafter/authoring/skill_point_commit_service.gd`
* `res://combat/skill_crafter/authoring/skill_navigation_service.gd`
* `res://combat/skill_crafter/authoring/skill_point_delete_service.gd`

## Preview / presentation

* `res://combat/skill_crafter/preview/skill_preview_player.gd`
* `res://combat/skill_crafter/preview/skill_preview_pose_driver.gd`
* `res://combat/skill_crafter/preview/skill_onion_skin_renderer.gd`
* `res://combat/skill_crafter/preview/skill_path_renderer.gd`
* `res://combat/skill_crafter/preview/skill_chain_presentation_player.gd`

Important:

* architect `skill_preview_player.gd` and `skill_chain_presentation_player.gd` around shared reusable playback logic, or make one shared chain playback service used by both

## Gizmos

* `res://combat/skill_crafter/gizmos/skill_target_gizmo.gd`
* `res://combat/skill_crafter/gizmos/skill_plane_gizmo.gd`
* `res://combat/skill_crafter/gizmos/skill_gizmo_controller.gd`

## Validation

* `res://combat/skill_crafter/validation/skill_crafter_validator.gd`
* `res://combat/skill_crafter/validation/skill_slot_law_validator.gd`
* `res://combat/skill_crafter/validation/skill_weapon_class_validator.gd`
* `res://combat/skill_crafter/validation/skill_use_state_validator.gd`
* `res://combat/skill_crafter/validation/skill_gear_modifier_validator.gd`

## Persistence

* `res://combat/skill_crafter/persistence/skill_draft_persistence_service.gd`
* `res://combat/skill_crafter/persistence/skill_draft_restore_service.gd`
* `res://combat/skill_crafter/persistence/skill_draft_autosave_service.gd`

## Defaults

* `res://combat/skill_crafter/defaults/default_skill_package_initializer.gd`
* `res://combat/skill_crafter/defaults/default_skill_template_resolver.gd`

## Runtime bridge

* `res://combat/skill_runtime/runtime_skill_binding.gd`
* `res://combat/skill_runtime/runtime_skill_package_resolver.gd`
* `res://combat/skill_runtime/melee_runtime_motion_solver.gd`

---

# 19. Important architecture warning

Do not bury playback logic directly inside editor-only code.

The chain playback system must be reusable for:

* editor preview
* runtime skill presentation
* looped skill viewing / trade presentation

Build the chain playback logic as a reusable runtime-capable layer.

---

# 20. First milestone to implement

Implement the following first milestone before deeper polish:

* weapon list
* skill list
* editor open
* draft restore
* Q/E navigation
* R add point
* T delete point
* Space commit point
* plane-constrained point drag
* 5-point local onion skin
* spline-like trajectory line
* F one-shot preview
* exit auto-save
* reopen restore
* default baseline assignment for new melee weapons
* reusable playback logic extracted enough to support future looped presentation mode

---

# 21. Final instruction to CODEX

Build a runtime melee skill crafter centered on weapon-owned point-chain motion authoring, not dense keyframed animation editing. Respect weapon ownership, point navigation, point insertion/deletion/commit semantics, local onion skin context, spline-like trajectory readability, active plane editing, automatic draft persistence, and reusable chain playback. Ensure the playback system used by F inside the editor can later or immediately be reused as a looped runtime skill presentation view for inspection and trading.

If you want, I can also convert this one into a **compact ultra-strict version** that reads like a task ticket list with zero explanation, just directives.
