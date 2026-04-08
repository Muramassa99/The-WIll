# Town, Gate, Floor, and Forge Authority Savepoint

Date: 2026-03-23
Status: Active authority savepoint derived from uploaded docs plus later clarifications from discussion
Purpose: Preserve the currently aligned understanding of town population management, gate behavior, floor instancing, forge persistence, forge social rules, naming/finalization, and the related lore so future implementation can refer back to one detailed anchor instead of reconstructing intent from scattered chat.

Implementation follow-through note: IMPLEMENTATION_DATA_MODEL_SPEC_2026-03-23.md translates this authority savepoint into modular Godot-facing defs/models/services with a strong preference for tunable `.tres` data over hardcoded gameplay values.

## 1. How to Use This Note

This note is not the same thing as the living implementation memory.

Use this note when the question is:
- what is the intended behavior of the Town, Gates, Floors, and Forge systems
- what later clarifications overrode or tightened earlier docs
- what lore meaning should shape presentation and UX
- what concrete implementation tasks follow from these rules

Do not use this note to claim that something is already coded unless the implementation memory separately says it is.

## 2. Authority Layering

The current behavior intent comes from two sources combined:

1. Earlier uploaded docs already established the baseline model:
- named floors are stable identity
- floor numbers are seasonal difficulty/drop assignment
- forge is an instanced crafting space
- 15-minute downed return to town exists
- testing dummies are part of forge workflow

2. Later clarification tightened the design and now acts as stronger authority where the older docs were loose:
- town layers and routing behavior
- gate board interaction model
- floor soft-cap/hard-cap behavior
- floor expiry model
- forge persistence versus forge instance lifetime
- pre-name equip/testing behavior inside forge
- shared forge social usage with player-owned data
- naming uniqueness scope
- salvage percentages and skill-core handling

If an older note conflicts with this savepoint on these clarified points, this savepoint wins until intentionally revised.

## 3. World Structure Summary

The world structure is:

- Town hub
- Town gates to named floors
- Central forge gate to the forge area
- Return paths from floors and forge back to town

Core movement structure:

- Town -> named Floor instance
- Town -> Forge instance
- named Floor -> Town
- Forge -> Town
- Town layer A -> Town layer B

The Town is the social center and staging ground.
The named Floors are expedition/combat/gathering spaces.
The Forge is a crafting-focused instanced area.

## 4. Town Layer System

### 4.1 Basic Rule

The Town is one physical hub map that may exist in multiple parallel population-managed layers.

These layers are not different towns in fiction.
They are parallel instanced equivalents of the same town used to manage performance, visibility clutter, and social density.

### 4.2 Why Town Layers Exist

Town layers exist to:
- reduce visual clutter
- reduce server and client stress
- prevent the hub from feeling unusably crowded by default
- still allow players to intentionally gather in dense layers if they want

The system should preserve the feeling of a living social hub without forcing all active players into one overpopulated copy.

### 4.3 Town Capacity and Tunables

The Town layer cap must be tunable from one central location.

Current approved defaults:
- target hard cap per town layer: 500
- soft full label starts around: 75%
- auto-routing should avoid layers above about: 80%
- preferred landing target is below about: 74% occupancy unless social affinity overrides that preference

These values are not sacred design truth.
They are operational safety knobs and must be easy to patch later if real performance or player FPS requires it.

### 4.4 Town Auto-Routing Priority

When a player logs in or returns to town from a floor or forge, the routing priority is:

1. active party/group affinity
2. guild presence
3. in-game friend presence
4. Steam friend presence
5. best-fit population layer

If no social affinity target applies, the player should be routed toward a healthy-population layer below the preferred threshold.

### 4.5 Town Manual Movement Rule

Players are allowed to deliberately move to denser or lower-population layers.

The full label is mostly a deterrent signal, not a total lock, until the real numerical hard cap is reached.

This means:
- auto-routing should avoid crowding by default
- manual joining can still allow players to gather with friends even in high-population layers

### 4.6 Login and Relog Rule

If logout occurred in Town:
- relog follows town social routing plus population rules

If logout occurred in a Floor:
- relog should restore the same floor instance and same location if that instance is still active and has not expired

