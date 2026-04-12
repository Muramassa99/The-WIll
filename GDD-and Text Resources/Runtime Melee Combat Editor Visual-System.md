Below is the **tight CODEX annex block** for the **runtime combat editor visual/system addendum**, using **Godot terminology** and preserving the workflow:

**weapon selection -> skill slot selector / skill selection -> editor workflow**

---

# CODEX ANNEX BLOCK

## The Will — Runtime Melee Combat Editor Visual/System Addendum

### Godot 4.6.1

### Append under the existing melee combat / skill crafting implementation brief

Build the runtime melee combat editor as a **3D in-game authoring scene** for weapon-owned skill drafts.

This annex defines:

* the editor workflow
* the visual structure of the editor
* the Bézier-curve motion layer
* how weapon data and skill-slot data feed the editor
* how authored curve data is stored and reused

Do not replace the existing melee combat block.
Treat this as an add-on specification.

---

# 1. Editor entry workflow

The runtime authoring workflow must be:

1. **weapon selection**
2. **skill slot / skill selection**
3. **editor workflow**

The editor must not open without:

* one selected weapon
* one selected skill draft target

The editor target is always:

* one weapon-owned skill draft
* belonging to one selected skill slot / selected skill entry

Use the terminology:

* **weapon selection**
* **skill slot selector**
* **skill selection**
* **editor**

If the selected skill draft does not exist yet, initialize it from the appropriate default baseline for that weapon/slot context.

---

# 2. Editor scene purpose

The editor is not a generic animation editor.

It is a **runtime 3D combat authoring scene** that lets the player edit:

* authored destination points
* Bézier trajectory shape between those points
* point-driven strike segmentation
* preview motion on the preview actor with the selected weapon

The editor must work on runtime-owned data and persist the resulting skill draft back into the owning weapon.

---

# 3. Visual editor requirements

The editor scene must contain and display:

* a **preview actor**
* the **selected weapon**
* the **selected skill context**
* authored **destination points**
* the visible **Bézier trajectory**
* editable **Bezier control handles**
* the current **active point**
* local **onion skin point context**
* the current **motion path / trajectory line**
* the current **speed-state color feedback**
* the current **editing plane / plane guide** if used by the authoring flow
* UI showing current weapon and current skill slot / skill

The editor must let the player see and manipulate curve shape directly in runtime.

---

# 4. Godot curve system requirement

Use Godot’s **Curve3D** / **Path3D** style curve workflow or an equivalent runtime curve system built around the same concept.

The curve system must support:

* runtime creation of curve points
* runtime editing of point positions
* runtime editing of curve handles / tangents / control vectors
* runtime sampling of the curve
* runtime saving and restoring of the curve data

The curve is not just for display.
It must be treated as gameplay-relevant motion data.

---

# 5. Point law vs curve freedom

Preserve the following design law:

* **destination points are the hard gameplay structure**
* **Bezier handles / control vectors are the freedom layer**

Destination points define:

* segment order
* strike segmentation
* slowdown/reset boundaries
* hit economy structure

Bezier handle editing defines:

* trajectory style
* curvature
* flourish
* visual path shaping between destination points

Do not let free curve editing destroy the meaning of the destination points.

---

# 6. Required saved motion data

The resulting motion path must be saved as modular runtime data, not as a pre-baked animation clip.

At minimum, the saved skill draft data must support:

* destination point positions
* curve handle/control-vector data per point as needed
* point order
* slowdown/reset metadata near destination points
* segment timing / speed-profile metadata as needed
* any additional motion metadata needed for playback and runtime use

The authored curve data must be restorable later so the same weapon-owned skill draft can be reopened and continued.

---

# 7. Runtime curve usage

The authored curve must be sampled at runtime and reused for:

* editor trajectory display
* editor playback
* speed-state evaluation along the path
* weapon motion driving
* future body-follow / IK driving
* future sound/effect timing support

Do not treat the curve as editor-only decoration.

---

# 8. Skill-slot selector and combat-role law

The editor must always be aware of:

* the selected skill slot
* the selected skill entry
* the slot law / combat-role box

The motion being authored is the **expression** of the selected slot, not a redefinition of the slot’s role.

Examples of slot law context may include:

* block/parry slot
* displacement slot
* crowd-control slot
* damage slot
* buff/support slot
* iframe slot
* other defined combat-role slots

Do not make the editor role-agnostic.
It must operate in the selected skill-slot context.

---

# 9. Relationship to Stage 1 weapon crafting data

The editor must pull gameplay-relevant input from the existing **Stage 1 weapon building system**.

This includes any already-calculated or already-available data such as:

* material data
* effect data
* hit-count modifiers if present
* center of mass
* mass distribution
* grip-related data
* handling-related values
* weapon class output
* any other combat-driving attributes already produced by Stage 1

Treat Stage 1 as the source of real combat-driving material/build data.

Stage 2 refinement is not the source of core combat truth for this editor.

---

# 10. Hit count source rule

The editor does not invent hit count visually.

The final usable hit amount comes from the resolved gameplay path:

* skill-slot logic
* plus applicable weapon/material/build modifiers from Stage 1

The editor then maps that resolved hit economy into authored strike segments.

