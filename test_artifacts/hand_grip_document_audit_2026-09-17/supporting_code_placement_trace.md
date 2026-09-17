# Supporting audit: occupied-hand center, mount, and final V2 seat

Read-only source trace, 2026-09-18. No Godot run, behavior verification, code change, or Git mutation. References below use current working-tree line numbers except explicitly marked April 11. Base path: `C:/WORKSPACE/The Will- main folder/the-will-gamefiles/`.

## Findings

The current occupied-hand path does determine an anatomical reference point and consumes it in the initial weapon mount. It is an approximate reference derived from a cached gripping pose; it is not the Hand-to-Index/Pinky right-angle construction described by the user. The subsequent V2 surface seat can move the weapon radially away from that initial center and rotate it. The original center is a seed, not an equality enforced by final seating.

There are distinct responsibilities: anatomical placement reference; signed orientation; actual surface fit. Counting two contact authorities does not establish the number of allowed translation directions, and the three Handle stations C0/Ci/Cp are not three independent anatomical constraints.

## Current mount call chain

1. `runtime/player/player_equipped_item_presenter.gd:619` requests `_resolve_hand_alignment_offset_state`; implementation at100 calls rig `resolve_hand_grip_alignment_offset_state` at108, preferring the origin-tagged dictionary API.
2. `runtime/player/player_humanoid_rig.gd:614` calls `resolve_hand_grip_alignment_offset_local`. At620-637 this starts from the live Index1/Pinky1 midpoint (`_resolve_hand_index_pinky_contact_center_world`,860-876). A missing/degenerate midpoint falls back directly to the cached grip center; otherwise it calls `_resolve_anatomically_seated_hand_grip_center_world` at631.
3. Rig878-895 obtains the finger presenter's anatomical center, subtracts its component along the live Index/Pinky axis, clamps the perpendicular displacement to0.75 times Index/Pinky span, and adds it to the midpoint. Thus its axial station is midpoint-derived and its radial seed comes from the old cached grip pose.
4. `runtime/player/player_rig_finger_grip_presenter.gd:2394` ensures the animation grip baseline cache and delegates to3268-3290. The latter averages cached Thumb and Index root/mid/end positions (up to six nonzero points). This is an explicit positional calculation, not solely an orientation.
5. Equipped presenter796-805 applies `_resolve_signed_contact_axis_weapon_hold_basis`2870-2933. It aligns the local Tip-minus-contact direction to the hand contact axis; reverse grip negates the target axis at2913-2914. This is the orientation responsibility.
6. Equipped presenter806-815 positions the weapon with `_resolve_hand_mount_origin_local`2935-2957: `target_contact_local - mount_basis * primary_grip_contact_local`. It stores that mount transform and origin metadata. Model re-centering at632-636 separately re-expresses mesh geometry relative to the weapon grip center.
7. Style refresh repeats the anatomical request: equipped presenter2293-2348, especially2321-2340. Preview4685-4704 invokes this for non-unarmed items. Preview4334-4384 resets the preview pose, applies grip state4348, hand mount4349, resolved grip4350, macro pose4370, then surface seat4371 and digit settling4380. Retained authoring Roll can return early4338-4339, preserving its established relationship.

## Final V2 surface fit

Preview `runtime/combat/combat_animation_station_preview_presenter.gd:5525` applies the final seat. When an actual solve is allowed it first establishes two-hand macro pose if needed5544-5552 and canonical open digit anatomy5553-5563. It calls rig `resolve_exact_surface_weapon_seat`5564-5568.

Rig4450-4491 dispatches by actual right/left slot and PrimaryGripGuide/SecondaryGripGuide. Primary wrappers4505-4516 and4530-4541 obtain the live anatomy from649 onward. That anatomy provides Index1/Pinky1 points, calibrated skin radii, authorized closing directions, and ordinary proximal capsules.

Finger presenter845-1036 validates exact Handle surface, execution role and origins; cached terminal results return891-898 and non-authorized new solves defer899-902. Stations1106-1283 use the authored selected C0 Handle ratio1183-1192, transform it into world, and project each live Index/Pinky point along the Handle endcap axis1218-1229 to sample Ci/Cp. The prepared exact Handle mesh and those stations feed `PlayerHandSurfaceSeatSolver.solve_prepared`996-1006.

The solver `runtime/player/player_hand_surface_seat_solver.gd:1370` constructs each radial ray direction from **slice center to its anatomical bone point, projected perpendicular to the Handle axis**1382-1396. It orients that direction using the authorized closing direction1397-1429, traces the first boundary1431-1436, and solves the skin-radius tangent target1440-1450. It does not obtain the ray from the old cached anatomical grip center independently of the already-mounted geometry.

