# The Will - Project Orientation and Authority Map

Created: 2026-07-22
Last full orientation pass: 2026-07-22
Scope root: `C:\WORKSPACE`

## Status And Purpose

This is the durable front door to The Will's project knowledge.

It exists to give a new agent one reliable orientation pass before work begins:

- what the project is trying to become;
- how the user wants work approached;
- which files answer which kinds of questions;
- which laws are global and which belong only to one system;
- what is live, historical, planned, sunset, or still undecided;
- where to go for the full source instead of expanding this file forever.

This file is an index and interpretation layer. It is not:

- a replacement for the linked source documents;
- an SPS handoff;
- a verifier result;
- proof that a historical implementation claim is still live;
- permission to implement every system mentioned here;
- a new naming or exported-knob tracker.

Anything under `C:\WORKSPACE` may be related to The Will, even when it is misplaced. File location is therefore a clue, not authority by itself. Content, date, explicit supersession, current user direction, code, and verification decide how a file should be used.

## Fast Start For A New Agent

Before changing anything:

1. Read this file completely.
2. Read the user's current instruction. It defines the active scope and may supersede older design wording.
3. Read the newest file in [`SPS/`](<SPS/>). At this orientation pass, the newest is [SPS_2026_06_02_00-46.md](<SPS/SPS_2026_06_02_00-46.md>).
4. Treat the SPS as a focus/resume slot, then reconcile it with the current worktree. The June 2 SPS is behind later June/July Forge V2 work.
5. Run `git status` before touching the active project. Existing changes belong to the user unless proven otherwise.
6. Read the exact code around the requested system before trusting old prose.
7. Open the task-specific source links in this file. Do not load unrelated systems merely because they are documented.
8. For Godot API or engine-behavior questions, use official version-matched Godot 4.7 documentation before implementing. The local `godot_info` set was written for 4.6/4.6.1.
9. Decide the narrow change, its owners, dependencies, and focused verification before editing.

Current preparation state: no implementation task has been authorized by this orientation work. Wait for the user's next scope instead of treating a historical `Next Focus` as automatic permission.

## The Project In One View

The Will is a hub-based, seasonal, instanced dungeon game with deep player creation at its center. It is not intended to be an unbounded open-world MMO. The structure combines:

- a shared social hub/town;
- private or instanced crafting workspaces;
- 99 named expedition-floor layouts;
- seasonal remapping of floor difficulty and reward quality;
- bounded large-floor exploration, gathering, PvE combat, secrets, and extraction;
- crafted equipment and authored behavior as the player's main expression of power.

The three project pillars are:

1. **People matter** - coordination, contracts, reputation, social knowledge, and crafting identity matter.
2. **Knowledge matters** - maps, enemy patterns, floor familiarity, discoveries, and accumulated understanding matter.
3. **Creation matters** - power is made; crafted gear, provenance, and player-authored behavior matter more than finding a finished answer as a drop.

The intended loop is broadly:

```text
explore / fight / gather
-> return with raw matter and knowledge
-> process material
-> author equipment
-> author or assign behavior
-> test the WIP
-> finalize/name/export
-> equip, trade, and return to the floors
```

The world and narrative should feel older, larger, and more informed than the player. The town is not waiting inertly for the protagonist. Information may be social, indirect, missable, or gradually recontextualized. Systems should help the world feel like it knows more than it immediately explains.

The project is deliberately built as systems on systems. Small authoritative units become models; models feed resolvers; resolvers feed services and runtime owners; those systems become building blocks for larger systems. Modularity is therefore functional, not aesthetic. A local shortcut that destroys a future seam can be more expensive than a slower correct implementation.

Primary vision sources:

- [PROJECT_OVERVIEW_AND_SCOPE - Copy.md](<UPLOADED/PROJECT_OVERVIEW_AND_SCOPE - Copy.md>) - broad project structure and pillars; exact implementation/status sections are a March 2026 snapshot.
- [thought process .txt](<UPLOADED/thought process .txt>) - long-form evolution of the project's design reasoning.
- [The Will game into plan.md](<UPLOADED/The Will game into plan.md>) - opening narrative, quest, and world-ignition intent.
- [the GAME FEEL.txt](<UPLOADED/the GAME FEEL.txt>) - atmosphere and experiential direction. It duplicates `immersive world narative.txt`.

## Authority Model

There is no safe single hierarchy for every question. Project intent, current implementation, and engine behavior have different authorities.

| Question | Strongest authority | How to use it |
| --- | --- | --- |
| What does the user want now? | Current user instruction | This sets scope and can revise older design intent. Do not invent beyond it. |
| What currently exists or executes? | Current code plus a focused fresh run | Code is king when doing. A passing old result is only historical evidence. |
| What should be resumed after a handoff? | Newest SPS, then current code/worktree | SPS preserves focus; it does not prove implementation or imply a commit. |
| What is the current milestone/design direction? | Relevant `ToDo stuff` file and newer task-specific notes | Reconcile dates, specificity, user corrections, and code. |
| What is the broad world/system intent? | `UPLOADED` knowledge base | Treat implementation-status language inside old documents as time-stamped. |
| Why does an older seam exist? | Sunset implementation memory, savepoints, old code, logs | Use for archaeology, not as an automatic resume instruction. |
| How does Godot behave? | Official Godot 4.7 documentation and observed 4.7 behavior | Local 4.6/4.6.1 notes are search aids, not exact current API authority. |
| What are live names, IDs, and exported values? | Current code plus current user/task direction | The old naming and knob registries are sunset and receive no new entries. |

