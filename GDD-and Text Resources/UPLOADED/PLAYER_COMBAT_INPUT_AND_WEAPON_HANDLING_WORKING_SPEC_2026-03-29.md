# PLAYER COMBAT INPUT AND WEAPON HANDLING WORKING SPEC 2026-03-29

Purpose:
- capture the current agreed direction for weapon grip style, stowed weapon presentation, combat input defaults, evade/block law, skill-slot ownership, and marker/chat utility controls
- turn recent chat guidance into one cleaner project reference without inventing extra systems beyond what was stated

Status:
- this is a working implementation-spec note
- it is not a promise that all systems below already exist in code
- where the current project is not ready yet, this note should be treated as the target law for upcoming passes

## 1. Weapon hold presentation

### 1.1 Grip style is authored per weapon

Every forge-authored weapon should carry a grip-style choice alongside the stow-position choice.

Current intended grip-style options:
- `Normal Grip`
- `Reverse Grip`

Default:
- `Normal Grip`

Design rule:
- the chosen grip style must be respected in either hand
- if the same weapon is equipped in the right hand or the left hand, the weapon should still point forward or backward according to the authored grip style instead of silently flipping into a different hold law

### 1.2 Reverse Grip law

Reverse grip is a melee-only option.

It should:
- be available for melee archetype weapons
- not be available for ranged archetype weapons
- not be available for shield archetype weapons

Reverse grip tooltip text:
- `Reverse grip shortens the weapon's effective reach significantly and disables two-handed weapon techniques, but grants +25% attack speed.`

Design intent behind that warning:
- the shorter practical reach should mostly emerge from the weapon orientation and movement path rather than a fake hard range cut
- reverse grip is expected to be weak or limiting for many medium or long weapon shapes
- reverse grip is expected to be more relevant for dagger-like or short weapons
- reverse grip is not expected to matter much for rope-based weapons
- the attack-speed bonus exists to compensate for the reduced technique range and the smaller skill-space available to that grip style

### 1.3 Two-hand compatibility with grip style

Reverse grip disables two-handed weapon techniques.

Normal grip remains the standard path for:
- one-handed use
- two-handed use when enough grip span exists
- ranged archetype weapons
- shield archetype weapons

## 2. Stowed weapon presentation

### 2.1 Authored stow-position choice

Every forge-authored weapon should keep the existing stow-position choice.

Current intended options:
- `Shoulder Hanging`
- `Side Hip`
- `Lower Back`

Hover notes:
- `Shoulder Hanging` -> `Recommended for medium and long weapon builds.`
- `Side Hip` -> `Recommended for short and medium weapon builds.`
- `Lower Back` -> `Recommended for short weapon builds.`

Important:
- these are recommendations only
- they do not restrict selection based on weapon length

### 2.2 Runtime side selection

Each stow-position category has two valid runtime placements, and the active one is chosen by equipped hand.

Shoulder Hanging:
- if equipped in the right hand, stow on the player's left shoulder/clavicle side
- if equipped in the left hand, stow on the player's right shoulder/clavicle side
- handle points upward at a slight angle and should avoid clipping if possible

Side Hip:
- if equipped in the right hand, stow on the player's left hip side
- if equipped in the left hand, stow on the player's right hip side
- handle points generally forward

Lower Back:
- if equipped in the right hand, use the right lower-back placement
- if equipped in the left hand, use the left lower-back placement
- the weapon sits behind the character around hip height
- the handle stays on the same side as the equipped hand
- the slight angle should favor reduced clipping

## 3. Weapon bounds support object

Each equipped or stowed weapon built from a WIP should later expose a bounds object derived from the weapon's overall shape.

Target law:
- build a collision-sized bounds volume from the weapon visual
- expand it by `+1` voxel layer in all directions
- do not collide that bounds object against the player capsule

Reason:
- this support object will later help animation legality, anti-clipping checks, and body/weapon spacing rules
- it is not intended to become a normal hard collision object against the player

## 4. Skill ownership and loadout law

### 4.1 Skill menu entry point

Default key:
- `K` opens the skill tree / skill loadout page

The `K` page should open whether the player is:
- unarmed
- armed with one weapon
- armed with two weapons
- armed with weapon + shield

### 4.2 Unarmed baseline

If no weapon is equipped:
- the skill page shows the unarmed skill set
- skills are shown as icons with the current keybind beside them
- hovering a skill shows the creator-authored skill description

Future presentation idea:
- skill preview media may later be a short loop such as a high-quality GIF or short video preview
- that is a shipping-product enhancement idea, not a current implementation requirement

### 4.3 Weapon skill takeover

