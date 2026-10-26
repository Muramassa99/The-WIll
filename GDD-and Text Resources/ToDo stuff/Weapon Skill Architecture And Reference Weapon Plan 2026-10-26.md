# Weapon skill architecture and reference weapon plan

Recorded: 2026-10-26, Europe/Bucharest.
Primary checklist entries: **SC-08** and **REF-01**. Related: SC-11, SC-13,
SC-09/10, COM-01/03/08, ENG-01/02 and UI-01/02.
Status: approved direction with unresolved design details; documentation and
read-only investigation only. The six-offensive/six-buff system is not implemented
by this note. The user has the game open as a reference; no new engine run occurred.

## Purpose and authority

Reduce the amount of manual attack-animation creation needed to finish a weapon.
The creator should be able to concentrate on fewer offensive skills instead of
spending multiple hours authoring the current full set. Keep the existing work
and expand the design into a reusable implementation brief.

The explicit decisions below supersede contradictory earlier directions on this
topic. Complementary older requirements are retained with sources. Historical
examples and unchosen mechanics remain identifiable; they are not automatically
part of the six selected buffs. Original source documents stay intact.

When the user later says to implement this note, recheck current owners, resolve
the relevant `NEEDS_DECISION` items and implement the selected slice. This note
does not authorize implementation merely because it describes future changes.

## Approved decisions from 2026-10-26

1. The twelve main skill positions are divided into **six offensive/damaging
   skills and six non-damaging applied buff skills**.
2. Their input allocation is fixed as follows:

   | Inputs | Existing slot IDs | Intended category |
   | --- | --- | --- |
   | `1 2 3 4 5 6` | `skill_slot_1` through `skill_slot_6` | Offensive/damaging skills |
   | `7 8 9 0 - =` | `skill_slot_7` through `skill_slot_12` | Non-damaging buff skills |
   | `Q` | Existing separate Block role | Stable default; retained |
   | `E` | Existing separate Evade role | Stable default; retained |

   This reduces offensive authoring work, while retaining twelve main skill
   positions. Q/E are not displaced into either six-slot group. These are gameplay
   bindings; they do not replace contextual Forge or Skill Crafter editing keys.
3. Choice and eligibility must reflect what can and cannot be used. The category
   allocation is decided; the exact available skill/buff choices and restrictions
   still need definition.
4. Buffs support **self use** and **beneficial AoE affecting party/raid members
   within range**. This is not a rule to affect every nearby character.
5. A party has a six-member grouping limit; raids combine groups of six. The
   maximum number of raid groups is not chosen here.
6. **Caster statistics determine buffing parameters.** The relevant statistics,
   formulas, values and evaluation timing still need definition.
7. The reference weapon is **parked until the user settles the future skill
   architecture**. Avoid creating a full skill set now that will need rework soon.
   Preserve the item and its existing skills; parking is not deletion or completion.

## What these decisions replace or clarify

| Earlier material | Current interpretation |
| --- | --- |
| Immediate reference-weapon work and an at-least-three-usable-skills milestone in the master TODO / latest SPS | Parked by the user. Reconfirm the useful reference set after the architecture is settled. |
| Roadmap instruction to author a full set of weapon skills | Its eventual testing purpose survives; its immediate execution against the old arrangement does not. |
| Twelve main slots with an unallocated mix of role families | Now explicitly six offensive slots and six buff slots, with the input/ID mapping above. |
| April reference's `6 + 6` HUD layout | That was visual grouping. Today's six/six rule is functional allocation as well. |
| Early illustrative slots such as Primary / Secondary / Mobility / Defense | Not the new effect table; do not carry those numbered assignments over automatically. |
| Separate Q Block and E Evade | Explicitly retained as stable defaults by today's follow-up. |

The older references already included buff/support among possible roles. They
did **not** establish a completed twelve-damaging-attacks rule. Today's change
settles allocation and the intended authoring burden; do not rewrite history as
if every old slot had a finalized attack definition. [S1] [S2] [S3] [S4]

## Complementary requirements carried forward

### Skill role, expression and ownership

- Gameplay rules define a skill's permitted role/effects; animation expresses
  that role. Motion authoring must not independently invent damage, hit counts,
  buffs or legality. Slot rules can govern motion-node allowance, damage-instance
  allowance, movement and usage conditions; their actual limits remain undecided.
- Damage-side hit economy combines slot rules with weapon/material/build data
  and maps the resulting allowances onto authored strike segments. The six/six
  decision does not select arithmetic or balance coefficients. [S1] [S3] [S5]