### Conflict Resolution

When sources disagree:

1. Identify whether each claim is design intent, current code truth, verifier truth, historical explanation, or future proposal.
2. Identify its date and system boundary.
3. Prefer the current user's explicit direction for intent.
4. Prefer current code and a fresh focused run for what actually exists.
5. Prefer newer, narrower task-specific design over older broad wording when the two clearly address the same decision.
6. Keep system-local laws local. A Forge V1 law does not silently become a Forge V2 law.
7. Report the conflict. Do not force documents and code to appear consistent.
8. If a core rule is still missing, use `TODO` or `NEEDS_DECISION` rather than guessing.

Code being live does not automatically make it the intended final design. A document describing intent does not automatically make that behavior implemented. Preserve that distinction in plans, patches, verification, and reports.

## Collaboration And Working Contract

The user is deliberately front-loading context so it only needs to be explained once. Continuity is part of correctness.

These rules are collaboration aids, not a demand for paralysis. Use judgment freely inside the requested scope; make assumptions explicit when they matter; and bring material design choices back to the user before they harden into architecture.

### Pace And Shape Of Work

- Prefer precision, maintainability, and correct ownership over speed.
- Work along a mostly linear timeline. Avoid creating cleanup or reimplementation work on purpose.
- Do not enter a `try fix -> fail -> force harder -> fail` loop.
- If an approach repeatedly fails, stop increasing force. Reinspect assumptions, ownership, data flow, engine behavior, and the smallest reproduction.
- Do not patch symptoms on top of symptoms merely to produce a visually acceptable outcome.
- The project may take months. A clean backend is more valuable than a fast impressive surface.
- The user may explain a large concept once and then expect it to remain available through documentation and handoffs.

### Scope Rigidity

- "Rigid" means disciplined execution of the requested scope, not rigid coupling between systems.
- Do not invent core mechanics, visible class systems, convenience subsystems, content, polish, or new abstractions that were not requested.
- Do not rename files, folders, classes, IDs, or established authored-unit terminology unless explicitly asked.
- Do not collapse distinct lifecycle objects into one generic type.
- Do not widen a narrow implementation into downstream systems because the future relationship is visible.
- Protect real seams early, but do not build future systems before their slice is needed.
- If a decision would materially change the requested outcome, stop and ask instead of silently choosing.

### Investigation And Editing

- Read current code before changing it.
- Find the upstream owner/root cause before selecting a fix location.
- Prefer one authoritative owner and thin presenters/adapters over duplicated hardcoded truth.
- Preserve existing user changes. Do not revert, clean, reformat broadly, stage, commit, or push unless the user asks for that action.
- "Now we know better" means fix forward. Do not restore an older state simply because it is familiar.
- Inspect the dirty worktree and work around unrelated changes.
- Call out older systems touched, dependencies that must move with the change, and possible domino effects.
- For engine work, check the documented native Godot path before building a custom replacement.

### Verification And Reporting

- Use the smallest verifier that proves the requested behavior and the nearest relevant regressions.
- Distinguish exactly:
  - `verified in the current run`;
  - `recorded historical result, not rerun`;
  - `not tested / uncertain`.
- A clean parser/editor diagnostic is not runtime proof.
- Never translate an engine banner-only log into a behavior pass.
- After meaningful work, report what changed, what did not, what was verified, what remains uncertain, and the narrow best next step.
- Every meaningful implementation slice should leave code truth, verifier truth, and tracker/handoff truth. Use a current task note and/or a new SPS when a real handoff is being made. Never append new work to the sunset trackers.

### Godot Execution

The active engine folder is [`C:\WORKSPACE\Godot_v4.7`](<../Godot_v4.7/>), containing:

- `Godot_v4.7-stable_win64.exe`
- `Godot_v4.7-stable_win64_console.exe`

Both may be used. Select the executable based on the implementation/test need. The console build has a known Windows failure mode when too many things are pushed through it at once. Keep substantial console operations moderated and generally run one meaningful Godot process at a time.

## Architecture And Data Laws

### Collaboration Mindset

The project is understood from the finished machine backward and built from authoritative roots upward:

- define end-state laws early;
- keep past, present, and future relationships visible;
- make the present slice actually work;
- distinguish true roots from optional implementations;
- prefer shared roots to duplicate solutions;
- resolve architecture before polish;
- protect future seams without prematurely implementing the future.

Source: [COLLABORATION_MINDSET.md](<UPLOADED/COLLABORATION_MINDSET.md>).

### Dependency Direction

The intended dependency direction is:

```text
definitions / atoms
-> models / state
-> resolvers
-> services
-> runtime controllers / presenters
-> scenes and UI
```

Higher presentation layers may consume lower truth. Lower truth should not depend on UI or scene convenience. Scene parentage is not automatically semantic authority.

