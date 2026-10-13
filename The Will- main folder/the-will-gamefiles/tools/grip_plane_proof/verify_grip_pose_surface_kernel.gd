extends SceneTree

## Analytical closed solids verify the production native distance kernel.
## Metres in one explicit common frame; no character or grip solve runs.
const TOLERANCE_M := 0.000002
var _checks := 0
var _failures: Array[String] = []
var _cases: Array[Dictionary] = []

class EngineErrors extends Logger:
	var entries: Array[Dictionary] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			entries.append({"function":function,"file":file,"line":line,"code":code,"rationale":rationale})
var _errors := EngineErrors.new()

func _init() -> void:
	OS.add_logger(_errors)
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists(&"GripPoseSurfaceKernel"):
		_check(false,"native GripPoseSurfaceKernel is registered"); _finish(); return
	var frames: Array[Transform3D] = [Transform3D.IDENTITY,
		Transform3D(Basis(Vector3(0.31,1.0,-0.27).normalized(),0.83),Vector3(0.4,-0.2,0.17))]
	for frame_index: int in frames.size():
		for winding: int in 3:
			var label := "box frame%d winding%d" % [frame_index,winding]
			var kernel: RefCounted = ClassDB.instantiate(&"GripPoseSurfaceKernel")
			var faces := _transform_faces(_winding(_box(Vector3.ONE*0.01),winding),frames[frame_index])
			var before := var_to_bytes(faces)
			var prepared: Dictionary = kernel.prepare(faces)
			_check(prepared.get("valid",false),label+" closed topology prepares")
			_check(var_to_bytes(faces)==before,label+" input geometry remains unchanged")
			if not prepared.get("valid",false): continue
			var samples: Array = [
				[Vector3(0.013,0.002,0.001),0.003,Vector3(0.01,0.002,0.001),Vector3.RIGHT],
				[Vector3(0.013,0.014,0.001),0.005,Vector3(0.01,0.01,0.001),Vector3(0.6,0.8,0)],
				[Vector3(0.012,0.013,0.016),0.007,Vector3.ONE*0.01,Vector3(2,3,6)/7.0],
				[Vector3(0.008,0.001,0.002),-0.002,Vector3(0.01,0.001,0.002),Vector3.RIGHT],
				[Vector3(-0.00996,0.001,0.002),-0.00004,Vector3(-0.01,0.001,0.002),Vector3.LEFT],
				[Vector3(-0.01004,0.001,0.002),0.00004,Vector3(-0.01,0.001,0.002),Vector3.LEFT],
				[Vector3(0.01,0.002,0.001),0.0,Vector3(0.01,0.002,0.001),Vector3.RIGHT],
				[Vector3(0.01,0.01,0.001),0.0,Vector3(0.01,0.01,0.001),null],
				[Vector3.ONE*0.01,0.0,Vector3.ONE*0.01,null]]
			_evaluate(kernel,samples,frames[frame_index],label)
			_segments(kernel,frames[frame_index],label)
	_concave_and_cavity()
	_invalid_inputs()
	_finish()

func _evaluate(kernel: RefCounted, samples: Array, frame: Transform3D, label: String) -> void:
	var points := PackedVector3Array()
	for sample: Array in samples: points.append(frame*(sample[0] as Vector3))
	var output: Dictionary = kernel.evaluate(points)
	_check(output.get("valid",false),label+" point batch evaluates")
	if not output.get("valid",false): return
	_check(output.signed_distances.size()==samples.size() and output.closest_points.size()==samples.size()
		and output.normals.size()==samples.size() and output.face_indices.size()==samples.size(),label+" one result per point")
	if output.signed_distances.size()!=samples.size(): return
	for i: int in samples.size():
		var expected: Array = samples[i]
		var depth: float = output.signed_distances[i]
		var normal: Vector3 = output.normals[i]
		_check(is_finite(depth) and absf(depth-float(expected[1]))<=TOLERANCE_M,label+" signed closest distance "+str(i))
		_check(normal.is_finite() and absf(normal.length()-1.0)<0.0001,label+" finite unit normal "+str(i))
		_check(int(output.face_indices[i])>=0,label+" source triangle exists "+str(i))
		if expected[2] is Vector3:
			_check((output.closest_points[i] as Vector3).distance_to(frame*(expected[2] as Vector3))<=TOLERANCE_M,label+" exact closest point "+str(i))
		if expected[3] is Vector3:
			_check(normal.dot(frame.basis*(expected[3] as Vector3))>0.9999,label+" outward distance gradient "+str(i))
	_cases.append({"label":label,"signed_distances_m":Array(output.signed_distances),
		"ambiguous_parity_queries":output.get("ambiguous_parity_queries",-1)})

