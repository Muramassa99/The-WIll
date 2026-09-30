extends RefCounted

## Prepared data is loaded/validated once. The current actor must still match
## the saved bone/rest/bind/skin source exactly; a similar name is insufficient.
## The returned anatomy is shared read-only input. The caller owns its config
## copy and all per-acquisition mutable context. No bake or save occurs here.
const Profile = preload("res://core/models/character_grip_data_def.gd")
const Store = preload("res://runtime/player/grip/character_hand_anatomy_store.gd")
const Capture = preload("res://runtime/player/grip/capture_coherent_skin_pose.gd")
const PalmarReference = preload("res://runtime/player/grip/palmar_reference_geometry.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const PROFILE_PATH := "res://core/defs/characters/josie/grip_contact_config.tres"
const SIGNATURE := "4935fa57cf6cc689121ae6077987b0985fc1fa7d0d3d8718f096418ea3c5b702"
const PREPARATION_REVISION := "rest_all_digits_surface_measurements_v1"

static var _loaded := false
static var _profile: Resource
static var _load_error: Dictionary = {}


static func load_for_actor(actor: Node3D) -> Dictionary:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return _failure("missing_live_character_actor")
	var skeleton := actor.get("skeleton") as Skeleton3D
	var mesh := actor.get("mesh_instance") as MeshInstance3D
	if not is_instance_valid(skeleton) or not is_instance_valid(mesh) or mesh.mesh == null or mesh.skin == null:
		return _failure("missing_current_character_skin")
	if not skeleton.is_inside_tree() or not mesh.is_inside_tree() or mesh.get_node_or_null(mesh.skeleton) != skeleton:
		return _failure("mesh_does_not_use_supplied_live_skeleton")
	var loaded := _load_once()
	if not loaded.get("valid", false):
		return loaded
	var anatomy: Resource = _profile.get("anatomy")
	var match_result: Dictionary = Capture.new()._reference_matches(skeleton, mesh, anatomy.get("reference_skin"))
	if not match_result.get("valid", false):
		return _failure("character_does_not_match_prepared_anatomy", match_result)
	var root := skeleton.find_bone(Origins.ORIGIN_RL_BONE_ROOT)
	if root < 0:
		return _failure("missing_machine_root_bone")
	var machine: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(root)
	var metric: Dictionary = PalmarReference.new()._validate_metric(anatomy.get("source_manifest").get("character_metric", {}), machine)
	if not metric.get("valid", false):
		return _failure("character_metric_does_not_match_preparation", metric)
	return {"valid": true, "anatomy": anatomy,
		"config": (_profile.get("contact_config") as Dictionary).duplicate(true),
		"character_id": _profile.get("character_id"), "anatomy_signature": SIGNATURE,
		"preparation_revision": PREPARATION_REVISION,
		"source_correspondence_verified": true, "anatomy_measurement_ran": false,
		"prepared_data_owner": PROFILE_PATH}


static func _load_once() -> Dictionary:
	if _loaded:
		return {"valid": true} if _load_error.is_empty() else _load_error.duplicate(true)
	_loaded = true
	# ResourceLoader preserves the external resource dependency in exported PCKs.
	# https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html
	_profile = ResourceLoader.load(PROFILE_PATH, "Resource", ResourceLoader.CACHE_MODE_REUSE)
	if _profile == null or not is_instance_of(_profile, Profile):
		return _remember_failure("missing_prepared_character_profile")
	var anatomy: Resource = _profile.get("anatomy")
	var validation: Dictionary = Store.new().validate(anatomy)
	if not validation.get("valid", false):
		return _remember_failure("invalid_prepared_character_anatomy", validation)
	if _profile.get("character_id") != &"josie" or anatomy.get("character_id") != _profile.get("character_id") or anatomy.get("source_signature") != SIGNATURE or anatomy.get("preparation_revision") != PREPARATION_REVISION:
		return _remember_failure("prepared_character_identity_mismatch")
	var correspondence: Dictionary = PalmarReference.new()._validate_reference_hashes(anatomy.get("reference_skin"), anatomy.get("source_manifest"))
	if not correspondence.get("valid", false):
		return _remember_failure("prepared_reference_content_mismatch", correspondence)
	var config: Dictionary = _profile.get("contact_config")
	if config.get("character_id") != _profile.get("character_id") or config.get("anatomy_signature") != SIGNATURE:
		return _remember_failure("contact_config_character_mismatch")
	for field: String in ["measured_radius_m", "envelope_radius_multiplier", "envelope_radius_m"]:
		var value: Variant = config.get(field)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0:
			return _remember_failure("invalid_contact_config_scalar", {"field": field})
	if absf(float(config.envelope_radius_m) - float(config.measured_radius_m) * float(config.envelope_radius_multiplier)) > 1.0e-12:
		return _remember_failure("inconsistent_measured_envelope_radius")
	var inward_target: Variant = config.get("guide_inward_target_offset_m", 0.0)
	if not (inward_target is float or inward_target is int) or not is_finite(float(inward_target)) or float(inward_target) < 0.0:
		return _remember_failure("invalid_guide_inward_target_offset")
	var palm_target: Variant = config.get("palm_guide_target_depth_m", 0.0)
	if not (palm_target is float or palm_target is int) or not is_finite(float(palm_target)) or float(palm_target) < 0.0:
		return _remember_failure("invalid_palm_guide_target_depth")
	return {"valid": true}


static func _remember_failure(reason: String, details: Dictionary = {}) -> Dictionary:
	_load_error = _failure(reason, details)
	return _load_error.duplicate(true)


static func _failure(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details, "anatomy_measurement_ran": false}
