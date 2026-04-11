Below is **Pass 2: revised CODEX-ready functional spec v2**.

This version is written in a more implementation-facing style, with the new additions folded in:

* weapon list → skill list → editor flow
* default starter content rule
* default baseline inheritance for new weapons
* Q / E / R / T / Space / F behavior
* 5-point onion skin neighborhood
* spline-like trajectory path
* auto-save continuity inside weapon-owned draft state

---

# CODEX-Ready Functional Spec v2

## The Will — Runtime Weapon-Owned Melee Skill Crafter

### Target: Godot 4.6.1

### Scope: first-pass melee authoring system

---

# 1. Build Goal

Implement a runtime in-game melee skill crafter that allows the player to:

* choose a weapon from a weapon list
* choose one of that weapon’s owned skills from a skill list
* open a 3D editor for that exact weapon-owned skill draft
* navigate through committed motion points
* add a new point after the current point
* delete the current editable point
* move/edit the current point on an active action plane
* commit point changes
* preview the full motion chain from start to finish
* leave the editor with automatic draft persistence
* reopen the same weapon later and continue editing where they left off

The system is runtime-first and weapon-owned.
It is not a generic offline animation editor.

---

# 2. Core Design Rules

## 2.1 Weapon ownership

Each melee weapon owns its own skill profile and its own editable skill drafts.

A draft must be stored with the owning weapon and restored when that weapon is reopened later.

---

## 2.2 Active bar rule

The character’s active bar can select from **1 or at most 2 weapon-owned skill packages**, subject to:

* slot law
* use-state legality
* gear modifiers
* weapon class type

This crafter does not implement the entire active bar, but the authored output must remain compatible with this runtime rule.

---

## 2.3 Slot law rule

The crafter must always operate in the context of:

* a selected weapon
* a selected skill
* that skill’s legal slot box

The player defines motion expression inside the slot’s legal role.
The player does not redefine the slot’s role type.

---

## 2.4 Runtime-only workflow rule

The crafter must operate on runtime weapon and gear state.

Do not build this as an offline-only developer editor.
The preview actor and preview weapon must reflect runtime-owned data.

---

## 2.5 Point-chain rule

A melee skill draft is an ordered chain of committed motion points.

Do not store the authored result as dense raw frame-by-frame skeleton animation for this first pass.

---

## 2.6 Navigation rule

Point navigation means moving between committed points in authored time.

Do not interpret navigation as undo-stack behavior.

---

## 2.7 Persistence rule

Leaving the editor must auto-save the draft into the owning weapon.

Reopening the same weapon later must restore the draft.

---

# 3. Top-Level Menu Flow

Implement the crafter as a 3-step flow.

## Step 1 — Weapon list

Display a list of weapons available for editing.

Player selects one weapon.

## Step 2 — Skill list

After weapon selection, display the selected weapon’s owned skill list.

Player selects one skill.

## Step 3 — Editor

After skill selection, open the 3D editor for that exact weapon-owned skill draft.

Do not open the editor without a specific weapon and specific skill target selected.

---

# 4. Default Content Rules

## 4.1 Developer-made starter content

Starter weapons and their starter skillsets are authored using the same weapon and skill crafting systems used by players.

Do not create a separate fake developer-only skill format.

---

## 4.2 Default baseline for newly created weapons

When a new melee weapon is created, assign it a default baseline skill package appropriate to:

* weapon class
* slot law
* legal combat box

The default baseline should be simple and generic, for example simple 2-point attacks.

Purpose:

* make the weapon immediately usable
* provide a starting draft for later editing

---

## 4.3 Editable default rule

Default baseline skill packages must remain editable unless a later lock/finalization system explicitly restricts them.

---

# 5. Required Runtime Objects

Implement the following conceptual objects or their equivalent structure.

---

## 5.1 Weapon-owned skill draft

Persistent authored draft state for one skill owned by one weapon.

Must contain:

