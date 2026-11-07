The Will lets players author functional skills inside the running game. They manually position poses through the shared two-point controls, adjust spline handles to define the trajectories between those poses, and compile the generated motion into a skill slot. Activating that slot plays the compiled motion together with its gameplay data.

The anatomical requirement applies to the entire generated transition. Valid poses A and B do not guarantee a valid motion from A to B. The body solver must produce a continuous joint trajectory that follows the authored tool path, preserves the active grips and remains within the joint relationships throughout.

Most movement uses tools or weapons. Their extremities provide the control pair; a weaponless hand uses its index and pinky knuckles. An unused offhand remains independently poseable, while a two-handed grip connects both arms to one controlled object. This guide specifies the coordination layer for Josie, whose rig has no shoulder-blade bone.

| Stage | Responsibility |
| - | - |
| Pose authoring | Solve the player's manually positioned controls into accepted body poses and record the spline settings |
| Motion compilation | Generate the intervening motion from the authored paths and timing, solve coordinated body movement, validate it and save the result with skill data |
| Skill activation | Play the compiled result on the skill timeline while processing hitboxes, collisions, damage rules and effects |

Authoring and compilation happen inside the running game. They are separate from execution of the finished skill. Map the actual bone axes, available clavicle controls and solver interfaces to the current project.

# 1 What the observed arm circle means

