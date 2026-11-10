# Glave Skill 2 observation — 2026-11-10

## Scope

User requested a live observation of Broken_Glave_v1, Skill 2: open, Save, inspect every node and full F playback, compare the saved poses with transitions, diagnose twisting/contact loss and primary-hand displacement when support joins. Camera orbit is allowed; authored control positions must remain unchanged. No production fixes or grip/hand-mode changes are authorized by this audit.

## Method

Use the real rendered station and its normal Save/F/node-selection handlers. Back up the player library before Save. Record original and subsequent authored fields, prepared pose signatures, validation warnings, actual bone transforms, hand-to-weapon relationships, compiled clip data and rendered images. Distinguish automatic lifecycle changes from deliberate control edits; none of the latter are made. A valid packet is not evidence of a certified grip, and clearing live grip bindings during playback is not by itself proof of contact loss.

Diagnostic: `tools/diagnose_glave_skill_two_observation.gd`. Current production code remains unchanged. Findings and evidence will be appended after the run.

## Fresh runs and evidence

- Baseline: Git `4a2304c5426ad5024b0483535cb961546091209a`, Godot 4.7, actual saved `Broken_Glave_v1`, `skill_slot_2`. Seven visible nodes; N01–N06 one-handed, N07 two-handed. No Reset, control-point movement, explicit Reacquire, or hand-mode toggles were performed.
- Rendered opening → real Save → each node selected and settled → full F: `C:/WORKSPACE/godot_runs/glave_skill2_observation_20261110_220452/`.
- Second rendered pass: reopen the actual saved skill → camera view adjustment → full F, with **no Save and no node navigation**: `C:/WORKSPACE/godot_runs/glave_skill2_replay_observation_20261110_221046/`.
- Both runs finished and exited; no runtime script errors in either stderr log. Root inspected the node screenshots and the complete second playback image sequence. These are instrumented observations, not performance benchmarks or certification that the poses are anatomically valid.
- Playback was traced from start through completion and inspected through sampled rendered images, not a frame-perfect video. The first trace retained mutable requested-pose arrays that later cleared; its actual transforms remain usable. The second trace deep-copies those arrays and supports direct requested-versus-displayed bone comparison. After F stops, the UI restores the selected editor endpoint in the same tick; the post-F screenshot is therefore not assumed to be the terminal transient replay frame.
- Original library backup: first run's `player_library_before.tres`; original isolated skill: `skill_before.tres`. The original library SHA256 was `f603db9c67bdd5e08003c59537832aa9ec2763310226ddae2c6d60f5d44827ad`.
- Requested Save wrote the library SHA256 `524c51349ea571492923d0a23eabd4eaab3fc986c11e61a7cc8354899abaed7e`. This hash remained unchanged through subsequent node inspection and the entire second run. Thus later selection-triggered alterations were observed in memory, not saved over the benchmark again.
- Read-only headless resource analysis: first run's `extract_pose_layers.gd`, `endpoint_layer_comparisons.json`, `body_clip_numeric.json`, `entry_clip_numeric.json`, `source_nodes_numeric.json`, `final_nodes_numeric.json`. Agent numeric observations: `audit_contact_numeric_results.json` in each run directory.

## What was already on disk

The original saved snapshot signatures matched current node settings only for N01 and N02. N03–N07 were stale. Native and GDScript signature calculations agree; current node normalization did not change their inputs. The precise historical action that left those five snapshots stale is not recoverable from this saved file alone.

All seven packets passed structural validation. This validates finite channels, bone layout, origin records and required fields; it does not certify anatomical pose or accepted gripping. N07 already had `shoulder_motion_range` for the left hand and `prepared_pose_grip_pending`, `prepared_pose_grip_not_applied`, `prepared_pose_grip_not_bound` warnings. Do not attribute these original warnings to this audit's Save.

Opening initially selected N07. Because that packet was not reusable, the visible pose was reconstructed rather than simply restored. Comparing its original recorded parent-local bone rotations with the opened rig shows approximately **179.13° left Forearm**, **163.46° left Upperarm**, **54.46° left Hand**, and **50.08° left Clavicle** changes. These are quaternion orientation differences, not measurements of axial roll alone. This is an important source of the last-node visual discrepancy **before F begins**.

By the first Save, left ForearmTwist01/02 had each changed approximately 28.684° from the original stored packet; right helpers changed about 3.708°. The selected live N07 subsequently matches its new recorded endpoint within 0.0001° in measured local rotations. That restoration adds no further demonstrated helper-only twist.

## Save and node selection are not passive observers

