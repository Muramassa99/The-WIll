extends SceneTree

## Whole-packet replacement proof, not a new geometry or acceptance policy.
## Includes native Variant conversion in timings; never applies a character pose.
const SliceReference = preload("res://runtime/player/grip/slice_reachable_surface.gd")
const TopologyReference = preload("res://runtime/player/grip/skin_plane_contact_query.gd")
const LIBRARY := "C:/WORKSPACE/test_artifacts/forge_v2_grip_target_wrapper_2026-09-28T03-59-21_straight_library.tres"
const LIBRARY_HASH := "8d6920bbf783e983499aee5c42ae59b23867475dcfacc243d691f626bae7dfa6"
const CAPTURE := "C:/WORKSPACE/test_artifacts/contact_driven_preparation_2026-10-01T00-31-21.json"
const CAPTURE_HASH := "7e7f5731c1a6dad5eec4961c1d7530afdc6af50b1754de885f8ee68eb710a34f"
const TOPOLOGY_CAPTURE := "C:/WORKSPACE/test_artifacts/saved_grip_section_coordinates_2026-09-28T11-45-33.json"
const TOPOLOGY_CAPTURE_HASH := "56ef1ee23b3d3ed2ccabc03be3d710f67433cae6e3e3544d182c27d92b995d5f"
const PLANE := &"NativeSectionVerificationPlaneOrigin"
const ROOT := &"RL_BoneRoot"
const SCALAR_ERROR := 0.000000000001
const VECTOR_ERROR := 0.00000001
var _slice_reference := SliceReference.new()
var _topology_reference := TopologyReference.new()
var _slice_native: Object
var _topology_native: Object
var _checks: Array = []
var _cases: Array = []
var _benchmark_inputs: Array = []
var _benchmarks: Array = []
var _failures := 0
var _captured_slice_cases := 0
var _captured_topology_cases := 0
var _preserved_invalid_topologies := 0
var _started := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_started = Time.get_ticks_usec()
	if not _check(ClassDB.class_exists(&"GripSliceKernel") and ClassDB.class_exists(&"GripTopologyKernel"),"both compiled section classes are registered"):
		_finish(); return
	_slice_native=ClassDB.instantiate(&"GripSliceKernel")
	_topology_native=ClassDB.instantiate(&"GripTopologyKernel")
	if not _check(_slice_native!=null and _topology_native!=null,"both compiled section instances are available"):
		_finish(); return
	for input: Array in [[LIBRARY,LIBRARY_HASH],[CAPTURE,CAPTURE_HASH],[TOPOLOGY_CAPTURE,TOPOLOGY_CAPTURE_HASH]]:
		if not _check(FileAccess.get_sha256(input[0])==input[1],"frozen input SHA256: "+input[0]):
			_finish(); return
	_synthetic_slices()
	_synthetic_topologies()
	_captured_slices()
	_captured_topologies()
	_check(_captured_slice_cases==12,"twelve real triangle slices cover both hands, Middle/Thumb and three target surfaces")
	_check(_captured_topology_cases==60,"all sixty frozen source/frame/digit topology cases compared")
	_check(_preserved_invalid_topologies>=6,"previously invalid cap sections remain uncertified")
	_benchmark()
	for input: Array in [[LIBRARY,LIBRARY_HASH],[CAPTURE,CAPTURE_HASH],[TOPOLOGY_CAPTURE,TOPOLOGY_CAPTURE_HASH]]:
		_check(FileAccess.get_sha256(input[0])==input[1],"frozen input unchanged: "+input[0])
	_finish()


