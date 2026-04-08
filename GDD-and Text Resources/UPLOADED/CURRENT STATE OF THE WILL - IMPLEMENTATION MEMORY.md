# CURRENT STATE OF THE WILL - IMPLEMENTATION MEMORY

Date: 2026-04-02
Scope: first forge vertical slice plus active audit-led foundation cleanup and ranged physical / shield planning lock

Reference note: TOWN_GATE_FLOOR_FORGE_AUTHORITY_SAVEPOINT_2026-03-23.md captures the active authority savepoint for Town/Gate/Floor/Forge design intent, clarifications, and lore framing. Use that note for behavioral/world-design truth; keep this file focused on implementation state and verification.
Reference note: THE WILL — .tres RESOURCE RULES.md locks the current `.tres` policy. Shared project `.tres` files are for authored definitions, templates, lookup data, and tuning defaults; they are not shared live session state.
Reference note: THE WILL — RESOURCE USAGE RULES locks the broader Resource policy. Use Resource for structured domain data, definitions, templates, and saveable/duplicable instance data; do not use Resource for scene presence, controller/service orchestration, or volatile live interaction state.
Primary implementation references:
- quirky-cuddling-mochi.md
- DECISION_LEDGER_FIRST_SLICE.md
- Crafting Atoms v0.1a.txt
- smallest implementation checklist per file.md
- agent-ready rule block for System 4 and System 5.md
- project-aligned workaround.md
- FULL_REPO_AUDIT_FIX_LEDGER_2026-04-01.md
- RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md

## Purpose

This file records the current checked state of the project using three labels:

- Locked in docs
- Implemented in code
- Still pending

It exists to prevent confusion between design law, prepared schema, and actual working behavior.

It also does double duty:

- as the live implementation-memory note used during work
- as a status-export note that can be handed to third parties so they can understand the current state without reading the full codebase

## Quick export read

If someone needs the short version first, the current state is:

- the first forge vertical slice is partially implemented and actively usable as a sandbox proof surface
- the resolver/service/profile stack is live and can bake current sample WIPs into a BakedProfile plus test-print preview data
- the current runtime sandbox includes a player, an interactable crafting bench, a provisional bench UI, and a controller-owned active preview mesh
- the current bench/runtime path now reads forge workspace rules from a shared ForgeRulesDef `.tres`, forge view tuning from a shared ForgeViewTuningDef `.tres`, forge material order from a shared ForgeMaterialCatalogDef `.tres`, and owned forge material quantities from a player-owned runtime inventory state seeded by a shared ForgeInventorySeedDef `.tres`
- the debug grip, flex, and bow sample presets now live as authored forge preset Resources built from external brush definitions instead of controller-hardcoded sample geometry
- the first grounded forge-ready base material roster now contains 16 populated `.tres` defs: wood, iron, bone, hide, crystal, mana_core, healing, pyro, frost, aqua, scale, tendon, carapace, silver, gold, and copper
- the grounded raw-drop -> gray-quality process side of that same 16-material roster now also exists as authored `.tres` reference points backed by default raw-drop and process-rule registries plus a small MaterialPipelineService verification path
- the material+tier carry-through path is now materially stronger than the earlier slice: runtime material variants can now be resolved from `mat_<material>_<quality>` ids on demand, baked profiles now aggregate resolved variant stat/bias data instead of only base-material bias lines, and the current forge UI/preview/test-print surfaces now read variant ids without silently falling back to unknown-material rendering
- player-owned body inventory authority and forge-side personal storage authority now exist as save-backed Resource models, with an InventoryStorageService that can transfer owned items between those surfaces and route processed forge-material stacks into forge inventory
- the first honest disassembly backend slice now exists on top of that authority layer: supported raw-drop items can be previewed for one-way disassembly into processed forge materials, finalized-item salvage stays blocked until finalized makeup/provenance data exists, and the commit path revalidates selected item snapshots before routing outputs to avoid preview/commit dupe drift
- the first honest disassembly bench UI slice now also exists in the traversal sandbox: a responsive viewport-safe station window can list supported body-inventory raw drops, move them into a pending disassembly queue, preview processed forge-material outputs, gate the commit behind an irreversible confirmation checkbox, and route confirmed outputs directly into forge storage
- forge-side temporary project naming now exists separately from later final item naming: CraftedItemWIP carries a forge-only temporary project label for in-forge organization while final export naming remains a later boundary
- the bench now has a dedicated forge project panel for temporary project naming, temporary forge notes, sample selection, blank-project creation, save, duplicate, delete, and saved-WIP reopening instead of packing project selection into the workflow popup
- the forge flow now has a save-backed player-owned WIP library on the player controller, with temporary project names, forge notes, and duplicate/delete behavior verified through a dedicated headless library harness
- the mochi v1 reconciliation work is now partially folded into the live code: disconnected-build validation is enforced, deterministic variant/stack ids exist, and WIPs can carry an optional baked-profile snapshot that is cleared on edit
- finalized naming is now explicitly modeled as a later boundary: FinalizedItemInstance has its own final item name and source-WIP provenance fields instead of reusing forge-side temporary project naming
- volatile forge-session state now lives on ForgeGridController instead of CraftedItemWIP: the controller owns the active viewed layer, the latest baked profile cache, and WIP mutation entry points while CraftedItemWIP stays authored-item data only
- the current forge-path warning debt was reduced again: the workspace preview now uses the current MultiMesh color API, the plane viewport no longer shadows CanvasItem.draw_rect with local variables, and the earlier headless-support preload constants were renamed so they no longer collide with global class names in reload warnings
- grip, flex, and bow sample presets have been runtime-verified through a headless Godot harness
- the authored forge material catalog and seed pass has now been headless-verified in Godot with 16 loaded materials, 16 authored catalog entries in the intended order, and 16 seeded material stacks
- the new inventory/storage authority pass has now been verified in a real unsandboxed Godot user-save run: body inventory and personal storage both persist, disassemblable items can move from body inventory into personal storage, and processed material stacks can be routed into forge inventory
- the current bench/editor presentation is provisional and should not be treated as the intended final forge-station design
- a full-repo audit/fix ledger now exists and is the active cleanup authority for architectural debt, ownership splits, and wrong-foundation corrections
- the forge bench, player controller, player rig, inventory overlay, and system menu are now materially cleaner than the earlier slice because major mixed-responsibility logic has been split into dedicated presenters/helpers instead of left buried in giant owner scripts
- the current crafted-item runtime geometry path is no longer the older per-exposed-face quad spam path, but it is still not the final canonical solid/chamfer-ready geometry stage; the next true geometry foundation work is still to lock the canonical processed solid/shape stage, not to pretend the current mesh path is the end state
- the geometry foundation moved forward again on 2026-04-02: the runtime path now explicitly stores `CraftedItemCanonicalSolid` and `CraftedItemCanonicalGeometry` on `TestPrintInstance`, and forge preview centering plus held-item mesh/bounds now read that shared canonical geometry stage instead of treating the committed render mesh itself as the first processed-shape authority
- the player/runtime cleanup moved forward again on 2026-04-02: motion/input/aim responsibilities now live in a dedicated `PlayerMotionPresenter`, so the controller no longer owns the full mouse-look, move-direction, target-speed, vertical motion, visual facing, locomotion sync, and minimal aim-context solve block itself
- the profile bake cleanup moved forward again on 2026-04-02: `ProfileResolver` now keeps mass/connectivity/grip as its core job while edge/blunt/pierce/guard/flex/launch scoring lives in a dedicated `ProfileCapabilityScoreResolver`
- the resolver lock pass moved forward again on 2026-04-02: `AnchorResolver.validate_primary_grip()` now uses the live eligible grip-span rules instead of carrying a stale future-material-legality TODO, and `SegmentResolver` now explicitly treats its current role output as first-pass bow-related hints rather than pretending general segment-role derivation is already solved
- the capability resolver pass moved forward again on 2026-04-04: current first-pass capability behavior is now explicit in code instead of hanging on TODOs, with optional pierce reach bonus intentionally disabled, raw reach clamped directly into `cap_reach`, accepted context bias inputs kept supported, and threshold/display-tier mapping left intentionally outside the resolver
- `NAMING_LAW.md` is now the live naming manual rather than a tiny suffix note only; it now locks suffix families, domain umbrella terms, ambiguous-term meaning, and unit/token rules, and it should be updated whenever new naming families or ambiguous gameplay terms are introduced
- the older simple `bow` mental model is no longer the authoritative future shape: the locked future umbrella is now `Ranged Physical Weapon`, with separate `bow` and `quiver` components, explicit authored string-anchor creator points, runtime four-point string behavior, and shield/quiver mannequin-style restriction overlap documented as the future foundation
- M1 is still open because a fresh full editor warning/problem capture has not yet been done
- M2 is complete as a runtime-verification milestone for the current preset paths
- fuller forge authoring, finalized-item flow, world-side spawned test-print flow, runtime articulation behavior, and broader context/page systems are still pending

## How to read this file

- read this file as a checked report of current implementation state, not as the source document for what the full future design should become
- use `Locked in docs` to understand the design authority the code is trying to honor
- use `Implemented in code` to understand what the files actually do right now
- use `Still pending` to understand what is not done yet or what remains intentionally provisional
- when sharing status externally, the safest summary anchors are the `Quick export read`, `Current project status in one sentence`, and `Explicit state-right-now summary` sections

## Reading map: what was, what is, what will be

What was:
- the foundation and structural laws already locked in docs and already implemented enough that later work should build on them, not re-argue them
- examples: lifecycle object separation, 6-neighbor segment truth, density-weighted mass/center of mass, ForgeService/ProfileResolver authority split, controller-owned active test-print preview

What is:
- the currently live implementation state that can be inspected, edited, baked, and iterated on right now
- examples: layered bench editor, active grip/flex/bow sample presets, first-pass joint and bow validation, full first-slice profile field coverage, first-pass capability derivation, known Godot warning/problem debt

What will be:
- the next mochi-ordered work that should extend the existing truth stack without pretending unfinished systems are already complete
- examples: fuller segment role derivation, edge/blunt legality, richer forge-grid authoring, world-side test-print flow, runtime articulation behavior, context/page builders, and later specialization follow-through

Working rule:
- future implementation should treat what was as settled support structure, what is as the active working surface, and what will be as the ordered expansion path
- do not collapse those three layers together when planning or updating this note
- keep the Def vs State split explicit: shared `.tres` resources are read-only definition/tuning truth, while current WIP contents, selected tool/material/layer, active preview state, and current player-owned quantities remain runtime or save-instance state

## 1. Core project law

Locked in docs:
- The player crafts matter, the Forge resolves matter into a profile, and the game uses the baked profile.
- Raw cells are authoring truth.
- Baked profile is gameplay-facing truth.
- Work-in-progress items are forge-bound.
- Test prints are temporary playable copies inside the Forge.
- Naming and finalization are the export point.
- Before naming, the cost of experimentation is time.
- After naming, the cost of revision is materials.

Implemented in code:
- Core lifecycle objects now exist as separate data containers.
- PlayerForgeInventoryState now exists as a dedicated runtime-owned forge material inventory container separate from WIP, baked profile, test print, and finalized item state.
- PlayerForgeWipLibraryState now exists as a dedicated player-owned WIP library container backed by `user://forge/player_wip_library_state.tres` for the current sandbox save/open selection path.
- FinalizedItemInstance now carries its own finalized item id, final item name, source WIP id, and finalized timestamp so final naming remains a separate later-stage authority from forge-side draft/project labeling.
- StoredItemInstance now exists as a concrete owned-item container for body inventory / storage authority work, including raw-drop references, finalized-item references, stack count, and disassemblable-state marking.
- PlayerBodyInventoryState now exists as a save-backed player-owned body inventory surface for owned runtime items that may later feed disassembly, storage movement, and finalized-item handling.
- PlayerPersonalStorageState now exists as a save-backed forge-side personal storage surface separate from body inventory.
- InventoryStorageService now exists as the current transfer/routing bridge between owned-item authority surfaces and forge material inventory.
- SalvageResult now exists as a staged disassembly preview/commit container so preview outputs remain separate from committed forge-material routing.
- SalvageService now exists as the current item-case-specific disassembly authority for supported raw-drop inputs, including irreversible-confirmation gating, snapshot revalidation before commit, and direct routing into forge material inventory.

Still pending:
- No finalized-item export flow exists yet.
- No test-print gameplay loop exists yet.
- Stationary storage interactables/pages and full broader inventory presentation are still pending above the new authority surfaces.

## 2. First-slice scope

Locked in docs:
- First slice proves forge materials, cells, profiles, and test prints.
- First slice is sandbox only.
- Combat, economy, multiplayer, polish, and the full game are out of scope.

Implemented in code:
- File structure for the first slice is now mostly present.
- Sandbox scene shell exists.
- Forge sandbox debug bake loop exists and can bake a layered grip-valid sample WIP through the current resolver path.
- The temporary crafting bench UI can now edit a small layered voxel sample, bake it, and refresh the live bench-side preview.
- The traversal sandbox now also includes an interactable disassembly bench with a first honest raw-drop-only station UI slice built on the live body-inventory and salvage backend authority path.
- The active forge plane view, workspace preview, bench UI colors, and test-print preview fallback/material tuning now read from a shared ForgeViewTuningDef `.tres` instead of local UI/view literals.
- The bench UI now reads owned material quantities from PlayerForgeInventoryState and updates those player-owned stacks when cells are placed, replaced, or removed.
- ForgeGridController now owns volatile forge-session state for the active bench flow, including current viewed layer, latest baked-profile cache, and the WIP mutation entry points used by CraftingBenchUI.
- CraftedItemWIP no longer stores current viewed layer or latest baked-profile snapshot fields; it remains authored WIP data only.
- The current debug grip, flex, and bow presets now load through ForgeSamplePresetDef resources referenced by ForgeRulesDef, with each preset composed from external ForgeSampleBrushDef definitions instead of script-authored sample geometry.
- CraftedItemWIP now also carries a forge-only temporary project label used inside the forge project flow; this is separate from later finalized item naming and does not lock or claim the final export name.
- CraftedItemWIP now also carries forge_project_notes for forge-side draft organization; these notes are save-backed WIP metadata, not finalized item-facing text.
- CraftingBenchUI now exposes a dedicated forge project panel with temporary project naming, forge notes, blank-project creation, live sample selection, save, duplicate, delete, and saved-project reopening instead of routing project selection through the workflow popup.
- The player-owned WIP library now persists through `user://` storage, and a dedicated headless verifier confirmed save -> reload retention of the saved WIP id, forge-only temporary project name, forge notes, and correct duplicate -> delete behavior for saved projects.
- PlayerForgeWipLibraryState now also exposes save-backed duplicate and delete operations for saved forge projects.

Still pending:
- The full place -> bake -> test print workflow is not completed yet.

## 3. Hard architectural laws

Locked in docs:
- Final grid target: 160 x 80 x 40.
- First prototype grid: 20 x 10 x 5.
- Medium prototype grid: 40 x 20 x 10.
- Connectivity is 6-neighbor only.
- Mass is density-weighted.
- Center of mass is density-weighted.
- Test print mesh must use MeshInstance3D plus runtime-generated ArrayMesh.
- No CSG in the player-side forge/test-print pipeline.
- WIP save format for v0.1 is Godot Resource (.tres).
- One active test print at a time.
- Same WIP can be re-baked and re-printed repeatedly.
- Material variants are generated in memory from BaseMaterialDef plus TierDef.
- CraftedItemWIP is a pure data container.
- Baking lives in ProfileResolver plus ForgeService.
- Gameplay reads BakedProfile, not raw cells.

Implemented in code:
- Configurable prototype grid field exists on ForgeGridController.
- ForgeRulesDef now externalizes the active forge workspace defaults and current anchor, joint, and segment-role thresholds into core/defs/forge/forge_rules_default.tres.
- ForgeRulesDef now also references the active debug sample preset resources, so ForgeGridController resolves sample WIPs from external preset data rather than hardcoded controller shape builders.
- ForgeViewTuningDef now externalizes the active forge preview/UI tuning defaults into core/defs/forge/forge_view_tuning_default.tres.
- ForgeGridController now exposes sample preset display names and can switch the active editor WIP between preset-backed sample data and cloned player-saved WIPs.
- TierResolver and ProcessResolver follow the in-memory variant and stack approach.
- SegmentResolver enforces 6-neighbor clustering.
- SegmentResolver now computes major axis, cross-section envelope, support ratios, endcap anchor validity, and a basic rectangular profile-state classification for each resolved segment.
- AnchorResolver enforces the locked primary-grip legality rules.
- ProfileResolver computes density-weighted total mass and center of mass.
- ProfileResolver computes primary_grip_valid, primary_grip_offset, reach, and balance_score.
- TestPrintMeshBuilder generates an ArrayMesh by emitting exposed voxel faces from the current test-print cells.
- ForgeGridController now owns the active spawned test-print mesh instance and replaces it when the active test print changes.
- The current resolver/service/controller bake path compiles cleanly in Godot with no active script parse errors, and the headless preset-verification harness now completes successfully under the local Godot 4.6.1 console build.
- A broader Resource-usage audit after the CraftedItemWIP cleanup found no remaining clear misalignments in the current codebase: shared `.tres` definitions remain read-only, instance Resources stay data-oriented, and scene/controller flow remains in Nodes or RefCounted services.

Still pending:
- A broader world-side spawned test-print gameplay entity flow does not exist yet beyond the current controlled preview mesh.

## 4. Lifecycle object separation

Locked in docs:
- Raw drops, forge stacks, WIP, baked profile, test print, and finalized item must not collapse into one generic type.

Implemented in code:
- ForgeMaterialStack exists.
- CraftedItemWIP exists.
- BakedProfile exists.
- TestPrintInstance exists.
- FinalizedItemInstance currently exists only as an empty Resource subclass placeholder.
- FinalizedItemInstance now exists as a minimal finalized-item container with separate final item naming/provenance fields, but no actual finalization/export workflow uses it yet.

Still pending:
- No finalized-item export flow or naming-station workflow uses FinalizedItemInstance yet.
- No raw-drop to world-item runtime layer exists yet.

## 5. Material truth vs crafting context

Locked in docs:
- Base materials are universal matter truth.
- Crafting context is a separate layer above material truth.
- Profile resolution is another layer above context.
- Wood stays wood regardless of whether the build becomes weapon, armor, shield, accessory, trinket, or ranged-support.

Implemented in code:
- BaseMaterialDef is the universal material-truth container.
- base_material_id is the normalized field name.
- wood.tres and iron.tres are populated with concrete first-slice material data.
- wood.tres and iron.tres now also carry the first active hard support flags used by the resolver path.
- CraftedItemWIP now carries minimal forge_intent and equipment_context fields so ranged validation can be driven by the authored WIP instead of out-of-band test overrides.

Still pending:
- No actual crafting-context page or builder logic exists yet.
- No melee, magic, ranged, or shield page builders exist yet.

## 6. ID universe and naming law

Locked in docs:
- Direct stat IDs are defined.
- Capability IDs are defined.
- Family IDs are defined.
- Element IDs are defined.
- Equipment-context IDs are defined.
- Forge-intent IDs are defined.
- Naming law distinguishes Def, Atom, Model/State, Profile, Resolver, Service, Controller, Registry, Factory/Builder.

Implemented in code:
- base_material_id is the active normalized material-id field used in the current code.
- The active material naming law now uses `mat_<material>_base` for internal authored base-material defs, `drop_<material>_raw_<quality>` for live raw-drop ids, and `mat_<material>_<quality>` for runtime/material-stack/forge-placement variants, with the current default tier living at `gray`.
- Base material plus tier now resolves the active forge/runtime variant truth more consistently across the live slice: raw-drop quality drives processed output ids, runtime variant ids can be rebuilt from the naming law plus the shared tier registry, and baked profiles now aggregate resolved variant stat/bias lines rather than only base-material bias lines.
- First-slice files use the intended category names.
- Defs, atoms, models, and profiles were normalized into typed data containers.