Save succeeded with **42 pose warnings**, about 8.02 seconds wall time in this instrumented run. It recovered stale N03–N07 packets. The recovery worker captures after two stable process frames and explicitly treats acquisition readiness as diagnostic rather than a wait condition (`runtime/combat/combat_animation_endpoint_recording_job.gd`, approximately lines 95–125). Consequently N03–N06 were saved with grip pending/not applied/not bound warnings and empty acquired-grip packets.

N07 settled with both hand bindings, but the weapon and both hands moved together during Save:

- Weapon origin: about **71.56 mm** world displacement.
- Right/left Hand origins: about **71.80 / 71.88 mm**.
- Root, waist and spine positions stayed unchanged; their orientation differences were at numerical rounding scale.
- Left clavicle rotated about **39.54°**, right clavicle about **1.73°**. Other arm joints compensated.
- Hand-to-weapon relationships remained effectively constant during that particular shift. This is a moved assembly, not proof that either hand detached during Save.

The captured N07 Tip/Pommel fields moved about 29 mm in their authoring reference, corresponding to that world shift. No control setter was called. Save therefore did not leave all authored coordinates numerically unchanged; the original backup is retained.

Selecting each node then allowed its normal automatic acquisition to run. N01, N02 and N07 were stable between immediate and settled observations. N03–N06 reacquired their primary grip. In particular, N05's weapon rotated **91.89°** and its origin moved **1.70 m**; N06 rotated **104.03°** and moved **1.85 m**, while the primary Hand and arm bones stayed fixed. A long weapon rotating around the hand can produce large weapon-origin displacement. These are primary weapon-to-hand realignments, not offhand-driven body motion.

The acquisition/capture lifecycle subsequently updated Tip/Pommel/orientation fields for N03–N06. F itself did not change those authored fields or packet hashes. A raw diagnostic equality flag also includes Resource instance identity; the numeric field comparisons, not that flag alone, establish the actual changes.

| Node | Before audit | After requested Save / inspection |
|---|---|---|
| N01 | Matching snapshot, no stored quality warnings | Stable selected pose; compiled material normalization changes upper-arm/forearm local frames. N01→N02 raises wrist-range warnings. |
| N02 | Matching snapshot, no stored quality warnings | Stable selected pose; same normalization discrepancy. N02→N03 adds reach/elbow-circle and shoulder/wrist warnings. |
| N03 | Stale snapshot | Save records right-shoulder and pending-grip warnings; navigation later reacquires and reseats weapon. |
| N04 | Stale snapshot | Save records both-shoulder and pending-grip warnings; navigation later reacquires. |
| N05 | Stale snapshot | Save records right-shoulder and pending-grip warnings; navigation produces the 91.89° weapon realignment. |
| N06 | Stale snapshot | Save records both-shoulder and pending-grip warnings; navigation produces the 104.03° realignment. |
| N07 | Stale snapshot; left-shoulder and unbound/pending offhand warnings already stored | Opening reconstructs a substantially different left-arm pose. Save moves the connected weapon/hands assembly and retains left-shoulder warning. Subsequent selection is stable. |

## Why F visibly loses contact

Both F runs reached the end. Rendered images show the weapon separated from the main hand during parts of the motion; this also occurs in the second run without navigation or another Save.

The prepared-track builder first tries to keep the captured hand-to-weapon relationship using arm guidance. For pose-quality failures (wrist range, shoulder/reach, missing elbow-circle solution), it deliberately returns the original finite interpolated body and weapon channels with warnings. This keeps F playable, as previously requested, but those independently interpolated channels do **not** guarantee contact. See `core/resolvers/combat_prepared_pose_track_builder.gd`, `guide_sample()` and `_quality_fallback()` around lines 179–213; `combat_prepared_attachment_resolver.gd`, `apply()`.

- First F, after node inspection: the historical `quality_fallback_samples` counter reported **179 / 194**.
- Second F, directly from the saved skill: that counter reported **183 / 194**. `interior_contact_validated` was false.

Correction from the subsequent implementation review: the historical counter increments for any quality warning, including successful guidance with a warning. These counts are warning-bearing samples, not a proven count of raw interpolation fallbacks. The measured large contact gaps and the source fallback branch remain independently established. The continuity change separates actual fallback and warning counters.
- Actual world-space primary Hand versus interpolated captured mate in the second run: approximately **443 mm** separation in N01→N02; approximately **654 mm / 143°** at a sampled point in N03→N04. These are sampled observations, not exhaustive maxima. The first span has effectively constant endpoint mates, making the large early gap particularly clear.
- The second clip's diagnostic maximum attachment error is 0.72494 **reference units**, not metres; do not label that raw diagnostic as world distance. World-space values above were calculated from actual rendered transforms.
- There is no sampled grip reacquisition during these F tracks: reported acquisition calls are zero. The defect is not an endlessly restarting finger solver in this run.

