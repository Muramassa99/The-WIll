Josie’s shoulder can be bounded using the angle of the **upper arm relative to the chest**. Forearm rotation has a separate limit **relative to the bent elbow**, and the wrist supplies two bends. Apply these limits together at each accepted arm pose. This gives each hand a finite amount of turn from its current posture, including when the sword is held upright at full reach.

# 1 Assign each rotation to a joint

| Component | Allowed movement | What sets its limit |
| - | - | - |
| Shoulder and upper arm | Aim the upper arm and turn it around its own shaft. Internal rotation turns the upper arm inward. External rotation turns it outward. | The internal and external endpoints depend on the upper arm’s direction relative to the chest. |
| Elbow | Flex or extend around the calibrated hinge. The existing guide starts at 0° straight and ends at 145° flexion. | Independent roll at the elbow hinge is 0°. Humeral turn carries the hinge and changes the plane in which the elbow bends. |
| Forearm | Pronate to turn the palm down from a thumb-up test pose, or supinate to turn it up. | One signed rotation about the forearm after the hinge. Its two endpoints change with elbow bend. |
| Wrist and hand | Flex, extend, and bend toward the thumb or little finger. | Use the existing coupled wrist envelope. Independent axial wrist spin is 0°. The hand inherits all accepted forearm turn. |
| Twist helpers, where present | Distribute an accepted rotation over the skin. | Their combined effect must reproduce the accepted hand pose. They supply 0° of extra joint travel. |

On Josie, shoulder internal or external rotation **is the upper arm turning in its socket**. Count that turn once. With no shoulder-blade bone, the chest-to-upper-arm measurement represents the combined shoulder complex. If an existing clavicle is animated, measure the upper arm after composing that clavicle with the upper-arm transform. Both motions then count inside the same shoulder envelope. Keep an animated clavicle inside its own existing local limits too. If those limits are unavailable, hold it at the accepted pose for this control. A fixed shoulder center approximates reach when the real shoulder blade would translate the socket.

# 2 Bound forearm rotation by elbow bend

Use `a` for elbow bend and `p` for anatomical forearm turn. Set `p = 0` at a calibrated thumb-up forearm neutral, positive toward pronation, negative toward supination. Carry that reference through elbow flexion. The legal interval is `−S(a) ≤ p ≤ P(a)`.

In the arm guide’s calibrated virtual frames, build the untwisted forearm from the accepted upper arm followed by its current elbow hinge. Then compose the local forearm turn once. With `s_P` equal to the side’s sign for pronation, the distal orientation is `R_distal = R_upper · Rx(a) · Ry(s_P p)`. Use the existing bind and carrying-angle offsets when mapping to Josie’s bones. If the upper arm turns 20° with the elbow and forearm coordinates held, the hand inherits that movement and the measured value of `p` stays the same.

| Elbow bend | Supination endpoint | Pronation endpoint |
| - | -: | -: |
| 0° straight | −39° | +109° |
| 45° | −73° | +96° |
| 90° | −85° | +80° |
| 145° model full flexion | −95° | +54° |

