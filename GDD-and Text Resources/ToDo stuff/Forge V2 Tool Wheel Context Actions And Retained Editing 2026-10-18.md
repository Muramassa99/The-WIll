# Forge V2 tool wheel, context actions and retained editing - 2026-10-18

## Authority and savepoint

User-approved workflow discussed October 18. Savepoint before changes:
37a84f84, `Forge v2 additions - guided views and smooth spline twist`, pushed
to recovery/stable-92b8a24-chat14. Preserve the accepted shared sweep geometry.
Read How To Do Menu Work.md for popup ownership, pointer placement, dismissal,
and preservation of the parent workspace. Current user decisions supersede the
old RMB Apply / Alt+RMB radial triggers in forge_v2_design_notes.md.

## Agreed controls

- Hold Q, point, release: tool radial using the same visual basis as V. Four
  outer tools: CSG Material Stroke, Spline Line, Handles, Detailing Brush.
  Two inner actions: Add on the left, Remove on the right, occupying the full
  centre. Releasing Q outside the drawn radial cancels; Q does not use V's
  centre-cancel convention. V retains its existing behavior. Releasing without
  moving from the centre keeps the current operation.
- Add/Remove changes the current operation immediately, without Apply/Cancel.
  Existing material and protected-Handle restrictions remain authoritative.
- Switching to a different tool with unfinished work requires Apply/Cancel.
  Dismissing that popup aborts the switch and preserves the unfinished work.
  Apply must succeed before switching; Cancel discards that unfinished operation
  through its existing cancel command, then selects the requested tool.
- Selecting the already-active tool does not require confirmation.
- Plain S opens a temporary Apply/Cancel popup at the pointer, for the active
  authoring context. Ctrl+S remains Save Draft; text entry keeps its keys.
  Spline Apply calls Generate CSG Noodle; Handle Apply calls Generate Handle or
  Apply Handle Change; Detailing Apply calls Generate Detailing Brush. Per the
  later October 18 correction, these Apply commands then commit pending material
  in chronological order before completing or selecting a queued tool. Cancel
  uses the existing cancellation command. No parallel generation logic.
- CSG freehand currently completes on gesture release. S must not invent a
  destructive "cancel the last finished stroke" operation for this mode.
- B, L, H lose their default tool bindings; Q offers the same tools.
- Reserve 1-6 for future profile slots. Assignment and recall are explicitly
  deferred by the user. Future slots are independent for each tool (up to six
  per tool); there is no new assignment UI in this pass.
- Each tool remembers its most recently selected profile configuration. Keep
  this state separate from profile-library editor selection and from material,
  operation, camera and point drafts. No separate unfinished draft per tool.
- V, LMB, RMB orbit/double-click alignment, C+RMB/MMB pan, Ctrl shortcuts,
  Space/Shift+Space, Escape, F and Home retain their established roles.

## E selection / retroactive editing agreement

E toggles selection view. Temporary tints overlay existing material/finish and
disappear afterward. LMB chooses a supported piece and exposes its path/twist
controls. Use the normal arrow cursor during selection and editing; hide the
cursor-following deposition ball, retaining actual point and twist controls.
S Apply/Cancel will also route to the active retroedit transaction.

Five gradient colors rank the editable splines among retained operations:
green #48BF72, yellow-green #A5C94A, yellow #E9D34E, amber #EAA43A,
dark orange #D87928. Fewer editable splines span the same range; one is green.
Red #C64F4F means unavailable (including fused and non-spline operations),
purple #A77AD9 identifies the protected editable Handle. Hover identifies the
specific selectable surface. Original material resources must not be modified.

Five ordinary history slots are shared with freehand operations; freehand still
consumes a slot but is not reopened as a spline. Editing preserves the original
operation's identity, chronological position and age. Handle is separate.

## Implementation order and verified architectural gaps

First implement the Q/S input workflow, per-tool profile memory and reserved
profile shortcuts. Then implement E against an actual bounded replacement
transaction, not UI-only selection pretending that retained bodies are editable.

Current bounded native continuation supports same-material Add/Replace only.
Saved-profile free-space splines are excluded by authoring, layer and presenter
eligibility checks. General Remove/multimaterial native continuation is separate
material-aware checkpoint work; Q must use existing operation rules.

E needs retained-source reopening, atomic native suffix replacement (at most
five operations), chronological accounting reconstruction, stable source picking,
one undoable Apply and correct promotion of the undo floor. Existing generic
document snapshots cannot undo committed ordinary-body replacement. An edit
record must not survive after its owner becomes fused. Current native surface
provenance only distinguishes newest operand versus earlier aggregate; it does
not already identify all five retained pieces. See focused audit before changing
the checkpoint contract. Pending/failed transactions must preserve prior geometry.

