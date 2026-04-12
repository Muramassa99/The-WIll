Reformulate the current beveling/chamfer and fillet behavior as local patch reconstruction, not direct shell deformation.

Godot 4.6 implementation base:
- MeshDataTool = inspect/read/edit current local topology (faces, edges, vertices)
- SurfaceTool = rebuild modified local patch geometry
- ArrayMesh = commit rebuilt patch mesh output

Do not implement bevel/chamfer or fillet by simply moving the current shell vertices inward.
That causes paper-like collapse, stretched faces, bad angles, and side-wide deformation.

Implement them as profile-replacement patch operations.

GENERAL LAW
1. Isolate only the affected local shell patch.
2. Read current local patch topology.
3. Identify the two contributing surface regions that form the sharp transition.
4. Generate the new transition profile geometry.
5. Detect and resolve overlap inside the patch.
6. Rebuild the local patch as new geometry.
7. Regenerate normals.
8. Commit the rebuilt patch as the new current shell truth.

CHAMFER / BEVEL METHOD
Purpose:
Replace a sharp angle with a planar transition strip.

Implementation wording:
- Resolve the local patch around the selected sharp transition.
- Resolve the two contributing surface regions, side A and side B.
- Compute chamfer depth.
- Create one new boundary line on side A and one new boundary line on side B at the requested depth.
- The original sharp corner region is no longer preserved as-is.
- Replace that region with a new planar strip between the two new boundary lines.
- If collapse from both sides creates overlapping geometry, detect it and trim/fuse it into one continuous surface.
- Rebuild the patch geometry so the untouched surrounding shell remains connected to the new chamfer strip.
- Regenerate normals and commit.

Important:
A chamfer is not “push old faces inward.”
A chamfer is “replace the sharp corner with a new planar transition band.”

FILLET METHOD
Purpose:
Replace a sharp angle with a rounded segmented transition.

Implementation wording:
- Resolve the local patch around the selected sharp transition.
- Resolve the two contributing surface regions, side A and side B.
- Compute fillet radius and segment count.
- Generate multiple intermediate transition bands/rings between side A and side B.
- Each intermediate band is part of the rounded profile.
- The original sharp corner region is replaced by this segmented rounded transition.
- If inward collapse creates overlapping geometry, detect and trim/fuse it into one continuous rounded surface.
- Rebuild the patch geometry so the untouched surrounding shell remains connected to the new rounded transition.
- Regenerate normals and commit.

Important:
A fillet is not “smooth the old corner.”
A fillet is “replace the sharp corner with a new rounded transition made of multiple generated bands.”

OVERLAP RULE
For both chamfer and fillet:
- overlapping collapsed regions are expected
- overlap is not left as stacked material
- overlap must be fused/trimmed into one valid continuous patch surface
- no visible gaps
- no doubled shell artifacts
- no folded receipt/card-tower behavior

SUCCESS CONDITION
The final result must behave like:
- one continuous welded local patch
- no paper-like collapse
- no whole-side deformation from a local edit
- correct visible planar chamfer
- correct visible rounded fillet
- rebuilt geometry becomes the new current shell truth

This is not a direct deformation problem.
It is a local topology replacement problem.