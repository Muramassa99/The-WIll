extends SceneTree

const Capture = preload("res://tools/grip_plane_proof/capture_grip_placement_stage.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const SavedSource = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const SurfaceQuery = preload("res://runtime/player/grip/grip_surface_query.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Wrapper = preload("res://core/models/prepared_grip_target_wrapper.gd")
var _checks: int = 0
var _failures: Array[String] = []


class AnatomyFixture extends Resource:
	var source_signature: String = "mesh_capture_verifier_fixture"


class BaselineFixture extends RefCounted:
	var animation_grip_baseline_initialized: bool = true
	var animation_grip_baseline_cache: Dictionary = {}


class ActorFixture extends Node3D:
	var skeleton: Skeleton3D
	var mesh_instance: MeshInstance3D
	var finger_grip_presenter: RefCounted
	var anchor: Node3D
	func get_right_hand_item_anchor() -> Node3D:
		return anchor
	func resolve_hand_grip_alignment_world_position(_slot: StringName) -> Vector3:
		return anchor.global_position


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var extractor := Capture.new()
	# All fixture coordinates below belong to Capture.OBJECT_ORIGIN. The 21 um
	# and 13 um details intentionally cannot survive a 0.1 mm grid snap.
	var points := PackedVector3Array([Vector3(0.000013,0.000021,0.000037),
		Vector3(0.010013,0.000021,0.000037), Vector3(0.000013,0.010021,0.000037),
		Vector3(0.010013,0.010021,0.000037)])
	var indices := PackedInt32Array([2,0,1,2,1,3])
	var indexed: Array = _arrays(points,indices)
	var nonindexed: Array = _arrays(PackedVector3Array([points[3],points[1],points[2]]))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,indexed)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,nonindexed)
	var copied: Dictionary = extractor.extract_object_triangle_faces(mesh)
	_check(copied.get("valid",false),"mixed indexed/nonindexed triangle surfaces accepted")
	var expected := PackedVector3Array([points[2],points[0],points[1],points[2],points[1],points[3],points[3],points[1],points[2]])
	if copied.get("valid",false):
		_check(copied.local_faces == expected,"rendered surface coordinates retained exactly")
		_check(copied.source_surface_count == 2,"all source surfaces copied")
		_check(copied.local_faces_origin_id == Capture.OBJECT_ORIGIN,"copied faces retain established named origin")
		_check(copied.geometry_policy == Capture.GEOMETRY_POLICY,"direct array policy recorded")
		_check(copied.local_face_sources.size() == 3,"one provenance record per output triangle")
		_check(copied.local_face_sources[0] == {"surface_index":0,"triangle_index":0,"vertex_indices":PackedInt32Array([2,0,1]),"indexed":true},"indexed first-triangle provenance")
		_check(copied.local_face_sources[1] == {"surface_index":0,"triangle_index":1,"vertex_indices":PackedInt32Array([2,1,3]),"indexed":true},"indexed second-triangle provenance")
		_check(copied.local_face_sources[2] == {"surface_index":1,"triangle_index":0,"vertex_indices":PackedInt32Array([0,1,2]),"indexed":false},"nonindexed provenance restarts at source surface")
		var snapped := expected.duplicate()
		for index: int in range(snapped.size()):
			snapped[index] = snapped[index].snapped(Vector3(0.0001,0.0001,0.0001))
		_check(copied.local_faces != snapped,"sub-0.1 mm details distinguish old grid-snapped geometry")
		var changed: PackedVector3Array = copied.local_faces
		changed[0] += Vector3(1,1,1)
		_check(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == points,"editing returned packet cannot mutate source vertices")
	_check(not extractor.extract_object_triangle_faces(null).get("valid",false),"null mesh rejected")
	_check(not extractor.extract_object_triangle_faces(ArrayMesh.new()).get("valid",false),"empty mesh rejected")
	_check(not extractor.extract_object_triangle_faces(BoxMesh.new()).get("valid",false),"unsupported mesh class rejected without conversion")
	var lines := ArrayMesh.new()
	lines.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,_arrays(PackedVector3Array([points[0],points[1]])))
	_check(not extractor.extract_object_triangle_faces(lines).get("valid",false),"actual non-triangle mesh rejected")
	for primitive: int in [Mesh.PRIMITIVE_POINTS,Mesh.PRIMITIVE_LINES,Mesh.PRIMITIVE_LINE_STRIP,Mesh.PRIMITIVE_TRIANGLE_STRIP]:
		_reject(extractor,indexed,primitive,0,"unsupported primitive %d" % primitive)
	_reject(extractor,indexed,Mesh.PRIMITIVE_TRIANGLES,-1,"negative surface provenance")
	_reject(extractor,[],Mesh.PRIMITIVE_TRIANGLES,0,"missing vertex arrays")
	_reject(extractor,_arrays(PackedVector3Array()),Mesh.PRIMITIVE_TRIANGLES,0,"empty vertices")
	_reject(extractor,_arrays(PackedVector3Array([points[0],points[1]])),Mesh.PRIMITIVE_TRIANGLES,0,"incomplete nonindexed triangle")
	_reject(extractor,_arrays(points,PackedInt32Array([0,1])),Mesh.PRIMITIVE_TRIANGLES,0,"incomplete indexed triangle")
	_reject(extractor,_arrays(points,PackedInt32Array([-1,1,2])),Mesh.PRIMITIVE_TRIANGLES,0,"negative triangle index")
	_reject(extractor,_arrays(points,PackedInt32Array([0,1,4])),Mesh.PRIMITIVE_TRIANGLES,0,"out-of-bounds triangle index")
	_reject(extractor,_arrays(points,PackedInt32Array([0,0,1])),Mesh.PRIMITIVE_TRIANGLES,0,"degenerate triangle")
	var malformed: Array = indexed.duplicate(true)
	malformed[Mesh.ARRAY_INDEX] = [0,1,2]
	_reject(extractor,malformed,Mesh.PRIMITIVE_TRIANGLES,0,"wrong index container")
	malformed = indexed.duplicate(true); malformed[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.UP])
	_reject(extractor,malformed,Mesh.PRIMITIVE_TRIANGLES,0,"2D vertices rejected")
	malformed = _arrays(PackedVector3Array([Vector3(NAN,0,0),points[1],points[2]]))
	_reject(extractor,malformed,Mesh.PRIMITIVE_TRIANGLES,0,"nonfinite vertices")
	_capture_named_frames(extractor,mesh,expected)
	var report := {"schema":"verify_grip_placement_mesh_capture_v2","ok":_failures.is_empty(),"checks":_checks,
		"failures":_failures,"capture_sha256":FileAccess.get_sha256("res://runtime/player/grip/capture_grip_placement_stage.gd"),
		"production_pose_written":false,"frozen_captures_changed":false,"scope":"strict rendered triangle capture and independent saved-surface capture with downstream validation"}
	var path: String = "C:/WORKSPACE/test_artifacts/verify_grip_placement_mesh_capture_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	if FileAccess.file_exists(path): push_error("Refusing to replace verifier report"); quit(1); return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: push_error("Cannot save mesh capture verification"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MESH_CAPTURE_VERIFIER="+path)
	print("MESH_CAPTURE_SUMMARY="+JSON.stringify(report))
	quit(0 if report.ok else 1)


