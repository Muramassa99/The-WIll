extends SceneTree

const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Sampler = preload("res://tools/grip_plane_proof/capture_model_skin_samples.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor = RigScene.instantiate()
	root.add_child(actor)
	await process_frame
	var names: Array[StringName] = []
	for side: String in ["R", "L"]:
		for digit: String in ["Mid", "Thumb"]:
			for index: int in range(1, 4):
				names.append(StringName("CC_Base_%s_%s%d" % [side, digit, index]))
	var captured: Dictionary = Sampler.new().capture(actor.skeleton, actor.mesh_instance, names)
	if not bool(captured.get("valid", false)):
		print("CHARACTER_CONTACT_SAMPLE_FAILURE=" + JSON.stringify(captured))
		quit(1)
		return
	var path := "C:/WORKSPACE/test_artifacts/character_contact_samples_" + Time.get_datetime_string_from_system().replace(":", "-") + ".bin"
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_var(captured)
	output.close()
	var counts: Dictionary = {}
	for bone: StringName in names:
		counts[bone] = captured["samples"][bone]["points_bone_local"].size()
	print("CHARACTER_CONTACT_SAMPLES=" + JSON.stringify({"path": path, "counts": counts, "identity": captured["model_identity"], "bind_error": captured["max_bind_reference_component_error"]}))
	actor.queue_free()
	await process_frame
	quit(0)
