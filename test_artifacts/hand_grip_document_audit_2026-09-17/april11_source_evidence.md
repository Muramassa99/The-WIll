# April 11 source evidence

Read-only excerpts from commit `be2f2946`, committed April 11, 2026 at21:43:36+03:00. Original source line numbers are included. These prove persisted implementation, not live behavior acceptance.

## player_rig_finger_grip_presenter.gd

Source SHA256: `19c31bab73a3284a3631a698d90d9211fa7617e4ba4f228230f2e5c8d8785f5e`

```gdscript
117: const PALM_TRIANGULATION_BONES := {
118: 	SLOT_RIGHT: {
119: 		"hand": &"CC_Base_R_Hand",
120: 		"thumb2": &"CC_Base_R_Thumb2",
121: 		"index1": &"CC_Base_R_Index1",
122: 		"mid1": &"CC_Base_R_Mid1",
123: 		"mid2": &"CC_Base_R_Mid2",
124: 		"ring1": &"CC_Base_R_Ring1",
125: 		"pinky1": &"CC_Base_R_Pinky1",
126: 	},
127: 	SLOT_LEFT: {
128: 		"hand": &"CC_Base_L_Hand",
129: 		"thumb2": &"CC_Base_L_Thumb2",
130: 		"index1": &"CC_Base_L_Index1",
131: 		"mid1": &"CC_Base_L_Mid1",
132: 		"mid2": &"CC_Base_L_Mid2",
133: 		"ring1": &"CC_Base_L_Ring1",
134: 		"pinky1": &"CC_Base_L_Pinky1",
135: 	},
136: }
```

```gdscript
285: func resolve_hand_grip_alignment_world_position(skeleton: Skeleton3D, slot_id: StringName) -> Vector3:
286: 	if skeleton == null:
287: 		return Vector3.ZERO
288: 	_ensure_animation_grip_baseline_cache()
289: 	return _resolve_hand_grip_center_world_from_cache(skeleton, animation_grip_baseline_cache, slot_id)
```

```gdscript
337: func _build_palm_frame(
338: 	slot_id: StringName,
339: 	get_bone_world_position_callable: Callable,
340: 	shell_center_world: Vector3,
341: 	major_axis_world: Vector3,
342: 	minor_axis_a_world: Vector3,
343: 	minor_axis_b_world: Vector3
344: ) -> Dictionary:
345: 	var bone_names: Dictionary = PALM_TRIANGULATION_BONES.get(slot_id, {})
346: 	if bone_names.is_empty():
347: 		return {}
348: 	var hand_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("hand", StringName()))
349: 	var thumb2_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("thumb2", StringName()))
350: 	var index1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("index1", StringName()))
351: 	var mid1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("mid1", StringName()))
352: 	var mid2_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("mid2", StringName()))
353: 	var ring1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("ring1", StringName()))
354: 	var pinky1_world: Vector3 = get_bone_world_position_callable.call(bone_names.get("pinky1", StringName()))
355: 	var center_world: Vector3 = (
356: 		hand_world
357: 		+ thumb2_world
358: 		+ index1_world
359: 		+ mid1_world
360: 		+ ring1_world
361: 		+ pinky1_world
362: 	) / 6.0
363: 	var knuckle_span_world: Vector3 = pinky1_world - index1_world
364: 	var thumb_span_world: Vector3 = thumb2_world - hand_world
365: 	var palm_normal_world: Vector3 = (index1_world - hand_world).cross(pinky1_world - hand_world)
366: 	if palm_normal_world.length_squared() <= 0.000001:
367: 		palm_normal_world = (mid1_world - hand_world).cross(ring1_world - hand_world)
368: 	if palm_normal_world.length_squared() <= 0.000001:
369: 		palm_normal_world = major_axis_world.cross(knuckle_span_world)
370: 	if palm_normal_world.length_squared() <= 0.000001:
371: 		palm_normal_world = minor_axis_a_world.cross(minor_axis_b_world)
372: 	palm_normal_world = palm_normal_world.normalized()
373: 	var shell_to_palm: Vector3 = center_world - shell_center_world
374: 	if palm_normal_world.dot(shell_to_palm) < 0.0:
375: 		palm_normal_world = -palm_normal_world
376: 	if knuckle_span_world.length_squared() <= 0.000001:
377: 		knuckle_span_world = minor_axis_a_world
378: 	return {
379: 		"center_world": center_world,
380: 		"hand_world": hand_world,
381: 		"thumb2_world": thumb2_world,
382: 		"index1_world": index1_world,
383: 		"mid1_world": mid1_world,
384: 		"mid2_world": mid2_world,
385: 		"ring1_world": ring1_world,
386: 		"pinky1_world": pinky1_world,
387: 		"thumb_close_world": mid2_world - thumb2_world,
388: 		"knuckle_span_world": knuckle_span_world.normalized(),
389: 		"thumb_span_world": thumb_span_world.normalized() if thumb_span_world.length_squared() > 0.000001 else minor_axis_a_world,
390: 		"palm_normal_world": palm_normal_world,
391: 	}
```