* owning weapon linkage
* owning skill linkage
* ordered point chain
* draft metadata needed for restore
* persistent motion-authoring data needed for preview and later runtime use

---

## 5.2 Skill point

Represents one committed motion checkpoint in the chain.

At minimum it must contain enough data to support:

* point position / target
* point order
* active plane state or equivalent plane reference
* movement direction context on plane if used
* timing for transition if already included in first pass

Optional fields can be added later for:

* grip state
* 1H / 2H state
* reverse grip
* body support values
* transition weights

---

## 5.3 Crafter session state

Temporary in-menu editing state.

Must contain:

* current weapon
* current skill
* current draft
* current selected point index
* current temporary editable point state
* current active plane edit state
* current playback state

Do not mutate committed point data directly during raw drag editing unless explicitly committing.

---

## 5.4 Playback state

Temporary authoring preview state.

Must contain:

* playback active flag
* playback start/reset state
* current playback progress
* current segment or current point progression info

---

# 6. Required Controls

Register and use explicit input actions.
Default bindings must match the following.

---

## 6.1 Q — Previous committed point

Action: `skill_crafter_prev_point`

Behavior:

* move selection to previous committed point if one exists
* do not create data
* do not destroy data
* update current edit context
* update onion skin context
* update local trajectory visualization

---

## 6.2 E — Next committed point

Action: `skill_crafter_next_point`

Behavior:

* move selection to next committed point if one exists
* do not create data
* do not destroy data
* update current edit context
* update onion skin context
* update local trajectory visualization

---

## 6.3 R — Add new point

Action: `skill_crafter_new_point`

Behavior:

* insert a new editable point after the current selected point
* new point becomes active point
* previous point remains part of local context display
* new point is temporary until committed with Space

---

## 6.4 T — Delete current point

Action: `skill_crafter_delete_point`

Behavior:

* delete the currently selected/editable point
* after deletion, move selection backward using Q-like behavior
* update point order
* update onion skin context
* update spline/path display
* update current edit state safely

Edge rule:

* if deletion of the first/root point is illegal, block it cleanly and show feedback
* first pass recommendation: protect mandatory root/start point if the chain requires one stable start

---

## 6.5 Space — Commit current point

Action: `skill_crafter_commit_point`

Behavior:

* if editing a new temporary point, commit it into the ordered chain
* if editing an existing point, commit the updated state
* update local display and point chain state
* keep navigation stable

---

## 6.6 F — Play preview

Action: `skill_crafter_play_preview`

Behavior:

* play the full committed instruction list from start to end once
* preview always starts at point 0
* pressing F again during playback restarts cleanly from the beginning
* playback must not mutate committed draft data

---

# 7. 3D Editor Requirements

Build a runtime 3D editor scene for the selected weapon-owned skill draft.

The editor must show:

* preview character
* preview weapon
* active editable point
* onion skin points
* active action plane
* trajectory path visualization
* skill / weapon context UI

The player must be able to:

* drag the active point in 3D constrained by the active plane
* adjust/rotate the active plane
* navigate points
* add/delete/commit points
* preview the whole motion chain

---

# 8. Point Editing Model

The editor is point-chain based.

Do not build first pass around dense frame editing.

The player workflow must be:

* choose point
* inspect local context
* adjust point on plane
* commit point
* add next point
* preview
* return and refine

The unit of authored progression is the committed point.

---

# 9. Onion Skin and Local Context Rules

Implement a local 5-point neighborhood display around the current point when enough points exist.

## 9.1 Visible neighborhood

When possible, display:

* current point
* point -1
* point -2
* point +1
* point +2

If fewer valid points exist, show as many as are available.

---

## 9.2 Transparency rules

* points at ±1 steps: 50% transparency
* points at ±2 steps: 25% transparency
* current selected/editable point: primary visible focus

---

## 9.3 Behavior near start/end

If the current point is near the start or end of the chain:

* display the valid asymmetric neighborhood that exists
* do not force nonexistent indices

---

## 9.4 Onion skin update behavior

