extends RefCounted

## Shared data preparation for the proof runner and live acquisition. No scene
## access, fixture positioning, wrapper generation or skeleton writes.
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Observer = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const Palm = preload("res://runtime/player/grip/prepared_palmar_slice_region.gd")
const Sections = preload("res://runtime/player/grip/prepared_saved_grip_sections.gd")
const ExistingPreparation = preload("res://runtime/player/grip/handle_grip_acquisition.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const ROOT := &"RL_BoneRoot"
const DIGITS: Array[StringName] = [&"middle",&"thumb",&"index",&"ring",&"pinky"]
var _builder := Candidate.new()
var _digits: Array[StringName] = []

func prepare_hand(anatomy: Resource, stage: Dictionary, digits: Array[StringName]) -> Dictionary:
	_digits.assign(digits)
	var adapter := _builder.prepare(anatomy,stage.posed_character,stage.slot,_digits)
	if not adapter.get("valid",false): return adapter
	var frame: Transform3D = stage.object.weapon_to_world
	var span: Vector3 = frame.basis * (stage.object.primary_grip_span_end_local-stage.object.primary_grip_span_start_local)
	if not span.is_finite() or span.length_squared()<1e-12:
		return {"valid":false,"reason":"degenerate_saved_handle_axis"}
	var axis := span.normalized()
	var plane: Transform3D = adapter.digit_inputs[&"middle"].plane_to_world
	var u: Vector3 = plane.basis.z.cross(axis)
	if u.length_squared()<1e-8: u=plane.basis.x-axis*plane.basis.x.dot(axis)
	if u.length_squared()<1e-8: return {"valid":false,"reason":"degenerate_shared_translation_basis"}
	u=u.normalized()
	var observations := {}
	for digit: StringName in _digits:
		var observed := Observer.new().prepare(adapter,digit)
		if not observed.get("valid",false): return observed
		observations[digit]=observed
	var context := {"valid":true,"adapter":adapter,"slot":stage.slot,"digit_order":_digits.duplicate(),
		"observations":observations,"station_axis_world":axis,"translation_u_world":u,
		"translation_v_world":axis.cross(u).normalized(),"vectors_origin_id":ROOT}
	# Reuse the mature open-angle and palm-facing derivation only. This never
	# instantiates or runs the previous closure/search/progression algorithm.
	context=ExistingPreparation.op_circle_prepare(self,anatomy,stage,context)
	if not context.get("valid",false): return context
	context["palm_region"]=Palm.new().prepare(context,anatomy)
	if not context.palm_region.get("valid",false): return context.palm_region
	return context

func prepare(anatomy: Resource, stage: Dictionary, config: Dictionary) -> Dictionary:
	var source: Dictionary = stage.get("saved_grip_source",{})
	if not source.get("valid",false):
		return {"valid":false,"reason":source.get("reason","missing_saved_wrapper_source")}
	var context := prepare_hand(anatomy,stage,DIGITS)
	if not context.get("valid",false): return context
	context["weapon_to_world"]=stage.object.weapon_to_world
	context["expected_source_body_signature"]=source.source_body_signature
	context["expected_contact_config"]=config.duplicate(true)
	var candidate := _builder.evaluate(context.adapter,_angles(context.open_parameters),Vector3.ZERO,ROOT)
	if not candidate.get("valid",false): return candidate
	var planes := {}
	for digit: StringName in _digits:
		planes[digit]={"plane_to_world":candidate.digit_states[digit].plane_to_world,
			"plane_origin_id":candidate.digit_states[digit].plane_origin_id}
	var records: Array = candidate.pose_packet.origin_records.duplicate(true)
	records.append(stage.object.weapon_origin_record)
	if not source.get("source_to_weapon") is Transform3D or source.get("source_parent_origin_id") != &"WeaponRootOrigin":
		return {"valid":false,"reason":"missing_equipped_saved_source_origin"}
	records.append({"origin_id":source.source_origin_id,"parent_origin_id":source.source_parent_origin_id,
		"transform_to_parent":source.source_to_weapon,"owner_system":&"saved_wrapper_grip_source",
		"resolve_phase":candidate.pose_packet.resolve_phase,"space_type":&"weapon","is_dynamic":false})
	var plane_context := {"origin_records":records,"resolve_phase":candidate.pose_packet.resolve_phase,
		"digit_planes":planes,"station_axis_world":context.station_axis_world,"vectors_origin_id":ROOT,
		"saved_source_origin_id":source.source_origin_id}
	var saved := Sections.new().prepare(source.wrapper,source.handle_packet,stage.object.weapon_to_world,
		candidate.pose_packet.machine_to_world,plane_context,config)
	if not saved.get("valid",false): return saved
	return {"valid":true,"context":context,"saved":saved}

func _selected_digits() -> Array[StringName]:
	return _digits

func _zero_parameters() -> Array:
	var values: Array=[]
	values.resize(_digits.size()*3+2)
	values.fill(0.0)
	return values

func _angles(parameters: Array) -> Dictionary:
	var result := {}
	for index: int in _digits.size(): result[_digits[index]]=parameters.slice(index*3,index*3+3)
	return result
