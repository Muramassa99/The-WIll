Yes — this is enough to consolidate into an **annexed add-on text** to sit under the existing CODEX-forwarding combat block.

I’ll keep this as a **clean addendum** focused on what the **combat editor is visually and functionally**, while also tying in the extra system truths you just clarified.

---

# Annex — Runtime Combat Editor Visual and System Addendum

## To append under the existing melee combat / skill crafting CODEX block

This annex expands the existing melee combat and skill-crafting specification by defining what the **runtime combat editor** is visually, what data it is driven by, and what system layers feed its behavior.

The combat editor is not a generic animation editor. It is a **runtime in-game Bézier-curve-driven combat authoring workspace** built around weapon-owned skill drafts, point-based motion segmentation, and slot-law-based combat behavior.

---

## 1. Visual identity of the combat editor

The combat editor must visually present a **3D runtime preview space** in which the player can see:

* the player model / preview character
* the currently selected weapon
* the currently selected weapon-owned skill
* authored destination points
* the Bézier spline formed between those points
* editable curvature handles / vector adjustments
* the active plane / relevant motion-editing guides
* local point context through onion skin visibility
* the trajectory line as the readable motion path
* motion-state coloring on the trajectory path

The editor is driven by **placed points**, but those points do not create only straight segment motion. The visible path between them is shaped by a **Bézier curve system**, so the player can mold the trajectory while still respecting the combat system’s deliberate hit-segmentation laws.

---

## 2. Core relationship between points and Bézier curves

The authored destination points remain the **hard gameplay structure**.

They define:

* segment order
* startup / non-hit entry positioning
* hit economy
* deliberate slowdown/reset zones
* segment boundaries
* intentional strike count structure

The Bézier system is the **between-point shaping layer**.

It defines:

* trajectory curvature
* elegance of the path
* flourish of the swing
* how motion visually travels between committed points
* how different authored swings can feel heavy, nimble, broad, tight, or sweeping

In short:

* **points are the law**
* **Bézier handles are the freedom**

The resulting curve is not cosmetic only. It is runtime mathematical motion data that can be sampled to drive:

* weapon motion
* trajectory visualization
* speed-state coloring
* sound timing support
* particle/effect timing support
* later body IK and motion-follow behavior

---

## 3. Runtime editability and persistence

The Bézier curve system must be:

* visible at runtime
* editable at runtime
* saved at runtime
* restorable later
* stored in the owning weapon’s skill draft data

This means the motion is not stored as a baked animation file.
It is stored as **modular mathematical curve data** consisting of:

* point positions
* control-handle vectors
* segment ordering
* segment timing / motion-profile data
* slowdown/reset information
* any additional per-point/per-segment runtime metadata needed by the motion solver

The result is that a skill draft can be reopened later and the player continues editing the same authored curve-driven motion package.

---

## 4. Relationship to the skill-slot combat law system

The combat editor does not invent the combat role of the skill.
The skill slot already defines the **functional box**.

Examples:

* block/parry type slot
* displacement / dash type slot
* crowd-control type slot
* damage slot
* buff / support slot
* iframe type slot
* other defined combat-role slots

The editor’s job is to let the player create the **motion expression** of the skill within that slot’s law.

So the editor must operate with awareness of:

* the selected weapon
* the selected skill
* the selected slot law
* the slot’s inherited behavior package
* any allowed/additive slot-based effects
* any weapon/material-driven modifier effects

The full combat system therefore emerges from:

1. the **slot law**
2. the **weapon material/build data**
3. the **authored motion path**
4. the **runtime collision and speed-state logic**

---

## 5. Relationship to Stage 1 and Stage 2 weapon creation

The combat editor depends primarily on **Stage 1 weapon building data**.

Stage 1 is where the real material and structural data exists:

* materials
* effects
* multi-hit modifiers if present
* center of mass
* mass distribution
* grip zones
* shape-derived weapon class information
* other real combat-driving attributes

Stage 2 refinement is visual alteration, but the combat-driving truth comes from Stage 1.

This means the combat editor must pull weapon behavior inputs from the Stage 1 data output.

Examples of values coming from Stage 1:

* total hit allowance modifiers
* elemental/material effects such as fire/ice/etc.
* center of mass
* mass weighting
* grip relation
* handling implications
* balance / imbalance behavior

These values then influence:

* how many hit phases the authored skill may support
* what material/effect visuals are used on valid hits
* how motion acceleration/deceleration feels
* how curvature and redirection should behave for a weighted vs nimble weapon

---

## 6. Hit count source and relationship to materials and slots

The amount of hits available to a skill is not invented by the editor visually.

The final hit count comes from the already existing gameplay calculation path, which ultimately resolves through the skill slot output while incorporating applicable Stage 1 material/build modifiers.

So, conceptually:

* material/build modifiers from Stage 1 may enhance hit count if such modifiers exist
* the skill slot is where the final resolved hit amount appears for the skill
* the editor then authors motion around that resolved hit economy

This means the editor should treat hit count as a **resolved gameplay value**, not as something purely visual.