- Existing authored weapon skills belong to their source item, retain their
  identity when hands change, and save/reopen with that item. Older paired-weapon
  and weapon-plus-shield design allows choosing usable skills from equipped
  sources. Preserve that existing attack-side contract. The precise ownership
  of the new buff family is still a decision; do not assume it must be stored or
  authored identically to an attack. [S6] [S7] [S8]
- Runtime legality works on effective/derived data rather than silently rewriting
  the authored chain. F preview and equipped playback should consume the same
  saved/prepared animation truth where applicable. R records node state; F includes
  the current final node; saving a selected skill does not rebake unrelated skills
  or idles. Current-pose entry and Reset's baseline remain separate. This category
  rework is not permission to dismantle that working lifecycle. [S8] [S9]

### Defaults, presentation and finalization

- Earlier design calls for simple editable defaults so basic item usability does
  not depend on the creator manually animating every skill. Developer starter
  skills use the same authoring system as player skills. Keep that goal; reconcile
  package contents with the new six/six categories. [S6]
- Earlier finalization intent supplies a suitable default skill set before
  Engraving if no custom set was authored. Category, form, material, balance and
  relevant qualifiers inform suitability. This remains design intent, not proof
  of an implemented default-content library. [S10]
- Skill descriptions, effects/sounds and later skill showcases remain relevant.
  Buff presentation has not been chosen: do not silently require six additional
  manually authored attack-style motion chains. Reuse common event/playback
  infrastructure where appropriate after the actual buff workflow is decided.
- Individual skill saving and final item packaging retain separate ownership.
  Engraving remains the finalization boundary for composition, skills, descriptions
  and visuals. The new buff data must eventually be accounted for in that product;
  its schema and ownership are not selected by this note. [S4] [S8] [S10]
- Future ranged waves, damage classifiers, material equations and defensive
  mechanics remain their own topics. The six/six allocation neither selects those
  features for a particular offensive slot nor cancels them. [S11]

### Reference item when work resumes

- Recorded workhorse: `Broken_Balde_v1`, WIP `player_wip_1792291462.519_14`.
- Its purpose is to exercise Forge V2 -> Skill Crafter -> saved/equipped use,
  later material/damage testing and finalization. Keep other valid handles/items
  as variation checks; do not hardcode the system to this item's geometry.
- Preserve creative flow: predictable controls, useful diagnostics, fewer
  unnecessary menu trips and continued editor/camera control where practical.
- The last recorded accepted normal test covered Skill 1 and Combat Idle, not a
  completed three-skill set. That acceptance is historical evidence, not a new
  runtime check today. The recorded reverse/two-hand/other-hand and isolated
  cold-source qualifications remain in their original task notes. [S4] [S12]

## Earlier buff/group information retained for reconciliation

These details were found in the original sources. They provide context and must
not silently become the chosen six buff effects or a completed combat formula.

- **Grouping:** `crafting and other` specifies parties of at most six, consistent
  with today. It also proposes five parties per raid frame (30 people) and five
  frames (150). Preserve those larger totals as historical proposals; today's
  groups-of-six decision does not ratify a raid cap or frame UI. [S13]
- **Healing areas:** older stationary healing-zone rules affect self/party
  recipients in range and determine caster-derived critical behavior at successful
  cast for that zone's lifetime. That is a specific healing-zone snapshot rule,
  not a blanket rule that every buff snapshots every stat. Its earlier absence of
  a separate unit cap does not settle every new buff's recipient count. [S13] [S14]
- **Temporary HP:** older notes describe a self/friendly temporary-HP bubble and
  material-derived duration scaling. The six-second duration is an example, not
  selected tuning for this architecture. No particular buff slot is assigned
  to the bubble. [S13]
- **Caster versus receiver:** historical healing math also includes received-
  healing modifiers on the target. Today's caster-owned buff parameters do not
  automatically delete separate receiver-side healing rules; reconcile them
  when defining an actual healing effect. [S15]
- **Effect definitions and applications:** the old math reference distinguishes
  base ability outputs/scaling/snapshot policy from applied `BuffInstance.stats[]`
  self/party modifiers. Preserve the conceptual distinction between an effect
  definition and its active application. Those historical type names are not a
  directive to create new classes with those names. [S15]
- The overview distinguishes delivery, origin, path, timing, contact, payload,
  motion and constraints. Payload examples include damage, healing, shielding
  and CC. This supports separate effect and motion responsibilities without
  prescribing a new engine architecture. [S16]

## Current code observed on 2026-10-26

Static inspection only; no game run or save modification. Paths below are
relative to `The Will- main folder/the-will-gamefiles`.

