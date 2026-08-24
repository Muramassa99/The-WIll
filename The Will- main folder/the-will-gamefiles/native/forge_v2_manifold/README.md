# Forge V2 native Manifold Add fast lane

This is the serial Manifold 3.3.2 GDExtension used by the Forge V2 presenter for
its strictly gated Add-material fast lane. It accepts only a fresh, connected,
same-material, explicit-profile Add/Replace sequence. Unsupported operations,
history mutations, mixed materials, and nonempty loaded workpieces continue
through the existing CSG implementation.

The extension exposes both the original stateless union proof API and the
stateful `clear_state` / `reset_mesh` / `add_mesh` API used by the presenter.
Publication remains revision-gated in Godot: a staged render mesh and collider
become authoritative only after the physics-ready handoff succeeds.

Subtract/Remove is intentionally not implemented by this lane yet.

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