### Lifecycle Separation

Keep these concepts distinct:

```text
raw world drops
-> processed ForgeMaterialStack data
-> CraftedItemWIP authoring state
-> TestPrintInstance / testing state
-> FinalizedItemInstance / named world-legal item
```

Do not collapse acquisition, processed inventory, mutable authoring, testing, and final identity. Finalization/naming is a real export boundary with provenance and world legality, not only a label change.

Gameplay should consume baked profile/state, not raw forge cells or live CSG authoring nodes.

### Materials And Context

- Materials are universal matter definitions.
- Equipment context, slot role, and use context are separate layers.
- Material truth should not be duplicated per equipment class.
- Fixed roles may exist in the backend, but do not invent player-visible class systems without design authority.

### Resource Law

- Resources hold structured data; they do not become control-flow owners.
- Treat project-shared `.tres` files as immutable definitions at runtime.
- Separate definition, mutable runtime state, and persistence/save representations (`Def / State / Save`) where those lifetimes differ.
- Duplicate mutable state deliberately instead of mutating a shared loaded resource.
- Services/resolvers may consume Resource data; operational flow belongs to a suitable runtime owner.

Sources:

- [THE WILL - .tres RESOURCE RULES.md](<UPLOADED/THE WILL — .tres RESOURCE RULES.md>)
- [THE WILL - RESOURCE USAGE RULES](<UPLOADED/THE WILL — RESOURCE USAGE RULES>)

### Authoring And Runtime Truth

- Preserve authored truth when runtime legality or presentation requires derived data.
- Compile/resolve a duplicate or effective form instead of mutating the player's authored chain behind their back.
- Preview, bake, and runtime should share authoritative data paths where their responsibilities overlap.
- Generated bridges, legality corrections, and presentation helpers must remain distinguishable from authored content.

## Workspace Map

All paths below are related to The Will, but not all are live authority.

| Path | Meaning | Authority / caution |
| --- | --- | --- |
| `C:\WORKSPACE` | Git/workspace root and broad evidence field | Related files can be misplaced. Search broadly, classify carefully. |
| [`GDD-and Text Resources`](<./>) | Documentation and reference root | This file belongs here because it spans all documentation layers. |
| [`UPLOADED`](<UPLOADED/>) | The "galaxy": broad canon, design evolution, laws, old savepoints, and references | Broadest context. Many exact implementation claims are historical. |
| [`ToDo stuff`](<ToDo stuff/>) | The "solar system": milestones, major features, and more focused design | More precise than `UPLOADED`; still reconcile with date/code. |
| [`SPS`](<SPS/>) | The "planet": current work/handoff snapshots | Newest filename is the resume slot. SPS is not a commit or verifier. |
| [`The Will- main folder/the-will-gamefiles`](<../The Will- main folder/the-will-gamefiles/>) | Active Godot 4.7 project | Primary implementation authority. Scope code searches here. |
| [`Godot_v4.7`](<../Godot_v4.7/>) | Active regular and console engine builds | Console use should be moderated. |
| [`godot_info`](<../godot_info/>) | Curated Godot concepts and offline official-doc mirror | Built around 4.6/4.6.1; useful for navigation, stale for exact 4.7 API claims. |
| [`godot_runs`](<../godot_runs/>) | Logs, result snapshots, generated verifier state | Evidence with timestamps, not design canon. Many banner-only logs prove only process startup. |
| Root `*_results.txt` files | Older verifier result snapshots | Historical unless freshly rerun against current code. |
| [`test_artifacts`](<../test_artifacts/>) | Generated test Resource state | Test evidence/data, not player or design authority. |
| [`DEBUG-LOGS`](<../DEBUG-LOGS/>) | Historical audits, backups, logs, and a misplaced handoff | Useful archaeology. Do not resume from it without reconciliation. |
| [`workspace debug home`](<../workspace debug home/>) | Older debug-home mirror/plans | Historical archive. No current resume pointer survives there. |
| [`old`](<../old/>) | May combat/player script snapshots | Reference/archive only, not live drop-in code. |
| [`godot_upgrade_probe`](<../godot_upgrade_probe/>) | Full Godot 4.7 migration probe copy | Can pollute broad code searches; live project wins. The two root combat-law files are exact duplicates of the live copies. |
| [`Test Models`](<../Test Models/>) | Upstream Josie showcase/source package | Reference/recovery source; live project's Josie assets/scenes are runtime authority. |
| [`images and refferences`](<../images and refferences/>) | Visual references, screenshots, elemental chart, and recording | Interpret per task; not self-executing design authority. |
| [`video_frame_samples`](<../video_frame_samples/>) | Extracted frames from a reference/debug recording | Historical visual evidence. |

No `AGENTS.md` was found anywhere in `C:\WORKSPACE` during the 2026-07-22 pass. The `.agents` directory was empty. Agent behavior is therefore governed by current user instructions and the linked rule documents, not an undiscovered repository `AGENTS.md`.

### Misplaced Or Duplicate Material Already Classified

