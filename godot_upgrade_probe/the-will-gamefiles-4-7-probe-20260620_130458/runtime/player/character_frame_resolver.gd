extends RefCounted
class_name CharacterFrameResolver

# Project-facing convention:
# the visible character front is +Z in local/model space.
const MODEL_FORWARD_LOCAL := Vector3(0.0, 0.0, 1.0)

func resolve_basis_frame(global_basis: Basis) -> Dictionary:
	var basis: Basis = global_basis.orthonormalized()
	var forward_world: Vector3 = (basis * MODEL_FORWARD_LOCAL).normalized()
	if forward_world.length_squared() <= 0.000001:
		forward_world = MODEL_FORWARD_LOCAL
	return {
		"forward_world": forward_world,
		"right_world": basis.x.normalized(),
		"up_world": basis.y.normalized(),
	}

func resolve_basis_forward_world(global_basis: Basis) -> Vector3:
	var frame: Dictionary = resolve_basis_frame(global_basis)
	return frame.get("forward_world", MODEL_FORWARD_LOCAL) as Vector3

func get_default_forward_world() -> Vector3:
	return MODEL_FORWARD_LOCAL