```gdscript
918: func _resolve_hand_grip_center_world_from_cache(
919: 	skeleton: Skeleton3D,
920: 	pose_cache: Dictionary,
921: 	slot_id: StringName
922: ) -> Vector3:
923: 	var sample_points: Array[Vector3] = []
924: 	for finger_id: StringName in [&"thumb", &"index"]:
925: 		for joint_key: StringName in [&"root", &"mid", &"end"]:
926: 			var joint_world: Vector3 = _resolve_animation_joint_world_position_from_cache(
927: 				skeleton,
928: 				pose_cache,
929: 				slot_id,
930: 				finger_id,
931: 				joint_key
932: 			)
933: 			if joint_world.length_squared() > 0.000001:
934: 				sample_points.append(joint_world)
935: 	if sample_points.is_empty():
936: 		return Vector3.ZERO
937: 	var center_world: Vector3 = Vector3.ZERO
938: 	for point_world: Vector3 in sample_points:
939: 		center_world += point_world
940: 	return center_world / float(sample_points.size())
```

## player_humanoid_rig.gd

Source SHA256: `be9c134304b95f666ba30b2dfe561dff1c3e58ef13c02d859e5bb5d16981dcfa`

```gdscript
210: func resolve_hand_grip_alignment_offset_local(slot_id: StringName) -> Vector3:
211: 	if skeleton == null:
212: 		return Vector3.ZERO
213: 	var hand_anchor: Node3D = get_right_hand_item_anchor() if slot_id == &"hand_right" else get_left_hand_item_anchor()
214: 	if hand_anchor == null:
215: 		return Vector3.ZERO
216: 	var grip_center_world: Vector3 = finger_grip_presenter.resolve_hand_grip_alignment_world_position(skeleton, slot_id)
217: 	if grip_center_world.length_squared() <= 0.000001:
218: 		return Vector3.ZERO
219: 	return hand_anchor.to_local(grip_center_world)
```

## player_equipped_item_presenter.gd

Source SHA256: `0587ac9896cb6ba7707f50f839fb320717e84e2aa88a99546594da87456efcd3`

```gdscript
78: 	var dominant_grip_shell_data: Dictionary = _build_grip_contact_shell_data(
79: 		test_print.display_cells,
80: 		dominant_hand_local_position,
81: 		cell_world_size,
82: 		test_print.baked_profile
83: 	)
84: 	var dominant_grip_center_local: Vector3 = dominant_grip_shell_data.get(
85: 		"slice_center_local",
86: 		dominant_hand_local_position
87: 	)
88: 	var support_grip_shell_data: Dictionary = {}
89: 	var support_grip_center_local: Vector3 = support_hand_local_position
90: 	if resolved_grip_style != CraftedItemWIP.GRIP_REVERSE and two_hand_character_eligible:
91: 		support_grip_shell_data = _build_grip_contact_shell_data(
92: 			test_print.display_cells,
93: 			support_hand_local_position,
94: 			cell_world_size,
95: 			test_print.baked_profile
96: 		)
97: 		support_grip_center_local = support_grip_shell_data.get(
98: 			"slice_center_local",
99: 			support_hand_local_position
100: 		)
101: 	var hand_alignment_offset_local: Vector3 = Vector3.ZERO
102: 	if humanoid_rig != null and humanoid_rig.has_method("resolve_hand_grip_alignment_offset_local"):
103: 		var alignment_variant: Variant = humanoid_rig.call("resolve_hand_grip_alignment_offset_local", slot_id)
104: 		if alignment_variant is Vector3:
105: 			hand_alignment_offset_local = alignment_variant
106: 	held_root.position = hand_alignment_offset_local
107: 	mesh_instance.scale = Vector3.ONE * cell_world_size
108: 	mesh_instance.position = -dominant_grip_center_local * cell_world_size
```