Still pending:
- Broader future systems still need to keep following the naming law as they are added.
- The broader carry-through law is now explicit and should be treated as design truth going forward: `BaseMaterialDef + TierDef` defines the raw-drop quality, that same quality carries into the processed forge material variant, and that same resolved material quality should remain attached through forge placement, baking, later engraving/finalization, and final crafted stat outcome.
- The current live first slice still stops short of the final boundary: raw-drop quality now routes cleanly into processed material ids, forge placement ids, and current baked-profile resolved stat/bias aggregation, but no finalized export/engraving path yet carries that same variant quality into an authoritative final crafted-item instance.

## 7. Foundation state in code

Locked in docs:
- defs/atoms -> models -> resolvers -> services -> runtime controllers -> scenes/ui

Implemented in code:
- BaseMaterialDef and StatLine are real Resource types.
- First-slice defs exist as Resource containers.
- First-slice atoms exist as Resource containers.
- First-slice models and profile exist as Resource containers.
- Resolver code exists for tier, process, segment, anchor, joint, bow, profile, capability, and a small shape-classification helper.
- ForgeService exists as a narrow orchestration layer.
- ForgeGridController exists as a narrow controller shell.
- forge_sandbox.tscn exists.
- Resolver, service, and sandbox bake-entry scripts now follow the current explicit typed-GDScript rule set from project-aligned workaround.md.
- The active first-slice script path is structurally wired and editor-diagnostic clean in the changed files, and the latest headless harness run no longer hits the earlier bench-UI property-access issue or the connected-bow typed-array runtime fault that showed up during M2 verification.

Still pending:
- behavior_template.gd is still a placeholder and not yet part of the current slice.
- Many later layers are still shells rather than behavior-complete systems.

## 8. Material data

Locked in docs:
- wood and iron are the first approved material examples.
- the next grounded expansion batch includes bone, hide, crystal, mana_core, healing, pyro, frost, aqua, scale, tendon, carapace, silver, gold, and copper.

Implemented in code:
- The current grounded forge-ready base roster now contains 16 populated BaseMaterialDef `.tres` files: wood, iron, bone, hide, crystal, mana_core, healing, pyro, frost, aqua, scale, tendon, carapace, silver, gold, and copper.
- The first active hard support flags are now populated across the live forge roster instead of only wood and iron.
- The live forge roster also carries the current forge preview/test-print color data, and the current forge render path resolves that color from the material defs instead of material-name checks in code.
- Forge material order now lives in a shared ForgeMaterialCatalogDef `.tres` instead of only being discovered by directory scan order.
- Forge-owned starting quantities now live in a shared ForgeInventorySeedDef `.tres` instead of only falling back to one uniform script path.
- RawDropDef `.tres` reference points now exist for the same grounded 16-material roster.
- ProcessRuleDef `.tres` reference points now exist for the same grounded 16-material roster using the current explicit `1 -> 6` default gray-quality conversion law.
- Default raw-drop and process-rule registries now exist so later pipeline systems can resolve authored data without hardcoded per-file paths.
- SalvageRulesDef and SkillCoreRulesDef now exist as authored rule-surface `.tres` reference points for later disassembly/salvage selection law instead of leaving those tunables implicit.

Still pending:
- Broader material population beyond the current grounded 16-material batch is still pending.
- Finalized-item contextual disassembly outputs, blueprint extraction, chase-skill recovery, and broader item-case-specific processing behavior are still pending.

## 9. Tier and process resolution

Locked in docs:
- Tier stat multiplier applies to StatLine values, not density.
- ProcessRuleDef output_count_per_input is explicit and defaults to 6.

Implemented in code:
- TierResolver creates a MaterialVariantDef from BaseMaterialDef plus TierDef.
- TierResolver scales direct base_stat_lines using stat_multiplier.
- ProcessResolver creates a ForgeMaterialStack from a ProcessRuleDef and MaterialVariantDef.
- ProcessResolver copies variant_stats into the stack.
- TierResolver now generates deterministic runtime variant ids from base material id plus tier id.
- ProcessResolver now generates deterministic runtime stack ids from process rule id plus variant id.
- MaterialPipelineService now resolves the current grounded quality chain from base material -> raw drop -> process rule -> gray tier variant -> forge material stack using authored registries.
- SalvageService now uses that same registry-backed path for the first player-facing raw-drop disassembly preview/commit flow, so supported body-inventory raw drops now resolve directly into authoritative forge-material outputs through the shared material pipeline instead of ad-hoc UI math.

Still pending:
- Wider future registry coverage around authored process outputs and later catalog validation is still pending.
- No full disassembly bench UI or finalized-item salvage path uses the registry-backed material pipeline yet.

## 10. Segment resolution

Locked in docs:
- SegmentResolver is the 6-neighbor cell clustering layer.
- Segments are derived/intermediate data, not sacred authored truth.

Implemented in code:
- SegmentResolver groups connected cells by face adjacency.
- SegmentResolver outputs separate SegmentAtom objects for disconnected islands.
- SegmentResolver fills member_cells.
- SegmentResolver fills material_mix.
- SegmentResolver computes major axis and minor axes per segment.
- SegmentResolver computes segment length and cross-section envelope dimensions.
- SegmentResolver computes anchor, joint-support, and bow-string support ratios from material truth.
- SegmentResolver computes start and end slice anchor validity.
- SegmentResolver assigns basic profile-state classification for rectangular spans and first-pass beveled-blade spans.
- SegmentResolver now detects first-pass opposing bevel-pair slices from actual slice occupancy.
- SegmentResolver now derives first-pass riser, bow-string, and projectile-pass candidate hints from material support plus segment geometry.
- SegmentResolver now explicitly treats those outputs as first-pass bow-related role hints only; later limb assignment and broader non-bow role derivation remain follow-on resolver work.
- Temporary runtime segment_id values are assigned per resolution pass.

Still pending:
- Full segment role derivation is still not implemented beyond the current first-pass bow candidate hints.
- Edge-span overlap detection is not implemented.
- Segment IDs must not be treated as stable save identity, trade identity, provenance identity, or cross-session truth.

## 11. Physical item truth stack

Locked in docs:
- System 1: handle, edge, blunt
- System 2: articulation and joints
- System 3: bow and ranged specialization
- System 4: profile math
- System 5: capability resolution

Implemented in code:
- BaseMaterialDef now carries hard support flags needed for later handle, joint, bow, and support classification.
- SegmentAtom now carries metadata fields needed by later anchor and physical-shape rules.
- SegmentAtom now also reserves first-pass joint and bow candidate metadata fields for later resolver outputs.
- The active resolver path now fills the first usable subset of that segment metadata from actual cell geometry and material support flags.

Still pending:
- Edge legality is not implemented.
- Blunt legality is not implemented.
- Full joint runtime behavior is not implemented.
- Full bow/ranged runtime specialization is not implemented.

## 12. System 1: handle / anchor / edge / blunt

Locked in docs:
- Grip legality depends on shape envelope, anchor-material ratio, valid endcaps, safe profile states, and no edge overlap.
- Edge legality depends on edge-capable material plus thin-enough blade geometry plus opposing bevel support.
- Blunt legality depends on thick, non-edge, strike-capable structure.

Implemented in code:
- AnchorResolver enforces the locked primary-grip legality rules.
- BaseMaterialDef has support flags for anchor, beveled edge, blunt, grip, guard, and plate.
- SegmentAtom has fields for anchor ratio, endcap validity, profile state, and edge overlap.
- AnchorResolver now produces primary grip anchors as eligible grip spans inside connected segments instead of only accepting a whole segment as one rigid grip candidate.
- AnchorResolver primary-grip validation now resolves against those same eligible grip spans, so current primary-grip legality no longer depends on a stale “later material lookup pass” comment.
- AnchorAtom now carries primary-grip axis, span-length, span start/end indices, span start/end positions, and span anchor-material ratio for later profile math and future combat-side sliding-hand use.
- BakedProfile now carries the resolved primary-grip contact point plus the underlying span start/end/length data, so the current bake path already preserves the difference between a neutral grip contact and the larger eligible grip area.

Still pending:
- User edits can still break grip validity after reset, so sandbox bakes may still become invalid depending on the authored WIP.
- The combat/runtime hand-placement system that will actually slide hands along the saved grip span does not exist yet; the forge/bake truth now carries the span data for that later layer.
- Edge and blunt resolution are not implemented.

## 13. System 2: articulation / joints

Locked in docs:
- Joint rules are documented.
- Square cross-plane may allow axial spin or planar hinge.
- Rectangular cross-plane forces one hinge plane.
- Membrane is runtime bridge logic, not sacred authored rigid truth.

Implemented in code:
- BaseMaterialDef has joint support flags.
- SegmentAtom has joint-related ratio fields reserved.
- JointResolver now exists and validates first-pass articulated joint chains from segment geometry plus joint-support material ratio.
- JointResolver now outputs joint_chain_valid, joint_type, joint_axis, motion_plane, link_count, hinge_count, angle limits, support flags, self-collision mode, and validation_error.
- The current wood sample material now exposes the minimum joint-support flags needed for first-pass articulated sample validation.
- The active joint angle limits and minimum joint envelope/material thresholds now read from core/defs/forge/forge_rules_default.tres instead of local JointResolver literals.

Still pending:
- No membrane bridge behavior or runtime articulation behavior exists yet.

## 14. System 3: bow / ranged specialization

Locked in docs:
- Bow logic is context-gated by ranged forge intent.
- Bows build on top of lower physical truth layers.
- A 1x1 string exception exists only inside ranged context.
- Grip, riser, limb, string, and projectile-pass logic are required.
- This older section is now only the resolver-side snapshot.
- The broader future authority for this bucket is now `RANGED_PHYSICAL_WEAPON_AND_SHIELD_FOUNDATION_SPEC_2026-04-02.md`, which supersedes the older "bow as the whole system" mental model.

Implemented in code:
- BaseMaterialDef has bow-support flags.
- SegmentAtom has bow-related ratio and candidate-reserved metadata fields only where already added.
- BowResolver now exists and enforces the ranged-context gate before bow validation can succeed.
- BowResolver now outputs first-pass bow validity, reference points, axes, limb validity, limb flex scores, string tension score, asymmetry score, and validation_error.
- BowResolver now derives upper/lower limb selection from either disconnected limb candidates or a second-stage logical sub-segmentation pass over a single connected authored bow mass.
- The active bow-string span rule, bow-limb minimum envelope, limb-flex length reference, and synthetic riser-slice compactness threshold now read from core/defs/forge/forge_rules_default.tres instead of local BowResolver literals.
- Bow resolver ownership is now cleaner than the older single-file pass:
  - connected-region fallback moved into `bow_connected_region_resolver.gd`
  - reference geometry moved into `bow_reference_geometry_resolver.gd`
  - limb/string validation moved into `bow_limb_validation_resolver.gd`

Still pending:
- No melee, magic, ranged, or shield page/builder flow exists yet.
- Bow structure is still validated by first-pass logical region extraction over the current connected sandbox sample, not by a final authored continuous bow workflow with dedicated builder semantics.
- No `Ranged Physical Weapon` builder exists yet.
- No separate `quiver` shell/mannequin crafter exists yet.
- No explicit authored `A1 / A2` bow string-anchor creator-point system exists yet.
- No runtime four-point bow-string draw/release behavior exists yet.
- No shield mannequin-anchor crafter overlap work exists yet.

## 15. System 4: profile math

Locked in docs:
- BakedProfile must receive gameplay-facing physical truth.
- total_mass is required.
- center_of_mass is required.
- reach is required.
- primary_grip_offset is required.
- front_heavy_score is required.
- balance_score is required.
- edge_score is required.
- blunt_score is required.
- pierce_score is required.
- guard_score is required.
- flex_score is required.
- launch_score is required.
- primary_grip_valid and validation_error are required.
- total_mass = sum of density-weighted cell masses.
- center_of_mass = density-weighted position average.

Implemented in code:
- BakedProfile contains the first-slice fields.
- agent-ready rule block for System 4 and System 5 is now available as later implementation guidance.
- ProfileResolver now matches the approved bake_profile entry shape with optional shape_data, joint_data, and bow_data inputs reserved for later layers.
- ProfileResolver material lookup now supports the real first-slice split: cell.material_variant_id may resolve either directly to BaseMaterialDef or first to MaterialVariantDef and then to BaseMaterialDef via base_material_id.
- ProfileResolver now follows the project-aligned workaround rule: explicit local typing, typed helper math, and immediate typed lookup/cast handling in the resolver path.
- ProfileResolver computes total_mass.
- ProfileResolver computes center_of_mass.
- ProfileResolver carries primary_grip_valid from anchor results.
- ProfileResolver sets validation_error to no_primary_grip_candidate when no primary grip anchor is present.
- ProfileResolver computes primary_grip_offset.
- ProfileResolver computes reach using the first-pass max-distance rule.
- For the current v0.1 pass, forward_axis is resolved from primary_grip_axis.
- ProfileResolver computes front_heavy_score from primary_grip_offset, forward_axis, and reach, and leaves it at the neutral default when no valid primary grip axis exists.
- ProfileResolver computes balance_score using the first-pass normalized offset rule.
- A small ShapeClassifierResolver now provides the first rule-backed shape checks for edge-valid, blunt-valid, guard-capable, and pointed-tip spans.
- ProfileResolver now computes edge_score from edge-valid spans, beveled-edge material support, and density-weighted segment mass share.
- ProfileResolver now computes blunt_score from blunt-valid spans, blunt-capable material support, and density-weighted segment mass share.
- ProfileResolver now computes pierce_score from pointed-tip geometry hints, pierce-capable material support sourced from positive cap_pierce material bias lines, and density-weighted segment mass share.
- ProfileResolver now computes guard_score from guard-capable spans, guard/plate-capable material support, and density-weighted segment mass share.
- ProfileResolver now computes flex_score from joint outputs or bow limb/string outputs combined with flex-capable material support.
- ProfileResolver now computes launch_score from bow validity, projectile-pass presence, string tension, and launch-capable material support.
- The bake path now uses primary-grip axis data carried by AnchorAtom for first-pass forward-axis profiling.
- ProfileResolver now reuses AnchorResolver for primary_grip_offset math instead of duplicating the formula.
- CellAtom now owns center-position conversion so anchor and profile resolvers reuse the same cell-position helper.
- ForgeService now wires WIP baking end to end: collect cells, resolve segments, classify joint segments, resolve anchors, build joint/bow data, bake profile, derive capability_scores, save latest_baked_profile_snapshot, and debug-print the baked values.
- ForgeService now pulls forge_intent and equipment_context directly from CraftedItemWIP when it resolves bow data, so ranged validation is no longer hardcoded to blank defaults.
- ForgeGridController can now bake the active WIP and build one runtime TestPrintInstance from it.
- The current grip, flex, and bow sample presets have now been runtime-exercised through the headless Godot preset harness rather than only inferred from code.

Still pending:
- ProfileResolver still does not yet consume shape_data.
- Current first-slice sample materials do not yet guarantee non-zero pierce_score because pierce support depends on positive cap_pierce material bias lines.
- The flex and bow presets now runtime-exercise non-zero flex_score and launch_score through the resolver path, but both still fail overall profile validation with no_primary_grip_candidate under the current grip rules.
- AnchorResolver still does not expose the full locked validation_error set because the current docs require profile-state validation but do not yet give that failure a dedicated error code.

## 16. System 5: capability resolution

Locked in docs:
- First-slice capabilities are cap_edge, cap_blunt, cap_pierce, cap_guard, cap_flex, cap_launch, cap_stability, and cap_reach.
- CapabilityResolver uses BakedProfile plus aggregated material/context biases.
- CapabilityResolver must not use raw cells or controller state.

Implemented in code:
- CapabilityResolver now provides a minimal first pass using only already-backed profile fields.
- BakedProfile has capability_scores.
- ForgeService now collects material capability_bias_lines from the active WIP cell materials and passes them into CapabilityResolver.
- CapabilityResolver accepts material and optional context bias lines as inputs.
- CapabilityResolver derives cap_edge from edge_score.
- CapabilityResolver derives cap_blunt from blunt_score.
- CapabilityResolver derives cap_pierce from pierce_score.
- CapabilityResolver derives cap_guard from guard_score.
- CapabilityResolver derives cap_flex from flex_score.
- CapabilityResolver derives cap_launch from launch_score.
- CapabilityResolver derives cap_stability from balance_score.
- CapabilityResolver clamps the current first-pass capability outputs into the 0.0 to 1.0 range.
- CapabilityResolver currently derives cap_reach by clamping the existing reach value directly as the explicit first-pass reach rule.
- CapabilityResolver currently applies no optional reach bonus to cap_pierce; that bonus is intentionally `0.0` until a later weighting rule is locked.

Still pending:
- No broader capability math is implemented beyond current profile-field inputs plus aggregated material capability bias lines.
- No forge context/page layer is passing context bias lines yet.
- Exact reach normalization beyond the current first-pass raw reach clamp is still a later design decision.
- A future non-zero optional reach bonus behavior for cap_pierce is still not locked.
- No thresholds or display tier mapping are implemented.

## 17. Test prints and sandbox

Locked in docs:
- Test print uses runtime-generated ArrayMesh.
- One active test print at a time.
- forge_sandbox.tscn must allow place -> bake -> test print.

Implemented in code:
- TestPrintInstance exists.
- TestPrintMeshBuilder now emits a visible ArrayMesh preview from test-print cells using exposed cube faces and placeholder material colors.
- forge_sandbox.tscn currently exists as a minimal Node scene whose script is ForgeGridController.
- ForgeGridController tracks one active test print reference and one controller-owned spawned mesh instance for it.
- forge_sandbox.tscn now auto-runs a debug bake loop with a layered grip-valid sample WIP and prints the baked outputs plus test_print_id.
- ForgeGridController can now build grip, flex, and ranged-bow debug sample WIPs, preserve the active sample preset across resets, bake them through ForgeService, and create a runtime TestPrintInstance for inspection.
- The current debug bake/test-print construction path is script-clean in the touched files, carries display_cells into the controller-owned runtime preview path, and has also been exercised by the dedicated headless preset harness.

Still pending:
- The visible preview is still a controlled local preview mesh, not yet a free-standing spawned test-print gameplay entity.
- No full place -> edit -> bake -> test -> export workflow exists yet.

## 18. Runtime traversal and crafting-bench demo slice

Locked in docs:
- No specific law block was added for this runtime sandbox branch.
- The branch should still remain honest to current Godot 4.6 scene, input, and UI patterns and must not pretend broader forge behavior exists where it does not.

Implemented in code:
- The main runtime sandbox now includes a controllable CharacterBody3D player with OTS camera, WASD movement, and jump on the Space key.
- PlayerController3D now supports a UI mode that releases mouse capture and halts movement while an interface is open.
- A world CraftingBench scene now exists as an interactable StaticBody3D in the sandbox.
- The player can hit the bench with the current interaction ray and open a Control-based crafting interface.
- The crafting bench owns a ForgeGridController instance and drives the current forge bake path from the UI.
- The bench UI now provides a minimal authored layered voxel editor for the active WIP by letting the user edit a 12 x 3 slice across two layers.
- The bench UI can now switch between grip, flex, and ranged-bow sample presets, reset the current preset, rebake the edited WIP, read the active WIP snapshot, display resolver diagnostics plus baked profile/capability output directly from the current code path, and show a compact color-coded preset-expectation panel for quick regression checks.
- The bench scene now exposes a preview root while ForgeGridController owns and updates the visible active test-print mesh generated from the current TestPrintInstance cell set.
- The sandbox, bench, UI, and player runtime path is present end to end, and the earlier CraftingBenchUI property-access issue around theme_override_constants on HBoxContainer has been fixed.
- The current bench/editor surface should be treated as a working provisional test surface, not yet as the intended authoritative forge station design.
- A dedicated headless Godot preset harness now exists and has runtime-verified the current grip, flex, and bow sample paths through the real engine.