If logout occurred in Forge:
- relog should restore forge continuation context through persistent forge state, even if the runtime forge instance itself had closed

## 5. Gate System

### 5.1 Gate Identity Rule

The Town contains physical gates arranged around the hub.

There are conceptually 99 floor gates plus the forge gate.
However, gates should not be presented to players primarily as numeric gate objects.

Gates must be identified by destination identity:
- Grace's Garden
- other named floors
- Forge

The floor number is still shown as current seasonal difficulty context, but the gate is named by the destination, not by the number.

### 5.2 Gate Interaction Model

A gate is effectively a destination-specific party board in the shape of a gate.

Interacting with a gate opens a menu for that specific named floor.
The menu is not a generic world-travel list.
It is the board for that one destination.

### 5.3 Gate Menu Must Show

For the selected named floor, the gate menu should expose:
- floor name banner
- current seasonal floor number next to the banner
- active event information if any
- active instances list for that named floor
- each instance privacy state
- each instance population count
- character list for a selected instance
- friend/guild/Steam-friend presence indicators
- create-instance actions
- join or request-to-join actions
- rejoin action where applicable

### 5.4 Boss and Mini-Boss Status Display

The gate menu should expose key encounter status for that named floor instance using icons.

Planned icon logic:
- normal icon = alive
- normal icon plus swords overlay = alive and currently in combat
- grayscale icon = already dead

This applies to main boss and relevant mini-bosses/points of interest.

### 5.5 Friend Visibility Signals in Gate UI

If an instance contains socially relevant players, the instance entry should signal that clearly.

Current intended color shorthand:
- green glow = guild member present
- blue glow = in-game friend present
- white glow = Steam friend present

The purpose is fast decision-making, not decorative UI noise.

### 5.6 Join and Request Flow

If the instance is open:
- selecting it can immediately offer an enter confirmation prompt

If the instance is private-on-invite:
- selecting it should allow sending a join request to the instance leader/owner

Incoming requests should:
- be stored in a message/request list
- play an audible notification
- not block or interrupt active gameplay such as combat

The leader should review and approve or deny requests when able.

### 5.7 Teleport Acceptance Flow

Invitation acceptance and open-entry confirmation should use a prompt style with:
- accept
- deny
- auto-cancel after about 15 seconds if unanswered

Invite-based teleportation should work when the invited player is in Town, regardless of town layer, but not while they are already inside another floor or forge instance.

## 6. Named Floors and Seasonal Difficulty

### 6.1 Named Floor Identity

A named floor is a stable content identity.
It owns:
- map/layout identity
- theme
- fauna and flora theme
- enemy pool
- landmarks/secrets
- exploration and puzzle elements

Grace's Garden is an example of this kind of identity.

### 6.2 Floor Number Meaning

The floor number is not the true identity of a floor.
It is a seasonal difficulty coefficient.

Higher number means:
- harder enemies
- better drop quality
- stronger offensive/defensive tuning
- eventually better AI and more advanced attack patterns

Lower number means:
- easier content
- lower drop quality
- simpler enemy pressure

### 6.3 Seasonal Reshuffle Rule

On season change, named floors keep their identity but may be remapped to new floor numbers.

This means:
- same named floor
- same gate identity
- same broad content identity
- new seasonal difficulty assignment

The gate should still visually communicate the named floor first and the current seasonal number second.

### 6.4 Season Change Operational Rule

During season reshuffle, floors may close for maintenance.
This naturally fits the existing auto-expiry model.
At season turnover, instance continuity is not expected to survive the reset window.

## 7. Floor Instance Lifecycle

### 7.1 Creation Rule

A floor instance must be created by at least one player.

When created, it can be configured as:
- open
- private-on-invite

### 7.2 Lifetime Rule

A floor instance expires 15 minutes after no players remain in it.

This allows floor instances to feel persistent and socially inhabited when player flow continues, while still keeping the system fundamentally instance-based rather than permanent-world based.

### 7.3 Rejoin Rule

If a player dies or returns to town, the previously associated group instance should be easy to rejoin.

The intended gate behavior is:
- previous associated group instance appears first
- rejoin option is exposed clearly

### 7.4 Floor Capacity Rule

Current intended occupancy:
- soft cap around 150
- hard cap around 200

