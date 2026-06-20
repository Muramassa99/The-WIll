# Melee Skill Crafter - Ranged Wave Attack Concept

## Status

- Future design note.
- Not an immediate implementation task.
- This should be revisited after Forge V2 can produce weapon material data reliably and after the melee Skill Crafter output format is stable enough to carry attack metadata.
- Expanded 2026-05-30 from the idea that melee-authored swing animations can generate ranged wave/projectile output when the selected skill slot and weapon material stats allow it.

## Core Idea

Melee weapons should be able to produce ranged slash-style attacks through the Skill Crafter.

The player still authors melee motion normally: swings, combinations, timing, motion nodes, acceleration, weapon tip path, and stance flow. Certain skill slots or skill configurations can then generate an outgoing wave attack from that melee motion.

This is not meant to replace melee animation with a spell cast. The melee animation remains the authored truth. The ranged attack is generated from that authored truth.

In practice, this behaves like an "air blade" or shock-wave slash:

- The player edits a swing animation in the melee Skill Crafter.
- The weapon tip trajectory between motion nodes becomes the source path for the wave.
- The generated wave inherits the swing path shape, spawn position, and orientation from the weapon motion.
- The wave propagates outward from the player along the swing direction.
- The wave travel speed is derived from the swing transition speed.
- Slow swing transition means slower wave propagation.
- Fast swing transition means faster wave propagation.

This gives melee builds a controlled ranged option without turning them into ranged or magic archetypes.

The material composition of the weapon can determine whether the effective attack reaches beyond the physical weapon model, and how far beyond it can go. A plain weapon can still create a reasonable non-magical air blade when the skill slot supports it. Special material then modifies or extends that base behavior.

## Authoring Behavior In Practice

The Skill Crafter should let the player author the melee swing first.

The player might create a single slash, a two-swing chain, or a longer swing combination. Each relevant node-to-node swing transition can then become a candidate source for a generated wave attack, depending on the selected skill slot and later balance rules.

For a wave-enabled swing:

- The weapon tip trajectory between motion nodes is sampled.
- That sampled path becomes the wave's generation shape.
- The path also gives the initial placement and facing angle for the wave.
- The wave travels outward from the player rather than remaining attached to the weapon.
- The emitted wave keeps the visual identity of the authored swing. A wide crescent swing creates a wide crescent-like wave. A tighter cut creates a tighter projected slash.

The wave should travel at a constant propagation speed for that emitted attack, but that constant should be derived from the authored swing transition:

- Slow transition produces a slower outgoing blade.
- Fast transition produces a faster outgoing blade.
- A combo can therefore produce different wave speeds per swing if the individual swing transitions have different timing.

This allows melee animation timing to matter beyond local hitboxes. The swing's authored speed becomes part of the ranged output instead of the projectile using an unrelated fixed speed.

## Why This Exists

This creates better consistency between melee, ranged physical, and ranged magic gameplay.

Some minigames, encounters, puzzles, or combat layouts may need all archetypes to interact with targets beyond direct melee reach. A melee-only build should not become unusable in those situations.

The goal is not to erase archetype identity. Melee still authors the attack through body and weapon motion. The ranged effect is a derived extension of the melee swing rather than a separately aimed projectile spell.

## Range Source

The wave range should come from multiple layers:

- Base skill slot coefficient.
- Weapon range coefficient.
- Material modifiers from the weapon composition.
- Optional special material bonuses.

The skill slot should provide a reasonable default range even if the weapon has no magical or special material.

Material can then improve or modify that range:

- Range-enhancing material can increase wave travel distance.
- Magic-affinity material can change the wave visuals and status effects.
- Piercing material can allow the wave to continue after hitting targets.
- Multi-hit material can allow one swing to emit more than one wave.

The intended rule is:

- Skill slot law makes the attack type possible and gives the non-magical baseline.
- Weapon material composition can make the wave longer, stronger, stranger, or more specialized.
- The weapon model's physical reach remains relevant for melee contact, but the generated wave range can extend beyond the model when the skill and material stats say it can.

The exact skill slot or slot family that permits this is still to be determined.

## Material-Driven Visual And Status Behavior

If the weapon has no relevant elemental or magical material, the ranged attack appears as a simple air blade:

- Clean slash wave.
- Neutral visual treatment.
- No extra elemental status.

If the weapon contains a magical or status-bearing material, the same wave behavior can be reskinned and modified by that material.

Examples:

- Fire material:
  - Wave becomes a fire crescent.
  - Applies burn or fire damage over time on hit.
- Poison material:
  - Wave uses poison visual treatment.
  - Applies poison status or poison damage over time on hit.
- Lightning material:
  - Wave uses lightning visual treatment.
  - Applies shock, stun, chain, or other lightning-related effect depending on later balance.
- Ice material:
  - Wave uses ice visual treatment.
  - Applies slow, chill, freeze buildup, or other ice-related effect depending on later balance.

The important rule is that the underlying authored wave shape remains based on the melee swing. Material changes what the wave is made of, how it looks, and what it does on contact.

If no magical material is present, the result should still be a valid air-blade slash:

- It has range.
- It has the authored swing shape.
- It uses neutral/non-elemental presentation.
- It does not apply fire, poison, lightning, ice, or similar status payloads.

