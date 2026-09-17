# Hand placement, triangulation and grip history audit

Completed September 18, 2026. Search began September 17. This is an investigation record; it does not authorize or implement a production change.

The useful historical idea is to derive a hand reference from character anatomy, then use it to place and orient a weapon before fitting contact. Anatomical reference calculations survive today, including an actual Hand-to-Index/Pinky perpendicular projection. They have different consumers. The current occupied-hand path does have a determined starting center, but later surface seating can move the weapon relative to that reference, and its acceptance does not validate measured palm skin. This is the concrete distinction to investigate when adapting the old idea.

## Reading coverage and authority

- [Complete matching-file inventory](inventory.md): all 106 matches, including incidental matches and duplicate documents, with filesystem dates and links.
- [Full-read coverage](complete_coverage.json): all 106 matched files, 58,401 lines / 314,843 whitespace-delimited words, read in full across the primary reader and three parallel readers. The nine nonmatching .md/.txt files were also read in full as a semantic check. They contained no missed substantive hand/grip requirement.
- All 115 source hashes matched the original inventory after reading. Source documents and production code were unchanged by this audit. Only audit artifacts were written.
- Creation time is not treated as authorship time: many imported documents share April 8 filesystem dates; the September 1 SPS has a September 14 creation timestamp. Embedded dates, appendices, retractions and current user directions matter.
- The consolidated orientation remains the authority map. Older naming/knob/implementation-memory files are historical evidence, not trackers to resume updating. Current chat requirements override earlier design restrictions.

## The screenshot and its written counterpart

[Viewed screenshot: April 11, 04:01:35](</C:/WORKSPACE/images and refferences/Screenshot 2026-04-11 040135.png>).

The image shows colored triangles and perpendicular construction over the hand skeleton, with a central blue reference. The user identifies this as an early hand-bone-derived placement idea, followed by Pinky?Index orientation. The user also clarifies that the old implementation needed tuning and should be adapted to current geometry, not restored unquestioningly.

The closest explicit written construction is [Skill Crafter Implementation Stages, line 90](</C:/WORKSPACE/GDD-and Text Resources/ToDo stuff/Skill Crafter Implementation Stages 2026-04-24.md:90>):

- H = Hand; I = Index1; P = Pinky1; F = Forearm.
- H/I/P define the hand plane; I?P gives hand width.
- The perpendicular from H to the I?P line derives a center reference.
- F?H provides the forearm approach direction.
- The same law is mirrored for the other hand.

That particular section explicitly concerns the empty-hand surrogate. It establishes the geometric idea, but is not documentary proof that the occupied V1 weapon used exactly that construction. No direct reference to the screenshot filename, or full explanation of every unlabeled colored construction in the image, was found in the audited GDD corpus. Do not claim to have recovered the exact original image explanation.

The April 9 uses of ?grip triangulation? in the [visual-system document](</C:/WORKSPACE/GDD-and Text Resources/Runtime Melee Combat Editor Visual-System.md:297>) and [addendum](</C:/WORKSPACE/GDD-and Text Resources/Runtime Combat Editor Visual and System Addendum.md:237>) concern weapon balance/handling intent. They do not supply this hand-center formula.

## What was actually implemented and survives

| Part | Historical evidence | Present role |
| --- | --- | --- |
| Anatomy-derived hand attachment | Implementation memory line 745 reports a proximal finger/thumb rest-derived palm offset. April 11 commit be2f2946 mounts the weapon using a sampled Thumb/Index joint center. | The cached Thumb/Index center remains a live input to occupied-hand alignment. It is an approximation, not measured palm contact. |
| H/I/P triangle and perpendicular center | April 24 specification; code already present in May 2 commit 766a1393. | Still constructs unarmed/free-hand authoring proxy points. It is not the final occupied-handle seat target. |
| Palm frame under PALM_TRIANGULATION_BONES | April 11 code averages six bone positions and derives a normal from Hand/Index1/Pinky1. | Still constructed; in the exact V2 path its center contributes to contact readiness. The identifier does not mean a triangle-derived weapon center is enforced. |
| Pinky?Index alignment | Hand-axis and contact-span geometry preserved in current rig/presenter. | Supplies orientation and the midpoint used in initial alignment. |
| Three-slice V2 surface seat | August 27 SPS defines selected C0 and Index/Pinky stations Ci/Cp, then radial translation and chord rotation. | Active exact surface geometry machinery. Its three weapon slices are not three independent anatomical palm references. |
| Old predicted finger target helpers | Legacy profile-cell, palm-frame and ray-based target machinery survives. | The current V2 path continues into its surface solver before those helpers. All five configured legacy digits take the plane-curl branch, bypassing the alternate target helper. Retained code is not evidence of an active behavior. |

[April 11 source excerpts, with original line numbers](april11_source_evidence.md) record the historical implementation directly from Git.

Current source anchors:

- [Hand alignment entry](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/player/player_humanoid_rig.gd:620>) and [anatomical offset calculation](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/player/player_humanoid_rig.gd:878>).
- [Cached Thumb/Index joint-center calculation](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/player/player_rig_finger_grip_presenter.gd:3268>).
- [Surviving palm frame](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/player/player_rig_finger_grip_presenter.gd:2496>).
- [Actual perpendicular projection for unarmed controls](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/combat/combat_animation_station_preview_presenter.gd:8336>).
- [V2 mount uses the hand alignment state](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/player/player_equipped_item_presenter.gd:619>).
- [Later preview surface-seat stage](</C:/WORKSPACE/The Will- main folder/the-will-gamefiles/runtime/combat/combat_animation_station_preview_presenter.gd:5525>).