Still pending:
- The bench editor is currently a minimal first-pass layered voxel editor, not the full forge grid/layer authoring interface described by the broader project vision.
- The visible preview is still not a full spawned world-side test-print object flow.
- A fresh full editor reload/problem capture is still needed to measure broader warning debt outside the files already touched.

## 19. Current project status in one sentence

The project is structurally complete across the current first-slice profile field set, with WIP-carried ranged context, first-pass joint and bow validation, sample presets that are now runtime-verified in Godot, a playable traversal sandbox, responsive viewport-safe crafting and disassembly station UIs, and a forge data layer that now reads authored rules, presets, view tuning, material catalog order, and inventory seed quantities from shared `.tres` resources, but the present station/editor surfaces are still provisional, broader Godot warning debt has not yet been fully re-captured, and substantial unfinished work remains in full forge authoring, broader storage/logistics presentation, runtime articulation, specialization workflows, and later multiplayer-facing systems.

## 20. Practical next implementation boundary

The next clean in-scope step is:
- keep using `FULL_REPO_AUDIT_FIX_LEDGER_2026-04-01.md` as the active cleanup order instead of ad-hoc patch stacking
- keep correcting wrong foundations first, especially where the current canonical item geometry stage, runtime owner boundaries, or resolver decision ownership still lag behind the project law
- keep the current bench/editor implementation framed as a temporary test harness surface rather than the final presentation of the forge station, and avoid treating layout work as final art direction
- keep moving unresolved forge truth and authored data into defs/registries/resources wherever the docs already support that move
- use the now-live body inventory / personal storage / transfer authority layer plus the first raw-drop disassembly bench UI slice as the support surface for the next storage and logistics work instead of inventing parallel temporary item state

That means:
- do not broaden capability math beyond fields backed by real profile values
- do not treat the current connected sandbox bow sample plus logical region extraction pass as final authored ranged physical weapon truth
- do not continue expanding the current bench/editor structure as if it already matches the intended crafting-station vision
- do not pretend the current crafted-item runtime mesh path is already the final canonical solid/chamfer-ready geometry stage
- keep this memory document, the audit ledger, and project-aligned workaround.md as the authority set while the runtime exercise path catches up

Only after that should the project move into broader page/context flows, runtime articulation behavior, or later specialization systems, unless a newer approved rule block changes the order.

## 21. Known Godot warning/problem list to keep in mind

Current attached warning/problem context says:
- the attached screenshot captured multiple shadowing warnings, including local names such as basis, input_event, and several layer identifiers that collide with base-class names or signals
- the attached screenshot also captured intentionally or accidentally unused parameters, including material_lookup in certain validation helpers, reference_center in resolve_bow_axes, and shape_data in bake_profile
- the attached screenshot captured one integer-division warning in the joint path
- the attached screenshot captured one active runtime issue in CraftingBenchUI._create_cell_buttons around invalid access to theme_override_constants on HBoxContainer

Implementation meaning:
- these are current WIP debt markers, not yet the primary mochi completion gate
- they should stay visible in planning and memory so later mochi passes do not mistake the project for being fully runtime-clean
- future implementation should avoid adding more shadowing, unused-parameter noise, or UI-property-access assumptions while the slice is still being completed
- M1 first pass has already reduced part of this list inside the active forge/runtime surface by fixing the HBoxContainer property-access issue, renaming several shadowing locals, quieting several unused-parameter warnings in the touched resolver path, and removing the specific integer-division warning in JointResolver
- M2 runtime verification then exposed and fixed one additional connected-bow typed-array runtime fault in BowResolver that did not show up in static diagnostics alone
- the last successful headless harness run exited cleanly with no script/runtime errors, but that run is not the same thing as a fresh full editor Problems-panel capture
- a fresh Godot reload/problem capture is still needed later to measure what warning debt remains outside the files already touched in the current pass
- the recurring Windows root certificate store warning should currently be treated as default external noise unless it starts correlating with an actual project-side failure path

## 22. Mochi execution map

Current rough split:
- in progress: about 75 to 80 percent of the remaining first-slice mochi work
- true todo: about 20 to 25 percent of the remaining first-slice mochi work

What counts as in progress:
- segment truth is active but incomplete: role derivation remains partial and edge-span overlap is still missing
- System 1 is active but incomplete: grip legality exists, edge/blunt legality does not
- System 2 is active but incomplete: joint validation exists, runtime articulation and membrane behavior do not
- System 3 is active but incomplete: bow validation exists, final authored bow-builder semantics do not
- System 4 is active but incomplete: all required first-slice profile fields exist, but some truth paths still need runtime exercise or richer upstream rules
- System 5 is active but incomplete: first-pass capability math exists, broader context math and threshold/tier handling do not
- sandbox and bench flow are active but incomplete: preview and bench editing exist, final forge authoring flow and spawned world-side test-print flow do not

What counts as true todo:
- finalized-item export and provenance flow
- real context/page builders above material truth for melee, ranged, shield, magic, and later related sections
- full world-side test-print gameplay/entity flow
- full forge grid/layer authoring interface beyond the current minimal bench editor

Ordered mochi continuation from here:
1. M1: stabilize the live runtime surface by keeping the known Godot warning/problem list visible, removing active runtime breakage in the current forge path, and reducing high-noise warning debt that directly affects the playable sandbox slice
2. M2: runtime-verify the flex and bow presets inside Godot when executable access is available
3. M3: resume forge/editor surface work only after a clearer authoritative crafting-station definition is supplied, then align the bench/editor structure to that definition instead of extending the current provisional shape by inertia
4. M4: complete missing truth-stack pieces that are already partially live, including segment role derivation, edge/blunt legality, richer validation reporting, and remaining runtime exercise of existing profile/capability paths
5. M5: only after that move into broader page/context flows, runtime articulation behavior, spawned world-side test-print flow, and later specialization layers unless mochi authority changes the order

Current checkpoint state:
- M1 is in progress and has already received a first cleanup pass plus one engine-confirmed runtime follow-up fix in the connected-bow path
- M2 is now runtime-verified through the local Godot 4.6.1 console build using a dedicated headless preset harness
- M3 is intentionally paused pending a better-defined authoritative forge station / editor description
- M4 to M5 have not started yet as explicit checkpointed work items

Current runtime-confirmed M2 read:
- grip sample bakes cleanly with primary_grip_valid=true, balance_score=1.0, flex_score=1.0, launch_score=0.0, and bow_valid=false because it is not in ranged context
- flex sample runtime-verifies the current joint path with joint_valid=true, flex_score=0.75, and launch_score=0.0, but it still reports validation_error=no_primary_grip_candidate under the current overall profile rules
- bow sample now runtime-verifies the connected-bow logical extraction path with bow_valid=true, string_tension=1.0, flex_score=1.0, and launch_score=1.0 after fixing a connected-bow typed-array runtime fault exposed during the first harness run
- the bow sample still reports validation_error=no_primary_grip_candidate at the profile level, so current ranged proof is specifically about bow-path exercise, not yet a full all-rules-clean crafted profile

Explicit state-right-now summary:
- resolver/service/runtime sample flow is live and engine-exercised
- current bench/editor flow is usable as a debug/proof surface but is not yet the intended forge-station presentation
- M1 is not finished because full warning-debt recapture has not been done yet
- M2 is finished as a runtime verification milestone for the current sample presets
- the next editor-side structural work should wait for the clarified definition rather than extending the provisional interface further

Planning rule:
- when deciding the next task, prefer advancing an in-progress bucket before opening a brand-new todo bucket unless a blocker forces the order to change

## 23. 2026-03-26 reconciliation addendum

This addendum supersedes older lines above where they overlap.

Past:
- the older mochi v1 note is no longer just a plan stub; its live-compatible under-the-hood items were audited, reconciled, and folded into code where they did not conflict with the current project
- deterministic variant ids, deterministic stack ids, disconnected-build validation, optional baked-profile snapshots on WIPs, and stale-snapshot clearing on edit now exist in the live codebase
- wood/iron tier, raw-drop, and process-rule reference-point resources now exist as the first material-pipeline anchors beyond the base material defs alone

Present:
- the forge station is still a provisional working surface, but it is now materially more data-driven than the older memory snapshot implies
- ForgeRulesDef now points at authored sample presets, forge inventory seed data, and forge material catalog data instead of leaving those paths only to local controller discovery
- the grounded forge-ready roster is now 16 materials wide and the active default seed also covers those same 16 materials
- the current 2026-03-26 headless forge material verification pass confirmed `material_lookup_count=32` because the lookup now intentionally contains both internal base defs and gray-quality runtime variants, while the player-facing authored catalog stayed clean at `material_catalog_count=16` with `material_catalog_matches_expected=true`; `inventory_seed_entry_count=16` and `seeded_stack_count=16` also remained correct
- the forge inventory seed path now also supports a data-driven debug bonus floor through ForgeRulesDef, and the current 2026-03-28 verification pass confirmed the active test baseline is `5096` per seeded gray forge material (`96` authored seed plus `5000` debug bonus) rather than the earlier `96`-only sandbox stock
- the current 2026-03-26 material-pipeline verification pass confirmed `raw_drop_registry_count=16`, `process_rule_registry_count=16`, `valid_pipeline_count=16`, and `all_catalog_materials_have_valid_pipeline=true`
- the current 2026-03-26 material-variant carry-through verification pass confirmed `mat_wood_green` resolves correctly from the naming law, green variant stat lines and cap_flex bias are greater than gray as expected, density remains unchanged at the current tier table, and baked profiles now preserve the resolved variant mix plus resolved stat/bias aggregates
- the current 2026-03-26 inventory/storage authority verification pass confirmed `body_state_save_exists=true`, `personal_storage_save_exists=true`, `raw_drop_partial_transfer_success=true`, `finalized_item_transfer_success=true`, `route_material_stack_success=true`, and `forge_inventory_routed_quantity=6`
- the player-facing authority surface under that pass now includes StoredItemInstance, PlayerBodyInventoryState, PlayerPersonalStorageState, ForgeStorageRulesDef reference points, and InventoryStorageService routing between owned-item storage and forge material counts
- the shared `user://` save-directory helper path was also hardened across the new storage states plus the pre-existing WIP library and user settings models so directory creation no longer depends on historical folders already existing
- the current processed-material routing path lands default gray processed outputs in forge inventory under variant ids such as `mat_wood_gray`, and the present forge bench now reads authored gray-quality catalog ids for placement while keeping base-material ids as the internal resolver anchor layer
- the 2026-03-26 naming audit also normalized the live raw-drop ids to the same quality-aware scheme, so the current first-slice gray drops now use ids such as `drop_wood_raw_gray` rather than the older generic non-quality raw-drop pattern
- the current forge plane view, free workspace preview, and test-print mesh builder now all resolve colors from variant ids through the shared material runtime resolver instead of treating non-base ids as unknown-material fallback cases
- the menu and forge windows were also made viewport-safe during this period, but those presentation/layout improvements should still be treated as support work around the forge proof surface rather than final art direction
- the current 2026-03-28 forge workspace UX pass also replaced the old side-by-side `2D + 3D` center split with a swap-based main/inset model: default forge editing now opens as `3D main workspace + 2D inset minimap`, the inset stays inside the work area at both `1280x720` and `1024x576`, a flip button can swap to `2D main + 3D inset`, the 2D inset now supports wheel zoom, and the older always-on debug/status text was moved into a separate scrollable popup behind its own Debug button so the center workspace can stay focused on authoring
- the current 2026-03-28 forge preview-light pass also moved the workspace directional light into a camera-following path controlled by ForgeViewTuningDef, so the light now travels with the forge camera instead of leaving one side of the model in a fixed shadow zone while orbiting; the camera verifier confirmed `light_parent_is_camera=true`, `light_changed_with_orbit=true`, and `light_aligned_to_camera=true`
- the current 2026-03-28 forge viewport-input follow-up also removed the remaining 3D zoom dead strips around the free workspace panel by routing wheel zoom through the whole visible 3D panel surface instead of only the inner SubViewportContainer, while keeping paint/orbit interactions bound to the actual viewport area; the camera verifier confirmed `panel_wheel_zoom_changed_distance=true`, and drag-place / drag-erase verification stayed clean afterward
- the current 2026-03-28 forge input pass also added continuous click-drag authoring instead of single-cell-only clicks: the 2D layer view now tracks held-button strokes so left-drag can paint with the active tool and right-drag can continuously erase, while the 3D workspace now supports left-drag paint strokes that follow the hovered grid cell with the active tool; the headless drag verifier confirmed both place and erase strokes succeed in both views with `plane_drag_place_success=true`, `plane_drag_erase_success=true`, `free_drag_place_success=true`, and `free_drag_erase_success=true`
- the current 2026-03-28 forge responsiveness/control pass then addressed three follow-up friction points: off-grid 3D clicks now reject instead of clamping to edge cells, edit-time place/remove no longer trigger the full forge UI/status rebuild on every voxel change and instead use a lighter live-edit refresh path while leaving heavy debug/profile reporting behind the popup until requested, and the 3D camera pitch plus layer controls were widened so the preview can now look from underneath and held layer stepping now honors a `0.5s` delay before repeating at roughly `10 layers/sec`; the control verifier confirmed `offgrid_top_left_rejected=true`, `offgrid_bottom_right_rejected=true`, `can_look_underneath=true`, `layer_hold_delay_respected=true`, and `layer_hold_repeat_advanced=true`
- the current 2026-03-28 forge responsiveness follow-up pass then removed more of the edit-path churn that was still making placement feel sticky under real use: ForgeGridController now keeps an active cell lookup instead of scanning all layers for every add/remove/query, the 2D plane viewport now draws only occupied cells on the active slice instead of checking every grid coordinate against the full WIP repeatedly, the 3D workspace preview now reuses its MultiMesh/cell mesh instead of constructing fresh preview objects on each sync, test-print clearing no longer emits redundant change signals when no test print exists, and edit-time forge UI refreshes are now coalesced so workspace visuals update continuously while heavier inventory/material side-panel refreshes are throttled and flushed after a stroke or short interval instead of per hovered voxel; the existing paint-drag, controls, and project-load verifiers all stayed green after this pass
- the current 2026-03-28 forge project-management pass also made saved work practical to resume: the forge project panel now exposes explicit `Load Selected` and `Resume Last` actions, clicking a saved project still loads it directly, and reopening the forge with no active draft now auto-restores the last selected saved player project instead of silently dropping back to a sample/default WIP; the project-load verifier confirmed `auto_restore_selected_beta=true`, `manually_loaded_alpha=true`, `selected_wip_id_after_manual_load=<alpha id>`, and `reopened_selected_alpha=true`
- the current 2026-03-27 salvage/disassembly verification pass confirmed `available_item_count=2`, `preview_valid=true`, `preview_wood_quantity=18`, `preview_iron_quantity=12`, `unconfirmed_commit_applied=false` with `irreversible_confirmation_required`, `confirmed_commit_applied=true`, and `stale_commit_failure_reason=selection_stale`
- the first live disassembly authority slice is intentionally narrow: only supported raw-drop inputs currently appear as available disassembly items, finalized-item salvage stays blocked until finalized material makeup exists, and blueprint / chase-skill branches remain disabled rather than guessed
- the current 2026-03-27 disassembly-bench UI verification pass also confirmed `layout_inside_1280x720=true`, `layout_inside_1024x576=true`, `selected_count_after_pick=1`, `disassemble_disabled_before=true`, `disassemble_disabled_after_check=false`, `body_remaining_after_commit=4`, `forge_wood_quantity_after_commit=24`, `main_scene_loaded=true`, and `disassembly_bench_present=true`
- a reusable saved-WIP rule-diagnosis harness now exists in `tools/diagnose_saved_wip_rules.gd`; it loads a real saved forge project from the player WIP library, rebuilds its live segment/anchor/profile state through the engine path, and writes segment-by-segment gate facts that can be reused for grip, edge, blunt, guard, pierce, and similar later rule debugging without relying on UI impressions alone
- the old saved `test_sword` diagnosis captured a real structural problem in the earlier model: the sword resolved as one connected segment with `segment_count=1`, `anchor_count=0`, `profile_validation_error=no_primary_grip_candidate`, `cross_width_voxels=7`, `cross_thickness_voxels=9`, and `anchor_material_ratio=0.42680412371134`, so the former whole-segment grip law rejected it before a handle-local reading could exist
- the current 2026-03-28 anchor-area pass replaced that rigid model with grip-span detection inside connected segments; the deterministic connected-sword verifier now confirms `segment_count=1`, `anchor_count=1`, `primary_grip_valid=true`, and `primary_grip_span_length_voxels=12`, and the refreshed saved-`test_sword` diagnosis now confirms `anchor_count=1`, `profile_primary_grip_valid=true`, and a stored grip span from `(74.0, 39.0, 19.5)` to `(99.0, 39.0, 19.5)`

Future:
- keep extending the grounded material/resource layer where the docs already name the materials, but do not jump ahead into invented families or unsupported system behavior
- continue the unfinished forge truth stack next: segment-role follow-through, edge/blunt legality, richer validation reporting, broader profile/runtime exercise, and later context/page builders
- when debugging future forged shapes, prefer the saved-WIP rule-diagnosis harness over one-off visual guesses; extend that same method for edge/blunt and later rule families instead of inventing separate ad-hoc inspection paths per system
- use the now-complete grounded raw-drop/process reference layer as the support surface for later storage, disassembly, and logistics work instead of building those features directly on loose per-file assumptions
- the concrete disassembly-bench visual target and working UX note are now backed by a first honest raw-drop bench UI slice in the traversal sandbox, but stationary storage interactables/pages, finalized-item/contextual disassembly outputs, and the remaining processed-material-to-placement unification work are still the next structural steps rather than optional polish
- leave networking, Steam, and other later multiplayer adapters on the shelf until the local/systemic foundations are further along

## 24. 2026-03-28 player / storage / equip-test addendum

This addendum supersedes older lines above where they imply the player side is still only the original capsule-and-box placeholder with no player-facing storage/equipment shell.

Past:
- the previous live traversal sandbox only had the simple placeholder body plus forge/disassembly benches
- the player controller already owned body inventory, personal storage, forge inventory, and forge WIP library state, but there was no dedicated equipment state, no shared player inventory overlay, no stationary personal-storage interactable, and no way to attach a saved forge WIP to the character's hand for forge-internal testing outside the bench preview itself