func _synthetic_slices() -> void:
	var box := _box(Vector3(-0.01,-0.015,-0.02),Vector3(0.01,0.015,0.02))
	var surface := _surface(box,true)
	var closed := _compare_slice("synthetic/closed_box",surface,Transform3D.IDENTITY,PLANE,0.1,0.0)
	_check(closed.get("valid",false) and closed.contours.size()==1 and not closed.classification_incomplete,"closed box retains one genuine complete contour")
	var clipped := _compare_slice("synthetic/clipped_box",surface,Transform3D.IDENTITY,PLANE,0.016,0.0)
	_check(clipped.get("valid",false) and clipped.counts.segments_clipped>0 and clipped.contours.is_empty()
		and clipped.classification_incomplete,"clipped square is open arcs without invented disk-boundary edges")
	var coplanar := _compare_slice("synthetic/coplanar_face",surface,Transform3D(Basis.IDENTITY,Vector3(0,0,0.02)),PLANE,0.1,0.0)
	_check(coplanar.get("valid",false) and coplanar.counts.coplanar_triangles==2 and coplanar.classification_incomplete,"coplanar face remains explicitly incomplete")
	_compare_slice("synthetic/translated_plane",surface,Transform3D(Basis.IDENTITY,Vector3(0.006,-0.007,0.003)),PLANE,0.1,0.0)
	_compare_slice("synthetic/diagonal_plane",surface,Transform3D(Basis(Vector3(1,2,3).normalized(),0.73),Vector3(0.002,-0.001,0)),PLANE,0.1,0.0)
	var frame := Transform3D(Basis(Vector3(1,2,3).normalized(),0.73),Vector3(2,-3,4))
	_compare_slice("synthetic/rigid_frame_and_surface",_surface(frame*box,true),frame,PLANE,0.1,0.0)
	var far_frame := Transform3D(Basis.IDENTITY,Vector3(1024,-2048,512))
	_compare_slice("synthetic/large_translated_coordinates",_surface(far_frame*box,true),far_frame,PLANE,0.1,0.0)
	var opened := box.duplicate()
	for _index: int in 6: opened.remove_at(12)
	var open := _compare_slice("synthetic/open_surface",_surface(opened,false),Transform3D.IDENTITY,PLANE,0.1,0.0)
	_check(open.get("valid",false) and open.classification_incomplete and open.counts.open_or_branched_vertices>0,"open geometry remains incomplete")
	var doubled := box.duplicate()
	doubled.append_array(Transform3D(Basis.IDENTITY,Vector3(0.1,0,0))*box)
	var multiple := _compare_slice("synthetic/two_disconnected_closed_loops",_surface(doubled,true),Transform3D.IDENTITY,PLANE,0.3,0.0)
	_check(multiple.get("valid",false) and multiple.contours.size()==2,"two genuine disconnected loops stay distinct")
	var crossing := _surface(PackedVector3Array([Vector3(-4,0,-2),Vector3(4,0,-2),Vector3(0,0,2)]))
	var crossed := _compare_slice("synthetic/crossing_all_vertices_outside_reach",crossing,Transform3D.IDENTITY,PLANE,1.0,0.25)
	_check(crossed.get("valid",false) and crossed.segments.size()==1 and crossed.counts.segments_clipped==1
		and crossed.contours.is_empty(),"disk clipping retains crossing triangle even when all three source vertices are outside reach")
	_compare_slice("synthetic/reach_pruned",_surface(PackedVector3Array([Vector3(5,-1,-1),Vector3(5,1,-1),Vector3(5,0,1)])),Transform3D.IDENTITY,PLANE,1.0,0.0)
	_compare_slice("synthetic/plane_misses_box",surface,Transform3D(Basis.IDENTITY,Vector3(0,0,0.5)),PLANE,1.0,0.0)
	var coplanar_mesh := PackedVector3Array([Vector3(-0.01,-0.01,0),Vector3(0.01,-0.01,0),Vector3(0.01,0.01,0),
		Vector3(-0.01,-0.01,0),Vector3(0.01,0.01,0),Vector3(-0.01,0.01,0)])
	_compare_slice("synthetic/coplanar_shared_diagonal_cancels",_surface(coplanar_mesh),Transform3D.IDENTITY,PLANE,0.1,0.0)
	coplanar_mesh.append_array(coplanar_mesh.duplicate())
	_compare_slice("synthetic/coplanar_even_duplicate_edges_cancel",_surface(coplanar_mesh),Transform3D.IDENTITY,PLANE,0.1,0.0)
	# One-um plane predicate and one-um squared clipping threshold remain exact
	# decisions. These fixtures compare both sides without granting any tolerance.
	for scale: float in [0.999,1.0,1.001]:
		var height: float=SliceReference.DISTANCE_EPSILON*scale
		var triangle := PackedVector3Array([Vector3(-0.01,0,height),Vector3(0.01,0,height),Vector3(0,0.02,0.01)])
		_compare_slice("synthetic/plane_epsilon_"+str(scale),_surface(triangle),Transform3D.IDENTITY,PLANE,0.1,0.0)
		var tiny := PackedVector3Array([Vector3(0,0,0),Vector3(0.000001*scale,0,0),Vector3(0,0.01,0.01)])
		_compare_slice("synthetic/clip_length_threshold_"+str(scale),_surface(tiny),Transform3D.IDENTITY,PLANE,0.1,0.0)
	# Edge insertion, bucket rounding and first representative order also matter.
	var ties := PackedVector3Array([Vector3(-0.0000005,0,0),Vector3(0.02,0,0),Vector3(0,0.01,0.01),
		Vector3(0.0000005,0,0),Vector3(0.02,0.01,0),Vector3(0,0.02,0.01)])
	_compare_slice("synthetic/weld_bucket_half_steps",_surface(ties),Transform3D.IDENTITY,PLANE,0.1,0.0)
	var bowtie := PackedVector2Array([Vector2(0.0625,-0.0078125),Vector2(0.078125,0.0078125),Vector2(0.0625,0.0078125),Vector2(0.078125,-0.0078125)])
	var omitted := box.duplicate()
	for index: int in bowtie.size():
		var a: Vector2=bowtie[index]
		var b: Vector2=bowtie[(index+1)%bowtie.size()]
		var corners:=PackedVector3Array([Vector3(a.x,a.y,-0.03125),Vector3(b.x,b.y,-0.03125),Vector3(b.x,b.y,0.03125),Vector3(a.x,a.y,0.03125)])
		for corner: int in [0,1,2,0,2,3]: omitted.append(corners[corner])
	_compare_slice("synthetic/zero_area_disconnected_cycle",_surface(omitted,true),Transform3D(Basis.IDENTITY,Vector3(0,0,0.0078125)),PLANE,0.3,0.0)
	_invalid_slices(surface)


