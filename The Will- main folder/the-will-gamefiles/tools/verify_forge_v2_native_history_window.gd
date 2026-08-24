extends SceneTree

const WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const EXTENSION_PATH := (
	"res://native/forge_v2_manifold/forge_v2_manifold.gdextension"
)
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/verify_forge_v2_native_history_window.json"
)
const TOTAL_DEPOSITED_PASSES := 20
const INITIAL_ADD_COUNT := TOTAL_DEPOSITED_PASSES - 1
const HISTORY_WINDOW_CAPACITY := 5
const MATERIAL_VARIANT_ID := &"mat_iron_gray"
# This oracle compares sequential resident-Manifold unions with Godot's
# all-at-once CSG BatchBoolean. At mature overlap they have different numeric
# association/triangulation despite identical bounds and topology. The live
# native baseline is gated byte-exactly below; this independent oracle keeps a
# separate sub-0.05 mm solid-set sanity bound rather than asserting layout.
const CSG_SURFACE_DISTANCE_LIMIT_METERS := 0.00005
const CSG_BOUNDS_LIMIT_METERS := 0.00001
const CSG_VOLUME_ABSOLUTE_LIMIT_CUBIC_METERS := 0.0000000005
const CSG_VOLUME_RELATIVE_LIMIT := 0.0001
const HISTORY_KEYS := [
	"history_window_enabled",
	"history_window_capacity",
	"checkpoint_operation_count",
	"active_tail_cursor",
	"tail_timeline_count",
	"redo_count",
	"retained_state_count",
	"retained_total_vertices",
	"retained_total_triangles",
	"promotion_count",
	"boolean_count",
	"export_count",
	"last_mode",
	"promotion_boolean_delta",
	"promotion_export_delta",
	"state_initialized",
	"revision",
	"state_revision",
	"state_vertex_count",
	"state_triangle_count",
	"state_volume_m3",
]

