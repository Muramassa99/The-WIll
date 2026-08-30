extends SceneTree

const ForgeV2ActionHistoryScript = preload(
	"res://runtime/forge_v2/forge_v2_action_history.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_action_history_2026-08-30.txt"
)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_verify_default_unbounded_order()
	_verify_peek_confirm_and_redo_branching()
	_verify_held_undo_redo_batch()
	_verify_checkpoint_prefix_pruning()
	_verify_stale_confirmation_guard()
	_verify_indexed_record_surgery()
	_verify_handle_tail_collapse()
	_verify_tail_truncation_and_clear()
	_verify_safe_record_copying()
	_verify_record_validation()
	_write_result([
		"ok=true",
		"default_action_count_unbounded=true",
		"optional_bounded_capacity_supported=true",
		"chronological_redo=true",
		"held_undo_is_one_redo_batch=true",
		"checkpoint_prefix_pruning=true",
		"new_action_clears_redo=true",
		"failed_replay_preserves_stacks=true",
		"stale_confirmation_rejected=true",
		"indexed_replacement_is_order_stable=true",
		"indexed_removal_is_order_stable=true",
		"indexed_surgery_redo_policy_is_explicit=true",
		"indexed_surgery_copy_and_confirmation_safe=true",
		"handle_tail_collapse=true",
		"tail_truncation=true",
		"safe_nested_container_copy=true",
		"live_object_resource_identity_preserved=true",
		"status_summary=true",
	])
	quit(0)


func _verify_default_unbounded_order() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	_require(history.get_capacity() == 0, "default action journal was not unbounded")
	for action_number in range(1, 13):
		_require(
			history.push_action(
				StringName("action_%d" % action_number),
				"Action %d" % action_number,
				{"number": action_number}
			),
			"valid action %d was rejected" % action_number
		)
	_require(history.get_undo_count() == 12, "unbounded journal discarded actions")
	_require(history.get_redo_count() == 0, "fresh pushes created redo entries")
	_require(
		history.get_undo_labels()
		== PackedStringArray([
			"Action 1", "Action 2", "Action 3", "Action 4", "Action 5", "Action 6",
			"Action 7", "Action 8", "Action 9", "Action 10", "Action 11", "Action 12",
		]),
		"unbounded journal did not preserve chronological undo order"
	)
	var summary: Dictionary = history.get_status_summary()
	_require(int(summary.get("capacity", -1)) == 0, "summary lost unbounded capacity")
	_require(int(summary.get("undo_count", -1)) == 12, "summary lost undo count")
	_require(int(summary.get("redo_count", -1)) == 0, "summary lost redo count")
	_require(bool(summary.get("can_undo", false)), "summary lost can-undo state")
	_require(not bool(summary.get("can_redo", true)), "summary invented redo state")
	_require(String(summary.get("undo_label", "")) == "Action 12", "summary lost next undo label")
	_require(
		not summary.has("undo_labels") and not summary.has("redo_labels"),
		"hot status summary enumerated the complete action journal"
	)

	var small_history = ForgeV2ActionHistoryScript.new(2)
	for action_number in range(1, 4):
		small_history.push_action(
			StringName("small_%d" % action_number),
			"Small %d" % action_number
		)
	_require(small_history.get_capacity() == 2, "custom capacity was ignored")
	_require(
		small_history.get_undo_labels() == PackedStringArray(["Small 2", "Small 3"]),
		"custom capacity did not evict the oldest action"
	)


func _verify_held_undo_redo_batch() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	for label in ["A", "B", "C", "D"]:
		history.push_action(StringName(label.to_lower()), label)
	_require(history.begin_undo_batch(), "held Undo batch did not begin")
	for expected_label in ["D", "C", "B"]:
		_require(
			String(history.peek_undo().get("label", "")) == expected_label,
			"held Undo selected the wrong action"
		)
		_require(history.confirm_undo(), "held Undo replay was not confirmed")
	_require(not history.can_redo(), "Redo escaped before held Undo release")
	_require(history.end_undo_batch(), "held Undo batch did not finish")
	_require(history.get_redo_count() == 1, "held Undo created more than one Redo gesture")
	var redo_batch := history.peek_redo_batch() as Array[Dictionary]
	_require(
		_collect_record_labels(redo_batch) == PackedStringArray(["B", "C", "D"]),
		"held Undo Redo batch lost chronological replay order"
	)
	_require(history.confirm_redo_batch(), "held Undo batch could not Redo")
	_require(
		history.get_undo_labels() == PackedStringArray(["A", "B", "C", "D"]),
		"one Redo did not restore the held Undo gesture"
	)


