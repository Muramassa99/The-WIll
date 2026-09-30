extends "res://tools/grip_plane_proof/run_full_hand_grip_proof.gd"

## One saved proposal per hand, on an isolated real preview rig. No acquisition
## search, runtime acceptance, reseat, new joint limit, or save mutation.
## Final skin is read inside Skeleton3D.skeleton_updated, after all modifiers:
## https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html#signals
const PreviewScene = preload("res://scenes/ui/combat_animation_station_ui.tscn")
const LiveCapture = preload("res://tools/grip_plane_proof/capture_grip_placement_stage.gd")
const ActualView = preload("res://tools/grip_plane_proof/observed_hand_pose_view.gd")
const RigScript = preload("res://runtime/player/player_humanoid_rig.gd")
const FRAME_GUARD: float = 0.000005

class DiagnosticPlayer extends Node:
	var library: Resource
	func get_forge_wip_library_state() -> Resource: return library
	func set_ui_mode_enabled(_enabled: bool) -> void: pass

var _saved_report: Dictionary = {}
var _saved_path: String = ""
var _saved_hash: String = ""
var _actual_view: Dictionary = {}
var _final_capture: Dictionary = {}
var _capture_actor: Node3D
var _capture_weapon: Node3D
var _capture_definition: Resource
var _capture_slot: StringName
var _applied_digit_dimensions: Array = []

func _run() -> void:
	var expected_root: String = OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\","/").simplify_path().trim_suffix("/")
	var actual_root: String = OS.get_user_data_dir().replace("\\","/").simplify_path().trim_suffix("/")
	if not expected_root.to_lower().begins_with("c:/workspace/") or actual_root.to_lower()!=expected_root.to_lower():
		push_error("Real-rig diagnostic requires the explicitly isolated workspace user directory"); quit(1); return
	_saved_path=OS.get_environment("THE_WILL_GRIP_REALIZATION_REPORT").replace("\\","/").simplify_path()
	if not _saved_path.begins_with("C:/WORKSPACE/test_artifacts/") or _saved_path.get_extension()!="json":
		push_error("Explicit workspace THE_WILL_GRIP_REALIZATION_REPORT required"); quit(1); return
	_saved_hash=FileAccess.get_sha256(_saved_path)
	if _saved_hash.is_empty() or _saved_hash!=OS.get_environment("THE_WILL_GRIP_REALIZATION_SOURCE_SHA256"):
		push_error("Selected report SHA256 does not match explicit source"); quit(1); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_saved_path))
	if not parsed is Dictionary or not parsed.get("ok",false) or parsed.get("schema")!="handle_grip_process_proof_v1":
		push_error("Expected completed full-hand source report"); quit(1); return
	_saved_report=parsed
	if parsed.get("selected_digits")!=["middle","thumb","index","ring","pinky"] or parsed.get("anatomy_signature")!=OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH").get_file().get_basename() or parsed.has("template_fixture"):
		push_error("Realization requires the matching actual-weapon five-digit proof"); quit(1); return
	var paths: Dictionary = {"runner":"run_handle_grip_process_proof.gd","depth":"planar_skin_overlap_budget.gd","palm":"prepared_palmar_slice_region.gd","progression":"planar_grip_guide_progression.gd","skin":"prepared_hand_candidate_pose.gd"}
	for key: String in paths:
		if parsed.get("source_sha256",{}).get(key)!=FileAccess.get_sha256("res://tools/grip_plane_proof/"+paths[key]):
			push_error("Selected source implementation mismatch: "+key); quit(1); return
	if parsed.get("envelope_configuration_sha256")!=FileAccess.get_sha256(CONFIG_PATH):
		push_error("Selected source envelope configuration mismatch"); quit(1); return
	var originals: Dictionary = {}
	for evidence: Dictionary in parsed.get("anatomy_extension_evidence",[]): originals[evidence.original_trace]=evidence.original_trace_sha256
	for requested: String in OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";",false):
		var path: String = requested.replace("\\","/").simplify_path()
		if not originals.has(path) or FileAccess.get_sha256(path)!=originals[path]:
			push_error("Realization trace does not match selected proof"); quit(1); return
	await super._run()

func _report_stem() -> String: return "selected_grip_arm_realization"

