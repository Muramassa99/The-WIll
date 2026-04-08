# THE WILL - Project Overview & Scope Document
**Version: 1.0**
**Created: 2026-03-21**
**Engine: Godot 4.6.1**
**Platform: Steam PC**

---

## Executive Summary

**The Will** is a hub-based, seasonal, instanced dungeon game with deep crafting at its core. The game philosophy centers on **three pillars: People matter, Knowledge matters, Creation matters.**

This is **NOT** an open-world MMO. It is a regulated, performance-optimized experience with a shared social hub and large instanced expedition floors.

**Development Strategy: Atomic-First, Foundation-Up**
- Build from the smallest components (atoms) upward
- Complete all architectural definitions before runtime implementation
- Architected to support future modding, content injection, and player-authored extensions within controlled boundaries
- All documentation, design, and foundational code completed BEFORE UI/visual implementation

---

## Core Game Concept

### Player Fantasy
- "I craft something personal, learn the place when it's safe, then return when it's deadly."
- "People matter, knowledge matters, creation matters."

### The Three Pillars
1. **People Matter** - Party coordination, contracts, reputation, crafting identity
2. **Knowledge Matters** - Map discovery, enemy patterns, floor mastery
3. **Creation Matters** - Crafted gear defines gameplay; provenance and templates matter

### Design Philosophy
- Power isn't found; it's made
- Equipment changes gameplay behavior (not just stats)
- Constraints breed creativity
- Seasons create memory and reset races

---

## Game Structure

### 1. THE HUB (Shared Social Space)
- **Purpose**: Central gathering point for all players on a shard
- **Scale**: Crowded with many players simultaneously (mitigated with LOD/pop-in/hide player toggle)
- **Features**:
  - Social spaces
  - Guild/faction areas
  - Contract board (player matchmaking)
  - NPC stations (forge access, repairs, cooking, storage)
  - Mailbox system
  - Character inspection
  - Chat/social systems

### 2. INSTANCED FLOORS (99 Total)
- **Structure**:
  - Each floor has a NAMED layout (e.g., "Grace's Garden")
  - Seasonal rotation remaps named floors to difficulty levels
  - Layout remains constant; difficulty and drop quality shift
  - Players feel like exploring an open world (~15-60 min per run)
- **Features**:
  - Personal fog-of-war (map reveal is permanent per named floor)
  - Party member visibility always shown
  - Extraction points (require attonement with risks)
  - Material gathering
  - PvE combat (mobs, elites, bosses)
  - Environmental hazards
  - Landmarks and secrets
- **Instancing Model**:
  - Supports multiple parties concurrently
  - Performance bounded through instancing, visibility controls, and future server-side validation; optimization targets must still be tested in real gameplay conditions
  - Server-side instancing planned later (future auth architecture)

### 3. FORGES (Private Crafting Workspaces)
- **Model**: Instanced per-player workspace
- **Stations**:
  1. Processing Station - Raw drops → forge materials
  2. Materials Storage - Filtered search by color/bonus/quality
  3. Weapon Crafting Station - 3D grid editing (160x80x40 blocks max)
  4. Armor Crafting Station - Mannequin-constrained editing
  5. Accessory Crafting Station - Similar constraints
  6. Skill Crafting Station - Behavior design & element allocation
  7. Testing Area - Dummies for iteration
  8. Semi-finished Storage - WIP backup
  9. Naming Station - Finalization & export
  10. Dismantling Station - Blueprint extraction & salvage

---

## CORE GAMEPLAY LOOP

```
Gather Materials
    ↓
Return to Hub
    ↓
Process Materials (Forge Station)
    ↓
Design Gear (Weapon/Armor/Accessories)
    ↓
Assign Behaviors (Skill Crafting)
    ↓
Test on Dummies (Testing Area)
    ↓
Finalize & Export (Naming Station)
    ↓
Equip & Enter Floor
    ↓
Combat, Gathering, Exploration
    ↓
Return with Materials or Die (Durability Penalty)
    ↓
Repeat at Higher Difficulty (Seasonal Rotation)
```

---

## CRAFTING SYSTEM (THE CORE)

### Material Pipeline Lifecycle