func _capture_named_frames(extractor: RefCounted, mesh: ArrayMesh, expected: PackedVector3Array) -> void:
	var actor := ActorFixture.new()
	var baseline := BaselineFixture.new()
	# These are existing HandGripAlignment-local baseline offsets; capture only
	# checks their presence. They are not new measured anatomical values.
	var offsets := {&"root":Vector3(0.001,0.002,0.003),&"mid":Vector3(0.002,0.003,0.004),&"end":Vector3(0.003,0.004,0.005)}
	baseline.animation_grip_baseline_cache = {&"hand_right":{"joint_offset_origin_id":Origins.ORIGIN_HAND_GRIP_ALIGNMENT,"joint_offsets":{&"thumb":offsets,&"index":offsets.duplicate(true)}}}
	actor.finger_grip_presenter = baseline
	actor.anchor = Node3D.new(); actor.add_child(actor.anchor)
	get_root().add_child(actor)
	var held := Node3D.new(); get_root().add_child(held)
	held.global_transform = Transform3D(Basis(Vector3.UP,0.23),Vector3(0.31,0.42,0.53))
	var visual := MeshInstance3D.new(); visual.mesh = mesh; visual.set_meta("visual_mesh_source",&"editable_mesh"); held.add_child(visual)
	visual.transform = Transform3D(Basis(Vector3.RIGHT,0.17),Vector3(0.004,0.005,0.006))
	var anatomy := AnatomyFixture.new()
	var machine_to_world := Transform3D(Basis(Vector3.FORWARD,0.11).scaled(Vector3(1.2,1.2,1.2)),Vector3(0.2,0.3,0.4))
	var stage: StringName = &"mesh_copy_verifier"
	var packet := {"valid":true,"engine_process_frame":Engine.get_process_frames(),"capture_stage":stage,
		"anatomy_signature":anatomy.source_signature,"root_origin_id":Origins.ORIGIN_RL_BONE_ROOT,"machine_to_world":machine_to_world}
	var before: Transform3D = held.global_transform
	var captured: Dictionary = extractor.capture(actor,held,anatomy,&"hand_right",stage,1,0,packet)
	_check(captured.get("valid",false),"capture metadata fixture accepted: "+str(captured.get("reason","")))
	if captured.get("valid",false):
		var object: Dictionary = captured.object
		_check(object.local_faces == expected,"capture exports exact source coordinates")
		_check(object.local_faces_origin_id == Capture.OBJECT_ORIGIN,"capture keeps original mesh origin identity")
		_check(object.origin_record.origin_id == Capture.OBJECT_ORIGIN and object.origin_record.parent_origin_id == Origins.ORIGIN_RL_BONE_ROOT,"mesh coordinate chain unchanged")
		_check(object.origin_record.transform_to_parent == machine_to_world.affine_inverse()*visual.global_transform,"mesh affine frame unchanged")
		_check(object.weapon_origin_record.origin_id == Origins.ORIGIN_WEAPON_ROOT and object.weapon_origin_record.parent_origin_id == Origins.ORIGIN_RL_BONE_ROOT,"weapon coordinate chain unchanged")
		_check(object.weapon_origin_record.transform_to_parent == machine_to_world.affine_inverse()*held.global_transform,"weapon affine frame unchanged")
		_check(object.local_face_sources.size() == 3 and captured.object_triangle_count == 3,"capture preserves triangle provenance and count")
		_check(held.global_transform == before and not captured.production_pose_written,"capture does not move the weapon")
	_capture_saved_surface_mode(extractor,actor,held,visual,anatomy,stage,packet)
	held.free(); actor.free()


