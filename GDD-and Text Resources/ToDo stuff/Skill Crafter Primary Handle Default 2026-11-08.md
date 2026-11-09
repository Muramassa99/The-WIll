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

## Handle coordinate mode clarification — 2026-11-09

Latest user decision supersedes the old +/-7% midpoint window for selecting the displayed Handle scale:

- If the plane through the weapon's intrinsic centre of mass, perpendicular to the Handle endcap axis, intersects the Handle span, display **-100% to +100%** (numeric -1 to +1), with zero at the Handle midpoint.
- If that plane falls outside the Handle span, display **0% to 100%** (numeric 0 to 1), from Pommel-side to Tip-side Handle endcap.
- This is binary span containment, including the end planes. It is not a handle-length category or proximity-to-midpoint test. Existing COM projection supplies the check; do not clamp an out-of-span projection before classifying it.
- Default single-hand grip remains normalized **0.5** in Node 0/Node 1/Reset. It reads **0** in the centred display and **0.5** in directional display. Saved normalized coordinates and established grips do not move merely because the display mode changes.
- **Final user clarification: preserve the same metric hand clearance at both physical ends.** -100/+100 name the same endpoints as 0/100. Hand size and padding determine the permitted physical interval once; display conversion merely relabels it. Thus a 10–90 directional interval displays as -80–+80. The intervening same-numerical-margin interpretation (10–90 -> -90–+90) was implemented/tested, then explicitly superseded and removed after the user clarified the physical intent. No halving of the actual end clearance remains.

Implementation: `ForgeV2WipCompatibilityAdapter.refresh_handle_coordinate_display_mode` is shared by fresh profile construction and `ForgeService.get_cached_profile_for_runtime` on private cached-profile copies. It updates only coordinate mode/authority/zero fields from valid finite authoritative COM/span data. Keep original cached metadata available for existing legacy schema-1 coordinate interpretation; schema-2 normalized positions are unchanged.

The pre-existing `primary_grip_center_balance_valid` also controls automatic two-hand spacing. That separate layout verdict is deliberately unchanged by this display-mode correction; it no longer selects the Forge V2 display scale. Intrinsic COM, Tip/Pommel polarity and grip solving remain with their current owners.

End limits use the original two-argument `PrimaryGripSeatResolver.resolve_hand_end_bounds(handle_length, hand_span)`. The temporary mode parameter, half-margin calculation and caller mode arguments were removed. Skill Crafter live bounds, saved-replay bound validation and equipped grip layout consume the same normalized physical limits. UI maps those bounds through the existing display conversion and rounds inward. No separate UI-only clamp, no changed hand dimensions, no new grip algorithm.

`Broken_Glave_v1` has COM projection 0.5750595694, which is inside its Handle span and therefore now receives centred display on refresh. Its stored player-library file is not rewritten by the refresh.

Fresh verification:

- Weighted mass/orientation contract passes with the two old off-centre-inside-Handle expectations updated to the new rule. Fresh pipeline checks preserve mass, mirror/Tip/Pommel behavior, Handle point-order invariance and directional mode for COM outside the span. Log: `godot_runs/handle_display_weighted_contract_20261109.log`.
- `verify_handle_display_mode_classification.gd`: final metric-clearance rerun **53 checks / 0 failures**, including exact end-plane inclusion, near-end inside/outside cases, sampled-path midpoint, invalid/unknown COM inputs, cached-profile isolation, unchanged authored coordinates, identical physical bounds in both displays, signed inverse mapping to the same seats, and saved-replay agreement at/beyond both ends. Actual saved Glave resolves to `balanced_signed` from COM ratio 0.5750595694. Source library hash unchanged: `de93eec209f5dd4c11ece510622ed95ace01d3f964348f151551285e2c3e6c36`. Report: `godot_runs/handle_display_mode_classification.json`; final log: `godot_runs/handle_display_mode_classification_metric.log`. The earlier 48-check numeric-margin run is superseded.
- `verify_solved_replay_end_bounds_scale.gd`: final metric-clearance rerun **676 checks / 0 failures**. Its first run exposed stale UI assertions expecting end-bound quality problems to block playback, while current production deliberately reports warnings. Updated only that verifier's UI expectations to require readable playback, the appropriate warnings and unchanged data. Physical-boundary/malformed-data assertions remain intact. No production warning policy changed. Final log: `godot_runs/handle_display_replay_bounds_metric_20261109.log`.
- No rendered-game/grip-quality run for this coordinate/limit change. No player save rewritten. No Git/index operation.
