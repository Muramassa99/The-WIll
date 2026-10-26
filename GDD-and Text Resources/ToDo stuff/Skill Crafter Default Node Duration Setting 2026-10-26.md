# Skill Crafter default node duration setting

2026-10-26, Europe/Bucharest. Narrow implementation requested during the Project TODO expansion pass. Independent weapon-facing roll was subsequently implemented separately under SC-07; camera behavior, broader grip faults and anatomy work remain deferred.

## Agreed behavior

- A user-selectable default travel time for newly added motion nodes, initially **1.0 seconds**.
- Change it once, then continue authoring multiple nodes at that duration; for example set 0.2 seconds, add three nodes, then select another default for subsequent nodes.
- Existing motion nodes retain their authored durations. The existing per-node duration field remains a local override and does not change the default.
- Remember the preference across station/game sessions, independently of weapon or skill saves.
- Expose the numeric setting inside Skill Crafter and, following the user's later same-day instruction, a vertical on-screen control inside the viewport near its right edge, vertically centered.
- Authoring duration bounds are now **100–2000 ms**, in **10 ms** increments, for both new-node defaults and deliberate per-node timing edits.

## Viewport control — later same-day addition

The viewport bar, its numeric box and Editor Settings operate on the same persistent **new-node default**. They do not retime the selected existing node. The existing per-node timing field still owns local overrides.

- The slider handle moves continuously, without snapping its physical position to duration steps. Only the numeric result is rounded to 10 ms.
- A smooth, monotonically increasing curve passes through 100, 250, 500, 1000 and 2000 ms at the bottom, quarter, middle, three-quarter and top positions. Sensitivity increases continuously upward: constant pointer travel changes the number slowly near the bottom and faster near the top. All 10 ms values remain available.
- The upper arrow adds 10 ms; the lower subtracts 10 ms. Press applies one step immediately. Holding waits **200 ms**, then repeats. The initial implementation uses **50 ms per subsequent step** as the stated implementation choice; the user specified the initial delay, not a repeat cadence.
- Release, leaving the held arrow, hiding/leaving the editor, lost window focus or reaching the boundary stops repetition. UI repeat timing ignores gameplay time scaling.
- The numeric box displays milliseconds and supports direct entry. Settings retains its seconds-labelled field with the same value converted appropriately.
- Widget changes update memory/UI immediately. Persistence is grouped at the end of a drag, held-arrow operation or numeric entry, with close/teardown flushing pending changes. No skill pose, grip solve or replay invalidation is triggered by adjusting the default.
- Only the control's footprint consumes mouse input; the surrounding viewport remains available. A camera orbit begun outside it still ends if RMB is released over the control.

Broader UI direction: progressively move essential controls from the right inspector/debug panel into the workspace. Once those essentials are available, the panel may become optional Advanced or developer UI. **Do not hide that panel yet** or implement the other proposed controls by implication.

Future playback timing is to use a percentage with attack-speed modifiers. Keep that distinct from authored durations: this addition does not implement gameplay modifiers, change prepared sample rates, or alter the separate 160 ms entry rule. The existing preview-speed multiplier is not new attack-speed functionality.

## Owners and scope

Production paths relative to `The Will- main folder/the-will-gamefiles`:

- `core/models/combat_animation_editor_settings_state.gd`: small persistent editor preference resource, using the existing `PersistentResourceStateIO` ownership pattern used by Forge preferences. Storage: `user://settings/combat_animation_editor_settings.tres`.
- `runtime/combat/combat_animation_station_ui.gd`: **Editor Settings → New Node Duration (s)** in the right inspector. The R/Add workflow and newly authored continuation after a grip-style bridge read this preference. A newly built node without a source also uses it.
- `runtime/combat/combat_node_duration_control.gd`: native VSlider, buttons, numeric field and repeat timer; visual mapping and interaction only. The UI remains the preference/persistence owner.
- `core/models/combat_animation_motion_node.gd`: shared authored-duration bounds/step and matching exported editor hint. Existing stored timing normalization is not widened into a migration.