Present:
- the player placeholder is now an explicit `2.0m` standing humanoid shell instead of the earlier box-only body; `player_character.tscn` now instances `player_humanoid_rig.tscn`, and the verification harness confirmed `humanoid_height_meters=2.00` with `humanoid_height_is_two_meters=true`
- the new humanoid rig is still placeholder art, but it now includes a real `Skeleton3D` bone layout plus explicit left/right hand anchor nodes for later held-item, IK, animation, or more detailed mesh replacement work
- the first arm pass looked too broken/jointed in practice, so the placeholder rig now derives the visible shoulder/arm segments from the actual skeleton rest positions instead of freehand box placement; this keeps the neutral pose readable without changing the verified `2.0m` standing height or the hand-anchor contract
- the placeholder mannequin shell has now been superseded by the imported `Josie` baseline model under `res://Josie`; `player_humanoid_rig.tscn` now wraps that authored scene instead of generating a procedural body, while keeping the same public rig interface for the controller/equipment code
- the authoritative current weapon attachment bones are `CC_Base_R_Hand` for the primary/right hand and `CC_Base_L_Hand` for the secondary/left hand; the wrapper rig creates explicit `RightHandItemAnchor` and `LeftHandItemAnchor` nodes on those bones so future equipment or combat work should continue to target the anchor nodes, not raw controller transforms
- the Josie wrapper scales the imported model to the project's standing-height rule of `2.0m`, and the verifier confirmed `visual_height_is_two_meters=true`, `default_animation=Idle`, plus both hand anchors resolving against the correct bone names
- the imported Josie mesh now has an explicit `MeshInstance3D.skeleton = ".."` path in the scene instead of relying on the older implicit-parent skeleton behavior; this matters under Godot `4.6`, where the old default-parent binding assumption is no longer safe for skinned meshes
- the Josie scene was also repacked under the current Godot `4.6.1` project after that bind fix, which cleared the old imported `ArrayMesh` surface-format warning that had been reappearing on every player/model verification run
- the Josie wrapper now also exposes the authored baseline locomotion clips already embedded in `josie.tscn` instead of leaving the model parked on `Idle` forever; the current rig/controller path can now reach `Idle`, `Walk`, `SlowRun`, `Run`, `Jump(Pose)`, and `Fall(Pose)` through a small locomotion state layer driven by grounded state, current horizontal speed, and sprint input
- the rig now also has a first runtime hand-grip pose layer for held weapons: when a hand actually has a mounted held item, the wrist plus individual finger and thumb joints receive additive local curl/hold offsets so the palm reads more tangential to the weapon instead of staying flat-open; the pose is deliberately exposed as tuning data in the rig script because final finger/wrist fit still needs hand-authored art-side tuning later
- Josie's imported locomotion clips were also carrying explicit finger-bone tracks, which meant the visible mesh could ignore runtime finger hold posing even though the skeleton and skin data were valid; the current rig now strips those finger tracks from the runtime animation copies on load, and a dedicated verifier confirmed all 30 left/right finger bones still have real mesh influence weights
- the hand-held item anchor no longer defaults to the raw hand-bone origin when no explicit offset is authored; the wrapper now derives a first palm-position offset from the proximal finger/thumb rest positions, and the current verifier confirms both hand anchors now resolve to non-zero local offsets instead of wrist-origin placement
- the shared player inventory overlay now follows the same containment rule as the forge and system menu shells: the central pages live inside a dedicated scroll region, dense action rows can wrap instead of overflowing, and the verifier now confirms the panel stays inside `1280x720` and `1024x576`
- player-owned equipment now has its own save-backed state surface through `PlayerEquipmentState` plus `EquippedSlotInstance`; this keeps hand-test occupancy and future finalized-item occupancy out of ad-hoc controller variables
- equipment slots are now data-driven through `equipment_slot_registry_default.tres` instead of being hardwired into the overlay/controller; the current first slot shell includes `hand_right`, `hand_left`, `helmet`, `chest`, `pants`, `boots`, `gloves`, `ring_left`, `ring_right`, `bracelet`, `necklace`, `belt`, `earring_left`, and `earring_right`
- the new `PlayerInventoryOverlay` is the shared player-facing authority surface for:
  - equipment slot inspection / clearing
  - on-body inventory
  - personal storage
  - forge material logistics view
  - saved WIP project view
- `ui_inventory` now opens that overlay on the body-inventory page and `ui_character` opens it on the equipment page; the same overlay can also be opened from a world storage object directly into the storage page
- the traversal sandbox now includes a placeholder `StorageBox` interactable wired to that same overlay, so the storage access-point pattern is no longer only an idea on paper
- the current first WIP-to-character bridge is deliberately forge-internal only: saved WIPs can now be marked as the preferred forge project from the player overlay and can be test-equipped into `hand_right` or `hand_left` if they pass the current grip-valid forge test gate
- the active hand-test path rebuilds a `TestPrintInstance` from the saved WIP through the live forge service, checks `primary_grip_valid`, and then mounts the resulting mesh to the corresponding hand anchor; the player-side verification harness confirmed `preview_valid=true`, `equip_success=true`, `right_hand_entry_is_forge_test=true`, and `right_hand_visual_child_count=1`
- on-body inventory and personal storage are now practical through the shared overlay rather than only model/service work; the player-side verification harness confirmed `moved_to_storage=true` and `moved_back_to_inventory=true`
- the traversal sandbox verification harness also confirmed the world-side placeholder access point exists with `storage_box_exists_in_world=true`

Present boundary:
- finalized-item equipment is still structurally incomplete because finalized-item data is still too thin to drive slot legality, held visuals, armor visuals, or world-valid combat usage honestly
- hand-held WIP visuals currently prioritize correctness of the live forge/test data chain and hand-anchor presence over final display/orientation polish; the item can now be mounted to the player, but later hand-rotation / stance / animation tuning is still expected
- the new runtime grip pose is a first believable hold layer, not final rig polish; it improves visible hand closure around held weapons, but weapon-specific hand fit, exact finger contact, attack-time hand changes, and later IK-driven gripping are still pending
- the earlier Godot reload warnings around shadowed local names and incompatible ternaries in the player/forge scripts were cleaned in the 2026-03-28 follow-up pass, and clean `--check-only` runs now exist for `player_humanoid_rig.gd`, `forge_plane_viewport.gd`, `forge_workspace_preview.gd`, and `forge_grid_controller.gd`
- the humanoid placeholder is now using the imported Josie locomotion/pair of jump-fall pose clips for baseline traversal state, but attack animation, IK, aim/body-follow logic, and deeper body-deformation work are still pending
- the first player aim baseline is now in place: the player scene has a center-screen crosshair overlay, a reusable camera-based aim-context solver that resolves world aim point / aim distance / flat aim direction from the current viewport center, and the character root now uses that flat aim direction as its baseline facing reference instead of only movement direction
- pressing `S` now resolves as true backpedal from the current aim-facing reference instead of forcing a turn-to-run-forward behavior, with the currently requested `10%` speed penalty applied through the shared movement-speed resolver; the dedicated aim verifier confirmed `backpedal_speed=4.95`, `forward_speed=5.5`, and `backpedal_is_penalized=true`
- this is intentionally only the first aim slice: head/chest follow weighting, upper-body bias, weapon-guided arm solving, actual crosshair-targeted attack execution, and skill-range-aware hit logic are still pending on top of this new aim-context foundation
- the shared overlay is functional and responsive, but it is still a systems shell, not final UI art direction

Future:
- next player-side structural work should continue from this shell instead of re-creating parallel inventory/storage/equipment paths elsewhere
- finalized-item provenance/category/slot data needs to grow before normal world-valid equipment can honestly occupy the non-hand slots
- forge `test work` can later become a stronger first-class button/flow that feeds directly into this same hand-test equipment surface instead of remaining an indirect WIP-page action
- armor/accessory visual follow-through, hand-usage handedness preferences, and later combat-slot / ability-slot integration should build on the new equipment-state shell rather than bypass it

## 25. 2026-03-29 aim-follow / turn-speed / IK-scaffold addendum

This addendum supersedes older player-motion lines above where they imply the current player slice stops at a static crosshair, single-speed facing, or no body-follow beyond basic locomotion playback.

Past:
- the first 2026-03-29 player aim slice already added the center-screen crosshair plus the reusable camera-based aim solver that resolves world aim point / flat aim direction from the viewport center
- that same slice already switched `S` into real backpedal with the requested `10%` speed penalty instead of a forced turn-around run-forward behavior

Present:
- the player rig now has an explicit upper-body aim-follow layer on top of locomotion: waist, spine, neck, and head tracks are stripped from the runtime locomotion copies and replaced by a weighted local aim-follow solve, with the head leading the waist rather than the whole torso rotating as one rigid block
- the current 2026-03-29 verifier confirmed `waist_changed=true`, `spine02_changed=true`, `head_changed=true`, `head_leads_waist=true`, and `spine_leads_waist=true`, so the upper-body aim-follow slice is now engine-verified rather than just code-present
- the old always-face-crosshair locomotion law has now been split: body facing is movement-driven during normal travel so the player can strafe/orbit a target while keeping it in view, and a dedicated runtime hook now exists for later combat/skill systems to temporarily force crosshair-facing even in the air when a skill actually fires
- the current head/look target routing now follows the new player rule instead of a fixed crosshair lock: if the crosshair target stays within `150°` of the character's current forward direction on the XZ plane the look solve prioritizes the crosshair, but for the rear `60°` behind the character it falls back to the player-camera direction instead; backpedal (`S`) also explicitly forces camera-priority look
- the dedicated movement/look verifier now confirms `movement_facing_matches_move=true`, `skill_facing_matches_crosshair=true`, `crosshair_priority_active=true`, `rear_camera_fallback_active=true`, and `backpedal_camera_override_active=true`
- the player-facing turn-response layer is now state-sensitive instead of single-speed: current exported defaults are `idle_turn_speed=12.0`, `move_turn_speed=10.0`, `sprint_turn_speed=7.5`, `backpedal_turn_speed=8.5`, and `air_turn_speed=6.5`
- the current 2026-03-29 turn-speed verifier confirmed those values resolve correctly and that idle / move / backpedal all currently turn faster than sprint, matching the first intended “different speeds for different movement states” milestone
- the locomotion integration still remains valid after that work: the current verifier still confirms `Idle`, `Walk`, `SlowRun`, `Run`, `Jump(Pose)`, and `Fall(Pose)` all resolve through the live movement-state path
- a first Godot-4.6 modifier-based IK baseline now exists in `player_humanoid_rig.gd` and `player_humanoid_rig.tscn`: explicit `IkTargets` nodes are present for left/right hands and feet plus pole targets, and the rig now creates `RightArmIK`, `LeftArmIK`, `RightLegIK`, and `LeftLegIK` `TwoBoneIK3D` modifiers under the live skeleton
- that modifier baseline is now enabled by default in the runtime exports, and the verification surface is split into two honest readings:
  - the stricter arm-focused scaffold verifier now confirms the arm modifier path converges through the post-modifier read correctly with `right_hand_near_target=true`, `right_hand_distance_to_target=0.0`, and a real right-hand solve delta
  - the real player-scene foot verifier now confirms the planted-foot path converges correctly in the actual character context with `right_foot_near_target=true` and `right_foot_target_on_floor=true`
- the older standalone rig-only foot reading still overstates the foot gap because that isolated harness does not reflect the same full character-body context as the real player scene, so future foot work should continue to judge the live player verifier as the authoritative check rather than the rig-only shorthand
- the current modifier baseline should now be treated as the live first-pass hand/foot solve layer, not just a prepared experiment surface, while still expecting later pelvis/body compensation and richer attack-time arm logic on top
- the dedicated idle-leg diagnosis now shows why the current idle stance reads as squat + hover: with foot IK enabled the right foot is being driven exactly to the floor-lift target (`right_foot_y=0.0297`, `right_target_y=0.0297`, `right_foot_distance_to_target=0.0`) while the hip height does not change at all (`with_ik_hip_y=without_ik_hip_y=0.5429`), so the current baseline has no pelvis compensation; the visible hover is also intentional in the current exports because `foot_ik_target_lift_meters=0.03`
- the same diagnosis also shows the authored idle pose / root alignment is not yet a clean straight-leg baseline by itself: with foot IK disabled the right foot falls well below the world floor (`without_ik_right_foot_y=-0.2745`), so the current idle problem is not just IK being “too strong”; it is the combination of base idle pose/root alignment plus floor-lifted foot IK and missing pelvis correction
- the requested “use the original lower-body idle again” pass is now handled at the real override point instead of inventing a second locomotion source: the runtime animation prep only strips finger and upper-body aim tracks, so Josie’s imported lower-half idle was already intact; the live change for this pass is setting `foot_ik_idle_influence=0.0` in the rig so idle stops being overridden by foot IK and falls back to the authored lower-body animation again while moving foot IK stays available
- the next posture pass added a small additive forward-bias layer across pelvis, waist, spine, neck, and head after the aim/support solve so the character stops reading as permanently leaned backward / looking upward from the rear; the current defaults are intentionally mild and exposed in the rig as tuning exports instead of being buried in the controller

Present boundary:
- crosshair, aim context, backpedal, upper-body aim follow, locomotion playback, and differentiated facing-turn speeds are now live and verified
- the modifier-based IK baseline is now live enough to be treated as the first real hand/foot movement dependency, but it is still only a baseline: pelvis compensation, stronger secondary-hand logic, and later attack/skill-specific solve rules are still pending
- the next 2026-03-29 follow-up pass moved the first weapon-guided arm layer on top of that modifier baseline: held forge-test weapons now spawn an explicit `PrimaryGripGuide` at the mounted primary grip and, when the baked grip span is long enough, a `SecondaryGripGuide` on the rear half of the valid grip span
- the controller now feeds those live guide nodes into the humanoid rig instead of leaving the arms entirely on camera-aim guesses; the occupied hand receives a direct weapon guidance target, and if the opposite hand is free the rig can now activate a support-hand state from the baked grip span instead of treating every long handle as permanently one-handed
- the 2026-03-29 continuation pass also locked the rig-side bone naming against Josie’s real skeleton by exposing a required-bone audit from the humanoid rig itself; current support/body work is now explicitly verified against real `CC_Base_*` bones only, and the dedicated weapon-guidance verifier currently reports `required_cc_base_bones_present=true` with `missing_cc_base_bone_count=0`
- weapon guidance now distinguishes between a true equipped-hand palm solve and a support-hand helper solve: the occupied hand applies its palm anchor offset into the IK target, while the free support hand still rides the grip span as a guidance helper until later full support-palm tuning exists
- the current dedicated player-scene weapon-guidance verifier confirms that updated flow is structurally live with `preview_valid=true`, `equip_success=true`, `primary_grip_span_length_voxels=22`, `secondary_guide_exists=true`, `left_guidance_target_exists=true`, `left_guidance_target_name=SecondaryGripGuide`, `left_support_active=true`, `left_arm_influence=1.0`, and `left_support_target_matches_secondary=true`
- that same verifier now also confirms the first actually usable support-hand settle in the baseline pose: `left_hand_distance_to_support=0.1022`, `left_anchor_distance_to_support=0.0421`, and `left_hand_near_support=true`
- attack animation, skill movement, full weapon-guided hand solving, two-hand grip behavior, and final grounded foot/pelvis compensation are still pending on top of this new base
- first-pass weapon-guided hand solving and first-pass two-hand grip-span usage are now live, but they are still an early baseline rather than the final answer; the primary hand is now structurally guided at the palm/attachment level, the support-hand law exists and reaches the guide in the baseline test, and the remaining quality gap sits in pose polish, richer torso/pelvis compensation, and later attack-time hand behavior rather than missing routing logic

Future:
- the clean next body-motion continuation is now weapon-guided arm behavior, two-hand grip-span usage, and later pelvis / attack / skill posture layers on top of the already-live aim context, differentiated turn-response layer, and new modifier-driven hand/foot baseline
- the clean next body-motion continuation from here is no longer “invent weapon-guided hands,” because that first pass is now in; it is specifically to finish the remaining offhand/two-hand pose quality gap, then move into pelvis compensation and later attack / skill posture layers on top of the already-live aim context, differentiated turn-response layer, modifier-driven hand/foot baseline, and new grip-span-driven support-hand routing

## 26. 2026-03-29 stowed-weapon position addendum

This addendum supersedes older player/equipment lines above where they imply hand-mounted forge-test visuals are the only supported presentation state for saved forge weapons.

Past:
- the current player/equipment bridge could rebuild a saved forge WIP into a test-print visual and mount it to `hand_right` or `hand_left`, but there was no authored way to decide where that same weapon should rest when not drawn
- there was also no stored per-WIP presentation choice for whether a weapon should visually hang from the shoulder/back, ride at the hip, or sit at the lower back during non-combat presentation

Present:
- `CraftedItemWIP` now carries a save-backed `stow_position_mode` field with three normalized authored choices: `stow_shoulder_hanging`, `stow_side_hip`, and `stow_lower_back`
- those options are exposed directly in the forge project panel so the choice can be authored during the forge workflow instead of being bolted on later in equipment code
- the current project-panel labels and notes are:
  - `Shoulder Hanging` -> `Recommended for medium and long weapon builds.`
  - `Side Hip` -> `Recommended for short and medium weapon builds.`
  - `Lower Back` -> `Recommended for short weapon builds.`
- those notes are recommendations only; they do not disable or forbid any stow mode based on weapon size
- the crafting-bench UI now exposes those notes through a dedicated hover bubble that appears beside the focused option instead of covering the option list itself
- the dedicated UI verifier now confirms `option_count=3`, `default_mode=stow_shoulder_hanging`, `saved_mode_after_select=stow_side_hip`, and `tooltip_popup_visible=true`
- the humanoid rig now exposes real stow anchors on verified Josie `CC_Base_*` bones only:
  - `LeftShoulderStowAttachment` on `CC_Base_L_Clavicle`
  - `RightShoulderStowAttachment` on `CC_Base_R_Clavicle`
  - `LeftHipStowAttachment` on `CC_Base_L_Thigh`
  - `RightHipStowAttachment` on `CC_Base_R_Thigh`
  - `LeftLowerBackStowAttachment` on `CC_Base_L_Thigh`
  - `RightLowerBackStowAttachment` on `CC_Base_R_Thigh`
- the current runtime mapping follows the authored mirroring law:
  - `Shoulder Hanging`: right-hand-equipped weapon stows on the left shoulder side, left-hand-equipped weapon stows on the right shoulder side
  - `Side Hip`: right-hand-equipped weapon stows on the left hip side, left-hand-equipped weapon stows on the right hip side
  - `Lower Back`: the handle stays on the same side as the equipped hand, so right-hand-equipped weapons use the right lower-back anchor and left-hand-equipped weapons use the left lower-back anchor
- the dedicated runtime verifier now confirms all three current mappings are live with `shoulder_right_parent_matches=true`, `side_left_parent_matches=true`, and `lower_right_parent_matches=true`
- the equipped-forge-weapon visual builder now also creates a padded bounds scaffold around the generated WIP/test-print mesh:
  - a child `WeaponBoundsArea`
  - a child `WeaponBoundsShape`
  - bounds sized from the active display-cell box plus `+1` cell of padding in all directions
- this bounds scaffold is intentionally non-colliding right now (`collision_layer=0`, `collision_mask=0`, monitoring disabled) so it can exist as later animation / illegal-overlap support truth without colliding against the player capsule yet
- the runtime verifier confirms that scaffold is currently present with `weapon_bounds_area_exists=true`, `weapon_bounds_shape_exists=true`, and `weapon_bounds_has_padding=true`
- the player-side visual system now understands a `weapons_drawn` state toggle; when weapons are not drawn, the held visual path can mount to the authored stow anchor instead of the live hand anchor
- for the current forge-testing workflow that state still defaults to `true`, so existing hand-test weapon presentation remains unchanged unless the stow state is explicitly used
- the 2026-03-29 grip-orientation follow-up finally moved the authored `Normal Grip` / `Reverse Grip` choice into the live held-weapon builder instead of leaving it as forge-only metadata: held weapons now apply one shared base long-axis roll to match forge-bench presentation for both hands, and `Reverse Grip` adds a `180°` local `Vector3.UP` flip on top of that; the earlier attempt at an additional left-hand-only correction was removed because it overcompensated and produced the wrong live result
- reverse-grip presentation also now suppresses the generated `SecondaryGripGuide` / two-hand support helper on purpose, because the current design law says reverse grip cannot use two-handed weapon techniques
- the new orientation verifier now confirms the function layer rather than only the world pose read: `right_reverse_changes_local_forward=true`, `left_reverse_changes_local_forward=true`, `left_normal_uses_left_hand_roll_correction=true`, `right_reverse_has_secondary_guide=false`, and `left_reverse_has_secondary_guide=false`
- the stow work did not break the current player or forge UI slices: the latest verification still confirms the player inventory/equipment shell loads and the current forge bench layout remains inside `1280x720` and `1024x576`

