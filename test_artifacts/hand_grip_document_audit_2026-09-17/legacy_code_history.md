# Bounded code-history follow-up: hand triangle construction

Read-only source/history investigation, 2026-09-18. This supplements the full-document coverage in `legacy_coverage.json`, `legacy_nonmatch_coverage.json`, and `additional_root_coverage.json`. Source code, Git history, and application state were not changed. Source excerpts below were examined as targeted implementation evidence, not as whole-file code reviews.

## Finding

The Hand/Index1/Pinky1 right-angle construction does exist in active current code. Its demonstrated purpose is an unarmed/free-hand authoring surrogate. It is distinct from the occupied-hand alignment center and from surface-contact fitting. The evidence supports a narrower implementation and subsequent evolution; it does not support saying all triangulation was lost, nor saying the screenshot's exact construction currently seats occupied hands.

All source paths below are relative to `C:/WORKSPACE/The Will- main folder/the-will-gamefiles/`. Current line numbers refer to the examined working tree.

## Historical sequence and evidence

1. **2026-04-08, `87eaba87`:** examined `runtime/player/player_humanoid_rig.gd` mounting setup. Hand item anchors used exported fixed positions (right `Vector3(-0.0025, 0.0969, 0.0190)`, left `Vector3(0.0025, 0.0969, 0.0190)`) and rotations. The later finger-grip presenter path did not exist in this snapshot. This is a statement about the inspected mounting path, not proof of absence throughout the entire project.

2. **2026-04-11, `be2f2946`:** `runtime/player/player_rig_finger_grip_presenter.gd` `_build_palm_frame` (337 onward) used a Hand/Index1/Pinky1 cross product to determine a palm normal. Its palm center (355–362) was the mean of six points: Hand, Thumb2, Index1, Mid1, Ring1, Pinky1. That is a triangle-derived orientation with an averaged center, not the perpendicular foot from Hand onto Index1–Pinky1. In the same file `_resolve_hand_grip_center_world_from_cache` (918–940) separately averaged cached Thumb and Index root/mid/end points for hand alignment. Thus the displayed phrase `PALM_TRIANGULATION_BONES` alone does not prove the screenshot's center construction.

3. **2026-04-24 design, inventory ID42:** `GDD-and Text Resources/ToDo stuff/Skill Crafter Implementation Stages 2026-04-24.md` lines 86–113 explicitly places the construction under Empty-Hand Surrogate Truth. H, I, and P define the plane; the H-to-I/P altitude gives the contact-center direction and its altitude point becomes the axial center. F-to-H supplies approach/wrist-back context. This is a staged specification, independently followed by code below.

4. **2026-05-02, `766a1393`, 14:44:07 +03:00:** exact center construction implemented in `runtime/combat/combat_animation_station_preview_presenter.gd`, then named `_resolve_unarmed_hand_proxy_local_points` (3964–4004). Lines 3984–3985:

   ```gdscript
   var line_t: float = (hand_world - index_world).dot(index_to_pinky) / index_to_pinky.length_squared()
   var contact_center_world: Vector3 = index_world + index_to_pinky * line_t
   ```

   This is the perpendicular projection of H onto the I–P line. It is not clamped to the segment. Lines 3986–3992 orient the proxy along I–P and build a tip/pommel around that center. The half-length is a clamped 1.5 times the Index/Pinky span. The same commit introduced `_resolve_hand_index_pinky_contact_center_world` in the rig: that separate helper uses the I/P midpoint.

5. **2026-05-02, `8ac56cda`, 15:55:54 +03:00:** `runtime/player/player_humanoid_rig.gd` gained `_resolve_anatomically_seated_hand_grip_center_world`. It takes the prior alignment center, subtracts the I/P midpoint, removes the component along I/P, and clamps the remaining displacement to 0.75 of the I/P span. This is a different construction from projecting H onto I/P. The occupied-hand alignment call was changed to use this seating adjustment. Its name does not establish measured skin contact.

6. **2026-05-09, `7140f6ca`:** origin migration introduced `_resolve_unarmed_hand_proxy_points_state`. The H-to-I/P projection was retained (historical lines 6151–6152) with origin-tracked point state. The current implementation remains at 8336–8379.

History checks were bounded to exact known seams using `git log --all -S` on the relevant paths. The exact `line_t` expression reports `766a1393`; the newer state-function name reports `7140f6ca`. This identifies the visible introduction of these exact implementations in the inspected history, not the first conceivable equivalent anywhere in the repository.

## Active current use, not merely a stranded helper

In `runtime/combat/combat_animation_station_preview_presenter.gd`:

- `_resolve_unarmed_hand_proxy_points_state` reads live Hand/Index1/Pinky1 bone positions at 8345–8350, projects at 8356–8357, and returns local points tagged with `ORIGIN_HAND_GRIP_ALIGNMENT` at 8369–8375.
- `_resolve_hand_authoring_proxy_points_state` calls it at 8382, with explicit fallbacks for missing or coincident geometry.
- `_build_weapon_preview_node` routes `CraftedItemWIP.is_unarmed_authoring_wip(active_wip)` to `_build_unarmed_preview_node` at 4543–4544. That builder calls the proxy resolver at 4574 and configures the unarmed proxy from its points. This is the direct unarmed-preview construction path.
- `_resolve_hand_proxy_default_trajectory_segment_state` calls the same resolver at 1909, transforms points back through the hand anchor at 1917–1920, then records them in trajectory-authoring space at 1924–1929.
- The authoring query invokes that default path at 1871. Its availability guard is 1809. `_is_hand_proxy_authoring_slot_available` (1932–1944) permits unarmed previews, missing held items, or the free nondominant hand; it returns false when support-hand use is active and excludes the occupied dominant hand. This establishes an intentional scope boundary.

In `runtime/player/player_humanoid_rig.gd`, the occupied-hand-related center seam remains separate:

- `_resolve_hand_index_pinky_contact_center_world`, 860–876: live I/P midpoint.
- `_resolve_anatomically_seated_hand_grip_center_world`, 878–895: old alignment center plus a perpendicular, span-limited offset from that midpoint.
- `_resolve_hand_index_pinky_axis_world`, 897 onward: I/P direction.

## Practical implication for the current investigation

The existing construction is reusable as an anatomical reference and an example of an origin-tracked chain. Its presence does not establish a correct occupied-hand surface seat for arbitrary handle geometry. The early averaged centers, I/P midpoint, H-to-I/P altitude point, and measured hand/weapon surface constraints are four distinguishable things.

Likewise, allowing a seat to translate in two independent transverse directions is not the same question as whether three anatomical landmarks or multiple skin-contact constraints determine that seat. The implementation can use three or more constraints while having only two permitted movement directions. A future change should explicitly state which center is an initial reference, which measured surfaces determine the final seat, and which axes are permitted to move. No restoration or code modification was performed in this audit.