- [AGENT_HANDOFF_2026-05-03.md](<../DEBUG-LOGS/AGENT_HANDOFF_2026-05-03.md>) is a misplaced historical handoff with still-useful user rules: read code, fix upstream, do not revert, and do not commit/push without user direction. Its old task pointer is superseded.
- Root documentation copies of `player_controller.gd`, `player_humanoid_rig.gd`, and `player_aim_solver.gd` are April parallel snapshots, not current live scripts. The old aim solver's referenced live path no longer exists.
- `Dropin asset location/transform_gizmo.glb` is an exact duplicate of the live scene asset. The live project path is operational authority.
- The documentation-root `Josie` package is upstream/reference material. The live `Josie/josie.tscn` is newer and contains additional project animation work.
- The `godot_upgrade_probe` combat law/plan Markdown files are byte-identical copies of the active project files.

## Current System Landscape

The active project is organized around:

- `core`: definitions, atoms, models, resources, and resolvers;
- `services`: packaging/operation seams such as Forge services;
- `runtime`: player, Forge V1, Forge V2, combat, inventory, UI owners, and presenters;
- `scenes`: world and UI composition;
- `tools`: focused verifiers, diagnostics, and migration/audit tools.

Systems currently represented in code include material processing, inventory/storage, Forge V1, Forge V1 Adaptive Outer Shell, Forge V2, WIP/test-print paths, disassembly/salvage, combat/Skill Crafter authoring and playback, player rig/IK/camera work, and a large focused verifier suite. Presence does not mean every system is complete or currently in scope.

## Forge V1, Forge V2, And The Shared Pond

### The Current User Decision

- Forge V1 is usable.
- Forge V2 is in progress and is the main development focus.
- V1 may evolve when block-based authoring is useful, especially for accessories, armor, or other asset work.
- V1 may later be removed, reshaped, specialized, or retained beside V2. This is intentionally undecided.
- V1 and V2 should inhabit one coherent ecosystem, use compatible downstream seams where appropriate, and remain cleanly separable.
- V1 must not constrain V2's CSG architecture.
- V2 must not erase V1's useful block-authoring role by assumption.

```text
Forge V1 structural authoring ------\
  -> optional Adaptive Outer Shell    \
                                       -> shared WIP/library/testing/future bake ecosystem
Forge V2 CSG authoring --------------/
```

"Same pond" does not mean "same geometry truth." It means clean coexistence, interoperable contracts, and the ability to prune or reshape either system without breaking unrelated consumers.

### Forge V1 Scope

Forge V1 is the block/cell structural authoring system. Its optional Adaptive Outer Shell is a refinement child of V1 structural truth before testing/export.

Enduring V1-local laws include:

- different shape tools resolve footprints into one V1 structural commit path;
- previews should show the actual affected cells/region;
- authored structure and optional shell refinement remain separate;
- baseline/restore and patch identity must be explicit;
- no-refinement fallback preserves the V1 structural result.

Grid sizes, Stage 1/Stage 2 wording, shell envelope percentages, grip-zone restrictions, cell-based handle detection, and "Stage 1 is always parent truth" are V1-specific. They do not automatically apply to Forge V2.

V1 references:

- [Structural Volume Authoring System.md](<Structural Volume Authoring System.md>)
- [Adaptive Outer Shell - Refinement Envelope System 1.md](<Adaptive Outer Shell - Refinement Envelope System 1.md>)
- [Adaptive Outer Shell - Refinement Envelope 2.md](<Adaptive Outer Shell - Refinement Envelope 2.md>)

### Forge V2 Scope

Forge V2 is closed-volume, CSG-first material authoring:

- real material operations add/replace/intersect material volume according to policy;
- `VOID` subtracts occupied volume;
- chronological authored layers/operations remain meaningful;
- material accounting follows resolved occupied volume rather than visual density tricks;
- finished/baked output should become runtime-friendly geometry/state rather than leaving live authoring CSG as gameplay truth.

Core design sources:

- [weapon crafter v2.md](<UPLOADED/weapon crafter v2.md>) - broad CSG-first directive.
- [forge_v2_design_notes.md](<ToDo stuff/forge_v2_design_notes.md>) - workspace, tool, keybinding, spline, target, and diegetic-box notes.
- [latest SPS](<SPS/SPS_2026_06_02_00-46.md>) - June 2 state and Handle-slice handoff.
- [How To Do Menu Work.md](<How To Do Menu Work.md>) - later profile/menu behavior direction.

### Shared-Pond Code Truth As Of 2026-07-22

- [node_3d.tscn](<../The Will- main folder/the-will-gamefiles/node_3d.tscn>) instantiates both `CraftingBench` and `CraftingBenchV2` side by side.
- [crafted_item_wip.gd](<../The Will- main folder/the-will-gamefiles/core/models/crafted_item_wip.gd>) has distinct V1 fields and `forge_v2_authoring_state` in one outer WIP type.
- Both benches reach the shared [player_forge_wip_library_state.gd](<../The Will- main folder/the-will-gamefiles/core/models/player_forge_wip_library_state.gd>).
- V2's project picker filters for WIPs that contain V2 state. V1's catalog currently does not symmetrically exclude V2-only WIPs.
- [forge_v2_stage_controller.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_stage_controller.gd>) currently builds a fresh V2 WIP on save, clears V1 `layers` and the cached baked profile, and does not preserve every state another system may have attached to an existing WIP.

