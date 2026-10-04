extends SceneTree

## Observe all requested real skin contours in frozen captures. No solve, bone
## writes, player-save access or change to prepared character Resources.
const Candidate = preload("res://runtime/player/grip/prepared_hand_candidate_pose.gd")
const Observer = preload("res://runtime/player/grip/prepared_grip_slice_contact.gd")
const Config = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const ROOT := &"RL_BoneRoot"
const DIGITS := [&"middle", &"thumb", &"index", &"ring", &"pinky"]
const TRACES := {
	"C:/WORKSPACE/test_artifacts/full_hand_placement_hand_right_2026-09-27T14-46-36.bin": "3e161def3a097dcd5942534b82e9bcc883bd969f6591e92d112611921d77075f",
	"C:/WORKSPACE/test_artifacts/full_hand_placement_hand_left_2026-09-27T14-46-36.bin": "2f55e79b3bd132272447a84c683703f52f4f774aa4f8239ee3d83ac917732c4f",
}
var _checks := 0
var _failures: Array[String] = []
var _cases: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok: _failures.append(label)
	return ok

func _run() -> void:
	var started := Time.get_ticks_usec()
	for path: String in TRACES: _case(path)
	var prefix := "C:/WORKSPACE/test_artifacts/skin_section_preference_anatomy_" + Time.get_datetime_string_from_system().replace(":", "-")
	var report := {"passed":_failures.is_empty(),"checks":_checks,"failures":_failures,"cases":_cases,
		"duration_ms":float(Time.get_ticks_usec()-started)/1000.0,"actual_3d_grip_verified":false,
		"production_pose_written":false,"scope":"real_skin_contour_percentage_coverage_no_grip_solve"}
	var output := FileAccess.open(prefix + ".json",FileAccess.WRITE)
	if output == null:
		push_error("Cannot write preference anatomy report"); quit(1); return
	output.store_string(JSON.stringify(report));output.close()
	print("SKIN_SECTION_PREFERENCE_ANATOMY=" + JSON.stringify({"passed":_failures.is_empty(),"checks":_checks,
		"failures":_failures,"case_count":_cases.size(),"path":prefix+".json","duration_ms":report.duration_ms}))
	quit(0 if _failures.is_empty() else 1)

func _case(path: String) -> void:
	if not _check(FileAccess.get_sha256(path)==TRACES[path],"frozen source hash"): return
	var input := FileAccess.open(path,FileAccess.READ)
	var raw: Dictionary=input.get_var(false);input.close()
	var source := {}
	for transaction: Dictionary in raw.transactions:
		if transaction.slot==raw.slot and transaction.get("result",{}).get("applied",false) and not transaction.get("finger_inputs",[]).is_empty():
			source=transaction.finger_inputs[-1]
	if not _check(not source.is_empty(),"captured hand input"): return
	var adapter: Dictionary=Candidate.new().prepare(Config.anatomy,source.posed_character,source.slot,DIGITS)
	if not _check(adapter.get("valid",false),"prepared hand "+str(source.slot)): return
	var observer := Observer.new()
	var observations := {}
	for digit: StringName in DIGITS:
		observations[digit]=observer.prepare(adapter,digit)
		if not _check(observations[digit].get("valid",false),"prepared observer "+str(digit)): return
	for fraction: float in [0.0,0.25,0.5]:
		var angles := {}
		for digit: StringName in DIGITS:
			var snapshot: Dictionary=adapter.digit_inputs[digit].snapshot
			var values: Array=[]
			for joint: int in 3:
				var low: float=snapshot.min_angles_rad[joint]
				var high: float=snapshot.max_angles_rad[joint]
				var closed: float=low if absf(low)>absf(high) else high
				values.append(lerpf(clampf(0.0,low,high),closed,fraction))
			angles[digit]=values
		var candidate: Dictionary=Candidate.new().evaluate(adapter,angles,Vector3.ZERO,ROOT)
		if not _check(candidate.get("valid",false),"coherent pose "+str(fraction)): continue
		var unchanged := var_to_bytes(candidate)
		for digit: StringName in DIGITS:
			var state: Dictionary=candidate.digit_states[digit]
			var slice: Dictionary=observer.slice_candidate(observations[digit],candidate,state.plane_to_world,state.plane_origin_id)
			if not _check(slice.get("valid",false),"valid slice "+str(digit)): continue
			var counts := [0,0,0]
			for edge: Dictionary in slice.segments:
				if not edge.has("location_bias"): continue
				var meta: Dictionary=edge.location_bias
				_check(edge.section_owner in [0,1,2],"only owned section receives preference")
				_check(meta.origin_id==state.plane_origin_id,"preference has named digit origin")
				_check(meta.a_percent>=0.0 and meta.a_percent<=100.0 and meta.b_percent>=0.0 and meta.b_percent<=100.0,"finite section-local percentage range")
				counts[edge.section_owner]+=1
			var label := str(source.slot)+"/"+str(digit)+"/"+str(fraction)
			if digit==&"thumb": _check(counts==[0,0,0],label+" no thumb preference")
			else:
				for section: int in 3: _check(counts[section]>0,label+" mapped S"+str(section+1))
			_cases.append({"slot":source.slot,"digit":digit,"pose_fraction":fraction,"mapping":slice.section_contact_preference,
				"mapped_by_section":counts,"owned_counts":[slice.owned[0].size(),slice.owned[1].size(),slice.owned[2].size()],
				"skin_segments":slice.segments if fraction==0.0 else [],"origin_id":state.plane_origin_id})
		_check(var_to_bytes(candidate)==unchanged,"observation preserves entire coherent pose")
	_check(FileAccess.get_sha256(path)==TRACES[path],"frozen source remains unchanged")
