# Skill Crafter hand control parity — 2026-11-10

## Scope and sequence

User approved staged work, one section at a time. Current implementation slice:
**empty-hand movement**, following the completed control inventory. Later stages
are plans, not permission to bundle them into this change.

1. Control inventory — completed against current code.
2. Empty-hand movement — implemented; focused checks passed, user testing next.
   Reuse main-hand movement intent and the shared
   anatomical allocator. Preserve occupied-hand grip, opposite-arm isolation,
   elbow controls and existing anatomical limits.
3. Independent green-ball wrist controls. Main hand keeps current behavior.
   Engaged offhand uses the same wrist bend axis (current Hand local Z); weapon
   and main hand remain stationary while the offhand arm adjusts around its grip.
4. Support-hand axial freedom. Permit weapon roll within the supporting grip;
   explicit dark-green cube rotates only the weapon with both hands stationary.
   Existing rigid full-frame attachment is not sufficient for this: contact,
   retention and recording must agree on permitted relative motion. Assess
   noncircular handle contact using existing grip capabilities; do not redesign
   the numerical finger solver.
5. Independent normal/reverse settings on the **current** motion node. No
   automatic new node. Primary flip moves weapon against primary hand; support
   flip opens/reorients/closes the support hand against stationary weapon and
   primary hand, at its selected handle percentage. Path depends on starting
   relationship and available anatomical movement, not world up or gravity.

Acquisition roles remain weapon-to-primary-hand and support-hand-to-weapon.
Empty hands have Index/Middle/Ring/Pinky controls; occupied hands do not.

## Findings before this change

- Both arms already share `combat_weapon_motion_allocator.gd` and its rig
  kinematics. The empty-hand route is not a separate primitive bone engine.
- UI knows which proxy endpoint was dragged, but its rig call loses that intent.
  `CombatIndependentArmMotionAdapter.move_hand` always requests `pose`, with six
  position/orientation rows. Main Pommel uses three position rows; main Tip uses
  three rotation rows and permits the arm to carry the hand through space.
- Rig empty-hand preparation first calls `_update_support_arm_ik_targets` (old
  reach projection) and reconstructs a full hand orientation from the proxy
  contact axis and current forearm. This adds requirements beyond the selected
  control's intent. Legacy alternate target correction is disabled in authoring;
  do not claim every legacy collision/front-orbit projection is actively clamping.
- Marker drawing/readback was already corrected on 2026-11-08 to use actual
  hand bones. Keep that; requested endpoints are not attained pose truth.
- Both elbows exist. Empty hands have two proxy endpoint spheres and four finger
  controls. Only the primary currently has the anatomical green-ball control.
  Two-hand support currently has its elbow but no independent wrist control.

## Stage 2 implementation contract

Read the actual Hand world transform and actual bone-derived proxy endpoints,
then resolve the explicitly selected Tip/Pommel intent in the same allocator as
the primary hand. Convert trajectory-authoring targets to world once; local task
landmarks belong to the Hand frame. Bone writes remain parent-local, with ancestry
to `RL_BoneRoot`. No invented new anatomical zero.

Large endpoint: position task at that actual endpoint, orientation may adapt,
with main Pommel's existing trailing-tip preference and wrist-coordinate holds.
Small endpoint: orientation task, no retained spatial pivot, same Tip rules.
General explicit two-endpoint placement may request a combined pose; it must not
silently turn an ordinary position drag into such a request.

Touched production owners: station UI, station preview presenter, humanoid rig
independent-arm entry point, independent-arm motion adapter. Existing numerical
grip solver, occupied two-hand allocation, profiles and core allocator are outside
this stage's changes.

## Implementation and verification

Stage 2 implementation now threads explicit control intent from mouse input
through the presenter and rig into the existing allocator. It bypasses legacy
target preparation for these requests, not the anatomical solver. General
combined two-endpoint API placement retains an explicit `pose` mode.

User explicitly reaffirmed that this includes Unarmed and its extra fingers.
Both Unarmed primary aliases (generic Tip/Pommel) are routed as empty-hand input,
including numeric setters. Their legacy weapon-only drag authority is excluded.
On opening/reset and after moving the primary empty hand, the invisible Unarmed
display proxy is rebuilt from physical hand points before publication/recording. These points
already use grip-alignment origin, so its mount uses a zero origin override to
avoid subtracting the contact center twice. Real weapons remain stationary
during empty-offhand edits. The attained primary frame is encoded into the
existing seven endpoint/orientation fields before retained identity is captured;
this keeps its up-reference consistent as well as its endpoint axis. Finger curl
behavior is unchanged.

