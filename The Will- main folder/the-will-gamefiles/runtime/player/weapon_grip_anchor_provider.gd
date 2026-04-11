extends RefCounted
class_name WeaponGripAnchorProvider

const PRIMARY_GRIP_ANCHOR_NAME := "PrimaryGripAnchor"
const SUPPORT_GRIP_ANCHOR_NAME := "SupportGripAnchor"
const PRIMARY_GRIP_BASIS_ANCHOR_NAME := "PrimaryGripBasisAnchor"
const SUPPORT_GRIP_BASIS_ANCHOR_NAME := "SupportGripBasisAnchor"

func ensure_grip_anchor_nodes(
	held_root: Node3D,
	primary_guide: Node3D,
	secondary_guide: Node3D
) -> void:
	if held_root == null:
		return
	_ensure_anchor_from_guide(held_root, primary_guide, PRIMARY_GRIP_ANCHOR_NAME, PRIMARY_GRIP_BASIS_ANCHOR_NAME)
	_ensure_anchor_from_guide(held_root, secondary_guide, SUPPORT_GRIP_ANCHOR_NAME, SUPPORT_GRIP_BASIS_ANCHOR_NAME)

func get_primary_grip_anchor(held_item: Node3D) -> Node3D:
	return held_item.get_node_or_null(PRIMARY_GRIP_ANCHOR_NAME) as Node3D if held_item != null else null

func get_support_grip_anchor(held_item: Node3D) -> Node3D:
	return held_item.get_node_or_null(SUPPORT_GRIP_ANCHOR_NAME) as Node3D if held_item != null else null

func get_primary_grip_basis_anchor(held_item: Node3D) -> Node3D:
	if held_item == null:
		return null
	var basis_anchor: Node3D = held_item.get_node_or_null(PRIMARY_GRIP_BASIS_ANCHOR_NAME) as Node3D
	return basis_anchor if basis_anchor != null else get_primary_grip_anchor(held_item)

func get_support_grip_basis_anchor(held_item: Node3D) -> Node3D:
	if held_item == null:
		return null
	var basis_anchor: Node3D = held_item.get_node_or_null(SUPPORT_GRIP_BASIS_ANCHOR_NAME) as Node3D
	return basis_anchor if basis_anchor != null else get_support_grip_anchor(held_item)

func _ensure_anchor_from_guide(
	held_root: Node3D,
	source_guide: Node3D,
	anchor_name: String,
	basis_anchor_name: String
) -> void:
	if held_root == null or source_guide == null:
		return
	var grip_anchor: Node3D = held_root.get_node_or_null(anchor_name) as Node3D
	if grip_anchor == null:
		grip_anchor = Node3D.new()
		grip_anchor.name = anchor_name
		held_root.add_child(grip_anchor)
	grip_anchor.transform = source_guide.transform
	var basis_anchor: Node3D = grip_anchor.get_node_or_null(basis_anchor_name) as Node3D
	if basis_anchor == null:
		basis_anchor = Node3D.new()
		basis_anchor.name = basis_anchor_name
		grip_anchor.add_child(basis_anchor)
	_configure_basis_anchor_from_guide(basis_anchor, source_guide)

func _configure_basis_anchor_from_guide(basis_anchor: Node3D, source_guide: Node3D) -> void:
	if basis_anchor == null:
		return
	basis_anchor.transform = Transform3D.IDENTITY
	basis_anchor.set_meta("grip_basis_valid", false)
	if source_guide == null:
		return
	var grip_center: Node3D = source_guide.get_node_or_null("GripShellCenter") as Node3D
	if grip_center == null:
		grip_center = source_guide
	var major_axis_local: Vector3 = grip_center.get_meta("grip_shell_major_axis_local", Vector3.ZERO) as Vector3
	var minor_axis_a_local: Vector3 = grip_center.get_meta("grip_shell_minor_axis_a_local", Vector3.ZERO) as Vector3
	var minor_axis_b_local: Vector3 = grip_center.get_meta("grip_shell_minor_axis_b_local", Vector3.ZERO) as Vector3
	if major_axis_local.length_squared() <= 0.000001:
		return
	if minor_axis_a_local.length_squared() <= 0.000001:
		return
	if minor_axis_b_local.length_squared() <= 0.000001:
		return
	var handle_axis: Vector3 = major_axis_local.normalized()
	var profile_right: Vector3 = minor_axis_a_local.normalized()
	var profile_up: Vector3 = minor_axis_b_local.normalized()
	var corrected_forward: Vector3 = handle_axis.normalized()
	var corrected_right: Vector3 = (profile_right - corrected_forward * profile_right.dot(corrected_forward)).normalized()
	if corrected_right.length_squared() <= 0.000001:
		return
	var corrected_up: Vector3 = corrected_forward.cross(corrected_right).normalized()
	if corrected_up.length_squared() <= 0.000001:
		corrected_up = profile_up.normalized()
	if corrected_up.length_squared() <= 0.000001:
		return
	corrected_right = corrected_up.cross(corrected_forward).normalized()
	var basis := Basis(corrected_right, corrected_up, corrected_forward).orthonormalized()
	basis_anchor.transform = Transform3D(basis, Vector3.ZERO)
	basis_anchor.set_meta("grip_basis_valid", true)
	basis_anchor.set_meta("grip_basis_major_axis_local", handle_axis)
	basis_anchor.set_meta("grip_basis_minor_axis_a_local", corrected_right)
	basis_anchor.set_meta("grip_basis_minor_axis_b_local", corrected_up)
