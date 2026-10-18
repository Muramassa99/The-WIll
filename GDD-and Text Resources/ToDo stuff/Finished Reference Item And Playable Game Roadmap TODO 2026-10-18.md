# Finished Reference Item And Playable Game Roadmap TODO

Recorded: 2026-10-18, Europe/Bucharest.
Source: the user's roadmap and explicit request to save all of it as a ToDo.
Status: planned work, not an implementation or verification claim.

## Purpose and working rules

The user will build an item they consider usable and finished. It will become a
long-term reference item for exercising current and future features, beginning
with Forge V2 output, Skill Crafter, material calculations and damage.

The item is a workhorse for the general system. It must expose problems and
missing features; it must not become a special case that the solver, combat
rules or export pipeline are hardcoded around. Solutions should apply to other
Forge V2 outputs. Keep additional varied items as checks when generality matters.

Preserving creative flow is a core project law, reaffirmed in this conversation.
Removing unnecessary actions, menu trips and interruptions is functional work.
Address actual authoring friction encountered during creation without treating
this roadmap as permission to implement every future subsystem immediately.

The immediate activity is the user's manual construction of the reference item.
Its saved name and location are not supplied yet. No new Git branch, commit or
push is authorized by recording this plan. Engraving's future development branch
is a planned task, not a branch change performed now.

## Reference item and Skill Crafter

- [ ] Build and save the reference item in Forge V2; record its actual saved name
  and identifier when available.
- [ ] Use the item to expose current and future Forge V2 features and authoring
  problems, while preserving general behavior for other items.
- [ ] Bring the item into Skill Crafter.
- [ ] Create a full set of skills and get those skills working as intended.
- [ ] Check that authored, saved and equipped gameplay playback agree.
- [ ] Revisit the documented per-skill key/slot-specific effects, give the user
  a reminder, and evolve the older notes as new decisions are made.
- [ ] Implement the agreed slot-specific behavior in the appropriate future slice.
- [ ] Evolve Skill Crafter's controls and workflow as real use reveals friction.
  The user anticipates additional QoL work; specific changes remain to be chosen.
- [ ] Add future skill-authoring capabilities, including visual effects,
  particles and sounds, with usable preview, persistence and playback.

## Materials, damage and skill values

- [ ] Establish the reference item's material and damage calculation baseline.
- [ ] Define base damage calculations and values for each skill, providing the
  base against which material-derived statistics can apply.
- [ ] Reconcile that intent with the existing damage/material rules before
  selecting equations, coefficients or aggregation order.
- [ ] Audit the material `.tres` database and adjust or redo it as required by
  the agreed model. A full replacement is possible, not already decided.
- [ ] Keep material definitions shared and immutable at runtime; put mutable
  item/session values in their proper state owners.
- [ ] Use the same material/stat calculation path for other Forge V2 outputs;
  do not introduce reference-item-only damage constants.

NEEDS_DECISION: exact formulas, stat fields, skill/material contribution order,
and changes to the current resource schema. This note does not supply them.

## Engraving and the finished product

- [ ] Start Engraving as a separate interactable station.
- [ ] Design and implement its UX/UI and the station workflow.
- [ ] Establish a dedicated development branch when this work is explicitly
  started and the Git operation is authorized.
- [ ] Carry the completed Forge geometry/material/combat data and authored skills
  into Engraving, with weapon and skill descriptions, notes and lore.
- [ ] Implement the final save/export boundary for the engraved article.
- [ ] Preserve the established intent that an engraved product is finalized:
  normal player editing of its composition, skills, descriptions and visuals ends.
- [ ] Verify that the exported item can be loaded, equipped and used outside the
  crafting stations with its authored behavior intact.
- [ ] Test the complete path from creation through finalization and normal use.

The user's rough expectation was about a month of Engraving work or less. This
is an unvalidated estimate, not a schedule or delivery commitment.

Earlier vision to retain: the final item packages related authored/baked data
together. Future wearer scaling must transform the mesh and correlated targeting,
collision and playback data coherently without changing the material-derived
stats simply because the displayed item is larger or smaller. Bake authoring
results for inexpensive playback; collision, damage and multiplayer authority
still require runtime work. Exact formats and policies need a separate design pass.