func _segments(kernel: RefCounted, frame: Transform3D, label: String) -> void:
	var cases: Array = [
		[Vector3(-0.02,0.001,0.002),Vector3(0.02,0.001,0.002),true],
		[Vector3(-0.002,0.001,0),Vector3(0.002,-0.001,0),true],
		[Vector3(0.02,0.02,0),Vector3(0.03,0.02,0),false],
		[Vector3(-0.02,0.002,0.01),Vector3(0.02,0.002,0.01),true],
		[Vector3(0.02,0.02,0.01),Vector3(0.03,0.02,0.01),false],
		[Vector3(0.01,0,0),Vector3(0.02,0,0),true],
		[Vector3.ZERO,Vector3.ZERO,true]]
	var points := PackedVector3Array()
	for pair: Array in cases: points.append(frame*(pair[0] as Vector3)); points.append(frame*(pair[1] as Vector3))
	var hits: PackedByteArray = kernel.intersects_segments(points)
	_check(hits.size()==cases.size(),label+" segment batch size")
	if hits.size()!=cases.size(): return
	for i: int in cases.size(): _check((hits[i]!=0)==bool(cases[i][2]),label+" crossing/contained/coplanar segment "+str(i))

func _concave_and_cavity() -> void:
	var kernel: RefCounted = ClassDB.instantiate(&"GripPoseSurfaceKernel")
	var prepared: Dictionary = kernel.prepare(_winding(_l_prism(),2))
	_check(prepared.get("valid",false),"concave L prism with mixed winding prepares")
	if prepared.get("valid",false):
		_evaluate(kernel,[
			[Vector3(0.02,0.02,0),0.01,null,null],
			[Vector3(0.008,0.02,0),-0.002,Vector3(0.01,0.02,0),Vector3.RIGHT],
			[Vector3(0.02,0.008,0),-0.002,Vector3(0.02,0.01,0),Vector3.UP],
			[Vector3(0.025,0.005,0),-0.005,null,null]],Transform3D.IDENTITY,"concave L prism")
	var shell := _box(Vector3.ONE*0.02)
	shell.append_array(_box(Vector3.ONE*0.01))
	prepared = kernel.prepare(_winding(shell,2))
	_check(prepared.get("valid",false),"nested closed surfaces prepare a parity cavity")
	if prepared.get("valid",false):
		_evaluate(kernel,[
			[Vector3(0.006,0,0),0.004,Vector3(0.01,0,0),Vector3.LEFT],
			[Vector3(0.012,0,0),-0.002,Vector3(0.01,0,0),Vector3.LEFT],
			[Vector3(0.024,0,0),0.004,Vector3(0.02,0,0),Vector3.RIGHT]],Transform3D.IDENTITY,"nested cavity")
		var hits: PackedByteArray = kernel.intersects_segments(PackedVector3Array([
			Vector3(-0.005,0,0),Vector3(0.005,0,0),Vector3(0.012,0,0),Vector3(0.017,0,0)]))
		_check(hits==PackedByteArray([0,1]),"empty-cavity segment stays clear while shell-contained segment collides")

