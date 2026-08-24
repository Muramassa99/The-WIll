extends "res://runtime/forge_v2/forge_v2_workpiece_solid_engine.gd"

# Compatibility entry point for tools and the established focused benchmarks.
# The canonical implementation and production identity live under runtime/.
const PROOF_BACKEND_ID := &"chunked_labelled_solid_contact_locality_proof_v2"


# The established tools benchmark numbers operations after an untimed seed at
# revision zero. Keep that historical measurement contract isolated here;
# production uses revision one for its first accepted body.
func initialize_seed(body: Resource) -> Dictionary:
	var result := super.initialize_seed(body)
	if not bool(result.get("ok", false)):
		return result
	revision = 0
	result["revision"] = 0
	result["accepted_revision"] = 0
	return result
