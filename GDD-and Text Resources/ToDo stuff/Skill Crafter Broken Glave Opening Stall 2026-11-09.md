# Skill Crafter Broken Glave opening stall — 2026-11-09

## Scope

After the Forge V2 Done/S confirmation and pure-navigation fixes, investigate why opening Skill Slot 1 of the newly saved `Broken_Glave_v1` freezes the program long enough for Windows to offer Wait/Close. User closed the game. Preserve the actual saved weapon/library, established grip mechanics, body motion and playback. This is opening/setup investigation, not a new F/Save workflow or mesh simplification pass.

## Saved source inspected

- Real player library: `user://forge/player_wip_library_state.tres` (39,242,662 bytes at inspection).
- WIP name `Broken_Glave_v1`, ID `player_wip_1794179018.538_16`.
- Skill Slot 1 contains two stored nodes (hidden baseline plus visible Node 1), no prepared pose/runtime track, and `authoring_pose_initialized=false`. It is not an existing long animation to unpack.
- Handle uses Medium rombus, approximately 3.50509 m path, 10 full turns (0 to 3600 degrees), 48 profile vertices.
- Full saved runtime mesh: 53,271 vertices / 106,594 triangles.
- Protected Handle: 34,608 vertices / 69,212 triangles.
- Saved grip wrapper is present, with three target meshes of 11,532 triangles each; saved build time 486.006 ms. These counts do not by themselves establish the startup bottleneck.

## Investigation plan

Use the actual saved WIP through Skill Crafter UI open/weapon selection/Skill 1 selection. Log and flush stage timestamps before synchronous calls so a stalled run retains its last reached stage. Enable existing opening latency metadata. Observe post-open frame gaps and acquisition state separately; a displayed pose is not proof of accepted grip. No F, Save, pose edits or source-library writes are needed. Confirm source file hash remains unchanged.

Owners being traced: `combat_animation_station_ui.gd` selection/baseline lifecycle; `combat_animation_station_preview_presenter.gd` scene setup; `player_equipped_item_presenter.gd` held-item construction; existing saved-wrapper source/preparation. Changes, if justified, must address measured redundant preparation or blocking work without bypassing validation or changing grip behavior.

## Results

### Reproduced cause

- Rendered actual-WIP baseline: weapon selection took 8.686 seconds. Skill Slot 1 then failed to return for over 73 seconds before the diagnostic process was stopped. No grip-owner configuration had begun.
- A second diagnostic with flushed subclass tracing located the stall inside `PlayerEquippedItemPresenter._append_visual_mesh_proxy_samples`, called while building the held weapon. Test-only wrappers call production `super` without changing behavior.
- The old bulk path compared every accepted vertex/triangle centroid against all previously accepted positions, using a linear search. This Glave sends 53,271 vertices plus 106,594 triangle centroids through that growing search before downsampling. This is quadratic collision-proxy setup, not a grip solve or an invalid saved skill.

### Narrow production change

- `runtime/player/player_equipped_item_presenter.gd`: bulk mesh sample uniqueness uses build-local 1 mm spatial buckets and 27 neighbour lookups. The exact existing 0.5 mm distance predicate remains unchanged.
- Keep vertex/centroid ordering, first accepted representative, grip-relative meter coordinates and origin records, clearance expansion, extrema, and final stride/sample selection unchanged. Only accepted points enter the index. Small final lists still use the existing linear helper.
- No grip algorithm, anatomical rule, animation, Forge mesh, persisted asset, or simplification change.
- Implementation uses documented Godot 4.7 [Dictionary](https://docs.godotengine.org/en/4.7/classes/class_dictionary.html) and [Vector3i](https://docs.godotengine.org/en/4.7/classes/class_vector3i.html) facilities.

### Fresh rendered result

- `godot_runs/broken_glave_skill_open_after/report.json`, `stages.jsonl`, `engine.log`, and `grip_chronology.jsonl`; exit 0, no script errors.
- Collision mesh sample preparation: **1,051.493 ms**, adding 134 surface samples. The existing cap is a stride target of 128 plus extrema, not an absolute total cap; this behavior was preserved.
- Skill Slot 1 selection: **4,829.657 ms**, successfully returned to the editor. Background acquisition then completed during observation; a live hand/weapon relationship was present by 5,562 ms after selection.
- This is opening/binding evidence, **not full-hand grip certification**: the solver's `grip_accepted` and `actual_3d_grip_verified` remain false; status is `preview_applied`. Grip mechanics were deliberately left unchanged. No F/Save test was needed for this lookup-only change.
- Actual player library SHA256 was identical before and after the successful run: `de93eec209f5dd4c11ece510622ed95ace01d3f964348f151551285e2c3e6c36`. No saved weapon or skill was altered. Test processes closed; user editor retained.

### Remaining opening cost, separate from the fixed stall

Weapon selection still took **8,904.074 ms**, including **7,412.444 ms** in `seed_station_geometry`. The saved profile lacks `material_runtime_data_resolved=true`, so `ensure_baked_profile_snapshot` currently rebakes the runtime contract instead of enriching the existing cached geometry. This is a future focused opening optimization; do not change the grip black box or restart mesh simplification to address it.

### Verification tooling

- `tools/diagnose_broken_glave_skill_open.gd`: read-only real-WIP rendered opener, source hash and legacy-migration preflight, stage-flushed timing, bounded post-open observation. Its observation criterion explicitly distinguishes a live relationship from a certified grip.
- `tools/verify_weapon_body_proxy_sampling.gd`: **19 checks / 0 failures**, exit 0. Old linear lookup oracle versus spatial lookup preserves exact ordered output through the shared production pipeline. Covers duplicate points, exact/near merge distances, negative cell boundaries, three-axis neighbours, nontransitive rejected intermediates, indexed/nonindexed surfaces, grip origin/scale/clearance, seeded output, extrema and downsampling. Report/log: `godot_runs/weapon_body_proxy_sampling.json` and `.log`.
- Direct saved-Glave sampling independently completed in **1,076.031 ms**, adding the same 134 surface samples. Source-library hash unchanged. The unbounded old algorithm was not rerun on the full Glave for a complete duration; the before timing remains a lower bound from interrupted runs.
- Focused production diff whitespace check passed. No Git commit or push performed in this follow-up.