Therefore coexistence exists at the world, library, and outer-data-container levels, but the persistence/update contract is not neutral yet. A V1/V2 hybrid or enriched WIP can lose unrelated state when replaced by the current V2 save path. Define this seam before downstream systems begin enriching V2 WIPs heavily.

## Forge V2 Current Snapshot - 2026-07-22

This section is time-stamped. Reinspect code, `git status`, and verifier timestamps before using it later.

### Repository State

- Active branch: `godot-4.7-plus-development`.
- Current committed base: `fa36709` (`Begin Godot 4.7+ workspace development`, 2026-06-20).
- The working tree is deliberately dirty with substantial Forge V2/profile work.
- The user confirmed on 2026-07-22 that development continued after the last SPS without creating another SPS or pushing Git. The June SPS, committed base, and July worktree are therefore expected to be out of alignment. This is normal provenance, not evidence that one should be forced back into the other.
- Eight tracked Forge V2 scripts are modified, with roughly 3,056 inserted lines in the current diff.
- New profile-library/model/verifier files are untracked.
- `extension_api.json` and `gdextension_interface.h` are also untracked generated-looking artifacts and are not referenced by project source during this pass.
- Do not clean, stage, commit, or push this work automatically.

### Implemented In Current Code

The June 2 SPS Handle slice is substantially implemented and has expanded into profile-authoring work:

- `Handles` is a real third Forge V2 tool with an `H` keybinding.
- A handle requires exactly three authored path points for semantic generation.
- The primary-grip minimum is `0.25 m`.
- Generated handles carry semantic body, shape, and profile-role identity.
- Arbitrary profile polygons are swept through `CSGPolygon3D`.
- Profile-aware occupied-volume sampling and material-ledger records exist.
- Handle material is unrestricted; no old V1 drift or angle rule was reintroduced.
- A persistent player profile library exists at `user://forge/tool_presets/player_tool_profile_library_state.tres`.
- Handle and generic 2D profile builders support control points, rotation, anchor data, a Hex-24 guide/grid, optional snapping, save/update/rename/delete, and stable library IDs.
- Handle profiles support four/eight control faces and optional corner rounding.
- Forge V2 authoring drafts can be manually saved and reopened through `CraftedItemWIP`.

Primary current files:

- [crafting_bench_ui_v2.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/crafting_bench_ui_v2.gd>)
- [forge_v2_authoring_state.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_authoring_state.gd>)
- [forge_v2_stage_controller.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_stage_controller.gd>)
- [forge_v2_material_body.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_material_body.gd>)
- [forge_v2_material_volume_resolver.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_material_volume_resolver.gd>)
- [forge_v2_volume_preview_presenter.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_volume_preview_presenter.gd>)
- [forge_v2_profile_shape_library.gd](<../The Will- main folder/the-will-gamefiles/runtime/forge_v2/forge_v2_profile_shape_library.gd>) - currently untracked.
- [player_tool_profile_library_state.gd](<../The Will- main folder/the-will-gamefiles/core/models/player_tool_profile_library_state.gd>) - currently untracked.

### Evolution Beyond The June SPS

The June SPS proposed reusing approved Stage 1 handle profile masks. Current work instead uses V1's Hex-24 concept as an editing envelope while allowing player-built custom handle and basic profiles. The V1 `PrimaryGripSliceProfileLibrary` preset catalog is not currently selectable; the Handle Presets menu says `No presets yet`.

This is a newer design/code direction, not merely completion of the original narrow plan. Preserve it as an explicit evolution so future work does not accidentally claim custom profile building and fixed V1 preset selection are the same thing.

### Recorded Verification, Not Rerun During This Orientation

Recorded July results report `ok=true` for:

- [2D profile builder result](<../godot_runs/verify_forge_v2_2d_profile_builder_2026-07-07.txt>) - control points, guide, snapping, rotation, saved-name behavior.
- [Handle profile builder result](<../godot_runs/verify_forge_v2_handle_builder_profiles_2026-07-05.txt>) - handle polygon, guide, control points, rounding, anchor storage, persistence naming, semantic body creation.
- [Profile extrusion result](<../godot_runs/verify_forge_v2_profile_extrusion_2026-06-27.txt>) - swept handle profile, semantic body/shape, volume, and layer profile data.

Recorded June 20 Godot 4.7 results cover core CSG material-surface targeting, stroke promotion/collision, build-area rejection, material replacement/empty-only/same-material accounting, live targetability, amount normalization, and amount-UI removal.

Those June baseline files were modified again afterward. Treat the June results as historical regression evidence, not proof that the entire July dirty diff is green. No Godot verifier was run during the 2026-07-22 orientation.

### Current Gaps And Risks Found By Static Reconciliation

These are code observations, not newly invented design requirements:

1. **Two-point Handle dead-end** - UI/state can finish a spline at two points, but semantic handle generation requires exactly three and a finished spline rejects more points. Recovery currently requires cancel/restart.
2. **Generic noodle action remains exposed in Handle mode** - it can create generic spline material and clear Handle points instead of creating a semantic handle.
3. **Removal can be labeled as a handle** - semantic Handle generation currently copies the active add/remove operation, allowing a subtraction body with Handle identity.
4. **Basic saved profiles are not consumed by deposition yet** - basic profiles are selectable/savable, while volume-stroke and generic spline geometry remains capsule/circular.
5. **Stable saved-profile identity is not retained by generated bodies** - the UI uses stable library IDs, but applied/generated Handle data returns to the generic builder profile ID while retaining the polygon.
6. **No explicit self-intersection validation** - custom points are boundary constrained but can form a crossing polygon.
7. **Anchor use is incomplete** - anchor data is recorded, but current CSG presentation/volume paths consume an already-centered polygon without applying the anchor as a sweep pivot.
8. **Length truths differ** - Handle validity and rough body volume use raw control-point polyline length, while visual/global CSG resolution uses a baked auto-Bezier path. Curved Handle validity, appearance, and accounting can diverge.
9. **No `0.325 m` two-hand classification** - intentionally deferred in the June SPS, still not implemented.
10. **No V2 baked grip/combat bridge** - no primary-grip bake, center-of-mass/shaft solve, test/equip output, or Skill Crafter/runtime consumer exists for `forge_v2_authoring_state` yet.
11. **Menu behavior lacks substantive automated proof** - [How To Do Menu Work.md](<How To Do Menu Work.md>) closely matches static code, but the recorded profile UI log is engine-banner-only and does not exercise popup layering, left/right click, save/update, cancel, or Escape behavior.
12. **Cross-system WIP preservation is unsafe** - the V2 save-replacement path can discard other-system state, as described above.

Do not fix this list automatically. Use it as a preflight when the user selects the next slice.

## Skill Crafter And Combat Orientation

Skill Crafter is a runtime, weapon-owned combat authoring station, not a generic bone/keyframe editor.

Enduring ownership chain:

```text
authoritative equipment construction truth
-> weapon-owned skill draft
-> authored motion-node chain
-> runtime-effective duplicate/chain
-> reusable body playback
```

Core laws:

- `motion node` is the current authored-unit term; old full-unit `point` wording is obsolete.
- Motion nodes are the hard authored structure.
- Bezier handles/control vectors provide freedom between nodes and are gameplay data, not decorative lines.
- Runtime legality may skip/bridge/retarget through derived data, but it must not rewrite the authored chain.
- Equipment slot determines the dominant-hand baseline; weapon class alone does not.
- Combat idle is station-owned; noncombat stow is a separate station context.
- Per-skill nodes may own stance/primary-hand state when swaps are authored.
- Grip/contact is a valid span and continuity problem, not one infinitesimal fixed pin.
- Tip, pommel, grip, axis, mass, and handling truth must come from authoritative constructed equipment data.
- Preview, inspection/trade presentation, and combat playback should share one playback highway where possible.
- Deterministic clamp/resolve is preferred where valid; impossible states are rejected.

Forge independence law:

> Skill Crafter should consume authoritative geometry, handling, material, grip, and baked profile truth through a stable provider boundary. It must not hardwire itself so deeply to either V1 cells or V2 CSG internals that coexistence or pruning becomes impossible.

Current scope boundary: the newest SPS explicitly says not to widen the first Forge V2 Handle work into Skill Crafter integration. That remains a good boundary until the user selects the bridge as a task.

Primary sources:

- [Skill Crafter Unified Implementation TODO 2026-04-30.md](<ToDo stuff/Skill Crafter Unified Implementation TODO 2026-04-30.md>) - strongest consolidated task/design reference.
- [Combat Editor Original Intent Digest 2026-04-30.md](<ToDo stuff/Combat Editor Original Intent Digest 2026-04-30.md>) - intent and ownership digest.
- [Combat System Canonical Truth 2026-04-21.md](<Combat System Canonical Truth 2026-04-21.md>) - April implementation-prep anchor beneath the later unified ToDo.
- [SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md](<UPLOADED/SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md>) - broader earlier reference.

### Combat Coordinate Law

The live combat coordinate system is documented in:

- [COMBAT_COORDINATE_LAW.md](<../The Will- main folder/the-will-gamefiles/COMBAT_COORDINATE_LAW.md>)
- [COMBAT_ORIGIN_MIGRATION_PLAN.md](<../The Will- main folder/the-will-gamefiles/COMBAT_ORIGIN_MIGRATION_PLAN.md>)

Key points:

- `RL_BoneRoot` is the combat machine coordinate system.
- Local combat fields require a declared `origin_id`; anonymous local zero is not valid unless explicitly machine-root truth.
- Transform chains must resolve explicitly back to the machine origin.
- Resolve phases and writers must be distinguishable.
- Scene parentage is convenience, not coordinate authority.
- Double-authoring means overlapping writers target the same truth through competing origins/chains/phases.

Current code includes `CombatOriginRecord`, `CombatOriginRegistry`, annotations, audits, and many origin IDs. May recorded results show all 15 default origin chains passing and strict annotation-pattern checks passing. The large local-field audit is diagnostic: it reports no anonymous authored locals, no originless `Vector3.ZERO` cases in its filtered scan, and 336 informational unpaired-reference findings. These are historical May results, not rerun today.

