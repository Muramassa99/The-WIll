extends SceneTree

const Progression = preload("res://tools/grip_plane_proof/planar_grip_guide_progression.gd")
const Centroid = preload("res://core/resolvers/primary_grip_seat_resolver.gd")
const INPUT_PATH: String = "C:/WORKSPACE/test_artifacts/contact_envelope_input_2026-09-26.json"
var _assertions: int = 0
var _failures: Array[String] = []
var _cases: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	var tool: RefCounted = Progression.new()
	var square: PackedVector2Array = PackedVector2Array([Vector2(-0.02,-0.02),Vector2(0.02,-0.02),Vector2(0.02,0.02),Vector2(-0.02,0.02)])
	_exercise(tool, "synthetic_square", square, Vector2.ZERO, 0.0508284749483291)
	_inward_targets(tool, square)
	var nonradial: PackedVector2Array = PackedVector2Array([Vector2(-0.02,-0.02),Vector2(0.02,-0.02),Vector2(0.02,0.02),Vector2(0.01,0.02),Vector2(0.01,-0.01),Vector2(-0.01,-0.01),Vector2(-0.01,0.02),Vector2(-0.02,0.02)])
	_exercise(tool, "synthetic_nonradial_u", nonradial, Vector2.ZERO, 0.0508284749483291)
	_check(not tool.prepare(square, Vector2.ZERO, &"", &"Square", 0.05).valid, "missing origin rejected")
	_check(not tool.prepare(square, Vector2.ZERO, &"TestPlane", &"", 0.05).valid, "missing source rejected")
	_check(not tool.prepare(square, Vector2.ONE, &"TestPlane", &"Square", 0.05).valid, "center outside hull rejected")
	_check(not tool.prepare(square, Vector2.ZERO, &"TestPlane", &"Square", 0.0).valid, "zero curvature radius rejected")
	var crossed: PackedVector2Array = PackedVector2Array([Vector2(-0.02,-0.02),Vector2(0.02,0.02),Vector2(0.02,-0.02),Vector2(-0.02,0.02)])
	_check(not tool.prepare(crossed, Vector2.ZERO, &"TestPlane", &"Crossed", 0.05).valid, "crossed source rejected")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INPUT_PATH))
	_check(parsed is Dictionary and parsed.get("schema") == "contact_envelope_input_v1", "frozen envelope input available")
	if parsed is Dictionary and parsed.get("cases") is Array:
		for entry: Dictionary in parsed.cases:
			if not String(entry.id).begins_with("hand_") or not bool(entry.get("complete", false)): continue
			var polygon: PackedVector2Array = PackedVector2Array()
			for point: Array in entry.polygon_m: polygon.append(Vector2(point[0], point[1]))
			var centroid: Dictionary = Centroid._calculate_polygon_centroid_state(polygon)
			_check(centroid.get("valid", false), String(entry.id) + " area centroid")
			if centroid.get("valid", false): _exercise(tool, entry.id, polygon, centroid.centroid, parsed.envelope_radius_m)
	var report: Dictionary = {"schema":"verify_planar_grip_guide_progression_v1", "ok":_failures.is_empty(),
		"assertions":_assertions,"failures":_failures,"cases":_cases,
		"input_path":INPUT_PATH,"input_sha256":FileAccess.get_sha256(INPUT_PATH),
		"helper_sha256":FileAccess.get_sha256("res://tools/grip_plane_proof/planar_grip_guide_progression.gd"),
		"total_ms":float(Time.get_ticks_usec()-started)/1000.0,
		"production_pose_written":false,"continuous_curvature_certified":false}
	var path: String = "C:/WORKSPACE/test_artifacts/verify_planar_grip_guide_progression_" + Time.get_datetime_string_from_system().replace(":","-") + ".json"
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file == null: push_error("Cannot save guide progression verification"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("GUIDE_PROGRESSION_VERIFIER=" + path)
	print("GUIDE_PROGRESSION_SUMMARY=" + JSON.stringify({"ok":report.ok,"assertions":_assertions,"failures":_failures,"total_ms":report.total_ms}))
	quit(0 if report.ok else 1)


func _exercise(tool: RefCounted, id: String, polygon: PackedVector2Array, center: Vector2, inward_radius: float) -> void:
	var prepared: Dictionary = tool.prepare(polygon,center,&"ProgressionVerificationPlane",StringName(id),inward_radius)
	_check(prepared.get("valid",false), id + " preparation: " + str(prepared.get("reason","")))
	if not prepared.get("valid",false): return
	var radius: float = prepared.enclosing_radius_m + 0.00002
	var previous: PackedVector2Array = PackedVector2Array()
	var rows: Array = []
	for phase: String in ["hull_transition","wrapper_transition"]:
		for amount: float in [0.0,0.25,0.5,0.75,1.0]:
			var measured: Dictionary = tool.sample(prepared,phase,amount,radius)
			var label: String = "%s/%s/%.2f" % [id,phase,amount]
			_check(measured.get("valid",false), label + ": " + str(measured.get("reason","")))
			if not measured.get("valid",false):
				rows.append({"phase":phase,"amount":amount,"failure":measured})
				continue
			_check(measured.center == center and measured.origin_id == &"ProgressionVerificationPlane", label + " named center unchanged")
			_check(measured.source_contained_within_numeric_tolerance, label + " source contained within explicit numeric guard")
			_check(measured.target.polygon == measured.polygon, label + " queried target equals displayed geometry")
			_check(not measured.continuous_curvature_certified and not measured.continuous_sweep_certified, label + " no analytic or motion overclaim")
			_check(measured.circle_polygon_maximum_outer_error_m <= Progression.CIRCLE_OUTER_ERROR_M + 1.0e-12, label + " circle approximation bounded")
			if phase == "wrapper_transition" and amount > 0.0:
				_check(measured.construction_bend_radius_m >= inward_radius, label + " inward radius never below configured minimum")
			if not previous.is_empty():
				var nested: Dictionary = tool._containment(measured.polygon,previous,center)
				_check(nested.get("within_numeric_tolerance",false), label + " progression contracts within numeric guard")
			previous = measured.polygon.duplicate()
			if (phase == "hull_transition" and amount == 1.0) or (phase == "wrapper_transition" and amount == 0.0):
				_check(measured.polygon == prepared.hull_polygon_m, label + " exact stored hull endpoint")
			if phase == "wrapper_transition" and amount == 1.0:
				_check(measured.polygon == prepared.final_envelope_polygon_m, label + " exact existing final wrapper endpoint")
			var inset: Dictionary = tool.sample(prepared,phase,amount,radius,0.0015)
			_check(inset.get("valid",false), label + " 1.5 mm contact target: " + str(inset.get("reason","")))
			if inset.get("valid",false):
				_check(inset.center == center and inset.origin_id == measured.origin_id, label + " inset retains named slice center")
				_check(inset.target.polygon == inset.polygon and inset.unoffset_guide_polygon_m == measured.polygon, label + " inset target and original envelope kept distinct")
				_check(inset.contact_target_offset_m == 0.0015 and not inset.physical_material_changed, label + " offset does not change material")
				_check(inset.inward_target_containment.within_numeric_tolerance, label + " target stays inside envelope")
				_check(prepared.source_polygon_m == polygon and not inset.has("source_contained"), label + " no physical-source mutation or false containment claim")
				var inset_fingerprint: String = inset.geometry_fingerprint
				inset.polygon[0] += Vector2(1,1)
				var repeated: Dictionary = tool.sample(prepared,phase,amount,radius,0.0015)
				_check(repeated.geometry_fingerprint == inset_fingerprint and repeated.polygon == repeated.target.polygon, label + " inset cache detached from caller")
			var fingerprint: String = measured.geometry_fingerprint
			measured.polygon[0] += Vector2(1,1)
			var again: Dictionary = tool.sample(prepared,phase,amount,radius)
			_check(again.geometry_fingerprint == fingerprint and again.polygon == previous, label + " cached geometry protected from caller mutation")
			rows.append({"phase":phase,"amount":amount,"vertices":again.polygon.size(),
				"source_outside_area_m2":again.source_containment.outside_area_m2,
				"circle_sides":again.circle_polygon_sides,"sample_ms":again.sample_build_ms,
				"geometry_fingerprint":fingerprint})
	_check(not tool.sample(prepared,"unknown",0.5,radius).valid,id + " unknown phase rejected")
	_check(not tool.sample(prepared,"wrapper_transition",-0.1,radius).valid,id + " negative amount rejected")
	_check(not tool.sample(prepared,"wrapper_transition",1.1,radius).valid,id + " excess amount rejected")
	_check(not tool.sample(prepared,"hull_transition",0.5,prepared.enclosing_radius_m * 0.5).valid,id + " undersized circle rejected")
	_cases.append({"id":id,"stages":rows,"preparation_ms":prepared.preparation_ms})


func _inward_targets(tool: RefCounted, square: PackedVector2Array) -> void:
	var prepared: Dictionary = tool.prepare(square,Vector2.ZERO,&"InsetTestPlane",&"Square",0.05)
	var guide: Dictionary = tool.sample(prepared,"hull_transition",1.0,0.03)
	var inset: Dictionary = tool.inset_contact_target(guide,0.0015)
	_check(inset.get("valid",false), "square inset available")
	if inset.get("valid",false):
		# An axis-aligned 40 mm square erodes to a 37 mm square. This is
		# independent of the contact solver and checks units/sign/normal offset.
		for point: Vector2 in inset.polygon:
			_check(absf(absf(point.x)-0.0185)<0.000005 and absf(absf(point.y)-0.0185)<0.000005, "square has independently expected 1.5 mm inset")
		_check(not tool.inset_contact_target(inset,0.0015).valid, "double offset rejected")
	_check(not tool.inset_contact_target(guide,-0.0015).valid, "outward request rejected")
	_check(not tool.inset_contact_target(guide,NAN).valid, "nonfinite request rejected")
	_check(not tool.inset_contact_target(guide,0.03).valid, "vanished target reported")
	var anonymous := guide.duplicate(true); anonymous.erase("origin_id")
	_check(not tool.inset_contact_target(anonymous,0.0015).valid, "anonymous target rejected")
	var circle := {"valid":true,"polygon":PackedVector2Array(),"center":Vector2(0.002,-0.003),
		"radius_m":0.05,"origin_id":&"InsetTestPlane","source_id":&"Circle","geometry_fingerprint":"circle_50mm"}
	var reduced: Dictionary = tool.inset_contact_target(circle,0.0015)
	_check(reduced.get("valid",false) and absf(reduced.get("radius_m",0.0)-0.0485)<1e-12 and reduced.center==circle.center, "circle loses radius, not center")
	_check(circle.radius_m==0.05 and not circle.has("contact_target_offset_m"), "circle input is immutable")
	_check(not tool.inset_contact_target(circle,0.05).valid, "collapsed circle rejected")
	var dumbbell := PackedVector2Array([Vector2(-0.02,-0.01),Vector2(-0.004,-0.01),Vector2(-0.004,-0.0005),Vector2(0.004,-0.0005),Vector2(0.004,-0.01),Vector2(0.02,-0.01),Vector2(0.02,0.01),Vector2(0.004,0.01),Vector2(0.004,0.0005),Vector2(-0.004,0.0005),Vector2(-0.004,0.01),Vector2(-0.02,0.01)])
	var split_input := {"valid":true,"polygon":dumbbell,"center":Vector2.ZERO,"origin_id":&"InsetTestPlane","source_id":&"NarrowBridge"}
	var split: Dictionary = tool.inset_contact_target(split_input,0.0015)
	_check(not split.valid and split.reason=="inward_contact_target_not_one_loop" and split.details.loop_count==2, "split target rejected without choosing an island")


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition: _failures.append(label)
