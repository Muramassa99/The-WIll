# THE WILL — First Slice Decision Ledger

Approved first-slice laws:
- Scope: forge materials -> cells -> profiles -> test prints (sandbox only)
- Grid sizes:
  - design_target_size = 160x80x40
  - prototype_small_size = 20x10x5
  - prototype_medium_size = 40x20x10
- Connectivity: 6-neighbor only
- Mass: density-weighted
- Center of mass: density-weighted
- Test print mesh: MeshInstance3D + runtime-generated ArrayMesh
- No CSG in player-side forge/test-print pipeline
- WIP save format for v0.1: Godot Resource (.tres)
- One active test print at a time
- Same WIP may be re-baked and re-printed repeatedly
- Anchor validation in v0.1:
  - WIP may exist without anchors
  - handheld test print requires one valid primary grip
- Layers are workflow/edit structure, not direct physics multipliers
- Default raw drop -> forge material conversion = 1:6
- Material variants are generated in memory in v0.1 from BaseMaterialDef + TierDef
- CraftedItemWIP is a pure data container
- Baking lives in ProfileResolver + ForgeService
- Gameplay reads BakedProfile, not raw cells