# Forge V2 Bounded Remove Support TODO

Recorded 2026-10-18, Europe/Bucharest, after savepoint ce720442.
Status: implemented; focused verification complete, broad regression comparison below.
The initial audit below was read-only; subsequent changes add bounded subtraction.

## Authorized implementation and decisions

The user requested the fix and confirmed test items can be rebuilt. Preserve the
S0 plus five-operation limit and protected Handle; use chronological native
Add/Remove, without introducing a separate unlimited history. Changes touch the
owners listed below and controller save preparation for a confirmed erased draft.
An erased ordinary solid remains valid history and can save as an authoring-only
draft, following the existing empty-draft policy; it is not a usable runtime item.
Removed ledger records retain their existing rough requested cutter-volume meaning
and are compacted into one checkpoint aggregate plus the retained operation tail.
Remove ignores the selected cutter material; ordinary Add remains single-material
Replace. Multi-material Add and EmptyOnly remain outside this fix.

User verification: the twist density hard stop worked during manual play testing;
an attempted 30 turns was capped at roughly 10 turns for that particular spacing.
No twist implementation change requested or made as part of Remove support.

Official Godot 4.7 CSGShape3D and GDExtension-file documentation consulted before
implementation. Native subtraction/history remains owned by the existing Manifold
backend; existing Godot CSG operand baking and publication readiness are retained.

## User case and result

The user applied Detailing Brush with Remove material (eraser), using a primitive
shape against existing geometry. Save showed pending layer commit rejected.
S Apply showed: "Could not finish the shape (pending_layer_commit_rejected).
Generated work is retained; Apply retries." The user then closed the game.
The exact failing unsaved draft was not captured; this is a mode/commit-path
reproduction, not a reconstruction of the screenshot's full geometry.

An isolated headless Godot 4.7 diagnostic creates an Add spline layer, then
generates a valid primitive Detailing body over it. Add mode commits. The same
Detailing path in Remove mode passes generation and commit-readiness checks,
but both commit_all_pending_material_bodies_as_layers and
prepare_pending_work_for_save return pending_layer_commit_rejected. Existing
committed layer references and pending-body count remain unchanged on rejection.

- Diagnostic: test_artifacts/diagnose_forge_detail_remove_commit_20261018.gd.
- Report: test_artifacts/forge_detail_remove_commit_20261018.json.
- Log: godot_runs/forge_detail_remove_commit_20261018.log.
- Fresh result: diagnostic_reproduced=true, exit 0, no script errors.
- Scope: logical controller/state path; no renderer/collision or geometry-save
  success claim. Separate diagnostic APPDATA; no player library writes.
- Post-run UID cache: declared/actual 647, main scene entry 646 in range. Only
  the existing editor remained open. No normal-startup rerun for this read-only
  production audit; that was verified before the earlier Git push.

## Root cause and missed coverage

forge_v2_authoring_state.gd _commit_material_bodies_as_layer calls
_must_reject_unsupported_bounded_commit. With active bounded history and existing
ordinary material, eligibility requires Add + Replace + the same material.
Remove is rejected before native geometry processing. This restriction can occur
with the first retained Add layer; a fused nonempty S0 is not required to hit it.

The restriction is documented in the August 16 bounded Add continuation contract,
whose unsupported-operation section deliberately defers chronological Remove.
The newer S Apply chain exposes the same underlying gate that Save already uses.
Twist density, primitive shape validity and surface contact did not cause this
reproduction. Repeating Apply cannot make this unsupported operation commit.

The 255-check workspace suite covered Detailing Add in an empty draft. It did
not cover Remove after existing bounded material. Preserve that passing result's
actual scope; it does not establish subtractive authoring support.

## Required implementation work

Do not remove the eligibility guard alone or fall back to an unbounded history.
The intended existing limit is S0 plus five ordinary editable history operations,
with the protected Handle separate. Proposed narrow first slice: support valid
Add/Remove chronology over the existing single-material ordinary solid, including
primitive Detailing removal, then verify saved-profile and other cutter sources
through the same operation path. Broader multi-material/EmptyOnly behavior remains
a separate design/implementation scope.

- [x] Native backend: add a true stateful subtraction operation with the same
  bounded history, revision, Undo/Redo and atomic failure contract as add_mesh.
  Current forge_v2_manifold_boolean.h exposes add_mesh, not stateful Remove.
  Existing protected-Handle composition subtraction is not general cutter history.
- [x] Presenter: dispatch each retained operation as Add or Remove for append,
  restoration and E replacement replay; preserve publication/collider readiness.
