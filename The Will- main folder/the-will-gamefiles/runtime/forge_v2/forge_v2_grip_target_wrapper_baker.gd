extends RefCounted

## Save-time target geometry only. The authoritative material mesh is never
## replaced. Skill Crafter slices these static triangles; no CSG survives bake.
## Godot 4.7 CSGShape3D.bake_static_mesh requires deferred mesh readiness.
const Wrapper = preload("res://core/models/prepared_grip_target_wrapper.gd")
const Validation = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Progression = preload("res://runtime/player/grip/planar_grip_guide_progression.gd")
const PROFILE_ORIGIN := Wrapper.PROFILE_ORIGIN_ID
const READINESS_FRAME_LIMIT := 120


func bake(presenter: Node3D, body: Resource, handle_packet: Dictionary, config: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not is_instance_valid(presenter) or not presenter.is_inside_tree() or body == null:
		return _fail("missing_wrapper_bake_owner_or_handle")
	var settings: Dictionary = Validation.validate_config(config)
	if not settings.get("valid", false): return _fail(String(settings.error))
	var normalized: Dictionary = settings.config
	var physical: Dictionary = HandlePacket.validate(handle_packet)
	if not physical.get("valid", false): return _fail(String(physical.error))
	var body_signature := HandlePacket.build_body_signature(body)
	if body_signature != String(physical.body_signature): return _fail("wrapper_source_body_mismatch")
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if polygon.size() < 3: return _fail("wrapper_source_profile_missing")
	# Arithmetic centre in the authored profile coordinates, not a new weapon
	# placement. The existing CSG path frames map this profile to WeaponRootOrigin.
	var center := Vector2.ZERO
	for point: Vector2 in polygon: center += point / float(polygon.size())
	var progression := Progression.new()
	var prepared: Dictionary = progression.prepare(polygon, center, PROFILE_ORIGIN,
		StringName(body_signature), float(normalized.inward_min_radius_m))
	if not prepared.get("valid", false): return _fail("wrapper_profile_prepare_failed", prepared)
	var guide: Dictionary = {"valid": true, "polygon": prepared.final_envelope_polygon_m,
		"center": center, "origin_id": PROFILE_ORIGIN, "source_id": StringName(body_signature),
		"geometry_fingerprint": prepared.input_fingerprint}
	var finger: Dictionary = progression.inset_contact_target(guide, float(normalized.guide_inward_target_offset_m))
	if not finger.get("valid", false): return _fail("wrapper_finger_target_failed", finger)
	var palm: Dictionary = progression.inset_contact_target(guide, float(normalized.palm_guide_target_depth_m))
	if not palm.get("valid", false): return _fail("wrapper_palm_target_failed", palm)
	var wrapper := Wrapper.new()
	wrapper.source_body_signature = body_signature
	wrapper.source_handle_vertices_m = physical.vertices.duplicate()
	wrapper.source_handle_indices = physical.indices.duplicate()
	wrapper.character_id = StringName(normalized.character_id)
	wrapper.anatomy_signature = String(normalized.anatomy_signature)
	wrapper.inward_min_radius_m = float(normalized.inward_min_radius_m)
	wrapper.guide_inward_target_offset_m = float(normalized.guide_inward_target_offset_m)
	wrapper.palm_guide_target_depth_m = float(normalized.palm_guide_target_depth_m)
	wrapper.source_profile_m = polygon.duplicate()
	wrapper.envelope_profile_m = prepared.final_envelope_polygon_m.duplicate()
	wrapper.target_profile_m = finger.polygon.duplicate()
	wrapper.palm_target_profile_m = palm.polygon.duplicate()
	var tree := presenter.get_tree()
	var staging := Node3D.new()
	staging.name = "InvisibleGripTargetBake"
	staging.visible = false
	presenter.add_child(staging)
	# Forge display scale/position are presentation only. Saved target vertices
	# have the exact same WeaponRootOrigin/metre contract as the protected handle.
	staging.top_level = true
	staging.global_transform = Transform3D.IDENTITY
	var shapes: Array[CSGCombiner3D] = []
	for target_polygon: PackedVector2Array in [wrapper.target_profile_m, wrapper.palm_target_profile_m]:
		var clone: Resource = body.duplicate(true)
		clone.set("profile_polygon_2d_meters", target_polygon.duplicate())
		var shape := CSGCombiner3D.new()
		shape.calculate_tangents = false
		shape.use_collision = false
		shape.collision_layer = 0
		shape.collision_mask = 0
		staging.add_child(shape)
		# Reuse final Handle CSG mapping, including its existing profile reflection,
		# curve sampling and orientation. Never touch the protected material cache.
		if not bool(presenter.call("_append_csg_body_shape", shape, clone,
			StringName(body.get("material_variant_id")), false, 0)):
			staging.free()
			return _fail("wrapper_sweep_build_failed")
		shapes.append(shape)
	var ready := false
	for _frame: int in READINESS_FRAME_LIMIT:
		await tree.process_frame
		if not is_instance_valid(staging) or not is_instance_valid(presenter):
			return _fail("wrapper_bake_owner_removed")
		ready = true
		for shape: CSGCombiner3D in shapes:
			if not bool(presenter.call("_csg_shape_generated_mesh_is_ready", shape)):
				ready = false
		if ready: break
	if not ready:
		staging.free()
		return _fail("wrapper_csg_readiness_timeout")
	var packets: Array[Dictionary] = []
	for shape: CSGCombiner3D in shapes:
		var mesh := shape.bake_static_mesh()
		var flattened: Dictionary = presenter.call("_flatten_native_protected_handle_baked_mesh", mesh, body_signature)
		if not flattened.get("ok", false):
			staging.free()
			return _fail("wrapper_baked_mesh_invalid", flattened)
		packets.append(flattened)
	staging.free()
	wrapper.target_vertices_m = packets[0].vertices
	wrapper.target_indices = packets[0].indices
	wrapper.palm_target_vertices_m = packets[1].vertices
	wrapper.palm_target_indices = packets[1].indices
	wrapper.build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	var verified: Dictionary = Validation.validate(wrapper, handle_packet, config)
	if not verified.get("valid", false): return _fail("wrapper_validation_failed", verified)
	return {"ok": true, "wrapper": wrapper, "build_ms": wrapper.build_ms,
		"rendered_geometry_changed": false, "material_geometry_changed": false}


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok": false, "reason": reason, "detail": detail}