func _invalid_slices(surface: Dictionary) -> void:
	_compare_slice("invalid/missing_plane_origin",surface,Transform3D.IDENTITY,&"",0.1,0.0)
	_compare_slice("invalid/scaled_plane",surface,Transform3D(Basis.from_scale(Vector3(2,1,1)),Vector3.ZERO),PLANE,0.1,0.0)
	_compare_slice("invalid/reflected_plane",surface,Transform3D(Basis.from_scale(Vector3(-1,1,1)),Vector3.ZERO),PLANE,0.1,0.0)
	_compare_slice("invalid/nonfinite_plane",surface,Transform3D(Basis.IDENTITY,Vector3(INF,0,0)),PLANE,0.1,0.0)
	for radius: float in [0.0,-0.01,INF,NAN,1.0e200]:
		_compare_slice("invalid/reach_"+str(radius),surface,Transform3D.IDENTITY,PLANE,radius,0.0)
	for padding: float in [-0.001,INF,NAN]:
		_compare_slice("invalid/padding_"+str(padding),surface,Transform3D.IDENTITY,PLANE,0.1,padding)
	_compare_slice("invalid/empty_surface",{},Transform3D.IDENTITY,PLANE,0.1,0.0)
	for field: String in ["surface_source_origin_id","resolved_world_origin_id"]:
		var missing:=surface.duplicate(true)
		missing.erase(field)
		_compare_slice("invalid/missing_"+field,missing,Transform3D.IDENTITY,PLANE,0.1,0.0)
	_compare_slice("invalid/no_triangles",_surface(PackedVector3Array()),Transform3D.IDENTITY,PLANE,0.1,0.0)
	_compare_slice("invalid/nontriangle_count",_surface(PackedVector3Array([Vector3.ZERO])),Transform3D.IDENTITY,PLANE,0.1,0.0)
	var nonfinite: PackedVector3Array=surface.triangles_world.duplicate()
	nonfinite[4]=Vector3(NAN,0,0)
	_compare_slice("invalid/nonfinite_after_visited_triangle",_surface(nonfinite),Transform3D.IDENTITY,PLANE,0.1,0.0)
	var wrong_type:=surface.duplicate(true)
	wrong_type.triangles_world=[]
	_compare_slice("invalid/nonpacked_triangle_storage",wrong_type,Transform3D.IDENTITY,PLANE,0.1,0.0)


