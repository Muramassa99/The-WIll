extends SceneTree

const Owner = preload("res://runtime/player/grip/preview_grip_acquisition.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var weapon := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.set_meta("visual_mesh_source", &"editable_mesh")
	weapon.add_child(mesh)
	var prefix := "preview_primary_grip_seat"
	weapon.set_meta(prefix + "_origin_id", Origins.ORIGIN_WEAPON_ROOT)
	var station := Vector3(-0.357086, -0.006542, -1.88737914186277e-15)
	weapon.set_meta(prefix + "_local", station)
	var original := Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy")
	station.z = 0.0
	weapon.set_meta(prefix + "_local", station)
	_check(original == Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy"), "bake zero tail retains relationship")
	station.z = -0.0
	weapon.set_meta(prefix + "_local", station)
	_check(original == Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy"), "signed zero retains relationship")
	var float32_offset := float(PackedFloat32Array([0.123456789])[0])
	station.x = float32_offset
	weapon.set_meta(prefix + "_local", station)
	var baked := Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy")
	station.x = 0.123456789
	weapon.set_meta(prefix + "_local", station)
	_check(baked == Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy"), "authored offset float32 round trip retains relationship")
	station.x += 0.00005
	weapon.set_meta(prefix + "_local", station)
	_check(baked != Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy"), "meaningful 0.05 mm station edit invalidates relationship")
	var moved := Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy")
	mesh.position.y = 0.00000001
	_check(moved != Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy"), "geometry transforms keep exact identity")
	mesh.position = Vector3.ZERO
	_check(moved != Owner.relationship_key(weapon, &"hand_right", &"hand_right", "anatomy", 1), "geometry revision invalidates relationship")
	weapon.free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); push_error(label)
