extends RefCounted
class_name PlayerDigitHingeRules

const CombatOriginRecordScript = preload(
	"res://core/models/combat_origin_record.gd"
)
const SLOT_RIGHT: StringName = &"hand_right"
const SLOT_LEFT: StringName = &"hand_left"
const ROOT_ORIGIN_ID: StringName = CombatOriginRecordScript.ORIGIN_RL_BONE_ROOT

# Every digit joint owns the same anatomical hinge contract in its own bone-local
# coordinate system. The handed ranges are authored independently so neither
# side depends on a mirrored transform or a runtime sign flip.
const HINGE_AXIS_LOCAL: Vector3 = Vector3(0.0, 0.0, 1.0)
const ZERO_DIRECTION_LOCAL: Vector3 = Vector3.UP
const THUMB_PREOPEN_STEP_DEGREES: float = 20.0
const RIGHT_THUMB1_OPEN_DEGREES: float = 70.0
const RIGHT_THUMB1_CLOSED_DEGREES: float = -30.0
const LEFT_THUMB1_OPEN_DEGREES: float = -70.0
const LEFT_THUMB1_CLOSED_DEGREES: float = 30.0
const RIGHT_FINGER_CLOSED_DEGREES: float = 90.0
const RIGHT_THUMB_CLOSED_DEGREES: float = -90.0
const LEFT_FINGER_CLOSED_DEGREES: float = -90.0
const LEFT_THUMB_CLOSED_DEGREES: float = 90.0
const SURFACE_SOLVER_RULE_REVISION: StringName = &"player_digit_local_z_surface_rules_v3"
const MAX_CONTACT_OVERLAP_METERS: float = 0.0005
const PREFERRED_CONTACT_OVERLAP_METERS: float = 0.00025
const CONTACT_OVERLAP_TOLERANCE_METERS: float = 0.00008
const SECTION_TARGET_OVERLAPS_METERS: Array[float] = [0.0005, 0.0004, 0.0003]
const THUMB_SECTION_TARGET_OVERLAPS_METERS: Array[float] = [0.0005, 0.001, 0.0003]
const DIGIT_IDS: Array[StringName] = [&"thumb", &"index", &"middle", &"ring", &"pinky"]

# These are Josie's independently measured phalanx skin radii and terminal
# section lengths in meters. They describe cosmetic contact geometry only; the
# authored hinge axis/range authority remains the per-bone rules below.
const RIGHT_DIGIT_CONTACT_GEOMETRY: Dictionary = {
	&"thumb": {"capsule_radii_m": [0.0120, 0.0110, 0.0100], "terminal_length_m": 0.0340},
	&"index": {"capsule_radii_m": [0.0105, 0.0095, 0.0085], "terminal_length_m": 0.0235},
	&"middle": {"capsule_radii_m": [0.0110, 0.0100, 0.0090], "terminal_length_m": 0.0255},
	&"ring": {"capsule_radii_m": [0.0103, 0.0093, 0.0083], "terminal_length_m": 0.0230},
	&"pinky": {"capsule_radii_m": [0.0092, 0.0082, 0.0072], "terminal_length_m": 0.0195},
}
const LEFT_DIGIT_CONTACT_GEOMETRY: Dictionary = {
	&"thumb": {"capsule_radii_m": [0.0120, 0.0110, 0.0100], "terminal_length_m": 0.0340},
	&"index": {"capsule_radii_m": [0.0105, 0.0095, 0.0085], "terminal_length_m": 0.0235},
	&"middle": {"capsule_radii_m": [0.0110, 0.0100, 0.0090], "terminal_length_m": 0.0255},
	&"ring": {"capsule_radii_m": [0.0103, 0.0093, 0.0083], "terminal_length_m": 0.0230},
	&"pinky": {"capsule_radii_m": [0.0092, 0.0082, 0.0072], "terminal_length_m": 0.0195},
}

static var _all_rules_cache: Array[Dictionary] = []
static var _rule_by_bone_cache: Dictionary = {}