| Owner | Current observation and relevance |
| --- | --- |
| `core/models/player_skill_slot_state.gd` | Defines `skill_slot_1`...`skill_slot_12`, separate `skill_block` and `skill_evade`, and persistent assignments. The new numbered split is not encoded here. |
| `core/models/combat_animation_station_state.gd` | `get_authoring_skill_slot_ids()` returns the twelve numbered IDs plus Block. Evade's separate runtime ID is not added by this authoring method. Skill and idle drafts remain separate. |
| `runtime/combat/combat_animation_station_ui.gd` | `_refresh_skill_slot_selector()` creates the selector from that authoring list. Merely relabeling six buttons would not implement the buff rules. |
| `core/models/combat_animation_draft.gd` | Stores source/slot identity, motion nodes, prepared clip, timing, name and description. The inspected schema does not supply the new buff targeting/parameter contract. |
| `core/models/skill_slot_assignment.gd` | An assignment records slot, source weapon WIP, source draft and display name. Future buff ownership must be reconciled with this existing lookup. |
| `runtime/player/player_equipped_skill_slot_presenter.gd` | Assigns publishable drafts from equipped weapons, currently visiting right then left and skipping occupied slots. Runtime resolution follows source WIP -> station -> draft -> motion chain/prepared clip. This is current routing, not proof the historical player-choice loadout is complete. |
| `runtime/player/player_runtime_skill_playback_presenter.gd` | Owns action/entry/idle playback consumption. Future buff activation must use the appropriate effect path rather than being assumed to be an ordinary attack clip. |

The inspected slot/draft/routing owners do not implement the new six-offensive /
six-buff contract. This is a bounded observation, not a claim that every possible
effect hook throughout the project has been exhaustively audited. No slot IDs,
input bindings, Resources or existing skills were changed in this pass.

## Decisions still needed

| Decision | What must be specified before its implementation |
| --- | --- |
| Skill choices and eligibility | Which offensive skills/buffs can be selected, what restricts them, and which choices belong to a weapon package versus the equipped loadout. |
| Buff ownership | Weapon, character or another owner; source identity, selection and saved data location. Existing weapon-owned attacks do not settle this automatically. |
| Buff authoring | How a creator chooses/configures a buff, whether it needs an animation, and how its presentation is obtained without recreating the twelve-animation workload. |
| Actual effects | Identities and allowed outputs of the six buff slots and the detailed offensive slot rules. No old example is automatically one of the selected effects. |
| Caster parameters | Which stats control which parameters, formulas/limits, and cast-time snapshot versus live evaluation. |
| Recipients and range | Per-effect self/AoE choice, applicable party/raid membership, range origin/shape, evaluation time, entering/leaving range and recipient caps if any. |
| Effect lifetime | Duration, cooldown/cost, stacking/refresh/replacement and interruption behavior; none was specified today. |
| Defaults | Required default content/selection for each category and what makes an item usable before custom authoring or Engraving. |
| Reference restart | When architecture is settled enough to resume, which skills demonstrate it and how to define the reference item's completion. The old three-skill threshold is not today's instruction to author three attacks. |

Q/E role retention and the twelve-slot category mapping are **decided**, not
open questions. Existing game work is preserved while the remaining decisions
are developed. This note does not request a save migration, slot deletion or
rewrite of the user's existing authored skills.

## Later implementation scope and acceptance

Use the existing authoritative model -> resolver/service -> runtime -> UI
direction. Keep shared `.tres` definitions immutable at runtime and active effect
state separate from definitions. Inspect actual owners again before choosing
files; the table above is a starting map, not a required rewrite list.

Once the necessary decisions are supplied:

- Implement category/eligibility rules and the selected buff definition,
  application and persistence ownership; make editor and runtime consume the
  same rules.
- Expose the agreed six offensive slots and six buff slots on their assigned
  inputs, retaining Q/E defaults and contextual editor bindings.
- Provide the chosen buff workflow so completing a weapon actually requires
  fewer manually authored attacks, rather than merely changing slot labels.
- Preserve R/F/Save/reopen/equipped behavior for existing offensive skills and
  independent idle/entry ownership. Add only the effect/presentation work required
  by the chosen buff contract.
- Validate self/group eligibility, groups of six, range behavior and caster-stat
  parameter changes against the rules selected above. Non-damaging buff slots
  must not accidentally execute an offensive damage event; any damage-output
  modifier granted by a buff needs its own explicitly chosen effect rule.
- Verify persistence, source ownership and equipped selection for the agreed
  families, then reconfirm the reference-item milestone with the user.