Focused armed regression harness:
`tools/verify_empty_hand_motion_intents.gd`; actual saved `Broken_Glave_v1` profile,
temporary library, both empty-hand sides, visible marker press/drag/release,
position versus orientation, actual marker attachment, untouched opposite bones
and weapon, and occupied-slot guards. No broad Save/F/equip cycle run.

Baseline output: `godot_runs/empty_hand_intents_before_20261110/`.
The first case (right primary, left empty hand) failed because the Tip phase
barely changed orientation: 0.062118 degrees maximum over four inputs. Pommel
steps took 218–1820 ms; Tip steps 1695–1949 ms. The inherited runner stopped on
that case failure; there is no measured left-primary baseline in this run.

After output: `godot_runs/empty_hand_intents_after_20261110/`.
Both primary-side configurations passed, with 16 actual input samples plus 12
release observations. All reported ACCEPTED; real weapon displacement and
release pose drift were zero. Maximum untouched-arm position difference was
0.000000329 m (float precision). Markers and stored endpoints matched physical
hand geometry. Occupied primary/support proxy edits were rejected by their
existing availability rules. Source library hash was unchanged:
`108ac5d6eb2658f3cdbf0adcc6b5f8ce881118bdc10f19cdd701483a9e37ae82`.

| Main hand / edited empty hand | Control | Maximum Hand travel | Maximum Hand turn | Input-step wall time |
|---|---|---:|---:|---:|
| R / L | Large / Pommel | 74.54 mm | 26.64 degrees | 184–228 ms |
| R / L | Small / Tip | 22.76 mm | 5.99 degrees | 53–64 ms |
| L / R | Large / Pommel | 60.94 mm | 33.59 degrees | 201–271 ms |
| L / R | Small / Tip | 20.83 mm | 6.17 degrees | 61–73 ms |

These are fixed pointer-step wall times including queued refresh and observation
frames, not OS mouse latency or a constant gameplay FPS guarantee. Position
requests remain more expensive. No core performance tuning was added.

Unarmed focused verifier: `tools/verify_unarmed_empty_hand_movement.gd`.
Final rendered run: `godot_runs/unarmed_empty_hand_verified_20261110/`.
Eight pointer cases cover both primary-hand choices, primary generic Tip/Pommel
and opposite-hand endpoints. Four additional numeric primary edits were checked.
All 1,144 assertions passed; these are repeated observations within those cases,
not 1,144 different poses. Every release retained the accepted Hand without a
measured position/angle change. Published/stored endpoints matched physical
points; the encoded orientation also decoded back to the actual proxy frame.
Both hands kept Index/Middle/Ring/Pinky controls, and seeded Index curls retained
their values and local joint rotations throughout movement. No grip request,
queue, worker or binding was introduced. No player library was loaded or saved.

Earlier Unarmed failures remain recorded rather than overwritten:

- `unarmed_empty_hand_motion_20261110`: four initial primary marker attachment
  failures exposed the double contact-center subtraction. Fixed in production.
- `unarmed_empty_hand_motion_final_20261110`: all frame/movement/finger checks
  passed, but one primary Pommel gesture shifted 3.89 mm / 1.73 degrees on
  release. That run mixed direct drag samples with captured native window input;
  it did not record enough input state to assign a definitive cause.
- `unarmed_empty_hand_release_trace_20261110`: unchanged production code, same
  first gesture, 189 assertions passed, no pending relative input and zero
  synchronous or delayed release drift. The final full run then isolated native
  window input in the verifier while retaining direct UI pick/drag/release calls.
  No production release workaround or tolerance relaxation was added.

The armed result predates the final Unarmed-only routing additions; those
branches explicitly require Unarmed. Scoped whitespace checks passed. No broad
Save/F/equip workflow was rerun, and no numerical grip/core allocator/profile
changes were made. Large position requests can still be expensive; this stage
corrects conflicting movement intent, not all motion-performance limits.

## Next stage

User manually checks armed empty offhand and both Unarmed hands. The user then
authorized adding the green-ball wrist controls for those **empty** hands too.
Engaged support-hand wrist adjustment remains a separate subsequent slice;
support roll and independent reverse grip are still not implemented here.

### Empty-hand wrist control addition