### E architecture and transaction handoff - implementation plan

This is a static code audit and proposed implementation contract, not completed
E behavior or fresh runtime verification. Scope remains the agreed E workflow;
general Remove/EmptyOnly/multimaterial checkpoint support and profile-slot
assignment are not added by this plan. Method names below are proposed seams.

#### Existing native APIs and bounded cost

Ordinary Add/Replace replacement does not require a new C++ API. Instantiate a
separate `ForgeV2ManifoldBoolean` with `ClassDB.instantiate`, enable history with
`set_history_window_enabled(true)`, and seed it using
`reset_checkpoint_mesh(vertices, indices, checkpoint_operation_count)`. Without
S0, use `reset_mesh` for the first retained operand. Replay the retained ordinary
timeline with `add_mesh`, in original order, at most five operations. When
restoring an existing redo timeline, append active plus redo operands, then
`undo_state` for the redo count. A new successful Apply abandons redo under the
existing action contract.

Reuse current materialized S0 data when possible. Otherwise export S0 from the
still-live backend once for the explicit Apply/replay transaction. This exports
aggregate geometry, not historical operations. Never add checkpoint export or
candidate reconstruction to normal append/promotion, hover or point movement.
Validate each native result, revision progression, checkpoint count, cursor and
retained capacity. No new native `.h`/`.cpp` change is needed for this mechanism.

Keep the old backend while preparing the candidate. Each engine holds at most
six states, so explicit Apply/Undo/Redo of a replacement can temporarily retain
up to twelve states across both engines, plus the aggregate packet. Normal
active history remains S0 plus five. This is a bounded memory/export tradeoff;
do not claim a six-state whole-process peak during replacement.

Presenter `_restore_bounded_native_static_lane` already has the replay sequence,
but resets the active backend. Extract/reuse its preparation and operations
without the destructive `_reset_native_static_lane` branch. Reuse the capability
checks/history initialization in `_ensure_native_static_backend` through an
independent candidate factory.

#### State/controller/presenter handshake

Proposed state interface:

```text
begin_retained_spline_change(body_id)
is_retained_spline_change_active()
build_retained_spline_change_candidate()
accept_retained_spline_change_candidate(candidate_token)
cancel_retained_spline_change()
```

Controller owns begin/cancel wrappers, Apply/history-replay requests, local edit
actions and completion/rejection callbacks. Presenter prepares exact operands
and the independent backend, stages geometry, reports collider readiness and
installs successful publication. Candidate failure discards only the candidate.

Keep original committed body/layer authority while editing a transient source
duplicate. Retain persisted polygon, anchor, path, normals, rolls, material,
operation and placement policy; do not rebuild from a changed library preset.
Apply preserves body ID, source-record ID, layer ID, slot, order and age. It
does not call ordinary append/commit or increment lifetime-operation count.

Candidate handoff fields:

```text
candidate_token                 unique request identity
reason                          apply / undo / redo
state_instance_id               owning AuthoringState instance
baseline_transition_revision    rejects stale logical work
checkpoint_identity             ID, revision/digest and operation count
source_body_id, source_layer_id stable authored owner
source_body_index, layer_index  checked positions, not identity substitutes
before_source, after_source     bounded immutable source snapshots
candidate_tail_bodies/layers    original order; at most five ordinary operations
candidate_redo_bodies/layers    explicit restoration timeline and desired cursor
candidate_ledger/resolver       prepared accounting/cache authority
before_editor_context          pre-E transient/tool/profile state for Cancel
```

Presenter adds candidate backend, native result/revision, operand packets,
publication generation and staged node. Fresh backends have their own revision
sequence: never compare candidate native revisions against the live engine's
revision. Check both logical baseline and publication generation on callbacks.

Prepare exact operands before publication. Keep old collider/backend valid
while the candidate waits for process/physics readiness. At the existing
`_publish_native_static_stage_after_update` swap seam, revalidate token/baseline,
then install prepared state/backend/publication in one non-yielding completion.
Only then record/confirm the action and notify observers; retire old publication
afterward. Any validation, Boolean, mesh or readiness failure keeps committed
state, publication and action cursor unchanged.

Do not directly use `_accept_bounded_native_result` for the candidate: it
updates live metadata and can acknowledge logical state before readiness.
Candidate rejection also must not use `_handle_native_static_publication_failure`
or `_reject_bounded_native_fast_lane`, which can suspend/reset the live lane.
Provide a candidate-only cleanup path.

