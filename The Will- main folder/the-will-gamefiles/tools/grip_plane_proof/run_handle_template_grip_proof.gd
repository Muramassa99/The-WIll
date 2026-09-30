extends "res://tools/grip_plane_proof/run_handle_grip_process_proof.gd"

## Shape comparison only. Replace the captured object with a recorded straight
## Forge profile fixture; all guide/contact/response/reseat code is inherited.
const TemplateFixture = preload("res://tools/grip_plane_proof/linear_handle_template_fixture.gd")
const TEMPLATE_KEYS: Dictionary = {
	"handle_profile_1783395703.211_3": "rounded_rectangle",
	"handle_profile_1787890891.94_10": "rombus",
	"handle_profile_1787891232.544_14": "odd_shape_3",
}
var _template_builder := TemplateFixture.new()
var _template_input: Dictionary = {}
var _template_key: String = ""


func _run() -> void:
	var profile_id: String = OS.get_environment("THE_WILL_GRIP_TEMPLATE_ID")
	if not TEMPLATE_KEYS.has(profile_id):
		push_error("Choose one of the three recorded handle template IDs")
		quit(1)
		return
	_template_key = TEMPLATE_KEYS[profile_id]
	_template_input = _template_builder.load_profile(profile_id)
	if not _template_input.get("valid", false):
		push_error(str(_template_input))
		quit(1)
		return
	print("HANDLE_TEMPLATE=" + JSON.stringify(_json(_template_input.metadata)))
	await super._run()


func _report_stem() -> String:
	var prefix: String = "verify_handle_template_input_" if OS.get_environment("THE_WILL_GRIP_TEMPLATE_INPUT_ONLY") == "1" else "handle_template_grip_"
	return prefix + _template_key


func _report_extensions() -> Dictionary:
	var out: Dictionary = super._report_extensions()
	# The base implementation uses get_script(); here distinguish its unchanged
	# solver source from this input-only adapter rather than mislabel either hash.
	out.source_sha256.runner = FileAccess.get_sha256("res://tools/grip_plane_proof/run_handle_grip_process_proof.gd")
	out["template_fixture"] = _template_input.metadata.duplicate(true)
	out["template_adapter_sha256"] = FileAccess.get_sha256("res://tools/grip_plane_proof/run_handle_template_grip_proof.gd")
	out["template_fixture_builder_sha256"] = FileAccess.get_sha256("res://tools/grip_plane_proof/linear_handle_template_fixture.gd")
	out["captured_weapon_replaced_for_test"] = true
	out["solver_settings_changed_for_template"] = false
	out["saved_profile_written"] = false
	return out


func _prepare(definition: Resource, stage: Dictionary) -> Dictionary:
	var built: Dictionary = _template_builder.build_for_stage(_template_input, stage)
	if not built.get("valid", false): return built
	var context: Dictionary = super._prepare(definition, built.stage)
	if not context.get("valid", false): return context
	context["template_fixture"] = built.metadata
	print("HANDLE_TEMPLATE_INPUT=" + JSON.stringify(_json({"slot": context.slot, "fixture": built.metadata})))
	return context


func _search(context: Dictionary) -> Dictionary:
	if OS.get_environment("THE_WILL_GRIP_TEMPLATE_INPUT_ONLY") == "1":
		_circle_cache.clear()
		_slice_cache.clear()
		_circle_evaluations = 0
		_set_phase("circle", 0.0)
		var sample: Dictionary = _circle_sample(context, context.open_parameters, 0.05, true)
		return {"valid": sample.get("valid", false), "reason": sample.get("reason", ""),
			"slot": context.slot, "selected": sample, "template_fixture": context.template_fixture,
			"evaluation_count": _circle_evaluations, "production_pose_written": false, "grip_accepted": false}
	var result: Dictionary = await super._search(context)
	result["template_fixture"] = context.template_fixture
	return result