const RIGHT_DIGIT_BONE_RULES := [
	{"bone": &"CC_Base_R_Thumb1", "next_bone": &"CC_Base_R_Thumb2", "digit": &"thumb", "section": 1},
	{"bone": &"CC_Base_R_Thumb2", "next_bone": &"CC_Base_R_Thumb3", "digit": &"thumb", "section": 2},
	{"bone": &"CC_Base_R_Thumb3", "next_bone": StringName(), "digit": &"thumb", "section": 3},
	{"bone": &"CC_Base_R_Index1", "next_bone": &"CC_Base_R_Index2", "digit": &"index", "section": 1},
	{"bone": &"CC_Base_R_Index2", "next_bone": &"CC_Base_R_Index3", "digit": &"index", "section": 2},
	{"bone": &"CC_Base_R_Index3", "next_bone": StringName(), "digit": &"index", "section": 3},
	{"bone": &"CC_Base_R_Mid1", "next_bone": &"CC_Base_R_Mid2", "digit": &"middle", "section": 1},
	{"bone": &"CC_Base_R_Mid2", "next_bone": &"CC_Base_R_Mid3", "digit": &"middle", "section": 2},
	{"bone": &"CC_Base_R_Mid3", "next_bone": StringName(), "digit": &"middle", "section": 3},
	{"bone": &"CC_Base_R_Ring1", "next_bone": &"CC_Base_R_Ring2", "digit": &"ring", "section": 1},
	{"bone": &"CC_Base_R_Ring2", "next_bone": &"CC_Base_R_Ring3", "digit": &"ring", "section": 2},
	{"bone": &"CC_Base_R_Ring3", "next_bone": StringName(), "digit": &"ring", "section": 3},
	{"bone": &"CC_Base_R_Pinky1", "next_bone": &"CC_Base_R_Pinky2", "digit": &"pinky", "section": 1},
	{"bone": &"CC_Base_R_Pinky2", "next_bone": &"CC_Base_R_Pinky3", "digit": &"pinky", "section": 2},
	{"bone": &"CC_Base_R_Pinky3", "next_bone": StringName(), "digit": &"pinky", "section": 3},
]

const LEFT_DIGIT_BONE_RULES := [
	{"bone": &"CC_Base_L_Thumb1", "next_bone": &"CC_Base_L_Thumb2", "digit": &"thumb", "section": 1},
	{"bone": &"CC_Base_L_Thumb2", "next_bone": &"CC_Base_L_Thumb3", "digit": &"thumb", "section": 2},
	{"bone": &"CC_Base_L_Thumb3", "next_bone": StringName(), "digit": &"thumb", "section": 3},
	{"bone": &"CC_Base_L_Index1", "next_bone": &"CC_Base_L_Index2", "digit": &"index", "section": 1},
	{"bone": &"CC_Base_L_Index2", "next_bone": &"CC_Base_L_Index3", "digit": &"index", "section": 2},
	{"bone": &"CC_Base_L_Index3", "next_bone": StringName(), "digit": &"index", "section": 3},
	{"bone": &"CC_Base_L_Mid1", "next_bone": &"CC_Base_L_Mid2", "digit": &"middle", "section": 1},
	{"bone": &"CC_Base_L_Mid2", "next_bone": &"CC_Base_L_Mid3", "digit": &"middle", "section": 2},
	{"bone": &"CC_Base_L_Mid3", "next_bone": StringName(), "digit": &"middle", "section": 3},
	{"bone": &"CC_Base_L_Ring1", "next_bone": &"CC_Base_L_Ring2", "digit": &"ring", "section": 1},
	{"bone": &"CC_Base_L_Ring2", "next_bone": &"CC_Base_L_Ring3", "digit": &"ring", "section": 2},
	{"bone": &"CC_Base_L_Ring3", "next_bone": StringName(), "digit": &"ring", "section": 3},
	{"bone": &"CC_Base_L_Pinky1", "next_bone": &"CC_Base_L_Pinky2", "digit": &"pinky", "section": 1},
	{"bone": &"CC_Base_L_Pinky2", "next_bone": &"CC_Base_L_Pinky3", "digit": &"pinky", "section": 2},
	{"bone": &"CC_Base_L_Pinky3", "next_bone": StringName(), "digit": &"pinky", "section": 3},
]

static func get_all_rules() -> Array[Dictionary]:
	if _all_rules_cache.is_empty():
		_append_expanded_rules(_all_rules_cache, SLOT_RIGHT, RIGHT_DIGIT_BONE_RULES)
		_append_expanded_rules(_all_rules_cache, SLOT_LEFT, LEFT_DIGIT_BONE_RULES)
		for rule: Dictionary in _all_rules_cache:
			_rule_by_bone_cache[rule.get("bone", StringName()) as StringName] = rule
	return _all_rules_cache