Present boundary:
- the stow anchors are structurally correct and verified, but their exact offsets/angles are still first-pass tuning values rather than final art-side presentation
- the padded weapon bounds are currently support data only, not yet part of the animation legality solver or collision rules
- the player still defaults to drawn-weapon presentation in the current forge test loop, because the immediate goal was to add the authored stow system without disrupting existing hand-guidance testing

Future:
- the next body/animation passes should consume this new stow-position choice when building true draw/stow combat state transitions instead of inventing a separate storage pose system later
- the padded weapon bounds scaffold should become one of the inputs for later anti-clipping / movement-legality checks once attack and locomotion posture work advances further
- when later finalized-item export grows up, the same stow-position law should carry forward from forge-authored WIP truth into the exported equipment presentation path rather than being duplicated in a second naming or equipment-only surface

2026-03-31 small reversible player-rig pass:
- the clean rebuilt Josie rig now has a minimal live two-hand support layer on top of the already-verified grip math, instead of the older full pose/IK stack
- this pass only adds support-arm guidance for one drawn weapon with a free offhand; it does not bring back the removed aim-follow / posture / foot-IK forcing systems
- the weapon visual builder now uses the resolved grip-hold layout directly:
  - dominant-hand mesh offset now comes from `dominant_hand_local_position`
  - a `PrimaryGripGuide` is created at the dominant grip origin
  - a `SecondaryGripGuide` is created only when the baked grip layout says two-hand character usage is eligible and the saved grip style is not reverse grip
- the rig now exposes a minimal support-arm IK surface using verified Josie `CC_Base_*` bones only:
  - right arm chain: `CC_Base_R_Upperarm -> CC_Base_R_Forearm -> CC_Base_R_Hand`
  - left arm chain: `CC_Base_L_Upperarm -> CC_Base_L_Forearm -> CC_Base_L_Hand`
- the controller now only activates that support-arm guidance when exactly one hand is holding a drawn forge-test weapon and the opposite hand slot is free; dual-wield and stowed presentation leave the support arm alone
- current verifier result in `player_weapon_guidance_results.txt`:
  - `secondary_guide_exists=true`
  - `left_guidance_target_exists=true`
  - `left_support_active=true`
  - `left_support_target_matches_secondary=true`
  - `left_anchor_distance_to_support=0.042`
  - `left_hand_near_support=true`
- the grip-layout math pass still stayed correct after this live layer was added; `player_grip_hold_layout_results.txt` still confirms the centered pole case clamps to the character span and the front-heavy case still resolves dominant/support bias correctly

Present boundary:
- this is intentionally a small live support layer, not a return to the old full-body runtime forcing stack
- only the free support arm is being guided to the weapon right now; no feet, spine, or generalized aim-follow systems were reintroduced in this pass
- reverse grip still suppresses two-hand support on purpose

2026-03-31 held forged-item material-face fix:
- player-held forged test items were generating per-face vertex colors correctly, but the live held `MeshInstance3D` did not have a material override telling Godot to use vertex colors as albedo
- that made mixed-material crafted weapons read as one flat default metallic/gray-looking surface in the player hand even when the saved WIP still had multiple material variants
- the fix was intentionally small and local in `runtime/player/player_controller.gd`:
  - the held item mesh instance now gets a dedicated `StandardMaterial3D`
  - `vertex_color_use_as_albedo = true`
  - roughness / metallic reuse the forge test-print tuning values from the shared forge view tuning resource
- focused verifier `player_held_item_materials_results.txt` now confirms:
  - `material_override_exists=true`
  - `material_override_uses_vertex_color=true`
  - `unique_vertex_color_count=2`
  - `multiple_visible_material_colors=true`

## 27. 2026-04-02 audit-led cleanup and ranged/shield foundation addendum

This addendum supersedes older lines above where they imply the current cleanup focus is still mostly about first-slice sample/runtime verification rather than about correcting foundations and reducing mixed ownership.

Present:
- a dedicated full-repo audit/fix ledger now exists in `FULL_REPO_AUDIT_FIX_LEDGER_2026-04-01.md`, and it is the active ordering authority for cleanup work
- the audit rule is now explicit and project-wide:
  - data can be provisional
  - core systems cannot be provisional hacks
  - if the foundation is wrong, stop and correct it
  - do it the correct way the first time
- the forge side is materially cleaner than before the audit:
  - `crafting_bench_ui.gd` no longer owns the same giant mixed block of workflow, material catalog, workspace interaction, project-panel, session, refresh, debug, and menu responsibilities directly
  - those responsibilities now largely live in dedicated forge presenters/helpers
- the player/runtime side is also materially cleaner:
  - `player_controller.gd` no longer directly owns the same mixed pile of persistent state access, forge hand-test flow, held-item presentation, world interaction glue, and UI-surface routing
  - those responsibilities now largely live in:
    - `player_runtime_state_presenter.gd`
    - `player_forge_test_presenter.gd`
    - `player_equipped_item_presenter.gd`
    - `player_interaction_presenter.gd`
    - `player_ui_surface_presenter.gd`
- the inventory and system-menu overlays are also now further split:
  - inventory refresh/interaction/session/navigation/layout/text/page/action responsibilities are no longer all buried in one overlay shell
  - system menu layout/controls/page/settings/session responsibilities are no longer all buried in one overlay shell
- the player shell, forge shell, and UI shell are therefore safer foundations to continue building on without reintroducing patch-on-patch growth
- the forge controller also now uses explicit authoring-preview naming for its ready-time sandbox preview path (`auto_spawn_test_print_on_ready`, `spawn_test_print_from_active_wip_with_defaults`) instead of older `sample bake loop` wording, which better matches the current intended role of that path
- the forge authoring-sandbox side is also now more explicit in code ownership:
  - `forge_authoring_sandbox_presenter.gd` owns active authoring-preset state plus preset/inventory metadata reads from the authoring sandbox resource
  - `forge_grid_controller.gd` now delegates through that presenter instead of carrying the active preset id directly
- forge project/workflow text now also describes preset-backed forge projects as `authoring preset` / `[Preset]` rather than `sample preset` / `[Sample]`, so the live UI is less misleading about what those preset-backed flows represent

Present geometry truth:
- the crafted-item runtime geometry path has already moved away from the older "emit every exposed face as its own tiny quad source" shortcut
- the runtime path now also has an explicit shared geometry authority layer:
  - raw voxel cells
  - `CraftedItemCanonicalSolid`
  - `CraftedItemCanonicalGeometry`
  - render mesh / preview centering / placeholder bounds from that canonical geometry
- however, this is still not the final canonical solid / chamfer-ready / shape-operator-ready stage
- the next correct geometry law is still:
  - voxel authoring truth
  - canonical processed solid truth
  - then render mesh + collision/hit-volume extraction from that same processed shape

Present ranged/shield foundation truth:
- the old "bow bucket" is no longer the full authoritative mental model
- the future umbrella is now `Ranged Physical Weapon`
- `bow` and `quiver` are separate crafted components under that umbrella
- the quiver uses a shell/mannequin-style restricted-volume crafter
- shield work overlaps that mannequin-anchor logic in parallel
- explicit authored string-anchor creator points are now the preferred future authored truth for bow strings:
  - `A1`
  - `A2`
  - with future pairs like `B1 / B2` possible later if needed
- the visible string should be generated in post from those anchors rather than hand-built as free voxel string geometry
- runtime bow-string behavior is intended to use a hand-connected four-point mapping so draw, release, and return remain consistent across long-bow, short-bow, and slingshot-like endpoint spacing

Present boundary:
- the newer ranged/shield foundation is locked in docs, not yet implemented as live crafting/runtime code
- the audit-led presenter cleanup is active and verified, but it does not mean the corrected foundations are "done forever"
- the canonical crafted-item geometry stage still needs another real correction pass before later chamfering, rounded forms, and shape-derived collision/hit volumes can honestly build on it

Verified during this cleanup phase:
- inventory slice still passes after the newer inventory/player-controller shell cuts
- inventory layout still passes after the newer inventory shell cuts
- system menu verification still passes after the newer system-menu session split
- player hand-mount orientation still passes after the newer controller shell cuts
- the updated geometry harness now confirms both canonical layers are live:
  - `line_canonical_solid_valid=true`
  - `line_canonical_geometry_valid=true`
  - `box_canonical_solid_valid=true`
  - `box_canonical_geometry_valid=true`
- the real `Extensive testing 1.` saved WIP also now reports through that path with:
  - `canonical_solid_cell_count=1967`
  - `canonical_geometry_quad_count=233`
  - `mesh_surface_count=1`
  - `mesh_vertex_count=932`
  - `mesh_triangle_count=466`

## 28. 2026-04-04 naming manual addendum

This addendum exists so later work does not silently drift back into vague or overloaded terminology.

Present:
- `NAMING_LAW.md` is now the live naming authority, not just an older starter note
- `NAMING_LAW.md` now also includes a knob/search index section so future tuning passes can use keyword search terms like `hurtbox`, `AoE`, `pierce`, `reach`, `grip`, `stow`, and `bounds` to jump to the likely files/names first instead of hunting blindly
- `LIVE_EXPORTED_KNOB_REGISTRY.md` now exists as the dedicated exported-knob/search file; use `NAMING_LAW.md` for naming meaning and use the live knob registry for exact exported names, file grouping, and search terms
- it now defines:
  - suffix-family meaning (`Def`, `State`, `Instance`, `Profile`, `Resolver`, `Service`, `Builder`, `Presenter`, `Controller`, `Overlay`, and related compound forms)
  - domain umbrella terminology including `Ranged Physical Weapon`, `Ranged Magical Weapon`, `bow`, `quiver`, and `shield`
  - token/prefix law such as `cap_`, `mat_`, `intent_`, `ctx_`, `stow_`, and `grip_`
  - unit/value suffix law such as `_meters`, `_degrees`, `_seconds`, `_voxels`, `_percent`, `_ratio`, `_score`, `_valid`, `_id`, and `_lines`
  - the current legacy meaning of `reach` and `cap_reach`
- the current naming law explicitly records that `reach` in live code is still the grip-to-geometry extent measure, not final attack range

Working rule from this point on:
- when a new naming family, ambiguous gameplay term, or system umbrella is introduced, update `NAMING_LAW.md` in the same work window or immediately after the pass
- if a legacy name cannot be renamed yet, document its exact current meaning there instead of letting the ambiguity spread

Present boundary:
- this addendum does not itself rename existing runtime/profile fields yet
- it establishes the naming authority first so later rename passes and tuning passes have a stable reference point

## 29. 2026-04-04 crafting bench start-menu addendum

Present:
- the real in-world crafting bench now opens through a craft-path start menu instead of assuming one direct editor path
- the new entry choices are:
  - `Continue Last`
  - `Project List`
  - `New Melee Weapon`
  - `New Ranged Physical Weapon`
  - `New Shield`
  - `New Magic Weapon`
- the stable direct-entry `open_for()` flow still exists for internal verifiers/harnesses, but world interaction now goes through the start-menu path

Foundation added:
- `forge_builder_path_id` now lives on `CraftedItemWIP`
- current persisted builder paths are:
  - `builder_path_melee`
  - `builder_path_ranged_physical`
  - `builder_path_shield`
  - `builder_path_magic`
- current default path mapping is:
  - melee -> `intent_melee` + `ctx_weapon`
  - ranged physical -> `intent_ranged` + `ctx_weapon`
  - shield -> `intent_shield` + `ctx_shield`
  - magic -> `intent_magic` + `ctx_focus`
- current builder-path workspace sizes are:
  - melee -> `240 x 80 x 40`
  - ranged physical -> `160 x 80 x 30`
  - shield -> `100 x 80 x 30`
  - magic -> `100 x 30 x 30`
- the ranged-physical quiver target size is already locked for later:
  - quiver -> `70 x 30 x 30`
- `forge_builder_component_id` now also lives on `CraftedItemWIP`
  - current live builder components are:
    - `builder_component_primary`
    - `builder_component_bow`
    - `builder_component_quiver`
  - ranged physical now defaults to `builder_component_bow`
  - ranged physical `builder_component_quiver` now resolves the smaller `70 x 30 x 30` workspace through live forge rules/controller code, not only as future design text
- the ranged physical path now also has a first live `Bow / Quiver` component strip in the forge project panel
  - it only appears for ranged physical drafts
  - `Bow` opens/continues the bow component draft
  - `Quiver` opens/continues the quiver component draft
  - `New` now keeps the current ranged component instead of falling back to generic ranged/bow assumptions
  - this is still an honest first pass, not the later packaged bow+quiver save/equip system
- forge project/workflow text now includes builder-component wording for multi-component paths, so ranged physical `bow` and `quiver` drafts are no longer described by one shared ambiguous path label only
- the ranged physical path will later split into separate `bow` and `quiver` tabs/entities, but they still belong to one saved/equipped ranged-physical package

Why this matters:
- it stops the station from pretending every new project begins as melee
- it gives later ranged/shield/magic UI/layout work a persisted branch identity to build from
- it keeps the current melee shell usable while the other dedicated builders are still being defined

Verification:
- `verify_crafting_bench_start_menu.gd`
- `crafting_bench_start_menu_results.txt`
- `verify_crafting_bench_project_load.gd`
- `crafting_bench_project_load_results.txt`
- `verify_ranged_physical_component_foundation.gd`
- `ranged_physical_component_foundation_results.txt`
- `verify_ranged_physical_component_tabs.gd`
- `ranged_physical_component_tabs_results.txt`

## 30. 2026-04-04 forge orientation indicator addendum

Present:
- the shared forge workspace now has a proper axis indicator overlay inside the main build viewport itself
- the legend text is locked to:
  - `+X Left`
  - `+Y up`
  - `+Z front`
- the indicator now lives in the bottom-right corner of the main workspace host
- it follows the free-view camera rotation, so the visible triad stays directionally true as the player orbits the builder
- the current active implementation now uses a staged drop-in 3D gizmo asset instead of the earlier drawn 2D triad widget:
  - source intake folder: `GDD-and Text Resources/Dropin asset location`
  - current integrated source asset: `transform_gizmo.glb`
  - live project copy: `res://scenes/ui/assets/transform_gizmo.glb`

Implementation shape:
- the overlay now lives on the shared `MainViewportHost`, not only inside the free-view container, so it stays in the main-view corner even when the 2D plane view is primary
- `ForgeWorkspacePreview` exports a camera-relative axis state for UI use
- `CraftingBenchUI` refreshes the gizmo alongside the normal free-workspace refresh path and during active UI processing
- `ForgeWorkspaceAxisIndicator` now hosts a transparent 3D subviewport and loads the current drop-in `.glb` through `GLTFDocument` at runtime

Why this matters:
- it reduces orientation confusion while building
- it gives clearer shared language for later tasking and tuning (`+X`, `+Y`, `+Z` against the forge view)
- it supports later archetype-specific build habits where some items are better authored vertically and others horizontally

Present boundary:
- the current host logic is clean and verified
- the current asset still logs a glTF material-workflow conversion warning on load (`spec/gloss -> roughness/metallic`); treat that as source-asset import noise unless the gizmo visuals themselves prove wrong in-editor

Verification:
- `verify_crafting_bench_camera.gd`
- `crafting_bench_camera_results.txt`

## 31. 2026-04-04 drop-in asset staging addendum

Present:
- `GDD-and Text Resources/Dropin asset location` is now the dedicated staging folder for user-supplied drop-in assets
- working rule:
  - assets placed there are intended to be picked up and integrated into the game/framework according to their scope
  - treat it as the first-stop intake location for externally provided art/helper assets before they are placed into the live project tree
- current observed contents:
  - `transform_gizmo.glb`

Why this matters:
- it gives one stable location for incoming assets instead of scattering them through random temp folders
- it makes it easier to know what new external asset is meant to be evaluated/integrated next

Present boundary:
- this addendum only locks the folder purpose and current content awareness
- it does not by itself mean every asset in that folder is already imported into the live project

## 32. 2026-04-04 ranged bow string-anchor foundation addendum

Present:
- the first live authored bow-string truth layer now exists in the forge builder
- ranged physical `bow` drafts now get a pinned top block of non-inventory builder markers instead of treating the visible string as player-authored voxel geometry
- current live marker set is:
  - `A1 / A2`
  - `B1 / B2`
  - `C1 / C2`
  - `D1 / D2`
  - `E1 / E2`
  - `F1 / F2`
- these markers are color-coded by pair, with both endpoints in the same pair sharing the same color
- they are currently only surfaced for the ranged physical `bow` component, not melee, quiver, shield, or magic paths

Builder/runtime law now implemented:
- string-anchor markers are authoring-only placement entries
- they do not consume forge inventory
- erasing them does not refund forge inventory
- placing the same marker again relocates that singleton marker instead of creating duplicates
- the current bow runtime path now detects the first complete authored pair when present and reports:
  - `string_anchor_source = explicit_authored_pair`
  - `string_anchor_pair_id = <pair>`
- if no authored pair exists, older heuristic bow-string inference remains alive for legacy/sample content

Bake/render law now implemented:
- builder markers are filtered out of baked material mass/stat aggregation
- builder markers are filtered out of segment generation
- builder markers are filtered out of test-print display geometry / canonical geometry
- builder markers still render in the forge editor with their dedicated marker colors so authored placement remains visible during editing

Verification:
- `verify_ranged_bow_string_anchor_markers.gd`
- `ranged_bow_string_anchor_markers_results.txt`
- latest focused result confirms:
  - `marker_entries_count=12`
  - `marker_entries_pinned_top=true`
  - `default_selection_is_not_marker=true`
  - `default_armed_is_not_marker=true`
  - `inventory_unchanged_after_first_marker=true`
  - `marker_one_relocated=true`
  - `marker_two_placed=true`
  - `bake_cells_exclude_markers=true`
  - `test_print_display_excludes_markers=true`
  - `explicit_pair_detected=true`
- legacy/sample bow fallback still held in:
  - `godot_m2_results.txt`
  - current `sample_bow` still reports `bow_valid=true`

Present boundary:
- this is the first authored truth layer only
- it does not yet implement the later full packaged bow+quiver save/equip system
- it does not yet implement the later runtime four-point pull-string deformation model
- it does not yet provide a dedicated ranged-only left/right material panel or the later quiver-shell crafter

2026-04-04 ranged bow string rest-path preview follow-up:
- the forge 3D workspace now renders a first-pass generated bow string when a complete authored string-anchor pair exists on a ranged bow draft
- this preview string is generated from the authored anchor pair plus the current resolved rest pull point, not from hand-authored voxel string cells
- current bow data now exposes:
  - `string_rest_path`
  - `string_pull_point_rest`
- current first-pass rest-path shape is:
  - `upper string anchor -> rest pull point -> lower string anchor`
- current rest pull point uses the bow projectile pass point when available, with midpoint fallback when the bow body has not yet provided stronger reference evidence
- the forge workspace preview now draws that rest path as two slim generated 3D string segments, so authored anchor placement immediately produces visible string feedback in the builder
- focused verification now also confirms:
  - `string_rest_path_points=3`
  - `preview_string_segment_a_visible=true`
  - `preview_string_segment_b_visible=true`
  - `preview_string_visible=true`

Present boundary:
- this is still a rest-state preview only
- it is not yet the later four-point hand-connected draw/deform/release runtime
- it is not yet exported into held-weapon/runtime combat presentation outside the forge builder

## 33. 2026-04-04 ranged bow marker-position and draw-preview correction addendum

Present:
- the ranged bow string-anchor system no longer stores authored anchor markers as fake material cells inside WIP voxel layers
- authored anchor truth now lives in `CraftedItemWIP.builder_marker_positions`
- legacy marker-as-cell data is migrated forward when a WIP becomes active
- marker erase/pick behavior is now marker-aware:
  - pick prefers the builder marker if one is present at that grid position
  - erase removes the marker first before touching real material mass at that grid position
- marker visibility is now explicit in both forge views:
  - 2D plane view draws labeled colored marker overlays
  - 3D workspace preview renders visible marker orbs

