# Arm Rig Guide Review and Shared Body Scope — 2026-10-28

This is the current decision and comparison note for BODY-01. The user requested durable notes so the scope survives continuation. **Status update: the subsequent user instruction authorizes a bounded shared-body implementation and targeted tests, with an SPS at completion.** The comparison sections below describe the earlier read-only review; its implementation hold is superseded by this authorization. No new Git operation is authorized.

## User decisions — current authority

1. **Usability and predictability in Skill Crafter are the goal.** The user explicitly withdrew the triangular-return example as an acceptance target. Do not optimize for exact A → B → C → A orientation restoration or require an absolute-reference solver because of that example. Smooth continuity, understandable control and absence of disruptive flipping/twisting are the practical goals. The mathematical literature on closed paths remains background, not a product requirement.
2. **Body is body.** The intended implementation is shared across Unarmed and every current/future weapon archetype. Use the existing Unarmed mode to isolate body behavior by removing the weapon component during initial tests. Do not build an Unarmed-only correction, duplicate anatomy rules by weapon type, or stop at an editor-only fix.
3. **Use the supplied paper/guide as guidance.** It is an external engineering proposal, not a replacement for current user decisions or evidence from our actual skeleton. Existing and future attachment systems consume the shared body result; they do not redefine human joint behavior independently.
4. **Allow practical tolerance when needed, up to 3%.** The user initially authorized up to 3% instead of forcing exact solves. When asked whether this covered target error or joint-bound extension, the clarification was: “use the paper as guidance, if need be we can implement tolerance on top of that, if need be.” Do not turn this into an automatic 3% expansion everywhere, insist on exact-zero residuals, or claim a target-only restriction was chosen. Determine the particular tolerance from evidence of need, document its purpose and normalization, and keep it within the stated allowance.
5. **Implementation authorization has now arrived.** Keep the work bounded, preserve time for the SPS, and trace every coordinate through its bone/reference chain. Live Skill Crafter, F and equipped use must share the rule. Do not undertake an indefinite optimization pass.

### Percentage tolerance: how to keep it meaningful

For each proposed margin, record the measured quantity, its reference magnitude, the allowed fraction and the resulting value in physical units. State whether the margin concerns target matching, a numerical comparison or a permitted boundary margin. Distance and rotation cannot share an unexplained denominator.

Examples of reference candidates are a relevant segment/reach length for a positional check or a relevant permitted angular span for a joint check. These are candidates, not selected defaults. Do not use the magnitude of a world coordinate or a target angle that happens to be zero. Record practical visual effects, including hand contact, before accepting a margin. An allowance of up to 3% does not mean every test must use 3%.

The guide's illustrative 0.1°/1 mm development thresholds and 0–145° elbow interval are not automatically adopted. No live thresholds changed during this comparison. No full shoulder profile, wrist model, search budget or percentage reference table has yet been selected.

## Documents and reading order

- [User-supplied implementation guide](<The Will Arm Rig Constraints and IK Implementation Guide.md>): read in full; kept unchanged. Approximately 761 lines, 45.8 kB in the reviewed copy.
- [Research entrypoint and coordinate worksheet](<../ToDo stuff/Shoulder Anatomy And Unarmed Rig Reference 2026-10-28.md>): anatomy-to-rig notation and proposed observations, updated with the latest user decisions.
- [Anatomy evidence and bibliography](<../ToDo stuff/Shoulder Anatomy Research 2026-10-28.md>): distinguishes measurement conventions, active/passive ranges and engineering approximations.
- [Live rig mapping audit](<../ToDo stuff/Shoulder Rig Mapping Audit 2026-10-28.md>): actual hierarchy, rotation writers, numerical allowances, source fingerprints and replay integration.
- [Body mobility task](<../ToDo stuff/Skill Crafter Body Mobility Preparation 2026-10-19.md>) and [Project TODO](<../ToDo stuff/Project TODO.md>): BODY-01 remains open; previous narrow corrections are not a full anatomy pass.

This note supersedes earlier suggestions that made exact triangular closure an acceptance contract or described Unarmed as the implementation boundary. Historical SPS files retain their historical statements; use the current task notes for the updated direction.

## What the full guide contributes