Protected composition must read candidate geometry. Currently
`_build_native_static_revision_node` calls protected helpers using the global
`native_static_manifold_backend`. Pass an optional backend through clip/build
helpers, or deliberately use `_build_native_static_handle_composite_revision_node`
with candidate aggregate vertices and the unchanged Handle. Never clip the old
engine and label its mesh with candidate identity.

Capture pre-E context with `capture_editor_transient_snapshot`, including tool
profile memory. Cancel restores directly through snapshot restoration, not tool
or profile setters that may cancel another transaction or clear a draft. Seed
working profile data from the body without overwriting unrelated tool memories.
Apply history records affected operation state and any applicable E profile
edits; it must not rewind unrelated tool selections or every tool's profile.
Selection/entering E are not authored actions.

#### Exact owner seams and saved-profile eligibility

- `forge_v2_authoring_state.gd`: retained membership, edit session, candidate
  creation/install, replacement transition. `_find_editable_material_body`
  rejects committed bodies; add a dedicated retained-edit path instead of
  weakening pending-body rules.
- `forge_v2_layer_data.gd`: recompute input snapshots/accounting while retaining
  identity/order. `configure_from_material_bodies` currently creates a new layer
  ID, so it cannot be used unchanged for replacement.
- `forge_v2_material_volume_resolver.gd`: use
  `restore_incremental_committed_cache_from_checkpoint` on a separate candidate
  resolver. Recompute subsequent affected layer deltas, because overlap
  attribution changes even with the same material. Updating only the selected
  body's geometry or stored ledger delta is insufficient.
- `forge_v2_volume_preview_presenter.gd`: exact operands, independent native
  candidate, protected composition, staging/readiness and publication swap.
- `forge_v2_stage_controller.gd`: semantic Apply/Undo/Redo, pending confirmation,
  local edit history and checkpoint-dependent action pruning.
- `crafting_bench_ui_v2.gd`, `forge_v2_workspace_preview.gd` and keybinding
  state: E/LMB/S routing, normal cursor, deposition-ball visibility and temporary
  selection presentation. Material mutation stays below UI.

Saved-profile splines use `BODY_KIND_PROFILE_EXTRUSION` and
`SHAPE_KIND_SPLINE_PROFILE_PATH`. Extend that exact supported case consistently
in state `_is_body_bounded_add_history_eligible`, LayerData
`is_bounded_add_history_eligible`, presenter `_validate_native_static_body`, and
`_build_native_static_operand_packet`. Reuse accepted profile/spline/twist
geometry; do not manufacture explicit surface-contact authority for free-space
splines just to pass the old gate. Current capsule operands already use exact
Godot CSG staging where required. Preserve material/Handle restrictions.

#### Tint/source provenance and undo readiness

Native `source_original_ids` currently means latest operand versus earlier
aggregate. It does not contain stable IDs for five retained bodies. E needs an
explicit bounded mapping from displayed surviving surfaces to checkpoint,
retained-body and Handle identity. Hover, tint and LMB must agree through overlap
and Apply/Undo/Redo; retained noneditable/freehand geometry is red. Raw
overlapping operand meshes do not prove final-surface ownership. The candidate
transaction solves replacement, but this source-mapping gap remains a required
part of E. Do not mutate shared material definitions for temporary tints.

Controller `_capture_document_action_snapshot` captures pending bodies,
protected Handle and transient state, not ordinary committed edits. Add a
dedicated replacement action with stable owner IDs and bounded before/after
source data. Local point/twist edits remain undoable in the edit session;
successful Apply becomes one global replacement action.

`undo_latest_action`/`redo_latest_action` currently confirm after synchronous
`_replay_action_record`. Replacement may await operand baking and readiness.
Keep the action cursor fixed through a pending confirmation token; confirm on
successful publication, cancel on failure, and block concurrent authoring while
pending. Held-Undo/Redo batches need the same atomic replay/failure behavior.

`_advance_action_history_checkpoint_floor` currently prunes through original
material-layer creation. A later edit to that owner would survive promotion and
target baked geometry. Track owner IDs in replacement records and batches;
retire the chronological prefix through the latest action dependent on the newly
promoted owner. Prune only after successful promotion acknowledgement. Deferred
or failed promotion must not move the floor.

#### Work division and focused acceptance

Separate parallel work by files: one agent owns state/LayerData transactions;
another owns presenter operands/native candidate/publication; integrator owns
controller actions and UI/input. Agree handoff fields before editing shared
owners. Keep Q/S test results distinct from E completion.