Why this matters:
- it fixes the earlier bad foundation where anchor metadata occupied real voxel mass positions
- it makes anchor placement/repositioning stable instead of fighting normal material placement
- it keeps authored string endpoints visible without contaminating baked geometry or segment generation

First draw-state follow-up now implemented:
- bow data now exposes:
  - `string_pull_point_draw_max`
  - `string_draw_path`
  - `string_draw_distance_meters`
  - `string_draw_length_meters`
  - `string_anchor_span_meters`
- current first-pass law is:
  - `string_pull_point_draw_max = string_pull_point_rest + draw_axis * bow_string_draw_distance_meters`
- the controlling forge rule knob now exists:
  - `bow_string_draw_distance_meters`
- forge 3D preview now shows:
  - rest string path
  - max-draw string path
  - max-draw pull point

Verification:
- `verify_ranged_bow_string_anchor_markers.gd`
- `ranged_bow_string_anchor_markers_results.txt`
- current focused result confirms:
  - `marker_one_relocated=true`
  - `marker_two_placed=true`
  - `marker_cells_live_outside_layers=true`
  - `explicit_pair_detected=true`
  - `string_rest_path_points=3`
  - `string_draw_path_points=3`
  - `string_draw_distance_positive=true`
  - `preview_builder_marker_count=2`
  - `preview_string_visible=true`
  - `preview_draw_string_visible=true`
- neighboring stability also still held in:
  - `crafting_bench_project_load_results.txt`
  - `godot_m2_results.txt`
  - `crafting_bench_camera_results.txt`

Present boundary:
- this is still not the later four-point hand-connected runtime string solve
- it does not yet attach to player hands or drive projectile release timing
- it is the clean data/preview layer that the later hand-connected draw system should build on

## 34. 2026-04-05 forge bench shell regroup and autosave protection addendum

Present:
- the live forge builder no longer uses the old always-visible left-side control column as the main interaction surface
- the left project/tool/status shell is now removed from the live layout
- project and status now live in top-row grouped menus beside the existing forge menus
- the live forge workspace also now has a small transparent bottom-right `Draw / Erase` overlay beside the orientation gizmo for fast tool switching without reopening menus
- the main new top-row groupings are:
  - `Project`
  - `Status`
  - `View`
  - `Geometry`
  - `Workflow`
- the old project panel is now used as a popup project manager instead of a permanent side column
- duplicate visible project-action buttons inside that popup were removed from the live presentation path

Project-flow changes:
- the start-menu `Project List` path now opens the editor shell and immediately shows the popup project manager
- the popup project manager now carries:
  - current project metadata
  - ranged bow/quiver component tabs when relevant
  - saved WIP list across archetypes
- top project menu now owns the high-risk actions:
  - save
  - new current path
  - load selected
  - resume last
  - duplicate
  - delete
  - return to crafting paths

Safety changes:
- closing the forge now autosaves meaningful current work before the UI shuts
- switching away from the current WIP now autosaves first before:
  - creating a new draft
  - loading another saved WIP
  - resuming last
  - switching ranged component
  - returning from editor surface back to crafting paths
- the autosave decision and save-if-needed path now live in the shared forge project workflow / action presenter layer, not only in `CraftingBenchUI`
- autosave intentionally does **not** create empty clutter just because a draft has a generated default name
- current autosave triggers for:
  - already-saved projects
  - drafts with placed cells
  - drafts with builder-marker positions
  - drafts with forge notes
- this autosave-on-exit / autosave-before-context-change rule is **global crafting law**, not a bow-only fix
- it applies to all present and future crafting families:
  - melee
  - ranged physical
  - shield
  - magic
  - armor components
  - accessory components

Why this matters:
- it removes the misclick-prone left project list / save cluster that was causing lost work
- it makes save-before-context-change the default law instead of a manual best effort
- it prevents future crafting branches from silently losing work just because they use a different builder shell later
- it keeps the forge shell cleaner while still preserving the richer project metadata editor in popup form

Verification:
- `verify_crafting_bench_controls.gd`
- `verify_crafting_bench_start_menu.gd`
- `verify_crafting_bench_project_load.gd`
- `verify_crafting_bench_autosave.gd`
- current focused results confirm:
  - `left_panel_hidden=true`

## 35. 2026-04-05 adaptive outer shell / refinement envelope stage note

New design reference docs were added in the non-uploaded GDD root:
- `Adaptive Outer Shell - Refinement Envelope System 1.md`
- `Adaptive Outer Shell - Refinement Envelope 2.md`

These define a future **Stage 2** runtime refinement layer that sits:
- after Stage 1 structural voxel truth
- before the current take-WIP-out / test-print path
- and therefore before later export / final visible mesh output

Stage naming lock:
- Stage 1 = the current live structural crafting system
- Stage 2 = the Adaptive Outer Shell / Refinement Envelope refinement layer

Locked design direction from those docs:
- Stage 2 is patch-based, not monolithic full-shell rebuild by default
- Stage 2 derives from Stage 1 and never replaces Stage 1 authority
- Stage 2 uses a thickness-aware local Refinement Envelope
- Stage 2 supports CAD-style selection tools and brush-style local tools
- restore always goes back toward Stage 1 baseline, never beyond it
- handle / anchor zones are intended to be fillet-only restriction zones
- live preview language uses transparent purple as the Stage 2 working color family

Important planning implication:
- this is a future major system bucket
- it should attach to the canonical crafted-item geometry pipeline and later export bridge
- the Stage 2 docs were then adapted further to the actual repo shape, so they now name the real current insertion chain:
  - `CraftedItemWIP`
  - `ForgeGridController`
  - `ForgeService.build_test_print_from_wip()`
  - `TestPrintInstance`
  - `TestPrintMeshBuilder`
  - player-held / forge test presentation
- placement decision after re-evaluating the functional requirements:
  - Stage 2 belongs as a **refinement substage of the crafting station**, not as a late export-only step and not as a service-only mesh modifier
  - authored Stage 2 state should live on the same `CraftedItemWIP`
  - `ForgeService.build_test_print_from_wip()` should consume that Stage 2 state when packaging the testing handoff
  - Stage 1 remains gameplay truth; Stage 2 supplies refined visible shell truth when present
- it is **not** yet implemented in the live forge runtime
  - `project_menu_exists=true`
  - `status_menu_exists=true`
  - `plane_changed_via_menu=true`
  - `project_manager_popup_visible=true`
  - `close_autosave_exists=true`
  - `close_autosave_has_cells=true`
  - `switch_autosave_saved=true`
  - `switch_autosave_has_cells=true`
  - `switched_to_shield_path=true`

## 36. 2026-04-05 first live Stage 2 foundation pass

The first real Stage 2 foundation is now live in code.

What exists now:
- `CraftedItemWIP.stage2_item_state` stores Stage 2 refinement state on the same WIP authority object
- `TestPrintInstance.stage2_item_state` carries the packaged Stage 2 section into test-print handoff
- `services/forge_stage2_service.gd` builds the first Stage 2 baseline shell directly from current Stage 1 canonical geometry
- Stage 2 patch generation is now local enough for brush work:
  - merged canonical faces are split into per-surface-cell patch records
  - the current baseline test block now produces `40` Stage 2 patches instead of `6` coarse face patches
- local patch envelope limits now use the locked first-pass rules from `ForgeRulesDef`
  - `stage2_single_cell_max_inward_ratio = 0.475`
  - `stage2_multi_cell_max_inward_ratio = 0.95`
  - `max_inward_offset_meters` now scales from local thickness instead of pretending every patch has the same one-cell envelope
- `ForgeGridController.ensure_stage2_item_state_for_active_wip()` initializes or refreshes Stage 2 for the active WIP
- Stage 1 edits now invalidate `stage2_item_state` in `_mark_wip_dirty()` so stale refinement data does not silently survive a structural change
- forge workflow menu now exposes `Initialize / Refresh Stage 2`
- `ForgeService.build_test_print_from_wip()` now prefers Stage 2 geometry when a live Stage 2 shell exists, while still falling back cleanly to Stage 1 canonical geometry when it does not

Important boundary:
- this was the **foundation slice**, not the final refinement editor
- live zone masks, CAD-style selection tooling, and more than the first brush pair are still future work
- current Stage 2 output is now both:
  - the baseline shell package / handoff layer
  - and the first live refinement authoring surface inside the forge bench

Verified:
- `stage2_refinement_foundation_results.txt`
  - `stage2_initialized=true`
  - `stage2_patch_count=40`
  - `stage2_has_positive_patch_depth=true`
  - `stage2_has_positive_envelope=true`
  - `test_print_stage2_exists=true`
  - `test_print_uses_stage2_geometry=true`
- `crafting_bench_project_load_results.txt`
- `godot_m2_results.txt`

## 37. 2026-04-05 first live Stage 2 refinement mode pass

The first live Stage 2 editor mode now exists inside the forge bench.

What exists now:
- forge workflow now has a real Stage 2 mode toggle:
  - `Enter Stage 2 Refinement`
  - `Exit Stage 2 Refinement`
- when Stage 2 mode is active:
  - forge free-view shows the transparent purple Stage 2 shell
  - forge tool overlay relabels from `Draw / Erase` to `Carve / Restore`
  - left-click free-view input edits Stage 2 instead of Stage 1 voxel mass
  - the current brush pair is:
    - `stage2_carve`
    - `stage2_restore`
  - the current brush hover path resolves against the live Stage 2 shell, not against raw voxel cells
  - a spherical Stage 2 brush preview now shows the current hit/radius
- current Stage 2 preview/runtime owners are:
  - `runtime/forge/forge_stage2_brush_presenter.gd`
  - `runtime/forge/forge_stage2_preview_presenter.gd`
  - `runtime/forge/forge_workspace_preview.gd`
  - `runtime/forge/crafting_bench_ui.gd`
- current Stage 2 preview tuning knobs now include:
  - `workspace_stage2_shell_color`
  - `workspace_stage2_brush_color`
  - `workspace_stage2_default_brush_radius_meters`
  - `workspace_stage2_brush_step_ratio`

Truth/safety behavior now implemented:
- Stage 2 edit mode is only enterable when the active WIP already has a valid Stage 2 shell
- leaving Stage 2 mode restores the normal `Draw / Erase` overlay labels
- Stage 2 edits now clear the active baked profile/test print so stale testing output is not left alive after a shell change
- plane-view Stage 1 voxel editing is blocked while Stage 2 mode is active

Verified:
- `stage2_refinement_mode_results.txt`
  - `stage2_mode_active=true`
  - `stage2_shell_visible=true`
  - `draw_text_ok=true`
  - `erase_text_ok=true`
  - `hover_hit_resolved=true`
  - `brush_preview_visible=true`
  - `carve_changed_shell=true`
  - `cleared_test_print_after_carve=true`
  - `mode_exited=true`
  - `draw_text_restored=true`
- `crafting_bench_controls_results.txt`
- `crafting_bench_project_load_results.txt`
- `godot_m2_results.txt`

## 38. 2026-04-05 first live Stage 2 grip-safe restriction pass

The first protected Stage 2 zone rule now exists in live code.

What exists now:
- Stage 2 no longer initializes as pure shell geometry only; `ForgeGridController.ensure_stage2_item_state_for_active_wip()` now makes sure a baked profile snapshot exists first, so Stage 2 can read real Stage 1 grip authority instead of inventing a fake zone source
- `services/forge_stage2_service.gd` now tags each patch with a first-pass zone id:
  - `stage2_zone_general`
  - `stage2_zone_primary_grip_safe`
- the first live protected zone is derived from the baked primary grip span using:
  - `primary_grip_span_start`
  - `primary_grip_span_end`
  - `stage2_primary_grip_safe_radius_voxels`
- `runtime/forge/forge_stage2_brush_presenter.gd` now blocks `stage2_carve` on `stage2_zone_primary_grip_safe`
- `stage2_restore` still remains allowed on those patches because the first-pass rule is “protect destructive shell loss,” not “forbid all grip-area refinement”
- the forge free-view brush preview now shows a blocked-state color through:
  - `workspace_stage2_blocked_brush_color`

Verified:
- `stage2_grip_safe_zone_results.txt`
  - `profile_primary_grip_valid=true`
  - `grip_safe_patch_count_positive=true`
  - `grip_hover_blocked=true`
  - `grip_safe_carve_changed_shell=false`
  - `general_hover_blocked=false`
  - `general_carve_changed_shell=true`
- `stage2_refinement_mode_results.txt`
- `crafting_bench_controls_results.txt`

## 39. 2026-04-05 first live Stage 2 fillet-tool pass

The first grip-safe editing tool now exists on top of the new Stage 2 zone rule.

What exists now:
- `runtime/forge/forge_stage2_brush_presenter.gd` now supports:
  - `stage2_carve`
  - `stage2_fillet`
  - `stage2_restore`
- the first fillet pass is still brush-local and patch-based; it is not the later CAD edge-fillet system yet
- `services/forge_stage2_service.gd` now resolves `max_fillet_offset_meters` per patch from:
  - `max_inward_offset_meters`
  - `stage2_fillet_max_inward_ratio`
- the top geometry menu is now truthful by mode:
  - Stage 1 = `Place / Erase / Pick`
  - Stage 2 = `Carve / Restore / Fillet`
- grip-safe patches now behave as intended in first pass:
  - `stage2_carve` blocked
  - `stage2_fillet` allowed
  - `stage2_restore` allowed

Verified:
- `stage2_grip_safe_zone_results.txt`
  - `stage2_geometry_menu_has_fillet=true`
  - `stage2_geometry_menu_has_pick=false`
  - `grip_hover_blocked=true`
  - `grip_safe_carve_changed_shell=false`
  - `grip_hover_blocked_for_fillet=false`
  - `grip_safe_fillet_changed_shell=true`
  - `general_carve_changed_shell=true`
- `stage2_refinement_mode_results.txt`
- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_pick_material=true`
  - `geometry_menu_has_fillet_tool=false`

## 40. 2026-04-05 first live Stage 2 chamfer-tool pass

The first destructive non-grip-safe shaping tool now exists in live Stage 2.

What exists now:
- `runtime/forge/forge_stage2_brush_presenter.gd` now supports:
  - `stage2_carve`
  - `stage2_fillet`
  - `stage2_chamfer`
  - `stage2_restore`
- `services/forge_stage2_service.gd` now resolves `max_chamfer_offset_meters` per patch from:
  - `max_inward_offset_meters`
  - `stage2_chamfer_max_inward_ratio`
- the top geometry menu is now truthful by mode:
  - Stage 1 = `Place / Erase / Pick`
  - Stage 2 = `Carve / Restore / Fillet / Chamfer`
- current first-pass rule remains:
  - `stage2_chamfer` blocked on `stage2_zone_primary_grip_safe`
  - `stage2_chamfer` allowed on `stage2_zone_general`

Verified:
- `stage2_grip_safe_zone_results.txt`
  - `stage2_geometry_menu_has_chamfer=true`
  - `grip_hover_blocked_for_chamfer=true`
  - `grip_safe_chamfer_changed_shell=false`
  - `general_chamfer_changed_shell=true`
- `stage2_refinement_mode_results.txt`
- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_chamfer_tool=false`

## 41. 2026-04-05 first live Stage 2 selection-first face-tool pass

The first selection-first / apply-second Stage 2 feature path now exists in live code.

What exists now:
- Stage 2 has a dedicated selection owner:
  - `runtime/forge/forge_stage2_selection_presenter.gd`
- current first-pass selectable target is:
  - `surface_face`
  - current live truth = connected coplanar Stage 2 face region
- current first-pass selection tools are:
  - `stage2_surface_face_fillet`
  - `stage2_surface_face_chamfer`
- current free-view selection loop is:
  - hover patch
  - click to toggle face selection
  - selected faces remain highlighted
  - explicit `Apply Selected Targets`
  - explicit `Clear Target Selection`
- current live Stage 2 selection preview now includes:
  - hovered face fill
  - selected face fill
  - `workspace_stage2_hover_face_color`
  - `workspace_stage2_selected_face_color`

Current first-pass behavior:
- `stage2_surface_face_fillet` applies the full first-pass fillet target to the selected face region's outer boundary loop
- `stage2_surface_face_chamfer` applies the full first-pass chamfer target to the selected face region's outer boundary loop
- grip-safe patches still follow the same zone law:
  - face fillet allowed
  - face chamfer blocked

Important boundary:
- this is the first boundary-loop-aware `surface_face` feature path only
- it is still patch-derived topology truth, not the later richer full CAD/topology system
- current face-region connectivity comes from the Stage 2 patch neighbor graph (`neighbor_patch_ids`)

Verified:
- `stage2_selection_feature_results.txt`
  - `stage2_geometry_menu_has_face_fillet=true`
  - `stage2_geometry_menu_has_face_chamfer=true`
  - `face_tool_apply_visible=true`
  - `face_tool_clear_visible=true`
  - `hover_preview_visible=true`
  - `selected_preview_visible=true`
  - `selected_count_after_pick=36`
  - `grip_safe_apply_target_count=26`
  - `grip_safe_face_boundary_smaller_than_selection=true`
  - `grip_safe_face_fillet_changed_shell=true`
  - `grip_safe_face_fillet_changed_patch_count=26`
  - `selected_count_after_clear=0`
  - `grip_safe_face_chamfer_changed_shell=false`
  - `general_selected_count=91`
  - `general_apply_target_count=36`
  - `general_face_boundary_smaller_than_selection=true`
  - `general_face_chamfer_changed_shell=true`
  - `general_face_chamfer_changed_patch_count=36`
- `stage2_refinement_mode_results.txt`
- `stage2_grip_safe_zone_results.txt`
- `crafting_bench_controls_results.txt`
- `crafting_bench_project_load_results.txt`

## 42. 2026-04-05 first live Stage 2 edge-run selection pass

The first boundary-style `surface_edge` Stage 2 selection path now exists in live code.

What exists now:
- current first-pass edge selection tools are:
  - `stage2_surface_edge_fillet`
  - `stage2_surface_edge_chamfer`
- current first-pass `surface_edge` truth is:
  - a contiguous run of coplanar Stage 2 patch boundary edges
- current live edge-run selection uses:
  - hovered patch hit
  - nearest valid boundary edge on that patch
  - connected collinear boundary-edge run resolution
- hovered edge-run and selected edge-run now reuse the same transparent purple Stage 2 preview language as the face tools
- explicit apply/clear now remains shared:
  - `Apply Selected Targets`
  - `Clear Target Selection`

Current first-pass behavior:
- selecting an edge tool no longer means one isolated patch unless the run is actually length `1`
- grip-safe edge runs follow the same zone law:
  - edge fillet allowed
  - edge chamfer blocked
- general-zone edge runs can take chamfer

Important boundary:
- this is still patch-derived `surface_edge` truth, not the later richer topology/edge graph
- current edge runs are boundary-edge runs only, not every possible internal feature edge

Verified:
- `stage2_edge_selection_feature_results.txt`
  - `stage2_geometry_menu_has_edge_fillet=true`
  - `stage2_geometry_menu_has_edge_chamfer=true`
  - `edge_tool_apply_visible=true`
  - `edge_tool_clear_visible=true`
  - `hover_preview_visible=true`
  - `selected_preview_visible=true`

## 43. 2026-04-05 first boundary-loop-aware Stage 2 face-region pass

The first richer face/topology Stage 2 pass now exists in live code.

What exists now:
- `surface_face` no longer means one hovered patch
- current live `surface_face` truth is:
  - a connected coplanar Stage 2 face region
- current face-region connectivity now uses:
  - `neighbor_patch_ids`
  - populated from `services/forge_stage2_service.gd`
- current face-tool apply path now resolves:
  - selected face region
  - then that region's outer boundary loop
  - then fillet/chamfer on that boundary loop only

Current first-pass behavior:
- face-region hover/select preview still shows the full selected face region
- actual face fillet/chamfer apply now ignores interior patches
- grip-safe boundary patches still follow the same zone law:
  - face fillet allowed
  - face chamfer blocked