Onion skin / local context display must update when:

* Q is pressed
* E is pressed
* R inserts a new point
* T deletes a point
* Space commits a point
* point ordering changes
* current selection changes

---

# 10. Trajectory Visualization Rules

Implement a spline-like trajectory visualization through the visible/local point chain.

Purpose:

* make path readability clear
* show incoming/outgoing motion context
* support local editing judgment
* improve ease of use

Requirements:

* render a readable smooth-looking trajectory path
* update it live when navigating, adding, deleting, moving, or committing points
* use it as visual guidance only; do not require it to be the final exact motion solver path in first pass as long as it remains a stable readable path guide

---

# 11. Plane Editing Rules

The active action plane must be visible and editable.

Required behavior:

* display the active plane or its useful representation
* allow the player to rotate/adjust the plane
* constrain active point dragging to the active plane
* preserve plane state as part of authored point/segment data where appropriate

Do not hide plane editing behind purely abstract data entry in first pass.

The plane must be part of the direct 3D interaction workflow.

---

# 12. Point Chain Operations

Implement the following point-chain operations cleanly.

## 12.1 Select point

Select current point by navigation or direct internal update.

## 12.2 Add point after current

Create new temporary point after current selection.

## 12.3 Edit point

Allow active point to be repositioned/adjusted before commit.

## 12.4 Commit point

Persist current edit state into the point chain.

## 12.5 Delete point

Remove current point and move selection backward safely.

## 12.6 Read local neighbors

Expose valid point neighbors for onion skin and trajectory display.

## 12.7 Stable ordering

Preserve point order consistently unless explicit future reorder functionality is added.

---

# 13. Playback Requirements

Implement an authoring preview player.

## 13.1 Start behavior

F always begins preview from point 0.

## 13.2 Restart behavior

If F is pressed while playback is active, restart from point 0 immediately and cleanly.

## 13.3 End behavior

Playback runs once and stops at end.

## 13.4 Data safety

Playback must not overwrite, reorder, or mutate committed authored point data.

## 13.5 Compatibility with in-progress drafts

Playback must work on unfinished but valid enough draft chains.

If chain is too incomplete for meaningful preview, show clear feedback.

## 13.6 Preview truthfulness

Preview should use the real or near-real runtime motion path as much as first-pass implementation allows, so preview remains trustworthy.

---

# 14. Auto-Save and Restore Requirements

## 14.1 Save on exit

Leaving the editor must save draft state automatically into the owning weapon.

## 14.2 Restore on reopen

Reopening the same weapon and same skill draft later must restore saved progress.

## 14.3 Multi-weapon continuity

Each weapon must preserve its own separate drafts independently.

## 14.4 Resume editing

Player must be able to:

* leave the crafter
* test the weapon outside
* return later
* continue editing the same draft

No manual save should be required to preserve work.

---

# 15. Validation Requirements

Add a validation layer that can at least detect:

* slot law mismatch
* weapon class mismatch
* use-state illegality
* gear modifier illegality if relevant
* invalid or incomplete draft state
* protected point deletion if applicable

The first pass may surface warnings or soft blocks where appropriate, but illegal states must not be invisible.

---

# 16. Functional Acceptance Criteria

Implementation is successful when all of the following are true.

## 16.1 Menu flow works

Player can open:

* weapon list
* select weapon
* skill list
* select skill
* enter editor

## 16.2 Existing draft restore works

If a weapon-owned draft exists, reopening it restores the draft.

## 16.3 Q works

Q moves to previous committed point without destroying data.

## 16.4 E works

E moves to next committed point without destroying data.

## 16.5 R works

R inserts a new point after current point.

## 16.6 T works

T deletes current editable point and selection moves backward safely.

## 16.7 Space works

Space commits point creation or point edits.

## 16.8 5-point local context works

Current point shows with local onion skin neighborhood:

* ±1 at 50%
* ±2 at 25%
  where valid

## 16.9 Trajectory visualization works