```
Raw World Drop (from enemy/environment)
    ↓ (Processing Service)
Processed Forge Material Stack
    ↓ (Forge Grid Controller)
Placed Forge Cells (3D grid editing)
    ↓ (Segment/Anchor Resolvers)
Segments & Anchors (gameplay-meaningful regions)
    ↓ (Profile Resolver)
Baked Profile (gameplay-facing stats & capabilities)
    ↓ (Capability Resolver)
Capability Scores & Outcome Clusters
    ↓ (Skill Crafting Controller)
Behavior Template (skill assignments)
    ↓ (Testing Service)
Test Print Instance (playable copy on dummies)
    ↓ (Naming Service)
Finalized Item Instance (exportable, tradeable, provenance-locked)
```

### THE FOUR SACRED CLASSES (NEVER COLLAPSE)

These four objects must remain separate to prevent architectural spaghetti:

1. **ForgeMaterialStack** - Processed inventory cubes (from raw drops)
2. **CraftedItemWIP** - Work-in-progress forge design (authoring state)
3. **TestPrintInstance** - Baked test output (playable copy for iteration)
4. **FinalizedItemInstance** - Exportable final item (tradeable, provenance-locked)

**Forge-Bound Design Laws:**
- Work-in-progress items are forge-bound: they can be edited repeatedly, fully refunded before naming, baked into temporary test prints, and used only inside the Forge testing area.
- Naming/finalization is the export point: once named, an item gains identity, provenance, and world legality, can leave the Forge, can be equipped/traded under rules, and loses full-refund status.
- **Design rule: Before naming, the cost of experimentation is time. After naming, the cost of revision is materials.**

### Crafting Atoms (Smallest Buildable Units)

#### 1. Material Atom
- Defines what a piece of matter contributes
- Properties: density, hardness, toughness, elasticity, magic affinity, heal affinity, elemental affinities, special effect tags

#### 2. Cell Atom
- One occupied unit in the 3D grid
- Stores: position, layer, material, shape, orientation, surface flags, mirror state

#### 3. Anchor Atom
- Marked gameplay-meaningful points
- Examples: primary grip, secondary grip, projectile origin, shield handle, skill emission

#### 4. Segment Atom
- Logical grouped regions within item
- Examples: blade, head, handle, guard, shaft
- Derived from cell clustering

#### 5. Layer Atom
- Active editable stratum in forge workflow
- Only one layer editable at a time
- Non-active layers show as baked preview

#### 6. Profile Atom
- **CRITICAL**: This is what gameplay reads, not raw cells
- Derived values: mass, center of mass, reach, balance, inertia, flex, guard, launch, capability scores

### Capability System (Backend Classification)

Players do not select visible combat classes. Instead, crafted items resolve to capability scores and backend outcome clusters, while crafting contexts/tabs remain a forge-side workflow aid rather than a class system.

**Capability Scoring:**

**Suggested Capability List (current first-pass):**
- Reach, Impact, Edge, Pierce, Blunt, Guard, Flex
- Tether, Launch, Magic, Heal, Mobility, Control
- Stability, Channel, Barrier
- Precision, Burst, Sustain, Support
- Projectile, Armor, Plate, Grip, Anchor
- AOE, Counter, Parry

**Scoring Model:**
- 0 = absent
- 1 = weak
- 2 = available
- 3 = strong
- 4 = defining

These scores determine:
- Available behavior families
- Fallback animation sets
- Tuning defaults
- Validation hints
- Which legal options can be shown inside fixed slot-role boundaries

### Hidden Outcome Clusters (Backend Patterns)

These are NOT visible to players:
- Sword-like, Spear-like, Staff-like, Shield-like
- Bow-like, Axe-like, Flail-like, Rope-dart-like

Used for suggested templates, fallback animations, and tuning defaults.

### Skill Atoms (Behavior Construction)

Skills are built from composable atoms:

1. **Delivery Atom** - How it exists (held-weapon, projectile, zone, tether, barrier)
2. **Origin Atom** - Where it begins (grip point, weapon tip, body center)
3. **Path Atom** - How it moves (straight, arc, sweep, thrust, spin, chain)
4. **Timing Atom** - How it unfolds (windup, active frames, linger, recovery)
5. **Contact Atom** - How it checks impact (point, line, cone, box, sweep volume)
6. **Payload Atom** - What it does (damage, heal, shield, CC, mark)
7. **Motion Atom** - Effect on player (dash, leap, blink, recoil, planted)
8. **Constraint Atom** - Item requirements (magic affinity, reach, stability, guard)

