# SC-04 — Skill Crafter action Undo/Redo

Prepared 2026-10-26, Europe/Bucharest. Status: **documentation and current-code investigation only; implementation not authorized by this preparation request**.

SC-03 subsequently received qualified user acceptance: working with manual reacquisition after a 17-position test; remaining matrix coverage and reported faults are deferred. This Undo/Redo preparation neither certifies that broader matrix nor changes its rules.

## Intended outcome

Undo and Redo should let the creator correct an authored change without rebuilding a motion pose. The recorded contract already distinguishes editing an existing motion node from creating or deleting timeline nodes.

| Confirmed rule | Meaning |
| --- | --- |
| Ctrl+Z / Ctrl+Y | Undo / Redo in the editor that owns focus. |
| Isolated history | Skill Crafter must not consume or modify Forge's history. |
| One gesture, one action | A continuous drag is a single before-to-after change, regardless of frame count. |
| Branching | A new authored action after Undo clears the Redo branch. |
| In-node coverage | Control-point placement, pose, hand roles, grip position, timing and other authored changes within an existing motion node. |
| Excluded navigation | Selection, camera movement, debug visibility and opening menus are not history actions unless they deliberately alter saved work. |
| Separate structural workflow | Undo/Redo must not create or remove motion nodes. R/T node operations remain explicit and separate. |
| Consistent station behavior | Apply the same action ownership across Skill Crafter authoring pages. |

These rules come from the earlier shared editor contract; today adds investigation and consolidation, not a new design decision. The earlier word "control node" means the motion-node workflow in this contract; undoing a control point's position must not delete the containing motion node.

## Current implementation — inspected 2026-10-26

Skill Crafter currently has **no connected action journal or Ctrl+Z/Ctrl+Y dispatch**. Its R recording and prepared-pose snapshots are not Undo history. `CombatAnimationDraft.begin_action_storage()` is a serialization mode and must not be mistaken for an undo transaction.

Paths below are relative to `The Will- main folder/the-will-gamefiles`.

| Owner | Relevant current behavior |
| --- | --- |
| `runtime/combat/combat_animation_station_ui.gd` | Owns input, editable node/draft setters, drag completion, preparation and Save. `_apply_motion_node_change()` and `_stage_active_wip_edit()` run after mutations; before-values must be captured earlier. |
| `runtime/combat/combat_animation_motion_node_editor.gd` | Tracks drag target and gesture activity through `begin_drag()` / `end_drag()`; it does not own document history. |
| `core/models/combat_animation_session_state.gd` | Transient selection, focus, playback and view state; currently no history owner. |
| `core/models/combat_animation_motion_node.gd` | Authored controls and current prepared pose. Node IDs currently derive from indices when blank; they are not a proven stable unique journal identity. |
| `core/models/combat_animation_draft.gd` | Insertion/deletion and normalization can shift indices. Its initialized-authoring marker records section ownership, not action history. |
| `core/models/combat_prepared_pose.gd` | Determines current pose signatures. Timing/curve edits and pose edits have different invalidation requirements. |
| `runtime/system/user_settings_runtime.gd` | Skill Crafter navigation/creation/playback bindings exist; dedicated Skill Crafter Undo/Redo bindings do not. |
| `runtime/forge_v2/forge_v2_action_history.gd` | Existing record-only chronological container, with push/peek/confirm, branch invalidation and optional Undo batching. It contains no Skill Crafter integration. |

Specific seams in the current UI:

- Ordinary viewport drags create a temporary node, then `_finalize_preview_drag()` commits an accepted change once. Illegal and unchanged drags are already distinguishable.
- Weapon-roll dragging is different: motion samples mutate the live node; release mainly refreshes controls. A journal must capture the gesture's starting state rather than record every sample.
- Numeric fields currently use `value_changed`. Number typing, spinner holds and individual confirmations need an agreed grouping rule.
- `_record_before_motion_node_action()` owns the R/navigation capture boundary. Do not replace that workflow with Undo.
- `capture_selected_prepared_pose()` and asynchronous acquisition can complete after the initiating gesture. Their resulting data belongs to that gesture's revision, not to a second user action.
- Normal/reverse style changes currently create a generated bridge plus a following editable node. Reset replaces the active visible chain. Those are structural operations, not simple in-node scalar changes.

## Decisions to settle before implementation

1. **History scope and lifetime — NEEDS_DECISION.** Is the chronological journal limited to the current motion node, shared across one skill/idle section, or retained across multiple sections with explicit ownership? Specify what happens on node navigation, section/WIP switching, Save, editor close/reopen and application restart. Forge's lifecycle provides a reference, not an automatic answer for Skill Crafter.
2. **Structural boundaries — NEEDS_DECISION.** R/T must remain outside Undo. Define whether adding/deleting a motion node clears a journal, prunes only affected records, or retains records for surviving nodes. Deleted targets must never silently redirect to the next node with the same index. Define Reset's history effect. Generated grip-flip insertion cannot be undone by deleting its nodes under the current no-node-creation/deletion rule; do not silently change that rule.
3. **Continuous controls and input ownership — NEEDS_DECISION.** Define numeric typing/spinner grouping, whether held Undo/Redo uses Forge's accelerated repetition and batch semantics, and whether dedicated rebindable actions are wanted immediately. Editing text must retain its own text-Undo behavior; the scene journal must not also consume that same keypress.
4. **Busy/pending work — NEEDS_DECISION.** Specify behavior when Undo arrives during an active drag, grip acquisition, F preparation/playback or Save. Do not invent queuing, cancellation or a new global input lock without agreement. An old asynchronous result must never overwrite a newer Undo/Redo state.