func _synthetic_topologies() -> void:
	for count: int in [4,63,64,65,500]:
		_compare_topology("synthetic/round_"+str(count),_polygon(_round(count)),PLANE)
	var star:=_round(500)
	for index: int in star.size(): star[index]*=0.2 if index%2 else 1.0
	var star_edges:=_polygon(star)
	_compare_topology("synthetic/alternating_concave_500",star_edges,PLANE)
	var reordered: Array=[]
	for index: int in star_edges.size(): reordered.append(star_edges[(index*137)%star_edges.size()])
	_compare_topology("synthetic/unordered_concave_500",reordered,PLANE)
	var crossing: Array=[]
	var ring:=_round(128)
	for index: int in ring.size(): crossing.append([ring[index],ring[(index+63)%ring.size()]])
	var crossed:=_compare_topology("synthetic/many_crossings_first_twelve",crossing,PLANE)
	_check(crossed.get("valid",false) and crossed.topology.self_intersections>12
		and crossed.topology.self_intersection_pairs.size()==12,"first twelve ordered intersection diagnostics are exercised")
	var duplicates:=_polygon(_round(80))
	duplicates.append(duplicates[3].duplicate(true)); duplicates.append(duplicates[40].duplicate(true))
	_compare_topology("synthetic/duplicate_edges",duplicates,PLANE)
	var near_weld:=_polygon(_round(80))
	near_weld[30].a+=Vector2(0.0000002,0)
	near_weld[31].b+=Vector2(0.0000011,0)
	_compare_topology("synthetic/endpoint_weld_boundary",near_weld,PLANE)
	for scale: float in [0.999,1.0,1.001]:
		_compare_topology("synthetic/sub_epsilon_edge_"+str(scale),[[Vector2.ZERO,Vector2(0.000001*scale,0)]],PLANE)
	var coplanar:=_polygon(_round(80))
	coplanar[20].coplanar=true
	_compare_topology("synthetic/coplanar_flag",coplanar,PLANE)
	var opened:=_polygon(_round(80)); opened.remove_at(12)
	_compare_topology("synthetic/open_boundary",opened,PLANE)
	var branch:=_polygon(_round(80)); branch.append([branch[0].a,Vector2(-0.3,0.2)])
	_compare_topology("synthetic/branched_boundary",branch,PLANE)
	var translated:=_round(80)
	for index: int in translated.size(): translated[index]+=Vector2(1024,-2048)
	_compare_topology("synthetic/large_coordinates",_polygon(translated),PLANE)
	var repeated: Array=[[Vector2.ZERO,Vector2(0.02,0.02)],[Vector2(0.0000018,0),Vector2(0.03,0.03)]]
	for index: int in 4: repeated.append([Vector2(0.0000009,0),Vector2(0.04+0.01*index,0.04+0.01*index)])
	var memo:=_compare_topology("synthetic/ambiguous_first_representative",repeated,PLANE)
	_check(memo.get("valid",false) and memo.topology.noncoincident_endpoint_welds==4,"all repeated noncoincident weld occurrences remain counted")
	if memo.get("valid",false):
		for index: int in range(2,repeated.size()):
			_check(memo.segments[index].vertex_ids[0]==0,"earliest compatible representative retained at repeated endpoint "+str(index))
	_compare_topology("synthetic/signed_zero_keys",[[Vector2(0.0,-0.0),Vector2(1,0)],
		[Vector2(-0.0,0.0),Vector2(0,1)],[Vector2(0.0,0.0),Vector2(-1,0)]],PLANE)
	var mixed: Array=_polygon(_round(4))
	mixed[0].dynamic=false; mixed[0].source_id=&"PreservedFixtureEdge"; mixed[0].custom={"weights":Vector3(0.1,0.2,0.7),"labels":[&"a",&"b"]}
	mixed[1]=[mixed[1].a,mixed[1].b]
	mixed[2]=PackedVector2Array([mixed[2].a,mixed[2].b])
	_compare_topology("synthetic/mixed_edge_representations_and_metadata",mixed,PLANE)
	_compare_topology("invalid/empty",[],PLANE)
	_compare_topology("invalid/zero_length",[[Vector2.ONE,Vector2.ONE]],PLANE)
	_compare_topology("invalid/nonfinite",[[Vector2(NAN,0),Vector2.ONE]],PLANE)
	_compare_topology("invalid/missing_endpoint",[{"a":Vector2.ZERO}],PLANE)
	_compare_topology("invalid/wrong_endpoint_type",[[Vector3.ZERO,Vector2.ONE]],PLANE)
	_compare_topology("invalid/unsupported_edge_type",[42],PLANE)
	_compare_topology("invalid/missing_origin",star_edges,&"")