Focused acceptance: edit oldest/middle/newest retained splines after S0 exists;
freehand shares five-slot age but cannot reopen; saved-profile point/twist
geometry; protected Handle; unchanged IDs/order/age; tint/hover/pick agreement;
one Apply action; Cancel; Undo/Redo/branch and held replay; later append/promotion
and correct undo floor; save/reload; stale callbacks and injected candidate,
operand or publication failures preserving prior state. Confirm no historical
operation replay, candidate construction during point motion, or new S0 export
on normal append/promotion. This audit and Q/S-only checks are not E runtime proof.

## Owners and verification

Q/S routing: crafting_bench_ui_v2.gd and forge_v2_keybinding_state.gd, with
forge_v2_workspace_action_menu.gd owning temporary command surfaces and routing.
Radial presentation: forge_v2_radial_menu.gd, with backward-compatible V behavior.
Profile memory/plain tool activation: forge_v2_authoring_state.gd and
forge_v2_stage_controller.gd. New focused tools verify these owners plus popup
interaction. No new profile-library schema or assignment interface is needed.

Check Q release/cancel/focus/text guards, four outer and two inner targets,
unchanged V, modifier-exact S versus Ctrl+S, Apply/Cancel per tool, failed Apply
retaining work, canceled tool switch, Add/Remove without confirmation, per-tool
profile recall, undo coherence, and no mutation from reserved number keys.
One substantial Godot run at a time. Editor alone is allowed to remain open.
No additional Git operation is authorized by implementation permission.

Official Godot 4.7 references consulted for this slice:
- https://docs.godotengine.org/en/4.7/classes/class_popupmenu.html
- https://docs.godotengine.org/en/4.7/classes/class_control.html
- https://docs.godotengine.org/en/4.7/tutorials/inputs/inputevent.html
- https://docs.godotengine.org/en/4.7/classes/class_viewport.html
- https://raw.githubusercontent.com/godotengine/godot/4.7/scene/gui/base_button.cpp

## Status

Q/S, independent tool-profile memory, and reserved profile keys are implemented
locally. E selection/retroactive editing was implemented in the October 18
follow-up below; use that follow-up for current verification and boundaries.
Profile-slot assignment remains explicitly deferred. No additional Git push was made.

Ordinary Shape tool choices and cross-family profile-editor actions use the same
unfinished-work gate. Basic profile edits keep an active Spline/Detailing tool
and its path. Confirmation from the profile editor belongs to that editor's
window; dismissal preserves the parent. If Apply starts deferred material work,
the requested tool/profile waits until it can be selected. Apply cannot run twice.
Escape abandons only that queued switch, retaining already-applied geometry.

Profile memory is saved with each WIP, separated by tool, copied without shared
mutable aliases and included in authoring snapshots. Transient profile Undo is
field-scoped to its owning tool. Document/Handle/layer replay preserves later
profile choices on unrelated tools. Direct WIP snapshot restoration remains exact.

Fresh verification on 2026-10-18, isolated diagnostic user data, serialized runs:

- `verify_forge_v2_workspace_actions.gd`: final headless 198/198; final rendered
  D3D12 Forward+ 216/216, no engine errors. Real embedded-window mouse dispatch
  checks Apply/Cancel, outside dismissal, no workspace click-through, nested
  profile confirmation, deferred completion, key/focus guards, and unchanged V.
  Report: `test_artifacts/forge_v2_workspace_actions_20261018.json` (final rendered).
- `verify_forge_v2_tool_profile_memory.gd`: 159/159, including profile save/reload,
  separate choices, transient and document/committed/Handle replay, and same-tool
  profile editing with actual nonempty Spline/Detailing paths.
  Report: `test_artifacts/forge_v2_tool_profile_memory_20261018.json`.
- `verify_forge_v2_saved_handle_profile_selection.gd`: 36/36.
  Report: `test_artifacts/forge_saved_profile_selection_2026-10-18T02-44-27/report.json`.
- `verify_forge_v2_saved_basic_profile_deposition.gd`: exit 0, `ok=true` in its
  report; log `godot_runs/forge_workflow_saved_basic_20261018.log`.
- Earlier in this slice, `verify_forge_v2_tools_radial.gd` passed 133/133. Final
  rendered workspace checks also exercise Q and V after label-spacing adjustment.
- UI parses and scoped `git diff --check` pass. Rendered Q and context popup
  captures inspected: `test_artifacts/forge_workflow_20261018/workspace_q.png`
  and `workspace_switch_popup.png`.

