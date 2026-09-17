# Weapon Roll about the wrist–Tip axis — chat 14

Created: 2026-09-14 12:42 Europe/Bucharest.
Updated: 2026-09-15, after the user authorized the manipulation stage before
F generation and saving. The dedicated GPU is repaired and back in use.
Base: `92b8a24fcac64e38c2565e56fec6878e22e55e26` on
`recovery/stable-92b8a24-chat14`. The later `d798cc01` backup remains a reference;
none of its Roll or Support implementation has been reapplied.

## Requested behavior

The user requested implementation after rollback: Tip and wrist stay stationary;
the weapon and solved hand/grip rotate together about the wrist–Tip axis; Pommel
orbits. Roll must not move or twist the upstream arm/body. A named wrist reference
must resolve to the common machine origin under the coordinate law.

## Implemented prerequisite

`core/models/combat_origin_record.gd` now declares `RightWristOrigin` and
`LeftWristOrigin`. `runtime/player/player_humanoid_rig.gd` provides
`capture_authoring_wrist_origin(slot_id)`. The method validates actual Hand-bone
ancestry to `RL_BoneRoot`, registers the full affine wrist-to-machine frame, and
returns the validated chain and machine-to-world conversion. Invalid inputs
return an unavailable result with a reason. No placeholder wrist origin is
registered by the generic registry defaults.

The method is read-only and must be called after the grip/body pose settles.
`post_final_pose` is a caller timing contract, not a claim that the method runs
solvers or waits for them. [The coordinate law](../../The%20Will-%20main%20folder/the-will-gamefiles/COMBAT_COORDINATE_LAW.md)
documents the names, owner, phase, chain, failure handling and distinction from
the anatomical grip-contact frame. The old naming tracker remains sunset.

The production caller is now `CombatAnimationWeaponRollManipulator`, through
the Skill Crafter preview presenter. Baking and runtime playback integration
remain deferred to the next user-directed stage.

## Fresh verification

`tools/verify_authoring_wrist_origin.gd` passed 28 checks under the supported
Godot 4.7 launcher. Evidence:
`godot_runs/the_will_2026-09-14_12-41-38.log`.

The verifier exercises both sides using a real `Skeleton3D` with translated,
rotated and scaled presentation/bone frames. It checks full world round trips,
registered ownership/phase, unchanged bone poses, dynamic recapture and rejection
of unknown slots, wrong ancestry, missing bones/skeleton/world frame and singular
presentation. No game scene, player saves, grip solve or live gesture was run.
The known root-certificate-store startup error was emitted; the verifier returned
`ok=true`, zero failed checks and process exit 0.

## Implemented manipulation stage

One-handed Roll, on either side, now takes the actual settled Hand and weapon
frames as its baseline. `CombatWeaponRollResolver` rotates both about wrist-to-Tip
using requested angle minus captured angle. Tip and wrist remain fixed; Pommel
orbits; the existing hand-to-weapon relationship and finger articulation remain
unchanged. The rig writer changes only the selected Hand bone rotation and
restores it if the requested world frame cannot be represented.

The green Weapon control and numeric Roll field use this operation. Horizontal
drag is 0.5 degrees per pixel, within the existing -120 to +120 range. Pressing
the handle does not change the pose. Release does not enter the generic endpoint
commit or reopen arm/grip solving. Reset clears the Roll drag state. Draw and
pick share a normal calculation that includes the scalar Roll.

The editor transaction retains its immutable source while only Roll changes.
Changed motion properties, geometry/origin IDs, actor/weapon, bone poses,
skeleton frame/version or trajectory frame invalidate retention. Collision
diagnostics observe the resulting pose without correcting it. Arm-reach
legality is explicitly unavailable for this operation because it does not run
that solver.

The resulting Tip/Pommel and orientation are written coherently into the existing
motion fields: orientation compensates for the legacy axial scalar so the
existing frame solver reconstructs the full actual weapon transform. This
round trip is checked before either live pose writer runs. Returning to the
captured starting angle restores the exact starting authored fields, including
the mounted-entry seed when it differs from the displayed pose. This editor
retention is not a persisted grip/pose representation.

The named full-frame chains and phase ownership are documented in the coordinate
law. Unsupported origins or unrepresentable frames reject with an explicit
reason rather than inventing a reference. The existing editor frame encoding
expects a unit weapon basis; the normal display assumes a uniform authoring
frame. Pure resolver tests with affine source transforms do not establish that
all such transforms are representable by this legacy editor encoding.

## Manipulation verification

- `tools/verify_combat_weapon_roll_resolver.gd`: 364 checks passed.
  Log: `godot_runs/the_will_2026-09-15_00-22-22.log`.
- `tools/verify_weapon_roll_manipulation.gd`: 114 checks passed headlessly using
  the actual Skill Crafter UI and `Star_Handle_Testing`, both hands.
  Log: `godot_runs/the_will_2026-09-15_00-32-06.log`.
  Numeric changes, reversals, return to baseline, preserved grip and all other
  bone poses, refresh retention, green-handle press/drag/release, invalid-origin
  rejection and Reset were exercised. Maximum observed Tip error was about
  0.00000031 m; wrist error was zero. A prior expanded harness run stopped on a
  CanvasLayer/Control parameter-type mistake; the cited rerun fixes that error.
- The same verifier passed 117 checks with D3D12 Forward+ on the repaired NVIDIA
  RTX 2070 SUPER, including three rendered captures (two overwrite the same
  return-to-zero image). Log: `godot_runs/the_will_2026-09-15_00-33-20.log`.
  Maximum Tip error was 0.00000043 m; wrist error was zero. Images
  `test_artifacts/weapon_roll_2026-09-15_0.png` and
  `test_artifacts/weapon_roll_2026-09-15_90.png` were inspected: body/arm placement
  remains fixed while the weapon changes orientation. The Tip lies beyond the
  image crop, so its fixed position is established by measurements, not the
  screenshots. All successful runs exited 0; the pre-existing certificate-store
  startup error still appears in the logs.
- Test Reset operates on a deep copy of the saved library with a redirected test
  save path. The player's library SHA256 remained
  `C59A09D3B33D321F482F2C379DF5FD299246544F2229E5A8B12970F769500E0E`.
- These are measured manipulation results, not proof of F, saved reopen or
  equipped-gameplay parity, and not the user's manual acceptance.

## Next stage, explicitly deferred

The user wants manipulation working first, then F generation and saving.
The F binding is `skill_crafter_play_preview`, routed by the station UI to
`_toggle_preview_playback()`. It currently requires a valid cached clip;
the save path is where that clip is built/baked. Trace those actual boundaries
when the user starts the next stage instead of treating F as an isolated key.

Pending: preserve the authored wrist-roll result through node changes, fresh
bake, saved reopen, F playback and equipped gameplay; compare actual frames
across those seams and update cache semantics as required. Current solved
replay already transports full bone/weapon/anchor transforms, but its producers
still need parity work. This turn did not alter Save, baker, chain player,
runtime fallback solvers or the save schema.

Two-handed behavior still uses its prior path. Do not move or release the support
hand, change upstream IK, or port the discarded backup's support work without
an explicit scoped decision. The preserved backup remains a source for review,
not an instruction to reapply it.

No commit or push was made or authorized for this implementation stage.

## Subsequent user acceptance and performance work

The user subsequently reported that the new Roll manipulation works as intended,
then selected control-point performance as the next issue. Current performance
measurements, recovered UI changes, and the unresolved grip-reuse dependency are
recorded in [Skill Crafter Performance Recovery 2026-09-15.md](<Skill Crafter Performance Recovery 2026-09-15.md>).