- [x] Authoring state: admit supported cuts only when downstream owners can
  publish them; retain exact chronological order and atomic rollback behavior.
- [x] Layer data: permit valid subtract records and signed material deltas for
  the ordinary solid; cutter operation identity is not the solid's material.
- [x] Checkpoint promotion: preserve the existing solid material when a cut ages
  into S0. Current promotion uses the promoted layer's operation_material_id;
  Remove uses MATERIAL_VOID, which must not become the checkpoint's solid identity.
- [x] Ledger: compact promoted removed_material_records into bounded aggregate
  accounting, without stale layer IDs or loss of removed amount/volume semantics.
  Current checkpoint summary clears material layer_ids but retains cut records.
- [x] Resolver/checkpoint: support validated empty results, or define and enforce
  their treatment before mutation. Current occupancy recovery and mesh validators
  assume nonempty contents, which matters when a cut erases S0 or the whole solid.
- [x] Preserve protected Handle material/geometry. Resolver removal already skips
  protected cells; native publication and replay must uphold the same rule.
- [x] E editing of an earlier Add must replay later cuts correctly; do not imply
  that a subtractive cutter is selectable as an ordinary visible retained surface.
- [ ] Provide a meaningful capability/failure message and safe recovery if an
  unsupported operation is attempted. Do not consume the editable draft and then
  offer an indefinitely futile generic retry as if it were a transient failure.

Owners under the active project:

- native/forge_v2_manifold/src/forge_v2_manifold_boolean.{h,cpp}
- runtime/forge_v2/forge_v2_volume_preview_presenter.gd
- runtime/forge_v2/forge_v2_authoring_state.gd
- runtime/forge_v2/forge_v2_layer_data.gd
- runtime/forge_v2/forge_v2_material_volume_resolver.gd
- runtime/forge_v2/forge_v2_material_ledger.gd
- runtime/forge_v2/forge_v2_history_checkpoint.gd
- Controller and context-action UI only where capability/results need propagation.

The implementation decisions above resolve empty-draft and aggregation semantics.
The remaining generic unsupported-operation UX item is separate from the fixed
Remove path. Mixed-material Add and Add/EmptyOnly retain their existing rejection
rules; no new support for those capabilities is claimed.

## Focused acceptance cases

- [x] Existing Add -> primitive Detailing Remove -> successful Apply and Save.
- [x] Saved-profile cutter and ordinary cutter paths share correct subtraction.
- [x] Remove before and after S0 exists; a cut promoted into S0; Add after that.
- [x] Protected Handle survives the cut and every history transition.
- [x] Undo/Redo, held batches and branching remain bounded and correct.
- [x] E edits an earlier retained Add and later cuts replay correctly.
- [x] No-op/outside cut, partial cut, complete erasure and an empty checkpoint.
- [x] Save/reload and runtime export match the resulting committed geometry.
- [x] Material accounting matches the occupied result; no unbounded cut metadata.
- [ ] Failed native operation/promotion preserves prior geometry, collider,
  checkpoint, history and ledger. No stale surface target becomes authoritative.

Related references:

- [Bounded Add continuation contract](<Forge V2 Bounded Native Add Continuation 2026-08-16.md>).
- [Current Forge workflow task note](<Forge V2 Tool Wheel Context Actions And Retained Editing 2026-10-18.md>).
- [Reference item roadmap](<Finished Reference Item And Playable Game Roadmap TODO 2026-10-18.md>).

Official Godot 4.7 SceneTree documentation was consulted for the isolated
diagnostic lifecycle: https://docs.godotengine.org/en/4.7/classes/class_scenetree.html.
The root-cause evidence above comes from current project code and the fresh run.

## Implementation evidence - 2026-10-18

Native backend rebuilt with pinned Manifold 3.3.2. Stateful subtract_mesh shares
the bounded Add mutation, history, revision and atomic validation machinery.
An erased solid stays initialized; Add continues the same timeline. Native empty
exports and persisted empty S0 are distinguished from absent/failed geometry.
The presenter replays actual Add/Remove chronology on restore and E replacement.
The authoring-only empty save path prevents a stale mesh from being saved as an item.

Fresh Godot 4.7 checks, serialized with isolated diagnostic APPDATA:

