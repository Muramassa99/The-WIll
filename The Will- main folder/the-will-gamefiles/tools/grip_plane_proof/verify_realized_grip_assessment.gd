extends SceneTree

const Assessment = preload("res://runtime/player/grip/realized_grip_assessment.gd")
const Profile = preload("res://core/defs/characters/josie/grip_contact_config.tres")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path: String = OS.get_environment("THE_WILL_LIVE_GRIP_CAPTURE").replace("\\", "/").simplify_path()
	if not path.begins_with("C:/WORKSPACE/test_artifacts/") or path.get_extension() != "bin":
		push_error("Explicit workspace actual-rig capture required"); quit(1); return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open actual-rig capture"); quit(1); return
	var capture: Variant = file.get_var(false)
	file.close()
	if not capture is Dictionary or not capture.get("valid", false):
		push_error("Invalid actual-rig capture"); quit(1); return
	var before: String = var_to_bytes(capture).hex_encode().sha256_text()
	var result: Dictionary = await Assessment.new().assess(Profile.anatomy, capture, Profile.contact_config, root)
	var unchanged: bool = var_to_bytes(capture).hex_encode().sha256_text() == before
	var checks := {"query_valid": result.get("valid", false), "capture_unchanged": unchanged,
		"observed_not_reposed": result.get("observed_not_reposed", false),
		"no_false_3d_certificate": not result.get("actual_3d_grip_verified", true),
		"all_five_planes": result.get("selected", {}).get("digits", []).size() == 5}
	var passed: bool = true
	for value: bool in checks.values(): passed = passed and value
	var report := {"ok": passed, "checks": checks, "source": path, "source_sha256": FileAccess.get_sha256(path), "assessment": result}
	var output := "C:/WORKSPACE/test_artifacts/verify_realized_grip_assessment_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var out := FileAccess.open(output, FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t")); out.close()
	print("REALIZED_GRIP_ASSESSMENT=" + output + " ok=" + str(passed))
	print("ACTUAL_MATERIAL=" + JSON.stringify({"safe": result.get("actual_material_safe"), "contacts": result.get("actual_material_contacts"), "reason": result.get("reason")}))
	quit(0 if passed else 1)