## Testing range and playable combat

- [ ] Provide enemy targets in a testing range.
- [ ] Measure and test attack ranges, damage and effects using the reference item.
- [ ] Exercise new Skill Crafter output, including particles, visual effects and
  sound, in actual gameplay.
- [ ] Add NPC enemy behavior: pathing, interactions, aggro and combat.
- [ ] Tune player movement values, including jump height and sprint speed.
- [ ] Add/tune dash behavior and invulnerability-frame logic.
- [ ] Tie movement and combat behavior into the agreed server authority model.
- [ ] Perform full front-to-back testing as each complete usable path becomes
  available, and retain regression examples beyond the reference item.

## World spaces and player persistence

- [ ] Design The Forge as a playable space with rooms and world-building elements.
- [ ] Add a second world space and make it the main/default world space.
- [ ] Develop maps and their intended connections.
- [ ] Implement portals and teleportation.
- [ ] Add login/re-entry behavior that restores the character's last logout
  location instead of always using a general predetermined spawn.
- [ ] Persist the world/space identity as well as the character location;
  decide how invalid or unavailable saved locations are handled.
- [ ] Add the game-time clock.

NEEDS_DECISION: exact layouts, spawn/return policies, portal rules and clock model.
The second/main space does not supersede the last-location restoration requirement.

## Headless server and multiplayer

- [ ] Host the game on a self-hosted headless server.
- [ ] Allow external PCs to join and test real session behavior.
- [ ] Test synchronization, timings and multiplayer logic across machines.
- [ ] Move authoritative combat data/calculations to the server as agreed.
- [ ] Connect movement, dash and invulnerability behavior to server validation.
- [ ] Test character/world persistence across disconnect, logout and re-entry.
- [ ] Define and test gameplay/network rollback functionality.
- [ ] Measure performance across the host and participating client machines.

NEEDS_DECISION: authority ownership, prediction/reconciliation and the intended
scope of gameplay rollback. Keep gameplay rollback distinct from deployment or
saved-world rollback below; the user's broad request does not select an algorithm.

## Items, economy and rewards

- [ ] In-game item marketplace.
- [ ] Trading between players.
- [ ] Item ownership, transfers and item drops.
- [ ] Drop-rate tables and item/reward adjustments.
- [ ] Reward packages redeemable through codes.
- [ ] Unique reward-code generation/hash handling and redemption behavior.

NEEDS_DECISION: economic rules, ownership/persistence contracts, drop sources,
reward eligibility and code reuse/expiry policy. Record those before implementation.

## Communication and presentation

- [ ] In-game chat.
- [ ] Direct player whispers.
- [ ] Global server announcements.
- [ ] Languages/localization.
- [ ] Sound design.
- [ ] UI/UX artwork changes.
- [ ] Miscellaneous tuning and QoL additions as actual play reveals them.

## Deployment, operations and safety

- [ ] Remote game/client patch distribution.
- [ ] Remote server patch deployment.
- [ ] Server rollback tests.
- [ ] Define which versions/data are restored during operational rollback and
  how saved items, characters and world state remain usable.
- [ ] Safety and anti-cheat detection.
- [ ] Account flagging and banning workflows.

These are future design and implementation tasks; no hosting service, update
provider, anti-cheat product or enforcement policy has been selected here.

## Steam and public presence

- [ ] Steam store page.
- [ ] Game-to-Steam communication/integration.
- [ ] Steam achievements.
- [ ] Website creation.

## Performance is ongoing work

The repeated performance-tuning entries are deliberate emphasis, not duplicate
tasks to discard. Performance must be revisited throughout creation, playback,
combat, world development and multiplayer.

- [ ] Investigate the previously reported high GPU utilization during the game.
- [ ] Keep the user's present PC as a practical baseline for playability; a
  hardware upgrade is not assumed to solve performance issues.
- [ ] Profile authoring responsiveness, finished-item playback, rendering,
  collision/combat, NPC load, networking and headless server work as each matures.