## SPS And Tracking Protocol

SPS means **Save Project State**. It is a durable mental/session save slot, not a technical save, backup, commit, or push.

Use SPS for:

- the active vertical slice;
- what changed since the prior SPS;
- planned points hit and missed;
- what is true now;
- next narrow focus;
- the first file/scene/action to open;
- what not to load yet.

Rules:

- Create a new timestamped SPS for a real new handoff; do not overwrite an older SPS to pretend it is current.
- Create one when the user asks for `SPS`, `save project state`, shutdown/handoff/resume memory, or when a durable context-preservation point is genuinely needed.
- An SPS may describe uncommitted work.
- SPS claims do not replace file inspection or focused verification.
- Keep it narrow. This orientation map, not SPS, owns the broad project index.

Source: [AGENT_HANDOFF_WORKFLOW_LAW_2026-05-26.md](<UPLOADED/AGENT_HANDOFF_WORKFLOW_LAW_2026-05-26.md>).

### Sunset Trackers - Read Only

Do not add new entries to:

- [CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md](<UPLOADED/CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY.md>) - historical implementation archaeology and old mental savepoints.
- [LIVE_EXPORTED_KNOB_REGISTRY.md](<UPLOADED/LIVE_EXPORTED_KNOB_REGISTRY.md>) - historical exported-field/search registry.
- [NAMING_LAW.md](<UPLOADED/NAMING_LAW.md>) and related naming trackers - historical naming/ID context.

Older files may still instruct an agent to update them. The user's current sunset instruction supersedes those additions. Use current code, current task notes, SPS when appropriate, and this map for current orientation.

## Rules And Law Source Index

### Agent / Collaboration Rules

- [AGENT_GUARDRAILS.md](<UPLOADED/AGENT_GUARDRAILS.md>) - no invention, no unrequested renaming/scope, lifecycle separation, official Godot-first research, dependency direction.
- [AGENT_HANDOFF_WORKFLOW_LAW_2026-05-26.md](<UPLOADED/AGENT_HANDOFF_WORKFLOW_LAW_2026-05-26.md>) - SPS, code/verifier/tracker truth, verification wording, restart order, and anti-drift intent. Its older tracker-update clauses are narrowed by the current sunset instruction.
- [COLLABORATION_MINDSET.md](<UPLOADED/COLLABORATION_MINDSET.md>) - finished-machine-backward understanding, bottom-up construction, real seams, and architecture before polish.
- [agent-ready rule block for System 4 and System 5.md](<UPLOADED/agent-ready rule block for System 4 and System 5.md>) - system-specific architecture/implementation rules.
- [clean rule pack for next resolvers.md](<UPLOADED/clean rule pack for next resolvers.md>) - resolver and ownership rules.
- [THE WILL - .tres RESOURCE RULES.md](<UPLOADED/THE WILL — .tres RESOURCE RULES.md>) - project Resource immutability and Def/State/Save laws.
- [AGENT_HANDOFF_2026-05-03.md](<../DEBUG-LOGS/AGENT_HANDOFF_2026-05-03.md>) - misplaced historical handoff; useful behavior rules survive, old task/status does not.

The extensionless [THE WILL - RESOURCE USAGE RULES](<UPLOADED/THE WILL — RESOURCE USAGE RULES>) is also authoritative for Resource use even though it is not an `.md` file.

### Domain Laws - Not General Agent Rules

- [Joint Articulation Rules.md](<UPLOADED/Joint Articulation Rules.md>) - joint/articulation domain design. It is not an agent-behavior file.
- [COMBAT_COORDINATE_LAW.md](<../The Will- main folder/the-will-gamefiles/COMBAT_COORDINATE_LAW.md>) - combat coordinate ownership.
- [How To Do Menu Work.md](<How To Do Menu Work.md>) - current Forge V2 profile/menu interaction rules.
- [weapon crafter v2.md](<UPLOADED/weapon crafter v2.md>) - Forge V2 CSG laws.
- [Structural Volume Authoring System.md](<Structural Volume Authoring System.md>) and the two Adaptive Outer Shell files - Forge V1-local authoring laws.

## Important Design Source Index

### Broad Galaxy - `UPLOADED`

- [PROJECT_OVERVIEW_AND_SCOPE - Copy.md](<UPLOADED/PROJECT_OVERVIEW_AND_SCOPE - Copy.md>) - world/game/system overview; snapshot details are old.
- [thought process .txt](<UPLOADED/thought process .txt>) - design evolution and rationale.
- [weapon crafter v2.md](<UPLOADED/weapon crafter v2.md>) - CSG-first Forge V2 direction.
- [IMPLEMENTATION_DATA_MODEL_SPEC_2026-03-23.md](<UPLOADED/IMPLEMENTATION_DATA_MODEL_SPEC_2026-03-23.md>) - early data model; verify against current code.
- [MATERIAL_SCHEMA_NOTES.md](<UPLOADED/MATERIAL_SCHEMA_NOTES.md>) - material schema notes.
- [PLAYER_COMBAT_INPUT_AND_WEAPON_HANDLING_WORKING_SPEC_2026-03-29.md](<UPLOADED/PLAYER_COMBAT_INPUT_AND_WEAPON_HANDLING_WORKING_SPEC_2026-03-29.md>) - combat input/handling ancestry.
- [RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md](<UPLOADED/RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md>) - ranged/shield foundation.
- [SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md](<UPLOADED/SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md>) - broader Skill Crafter ancestry.
- [REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md](<UPLOADED/REPO_ALIGNMENT_RECOVERY_SAVEPOINT_2026-04-13.md>) - recovery context only.

