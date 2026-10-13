extends SceneTree

## Read-only 3D companion to the section report. It consumes the actual captured
## skin and saved physical handle; no hypothetical pose or solver is run here.
const Actual = preload("res://runtime/player/grip/observed_hand_pose_view.gd")
const PROFILE = preload("res://core/defs/characters/josie/grip_contact_config.tres")
const TEMPLATE := "res://tools/grip_plane_proof/surface_grip_mesh_view.html"
const DIGITS := [&"middle", &"index", &"ring", &"pinky", &"thumb"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := OS.get_environment("THE_WILL_GRIP_SURFACE_REPORT").replace("\\", "/").simplify_path()
	if not path.to_lower().begins_with("c:/workspace/"):
		_fail("Workspace observation report required."); return
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not report is Dictionary or not report.has("actual_capture_path"):
		_fail("Actual pose capture required."); return
	var captured_path: String = report.actual_capture_path
	if not captured_path.replace("\\", "/").simplify_path().to_lower().begins_with("c:/workspace/") or FileAccess.get_sha256(captured_path) != report.actual_capture_sha256:
		_fail("Capture provenance does not match."); return
	var file := FileAccess.open(captured_path, FileAccess.READ)
	if file == null: _fail("Cannot read capture."); return
	var capture: Dictionary = file.get_var(false)
	file.close()
	var observed := Actual.new().observe(PROFILE.anatomy, capture.posed_character, capture.slot, DIGITS)
	if not observed.get("valid", false): _fail("Cannot observe captured hand."); return
	var view: Dictionary = observed.view
	var adapter: Dictionary = observed.adapter
	var skin: Dictionary = adapter.skin_prepared
	var relevant := PackedByteArray()
	relevant.resize(skin.vertex_count)
	for vertex: int in skin.vertex_count:
		for influence: int in range(skin.vertex_offsets[vertex], skin.vertex_offsets[vertex + 1]):
			var bone: StringName = skin.bind_bone_names[skin.influence_binds[influence]]
			if adapter.descendant_bones.has(bone) and skin.influence_weights[influence] > 0.001:
				relevant[vertex] = 1
	# A rigid observation frame preserves the actual captured metric geometry.
	var inverse := Transform3D(view.hand_to_world.basis.orthonormalized(), view.hand_to_world.origin).affine_inverse()
	var hand: Array = []
	for triangle: int in skin.triangle_count:
		var ids: PackedInt32Array = skin.triangle_indices.slice(triangle * 3, triangle * 3 + 3)
		if relevant[ids[0]] == 0 and relevant[ids[1]] == 0 and relevant[ids[2]] == 0: continue
		var face: Array = []
		for index: int in ids: face.append(_point(inverse * view.posed.vertices_world[index]))
		hand.append(face)
	var source: Dictionary = capture.saved_grip_source
	var weapon: Array = []
	var transform: Transform3D = inverse * capture.object.weapon_to_world * source.source_to_weapon
	var packet: Dictionary = source.handle_packet
	for triangle: int in packet.indices.size() / 3:
		var face: Array = []
		for corner: int in 3: face.append(_point(transform * packet.vertices[packet.indices[triangle * 3 + corner]]))
		weapon.append(face)
	var joints: Array = []
	for digit: StringName in DIGITS:
		var chain: Array = []
		for origin: Vector3 in view.digit_states[digit].joint_origins_world: chain.append(_point(inverse * origin))
		chain.append(_point(inverse * view.digit_states[digit].tip_world))
		joints.append(chain)
	var state: Dictionary = report.get("owner_status", {}).get(str(capture.slot), {})
	var totals: Dictionary = state.get("solver_totals", {})
	var data := {"weapon_name":report.weapon_name, "slot":str(capture.slot), "hand":hand,
		"weapon":weapon, "joints":joints, "solver_ms":state.get("solver_total_ms", 0),
		"physically_engaged_sections":totals.get("physically_engaged_sections", []),
		"maximum_depth_sections":totals.get("maximum_depth_sections", []),
		"palm_engaged":totals.get("palm_engaged", false),
		"palm_gap_m":totals.get("palm_gap_m", null),
		"sampled_material_safe":state.get("sampled_material_safe", false),
		"grip_accepted":state.get("grip_accepted", false),
		"source_capture":captured_path, "source_capture_sha256":report.actual_capture_sha256,
		"geometry_reposed":false, "solver_ran":false, "units":"hand-local millimetres"}
	var target := path.trim_suffix(".json") + "_mesh.html"
	if FileAccess.file_exists(target): _fail("Refusing to overwrite an existing observation."); return
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output == null: _fail("Cannot write mesh observation."); return
	output.store_string(FileAccess.get_file_as_string(TEMPLATE).replace("__REPORT__", JSON.stringify(data).replace("<", "\\u003c")))
	output.close()
	var json := FileAccess.open(target.trim_suffix(".html") + ".json", FileAccess.WRITE)
	json.store_string(JSON.stringify(data)); json.close()
	print("SURFACE_GRIP_MESH " + target)
	quit(0)

func _point(point: Vector3) -> Array:
	return [point.x * 1000.0, point.y * 1000.0, point.z * 1000.0]

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