Verification boundaries: the old action-undo integration run was stopped during
its 5,000-point stress section; it is NOT a pass. Focused Undo cases above passed.
No full-game stress test or E runtime claim. Initial popup-click failures were
test input routing errors: embedded Window hover must be driven through its
embedder, not direct popup.push_input. Fixed fixture and reverified real buttons.
Saved Basic fixture now chooses its profile after selecting Spline; saved Handle
fixture checks its pending body before Save and committed adapters afterward.

## Follow-up: smoothing preference and radial size - 2026-10-18 03:05

User requested a default smoothing strength of 4 with persistence restored,
both Q/V menus enlarged uniformly to 1.5x, and a hand icon for manual CSG Stroke.
Implemented locally; no new Git operation. E editing remains future work.

Smoothing previously existed only on the session workspace contract and reset
on process restart. New core model `forge_v2_editor_settings_state.gd` uses the
existing `PersistentResourceStateIO` helper to store the chosen 0-10 strength in
`user://settings/forge_v2_editor_settings.tres`. No saved preference means 4;
an explicitly saved 0 stays 0. The controller loads it when creating the workspace
contract and persists slider changes immediately. New drafts and Undo do not
reset it. UI reports a preference-save failure while retaining the session choice.
This is a Forge preference, separate from WIP data and document history; it does
not add persistence for arbitrary actions or implement deferred profile slots.

`forge_v2_radial_menu.gd` now uses one 1.5 scale for Q and V, including geometry,
text, icons and line widths. Normal outer radius is 150 UI units; existing small
viewport fitting remains. Manual CSG Stroke uses a code-drawn open hand. Selection
and cancellation semantics are unchanged.

Fresh verification, serialized engine runs with isolated diagnostic user data:

- `verify_forge_v2_editor_settings.gd`: three separate processes, seed 4/4,
  zero 4/4, reload 7/7. Confirms default 4, explicit 0, later choice 7, draft
  retention, bounds and uncached disk read. Logs:
  `godot_runs/forge_preferences_{seed,zero,reload}_20261018.log`.
- `verify_forge_v2_tools_radial.gd`: 133/133 after resizing boundary fixtures.
- `verify_forge_v2_workspace_actions.gd`: rendered D3D12 Forward+ 221/221,
  including actual Settings slider persistence and Q/V input regressions.
  Latest report: `test_artifacts/forge_v2_workspace_actions_20261018.json`.
- Rendered `test_artifacts/forge_preferences_20261018/workspace_q.png` and
  `workspace_v.png` inspected for spacing, hand readability and full scaling.
- Existing generic-volume layering fixture now injects its own diagnostic
  preferences before forcing smoothing 0, so future runs cannot overwrite
  the player's choice. Parse checked; its geometry suite was not rerun.
- Scoped diff checks passed; only the existing Godot editor remains running.

First parse exposed a new-class constructor lookup before editor import; fallback
construction now loads the script explicitly. All results above are after that
correction. The unchanged stabilizer's reset-to-zero internal state is deliberate;
the selected strength is supplied when a stroke begins.

Official Godot 4.7 ResourceSaver, ResourceLoader, ConfigFile and CanvasItem
references were checked; existing Resource persistence was chosen for consistency:
- https://docs.godotengine.org/en/4.7/classes/class_resourcesaver.html
- https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html
- https://docs.godotengine.org/en/4.7/classes/class_configfile.html
- https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html

## Follow-up: reference wheel icons and positions - 2026-10-18 03:15

User clarified the supplied radial drawing: top manual CSG hand, right Detailing,
bottom Handles, left Spline; centre left writing pen for Add, centre right eraser
for Remove. This supersedes the earlier right-Handles/bottom-Detailing arrangement.

Updated the actual Q tool entry order and its workspace input fixture. Redrew
the symbols in the shared radial presenter: filled angled hand with palm creases,
smooth four-point Spline, angular multi-point Detailing, T-cap patterned Handle,
writing pen and eraser. The original hand asset could not be identified locally
or online, so this is a vector interpretation of the supplied reference, not a
claim of importing the exact original pixels. No downloaded candidate icons
were added to game assets. Labels, 1.5x size and Q/V input rules are retained.

Fresh rendered workspace check: 221/221 passed after the position changes.
Inspected `test_artifacts/forge_hand_icon_20261018/workspace_q.png`; engine log
`godot_runs/forge_hand_icon_workspace_20261018.log`. Scoped diff check passed;
only the editor remains open. No Git operation. E editing remains future work.

## Follow-up: supplied Q icon atlas - 2026-10-18 03:56

