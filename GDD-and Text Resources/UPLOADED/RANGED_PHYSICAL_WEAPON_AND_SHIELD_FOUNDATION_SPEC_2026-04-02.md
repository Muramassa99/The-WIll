# Ranged Physical Weapon And Shield Foundation Spec

Date: `2026-04-02`

Purpose:
- lock the newer system shape for ranged physical weapons and shields so it does not get lost
- update the older simpler "bow" mental model
- keep future implementation aligned with the permanent end-product intent

## 1. Terminology Lock

Old loose usage:
- `bow` was sometimes used as the whole system name

Locked terminology from now on:
- `Ranged Physical Weapon`
  - umbrella term for the physical ranged weapon family
  - this includes the `bow` component and the `quiver` component
- `bow`
  - the actual bow body / launcher component
- `quiver`
  - the carried container component for arrows
- `Ranged Magical Weapon`
  - separate future umbrella for magic-based ranged weapons

Reason:
- this prevents `ranged` vs `bow` vs `quiver` confusion later
- this keeps future crafting/UI/resolver work using precise names

## 2. Locked High-Level Law

`Ranged Physical Weapon` is not a single-part craft.

It is a two-component system:
- `bow`
- `quiver`

They are crafted separately.

They are later equipped/used under one shared ranged-physical umbrella.

This is the first system in the project that combines:
- a melee-like solid builder for one component
- a mannequin/shell-restricted builder for another component

So the future implementation must not treat ranged physical as "just another melee weapon with string logic."

## 2A. Crafting Station Entry Law

The weapon crafting station should not open directly into one fixed editor path by assumption.

Locked station entry flow:
- `Continue Last`
  - loads the last preferred saved forge state
- `Project List`
  - opens the existing saved-WIP/project list across all archetypes so work can continue on an older parallel project instead of only the most recent one
- `New Melee Weapon`
  - opens the current melee-oriented blank forge workflow
- `New Ranged Physical Weapon`
  - opens the ranged-physical craft path
- `New Shield`
  - opens the shield craft path
- `New Magic Weapon`
  - opens the magic craft path

Reason:
- melee, ranged physical, shield, and magic will share some architecture
- but they should still exist as separate code paths/entities because each needs its own rules and layout

First implemented foundation note:
- the station now has an explicit craft-path entry menu
- `forge_builder_path_id` is the persistent WIP-level selector for that branch
- dedicated ranged/shield/magic layouts still come later, but the entry split should exist now so later UI divergence does not need to be retrofitted from a melee-only opening flow

### Workspace Size Law

The forge work area should not stay one shared size for every archetype.

Locked first-pass workspace sizes:
- melee = `240 x 80 x 40`
- ranged physical bow body = `160 x 80 x 30`
- shield = `100 x 80 x 30`
- magic = `100 x 30 x 30`
- ranged physical quiver = `70 x 30 x 30`

Reason:
- melee needs more forward length for pole-style weapons
- the other archetypes need distinct working envelopes so the player can immediately read that they are in a different builder path
- these different envelopes are part of the archetype identity, not only cosmetic layout

## 3. Bow Component Law

The `bow` component uses a crafting method closer to the current melee weapon path:
- voxel/solid authored build
- canonical fused shape output
- no mannequin shell core for the bow body itself

The bow is still its own component, not the whole ranged umbrella.

### Bow String Anchor Law

The bow string should not be authored by forcing the player to build the visible string cell-by-cell.

Instead, bow crafting should use explicit authored endpoint markers.

Concept:
- special creator-point blocks are placed in the bow crafter
- these are required structure markers, similar in spirit to grip conditioning on melee weapons
- they define where the string endpoints live

First naming pass:
- first legal pair:
  - `A1`
  - `A2`
- future additional pairs if ever needed:
  - `B1`
  - `B2`
  - and so on

Implementation-minded naming note:
- user-facing labels can stay simple like `A1 / A2 / B1 / B2`
- internally this should behave like:
  - `string_anchor_pair_id`
  - `string_anchor_endpoint_id`
- that keeps the system extensible without hardcoding only one pair forever

Locked authored-truth law:
- a bow is not eligible as a bow unless the required string-anchor pair exists
- for the first permanent pass, one legal pair is enough:
  - `A1`
  - `A2`
- future multi-string or exotic variants can extend the same system with more pairs if needed

First implemented foundation note:
- the live forge builder now surfaces `6` authored string-anchor pairs:
  - `A1 / A2`
  - `B1 / B2`
  - `C1 / C2`
  - `D1 / D2`
  - `E1 / E2`
  - `F1 / F2`