The occupied midpoint/perpendicular-offset adaptation was already introduced on May 2, before the Forge V2 transition. Its existence should not be attributed solely to V2 or the recent rollback. [Bounded code history and current unarmed callers](legacy_code_history.md).

The occupied starting center is currently constructed from the Index/Pinky midpoint, plus the component toward the cached Thumb/Index center perpendicular to the Index/Pinky axis. That offset is capped at 0.75 of the Index/Pinky span. The mount aligns the selected weapon contact point to this target. The subsequent exact surface-seat stage applies another weapon transform while holding the Hand fixed.

The complete call chain, branch predicates and final-seat acceptance conditions are recorded in the [occupied-hand placement trace](supporting_code_placement_trace.md).

Consequently, the evidence supports ?anatomical reference and final surface-fit acceptance are not the same thing.? It does not support ?V2 has no determined hand-derived point at all.? The audit has not established that this distinction is the sole cause of the visible grip failures.

## What should be retained and adapted

1. **Retain the hand-derived reference concept.** A reference location, hand plane and side-aware basis can be prepared from character geometry and stored with the character's existing measured anatomy. Use the established named origin chain through the Hand to RL_BoneRoot. The old screenshot is a design guide, not sufficient evidence to select every formula or offset without comparison.
2. **Retain actual V2 geometry.** Its protected Handle selection, curved slice centers, exact surface queries and grip-position semantics are useful. Reintroducing V1 voxel/profile restrictions would defeat the current arbitrary-shape requirement.
3. **Make the three responsibilities explicit:** anatomical reference location; weapon orientation; size/shape-dependent surface fit. A stable anatomical reference does not imply the center of every differently shaped handle must occupy an identical final point. The measured skin and handle surface determine the appropriate offset from that reference.
4. **Extend acceptance to the relevant shared hand surface.** Current Index/Pinky seating is not palm-clearance proof. The existing prepared anatomy and coherent posed-skin query are useful inputs. Middle/Thumb candidates must be evaluated against the same neighboring/palm pose, followed by whole-hand checks before live integration.
5. **Preserve current movement ownership.** Normal/reverse, either hand and two-hand setups must consume the same geometric rules with their actual transforms. A shared weapon pose must satisfy both hands. This does not authorize introducing upstream IK motion, changing grip percentage or altering accepted wrist?Tip Roll.
6. **Preserve solve lifecycle and performance.** Character preparation is reusable; weapon-specific acquisition runs on relationship changes. Ordinary rigid manipulation retains an accepted hand/weapon relationship. Measure total acquisition, not merely the fastest helper.

Do not copy the old six-bone average, old profile-cell finger targets, or an unrestricted hand/weapon reposition as a presumed complete fix. Do not delete dormant helpers during this investigation: their removal and callers would be a separate scoped change.

## Proposed next bounded proof

Use the existing frozen real-weapon fixtures and prepared character data. In one named coordinate frame, display/measure:

- Hand, Index1 and Pinky1, their plane and perpendicular reference;
- the current cached anatomical alignment center;
- selected Handle slice center before and after the surface-seat correction;
- measured palm and Middle/Thumb skin, with one coherent neighboring-hand pose.

This comparison should reveal which reference is useful, how the current seat moves away from its starting placement, and whether a changed placement constraint can produce real contact without introducing intersections. Then test the proposed reference-plus-contact fit on the current difficult Handle before changing production. Keep handedness, normal/reverse and eventual shared two-hand acceptance in the contract from the start; do not claim the existing separate left/right captures prove simultaneous two-handed behavior.

No placement change was made here. This proof is the recommended next step, not a completed solver result.

## Bone-name findings and terminology traps

[Literal bone-name occurrences](bone_name_occurrences.json) include CC_Base_R/L_Hand, Forearm, Upperarm, Index1 and Pinky1. [The original articulation note](</C:/WORKSPACE/GDD-and Text Resources/ToDo stuff/the thing i figured out.md:69>) also enumerates the Thumb/Index/Mid/Ring/Pinky three-joint chains using compressed 1/2/3 notation; these remain distinct from the crafted weapon's own joints.

- The April 24 staged document spells the root LR_BoneRoot in places. Current origin authority uses RL_BoneRoot; do not propagate the historical typo.
- Joint Articulation Rules and the articulated-segment guide describe weapon construction hinges, chains and spin joints, not character finger limits.
- Three-point Handle authoring paths, mesh retriangulation, bow-string four-point mapping, and two translation degrees of freedom are separate concepts. None proves or disproves the anatomical construction in the screenshot.
- Historical reverse-plus-two-hand restrictions are dated policy/implementation limitations. They must not silently narrow the user's current geometry-neutral solver requirement.

## Evidence limits and workspace preservation

This pass read documentation, inspected the screenshot and compared source/history. It did not run Godot, replay the grip, or establish a new valid hand pose. Historical synthetic passes and user-rejected implementations are reported as such; the August 27 manual rejection remains part of its three-slice history.

Verified active branch: recovery/stable-92b8a24-chat14, HEAD92b8a24fcac64e38c2565e56fec6878e22e55e26. Existing seven tracked modified files were preserved. No source change, rollback, player-library write, commit or push was performed.

Detailed reading notes: [primary](root_notes.md), [history](history_notes.md), [legacy](legacy_notes.md), [supporting](supporting_notes.md), [additional ToDo files](additional_root_notes.md).
