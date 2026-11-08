# Primary handle target default — 2026-11-08

- User requests 0.5 (handle midpoint) instead of 0.2. The current test weapon's
  lower usable boundary is approximately 0.2222, so 0.2 starts outside it.
- Changed `DEFAULT_GRIP_SEAT_SLIDE_OFFSET` to 0.5 in
  `core/models/combat_animation_motion_node.gd` and
  `core/models/combat_animation_retarget_node.gd`.
- Existing weapon geometry seeding, new-node construction, Reset and preset
  fallback already consume these defaults. Authored values carried forward to
  subsequent nodes are not overridden. Secondary hand and unarmed defaults,
  handle-end restrictions, grip solver and balanced-coordinate display stay as is.
- Explicit serialized positions remain as stored. Old resources that omitted
  their default-valued field now inherit 0.5. No save-file migration was added.
- Official reference reviewed: Godot 4.7 Resources documentation,
  https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html.

## Verification limits

- `git diff --check` passes. Existing retarget resolver verifier run; output in
  `C:/WORKSPACE/combat_retarget_resolver_results.txt`.
- Existing baseline/reset diagnostic completed with both Reset calls successful.
  Its fake weapon has no valid primary-grip profile and geometry-seed checks
  are false; this is not proof of live acquisition.
- Existing handle-coordinate verifier hit two stale replay-boundary assertions:
  it expects a 0.002 mm overrun to fail, whereas the current replay allowance is
  0.05 mm. That path uses explicit anchor positions, independent of these defaults.
  Its printed PASS is not a clean overall pass. No tolerance was changed.
- No new tests or rendered-game run were added for this two-constant change.
  No Git/index operation.