Use the resolved hit amount as the authoritative limit for how many meaningful strike segments can actually count as damaging phases.

---

# 11. Segment-based strike rule

Preserve the currently settled melee rule:

* current runtime state -> first authored point = startup / entry positioning only
* this startup motion does not count as a hit
* each later point-to-point segment is one potential strike phase
* near each destination point, motion is intentionally forced through a controlled slowdown/reset band
* after the slowdown band, motion re-accelerates into the next segment

This is the current deliberate simplification for melee hit logic.

Do not attempt to restore the older free continuous-motion hit inference model in this implementation.

---

# 12. Curve shape vs strike segmentation

The Bézier curve may make the motion appear smooth and continuous, but the strike segmentation rule still follows the authored destination-point structure.

This means:

* the curve can look elegant
* the path can be highly shaped
* the between-point motion can be visually expressive

but:

* hit economy remains point/segment driven
* slowdown/reset remains destination-point driven
* repeated hits remain deliberate authored segments

That is required.

---

# 13. Speed-state trajectory coloring

The visible trajectory path must be color-coded by motion speed state.

At minimum, support:

* **red** = at or above valid armed strike threshold
* **green** = clearly below low-speed threshold / reset / non-armed phase
* gradient between green and red = buildup / decay / intermediate motion state

This color-coded path is not cosmetic only.
It is a live combat-state preview for the authored motion.

Update the path coloring live when:

* editing points
* editing curve handles
* changing path shape
* changing timing/speed parameters
* navigating points
* previewing playback

---

# 14. Weapon feel and mass distribution

The editor/runtime motion evaluation must remain compatible with the idea that weapon feel is influenced by:

* center of mass
* mass distribution
* grip relation / grip triangulation
* overall handling balance

This means the resulting motion can later express:

* heavier, more committed weighted motion
* lighter, more nimble balanced motion

Do not lock all weapons to identical curve execution feel if the existing weapon system already provides meaningful handling-related data.

---

# 15. Material/effect integration

The editor and runtime motion path must remain compatible with material/effect output coming from Stage 1 data, including cases such as:

* fire
* ice
* other elemental/effect families
* other applicable weapon material outputs

The intended compatibility is:

* when the motion enters valid armed state, material/effect-capable motion visuals can be enabled if appropriate
* on valid collision, material-driven hit visuals / particles can be produced
* skill-slot modifiers may further affect those results

The exact final VFX implementation is separate, but the editor/runtime motion system must not block this integration.

---

# 16. Air vs ground compatibility note

The combat editor/runtime path should remain compatible with future contextual branching for:

* ground combat use
* air combat use

Exact ground/air effect mapping is not finalized in this annex.
Do not hardcode speculative behavior here.

Only preserve compatibility with the idea that:

* the same authored skill may later have contextual effect differences based on ground vs air usage

This note is contextual, not a finalized implementation rule.

---

# 17. Sound-system compatibility note

The authored curve and sampled runtime motion path should remain compatible with later sound logic such as:

* weapon air/whoosh sound based on motion speed/pathing
* material-based impact sound on collision
* ground/environment impact sound
* optional actor vocal effort sounds

Do not build sound now unless already in scope, but do not structure the curve system in a way that prevents motion-driven sound evaluation later.

---

# 18. Required Godot-side architecture additions

Add or preserve architecture supporting the following:

## Browser / selection

* weapon selection UI/panel
* skill slot selector / skill selection UI/panel

## Editor scene

* runtime 3D editor root scene
* preview actor
* preview weapon
* curve/point editing tools
* runtime path visualization

## Curve data

* runtime `Curve3D`-style data or equivalent
* point data
* control handle / tangent / vector data
* persistent storage in weapon-owned draft data

## Runtime playback

* curve sampling
* trajectory preview
* strike-segment playback
* future reuse for presentation / skill-view mode

## Future IK bridge

* expose curve-sampled motion data in a way that can later drive body-follow / IK logic

---

# 19. Acceptance criteria for this annex

This annex is satisfied when all of the following are true:

1. workflow is:

   * weapon selection
   * skill slot selector / skill selection
   * editor workflow

2. editor opens on one exact weapon-owned skill draft

3. the editor displays a visible runtime-editable Bézier trajectory

4. destination points are visible and editable

5. Bézier control handles / vector adjustments are visible and editable at runtime

6. curve data is saved and restored with the weapon-owned skill draft

7. curve sampling is usable for motion preview/playback

8. the trajectory path is color-coded by speed/armed state

9. destination-point strike segmentation remains intact despite curved visual motion

10. the system remains compatible with Stage 1 weapon material/build data

11. the system remains compatible with future body IK/body-follow usage

---

# 20. Final instruction to CODEX

Build the runtime melee combat editor as a weapon-owned, skill-slot-aware, 3D Bézier-curve-based motion authoring scene. Use destination points as the hard strike-segmentation structure and use Bezier control handles as the between-point trajectory shaping layer. Keep the workflow as weapon selection -> skill slot selector / skill selection -> editor workflow. Save curve data as modular runtime motion data in the owning weapon’s skill draft. Sample the curve at runtime for trajectory display, speed-state coloring, playback, and future body-follow / IK integration. Do not turn the system into a generic clip editor or remove the deliberate destination-point slowdown/reset law.