func _report_extensions() -> Dictionary:
	var out: Dictionary = super._report_extensions()
	out.schema="selected_grip_arm_realization_diagnostic_v1"
	out.scope="one_saved_candidate_per_hand_on_isolated_real_preview_rig"
	out["selected_source_report"]=_saved_path; out["selected_source_sha256"]=_saved_hash
	out["diagnostic_sha256"]=FileAccess.get_sha256(get_script().resource_path)
	out["full_hand_runner_sha256"]=FileAccess.get_sha256("res://tools/grip_plane_proof/run_full_hand_grip_proof.gd")
	out["search_performed"]=false; out["runtime_integration_enabled"]=false
	out["production_pose_written"]=false; out["isolated_test_rig_pose_written"]=true
	out["material_measurement_policy"]="actual_post_modifier_skin_and_actual_weapon_sections; guide_safety_is_not_acceptance"
	out["capture_signal"]="Skeleton3D.skeleton_updated"
	out["limitations"]=["Single-hand tests, not simultaneous support/reverse/playback certification","Five planes and conservative palm core, not complete three-dimensional collision","The existing arm operator may miss or clamp the desired Hand frame; mismatch remains a finding","No new failure policy, acquisition performance claim, or production acceptance"]
	return out

func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var result: Dictionary = super._prepare(definition,stage)
	if result.get("valid",false):
		result["diagnostic_definition"]=definition
		result["diagnostic_stage"]=stage
	return result

func _rigid_candidate(context: Dictionary, parameters: Array, translation: Vector3) -> Dictionary:
	if not _actual_view.is_empty(): return _actual_view
	return super._rigid_candidate(context,parameters,translation)

func _search(context: Dictionary) -> Dictionary:
	_actual_view.clear()
	var source_case: Dictionary = {}
	for entry: Dictionary in _saved_report.cases:
		if entry.get("slot")==str(context.slot): source_case=entry; break
	var source: Dictionary = source_case.get("selected",{})
	if not source.get("valid",false) or not source.get("material_assessed",false) or source.get("parameters",[]).size()!=_parameter_count() or int(source_case.get("source_transaction",-1))!=int(context.adapter.base_packet.get("transaction_serial",-2)):
		return {"valid":false,"reason":"selected_source_or_transaction_mismatch","slot":context.slot}
	var parameters: Array = _clamped(context,source.parameters)
	for index: int in parameters.size():
		if not is_finite(float(source.parameters[index])) or absf(float(parameters[index])-float(source.parameters[index]))>1e-12:
			return {"valid":false,"reason":"saved_parameter_outside_current_limits","slot":context.slot}
	var translation: Vector3 = context.translation_u_world*float(parameters[_translation_u_index()])+context.translation_v_world*float(parameters[_translation_v_index()])
	var proposal: Dictionary = super._rigid_candidate(context,parameters,translation)
	if not proposal.get("valid",false): return proposal
	var setup: Dictionary = await _open_preview(context.slot)
	if not setup.get("valid",false): return setup
	var result: Dictionary = await _realize_and_observe(context,source,proposal,setup)
	setup.ui.queue_free(); setup.player.queue_free()
	await process_frame
	_actual_view.clear()
	return result

func _open_preview(slot: StringName) -> Dictionary:
	var original: Resource = load("user://forge/player_wip_library_state.tres")
	if original==null: return {"valid":false,"reason":"isolated_saved_library_missing"}
	var player := DiagnosticPlayer.new()
	player.library=original.duplicate(true)
	player.library.set("save_file_path","C:/WORKSPACE/test_artifacts/selected_grip_arm_realization_unused_save.tres")
	var chosen: Resource
	for wip: Resource in player.library.get("saved_wips"):
		if wip.get("forge_project_name")=="Star_Handle_Testing":
			if chosen!=null: return {"valid":false,"reason":"ambiguous_test_weapon"}
			chosen=wip
	if chosen==null: return {"valid":false,"reason":"isolated_test_weapon_missing"}
	root.add_child(player)
	var ui: Node = PreviewScene.instantiate()
	ui.set_meta("verification_skip_persistence",true)
	root.add_child(ui)
	await process_frame
	ui.open_for(player,"Selected grip arm realization diagnostic")
	if not ui.open_saved_wip_with_hand_setup(chosen.get("wip_id"),slot,false,false) or not ui.select_skill_slot(&"skill_slot_1",true):
		ui.queue_free(); player.queue_free(); return {"valid":false,"reason":"cannot_open_isolated_preview"}
	await process_frame
	var live: Dictionary = ui.preview_presenter.call("_weapon_roll_context",ui.preview_subviewport)
	if live.is_empty(): ui.queue_free(); player.queue_free(); return {"valid":false,"reason":"preview_context_missing"}
	# Stop the ordinary per-frame authoring writer while this tool owns its one
	# test pose. Existing modifiers stay installed and are advanced once below.
	live.actor.set_process(false)
	return {"valid":true,"ui":ui,"player":player,"actor":live.actor,"weapon":live.weapon}