- [ ] Measure changes on repeatable scenarios, including the reference item.
- [ ] Tune repeatedly as assets, maps and systems accumulate; retain frame-time
  and resource-use evidence rather than relying only on a good average FPS.
- [ ] Extend cross-machine testing when external clients/server testing is ready.

NEEDS_DECISION: numerical frame-time, memory, server-tick and networking budgets.

## Suggested dependency order, for review

This is a planning aid, not a newly approved implementation schedule:

1. Finish/save the reference item and identify actual Forge authoring issues.
2. Use it in Skill Crafter; build the full skill set and verify saved gameplay
   playback. Reconcile the old slot effects and material/damage definitions.
3. Establish the damage/effect baseline and a small usable testing range.
4. Complete the creation-to-Engraving-to-equipped-item path and test it end to end.
5. Expand worlds, persistence, NPCs and the multiplayer/headless-server slice.
6. Grow economy, communication, deployment, Steam and public-facing services
   around the validated item and gameplay contracts.

Consider server authority, versioned persistence and final-item boundaries early
enough that the local slices can feed them later. Performance and creative flow
apply throughout, not just at the end. Narrow implementation slices will still
need current code inspection and their own agreed acceptance criteria.

## Immediate next action and open references

The user builds the item. Record its saved identity when supplied, then inspect
that exact artifact and the first reported obstacle. Avoid speculative grip or
material database rewrites before the user selects the next implementation slice.

Historical design is not proof of current implementation. The focused lookup
below recovered the existing intent; it did not audit the live combat code.

Current Forge context:
[Forge V2 Tool Wheel Context Actions And Retained Editing 2026-10-18.md](<Forge V2 Tool Wheel Context Actions And Retained Editing 2026-10-18.md>).

This backlog is intentionally open-ended. Append newly identified work with its
scope and dependencies; do not mark an item complete based only on this plan.

## Historical skill-slot reminder

The April design defines twelve main combat slots on `1 2 3 4 5 6 7 8 9 0 - =`,
corresponding in order to `skill_slot_1` through `skill_slot_12`. It separately
describes `Q` for block, `E` for evade, and double-tap `S` for back-dodge. These
are historical gameplay bindings, not changes to Forge's contextual controls.

The documented role families are block/parry, displacement/dash, crowd control,
damage, buff/support, and invulnerability frames. The selected slot supplies
functional rules; Skill Crafter authors motion within them. Slot data is intended
to determine permitted motion-node count, damage-instance count, movement,
effects and usage conditions, combined with weapon/material data and runtime
legality. These families are not a completed assignment to the twelve numbers.

NEEDS_DECISION: the exact effect assigned to each numbered slot, effect strength
and duration, damage coefficients and final hit-count rules. The historical
consolidation explicitly marks exact per-slot gameplay-effect tables undefined.
The August damage-economy note also leaves the relationship between critical
chance, critical damage, attack speed and DPS unresolved. Do not convert those
proposals into final formulas just because they appear in an older document.

Sources inspected on 2026-10-18:

- [Skill system consolidated reference, 2026-04-12](<../UPLOADED/SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md>):
  lines 56-64 and 82-108 describe inputs/slot IDs; 370-417 describes slot-owned
  parameters; 1138-1150 explicitly leaves the exact effect table unfinished.
- [Combat Editor Original Intent Digest, 2026-04-30](<Combat Editor Original Intent Digest 2026-04-30.md>):
  lines 242-268 reaffirm role families, authored motion and hit economy from
  slot output plus weapon/material/build modifiers.
- [Runtime Combat Editor Visual and System Addendum](<../Runtime Combat Editor Visual and System Addendum.md>):
  lines 99-130 describe slot law, material/build, authored motion and
  collision/speed contributions.
- [Skill Crafter Unified Implementation TODO, 2026-04-30](<Skill Crafter Unified Implementation TODO 2026-04-30.md>):
  August 29 addition at lines 925-929 records unresolved damage-economy questions.

These references provide a reminder and discussion starting point. Preserve their
history and record newer approved rules explicitly when the user revisits them.