func _verify_checkpoint_prefix_pruning() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	for label in ["Dot 1", "Dot 2", "Generate 1", "Dot 3", "Generate 2"]:
		history.push_action(StringName(label.to_snake_case()), label)
	_require(
		not history.discard_undo_prefix_through(-1),
		"negative checkpoint boundary was accepted"
	)
	_require(
		history.discard_undo_prefix_through(2),
		"valid checkpoint prefix was not discarded"
	)
	_require(
		history.get_undo_labels() == PackedStringArray(["Dot 3", "Generate 2"]),
		"checkpoint prune did not preserve the newer action epoch"
	)
	var peeked := history.peek_undo()
	_require(not peeked.is_empty(), "checkpoint fixture lost its undo tail")
	_require(
		history.discard_undo_prefix_through(0),
		"second checkpoint prune failed"
	)
	_require(
		not history.confirm_undo(),
		"checkpoint prune retained a stale replay confirmation"
	)
	_require(
		history.get_undo_labels() == PackedStringArray(["Generate 2"]),
		"second checkpoint prune crossed its requested boundary"
	)


func _verify_peek_confirm_and_redo_branching() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	for label in ["A", "B", "C"]:
		history.push_action(StringName(label.to_lower()), label, {"label": label})

	var failed_replay_record: Dictionary = history.peek_undo()
	_require(String(failed_replay_record.get("label", "")) == "C", "peek undo did not select latest action")
	# Simulate replay failure by cancelling rather than confirming.
	history.cancel_pending_confirmation()
	_require(history.get_undo_count() == 3, "failed undo replay changed undo count")
	_require(history.get_redo_count() == 0, "failed undo replay changed redo count")
	_require(not history.confirm_undo(), "undo confirmed without a current successful replay")

	_require(String(history.peek_undo().get("label", "")) == "C", "second undo peek drifted")
	_require(history.confirm_undo(), "confirmed undo was rejected")
	_require(String(history.peek_undo().get("label", "")) == "B", "undo did not expose prior action")
	_require(history.confirm_undo(), "second confirmed undo was rejected")
	_require(
		history.get_redo_labels() == PackedStringArray(["B", "C"]),
		"redo records were not exposed in replay order"
	)
	_require(String(history.get_redo_label()) == "B", "next redo label was not chronological")

	_require(String(history.peek_redo().get("label", "")) == "B", "redo peek selected wrong action")
	_require(history.confirm_redo(), "confirmed redo was rejected")
	_require(
		history.get_undo_labels() == PackedStringArray(["A", "B"]),
		"redo did not restore chronological undo order"
	)
	_require(history.get_redo_labels() == PackedStringArray(["C"]), "redo tail was corrupted")

	history.push_action(&"d", "D")
	_require(history.get_redo_count() == 0, "new action did not clear redo")
	_require(
		history.get_undo_labels() == PackedStringArray(["A", "B", "D"]),
		"new branch did not retain valid undo chronology"
	)


func _verify_stale_confirmation_guard() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	history.push_action(&"a", "A")
	history.peek_undo()
	history.push_action(&"b", "B")
	_require(not history.confirm_undo(), "stale undo confirmation moved a newer record")
	_require(
		history.get_undo_labels() == PackedStringArray(["A", "B"]),
		"stale undo confirmation corrupted the journal"
	)

	history.peek_undo()
	history.confirm_undo()
	history.peek_redo()
	history.truncate_undo_since(0)
	_require(not history.confirm_redo(), "stale redo confirmation survived history surgery")
	_require(history.get_undo_count() == 0, "history surgery did not retain requested prefix")
	_require(history.get_redo_count() == 0, "history surgery did not clear stale redo")


