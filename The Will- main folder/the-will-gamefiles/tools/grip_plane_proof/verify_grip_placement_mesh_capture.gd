extends SceneTree

const Capture = preload("res://tools/grip_plane_proof/capture_grip_placement_stage.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
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
	var report := {"schema":"verify_grip_placement_mesh_capture_v1","ok":_failures.is_empty(),"checks":_checks,
		"failures":_failures,"capture_sha256":FileAccess.get_sha256("res://tools/grip_plane_proof/capture_grip_placement_stage.gd"),
		"production_pose_written":false,"frozen_captures_changed":false,"scope":"direct triangle copy and preserved capture coordinate metadata"}
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
	held.free(); actor.free()


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