If magical or status-bearing material is present, the same authored wave gains the relevant material identity without changing the fact that the melee swing generated it.

## Projectile Behavior

Even though the attack comes from a melee swing, the outgoing wave should be treated as a projectile-like combat object after generation.

It needs:

- Spawn transform derived from the weapon tip trajectory.
- Shape derived from swing path.
- Travel direction derived from swing orientation.
- Travel speed derived from swing speed.
- Max range derived from skill and material stats.
- Hit behavior derived from weapon material modifiers.
- Status application derived from material composition.

This should reuse future shared projectile logic where possible.

The same broad projectile rules should later support:

- Melee wave attacks.
- Ranged physical projectiles.
- Ranged magic projectiles.
- Multi-shot / fan-out attack patterns.
- Piercing and target pass-through behavior.

## Piercing And Multi-Hit Material Rules

Some materials may modify whether the wave stops on first contact.

Piercing behavior:

- Without piercing, the wave can stop or dissipate on first valid target hit.
- With piercing, the wave continues through targets until it reaches max range or another termination rule.
- Piercing should be material-driven and should use the same shared logic for melee waves, ranged physical projectiles, and ranged magic projectiles.

Multi-hit / fan-out behavior:

- Some materials may cause one authored swing to emit more than one wave.
- Possible outcomes:
  - Base wave only.
  - Base wave plus one additional wave.
  - Base wave plus two additional waves.
  - Base wave plus three or four additional waves, depending on later balance.
- The extra waves should use predefined propagation patterns rather than fully freeform chaos.
- Fan-out patterns should be authored or selected by us so they stay readable and balanced.

This makes material choice matter beyond simple damage number changes.

This should also become shared projectile behavior rather than a melee-only exception. If a material creates piercing or multi-hit behavior here, the same concept should be reusable by:

- melee wave projectiles,
- ranged physical projectiles,
- ranged magic projectiles.

The melee version is special only in how the projectile is generated: from authored weapon-tip motion rather than from a bow, staff, or spell cast origin.

## Data Direction

The weapon needs to carry material-derived stat data that the Skill Crafter and runtime combat can read.

Likely `.tres` / resource-facing values:

- Bonus range modifier.
- Elemental / magical affinity.
- Status effect payload.
- Piercing modifier.
- Multi-hit modifier.
- Projectile count or fan-out level.
- Projectile visual profile.
- Projectile hit behavior profile.

These values should not be hand-authored per weapon in isolation. They should come from Forge V2 weapon composition, material volume percentages, and material definitions.

The Skill Crafter should consume the weapon's stats and expose valid options based on them.

Potential resource/data flow:

- Material definitions expose stat modifiers such as bonus range, elemental affinity, piercing, fan-out count, and status payload.
- Forge V2 records which materials compose the weapon and in what meaningful proportion.
- The weapon's generated or saved `.tres` data carries the resolved combat-facing material stats.
- The melee Skill Crafter reads those stats when deciding which ranged-wave options are available.
- Runtime combat reads the same resolved stats when spawning and resolving the outgoing wave.

The important boundary is that the Skill Crafter should not invent material behavior on its own. It should read material truth from the weapon and use that truth to shape legal authoring options and runtime output.

## Skill Crafter Integration

The melee Skill Crafter already authors motion. This feature should extend that motion rather than replacing it.

Potential integration path:

- Skill slot determines whether a wave attack is allowed.
- Motion nodes define the swing path.
- Weapon tip path between relevant motion nodes defines the wave source shape.
- Transition timing defines wave speed.
- Skill slot coefficient defines baseline range.
- Weapon material stats modify range, visual profile, hit behavior, and status payload.

Open decision:

- Determine which skill slots can generate wave attacks.
- Determine whether all melee skill slots can opt into wave generation, or only specific slots can.
- Determine whether wave generation is automatic from material/skill combination or manually enabled per authored attack.

## Design Constraints

- Melee should remain melee-authored.
- The wave should feel like a projected extension of the swing, not a disconnected spell button.
- Base non-magical air blade must exist so melee is not locked out of ranged interactions.
- Magical materials should enhance and transform the effect, not be required for the whole system to work.
- The generated wave must be readable in gameplay.
- The system should reuse projectile logic across melee, ranged physical, and ranged magic wherever possible.
- Material composition should influence behavior through clear stat/resource data, not one-off special cases.

## Not Now

- Do not implement this during current Forge V2 spline/authoring work.
- Do not rebalance material economy around this yet.
- Do not add status effects only for this feature in isolation.
- Do not force Forge V2 material data into final form only for this note.
- Do not solve ranged physical or ranged magic Skill Crafter behavior here.

## Future Pickup

When this becomes active, first inspect:

- Current melee Skill Crafter motion node data.
- How weapon tip trajectory is represented between motion nodes.
- Runtime hitbox generation and trajectory volume code.
- Weapon material stat export from Forge V2.
- Existing projectile or attack volume abstractions.

First useful prototype:

- Pick one melee swing.
- Generate one neutral air blade from the weapon tip path.
- Give it a simple fixed range and fixed speed.
- Then replace fixed range/speed with skill-slot coefficient and swing-speed-derived propagation.
- Only after that, add material-driven visuals, status, piercing, and fan-out.