The central division is useful: define legal joint configurations; find a suitable configuration near the requested full hand pose; deform the mesh from the accepted configuration. Hand-target success alone does not certify the intermediate joints, and legal joints alone do not certify skin quality.

The reviewed equations for calibrated coordinate conversion, signed hinge angle, hinge-plus-roll composition, swing–twist decomposition, ideal two-link reach and elbow-circle construction are consistent under their stated assumptions. Grip-offset conversion and damped numerical steps also state the relevant frame/order assumptions. This is a review of the proposed model, not proof that our imported skeleton currently implements it.

The guide explicitly assumes a simplified zero-carrying-angle hinge for its basic derivations. A calibrated carrying-angle variant needs its own forward-kinematic mapping and reach interpretation. A bent calibration pose establishes a geometric hinge reference, but pronation zero must also be linked to a known hand/forearm orientation.

Useful features to retain when a design is selected:

- Diagnose signed elbow inversion, elbow swivel, singularity, competing writers and skin collapse separately.
- Give upper-arm axial orientation responsibility for carrying the material hinge frame; keep forearm pronation distinct from that hinge.
- Enforce the selected constraints during the solve rather than applying unrelated late corrections that invalidate earlier results.
- Distinguish original request, adjusted candidate and accepted pose; report residuals instead of silently changing intent.
- Distinguish a failed bounded search from proven geometric impossibility.
- Map helpers according to actual serial/branch hierarchy and preserve the accepted joint centres and hand orientation.

