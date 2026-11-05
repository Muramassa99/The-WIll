This layer allocates weapon-control input across an already constrained arm. It uses the joint rules from the [arm guide](https://chatgpt.com/space/page_67bdd1d032a88191b108d3225cefcdc6) and [wrist guide](https://chatgpt.com/space/page_402c58a864cc8191ad9d1d3e516075b1), and adds the missing task priorities, directional saturation, reversal behavior, and persistent controller state.

**Tip control now pivots around the hand-contact control anchor. The pommel is not fixed during a tip swing.** Pommel dragging translates the complete weapon. Roll is a separate orientation command with an explicitly defined axis.

The desired behavior is a distal-first, saturation-aware movement policy: use available motion near the weapon, recruit additional joints when necessary, and restore distal priority when the input direction allows it. This is a gameplay policy applied to an anatomical model; it is not a claim that human muscles always exhaust one joint before using another.

The important distinction is between **preferred motion contribution** and **necessary compensation**. A proximal joint may need to compensate before the wrist reaches a limit in order to preserve the chosen pivot and grip.

# 1 Define the weapon and its control anchors

Use one rigid weapon transform and calibrated local offsets. Let:

| Symbol | Meaning |
| - | - |
| `C` | Hand-contact control anchor used as the tip pivot |
| `P` | Pommel point |
| `T` | Tip point |
| `W` | Anatomical wrist center |
| `R` | Weapon orientation in world space |
| `p, t, w` | Local offsets from C to P, T, and W |
| `L` | Distance between pommel and tip |

With the weapon coordinate origin at C:

```math
P=C+Rp,\qquad T=C+Rt,\qquad W=C+Rw
```

`w` comes from the rigid hand/weapon grip calibration. The wrist center and the hand-contact anchor are different points.

For a simple straight-axis grip, let `b` be the local unit blade direction and `a` the pommel-to-contact distance:

```math
p=-ab,\qquad t=(L-a)b,\qquad 0<a<L
```

This places the hand contact between pommel and tip. During tip control, the tip follows a sphere of **radius L−a**, centered at C. For general offsets, that radius is `norm(t)`. Weapon length is not that sphere's diameter.

Retain complete calibrated transforms for hand orientation and for off-axis offsets. Do not infer the wrist center by placing it directly on the grip anchor.

Two endpoint positions determine the weapon's position and direction but leave rotation around that direction unspecified. Keep an additional blade-up reference or roll state. Reconstructing orientation from tip and pommel plus a fixed world-up vector can cause flips.

# 2 Give each input mode an explicit contract

| Mode | Held constraint | Requested change | Consequence |
| - | - | - | - |
| Tip swing | C stays fixed | Weapon orientation changes | Tip and pommel orbit the contact anchor |
| Pommel translation | Weapon orientation stays fixed | P translates | C, T, W, and the weapon translate together |
| Roll | Selected roll-axis/pivot contract | Weapon rotates around its longitudinal direction | Forearm and arm cooperate to preserve the grip and pivot |

For the default roll configuration, hold C and rotate about the line through C parallel to the blade direction. If C lies on the weapon centerline, tip and pommel stay fixed during pure roll.

If C is off that centerline, rolling around C keeps C fixed but makes the centerline orbit. Rolling around the actual weapon centerline instead moves the off-axis contact point. Those are different valid controls. Configure the axis point explicitly; do not promise to hold both incompatible points fixed. The equations below use the fixed-C roll configuration.

Define the input reference frame: camera, world, chest, or another authored control frame. “Up” and “sideways” refer to that frame. They do not identify anatomical joint axes.

## Tip swing

For a small requested tip velocity `vT`, let `rhat = normalize(T−C)` and `ell = norm(T−C)`. Remove the radial part:

```math
v_{tan}=v_T-\hat r(\hat r\cdot v_T),\qquad
\omega_{swing}=\frac{\hat r\times v_{tan}}{\ell}
```

This is the angular command for rotation about C without instantaneous spin around the C-to-tip direction.

Update orientation with a rotation exponential or a normalized quaternion increment, then reconstruct all weapon points from the rigid transform. Do not linearly move the tip through the interior of the sphere or alter weapon length.

Transport the blade reference continuously as the tip direction changes. A shortest-arc transport needs an explicit fallback at an antipodal direction change. Subdivide large input changes rather than choosing an arbitrary 180° axis.

## Pommel translation

For an accepted displacement `delta_p`:

```math
P'=P+\delta_p,\quad C'=C+\delta_p,\quad T'=T+\delta_p,\quad R'=R
```

Do not preserve the old world-space contact anchor in this mode. That would conflict with whole-weapon translation.

## Roll

For blade direction `n = normalize(T−P)` and requested roll rate `psi_dot`:

```math
\omega_{roll}=\dot\psi\,n
```

This is a weapon-space task expressed in world coordinates. It is not a forearm joint-angle command. Forearm and weapon axes need not be aligned.

When combining channels, construct one coherent rigid-body command before solving. Do not let separate tip and pommel controllers write incompatible weapon poses in the same update.

# 3 Allow necessary compensation before a limit is reached

For any point X rigidly attached to the weapon:

```math
v_X=v_C+\omega\times(X-C)
```

In fixed-contact tip or roll control, `vC = 0`, so:

```math
v_W=\omega\times(W-C)
```

Unless W lies on the current rotation axis through C, the wrist center must move. The elbow and shoulder must provide that translation while the wrist contributes its preferred bend.

If the arm is frozen and only the wrist rotates:

```math
v_C=\omega_{wrist}\times(C-W)
```

That generally moves the supposedly fixed contact anchor. Moving the pivot from the pommel to the hand contact reduces the lever arm, but does not automatically make it zero.

Therefore use these operational rules:

- **Wrist first** means prefer wrist contribution while minimizing unnecessary proximal movement.

- **Elbow stationary on reversal** means hold it when the complete pivot/grip task remains feasible with that hold.

- If an exact hold makes the task infeasible, allow the smallest required compensation.

- Never preserve a cosmetic joint freeze by drifting the pivot, breaking the grip, stretching the arm, or violating another anatomical limit.

This distinction matters even away from limits. In a fully constrained planar three-joint example, fixing the contact position and weapon orientation can determine all three joint angles. There is then no remaining freedom to demand an independently stationary elbow. A human-like 3D arm has more freedom, but that freedom still depends on the pose and active constraints.

# 4 Use mode-specific motion priorities

The following are configurable default preferences. They are not hard locks on all later joints.

| Mode | Preferred contribution order | Required compensation |
| - | - | - |
| Tip swing | Wrist bends → useful elbow flexion → useful forearm rotation → shoulder rotation → permitted shoulder girdle → permitted torso | Maintain fixed C, grip, and the requested orientation path |
| Roll | Forearm pronation/supination → humeral axial rotation → permitted girdle/torso assistance | Wrist bends, elbow, and shoulder swing preserve the pivot and blade direction |
| Pommel translation | Elbow flexion and shoulder swing as a coordinated positioning group → permitted girdle → permitted torso | Forearm rotation and wrist bends maintain weapon orientation |

For tip swing, both wrist controls belong to one coupled group. A world-vertical command can require flexion, deviation, or both, depending on forearm orientation.

Elbow flexion has one anatomical axis. It cannot become elbow yaw to satisfy a sideways request. Prefer it only when the current geometry allows a useful contribution. If it is ineffective, constrained, or singular for the requested task, continue to another useful component.

For pommel translation, wrist-only motion cannot generally produce pure weapon translation while preserving weapon orientation. Begin with the arm-positioning group and let the wrist compensate. Do not force the tip-control priority order onto this different task.

For roll, an independent wrist-roll degree of freedom does not exist in the chosen wrist model. Start with the accepted forearm-rotation control. When the wrist is bent, even forearm roll can require other joints to preserve the weapon axis.

Expose girdle and torso movement only when the existing rig provides those degrees of freedom and the runtime profile authorizes them. If they are unavailable, reaching the remaining chain's feasible boundary is a legitimate stop.

## Test usefulness in the current pose

A joint's anatomical name does not prove it can move the weapon in the requested direction while preserving the anchors.

Evaluate its effect through the current forward kinematics and constrained Jacobian. A raw axis-dot-input test can be a cheap hint, but it does not account for fixed-contact compensation, coupled limits, or collision.

For a mode, recompute priorities against the current pose on every input increment. Use stable ordering within equal-priority groups so replay is predictable. Do not permanently mark the elbow or wrist as the owner of a movement after one successful frame.

# 5 Treat saturation as directional

At an upper scalar bound, outward motion is forbidden and inward motion is available:

```math
q_i=q_{i,\max}\quad\Rightarrow\quad \dot q_i\leq0
```

At a lower bound:

```math
q_i=q_{i,\min}\quad\Rightarrow\quad \dot q_i\geq0
```

A joint at its maximum is not disabled. It is blocked only in the direction that would violate its current constraints.

For a coupled limit `f(q) ≤ 0`, the local boundary condition is:

```math
\nabla f(q)^T\Delta q\leq-f(q)
```

At the boundary this allows tangent and inward motion while excluding outward motion. Include every parameter on which f depends. For example, if the wrist envelope depends on forearm rotation, changing that rotation can change wrist legality even when the two wrist angles are unchanged.

For the wrist envelope from the wrist guide, availability is a region of beta/gamma movement, not two independent “maximum reached” booleans. A diagonal request may be blocked while another direction remains available.

A component may require help because of:

- Anatomical range or a coupled-envelope boundary.

- Velocity or acceleration capacity.

- Collision or a blocked transition.

- Insufficient leverage or a kinematic singularity.

- A fixed-pivot, orientation, or second-grip constraint.

Recruit the next useful component for any of these reasons. Waiting only for a scalar angle to equal its hard endpoint misses several real limits.

# 6 Preserve the requested reversal behavior

Use the previous **accepted joint state** as the hold reference for each new increment. Do not use the original neutral/rest pose as the return target.

The controller behavior is:

1. Evaluate the new requested direction.

2. Recompute which joint motions are currently feasible.

3. Restore the normal distal-first priority order.

4. Hold proximal joints at their current state where feasible.

5. Let distal joints move inward from their old boundary immediately.

6. Recruit proximal contribution again only when required by geometry, limits, or the requested rate.

Do not unwind the elbow simply because the wrist begins moving back. That would implement a return-to-neutral controller, which is a different behavior.

The following scalar example illustrates the policy only; its values are abstract control units, not anatomical angles or an arm kinematic model. The distal variable has bounds −1 to +1.

| Input increment | Distal state | Proximal state | Result |
| - | -: | -: | - |
| Start | 0 | 0 | Neutral example state |
| +1.5 | +1 | +0.5 | Distal range used first; remainder goes proximal |
| −0.25 | +0.75 | +0.5 | Reversal immediately returns to distal motion |
| −2 | −1 | +0.25 | Distal reaches the opposite bound; remaining input goes proximal |

The real solver applies this preference in weapon task space while preserving the pivot and grip. It must not add the numerical angle excess from one joint directly to another joint angle.

## Prevent input accumulation beyond a blocked limit

For relative mouse/stick increments, update the controller's target from the **accepted** weapon motion. Do not accumulate rejected motion into an unreachable hidden target.

Otherwise a user can push against a limit, reverse input, and see no response while the controller spends several frames cancelling the stored excess. That looks like a failure to return control to the wrist.

Record requested and accepted increments separately. Discard or explicitly report the unaccepted part under the relative-input policy. Do not carry it forward as an implicit backlog.

An absolute target supplied by another system is a different interface: keep the target and report tracking error, or use a declared target-rebasing policy. Do not silently reinterpret an absolute target as relative input.

## Smooth handoff without sticky reversal

Use a small numerical activation tolerance and smooth velocity transitions. Hysteresis can stabilize stage labels and candidate selection, but must not prevent a newly inward wrist command from becoming eligible.

“Immediate return of priority” does not mean an instantaneous velocity jump. Enforced acceleration limits can require a short deceleration transition. Predict stopping distance or use a viable braking envelope so acceleration and range constraints do not become contradictory at the last instant.

During a sharp reversal, the feasible velocity may initially still point in the old direction while braking. Run an explicit `BRAKING` phase or a feasible command-shaping stage; do not require every transitional velocity to be a nonnegative multiple of the new raw input. The anatomical and anchor constraints still hold. Report requested, shaped, and accepted motion separately.

When input stops, hold the accepted configuration. Do not keep moving toward an old rejected target or automatically recenter proximal joints. If the body or environment moves, compensation may still be necessary to preserve the selected world-space anchor.

# 7 Solve one task with hard constraints and ordered preferences

A suitable foundation is constrained differential IK with a hierarchy of tasks or optimization objectives. Hierarchical QP methods handle equality and inequality constraints while protecting higher-priority tasks. [Kanoun 2011](https://www.roboticsproceedings.org/rss07/p21.html)

The SNS family also addresses hard joint constraints, saturation, and scaling infeasible task commands. Those are useful implementation references; ordinary unconstrained IK followed by clipping does not provide the same behavior. [Flacco, De Luca, and Khatib](https://iris.uniroma1.it/handle/11573/780461)

There are two different hierarchies:

| Hierarchy | Purpose |
| - | - |
| Task/constraint hierarchy | Protect anatomy, contact, pivot, collision, and commanded mode |
| Joint-use preference | Decide which legal combination of joints performs the task |

“Wrist priority” never outranks the rigid grip or anatomical constraints.

## Level 0 Protect invariants

Require the calibrated grip relation, fixed bone lengths, anatomical profiles, collision policy, and the mode's held anchor/orientation. Weapon length is already preserved by the rigid-transform representation.

For two hands, solve both arms against one shared weapon pose and their fixed grip transforms. In tip mode, only the selected control anchor is pinned in world space; the other contact follows the rotating weapon. Pinning both contacts in world space would usually prevent the requested swing.

## Level 1 Preserve the requested movement as far as feasible

Let s scale this increment's task-velocity reference, with `0 ≤ s ≤ 1`. Use the raw requested velocity when feasible to do so; use the explicitly shaped reference during a braking transition. Maximize s subject to the hard constraints and all authorized joint capabilities.

Use a common s for the components of one intended movement when preserving its direction/path is required. Independent per-axis clipping can turn an upward command into a sideways motion.

If the whole allowed chain cannot continue, accept a smaller increment or stop with a specific reason. Continuation is required when a legal solution is found; it cannot be promised beyond the actual feasible workspace.

## Level 2 Minimize unnecessary movement of later components

Among solutions with the same accepted task progress, minimize changes in the later, less-preferred joint groups first.

For tip control, a representative minimization order is:

```text
torso change
then shoulder-girdle change
then shoulder rotation change
then forearm-rotation change
then elbow-flexion change
then a wrist continuity/tie-breaking objective
```

This reverses the preferred-use list intentionally: minimizing proximal change first leaves distal freedom available to perform the task.

For roll, minimize later axial contributors before preferring forearm rotation, while allowing the non-axial compensation required by the pivot and grip. For pommel translation, use the positioning-group policy rather than a wrist-first policy.

Measure change from the previous accepted state and normalize mixed units/ranges appropriately. Do not add a neutral-posture objective that silently undoes the user's requested memory of proximal positioning.

Use true ordered optimization if strict priorities are required. Finite numerical weights give trade-offs and can allow a lower-priority objective to influence a higher-priority one.

All authorized joints remain available for necessary compensation. Freezing entire proximal tiers until the wrist reaches a limit can make the fixed-contact task infeasible before any wrist limit is reached.

# 8 Build the differential tasks from the actual geometry

Let q be the semantic joint state from the existing anatomical model. Compute current world-space Jacobians for contact C, pommel P, and weapon angular velocity:

```math
v_C=J_C(q)\dot q,\qquad
v_P=J_P(q)\dot q,\qquad
\omega=J_\omega(q)\dot q
```

A Jacobian maps joint rates to task velocity and changes with configuration. That is why a useful elbow contribution in one pose can be ineffective in another. [Modern Robotics](https://modernrobotics.northwestern.edu/nu-gm-book-resource/5-1-1-space-jacobian/)

For a revolute joint i with world axis `ai` and origin `oi`, the point-velocity column at X is:

```math
J_{X,i}=a_i\times(X-o_i)
```

The angular-velocity column is `ai`. For coupled semantic parameterizations, differentiate their complete forward kinematics; do not pretend quaternion components are independent hinge joints. Finite differences are useful for verifying an analytic Jacobian.

The mode equations, at a valid anchor state, are:

| Mode | Held part | Scaled requested part |
| - | - | - |
| Tip swing | `J_C qdot = 0` | `J_omega qdot = s omega_swing` |
| Pommel translation | `J_omega qdot = 0` | `J_P qdot = s v_P_requested` |
| Fixed-contact roll | `J_C qdot = 0` | `J_omega qdot = s psi_dot n` |

This uses full angular commands, so an undeclared extra roll cannot be introduced to hide an error. The tip command's roll behavior is supplied by its continuous reference transport.

If the anchor already has small numerical error, include a bounded corrective term toward the captured anchor. A zero-velocity equation alone only preserves existing drift. Large inconsistency or an invalid starting pose requires recovery, not an unbounded correction.

With moving torso/root animation, include its known contribution to point and angular velocity on the right-hand side, or include its permitted coordinates in q. A frozen-base Jacobian cannot compensate for a base that moves outside the solve.

## Bounds for one small step

For a scalar joint with timestep dt, a position/velocity-bound interval is:

```math
\max\left(-v_{i,\max},\frac{q_{i,\min}-q_i}{dt}\right)
\leq\dot q_i\leq
\min\left(v_{i,\max},\frac{q_{i,\max}-q_i}{dt}\right)
```

Intersect with the previous velocity plus/minus the allowed acceleration times dt when acceleration is enforced. Detect an empty interval rather than silently dropping a hard bound. Use anticipatory braking so the controller stays in a state from which it can stop legally.

Include linearized coupled-angle and clearance constraints in the local solve. Recompute them after accepted changes, particularly when shoulder or wrist envelopes depend on other joint parameters.

## Finite motion still needs validation

A differential solution is locally correct. Integrating it over a large step can drift the pivot, violate a curved joint boundary, or cross an obstacle.

Subdivide, recompute forward kinematics, enforce the nonlinear anchor/grip constraints, and validate the whole pose and transition. If validation fails, reduce the requested increment and solve again. Do not simply scale the joint vector and assume an exact fixed pivot remains exact.

Keep damping, step limits, rank thresholds, collision margins, and iteration budgets configurable and tied to the character's scale. A damped pseudoinverse alone is not a hard-constraint solver.

# 9 Implement the allocator as a separate module

The new module sits above the existing arm/wrist legality functions and owns acceptance of the complete weapon pose.

```text
MotionAllocatorInput:
    mode
    input_frame
    requested_increment_or_velocity
    previous_accepted_joint_state
    previous_accepted_weapon_transform
    current_body_and_collision_state
    grip_transforms
    mode_anchor_snapshot
    anatomy_profiles
    runtime_motion_policy
```

```text
MotionAllocatorResult:
    accepted_joint_state
    accepted_weapon_transform
    requested_task_increment
    shaped_task_reference
    accepted_task_increment
    task_scale
    pivot_error
    grip_errors
    active_limits
    contributing_joint_groups
    stage_reason
    remaining_task_error
    status
```

Useful stage reasons include `JOINT_RANGE`, `COUPLED_LIMIT`, `RATE_LIMIT`, `COLLISION`, `SINGULARITY`, and `ANCHOR_COMPENSATION`. A moving elbow does not automatically mean the wrist saturated.

Useful statuses include `ACCEPTED`, `SCALED`, `BRAKING`, `BLOCKED`, `SEARCH_EXHAUSTED`, `INVALID_PROFILE`, and `RECOVERY_REQUIRED`. Distinguish a local search failure from proof that a target is impossible.

## Runtime policy

```text
MotionPolicy:
    enabled_joint_groups
    preferred_use_order_by_mode
    within_group_preferences
    compensation_motion_limits
    tip_input_frame
    roll_axis_point_and_direction
    pivot_and_grip_tolerances
    relative_or_absolute_input_policy
    velocity_acceleration_and_step_limits
    collision_policy
    singularity_thresholds
    stage_hysteresis_for_reporting
    maximum_iterations_and_substeps
    allow_command_driven_nullspace_repositioning
    allow_idle_recentering = false
```

Anatomical limits stay separate from controller preferences. Runtime changes to the chain of command must not silently enlarge those limits.

## Update loop

```text
on_control_update(input, current_scene, dt):
    state = read_one_coherent_accepted_state()
    policy = select_mode_policy(input.mode)
    command = resolve_rigid_weapon_command(input, state, policy)

    for substep in split_command_if_needed(command, dt):
        recompute_joint_geometry_and_constraints(state)

        # All authorized compensation is available.
        # Higher-numbered tiers are preferences, not blanket locks.
        task = build_mode_task(substep, state, policy)
        solution = maximize_feasible_task_progress(task, constraints)

        if task_progress_is_zero_and_repositioning_is_enabled():
            attempt_bounded_pose_change_at_fixed_weapon_pose()
            recompute_constraints_and_resolve_task()

        if solution.exists:
            solution = apply_ordered_joint_use_preferences(
                solution, reference=state, policy=policy
            )

        if no_solution_or_finite_step_invalid(solution):
            retry_with_smaller_task_increment_or_return_failure()
            continue_or_exit_without_committing_invalid_pose()

        state = accept_verified_complete_pose(solution)
        update_directional_limit_state(state)
        record_requested_and_accepted_progress()

    commit_joint_pose_and_weapon_pose_together(state)
    apply_deformation_without_changing_accepted_anchors()
    verify_final_pose_after_all_writers()
```

The old arm and wrist solvers may remain candidate generators and constraint evaluators. A single-pass “arm result, then wrist clamp, then stop weapon” pipeline cannot provide the requested continuation. Feed the wrist's boundary back into whole-task allocation before committing.

Never overwrite the accepted weapon orientation with the raw tip target after the constrained solve. That would reintroduce grip mismatch or illegal hand rotation.

# 10 Handle transitions and difficult configurations

## Changing the pivot to the contact anchor

Switch the pivot mapping atomically. Keep the current accepted weapon pose, compute the new contact anchor from that pose, and capture its world position as the new fixed anchor.

Do not reuse the old pommel anchor's world position as the new hand-contact position. That would teleport or reorient the weapon.

Recompute local weapon/grip/wrist offsets and validate the current pose. The first zero-input frame after the switch should have no discontinuity.

## Changing modes

When entering tip mode, capture C from the accepted pose. When entering pommel mode, capture the orientation to hold. When entering roll mode, capture its configured axis/pivot reference.

Preserve the accepted joint state. Do not reset elbow, shoulder, or wrist toward neutral during a mode change.

## Changing movement direction

Recompute availability from the new command. A component blocked in one direction can become the preferred component immediately in the other. Stage-reporting hysteresis must not latch it out.

## Singular or trapped configurations

At straight-arm or other singular poses, some task directions can have negligible instantaneous leverage. Another legal joint combination or permitted posture adjustment may restore it.

If enabled, a bounded null-space repositioning step may change the arm while preserving the accepted weapon pose, to prepare for the current command. It must preserve anatomical/collision constraints and must not run as an idle neutral-return behavior.

A local controller cannot guarantee escape from every nonconvex or disconnected feasible region. Use a declared bounded recovery search when necessary, then return a clear failure. Do not escape by breaking the pivot or crossing an illegal pose.

External animation, a changed grip, or a moving obstacle can make previously compatible hard constraints contradictory. Return `RECOVERY_REQUIRED` so the gameplay authority can reject/pause the conflicting motion or invoke an explicitly configured release/re-anchor policy. The allocator cannot guarantee all constraints when their feasible intersection is empty.

## Deterministic behavior

Use a stable joint-group order, consistent timestep policy, previous accepted state, fixed tie-breaks, and bounded iteration strategy. Define what happens after a teleport or a large target jump.

Because proximal state is retained, the same weapon pose can have different arm configurations after different input histories. That is expected for this control policy. Predictability means the same initial state, inputs, and policy reproduce the same behavior.

# 11 Verify the exact behaviors being requested

| Test | Pass condition |
| - | - |
| Small tip swing away from limits | Wrist is preferred; only necessary proximal compensation occurs; C remains fixed |
| Continue at wrist extension boundary | Legal chain motion continues when found; wrist never exceeds its envelope |
| Reverse after proximal engagement | Wrist becomes eligible immediately; proximal state is retained where feasible |
| Reach the opposite wrist boundary | Further input recruits useful additional components again |
| Sideways input at different forearm orientations | Actual joint contribution is recomputed; no invented elbow sideways axis |
| Pommel translation | Whole weapon translates; orientation is preserved; old contact anchor is not pinned |
| Roll with straight and bent wrists | Forearm rotation is preferred; compensating motion preserves the selected roll contract |
| Neutral wrist with forearm roll | No double-counting of forearm rotation |
| Large repeated blocked input followed by reversal | No hidden-target backlog delays the reverse response |
| Input released after a staged movement | No automatic proximal unwinding |
| Pivot changed from pommel to contact | No zero-input jump; new anchor uses its own current world location |
| Entire chain at a feasible boundary | Controlled scaling or stop, with a specific reason |
| Curved joint boundary or collision transition | Final pose and path are checked after integration |
| Two-hand weapon when used | Both grip transforms agree with the same accepted weapon pose |
| Full update stack | No later module restores the raw unconstrained target |

Log the requested and accepted weapon increments, C/P/T/W positions, orientation, pivot/grip errors, signed joint parameters, active constraint normals, task scale, and every contributing joint group.

For reversal tests, distinguish:

- An inward wrist command becoming available.

- Actual wrist velocity after acceleration limits.

- Proximal compensation required to hold the pivot.

- Unwanted proximal return toward an old pose.

These are different measurements and should not be collapsed into one “current owner” flag.

# 12 Implementation handoff

Build a stateful weapon-task allocator with fixed-contact tip control, whole-weapon pommel translation, and a declared axial-roll mode.

1. Integrate the new contact pivot and complete grip/wrist offsets.

2. Build rigid weapon commands before assigning motion to joints.

3. Reuse the implemented anatomy and wrist envelopes as hard constraints.

4. Add current-pose Jacobians and a constrained task-progress solve.

5. Apply mode-specific distal/proximal preferences while permitting necessary compensation.

6. Track directional saturation and release inward motion immediately.

7. Preserve proximal state on reversal; disable automatic idle recentering.

8. Prevent relative-input windup beyond accepted movement.

9. Validate finite poses, transitions, anchors, and grip agreement before committing.

10. Expose runtime policy data separately from the anatomical profiles and run the acceptance tests.

**The implementation rule is to constrain how each joint may move while solving for continued legal weapon motion across the whole available chain.** A local wrist boundary becomes a redistribution condition; a whole-chain infeasibility becomes an explicit stop.

# Technical references

- [Flacco, De Luca, and Khatib. Control of Redundant Robots Under Hard Joint Constraints](https://iris.uniroma1.it/handle/11573/780461) — saturation-aware differential control and task scaling.

- [Kanoun. Real-time prioritized kinematic control under inequality constraints](https://www.roboticsproceedings.org/rss07/p21.html) — prioritized control with hard inequality constraints.

- [Lynch and Park. Space Jacobian](https://modernrobotics.northwestern.edu/nu-gm-book-resource/5-1-1-space-jacobian/) — joint-rate contributions to rigid-body motion.

- [The Will Arm Rig Constraints and IK Implementation Guide](https://chatgpt.com/space/page_67bdd1d032a88191b108d3225cefcdc6) — the existing anatomical arm model.

- [The Will Wrist and Hand Forearm Implementation Guide](https://chatgpt.com/space/page_402c58a864cc8191ad9d1d3e516075b1) — the existing wrist model and grip-frame mapping.

The mode contracts, preferred joint orders, state-retention behavior, and interface schemas are the proposed game-controller design. The cited robotics methods provide foundations for handling redundancy, priorities, and saturation; they do not prescribe this exact gameplay policy.