The original 0–2 second fields were superseded by the user's **0.1–2 second** instruction. Explicit Duplicate still copies the source duration. A generated grip-flip bridge keeps its existing inherited timing rule; its following new editable node gets the new-node default. Reset/default-pose timing and the separate **160 ms current-pose entry** are unchanged. No saved weapon data is migrated or rewritten by changing this preference. Legacy out-of-range per-node timings can be displayed honestly; a deliberate duration edit applies the new limits.

A settings write failure restores the previous value and reports the failure. Changing this preference does not dirty/reprepare the current skill, move the camera, or acquire grip.

## Verification

Initial numeric-setting verification (before the later viewport addition): `tools/verify_combat_editor_node_duration.gd` passed **26/26 checks** on Godot 4.7; report: `C:/WORKSPACE/godot_runs/sc_node_duration_20261026/run1/results.json`.

The focused fixture drives the actual numeric-control signal, R insertion, local duration setter and duplication. It verifies three successive 0.2-second nodes; a local 0.65-second override; the next R still using 0.2; changing the default to 0.4 without changing existing nodes; subsequent nodes using 0.4; explicit duplication retaining the source duration; inherited bridge timing and new continuation timing; disk persistence and recreated UI display; no skill dirtying from the preference; and unchanged 160 ms entry.

The fixture substitutes already-captured endpoint and grip-frame data. This proves settings/timing behavior, not live grip, camera, anatomy or equipped animation correctness. No real user weapon/skill files were changed and no full gameplay run was required. User visual acceptance of the new inspector section remains pending. No Git operation was performed.

Viewport addition completed: **71/71 checks passed** in a fresh rendered Godot 4.7 run, report `C:/WORKSPACE/godot_runs/sc_node_duration_20261026/viewport6/results.json`; screenshot `duration_control.png` in the same folder was inspected. This exercises the real editor layout and native controls with injected viewport input, while retaining the prepared-pose/geometry fixture described above. It is not a full gameplay or live-grip verification.

The extended checks cover all five curve anchors, continuous increasing sensitivity, reachability of all 191 numeric values, unsnapped slider travel/release, settings synchronization, numeric entry, both held arrows, delayed repeat, release and boundary stops, hiding/reopening and lost-window-focus cancellation, grouped disk writes and legacy-duration preservation. The curve inverse's measured maximum error was 0.00232 ms. The test left no game process running; the existing editor remained open.

The hide/reopen check exposed a native Button press-state edge case. Arrows now use `ACTION_MODE_BUTTON_PRESS` with `pressed`, so a press immediately triggers a step even after the control was hidden during a previous hold. Release still ends the repeat. This is covered by the passing focused run.

Later user acceptance: holding works nicely and the slider moves as expected, including its greater precision at the lower end. Two requested cosmetic changes followed: values are now aligned above the indication ticks, and the value box is sized for four digits plus padding. The 71-check duration run preceded those cosmetics; later rendered weapon-facing checks displayed the revised widget and screenshots were inspected. Dedicated acceptance of the final cosmetic layout remains for the user.

## Sources

- Current user clarification, 2026-10-26: adjustable persistent default in SC; current 1.0 comes from settings; local per-node overrides; later main-UI slider.
- [Project TODO](Project%20TODO.md), UI-02 settings ownership; SC-03 qualified acceptance and SC-07 separately implemented control.
- [Grip-facing/camera feedback](Skill%20Crafter%20Grip%20Facing%20And%20Camera%20Control%20Plan%202026-10-26.md): the initially unfinished settings request was clarified as duration, not a camera toggle.
- [Godot 4.7 SpinBox](https://docs.godotengine.org/en/4.7/classes/class_spinbox.html) and [ResourceSaver](https://docs.godotengine.org/en/4.7/classes/class_resourcesaver.html): native numeric entry and resource persistence, checked before implementation.
- [Godot 4.7 VSlider](https://docs.godotengine.org/en/4.7/classes/class_vslider.html), [Range](https://docs.godotengine.org/en/4.7/classes/class_range.html), [Curve](https://docs.godotengine.org/en/4.7/classes/class_curve.html), [Timer](https://docs.godotengine.org/en/4.7/classes/class_timer.html) and [BaseButton](https://docs.godotengine.org/en/4.7/classes/class_basebutton.html): continuous native slider, smooth mapping and held input, checked before implementation.