The folder also contains exact duplicate pairs. Do not treat duplicate wording as independent confirmation:

- `base material tres list.txt` = `material and naming shematics .txt`
- `big w crafting.txt` = `forge material pipeline framework.txt`
- `godot project architecture skeleton.txt` = `godot structure .txt`
- `immersive world narative.txt` = `the GAME FEEL.txt`

### Milestone / Focus Layer - `ToDo stuff`

- [forge_v2_design_notes.md](<ToDo stuff/forge_v2_design_notes.md>)
- [Skill Crafter Unified Implementation TODO 2026-04-30.md](<ToDo stuff/Skill Crafter Unified Implementation TODO 2026-04-30.md>)
- [Combat Editor Original Intent Digest 2026-04-30.md](<ToDo stuff/Combat Editor Original Intent Digest 2026-04-30.md>)
- [melee_skill_crafter_ranged_wave_attacks.md](<ToDo stuff/melee_skill_crafter_ranged_wave_attacks.md>)
- [Skill Crafter Implementation Stages 2026-04-24.md](<ToDo stuff/Skill Crafter Implementation Stages 2026-04-24.md>) - older than the unified April 30 document.
- [Skill Crafter TODO 2026-04-21.md](<ToDo stuff/Skill Crafter TODO 2026-04-21.md>) - older ancestry.

### Root Documentation Layer

- [How To Do Menu Work.md](<How To Do Menu Work.md>) - newest root design note, July 7.
- [Combat System Canonical Truth 2026-04-21.md](<Combat System Canonical Truth 2026-04-21.md>)
- [Runtime Weapon-Owned Melee Skill Crafter 1.md](<Runtime Weapon-Owned Melee Skill Crafter 1.md>) and [2](<Runtime Weapon-Owned Melee Skill Crafter-2.md>) - early ancestry; newer canonical/unified wording wins.
- [Runtime Combat Editor Visual and System Addendum.md](<Runtime Combat Editor Visual and System Addendum.md>) and [Runtime Melee Combat Editor Visual-System.md](<Runtime Melee Combat Editor Visual-System.md>) - curve/gameplay-data ancestry.
- [last pass before tokens where gone.md](<last pass before tokens  where gone.md>) - historical savepoint only.

## Historical Evidence Rules

- Logs, result text, screenshots, videos, backups, old scripts, probe copies, and test Resources remain useful evidence.
- A timestamped result proves only what its verifier actually asserted against the code/environment at that time.
- A Godot log containing only the engine banner proves startup, not behavior.
- A historical file saying "current," "live," or "next" remains historical unless reconciled.
- Do not import archive scripts into the live project unchanged. Some old/root copies declare colliding `class_name` values or reference paths that no longer exist.
- Do not use `workspace debug home/DEBUG-LOGS/plan.md` as a queue. It points to March V1 work, Godot 4.6.1, and the sunset implementation-memory process.

## Open Or Intentionally Undecided Areas

The following should not be silently resolved by an agent:

- Whether Forge V1 is ultimately retained, specialized, reshaped, or removed.
- Whether V1 and V2 can author different aspects of one item, or only coexist as separate authoring paths feeding a neutral bake/provider contract.
- The exact preservation/merge rules when a WIP passes between authoring systems.
- The Forge V2 baked profile/test-print/finalized-item bridge.
- Downstream two-hand classification from the `0.325 m` Handle threshold.
- Whether V1 fixed Handle presets remain a required selection catalog beside custom profile creation.
- Exact resolution of the current static Forge V2 profile/Handle issues listed above.
- Full Skill Crafter integration with Forge V2.
- Any broader combat, ranged, shield, world, or content slice not explicitly selected by the user.

## Maintenance Law For This File

Update this map when:

- the user changes a top-level authority, working rule, or system relationship;
- a new documentation layer replaces SPS/ToDo/UPLOADED responsibilities;
- a system is formally sunset or promoted to live authority;
- the active engine/project location changes;
- a new agent would otherwise be sent to a known-wrong source;
- the curated source links materially change.

Do not turn this file into:

- a per-commit changelog;
- a dump of verifier output;
- a second implementation memory;
- a copy of every design document;
- a place to claim tests that were not run.

For time-sensitive state, add or replace a clearly dated snapshot section. Preserve the source links and the distinction between current user intent, current code truth, recorded verification, and history.

Final operating rule:

> Understand the finished machine, build from the correct roots, make the requested present slice real, and leave every seam easier to continue than it was before.