The authored point structure then maps that hit economy into deliberate strike segments.

---

## 7. Deliberate hit segmentation rule used by the editor

The current settled melee rule is:

* transition into the first authored point is startup / positioning only
* it does not count as a hit
* each subsequent point-to-point authored segment is one potential hit phase
* near each destination point, motion is forced through a controlled slowdown/reset band
* after that slowdown band, motion re-accelerates into the next segment

This gives the editor a clear rule:

* hit economy is tied to the number of authored strike segments
* trajectory style remains editable via Bézier shaping
* repeated hits are deliberate, not guessed from arbitrary continuous motion

This is the current simplification chosen in order to avoid fragile automatic continuous-motion inference.

---

## 8. Speed-state and visual trajectory feedback

The visible trajectory spline must not be only a geometric guide.

It is also a **combat-state guide**.

The trajectory should be color-coded by normalized motion speed state, with the currently intended model being:

* **red** = at or above valid armed strike threshold
* **green** = below low-speed threshold / non-armed / recovery / reset
* gradient between green and red = buildup / decay / intermediate motion state

This visual feedback helps the player understand:

* where the path is a valid strike phase
* where motion is in reset/recovery
* where acceleration is building
* where the intended hit zones exist

Because the game’s melee logic is motion-driven, this color-coded spline acts as a live readable combat-state preview.

---

## 9. Weapon feel and mass-distribution influence on motion

The combat editor should not treat all weapons as if they move identically.

Weapon center of mass and grip-point triangulation should influence how the motion behaves.

This can affect:

* acceleration profile
* deceleration profile
* redirection responsiveness
* how sharply the weapon can visually or mechanically reshape its path
* how “weighty” or “nimble” a weapon feels

So:

* a heavy off-balance weapon should visually feel more committed and weighty
* a balanced/nimble weapon should feel quicker and more responsive

This means the Bézier path is still editable, but the resulting motion solver and motion profile may be influenced by weapon physical data rather than treating every curve as equally easy to execute.

That preserves the authored path while still letting weapon build identity matter.

---

## 10. Elemental/material effects during armed motion and on hit

Material effects such as:

* fire
* ice
* other elemental/effect categories

come from Stage 1 material data and remain part of the combat result.

The editor and runtime motion preview should be compatible with the idea that:

* while the motion is in valid red / armed state, corresponding material-linked motion effects may be enabled
* on valid collision, corresponding material-based hit effects and particle effects may be generated
* skill-slot modifiers, if applicable, may further modify those effect results

So effects are effectively fed from:

1. weapon material/build data
2. skill-slot law / slot effect modifiers
3. valid armed strike state
4. actual collision

This is a multi-source output model rather than a single-source one.

---

## 11. Sound-design implications of the editor/runtime path

The authored curve and sampled motion path also provide the basis for sound logic.

The current conceptual direction supports:

* weapon whoosh / air-cut sound based on motion speed/pathing
* impact sound based on weapon material and collision target
* ground/environment contact sound based on material
* character vocal effort layered separately if desired

So the motion path is useful not only for animation and combat, but also for:

* whoosh intensity
* timing of swing audio
* collision audio variation
* material identity

This should be kept in mind as a future-compatible output of the authored path.

---

## 12. Ground vs air usage context

Some skills may later have different behavior depending on whether the attack is used:

* on ground
* in air

The exact effect mapping is not being finalized here, but context exists that some skill outcomes may differ between ground and air use.

Examples already discussed in broader project context include cases where one CC-related result may apply on ground and a different one in air.

This annex is not locking those exact effect mappings for implementation right now.
It is only preserving the important idea that:

* air/ground context may alter resulting combat effects
* the editor and runtime system should remain compatible with future contextual branches

This note is for context only unless a later implementation spec formalizes the exact mapping.

---

## 13. What the combat editor is, in one clean sentence

The combat editor is a runtime 3D Bézier-curve-driven weapon-skill authoring workspace where authored destination points define deliberate melee strike segments and Bézier handle vectors shape the trajectory between them, while runtime combat behavior is resolved from slot law, weapon build/material data, motion speed state, and later collision/effect output.

---

## 14. Practical summary to preserve for implementation

To summarize the intended editor behavior and system meaning:

* the editor is opened through weapon selection and skill selection
* each weapon owns its own skill drafts
* the editor works in runtime, not offline only
* authored points define strike segmentation and hit economy
* the visible trajectory between points is shaped by Bézier curves
* the Bézier curve is mathematically stored as modular runtime motion data
* the first transition into the first point is startup only
* each later segment is a potential hit phase
* destination points enforce slowdown/reset structure
* the spline is color-coded by speed/armed state
* Stage 1 crafting data feeds material, hit-count modifiers, elemental effects, mass distribution, center of mass, and handling identity
* skill slots provide the law and final combat-role box
* the resulting motion path becomes the source for weapon motion and later body-follow/IK response

---

If you want, next I can turn this annex into a **tight CODEX annex block** written in the same stricter directive style as the previous implementation brief.