Behavior split:
- open walk-in access stops at soft cap
- invite-based entry can extend occupancy from soft cap up to hard cap

This preserves public readability while still allowing intentional group gathering above the soft cap.

### 7.5 Party Leader Destination Inheritance

Party/group destination flow should inherit the party leader's selected target.

This applies both when entering floor instances and when entering forge space.

### 7.6 Content Initiation Authority

Content initiation authority should follow the current social hierarchy:

- solo player: may initiate their own destination entry
- party only: party leader initiates content entry
- group present: group leader initiates content entry

If a group exists, group authority overrides party-only initiation authority.

The deeper party/group management model is intentionally deferred for later dedicated implementation, but the current behavior truth is:

- a group must always have a leader
- a party must always have a leader
- group leader may delegate limited invite authority to party leaders through group settings
- party leaders cannot remove the group leader
- group leader can remove party leaders
- if a leader is removed or leadership is passed, the next valid successor follows join-order inheritance rules

## 8. Return, Death, and Travel Notes

### 8.1 Death Rule

Death sends the player back to Town.

Resurrection scroll behavior remains distinct from death return.
Extraction scroll behavior remains distinct from floor beacon extraction.

### 8.2 Floor Extraction Beacons

Floors also contain beacon-based extraction/return infrastructure.

Current intended behavior includes:
- entrance-adjacent beacon
- more beacons unlocked later across the floor after progress/boss defeat
- atonement requirement
- risk while atoning
- no free safe-zone behavior

### 8.3 Teleport Logbook and Teleport Scrolls

Coordinate-based teleportation and imprintable teleport scrolls remain part of the broader travel/social loop.
These systems reinforce guild play, regrouping after wipes, and remote assistance, but they are separate from the gate-board system itself.

## 9. Forge Area Overview

### 9.1 Forge Access Rule

The Forge is a destination entered through the central forge gate.

It is a medieval forge-themed instanced area.
Placeholder primitives are acceptable now.
Final art comes later.

Forge entry initiation should follow the same authority split described above:

- solo player can initiate forge entry directly
- party leader can initiate forge entry when only a party exists
- group leader can initiate forge entry when a group exists

When a party or group is present, other eligible members should receive a prompt asking whether they want to teleport with the initiating leader/host.
If accepted, they travel into the same forge instance with that leader.

### 9.2 Forge Instance Capacity

The Forge is solo-first by design, but currently intended to support invited additional occupants.

Current target cap:
- 10 total people including the owner

### 9.3 Forge Instance Lifetime Versus Forge Data Lifetime

The forge runtime instance may close when empty.
Forge data must not be lost when that happens.

This is a hard rule.

The runtime forge scene is transient.
The player's forge data is persistent.

### 9.4 Forge Area Runtime Behavior

Once teleported into the forge area, players should behave as they do in town or floors with normal movement and skill usage still available.

The forge area should include and support interaction with at least the following current interactables:

- training dummies
- disassembly bench
- weapon crafter
- armor crafter
- accessory crafter
- own storage
- guild storage
- engraver
- exit-to-town gate
- direct player trade

This list is not final and may expand later, but it is the current v0 workflow picture.

### 9.5 Forge Membership Grace Rule

Dropping party/group status should not immediately eject non-host occupants from a forge instance.

Instead, if players lose the relationship that justified shared presence with the host, a 5-minute grace timer should begin before forced move-to-town behavior starts.

This rule exists specifically to avoid abuse, scamming, or weaponized party power.

## 10. Forge Persistence and Storage

### 10.1 Continuation Rule

Re-entering forge as owner should restore the exact last state as it was left.

Exiting the forge menu should also preserve exact continuation state.

The intention is:
- work can be paused
- materials can be gathered later
- player returns later
- the project is still exactly where it was

### 10.2 WIP Persistence Rule

Unnamed and unfinished projects persist per account in WIP storage indefinitely until intentionally changed, finalized, or deleted.

Even if the player feels the item is functionally done, if it has not been named/finalized it still belongs to WIP storage, not final item storage.

### 10.3 Storage Capacity Targets

Current desired storage targets per character:
- 300 weapon WIP slots
- 300 armor WIP slots
- 300 accessory WIP slots
- 200 blueprint slots