The history capacity/memory policy is also not yet specified for Skill Crafter. Forge's five-CSG consolidation floor has no equivalent here and must not be copied across. Do not assume "five undo actions" or unbounded copies of complete weapons.

## Proposed implementation approach — for review

1. Resolve the scope/lifetime and structural-boundary decisions above, then choose a bounded first acceptance slice.
2. Choose a transient history owner and stable target identity. Do not use a mutable timeline index or assume the present `node_id` is unique. Preserve existing public IDs/names unless a migration is explicitly agreed.
3. Reuse the existing journal's record/confirmation semantics where appropriate, or assess Godot 4.7's native UndoRedo before selecting an implementation. The Forge-named file is generic in behavior but its location/name is not permission for a broad move or rename. Forge's active history must remain independent.
4. Capture the whole affected authored relationship before and after a gesture. Roll can change endpoints/orientation together; grip or role changes can affect several related fields. Undo must not restore only the number on the clicked control while leaving dependent values behind.
5. Apply history through the existing validation, refresh and prepared-pose lifecycle. Reuse matching stored poses where valid; otherwise request the normal preparation path. Never stamp an old prepared signature onto incompatible controls or loosen grip/reach checks to make Undo pass.
6. Keep payloads scoped to affected nodes/settings and required prepared data. Avoid a complete WIP, library, generated clip or geometry copy per mouse sample. New shoulder/spine controls should fit the same node/capture contract when introduced later.
7. Move the history cursor only after the chosen replay transaction succeeds. Keep failure/dirty-state reporting truthful, and suppress recursive journaling while applying Undo/Redo.
8. Cover the agreed first slice before expanding coverage to every station page. No production files are selected for immediate editing by this document.

Current likely integration files are the UI, settings bindings and a transient session/history owner. Motion-node identity changes depend on the decision above. Reuse existing preview/capture owners rather than creating another grip solver or saved-pose format.

## Completion checks for the future implementation

- One drag containing many samples produces one history entry; unchanged/rejected gestures produce none.
- Undo/Redo restores the entire affected authored state, including coupled endpoint/orientation changes; it does not merely approximate the visible result.
- A new edit after Undo discards the correct Redo branch. Navigation/camera changes do not.
- Numeric edits and held input obey the chosen grouping policy.
- R/T, Reset and generated grip transitions obey the agreed structural boundaries; surviving records never target a renumbered or deleted neighbor.
- Skill/idle/WIP transitions and Save/reopen obey the chosen journal lifetime and preserve unrelated sections.
- Text fields, popups, rebinding and Forge/Skill Crafter focus cannot cause two histories to consume one shortcut.
- Pending acquisition or preparation cannot apply stale results after Undo/Redo; recorded poses and F caches match restored controls.
- F and Save after Undo/Redo consume the restored state; saved equipped playback uses the same result.
- No per-frame whole-document history growth. Performance is measured on realistic edit sequences.

No new runtime or automated tests were run for this preparation. SC-01's passing tests and SC-02's user acceptance do not certify Undo/Redo.

## Sources and retained history

- [Shared Skill Crafter editor contract](Skill%20Crafter%20Unified%20Implementation%20TODO%202026-04-30.md), "Shared Editor Undo/Redo Contract" (lines 943–969): direct SC requirements. Its later handle-placement UI note also requires integration with this contract.
- [Forge V2 Undo/Redo scope](Forge%20V2%20Action%20Undo%20Redo%20Work%20Scope%202026-08-30.md): shared action semantics and parked Skill Crafter follow-up. Forge-specific CSG limits, native acknowledgements and Handle transactions remain Forge scope.
- [2026-08-30 15:07 SPS](../SPS/SPS_2026_08_30_15-07.md): records Forge's implementation and explicitly states Skill Crafter Undo was still future work. Historical test counts apply to that Forge pass only.
- [SC-01 lifecycle](Skill%20Crafter%20Node%200%20Defaults%20And%20Section%20Reset%20Lifecycle%202026-10-26.md): saved-node priority, explicit Reset acquisition, selected-section Save and prepared-data validity that Undo must preserve.
- [Playback availability investigation](Skill%20Crafter%20Playback%20Availability%20Investigation%202026-10-25.md): R/F/Save ownership and retained authored/prepared data.
- [Project TODO](Project%20TODO.md): SC-04 is the single checklist entry for this outcome. SC-03 records the later qualified user acceptance separately.

No older source was rewritten. Current explicit user decisions will resolve the open points when this topic is discussed.