User supplied `assets/ui_v2/Radial menu 1` with `forge_icons.png`, `atlas.json`
and six individual 512px PNGs, and authorized renaming/moving for actual atlas
usage. Folder is now `assets/ui_v2/forge_radial`. Original PNG/JSON contents and
individual images are preserved. `512/.gdignore` keeps the standalone source
images out of runtime imports/exports; the atlas is the display asset.

The 1536x1024 PNG contains six 512x512 tiles. Read-only pixel audit confirmed
every region matches its corresponding individual RGBA image, with transparent
background, partial-alpha edges and at least 48px padding. JSON owns the crop
coordinates. `forge_v2_radial_menu.gd` preloads both PNG and native JSON resources,
caches six Godot AtlasTexture views with filter clipping, and draws the supplied
art at the existing icon locations. The procedural Q icon implementations have
been removed. V's drawn face icons and Q/V interaction are unchanged.

Mapping: manual hand -> top CSG Stroke; node path -> left Spline; extruded profile
-> right Detailing; wrapped handle -> bottom Handles; draw tool -> centre-left
Add; eraser -> centre-right Remove. Native PNG import is lossless, full dimensions,
alpha-border fixing and mipmaps enabled; radial-local linear mipmap filtering
handles reduction from 512px cells to menu-sized images.

Fresh Godot 4.7 import exited 0. Rendered workspace input check passed 221/221,
using isolated diagnostic user data. Inspected the actual atlas artwork in
`test_artifacts/forge_atlas_20261018/workspace_q.png`. Log:
`godot_runs/forge_atlas_workspace_20261018.log`. Scoped diff check passed.
No full-game export run or claim; PNG and JSON are explicit native resource
dependencies. Only the existing editor remains open. No Git operation.

Official references: Godot 4.7 AtlasTexture and image import documentation above,
plus native JSON resource support verified against
https://raw.githubusercontent.com/godotengine/godot/4.7/core/io/json_resource_format.cpp.

## Follow-up: E retained editing - 2026-10-18

User selected implementation with "let's do E". The actual retained-edit path
now exists. E enters temporary selection; LMB opens a retained spline or the
separate protected Handle. Original materials are untouched. Green through
dark orange identifies editable spline age, unavailable surfaces are red,
Handle is purple, and hover brightens the selected owner. Normal arrow cursor
replaces the deposition ball during selection and editing. Existing point drag,
Space/Shift+Space and twist controls operate on the reopened source.

S uses the existing context menu to Apply or Cancel. E exit or Q tool change
with an unfinished edit uses that same gate. Escape cancels the current edit
back to selection, then exits selection without closing Forge. No profile-slot
assignment was added. Add/Remove and the existing Q/V atlas remain separate.

AuthoringState edits detached source data, retaining saved polygon, anchor,
rolls, path, material and operation identity. LayerData recomputes accounting
while retaining IDs/order/age. Apply prepares a separate native engine from S0
plus at most five retained ordinary operands, with saved-profile spline support.
The old solid/collider remains authoritative until candidate readiness and
token validation; the final state/backend/geometry swap is non-yielding.
Candidate failure retains original geometry and the editable draft. Point
motion does not rebuild the Boolean result or export the checkpoint.

The controller gives the draft its own Undo journal. Apply adds exactly one
global replacement action. Mixed held-Undo/Redo gestures containing a replacement
replay on an isolated bounded logical state and publish once. History confirmation
waits for publication, including Ctrl release while pending. Promotion prunes
through the last action dependent on the owner becoming fused, including later
edits to that owner. Save preparation applies an active retained edit first.

Native mesh export can collapse tiny triangles to exact-zero area at float32
precision. Replacement checkpoint preparation welds exact duplicate positions
and removes only exact-zero faces before native closed-manifold validation;
it does not shift vertices or relax geometric tolerances.

Small older WIPs previously suspended solely because saved-profile splines were
unsupported may resume on first load, only when their complete active/redo
timeline fits five slots, all ordinary operations are same-material Add/Replace,
stable source/layer IDs match and any existing S0 is valid and restore-ready.
No truncation or migration of larger/unsupported old histories is attempted.
Their unavailable status is exposed in E; the separate Handle remains available.

Owners changed for E: forge_v2_authoring_state.gd, forge_v2_layer_data.gd,
forge_v2_volume_preview_presenter.gd, forge_v2_stage_controller.gd,
crafting_bench_ui_v2.gd, forge_v2_workspace_preview.gd,
forge_v2_keybinding_state.gd and forge_v2_workspace_action_menu.gd.
New helper: forge_v2_retained_surface_selection.gd. No native DLL change.