These should remain expandable later if necessary.

### 10.4 Personal Versus Guild Storage Use

Inside the forge area, personal storage and guild storage are separate interactables and separate authority surfaces.

- personal storage is account/character-owned forge-side storage outside the body inventory
- guild storage is guild-owned shared storage gated by guild permissions

The expected loop allows the player to move between:

- disassembly bench
- personal storage
- guild storage
- crafting station
- engraver
- exit gate

in whatever order they choose once entry and access conditions are satisfied.

### 10.5 Open Project Persistence Rule

An actively opened project at a crafting station should be treated as the current called-out project from WIP storage, not as a separate non-persistent object.

In practice:

- the currently opened project already belongs to WIP storage
- opening it for editing simply marks it as the project currently being altered
- re-interacting with the appropriate station should restore it in its most recent saved state, whether moments or months later

## 11. Forge-Internal Test Usage Before Naming

### 11.1 Core Rule

Unnamed items cannot leave the forge.
That does not mean they cannot be used inside the forge.

This is an important rule.

### 11.2 Equip/Test Rule

If a WIP is valid enough for its category to be stored and equipped in forge context, it should be possible for its owner/crafter to:
- load it from WIP storage
- equip it on the actual character model inside the forge instance
- test it against forge dummies
- return to editing/crafting stations and continue iterating

The intended shorthand user action for this is a direct `test work` button that equips the in-progress item on the owner immediately while preserving the current WIP state on the bench/storage side.

### 11.3 Testing Scope Rule

Before naming, a forge item is not yet a legitimate external/world item.
But it is still a real usable forge-internal test item for its owner.

That distinction must be preserved in future implementation.

Testing is condition-gated.
It is only available when the current WIP has passed the minimum greenlit conditions required to count as equipable/testable for its category.

### 11.4 Visitor Limitation Rule

Unnamed items are non-tradeable and cannot be handed to visitors for test use.

Showcase before naming happens by:
- owner equips the item
- owner demonstrates it
- visitors observe and may hit dummies with their own things

## 12. Shared Forge Social Architecture

### 12.1 Updated Social Rule

The forge space can be shared socially.

Multiple players inside the same forge instance should be allowed to use crafting stations concurrently.

This is now preferred over a stricter owner-only usage model.

### 12.2 Ownership Split Rule

Forge instance ownership and forge data ownership are different.

Shared space:
- stations
- physical room
- dummies
- observation/teaching/social presence

Player-owned data:
- materials inventory
- WIP storage
- blueprint storage
- resources
- current project state
- resulting items

### 12.3 Cross-Forge Continuation Rule

A player should be able to continue their own paused project:
- in their own forge
- or in another player's forge instance

The station is only an access point.
The real project data remains tied to the player.

### 12.4 Social Outcome Rule

This is intended to allow:
- teaching
- comparison
- live iteration together
- forge school behavior
- collaborative learning
- social showcasing and commissions

## 13. Forge Workflow Stages

The broad forge workflow remains:

1. Processing Station
2. Materials Storage
3. Category-specific crafting station
4. Testing through dummies and forge-internal equip state
5. Skill crafting/allocation where applicable
6. Semi-finished/WIP storage
7. WIP naming/project labeling inside forge-bound state
8. Engraver hard-lock/finalization step
9. Finalized item usable outside forge

The categories and resulting behavior are still shaped by:
- category built in
- base material allowances
- baked shape
- skill allocation
- chosen animation/effect parameters

The practical player loop is not strictly linear once prerequisites are met.
It may be mixed in any order, but the normal v0 pattern is:

1. deconstruct items/material sources at the disassembly bench
2. route resulting materials/matter/cores/other outputs automatically into forge-side storage/unlock systems
3. access personal storage or guild storage as needed
4. open a category-specific crafting station
5. select main category then sub-category
6. provide WIP project name before first placement/editing begins
7. craft/check/test/change/store in any order
8. optionally visit the skill crafter at any point between crafting and engraving
9. engrave a greenlit WIP into a finalized item

This workflow should stay flexible, but the data/state chain should still preserve those stage boundaries.

### 13.1 Category and Subcategory Entry Flow

The current intended first-pass crafting selection chain is:

- main category: weapon, armor, accessory
- then sub-category selection inside that main category

Current examples explicitly named by the user include:

- weapon: melee, ranged, magic, shield
- armor: helmet, chest, pants, boots, gloves
- accessory: rings, bracelet, necklace, belt, earrings

This list should be treated as the current v0 explicit set from discussion, not as a forever-final exhaustive taxonomy. If later category reference docs expand it, those docs can refine the exact final list.

Slot naming and role clarification:

- use `helmet` as the canonical armor slot name instead of `head`
- gloves are armor for the current implementation scope, even if later patches may let them branch toward fist-weapon behavior
- earrings are accessories

Stat-role clarification:

- gloves remain armor-category pieces, but may contribute more offensive-oriented stats than other armor pieces
- earrings remain accessory-category pieces, but may contribute more defensive-oriented stats than other accessories
- boots may expose movement-speed-oriented stat space that chest or helmet pieces do not

Category identity and stat tendency are therefore separate layers. A slot's crafting category does not force it to contribute only one stat orientation.

### 13.2 WIP Naming Gate At Craft Start

Immediately after selecting the relevant crafting sub-category, the player should be prompted for the WIP project name.

That WIP name is required before initial placement/editing begins because it establishes the save address/identity under which the in-progress work will be stored and recovered after:

- normal exit
- reopening later
- disconnects
- other interruption cases

### 13.3 Create-New Behavior While Another Project Is Open

If the player chooses `create new` while another project is currently open, the current project should automatically return to WIP storage in its latest altered state if storage capacity allows it.

If WIP storage is full, the user should receive a blocking prompt equivalent to:

`storage full can no longer add new builds, please proceed on deleting ongoing projects to allow for new ones to be made`

In that case, the new-project flow should not continue until capacity is available.

### 13.4 Disassembly Output Routing Rule

Disassembly is deconstructive processing.

Its outputs may include:

- materials
- matter
- cores
- other derived forge-side resources

Those outputs should be routed automatically into the relevant forge storage/count/unlock destinations rather than requiring manual pickup from the disassembly bench UI.

The disassembly UX itself is contextual and item-case-specific:

- different input objects may expose different context options
- each dismantleable thing may carry parameters that determine what the disassembly menu shows and allows

### 13.5 Material Eligibility And Display Filtering

Material visibility and material usability at crafting time should be filtered on a per-subcategory basis.

This filtering should be driven by material data in the relevant material `.tres` definitions rather than by hardcoded UI-only slot tables.

At the crafting station:

- the UI should still show allowed materials even when the player owns zero of them
- the UI should hide materials that are not legal for the currently selected subcategory
- ownership and legality are separate concerns: a material can be visible but unavailable due to quantity, or invisible because it is not legal for that subcategory at all

Examples from current clarified intent:

- some offensive-oriented materials may be legal for gloves even though gloves are armor
- some defensive-oriented materials may be legal for earrings even though earrings are accessories
- skill cores should be legal for weapons but not for armor or accessories
- some defense-oriented materials should be illegal for weapons

The broader balance rule is intentional: do not allow every material/stat direction on every slot. Subcategory filtering is part of the crafting process, not just a later stat-balancing pass.

### 13.6 Skill Crafter Placement In Workflow

The skill crafter belongs between crafting and engraving, but can be visited at any point in that span.

If the player does not explicitly perform manual skill-crafter work before engraving, the system should auto-load the best-fit default skill set based on a hierarchy driven by at least:

- main category
- sub-category
- material composition
- form factor
- center of mass
- other relevant qualifying parameters

This exists specifically to prevent accidental engraving of a valid item into a broken finished state with no meaningful skills assigned.

## 14. WIP Naming and Engraving Finalization

### 14.1 Terminology Split

The workflow now uses two separate terms intentionally:

- naming = WIP/project naming inside forge-bound state
- engraving = finalized hard-lock/export step

This distinction exists to reduce development confusion and to keep forge-side temporary/project naming clearly separate from finalized item identity.

### 14.2 Engraving Is the Lock Point

Engraving is not just cosmetic text entry.
Engraving is the hard lock/export point.