### Material Families

**Structural Materials** - mass, hardness, toughness, flexibility, durability
**Affinity Materials** - elemental access, heal bias, status payload, damage flavor
**Keystone Materials** - rare, signature effects, special behavior unlocks

### Material Truth vs Crafting Context

- **Base materials are universal matter definitions.** Wood is still wood, iron is still iron, regardless of whether the final craft becomes a weapon, armor piece, shield, accessory, trinket, or ranged-support component.
- **Crafting context is a separate layer above material truth.** Context examples: weapon, armor, accessory, shield, trinket, ranged_support.
- **Material defines what matter contributes. Context defines what kind of object the player is attempting to build. Geometry/profile defines what the built object actually becomes.**

---

## COMBAT SYSTEM

### Core Combat Mechanics
- **Camera**: 3D OTS (over-the-shoulder) with zoom option
- **Attacks**: All are skillshots (including melee)
- **Hits**: Require actual spatial overlap; misses are real
- **I-frames**: Exist only on dedicated skills (usually mobility type)
- **Damage**: No flavor system for PvE baseline; flat damage vs flat defense

### Combat Resources

**HP** - Primary survivability pool

**Armor + Endurance**
- Armor = sum of defense stats on gear
- Endurance = core stat multiplying defense effectiveness
- Formula: (Defense) × (1 + Endurance/100) = Effective Defense

**Bubble-Shield** (Temporary HP)
- Flat value added on top of HP
- Uses 50% of defender's effective defense for mitigation
- Primarily from support skills and House effects

**Stamina**
- Visible bar (no numeric display)
- Consumed by: sprint, dodge, movement skills
- Regen: starts 2.0s after consumption, full in 10.0s
- Modified by food/buffs

**Cooldowns** - Skill-based resource (no mana/energy)

### Damage Calculation

```
(∑ Attack Mod) × (3 + 0.03×∑Power) + Base Attack = Attack Value
Attack × Skill Base × ∑%Damage Mods = Raw Damage
(∑Defense Mod) × (3 + ∑Endurance/100) + Base Defense = Raw Defense
Raw Defense × (1 - ∑%Damage Reduction) = True Defense
Raw Damage / True Defense = Damage Taken
```

**Base Attack** = 0.2 × Rank
**Base Defense** = 0.15 × Rank
**Base HP** = 0.1 × Rank

**Rank Scale:**  S=1200, A=800, B=600, C=350, D=200, E=120, F=50

### Crit System
- **Crit Chance**: 0-100% (0% = never, 100% = always)
- **Crit Damage**: Base +100% (2x), can scale very high (10x+)
- **Applies to**: Direct heals, skill damage (multi-hit rolls per hit)
- **Does NOT apply to**: DoTs, item damage, environmental damage

**CRITICAL PROFILE AUTHORITY:**
- Gameplay reads baked profiles instead of raw forge cells
- The baked Profile Atom contains gameplay-facing stats, capabilities, and handling outputs
- Raw cell data is for authoring only; resolved profile data is the source of truth

### Threat & Aggro
- **Threat Generation**:
  - Damage generates threat equal to damage dealt
  - Healing generates threat equal to healing output
  - Resurrection generates 250% base damage equivalent threat
- **Aggro Buff**:
  - +150% virtual threat (threat counts as 2.5× real damage)
  - Tanking is orchestrated threat management, not a binary button

### CC System (Crowd Control)

**CC Types**: Stun, Knockdown, Snare (airborne stun), Slow (airborne knockdown)

**Base Duration**: 3.0 seconds

**By Enemy Type**:
- **Normal Mobs**: CC works freely; cooldowns and skillshots are limiting
- **Elites**: Stun max 3 times, then immune; Knockdown immune; Slow reduced
- **Bosses**: CC only in explicit CC windows; multi-hit chains required (tunable 3-7 hits)

**Airborne Variants**:
- Stun skill while airborne = Snare (horizontal lock)
- Knockdown skill while airborne = Slow (daze)

### Downed / Death System