If one weapon is equipped:
- weapon skills replace the unarmed skill set

If two weapons are equipped, or weapon + shield:
- the player can choose which skills occupy the numbered skill slots
- each equipped item contributes only its own valid skills
- the equipped item that owns a skill is the item that performs that skill

Ownership law:
- if a skill belongs to the left-hand weapon, that weapon performs the attack
- if the same weapon is later moved to the right hand, that same weapon still performs the same skill from the right side
- the skill follows the weapon, not the slot side

### 4.4 Two-handed skill availability

If a weapon was authored for two-handed use:
- skills that require true two-hand usage should be unavailable when the weapon is paired with another item
- those unavailable skills should be visibly grayed out
- if some of the weapon's skills are valid for one-hand use, only those should remain available in dual-weapon or weapon-plus-shield setups

### 4.5 Single-weapon compensation

If the player equips only one weapon instead of two:
- grant a flat movement-speed bonus of `15%`
- grant a flat attack-speed bonus of `15%`

Current status of these values:
- they are intended to be adjustable during testing
- the current note treats `15%` as the first test target

## 5. Combat input defaults

These defaults should later become editable through the controls/settings UI.

Movement and combat:
- `1 2 3 4 5 6 7 8 9 0 - =` -> main skill slots
- `Q` -> block
- `E` -> evade / dodge
- `F` -> interact
- `SS` -> back-dodge input via double-tapping `S`

UI:
- `I` -> inventory
- `M` -> map
- `U` -> quests
- `P` -> party menu
- `L` -> friends list
- `K` -> skill tree / loadout

Communication and utility:
- `/` or `Enter` -> open chat
- `Enter` again after typing -> send message and close chat
- `` ` `` -> ping system
- `N` -> marker radial system

## 6. Evade and iframe law

### 6.1 E evade

`E` is the main evade input.

Directional behavior:
- `E + A` or `E + D` -> lateral evade
- `E + WA`, `E + WD`, `E + SA`, `E + SD` -> diagonal variants
- `E` with no directional input -> local backflip
- `E` in midair -> airborne evade / hover-like extension

Timing:
- directional `E` variants -> `0.6s`
- non-directional `E` -> `1.0s`
- airborne `E` -> `1.0s`

Resource use:
- each use consumes `30` stamina

### 6.2 SS back dodge

`SS` means pressing `S` twice within `1.0s`.

Rules:
- `SS` cannot be performed while airborne
- `SS` always moves the character backward by `5m`
- `SS` can be combined with held directionals

Current intended orientation rule:
- `SS` during `W` or `D` combination -> counter-clockwise rotational feeling
- `SS` during `A` combination or while stationary -> clockwise rotational feeling

Timing:
- `SS` duration -> `1.0s`

Resource use:
- consumes `30` stamina

### 6.3 Iframe implementation law

Iframes should be implemented by disabling the player's hurtbox for a fixed duration.

Important rules:
- stamina is consumed at the same moment the hurtbox is disabled
- the hurtbox-disabled timer runs for its full fixed duration even if the visible animation is canceled into another action
- mastering animation cancel timing should be allowed and rewarded
- faster attack speed or movement speed should not shrink the iframe window
- re-casting an evade before the previous timer ends should reset the iframe timer from the start and consume stamina again if available

This means:
- the defensive timing is fixed-duration and skill-based
- canceling the visible animation does not end invulnerability early

DOT rule:
- existing damage-over-time effects already applied to the player continue ticking normally
- iframe state does not erase an already-applied DOT timer
- if an attack carrying a DOT payload does not hit, the payload is not applied

## 7. Block law

`Q` is the block input.

Shield equipped:
- blocking can be held indefinitely while the button is held
- once the button is released, block enters a `0.5s` cooldown before it can be started again

No shield equipped:
- blocking still exists
- maximum continuous block duration is `2.5s`
- once block ends, block enters a `1.0s` cooldown

Important:
- block does not consume stamina under the current rule

## 8. Stamina law for evade

Evade-type actions consume stamina.

Current intended law:
- evade / iframe actions consume stamina
- block does not consume stamina
- `30` stamina per evade source allows three chained uses from a `100` stamina baseline

The current project should later re-check this against the existing stamina and stamina-regeneration reference material before code lock.

## 9. Marker and ping utility systems

### 9.1 Marker radial system

Default key:
- `N`

Use flow:
- aim with the crosshair at the desired placement point
- hold `N` to open the radial menu
- while holding `N`, choose a slice by mouse directional input
- releasing `N` applies the selected marker

Input behavior:
- during the radial hold, the mouse remains center-bound in principle
- direction of mouse movement relative to center selects the radial slice

Marker placement law:
- line-of-sight based
- valid on playable surfaces with proper collision
- should prefer valid ground over walls when both are plausible
- not valid on skyboxes or out-of-bounds areas

Marker presentation:
- marker is a world marker that faces players for readability
- later intended as sprite-based, player-facing 2D content

Removal:
- the `6 o'clock` radial slice should be the remove-marker action
- aiming at an existing marker and choosing that option removes it