func _captured_slices() -> void:
	var library: Resource=ResourceLoader.load(LIBRARY,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not _check(library!=null and library.saved_wips.size()==1,"one frozen Forge weapon loads"): return
	var stage2: Resource=library.saved_wips[0].stage2_item_state
	var wrapper: Resource=stage2.primary_grip_target_wrapper
	if not _check(wrapper!=null,"frozen weapon contains prepared wrapper geometry"): return
	var arrays: Array=stage2.primary_grip_handle_mesh_state.surface_arrays
	var physical_vertices:=PackedVector3Array()
	for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: physical_vertices.append(vertex*stage2.cell_world_size_meters)
	var surfaces: Dictionary={
		"handle":_indexed_faces(physical_vertices,arrays[Mesh.ARRAY_INDEX]),
		"digit_target":_indexed_faces(wrapper.get("target_vertices_m"),wrapper.get("target_indices")),
		"palm_target":_indexed_faces(wrapper.get("palm_target_vertices_m"),wrapper.get("palm_target_indices"))}
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(CAPTURE))
	if not _check(raw is Dictionary and raw.get("cases") is Array,"current hand capture parses"): return
	for hand: Dictionary in raw.cases:
		var follower: Dictionary={}
		for stage: Dictionary in hand.stages:
			if stage.label=="follower_response_fixed_weapon": follower=stage; break
		if not _check(not follower.is_empty(),str(hand.slot)+": captured follower found"): continue
		for stage: Dictionary in [hand.selected,follower]:
			if not _check(stage.digits.size()==1,"one explicit captured digit plane"): continue
			var digit: Dictionary=stage.digits[0]
			var plane:=_transform(digit.plane_to_world)
			var weapon:=_transform(stage.weapon_to_world)
			var id:=StringName(digit.origin_id)
			for kind: String in surfaces:
				var faces: PackedVector3Array=weapon*surfaces[kind]
				var surface:=_surface(faces,false,&"WeaponRootOrigin")
				var reach:=0.0
				for point: Vector3 in faces: reach=maxf(reach,point.distance_to(plane.origin))
				reach+=0.0001
				var label: String="captured/"+str(hand.slot)+"/"+str(digit.digit)+"/"+kind
				var result:=_compare_slice(label,surface,plane,id,reach,0.0,true)
				_check(result.get("valid",false) and not result.get("segments",[]).is_empty(),label+": actual saved geometry yields section segments")
				_captured_slice_cases+=1