This pass does not start damage equations, a full multiplayer party system,
new defensive moves, final packaging, visual polish or reference-skill authoring.
Those dependencies remain linked tasks whose relevant interfaces must be
considered when the selected implementation slice is defined.

## Sources and reconciliation trail

The research searched SPS and task notes, plus the original/root and UPLOADED
design material, for reference-item, slot/role, buff, party/raid and related
authoring/default requirements. Matching relevant sections were read; this is
not a claim of a fresh whole-project code or runtime audit. Line anchors below
describe the source versions examined on this date.

- **S1:** [Skill system consolidated reference](<../UPLOADED/SKILL_SYSTEM_CONSOLIDATED_REFERENCE_2026-04-12.md>), sections 2.1-2.2.1 (ownership/IDs), 2.7 (HUD), 3.8-3.9.1 (roles/data authority), 8 (undefined effect table).
- **S2:** [Early creation process](<../UPLOADED/The creation process.txt>), lines 112-131: illustrative four-role example, not a final twelve-slot table.
- **S3:** [Combat Editor Original Intent Digest](<Combat Editor Original Intent Digest 2026-04-30.md>), section 12 / lines 242-268: slot law and hit economy.
- **S4:** [Finished reference item and roadmap](<Finished Reference Item And Playable Game Roadmap TODO 2026-10-18.md>), reference-item, materials, Engraving and historical slot-reminder sections. Its immediate reference-work instruction is superseded above.
- **S5:** [Runtime Combat Editor Visual and System Addendum](<../Runtime Combat Editor Visual and System Addendum.md>), lines 99-130 and 172-186: slot/build/motion/collision responsibilities.
- **S6:** [Runtime Weapon-Owned Melee Skill Crafter 1](<../Runtime Weapon-Owned Melee Skill Crafter 1.md>), lines 48-65 and 139-168: ownership/loadout and editable defaults.
- **S7:** [Combat input and weapon handling specification](<../UPLOADED/PLAYER_COMBAT_INPUT_AND_WEAPON_HANDLING_WORKING_SPEC_2026-03-29.md>), lines 112-156: equipped-source skills and ownership across hands.
- **S8:** [Unified Skill Crafter TODO](<Skill Crafter Unified Implementation TODO 2026-04-30.md>), lines 769-805: weapon draft persistence/shared playback; lines 925-929 retain unresolved damage economics.
- **S9:** [Playback availability investigation](<Skill Crafter Playback Availability Investigation 2026-10-25.md>): current recording, selected saving and playback evidence; [2026-10-25 handoff](<../SPS/SPS_2026_10_25_23-04.md>): prior state, now superseded only where this note explicitly changes direction.
- **S10:** [Town/Gate/Floor/Forge authority](<../UPLOADED/TOWN_GATE_FLOOR_FORGE_AUTHORITY_SAVEPOINT_2026-03-23.md>), lines 682-695: default skill assignment before finalization; distinguish original intent from completed code.
- **S11:** [Melee ranged-wave concept](<melee_skill_crafter_ranged_wave_attacks.md>), lines 80-86 and 212-225: future slot eligibility/emission questions; not selected by this plan.
- **S12:** [Equipped Skill and Combat Idle repair](<Equipped Skill and Combat Idle Repair 2026-10-25.md>), reference identity and implementation/evidence/remaining-limits sections.
- **S13:** [Crafting and other](<../UPLOADED/crafting  and other.txt>), lines 10 (healing areas), 174-176 (group sizes), 229 (temporary HP and duration example).
- **S14:** [Consolidated GDD](<../UPLOADED/GDD v0.02 (Consolidated).txt>), lines 217-226: stationary healing-zone behavior.
- **S15:** [Math and variables reference](<../UPLOADED/THE_WILL_Math_and_Variables_Cheat_Sheet_v0.02b_atomic_first.txt>), lines 17-46 (ability/buff concepts), 92-109 and 238-248 (healing modifiers).
- **S16:** [Project overview](<../UPLOADED/PROJECT_OVERVIEW_AND_SCOPE - Copy.md>), lines 221-232: effect/delivery/motion vocabulary.
- **S17:** [2026-10-24 SPS](<../SPS/SPS_2026_10_24_02-39.md>), preview/storage roadmap: later previews and packaging remain related work; one-skill size evidence does not determine future six-buff storage cost.

Newest authority: the user's 2026-10-26 topic-expansion instructions, six/six
direction, reference-item parking and follow-up input allocation `123456`
offensive / `7890-=` buffs / stable Q/E defaults.