- these currently appear as ranged-bow-only builder markers pinned at the top of the forge material list
- they are non-inventory authoring entries:
  - no forge-material consume/refund
  - single-marker relocation instead of duplicate placement
  - filtered out of baked geometry / test-print geometry
- the current bow runtime path now prefers the first complete authored pair when present and falls back to older inferred string logic for legacy/sample content when no authored pair exists yet
- the forge 3D workspace now also shows a first-pass generated bow string rest path from those authored anchors, so the player can see the connected string inside the builder before later draw/deform/runtime-fire work is added

Runtime/render law:
- the player places the endpoint anchors
- the system generates the string between them in post
- the string is then manipulated/rendered by code instead of being fully authored as voxel geometry by the player

### Runtime Bow String Mapping Law

The generated bow string must still be able to connect cleanly to the player model during draw/use.

So the bow string system is not only:
- authored endpoint truth

It is also:
- runtime hand-connected string behavior

First permanent runtime model:
- use a four-point mapping for the active drawn string state

Meaning:
- point 1 = authored endpoint anchor `A1`
- point 2 = authored endpoint anchor `A2`
- point 3 = runtime string alignment / center reference on the bow side, kept in line with the holding-hand / riser side
- point 4 = runtime pull / nock point attached to the firing hand

Practical behavior:
- the holding hand stays on the bow body
- the firing hand attaches to the string pull point
- drawing the weapon moves the firing hand back
- the string deforms accordingly instead of staying a fixed straight line
- releasing the draw allows the string to return to its straight/rest state
- that return event is the trigger point for the projectile shot release behavior

This must work across different crafted configurations:
- long bow
- short bow
- slingshot-like close-endpoint cases

### Draw Distance Law

String endpoint separation and draw distance are not the same thing.

So:
- endpoint distance may vary depending on the crafted ranged body
- draw distance behavior must still remain consistent and controllable across valid configurations

Locked intent:
- short-endpoint and wide-endpoint ranged physical weapons should still use the same runtime draw-control law
- the system must not become unusable just because endpoint anchors are close together
- the system must not assume one fixed bow size

That means future runtime should resolve:
- endpoint spacing from authored geometry
- draw behavior from normalized runtime rules

not:
- draw behavior directly guessed only from raw endpoint distance

Why this matters:
- it keeps long bows and short bows usable inside one system
- it allows slingshot-like variants later without inventing a separate string model
- it keeps bow/string animation predictable and readable
- it gives projectile release a clean deterministic trigger

Why this is the correct foundation:
- it gives explicit authored truth for string endpoints
- it avoids bad-looking hand-built string geometry
- it makes render/control of the string much more predictable
- it gives animation and draw logic a clean stable source for bow-string behavior
- it allows the string to connect to the actual player hands cleanly during draw/release
- it separates authored endpoint spacing from normalized runtime draw behavior
- it reduces bow heuristic inference later

So for future ranged physical work:
- explicit string-anchor creator points are the canonical source of bow-string endpoints
- not freehand player-made string volume

Bow stow law:
- valid stow zones are:
  - same-side back slot
  - lower back
- invalid stow zone:
  - shoulder hanging

Bow side law:
- if the bow is held in the left hand, the bow stows on the left-side valid bow slot
- if the bow is held in the right hand, the bow stows on the right-side valid bow slot

This means the bow uses the free back-side space not occupied by the quiver.

## 4. Quiver Component Law

The `quiver` is not crafted like a normal melee weapon.

It uses the mannequin/shell restriction idea that was previously discussed for armor/accessory systems.

Core law:
- the quiver crafter contains a forced empty core / restricted area
- the player is only allowed to build around that restricted inner space
- part of that restricted shape extends outside the legal build area
- because of that extension, the player cannot fully cap both ends
- this creates an open container state by construction

Important:
- this is intentionally simple
- no fancy "detect open cavity" rule should be needed for the first permanent design
- the restricted volume itself creates the open-container requirement

Result:
- the player still gets decorative freedom around the quiver body
- but the system naturally preserves a usable open end

Quiver equip law:
- quiver is never a hand-equipped item
- quiver always occupies a back slot

Quiver builder law:
- the ranged physical path will eventually split into:
  - `bow`
  - `quiver`
- these are separate authored entities in code
- but they are saved/equipped as one ranged-physical weapon package
- the quiver workspace size target is:
  - `70 x 30 x 30`