func _realize_and_observe(context: Dictionary, source: Dictionary, proposal: Dictionary, setup: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var actor: Node3D = setup.actor
	var weapon: Node3D = setup.weapon
	var skeleton: Skeleton3D = actor.get("skeleton")
	var definition: Resource = context.diagnostic_definition
	var slot: StringName = context.slot
	var before: Dictionary = LiveCapture.new().capture(actor,weapon,definition,slot,&"before_selected_realization",1)
	if not before.get("valid",false): return {"valid":false,"reason":"initial_real_rig_capture_failed","detail":before,"slot":slot}
	var saved_object: Dictionary = context.diagnostic_stage.object
	var saved_mesh_in_weapon: Transform3D = (saved_object.weapon_to_world as Transform3D).affine_inverse()*(saved_object.mesh_to_world as Transform3D)
	var live_mesh_in_weapon: Transform3D = (before.object.weapon_to_world as Transform3D).affine_inverse()*(before.object.mesh_to_world as Transform3D)
	if before.object.local_faces!=saved_object.local_faces or not _same_frame(saved_mesh_in_weapon,live_mesh_in_weapon):
		return {"valid":false,"reason":"real_weapon_geometry_does_not_match_selected_source","slot":slot}
	var desired_in_weapon: Transform3D = context.weapon_to_world.affine_inverse()*(proposal.hand_to_world as Transform3D)
	var fixed_weapon: Transform3D = weapon.global_transform
	# Freeze the isolated test object even if a scene attachment is its parent.
	weapon.set_as_top_level(true)
	weapon.global_transform=fixed_weapon
	var desired_hand: Transform3D = fixed_weapon*desired_in_weapon
	var hand_name: StringName = context.adapter.hand_bone_name
	var hand_index: int = skeleton.find_bone(hand_name)
	if hand_index<0: return {"valid":false,"reason":"real_hand_bone_missing","slot":slot}
	var initial_hand: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)
	var anchor: Node3D = actor.get_right_hand_item_anchor() if slot==&"hand_right" else actor.get_left_hand_item_anchor()
	var attachment: BoneAttachment3D = anchor.get_parent() as BoneAttachment3D
	if attachment==null or attachment.bone_name!=hand_name or attachment.override_pose:
		return {"valid":false,"reason":"unsupported_real_hand_anchor_chain","slot":slot}
	var anchor_in_hand: Transform3D = anchor.transform
	var anchor_authoritative: Transform3D = initial_hand*anchor_in_hand
	if not _same_frame(anchor_authoritative,anchor.global_transform):
		return {"valid":false,"reason":"hand_attachment_global_frame_is_stale","slot":slot,"authoritative":anchor_authoritative,"cached":anchor.global_transform}
	var alignment_state: Dictionary = actor.resolve_hand_grip_alignment_offset_state(slot)
	if alignment_state.get("hand_alignment_offset_origin_id")!=LiveCapture.Origins.ORIGIN_HAND_GRIP_ALIGNMENT or not alignment_state.get("hand_alignment_offset_local") is Vector3:
		return {"valid":false,"reason":"missing_named_real_hand_alignment_offset","slot":slot}
	var alignment_in_hand: Vector3 = anchor_in_hand*(alignment_state.hand_alignment_offset_local as Vector3)
	var alignment_world: Vector3 = actor.resolve_hand_grip_alignment_world_position(slot)
	if (initial_hand*alignment_in_hand).distance_to(alignment_world)>FRAME_GUARD:
		return {"valid":false,"reason":"named_alignment_reader_disagrees_with_authoritative_hand_chain","slot":slot}
	var weapon_origin_id: StringName = before.object.weapon_origin_record.origin_id
	var mapping_records: Array = [
		{"origin_id":&"RealizationTargetHandInWeapon","parent_origin_id":weapon_origin_id,"transform_to_parent":desired_in_weapon,"owner_system":&"selected_grip_arm_diagnostic","resolve_phase":&"editor_preview","space_type":&"bone_frame","is_dynamic":false},
		{"origin_id":&"RealizationTargetHandGripAlignment","parent_origin_id":&"RealizationTargetHandInWeapon","transform_to_parent":Transform3D(Basis.IDENTITY,alignment_in_hand),"owner_system":&"selected_grip_arm_diagnostic","resolve_phase":&"editor_preview","space_type":&"presentation","is_dynamic":false}]
	var target_records: Array = before.posed_character.origin_records+[before.object.weapon_origin_record]+mapping_records
	var registered: Dictionary = HandSkin.new()._registry(target_records,before.posed_character.resolve_phase)
	if not registered.get("valid",false): return {"valid":false,"reason":"target_origin_chain_invalid","detail":registered,"slot":slot}
	var registered_hand: Transform3D = before.posed_character.machine_to_world*registered.registry.resolve_transform_to_machine(&"RealizationTargetHandInWeapon")
	var registered_alignment: Transform3D = before.posed_character.machine_to_world*registered.registry.resolve_transform_to_machine(&"RealizationTargetHandGripAlignment")
	if not _same_frame(registered_hand,desired_hand) or registered_alignment.origin.distance_to(desired_hand*alignment_in_hand)>FRAME_GUARD:
		return {"valid":false,"reason":"target_origin_chain_does_not_resolve_to_requested_frame","slot":slot}
	var target := Node3D.new(); target.name="SelectedGripAlignmentTarget"; root.add_child(target)
	target.global_transform=Transform3D(desired_hand.basis,desired_hand*alignment_in_hand)
	actor.set_arm_guidance_target(slot,target); actor.set_arm_guidance_active(slot,true)
	actor.set_authoring_contact_anchor_basis(slot,desired_hand.basis*anchor_in_hand.basis)
	# This is the existing bounded arm operator. It retains reach clamps, elbow,
	# upper-arm and wrist authorities; it does not directly place the Hand bone.
	var pass_records: Array = []
	var snap_delta: float = 1.0/maxf(float(actor.get("support_arm_ik_target_smoothing_speed")),0.001)
	for iteration: int in RigScript.AUTHORING_GRIP_RELATIONSHIP_PRECISE_SETTLE_PASSES:
		actor.call("_update_support_arm_ik_targets",snap_delta)
		actor.call("_apply_authoring_precise_contact_alignment_for_slot",slot)
		skeleton.force_update_all_bone_transforms()
		var reached: Transform3D = skeleton.global_transform*skeleton.get_bone_global_pose(hand_index)
		pass_records.append({"pass":iteration+1,"hand_position_error_m":reached.origin.distance_to(desired_hand.origin),"hand_basis_error_rad":_basis_angle(reached.basis,desired_hand.basis)})
		if reached.origin.distance_to(desired_hand.origin)<=RigScript.AUTHORING_GRIP_RELATIONSHIP_ALIGNMENT_EPSILON_METERS and rad_to_deg(_basis_angle(reached.basis,desired_hand.basis))<=RigScript.AUTHORING_GRIP_RELATIONSHIP_CONTACT_AXIS_EPSILON_DEGREES: break
	var rotations: Dictionary = _rotation_plan(skeleton,proposal)
	if not rotations.get("valid",false): target.queue_free(); return {"valid":false,"reason":"digit_rotation_plan_invalid","detail":rotations,"slot":slot}
	_applied_digit_dimensions=rotations.entries.duplicate(true)
	for item: Dictionary in rotations.entries: skeleton.set_bone_pose_rotation(item.index,item.rotation)
	var dimensions_after_write: Dictionary = _check_digit_dimensions(skeleton)
	if not dimensions_after_write.unchanged:
		target.queue_free(); return {"valid":false,"reason":"rotation_write_changed_bone_dimensions","detail":dimensions_after_write,"slot":slot}
	skeleton.force_update_all_bone_transforms()
	_final_capture.clear(); _capture_actor=actor; _capture_weapon=weapon; _capture_definition=definition; _capture_slot=slot
	skeleton.skeleton_updated.connect(_capture_final_skin,CONNECT_ONE_SHOT)
	skeleton.advance(0.0)
	for _frame: int in 3:
		if not _final_capture.is_empty(): break
		await process_frame
	if skeleton.skeleton_updated.is_connected(_capture_final_skin): skeleton.skeleton_updated.disconnect(_capture_final_skin)
	target.queue_free()
	if _final_capture.is_empty() or not _final_capture.get("valid",false):
		return {"valid":false,"reason":"post_modifier_capture_failed","detail":_final_capture,"slot":slot}
	var observed: Dictionary = ActualView.new().observe(definition,_final_capture.posed_character,slot,_selected_digits())
	if not observed.get("valid",false): return {"valid":false,"reason":"actual_pose_observation_failed","detail":observed,"slot":slot}
	var actual_hand: Transform3D = observed.view.hand_to_world
	var after_weapon: Transform3D = _final_capture.object.weapon_to_world
	if not _same_frame(after_weapon,fixed_weapon): return {"valid":false,"reason":"test_weapon_moved_during_arm_realization","slot":slot}
	# New preparation belongs to the observed coherent epoch, never to the saved
	# rigidly translated forearm. Discard all translation-keyed source caches.
	_circle_cache.clear(); _slice_cache.clear(); _fixed_guides.clear(); _guide_preparation_cache.clear(); _frozen_parameters.clear()
	var actual_context: Dictionary = _prepare(definition,_final_capture)
	var material: Dictionary = actual_context
	if actual_context.get("valid",false):
		_actual_view=observed.view
		var actual_parameters: Array = _zero_parameters()
		for digit_index: int in _selected_digits().size():
			for joint: int in 3: actual_parameters[digit_index*3+joint]=observed.view.digit_states[_selected_digits()[digit_index]].angles_rad[joint]
		_circle_cache.clear(); _slice_cache.clear(); _set_phase("circle",0.0)
		material=_circle_sample(actual_context,actual_parameters,0.0,true)
		_actual_view.clear()
		# The inherited planar predicate does not establish legal realized
		# articulation, whole-hand coverage, or equivalence to the frozen guide.
		material["planar_predicate_only_not_acceptance"]=material.get("diagnostic_grip_accepted",false)
		material["diagnostic_grip_accepted"]=false
	var binary: String = "C:/WORKSPACE/test_artifacts/selected_grip_realized_"+str(slot)+"_"+Time.get_datetime_string_from_system().replace(":","-")+".bin"
	var file: FileAccess = FileAccess.open(binary,FileAccess.WRITE)
	if file==null: return {"valid":false,"reason":"cannot_save_actual_coherent_capture","slot":slot}
	file.store_var(_final_capture,false); file.close()
	return {"valid":true,"slot":slot,"harness_completed":true,"search_performed":false,
		"production_pose_written":false,"isolated_test_rig_pose_written":true,"grip_accepted":false,"actual_3d_grip_verified":false,
		"selected":material,"material_query_valid":material.get("valid",false),"actual_articulation":observed.articulation,
		"source_material_contacts":source.get("material_contacts",[]),"actual_material_contacts":material.get("material_contacts",[]),
		"actual_material_safe":material.get("material_safe",false),"observed_not_reposed":true,
		"actual_capture_path":binary,"actual_capture_sha256":FileAccess.get_sha256(binary),
		"target_hand_in_weapon":desired_in_weapon,"target_hand_in_weapon_origin_id":weapon_origin_id,"target_origin_records":target_records,
		"actual_hand_in_weapon":after_weapon.affine_inverse()*actual_hand,"actual_hand_in_weapon_origin_id":_final_capture.object.weapon_origin_record.origin_id,
		"anchor_local_chain_verified":true,"alignment_source_origin_id":alignment_state.hand_alignment_offset_origin_id,
		"hand_position_error_m":actual_hand.origin.distance_to(desired_hand.origin),"hand_basis_error_rad":_basis_angle(actual_hand.basis,desired_hand.basis),
		"arm_passes":pass_records,"existing_arm_target_diagnostics":actor.get("last_two_hand_solve_result"),
		"digit_rotations_applied":rotations.entries.size(),"digit_geometry_preflight":rotations.geometry_checks,
		"digit_dimensions_after_rotation_write":dimensions_after_write,"digit_dimensions_after_modifiers":_final_capture.digit_dimensions,
		"prepared_geometry_matches_live":rotations.geometry_matches_prepared,
		"weapon_fixed":true,"capture_signal":"Skeleton3D.skeleton_updated","total_search_ms":0.0,
		"total_realization_diagnostic_ms":float(Time.get_ticks_usec()-started)/1000.0}