func _captured_topologies() -> void:
	var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(TOPOLOGY_CAPTURE))
	if not _check(data is Dictionary and data.get("cases") is Array,"frozen topology capture parses"): return
	for capture: Dictionary in data.cases:
		for kind: String in capture.surfaces:
			for digit: String in capture.surfaces[kind]:
				for frame: String in ["world","weapon"]:
					var section: Dictionary=capture.surfaces[kind][digit][frame]
					var edges: Array=[]
					for raw_contour: Array in section.raw_contours:
						var points:=PackedVector2Array()
						for point: Array in raw_contour: points.append(Vector2(float(point[0]),float(point[1])))
						if points.size()>1 and points[0]==points[-1]: points.remove_at(points.size()-1)
						edges.append_array(_polygon(points))
					var origin:=StringName(section.coordinate_provenance.query_origin_id)
					var label: String="frozen/"+str(capture.slot)+"/"+kind+"/"+digit+"/"+frame
					var benchmark: bool=frame=="weapon" and digit.to_lower() in ["middle","thumb"]
					var result:=_compare_topology(label,edges,origin,benchmark)
					_captured_topology_cases+=1
					if not bool(section.valid):
						var retained: bool=not result.get("topology_complete",false)
						_check(retained,label+": known invalid cap is not silently certified")
						_preserved_invalid_topologies+=int(retained)


func _compare_slice(label: String,surface: Dictionary,plane: Transform3D,origin: StringName,reach: float,padding: float,benchmark: bool=false) -> Dictionary:
	var input_before:=var_to_bytes([surface,plane,origin,reach,padding])
	var input: Dictionary={"kind":"slice","label":label,"surface":surface,"plane":plane,"origin":origin,"reach":reach,"padding":padding}
	var measured:=_measure(input,_cases.size()%2==0)
	var reference: Dictionary=measured.reference
	var native: Dictionary=measured.native
	var difference:=_difference(reference,native,"slice")
	_check(difference.is_empty(),label+": complete ordered slice packet matches: "+difference)
	_check(var_to_bytes([surface,plane,origin,reach,padding])==input_before,label+": input surface/frame unchanged")
	if label.begins_with("invalid/"): _check(not reference.get("valid",false),label+": invalid input remains rejected")
	_cases.append({"kernel":"slice","label":label,"parity":difference.is_empty(),"difference":difference,
		"reference_usec":measured.reference_usec,"native_usec":measured.native_usec,"source_triangles":surface.get("triangles_world",[]).size()/3,
		"valid":native.get("valid",false),"status":native.get("status",""),"counts":native.get("counts",{}),
		"contour_count":native.get("contours",[]).size(),"classification_incomplete":native.get("classification_incomplete",true)})
	if benchmark: _benchmark_inputs.append(input)
	return reference


func _compare_topology(label: String,segments: Array,origin: StringName,benchmark: bool=false) -> Dictionary:
	var input_before:=var_to_bytes(segments)
	var input: Dictionary={"kind":"topology","label":label,"segments":segments,"origin":origin}
	var measured:=_measure(input,_cases.size()%2==0)
	var reference: Dictionary=measured.reference
	var native: Dictionary=measured.native
	var difference:=_difference(reference,native,"topology")
	_check(difference.is_empty(),label+": complete topology packet and diagnostic order match: "+difference)
	_check(var_to_bytes(segments)==input_before,label+": raw segment order/metadata unchanged")
	if label.begins_with("invalid/"): _check(not reference.get("valid",false),label+": invalid topology input remains rejected")
	_cases.append({"kernel":"topology","label":label,"parity":difference.is_empty(),"difference":difference,
		"reference_usec":measured.reference_usec,"native_usec":measured.native_usec,"edge_count":segments.size(),
		"valid":native.get("valid",false),"reason":native.get("reason",""),"topology_complete":native.get("topology_complete",false),
		"topology":native.get("topology",{})})
	if benchmark: _benchmark_inputs.append(input)
	return reference


func _measure(input: Dictionary,native_first: bool) -> Dictionary:
	var reference: Dictionary
	var native: Dictionary
	var reference_usec: int
	var native_usec: int
	var started: int
	if native_first:
		started=Time.get_ticks_usec(); native=_call_native(input); native_usec=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec(); reference=_call_reference(input); reference_usec=Time.get_ticks_usec()-started
	else:
		started=Time.get_ticks_usec(); reference=_call_reference(input); reference_usec=Time.get_ticks_usec()-started
		started=Time.get_ticks_usec(); native=_call_native(input); native_usec=Time.get_ticks_usec()-started
	return {"reference":reference,"native":native,"reference_usec":reference_usec,"native_usec":native_usec}