Important boundary:
- this is still patch-derived topology, not the later richer CAD/topology graph
- current face-region target is coplanar connectivity only
- current boundary loop is the outer edge boundary of the selected patch region

Verified:
- `stage2_selection_feature_results.txt`
  - `grip_safe_selected_count=36`
  - `grip_safe_apply_target_count=26`
  - `grip_safe_face_boundary_smaller_than_selection=true`
  - `grip_safe_face_fillet_changed_patch_count=26`
  - `general_selected_count=91`
  - `general_apply_target_count=36`
  - `general_face_boundary_smaller_than_selection=true`
  - `general_face_chamfer_changed_patch_count=36`
- `stage2_edge_selection_feature_results.txt`
- `stage2_grip_safe_zone_results.txt`
- `stage2_refinement_mode_results.txt`
- `stage2_refinement_foundation_results.txt`
- `crafting_bench_controls_results.txt`
- `crafting_bench_project_load_results.txt`

## 44. 2026-04-05 first live Stage 2 internal feature-edge pass

The first explicit non-boundary/internal `surface_feature_edge` Stage 2 path now exists in live code.

What exists now:
- current first-pass internal feature-edge selection tools are:
  - `stage2_surface_feature_edge_fillet`
  - `stage2_surface_feature_edge_chamfer`
- current first-pass `surface_feature_edge` truth is:
  - a contiguous run of coplanar internal shared edges
  - with both patch sides selected along that run
- current live internal feature-edge selection uses:
  - hovered patch hit
  - nearest valid internal shared edge on that patch
  - connected collinear internal edge-run resolution
  - adjacent patch-side union across that run

Current first-pass behavior:
- boundary-edge tools remain boundary-edge tools
- internal feature-edge tools now target internal shared-edge runs only
- grip-safe internal feature-edge runs follow the same zone law:
  - feature-edge fillet allowed
  - feature-edge chamfer blocked
- general-zone internal feature-edge runs can take chamfer

Important boundary:
- this is still patch-derived internal edge truth, not the later richer CAD/topology feature graph
- current internal feature-edge runs come from shared patch seams, not from higher-order curvature analysis

Verified:
- `stage2_internal_feature_edge_results.txt`
  - `stage2_geometry_menu_has_feature_edge_fillet=true`
  - `stage2_geometry_menu_has_feature_edge_chamfer=true`
  - `feature_edge_tool_apply_visible=true`
  - `feature_edge_tool_clear_visible=true`
  - `grip_safe_selected_count=24`
  - `grip_safe_feature_edge_fillet_changed_shell=true`
  - `grip_safe_feature_edge_chamfer_changed_shell=false`
  - `general_selected_count=26`
  - `general_feature_edge_chamfer_changed_shell=true`
- `stage2_edge_selection_feature_results.txt`
- `stage2_selection_feature_results.txt`
- `stage2_grip_safe_zone_results.txt`
- `crafting_bench_controls_results.txt`
  - `selected_count_after_pick=3`
  - `grip_safe_edge_fillet_changed_shell=true`
  - `selected_count_after_clear=0`
  - `grip_safe_edge_chamfer_changed_shell=false`
  - `general_selected_count=7`
  - `general_edge_chamfer_changed_shell=true`
- `stage2_selection_feature_results.txt`
- `stage2_refinement_mode_results.txt`
- `stage2_grip_safe_zone_results.txt`
- `crafting_bench_controls_results.txt`
- `crafting_bench_project_load_results.txt`

## 45. 2026-04-05 first live Stage 2 offset-derived feature-loop pass

The first explicit offset-derived `surface_feature_loop` Stage 2 path now exists in live code.

What exists now:
- current first-pass offset-derived feature-loop selection tools are:
  - `stage2_surface_feature_loop_fillet`
  - `stage2_surface_feature_loop_chamfer`
- current first-pass `surface_feature_loop` truth is:
  - the boundary loop around a connected coplanar same-offset Stage 2 feature region
  - including the adjacent offset-change seam patches on that loop
- current live feature-loop selection uses:
  - hovered patch hit
  - connected coplanar same-offset region resolution
  - then loop extraction from neighboring offset-change seam patches

Current first-pass behavior:
- feature-loop tools no longer mean one modified patch only
- grip-safe feature loops follow the same zone law:
  - feature-loop fillet allowed
  - feature-loop chamfer blocked
- general-zone feature loops can take chamfer

Important boundary:
- this is still patch-derived offset topology, not a later richer curvature/shape graph
- current feature loops come from same-offset modified regions, not arbitrary visual silhouette tracing

Verified:
- `stage2_feature_loop_results.txt`
  - `stage2_geometry_menu_has_feature_loop_fillet=true`
  - `stage2_geometry_menu_has_feature_loop_chamfer=true`
  - `feature_loop_tool_apply_visible=true`
  - `feature_loop_tool_clear_visible=true`
  - `grip_safe_selected_count=5`
  - `grip_safe_feature_loop_fillet_changed_shell=true`
  - `grip_safe_feature_loop_chamfer_changed_shell=false`
  - `general_selected_count=5`
  - `general_feature_loop_chamfer_changed_shell=true`
- `stage2_internal_feature_edge_results.txt`
- `crafting_bench_controls_results.txt`

## 46. 2026-04-05 first live Stage 2 offset-derived feature-region pass

The first explicit offset-derived `surface_feature_region` Stage 2 path now exists in live code.

What exists now:
- current first-pass offset-derived feature-region selection tools are:
  - `stage2_surface_feature_region_fillet`
  - `stage2_surface_feature_region_chamfer`
- current first-pass `surface_feature_region` truth is:
  - a connected coplanar Stage 2 patch region with shared current offset and shared zone mask
- current live feature-region selection uses:
  - hovered patch hit
  - connected coplanar same-offset region resolution
  - direct region-wide apply on the selected modified island

Current first-pass behavior:
- feature-region tools now target the whole modified island instead of only its boundary
- grip-safe feature regions follow the same zone law:
  - feature-region fillet allowed
  - feature-region chamfer blocked
- general-zone feature regions can take chamfer

Important boundary:
- this is still patch-derived offset topology, not a later global surface graph
- current feature-region truth depends on matching current offset and zone, not on higher-order shape classification

Verified:
- `stage2_feature_region_results.txt`
  - `stage2_geometry_menu_has_feature_region_fillet=true`
  - `stage2_geometry_menu_has_feature_region_chamfer=true`
  - `feature_region_tool_apply_visible=true`
  - `feature_region_tool_clear_visible=true`
  - `grip_safe_selected_count=4`
  - `grip_safe_apply_target_count=4`
  - `grip_safe_feature_region_fillet_changed_shell=true`
  - `grip_safe_feature_region_changed_patch_count=4`
  - `grip_safe_feature_region_chamfer_changed_shell=false`
  - `general_selected_count=5`
  - `general_apply_target_count=5`
  - `general_feature_region_chamfer_changed_shell=true`
  - `general_feature_region_changed_patch_count=5`
- `stage2_feature_loop_results.txt`
- `stage2_internal_feature_edge_results.txt`
- `crafting_bench_controls_results.txt`

## 47. 2026-04-05 first live Stage 2 CAD restore pass for offset-derived targets

The first CAD-style restore pass for the new offset-derived Stage 2 targets now exists in live code.

What exists now:
- current first-pass offset-derived restore tools are:
  - `stage2_surface_feature_region_restore`
  - `stage2_surface_feature_loop_restore`
- current live behavior is:
  - selected modified regions can restore directly toward baseline without switching back to brush restore
  - selected modified loops can restore directly toward baseline without switching back to brush restore

Current first-pass behavior:
- grip-safe feature-region restore is allowed
- general feature-loop restore is allowed
- selected restore now commits through the same Stage 2 selection/apply flow as fillet/chamfer instead of being brush-only

Important boundary:
- this is still first-pass restore-to-baseline only
- it is not yet a richer partial un-chamfer / un-fillet solver beyond current selected-patch baseline return

Verified:
- `stage2_feature_restore_results.txt`
  - `stage2_geometry_menu_has_feature_region_restore=true`
  - `stage2_geometry_menu_has_feature_loop_restore=true`
  - `restore_tool_apply_visible=true`
  - `restore_tool_clear_visible=true`
  - `grip_safe_feature_region_selected_count=4`
  - `grip_safe_feature_region_apply_target_count=4`
  - `grip_safe_feature_region_restore_changed_shell=true`
  - `general_feature_loop_selected_count=14`
  - `general_feature_loop_apply_target_count=14`
  - `general_feature_loop_restore_changed_shell=true`
- `stage2_feature_region_results.txt`
- `stage2_feature_loop_results.txt`
- `crafting_bench_controls_results.txt`

## 48. 2026-04-05 first live Stage 2 CAD restore pass for older selection families

CAD-style restore now covers the older Stage 2 selection families too.

What exists now:
- current first-pass older-family restore tools are:
  - `stage2_surface_face_restore`
  - `stage2_surface_edge_restore`
  - `stage2_surface_feature_edge_restore`
- current live behavior is:
  - selected face boundary targets can restore toward baseline
  - selected boundary edge runs can restore toward baseline
  - selected internal feature-edge runs can restore toward baseline

Current first-pass behavior:
- selected restore now works across the older selection-first families instead of only on brush restore or the newer offset-derived targets
- face restore still uses the same boundary-loop apply target as face fillet/chamfer
- edge and internal feature-edge restore still use their direct selected-run targets

Verified:
- `stage2_selection_restore_results.txt`
  - `stage2_geometry_menu_has_face_restore=true`
  - `stage2_geometry_menu_has_edge_restore=true`
  - `stage2_geometry_menu_has_feature_edge_restore=true`
  - `restore_tool_apply_visible=true`
  - `restore_tool_clear_visible=true`
  - `face_selected_count=36`
  - `face_apply_target_count=26`
  - `face_restore_changed_shell=true`
  - `edge_selected_count=7`
  - `edge_apply_target_count=7`
  - `edge_restore_changed_shell=true`
  - `feature_edge_selected_count=26`
  - `feature_edge_apply_target_count=26`
  - `feature_edge_restore_changed_shell=true`

## 49. 2026-04-05 first live Stage 2 offset-derived feature-band pass

The first explicit offset-derived `surface_feature_band` Stage 2 path now exists in live code.

What exists now:
- current first-pass offset-derived feature-band selection tools are:
  - `stage2_surface_feature_band_fillet`
  - `stage2_surface_feature_band_chamfer`
- current first-pass `surface_feature_band` truth is:
  - a connected same-offset feature region plus its adjacent offset-change boundary loop

Current first-pass behavior:
- feature-band targets are larger than feature-region targets because they include both the modified island and the seam band around it
- grip-safe feature-band fillet is allowed
- grip-safe feature-band chamfer is blocked
- general-zone feature-band chamfer is allowed

Verified:
- `stage2_feature_band_results.txt`
  - `stage2_geometry_menu_has_feature_band_fillet=true`
  - `stage2_geometry_menu_has_feature_band_chamfer=true`
  - `feature_band_tool_apply_visible=true`
  - `feature_band_tool_clear_visible=true`
  - `grip_safe_region_selected_count=4`
  - `grip_safe_band_selected_count=10`
  - `grip_safe_band_larger_than_region=true`
  - `grip_safe_feature_band_fillet_changed_shell=true`
  - `grip_safe_feature_band_chamfer_changed_shell=false`
  - `general_region_selected_count=5`
  - `general_band_selected_count=14`
  - `general_band_larger_than_region=true`
  - `general_feature_band_chamfer_changed_shell=true`
- `stage2_feature_region_results.txt`
- `stage2_feature_loop_results.txt`
- `crafting_bench_controls_results.txt`

## 50. 2026-04-05 first live Stage 2 feature-band restore pass

The first CAD-style restore path for `surface_feature_band` now exists in live code.

What exists now:
- current first-pass feature-band restore tool is:
  - `stage2_surface_feature_band_restore`
- current live behavior is:
  - selected feature-band targets can restore directly toward baseline through the shared selection/apply path

Current first-pass behavior:
- grip-safe feature-band restore is allowed
- general-zone feature-band restore is allowed
- feature-band restore uses the same selected band target as the existing feature-band fillet/chamfer pair

Verified:
- `stage2_feature_band_restore_results.txt`
  - `stage2_geometry_menu_has_feature_band_restore=true`
  - `restore_tool_apply_visible=true`
  - `restore_tool_clear_visible=true`
  - `grip_safe_feature_band_selected_count=10`
  - `grip_safe_feature_band_apply_target_count=10`
  - `grip_safe_feature_band_restore_changed_shell=true`
  - `general_feature_band_selected_count=14`
  - `general_feature_band_apply_target_count=14`
  - `general_feature_band_restore_changed_shell=true`
- `stage2_feature_band_results.txt`
- `stage2_selection_restore_results.txt`
- `crafting_bench_controls_results.txt`

## 51. 2026-04-05 first live Stage 2 higher-continuity feature-cluster pass

The first higher-continuity `surface_feature_cluster` Stage 2 path now exists in live code.

What exists now:
- current first-pass feature-cluster selection tools are:
  - `stage2_surface_feature_cluster_fillet`
  - `stage2_surface_feature_cluster_chamfer`
  - `stage2_surface_feature_cluster_restore`
- current first-pass `surface_feature_cluster` truth is:
  - the closure of connected coplanar same-zone offset-derived feature regions plus their adjacent transition bands across the same topology plane

Current first-pass behavior:
- feature-cluster targets sit above feature-band targets in continuity scope
- feature-cluster selection no longer stops at one same-offset region or one immediate transition band
- live chamfer/restore now work through the shared selection/apply path on this higher-continuity family too
- the continuity proof is locked with a synthetic linear Stage 2 patch graph:
  - synthetic band = `3`
  - synthetic cluster = `6`
  - `synthetic_cluster_larger_than_band=true`

Verified:
- `stage2_feature_cluster_results.txt`
  - `stage2_geometry_menu_has_feature_cluster_fillet=true`
  - `stage2_geometry_menu_has_feature_cluster_chamfer=true`
  - `stage2_geometry_menu_has_feature_cluster_restore=true`
  - `feature_cluster_tool_apply_visible=true`
  - `feature_cluster_tool_clear_visible=true`
  - `synthetic_band_selected_count=3`
  - `synthetic_cluster_selected_count=6`
  - `synthetic_cluster_larger_than_band=true`
  - `feature_cluster_chamfer_changed_shell=true`
  - `feature_cluster_restore_changed_shell=true`
- `stage2_feature_band_results.txt`
- `stage2_feature_band_restore_results.txt`
- `crafting_bench_controls_results.txt`

## 52. 2026-04-05 first live Stage 2 cross-topology feature-bridge pass

The first cross-topology `surface_feature_bridge` Stage 2 path now exists in live code.

What exists now:
- current first-pass feature-bridge selection tools are:
  - `stage2_surface_feature_bridge_fillet`
  - `stage2_surface_feature_bridge_chamfer`
  - `stage2_surface_feature_bridge_restore`
- current first-pass `surface_feature_bridge` truth is:
  - the closure of connected same-zone non-zero-offset feature clusters bridged across shared topology edges between different topology planes

Current first-pass behavior:
- feature-bridge targets sit above same-plane feature-cluster targets in continuity scope
- feature-bridge selection now crosses topology-plane breaks when modified clusters share a valid boundary edge across those planes
- live chamfer/restore now work through the shared selection/apply path on this higher-continuity family too
- the continuity proof is locked with a synthetic bridge topology:
  - synthetic cluster = `6`
  - synthetic bridge = `12`
  - `synthetic_bridge_larger_than_cluster=true`
- grip-safe bridge rule still holds:
  - bridge fillet allowed
  - bridge chamfer blocked

Verified:
- `stage2_feature_bridge_results.txt`
  - `stage2_geometry_menu_has_feature_bridge_fillet=true`
  - `stage2_geometry_menu_has_feature_bridge_chamfer=true`
  - `stage2_geometry_menu_has_feature_bridge_restore=true`
  - `feature_bridge_tool_apply_visible=true`
  - `feature_bridge_tool_clear_visible=true`
  - `synthetic_cluster_selected_count=6`
  - `synthetic_bridge_selected_count=12`
  - `synthetic_bridge_larger_than_cluster=true`
  - `feature_bridge_chamfer_changed_shell=true`
  - `feature_bridge_restore_changed_shell=true`
  - `grip_safe_feature_bridge_fillet_changed_shell=true`
  - `grip_safe_feature_bridge_chamfer_changed_shell=false`
- `stage2_feature_cluster_results.txt`
- `stage2_feature_band_results.txt`
- `stage2_feature_band_restore_results.txt`
- `crafting_bench_controls_results.txt`

## 53. 2026-04-05 first live Stage 2 multi-plane feature-contour pass

The first multi-plane `surface_feature_contour` Stage 2 path now exists in live code.

What exists now:
- current first-pass feature-contour selection tools are:
  - `stage2_surface_feature_contour_fillet`
  - `stage2_surface_feature_contour_chamfer`
  - `stage2_surface_feature_contour_restore`
- current first-pass `surface_feature_contour` truth is:
  - the per-topology-plane offset-transition contour inside a bridge-connected modified feature family

Current first-pass behavior:
- feature-contour targets sit above bridge as the first explicit boundary/transition family for the whole bridged modified set
- feature-contour selection is not the full bridge closure:
  - it resolves the seam/transition subset inside that bridged family
- live chamfer/restore now work through the shared selection/apply path on this contour family too
- the continuity proof is locked with a synthetic bridge topology:
  - synthetic bridge = `12`
  - synthetic contour = `8`
  - `synthetic_contour_smaller_than_bridge=true`
- grip-safe contour rule still holds:
  - contour fillet allowed
  - contour chamfer blocked

Verified:
- `stage2_feature_contour_results.txt`
  - `stage2_geometry_menu_has_feature_contour_fillet=true`
  - `stage2_geometry_menu_has_feature_contour_chamfer=true`
  - `stage2_geometry_menu_has_feature_contour_restore=true`
  - `feature_contour_tool_apply_visible=true`
  - `feature_contour_tool_clear_visible=true`
  - `synthetic_bridge_selected_count=12`
  - `synthetic_contour_selected_count=8`
  - `synthetic_contour_non_empty=true`
  - `synthetic_contour_smaller_than_bridge=true`
  - `feature_contour_chamfer_changed_shell=true`
  - `feature_contour_restore_changed_shell=true`
  - `grip_safe_feature_contour_fillet_changed_shell=true`
  - `grip_safe_feature_contour_chamfer_changed_shell=false`
- `stage2_feature_bridge_results.txt`
- `stage2_feature_cluster_results.txt`
- `crafting_bench_controls_results.txt`

## 54. 2026-04-05 structural volume authoring brief aligned to live forge ownership

The structural authoring brief has now been reinterpreted against the real repo instead of being left as a generic `stage1_*` module sketch.

Current locked understanding:
- the existing freehand structural path remains the authority
- structural shape tools are future footprint extensions of that same path, not a separate subsystem
- the correct ownership stays under the current forge bench/runtime files:
  - `runtime/forge/crafting_bench_ui.gd`
  - `runtime/forge/forge_bench_menu_presenter.gd`
  - `runtime/forge/forge_plane_viewport.gd`
  - `runtime/forge/forge_workspace_interaction_presenter.gd`
  - `runtime/forge/forge_workspace_edit_action_presenter.gd`
  - `runtime/forge/forge_grid_controller.gd`

The structural tool family is now documented as:
- rectangle
- circle
- oval
- triangle

All remain:
- pre-Stage-2
- structural
- block-truthful
- routed through the same placement/removal path as freehand

The structural brief now also carries a future implementation reminder for:
- `layer sweep authoring`

