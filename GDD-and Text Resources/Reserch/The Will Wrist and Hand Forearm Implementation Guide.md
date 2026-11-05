This guide adds wrist and rigid-hand mobility to an already implemented arm system. The shoulder, elbow, reach solver, and forearm-rotation controller remain the upstream systems. Fingers are outside scope.

The central rule is: **measure wrist movement relative to the forearm's final distal orientation, including its accepted pronation or supination. Add two bounded wrist movements to that frame. Return any remaining target error to the existing controller.**

This is a companion to the [Arm Rig Constraints and IK Implementation Guide](https://chatgpt.com/space/page_67bdd1d032a88191b108d3225cefcdc6). Its names describe interface roles, not assumed names in the current project.

# 1 Separate wrist bending from forearm rotation

| Movement | What moves | Primary owner |
| - | - | - |
| Flexion | Palm bends toward the inner forearm | Wrist |
| Extension | Back of hand bends toward the outer forearm | Wrist |
| Radial deviation | Hand bends toward the thumb side | Wrist |
| Ulnar deviation | Hand bends toward the little-finger side | Wrist |
| Pronation and supination | Palm orientation turns with radius–ulna motion | Existing forearm controller |
| Circumduction | Hand direction traces a loop through combined wrist bends | Combination of the two wrist controls |

Use the hand as a rigid body connected through a two-degree-of-freedom wrist approximation. The real carpus contains multiple articulations with coupled motion; it is not literally two perfect hinges. The reduced model prevents an independent third wrist spin while retaining the major movement directions.

Active wrist-motion measurements show that flexion/extension and deviation interact: combined motion covers an asymmetric region, and moving away from neutral in one direction can reduce the available movement in the other. A pair of independent maximum-angle clamps does not express that relationship. [Active wrist coupling study](https://pubmed.ncbi.nlm.nih.gov/15621323/)

Mechanical testing of six cadaver wrists also found an oblique movement envelope, with a principal direction running from radial extension toward ulnar flexion. That supports a coupled envelope, not a requirement to force every motion along that diagonal. Passive mechanical limits and active functional limits are different measurements. [Mechanical wrist axes](https://pmc.ncbi.nlm.nih.gov/articles/PMC3016043/)

# 2 Define the connection to the existing arm system

The wrist module should receive:

```text
WristInput:
    wrist_center_world
    distal_forearm_rotation_world
    accepted_forearm_rotation_rad
    requested_hand_rotation_world
    optional_requested_grip_transform_world
    previous_accepted_wrist_angles
    current_collision_state
    pose_sample_id
```

The distal forearm frame must already include the **full accepted forearm rotation**. It is a kinematic reference, not necessarily the transform of the immediate parent bone.

A forearm twist-helper bone may carry only a fraction of the total roll. If its transform is used as the wrist reference, the wrist may incorrectly absorb the missing fraction. Conversely, adding pronation again after reading a fully rolled frame double-counts it.

Some rigs store forearm rotation on the hand bone or split it among helpers. Preserve that representation through an adapter: obtain the semantic distal forearm frame before calculating the two wrist bends, then compose the required imported-bone transform once.

Read all inputs from the same solve/update sample. Mixing this frame's hand target with last frame's forearm orientation creates apparent lag, overshoot, and changing local limits.

The wrist module produces an accepted hand pose, its two semantic angles, and target residuals. It must not independently rewrite the already accepted upper-arm or elbow pose.

# 3 Calibrate a hand frame and its neutral offset

Use right-handed orthonormal frames and column vectors. In `A B`, `B` acts first. Compute with radians; expose degrees only at the authoring interface.

At the wrist pivot, define:

- **+Y:** toward the middle-finger knuckle, along the third-metacarpal direction. This is a landmark for the rigid palm, not a finger control.

- **+Z:** toward the back of the hand, away from the palm surface.

- **+X:** `Y × Z`, across the palm.

Orthogonalize the measured dorsal direction against Y before constructing X, then recompute Z as `X × Y`. Verify determinant +1. Reject a reflected basis rather than treating it as a rotation.

With these axes:

| Semantic variable | Positive direction | Mathematical control |
| - | - | - |
| `beta` | Extension, toward the back of the hand | `R_x(beta)` |
| `gamma` | Radial deviation, toward the thumb | `R_z(s_r gamma)` |
| Independent axial wrist spin | Not provided by this model | No third scalar control |

`s_r` is +1 or −1, calibrated for each hand. A positive mathematical Z rotation initially moves +Y toward −X. Select `s_r` so the resulting movement goes toward the thumb. Do not assume both hands use the same sign.

Let `F0` be the distal forearm rotation and `H0` the hand anatomical rotation in the same known neutral-wrist calibration pose. Their fixed offset is:

```math
R_0=F_0^T H_0
```

At runtime the neutral hand frame carried by the forearm is:

```math
B=F R_0
```

Store `R0` once per calibrated rig/profile. Recomputing it from the current target would redefine neutral every frame and erase the meaning of the limits.

For imported hand-bone rotation `R_b0` and calibrated anatomical frame `H0`, store:

```math
A_H=R_{b0}^T H_0
```

Map an accepted anatomical hand rotation back to the imported bone:

```math
R_b=H A_H^T,\qquad
R_{\mathrm{local}}=R_{\mathrm{parent}}^T R_b
```

Use the actual imported parent transform in the last expression, including any intermediate helpers. The semantic forearm frame and the imported parent are not automatically the same frame.

These rotation equations assume a shared wrist pivot. If the hand bone origin differs from that pivot, calibrate a full rigid-transform offset and include its translation. Rotate the rigid hand about the wrist center rather than about an unrelated mesh origin.

# 4 Use two parameters instead of deleting a rotation component

One explicit forward model is:

```math
R_w(\beta,\gamma)=R_x(\beta)R_z(s_r\gamma)
```

```math
H=F R_0 R_w(\beta,\gamma)
```

The rotation order is part of the model. This equation uses deviation followed by extension about the reference X axis, under the column-vector convention. Swapping the product changes the resulting orientation. Either convention requires calibration and limits defined for that same convention.

For a requested anatomical hand rotation `Hd`:

```math
R_d=(F R_0)^T H_d
```

Fit `Rd` with the allowed two-parameter wrist model. Do not clamp world Euler angles or use the imported hand bone's raw Euler values as anatomical measurements.

## Why zeroing quaternion Y is wrong

Write `theta = s_r gamma`. The quaternion of `Rx(beta) Rz(theta)`, in **w, x, y, z** order, is:

```math
q=
\left(
\cos\frac{\beta}{2}\cos\frac{\theta}{2},
\sin\frac{\beta}{2}\cos\frac{\theta}{2},
-\sin\frac{\beta}{2}\sin\frac{\theta}{2},
\cos\frac{\beta}{2}\sin\frac{\theta}{2}
\right)
```

The Y component is generally nonzero. For `beta = 30°` and `theta = 20°`, it is approximately `−0.04494`, despite the model having only two controls.

That example demonstrates rotation composition, not acceptance under the starter envelope below. Whether its angles are allowed is a separate profile check.

**No independent wrist roll does not mean zero quaternion Y, zero Euler Y in every convention, or zero twist from every swing–twist decomposition.** Accept poses constructed by the chosen two-parameter model. Removing an axial component afterward changes that model.

If an arbitrary input rotation must be constrained, project it onto the permitted wrist model by fitting beta and gamma.

# 5 Bound the combination of the two movements

Define a permitted region `Omega` in the semantic `(beta, gamma)` plane.

For initial debugging, the following are deliberately restricted **game settings**, not a complete measured human envelope:

| Direction | Semantic endpoint |
| - | - |
| Flexion | `beta = −65°` |
| Extension | `beta = +60°` |
| Ulnar deviation | `gamma = −30°` |
| Radial deviation | `gamma = +15°` |

Healthy-subject measurements vary with the population and test posture. For example, a study of 30 young adults reported mean neutral-forearm wrist flexion of roughly 70–80° across its sex/side groups, and extension of roughly 66–76°. These values motivate scale, not universal hard stops. [Wrist and forearm ROM study](https://pmc.ncbi.nlm.nih.gov/articles/PMC6692155/)

## A simple coupled starter envelope

Let `B(beta)` be 60° for extension and 65° for flexion. Let `G(gamma)` be 15° for radial deviation and 30° for ulnar deviation. Use consistent units in:

```math
\left(\frac{\beta}{B(\beta)}\right)^2+
\left(\frac{\gamma}{G(\gamma)}\right)^2\leq1
```

This is an asymmetric, piecewise elliptical engineering approximation. It removes the simultaneous-maxima corners of a rectangular clamp. It does not reproduce the oblique anatomical envelope by itself.

For direct angle commands outside this envelope, a simple radial projection is:

```math
r=\sqrt{
\left(\frac{\beta}{B(\beta)}\right)^2+
\left(\frac{\gamma}{G(\gamma)}\right)^2
}
```

```math
(\beta',\gamma')=
\frac{(\beta,\gamma)}{\max(1,r)}
```

The requested pair `(+60°, +15°)` therefore becomes approximately `(+42.43°, +10.61°)`. This preserves direction in the parameter plane; it is not generally the closest orientation in rotation space.

For orientation targets, minimize orientation error over the envelope instead. For a more accurate profile, store a sampled circumduction boundary or a verified two-dimensional region that captures asymmetry and obliqueness.

Do not rotate a numerical ellipse by a published mechanical-axis angle and assume it has become a validated anatomical model. Match coordinate definitions, populations, loading conditions, and the complete boundary.

## Optional dependence on forearm rotation

The profile can later become `Omega(rho)`, where rho is the accepted upstream forearm rotation. Reading rho does not mean applying that rotation again.

Evidence depends on the measurement: the young-volunteer study found some active ROM differences with forearm position; controlled testing of six cadaver limbs found no overall significant change in passive ROM or principal-envelope orientation. A fixed authored envelope is a practical first stage. Add dependence on rho when supported by character calibration or suitable measured data. [Active measurements](https://pmc.ncbi.nlm.nih.gov/articles/PMC6692155/) · [Passive mechanical measurements](https://pmc.ncbi.nlm.nih.gov/articles/PMC4117694/)

Keep a preferred comfortable region inside the hard envelope. Preference may improve posture; it must not authorize crossing the hard boundary.

# 6 Fit a target and return what the wrist cannot supply

With a fixed forearm, the wrist has two controls. A general hand-orientation target has three rotational degrees of freedom. Some targets therefore cannot be reached by the wrist alone.

For example, requesting a pure axial turn while keeping the hand aligned with the forearm requires forearm rotation in this model. The wrist must not invent a third spin or force the palm into an unrelated bend to report success.

Use the geodesic orientation error:

```math
e_R(\beta,\gamma)=
2\arccos\left(
\operatorname{clamp}
\left(
\left|q_d\cdot q_w(\beta,\gamma)\right|,
0,1
\right)
\right)
```

Normalize the quaternions first. The absolute dot product treats q and −q as the same rotation.

Select the legal beta/gamma pair with the lowest task error, using continuity or a preferred posture to break close ties. Alternatively, use a weighted objective, but keep reporting the actual target error; a preference term can deliberately trade some accuracy for posture.

For this small search, use previous-state and neutral seeds plus a coarse set of legal candidates, followed by bounded refinement. Recheck the envelope and collisions after each candidate change. A failed local search means no solution was found within the search, not proof that none exists.

For an exact rotation already generated by the chosen model, the matrix entries provide:

```math
\beta=\operatorname{atan2}(-R_{yz},R_{zz}),\qquad
\gamma=s_r\operatorname{atan2}(-R_{xy},R_{xx})
```

The subscripts here mean **row, column** in the declared anatomical frame. These formulas are useful for round-trip tests and as seeds. For an arbitrary target, they are not a substitute for the constrained orientation fit. If an atan2 pair is degenerate, use a valid prior or neutral seed.

A compact result contract is:

```text
WristResult:
    status: ACCEPTED | APPROXIMATE | BLOCKED | INVALID_PROFILE
    beta_rad
    gamma_rad
    accepted_hand_transform_world
    orientation_error_rad
    residual_rotation_world
    grip_position_error_m
    active_limits
    pose_sample_id
```

`ACCEPTED` means the request is reached within declared tolerances; `APPROXIMATE` is a legal pose with remaining task error. `BLOCKED` means the search did not produce an acceptable candidate, not proof that no solution exists.

A full residual rotation is:

```math
R_{\mathrm{residual}}=H_d H_{\mathrm{accepted}}^T
```

This residual is expressed in world coordinates under the declared convention. It is a request for the existing controller to reconsider orientation allocation, not a command to apply that same rotation directly to the forearm.

A residual can result from an angular boundary, collision, insufficient forearm rotation, or a combination. Do not label every residual “missing pronation.”

# 7 Keep grip position consistent with wrist orientation

A hand bone, wrist pivot, palm center, and weapon grip marker are different reference points.

If `T_HG` maps the grip frame into the anatomical hand frame, then:

```math
T_{WG}=T_{WH}T_{HG}
```

For a requested grip pose:

```math
T_{WH}^{desired}=T_{WG}^{desired}(T_{HG})^{-1}
```

Apply any separate hand-origin-to-wrist-pivot offset before sending a wrist-center target upstream.

Changing wrist orientation can move the grip marker even when the wrist center stays fixed. A marker 5 cm perpendicular to a rotation axis moves 5 cm through space during a 60° rotation about that axis. Thus an orientation correction can break an otherwise correct grip position.

After accepting a legal wrist orientation, recompute the achieved grip pose. If the task requires a rigid grip, return the necessary wrist-center adjustment to the existing arm solver, then fit the wrist again against the newly solved forearm.

This is a bounded coupled iteration between existing arm solving and wrist fitting. It is not permission to translate the hand independently off the forearm.

For two-handed objects, use one accepted object pose and its two fixed grip offsets. If the two arms and wrists cannot satisfy it together, return the conflict to the object/pose controller.

# 8 Place the wrist stage in the update order

Use this sequence:

1. Resolve the requested hand or grip pose.

2. Obtain the accepted upstream arm state and semantic distal forearm frame.

3. Fit beta and gamma inside the wrist envelope.

4. Evaluate palm/hand and held-object collision, including the transition.

5. Recompute grip and orientation residuals.

6. If allowed, request a bounded upstream adjustment and repeat.

7. Commit the accepted hand bone transform through the rig adapter.

8. Run deformation/helper passes that preserve accepted kinematic anchors.

9. Verify the final pose after all writers.

A direct target-rotation copy after step 7 would bypass the wrist restrictions. Give the final hand transform one owner.

If palm collision requires a different wrist pose, search within the wrist envelope. If none is found, report blockage instead of rotating or translating the hand outside its rules.

Interpolation also requires validation. A smooth path between two legal poses can cross an obstacle. If a refined envelope is nonconvex, interpolation can leave that envelope as well.

The wrist constraint layer should not drive fingers. It may use a rigid hand/palm collision representation selected by the existing gameplay system.

# 9 Prevent double twist and deformation regressions

Keep the accepted forearm rotation, wrist bending, and visual twist distribution separate.

- The forearm system owns the accepted pronation/supination value.

- The wrist system owns beta and gamma relative to the fully rolled distal reference.

- The deformation system distributes already accepted motion over weighted helpers and corrective shapes.

If the hand bone carries forearm roll as part of the imported hierarchy, the adapter must compose both contributions before writing. A zero-roll rule applied to that raw bone can accidentally remove legitimate forearm motion.

Do not feed the wrist model's nonzero axial quaternion component into a forearm-roll accumulator. That component can arise from composing the two wrist bends; accumulating it each frame creates artificial twist.

A generic twist extraction from a bent hand can also contain wrist-composition effects. Drive forearm twist helpers from the authoritative forearm control, or validate the extractor against the complete declared wrist model.

When the forearm/hand transition collapses, inspect bones first. Legal bones plus a collapsing mesh indicate a deformation problem. Wrist limits do not by themselves fix skin weights, helper placement, or skinning collapse.

# 10 Test the wrist in isolation and in combination

| Test | Expected result |
| - | - |
| Neutral wrist through the full allowed forearm roll | Hand follows the forearm; beta and gamma remain zero |
| Extension/flexion sweep at fixed forearm | Rotation follows the calibrated X control; wrist center stays attached |
| Radial/ulnar sweep on both sides | Positive gamma bends toward each hand's thumb |
| Simultaneous endpoint request | Coupled envelope rejects or projects the corner |
| Combined-bend quaternion | Nonzero quaternion Y is retained when produced by a legal model pose |
| Pure axial hand target with fixed forearm | Residual remains unless upstream rotation changes |
| Rigid world rotation of the entire setup | Recovered wrist angles remain unchanged |
| Different helper-roll fractions | Semantic wrist angles remain unchanged |
| Grip offset under wrist bending | Achieved marker pose matches full-transform composition |
| Impossible grip | Explicit residual or blockage; no detached wrist |
| Collision between clear endpoint poses | Transition is rejected or replanned |
| Full modifier stack | No late writer restores the unconstrained target |

Use the same target recording with the hand mesh disabled and enabled. Log the forearm reference, wrist angles, requested and achieved hand transforms, residual, active limit, and writer/update phase.

A useful diagnostic pattern is:

| Symptom | First check |
| - | - |
| Neutral wrist bends when the forearm rolls | Wrong distal reference or double-counted roll |
| One side deviates away from the thumb | Radial sign or mirrored calibration |
| Single-axis poses work but combined bends fail | Rotation order or component-zeroing rule |
| Hand looks correct but weapon slips | Grip/pivot offset or wrist-center target |
| Restrictions work before the final frame | A later hand-orientation writer |
| Twist grows each frame | Composition residual fed back into forearm roll |
| Skeleton is correct but wrist surface caves in | Deformation weights and helpers |

# 11 Implementation handoff

Add a wrist controller to the existing arm system with the following contract:

1. Read the accepted wrist center and full distal forearm orientation from one coherent pose sample.

2. Calibrate the neutral hand offset, imported-bone mapping, dorsal/flexion axis, and per-hand radial sign.

3. Represent wrist motion by two scalar variables with a declared rotation order.

4. Enforce a coupled two-dimensional range, starting with an explicit authored profile.

5. Fit requested orientation and return remaining error instead of adding independent axial wrist spin.

6. Recompute grip offsets and negotiate required wrist-center or forearm changes through the existing controller.

7. Preserve the accepted hand pose through deformation and all later update stages.

8. Pass the isolated and combined tests before integrating unrestricted gameplay targets.

The current rig determines the bone mapping and where forearm roll is stored. The anatomical model does not require those representations to be changed; it requires their contributions to be explicit.

# Sources

- [Li et al. Coupling between wrist flexion-extension and radial-ulnar deviation](https://pubmed.ncbi.nlm.nih.gov/15621323/) — active coupled movement and an asymmetric motion envelope.

- [Crisco et al. The mechanical axes of the wrist](https://pmc.ncbi.nlm.nih.gov/articles/PMC3016043/) — passive mechanical envelope and its oblique direction.

- [Fan et al. Wrist ROM with forearm rotation](https://pmc.ncbi.nlm.nih.gov/articles/PMC6692155/) — active measurements across forearm postures in 30 young volunteers.

- [Kane et al. Effect of supination and pronation on wrist ROM](https://pmc.ncbi.nlm.nih.gov/articles/PMC4117694/) — passive cadaver measurements with different forearm orientations.

The rotation model, initial envelope numbers, module interfaces, and solver procedure are engineering choices. They are separate from the studies' measured findings.
