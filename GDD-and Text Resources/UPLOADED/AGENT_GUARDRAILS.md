# THE WILL — Agent Guardrails

Hard rules:
- Do not invent core game rules that are not explicitly defined in project docs.
- Do not rename files, folders, classes, or IDs unless explicitly asked.
- Do not collapse distinct lifecycle objects into one generic type.
- Keep these separate:
  - raw drops
  - forge material stacks
  - crafted WIP
  - test prints
  - finalized items
- Gameplay must read baked profile/state, not raw forge cells.
- Materials are universal matter definitions.
- Equipment context is a separate layer.
- Fixed slot roles may exist, but do not invent visible class systems.
- When a rule is underspecified, leave TODO / NEEDS_DECISION instead of guessing.
- Prefer placeholders, stubs, and safe scaffolding over fake completion.
- Do not implement extra systems “for convenience.”
- Do not add polish, visuals, or content not required for the requested slice.

Output law:
- First show plan
- Then assumptions
- Then NEEDS_DECISION
- Then exact files to touch
- Then code

Architecture law:
- defs/atoms -> models -> resolvers -> services -> runtime controllers -> scenes/ui