Selection reads the displayed mesh's original vertex/index arrays. Godot's
Mesh.get_faces/TriangleMesh path rounds vertices to 0.0001 coordinate units;
using it directly in metres distorted tiny faces and caused tint/pick gaps.
The final overlay now uses unsnapped mesh data, and query BVHs use millimetres
internally (1000x coordinates), reducing that internal rounding to 0.1 micrometres.
Rendering, saved geometry and authored coordinates remain unchanged.

Tint, hover and selection share a final-face owner map, built on E entry or a
publication change, not every mouse move. A final triangle must fit completely
inside one source triangle, within 15 micrometres of roundoff tolerance. Newer
owners are considered first. Partial coplanar overlap from a newer source blocks
fallback to an older source; ambiguous merged triangles stay red rather than
selecting the wrong component. The same conservative rule handles small holes
that a handful of sample points would miss. Overlay depth testing remains active,
with a tiny projection-depth bias to avoid equal-surface flicker.

Final fresh verification, serialized Godot 4.7 runs with isolated user data:

- State: 111/111, `test_artifacts/forge_v2_retained_edit_state_20261018.json`.
  Detached edits, stable identity/order, accounting/cache reconstruction, stale
  rejection, saved-profile restoration and narrow older-WIP compatibility.
- Native integration: 121/121,
  `test_artifacts/forge_retained_edit_integration_20261018.json`.
  Checkpoint plus five retained operations, editing different ages, local/global
  Undo/Redo, mixed held-key batches, failed publication preservation, promotion
  pruning and save/reload.
- Surface/native cases: 125/125,
  `test_artifacts/forge_retained_edit_surfaces_20261018.json`.
  Saved-profile native Apply/Undo/Redo; all five editable owners; invalid/stale
  candidates; uncached save/load into a fresh controller/presenter then editing;
  40-micrometre faces; hole and newer-partial-overlap cases; actual native
  coplanar freehand overlap followed by another append; queued Apply followed
  by disconnect/rebind, harmless stale completion and a successful new Apply.
- Rendered UI: 81/81,
  `test_artifacts/forge_retained_edit_ui_20261018/report.json`.
  Real E/LMB events, hover, point dragging, twist, S Apply/Cancel buttons,
  Ctrl+Z/Y, Handle selection/cancellation, and Escape back to selection.
  D3D12 Forward+; inspected `selection.png`, `editing.png` and the final clean
  `selection_after_edits.png` in that directory.
  Final log: `godot_runs/forge_retained_edit_ui_20261018.log`. The similarly
  named `forge_retained_ui_20261018.log` belongs to an intermediate failed run.
- Workspace regression: 237/237,
  `test_artifacts/forge_v2_workspace_actions_20261018.json`.
  Existing Q/S/V, text/modifier guards, preferences/profile memory and E routing.
- Scoped diff checks pass. No native DLL change and no Git operation.

The final surface and rendered UI processes took about 3.6 and 9.2 seconds
respectively; these are whole fixture runtimes, not E latency benchmarks. No
large-project performance or full-game/export claim. Manual authoring feel is
the next check. Unsupported Remove/EmptyOnly/multimaterial histories and larger
old suspended histories remain unavailable; no unbounded replay was introduced.
Intermediate failed diagnostics were corrected and are not counted as passes.
The final disconnect fix clears the presenter's pending flag when invalidating
its candidate generation; it prevents a stale busy state after rebinding. The
surface suite was rerun after that fix; the earlier rendered UI pass was not
repeated because its normal input paths were unchanged.

## Follow-up: normal launch cache repair - 2026-10-18 04:38

After the E handoff, Project Manager Run failed with "Couldn't detect whether
to run the editor, the project manager or a specific project. Aborting." The
real player log first reported unrecognized main-scene UID cxi4cr0u5qq04.
Both project.godot and node_3d.tscn remained correct and unchanged. The generated
.godot/uid_cache.bin header declared 635 entries, but the file contained 643;
the main scene was entry 640 and therefore ignored by the engine loader.
The responsible writer was not identified; concurrent/stale Godot cache writers
are a plausible cause, not a proven attribution to the E runtime logic.

Preserved the broken cache at
test_artifacts/uid_cache_before_startup_repair_20261018.bin. Ran native Godot 4.7
--headless --editor --import after the user closed the failed launch. Import
exited 0; the rebuilt index declares and contains 647 entries, with the main
scene at entry 646. Then ran the ordinary project entry (no --script or explicit
scene bypass), rendered D3D12 Forward+, --quit-after 180, isolated diagnostic
user data. Exit 0, no script/runtime errors or warnings. The user independently
saw the game open and confirmed it functions; manual Forge testing follows.
Cache count and scene entry were checked again after the run and stayed valid.
Only the user's Project Manager remained running afterward.