func _verify_indexed_record_surgery() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	for label in ["A", "B", "C", "D"]:
		history.push_action(StringName(label.to_lower()), label, {"label": label})
	_require(String(history.peek_undo().get("label", "")) == "D", "indexed fixture peek drifted")
	_require(history.confirm_undo(), "indexed fixture could not create redo branch")
	_require(history.get_redo_labels() == PackedStringArray(["D"]), "indexed fixture redo branch drifted")

	var live_resource := Resource.new()
	var replacement_payload := {
		"nested": {"values": [1, 2, 3]},
		"live_resource": live_resource,
	}
	history.peek_undo()
	_require(
		history.replace_undo_record_at(1, {
			"kind": &"finalized_b",
			"label": "B Finalized",
			"payload": replacement_payload,
		}),
		"valid indexed replacement was rejected"
	)
	_require(not history.confirm_undo(), "indexed replacement retained a stale confirmation")
	_require(
		history.get_undo_labels() == PackedStringArray(["A", "B Finalized", "C"]),
		"indexed replacement reordered neighboring undo records"
	)
	_require(
		history.get_redo_labels() == PackedStringArray(["D"]),
		"indexed replacement cleared redo without an explicit request"
	)
	(replacement_payload["nested"] as Dictionary)["values"] = [99]
	var stored_replacement := history.get_undo_records()[1] as Dictionary
	var stored_payload := stored_replacement.get("payload", {}) as Dictionary
	_require(
		((stored_payload.get("nested", {}) as Dictionary).get("values", []))
		== [1, 2, 3],
		"indexed replacement retained caller-owned nested containers"
	)
	_require(
		stored_payload.get("live_resource") == live_resource,
		"indexed replacement cloned or lost a live Resource"
	)

	# A rejected mutation must not invalidate an otherwise current replay peek.
	_require(String(history.peek_undo().get("label", "")) == "C", "replacement changed the undo tail")
	_require(
		not history.replace_undo_record_at(history.get_undo_count(), {
			"kind": &"invalid_index",
			"label": "Invalid Index",
			"payload": {},
		}),
		"out-of-range indexed replacement was accepted"
	)
	_require(history.confirm_undo(), "rejected replacement invalidated a valid confirmation")
	_require(
		history.get_redo_labels() == PackedStringArray(["C", "D"]),
		"confirmation after rejected replacement corrupted redo chronology"
	)

	_require(String(history.peek_redo().get("label", "")) == "C", "redo fixture drifted before removal")
	_require(history.confirm_redo(), "redo fixture could not restore removal neighbor")
	history.peek_undo()
	_require(
		history.remove_undo_record_at(1),
		"valid indexed removal was rejected"
	)
	_require(not history.confirm_undo(), "indexed removal retained a stale confirmation")
	_require(
		history.get_undo_labels() == PackedStringArray(["A", "C"]),
		"indexed removal reordered its surviving neighbors"
	)
	_require(
		history.get_redo_labels() == PackedStringArray(["D"]),
		"indexed removal cleared redo without an explicit request"
	)
	history.peek_undo()
	_require(not history.remove_undo_record_at(-1), "negative indexed removal was accepted")
	_require(history.confirm_undo(), "rejected removal invalidated a valid confirmation")

	_require(
		history.replace_undo_record_at(0, {
			"kind": &"branch_rewrite",
			"label": "Branch Rewrite",
			"payload": {},
		}, true),
		"explicit redo-clearing replacement was rejected"
	)
	_require(history.get_redo_count() == 0, "explicit replacement did not clear redo")

	var removal_history = ForgeV2ActionHistoryScript.new()
	removal_history.push_action(&"a", "A")
	removal_history.push_action(&"b", "B")
	removal_history.peek_undo()
	removal_history.confirm_undo()
	_require(
		removal_history.remove_undo_record_at(0, true),
		"explicit redo-clearing removal was rejected"
	)
	_require(
		removal_history.get_undo_count() == 0
		and removal_history.get_redo_count() == 0,
		"explicit removal did not clear redo"
	)