A spline-like path is shown and updates live.

## 16.10 Plane interaction works

Player can edit the active plane and drag the point on it.

## 16.11 F works

F plays full chain once from beginning.

## 16.12 F restart works

Pressing F again during playback restarts from beginning.

## 16.13 Exit auto-save works

Leaving the editor saves the draft into the weapon automatically.

## 16.14 Resume later works

Returning later to the same weapon restores progress.

## 16.15 Default baseline assignment works

New melee weapons receive a simple default baseline skill package and are immediately usable.

## 16.16 Starter content parity is preserved

Developer-authored starter weapons and skills can be created using this same system.

---

# 17. Recommended Scene / File Architecture

Use this as the implementation-oriented architecture target.

---

## 17.1 Browser / menu flow

* `res://combat/skill_crafter/browser/weapon_skill_crafter_browser.gd`
* `res://combat/skill_crafter/browser/weapon_list_panel.gd`
* `res://combat/skill_crafter/browser/weapon_skill_list_panel.gd`

Responsibilities:

* weapon list UI
* skill list UI
* transition into editor

---

## 17.2 Crafter root

* `res://combat/skill_crafter/skill_crafter_root.tscn`
* `res://combat/skill_crafter/skill_crafter_root.gd`

Responsibilities:

* top-level editor scene
* preview world
* UI overlay
* session lifecycle
* exit autosave trigger

---

## 17.3 Session

* `res://combat/skill_crafter/session/skill_crafter_session.gd`
* `res://combat/skill_crafter/session/skill_crafter_selection_state.gd`
* `res://combat/skill_crafter/session/skill_crafter_input_router.gd`

Responsibilities:

* current weapon / skill / draft
* current point index
* temporary edit state
* input routing for Q/E/R/T/Space/F
* playback session state

---

## 17.4 Data

* `res://combat/skill_crafter/data/weapon_skill_draft.gd`
* `res://combat/skill_crafter/data/weapon_skill_point.gd`
* `res://combat/skill_crafter/data/weapon_skill_plane_state.gd`
* `res://combat/skill_crafter/data/weapon_skill_preview_state.gd`

Responsibilities:

* persistent draft structure
* point structure
* plane state storage
* preview state support if needed

---

## 17.5 Authoring

* `res://combat/skill_crafter/authoring/skill_point_chain_editor.gd`
* `res://combat/skill_crafter/authoring/skill_plane_editor.gd`
* `res://combat/skill_crafter/authoring/skill_point_commit_service.gd`
* `res://combat/skill_crafter/authoring/skill_navigation_service.gd`
* `res://combat/skill_crafter/authoring/skill_point_delete_service.gd`

Responsibilities:

* point navigation
* point insert
* point edit support
* point commit
* point delete
* plane editing

---

## 17.6 Preview

* `res://combat/skill_crafter/preview/skill_preview_player.gd`
* `res://combat/skill_crafter/preview/skill_preview_pose_driver.gd`
* `res://combat/skill_crafter/preview/skill_onion_skin_renderer.gd`
* `res://combat/skill_crafter/preview/skill_path_renderer.gd`

Responsibilities:

* full-chain preview
* restart preview logic
* local onion skin display
* trajectory line rendering

---

## 17.7 Gizmos

* `res://combat/skill_crafter/gizmos/skill_target_gizmo.gd`
* `res://combat/skill_crafter/gizmos/skill_plane_gizmo.gd`
* `res://combat/skill_crafter/gizmos/skill_gizmo_controller.gd`

Responsibilities:

* active point manipulation
* plane manipulation
* interactive 3D controls

---

## 17.8 Validation

* `res://combat/skill_crafter/validation/skill_crafter_validator.gd`
* `res://combat/skill_crafter/validation/skill_slot_law_validator.gd`
* `res://combat/skill_crafter/validation/skill_weapon_class_validator.gd`
* `res://combat/skill_crafter/validation/skill_use_state_validator.gd`
* `res://combat/skill_crafter/validation/skill_gear_modifier_validator.gd`