Quiver side law:
- quiver stow position is opposite the bow holding hand by default
- if the bow holding hand is left, the quiver sits on the right back slot
- if the bow holding hand is right, the quiver sits on the left back slot

## 5. Arrow Visual / Runtime Anchor Law

Future ranged physical runtime must include an `arrow` asset for visual/readability purposes.

This arrow asset is rendered at the quiver open end using:
- the crafted quiver open-border measurement
- an offset anchor point

Goal:
- guarantee that a visible amount of arrow shaft and fletching can always be seen
- avoid cases where the entire arrow disappears visually because of quiver shape variation

This arrow/quiver relation also provides a clean future grab/use point for bow animations:
- the visible shaft + fletching region can act as the animation grab target during draw/reload behavior

Bow-string relation note:
- arrow runtime behavior should align with the explicit bow string anchor system above
- the string endpoints are authored by anchor markers
- the string body is generated in post
- the arrow draw/use logic can then reference stable bow-string endpoint truth instead of guessing from noisy crafted geometry
- the firing hand should grab the runtime pull / nock point on the generated string
- projectile release should happen when the generated string returns through its release path back toward rest

## 6. Shield System Parallel Law

Shield work should be treated as parallel to this ranged physical foundation where the mannequin logic overlaps.

Shield crafting law:
- shield should use a custom crafter with mannequin restriction areas
- shield includes a pre-established internal handle from the start
- the player builds outward from that handle

Reason:
- the handle becomes the stable animation/manipulation anchor
- shield silhouette can vary freely around that stable core
- character-side behavior becomes more predictable

Additional restriction goal:
- the mannequin restriction shape should reduce player-facing clipping
- it should also prevent abusive inward-pointing geometry aimed back into the character
- this gives decorative freedom without allowing obviously bad inward profiles

So the shield system is not identical to quiver, but it shares the same family of:
- restricted-volume authoring
- stable internal anchor
- outward-only shaping logic

## 7. System Implications

This changes the meaning of the old "bow bucket" in the audit ledger.

That future bucket is really:
- `Ranged Physical Weapon foundation`
- plus the parallel `Shield mannequin-anchor foundation`

So future bow/resolver work must not be tackled as if it is only:
- limb inference
- string legality
- geometry heuristics

It also depends on:
- correct umbrella naming
- correct component separation
- correct crafter separation
- correct explicit string-anchor authored truth for bows
- correct runtime four-point string mapping and release behavior
- correct slot/stow rules
- correct shell/mannequin authoring model

## 8. Implementation Order Guidance

When this bucket becomes active, preferred order is:

1. Lock naming and context IDs to the new terminology:
   - `Ranged Physical Weapon`
   - `Ranged Magical Weapon`
   - explicit `bow` and `quiver` component terminology

2. Define the component split at the data/crafter level:
   - bow crafted separately
   - quiver crafted separately

3. Add the bow string-anchor creator-point system as explicit authored bow truth.

4. Define the runtime four-point bow-string mapping and normalized draw-distance law.

5. Build the quiver shell/mannequin crafter foundation.

6. Build the shield restricted-volume + fixed-handle crafter foundation in parallel where shared logic is reusable.

7. Add back-slot and side-routing laws for:
   - bow stow
   - quiver back-slot occupancy

8. Add arrow visual anchor/runtime placement for quiver.

9. Only after the above is stable, revisit deeper ranged physical resolver logic and reduce bow heuristic inference to match authored truth.

## 9. Audit / Planning Effect

From this point forward:
- do not treat the old bow bucket as a self-contained resolver-only cleanup
- treat it as a bigger foundation bucket with bow + quiver + shield mannequin overlap
- any future ranged/shield implementation should be checked against this document first

This is the permanent target shape unless a later explicit design decision replaces it.

## 10. Current Live Progress Snapshot

Current live progress now in code:
- ranged physical has separate live `bow` / `quiver` builder-component identity
- ranged `bow` now has explicit authored string-anchor markers `A1/A2` through `F1/F2`
- those markers now live as dedicated WIP marker-position metadata, not fake material mass cells
- forge 2D and 3D builder views now render those markers directly
- forge 3D builder preview now shows:
  - generated bow string rest path
  - generated max-draw string path
  - generated max-draw pull point
- first-pass max draw uses the live forge rule:
  - `bow_string_draw_distance_meters`

Still not live yet:
- packaged `bow + quiver` save/equip behavior
- quiver shell/mannequin crafter
- shield restricted-volume / fixed-handle crafter
- four-point hand-connected runtime string solve
- projectile release / hand-linked draw animation logic