Implementation uses the existing Hand-local-Z gamma bend and fixed anatomical
limits. `roll` mode in the independent arm adapter freezes upstream coordinates,
forearm rho and wrist beta. The controlled frame is the actual Hand world frame,
with a zero Hand-local pivot; `H * Rz(delta)` leaves its origin stationary. No
weapon binding or finger solve is needed. Both sides use the same contract.

The focus list exposes an empty-hand green sphere beside that hand. Unarmed's
primary wrist occupies the former generic weapon-control position; other empty
wrists precede their fingers/hand movement controls. Ordinary Space/Shift+Space
selection, visible-mesh picking, pointer capture and speed limiting still apply.
Rejected pointer travel is consumed so reversal at a limit does not accumulate
dead travel. The old Unarmed weapon-roll box is hidden; its API redirects to
the primary wrist, keeping the stored weapon orientation decomposition separate.

Accepted motion reuses endpoint readback, independent-arm retention, and the
existing prepared-pose bone/wrist-state packet. No extra authored angle field,
alternate skeleton, new anatomical reference or grip-solver changes were added.
Production owners: session focus IDs, station UI, preview presenter and
independent-arm adapter, plus a small helper-update hook in the shared motion
adapter. The occupied-hand path keeps its previous helper distribution.

First wrist use seeds temporary hand guidance from the actual displayed Hand,
even when that hand has never received a position edit. Only an accepted edit
promotes those fields into the node. Rejected edits retain the displayed pose
without marking temporary guidance as authored.

The initial focused run exposed an unrelated first-edit reset of forearm skin
helpers. Bone-level diagnosis identified `CC_Base_L_ForearmTwist02`: it turned
34.714 degrees while semantic forearm rho and wrist beta stayed fixed. Shared
commit had unconditionally rebuilt helpers from rest. Independent wrist-Z edits
now preserve captured helpers, since this mode freezes rho and the upstream
chain. Trial validation and final commit use the same hook; the final pose
packet still reads back the actual committed bones. Other movement modes keep
their existing behavior.

Verification harness: `tools/verify_empty_hand_wrist_controls.gd`.
It exercises first-use green-sphere picking/drag/release, both anatomical limits
and immediate reversal, fixed wrist origin, unchanged upstream/opposite bones,
finger retention, unchanged real weapon, and no new grip acquisition. A focused
prepared-node resource save/load checks stored bone/wrist state and normal pose
restoration without rerunning the full Save/F/equip workflow.

Historical test evidence for this slice:

- `godot_runs/empty_hand_wrist_20261110`: harness typed-array error before any
  gesture; corrected in the verifier.
- `godot_runs/empty_hand_wrist_verified_20261110`: initial six-case run found
  helper drift. Its single-event extreme-angle expectation and acquisition
  request-serial equality on prepared restore were overbroad assertions.
- `godot_runs/empty_hand_wrist_diagnostic_20261110`: one-case bone diagnosis,
  304 checks with 16 helper-drift failures; other checks passed. Huge requests
  correctly use the existing 12-substep budget, so the verifier checks bounded
  progress and convergence, with unchanged final limit/reversal tolerances.
  Restoring an armed prepared pose rebuilds grip request bookkeeping without
  starting acquisition; restore checks inspect idle state and imported bindings.

Final six-case rendered verification passed in
`godot_runs/empty_hand_wrist_final_20261110`: 2,131 assertions, zero failures.
These are repeated checks within six cases, not 2,131 distinct poses. Both armed
primary choices and both hands in both Unarmed primary configurations passed,
including prepared-node serialization/restoration. The saved player library hash
was unchanged. Parser and scoped whitespace checks passed. No broad Save/F/equip
run was performed, no new grip solve was introduced, and the occupied-hand grip
solver was not changed.

Empty-hand wrist controls are ready for manual testing. Engaged offhand wrist
controls, passive weapon roll in the support hand, and independent reverse-grip
settings remain the subsequent stages; they are not implemented by this slice.

Do not interpret a valid motion result as a newly certified finger grip.

## References

- `Skill Crafter Free Hand Marker Attachment 2026-11-08.md`
- `Skill Crafter Glave Skill 1 Offhand Audit 2026-11-09.md`
- `SPS_2026_11_09_07-44.md` (prior state; current code takes precedence)
- [Godot 4.7 Skeleton3D](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html): bone global pose is skeleton-relative, not world.
- [Godot 4.7 Transform3D](https://docs.godotengine.org/en/4.7/classes/class_transform3d.html): compose/invert frames explicitly, retaining scale.