Support attachment enforcement and its error metric are skipped across N06→N07 because support is active only at the destination. Therefore zero support-error maxima do not certify contact during offhand joining.

## Endpoint versus playback arm treatment

Selected recorded poses restore with arm-material normalization disabled. Clip preparation normalizes complete arm frames, and the runtime writer also requests normalization. This is a real policy difference, not just different camera views.

Exact resource comparison found N01 and N02's compiled local bone rotations differ from their recorded endpoints by up to **8.939°** at the right Forearm; later endpoints differ by at most about **0.053°**. Running the current `ArmFrame.normalize_material_frames()` on each captured endpoint reproduces every compiled endpoint rotation exactly. That identifies the preparation-stage source of those edits. Local Upperarm/Forearm changes may compensate, so this is not by itself proof of a corresponding Hand world-rotation error; live-frame comparison is recorded separately below.

Endpoint FK comparison confirms that compensation: across all seven nodes, Hand-frame orientation differences are at most 0.000045° and positional differences below 0.000039 **packet-reference units**. Thus the 8.939° is not an 8.939° Hand rotation; upper-arm material orientation can change while downstream Hand placement remains effectively the same. The original N05 also has a concrete authored-versus-packet weapon mismatch: reconstructed Tip differs by 3.20656 trajectory-local units and Pommel by 0.750229, supporting its stale-packet diagnosis independently of hashes (`pose_geometry_analysis.json`).

The second replay captured the requested pose arrays correctly. Across its 28 samples **after** the 160 ms entry, the runtime writer changed Upperarm/Forearm local rotations by up to 10.408° on the right and 22.922° on the left. Reconstructing the complete requested arm from the same actual clavicle shows those changes compensate: requested versus displayed Hand world frames agree within **0.0362 mm / 0.000171° right** and **0.0201 mm / 0.000203° left**. Therefore these runtime local-frame adjustments do **not** explain the large observed hand–weapon gaps. The displayed body is closely following the requested prepared body; that requested body is already inconsistent with the weapon during failed-guidance spans. Right distal forearm helper orientation differs by at most about 1.045° world in these samples; that is a separate, much smaller skin-frame difference. See second run's `requested_vs_live_analysis.json`.

One sampled frame during entry (0.067456 seconds) has much larger requested-versus-displayed differences, including fingers/spine. It is separated from the body-only comparison; a single observation does not identify its timing/order cause. Do not extrapolate the post-entry agreement to every entry frame.

The entry source path starts playback and synchronizes a pose immediately, then advances and synchronizes each process tick. Arm normalization cannot explain changed finger/spine channels. Another writer or initial-frame ordering remains a candidate only; an event-level ownership trace would be needed to establish the cause. No such instrumentation/fix was added in this pass.

## Offhand engagement: what is proven and what remains distinct

No two-hand toggle was performed, because changing the benchmark was out of scope. The saved N06→N07 transition and N07's opening/Save lifecycle were inspected. The 71 mm Save assembly movement is reproduced; the exact instant of the user's original toggle is not.

Current numerical support acquisition guards weapon world pose, primary Hand world pose and primary finger rotations against modification (`runtime/player/grip/preview_grip_acquisition.gd`, around lines 1087–1101 and 1248–1257). However, the general presenter can alter the macro pose **before** that guarded acquisition, and its fallback two-hand coupling can rotate the weapon around the primary grip and translate the contact group (`combat_animation_station_preview_presenter.gd`, approximately 5582–5624 and 9041–9143). This is a candidate ownership conflict for the reported toggle behaviour; the observed Save shift alone does not establish which internal stage caused it.

## Boundaries and next discussion

No production fix, joint-limit change, grip solver change, Git operation or SPS was made. The diagnostic and this note are the only new source/documentation work. All control-point movement remained untouched by the operator; automatic lifecycle movement is explicitly recorded above.

The evidence separates three concerns: stale recorded poses being reconstructed on open; Save capturing recovery poses before acquisition finishes; and F's contact-preserving guidance falling back to raw interpolation. Different arm-frame treatment exists, but the measured post-entry writer largely preserves the requested Hand world frames and should not be blamed for the large contact gap on local-angle differences alone. These should be discussed as focused fixes, not another broad body/grip rewrite or a return to rejecting Save/F for pose-quality warnings.
