# Future Fishing And Cooldown-Reset Trinket TODO

Recorded: 2026-09-01 18:53 Europe/Bucharest

Status: **months-later future design only**.  
This file preserves two gameplay concepts. It does not authorize implementation,
dependency work, balance tuning, UI construction, or changes to the current Skill
Crafter / Forge V2 slice.

## 1. Fishing Minigame And Mouse-Manipulated Fishing Rod

### Core intent

Fishing is a physical mouse-manipulation activity rather than a single interact
button or timing bar. Mouse movement controls the fishing-rod Tip, mouse velocity
and direction control the cast, and the player alternates line braking, rod pulls,
line release, and reeling according to the fish's behavior.

The fishing rod also functions as an unadvertised environmental interaction tool.

### Equip and availability

- The fishing-rod equip method is undecided. It may use ordinary weapon-style equip,
  a dedicated keybind, or another later-selected route.
- The rod should be available whenever equipped/activated rather than restricted to
  a recognized fishing location.
- It may be cast with or without a body of water.
- Water detection may affect catch availability later, but it must not prevent the
  basic rod, line, cast, and hook interactions from functioning.

### Input authority

- Mouse movement controls the fishing-rod Tip direction.
- Pulling the mouse backward/downward toward the real-world user pulls the rod Tip
  back and charges/prepares the cast.
- A rapid mouse movement in the opposite direction accelerates the rod into the
  cast. The direction of that flick determines throw direction.
- `LMB held` engages the **line brake**: line extension is prevented while the
  brake is held.
- `LMB released` releases the brake. During the prepared cast, releasing LMB launches
  the lead/weight using the measured mouse flick velocity and direction.
- `RMB held` reels the line inward.

Use **brake** for the input that stops line extension. Use **line break** only for a
future actual snapped/broken-line failure state, should one be added.

### Casting behavior

1. Hold LMB to prevent line extension while preparing the rod.
2. Pull the mouse backward/downward to pull the Tip back and charge the swing.
3. Flick the mouse forward in the desired cast direction.
4. Release LMB to release the line and launch the lead/weight.
5. Cast distance derives from mouse velocity:
   - slower flick = shorter cast;
   - faster flick = longer cast;
   - initial maximum-distance cap = `50 meters`.
6. Flick direction influences the cast's world direction.

The exact velocity curve, minimum flick threshold, sensitivity normalization,
trajectory/ballistics, and whether the cast uses a physically simulated or authored
rod bend remain undecided.

### Bite, hook, and catch loop

When a fish catches/bites:

1. Hold LMB to engage the line brake.
2. Yank the mouse/rod backward to set the hook.
3. Continue manipulating the rod Tip with mouse movement:
   - pushing the mouse forward points the rod forward;
   - pulling it backward pulls the rod back.
4. A typical successful recovery cycle is:
   - hold LMB and pull the mouse toward the player;
   - move the mouse forward slowly and steadily;
   - hold RMB during the controlled forward motion to reel in line;
   - re-engage/maintain the LMB brake and pull back again;
   - repeat according to fish behavior until the catch state is reached.

### Fish-response rules

- If the fish pulls left, position/pull the rod toward the right; if it pulls right,
  counter toward the left.
- If an energetic fish splashes or surges, the player may:
  - hold the brake and resist in order to tire it;
  - release the brake and allow it to gain line/space when resisting would be unsafe.
- The intended gameplay is situational use of hold, drag, release, reel, and rod
  direction—not one fixed rhythm.
- A later implementation will need line-tension, fish-energy/stamina, hook security,
  distance, escape, catch, and possible line-failure rules. None of their numeric
  values are decided here.

### Rewards and broader use

- Fish may provide crafting material, including fish scales.
- Fish may be used as food.
- Cooking fish may provide food buffs.

### Hidden environmental utility

The same rod/line/hook mechanic should support environmental interactions:

- cast toward and hook otherwise inaccessible objects;
- pull hooked objects toward the player;
- trigger remote levers;
- trigger traps from a distance;
- support puzzles and hidden interactions built around those capabilities.

Only the ordinary fishing capability should be explained directly to players. The
environmental/puzzle utility is intended to be discovered through experimentation.

### Explicitly undecided

- equip/unequip route and whether the rod occupies a weapon/item slot;
- exact mouse sensitivity and velocity sampling;
- camera relationship and input capture;
- line physics, collision, tension limits, snapping, and recovery;
- rod material/stat influence;
- fish AI, species, rarity, spawn, water detection, loot, and cooking balance;
- multiplayer/network authority;
- animation, audio, UI feedback, accessibility alternatives, and key rebinding;
- interaction rules for non-water casting and puzzle targets.

## 2. Three-Tier Cooldown-Reset Trinket

### Core intent

The Trinket is a deliberate emergency and burst-window tool. Every tier performs
the same action; tier only changes the Trinket's own reuse cooldown.

It is intended to remove the excuse for refusing a time-sensitive mechanic because
the player is low on HP or their required crowd-control skill is unavailable: use
the Trinket, recover to the safety threshold, regain skill cooldowns, and perform
the mechanic.

### Tiers

| Tier | Trinket reuse cooldown |
|---|---:|
| Tier 1 | 5 minutes / 300 seconds |
| Tier 2 | 1.5 minutes / 90 seconds |
| Tier 3 | 50 seconds |

Tier names, acquisition, rarity, crafting, charges, and progression are undecided.

### Effect shared by all tiers

On use, perform both actions:

1. Restore current HP to exactly `80%` of maximum HP when below that threshold.
2. Reset all eligible **skill cooldowns**.

HP rule:

```text
new_hp = max(current_hp, maximum_hp * 0.80)
```

Examples:

- current HP `80%` or higher -> restore `0%`; HP is unchanged;
- current HP `50%` -> restore `30%`, ending at `80%`;
- current HP `1%` -> restore `79%`, ending at `80%`.

The Trinket does not heal above 80%, does not reduce HP when already above 80%, and
does not provide overheal through this effect.

Cooldown-reset boundary:

- Reset skills only.
- Do not reset other items.
- Do not reset tokens.
- Do not reset the Trinket's own tier cooldown through its skill-reset effect.

### Intended uses

- Crowd control -> Trinket -> immediate second crowd control.
- Create a short burst-damage window by chaining more abilities than their normal
  cooldown order permits.
- Emergency HP recovery in a dangerous moment.
- Enable a player at low HP and with unavailable skills to participate in a
  time-sensitive boss mechanic instead of playing passively.

`CC` in this concept means **crowd control**.

### Explicitly undecided

- final item name and tier names;
- acquisition, crafting, cost, rarity, charges, and inventory/equip slot;
- whether every skill is eligible or whether exceptional skills require exclusions;
- interaction with passive cooldown modifiers, cooldown reduction, queued casts,
  charges, global cooldown, skills already executing, and skills with multiple
  resources;
- PvP availability and balance;
- whether use is allowed while crowd-controlled, stunned, downed, or otherwise
  action-locked;
- animation, VFX, SFX, UI cooldown presentation, and AI access;
- final balance of the three tier cooldowns.

## Future Resume Boundary

When either idea becomes active work:

1. Treat fishing and the Trinket as separate implementation slices.
2. Re-read this file as design intent, then inspect the current input, equipment,
   interaction, skill-cooldown, health, inventory, and save systems before planning.
3. Ask for decisions only where this file explicitly leaves a choice open.
4. Do not pull either system into Forge V2, Skill Crafter grip, combat damage, or
   current optimization work merely because a reusable subsystem appears nearby.
