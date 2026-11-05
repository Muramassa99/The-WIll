# Shoulder Anatomy Research — 2026-10-28

Scope: anatomical and rotational groundwork for the Skill Crafter upper-body chain. Current test surface is **unarmed mode and its body controls**. This note adds no runtime behavior, numerical joint limits, rig hierarchy changes, or weapon-specific mechanism. Sources were checked on 2026-10-28. This is animation research, not a clinical assessment.

Start with [Shoulder Anatomy And Unarmed Rig Reference 2026-10-28](<Shoulder Anatomy And Unarmed Rig Reference 2026-10-28.md>) for the project entrypoint, coordinate-mapping worksheet, and future unarmed verification plan. This companion records the biological evidence, rotation distinctions, source access, and limits on translating that evidence into rig rules.

**Later user clarification, 2026-10-28:** the triangular-return example is withdrawn as a product requirement. The goal is usable, predictable control of the shared body across all weapon archetypes; Unarmed is only the initial isolation test. Follow the paper/guide as guidance and introduce a tolerance only if needed, up to the user's 3% allowance with a defined reference. See the entrypoint's latest-decisions section. No live margins have been changed.

## Shoulder movement is a coupled chain

The biological chain separates these relationships:

| Relationship | Relative motion to represent |
| --- | --- |
| Sternoclavicular (SC) | Clavicle relative to thorax: elevation/depression, protraction/retraction, axial rotation. |
| Acromioclavicular (AC) | Scapula relative to clavicle: upward/downward rotation, internal/external rotation, anterior/posterior tilt. |
| Scapulothoracic (ST) | Scapula relative to thorax: the combined functional result of SC and AC motion, not an extra independent rotation to add twice. |
| Glenohumeral (GH) | Humerus relative to scapula: elevation, elevation-plane placement, and axial orientation. |