static func get_rule_for_bone(bone_name: StringName) -> Dictionary:
	get_all_rules()
	var rule: Dictionary = _rule_by_bone_cache.get(bone_name, {}) as Dictionary
	return rule.duplicate(true) if not rule.is_empty() else {}

static func get_closed_degrees_for_bone(bone_name: StringName) -> float:
	get_all_rules()
	var rule: Dictionary = _rule_by_bone_cache.get(bone_name, {}) as Dictionary
	return float(rule.get("closed_degrees", 0.0))

static func get_chain_rules(slot_id: StringName, digit_id: StringName) -> Array[Dictionary]:
	var chain_rules: Array[Dictionary] = []
	for rule: Dictionary in get_all_rules():
		if (rule.get("slot_id", StringName()) as StringName) != slot_id:
			continue
		if (rule.get("digit", StringName()) as StringName) != digit_id:
			continue
		chain_rules.append(rule.duplicate(true))
	chain_rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("solve_order", 0)) < int(b.get("solve_order", 0))
	)
	return chain_rules


static func get_revision() -> StringName:
	return SURFACE_SOLVER_RULE_REVISION


static func get_contact_capsule_radius_meters(
	slot_id: StringName,
	digit_id: StringName,
	section_index: int
) -> float:
	if slot_id != SLOT_RIGHT and slot_id != SLOT_LEFT:
		return 0.0
	if section_index < 1 or section_index > 3:
		return 0.0
	var contact_geometry: Dictionary = (
		RIGHT_DIGIT_CONTACT_GEOMETRY
		if slot_id == SLOT_RIGHT
		else LEFT_DIGIT_CONTACT_GEOMETRY
	)
	var digit_geometry: Dictionary = contact_geometry.get(digit_id, {}) as Dictionary
	var radii: Array = digit_geometry.get("capsule_radii_m", []) as Array
	if radii.size() != 3:
		return 0.0
	return maxf(float(radii[section_index - 1]), 0.0)


static func get_finger_bone_names(slot_id: StringName) -> Array[StringName]:
	var bone_names: Array[StringName] = []
	for digit_id: StringName in DIGIT_IDS:
		for rule: Dictionary in get_chain_rules(slot_id, digit_id):
			bone_names.append(rule.get("bone", StringName()) as StringName)
	return bone_names


