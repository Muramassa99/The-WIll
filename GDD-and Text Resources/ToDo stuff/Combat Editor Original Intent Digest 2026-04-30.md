# Combat Editor Original Intent Digest 2026-04-30

## Purpose

This file brings together the older four combat-editor design files so their original intent can be compared against the newer Skill Crafter implementation TODO.

This is not a replacement for the source files. It is a compact reading map and relevance check.

## Source Files Read

- `GDD-and Text Resources/Runtime Weapon-Owned Melee Skill Crafter 1.md`
- `GDD-and Text Resources/Runtime Weapon-Owned Melee Skill Crafter-2.md`
- `GDD-and Text Resources/Runtime Melee Combat Editor Visual-System.md`
- `GDD-and Text Resources/Runtime Combat Editor Visual and System Addendum.md`

## Core Original Intent

### 1. Runtime, Weapon-Owned Authoring

The combat editor was always intended as an in-game runtime authoring station.

It is not:

- an offline developer-only tool
- a generic animation editor
- a dense frame-by-frame skeleton editor
- a loose visual-only spline toy

It is:

- opened from a selected weapon
- opened on a selected skill slot / skill draft
- saved back into the owning weapon
- restored later when that same weapon is reopened

Current relevance:

- Still fully valid.
- This supports the current weapon-owned draft model.
- It also supports future skill inspection / trading, because the skill is real runtime data owned by the weapon.

### 2. Entry Flow

The original workflow is:

1. Weapon selection.
2. Skill slot / skill selection.
3. 3D editor workflow.

The editor should not open without:

- one selected weapon
- one selected skill slot or skill draft target

Current relevance:

- Still valid.
- Newer authority cleanup should keep this flow.
- Combat idle and noncombat/stow authoring can live in the same station family, but should still make the selected authoring target explicit.

### 3. Destination Points / Motion Nodes Are The Hard Structure

Older files used the term `point`; newer project language corrected this to `motion node`.

The original intent behind points was not "just a position." It was the authored combat timeline unit.

The hard structure defines:

- order
- segment boundaries
- startup / entry positioning
- hit economy structure
- slowdown/reset zones
- local navigation
- save/restore structure

Current relevance:

- Still valid, but use `motion node`.
- The current implementation has already moved beyond a simple point and stores grip, hand, weapon frame, roll, support, timing, and other state.
- The newer parametric retarget plan should preserve the motion node as the authored unit.

### 4. Bezier Handles Are The Freedom Layer

The old docs repeat this clearly:

- destination points / motion nodes are the law
- Bezier handles / control vectors are the freedom

Bezier data was intended to define:

- trajectory style
- curvature
- flourish
- readable path between motion nodes
- swing shape

The Bezier path is not cosmetic only.

It should be sampled for:

- trajectory display
- editor preview
- runtime playback
- speed-state evaluation
- weapon motion driving
- future body-follow / IK
- future sound/effect timing

Current relevance:

- Still valid.
- This strengthens the current requirement that grip-swap and bridge trajectories must use editable path data where applicable.
- The newer valid-volume system should constrain Bezier handles and sampled path positions, not only endpoint positions.

### 5. Saved Motion Data

The old files require modular runtime motion data, not baked animation clips.

Saved data must support:

- motion node positions
- Bezier handle / control-vector data
- point or node order
- active plane state
- slowdown/reset metadata near destination nodes
- segment timing / speed profile metadata
- draft metadata needed for restore
- future runtime metadata needed by solver/playback

Current relevance:

- Still valid.
- Newer normalized retarget data should add to this, not erase it.
- Legacy absolute tip/pommel data can remain as migration/display data, but the future saved truth should be retargetable from grip/contact pivot plus normalized legal-volume placement.

### 6. Control Law

Original controls:

- `Q` = previous motion node
- `E` = next motion node
- `R` = add new motion node after current
- `T` = delete current editable motion node
- `Space` = commit current motion node edit
- `F` = preview full chain from the beginning

Original safety rules:

- `Q` and `E` are navigation only.
- `T` must update selection, visuals, and chain state cleanly.
- `F` playback must not mutate committed draft data.
- Leaving the editor auto-saves.

Current relevance:

- Still valid for normal skill drafts.
- Newer combat idle special case overrides `R`/`T` because combat idle is a single-node authoring target:
  - `T` cannot delete it.
  - `R` should reset it, not add a second idle node.

### 7. Onion Skin And Local Context

Original requirement:

- show current motion node
- show node -1 and +1 at 50% transparency
- show node -2 and +2 at 25% transparency
- update live on navigation, insert, delete, commit, drag, and selection changes

Current relevance:

- Still valid for skill chains.
- For single-node idle/stow authoring, onion skin can be hidden or replaced with target-specific context.

### 8. Active Plane Editing

The original editor was intended to expose a visible action plane or plane guide.

The player should be able to:

- see the active plane
- rotate/adjust it
- drag the active target constrained to it
- preserve plane state as authored data where useful

Current relevance:

- Still valid.
- The newer normalized-ray/volume model should decide whether the plane remains a direct movement plane, a helper for ray selection, or both.

### 9. Preview And Runtime Playback Must Share The Same Layer

The old docs are very explicit that `F` preview should not be editor-only code.

The playback layer should support:

- editor one-shot preview
- runtime skill execution
- looped skill presentation
- inspection view
- trading/showcase view

