extends SceneTree

## Runs the production bake loop with small capture/acquisition fixtures. It
## verifies per-frame hand ownership and scope restoration, not grip geometry.
const Presenter = preload("res://runtime/combat/combat_animation_station_preview_presenter.gd")
const Motion = preload("res://core/models/combat_animation_motion_node.gd")
const Draft = preload("res://core/models/combat_animation_draft.gd")
const Clip = preload("res://core/models/combat_runtime_clip.gd")
const Wip = preload("res://core/models/crafted_item_wip.gd")

class GripOwner extends Node:
	var calls: Array = []
	var reject := false
	func prepare_replay_grip(slots: Array[StringName], dominant: StringName) -> Dictionary:
		calls.append({"slots":slots.duplicate(), "dominant":dominant})
		return {"valid":not reject, "reason":"fixture_capture_rejected" if reject else ""}

class CaptureActor extends Node3D:
	func get_runtime_upper_body_pose_bone_names() -> Array[StringName]:
		return [&"CC_Base_R_Hand", &"CC_Base_L_Hand"]
	func capture_runtime_upper_body_pose_frame(_names: Array) -> Dictionary:
		return {"bone_names":get_runtime_upper_body_pose_bone_names(),
			"pose_positions":PackedVector3Array([Vector3.ZERO, Vector3.ZERO]),
			"pose_rotations":PackedVector4Array([Vector4(0,0,0,1), Vector4(0,0,0,1)]),
			"pose_scales":PackedVector3Array([Vector3.ONE, Vector3.ONE])}

class FixturePresenter extends Presenter:
	var fixture: Dictionary = {}
	var weapon: Node3D
	var refreshed: Array[StringName] = []
	var applied: Array[StringName] = []
	func _ensure_preview_nodes(_container: SubViewportContainer, _viewport: SubViewport) -> Dictionary: return fixture
	func _sync_preview_size(_container: SubViewportContainer, _viewport: SubViewport) -> void: pass
	func get_grip_acquisition_status(_viewport: SubViewport) -> Dictionary: return {}
	func _prepare_trajectory_root_for_authoring(_state: Dictionary) -> void: pass
	func _refresh_actor_and_weapon(state: Dictionary, _wip: CraftedItemWIP, _motion: CombatAnimationMotionNode, _draft: Resource = null) -> void:
		refreshed.append(_resolve_preview_dominant_slot_id())
		state.preview_root.set_meta("preview_held_item", weapon)
	func _apply_runtime_clip_preview_pose(_state: Dictionary, _motion: CombatAnimationMotionNode,
		playback: Dictionary, _draft: Resource = null, _allow: bool = false) -> Dictionary:
		applied.append(_resolve_preview_dominant_slot_id())
		return playback
	func _should_preview_use_support_hand(_weapon: Node3D, motion: CombatAnimationMotionNode) -> bool:
		return motion.two_hand_state == Motion.TWO_HAND_STATE_TWO_HAND
	func _resolve_trajectory_authoring_transform(_actor: Node3D) -> Transform3D: return Transform3D.IDENTITY

var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _clip(slots: Array) -> Resource:
	var clip := Clip.new()
	var motion := Motion.new()
	motion.primary_hand_slot = slots[-1]
	motion.two_hand_state = Motion.TWO_HAND_STATE_TWO_HAND
	clip.motion_node_chain.assign([motion])
	for index: int in slots.size():
		clip.baked_frame_times.append(float(index) * 0.1)
		clip.baked_primary_hand_slots.append(slots[index])
		clip.baked_two_hand_states.append(Motion.TWO_HAND_STATE_TWO_HAND)
	return clip

func _run() -> void:
	var container := SubViewportContainer.new()
	root.add_child(container)
	var viewport := SubViewport.new()
	container.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var pivot := Node3D.new()
	scene.add_child(pivot)
	var actor := CaptureActor.new()
	actor.name = Presenter.PREVIEW_ACTOR_NAME
	pivot.add_child(actor)
	var owner := GripOwner.new()
	owner.name = "PreparedGripAcquisition"
	actor.add_child(owner)
	var weapon := Node3D.new()
	scene.add_child(weapon)
	var presenter := FixturePresenter.new()
	presenter.fixture = {"preview_root":scene, "actor_pivot":pivot}
	presenter.weapon = weapon
	var wip := Wip.new()
	var draft := Draft.new()
	draft.draft_kind = Draft.DRAFT_KIND_SKILL
	draft.selected_motion_node_index = 0
	var swap := _clip([&"hand_left", &"hand_left", &"hand_right"])
	presenter.configure_preview_hand_setup(&"hand_right", false)
	var result := presenter.bake_runtime_clip_upper_body_pose_track(container, viewport, wip, draft, swap)
	_check(result.baked and result.solved_replay_track, "production bake completes left-to-right fixture")
	_check(presenter.refreshed == [&"hand_left", &"hand_right"], "weapon context changes only at declared hand transition")
	_check(presenter.applied == [&"hand_left", &"hand_left", &"hand_right"], "each pose uses its frame primary hand")
	_check(owner.calls.size() == 3 and owner.calls[0].slots == [&"hand_left", &"hand_right"] and owner.calls[2].slots == [&"hand_right", &"hand_left"], "acquisition reverses primary/support roles at hand swap")
	_check(presenter.preview_dominant_slot_id == &"hand_right" and not presenter.preview_default_two_hand, "caller hand setup restored after skill bake")
	_check(draft.selected_motion_node_index == 0 and swap.motion_node_chain[0].primary_hand_slot == &"hand_right", "authored selected node and hand unchanged")
	# Skill Save next visits Combat Idle without selecting that draft in the UI.
	var idle := Draft.new()
	idle.draft_kind = Draft.DRAFT_KIND_IDLE
	idle.context_id = Draft.IDLE_CONTEXT_COMBAT
	var idle_clip := _clip([&"hand_left"])
	presenter.refreshed.clear(); presenter.applied.clear(); owner.calls.clear()
	result = presenter.bake_runtime_clip_upper_body_pose_track(container, viewport, wip, idle, idle_clip)
	_check(result.baked and owner.calls[0].dominant == &"hand_left", "automatic idle uses its own hand rather than selected skill hand")
	_check(presenter.preview_dominant_slot_id == &"hand_right" and not presenter.preview_default_two_hand, "automatic idle restores selected skill hand setup")
	# Fail after switching the bake context, rather than only at input validation.
	owner.reject = true
	presenter.configure_preview_hand_setup(&"hand_right", true)
	result = presenter.bake_runtime_clip_upper_body_pose_track(container, viewport, wip, idle, _clip([&"hand_left"]))
	_check(not result.baked and result.reason == "fixture_capture_rejected", "failed acquisition rejects the bake")
	_check(presenter.preview_dominant_slot_id == &"hand_right" and presenter.preview_default_two_hand, "failure restores both dominant and default support state")
	container.free()
	print(JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