static func get_surface_solver_side_rules(slot_id: StringName) -> Dictionary:
	if slot_id != SLOT_RIGHT and slot_id != SLOT_LEFT:
		return {}
	var contact_geometry: Dictionary = (
		RIGHT_DIGIT_CONTACT_GEOMETRY
		if slot_id == SLOT_RIGHT
		else LEFT_DIGIT_CONTACT_GEOMETRY
	)
	var digits: Array[Dictionary] = []
	for digit_id: StringName in DIGIT_IDS:
		var chain_rules: Array[Dictionary] = get_chain_rules(slot_id, digit_id)
		var geometry: Dictionary = contact_geometry.get(digit_id, {}) as Dictionary
		if chain_rules.size() != 3 or geometry.is_empty():
			return {}
		var bone_names: Array[StringName] = []
		var hinge_axes_local: Array[Vector3] = []
		var hinge_axis_origin_ids: Array[StringName] = []
		var zero_direction_origin_ids: Array[StringName] = []
		var minimum_angles_rad: Array[float] = []
		var maximum_angles_rad: Array[float] = []
		var preferred_angles_rad: Array[float] = []
		for rule: Dictionary in chain_rules:
			var bone_name: StringName = rule.get("bone", StringName()) as StringName
			var hinge_axis_origin_id: StringName = rule.get(
				"hinge_axis_origin_id",
				StringName()
			) as StringName
			var zero_direction_origin_id: StringName = rule.get(
				"zero_direction_origin_id",
				StringName()
			) as StringName
			if (
				bone_name == StringName()
				or hinge_axis_origin_id != bone_name
				or zero_direction_origin_id != bone_name
				or (rule.get("bone_root_origin_id", StringName()) as StringName) != ROOT_ORIGIN_ID
			):
				return {}
			bone_names.append(bone_name)
			hinge_axes_local.append(rule.get("hinge_axis_local", Vector3.ZERO) as Vector3)
			hinge_axis_origin_ids.append(hinge_axis_origin_id)
			zero_direction_origin_ids.append(zero_direction_origin_id)
			minimum_angles_rad.append(deg_to_rad(float(rule.get("min_degrees", 0.0))))
			maximum_angles_rad.append(deg_to_rad(float(rule.get("max_degrees", 0.0))))
			preferred_angles_rad.append(deg_to_rad(float(rule.get("closed_degrees", 0.0))))
		var terminal_length_m: float = float(geometry.get("terminal_length_m", 0.0))
		var is_thumb: bool = digit_id == &"thumb"
		var thumb1_open_degrees: float = (
			RIGHT_THUMB1_OPEN_DEGREES
			if slot_id == SLOT_RIGHT
			else LEFT_THUMB1_OPEN_DEGREES
		)
		digits.append({
			"digit_id": digit_id,
			"bone_names": bone_names,
			"bone_root_origin_id": ROOT_ORIGIN_ID,
			"neutral_local_rotations": [
				Quaternion.IDENTITY,
				Quaternion.IDENTITY,
				Quaternion.IDENTITY,
			],
			"hinge_axes_local": hinge_axes_local,
			"hinge_axis_origin_ids": hinge_axis_origin_ids,
			"zero_direction_local": ZERO_DIRECTION_LOCAL,
			"zero_direction_origin_ids": zero_direction_origin_ids,
			"min_angles_rad": minimum_angles_rad,
			"max_angles_rad": maximum_angles_rad,
			"preferred_angles_rad": preferred_angles_rad,
			"capsule_radii_m": (geometry.get("capsule_radii_m", []) as Array).duplicate(),
			"terminal_length_m": terminal_length_m,
			"tip_offset_local": ZERO_DIRECTION_LOCAL * terminal_length_m,
			"tip_offset_origin_id": bone_names[2],
			"tip_offset_root_origin_id": ROOT_ORIGIN_ID,
			"is_thumb": is_thumb,
			"contact_strategy": &"opposition_then_wrap" if is_thumb else &"serial_wrap",
			"section_target_overlaps_meters": (
				THUMB_SECTION_TARGET_OVERLAPS_METERS.duplicate()
				if is_thumb
				else SECTION_TARGET_OVERLAPS_METERS.duplicate()
			),
			# Pre-open is deliberately opposite the approved closing direction:
			# right +70 -> -30, left -70 -> +30.
			"thumb_clearance_open_sign": (
				signf(thumb1_open_degrees)
			) if is_thumb else 0.0,
			"thumb_clearance_step_degrees": THUMB_PREOPEN_STEP_DEGREES if is_thumb else 0.0,
			"thumb_clearance_max_degrees": absf(thumb1_open_degrees) if is_thumb else 0.0,
		})
	return {
		"calibration_revision": SURFACE_SOLVER_RULE_REVISION,
		"solver_compatibility_revision": 6,
		"independent_source_id": (
			&"josie_right_hand_local_z_direct_rules_v1"
			if slot_id == SLOT_RIGHT
			else &"josie_left_hand_local_z_direct_rules_v1"
		),
		"derived_from_side": StringName(),
		"mirrored_from_side": StringName(),
		"side_id": slot_id,
		"hand_bone_name": &"CC_Base_R_Hand" if slot_id == SLOT_RIGHT else &"CC_Base_L_Hand",
		"hand_bone_root_origin_id": ROOT_ORIGIN_ID,
		"max_overlap_meters": MAX_CONTACT_OVERLAP_METERS,
		"preferred_overlap_meters": PREFERRED_CONTACT_OVERLAP_METERS,
		"target_overlap_tolerance_meters": CONTACT_OVERLAP_TOLERANCE_METERS,
		"digits": digits,
	}

static func get_closed_degrees_for_group(slot_id: StringName, digit_id: StringName) -> float:
	var is_thumb: bool = digit_id == &"thumb"
	if slot_id == SLOT_RIGHT:
		return RIGHT_THUMB_CLOSED_DEGREES if is_thumb else RIGHT_FINGER_CLOSED_DEGREES
	return LEFT_THUMB_CLOSED_DEGREES if is_thumb else LEFT_FINGER_CLOSED_DEGREES