After engraving:
- customization locks
- skill allocation locks
- effects/parameters lock
- design stops being editable
- item becomes legitimate external game asset
- item can be used outside forge
- item can be displayed/traded as finalized item

### 14.3 Runtime Identity Split

At runtime, the finalized item should preserve both sides of the naming chain as separate concepts:

- the forge/WIP-side temporary or project naming reference
- the engraved final item name used by the finished item

The finalized item should therefore be able to reference its source WIP naming lineage without collapsing the two identities into one field.

### 14.4 Engraver Input UX

The engraver should present selectable WIPs from WIP storage, including the currently open project if one exists, because the currently open project is still just the currently called-out WIP entry.

If WIP storage is empty, the engraver should present a `no items to engrave` style message.

For each selectable WIP, the engraver list should show at least:

- a fixed-angle isometric preview image/icon
- the current WIP project name beneath it

When a WIP is selected, the engraver naming field should autofill from the current WIP project name while still allowing the player to edit it before engraving.

### 14.5 Engraved Name Validation Rule

The active naming policy now follows the dedicated naming.md specification.

Exact behavior:

- normalize input to NFC before validation and comparison
- measure user-visible length by Unicode extended grapheme clusters, not bytes/code units/raw code points
- accept total weighted cost from 1 to 30 inclusive

Weighted cost table:

- ASCII printable grapheme = cost 1
- non-ASCII ordinary text grapheme = cost 1
- East Asian Wide or Fullwidth grapheme = cost 2
- emoji grapheme = cost 2

Additional validation rules:

- combining marks, variation selectors, and valid ZWJ internals do not add extra cost beyond their grapheme bucket
- reject control characters
- reject standalone invalid combining sequences
- reject most invisible formatting characters and spoof-prone formatting controls
- reject leading spaces
- reject trailing spaces
- reject repeated internal spaces beyond one in a row

This naming policy applies to engraving input and is the current recommended standard for player-visible item names.

### 14.6 Engraving Confirmation Prompt

Before locking the engraved name, the player must receive a confirmation prompt equivalent to:

`are you sure you want to use this name, Engraving will lock current changes and will not allow further changes`

If the player selects `no`, control returns to the engraver naming box.
If the player selects `yes`, the finalized item is created and the UX should confirm that the item was sent to the player's body inventory.

### 14.7 Engraving Destination Rule

Successful engraving sends the finished item to the player's body inventory.

After that point the item is:

- usable outside the forge
- tradeable
- valid input for later disassembly
- equipable in normal gameplay contexts

### 14.8 Engraved Name Uniqueness Scope

Names are not globally unique across all players.

Different players may each create items named Sword.

But one individual player should not be able to create two items of the same general category with the same name.

The practical persistence identity is effectively:
- visible item name
- general category
- crafted by player

### 14.9 Invite-Only Floor Grace Parallel

The same anti-abuse grace concept should also apply to private invite-only floor instances.

If the instance is invite-only and party/group status that justified presence is dropped, a 5-minute grace timer should begin before forced removal.

If the floor instance is open-to-all, dropping party/group status should not auto-remove players who are already inside, even if total occupancy is above the soft-cap target.
Once inside an open instance, a player remains until they die or choose to leave.

## 15. Trade, Showcase, Blueprint, and Salvage

### 15.1 Trade Boundary

Only named/finalized items can be traded as legitimate external items.

Unnamed WIPs remain forge-bound.

### 15.2 Showcase Behavior

Because unnamed items are not tradeable or transferable, showcase behavior should happen through the owner equipping and demonstrating the item in forge space.

### 15.3 Blueprint Extraction Rule

The disassembly bench can process finished items.

One intended path is:
- blueprint extraction
- smaller material return

Current target example:
- about 15% material plus blueprint

Alternative intended path is:
- no blueprint extraction
- higher material return

Current target example:
- about 35% material without blueprint

### 15.4 Salvage Priority Rule

Material recovery should prioritize:
- higher tier materials
- skill-core materials

Material selection should matter.
This should not collapse into a blind generic refund.

### 15.5 Skill-Core Rule

Skill cores are chase materials.
They provide preset powerful abilities that cannot be modified in the skill crafting station.

If many skill cores were used in one item, salvage should force meaningful tradeoffs about what to recover.

## 16. Lore and Narrative Meaning