func _rotation_plan(skeleton: Skeleton3D, proposal: Dictionary) -> Dictionary:
	var entries: Array = []
	var geometry_checks: Array = []
	var geometry_matches: bool = true
	for digit: StringName in _selected_digits():
		var state: Dictionary = proposal.digit_states[digit]
		var parent: Transform3D = proposal.hand_to_world
		for joint: int in 3:
			var name: StringName = state.snapshot.bone_names[joint]
			var index: int = skeleton.find_bone(name)
			if index<0: return {"valid":false,"reason":"missing_real_digit_bone","bone":name}
			var parent_index: int = skeleton.get_bone_parent(index)
			var expected_parent: StringName = state.snapshot.bone_names[joint-1] if joint>0 else state.digit.hand_bone_name
			if parent_index<0 or skeleton.get_bone_name(parent_index)!=expected_parent:
				return {"valid":false,"reason":"actual_digit_parent_chain_differs","bone":name}
			# Preserve the canonical prepared local chain. Reconstructing it by
			# inverting already-scaled world frames introduces avoidable cancellation.
			var expected: Transform3D = state.snapshot.relative_transforms[joint]
			expected.basis = expected.basis * Basis((state.snapshot.neutral_local_rotations[joint] as Quaternion).normalized()) * Basis((state.snapshot.hinge_axes_local[joint] as Vector3).normalized(),float(state.angles_rad[joint]))
			var actual: Transform3D = skeleton.get_bone_pose(index)
			if not actual.is_finite() or actual.basis.determinant()<=0.0:
				return {"valid":false,"reason":"nonfinite_or_nonpositive_actual_digit_frame","bone":name}
			var position_error: float = (parent.basis*(actual.origin-expected.origin)).length()
			var scale_error: float = actual.basis.get_scale().distance_to(expected.basis.get_scale())
			var matches: bool = position_error<=FRAME_GUARD and scale_error<=FRAME_GUARD
			geometry_matches=geometry_matches and matches
			geometry_checks.append({"bone":name,"local_position_error_world_m":position_error,"local_scale_error":scale_error,"numeric_guard":FRAME_GUARD,"matches_prepared":matches})
			# This observation diagnostic must expose the actual result even if
			# animated local translations differ from preparation. Keep dimensions
			# untouched; the measured articulation mismatch still prevents acceptance.
			entries.append({"index":index,"bone":name,"rotation":expected.basis.orthonormalized().get_rotation_quaternion(),
				"position_before":skeleton.get_bone_pose_position(index),"position_origin_id":proposal.pose_packet.bone_origin_ids[expected_parent],"scale_before":skeleton.get_bone_pose_scale(index)})
			parent=state.joint_transforms_world[joint]
	return {"valid":entries.size()==15,"entries":entries,"geometry_checks":geometry_checks,"geometry_matches_prepared":geometry_matches}