**Downed State**:
- HP reaches zero
- Visual grayscale; can look around
- No movement/skills
- UI: "Give Up" (return to hub) or "Request Res" (ping for revival)

**Bleedout**: 15 minutes downed = auto-return to town (counts as full death)

**Durability**:
- Downed: ~1.5% durability loss on equipped gear
- Full death: additional ~1.5% (total ~3%)
- Accessories don't break
- At 0 durability: item grants no stats, weapon auto-unequips, fallback "unnamed" kit used

**Return Scroll**:
- Cast time: 15 seconds (interrupted by damage, CC, movement, ability use)
- On success: creates 15m extraction zone for 60 seconds
- Entering zone triggers "Return?" prompt (persists 3 min AFK window)
- Can accept while downed

**Resurrection Scroll**:
- No out-of-combat restriction
- 4m AOE revive at current coordinates
- Accept window: 30 seconds
- Cooldown: 10 minutes (House of Prayer reduces to ~2m30s)

### Return Scroll Eligibility (Extraction Rules)

May ONLY start casting if ALL true:
1. NOT the primary target of any enemy
2. 40+ seconds since last hostile damage
3. 15+ seconds since last combat action

---

## STAT SYSTEM (ATOMIC)

### Atomic Stat IDs (What You Store on Gear)

**Note:**
- This section lists direct atomic stat IDs only.
- The full master ID universe also includes capability IDs, family IDs, elemental IDs, equipment-context IDs, and forge-intent IDs maintained in dedicated reference documents.
- This overview is not the sole naming authority for all gameplay IDs.

**OFFENSE**
- `atk_mod_flat` - Attack contribution from gear
- `power_flat` - Core offensive stat
- `dmg_pct_add` - Outgoing damage %
- `crit_chance_pct` - Crit chance (0.0-1.0)
- `crit_damage_bonus_add` - Adds to crit bonus (0.25 = +25%)

**DEFENSE**
- `def_mod_flat` - Defense contribution from gear
- `endurance_flat` - Core defensive multiplier
- `dmg_reduction_pct_add` - Incoming damage reduction %
- `hp_pct_add` - Max HP %
- `bubble_hp_flat` - Temporary HP pool

**MOVEMENT/SPEED**
- `move_speed_pct_add` - % movement speed
- `move_speed_flat_add` - Flat movement speed
- `aspd_pct_add` - Attack/cast speed

**STAMINA**
- `stamina_max_flat` - Pool size
- `stamina_regen_pct_add` - Regen speed
- `stamina_regen_delay_flat` - Delay before regen

**HEALING**
- `heal_power_flat` - Healing power points
- `heal_power_pct_add` - Healing multiplier
- `received_heal_pct_add` - Target's healing received

**THREAT**
- `threat_virtual_bonus_pct` - Bonus virtual threat contribution (tank bias / threat amplification)
- `threat_from_heal_coeff` - Coefficient for threat generated from healing
- `threat_from_res_coeff` - Coefficient for threat generated from resurrection effects

**UTILITY / DURATION**
- `buff_duration_pct_add` - Buff duration bonus
- `bubble_duration_pct_add` - Bubble / temporary shield duration bonus
- `dot_duration_pct_add` - Damage-over-time duration bonus
- `cooldown_rate_pct_add` - Cooldown rate modifier (balance-sensitive; optional future)

---

## ECONOMY & TRADING

### Currency
- Single currency: Copper / Silver / Gold (with denomination conversions)
- Player-to-player barter encouraged and culturally supported

### Trading Tiers
- **Raw Drops**: Fully tradeable
- **Processed Mats**: Untradeable until finalized into an item
- **Finalized Items**: Tradeable with rules

### Trade Limits
- Crafted gear can have limited trades before binding (exact count TBD)
- Creator's first sale may not count against limit

### Provenance & Blueprint System
- Items traceable: "designed by @playername" permanently attached
- Ownership history recorded
- Blueprint extraction: sacrifice finalized item → get blueprint + creator tag retained
- Blueprints: skills cannot be modified, only material quality can be upgraded
- Intent: creators sell "designs," buyers invest rare materials

### NPC Daily Limits
- Scrolls and potions have daily purchase limits (scope: character vs account TBD)
- Restock resets daily at fixed universal time
- No banking: missed day = missed opportunity