static func get_closed_degrees_for_joint(
	slot_id: StringName,
	digit_id: StringName,
	section_index: int
) -> float:
	if digit_id == &"thumb" and section_index == 1:
		return (
			RIGHT_THUMB1_CLOSED_DEGREES
			if slot_id == SLOT_RIGHT
			else LEFT_THUMB1_CLOSED_DEGREES
		)
	return get_closed_degrees_for_group(slot_id, digit_id)


static func get_open_degrees_for_joint(
	slot_id: StringName,
	digit_id: StringName,
	section_index: int
) -> float:
	if digit_id == &"thumb" and section_index == 1:
		return (
			RIGHT_THUMB1_OPEN_DEGREES
			if slot_id == SLOT_RIGHT
			else LEFT_THUMB1_OPEN_DEGREES
		)
	return 0.0

static func _append_expanded_rules(
	target: Array[Dictionary],
	slot_id: StringName,
	authored_rules: Array
) -> void:
	for authored_rule: Dictionary in authored_rules:
		var expanded_rule: Dictionary = authored_rule.duplicate(true)
		var bone_name: StringName = expanded_rule.get("bone", StringName()) as StringName
		var digit_id: StringName = expanded_rule.get("digit", StringName()) as StringName
		var section_index: int = int(expanded_rule.get("section", 0))
		var is_thumb: bool = digit_id == &"thumb"
		var open_degrees: float = get_open_degrees_for_joint(
			slot_id,
			digit_id,
			section_index
		)
		var closed_degrees: float = get_closed_degrees_for_joint(slot_id, digit_id, section_index)
		var is_bidirectional_thumb_root: bool = is_thumb and section_index == 1
		expanded_rule["slot_id"] = slot_id
		expanded_rule["hinge_axis_local"] = HINGE_AXIS_LOCAL
		expanded_rule["hinge_axis_origin_id"] = bone_name
		expanded_rule["zero_direction_local"] = ZERO_DIRECTION_LOCAL
		expanded_rule["zero_direction_origin_id"] = bone_name
		expanded_rule["bone_root_origin_id"] = ROOT_ORIGIN_ID
		expanded_rule["open_degrees"] = open_degrees
		expanded_rule["closed_degrees"] = closed_degrees
		expanded_rule["min_degrees"] = minf(open_degrees, closed_degrees)
		expanded_rule["max_degrees"] = maxf(open_degrees, closed_degrees)
		expanded_rule["bidirectional_about_zero"] = is_bidirectional_thumb_root
		expanded_rule["motion_direction_sign"] = 1.0 if closed_degrees > 0.0 else -1.0
		expanded_rule["solve_order"] = int(expanded_rule.get("section", 0))
		expanded_rule["solve_mode"] = &"serial_joint_hinge"
		expanded_rule["preload_mode"] = &"collinear_then_clear_open" if is_thumb else &"authored_open_pose"
		expanded_rule["preload_collinear"] = is_thumb
		expanded_rule["pre_open_required"] = is_thumb
		expanded_rule["pre_open_step_degrees"] = THUMB_PREOPEN_STEP_DEGREES if is_thumb else 0.0
		target.append(expanded_rule)

static func rule_has_valid_origin_chain(
	rule: Dictionary,
	skeleton: Skeleton3D
) -> bool:
	if skeleton == null or rule.is_empty():
		return false
	var bone_name: StringName = rule.get("bone", StringName()) as StringName
	var hinge_axis_origin_id: StringName = rule.get(
		"hinge_axis_origin_id",
		StringName()
	) as StringName
	var zero_direction_origin_id: StringName = rule.get(
		"zero_direction_origin_id",
		StringName()
	) as StringName
	var root_origin_id: StringName = rule.get(
		"bone_root_origin_id",
		StringName()
	) as StringName
	if (
		bone_name == StringName()
		or hinge_axis_origin_id != bone_name
		or zero_direction_origin_id != bone_name
		or root_origin_id != ROOT_ORIGIN_ID
	):
		return false
	var bone_index: int = skeleton.find_bone(String(bone_name))
	var visited: Dictionary = {}
	while bone_index >= 0:
		if visited.has(bone_index):
			return false
		visited[bone_index] = true
		if StringName(skeleton.get_bone_name(bone_index)) == root_origin_id:
			return true
		bone_index = skeleton.get_bone_parent(bone_index)
	return false
