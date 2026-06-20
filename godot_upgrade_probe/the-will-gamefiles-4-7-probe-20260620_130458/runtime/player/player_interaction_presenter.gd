extends RefCounted
class_name PlayerInteractionPresenter

func try_interact(
	interaction_raycast: RayCast3D,
	camera: Camera3D,
	player_global_position: Vector3,
	interaction_distance: float,
	scene_tree: SceneTree,
	interacting_player
) -> void:
	if interaction_raycast == null:
		return
	interaction_raycast.force_raycast_update()

	var interactable: Object = null
	if interaction_raycast.is_colliding():
		interactable = resolve_interactable(interaction_raycast.get_collider())
	if interactable == null:
		interactable = find_nearby_interactable(camera, player_global_position, interaction_distance, scene_tree)
	if interactable != null:
		interactable.call("interact", interacting_player)

func resolve_interactable(candidate: Object) -> Object:
	var current: Object = candidate
	while current != null:
		if current.has_method("interact"):
			return current
		if current is Node:
			current = (current as Node).get_parent()
			continue
		break
	return null

func find_nearby_interactable(
	camera: Camera3D,
	player_global_position: Vector3,
	interaction_distance: float,
	scene_tree: SceneTree
) -> Object:
	if camera == null or scene_tree == null:
		return null
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best_candidate: Node3D = null
	var best_distance: float = interaction_distance + 0.75
	for candidate_node: Node in scene_tree.get_nodes_in_group("interactable"):
		if not candidate_node is Node3D:
			continue
		var candidate: Node3D = candidate_node
		var to_candidate: Vector3 = candidate.global_position - player_global_position
		var distance: float = to_candidate.length()
		if distance > best_distance:
			continue
		var flat_direction: Vector3 = to_candidate
		flat_direction.y = 0.0
		if not flat_direction.is_zero_approx() and forward.dot(flat_direction.normalized()) < 0.2:
			continue
		best_candidate = candidate
		best_distance = distance
	return best_candidate