### Prices (Placeholder)
- Resurrection Scroll: 50 silver
- Return Scroll: 1 gold 80 silver
- Repair: 1 gold per component

---

## SEASONS & PROGRESSION

### Seasonal System
- **Frequency**: Every ~3 months
- **Reset List**: Floor numbers, leaderboards, first clear races
- **Preservation**: Player crafted items, knowledge, reputation remains

### Quest & Contract Systems

**Quest Board (NPC)**:
- Ranks: F → E → D → C → B → A → S
- Higher ranks unlock via quest completion thresholds
- Better rewards/odds for higher ranks

**Player Contracts** (matchmaking as quests):
- "Help me kill X boss / clear objective"
- "Escort/Guide me (exploration + protection)"
- "Bring X items/materials"
- "Commission craft" (design/service fees)
- Can be used as party board / farm queue

**Escrow System**:
- Rewards deposited up-front into system escrow
- Auto-pays on completion
- Expired/cancelled contracts return escrow minus fee
- Prevents scams; logs available for disputes

---

## HOUSES (FACTIONS / OATHS)

**Purpose**: Opt-in identity layer with passive bonuses + dedicated skill hotbar

**Current Houses**:
- **House of Prayer** - Support/healing; Bubble focus; reduces resurrection scroll cooldown
- **House of Might** - Physical single-target bias (stats + effects)
- **House of Wisdom** - Magic/elemental bias + perception (traps/markers)
- **House of Fortification** - Defense/stamina/anti-stagger + threat management

---

## MONETIZATION (F2P)

### Free-to-Play Model
- Premium feature bundle (cosmetics, convenience)
- Battlepass system
- Premium pass unlocks additional features

### Premium Feature Candidates
- Coordinate-based teleport logbook
- Imprintable teleport scrolls
- Cosmetic items
- Title/achievement cosmetics
- Battlepass cosmetics

### Anti-Cheat Integrity
- Money/premium features must be server-side validated (future architecture)

---

## CODEBASE ARCHITECTURE

### Naming Conventions (CRITICAL)

Must follow these patterns to prevent drift:

- `*Def` = Static definition (Resource class)
- `*Atom` = Smallest stored unit (data structure)
- `*State` = Mutable runtime state
- `*Instance` = Concrete owned thing in play/inventory
- `*Profile` = Baked/derived gameplay-facing result
- `*Resolver` = Pure rule logic (converts one layer to another)
- `*Service` = Orchestration / application layer (no scene ownership)
- `*Controller` = Scene/node behavior (Godot-specific)
- `*Registry` = Lookup table / index
- `*Factory` = Builds legal runtime objects from definitions/profiles

### Dependency Direction (LAW)

### ALLOWED DIRECTION:
```
Defs/Atoms → Models → Resolvers → Services → Runtime Controllers → Scenes/UI
```

### NOT ALLOWED:
- UI reading raw forge cells directly
- Controllers doing math locally
- Combat reading cells when Profile exists
- Forge tools writing to player state without going through services

### Save / Versioning Separation

- Save domains must remain separate from the start.
- At minimum, the project distinguishes between: player progress, seasonal memory/leaderboard state, Forge WIP objects, test-print state if retained, finalized items, and world/floor state.
- Save/version migration must be planned from day one so future updates do not corrupt earlier crafted items or progression.

### Modding Boundaries (Future)

- Modding support is planned in a controlled form.
- Modders may extend content, presentation, and data-driven definitions within allowed boundaries.
- Core combat formulas, authoritative validation, progression ownership, and protected economy/state systems remain locked.

### Project Folder Structure

```
res://
├── boot/               // App startup
├── core/               // Game rules (NO scene ownership)
│   ├── atoms/          // Smallest stored units
│   ├── defs/           // Static definition resources
│   ├── models/         // Runtime data containers
│   ├── resolvers/      // Pure rule logic
│   ├── registries/     // Lookup tables
│   └── constants/      // Global constants
├── services/           // Orchestration layer
├── runtime/            // Godot node behavior
│   ├── player/
│   ├── combat/
│   ├── forge/
│   ├── world/
│   ├── enemies/
│   └── ui_bridge/
├── scenes/             // Composition only
├── data/               // .tres content resources
├── saves/              // Separated persistence domains
├── net/                // Networking (future)
├── mods/               // Mod support (future)
└── tools/              // Editor tools / validators
```