Moving the hand forward, overhead, behind the body and down changes several relationships at once. The upper arm changes direction and axial orientation; the shoulder girdle contributes; the elbow and forearm may adjust; the palm may change direction. Human shoulder research demonstrates that glenohumeral and scapulothoracic motion contribute together to humeral axial rotation, with contributions depending on the movement. [Aliaj and colleagues 2022](https://scholarlycommons.henryford.com/orthopaedics_articles/410/)

The visible change of route does not establish that bones first collide and then trigger rotation. Use approaching anatomical boundaries and body clearance as control signals. Muscular coordination can prepare those adjustments before a hard boundary is reached.

A hand can trace repeated loops while the arm passes repeatedly through a bounded set of legal configurations. Accumulated hand travel around a circle is not accumulated axial twist of one joint. Track both the full pose and the anatomical roll coordinates. Do not cap a circular hand path simply because its accumulated travel exceeds 360 degrees.

Changing the direction of a bone also changes how its orientation is described. Shoulder motion has a geometric effect illustrated by Codman’s paradox: a closed sequence of changes in arm direction can alter apparent axial orientation. This makes a fixed, calibrated reference essential when comparing roll across poses. [University of Washington shoulder motion reference](https://orthop.washington.edu/patient-care/articles/shoulder/humerothoracic-positions-and-motion.html)

A perfectly planar circle with a locked elbow, fixed shoulder socket and fixed palm orientation is a different request from a natural arm circle. The controller must know which of those properties the user actually intends to hold.

# 2 Interpret XYZW correctly

When the Godot bone inspector shows rotation as X, Y, Z and W, those values are quaternion components. They jointly encode one 3D orientation. They are not four independent anatomical angles. Godot’s bone pose rotation is expressed relative to its parent bone; skeleton global bone poses are relative to the Skeleton3D, not automatically to the game world. [Godot Quaternion](https://docs.godotengine.org/en/stable/classes/class_quaternion.html) and [Skeleton3D](https://docs.godotengine.org/en/stable/classes/class_skeleton3d.html)

Keep the existing anatomical calibration between imported bone frames and anatomical frames. Calculate readable values from those calibrated frames: shoulder direction, humeral internal or external rotation, elbow bend, forearm pronation or supination, and the two wrist bends. Apply limits there, then construct the bone transforms.

Do not clamp quaternion X, Y, Z or W separately. Converting to Euler angles also does not automatically produce anatomical angles; axis order and the reference frame still matter. A quaternion represents orientation and does not preserve a count of completed revolutions.

For debugging, show anatomical angles, their current permitted intervals, the active coordinate chart and body clearance beside the raw transform. Preserve the established anatomical references across drags, chart transitions and save/load. A quaternion sign change alone is not a physical flip.

# 3 Define the shared two point controller

Treat the manipulated item as a rigid control frame with two local endpoint markers and a persistent transverse orientation reference. A weaponless hand uses a hand-sized virtual control frame; it does not require a visible object or a separate wrist-only interface.

| Configuration | First endpoint | Second endpoint | Orientation reference |
| - | - | - | - |
| Tool or weapon | Tip or designated working extremity | Pommel or designated opposite extremity | Complete object orientation, calibrated to the palm frame through the grip |
| Weaponless hand | Index knuckle | Pinky knuckle | The existing palm-facing axis |
| Offhand not gripping an object | Its own index knuckle | Its own pinky knuckle | Its own palm-facing axis |
| Two hands gripping one object | The object's first endpoint | The object's second endpoint | One shared object orientation, with a separate grip transform for each hand |

Keep the endpoint separation fixed for the current rigid control frame. Moving a control changes the requested rigid pose under that control's mode. It must not stretch a weapon, change hand width or redefine the grip to force a solution.

## Build the palm reference from the existing anchors

Let I and P be the index and pinky knuckle anchors, M their midpoint, and W the wrist center. Use stable palm-relative anchors, not animated fingertips. The pinky-to-index direction and the midpoint-to-wrist direction define the palm plane.

An orthonormal frame can be constructed as follows:

```math
M=\frac{I+P}{2},\qquad
a=\frac{I-P}{\|I-P\|}
```

```math
t=\frac{(W-M)-a\,[a\cdot(W-M)]}
{\|(W-M)-a\,[a\cdot(W-M)]\|},\qquad
n=\sigma(a\times t),\qquad
b=n\times a
```

Choose the fixed per-hand sign sigma so that n points out through the palm side. Then R_H = [a, b, n] is a right-handed orientation basis and M is its origin. Depending on the hand and sign convention, b may point toward or away from the wrist; record that mapping. Do not flip only one column of an existing basis and leave a reflected coordinate system.

This numerical cleanup preserves the user's T-shaped reference even if its measured segments are not exactly perpendicular. Reject coincident anchors or a nearly zero projected wrist direction; do not normalize those cases. Godot represents a basis using three axis columns and uses a right-handed coordinate system. [Godot Basis](https://docs.godotengine.org/en/stable/classes/class_basis.html)

For body-relative orientation, express n and a in the chest's rotation frame. For example, n_body = transpose(R_chest) \* n_world when R_chest is a pure rotation. Dot products with calibrated chest axes provide continuous measures of palm-up, inward or outward orientation. Labels are useful for debugging; avoid abrupt anatomical gates at label boundaries. A palm normal alone does not specify rotation around itself, so retain the complete frame.

## Capture the completed grip as a full transform

After automatic gripping succeeds, capture the hand's complete position and orientation relative to the object. The knuckle axis is parallel to the selected handle axis, with the grip's polarity and lateral offset preserved. A parallel-axis rule alone does not preserve the full grip.

Let T_O be the object's world transform and T_H the palm frame's world transform. Store G for that hand:

```math
G=T_O^{-1}T_H,\qquad
T_H^{\mathrm{target}}=T_O^{\mathrm{candidate}}G
```

The constant G contains both the orientation relationship and the offset that seats the handle in the palm. These are ordinary rigid-transform compositions. [Modern Robotics on transformations](https://modernrobotics.northwestern.edu/nu-gm-book-resource/3-3-1-homogeneous-transformation-matrices/)

The knuckle midpoint is not the anatomical wrist center. If A maps from the palm frame to the rigid hand-bone frame at the wrist, derive the IK hand target as T_J_target = T_O_candidate \* G \* A. This targets the distal hand frame; it does not lock the forearm frame to the hand or remove the wrist's two allowed bends.

For a weaponless hand, choose the virtual object frame to be the palm frame, so G is the identity. Use the same target construction and body solver with the hand's own endpoint offsets.

Keep G fixed during an established grip. Do not recapture it from each imperfect IK result, which would turn solver error into grip slip. Change it only through an intentional grip edit, release or regrip. Keep the selected handle axis separate from the endpoint line when an object's geometry makes them different.

Use rigid transforms for the solver and handle imported scale through the existing rig calibration. Godot's Transform3D contains a basis and an origin; an arbitrary basis may also contain scale or shear. [Godot Transform3D](https://docs.godotengine.org/en/stable/classes/class_transform3d.html)

## Assign each hand independently

Each hand is either independently controlled through its knuckle pair or attached to a controlled object through a grip transform. An offhand is not disabled just because the other hand holds a weapon.

For one-handed use, solve the weapon hand against its object-derived target. The offhand keeps its own controls and orientation state. If it is not being edited, preserve its accepted pose under its declared body-relative or world-relative policy. A world-pinned offhand must remain a constraint if shoulder or torso assistance would otherwise move it.

For two-handed use, both hands attach to the same object with different grip transforms:

```math
T_{H_R}^{\mathrm{target}}=T_O G_R,\qquad
T_{H_L}^{\mathrm{target}}=T_O G_L
```

Use one candidate T_O and solve both arms together, including shared chest or torso coordinates when enabled. Both hand targets move with that candidate. The hands are fixed relative to their handle zones, not independently pinned in world space.

A candidate is accepted only if both grips and the complete participating body satisfy their constraints. If either arm cannot follow, reduce or stop the shared object movement. Do not accept different weapon poses per hand, stretch the handle, silently slide a grip or let one arm break its limits.

In two-handed mode, independent knuckle drags cannot remain competing world-position commands on the attached hands. Interpret a grip-edit action as an intentional regrip operation, or release that hand before restoring independent posing. When engaging the second hand, keep the accepted object pose, solve a legal approach to its selected handle zone, and commit the new attachment only when the grip can be established. A failed transition preserves the previous valid configuration. On release, initialize that hand's independent control frame from its current accepted pose and retain the object's accepted pose and remaining grip, so switching roles does not snap the hand or reset anatomical references.

When both hands share movable torso coordinates, independent arms can still interact. Assemble their active targets and any hard offhand pins into the same coordinated solve rather than letting one arm's pass overwrite the other's result.

## Carry orientation through endpoint movement

Two distinct endpoint positions determine a rigid segment's location and axial direction but leave rotation around that line unspecified. The existing palm frame supplies a transverse reference at initialization; the completed grip connects that reference to the object.

Carry the complete accepted object orientation forward as controller state. Use the existing roll command when present. When only the endpoint direction changes, a continuous minimum-turn transport can supply a reference orientation; the opposite-direction case needs a stable stored transverse axis. This does not require a third visible control.

Reference transport is not anatomical permission. Check the resulting pose against the same joint limits, and do not reset anatomical zeros when the endpoint direction changes. Closed paths can alter a transported reference, so retaining full orientation and validating actual joint coordinates is essential.

If the task permits some roll adjustment, the solver may use that declared freedom while keeping the grips intact. If blade or tool-face orientation is fixed, it remains fixed. Do not rotate the weapon inside the hand or silently change its cutting-face direction to obtain an easier arm pose.

## Specify what each drag holds

The control mode supplies the rules internally; the user continues moving a few points. Distinguish an object-relative grip attachment from a world-space pin.

| Mode or condition | Held relationship | Allowed continuation |
| - | - | - |
| Translation or reach | Rigid grip and declared object orientation policy | The object, hand contact and wrist may travel together; the body adjusts reach |
| Dedicated tip orbit about the hand contact | Contact point fixed in world space, rigid grip maintained | Object orientation changes around that contact; the wrist center may still move because of its offset |
| General endpoint positioning | The requested endpoint and the mode's other declared constraints | Remaining object translation or orientation follows the mode's preferences and the feasible body pose |
| Explicitly pinned opposite endpoint | That endpoint fixed in world space | The moved endpoint is restricted to the rigid object's endpoint sphere |
| Two-handed movement | Both fixed object-relative grips | One object pose drives both hand targets and both arms |

Moving the tip farther away can extend the arm only if the relevant mode permits the hand contact to travel. The earlier fixed-contact tip-orbit mode does not permit radial reach away from that contact. Keep it as a dedicated mode rather than applying its world-space pin to every endpoint drag.

If both endpoint positions are supplied, their distance must agree with the rigid marker separation. If they disagree, return an achieved pose and target error according to the mode's priority; do not change object length. One moved endpoint alone also needs a policy for the other endpoint and roll. Previous pose and the selected mode can supply that policy without more user-facing controls.

Record the input frame, hard pins, permitted object roll, available body contributors, path tolerance and absolute-versus-relative input behavior. For a fixed object pose, the grip determines the required hand pose, but multiple arm postures can still satisfy it. Joint limits couple that choice to hand position and orientation. [Kamper and Rymer 1999](https://pubmed.ncbi.nlm.nih.gov/10333014/)

# 4 Separate restrictions from preferences

Use three levels of authority. Lower levels may use only the freedom left by higher levels.

| Level | Responsibility | Examples |
| - | - | - |
| Hard feasibility | Keep every accepted configuration and transition valid | Rigid geometry, anatomical envelopes, all active grips, hard pins, forbidden collisions |
| User task | Follow the endpoint movement as far as feasible under its contract | Object endpoint targets, declared roll or tool-face direction, active offhand targets, path tolerance |
| Pose selection | Choose a continuous and plausible body solution among comparable task solutions | Previous elbow side, joint reserve, shoulder economy, continuity of the accepted object orientation |

A hard limit is not a large penalty. If no solution satisfies the hard constraints, report the conflict and keep or recover to a validated pose. Do not buy task accuracy by accepting an illegal joint angle.

Anatomical limits must depend on the relevant pose. Retain the existing coupled wrist envelope, bend-dependent forearm interval and direction-dependent shoulder interval. A coordinator does not fill missing anatomical data: unvalidated shoulder regions remain provisional or unavailable under the existing profile policy.

For Josie, keep the effective shoulder allowance measured relative to the chest as specified in the rotation guide. Any available clavicle contribution shares that overall allowance. Do not add a second unrestricted shoulder-roll budget.

If clavicle motion can move the shoulder socket, include that motion in forward kinematics and in the same solve. If the socket is fixed by the actual rig, software cannot reproduce its translation just by increasing upper-arm rotation limits. A logical shoulder-girdle model is useful only to the extent that its result can be represented by the available transforms.

# 5 Choose posture continuously

Start each solve from the previous accepted pose. This supplies continuity and prevents the elbow from selecting a different solution independently on every frame.

Use a small collection of soft preferences:

- **Elbow continuity.** Prefer the previous bend-plane direction, with a configurable chest-relative preference for the task.

- **Orientation continuity.** Preserve the control frame's orientation reference within its declared flexibility. Gripped hand orientations follow from the object and the fixed grip transforms.

- **Joint reserve.** Prefer leaving some room before coupled limits when an equally useful pose can do so.

- **Body clearance.** Prefer additional space around the torso, head and nearby obstacles before contact becomes forbidden.

- **Economy of motion.** Avoid unnecessary changes to proximal joints and the torso.

- **Task posture.** Use the accepted starting posture or a selected tool-use preference. Automatic return to a captured ready pose is optional behavior, not a requirement for endpoint control.

Normalize angle, position and clearance errors before combining them. Their weights are behavior settings, not anatomical measurements. Use ordered objectives where the existing control contract requires a strict priority; finite weights permit trade-offs.

For object translation or reach, use continuity, joint reserve and posture preferences to coordinate elbow and shoulder motion. A wrist-first rotation preference does not mean freezing those positioning joints. For two-handed use, evaluate preferences across both arms while preserving the single shared object pose.

Preserve the user’s accepted posture when input stops, provided the context remains valid. Do not silently pull every joint toward a universal neutral pose. A captured ready posture may be an explicit preference; it is not the default destination of every endpoint movement.

## Treat the elbow pole as a preference

With fixed shoulder and wrist locations, the elbow has a family of possible positions before anatomical and collision restrictions are applied. A pole preference selects a region of that family.

Store a preferred elbow-offset direction relative to the chest or capture it from the starting pose. This points from the shoulder-to-wrist line toward the elbow. Project it perpendicular to that line, then favor nearby legal elbow positions. The line and offset together define the bend plane. If the projection becomes too small, use the previous valid offset direction or another calibrated reference. A preference to keep the elbow away from the torso is useful; a universal hard rule that the elbow must point down would obstruct overhead poses.

Near full extension, elbow-plane calculations become poorly conditioned. Preserve the latent bend plane as the elbow straightens so that bending again resumes on a continuous side. This memory does not permit hyperextension or additional humeral twist.

Elbow swivel describes alternative arm configurations; it is not an extra anatomical joint. When the elbow position changes, recompute the shoulder, elbow, forearm and wrist together. Treating the pole as a separate hard instruction can conflict with the requested hand pose.

# 6 Begin compensation before a hard stop

For each anatomical or collision constraint, calculate the remaining margin and whether the proposed step reduces it. A shoulder margin must include the change in its allowed rotation interval as the arm direction changes. A forearm margin must include the change caused by elbow bending.

Represent a general legal condition as `c(z) >= 0`, where `z` is the complete anatomical state. A local step must account for the whole gradient:

```math
c(z+\Delta z)\approx c(z)+\nabla c(z)^T\Delta z\geq 0
```

For example, an upper humeral-rotation constraint can be written as `c(z) = h_max(direction(z)) - h(z)`. Differentiating only `h` would miss the fact that moving the arm can shrink its rotation allowance.

Add a configurable warning band inside the hard boundary. As the predicted margin shrinks, progressively favor alternative legal joint combinations and reduce motion toward the boundary. At the boundary, outward motion is forbidden; inward motion becomes eligible immediately.

The warning band can use a smooth activation function. A velocity-damping constraint is another option:

```math
\dot c \geq -\kappa c,\qquad \kappa>0
```

This limits how quickly a legal margin can disappear. It still requires bounded steps and nonlinear validation after integration. Numerical tolerances and collision margins must match the character scale.

These signals provide the desired transition from mostly positional movement to coordinated position and rotation. No universal rule such as “begin shoulder roll at 120 degrees” applies to every palm orientation and elbow pose.

Use separate diagnostics for anatomical restriction and external body clearance. A torso capsule can prevent the forearm entering the chest; it does not model internal shoulder anatomy.

## Preserve the earlier movement allocation behavior

The existing distal-first weapon policy remains a joint-use preference. Necessary compensations remain available throughout the move. Keep the documented behavior on reversal: inward wrist movement becomes available without first returning the elbow or shoulder to neutral.

A posture policy must not silently replace a strict allocation contract with a different one. If anticipatory posture changes are enabled for a control mode, make their permitted scope explicit. Fixed grip and pivot compensation is mandatory whenever the task requires it; optional comfort adjustments can remain lower priority.

# 7 Solve the connected body during authoring and compilation

Use the existing constrained IK allocator for manual pose editing and for the motion compiler. Solve the controlled object pose and all required hand/body relationships coherently. An object-pose proposal followed by arm IK is workable only if feasibility feeds back before either result is accepted. Include both arms and shared body coordinates whenever their constraints interact.

The compiled skill contains the resulting motion for playback. Skill activation should not repeat the authoring search or continuously regenerate the transition through IK. Playback may interpolate the saved representation; that is a separate operation from finding a new body trajectory.

A suitable mathematical foundation is constrained IK with prioritized tasks and inequalities. Hierarchical optimization is an established way to preserve higher-priority requirements while using remaining freedom for posture objectives. [Kanoun 2011](https://www.roboticsproceedings.org/rss07/p21.html)

The following architectural pseudocode describes editing a pose. The compiler reuses its anatomical constraints and coupled solve while also considering the known trajectory and destination pose. These functions describe responsibilities rather than Godot APIs.

```text
on_authoring_control_update(input, previous_state):
    contract = interpret_endpoint_input(input)
    bindings = active_object_grips_and_independent_hands()
    state = validate_start(previous_state, current_body_and_scene)

    if input_is_idle and the validated context is unchanged:
        return state

    for requested_step in bounded_steps(contract):
        goals = build_object_and_independent_hand_goals(
            requested_step, contract, bindings
        )
        preferences = build_body_posture_preferences(state, contract)

        candidate = coordinated_solve(
            seed = state,
            object_goals = goals,
            hand_target_rule = object_pose * grip * hand_frame_offset,
            bindings = bindings,
            limits = anatomical_profiles,
            held_constraints = all_active_grips_and_hard_pins,
            clearance = body_objects_and_scene,
            preferences = preferences
        )

        if all_grips_pose_and_transition_are_valid(state, candidate):
            state = candidate
            continue

        retry using a smaller shared task step
        or a permitted connected body configuration

        if no valid continuation is found within the solve budget:
            keep the last validated object and body state
            report the blocking condition or solver failure
            break

    commit_validated_objects_and_bones_together(state)
    remember_pose_orientation_and_continuity_state(state)
    return state
```

For every candidate object pose, derive each attached hand target from its fixed grip transform. Recompute body forward kinematics, current axes, coupled limits and clearances during the iterative solve. Evaluate all enabled contributors together, including both arms when they grip one object or share movable body coordinates. Apply step limits, damping and a bounded iteration budget.

After solving, validate the nonlinear pose and the intervening motion. Legal endpoints do not prove a legal path. Use adaptive substeps or swept collision checks where needed. Unconstrained interpolation of bone quaternions can break a pinned contact or pass through an invalid coupled posture.

During authoring and compilation, keep one final coordinator responsible for accepted object and body transforms. During skill playback, the compiled motion owns those transforms. In both cases, apply a mutually consistent state and verify Godot's modifier order so later animation does not overwrite it. Rendering twist helpers distribute accepted rotation without adding anatomical freedom.

## Handle targets without accumulating an invisible backlog

While editing a pose, keep the requested control position separate from the achieved position. Show the error for an unreachable absolute target. For relative dragging, discard the blocked portion under the existing no-windup policy so reversal responds promptly. During compilation, a failure to follow an authored segment is an error to resolve; do not silently bake the editor's clamped preview as a completed segment.

For an interactive edit, scale progress along a requested increment rather than clipping each Cartesian axis independently. For compilation, smaller solver steps improve numerical resolution; they do not authorize changing the authored path or duration. Any permitted path adjustment or retiming must be explicit and reflected in the resulting skill timeline.

If the authoring context changes and makes the current pose invalid, re-solve that context and report conflicting hard constraints. During compiled skill execution, handle newly encountered world collisions through the game's execution policy; do not implicitly restart the authoring solver to invent a different attack.

# 8 Apply the shared controller to practical motions

## Reach and retract a held object

Use the completed grip transform and the existing endpoint controls. In a mode that permits translation, an outward object request moves the required hand pose outward. The body chooses the legal shoulder, elbow, forearm and wrist configuration that supports it.

| User action | Coordinated response |
| - | - |
| Move the object farther away | Extend and reposition the participating arm or arms while retaining each grip |
| Move it closer | Bend and reposition the arms while checking hand, object and body clearance |
| Change endpoint direction | Change object orientation under the roll policy; derive the resulting hand positions and orientations |
| Approach a wrist or forearm limit | Recruit useful legal motion elsewhere before a hard stop, while respecting the mode's pins |
| Move an unused offhand | Solve its own knuckle-frame request while retaining the equipped hand's required grip |
| Move a two-handed object | Solve both arms against the same candidate object pose and their separate handle zones |

For a fixed object pose and fixed grip, there is no independent palm-orientation guess to make: the required palm pose is already determined. The remaining choice concerns the body configuration that can support that pose.

## Use the same controls without a weapon

For a weaponless hand, the index knuckle takes the tip role and the pinky knuckle takes the pommel role. Their midpoint and palm-facing reference define the hand-sized control frame. A punch is one possible trajectory of those same controls; it is not a separate wrist-driven control system.

The unused offhand uses this same binding and remains available for posing. In two-handed grip mode it changes role: its target comes from its grip on the shared object until the hand is released or intentionally regripped.

## Sweep or circle the object

Use the requested endpoint trajectory and its orientation policy. The grip defines the corresponding hand path. Keep elbow, shoulder-girdle and permitted torso coordinates available within their anatomical profiles; only hold the contact in world space when the selected mode explicitly requires it.

As the object moves around the body, the coordinator uses legal shoulder direction, humeral rotation, forearm rotation, elbow bending and permitted girdle changes. In two-handed mode, evaluate the resulting targets for both hands throughout the sweep. Retain continuous elbow solutions and prepare for shrinking margins.

Repeated circles must not grant additional joint rotation. Validate each anatomical state against the same reference system. Repetition also need not produce precisely the same pose unless the task and posture policy require it.

If the exact route requires shoulder-socket translation or object roll that the rig or contract forbids, report that conflict. A variation of the route is allowed only within the stated path tolerance.

## Make body motion support the object trajectory

To make a swing look body-driven, coordinate the participating joints throughout the motion rather than waiting for visible arm failure and then correcting it. Use smooth pose changes, clearance anticipation and permitted shoulder or torso contribution while retaining the accepted endpoint path and grip.

Compilation knows the authored route and upcoming pose, so it can use lookahead to prepare legal shoulder, elbow and forearm configurations. For example, if an upcoming elbow bend reduces the permitted forearm rotation, begin a compatible redistribution before the bend reaches that boundary. Retain the specified tool path and grip throughout. Temporal smoothness and any selected speed or acceleration limits also apply; slowing the motion alone cannot fix a geometric conflict.

# 9 Compile a valid transition between the authored poses

## Separate path timing and body solution

The spline describes the requested spatial route. The timing or easing law determines progress along that route. The body solver finds the corresponding joint configurations.

Godot Tween interpolates values and supports method callbacks and controlled stepping. In a Tween-driven filler, this can advance progress or evaluate the interpolation law; anatomical constraints and IK remain responsibilities of the surrounding motion-generation code. [Godot Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)

If the implementation uses Curve3D, it supplies a sampleable Bézier path and a cache of curve points. That cache is not the compiled skeletal motion. Preserve the project's existing spline representation if it uses another implementation. [Godot Curve3D](https://docs.godotengine.org/en/stable/classes/class_curve3d.html)

Use one shared segment time to evaluate the relevant endpoint paths and orientation references. Independently interpolating tip and pommel can violate their fixed separation even when both endpoint poses are valid. Check compatibility with a rigid object pose throughout the segment. A path tangent also does not automatically specify blade-face orientation; retain the declared roll reference.

## Constrain the whole transition

Let z(t) be the participating body joint state, O(t) the object pose, H_i(z(t)) the forward-kinematic palm frame for attached hand i, and G_i its fixed grip transform. For every time in an attached interval:

```math
H_i(z(t))=O(t)G_i,\qquad
c_j(z(t),O(t))\geq 0
```

The functions c_j represent the configured anatomical and clearance restrictions. O(t) must also satisfy the authored endpoint trajectory and orientation policy. Independent offhand controls add their own time-varying targets. Grip attachments or releases change these equations only at the authored transition.

Preserve the accepted poses at the user-authored nodes, including their stored body configurations and explicit locks under the project's pose contract. Prefer continuity and useful joint reserve between those anchors. Do not substitute a different elbow or shoulder pose at B merely because it reaches the same weapon endpoints.

Both endpoints can satisfy every rule while an intermediate configuration fails. Check coupled shoulder, elbow, forearm and wrist limits across the entire transition. Also retain continuous angle branches, elbow-side continuity, grip agreement and any configured velocity or acceleration limits.

## Use the known future pose

A greedy solve that chooses the easiest next pose can enter a configuration that cannot connect to B. During compilation, consider the destination pose and the upcoming spline segment when selecting elbow placement, humeral rotation and forearm rotation.

Begin with the previous accepted state, use bounded steps and retry nearby connected configurations when needed. If a local pass stalls, use a bounded lookahead or segment optimization that can revise earlier intermediate poses while retaining the authored anchors. Validate the path to every alternative; never jump to a legal pose across an illegal transition.

The solver may change body coordination within its permitted degrees of freedom. It may not silently reroute the tool away from the user's spline, slide a fixed grip, relax anatomical limits or retime the skill. If no valid connection is found, identify the failing segment and constraint. Distinguish a search-budget failure from an established geometric conflict.

## Bake and validate the playback representation

Compile from a stable snapshot of the authored poses, splines, timing, grips and constraint profiles. Include every authored pose time, and use additional samples where curvature, coupled limits, orientation changes or clearance require them.

```text
compile_skill(authoring_snapshot):
    validate_authored_poses_and_rigid_path_contracts()
    timeline = build_shared_timeline()

    for segment in timeline:
        targets = evaluate_paths_timing_and_orientation(segment)
        motion = solve_connected_body_trajectory(
            targets,
            start_pose = segment.pose_A,
            end_pose = segment.pose_B,
            grip_and_hand_roles = segment.bindings,
            anatomy = constraint_profiles,
            lookahead = known_following_motion
        )

        if motion fails validation:
            report_segment_and_reason()
            return compilation_failed

        append_validated_motion_and_timestamps(motion)

    clip = encode_motion_with_skill_data()
    validate_the_actual_playback_interpolation(clip)
    save_validated_clip_to_skill_slot(clip)
```

This is an architectural contract, not a requirement to replace the existing compiler. Refine its current sampling and solve stages where necessary.

Validate the motion reconstructed by the saved representation, including interpolation between stored samples. Valid sample poses alone do not guarantee valid interpolated motion, especially for two-handed grips. Use adaptive checks, suitable swept collision tests or conservative error bounds. If encoding or compression changes the motion, include that change in validation.

If compilation fails, retain the editable source and the last valid compiled version rather than marking a partial motion as complete. Recompilation is needed when relevant poses, paths, timing, grips or constraint profiles change.

## Keep gameplay data on the compiled timeline

Save the solved object and body motion with the skill's associated data: timing, hand-role or grip transitions, hitbox and collision-volume bindings, damage parameters, activation windows and effect events. Use the project's declared root reference and existing data format.

Playback advances one skill clock. Motion, hitbox placement, active windows and effects follow that clock. Process events crossed during an update rather than relying on an exact frame landing on an event timestamp. Apply the existing collision-query policy to fast movement so contacts between playback samples are handled appropriately.

Damage parameters and attack windows can be compiled. Which target is actually hit, current collisions and the resulting gameplay outcomes are evaluated against the live game state. Replaying the motion does not remove those runtime responsibilities.

The saved asset is the generated skill data. Any Tween used to drive playback is a transient playback mechanism, not the persistent compiled result.

# 10 Build and inspect it in manageable steps

Use the same implementation for both arms with separate calibrated axis mappings, anatomical profiles and pose preferences. Mirror the anatomical meanings and preferred directions; do not assume that negating quaternion components provides the correct left-arm mapping.

| Step | Deliverable | Acceptance check |
| - | - | - |
| 1 | Calibrated hand and anatomical frames | Verify palm-side signs, rigid offsets and joint margins for both hands |
| 2 | Shared endpoint controller | Bind tool endpoints or index and pinky knuckles through the same control abstraction |
| 3 | Grip and hand-role bindings | Retain independent offhand controls and derive both attached hand targets from one object |
| 4 | Coordinated pose editing | Accept manually positioned poses without elbow flips, grip slip or disagreement between arms |
| 5 | Transition compiler | Follow the authored spline from the accepted A pose to the accepted B pose with continuous legality |
| 6 | Compiled skill execution | Replay validated motion with synchronized gameplay data without rerunning the authoring solve |

For pose editing, display requested and achieved endpoints, palm frames, grip errors, elbow bend planes, shoulder sockets and joint margins. For compilation, also identify the segment, sample time, upcoming constraint and deviation from the authored path or pose. Keep intentional grip contact excluded from collision rejection while retaining relevant hand-to-hand, limb-to-body and weapon-to-body checks.

Verify the pose-editing and grip cases first, then the compiled transitions:

1. Move a one-handed object outward and inward in a translation-capable mode; verify fixed grip offsets and legal reach.

2. Pose the unused offhand through its knuckle controls while the other hand remains equipped. Check any enabled torso motion against both hand tasks.

3. Engage two different handle zones, move the same endpoint pair and confirm that both grips follow one accepted object pose.

4. Bring one arm to a limit during two-handed movement. Reduce or stop the shared request without slipping, stretching or accepting an illegal pose.

5. Approach full extension, bend again and repeat object circles through lowered, overhead and behind-body regions without elbow flips or extra twist allowance. Show provisional shoulder regions.

6. Reverse a blocked relative drag and confirm immediate inward eligibility without target backlog. Preserve the fixed-contact rule only in its dedicated mode.

7. Repeat the controls with index and pinky endpoints on a weaponless hand, then repeat for the opposite hand and a rotated torso. Confirm palm-normal signs and orientation continuity.

8. Test impossible targets and grip-mode transitions. Distinguish anatomical restriction, collision, hard pins, conflicting endpoint geometry, unavailable rig motion and local solver failure.

9. Use legal A and B poses with an illegal middle portion of the spline. Compilation must identify the invalid portion rather than accept the skill based only on its endpoints.

10. Verify the saved playback reaches every authored pose, follows the intended trajectory and preserves both grips between samples. Include any encoding or interpolation error.

11. Compare motion, hitboxes, damage windows and effect timing on the same skill clock. Activating the compiled skill must not trigger a new authoring solve.

Use deterministic candidate ordering and stable tie-breaking. The same complete starting state, hand bindings, contract and input should produce the same result. Endpoint positions alone need not produce the same pose because roll state, hard pins, active grips and movement history can differ.

Log the authored segment and time, control contract, hand bindings and anatomical state when a case fails. A raw XYZW value cannot identify the failed relationship. Preserve enough source information to revise the pose or spline and recompile.

# 11 Integration with the existing guides

| Existing guide | Responsibility retained |
| - | - |
| [The Will Arm Rig Constraints and IK Implementation Guide](https://chatgpt.com/space/page_67bdd1d032a88191b108d3225cefcdc6) | Anatomical frames, elbow hinge, shoulder constraints and IK validity |
| [The Will Wrist and Hand Forearm Implementation Guide](https://chatgpt.com/space/page_402c58a864cc8191ad9d1d3e516075b1) | Two-axis wrist model, coupled wrist range and forearm ownership of pronation and supination |
| [The Will Weapon Motion Allocation and Joint Priority Guide](https://chatgpt.com/space/page_5c62f07130a88191bb39a0361e6f310f) | Dedicated tip-orbit, translation and roll contracts; directional saturation and reversal. The world-fixed contact applies to its pivot mode, not every endpoint request |
| [Shoulder and Forearm Rotation Limits for Josie](https://chatgpt.com/space/page_638167142af48191b988a78103d1d895) | Pose-dependent rotation allowances, effective shoulder accounting and provisional regions |

The coordination rules govern manual posing and generation of the complete motion between authored poses. Equipment geometry and grip roles change the constraints; the shared controls remain the same. Compilation turns a validated body trajectory and its gameplay data into the functional skill that the player activates.