| Verifier | Result | Scope |
| --- | --- | --- |
| verify_forge_v2_native_remove_history.gd | 360/360 | Analytic partial/full/no-op cuts; S0+5; branching; invalid-cut atomicity; empty restore; protected composition |
| verify_forge_v2_remove_accounting.gd | 45/45 | Signed occupied deltas; 1,000-cut metadata compaction; empty occupancy persistence and rollback; protected cells |
| verify_forge_v2_bounded_remove_state.gd | 124/124 | Primitive and saved-profile cuts; signed deltas; guards; promotion identity including cut-only tail; E chronology |
| verify_forge_v2_bounded_remove_integration.gd | 62/62 | Rendered real controller/presenter; primitive cut; E earlier Add replay; Undo/Redo; promotion; complete erasure; save/load; empty S0 |
| verify_forge_v2_protected_remove_integration.gd | 80/80 | Rendered saved-profile Detailing; Handle exact-packet identity; live collider; partial/full cuts and Save/reload; Handle-only export |
| verify_forge_v2_retained_edit_state.gd | 111/111 | Existing E logical regression |
| verify_forge_v2_retained_edit_integration.gd | 121/121 | Existing rendered E regression, including held mixed history |
| verify_forge_v2_workspace_actions.gd | 257/257 | Real S popup Apply after committed Add then Detail Remove; existing Q/S/E workflows |

Reports are in test_artifacts with names forge_v2_native_remove_history_20261018,
forge_v2_remove_accounting_20261018, forge_v2_bounded_remove_state_20261018,
forge_v2_bounded_remove_integration_20261018,
forge_v2_protected_remove_integration_20261018 and
forge_v2_workspace_actions_20261018 (JSON). Matching Godot logs, plus
forge_bounded_remove_state_final_20261018.log,
forge_retained_edit_state_after_remove_20261018.log and
forge_retained_edit_after_remove_20261018.log are under godot_runs.

All listed tests exited 0. Initial integration fixture erasure was too small
because tool recall restored its brush size; corrected the fixture after tool
selection. A subsequent real integration bug rejected an empty S0 when the live
tail was nonempty: the validator read live-state volume instead of exported S0
volume. Corrected that distinction; all integrated cases above passed afterward.

Normal rendered project startup passed (--quit-after 180, no scene or --script
bypass), exit 0 and no errors: godot_runs/forge_remove_normal_startup_20261018.log.
UID cache declared/actual 652, main scene entry 651 in range. New verifier UIDs
were generated by native editor import. The import logged locked reload-copy DLL
errors because the existing editor held its ~ DLLs; runtime runs load the base
DLL successfully. No claim of an error-free editor import; normal game startup
and all focused rendered runs passed.

The exact unsaved screenshot geometry was unavailable. Fixtures reproduce the
reported primitive Detailing Remove workflow and exercise additional cases;
user visual confirmation on their own artwork remains pending. No player saves
were changed, although the user explicitly authorized changing them if needed.
No Git index, commit, branch or push operation performed for this fix.

## Older broad regression: baseline comparison and follow-ups

The unchanged verify_forge_v2_bounded_add_history.gd reports 14 failures.
An isolated read-only Git archive of pre-fix HEAD ce720442 (all 66 Forge runtime
files and the old native DLL) ran the identical rendered verifier and reproduced
the EXACT same 14 failures and the same gate values. Current-only failures: 0;
baseline-only failures: 0; gate differences: 0. Both runs exited 1. This is a
confirmed pre-existing failing regression, not an all-green broad-suite claim.

Evidence: test_artifacts/forge_remove_head_baseline_20261018/comparison.json,
current_before_baseline_bounded_add_history.json,
head_baseline_bounded_add_history.json and manifest.json. The normal shared
godot_runs/verify_forge_v2_bounded_add_history.json now holds the baseline run.
Logs: forge_v2_bounded_add_after_remove_20261018.log and
forge_v2_bounded_add_history_head_baseline_20261018.log under godot_runs.

Separate follow-ups, not silently fixed or waived here:

- Initial Handle publication can use a CSG fallback while its exact bake is
  pending; subsequent publications use native composition. The older test
  requires zero fallback even during that initial readiness interval.
- Its independent Godot CSG oracle is nonmanifold (8-10 boundary edges and
  68-103 nonmanifold edges at tested boundaries), while live lanes and final
  native extraction are watertight. Surface/bounds/material/normal checks pass;
  the oracle volume/topology comparison remains unresolved.
- Its Save helper bypasses current required grip-target preparation and labels
  a resulting null WIP as checkpoint failure. The checkpoint actually materializes.
  The new protected integration calls prepare_pending_work_for_save and validates
  the real controller save/load path successfully.

No broad-verifier assertions were weakened or removed. Only the existing editor
PID20592 remained after all runtime verification. Scope remains bounded Remove;
generic unsupported-operation messaging and the follow-ups above remain separate.