func _invalid_inputs() -> void:
	var kernel: RefCounted = ClassDB.instantiate(&"GripPoseSurfaceKernel")
	_check(not kernel.evaluate(PackedVector3Array([Vector3.ZERO])).get("valid",true),"unprepared evaluation fails explicitly")
	_check(kernel.intersects_segments(PackedVector3Array([Vector3.ZERO,Vector3.ONE]))==PackedByteArray([1]),"unprepared segment fails closed")
	var good := _box(Vector3.ONE*0.01)
	var malformed := good.duplicate(); malformed.remove_at(malformed.size()-1)
	_check(not kernel.prepare(malformed).get("valid",true),"nontriangle input rejected")
	var open := good.slice(3)
	_check(not kernel.prepare(open).get("valid",true),"open boundary rejected")
	var degenerate := good.duplicate(); degenerate[1]=degenerate[0]
	_check(not kernel.prepare(degenerate).get("valid",true),"degenerate triangle rejected")
	var nonfinite := good.duplicate(); nonfinite[0]=Vector3(INF,0,0)
	_check(not kernel.prepare(nonfinite).get("valid",true),"nonfinite surface rejected")
	_check(kernel.prepare(good).get("valid",false),"valid surface can follow rejected input")
	_check(not kernel.evaluate(PackedVector3Array([Vector3(NAN,0,0)])).get("valid",true),"nonfinite query rejected")
	_check(kernel.intersects_segments(PackedVector3Array([Vector3(NAN,0,0),Vector3.ONE]))==PackedByteArray([1]),"nonfinite segment fails closed")
	_check(kernel.intersects_segments(PackedVector3Array([Vector3.ZERO])).is_empty(),"unpaired segment endpoints rejected")
	_check(not kernel.prepare(open).get("valid",true),"failed replacement remains rejected")
	_check(not kernel.evaluate(PackedVector3Array([Vector3.ZERO])).get("valid",true),"failed replacement cannot retain stale geometry")

func _box(half: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(-half.x,-half.y,-half.z),Vector3(half.x,-half.y,-half.z),
		Vector3(half.x,half.y,-half.z),Vector3(-half.x,half.y,-half.z),Vector3(-half.x,-half.y,half.z),
		Vector3(half.x,-half.y,half.z),Vector3(half.x,half.y,half.z),Vector3(-half.x,half.y,half.z)])
	var faces := PackedVector3Array()
	for index: int in [0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,3,7,6,3,6,2,0,4,7,0,7,3,1,2,6,1,6,5]: faces.append(points[index])
	return faces

func _l_prism() -> PackedVector3Array:
	var outline := PackedVector2Array([Vector2(0,0),Vector2(0.03,0),Vector2(0.03,0.01),Vector2(0.01,0.01),Vector2(0.01,0.03),Vector2(0,0.03)])
	var faces := PackedVector3Array()
	for z: float in [-0.005,0.005]:
		for index: int in [0,1,2,0,2,3,0,3,5,3,4,5]: faces.append(Vector3(outline[index].x,outline[index].y,z))
	for i: int in outline.size():
		var a := outline[i]; var b := outline[(i+1)%outline.size()]
		faces.append_array(PackedVector3Array([Vector3(a.x,a.y,-0.005),Vector3(b.x,b.y,-0.005),Vector3(b.x,b.y,0.005),
			Vector3(a.x,a.y,-0.005),Vector3(b.x,b.y,0.005),Vector3(a.x,a.y,0.005)]))
	return faces

func _winding(faces: PackedVector3Array, mode: int) -> PackedVector3Array:
	var changed := faces.duplicate()
	for i: int in range(0,changed.size(),3):
		if mode==1 or (mode==2 and (i/3)%3!=1):
			var swap := changed[i+1]; changed[i+1]=changed[i+2]; changed[i+2]=swap
	return changed

func _transform_faces(faces: PackedVector3Array, frame: Transform3D) -> PackedVector3Array:
	var moved := PackedVector3Array()
	for point: Vector3 in faces: moved.append(frame*point)
	return moved

func _check(condition: bool, label: String) -> void:
	_checks+=1
	if not condition: _failures.append(label); push_error(label)

func _finish() -> void:
	var report := {"schema":"grip_pose_surface_kernel_analytic_v1","checks":_checks,"failures":_failures,
		"engine_errors":_errors.entries,"cases":_cases,"passed":_failures.is_empty() and _errors.entries.is_empty(),
		"grip_solve_run":false,"production_save_written":false,"tolerance_m":TOLERANCE_M}
	var path := "C:/WORKSPACE/test_artifacts/grip_pose_surface_kernel_"+Time.get_datetime_string_from_system(true).replace(":","-")+".json"
	if FileAccess.file_exists(path): push_error("Refusing to overwrite kernel report"); quit(1); return
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: push_error("Cannot write kernel report"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("GRIP_POSE_SURFACE_KERNEL ","PASS" if report.passed else "FAIL"," checks=",_checks," report=",path)
	quit(0 if report.passed else 1)
