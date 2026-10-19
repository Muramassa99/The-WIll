# Skill Crafter Body Control And Directional Combat Brainstorm 2026-10-19

Session date: 2026-10-19, Europe/Bucharest.

Preserve the discussion about greater player agency over body and skill composition, together with the related future directional combat ideas. The immediate next focus is body mobility and more extensive player control over skill/body composition. Combat classification is future work, not the next implementation task.

This session was explicitly brainstorming and read-only investigation. The user subsequently authorized saving the useful discussion and the supplied image. No game code, saved weapon data or Git history was changed, and no Godot runtime tests were run for this session.

## Decisions And Status

| Topic | Status at the end of the session |
| --- | --- |
| Next focus | Body mobility and player agency in composing skills and poses. |
| Torso, head and hip control | User wants more torso rotation/position control, head direction and hip twist for expressive, fluid motion. Detailed controls remain to be designed. |
| Advanced animation mode | Explore optional additional controls while preserving approachable use and flow. A full general-purpose animation editor was not commissioned. |
| Wrist and shoulder defects | Assume solved for this design discussion only. They remain unresolved in actual project state; do not record them as fixed or use them to block the hypothetical discussion. |
| Future damage/contact direction | Explicit user choice: "directional it is." Use forgiving contact detection with direction-based slash/blunt/pierce classification. Precise per-edge hitbox zones are not the selected starting approach. |
| Scan comparison | User clarified that the drawing means a scan length below 60% of the longest scan, not an angle of 60 degrees. This is a proposed heuristic, not a validated threshold. |
| Sharpness validation | User accepted that a local taper/sharpness check is also needed; scan length alone is insufficient. |
| Scope | Save the discussion now. Do not turn these notes into automatic implementation authorization. |

## Why More Animation Control Is Being Considered

The user anticipates professional animators trying a demo/alpha/beta and identifying control or workflow limits. The goal is to let skilled creators express the poses and motion they intend while retaining a usable creation tool for ordinary players. The user does not have enough Blender experience to judge feature parity personally and wants informed feedback rather than an attempt to reproduce Blender wholesale.

Desired expression includes body motion accompanying the weapon: torso rotation and positioning, head direction, hip twist, and coordinated, organic motion through a chain of poses. These controls should support both artistic presentation and deliberate weapon orientation at contact.

Blender is a workflow reference. A model originally intended for Blender does not automatically provide a complete animator control rig inside Godot. Deforming bones, animator-facing controls, and the authoring interface are separate concerns.

Assistant recommendations to evaluate, not an approved feature list:

- Keep one shared authored-data and playback system, exposing more controls progressively. Returning to a simpler UI should preserve existing advanced choices.
- Define how deliberate body edits interact with automatic body following, weapon targets, grip constraints and pinned contacts. Avoid one solver silently overwriting an artist's chosen pose.
- Consider elbow direction, independent chest/shoulder/pelvis/head controls, clearer timing, pose copying/mirroring and useful motion previews.
- Evaluate a few animators attempting a concrete short sequence. Observe what result they cannot achieve, which corrections are repetitive, and whether saved playback preserves their intent. No external test program was commissioned.
- Judge capability by expressive results and predictable editing, rather than number of sliders or nominal feature parity.

NEEDS_DECISION: the initial body-control set; local versus whole-character translation; what remains planted when hips/torso move; control spaces, ownership and limits; how body controls relate to gameplay locomotion; interface and save-data representation. No new anatomical angle limits were agreed.

## Orientation And Target Aids

User proposals:

- A ground arrow in the authoring environment showing character front, to avoid losing orientation while orbiting the view.
- Alternatively, a visual target approximately 80% of maximum weapon range in front of the character, to help place and understand intended hits.

The user did not choose between these aids or specify that both must be built. Maximum range, its reference origin, target height, target movement and exact presentation remain open. Keeping a stable reference-facing arrow and a target that does not continually chase the edited pose were assistant suggestions, not agreed rules.

## Timing Handling And Damage Context

The user recalls earlier acceleration variants and intends weapon geometry, mass, heaviness/balance and motion to affect execution limits and eventual damage. The business end was described as the Tip. A threshold in its movement would govern when an attack becomes effective, with additional data governing maximum animation speed.

