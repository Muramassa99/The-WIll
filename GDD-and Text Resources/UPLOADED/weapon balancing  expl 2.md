Here is the same solution written with math and clear examples.

---

My solution is to use **negative space as a threshold-based balance system**.

I do not want a smooth linear formula that constantly adjusts power across all usage values. That would make every build slowly drift toward the same result and would reduce meaningful design choices.

Instead, I want the system to be balanced around **clear usage bands**.

## Core idea

Let:

* `U` = current used space
* `C` = maximum allowed usable space under the 35% rule
* `R = U / C` = usage ratio

So `R` is how much of the allowed crafting space the player has used.

Example:

* if the player used 9% of the allowed space, then `R = 0.09`
* if the player used 28% of the allowed space, then `R = 0.28`

I do not want power to scale smoothly with `R`.

I want `R` to place the weapon into a **category band**.

---

## Threshold band model

Example threshold structure:

* `0% to 2%` = Band 1
* `2.001% to 4%` = Band 2
* `4.001% to 6%` = Band 3
* `6.001% to 8%` = Band 4
* and so on
* `30.001% to 35%` = Final Band

Each band has a fixed number of **negative-space benefits**.

The lower the usage band, the more benefits remain active.

The higher the usage band, the more benefits are removed.

This means the system is not balanced at every single value of `R`.
It is balanced at the **band breakpoints**.

---

## Why this works

If a player builds just below an important threshold, they keep the bonus package for that band.

If they go slightly above it, they lose one or more benefits.

That creates a real decision:

* keep the weapon smaller and preserve bonuses
* or go bigger and accept losing them

That is the design goal.

I am not trying to stop players from optimizing around thresholds.
I want threshold optimization to be part of the game.

---

## Example benefit table

This is only an example structure.

### Band table

* `0% to 2%` → 15 benefits
* `2% to 4%` → 14 benefits
* `4% to 6%` → 13 benefits
* `6% to 8%` → 12 benefits
* `8% to 10%` → 11 benefits
* ...
* `28% to 30%` → 1 benefit
* `30% to 35%` → 0 benefits

So if a player uses 3.8% of the available crafting space, they are still in the `2% to 4%` band and keep 14 benefits.

If they increase to 4.1%, they move into the next band and drop to 13 benefits.

That small difference in used space now matters.

---

## Benefit meaning

The benefits are meant to compensate for lower material quantity and help minimalist builds stay competitive in long-term output.

These benefits should only affect **output numbers**, not weapon feel.

That means they can affect:

* damage multiplier
* critical chance
* critical damage
* elemental effect strength
* status buildup
* multihit coefficient
* skill damage scaling
* other DPS-related outputs

They should **not** affect:

* handling
* animation flow
* weapon feel
* center of mass
* motion behavior
* physical identity

Those are already handled elsewhere in the system.

---

## Mathematical example

Assume:

* a minimalist build uses `R = 0.039`
* a larger build uses `R = 0.041`

Then:

* `R = 0.039` stays in the `2% to 4%` band
* `R = 0.041` enters the `4% to 6%` band

If each band loses one output benefit, then the first weapon keeps one extra damage-related advantage.

This means the player has to decide:

* is the extra material worth losing the bonus?
* should I redesign the weapon to stay below the threshold?

That is exactly the kind of tension I want.

---

## Why I do not want a linear formula

A linear formula would look like this in concept:

`PowerBonus = 1 - R`

or

`PowerBonus = constant × unused space`

That is not what I want.

Why?

Because it creates smooth drift.

That means:

* 3.9% and 4.1% are almost the same
* 9.9% and 10.1% are almost the same
* there is no real decision point

The player will not feel pressure around any specific number.

The system becomes soft.

I do not want soft balancing.
I want **hard breakpoints**.

---

## Efficient anchor points

The system is not supposed to be most efficient at every value.

It is supposed to be most efficient at specific anchor bands.

For example:

* `1.9%`
* `3.9%`
* `5.9%`
* `7.9%`

These become natural efficiency zones.

The player will want to stay just under them.

That is not a flaw.
That is intended.

This creates a design environment where players constantly ask:

* can I remove a few cells and stay in the better band?
* can I reshape this design to remain below the threshold?
* do I really need those extra cells if they cost me a whole benefit?

That is meaningful decision-making.

---

## Endgame balance goal

I do not expect all builds to be perfectly equal.

That is unrealistic.

What I want is:

if two builds have similar quality materials and are played well, they should be able to hover in a similar long-term DPS range, even if they reach that range in different ways.

So:

* a larger build gets more raw material value
* a smaller build gets more negative-space benefits

That keeps both valid.

---

## Example comparison

### Build A: minimalist blade

* Uses `3.8%`
* Falls in Band 2
* Keeps 14 benefits
* Lower raw material quantity
* Higher compensation package

### Build B: larger blade

* Uses `4.2%`
* Falls in Band 3
* Keeps 13 benefits
* Slightly higher raw material quantity
* Slightly lower compensation package

Even though Build B uses more material, Build A can remain competitive because it preserves one more output bonus.

The player had a real trade to make.

---

## Another example

### Build C: big heavy weapon

* Uses `29.5%`
* Still gets 1 remaining benefit

### Build D: pushes into full cap range

* Uses `31.0%`
* Gets 0 benefits

Now the player must decide:
is going past `30%` worth losing the final bonus?

This is the kind of hard choice I want the system to create.

---

## Final design principle

The balance system is not based on equal values across the entire curve.

It is based on **discrete efficiency tiers**.

In short:

* lower usage keeps more benefits
* higher usage loses benefits
* breakpoints matter
* players are meant to optimize around those breakpoints
* the system is balanced at the threshold bands, not at every percentage value

That is the intended structure.

---

## Short reminder version

Negative space is not a smooth multiplier.

It is a **threshold reward system**.

Used space places the build into a band.

Each higher band removes one or more output-only benefits.

This creates meaningful design decisions around thresholds and allows minimalist and high-volume builds to remain competitive without making them identical.
