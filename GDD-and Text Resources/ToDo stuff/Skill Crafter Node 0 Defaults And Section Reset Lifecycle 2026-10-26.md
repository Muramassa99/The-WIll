# SC-01 — Node 0 defaults and section Reset lifecycle

Status: implemented and focused verification passed, 2026-10-26.

## Current decision and scope

Node 0 means the default **body pose**. It is Reset's baseline, not a shared solved grip and not a waypoint played before an action. This clarification supersedes the older SC-01 wording about a universally solved fallback.

| Section | First untouched opening | Save and later opening | Reset |
| --- | --- | --- | --- |
| Skill | Default body; acquire weapon in hand; record the settled result in visible N01. | Enter, wait, Save and exit is sufficient. Restore that section's saved N01, even without a manual edit. | Flush this section's visible nodes; restore the default body and acquire the weapon again. |
| Combat Idle | Default body; acquire weapon in hand; record the settled result in visible N01. | Saved N01 has priority over the default, whether manually altered or not. | Restore the default body and acquire the weapon again. |
| Noncombat Idle | Default body; weapon on the configured body attachment. No hand acquisition. | Save and restore the section's stow position and orientation. | Default body and body attachment. No hand acquisition. |

Saving is the durability boundary. No automatic first-open write or preparation of unrelated sections is required. A completed default pose is valid authored content; a merely allocated placeholder is not. Saved prepared poses must still match their node and actual geometry/rig context before reuse.

Skill editor array index 0 is the hidden Reset placeholder, and index 1 is visible N01. Idle drafts already contain one visible N01 at array index 0. Preserve these existing representations. Persisted skill actions omit the hidden Reset placeholder.

Runtime entry remains current live pose to first authored pose in 160 ms. Reset is not part of playback. Selected-section Save remains independent of other skills and idles. No six-offensive/six-buff implementation, new body controls, solver redesign, or Git operation is included here.

## Current code and narrow implementation

- `core/models/combat_animation_draft.gd`: section-local `authoring_pose_initialized` distinguishes a prepared/saved default from an untouched placeholder through storage/reload. Reset/reseed clears it. Existing current first-node packets also establish section ownership; this marker does not bypass context validation.
- `runtime/combat/combat_animation_station_ui.gd`: use the appropriate first visible index when recording baseline completion; include Combat Idle in first-open/Reset acquisition; preserve saved-node priority.
- `runtime/combat/combat_animation_station_preview_presenter.gd`: restore a current, validated saved authoring pose through the existing prepared-frame application, before the ordinary mount/solve path. Explicit edits and Reset retain their normal acquisition path.
- `tools/verify_combat_default_pose_lifecycle.gd`: isolated real-scene lifecycle checks, with no R, F or manual pose change before the first Save.

Native Resource persistence remains in use. Reviewed official Godot 4.7 [Resource](https://docs.godotengine.org/en/4.7/classes/class_resource.html), [ResourceSaver](https://docs.godotengine.org/en/4.7/classes/class_resourcesaver.html) and [GDScript exports](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html) documentation. A fresh reload must bypass the Resource cache for verification.

## Evidence and acceptance

Fresh real-scene verification used an isolated copy of `Broken_Balde_v1`, right primary hand, normal grip, Skill 3 plus fresh Combat/Noncombat Idle fixtures. First Save followed entry and natural settling, with **no manual edit, R or F beforehand**. Reopen used a fresh world/station instance and disk reload with Resource cache bypass.

| Context | First-open acquisitions | Save acquisitions | Cold-reopen acquisitions | Reset acquisitions |
| --- | ---: | ---: | ---: | ---: |
| Skill 3 | 1 | 0 | 0 | 1 |
| Combat Idle | 1 | 0 | 0 | 1 |
| Noncombat Idle | 0 | 0 | 0 | 0 |

All three passed: saved controls/packets survive reload, saved armed N01 is actually applied, Noncombat is stowed without hand coupling, Reset leaves one visible node and preserves other sections. The skill Reset check first inserted a second node through R. Save trace totals were approximately 0.98 s / 0.56 s / 0.50 s respectively; these are single-pose fixtures, not a multi-node preparation benchmark.

- [Live lifecycle report](../../godot_runs/sc01_lifecycle_20261026/run2/results/default_pose_lifecycle.json), with fresh/reopened screenshots alongside it.
- [Storage regression](../../godot_runs/sc01_action_storage_final/results.json): **49/49 checks pass**, including initialized default persistence and uninitialized placeholders staying unpublished.
- UI GDScript parse check passed. Original real library and isolated source copy retained SHA-256 `1620c9e815d93901d03b167e923cec84f991c2721d8424b0aec5dc153da90127` after the three-context run.

The initial diagnostic stopped because its body-control assertion incorrectly assumed all-zero defaults. Current weapon seed explicitly uses body support 0.4; the verifier now reports observed values against the declared seed. That failed assertion was not treated as a production defect or a passing run.

Reusing a saved frame does not reconstruct provenance-bearing live digit-acquisition packets. A genuine later edit may acquire again through the existing editing path; passive reopen and focus changes must not require that.

That regression exposed a retained-roll shortcut which assumed a live planar binding after saved-pose restoration. The edit changed its control value but could not capture a current pose, with zero acquisitions. Both retained-roll paths now require a real active-hand binding; otherwise the existing acquisition path runs. No solver constraints or tolerance limits were loosened.

The [final reopened-edit regression](../../godot_runs/sc01_lifecycle_20261026/run4_edit/results/default_pose_lifecycle.json) **passed**: cold reopen, numeric roll from 0 to 5 degrees, natural acquisition/capture, Save, another cold reopen, R, then Reset. The edit acquired once; Save and the subsequent reopen acquired zero times. The custom 5-degree pose and its current prepared packet survived reload; Reset cleared the extra visible node and restored the default 0-degree roll. Both runtime runs exited successfully and left their source library unchanged.

Limits: this is lifecycle/persistence evidence, not full-hand contact or anatomy certification. Existing body-clearance warnings at the default pose remain outside this pass. Joint/contact safety checks remain in force. Left-primary, reverse/two-hand combinations and equipped runtime variants were not rerun here. No user saves or Git history/index were changed.

## Related history

- [Playback availability investigation](Skill%20Crafter%20Playback%20Availability%20Investigation%202026-10-25.md): first-open baseline, selected Save ownership and remaining reuse gap.
- [Playtest audit](Skill%20Crafter%20Playtest%20Audit%202026-10-23.md): historical hidden node-0 purpose and entry separation.
- [Equipped repair](Equipped%20Skill%20and%20Combat%20Idle%20Repair%202026-10-25.md): equipped action/idle work; this pass does not reopen that implementation.
- [Project TODO](Project%20TODO.md): SC-01 index entry.

The user's 2026-10-26 clarification above governs contradictions with older SPS/task notes. Historical evidence is not fresh verification of this change.