Relevant existing notes were found in the [Skill Crafter Unified Implementation TODO](<Skill Crafter Unified Implementation TODO 2026-04-30.md>):

- The slowdown/reset and speed-state section, around lines 507-529, describes acceleration/deceleration tuning, sampled trajectory feedback and later hit activation.
- The parked August 29 handling/damage hypothesis, around lines 898-941, distinguishes intrinsic weapon mass/COM from active grip state and handling limits. Authored duration is requested timing; the proposed handling system supplies the fastest permitted execution. Slower deliberate motion remains allowed.
- That hypothesis considers mass, COM, length, lever arms, grip positions, acceleration, deceleration and redirection. It also discusses retaining motion across a compatible two-hand wind-up to one-hand release.
- Exact damage, critical-strike and DPS relationships remain undecided. Old examples are not ready-made equations or proof of implementation.

Current code inspection found tip/pommel distance-over-time sampling with a tuning envelope in `core/resolvers/combat_animation_speed_state_sampler.gd`; this is not evidence of a complete mass/inertia/contact-damage simulation. Older reset rules and later momentum-continuity proposals need reconciliation before implementation.

Technical distinctions to preserve for that later design:

- Metres/second describes speed; acceleration is change in velocity per second. The user's threshold wording needs an explicit speed-versus-acceleration decision, not silent conversion into a formula.
- Tip paths describe motion. Angular momentum also requires mass distribution and rotation; a tip tracer alone does not determine it.
- A tip's motion need not equal the motion of the actual striking portion during combined translation, rotation and roll.
- Animation can be prepared during creation and replayed from saved results. Runtime still performs sampling, transforms, skinning and contact/gameplay work; it is not calculation-free.

## Directional Contact Is The Selected Future Approach

The discussion initially considered regional geometry-derived hitboxes. The user's final preference is to use angles and directions for classification while allowing a broader, more forgiving collision shape. Do not make precise per-cutting-edge collision zones a prerequisite.

Separate the two responsibilities:

| Responsibility | Intended approach |
| --- | --- |
| Detect gameplay contact | A sufficiently forgiving collision volume moving with the weapon; exact shape and tolerance are undecided. |
| Classify a valid contact | Prepared weapon geometry/directional properties combined with weapon orientation and motion relative to the contacted object. |
| Apply a result | Future damage/effect/world-interaction rules consume that contact result. Exact charts and formulas are open. |

The user wants the same weapon to behave differently depending on how it is presented. A blade can lead with an edge for a cut or with its flat for a blunt interaction. A rounded club remains blunt in the intended slashing orientations. A broad blade, with a Buster Sword given as an illustrative reference, could support both cutting and broad-surface defensive use.

User's proposed classifier:

- A suitably acute leading geometry direction produces a slash/cutting result.
- Other valid striking directions produce a blunt result.
- Travel within an angular cone of the Tip-Pommel axis represents thrust/pierce use. The cone angle Y was not specified.

Assistant refinements still requiring detailed agreement:

- The axial cone identifies thrusting motion. Requiring a suitable contacting point for piercing would prevent a flat-ended club thrust from automatically becoming piercing damage.
- Relative motion matters for incoming projectiles and stationary guards. A weapon need not swing to receive a meaningful directional contact.
- Use a stable relation to the weapon's orientation. The identified directions turn with the weapon, including authored roll.
- An inflated collider adds tolerance and effective reach; allowed visible penetration is a separate choice. Showing the effective gameplay envelope in Skill Crafter was suggested.
- Motion-aware/swept contact checks are relevant to fast movement. A hitbox shifted ahead of the visible weapon could register premature contact; inflation alone does not solve missed intermediate motion.
- Whole-weapon direction rules lose some contact-location information. Handle contacts, mixed heads and unusual builds may expose that tradeoff. A few broad functional sections were mentioned only as a possible fallback if testing warrants them, not as a selected requirement.

No exact angular thresholds, contact margins, attack activation rules, speed caps, material gates or damage formulas were finalized.

## Cross Section Scan Proposal And Original Image

![Original user drawing of a cross-section with red spline centre, coloured scan directions and longest/shorter comparisons](<../../images and refferences/skill-crafter-directional-cross-section-2026-10-19.png>)