Logs: godot_runs/startup_uid_cache_reimport_20261018.log and
godot_runs/startup_main_scene_after_uid_repair_20261018.log. No gameplay source,
launch configuration, saved weapon or Git history change was needed. Import
created normal .uid sidecars for the five new E helper/verifier scripts.

Verification gap: the earlier focused E suites did not establish normal project
startup, and no ordinary-entry smoke run was performed before handoff. For
future implementation handoffs, include a normal-entry startup check when
diagnostic/editor runs have touched shared generated import data; isolated
APPDATA alone does not isolate the project's .godot directory. Do not treat a
test-script launch as proof that a UID-configured main scene can launch.

Engine behavior checked against official Godot 4.7 main.cpp startup resolution,
resource_uid.cpp cache count handling, and the command-line import workflow:
https://github.com/godotengine/godot/blob/4.7/main/main.cpp
https://github.com/godotengine/godot/blob/4.7/core/io/resource_uid.cpp
https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html

## Follow-up: S Apply completes commitment - 2026-10-18

Manual testing found E showed zero editable splines until Save. Code inspection
confirmed Generate intentionally left bodies pending, while E reads committed
retained history; Save performed the missing commit. User explicitly requested
attaching commitment to the end of S Apply rather than requiring a separate step.

forge_v2_workspace_action_menu.gd now generates once with the existing controller
command, then awaits commit_all_pending_material_bodies_as_layers. The same
Apply/Cancel gate used by Q tool changes follows this chain. The controller's
existing chronological grouping upgrades the generation history record, so
commitment does not add a second Undo action. Earlier pending work is committed
in order rather than bypassed. Handle creation/change and Detailing use the same
existing finalization. E retained replacement keeps its own publication transaction.

During commitment, Apply/Cancel and workspace input cannot repeat generation.
Escape or focus loss may dismiss the popup and abandon a queued tool switch;
already generated work still finishes commitment. Popup/controller/state identity
checks prevent stale completion from switching tools afterward. A rejected
commit retains the generated work; Apply retries commitment only while its popup
is open. It does not generate a duplicate shape.

No file save, full-weapon export or wrapper bake is added to S. Ordinary Shape
menu generation remains its existing pending operation; this change is the
user-requested context Apply sequence. Commit readiness is logical history
completion; native surface/collider publication still follows the presenter's
existing path.

Fresh verification: the rendered workspace-action suite passed 255/255 checks,
exit 0. Actual plain S Apply left zero pending bodies and allowed an E final-
surface pick without Save. One Generate history record remained; one Undo
restored the draft and removed its committed solid, and one Redo restored the
committed editable source. Handle and Detailing commitment checks also passed.
Deferred completion disabled repeat Apply; Escape abandoned the queued tool
switch while generated material still committed. Report:
test_artifacts/forge_v2_workspace_actions_20261018.json; log:
godot_runs/forge_apply_commit_ui_20261018.log.

Normal rendered project startup (no test script or explicit scene bypass) also
exited 0 without errors or warnings after --quit-after 180. Log:
godot_runs/forge_apply_commit_main_startup_20261018.log. Before and after this
run, the UID cache declared and contained 647 entries, with the main scene at
entry 646 within the header count. Only the existing editor remained afterward.
Scoped diff whitespace check passed. No Git index/history changes were made.

Verification boundary: commit failure was reviewed in code, not fault-injected.
Commit-only retry is scoped to the same open popup. Dismissing it after a rejected
commit drops that retry context; the retained pending work remains recoverable
through the existing Commit Layer/Save path. Broader E suites from the earlier
handoff were not rerun for this narrow context-action change.

Official Godot 4.7 coroutine and popup lifecycle references checked before change:
https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html#awaiting-signals-or-coroutines
https://docs.godotengine.org/en/4.7/classes/class_popup.html

## Future reference item and broader roadmap - 2026-10-18

The user plans to build a usable finished reference item for future feature
development and explicitly requested saving the broader backlog. See
[Finished Reference Item And Playable Game Roadmap TODO 2026-10-18.md](<Finished Reference Item And Playable Game Roadmap TODO 2026-10-18.md>).
It captures Skill Crafter, slot effects, materials/damage, Engraving, testing,
worlds, persistence, multiplayer/server work, economy, operations, Steam and
ongoing performance/flow work. This is a general-system reference item, not a
special-case target to hardcode around. The user is building it next; the note
does not authorize implementing all listed systems or changing Git branches.