Ludewig et al. measured clavicle, scapula, and humerus using bone-fixed sensors in twelve healthy participants. Raising the arm involved motion throughout this chain, including clavicular posterior rotation and scapular upward rotation/posterior tilt. The findings support moving the shoulder support frame as the arm moves; they do not support making the humerus solve every target against an immovable shoulder. These were measured patterns in selected tasks, not universal maximum-angle rules. [Ludewig et al., 2009, original study](https://pmc.ncbi.nlm.nih.gov/articles/PMC2657311/)

Do not turn scapulohumeral rhythm into an unconditional 2:1 equation. In an unconstrained reaching study using bone-fixed sensors, Braman et al. found different average GH-elevation/scapular-rotation ratios during raising (2.3) and lowering (2.7), with variation across the movement arc. Those sample averages demonstrate coupling and variation; they are not values to paste into every rig frame. [Braman et al., 2009](https://pubmed.ncbi.nlm.nih.gov/19395283/)

## Establish the reference before assigning a limit

ISB guidance distinguishes a bone's orientation relative to its proximal segment from its orientation relative to the thorax. Humerus-relative-to-thorax motion includes shoulder-girdle contributions; it is not isolated GH motion. Anatomical coordinate systems must be calibrated to landmarks or suitable calibration movements. An imported bone's local X/Y/Z convention is not automatically an anatomical coordinate system. [Wu et al., ISB recommendation, 2005](https://media.isbweb.org/images/documents/standards/isb_jcs_part_ii.pdf)

Use the 2005 standard consistently for anatomical directions and rotation sequences; its mapping is recorded in the companion worksheet. Earlier shoulder protocols use different conventions and cannot be substituted without converting the reference frames. [Wu et al., sections 2.3–2.4, searchable official PDF](https://media.isbweb.org/images/documents/standards/Wu%20et%20al%20J%20Biomech%2038%20%282005%29%20981%E2%80%93992.pdf)

For this rig, label every proposed angle with its reference: thorax, clavicle/support frame, humerus, or forearm. Record the neutral posture, left/right sign convention, and rotation decomposition. Euler orders have singularities; the older Van der Helm protocol describes first/third-axis ambiguity near aligned axes. It is **historical background, not the axis/sequence authority for the 2005 mapping**. Do not mix its conventions with Wu 2005. A sudden decomposed angle jump needs comparison with the actual bone basis before being called a physical flip. [Historical protocol, sections 4–6](https://media.isbweb.org/images/documents/standards/frans_c.t._van_der_helm_shoulder_protocol.pdf)

Range also depends on the task and humeral position. Humphries et al. measured active and passive axial rotation in twenty healthy participants at 60°, 90°, and 120° elevation across three planes. Maximum internal rotation varied with position and was reduced in sagittal-plane/high-elevation conditions; maximum external rotation did not show that dependence in their sample. This supports a position-aware envelope, not an assumption that every range varies identically or a universal symmetric roll clamp. [Humphries et al., 2015](https://pubmed.ncbi.nlm.nih.gov/26410346/)

Two cadaveric studies add useful context, without supplying active-character limits. Southgate et al. found a largest total internal-to-external excursion of 140° under ±1 Nm at 30° GH abduction in the scapular plane, using nine muscle-resected specimens. That is neither ±140° nor an active-use limit. [Southgate et al., 2009](https://pubmed.ncbi.nlm.nih.gov/19375080/)

Moskal et al. studied eight preparations before/after capsular release. Resisting torque rose near range endpoints; intact-capsule axial availability decreased approaching maximum elevation, and residual cuff tension still limited motion after release. This supports coupled soft-tissue constraints. It does not establish that a game must reproduce their surgical preparation, torques, or measured translations. [Moskal et al., 1999](https://pubmed.ncbi.nlm.nih.gov/10355717/)

Bibliographic distinction: Browne et al. is a separate 1990 nine-cadaver elevation study, not the 2009/PMID 19375080 range paper. It associates plane-dependent humeral rotation with tuberosity clearance and capsular constraints during maximal elevation. Its fixed-scapula experimental result must not become a universal active whole-shoulder rotation ramp. [Browne et al., 1990](https://pubmed.ncbi.nlm.nih.gov/2211768/)

## Axial orientation is not the same measurement as accumulated axial rotation

Aliaj et al. compared Euler/Cardan angle changes with the time integral of angular velocity projected onto the humeral shaft, using biplane fluoroscopy in twenty healthy participants. During the studied elevation tasks, apparent axial-angle changes differed substantially from this true axial-rotation measure. At higher elevations, the latter was not significantly different from zero in the analyzed ranges. This does **not** mean the humerus has no axial degree of freedom. It means a changing Euler axial coordinate cannot directly justify adding that many degrees of physical twist. [Aliaj et al., 2021](https://pubmed.ncbi.nlm.nih.gov/33989999/)

A subsequent analysis of the same underlying cohort found that ST motion supplied 13–20° (76–94%) of humerothoracic axial rotation during the measured elevation trials. The shoulder-girdle contribution depended on its relation to the humerus. These are task/cohort observations, not fixed blend weights. They strengthen the case for accounting for upstream shoulder motion before assigning all visible rotation to a humeral or forearm twist helper. [Kinematic coupling of the GH and ST joints, 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9081276/)

## What a triangular return movement guarantees

This section is retained mathematical background, **not an active acceptance test**. The user withdrew that example after this research was written.

Returning a hand position, or the upper-arm longitudinal direction, does **not** uniquely return the full arm orientation. An additional direction is needed to distinguish axial orientation; an articulated arm also has alternative elbow configurations. Politti et al. demonstrate that a particular sequence of three orthogonal 90° arm rotations returns the longitudinal direction while leaving a net 90° orientation change. This is the geometric Codman effect, not evidence of a solver bug by itself. [Politti et al., 1998, mathematical validation](https://pubmed.ncbi.nlm.nih.gov/9728676/)

The path matters because spatial rotations do not generally commute. Cheng's simulations generalize the closed-loop example to other starting attitudes and axes; they do not imply that every triangle produces the same residual angle. [Cheng, 2006](https://www.sciencedirect.com/science/article/pii/S0021929005001569)

For a frame transported around a closed direction path without local spin, the residual orientation has a geometric interpretation involving the enclosed spherical area. That condition matters: it is not a statement that every freely rotating body must accumulate that amount of twist. [UC Berkeley Rotations, Codman's paradox and geometric interpretation](https://rotations.berkeley.edu/some-interesting-rotation-sequences/)

Consequences for the editor, as engineering choices:

- **Position-only loop A → B → C → A:** exact orientation return is not guaranteed by the target position alone.
- **Exact reverse of the complete rotations:** applying their true inverses in reverse order restores the starting orientation, apart from numerical error. Returning through a different third path is not the same operation.
- **Same complete authored state:** an absolute-reference deterministic solver can be designed to reproduce the same orientation. That remains an optional control design, not a current user requirement. It is not a claim that biology erases geometric phase.
- **Parallel-transport control:** smooth minimal incremental rotations can be a valid control design, but closed-loop residual orientation is then expected unless explicit compensation/reference rules remove it. Do not mix this behavior with an absolute-reference control without deciding which one owns the final orientation.

## Implications for the current upper-body work

These are implementation hypotheses, not additional anatomical findings or approved new mechanics:

1. Inspect the current rig's actual support bones, rest frames, and skin weights. If there is no independently usable scapula, represent the omitted motion explicitly as an approximation in the existing support frame; do not claim that one Clavicle bone is all four biological relationships.
2. Keep one definition of the anatomical humeral frame across shoulder solving, elbow bend validation, manual elbow orbit, and twist-helper deformation. A visually rotated helper that does not parent the Forearm cannot silently supply the Forearm's coordinate reference.
3. Revisit the existing pure-swing main-Upperarm authority openly. A biological humerus has axial orientation; assigning its visual effect to helpers is a rig implementation choice. Neither the anatomy sources nor Codman's example decides whether to retain or replace that implementation.
4. Separate accepted pose changes, clearance rejection/rollback, and orientation-history drift in observations. A rejected movement returning to authored targets is not the same event as an accepted joint changing direction.
5. Use unarmed L/R controls for level/raised/cross-body reach, extension/retraction, deliberate elbow orbit and varied repeated adjustments. Compare full bone/skin orientation, complete inputs and continuity state to diagnose surprising motion, not only endpoints or one Euler component. The user's withdrawn triangle example is not an acceptance condition. This is a proposed test set; no tests were run for this research note.

NEEDS_DECISION before numerical implementation: the anatomical-to-rig calibration, which existing bone or logical frame represents missing scapular support, the allowed posture-dependent envelope, and the intended absolute-reference versus transported-reference behavior of each authoring control. The cited studies do not supply a turnkey safe clamp table for this character.

## Source register and reuse limits

Access date for every entry: **2026-10-28**. This register records what was consulted, not an assertion that every linked full paper was read. No copyrighted article archive or copied figure was created. Summaries above are intentionally short; use the primary links for definitions, figures, methods, uncertainty, and original data.

| Source | Stable identifier / original publication | Access and applicability |
| --- | --- | --- |
| Wu et al., 2005 | [DOI 10.1016/j.jbiomech.2004.05.042](https://doi.org/10.1016/j.jbiomech.2004.05.042), *Journal of Biomechanics* 38:981–992 | Official ISB PDF and relevant shoulder-coordinate sections consulted. A measurement/reporting standard, not a physiological limit table. |
| Van der Helm, historical shoulder protocol | [Official ISB-hosted PDF](https://media.isbweb.org/images/documents/standards/frans_c.t._van_der_helm_shoulder_protocol.pdf); document describes the 1996 proposal as its starting point | Relevant reference-frame/singularity sections consulted. Exact revision date not established; do not treat it as interchangeable with Wu 2005. |
| Ludewig et al., 2009 | [DOI 10.2106/JBJS.G.01483](https://doi.org/10.2106/JBJS.G.01483), *JBJS American* 91:378–389 | PMC full-text material consulted. Small invasive study, prescribed planes and individual variability; observed rotations are not hard limits. |
| Braman et al., 2009 | [DOI 10.1016/j.jse.2009.02.001](https://doi.org/10.1016/j.jse.2009.02.001), *Journal of Shoulder and Elbow Surgery* 18:960–967 | Primary abstract consulted. Unconstrained reaching evidence; ratios depend on task and movement phase. |
| Humphries et al., 2015 | [DOI 10.1016/j.jse.2015.07.007](https://doi.org/10.1016/j.jse.2015.07.007), *Journal of Shoulder and Elbow Surgery* 24:1974–1981 | Primary abstract consulted. Optical tracking, selected elevations/planes, twenty healthy subjects; no complete universal ROM surface extracted. |
| Southgate et al., 2009 | [DOI 10.1016/j.jbiomech.2009.03.007](https://doi.org/10.1016/j.jbiomech.2009.03.007), *Journal of Biomechanics* 42:1307–1312 | Primary abstract consulted. Passive specimen loading; not normal active ROM. |
| Moskal et al., 1999 | [DOI 10.1016/S0749-8063(99)70059-9](https://doi.org/10.1016/S0749-8063(99)70059-9), *Arthroscopy* 15:408–416 | Primary abstract and publisher methods/results excerpts consulted. Cadaveric surgical intervention, not healthy dynamic reaching. |
| Browne et al., 1990 | [DOI 10.1302/0301-620X.72B5.2211768](https://doi.org/10.1302/0301-620X.72B5.2211768), *JBJS British* 72:843–845 | Primary abstract consulted. Passive maximal GH elevation; separate from whole-body active motion. |
| Aliaj et al., 2021 | [DOI 10.1016/j.gaitpost.2021.05.004](https://doi.org/10.1016/j.gaitpost.2021.05.004), *Gait & Posture* 88:28–36 | Primary abstract and PMC methods/results/discussion excerpts consulted. Specific right-arm tasks/cohort; distinguishes two rotation measurements. |
| Aliaj, Lawrence et al., 2022 | [DOI 10.1016/j.jbiomech.2022.111059](https://doi.org/10.1016/j.jbiomech.2022.111059), *Journal of Biomechanics* 136:111059 | PMC methods/discussion consulted. Reuses the underlying cohort; not an independent replication of the 2021 observations. |
| Politti et al., 1998 | [DOI 10.1016/S1350-4533(98)00020-4](https://doi.org/10.1016/S1350-4533(98)00020-4), *Medical Engineering & Physics* 20:257–260 | Primary abstract consulted. Mathematical orientation result; does not prescribe muscle coordination or game input semantics. |
| Cheng, 2006 | [DOI 10.1016/j.jbiomech.2005.03.017](https://doi.org/10.1016/j.jbiomech.2005.03.017), *Journal of Biomechanics* 39:1201–1207 | Publisher abstract/introduction consulted. Geometric simulations; not a joint-limit study. |
| UC Berkeley Rotations | [Some interesting rotation sequences](https://rotations.berkeley.edu/some-interesting-rotation-sequences/) | Institutional mathematical derivation consulted. Secondary explanation of original work, used alongside primary Codman papers; no publication date established. |

Conservative translation into game rules means recording the assumptions and testing the actual rig. It does not mean selecting the smallest angle from incompatible studies. Separate biological evidence, measurement convention, reduced-rig approximation, and deliberate user-control behavior before choosing any numeric limit.