Original chat attachment, preserved without editing or reconstruction: PNG, 430 x 420 pixels, 48,774 bytes. The apparent degree-like mark in the handwritten annotation is clarified by the user's reply: **length below 60% of the longest scan**, not 60 degrees. Keep the original artwork unchanged and read it with that clarification.

The proposed construction uses the main spline's red centre/path as the reference. Several colour-coded scans cross the section. The longest span becomes the 100% reference and a candidate cutting direction; shorter directions below the proposed 60% ratio are candidates for blunt directions. The user suggested a three-axis construction; exact scan count and orientation are not settled.

Additional geometry validation was accepted because relative length alone does not prove an edge. An elongated rectangle can have a long axis and broad flat ends; a shorter protrusion can still be sharp. Check whether the local surface narrows into an exposed edge rather than treating every longest span as cutting.

Further assistant implementation ideas, not finalized algorithms:

- Use a cross-section plane perpendicular to the local spline tangent, with scan directions within that plane. An axis along the spline is not another comparable cross-sectional span.
- Follow the local profile orientation through bends and twist.
- Assess the two ends independently; one side may be an edge and the other a thick spine.
- Include relevant profile corners or refine candidate directions so a small fixed scan set does not miss an edge lying between them.
- Treat geometric sharpness as a property of the actual profile/surface rather than arbitrary render-triangle corners.

The final directional choice keeps this scan idea as a possible way of preparing orientation/capability information. It does not commit to exporting a separate collision zone for every scan or detected edge.

## What The Existing Twist Guides Actually Provide

The guides are basic visual indicators. The user was independently explaining their understanding while the assistant's message was being written; those messages crossed in time. This was not a disagreement about requirements.

Fresh read-only inspection found:

- `runtime/forge_v2/forge_v2_volume_preview_presenter.gd`, around line 979: guide construction chooses a farthest profile vertex and an opposing projected vertex, then traces them. Those are display choices; a round profile gets guides too. They are not an edge classifier.
- `runtime/forge_v2/forge_v2_path_roll.gd`, around line 364: shared data includes sampled centreline points, tangents, perpendicular profile axes, roll and distances.
- `runtime/forge_v2/forge_v2_volume_preview_presenter.gd`, around line 9391: solid construction uses the shared frames and profile rings to generate side surfaces and caps.

The reusable foundation is the profile and sweep geometry behind the lines. Cutting-edge identification would be additional work. Placement/reference normals and guide-tube rendering normals are not automatically final weapon surface normals.

Add/Remove composition can cover, remove or create edges. Any final directional properties derived from source profiles must remain consistent with the final composed weapon, including fused history. No completed sharpness classifier or regional combat-collider system was established by this inspection.

## Projectile Responses And World Interaction

User's intended future gameplay examples:

- Blunt contact with an incoming projectile can deflect it.
- Slash contact can visually separate an incoming projectile into two pieces that clear the character on opposite sides.
- Deflection direction depends on incoming direction, weapon/surface orientation and swing direction/speed.
- Redirected attacks may travel toward other actors, including a friend behind the player, subject to the eventual friendly-fire rules.
- Environmental example: redirect a burning enemy attack upward into a rope; the rope burns and releases a drawbridge.

The intended value extends beyond damage type versus HP. Directional contact can support reusable environmental mechanics and deliberate player technique.

Assistant proposals and unresolved details:

- A successful cut's guaranteed two-sided clearance must be an explicit gameplay response; merely splitting geometry does not guarantee both halves miss the player.
- Prepared split visuals could avoid arbitrary live mesh cutting. This is an optimization option, not a requirement.
- Deflection can begin with a surface-based directional bounce, with moving-weapon influence and retained speed supplied by future gameplay rules.
- Contact information can feed damage, projectile responses and environmental interactions. Successful deflection/cutting conditions, projectile eligibility, fragment behaviour, ownership and friendly fire remain to be specified.

## Historical Cutting And Blunt Notes

Direct searches for `blunt` found the original idea in the uploaded historical documentation:

- [Forge material pipeline framework](<../UPLOADED/forge material pipeline framework.txt>), around lines 535-547: thin/long/exposed forms as edge candidates; thick/heavy/front-loaded forms as blunt candidates; broad flat forms as guard candidates.
- [Clean rule pack](<../UPLOADED/clean rule pack for next resolvers.md>), around lines 274-338: separate material/geometry conditions for cutting and blunt; softened corners alone do not make a mace or handle into a cutting edge.
- [The creation process](<../UPLOADED/The creation process.txt>), around lines 99-129: blade/blunt/pierce weighting, mass/reach/balance and conceptual skill behaviour.
- [Stage 2 specification from April 9](<../UPLOADED/STAGE 2 - UNIFIED VISUAL SHELL IMPLEMENTATION SPEC 2026-04-09.md>), around lines 229-247: explicitly shelved the cutting-edge/blunt-zone classifier in favour of simple containment-style collision.

The user clarified why it was shelved: the Forge V1 block-era build did not offer a convincing way to establish the desired rules. Forge V2 provides a different basis. That historical drop is not a current prohibition. Reconsider the intended behaviour using current geometry and the final directional preference; do not restore old block-based classifier assumptions automatically.

## Current Skill Crafter Foundations And Gaps

These are code-inspection findings, not runtime quality or performance certification:

- `core/models/combat_animation_motion_node.gd`, around line 31, stores weapon-first paths, roll, timing, grip states, body-support blend, upper-arm roll and free-hand proxies. It does not provide general independently keyed bone channels.
- `runtime/player/player_rig_upper_body_pose_presenter.gd`, around line 75, derives much upper-body movement from weapon/hand targets. New artistic controls need explicit authority alongside that automation.
- `runtime/player/player_humanoid_rig.gd`, around line 79, lists captured upper-body, twist and finger bones. Current solved-pose replay coverage does not include the full legs/feet/head/neck chain.
- `runtime/combat/combat_animation_chain_player.gd`, around line 860, samples spatial weapon paths and interpolates properties. A broader timing-curve system would need additional authored data.
- `runtime/combat/combat_animation_station_preview_presenter.gd`, around line 646, bakes solved body/weapon/anchor motion. `runtime/player/player_runtime_skill_playback_presenter.gd`, around line 373, still prepares a playback clip and uses cached pose tracks; runtime is not free of calculations.
- Existing neighbouring motion previews are weapon endpoint markers, not established full-body ghost poses.

The design opportunity is to do suitable preparation during creation and preserve the approved result for efficient replay. More controls do not establish a particular performance cost by themselves. Editing responsiveness, bake time, stored data and gameplay playback need separate measurement when a concrete change is selected.

## Research References

- [Blender deforming and control bones](https://docs.blender.org/manual/en/5.0/animation/armatures/bones/introduction.html).
- [Blender Graph Editor and values over time](https://docs.blender.org/manual/en/4.1/editors/graph_editor/introduction.html).
- [Godot 4.7 SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html).
- [Godot 4.7 ShapeCast3D](https://docs.godotengine.org/en/4.7/classes/class_shapecast3d.html) and [physics-space queries](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate3d.html).
- [Godot 4.7 vector bounce](https://docs.godotengine.org/en/4.7/classes/class_vector3.html#class-vector3-method-bounce).
- [Angular momentum and mass distribution](https://openstax.org/books/university-physics-volume-1/pages/11-2-angular-momentum).

## Next Session Entry

Start with the player's mobility and agency over body/skill composition. Establish the desired torso, hip and head controls and how they coexist with weapon/grip ownership, then inspect the current authoring, body-solve and replay owners before proposing a bounded implementation slice. A future session still needs explicit scope; this handoff does not authorize implementing every idea above.

Keep directional damage, projectile splitting/deflection, environmental mechanics and their thresholds parked as future design. Preserve the real wrist/shoulder TODO, but do not present those issues as solved or revive them as a blocker to the agreed hypothetical discussion.

Design discussion preserved; implementation rules, thresholds, feasibility, performance and detailed control UX remain to be established.

## Subsequent Body-Mobility Preparation - 2026-10-19

The user subsequently selected upstream shoulder/arm investigation before wrist
limit adjustment and authorized diagnostic engine runs. The requested real-item
reproduction is a normal single-hand pommel thrust and retraction on both sides,
using skill slot 2. Retain the test environment for later body-control work.
See [Body Mobility Preparation](<Skill Crafter Body Mobility Preparation 2026-10-19.md>)
for code ownership, diagnostic evidence, fixture limitations and the bounded
control plan. Production solver changes remain outside this prep session.