var _workspace: Node3D
var _errors: Array[String] = []
var _deposit_rows: Array[Dictionary] = []
var _history_rows: Array[Dictionary] = []
var _geometry_rows: Array[Dictionary] = []
var _csg_rows: Array[Dictionary] = []
var _packet_replay_rows: Array[Dictionary] = []
var _subject_packet_digests: Dictionary = {}
var _revision_check_count := 0
var _revision_check_pass_count := 0
var _gate_state := {
	"native_contract_is_available": true,
	"fixture_is_deterministic_connected_and_explicit": true,
	"independent_full_replays_are_strict": true,
	"boundary_packets_match_independent_current_csg": true,
	"n_le_5_has_checkpoint_0_and_tail_n": true,
	"n_6_promotes_to_checkpoint_1_and_tail_5": true,
	"n_20_has_checkpoint_15_tail_5_and_6_states": true,
	"every_add_has_exactly_one_boolean_and_one_export": true,
	"promotions_have_no_extra_boolean_or_export": true,
	"retained_storage_matches_the_six_state_window": true,
	"selected_packets_match_independent_full_replay": true,
	"navigation_packets_match_original_subject_packets_exactly": true,
	"successful_mutations_increment_revision_by_one": true,
	"unavailable_navigation_preserves_revision_and_error_code": true,
	"n_1_undo_reaches_empty_s0_and_redo_restores_s1": true,
	"exactly_five_undos_succeed_and_the_sixth_fails": true,
	"five_redos_restore_the_exact_states": true,
	"branch_append_clears_redo_and_preserves_checkpoint": true,
}
var _report := {
	"schema": "forge_v2_native_history_window",
	"schema_version": 1,
	"ok": false,
	"production_files_touched": false,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var fixture_preflight: Dictionary = StressFixtureScript.preflight(
		TOTAL_DEPOSITED_PASSES
	)
	_mark(
		"fixture_is_deterministic_connected_and_explicit",
		bool(fixture_preflight.get("ok", false)),
		"stress_fixture_preflight_failed"
	)
	if not bool(fixture_preflight.get("ok", false)):
		_finish_failure("deterministic stress fixture preflight failed")
		return

	_workspace = WorkspacePreviewScript.new()
	_workspace.name = "NativeHistoryWindowVerifierWorkspace"
	root.add_child(_workspace)
	await process_frame
	var presenter := _workspace.get("volume_preview_presenter") as Node3D
	if presenter == null:
		presenter = VolumePreviewPresenterScript.new()
		_workspace.add_child(presenter)

	var fixture_packets := _build_fixture_packets(presenter)
	if not bool(fixture_packets.get("ok", false)):
		_mark(
			"fixture_is_deterministic_connected_and_explicit",
			false,
			"fixture_sweep_packet_failed"
		)
		_finish_failure(String(fixture_packets.get(
			"error", "fixture packet construction failed"
		)))
		return
	var packets: Array = fixture_packets.get("packets", []) as Array
	var bodies: Array = fixture_packets.get("bodies", []) as Array

	var extension_resource: Resource = load(EXTENSION_PATH)
	if extension_resource == null or not ClassDB.class_exists(
		&"ForgeV2ManifoldBoolean"
	):
		_mark(
			"native_contract_is_available",
			false,
			"native_extension_unavailable"
		)
		_finish_failure("native ForgeV2ManifoldBoolean is unavailable")
		return
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null or not _contract_is_available(backend):
		_mark(
			"native_contract_is_available",
			false,
			"history_method_contract_missing"
		)
		_finish_failure("native history-window method contract is incomplete")
		return
	var enable_result := backend.call(
		"set_history_window_enabled", true
	) as Dictionary
	if not bool(enable_result.get("ok", false)) \
			or not bool(enable_result.get("history_window_enabled", false)):
		_mark(
			"native_contract_is_available",
			false,
			"history_window_opt_in_failed"
		)
		_finish_failure("native history-window opt-in failed")
		return

	# The oracle never undoes or branches. It independently replays the original
	# explicit sweep packets from the reset through every deposited pass.
	var original_oracle := _build_full_replay_oracle(
		packets, TOTAL_DEPOSITED_PASSES
	)
	if not bool(original_oracle.get("ok", false)):
		_mark(
			"independent_full_replays_are_strict",
			false,
			"original_full_replay_failed"
		)
		_finish_failure(String(original_oracle.get(
			"error", "original full replay failed"
		)))
		return
	var original_states: Array = original_oracle.get("states", []) as Array
	_mark(
		"independent_full_replays_are_strict",
		bool(original_oracle.get("strict", false)),
		"original_full_replay_topology_failed"
	)

	# S18 is seed + operation bodies 0..16. Skip the two redo operands and use
	# operation body 19 as a distinct but still overlapping branch operand.
	var branch_packets: Array = []
	for packet_index in range(TOTAL_DEPOSITED_PASSES - 2):
		branch_packets.append(packets[packet_index])
	branch_packets.append(packets[TOTAL_DEPOSITED_PASSES])
	var branch_oracle := _build_full_replay_oracle(
		branch_packets, branch_packets.size()
	)
	if not bool(branch_oracle.get("ok", false)):
		_mark(
			"independent_full_replays_are_strict",
			false,
			"branch_full_replay_failed"
		)
		_finish_failure(String(branch_oracle.get(
			"error", "branch full replay failed"
		)))
		return
	var branch_states: Array = branch_oracle.get("states", []) as Array
	_mark(
		"independent_full_replays_are_strict",
		bool(branch_oracle.get("strict", false)),
		"branch_full_replay_topology_failed"
	)
	var csg_oracles: Dictionary = await _build_csg_checkpoint_oracles(
		presenter, bodies
	)
	if not bool(csg_oracles.get("ok", false)):
		_mark(
			"boundary_packets_match_independent_current_csg",
			false,
			"current_csg_oracle_construction_failed"
		)
		_finish_failure(String(csg_oracles.get(
			"error", "current CSG oracle construction failed"
		)))
		return

	var empty_probe := _run_empty_sentinel_probe(
		packets[0] as Dictionary,
		original_states[1] as Dictionary
	)

	var append_counter_checks := 0
	var promotion_checks := 0
	var packet: Dictionary = packets[0] as Dictionary
	var before_reset := _history_info(backend)
	var reset_result := backend.call(
		"reset_mesh",
		packet.get("vertices", PackedVector3Array()),
		packet.get("indices", PackedInt32Array())
	) as Dictionary
	if not _mutation_succeeded(reset_result):
		_finish_failure("subject reset_mesh failed: %s" % String(
			reset_result.get("error_message", "unknown")
		))
		return
	var history := _history_info(backend)
	_check_revision_advanced(
		before_reset, history, reset_result, "subject_reset"
	)
	_check_result_matches_history(reset_result, history, "reset")
	_check_linear_window(history, 1, original_states, "deposit_01")
	_mark(
		"every_add_has_exactly_one_boolean_and_one_export",
		int(history.get("boolean_count", -1)) == 0
			and int(history.get("export_count", -1)) == 1,
		"reset_counter_baseline_changed"
	)
	_mark(
		"n_le_5_has_checkpoint_0_and_tail_n",
		String(history.get("last_mode", "")) == "reset",
		"reset_mode_changed"
	)
	_record_geometry_match(
		"deposit_01_reset", 1, reset_result, original_states[1] as Dictionary
	)
	_save_subject_packet_digest(1, reset_result)
	_deposit_rows.append(_deposit_row(1, history, reset_result))

	for deposited_pass in range(2, TOTAL_DEPOSITED_PASSES + 1):
		packet = packets[deposited_pass - 1] as Dictionary
		var before := _history_info(backend)
		var add_result := backend.call(
			"add_mesh",
			packet.get("vertices", PackedVector3Array()),
			packet.get("indices", PackedInt32Array())
		) as Dictionary
		if not _mutation_succeeded(add_result):
			_finish_failure("subject add_mesh failed at N=%d: %s" % [
				deposited_pass,
				String(add_result.get("error_message", "unknown")),
			])
			return
		history = _history_info(backend)
		_check_revision_advanced(
			before,
			history,
			add_result,
			"subject_deposit_%02d" % deposited_pass
		)
		var counter_ok := (
			int(history.get("boolean_count", -1))
				== int(before.get("boolean_count", -2)) + 1
			and int(history.get("export_count", -1))
				== int(before.get("export_count", -2)) + 1
		)
		append_counter_checks += int(counter_ok)
		_mark(
			"every_add_has_exactly_one_boolean_and_one_export",
			counter_ok,
			"append_counter_delta_changed_at_%d" % deposited_pass
		)
		var promoted := deposited_pass > HISTORY_WINDOW_CAPACITY
		var expected_mode := "promotion_append" if promoted else "append"
		var promotion_ok := (
			int(history.get("promotion_count", -1))
				== int(before.get("promotion_count", -2)) + int(promoted)
			and int(history.get("promotion_boolean_delta", -1)) == 0
			and int(history.get("promotion_export_delta", -1)) == 0
			and int(add_result.get("promotion_boolean_delta", -1)) == 0
			and int(add_result.get("promotion_export_delta", -1)) == 0
		)
		if promoted:
			promotion_checks += int(promotion_ok)
			_mark(
				"promotions_have_no_extra_boolean_or_export",
				promotion_ok,
				"promotion_did_extra_work_at_%d" % deposited_pass
			)
		_mark(
			"n_le_5_has_checkpoint_0_and_tail_n"
				if deposited_pass <= HISTORY_WINDOW_CAPACITY
				else "n_6_promotes_to_checkpoint_1_and_tail_5"
				if deposited_pass == HISTORY_WINDOW_CAPACITY + 1
				else "n_20_has_checkpoint_15_tail_5_and_6_states",
			String(history.get("last_mode", "")) == expected_mode,
			"append_mode_changed_at_%d" % deposited_pass
		)
		_check_result_matches_history(
			add_result, history, "deposit_%02d" % deposited_pass
		)
		_check_linear_window(
			history,
			deposited_pass,
			original_states,
			"deposit_%02d" % deposited_pass
		)
		_record_geometry_match(
			"deposit_%02d" % deposited_pass,
			deposited_pass,
			add_result,
			original_states[deposited_pass] as Dictionary
		)
		_save_subject_packet_digest(deposited_pass, add_result)
		if deposited_pass in [5, 6, TOTAL_DEPOSITED_PASSES]:
			_record_csg_parity(
				"deposit_%02d" % deposited_pass,
				deposited_pass,
				add_result,
				csg_oracles.get(str(deposited_pass), {}) as Dictionary
			)
		_deposit_rows.append(_deposit_row(
			deposited_pass, history, add_result
		))

	_mark(
		"every_add_has_exactly_one_boolean_and_one_export",
		append_counter_checks == INITIAL_ADD_COUNT,
		"initial_append_counter_check_count_changed"
	)
	_mark(
		"promotions_have_no_extra_boolean_or_export",
		promotion_checks
			== TOTAL_DEPOSITED_PASSES - HISTORY_WINDOW_CAPACITY,
		"promotion_check_count_changed"
	)
	_check_history_shape(
		history,
		15,
		5,
		5,
		0,
		6,
		_retained_totals(original_states, 15, 20),
		"n_20",
		"n_20_has_checkpoint_15_tail_5_and_6_states"
	)

	var undo_success_count := 0
	for undo_index in range(1, HISTORY_WINDOW_CAPACITY + 2):
		var before_undo := _history_info(backend)
		var undo_result := backend.call("undo_state") as Dictionary
		var after_undo := _history_info(backend)
		if undo_index <= HISTORY_WINDOW_CAPACITY:
			var undo_ok := _mutation_succeeded(undo_result)
			undo_success_count += int(undo_ok)
			_mark(
				"exactly_five_undos_succeed_and_the_sixth_fails",
				undo_ok,
				"undo_%d_failed" % undo_index
			)
			var expected_pass := TOTAL_DEPOSITED_PASSES - undo_index
			_check_revision_advanced(
				before_undo,
				after_undo,
				undo_result,
				"subject_undo_%d" % undo_index
			)
			_check_navigation_counters(
				before_undo,
				after_undo,
				"undo_%d" % undo_index,
				"exactly_five_undos_succeed_and_the_sixth_fails"
			)
			_check_result_matches_history(
				undo_result, after_undo, "undo_%d" % undo_index
			)
			_check_history_shape(
				after_undo,
				15,
				5 - undo_index,
				5,
				undo_index,
				6,
				_retained_totals(original_states, 15, 20),
				"undo_%d" % undo_index,
				"exactly_five_undos_succeed_and_the_sixth_fails"
			)
			_record_geometry_match(
				"undo_%d" % undo_index,
				expected_pass,
				undo_result,
				original_states[expected_pass] as Dictionary
			)
			_check_subject_packet_replay(
				"undo_%d" % undo_index,
				expected_pass,
				undo_result,
				"exactly_five_undos_succeed_and_the_sixth_fails"
			)
			_history_rows.append(_navigation_row(
				"undo", undo_index, expected_pass, after_undo
			))
		else:
			var unavailable_ok := _unavailable_navigation_ok(
				undo_result,
				before_undo,
				after_undo,
				"UNDO_UNAVAILABLE"
			)
			_mark(
				"exactly_five_undos_succeed_and_the_sixth_fails",
				unavailable_ok,
				"sixth_undo_was_not_a_noop_failure"
			)
			_mark(
				"unavailable_navigation_preserves_revision_and_error_code",
				unavailable_ok,
				"sixth_undo_revision_or_error_code_changed"
			)
			_check_result_matches_history(
				undo_result, after_undo, "undo_unavailable"
			)
			_history_rows.append({
				"phase": "undo_unavailable",
				"ok": unavailable_ok,
				"error_code": String(undo_result.get("error_code", "")),
			})
	_mark(
		"exactly_five_undos_succeed_and_the_sixth_fails",
		undo_success_count == HISTORY_WINDOW_CAPACITY,
		"undo_success_count_changed"
	)

	var redo_success_count := 0
	for redo_index in range(1, HISTORY_WINDOW_CAPACITY + 1):
		var before_redo := _history_info(backend)
		var redo_result := backend.call("redo_state") as Dictionary
		var after_redo := _history_info(backend)
		var redo_ok := _mutation_succeeded(redo_result)
		redo_success_count += int(redo_ok)
		_mark(
			"five_redos_restore_the_exact_states",
			redo_ok,
			"redo_%d_failed" % redo_index
		)
		_check_revision_advanced(
			before_redo,
			after_redo,
			redo_result,
			"subject_redo_%d" % redo_index
		)
		_check_navigation_counters(
			before_redo,
			after_redo,
			"redo_%d" % redo_index,
			"five_redos_restore_the_exact_states"
		)
		_check_result_matches_history(
			redo_result, after_redo, "redo_%d" % redo_index
		)
		_check_history_shape(
			after_redo,
			15,
			redo_index,
			5,
			5 - redo_index,
			6,
			_retained_totals(original_states, 15, 20),
			"redo_%d" % redo_index,
			"five_redos_restore_the_exact_states"
		)
		var expected_pass := 15 + redo_index
		_record_geometry_match(
			"redo_%d" % redo_index,
			expected_pass,
			redo_result,
			original_states[expected_pass] as Dictionary
		)
		_check_subject_packet_replay(
			"redo_%d" % redo_index,
			expected_pass,
			redo_result,
			"five_redos_restore_the_exact_states"
		)
		_history_rows.append(_navigation_row(
			"redo", redo_index, expected_pass, after_redo
		))
	_mark(
		"five_redos_restore_the_exact_states",
		redo_success_count == HISTORY_WINDOW_CAPACITY,
		"redo_success_count_changed"
	)

	for branch_undo_index in range(1, 3):
		var before_branch_undo := _history_info(backend)
		var branch_undo := backend.call("undo_state") as Dictionary
		var after_branch_undo := _history_info(backend)
		var target_pass := TOTAL_DEPOSITED_PASSES - branch_undo_index
		_mark(
			"branch_append_clears_redo_and_preserves_checkpoint",
			_mutation_succeeded(branch_undo),
			"branch_setup_undo_%d_failed" % branch_undo_index
		)
		_check_revision_advanced(
			before_branch_undo,
			after_branch_undo,
			branch_undo,
			"branch_setup_undo_%d" % branch_undo_index
		)
		_check_result_matches_history(
			branch_undo,
			after_branch_undo,
			"branch_setup_undo_%d" % branch_undo_index
		)
		_check_navigation_counters(
			before_branch_undo,
			after_branch_undo,
			"branch_setup_undo_%d" % branch_undo_index,
			"branch_append_clears_redo_and_preserves_checkpoint"
		)
		_check_history_shape(
			after_branch_undo,
			15,
			5 - branch_undo_index,
			5,
			branch_undo_index,
			6,
			_retained_totals(original_states, 15, 20),
			"branch_setup_undo_%d" % branch_undo_index,
			"branch_append_clears_redo_and_preserves_checkpoint"
		)
		_record_geometry_match(
			"branch_setup_undo_%d" % branch_undo_index,
			target_pass,
			branch_undo,
			original_states[target_pass] as Dictionary
		)
		_check_subject_packet_replay(
			"branch_setup_undo_%d" % branch_undo_index,
			target_pass,
			branch_undo,
			"branch_append_clears_redo_and_preserves_checkpoint"
		)

	var before_branch := _history_info(backend)
	packet = packets[TOTAL_DEPOSITED_PASSES] as Dictionary
	var branch_result := backend.call(
		"add_mesh",
		packet.get("vertices", PackedVector3Array()),
		packet.get("indices", PackedInt32Array())
	) as Dictionary
	if not _mutation_succeeded(branch_result):
		_finish_failure("branch add_mesh failed: %s" % String(
			branch_result.get("error_message", "unknown")
		))
		return
	var after_branch := _history_info(backend)
	_check_revision_advanced(
		before_branch, after_branch, branch_result, "subject_branch_append"
	)
	var branch_counter_ok := (
		int(after_branch.get("boolean_count", -1))
			== int(before_branch.get("boolean_count", -2)) + 1
		and int(after_branch.get("export_count", -1))
			== int(before_branch.get("export_count", -2)) + 1
	)
	append_counter_checks += int(branch_counter_ok)
	_mark(
		"every_add_has_exactly_one_boolean_and_one_export",
		branch_counter_ok and append_counter_checks == 20,
		"branch_append_counter_delta_changed"
	)
	var branch_contract_ok := (
		String(after_branch.get("last_mode", "")) == "branch_append"
		and int(after_branch.get("checkpoint_operation_count", -1))
			== int(before_branch.get("checkpoint_operation_count", -2))
		and int(after_branch.get("promotion_count", -1))
			== int(before_branch.get("promotion_count", -2))
		and int(after_branch.get("redo_count", -1)) == 0
		and int(after_branch.get("promotion_boolean_delta", -1)) == 0
		and int(after_branch.get("promotion_export_delta", -1)) == 0
	)
	_mark(
		"branch_append_clears_redo_and_preserves_checkpoint",
		branch_contract_ok,
		"branch_append_history_shape_changed"
	)
	_check_result_matches_history(branch_result, after_branch, "branch_append")
	_check_history_shape(
		after_branch,
		15,
		4,
		4,
		0,
		5,
		_retained_totals(branch_states, 15, 19),
		"branch_append",
		"branch_append_clears_redo_and_preserves_checkpoint"
	)
	_record_geometry_match(
		"branch_append",
		19,
		branch_result,
		branch_states[19] as Dictionary
	)
	_record_csg_parity(
		"branch_append",
		19,
		branch_result,
		csg_oracles.get("branch", {}) as Dictionary
	)
	_history_rows.append(_navigation_row(
		"branch_append", 1, 19, after_branch
	))

	var before_failed_redo := _history_info(backend)
	var failed_redo := backend.call("redo_state") as Dictionary
	var after_failed_redo := _history_info(backend)
	var failed_redo_ok := _unavailable_navigation_ok(
		failed_redo,
		before_failed_redo,
		after_failed_redo,
		"REDO_UNAVAILABLE"
	)
	_mark(
		"branch_append_clears_redo_and_preserves_checkpoint",
		failed_redo_ok,
		"redo_survived_branch_append"
	)
	_mark(
		"unavailable_navigation_preserves_revision_and_error_code",
		failed_redo_ok,
		"branch_redo_revision_or_error_code_changed"
	)
	_check_result_matches_history(
		failed_redo, after_failed_redo, "branch_redo_unavailable"
	)

	_mark(
		"boundary_packets_match_independent_current_csg",
		_csg_rows.size() == 4,
		"current_csg_checkpoint_count_changed"
	)
	_mark(
		"navigation_packets_match_original_subject_packets_exactly",
		_packet_replay_rows.size() == 13,
		"exact_packet_replay_check_count_changed"
	)
	_mark(
		"successful_mutations_increment_revision_by_one",
		_revision_check_count == 36
			and _revision_check_pass_count == _revision_check_count,
		"successful_revision_check_count_changed"
	)
	var passed := _errors.is_empty()
	for value: Variant in _gate_state.values():
		passed = passed and bool(value)
	_report.merge({
		"ok": passed,
		"outcome": "pass" if passed else "fail",
		"scope": {
			"deposited_passes": TOTAL_DEPOSITED_PASSES,
			"initial_add_calls": INITIAL_ADD_COUNT,
			"total_add_calls_including_branch": 20,
			"history_window_capacity": HISTORY_WINDOW_CAPACITY,
			"full_replay_oracle": "fresh_native_replay_without_undo_or_redo",
			"independent_oracle": "current_presenter_csg_at_n5_n6_n20_branch",
			"revision_checks": _revision_check_count,
		},
		"fixture": {
			"fixture_id": fixture_preflight.get("fixture_id", ""),
			"stream_digest": fixture_preflight.get("stream_digest", ""),
			"packet_count_including_branch": packets.size(),
		},
		"deposits": _deposit_rows,
		"history": _history_rows,
		"geometry": _geometry_rows,
		"current_csg": _csg_rows,
		"packet_replay": _packet_replay_rows,
		"subject_packet_digests": _subject_packet_digest_summary(),
		"empty_sentinel": empty_probe,
		"final_history": _history_summary(after_failed_redo),
		"errors": _errors,
		"gates": _gate_state,
	}, true)
	_write_report()
	if passed:
		print("FORGE_V2_NATIVE_HISTORY_WINDOW: PASS")
		quit(0)
	else:
		push_error("FORGE_V2_NATIVE_HISTORY_WINDOW: FAIL")
		quit(1)


func _build_fixture_packets(presenter: Node3D) -> Dictionary:
	var packets: Array[Dictionary] = []
	var bodies: Array[Resource] = []
	for packet_index in range(TOTAL_DEPOSITED_PASSES + 1):
		var body: Resource = (
			StressFixtureScript.build_seed_body()
			if packet_index == 0
			else StressFixtureScript.build_operation_body(packet_index - 1)
		)
		if (
			body == null
			or not bool(body.call("uses_explicit_surface_contact_authority"))
		):
			return {
				"ok": false,
				"error": "fixture body %d lacks explicit contact authority" % packet_index,
			}
		var sweep := presenter.call(
			"_build_active_material_body_sweep_mesh", body
		) as ArrayMesh
		var packet := _mesh_packet(sweep)
		if not bool(packet.get("ok", false)):
			return {
				"ok": false,
				"error": "fixture body %d produced an invalid sweep" % packet_index,
			}
		packets.append(packet)
		bodies.append(body)
	return {"ok": true, "packets": packets, "bodies": bodies}


func _build_csg_checkpoint_oracles(
	presenter: Node3D, bodies: Array
) -> Dictionary:
	var result := {"ok": true}
	for deposited_pass in [5, 6, TOTAL_DEPOSITED_PASSES]:
		var prefix_bodies: Array = []
		for body_index in range(deposited_pass):
			prefix_bodies.append(bodies[body_index])
		var oracle: Dictionary = await _build_current_csg_oracle(
			presenter,
			prefix_bodies,
			"N%d" % deposited_pass
		)
		if not bool(oracle.get("ok", false)):
			return {
				"ok": false,
				"error": "current CSG oracle failed at N=%d: %s" % [
					deposited_pass,
					String(oracle.get("error", "unknown")),
				],
			}
		result[str(deposited_pass)] = oracle
	var branch_bodies: Array = []
	for body_index in range(TOTAL_DEPOSITED_PASSES - 2):
		branch_bodies.append(bodies[body_index])
	branch_bodies.append(bodies[TOTAL_DEPOSITED_PASSES])
	var branch_oracle: Dictionary = await _build_current_csg_oracle(
		presenter, branch_bodies, "BranchN19"
	)
	if not bool(branch_oracle.get("ok", false)):
		return {
			"ok": false,
			"error": "branch current CSG oracle failed: %s" % String(
				branch_oracle.get("error", "unknown")
			),
		}
	result["branch"] = branch_oracle
	return result


func _build_current_csg_oracle(
	presenter: Node3D, bodies: Array, label: String
) -> Dictionary:
	var combiner := CSGCombiner3D.new()
	combiner.name = "NativeHistoryCurrentCsg%s" % label
	combiner.operation = CSGShape3D.OPERATION_UNION
	combiner.calculate_tangents = false
	_workspace.add_child(combiner)
	for body_index in range(bodies.size()):
		var body := bodies[body_index] as Resource
		if not bool(presenter.call(
			"_append_csg_body_shape",
			combiner,
			body,
			MATERIAL_VARIANT_ID,
			false,
			body_index
		)):
			combiner.queue_free()
			return {"ok": false, "error": "presenter rejected body %d" % body_index}
	await process_frame
	await process_frame
	var baked := combiner.bake_static_mesh()
	combiner.queue_free()
	if baked == null or baked.get_surface_count() <= 0:
		return {"ok": false, "error": "CSG bake returned no surface"}
	var analysis := MeshAnalyzerScript.analyze_mesh(baked)
	if not _strict_topology_passes(analysis):
		return {"ok": false, "error": "CSG bake failed strict topology"}
	return {"ok": true, "analysis": analysis}


func _record_csg_parity(
	label: String,
	deposited_pass: int,
	actual_result: Dictionary,
	oracle: Dictionary
) -> void:
	var actual := _analyze_packet(actual_result)
	var actual_analysis: Dictionary = actual.get("analysis", {}) as Dictionary
	var oracle_analysis: Dictionary = oracle.get("analysis", {}) as Dictionary
	var comparison := MeshAnalyzerScript.compare_surfaces(
		actual_analysis, oracle_analysis
	) if bool(actual.get("ok", false)) else {
		"bidirectional_max_meters": INF,
	}
	var surface_delta := float(comparison.get(
		"bidirectional_max_meters", INF
	))
	var volume_delta := absf(
		float(actual_analysis.get("absolute_volume_cubic_meters", 0.0))
		- float(oracle_analysis.get("absolute_volume_cubic_meters", 0.0))
	)
	var volume_limit := maxf(
		CSG_VOLUME_ABSOLUTE_LIMIT_CUBIC_METERS,
		float(oracle_analysis.get(
			"absolute_volume_cubic_meters", 0.0
		)) * CSG_VOLUME_RELATIVE_LIMIT
	)
	var bounds_delta := _bounds_delta(actual_analysis, oracle_analysis)
	var parity_ok := (
		bool(actual.get("ok", false))
		and bool(oracle.get("ok", false))
		and _strict_topology_passes(actual_analysis)
		and _strict_topology_passes(oracle_analysis)
		and surface_delta <= CSG_SURFACE_DISTANCE_LIMIT_METERS
		and bounds_delta <= CSG_BOUNDS_LIMIT_METERS
		and volume_delta <= volume_limit
	)
	_mark(
		"boundary_packets_match_independent_current_csg",
		parity_ok,
		"current_csg_parity_failed_%s" % label
	)
	_csg_rows.append({
		"label": label,
		"n": deposited_pass,
		"ok": parity_ok,
		"surface_um": surface_delta * 1000000.0,
		"bounds_um": bounds_delta * 1000000.0,
		"volume_delta_m3": volume_delta,
		"volume_limit_m3": volume_limit,
		"native_strict": _strict_topology_passes(actual_analysis),
		"csg_strict": _strict_topology_passes(oracle_analysis),
	})


func _bounds_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for suffix: String in [
		"position_x", "position_y", "position_z", "size_x", "size_y", "size_z"
	]:
		maximum = maxf(maximum, absf(
			float(first.get("aabb_%s" % suffix, INF))
			- float(second.get("aabb_%s" % suffix, -INF))
		))
	return maximum


func _build_full_replay_oracle(
	packets: Array, deposited_pass_count: int
) -> Dictionary:
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null or not _contract_is_available(backend):
		return {"ok": false, "error": "oracle backend is unavailable"}
	var states: Array[Dictionary] = [{
		"packet_digest": "empty",
		"vertex_count": 0,
		"triangle_count": 0,
		"analysis": {},
	}]
	var all_strict := true
	for packet_index in range(deposited_pass_count):
		var packet := packets[packet_index] as Dictionary
		var result := backend.call(
			"reset_mesh" if packet_index == 0 else "add_mesh",
			packet.get("vertices", PackedVector3Array()),
			packet.get("indices", PackedInt32Array())
		) as Dictionary
		if not _mutation_succeeded(result):
			return {
				"ok": false,
				"error": "oracle replay failed at deposited pass %d: %s" % [
					packet_index + 1,
					String(result.get("error_message", "unknown")),
				],
			}
		var analyzed := _analyze_packet(result)
		if not bool(analyzed.get("ok", false)):
			return {
				"ok": false,
				"error": "oracle emitted an invalid packet at deposited pass %d"
					% (packet_index + 1),
			}
		var analysis: Dictionary = analyzed.get("analysis", {}) as Dictionary
		all_strict = all_strict and _strict_topology_passes(analysis)
		states.append({
			"packet_digest": analyzed.get("packet_digest", ""),
			"canonical_geometry_digest": analyzed.get(
				"canonical_geometry_digest", ""
			),
			"vertex_count": analyzed.get("vertex_count", 0),
			"triangle_count": analyzed.get("triangle_count", 0),
			"analysis": analysis,
		})
	return {"ok": true, "strict": all_strict, "states": states}


func _run_empty_sentinel_probe(
	seed_packet: Dictionary, expected_s1: Dictionary
) -> Dictionary:
	var backend := ClassDB.instantiate(&"ForgeV2ManifoldBoolean") as Object
	if backend == null or not _contract_is_available(backend):
		_mark(
			"n_1_undo_reaches_empty_s0_and_redo_restores_s1",
			false,
			"empty_probe_backend_unavailable"
		)
		return {"ok": false, "error": "backend unavailable"}
	var enable_result := backend.call(
		"set_history_window_enabled", true
	) as Dictionary
	if not bool(enable_result.get("ok", false)) \
			or not bool(enable_result.get("history_window_enabled", false)):
		_mark(
			"n_1_undo_reaches_empty_s0_and_redo_restores_s1",
			false,
			"empty_probe_history_opt_in_failed"
		)
		return {"ok": false, "error": "history opt-in failed"}
	var before_reset := _history_info(backend)
	var reset_result := backend.call(
		"reset_mesh",
		seed_packet.get("vertices", PackedVector3Array()),
		seed_packet.get("indices", PackedInt32Array())
	) as Dictionary
	var after_reset := _history_info(backend)
	var reset_ok := (
		_mutation_succeeded(reset_result)
		and bool(after_reset.get("history_window_enabled", false))
		and int(after_reset.get("history_window_capacity", -1))
			== HISTORY_WINDOW_CAPACITY
		and int(after_reset.get("checkpoint_operation_count", -1)) == 0
		and int(after_reset.get("active_tail_cursor", -1)) == 1
		and int(after_reset.get("tail_timeline_count", -1)) == 1
		and int(after_reset.get("redo_count", -1)) == 0
		and int(after_reset.get("retained_state_count", -1)) == 2
		and int(after_reset.get("retained_total_vertices", -1))
			== int(expected_s1.get("vertex_count", -2))
		and int(after_reset.get("retained_total_triangles", -1))
			== int(expected_s1.get("triangle_count", -2))
		and int(after_reset.get("promotion_count", -1)) == 0
		and int(after_reset.get("boolean_count", -1)) == 0
		and int(after_reset.get("export_count", -1)) == 1
		and String(after_reset.get("last_mode", "")) == "reset"
	)
	_mark(
		"n_1_undo_reaches_empty_s0_and_redo_restores_s1",
		reset_ok,
		"empty_probe_reset_failed"
	)
	if not reset_ok:
		return {"ok": false, "phase": "reset"}
	_check_revision_advanced(
		before_reset, after_reset, reset_result, "empty_probe_reset"
	)
	_check_result_matches_history(
		reset_result, after_reset, "empty_probe_reset"
	)
	_record_geometry_match(
		"empty_probe_reset", 1, reset_result, expected_s1
	)
	var reset_digest := _exact_packet_digest(reset_result)
	var retained_vertices := int(expected_s1.get("vertex_count", -1))
	var retained_triangles := int(expected_s1.get("triangle_count", -1))
	var before_undo := after_reset
	var undo_result := backend.call("undo_state") as Dictionary
	var after_undo := _history_info(backend)
	var undo_vertices: PackedVector3Array = undo_result.get(
		"vertices", PackedVector3Array()
	)
	var undo_indices: PackedInt32Array = undo_result.get(
		"indices", PackedInt32Array()
	)
	var undo_sources: PackedInt32Array = undo_result.get(
		"source_original_ids", PackedInt32Array()
	)
	var undo_faces: PackedInt32Array = undo_result.get(
		"source_face_ids", PackedInt32Array()
	)
	var empty_undo_ok := (
		bool(undo_result.get("ok", false))
		and bool(undo_result.get("committed", false))
		and String(undo_result.get("status", "")) == "Empty"
		and String(after_undo.get("status", "")) == "Empty"
		and not bool(undo_result.get("state_initialized", true))
		and int(undo_result.get("output_vertex_count", -1)) == 0
		and int(undo_result.get("output_triangle_count", -1)) == 0
		and undo_vertices.is_empty()
		and undo_indices.is_empty()
		and undo_sources.is_empty()
		and undo_faces.is_empty()
		and int(after_undo.get("checkpoint_operation_count", -1)) == 0
		and int(after_undo.get("active_tail_cursor", -1)) == 0
		and int(after_undo.get("tail_timeline_count", -1)) == 1
		and int(after_undo.get("redo_count", -1)) == 1
		and int(after_undo.get("retained_state_count", -1)) == 2
		and int(after_undo.get("history_window_capacity", -1))
			== HISTORY_WINDOW_CAPACITY
		and int(after_undo.get("retained_total_vertices", -1))
			== retained_vertices
		and int(after_undo.get("retained_total_triangles", -1))
			== retained_triangles
		and int(after_undo.get("boolean_count", -1)) == 0
		and int(after_undo.get("export_count", -1)) == 1
		and int(after_undo.get("promotion_count", -1)) == 0
		and int(after_undo.get("promotion_boolean_delta", -1)) == 0
		and int(after_undo.get("promotion_export_delta", -1)) == 0
		and String(after_undo.get("last_mode", "")) == "undo"
	)
	_mark(
		"n_1_undo_reaches_empty_s0_and_redo_restores_s1",
		empty_undo_ok,
		"n1_undo_did_not_reach_empty_s0"
	)
	_check_revision_advanced(
		before_undo, after_undo, undo_result, "empty_probe_undo"
	)
	_check_result_matches_history(
		undo_result, after_undo, "empty_probe_undo"
	)

	var before_redo := after_undo
	var redo_result := backend.call("redo_state") as Dictionary
	var after_redo := _history_info(backend)
	var redo_digest := _exact_packet_digest(redo_result)
	var packet_digest_equal := (
		not reset_digest.is_empty() and redo_digest == reset_digest
	)
	var redo_ok := (
		_mutation_succeeded(redo_result)
		and packet_digest_equal
		and int(after_redo.get("checkpoint_operation_count", -1)) == 0
		and int(after_redo.get("active_tail_cursor", -1)) == 1
		and int(after_redo.get("tail_timeline_count", -1)) == 1
		and int(after_redo.get("redo_count", -1)) == 0
		and int(after_redo.get("retained_state_count", -1)) == 2
		and int(after_redo.get("history_window_capacity", -1))
			== HISTORY_WINDOW_CAPACITY
		and int(after_redo.get("retained_total_vertices", -1))
			== retained_vertices
		and int(after_redo.get("retained_total_triangles", -1))
			== retained_triangles
		and int(after_redo.get("boolean_count", -1)) == 0
		and int(after_redo.get("export_count", -1)) == 2
		and int(after_redo.get("promotion_count", -1)) == 0
		and String(after_redo.get("last_mode", "")) == "redo"
	)
	_mark(
		"n_1_undo_reaches_empty_s0_and_redo_restores_s1",
		redo_ok,
		"n1_redo_did_not_restore_exact_s1"
	)
	_mark(
		"navigation_packets_match_original_subject_packets_exactly",
		packet_digest_equal,
		"empty_probe_redo_packet_digest_mismatch"
	)
	_check_revision_advanced(
		before_redo, after_redo, redo_result, "empty_probe_redo"
	)
	_check_result_matches_history(
		redo_result, after_redo, "empty_probe_redo"
	)
	_record_geometry_match(
		"empty_probe_redo", 1, redo_result, expected_s1
	)
	_packet_replay_rows.append({
		"label": "empty_probe_redo",
		"n": 1,
		"packet_digest_equal": packet_digest_equal,
		"digest": redo_digest.substr(0, 16),
	})
	return {
		"ok": reset_ok and empty_undo_ok and redo_ok,
		"empty_status": String(undo_result.get("status", "")),
		"empty_export_delta": (
			int(after_undo.get("export_count", -1))
			- int(before_undo.get("export_count", -1))
		),
		"redo_packet_digest_equal": packet_digest_equal,
		"final_revision": int(after_redo.get("revision", -1)),
	}


func _contract_is_available(backend: Object) -> bool:
	if backend == null:
		return false
	for method_name: StringName in [
		&"set_history_window_enabled",
		&"reset_mesh",
		&"add_mesh",
		&"undo_state",
		&"redo_state",
		&"get_history_info",
	]:
		if not backend.has_method(method_name):
			return false
	return true


func _mesh_packet(mesh: ArrayMesh) -> Dictionary:
	if mesh == null or mesh.get_surface_count() != 1:
		return {"ok": false}
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() < Mesh.ARRAY_MAX:
		return {"ok": false}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return {
		"ok": (
			not vertices.is_empty()
			and not indices.is_empty()
			and indices.size() % 3 == 0
		),
		"vertices": vertices,
		"indices": indices,
	}


func _analyze_packet(result: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = result.get(
		"vertices", PackedVector3Array()
	)
	var indices: PackedInt32Array = result.get(
		"indices", PackedInt32Array()
	)
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return {"ok": false}
	for vertex_index: int in indices:
		if vertex_index < 0 or vertex_index >= vertices.size():
			return {"ok": false}
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mesh.get_surface_count() != 1:
		return {"ok": false}
	return {
		"ok": true,
		"packet_digest": var_to_bytes([
			vertices, indices,
		]).hex_encode().sha256_text(),
		"canonical_geometry_digest": _canonical_geometry_digest(
			vertices, indices
		),
		"vertex_count": vertices.size(),
		"triangle_count": indices.size() / 3,
		"analysis": MeshAnalyzerScript.analyze_mesh(mesh),
	}


func _exact_packet_digest(result: Dictionary) -> String:
	var vertices: PackedVector3Array = result.get(
		"vertices", PackedVector3Array()
	)
	var indices: PackedInt32Array = result.get(
		"indices", PackedInt32Array()
	)
	if vertices.is_empty() or indices.is_empty() or indices.size() % 3 != 0:
		return ""
	return var_to_bytes([vertices, indices]).hex_encode().sha256_text()


func _save_subject_packet_digest(
	deposited_pass: int, result: Dictionary
) -> void:
	var digest := _exact_packet_digest(result)
	_subject_packet_digests[deposited_pass] = digest
	_mark(
		"selected_packets_match_independent_full_replay",
		not digest.is_empty(),
		"subject_packet_digest_missing_at_%d" % deposited_pass
	)


func _check_subject_packet_replay(
	label: String,
	deposited_pass: int,
	result: Dictionary,
	phase_gate: String
) -> void:
	var actual_digest := _exact_packet_digest(result)
	var expected_digest := String(_subject_packet_digests.get(
		deposited_pass, "missing"
	))
	var packet_digest_equal := (
		not actual_digest.is_empty() and actual_digest == expected_digest
	)
	_mark(
		"navigation_packets_match_original_subject_packets_exactly",
		packet_digest_equal,
		"subject_packet_digest_mismatch_%s" % label
	)
	_mark(
		phase_gate,
		packet_digest_equal,
		"phase_packet_digest_mismatch_%s" % label
	)
	_packet_replay_rows.append({
		"label": label,
		"n": deposited_pass,
		"packet_digest_equal": packet_digest_equal,
		"digest": actual_digest.substr(0, 16),
	})


func _subject_packet_digest_summary() -> Dictionary:
	var result := {}
	var keys := _subject_packet_digests.keys()
	keys.sort()
	for key: Variant in keys:
		result[str(int(key))] = String(
			_subject_packet_digests.get(key, "")
		).substr(0, 16)
	return result


func _check_revision_advanced(
	before: Dictionary,
	after: Dictionary,
	result: Dictionary,
	label: String
) -> void:
	var before_revision := int(before.get("revision", -2))
	var after_revision := int(after.get("revision", -1))
	var revision_ok := (
		after_revision == before_revision + 1
		and int(after.get("state_revision", -1)) == after_revision
		and int(result.get("previous_revision", -2)) == before_revision
		and int(result.get("revision", -1)) == after_revision
		and int(result.get("state_revision", -1)) == after_revision
	)
	_revision_check_count += 1
	_revision_check_pass_count += int(revision_ok)
	_mark(
		"successful_mutations_increment_revision_by_one",
		revision_ok,
		"revision_delta_changed_%s" % label
	)


func _unavailable_navigation_ok(
	result: Dictionary,
	before: Dictionary,
	after: Dictionary,
	expected_error_code: String
) -> bool:
	var before_revision := int(before.get("revision", -2))
	return (
		not bool(result.get("ok", true))
		and not bool(result.get("committed", true))
		and String(result.get("error_code", "")) == expected_error_code
		and int(result.get("previous_revision", -1)) == before_revision
		and int(result.get("revision", -1)) == before_revision
		and int(result.get("state_revision", -1)) == before_revision
		and _same_history(before, after)
	)


func _record_geometry_match(
	label: String,
	deposited_pass: int,
	actual_result: Dictionary,
	expected_state: Dictionary
) -> void:
	var actual := _analyze_packet(actual_result)
	var expected_analysis: Dictionary = expected_state.get(
		"analysis", {}
	) as Dictionary
	var actual_analysis: Dictionary = actual.get("analysis", {}) as Dictionary
	var packet_digest_equal := (
		String(actual.get("packet_digest", ""))
		== String(expected_state.get("packet_digest", "missing"))
	)
	var canonical_digest_equal := (
		String(actual.get("canonical_geometry_digest", ""))
		== String(expected_state.get(
			"canonical_geometry_digest", "missing"
		))
	)
	var analyzer_digests_equal := (
		String(actual_analysis.get("geometry_signature_unoriented", ""))
			== String(expected_analysis.get(
				"geometry_signature_unoriented", "missing"
			))
		and String(actual_analysis.get("geometry_signature_oriented", ""))
			== String(expected_analysis.get(
				"geometry_signature_oriented", "missing"
			))
	)
	var counts_equal := (
		int(actual.get("vertex_count", -1))
			== int(expected_state.get("vertex_count", -2))
		and int(actual.get("triangle_count", -1))
			== int(expected_state.get("triangle_count", -2))
		and int(actual_analysis.get("strict_welded_vertex_count", -1))
			== int(expected_analysis.get("strict_welded_vertex_count", -2))
		and int(actual_analysis.get("strict_triangle_count", -1))
			== int(expected_analysis.get("strict_triangle_count", -2))
	)
	var geometry_ok := (
		bool(actual.get("ok", false))
		and canonical_digest_equal
		and analyzer_digests_equal
		and counts_equal
		and _strict_topology_passes(actual_analysis)
		and _strict_topology_passes(expected_analysis)
	)
	_mark(
		"selected_packets_match_independent_full_replay",
		geometry_ok,
		"geometry_mismatch_%s" % label
	)
	_geometry_rows.append({
		"label": label,
		"n": deposited_pass,
		"ok": geometry_ok,
		"layout": packet_digest_equal,
		"canonical": canonical_digest_equal,
		"analyzer": analyzer_digests_equal,
		"strict": _strict_topology_passes(actual_analysis),
		"digest": String(actual.get(
			"canonical_geometry_digest", ""
		)).substr(0, 16),
	})


func _canonical_geometry_digest(
	vertices: PackedVector3Array, indices: PackedInt32Array
) -> String:
	var triangle_keys: Array[String] = []
	for triangle_index in range(indices.size() / 3):
		var first := var_to_bytes(vertices[
			indices[triangle_index * 3]
		]).hex_encode()
		var second := var_to_bytes(vertices[
			indices[triangle_index * 3 + 1]
		]).hex_encode()
		var third := var_to_bytes(vertices[
			indices[triangle_index * 3 + 2]
		]).hex_encode()
		var rotations: Array[String] = [
			"%s;%s;%s" % [first, second, third],
			"%s;%s;%s" % [second, third, first],
			"%s;%s;%s" % [third, first, second],
		]
		rotations.sort()
		triangle_keys.append(rotations[0])
	triangle_keys.sort()
	return "\n".join(PackedStringArray(triangle_keys)).sha256_text()


func _strict_topology_passes(analysis: Dictionary) -> bool:
	return (
		int(analysis.get("triangle_count", 0)) > 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
		and int(analysis.get("degenerate_triangle_count", -1)) == 0
		and bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", -1)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
	)


func _check_linear_window(
	info: Dictionary,
	deposited_pass: int,
	oracle_states: Array,
	label: String
) -> void:
	var checkpoint := maxi(deposited_pass - HISTORY_WINDOW_CAPACITY, 0)
	var tail_count := mini(deposited_pass, HISTORY_WINDOW_CAPACITY)
	var gate := (
		"n_le_5_has_checkpoint_0_and_tail_n"
		if deposited_pass <= HISTORY_WINDOW_CAPACITY
		else "n_6_promotes_to_checkpoint_1_and_tail_5"
		if deposited_pass == HISTORY_WINDOW_CAPACITY + 1
		else "n_20_has_checkpoint_15_tail_5_and_6_states"
	)
	_check_history_shape(
		info,
		checkpoint,
		tail_count,
		tail_count,
		0,
		tail_count + 1,
		_retained_totals(oracle_states, checkpoint, deposited_pass),
		label,
		gate
	)
	_mark(
		gate,
		int(info.get("promotion_count", -1)) == checkpoint,
		"promotion_count_changed_%s" % label
	)


func _check_history_shape(
	info: Dictionary,
	checkpoint: int,
	cursor: int,
	timeline_count: int,
	redo_count: int,
	retained_count: int,
	retained_totals: Dictionary,
	label: String,
	gate: String
) -> void:
	var shape_ok := (
		bool(info.get("ok", false))
		and bool(info.get("history_window_enabled", false))
		and int(info.get("history_window_capacity", -1))
			== HISTORY_WINDOW_CAPACITY
		and int(info.get("checkpoint_operation_count", -1)) == checkpoint
		and int(info.get("active_tail_cursor", -1)) == cursor
		and int(info.get("tail_timeline_count", -1)) == timeline_count
		and int(info.get("redo_count", -1)) == redo_count
		and int(info.get("retained_state_count", -1)) == retained_count
		and bool(info.get("state_initialized", false))
	)
	_mark(gate, shape_ok, "history_shape_changed_%s" % label)
	var totals_ok := (
		int(info.get("retained_total_vertices", -1))
			== int(retained_totals.get("vertices", -2))
		and int(info.get("retained_total_triangles", -1))
			== int(retained_totals.get("triangles", -2))
	)
	_mark(
		"retained_storage_matches_the_six_state_window",
		totals_ok,
		"retained_totals_changed_%s" % label
	)


func _check_navigation_counters(
	before: Dictionary,
	after: Dictionary,
	label: String,
	gate: String
) -> void:
	var ok := (
		int(after.get("boolean_count", -1))
			== int(before.get("boolean_count", -2))
		and int(after.get("export_count", -1))
			== int(before.get("export_count", -2)) + 1
		and int(after.get("promotion_count", -1))
			== int(before.get("promotion_count", -2))
		and int(after.get("promotion_boolean_delta", -1)) == 0
		and int(after.get("promotion_export_delta", -1)) == 0
	)
	_mark(gate, ok, "navigation_counter_changed_%s" % label)


func _check_result_matches_history(
	result: Dictionary, info: Dictionary, label: String
) -> void:
	var matches := true
	for key: String in HISTORY_KEYS:
		matches = matches and result.get(key, null) == info.get(key, null)
	_mark(
		"native_contract_is_available",
		matches,
		"result_history_metadata_mismatch_%s" % label
	)


func _retained_totals(
	states: Array, first_state: int, last_state: int
) -> Dictionary:
	var vertices := 0
	var triangles := 0
	if first_state < 0 or last_state >= states.size() or first_state > last_state:
		return {"vertices": -1, "triangles": -1}
	for state_index in range(first_state, last_state + 1):
		var state := states[state_index] as Dictionary
		vertices += int(state.get("vertex_count", 0))
		triangles += int(state.get("triangle_count", 0))
	return {"vertices": vertices, "triangles": triangles}


func _same_history(first: Dictionary, second: Dictionary) -> bool:
	for key: String in HISTORY_KEYS:
		if first.get(key, null) != second.get(key, null):
			return false
	return true


func _history_info(backend: Object) -> Dictionary:
	var value: Variant = backend.call("get_history_info")
	return value as Dictionary if value is Dictionary else {}


func _mutation_succeeded(result: Dictionary) -> bool:
	return (
		bool(result.get("ok", false))
		and bool(result.get("committed", false))
		and String(result.get("status", "")) == "NoError"
		and bool(result.get("state_initialized", false))
	)


func _deposit_row(
	deposited_pass: int, history: Dictionary, result: Dictionary
) -> Dictionary:
	return {
		"n": deposited_pass,
		"mode": String(history.get("last_mode", "")),
		"checkpoint": int(history.get("checkpoint_operation_count", -1)),
		"cursor": int(history.get("active_tail_cursor", -1)),
		"tail": int(history.get("tail_timeline_count", -1)),
		"states": int(history.get("retained_state_count", -1)),
		"promotions": int(history.get("promotion_count", -1)),
		"booleans": int(history.get("boolean_count", -1)),
		"exports": int(history.get("export_count", -1)),
		"triangles": int(result.get("output_triangle_count", -1)),
	}


func _navigation_row(
	phase: String, step: int, deposited_pass: int, history: Dictionary
) -> Dictionary:
	return {
		"phase": phase,
		"step": step,
		"n": deposited_pass,
		"cursor": int(history.get("active_tail_cursor", -1)),
		"redo": int(history.get("redo_count", -1)),
		"exports": int(history.get("export_count", -1)),
	}


func _history_summary(info: Dictionary) -> Dictionary:
	var summary := {}
	for key: String in HISTORY_KEYS:
		summary[key] = info.get(key, null)
	return summary


func _mark(gate: String, condition: bool, error: String) -> void:
	if condition:
		return
	_gate_state[gate] = false
	if _errors.size() < 64 and not _errors.has(error):
		_errors.append(error)


func _finish_failure(message: String) -> void:
	if _errors.size() < 64 and not _errors.has(message):
		_errors.append(message)
	_report.merge({
		"outcome": "fail",
		"failure_reason": message,
		"errors": _errors,
		"gates": _gate_state,
	}, true)
	_write_report()
	push_error("FORGE_V2_NATIVE_HISTORY_WINDOW: %s" % message)
	quit(1)


func _write_report() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report))