func _call_reference(input: Dictionary) -> Dictionary:
	if input.kind=="slice": return _slice_reference.slice(input.surface,input.plane,input.origin,input.reach,input.padding)
	return _topology_reference.prepare_target(input.segments,input.origin)


func _call_native(input: Dictionary) -> Dictionary:
	if input.kind=="slice": return _slice_native.call("slice",input.surface,input.plane,input.origin,input.reach,input.padding)
	return _topology_native.call("prepare_target",input.segments,input.origin)


func _benchmark() -> void:
	var slice_cases:=0
	var topology_cases:=0
	for input: Dictionary in _benchmark_inputs:
		if input.kind=="slice": slice_cases+=1
		else: topology_cases+=1
		var reference_times: Array[int]=[]
		var native_times: Array[int]=[]
		for repeat: int in 3:
			var measured:=_measure(input,repeat%2==0)
			reference_times.append(measured.reference_usec); native_times.append(measured.native_usec)
			var difference:=_difference(measured.reference,measured.native,"benchmark")
			_check(difference.is_empty(),input.label+": repeated full-packet parity "+str(repeat)+" "+difference)
		var old_sorted:=reference_times.duplicate(); old_sorted.sort()
		var new_sorted:=native_times.duplicate(); new_sorted.sort()
		_benchmarks.append({"kernel":input.kind,"label":input.label,"reference_usec":reference_times,"native_usec":native_times,
			"reference_median_usec":old_sorted[1],"native_median_usec":new_sorted[1],"median_speedup":float(old_sorted[1])/float(maxi(1,new_sorted[1]))})
	_check(slice_cases==12,"all twelve captured triangle packets receive three repeated timing comparisons")
	_check(topology_cases==12,"both Middle/Thumb and three saved sources per hand receive three repeated topology timings")


func _difference(before: Variant,after: Variant,path: String) -> String:
	if (before is String or before is StringName) and (after is String or after is StringName):
		return "" if String(before)==String(after) else path+": text differs"
	if (before is float or before is int) and (after is float or after is int):
		if before is int: return "" if before==after else path+": integer differs ("+str(before)+" vs "+str(after)+")"
		if is_nan(float(before)) and is_nan(float(after)): return ""
		if not is_finite(float(before)) or not is_finite(float(after)): return "" if before==after else path+": nonfinite value differs"
		return "" if absf(float(before)-float(after))<=SCALAR_ERROR else path+": scalar difference "+str(absf(float(before)-float(after)))
	if before is Vector2 and after is Vector2:
		return "" if before.distance_to(after)<=VECTOR_ERROR else path+": Vector2 difference "+str(before.distance_to(after))
	if before is Vector3 and after is Vector3:
		return "" if before.distance_to(after)<=VECTOR_ERROR else path+": Vector3 difference "+str(before.distance_to(after))
	if typeof(before)!=typeof(after): return path+": value type differs"
	if before is Dictionary:
		if before.size()!=after.size(): return path+": dictionary size differs"
		for key: Variant in before:
			if not after.has(key): return path+": missing key "+str(key)
			var difference:=_difference(before[key],after[key],path+"."+str(key))
			if not difference.is_empty(): return difference
		return ""
	if before is Array or before is PackedVector2Array or before is PackedVector3Array or before is PackedInt32Array or before is PackedFloat64Array:
		if before.size()!=after.size(): return path+": array size differs ("+str(before.size())+" vs "+str(after.size())+")"
		for index: int in before.size():
			var difference:=_difference(before[index],after[index],path+"["+str(index)+"]")
			if not difference.is_empty(): return difference
		return ""
	return "" if before==after else path+": value differs"


func _surface(triangles: PackedVector3Array,closed: bool=false,source: StringName=&"NativeSectionFixtureWeaponOrigin") -> Dictionary:
	return {"valid":true,"triangles_world":triangles,"surface_source_origin_id":source,"resolved_world_origin_id":ROOT,
		"capsule_surface_topology":{"valid":true,"closed":closed}}