Current intended meaning:
- simultaneous held structural placement/removal plus continuous held `Q` / `E` layer stepping
- apply the active footprint once on each newly entered layer
- keep this inside the same structural authoring path rather than inventing a separate mechanic

Reference:
- `GDD-and Text Resources/Structural Volume Authoring System.md`

## 55. 2026-04-05 first live layer-sweep authoring pass

The first live `layer sweep authoring` pass now exists inside the current forge structural authoring path.

What exists now:
- current live scope is plane-view structural authoring
- current live behavior is:
  - hold mouse for structural draw/remove
  - hold `Q` / `E` for repeated layer stepping
  - when both are active together, apply the current structural footprint once per newly entered layer
- current first pass intentionally excludes `pick`

Current ownership:
- `runtime/forge/forge_plane_viewport.gd`
  - now stores the active dragged plane footprint and can re-emit that footprint on the new active layer
- `runtime/forge/crafting_bench_ui.gd`
  - now reapplies the current plane drag footprint after real layer changes only

Important boundary:
- this is currently plane-view structural behavior only
- it is not a separate structural write path
- it is not yet the later shape-footprint pass; it just makes the existing footprint sweep across layers
- same-layer repeats are intentionally blocked, so one entered layer gets one re-application

Verified:
- `crafting_bench_layer_sweep_results.txt`
  - `placed_layers=[15, 16, 17, 18]`
  - `layer_sweep_place_success=true`
  - `place_one_per_new_layer=true`
  - `layer_sweep_erase_success=true`
  - `erase_returned_to_empty=true`
- `crafting_bench_controls_results.txt`
  - `layer_hold_delay_respected=true`
  - `layer_hold_repeat_advanced=true`
- `crafting_bench_paint_drag_results.txt`
  - `plane_drag_place_success=true`
  - `plane_drag_erase_success=true`
  - `free_drag_place_success=true`
  - `free_drag_erase_success=true`

## 56. 2026-04-05 first live structural rectangle tool pass

The first live Structural Volume authoring tool beyond freehand now exists in the forge bench.

What exists now:
- current first-pass structural shape tool is:
  - `rectangle_place`
  - `rectangle_erase`
- current live scope is:
  - plane-view only
  - drag-defined axis-aligned rectangle footprint
  - same structural commit path as freehand
- current live preview is:
  - truthful cell-by-cell rectangle preview on the active plane before release

Current ownership:
- `runtime/forge/forge_workspace_shape_tool_presenter.gd`
  - rectangle tool ids and rectangle footprint resolution
- `runtime/forge/forge_plane_viewport.gd`
  - active drag signals plus structural shape preview drawing
- `runtime/forge/crafting_bench_ui.gd`
  - shape drag state, preview sync, menu/tool routing, and batch commit through the existing structural path
- `runtime/forge/forge_workspace_edit_action_presenter.gd`
  - batched structural add/remove commit over resolved cell sets

Important boundary:
- this first rectangle pass does not yet include rotation
- this first rectangle pass does not yet include circle / oval / triangle
- this is still not a separate save or mesh system; it writes normal structural cells only
- that pass still predated shape-sweep fusion; later structural shape layer sweep was added in section `59`

Verified:
- `crafting_bench_rectangle_tool_results.txt`
  - `geometry_menu_has_rectangle_draw=true`
  - `geometry_menu_has_rectangle_erase=true`
  - `preview_visible_during_drag=true`
  - `expanded_preview_count=4`
  - `rectangle_place_success=true`
  - `rectangle_place_expected_cells_ok=true`
  - `rectangle_erase_success=true`
- `crafting_bench_paint_drag_results.txt`
  - `plane_drag_place_success=true`
  - `plane_drag_erase_success=true`
  - `free_drag_place_success=true`
  - `free_drag_erase_success=true`
- `crafting_bench_layer_sweep_results.txt`
  - `layer_sweep_place_success=true`
  - `layer_sweep_erase_success=true`
- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_rectangle_draw=true`
  - `geometry_menu_has_rectangle_erase=true`

## 57. 2026-04-05 first live structural circle / oval / triangle tool pass

The remaining first-pass pre-Stage-2 structural shape tools are now also live in the forge bench.

What exists now:
- current first-pass structural shape tools are:
  - `rectangle_place` / `rectangle_erase`
  - `circle_place` / `circle_erase`
  - `oval_place` / `oval_erase`
  - `triangle_place` / `triangle_erase`
- current live scope is:
  - plane-view only
  - drag-defined footprint add/remove
  - same structural commit path as freehand
  - same overlay draw/erase family behavior as the active shape family

Current ownership:
- `runtime/forge/forge_workspace_shape_tool_presenter.gd`
  - shared shape-family ids plus rectangle/circle/oval/triangle footprint resolution
- `runtime/forge/crafting_bench_ui.gd`
  - shared shape preview routing and commit through the existing structural path
- `runtime/forge/forge_bench_menu_presenter.gd`
  - live menu exposure for circle / oval / triangle draw/erase tools
- `runtime/forge/forge_workspace_presentation.gd`
  - truthful tool/status naming and place/erase active-state reporting

Important boundary:
- rotation is still intentionally not live yet
- the correct next rotation step is one shared structural shape rotation slot across all shape tools, not separate per-shape rotation work
- that pass still predated shape-sweep fusion; later structural shape layer sweep was added in section `59`

Verified:
- `crafting_bench_shape_tools_results.txt`
  - `geometry_menu_has_circle_draw=true`
  - `geometry_menu_has_circle_erase=true`
  - `geometry_menu_has_oval_draw=true`
  - `geometry_menu_has_oval_erase=true`
  - `geometry_menu_has_triangle_draw=true`
  - `geometry_menu_has_triangle_erase=true`
  - `circle_place_expected_count_ok=true`
  - `oval_place_expected_count_ok=true`
  - `triangle_place_expected_count_ok=true`
  - `circle_erase_success=true`
  - `oval_erase_success=true`
  - `triangle_erase_success=true`
  - `overlay_switched_to_oval_erase=true`
  - `overlay_switched_back_to_oval_draw=true`
- `crafting_bench_rectangle_tool_results.txt`
  - `rectangle_place_success=true`
  - `rectangle_erase_success=true`
- `crafting_bench_layer_sweep_results.txt`
  - `layer_sweep_place_success=true`
  - `layer_sweep_erase_success=true`
- `crafting_bench_paint_drag_results.txt`
  - `plane_drag_place_success=true`
  - `plane_drag_erase_success=true`
  - `free_drag_place_success=true`
  - `free_drag_erase_success=true`
- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_circle_draw=true`
  - `geometry_menu_has_oval_draw=true`
  - `geometry_menu_has_triangle_draw=true`

## 58. 2026-04-05 shared structural shape rotation slot pass

The first shared structural shape rotation slot is now live in the forge bench.

What exists now:
- one shared quarter-turn rotation slot across the structural shape family:
  - `0°`
  - `90°`
  - `180°`
  - `270°`
- current live scope applies across:
  - `rectangle_place` / `rectangle_erase`
  - `circle_place` / `circle_erase`
  - `oval_place` / `oval_erase`
  - `triangle_place` / `triangle_erase`
- current live behavior:
  - menu-driven through the geometry menu
  - same slot reused across all structural shape tools
  - circle stays equivalent under quarter-turn rotation in the current first pass

Current ownership:
- `runtime/forge/crafting_bench_ui.gd`
  - shared rotation-slot state and UI wiring
- `runtime/forge/forge_bench_menu_presenter.gd`
  - geometry menu rotation actions
- `runtime/forge/forge_workspace_shape_tool_presenter.gd`
  - shared quarter-turn footprint rotation over resolved structural shape cells
- `runtime/forge/forge_workspace_presentation.gd`
  - truthful tool/status text with current rotation value

Important boundary:
- this is a shared quarter-turn slot, not a richer arbitrary-angle shape system
- the goal was to add one reusable rotation layer now and avoid rebuilding rotation separately per shape tool later
- that pass still predated shape-sweep fusion; later structural shape layer sweep was added in section `59`

Verified:
- `crafting_bench_shape_rotation_results.txt`
  - `geometry_menu_has_rotation_label=true`
  - `geometry_menu_has_rotate_left=true`
  - `geometry_menu_has_rotate_right=true`
  - `rectangle_rotation_ninety_ok=true`
  - `rectangle_rotation_changed_footprint=true`
  - `rectangle_rotation_swapped_bounds=true`
  - `rectangle_commit_ok=true`
  - `oval_rotation_changed_footprint=true`
  - `triangle_rotation_changed_footprint=true`
  - `circle_rotation_preserved_footprint=true`
- `crafting_bench_shape_tools_results.txt`
  - `circle_place_expected_count_ok=true`
  - `oval_place_expected_count_ok=true`
  - `triangle_place_expected_count_ok=true`
- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_circle_draw=true`
  - `geometry_menu_has_oval_draw=true`
  - `geometry_menu_has_triangle_draw=true`

## 59. 2026-04-05 structural shape layer sweep fusion pass

`layer sweep authoring` is now fused into the current structural shape drag path inside the forge bench.

What exists now:
- held structural shape drag plus held `Q` / `E` layer stepping now commits the active shape footprint once per newly entered layer
- the starting layer is committed before the first successful layer step
- each newly entered layer is committed once after the step
- release now only commits if the current layer still has uncommitted shape preview changes
- the current live verified shape-sweep scope is:
  - `rectangle`
  - `oval`

Current ownership:
- `runtime/forge/crafting_bench_ui.gd`
  - structural shape preview dirty-state tracking, pre-step commit, post-step commit, and release behavior
- `runtime/forge/forge_plane_viewport.gd`
  - plane-view shape drag signals that feed the shared structural shape preview path
- `runtime/forge/forge_workspace_edit_action_presenter.gd`
  - same batched structural add/remove commit path used by ordinary structural shape drag

Important boundary:
- current live fusion stays in the same plane-view structural authoring path
- `pick` remains excluded
- same-layer repeats are blocked
- this is not a second write path; it is the existing structural shape drag path plus layer stepping

Verified:
- `crafting_bench_shape_layer_sweep_results.txt`
  - `rectangle_place_layer_count=4`
  - `rectangle_place_expected_total_ok=true`
  - `rectangle_place_one_per_layer_ok=true`
  - `rectangle_erase_success=true`
  - `oval_place_layer_count=4`
  - `oval_place_expected_total_ok=true`
  - `oval_place_one_per_layer_ok=true`
  - `oval_erase_success=true`
- `crafting_bench_shape_tools_results.txt`
  - `circle_place_expected_count_ok=true`
  - `oval_place_expected_count_ok=true`
  - `triangle_place_expected_count_ok=true`
  - `circle_erase_success=true`
  - `oval_erase_success=true`
  - `triangle_erase_success=true`
- `crafting_bench_rectangle_tool_results.txt`
  - `rectangle_place_success=true`
  - `rectangle_erase_success=true`
- `crafting_bench_layer_sweep_results.txt`
  - `layer_sweep_place_success=true`
  - `layer_sweep_erase_success=true`
- `crafting_bench_paint_drag_results.txt`
  - `plane_drag_place_success=true`
  - `plane_drag_erase_success=true`
  - `free_drag_place_success=true`
  - `free_drag_erase_success=true`
- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_rectangle_draw=true`
  - `geometry_menu_has_circle_draw=true`
  - `geometry_menu_has_oval_draw=true`
  - `geometry_menu_has_triangle_draw=true`

## 60. 2026-04-05 warning cleanup pass

The first explicit warning-cleanup pass landed for the current forge/player refactor surface.

What changed:
- same-class shadowing warnings were removed across the recent presenter/helper splits by renaming forwarded `Callable` parameters to `_callback` style instead of leaving them identical to local method names
- truly unused parameters were removed where they were no longer part of the real dependency path
- the player grip layout warning was fixed as a real math/scoping correction, not a silence pass:
  - `mini(...)` on float span values was corrected to `minf(...)`
  - duplicate local `support_position` naming was split into clearer branch-specific names
- the forge axis gizmo warning was fixed at the loading path:
  - the HUD gizmo now instantiates the imported PackedScene resource
  - it no longer reparses the raw `.glb` through `GLTFDocument` on every load

Main files:
- `core/models/crafted_item_wip.gd`
- `core/resolvers/bow_resolver.gd`
- `runtime/player/player_forge_test_presenter.gd`
- `runtime/player/player_rig_grip_layout_presenter.gd`
- `runtime/forge/forge_workspace_preview.gd`
- `runtime/forge/forge_workspace_edit_flow.gd`
- `runtime/forge/forge_workspace_edit_action_presenter.gd`
- `runtime/forge/forge_workspace_interaction_presenter.gd`
- `runtime/forge/forge_project_panel_presenter.gd`
- `runtime/forge/forge_bench_refresh_presenter.gd`
- `runtime/forge/forge_workspace_shape_tool_presenter.gd`
- `runtime/forge/forge_workspace_axis_indicator.gd`

Verified:
- warning-focused forge rerun:
  - `godot_runs/verify_crafting_bench_controls_warning_cleanup_2026-04-05_b.log`
- warning-focused grip-layout rerun:
  - `godot_runs/verify_player_grip_hold_layout_warning_cleanup_2026-04-05_b.log`
- behavior checks still green:
  - `crafting_bench_controls_results.txt`
  - `player_grip_hold_layout_results.txt`

Current residual:
- the remaining visible line in those runs is the Windows root certificate store read warning from the environment
- the targeted GDScript shadowing / unused-parameter / narrowing-conversion / confusable-local warnings from this cleanup batch are no longer present in the fresh logs

## 61. 2026-04-08 forge overlay stability + Stage 2 radius HUD pass

The forge overlay now has a stable host above the workspace stage instead of living under the swap-prone main viewport host.

What changed:
- `ToolOverlayPanel` moved under a stable `ToolOverlayHost` on `WorkspaceStage`
- repeated `2D Main` / `3D Main` swaps no longer orphan the overlay under a reparented viewport host
- the overlay is now a richer live HUD:
  - `Tool State: <Add / Remove / Pick>`
  - `Active Tool: <tool name>`
  - placement-mode material row only:
    - `<material name> - <quantity>`
    - `Select Material` when nothing is selected / armed
  - no material row during Stage 2 refinement mode
  - `Radius: <value> m` only for the mouse-centered Stage 2 brush family
- Stage 2 pointer-brush radius now supports `Ctrl + Mouse Wheel`
  - current first-pass direction:
    - wheel up = larger radius
    - wheel down = smaller radius
  - clamped by live forge rules:
    - `stage2_pointer_tool_min_radius_meters = 0.0125`
    - `stage2_pointer_tool_max_radius_meters = 0.375`
    - `stage2_pointer_tool_radius_step_meters = 0.0125`
- radius control only applies to the pointer-radius Stage 2 brush family:
  - `stage2_carve`
  - `stage2_restore`
  - `stage2_fillet`
  - `stage2_chamfer`
- radius does not apply to Stage 2 selection-driven edge / face / feature tools

Main files:
- `scenes/ui/crafting_bench_ui.tscn`
- `runtime/forge/crafting_bench_ui.gd`
- `runtime/forge/forge_stage2_brush_presenter.gd`
- `core/defs/forge_rules_def.gd`
- `core/defs/forge/forge_rules_default.tres`

Verified:
- `crafting_bench_overlay_hud_results.txt`
  - `overlay_parent_is_tool_host=true`
  - `overlay_host_frontmost_after_second_flip=true`
  - `rectangle_overlay_erase_after_second_flip_ok=true`
  - `select_material_prompt_ok=true`
  - `material_hidden_in_stage2=true`
  - `radius_visible_in_stage2=true`
  - `radius_increased_with_ctrl_scroll=true`
  - `radius_clamped_to_min=true`
  - `radius_clamped_to_max=true`
- regressions stayed green:
  - `crafting_bench_controls_results.txt`
  - `crafting_bench_shape_tools_results.txt`
  - `stage2_refinement_mode_results.txt`

Reminder:
- later overlay evolution is still intended:
  - active tool row becomes a future tool picker surface
  - material row becomes a future material picker surface
  - text can later swap to icon + quantity once the material icon pipeline exists

## 62. 2026-04-08 shape/Stage 2 regression fix pass

Live fixes:
- `runtime/forge/forge_plane_viewport.gd`
  - plane drag now interpolates between plane cells instead of only applying the current hovered cell
  - this restores missed-cell coverage for faster freehand drag and gives shape drag a stable multi-cell path update
- `runtime/forge/forge_workspace_interaction_presenter.gd`
  - `Ctrl + Mouse Wheel` now suppresses the generic free-view zoom handlers
  - Stage 2 pointer-radius resize no longer falls through to camera zoom at the same time
- `services/forge_stage2_service.gd`
  - Stage 2 patch neighbor detection no longer uses the old all-pairs walk
  - it now hashes coplanar edge keys before linking neighbors, which is the current anti-freeze path for `Initialize / Refresh Stage 2`
- `runtime/forge/crafting_bench_ui.gd`
  - Stage 2 brush and selection edits now refresh workspace visuals immediately after apply instead of waiting only on the deferred edit refresh path
- `runtime/forge/forge_workspace_shape_tool_presenter.gd`
  - removed the stale unused `_build_plane_bounds(active_layer)` parameter warning

Important current limitation kept explicit:
- current Stage 1 structural shapes are still drag-footprint tools
  - rectangle / circle / oval / triangle size is currently defined by drag bounds on the plane
  - there is not yet a separate end-user scalar size adjuster for Stage 1 shapes
- current Stage 1 shape rotation is still the live quarter-turn system
  - `0 / 90 / 180 / 270`
  - full `0..360` per-degree rotation is still a later feature pass

Verified:
- `crafting_bench_paint_drag_results.txt`
  - `plane_drag_place_success=true`
  - `plane_drag_erase_success=true`
  - `free_drag_place_success=true`
  - `free_drag_erase_success=true`
- `crafting_bench_shape_tools_results.txt`
  - `circle_place_expected_cells_ok=true`
  - `oval_place_expected_cells_ok=true`
  - `triangle_place_expected_cells_ok=true`
- `stage2_refinement_foundation_results.txt`
  - `stage2_initialized=true`
  - `stage2_patch_count=40`
- `stage2_refinement_mode_results.txt`
  - `stage2_shell_visible=true`
  - `carve_changed_shell=true`
- fresh logs no longer showed the old `forge_workspace_shape_tool_presenter.gd:204` unused-parameter reload warning

## Forge Tool Contract Lock

Current live forge authoring now follows:

- Stage 1:
  - `tool family` = `freehand / rectangle / circle / oval / triangle`
  - global modifier = `Add / Remove / Pick`
- Stage 2:
  - `tool family` = pointer brush or selection family
  - global modifier = `Apply / Revert`

Important UI law:

- visible geometry menus should expose tool families, not duplicate add/remove or apply/revert variants
- restore/revert selection variants still exist in code as effective tool ids
- but the user-facing path is now `select family -> change global modifier`

Current verified effects:

- Stage 1 shape menus now show `Rectangle Tool`, `Circle Tool`, `Oval Tool`, `Triangle Tool`
- Stage 1 erase variants are hidden from the menu
- Stage 2 restore variants are hidden from the menu
- Stage 2 restore/revert is reached through the shared overlay/global modifier flow
- overlay text and status wording now use `Material` instead of `Armed material`

Verified:

- `crafting_bench_controls_results.txt`
  - `geometry_menu_has_rectangle_tool=true`
  - `geometry_menu_hides_rectangle_erase_entry=true`
- `crafting_bench_rectangle_tool_results.txt`
  - `geometry_menu_has_rectangle_tool=true`
  - `rectangle_erase_success=true`
- `stage2_feature_restore_results.txt`
  - `stage2_geometry_menu_feature_region_restore_hidden=true`
  - `restore_tool_revert_visible=true`
- `stage2_selection_restore_results.txt`
  - `stage2_geometry_menu_face_restore_hidden=true`
  - `restore_tool_revert_visible=true`