Current relevance:

- Very important and still valid.
- Current chain-player reuse is already aligned with this.
- A later presentation view should reuse the same runtime-capable playback path, not a video or duplicate visual-only driver.

### 10. Hit Segmentation

Original melee rule:

- current runtime state -> first authored motion node is startup / entry positioning
- the startup motion does not count as a hit
- each later node-to-node segment is one potential strike phase
- near each destination node, motion enters a controlled slowdown/reset band
- after that band, motion re-accelerates into the next segment

Current relevance:

- Still relevant unless intentionally changed later.
- The current hidden entry bridge fits the startup/non-hit idea.
- Slowdown/reset metadata should remain part of the motion model or be reintroduced when segment timing is formalized.

### 11. Speed-State Trajectory Coloring

Original visual feedback:

- red = valid armed strike threshold or higher
- green = low-speed / reset / non-armed
- gradient = buildup or decay

This is not only cosmetic. It is a live combat-state preview for the player.

Current relevance:

- Still relevant.
- Not yet central enough in the new TODO.
- Should be tied to segment timing, slowdown/reset bands, weapon feel, and later collision legality.

### 12. Slot Law And Hit Economy

The combat editor does not invent the role of a skill.

The selected skill slot defines the role box.

Examples from old docs:

- block/parry
- displacement
- crowd control
- damage
- buff/support
- iframe

The editor authors the motion expression inside that selected role.

Hit count is also resolved through gameplay law:

- skill slot output
- weapon/material/build modifiers
- then mapped onto authored strike segments

Current relevance:

- Still valid.
- Current work can postpone full slot-law enforcement, but the data model should not block it.

### 13. Stage 1 Data Relationship

Older files say the combat editor pulls gameplay-relevant inputs from Stage 1, including:

- material data
- effect data
- center of mass
- mass distribution
- grip data
- weapon class output
- handling-related values

Newer chat corrected one important authority boundary:

- Stage 1 is no longer stance/stow authority.
- Stage 1 remains geometry/build/material/profile truth.

Current reconciliation:

- Stage 1 should own weapon build truth.
- Stage 1 should not own combat idle stance, skill stance, or final stow authoring truth.
- Stage 1 material, geometry, mass, grip, and baked profile data still feed the combat editor and runtime solver.

### 14. Weapon Feel

The original intent is that not all weapons should move identically.

Motion should eventually account for:

- center of mass
- mass distribution
- grip relation / grip triangulation
- balance
- handling implications

This can affect:

- acceleration
- deceleration
- redirection responsiveness
- weighted vs nimble motion feel

Current relevance:

- Still valid.
- This belongs after the legal-motion foundation exists, because weapon feel should shape allowed timing/response rather than break solver stability.

### 15. Material, Effect, Sound, Air/Ground Compatibility

Older docs preserve future compatibility for:

- material/effect visuals during armed state
- material/effect hit output on valid collision
- whoosh / swing sound from motion speed
- impact sound from collision/material
- future ground vs air contextual differences

Current relevance:

- Still valid future hooks.
- Not immediate implementation unless the current slice touches the data model.
- Do not structure the curve/playback system in a way that makes these impossible later.

## Relevant Items Not Explicit Enough In The Unified TODO

These should be considered additions or stronger reminders for the working TODO:

1. Reusable looped skill presentation view.
2. Speed-state trajectory coloring.
3. Slowdown/reset band metadata at motion nodes.
4. Slot-law and hit-economy integration.
5. Stage 1 material/build/handling data feeding motion feel without owning stance/stow.
6. Active plane editing as a first-class visible authoring tool.
7. Auto-save/restore as a hard player-work-protection rule.
8. Bezier handles as gameplay-relevant sampled motion data, not decoration.

## Implementation Order Impact

The newer implementation order remains mostly correct, but these older docs suggest a few insertions:

1. During authority cleanup, explicitly preserve Stage 1 as build/material/profile truth while removing stance/stow authority.
2. During combat idle and skill data cleanup, keep Bezier handle data and slowdown/reset metadata visible in the model.
3. Before deeper runtime combat behavior, ensure chain playback remains reusable for editor preview, runtime execution, and later presentation/trading views.
4. When trajectory volume work continues, validate sampled Bezier path positions, not only motion node endpoints.
5. Add speed-state coloring and segment armed/reset visualization as near-term editor feedback, using the same sampled data path that later supports hitbox logic.
6. After retargeting exists, presets can become real because normalized motion recipes can adapt to weapon geometry.

## Resolved Questions From 2026-04-30

1. Slowdown/reset bands stay hard law near every non-start motion node.
2. Speed-state coloring becomes near-term editor feedback and later feeds armed-state/hitbox logic.
3. Obsolete UI must be disabled or hidden so it cannot push stale state.
4. Collision proxies should be mesh-derived and adaptable, not placeholder capsule authoring truth.
5. Collision response should clamp when deterministic and reject when not.
6. Shape-change retargeting should be automatic and seamless in normal cases.

## Remaining Questions Recovered From The Old Intent

1. Should looped skill presentation/trading view be tracked as a separate later feature, or folded into the playback architecture work now?
2. Should active plane editing remain a direct manipulation tool in the normalized-ray future, or become a helper/gizmo around the normalized volume?
3. Should slot-law hit economy be represented in the draft data now as placeholder metadata, even before final combat damage logic exists?