### Implementation Phases

**Phase 1 - Definitions & Models (in progress)**
- All Def classes
- All Atom classes
- Core Model classes

**Phase 2 - Resolvers (in progress)**
- Pure rule logic converters
- Stat aggregation
- Profile generation

**Phase 3 - Services (NOT STARTED)**
- Processing service
- Crafting service
- Testing service
- Naming service
- Equipment service

**Phase 4 - Runtime Controllers (BARELY STARTED)**
- Player controllers
- Forge controllers
- Combat controllers
- World controllers

**Phase 5 - Scenes & UI (NOT STARTED)**
- Scene composition
- UI layouts
- HUD systems
- Menus

**Note:** Phase completion percentages are omitted to prevent stale tracking. Update architecture and progress markers as implementation evolves.

---

## CURRENT CODEBASE STATUS (SNAPSHOT AS OF 2026-03-21)

### Implemented (20 script files)

**Atoms** (5):
- `stat_line.gd`, `cell_atom.gd`, `layer_atom.gd`, `segment_atom.gd`, `anchor_atom.gd`

**Defs** (5):
- `base_material_def.gd`, `material_variant_def.gd`, `tier_def.gd`, `process_rule_def.gd`, `raw_drop_def.gd`

**Models** (4):
- `crafted_item_wip.gd`, `baked_profile.gd`, `behavior_template.gd`, `forge_material_stack.gd`

**Resolvers** (5):
- `tier_resolver.gd`, `process_resolver.gd`, `segment_resolver.gd`, `anchor_resolver.gd`, `profile_resolver.gd`

**Runtime** (1):
- `forge_grid_controller.gd`

### Resources (2):
- `iron.tres`, `wood.tres`

---

## CORE PHILOSOPHY (PIN TO WALL)

**Author in atoms, resolve into profile, play from baked state.**

This is the foundational law. Raw crafting cells are authoring data. Gameplay must read baked profiles only. This separation prevents spaghetti and supports future mod systems, server authority, and separate save domains.

---

## OPEN DESIGN QUESTIONS

- Exact capability score formula weights
- Which anchors are mandatory per item type
- Minimum valid profile for projectile-capable gear
- How many elemental assignments per item
- How dual wielding modifies slot-role generation
- How much behavior tuning is freeform vs template-clamped
- Whether hidden outcome clusters derived or saved
- Salvage percentages by rarity
- Exact provenance fields on finalized items
- WIP versioning for test prints

---

## KEY FILES & REFERENCES

### Documentation Files
- `GDD v0.02 (Consolidated).txt` - Full game design
- `the GAME.txt` - Core philosophy
- `the GAME FEEL.txt` - Atmosphere design
- `Crafting Atoms v0.1a.txt` - Forge system details
- `THE_WILL_Math_and_Variables_Cheat_Sheet_v0.02b_atomic_first.txt` - Combat math
- `godot structure .txt` - Architecture skeleton
- `big w crafting.txt` - Material crafting pipeline

### Source Files Location
- Main Project: `c:\WORKSPACE\The Will- main folder\the-will-gamefiles\`
- Resources: `c:\WORKSPACE\GDD-and Text Resources\UPLOADED\`

---

## NEXT STEPS (Recommendations)

1. **Complete all Design Documentation** (You're ~95% there)
   - Finalize open questions list
   - Create exact material definition spec
   - Define all capability formula weights

2. **Complete Core/Defs Classes** (Following atomic-first order)
   - Implement remaining definition classes
   - Create resource instances for all materials
   - Set up stat ID registry

3. **Complete Services Layer** (Critical milestone)
   - Processing service
   - Crafting service
   - Testing service
   - Naming service
   - Equipment service

4. **Build First Playable Vertical Slice**
   - One floor + basic combat
   - One crafted weapon type
   - Hub navigation
   - Basic UI for feedback

5. **Iterate on Foundation** (Repeat until systems feel right)

---

**Project Owner**: You
**Architect**: Claude + You
**Status**: Locked Pre-Alpha Architecture
**Monetization**: F2P + Battlepass + Premium Pass
**Target**: Steam PC Platform