func _verify_handle_tail_collapse() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	history.push_action(&"seed", "Seed")
	history.push_action(&"stroke", "Stroke")
	var transaction_index: int = history.get_undo_count()
	history.push_action(&"handle_point", "Move Handle Point 1")
	history.push_action(&"handle_point", "Move Handle Point 2")
	_require(
		history.collapse_undo_since(transaction_index, {
			"kind": &"replace_handle",
			"label": "Replace Handle",
			"payload": {
				"before_id": &"handle_old",
				"after_id": &"handle_new",
			},
		}),
		"valid handle transaction tail was not collapsed"
	)
	_require(
		history.get_undo_labels() == PackedStringArray(["Seed", "Stroke", "Replace Handle"]),
		"handle transaction was not one atomic chronological action"
	)
	var replacement: Dictionary = history.peek_undo()
	_require(StringName(replacement.get("kind")) == &"replace_handle", "collapsed record lost kind")
	_require(
		StringName((replacement.get("payload", {}) as Dictionary).get("before_id"))
		== &"handle_old",
		"collapsed record lost payload"
	)
	_require(
		not history.collapse_undo_since(-1, replacement),
		"negative collapse index was accepted"
	)
	_require(
		not history.collapse_undo_since(history.get_undo_count() + 1, replacement),
		"out-of-range collapse index was accepted"
	)


func _verify_tail_truncation_and_clear() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	for label in ["A", "B", "C"]:
		history.push_action(StringName(label.to_lower()), label)
	_require(history.truncate_undo_since(1), "valid truncate index was rejected")
	_require(history.get_undo_labels() == PackedStringArray(["A"]), "truncate retained discarded tail")
	_require(not history.truncate_undo_since(2), "invalid truncate index was accepted")
	history.clear()
	_require(not history.can_undo() and not history.can_redo(), "clear retained history")
	_require(history.peek_undo().is_empty(), "empty history returned an undo record")
	_require(history.peek_redo().is_empty(), "empty history returned a redo record")
	_require(history.get_undo_label().is_empty(), "empty history returned an undo label")
	_require(history.get_redo_label().is_empty(), "empty history returned a redo label")


func _verify_safe_record_copying() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	var live_object := RefCounted.new()
	var live_resource := Resource.new()
	var source_payload := {
		"nested": {
			"values": [1, 2, 3],
		},
		"live_object": live_object,
		"live_resource": live_resource,
	}
	history.push_action(&"copy_test", "Copy Test", source_payload)
	(source_payload["nested"] as Dictionary)["values"] = [99]

	var first_peek: Dictionary = history.peek_undo()
	var first_payload: Dictionary = first_peek.get("payload", {}) as Dictionary
	var first_nested: Dictionary = first_payload.get("nested", {}) as Dictionary
	_require(first_nested.get("values", []) == [1, 2, 3], "source mutation leaked into stored record")
	_require(first_payload.get("live_object") == live_object, "live Object was cloned or lost")
	_require(first_payload.get("live_resource") == live_resource, "live Resource was cloned or lost")

	first_nested["values"] = [77]
	first_payload["new_key"] = true
	var second_peek: Dictionary = history.peek_undo()
	var second_payload: Dictionary = second_peek.get("payload", {}) as Dictionary
	_require(
		((second_payload.get("nested", {}) as Dictionary).get("values", [])) == [1, 2, 3],
		"returned record mutation leaked into stored nested containers"
	)
	_require(not second_payload.has("new_key"), "returned payload shared its Dictionary")
	_require(second_payload.get("live_object") == live_object, "Object identity changed between copies")
	_require(second_payload.get("live_resource") == live_resource, "Resource identity changed between copies")


func _verify_record_validation() -> void:
	var history = ForgeV2ActionHistoryScript.new()
	_require(not history.push_record({}), "empty record was accepted")
	_require(
		not history.push_record({"kind": &"bad", "label": "Bad", "payload": []}),
		"non-Dictionary payload was accepted"
	)
	_require(
		not history.push_record({"kind": StringName(), "label": "Bad", "payload": {}}),
		"empty kind was accepted"
	)
	_require(history.get_undo_count() == 0, "invalid records mutated history")


func _collect_record_labels(records: Array[Dictionary]) -> PackedStringArray:
	var labels := PackedStringArray()
	for record: Dictionary in records:
		labels.append(String(record.get("label", "")))
	return labels


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