func _box(low: Vector3,high: Vector3) -> PackedVector3Array:
	var vertices:=PackedVector3Array([Vector3(low.x,low.y,low.z),Vector3(high.x,low.y,low.z),Vector3(high.x,high.y,low.z),Vector3(low.x,high.y,low.z),
		Vector3(low.x,low.y,high.z),Vector3(high.x,low.y,high.z),Vector3(high.x,high.y,high.z),Vector3(low.x,high.y,high.z)])
	var triangles:=PackedVector3Array()
	for face: Array in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		for index: int in [face[0],face[1],face[2],face[0],face[2],face[3]]: triangles.append(vertices[index])
	return triangles


func _indexed_faces(vertices: PackedVector3Array,indices: PackedInt32Array) -> PackedVector3Array:
	var result:=PackedVector3Array()
	result.resize(indices.size())
	for index: int in indices.size(): result[index]=vertices[indices[index]]
	return result


func _round(count: int) -> PackedVector2Array:
	var points:=PackedVector2Array()
	for index: int in count: points.append(Vector2.from_angle(TAU*float(index)/float(count))*0.04)
	return points


func _polygon(points: PackedVector2Array) -> Array:
	var segments: Array=[]
	for index: int in points.size(): segments.append({"a":points[index],"b":points[(index+1)%points.size()]})
	return segments


func _transform(packet: Dictionary) -> Transform3D:
	return Transform3D(Basis(_vector3(packet.basis[0]),_vector3(packet.basis[1]),_vector3(packet.basis[2])),_vector3(packet.origin))


func _vector3(values: Array) -> Vector3:
	return Vector3(float(values[0]),float(values[1]),float(values[2]))


func _check(condition: bool,label: String) -> bool:
	_checks.append({"passed":condition,"label":label})
	if not condition: _failures+=1; push_error(label)
	return condition


func _json(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary={}
		for key: Variant in value: out[String(key)]=_json(value[key])
		return out
	if value is Vector2: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is float and not is_finite(value): return str(value)
	if value is Array or value is PackedVector2Array or value is PackedVector3Array or value is PackedInt32Array or value is PackedFloat64Array:
		var out: Array=[]
		for item: Variant in value: out.append(_json(item))
		return out
	return value


func _finish() -> void:
	var path: String="C:/WORKSPACE/test_artifacts/native_section_kernels_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	var report: Dictionary={"schema":"native_section_kernels_verification_v1","passed":_failures==0,"checks":_checks,"failures":_failures,
		"cases":_cases,"benchmarks":_benchmarks,"duration_ms":float(Time.get_ticks_usec()-_started)/1000.0,
		"library":LIBRARY,"library_sha256":LIBRARY_HASH,"capture":CAPTURE,"capture_sha256":CAPTURE_HASH,
		"topology_capture":TOPOLOGY_CAPTURE,"topology_capture_sha256":TOPOLOGY_CAPTURE_HASH,
		"slice_reference_sha256":FileAccess.get_sha256("res://runtime/player/grip/slice_reachable_surface.gd"),
		"topology_reference_sha256":FileAccess.get_sha256("res://runtime/player/grip/skin_plane_contact_query.gd"),
		"scalar_error_limit":SCALAR_ERROR,"vector_error_limit_m":VECTOR_ERROR,
		"captured_slice_cases":_captured_slice_cases,"captured_topology_cases":_captured_topology_cases,
		"preserved_invalid_topologies":_preserved_invalid_topologies,
		"comparison_scope":"Complete result dictionaries, ordered segments/contours, preserved metadata, reasons, counts, provenance and first twelve ordered topology diagnostics. No fields removed.",
		"timing_scope":"Three repeats after warm-up, alternating order; full native call and Variant packet construction/conversion included. Input preparation, comparison, hashing and report writing excluded. Slice timings use whole captured source triangle soups, not the live broad-phase subset. Not full-grip timings.",
		"production_pose_written":false,"geometry_or_tolerances_changed":false,"actual_3d_grip_verified":false}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: _check(false,"write native section report")
	else: file.store_string(JSON.stringify(_json(report),"\t")); file.close()
	print("NATIVE_SECTION_KERNELS ","PASS" if _failures==0 else "FAIL"," checks=",_checks.size()," failures=",_failures," report=",path)
	quit(0 if _failures==0 else 1)