func _capture_saved_surface_mode(extractor: RefCounted, actor: Node3D, held: Node3D,
		visual: MeshInstance3D, anatomy: Resource, stage: StringName, packet: Dictionary) -> void:
	var source := _saved_source_fixture()
	_check(SurfaceQuery.prepare(source).get("valid",false),"analytical saved handle and wrapper pass production validation")
	held.set_meta(SavedSource.META,source)
	held.set_meta("preview_primary_grip_seat_local",Vector3.ZERO)
	held.set_meta("preview_primary_grip_seat_origin_id",Origins.ORIGIN_WEAPON_ROOT)
	for endpoint: String in ["start","end"]:
		held.set_meta("primary_grip_span_"+endpoint+"_local",Vector3(0,-0.01 if endpoint == "start" else 0.01,0))
		held.set_meta("primary_grip_span_"+endpoint+"_origin_id",Origins.ORIGIN_WEAPON_ROOT)
	var bad_visual := ArrayMesh.new()
	bad_visual.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		_arrays(PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP]),PackedInt32Array([0,0,1])))
	visual.mesh = bad_visual
	var strict: Dictionary = extractor.capture(actor,held,anatomy,&"hand_right",stage,2,0,packet)
	_check(not strict.get("valid",false) and strict.get("reason") == "object_triangle_copy_failed"
		and strict.get("details",{}).get("reason") == "degenerate_or_nonfinite_object_triangle",
		"strict capture still rejects a degenerate rendered triangle")
	var saved: Dictionary = extractor.capture(actor,held,anatomy,&"hand_right",stage,3,0,packet,{},false)
	_check(saved.get("valid",false),"unused bad visual geometry does not block saved-surface capture")
	if saved.get("valid",false):
		_check(not saved.object.rendered_geometry_captured and saved.object.geometry_policy == Capture.SAVED_GEOMETRY_POLICY,
			"saved-source policy explicitly says rendered geometry was not copied")
		_check(not saved.object.has("local_faces") and not saved.object.has("local_face_sources")
			and not saved.has("object_triangle_count"),"skipped rendered geometry has no pretend triangle data or count")
		_check(saved.object.weapon_to_world == held.global_transform
			and saved.object.mesh_to_world == visual.global_transform,"saved-surface capture preserves live coordinate frames")
		_check(saved.object.grip_pivot_local == Vector3.ZERO
			and saved.object.primary_grip_span_start_origin_id == Origins.ORIGIN_WEAPON_ROOT,
			"saved-surface capture retains station metadata and lineage")
		_check(SurfaceQuery.prepare(saved.saved_grip_source).get("valid",false),
			"valid saved handle and wrapper remain usable despite malformed rendered mesh")
		_check(not saved.production_pose_written and not saved.get("grip_accepted",false),
			"successful input capture is not an accepted or applied grip")
	var invalid_frame: Dictionary = packet.duplicate(true)
	invalid_frame.machine_to_world = Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO)
	var frame_rejected: Dictionary = extractor.capture(actor,held,anatomy,&"hand_right",stage,4,0,invalid_frame,{},false)
	_check(not frame_rejected.get("valid",false) and frame_rejected.get("reason") == "invalid_machine_frame",
		"saved-surface mode retains frame validation")
	held.set_meta(SavedSource.META,{"valid":false,"reason":"fixture_saved_source_invalid"})
	var invalid_source: Dictionary = extractor.capture(actor,held,anatomy,&"hand_right",stage,5,0,packet,{},false)
	_check(not invalid_source.get("valid",false) and invalid_source.get("reason") == "fixture_saved_source_invalid",
		"invalid saved-source metadata cannot use rendered-geometry bypass")
	for kind: String in ["handle","wrapper"]:
		var malformed_source: Dictionary = source.duplicate(true)
		if kind == "handle":
			var bad_indices: PackedInt32Array = malformed_source.handle_packet.indices.duplicate()
			bad_indices[0] = 999
			malformed_source.handle_packet.indices = bad_indices
			malformed_source.handle_packet.primary_grip_handle_indices = bad_indices
		else:
			malformed_source.wrapper = source.wrapper.duplicate(true)
			var bad_indices: PackedInt32Array = malformed_source.wrapper.target_indices.duplicate()
			bad_indices[0] = 999
			malformed_source.wrapper.target_indices = bad_indices
		held.set_meta(SavedSource.META,malformed_source)
		var malformed: Dictionary = extractor.capture(actor,held,anatomy,&"hand_right",stage,6,0,packet,{},false)
		_check(malformed.get("valid",false),kind+" topology is left for existing downstream validation")
		_check(not SurfaceQuery.prepare(malformed.get("saved_grip_source",{})).get("valid",false),
			"malformed saved "+kind+" is rejected by production surface validation")
	_check(SurfaceQuery.prepare(source).get("valid",false),"failure fixtures do not mutate the valid saved source")