Responsibilities:

* legality checks
* draft readiness checks
* protected delete checks if needed

---

## 17.9 Persistence

* `res://combat/skill_crafter/persistence/skill_draft_persistence_service.gd`
* `res://combat/skill_crafter/persistence/skill_draft_restore_service.gd`
* `res://combat/skill_crafter/persistence/skill_draft_autosave_service.gd`

Responsibilities:

* restore weapon-owned draft
* save weapon-owned draft
* maintain continuity across sessions

---

## 17.10 Defaults

* `res://combat/skill_crafter/defaults/default_skill_package_initializer.gd`
* `res://combat/skill_crafter/defaults/default_skill_template_resolver.gd`

Responsibilities:

* assign baseline skill package to newly created melee weapons
* resolve correct baseline by weapon class / slot law

---

## 17.11 Runtime bridge

* `res://combat/skill_runtime/runtime_skill_binding.gd`
* `res://combat/skill_runtime/runtime_skill_package_resolver.gd`
* `res://combat/skill_runtime/melee_runtime_motion_solver.gd`

Responsibilities:

* bridge authored draft output into runtime combat use
* resolve weapon-owned skill package legality
* provide real runtime motion execution layer

---

# 18. Required InputMap Actions

Create and use these explicit actions:

* `skill_crafter_prev_point`
* `skill_crafter_next_point`
* `skill_crafter_new_point`
* `skill_crafter_delete_point`
* `skill_crafter_commit_point`
* `skill_crafter_play_preview`

Optional extras:

* `skill_crafter_cancel_edit`
* `skill_crafter_rotate_plane_modifier`
* `skill_crafter_drag_target`

Default bindings:

* Q = prev point
* E = next point
* R = new point
* T = delete point
* Space = commit point
* F = play preview

---

# 19. Implementation Warnings for CODEX

Do not do the following:

## 19.1 Do not make Q/E destructive

They are navigation only.

## 19.2 Do not use delete as silent unsafe mutation

T must update selection, visuals, and chain state cleanly.

## 19.3 Do not make onion skin only previous-point-only anymore

Implement the local 5-point context rule.

## 19.4 Do not make the path visualization static

It must update live.

## 19.5 Do not make preview mutate draft data

Playback is read-only relative to authored content.

## 19.6 Do not require manual save to preserve work

Exit autosave is required.

## 19.7 Do not build a dense bone-keyframe editor for first pass

The authored unit is the motion point chain.

## 19.8 Do not detach the editor from weapon ownership

The draft belongs to the weapon.

---

# 20. First Milestone Recommendation

First milestone should prove the full authoring loop, not final polish.

Milestone target:

* weapon list works
* skill list works
* editor opens
* current draft restores
* Q/E navigation works
* R new point works
* T delete point works
* point drag on plane works
* Space commit works
* 5-point onion skin works
* spline-like path visualization works
* F preview works
* exit autosave works
* reopen restore works
* new melee weapons get baseline default skill package

If this milestone works, the core system foundation is proven.

---

# 21. Final Summary for CODEX

Build a runtime in-game melee skill crafter where each weapon owns its own editable skill drafts. The crafter opens through weapon selection, then skill selection, then a 3D editor. The editor is point-chain based. Q and E navigate committed points. R inserts a new point after the current point. T deletes the current editable point and moves selection backward safely. Space commits the current point. F previews the full chain from start to finish and restarts from the beginning if pressed again. The editor always shows a local 5-point context when possible: current point, ±1 at 50% transparency, ±2 at 25% transparency, with a spline-like path through the visible local chain. The active point is edited on a visible action plane. Exiting the editor automatically saves the draft into the owning weapon. Reopening that weapon later restores the draft. Newly created melee weapons receive a simple default baseline skill package so they are immediately usable and editable.

If you want, next I can turn this into an even stricter **“paste into CODEX” implementation prompt** with imperative wording only, no narrative.