### 9.2 Ping system

Default key:
- `` ` ``

Behavior:
- one press -> temporary green ping bubble
- two presses within `1.0s` on roughly the same spot -> convert that ping to a red variant

## 10. Chat behavior

Open chat:
- `/`
- `Enter`

Send rule:
- pressing `Enter` again after text entry sends the chat message and closes the chat input
- once chat is closed, movement inputs should no longer route into chat text entry

## 11. Recommended implementation order

This is the cleanest next-pass sequence based on current project readiness.

### Pass 1. Weapon metadata expansion

Add per-weapon authored grip-style data next to the already-authored stow-position data.

Deliverables:
- `Normal Grip` / `Reverse Grip`
- melee-only reverse-grip legality
- tooltip note for reverse grip
- saved WIP persistence for grip style

### Pass 2. Runtime draw/stow and grip-orientation presentation

Use the new grip-style metadata plus the current stow-position metadata to control:
- right-hand forward hold
- left-hand forward hold
- reverse-grip hold in either hand
- stowed visual orientation per position type

This pass should stay presentation-focused first.

### Pass 3. Input-action registry expansion

Extend the current input settings/runtime layer so the requested defaults exist as real actions and become rebindable through the menu system.

Deliverables:
- numbered skill actions
- block / evade / marker / ping / friends / party / quests / map / chat actions
- no full gameplay behavior required yet beyond input registration and settings exposure

### Pass 4. Player combat-state shell

Add the first explicit player combat-state authority surface for:
- armed vs unarmed
- weapons drawn vs stowed
- shield present vs no shield
- out-of-combat vs combat
- stamina pool / stamina use timers
- hurtbox enable/disable windows

This is the dependency layer needed before evade/block and later attacks stay coherent.

### Pass 5. Evade and block baseline

Implement:
- `E` directional evade
- `SS` back dodge
- fixed iframe timers
- stamina cost / cooldown rules
- shield vs no-shield block law

This pass should focus on timing correctness and state correctness before animation polish.

### Pass 6. Skill-loadout page shell

Add the first `K` menu shell for:
- unarmed skill view
- single-weapon skill view
- dual-weapon / weapon+shield skill assignment
- gray-out of invalid two-hand-only skills in one-hand contexts

This can begin as a systems UI without final art.

### Pass 7. Marker, ping, and chat utility shell

Implement the non-combat communication layer:
- basic ping
- basic marker radial
- basic chat entry behavior

This should come after the action/input registry exists.

### Pass 8. Attack and hitbox layer

Only after the previous dependencies exist should the project move into:
- weapon-hitbox generation
- attack execution
- weapon-owned skill execution
- aim-based strike direction
- DOT payload delivery rules

## 12. HUD layout editor requirements

This section captures the currently requested gameplay HUD shell, even though it should be implemented after the combat/input core is further along.

Requested baseline HUD elements:
- `12` main skill slots
- `1` separate block slot
- `1` horizontal HP bar
- `1` separate vertical stamina bar

Skill-slot layout law:
- the `12` skill slots should be arranged as `6 + 6`
- each six-slot half should behave as part of one combined horizontal bar for movement in the HUD editor
- the separate block slot should remain its own element

Persistence law:
- HUD layout should be per-player
- once positioned and saved, it should behave as a set-it-and-forget-it personal preference until the player changes it again

HUD editor law:
- there should later be a `UI Layout Editor` mode
- in that mode the player can reposition the skill bar group, block slot, HP bar, and stamina bar
- there should also be an `Adjust UI Size` control for these gameplay HUD elements
- this size adjustment is meant for the gameplay HUD elements above, not for the broader menu pages or other tabbed windows

Chat box requirements for later:
- chat should later exist as a fading text box that disappears when not in active use
- chat should have its own settings for font and size
- chat should support custom position
- chat should support width/height resizing by dragging edges or corners

## 13. Current boundary

This note intentionally does not define:
- exact skill tree content
- final animation graphs
- final hitbox math
- final stamina numbers beyond the values already mentioned
- final marker art
- final party/friends/quest UI visuals

Those remain later implementation details built on top of the rules above.