func _saved_source_fixture() -> Dictionary:
	var vertices := PackedVector3Array([Vector3(-0.01,-0.01,-0.01),Vector3(0.01,-0.01,-0.01),
		Vector3(0.01,0.01,-0.01),Vector3(-0.01,0.01,-0.01),Vector3(-0.01,-0.01,0.01),
		Vector3(0.01,-0.01,0.01),Vector3(0.01,0.01,0.01),Vector3(-0.01,0.01,0.01)])
	var indices := PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5])
	var wrapper := Wrapper.new()
	wrapper.schema_version = Wrapper.SCHEMA_VERSION
	wrapper.construction_revision = Wrapper.CONSTRUCTION_REVISION
	wrapper.source_body_signature = "capture_saved_cube"
	wrapper.source_handle_vertices_m = vertices
	wrapper.source_handle_indices = indices
	wrapper.character_id = &"capture_fixture"
	wrapper.anatomy_signature = "mesh_capture_verifier_fixture"
	wrapper.inward_min_radius_m = 0.05
	wrapper.guide_inward_target_offset_m = 0.001
	wrapper.non_thumb_s1_guide_target_depth_m = 0.001
	wrapper.palm_guide_target_depth_m = 0.001
	var profile := PackedVector2Array([Vector2(-0.01,-0.01),Vector2(0.01,-0.01),Vector2(0.01,0.01),Vector2(-0.01,0.01)])
	for field: String in ["source_profile_m","envelope_profile_m","target_profile_m","palm_target_profile_m","non_thumb_s1_target_profile_m"]:
		wrapper.set(field,profile)
	for prefix: String in ["target","palm_target","non_thumb_s1_target"]:
		wrapper.set(prefix+"_vertices_m",vertices)
		wrapper.set(prefix+"_indices",indices)
	return {"valid":true,"wrapper":wrapper,"handle_packet":HandlePacket.build(vertices,indices,wrapper.source_body_signature),
		"source_origin_id":SavedSource.SOURCE_ORIGIN,"source_parent_origin_id":Origins.ORIGIN_WEAPON_ROOT,
		"metric_units":&"meters","source_to_weapon":Transform3D.IDENTITY}


func _arrays(vertices: PackedVector3Array, indices: PackedInt32Array = PackedInt32Array()) -> Array:
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not indices.is_empty(): arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


func _reject(extractor: RefCounted, arrays: Array, primitive: int, surface: int, label: String) -> void:
	var result: Dictionary = extractor.copy_triangle_surface_arrays(arrays,primitive,surface)
	_check(not result.get("valid",false) and not result.has("local_faces"),label+" rejected without partial geometry")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition: _failures.append(label)
