extends SceneTree

const ForgeV2PlacementTargetResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_placement_target_resolver.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2WorkspaceContractScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_contract.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_surface_target_infrastructure_2026-08-10.txt"
)

var result_lines: PackedStringArray = []


class StubPlacementTargetResolver:
	extends RefCounted

	var hybrid_result: Dictionary = {}
	var material_result: Dictionary = {}
	var plane_result: Dictionary = {}
	var last_query := StringName()

	func resolve_from_camera(
		_camera: Camera3D,
		_screen_position: Vector2,
		_workspace_node: Node3D,
		_workspace_contract,
		_ray_plane_epsilon: float
	) -> Dictionary:
		last_query = &"hybrid"
		return hybrid_result.duplicate(true)

	func resolve_material_surface_from_camera(
		_camera: Camera3D,
		_screen_position: Vector2,
		_workspace_node: Node3D,
		_workspace_contract
	) -> Dictionary:
		last_query = &"material_only"
		return material_result.duplicate(true)

	func resolve_placement_plane_from_camera(
		_camera: Camera3D,
		_screen_position: Vector2,
		_workspace_node: Node3D,
		_workspace_contract,
		_ray_plane_epsilon: float
	) -> Dictionary:
		last_query = &"plane_only"
		return plane_result.duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())

	var resolver = ForgeV2PlacementTargetResolverScript.new()
	var contract = ForgeV2WorkspaceContractScript.new()
	var resolver_workspace := Node3D.new()
	resolver_workspace.name = "SurfaceResolverWorkspace"
	root.add_child(resolver_workspace)
	var resolver_camera := Camera3D.new()
	resolver_camera.name = "SurfaceResolverCamera"
	resolver_camera.position = Vector3(0.0, 0.0, 2.0)
	resolver_camera.far = 8.0
	resolver_camera.current = true
	resolver_workspace.add_child(resolver_camera)
	await process_frame
	var screen_center := root.get_visible_rect().size * 0.5

	var material_miss: Dictionary = resolver.call(
		"resolve_material_surface_from_camera",
		resolver_camera,
		screen_center,
		resolver_workspace,
		contract
	)
	if not _check(
		not bool(material_miss.get("valid", true))
		and StringName(material_miss.get("target_kind", StringName()))
		== ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
		and StringName(material_miss.get(
			"surface_target_id",
			&"unexpected"
		)) == StringName(),
		"material-only miss silently fell back or omitted its empty target identity"
	):
		return
	result_lines.append("material_only_miss_has_no_plane_fallback=true")

	var plane_hit: Dictionary = resolver.call(
		"resolve_placement_plane_from_camera",
		resolver_camera,
		screen_center,
		resolver_workspace,
		contract,
		0.000001
	)
	if not _check(
		bool(plane_hit.get("valid", false))
		and StringName(plane_hit.get("target_kind", StringName()))
		== ForgeV2PlacementTargetResolverScript.TARGET_KIND_PLACEMENT_PLANE
		and StringName(plane_hit.get("surface_target_id", StringName()))
		== ForgeV2PlacementTargetResolverScript.SURFACE_TARGET_ID_PLACEMENT_PLANE,
		"plane-only query did not resolve the canonical placement plane"
	):
		return
	var hybrid_hit: Dictionary = resolver.call(
		"resolve_from_camera",
		resolver_camera,
		screen_center,
		resolver_workspace,
		contract,
		0.000001
	)
	if not _check(
		bool(hybrid_hit.get("valid", false))
		and StringName(hybrid_hit.get("surface_target_id", StringName()))
		== ForgeV2PlacementTargetResolverScript.SURFACE_TARGET_ID_PLACEMENT_PLANE,
		"existing material-first hybrid query no longer falls back to the plane"
	):
		return
	result_lines.append("plane_only_and_hybrid_plane_identity=true")

	var front_plane_hit: Dictionary = resolver.call(
		"_resolve_placement_plane",
		Vector3(0.0, 0.0, 2.0),
		Vector3.FORWARD,
		resolver_workspace,
		contract,
		0.000001
	)
	var back_plane_hit: Dictionary = resolver.call(
		"_resolve_placement_plane",
		Vector3(0.0, 0.0, -2.0),
		Vector3.BACK,
		resolver_workspace,
		contract,
		0.000001
	)
	var front_normal: Vector3 = front_plane_hit.get(
		"world_normal",
		Vector3.ZERO
	) as Vector3
	var back_normal: Vector3 = back_plane_hit.get(
		"world_normal",
		Vector3.ZERO
	) as Vector3
	var front_bc: Vector3 = front_plane_hit.get(
		"world_contact_direction",
		Vector3.ZERO
	) as Vector3
	var back_bc: Vector3 = back_plane_hit.get(
		"world_contact_direction",
		Vector3.ZERO
	) as Vector3
	if not _check(
		bool(front_plane_hit.get("valid", false))
		and bool(back_plane_hit.get("valid", false))
		and front_normal.is_equal_approx(Vector3.BACK)
		and back_normal.is_equal_approx(Vector3.BACK)
		and front_bc.is_equal_approx(Vector3.FORWARD)
		and back_bc.is_equal_approx(Vector3.BACK)
		and Vector3.BACK.dot(front_bc) <= 0.000001
		and Vector3.FORWARD.dot(back_bc) <= 0.000001,
		"placement-plane explicit B-C did not enforce ABC without mutating raw normal"
	):
		return
	result_lines.append("placement_plane_abc_angle_rule=true")

	var corrected_material_contact: Vector3 = resolver.call(
		"_resolve_world_contact_direction_for_abc",
		Vector3(0.0, 0.0, 2.0),
		Vector3.ZERO,
		Vector3.BACK,
		Vector3.FORWARD
	) as Vector3
	if not _check(
		corrected_material_contact.is_equal_approx(Vector3.FORWARD)
		and Vector3.BACK.dot(corrected_material_contact) <= 0.000001,
		"material surface did not select explicit B-C in the valid ABC hemisphere"
	):
		return
	result_lines.append("material_explicit_bc_abc_hemisphere_selection=true")

	var parallel_plane: Dictionary = resolver.call(
		"_resolve_placement_plane",
		Vector3.ZERO,
		Vector3.RIGHT,
		resolver_workspace,
		contract,
		0.000001
	)
	if not _check(
		not bool(parallel_plane.get("valid", true))
		and StringName(parallel_plane.get("surface_target_id", StringName()))
		== ForgeV2PlacementTargetResolverScript.SURFACE_TARGET_ID_PLACEMENT_PLANE,
		"invalid placement-plane result lost its canonical target identity"
	):
		return
	result_lines.append("invalid_plane_retains_canonical_identity=true")

	var workspace_preview: Node3D = ForgeV2WorkspacePreviewScript.new()
	root.add_child(workspace_preview)
	await process_frame
	var stub_resolver := StubPlacementTargetResolver.new()
	var locked_zone_id := &"forge_v2_surface_zone_locked"
	stub_resolver.material_result = {
		"valid": true,
		"target_kind": ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
		"surface_target_id": locked_zone_id,
		"local_position": Vector3(0.1, 0.2, 0.3),
		"local_normal": Vector3.UP,
	}
	stub_resolver.hybrid_result = stub_resolver.material_result.duplicate(true)
	stub_resolver.plane_result = {
		"valid": true,
		"target_kind": ForgeV2PlacementTargetResolverScript.TARGET_KIND_PLACEMENT_PLANE,
		"surface_target_id": (
			ForgeV2PlacementTargetResolverScript.SURFACE_TARGET_ID_PLACEMENT_PLANE
		),
		"local_position": Vector3(0.1, 0.2, 0.0),
		"local_normal": Vector3.FORWARD,
	}
	workspace_preview.set("placement_target_resolver", stub_resolver)
	var locked_match: Dictionary = workspace_preview.call(
		"resolve_strict_surface_target",
		screen_center,
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
		locked_zone_id
	)
	if not _check(
		bool(locked_match.get("valid", false))
		and stub_resolver.last_query == &"material_only",
		"strict surface target rejected an exact kind/identity match"
	):
		return
	var locked_id_mismatch: Dictionary = workspace_preview.call(
		"resolve_strict_surface_target",
		screen_center,
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
		&"forge_v2_surface_zone_other"
	)
	if not _check(
		not bool(locked_id_mismatch.get("valid", true))
		and StringName(locked_id_mismatch.get("reject_reason", StringName()))
		== ForgeV2WorkspacePreviewScript.REJECT_SURFACE_TARGET_ID_MISMATCH
		and StringName(locked_id_mismatch.get("surface_target_id", StringName()))
		== locked_zone_id,
		"strict surface identity mismatch was not explicit or lost the actual hit"
	):
		return
	var locked_plane: Dictionary = workspace_preview.call(
		"resolve_strict_surface_target",
		screen_center,
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_PLACEMENT_PLANE,
		ForgeV2PlacementTargetResolverScript.SURFACE_TARGET_ID_PLACEMENT_PLANE
	)
	if not _check(
		bool(locked_plane.get("valid", false))
		and stub_resolver.last_query == &"plane_only"
		and StringName(locked_plane.get("target_kind", StringName()))
		== ForgeV2PlacementTargetResolverScript.TARGET_KIND_PLACEMENT_PLANE,
		"locked placement plane was intercepted by the hybrid material result"
	):
		return
	var unlocked_hybrid: Dictionary = workspace_preview.call(
		"resolve_strict_surface_target",
		screen_center,
		StringName(),
		StringName()
	)
	if not _check(
		bool(unlocked_hybrid.get("valid", false))
		and stub_resolver.last_query == &"hybrid"
		and StringName(unlocked_hybrid.get("target_kind", StringName()))
		== ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
		"unlocked first surface target did not retain hybrid material-first routing"
	):
		return
	var locked_kind_mismatch: Dictionary = workspace_preview.call(
		"resolve_strict_surface_target",
		screen_center,
		&"target_unrecognized",
		StringName()
	)
	if not _check(
		not bool(locked_kind_mismatch.get("valid", true))
		and StringName(locked_kind_mismatch.get("reject_reason", StringName()))
		== ForgeV2WorkspacePreviewScript.REJECT_SURFACE_TARGET_KIND_MISMATCH,
		"strict surface kind mismatch was not explicit"
	):
		return
	result_lines.append("strict_target_lock_match_and_mismatch=true")
	result_lines.append("locked_plane_uses_plane_only_query=true")

	var projection: Dictionary = workspace_preview.call(
		"project_workspace_local_to_screen",
		Vector3.ZERO
	)
	if not _check(
		bool(projection.get("valid", false))
		and projection.get("screen_position", null) is Vector2,
		"workspace-local point could not be projected through the preview camera"
	):
		return
	result_lines.append("workspace_local_projection=true")

	var presenter: Node3D = ForgeV2VolumePreviewPresenterScript.new()
	root.add_child(presenter)
	await process_frame
	var zone_key := "material_iron:body_a,body_b"
	var zone_target_id: StringName = presenter.call(
		"_build_zone_surface_target_id",
		zone_key
	)
	var repeated_zone_target_id: StringName = presenter.call(
		"_build_zone_surface_target_id",
		zone_key
	)
	var other_zone_target_id: StringName = presenter.call(
		"_build_zone_surface_target_id",
		"material_iron:body_a,body_c"
	)
	if not _check(
		zone_target_id != StringName()
		and zone_target_id == repeated_zone_target_id
		and zone_target_id != other_zone_target_id,
		"connected-zone target identity was not deterministic and zone-specific"
	):
		return
	var zone_node: CSGCombiner3D = presenter.call(
		"_build_csg_zone_node",
		{
			"zone_key": zone_key,
			"surface_target_id": zone_target_id,
			"material_variant_id": &"material_iron",
			"primary_body_ids": [&"body_a", &"body_b"],
			"body_records": [],
		},
		true,
		"VerifyZone"
	) as CSGCombiner3D
	if not _check(
		zone_node != null
		and StringName(zone_node.get_meta(
			"forge_v2_surface_target_id",
			StringName()
		)) == zone_target_id
		and StringName(zone_node.get_meta(
			"forge_v2_material_variant_id",
			StringName()
		)) == &"material_iron"
		and zone_node.has_meta("forge_v2_body_id")
		and not zone_node.calculate_tangents,
		"zone CSG node did not carry stable surface/material/body metadata"
	):
		return
	zone_node.free()
	var spline_csg := presenter.get_node_or_null("SplineCsgNoodle") as CSGPolygon3D
	if not _check(
		spline_csg != null and not spline_csg.calculate_tangents,
		"authoring spline CSG still calculates unused tangents"
	):
		return
	result_lines.append("static_zone_metadata_and_csg_tangent_policy=true")

	_finish(true)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_finish(false, message)
	return false


func _finish(passed: bool, message: String = "") -> void:
	var output_lines := PackedStringArray([
		"ok=true" if passed else "ok=false",
	])
	output_lines.append_array(result_lines)
	if not passed:
		output_lines.append("failure=%s" % message)
	var result_file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if result_file != null:
		result_file.store_string("\n".join(output_lines) + "\n")
	if passed:
		print("FORGE_V2_SURFACE_TARGET_INFRASTRUCTURE_VERIFY: PASS")
		quit()
		return
	push_error(
		"FORGE_V2_SURFACE_TARGET_INFRASTRUCTURE_VERIFY: FAIL: %s" % message
	)
	quit(1)