The source review found that the swing–twist factorization is supported by [Dobrowolski](https://arxiv.org/abs/1506.05481). Its scalar is a chosen orientation coordinate, not automatically an ISB axial angle or the integrated biological axial-rotation measure from the earlier research. [Akhter and Black](https://www.cv-foundation.org/openaccess/content_cvpr_2015/papers/Akhter_Pose-Conditioned_Joint_Angle_2015_CVPR_paper.pdf) supports pose-conditioned restrictions but does not supply the guide's full humeral axial-twist envelope. Building our character's profile remains substantive work.

## Fit to the current skeleton and code

The existing Clavicle → Upperarm → Forearm → Hand chain can represent the guide's logical shoulder, hinge, forearm-roll and wrist controls without requiring one physical bone per logical degree of freedom. This is mathematical compatibility, not a verified skin-quality result. There is no separately named scapula; any reduced support model must state its approximation.

Current conflicts identified by code inspection:

| Current behavior | Implication for a guide-based model |
| --- | --- |
| Main Upperarm is reconstructed as pure swing, with Forearm compensation | It cannot simultaneously be treated as an independently axially oriented humerus carrying the hinge without changing that authority. |
| Manual “upperarm roll” moves the elbow around shoulder-to-hand | Treat it as an elbow-placement request under the shared joint rules; it is not identical to shoulder-to-elbow axial rotation. |
| Forearm signed guard uses the incoming bend plane | It closes one demonstrated crossing route but does not establish the calibrated material hinge and lateral-plane invariant. |
| Wrist orientation and helper distribution run after arm positioning | All writers must agree on accepted orientation; a later operation must not silently undo the joint solve. |
| Twist helpers branch beside the main downstream joints | Deforming those branches does not by inheritance rotate the Forearm/Hand parent frame. Each two-helper branch is internally serial; account for inherited main-bone rotation before adding helper rotations. |
| Automatic torso/clavicle posing and CCD both affect support | Driver clamps are not necessarily final socket limits. Record order and final state. |
| Live and prepared-arm paths duplicate pure-swing rules | A correction must reach the common behavior used by editing, prepared tracks and equipped playback. |

The saved mapping audit identifies the exact files/functions. No hierarchy rewrite, new physical bones, new skinning backend or whole-solver replacement has been selected. Skin weights and ElbowShareBone influence still need direct verification before promising deformation quality.

## Playback and lifecycle must stay in scope

Current prepared-track code interpolates local bone quaternions; Unarmed bypasses the weapon attachment correction. A stricter hinge-plus-roll model therefore requires a decision about interpolation, not merely legal endpoints.

A small independent algebra check used the guide's fixed-parent model `Rx(alpha) * Ry(rho)`:

| State | Flexion alpha | Forearm roll rho | Hinge-plane departure |
| --- | --- | --- | --- |
| A | 20° | -80° | 0° |
| B | 120° | +80° | 0° |
| Shortest quaternion interpolation at halfway | Combined orientation | Combined orientation | Approximately -42.74° |
| Interpolation of alpha/rho at halfway | 70° | 0° | 0° |

This demonstrates that arbitrary quaternion interpolation between legal endpoints need not preserve the proposed hinge model. **It is synthetic mathematical evidence, not a live reproduction of the current defect.** Interpolating meaningful joint parameters is one possible inexpensive approach. It alone does not establish collision freedom or compliance with a nonconvex shoulder envelope.

Preserve the established lifecycle: editing captures usable solved node state; R records it; F prepares/plays the authored sequence; Save writes the selected skill for equipped consumption. This guide does not authorize restoring repeated finger acquisition or a heavy full-body search at every playback sample. Decide which checks belong to editing/preparation and which values can be reconstructed or replayed cheaply.

Changed profile/calibration rules must enter prepared-context identity. Existing captured endpoints and derived replay caches are different layers; a runtime-cache version bump alone does not update stale endpoint meaning. Preserve authored controls when designing any migration.

## Remaining design work, judged by usability

- **Orientation authority and calibration:** which existing bone/logical frame owns shoulder support, humeral roll, hinge, forearm rotation and wrist movement; define their neutrals on both sides.
- **Anatomical profile:** establish a practical allowed region and how it is expressed. Literature values in different frames cannot be pasted into the same table.
- **History and continuity:** previous-state seeds, preferences and hysteresis are allowed design choices. Select them for predictable editing; do not require exact loop closure from the withdrawn example. Record enough state to explain unexpected jumps or drift.
- **Target priorities:** the guide's finite weighted objective can choose an approximate pose even when an exact pose is available. Define acceptable tradeoffs and residual tolerance, especially where a held hand must remain attached. This is not a mandate for zero error.
- **Singularities:** straight-arm, collinear-pole, antiparallel transport and swing–twist chart transitions need explicit behavior. A new coordinate chart also needs consistently expressed limits; changing quaternion sign alone is insufficient.
- **Scope of clearance/timing:** follow current gameplay policies. The generic guide's full environment-path checks and hard speed limits do not automatically override the accepted grip-flip ground intersection, authored node durations or 160 ms entry rule.
- **Regression coverage:** Unarmed isolates the shared body; later checks confirm that held-object attachments, support-hand constraints, capture and replay consume the same result correctly. Passing an isolated body test does not by itself prove those integrations.

## Review-time implementation direction — now followed in a bounded slice

The review proposed beginning from the actual shared rig and existing Unarmed controls, calibrating both sides and tracing the first conflicting writer. The subsequent implementation replaced the Upperarm pure-swing authority and integrated its calibrated material frame through preparation and replay. Unarmed preparation was blocked, so the user redirected the live test to the established weapon fixture. See [implementation and evidence](<../ToDo stuff/Arm Material Frame Implementation 2026-10-28.md>). Broader anatomical limits, skin quality and all motion discontinuities are not declared solved.

Avoid stacking a new final clamp over competing writers. Avoid implementing every optional module in the guide merely because it is listed. Existing diagnostics and capture infrastructure are reusable; the source guide explicitly allows retaining a suitable existing solver.

Godot API references in the supplied guide use 4.6. Relevant [Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html), [SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html), [TwoBoneIK3D](https://docs.godotengine.org/en/4.7/classes/class_twoboneik3d.html), [IterateIK3D](https://docs.godotengine.org/en/4.7/classes/class_iterateik3d.html) and [BoneTwistDisperser3D](https://docs.godotengine.org/en/4.7/classes/class_bonetwistdisperser3d.html) behavior was checked against official 4.7 documentation. These are possible building blocks, not a selected replacement or a complete anatomical solution.

## Verification status at the end of the comparison-only review

- Full user guide read; equations, primary references and current-code compatibility reviewed.
- Independent synthetic quaternion example calculated; no production/runtime reproduction implied.
- Existing code-owner fingerprints matched the prior mapping snapshot during review.
- No game run, anatomical implementation, runtime threshold change, real saved-skill edit or Git operation in this pass.
- BODY-01 remains open. The narrow signed folded-limit correction and red failure-node feedback retain their earlier limited evidence; the full twisting/inversion problem and original F/Save elbow-circle blocker are not declared solved.
