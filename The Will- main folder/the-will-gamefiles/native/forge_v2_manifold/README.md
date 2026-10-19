# Forge V2 native Manifold bounded Boolean lane

This is the serial Manifold 3.3.2 GDExtension used by the Forge V2 presenter for
its gated single-material ordinary geometry lane. The backend supports
chronological Add and Remove with a protected Handle composed separately.
The presenter owns eligibility; this backend does not choose material policy.

The extension exposes both the original stateless union proof API and the
stateful `clear_state` / `reset_mesh` / `add_mesh` / `subtract_mesh` API.
Publication remains revision-gated in Godot: a staged render mesh and collider
become authoritative only after the physics-ready handoff succeeds.

Enable history before initial authoring to retain S0 plus five operations.
Both Add and Remove append one operation, including a valid no-op cut. Promotion
retains the already computed solid, without another Boolean or mesh export.
Validation and export finish before replacement history is committed. Invalid
operands leave geometry, revision, history, and counters unchanged.

Successful geometry packets explicitly report `empty`; valid empty output has
empty packed vertex/index/provenance arrays and zero counts/volume. An erased
solid remains `state_initialized=true`, with `state_empty=true`. Continue it with
Add/Remove, not reset_mesh. An opted-in blank S0 also accepts Add/Remove, allowing
a branch after Undo to empty without discarding history. Empty operands remain
invalid; an empty *result* is valid.

`reset_checkpoint_mesh(empty_vertices, empty_indices, operation_count)` restores
an empty prefix even when earlier operations have accumulated. A positive count
keeps the empty prefix initialized. Undo/Redo and protected Handle composition
preserve this empty-state contract. Native provenance IDs identify input surfaces,
not material ownership: new cut faces are ordinary solid material, not VOID.

Focused verifier: `tools/verify_forge_v2_native_remove_history.gd`.

Dependencies are pinned outside the game project under
`C:/WORKSPACE/helper applications/cpp-dependencies`.

Configure and build from the portable toolchain shell:

```powershell
cmake -S native/forge_v2_manifold `
  -B "C:/WORKSPACE/helper applications/cpp-build/forge-v2-manifold" `
  -G Ninja `
  -DCMAKE_TOOLCHAIN_FILE="C:/WORKSPACE/helper applications/cpp-toolchain/llvm-mingw-x86_64.cmake" `
  -DCMAKE_BUILD_TYPE=Release
cmake --build "C:/WORKSPACE/helper applications/cpp-build/forge-v2-manifold" `
  --target forge_v2_manifold --parallel 4
```