**These are proposed rig settings for both arms.** They preserve the earlier guide’s 85° supination and 80° pronation at 90° elbow bend. To get the other rows, scale each direction separately by its measured ratio to the 90° value in Shaaban’s right-forearm series, round to whole degrees, and map the study’s full-flexion sample to Josie’s configured full bend. The measured trend is more pronation toward extension and more supination toward flexion. A separate study of 352 adults found 80° mean active pronation and 87° supination in the dominant arm. [Shaaban et al., Table 2](https://journals.sagepub.com/doi/10.1177/1753193407087862) · [Zwerus et al.](https://journals.sagepub.com/doi/10.1177/1758573217728711)

Interpolate each endpoint linearly between adjacent bend samples. If Josie has a deliberately tighter validated interval, intersect it with this profile. Recheck the interval when **either** the elbow bend **or** the forearm turn changes.

For example, at 90° elbow bend, +75° pronation fits. Bending to 145° reduces the upper endpoint to +54°. The forearm must give back at least 21° of pronation during the bend. If the grip or a collision prevents that movement, the accepted elbow bend must stop earlier. Solve those two coordinates together so the hand stays on the handle.

# 3 Bound shoulder rotation in the chest frame

Use `h` for humeral turn, positive toward internal rotation and negative toward external rotation. Select its limits using **where the upper arm points**. The sword example uses the **forward** row because the shoulder-to-elbow line points forward at shoulder height.

| Upper arm direction | External endpoint | Internal endpoint |
| - | -: | -: |
| Forward at shoulder height | −113° | +41° |
| At shoulder height, about 30–35° forward of directly sideways | −103° | +65° |
| Directly sideways at shoulder height | −107° | +73° |
| Down by the torso | −67° | Forearm contacted the torso in this protocol. A paired reference for this pose appears below. |

These are mean **active upper-arm rotations relative to the torso** from 16 adults, measured with the elbow bent 90° and forearm approximately horizontal at the study’s zero. In the forward position the between-person standard deviations were 11° external and 14° internal. Use the rows as reference samples for Josie’s combined shoulder envelope. Using these bent-elbow measurements as shoulder reference samples for a straight-elbow pose is a rig approximation. The sword grip has its own starting position within an interval. [McCully et al., methods and Table I](https://biomechanics.uoregon.edu/obl/articles/2005_mccully_jses.pdf)

**Put the endpoints into Josie’s frame before using them.**

1. On each side, pose the upper arm in the sample direction. Bend the elbow to 90° so the hinge and forearm give a visible pointer. Reproduce the reference posture with a horizontal forearm on the anatomically corresponding branch. Record the upper-arm orientation relative to the chest and its transverse hinge axis as the zero for that direction.

2. Calibrate the sign independently on each arm. With the upper arm by the side, elbow bent and forearm pointing forward, a small internal shoulder rotation moves the forearm toward the abdomen. With the upper arm held steady in that pose, a small pronation turns the palm from inward toward the floor. Assign the two signs separately. Share anatomical limits between mirrored sides and use each side’s imported bone offsets.

3. At any sampled direction, let `u` point along the upper arm. Let `x₀` be its transverse hinge axis at the calibrated zero and `x` the current transverse hinge axis. Express all three in chest coordinates. With normalized transverse vectors perpendicular to `u`, calculate the signed angle in radians with the expression below.

```math
h=s_H\,\operatorname{atan2}\!\left(u\cdot(x_0\times x),\;x_0\cdot x\right)
```

Here `s_H` is the calibrated sign for internal rotation. Use the continuous angle branch around the previous accepted value. If the asset uses a different zero, record where its zero lies in the measurement frame and subtract that offset from **both** tabulated endpoints. Retain the hinge reference when straightening the elbow. In full extension, the shoulder, elbow and wrist centers lie on a line and cannot identify how much turn belongs to the humerus.

Store an anatomical zero and two finite endpoints for each covered upper-arm direction. Interpolate reference frames in the same anatomical convention, then verify the motion between samples. During a first implementation, uncovered poses can be edited using the provisional rules below. Shoulder rotation changes with the plane and height of the arm. [Humphries et al.](https://pubmed.ncbi.nlm.nih.gov/26410346/)

## Lowered overhead and behind the body

Select the pose from the **shoulder-to-elbow direction relative to the chest**. A hand can reach behind the back through several combinations of shoulder, elbow and forearm movement. Measure elevation from the arm hanging down. At 90° the upper arm is horizontal, and at 180° it points straight up.

**Arm hanging by the side.** A second study provides both endpoints for this position. At a mean of 2° abduction, Sahara and colleagues reported **65.1° external and 66.9° internal** rotation of the upper arm relative to the torso. In this guide’s sign convention that gives a reference pair of **[−65.1°, +66.9°]**. Map the study’s neutral to Josie before using that pair. Use both values from the same protocol. A bent forearm contacting the abdomen, or a sword contacting the thigh, can stop the actual gesture earlier. An arm angled forward or behind the hip needs its own direction sample as it moves away from the hanging pose. [Sahara et al., results](https://www.sciencedirect.com/science/article/abs/pii/S0949265820300105)

**Arm above shoulder height.** During axial rotation at several tested arm abduction angles, the external endpoint averaged **105.7° external** at the nominal 135° abduction pose and **115.0° external** at the subjects’ maximum abduction, averaging 161.4°. The *entire interval* narrowed beyond shoulder height and shifted toward external rotation in that measurement frame. The more outward endpoint can therefore coexist with **less total turn**. Use those figures to check the outward endpoint on the corresponding abduction path after mapping its zero. Author the inward endpoint separately. Give a forward overhead reach its own sample. The remaining travel is the distance from the currently accepted turn to the endpoint. [Sahara et al., measured positions](https://www.sciencedirect.com/science/article/abs/pii/S1058274618306220) · [Results on the total arc](https://pubmed.ncbi.nlm.nih.gov/30573432/)

**Upper arm reaching behind the torso.** Key a distinct sample with the elbow behind the shoulder, for example at 30° shoulder extension. Use a clear view of the elbow hinge to record an interior upper-arm orientation, then check inward and outward turn separately with the chest fixed. Test the back-pocket reach with the actual hand and grip afterward. In one study, 30° extension gave an average **14.8° of additional passive inward travel** from the test start while the examiner constrained shoulder-girdle movement. That number describes a change during that test. A signed limit for Josie requires both a mapped zero and an endpoint for each direction. [Shirai et al., methods and results](https://www.jstage.jst.go.jp/article/jpts/34/11/34_2022-069/_pdf)

## First implementation rules for missing samples

Keep the poses editable on both arms. Apply the published or checked Josie row when the side, arm direction and reference match. Use a nearest row only for a **small local gap**. At exactly overhead, every horizontal shoulder-height row is 90° away and tied. A tiny sideways movement could otherwise switch the arm between two different limits.

1. **Pick the source by arm direction.** Compare unit shaft vectors in chest space using the angle between them. Require a complete source row in the same movement region. An initial search radius of **15°** is an editor tuning choice. Use original reference rows or rows already checked on Josie as donors. This prevents a sequence of provisional samples from extending a 15° allowance around the whole shoulder.

2. **Align the zeros before borrowing.** Carry the donor’s hinge reference through the shortest swing to the target shaft. Measure that transported zero in the target’s fixed anatomical frame. If it reads `k`, the donor bounds `[L, U]` become `[L + k, U + k]` on the same continuous angle branch. Keep any tighter known bounds and take the overlap in transition regions. Choose the frame from the stored profile for that arm. At straight up or down, use a stored hinge reference because the shaft alone leaves the elevation plane ambiguous.

3. **Give distant poses a local starting point.** For overhead or posterior regions beyond the search radius, use a fixed, inspected Josie pose in that region. Store its signed twist once. As a first editor pass, inspect poses **10° to either side** of that center and enable only the part that passes the pose and collision checks. The 10° is an authoring increment. Each endpoint can then be expanded independently. If the center is missing or the interval is empty, keep the target editable, retain the last legal arm pose and flag the missing sample.

4. **Protect motion across regions and repeated drags.** Keep swing, elbow, forearm, wrist, grip and collision constraints active. If the next direction has a narrower interval, let the humerus turn back into the interval during the move, or stop at the last feasible step. Keep the same zeros and endpoints on mouse release, node change and reload. Mark borrowed or locally estimated rows **provisional** in the saved profile so preview and replay can identify the same rule. A checked local pair replaces the fallback.

For acceptance, approach the same high or posterior direction from two sides, repeat on the opposite arm, and release and re-grab at a twist limit. The same side and shaft direction must recover the same anatomical interval. Different paths may leave the elbow and forearm in different legal poses. Repeated outward input must stop at the limit, and the first feasible inward increment must move away from it.

# 4 Account for what changes when the elbow bends

Let `u` point from shoulder to elbow and `v` from elbow to wrist. In the ideal hinge model used by the arm guide, `u · v = cos(a)`. With the shoulder center and upper-arm direction held, the result of turning the humerus changes with elbow bend.

| Elbow bend | Effect of turning the humerus |
| - | - |
| 0° | The upper-arm and forearm shafts align. Their signed turns can add around the same line. |
| 45° | About 71% of the **instantaneous angular velocity** of humeral turn projects along the forearm shaft. The forearm also swings in space. |
| 90° | The shafts are perpendicular. Humeral turn swings the forearm around the upper arm. Pronation and supination still turn the hand about the forearm’s own shaft. |
| Beyond 90° | The forearm-axis projection changes sign. Evaluate the actual joint axes and grip at the new pose. |

Use this projection to understand which joint can help. **Keep the shoulder’s own limit in its shoulder profile.** Multiplying that limit by `cos(a)` would switch off legal shoulder rotation at 90° bend. On a rig with a carrying angle, use the actual shaft dot product for the projection.

The upper arm can keep both joint centers in place while its hinge axis rotates. With a 26 cm forearm, a 90° elbow bend and a fixed upper-arm direction, 30° of humeral turn alone moves the wrist center about **13.5 cm**. It traces a circle of radius `forearm_length × sin(a)` around the upper-arm line. A forearm swing exceeding 90° is possible if the starting shoulder angle, remaining interval and clearances allow it. Holding the hand-contact point fixed may require other joints to compensate and can shorten that swing.

# 5 Apply the rules to the upright sword

Place the contact pivot at the gripping hand, extend the right arm forward and point the blade upward. In this gesture the sword tip sweeps in the plane parallel to the chest. Its rotation axis is the **forward line through the contact point**. Capture the grip orientation so the blade edge and palm follow the intended sweep. From the front, the character’s right shoulder is on the viewer’s left. Mirror the example toward the character’s left shoulder for the other hand.

Read the starting angles `p₀` and `h₀` from this actual grip. Upright describes the sword, and many combinations of shoulder and forearm turn can put it there. For the straight, aligned, fixed-wrist example, if the thumb-side descent uses pronation plus internal rotation, the available angle in each direction follows from the remaining joint travel.

```math
\begin{aligned}
\text{toward descent} &= (P-p_0)+(h_{\max}-h_0) \\
\text{toward opposite side} &= (p_0+S)+(h_0-h_{\min})
\end{aligned}
```

A small positive turn on each side identifies its actual blade direction for that grip. If a mounting or reverse grip reverses the gesture, exchange the corresponding directional headroom. Use the full arm and hand transforms as soon as the axes separate.

For a worked example, suppose an upright grip measures `p₀ = 0°` and `h₀ = −35°` in the reference above. At full extension the forearm has 109° available toward pronation. The shoulder has 76° left toward internal rotation, for an ideal **185°** in that direction. The reverse side has 39° of supination and 78° of external shoulder rotation, for **117°**. Those budgets can cover down at +180° and the same-side horizon at about −90°. The assumed −35° is an example reading. Measure Josie’s starting angle before predicting either endpoint. The hand-to-wrist offset, fixed contact and collision can reduce the reachable arc.

# 6 Enforce the limits throughout a movement

1. Start from the previous accepted joint pose. For each small input step, try the existing allocator with the actual hand contact and requested blade direction. Prefer useful forearm turn for rotation about its shaft, then recruit available humeral turn. Keep wrist bending and shoulder aiming available within their existing limits when contact requires compensation.

2. Accept the entire candidate together. Check the signed elbow hinge, `−S(a) ≤ p ≤ P(a)`, the chest-relative shoulder envelope at the candidate direction, the wrist envelope, rigid grip, contact position and collisions. If a pose change would narrow an interval around an already turned joint, solve for the required turn at the same time. Commit the largest verified legal part of the requested step.

3. Store persistent, signed joint angles measured from anatomical references. Use small steps to choose the continuous branch around the previous accepted angle. Apply bounds to the **total joint angle**. An angle display that wraps from +180° to −180°, a quaternion sign change, a crossed clock position or a new mouse drag must all preserve the same anatomical reference.

4. At an endpoint, stop the outward component and allow inward motion on reversal. Hold reached proximal angles where geometry permits. For relative input discard the rejected remainder. For authored motion, validate the path between nodes, store the accepted motion and play that path. Interpolating wrapped endpoint orientations alone can choose the other route. Apply twist helpers from the accepted pose, then check the final hand and weapon transforms.

**Use the blade circle as a joint test.** On each arm, first isolate forearm turn at 0° and 90° bend and read both signed endpoints. Next isolate shoulder turn with a bent elbow so its change is visible on the forearm. Finally repeat the upright sword sweep, continue outward through several requested revolutions, then reverse through upright. Log the accepted forearm angle, shoulder angle, elbow bend and blade angle independently. For the straight, fixed-direction, fixed-wrist test, the accepted motion must plateau at the first joint or held-contact boundary even while input continues. An on-axis test pivot isolates the angular limits. Restore Josie’s actual contact offset for the grip test. Repeat with the wrist and permitted compensations enabled, checking every joint and the grip along the path. A tip can trace a loop through a sequence of bounded, coordinated poses. The physical failure is a component crossing its own interval, a discontinuous pose change, or loss of the required grip.

The existing implementation guides define the joint frames, wrist envelope and contact-pivot solver used here. [Arm constraints](https://chatgpt.com/space/page_67bdd1d032a88191b108d3225cefcdc6) · [Wrist and hand](https://chatgpt.com/space/page_402c58a864cc8191ad9d1d3e516075b1) · [Weapon motion allocation](https://chatgpt.com/space/page_5c62f07130a88191bb39a0361e6f310f)
