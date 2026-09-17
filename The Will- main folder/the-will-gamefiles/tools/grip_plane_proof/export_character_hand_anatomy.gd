extends SceneTree

const Rig = preload("res://scenes/player/player_humanoid_rig.tscn")
const Baker = preload("res://tools/grip_plane_proof/bake_character_hand_anatomy.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var started := Time.get_ticks_usec()
	var actor = Rig.instantiate()
	root.add_child(actor)
	_quiet(actor)
	actor.skeleton.reset_bone_poses()
	actor.skeleton.force_update_all_bone_transforms()
	var baker = Baker.new()
	var source: Dictionary = baker.capture_source(actor, &"josie", Rig.resource_path)
	if not bool(source.get("valid", false)):
		_fail(source)
		return
	var source_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var path: String = "res://tools/grip_plane_proof/prepared_characters/josie/" + source["signature"] + ".tres"
	var store = Store.new()
	var reuse_started := Time.get_ticks_usec()
	var existing: Dictionary = store.load_matching(path, source["signature"], Baker.REVISION)
	var load_ms := float(Time.get_ticks_usec() - reuse_started) / 1000.0
	if bool(existing.get("valid", false)):
		print("CHARACTER_ANATOMY_EXPORT=" + JSON.stringify({"status": "reused", "path": path, "source_signature": source["signature"], "source_check_ms": source_ms, "resource_load_ms": load_ms, "expensive_bake_ran": false, "total_ms": float(Time.get_ticks_usec() - started) / 1000.0}))
	else:
		if FileAccess.file_exists(path):
			_fail({"reason": "existing_anatomy_failed_validation_not_overwritten", "details": existing})
			return
		var baked: Dictionary = baker.bake(actor, source)
		if not bool(baked.get("valid", false)):
			_fail(baked)
			return
		var saved: Dictionary = store.save_new(baked["resource"], path)
		if not bool(saved.get("valid", false)):
			_fail(saved)
			return
		print("CHARACTER_ANATOMY_EXPORT=" + JSON.stringify({"status": "prepared_and_saved", "path": path, "source_signature": source["signature"], "source_check_ms": source_ms, "bake_ms": baked["bake_ms"], "timings": baked["timings"], "expensive_bake_ran": true, "contact_shape_validated": false, "total_ms": float(Time.get_ticks_usec() - started) / 1000.0}))
	actor.queue_free()
	await process_frame
	quit(0)

func _quiet(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is AnimationPlayer:
		node.stop()
	if node is AnimationTree or node is SkeletonModifier3D:
		node.active = false
	for child: Node in node.get_children():
		_quiet(child)

func _fail(result: Dictionary) -> void:
	push_error("CHARACTER_ANATOMY_EXPORT_FAILED=" + JSON.stringify(result))
	quit(1)
