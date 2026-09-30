extends "res://tools/grip_plane_proof/run_inward_guide_grip_comparison.gd"

## Same frozen pose through zero-offset and live-offset guide consumers.
## This verifies the integration without another acquisition search.
var _checks := 0
var _failures: Array[String] = []
var _maximum_saved_setting_roundtrip_error_m := 0.0


func _report_stem() -> String:
	return "verify_inward_guide_acquisition"


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
		push_error(label)


func _search(context: Dictionary) -> Dictionary:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_comparison_baseline_path))
	var saved: Dictionary = {}
	for case: Dictionary in baseline.cases:
		if case.slot == str(context.slot): saved = case.selected
	if saved.is_empty(): return {"valid":false,"reason":"missing_saved_pose"}
	var zero_config: Dictionary = _config.duplicate(true)
	zero_config.erase("guide_inward_target_offset_m")
	var original := SharedGripAcquisition.new()
	var inset := SharedGripAcquisition.new()
	var surface_palm := SharedGripAcquisition.new()
	var surface_palm_config: Dictionary = _config.duplicate(true)
	surface_palm_config.erase("palm_guide_target_depth_m")
	_check(original.configure_prepared(context,zero_config,root,_selected_digits()).get("valid",false),"original configuration")
	_check(inset.configure_prepared(context,_config,root,_selected_digits()).get("valid",false),"live configuration")
	_check(surface_palm.configure_prepared(context,surface_palm_config,root,_selected_digits()).get("valid",false),"surface-tangent palm configuration")
	original._reset_acquisition(); inset._reset_acquisition(); surface_palm._reset_acquisition()
	var parameters: Array = saved.parameters.duplicate()
	var current: Dictionary = {}
	var observations: Array = []
	for setup: Array in [["circle",0.0,0.08],["circle",0.0,0.0],["hull_transition",0.5,0.0],["wrapper_transition",1.0,0.0]]:
		var label: String = str(setup)
		original._set_phase(setup[0],setup[1]); inset._set_phase(setup[0],setup[1])
		surface_palm._set_phase(setup[0],setup[1])
		var before: Dictionary = original._circle_sample(context,parameters,setup[2],true)
		current = inset._circle_sample(context,parameters,setup[2],true)
		var palm_before: Dictionary = surface_palm._circle_sample(context,parameters,setup[2],true)
		_check(before.get("valid",false) and current.get("valid",false),label+" valid measured samples: "+str(current.get("reason","")))
		if not before.get("valid",false) or not current.get("valid",false): continue
		_check(palm_before.get("valid",false),label+" surface-palm sample valid")
		if not palm_before.get("valid",false): continue
		_check(palm_before.guide_id==current.guide_id,label+" palm depth does not change envelope geometry")
		_check(palm_before.material_safe==current.material_safe and palm_before.material_contacts==current.material_contacts,label+" palm target does not change material limits")
		_check(surface_palm._contact_requests(palm_before)==inset._contact_requests(current),label+" digit native IK requests unchanged by palm target")
		var old_residual: PackedFloat64Array = surface_palm._residual(palm_before)
		var new_residual: PackedFloat64Array = inset._residual(current)
		_check(before.parameters == current.parameters and before.translation_world == current.translation_world,label+" pose unchanged")
		_check(before.material_safe == current.material_safe and before.material_contacts == current.material_contacts,label+" actual-material assessment unchanged")
		var active: bool = current.material_assessed
		for d: int in current.digits.size():
			var old: Dictionary = before.digits[d]
			var new: Dictionary = current.digits[d]
			var reference: Dictionary = saved.digits[d]
			_check(old.target_polygon_m == new.target_polygon_m and old.skin_segments == new.skin_segments,label+" actual material and skin unchanged "+str(new.digit))
			_check(old.circle_center_m == new.circle_center_m and old.plane_origin_id == new.plane_origin_id,label+" named center unchanged "+str(new.digit))
			var guide: Dictionary = new.guide_geometry
			if not active:
				_check(old.guide_geometry == guide,label+" preparation unaffected "+str(new.digit))
			else:
				_check(is_equal_approx(guide.get("contact_target_offset_m",0.0),0.0015),label+" inward target active "+str(new.digit))
				_check(guide.unoffset_guide_geometry_fingerprint == old.guide_id and new.guide_id != old.guide_id,label+" original and queried geometry distinct "+str(new.digit))
				if guide.polygon.is_empty():
					_check(absf(old.radius_m-new.radius_m-0.0015)<1e-8,label+" circle radius inset "+str(new.digit))
				else:
					_check(guide.target.polygon == new.guide_polygon_m and guide.unoffset_guide_polygon_m == old.guide_polygon_m,label+" query matches drawn inset "+str(new.digit))
			for r: int in new.regions.size():
				for field: String in ["cap_m","target_overlap_m","contact_required","owned_segments","material_gap_m","depth_upper_m","material_cap_verified","material_contact"]:
					_check(old.regions[r][field] == new.regions[r][field],label+" regional rule/measurement unchanged "+str(new.digit)+"/"+str(r)+"/"+field)
				for field: String in ["cap_m","target_overlap_m"]:
					if r==3 and field=="target_overlap_m":
						_check(new.regions[r][field]==float(_config.get("palm_guide_target_depth_m",0.0)),label+" explicit configured palm target")
						continue
					# The old report is decimal JSON, unlike the live binary values.
					# Keep the before/after live equality above exact; bound only this
					# serialized-history comparison and expose its largest error.
					var error_m: float = absf(reference.regions[r][field]-new.regions[r][field])
					_maximum_saved_setting_roundtrip_error_m=maxf(_maximum_saved_setting_roundtrip_error_m,error_m)
					_check(error_m<=1e-15,label+" matches pre-change saved section setting "+str(new.digit)+"/"+str(r)+"/"+field)
			var palm: Dictionary = new.regions[3]
			var depth: float = float(_config.get("palm_guide_target_depth_m",0.0))
			_check(palm.cap_m==0.0025,label+" palm keeps 2.5 mm cap "+str(new.digit))
			_check(palm.response_target_clearance_m==(-depth if active else SharedGripAcquisition.CLEARANCE_M),label+" palm target is not clamped to cap "+str(new.digit))
			# Four regions each contribute target and material errors, followed by
			# five guide and five material excesses. Only the palm target error
			# may change when the same captured pose gets the deeper palm target.
			for row: int in 18:
				var index: int = d*18+row
				var delta: float = depth*1000.0 if row==6 and active and is_finite(palm.nearest_unrestricted_gap_m) else 0.0
				_check(absf((new_residual[index]-old_residual[index])-delta)<=1e-10,label+" palm-only response delta "+str(new.digit)+"/"+str(row))
			if palm.has("response_target_point_m"):
				_check(palm.response_target_origin_id==new.plane_origin_id,label+" palm response uses named plane")
				var actual_offset: Vector2 = palm.response_target_point_m-palm.guide_witness.target_point_m
				var expected_offset: Vector2 = palm.guide_witness.target_outward_normal*palm.response_target_clearance_m
				_check(actual_offset.distance_to(expected_offset)<1e-7,label+" displayed palm target matches response")
		observations.append({"phase":setup[0],"amount":setup[1],"radius":setup[2],"material_contacts":current.material_contacts,"material_safe":current.material_safe})
	if current.get("valid",false):
		var freeze: Dictionary = inset._freeze_guides(context,current)
		_check(freeze.get("valid",false),"inset guides freeze for reseating")
		for digit: Dictionary in current.digits:
			_check(inset._fixed_guides[digit.digit] == digit.guide_geometry,"reseat preserves exact inset "+str(digit.digit))
		var moved: Array = parameters.duplicate(); moved[-1]+=0.01; moved[-2]-=0.01
		var clamped: Array = inset._clamped(context,moved)
		_check(clamped[-1]==parameters[-1] and clamped[-2]==parameters[-2],"reseat keeps shared placement frozen")
	for field: String in ["guide_inward_target_offset_m","palm_guide_target_depth_m"]:
		for invalid: Variant in [-0.001,NAN,INF,"0.0015"]:
			var bad: Dictionary = _config.duplicate(true)
			bad[field]=invalid
			_check(not SharedGripAcquisition.new().configure_prepared(context,bad,root,_selected_digits()).get("valid",false),"invalid "+field+" rejected "+str(invalid))
	print("INWARD_GUIDE_INTEGRATION_CHECKS="+JSON.stringify({"checks":_checks,"failures":_failures}))
	return {"valid":_failures.is_empty(),"slot":context.slot,"checks":_checks,"failures":_failures,
		"reason":"" if _failures.is_empty() else "inward_target_integration_failed",
		"selected":current,"states":observations,"search_performed":false,
		"maximum_saved_setting_roundtrip_error_m":_maximum_saved_setting_roundtrip_error_m}