### 16.1 Town Cosmology Role

The Town is not merely a neutral lobby.
It is the center point where many worlds meet.

It can be understood as:
- a place where universes touch
- a place where parallel lines of time intersect
- the point at the center holding separation together

The worlds beyond the gates are not just destinations.
They are pressures beyond containment.

### 16.2 Purpose of the Gates

The gates are not primarily there to let people go out.
They are there to stop the worlds from seeping in and mixing.

The town's responsibility is to maintain the gates and prevent the worlds from collapsing into one another.
If the worlds mix uncontrolled, the result is fracture in time and space and the destruction of everything known.

This lore matters because gate presentation should feel like controlled containment, not casual fantasy doorframes.

### 16.3 The Forge Gate

At the center of everything sits the Forge gate.

The Forge is where Will becomes creation.
It is where players use knowledge, intention, material, and craft to make the tools needed to keep the danger beyond the gates in check.

The forge is therefore not side content.
It is a core pillar of why the world survives at all.

### 16.4 Why the Game Is Called The Will

The name ties directly into the philosophy of the game world and the crafting loop.

People claim something is impossible.
But if there is a will, there is a way.

Creation is the answer to danger.
Knowledge is the answer to chaos.
People are the answer to scale.

That is why the forge and the player's act of making things matter so much.

## 17. Implementation Consequences

The following architecture consequences should be treated as direct outputs of this savepoint.

### 17.1 Town Systems

Need:
- centralized town population tuning config
- town layer router service
- social affinity lookup pipeline
- relog restoration rules for town/floor/forge
- manual layer transfer flow

### 17.2 Gate Systems

Need:
- physical named gates in town
- per-destination gate board UI
- floor instance list/state model
- boss/miniboss state feed
- join/request/rejoin action model
- social presence highlighting

### 17.3 Floor Systems

Need:
- named floor identity data
- seasonal floor number assignment data
- floor instance privacy state
- soft-cap/hard-cap enforcement behavior
- 15-minute empty-instance expiry logic

### 17.4 Forge Persistence Systems

Need:
- per-player forge workspace state
- per-player WIP storage
- per-player blueprint storage
- per-player material inventory
- forge instance lifecycle separated from persistent data lifecycle

### 17.5 Forge Equipment/Test Systems

Need:
- forge-only equipable WIP test state
- valid-enough-to-test checks per category
- owner-only pre-name equip behavior
- dummy testing path using forge-bound WIP/test items

### 17.6 Finalization Systems

Need:
- naming station lock/export transition
- uniqueness enforcement per player plus category
- finalized item export model
- post-naming external usage/trade eligibility

### 17.7 Shared Forge Systems

Need:
- station interaction bound to current player identity
- concurrent station use by multiple players in one forge instance
- shared space, private data architecture
- cross-forge continuation of own projects

### 17.8 Salvage and Blueprint Systems

Need:
- disassembly bench logic
- salvage selection UI
- blueprint extraction path
- material-only recovery path
- skill-core priority logic

## 18. Clear Applicable Todo List

The next practical tasks implied by this savepoint are:

1. Create one explicit config location for town population thresholds and hard cap.
2. Define data models for named floors, seasonal number assignment, and floor instances.
3. Define the gate board UI/state contract for one named floor.
4. Define instance privacy, join request, invite teleport, and rejoin rules in data terms.
5. Define per-player forge persistence objects:
   - workspace state
   - WIP project record
   - blueprint record
   - finalized item record
6. Define the forge-only equip/test boundary before naming.
7. Define the finalization transition from forge-bound object to external item.
8. Define shared forge station behavior with player-scoped data.
9. Define salvage selection and blueprint extraction logic.
10. Reflect the strongest parts of this savepoint into later implementation-facing docs/code plans as needed.

## 19. Closing Note

This savepoint exists because enough information is now stable that future planning should not repeatedly rediscover it from scattered notes and conversation fragments.

The key intent is now clear:
- Town is a managed social center
- Gates are containment-facing destination boards
- named Floors are stable worlds with rotating seasonal difficulty numbers
- the Forge is a deep, persistent, social crafting core
- naming/finalization is the legal export boundary
- crafting is central to the identity and long-term social economy of The Will