func _check_digit_dimensions(skeleton: Skeleton3D) -> Dictionary:
	var rows: Array = []
	var unchanged: bool = true
	for item: Dictionary in _applied_digit_dimensions:
		var position: Vector3 = skeleton.get_bone_pose_position(item.index)
		var scale: Vector3 = skeleton.get_bone_pose_scale(item.index)
		var same: bool = position==item.position_before and scale==item.scale_before
		unchanged=unchanged and same
		rows.append({"bone":item.bone,"position":position,"position_origin_id":item.position_origin_id,"scale":scale,"unchanged":same})
	return {"unchanged":unchanged,"bones":rows}

func _capture_final_skin() -> void:
	_final_capture=LiveCapture.new().capture(_capture_actor,_capture_weapon,_capture_definition,_capture_slot,&"after_selected_arm_and_digit_realization",2)
	_final_capture["capture_signal"]=&"Skeleton3D.skeleton_updated"
	_final_capture["isolated_test_rig_pose_written_before_capture"]=true
	_final_capture["digit_dimensions"]=_check_digit_dimensions(_capture_actor.get("skeleton"))

func _basis_angle(first: Basis, second: Basis) -> float:
	return first.orthonormalized().get_rotation_quaternion().angle_to(second.orthonormalized().get_rotation_quaternion())