The two contact target points define a chord; solver208-236 rotates it toward the Index/Pinky chord by shortest arc. It then shifts the target midpoint toward the anatomical Index/Pinky midpoint240-274. The accumulated displacement is explicitly projected perpendicular to the original endcap axis280-289. This allows radial motion in the C0 plane; it does not preserve C0 at its original anatomical seed point. Input station C0 and no-axial-slide are enforced, not equality to the original reference center.

Acceptance at1083-1091 checks both radial errors within1mm, safety of both authority points, and the optional proximal safety result. There is no palm or thumb contact constraint in this seat objective. Primary wrappers finger777-808 pass `enforce_ordinary_proximal_safety=false`; support wrappers811-842 passtrue. The separate later digit solver is responsible for digit contact. This distinction does not itself prove a visible bug.

Preview5620-5624 forms `final_transform = base_transform * seat_correction_local`, compares original and final C0, rejects axial displacement5660-5669, then writes the final weapon transform5671. It does not compare final C0 with the initial cached grip center. Surface fitting therefore explicitly refines/supersedes the radial mount location while retaining the authored station contract.

## Surviving palm triangulation versus unused target helper

Finger presenter `_build_palm_frame`2496-2550 is called at355 **before** the exact-surface branch369. It reads Hand, Thumb2, Index1, Mid1, Mid2, Ring1, Pinky1. Its center is an average of Hand/Thumb2/Index1/Mid1/Ring1/Pinky1; palm normal uses the cross product of Hand-to-Index and Hand-to-Pinky with fallbacks. This is not the same cached six-joint center used by mounting.

In the active V2 path the palm frame's center feeds contact distance/readiness365-368. That readiness is passed into the exact serial grasp wrappers384/etc and remains a real gate in `_update_exact_surface_serial_grasp_for_path`1527. The palm normal/knuckle-span outputs do not determine the V2 weapon seat center through this path.

`_resolve_finger_target_world_position`2552 remains in the source, but its production caller443 is currently unreachable: exact ForgeV2 Handles continue at417; the remaining loop iterates only `FINGER_IDS`420, and `_finger_uses_plane_curl_path`3620-3621 returns membership in that same FINGER_IDS set for all five digits. Consequently the else containing443 cannot execute for any loop member. Its thumb/non-thumb palm-frame target construction is retained historical code, not an active V2 placement mechanism. This is a static production-call-path conclusion, not a statement that arbitrary external/test dynamic calls are impossible.

## April 11 comparison

Commit `be2f2946bc51d4cf17b19fef6d2be536cb85c696`, authored/committed2026-04-11 21:43:36+0300, inspected using read-only `git show`.

- Historical rig210-219 directly used the finger presenter's cached center and converted it into the hand anchor's local coordinates.
- Historical finger presenter285-289 delegated to `_resolve_hand_grip_center_world_from_cache`;918-940 averaged Thumb/Index root/mid/end positions. This calculation still exists in the current file3268-3290 and is still consumed, now through the midpoint/perpendicular-clamp adaptation.
- Historical equipped presenter78-87 selected the Handle shell slice center,101-106 put held_root at the anatomical alignment offset, and108 shifted mesh geometry by the negative slice center. Thus V1 had a definite positional mounting reference.
- Historical `_finger_uses_plane_curl_path`1100-1101 included only Index/Middle/Ring/Pinky, leaving Thumb able to use the alternative target helper. Current membership includes Thumb too, explaining the now-unreachable helper without assuming source deletion.

These inspected April11 occupied-hand lines do not implement the user's Hand-to-Index/Pinky altitude as the mount center. Root/legacy agent separately trace that exact construction in the unarmed proxy and historical documents. Do not conflate those authorities.

## Bounded next step suggested for discussion

Expose three positions together in the existing diagnostic view/report: anatomical mount reference, mounted C0, and final seated C0, plus Index/Pinky contact targets and an independently derived hand-plane reference. Compare their differences on the difficult saved Handle in normal/reverse grip and each relevant hand role. This establishes whether the reference itself is poor, the final surface fit moves away from a useful reference, or both.

If adapting the old triangle is agreed, use it as a clearly named, character-derived placement reference feeding the existing mount chain, with its own origin ancestry. Keep actual surface clearance separate and explicitly decide whether that reference is a seed, a preference, or a hard invariant before adding another constraint. A third anatomical observation is not automatically a third movement axis and should not silently override authored slide/Roll or support-hand ownership. No implementation is authorized or performed by this report.
