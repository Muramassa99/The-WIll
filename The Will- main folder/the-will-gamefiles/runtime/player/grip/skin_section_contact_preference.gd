extends RefCounted

## Attraction metadata only. Source topology joins contours; distance never joins
## unrelated skin. Missing anatomy/topology leaves the existing contact neutral.
const Slicer = preload("res://runtime/player/grip/weighted_skin_plane_slicer.gd")
const EPS_M: float = Slicer.EPSILON_M
const WEIGHT_EPS := 0.0000001
const PEAKS := [20.0, 50.0, 80.0]
const SPREAD := 25.0
const POLICY := &"source_topology_ordered_positive_dominant_influence_crossings"


## Render seams can split one original skin vertex into several array entries.
## Alias only byte-identical reference XYZ AND the complete original skin tuple.
## These IDs are connectivity hints for preference; mesh/source IDs stay intact.
static func build_vertex_aliases(vertices: PackedVector3Array, bind_ids: PackedInt32Array,
		bind_weights: PackedFloat32Array, influences: int) -> PackedInt32Array:
	var aliases := PackedInt32Array()
	if influences <= 0 or bind_ids.size() != vertices.size() * influences or bind_weights.size() != bind_ids.size(): return aliases
	var first_by_signature := {}
	for vertex: int in vertices.size():
		if not vertices[vertex].is_finite(): return PackedInt32Array()
		var first: int = vertex * influences
		for offset: int in range(first, first + influences):
			if bind_ids[offset] < 0 or not is_finite(bind_weights[offset]) or bind_weights[offset] < 0.0: return PackedInt32Array()
		var signature: String = var_to_bytes([vertices[vertex], bind_ids.slice(first, first + influences),
			bind_weights.slice(first, first + influences)]).hex_encode()
		if not first_by_signature.has(signature): first_by_signature[signature] = vertex
		aliases.append(first_by_signature[signature])
	return aliases


func annotate(segments: Array, hand_weights: PackedFloat64Array, terminal_start_m: Vector2,
		terminal_tip_m: Vector2, origin_id: StringName, aliases: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var eligible := 0
	for value: Variant in segments:
		if value is Dictionary:
			value.erase("location_bias")
			if int(value.get("section_owner", -1)) in [0, 1, 2]: eligible += 1
	var report := {"valid": true, "mapped_segments": 0, "eligible_segments": eligible,
		"neutral_segments": eligible, "reason": "unavailable_contour", "origin_id": origin_id,
		"physical_contact_changed": false, "boundary_policy": POLICY}
	if origin_id == &"" or not terminal_start_m.is_finite() or not terminal_tip_m.is_finite(): return report
	var axis := terminal_tip_m - terminal_start_m
	if axis.length() <= EPS_M: return report
	axis = axis.normalized()
	report["terminal_axis"] = [float(axis.x), float(axis.y)]
	report["terminal_start_m"] = [float(terminal_start_m.x), float(terminal_start_m.y)]
	report["terminal_tip_m"] = [float(terminal_tip_m.x), float(terminal_tip_m.y)]
	var graph := _graph(segments, hand_weights, origin_id, aliases)
	var nodes: Dictionary = graph.nodes
	var tip := ""
	var projection := -INF
	var tied := false
	var tip_candidates: Array = []
	for key: String in nodes:
		var node: Dictionary = nodes[key]
		var distal := false
		for index: int in node.edges:
			if int(segments[index].get("section_owner", -1)) == 2: distal = true
		if not distal: continue
		var candidate: float = (node.point - terminal_start_m).dot(axis)
		var candidate_report := _node_report(key, nodes)
		candidate_report["projection_m"] = candidate
		tip_candidates.append(candidate_report)
		if candidate > projection + EPS_M:
			projection = candidate; tip = key; tied = false
		elif absf(candidate - projection) <= EPS_M:
			tied = true
	tip_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.projection_m > b.projection_m)
	report["distal_candidates"] = tip_candidates.slice(0, mini(6, tip_candidates.size()))
	if tip.is_empty() or tied:
		report.reason = "missing_or_ambiguous_distal_tip"; return report
	if nodes[tip].bad or nodes[tip].edges.size() != 2:
		report.reason = "ambiguous_tip_topology"; return report
	var branches: Array = []
	for index: int in nodes[tip].edges:
		var branch := _walk(nodes, graph.endpoints, segments, tip, index)
		if not branch.valid:
			report.reason = branch.reason
			report["walk_detail"] = branch.get("detail", {})
			return report
		branches.append(branch)
	var first_edges := {}
	for piece: Dictionary in branches[0].pieces: first_edges[piece.index] = true
	for piece: Dictionary in branches[1].pieces:
		if first_edges.has(piece.index):
			report.reason = "contour_branches_rejoin_before_palm"; return report
	var common_lengths: Array = []
	for section: int in 3:
		common_lengths.append(0.5 * (branches[0].lengths[section] + branches[1].lengths[section]))
	for branch: Dictionary in branches:
		for piece: Dictionary in branch.pieces:
			var edge: Dictionary = segments[piece.index]
			var owner: int = int(edge.get("section_owner", -1))
			if owner < 0 or owner > 2: continue
			var proximal: float = branch.boundaries[2 - owner]
			var distal: float = 0.0 if owner == 2 else branch.boundaries[1 - owner]
			if minf(piece.a_distance, piece.b_distance) < distal - EPS_M or maxf(piece.a_distance, piece.b_distance) > proximal + EPS_M: continue
			var length_m: float = proximal - distal
			edge["location_bias"] = {"a_percent": 100.0 * clampf((proximal - piece.a_distance) / length_m, 0.0, 1.0),
				"b_percent": 100.0 * clampf((proximal - piece.b_distance) / length_m, 0.0, 1.0),
				"section_length_m": common_lengths[owner], "branch_length_m": length_m,
				"origin_id": origin_id, "boundary_policy": POLICY,
				"percent_units": &"percentage_points_0_to_100",
				"measurement": &"current_slice_contour_arclength_proximal_zero_distal_one_hundred"}
			report.mapped_segments += 1
	report.neutral_segments = eligible - report.mapped_segments
	report.reason = "mapped" if report.mapped_segments > 0 else "no_consistent_owned_edges"
	report["section_lengths_m"] = common_lengths
	report["distal_tip_source_key"] = tip
	return report


## Discrete attraction ranking, not a differentiated motion objective. Caller
## freezes the selected source edge during its ordinary contact-distance solve.
## Strength is supplied by the owning rule; spread does not imply strength.
func rank(edge: Dictionary, witness: Dictionary, section: int, clearance_m: float,
		strength_fraction: float) -> Dictionary:
	var residual: float = float(witness.get("signed_clearance_m", INF)) - clearance_m
	var result := {"score_m2": residual * residual, "residual_m": residual,
		"biased": false, "percent": -1.0, "bell": 0.0, "strength_fraction": strength_fraction,
		"section_length_m": 0.0, "credit_m2": 0.0}
	if section < 1 or section > 3 or int(edge.get("section_owner", -1)) != section - 1: return result
	if not is_finite(strength_fraction) or strength_fraction < 0.0 or not is_finite(residual): return result
	var metadata: Dictionary = edge.get("location_bias", {})
	var t: float = float(witness.get("skin_segment_t", -1.0))
	if metadata.is_empty() or metadata.get("origin_id") != edge.get("origin_id") or not is_finite(t) or t < 0.0 or t > 1.0: return result
	var length_m: float = float(metadata.get("section_length_m", 0.0))
	var a: float = float(metadata.get("a_percent", -1.0))
	var b: float = float(metadata.get("b_percent", -1.0))
	if not is_finite(length_m) or length_m <= EPS_M or not is_finite(a) or not is_finite(b) or a < 0.0 or a > 100.0 or b < 0.0 or b > 100.0: return result
	var percent: float = lerpf(a, b, t)
	var bell := exp(-0.5 * pow((percent - float(PEAKS[section - 1])) / SPREAD, 2.0))
	var credit := pow(strength_fraction * length_m, 2.0) * bell
	result.merge({"score_m2": residual * residual - credit, "biased": strength_fraction > 0.0,
		"percent": percent, "bell": bell, "section_length_m": length_m, "credit_m2": credit}, true)
	return result


func _graph(segments: Array, hand_weights: PackedFloat64Array, origin_id: StringName, aliases: PackedInt32Array) -> Dictionary:
	var nodes := {}
	var endpoints := {}
	for index: int in segments.size():
		if not segments[index] is Dictionary: continue
		var edge: Dictionary = segments[index]
		var keys: Array = []
		for end: String in ["a", "b"]:
			var source: Dictionary = edge.get(end + "_source", {})
			var key: String = _topology_key(source, aliases)
			if key.is_empty(): keys.append(""); continue
			keys.append(key)
			var point: Vector2 = edge.get(end, Vector2(INF, INF))
			var selected: Vector3 = edge.get(end + "_selected_weights", Vector3(INF, INF, INF))
			var hand: float = _hand_weight(source, hand_weights)
			var weights := Vector4(selected.x, selected.y, selected.z, hand)
			var bad: bool = edge.get("origin_id") != origin_id or edge.get("coplanar", false) or source.get("coplanar", false) or source.get("topology_ambiguous", false) or not point.is_finite() or not weights.is_finite()
			if not nodes.has(key): nodes[key] = {"point": point, "weights": weights, "edges": [], "bad": bad}
			var node: Dictionary = nodes[key]
			node.bad = node.bad or bad or (point - node.point).length() > EPS_M or (weights - node.weights).length() > WEIGHT_EPS
			node.edges.append(index)
		endpoints[index] = keys
		if keys.size() != 2 or keys[0].is_empty() or keys[1].is_empty() or keys[0] == keys[1]:
			for key: String in keys:
				if nodes.has(key): nodes[key].bad = true
	return {"nodes": nodes, "endpoints": endpoints}


func _topology_key(source: Dictionary, aliases: PackedInt32Array) -> String:
	var original: String = str(source.get("topology_key", ""))
	if aliases.is_empty(): return original
	var ids: Variant = source.get("vertex_ids", [])
	if not ids is PackedInt32Array and not ids is Array: return ""
	if ids.size() < 1 or ids.size() > 2: return ""
	for vertex: int in ids:
		if vertex < 0 or vertex >= aliases.size() or aliases[vertex] < 0 or aliases[vertex] > vertex: return ""
	if ids.size() == 1: return "v:%d" % aliases[ids[0]]
	var first: int = aliases[ids[0]]
	var last: int = aliases[ids[1]]
	if first == last: return ""
	return "e:%d:%d" % [mini(first, last), maxi(first, last)]


func _hand_weight(source: Dictionary, weights: PackedFloat64Array) -> float:
	var ids: Variant = source.get("vertex_ids", [])
	if not ids is PackedInt32Array and not ids is Array: return NAN
	if ids.size() < 1 or ids.size() > 2: return NAN
	for vertex: int in ids:
		if vertex < 0 or vertex >= weights.size() or not is_finite(weights[vertex]) or weights[vertex] < 0.0: return NAN
	if ids.size() == 1:
		if source.get("kind") != "vertex" or source.get("topology_key") != "v:%d" % ids[0]: return NAN
		return weights[ids[0]]
	var t: float = float(source.get("t", -1.0))
	if source.get("kind") != "edge" or ids[0] >= ids[1] or source.get("topology_key") != "e:%d:%d" % [ids[0], ids[1]] or not is_finite(t) or t < 0.0 or t > 1.0: return NAN
	return lerpf(weights[ids[0]], weights[ids[1]], t)


func _walk(nodes: Dictionary, endpoints: Dictionary, segments: Array, tip: String, first_edge: int) -> Dictionary:
	var current := tip
	var index := first_edge
	var distance := 0.0
	var boundaries: Array = []
	var pieces: Array = []
	var visited := {}
	for step: int in segments.size():
		if visited.has(index): return {"valid": false, "reason": "cyclic_contour_before_palm"}
		visited[index] = true
		var keys: Array = endpoints[index]
		var following: String = keys[1] if keys[0] == current else keys[0]
		if not nodes.has(following) or nodes[current].bad or nodes[following].bad or nodes[current].edges.size() != 2 or nodes[following].edges.size() != 2:
			return {"valid": false, "reason": "missing_ambiguous_or_branched_contour",
				"detail": {"current": _node_report(current, nodes), "following": _node_report(following, nodes),
					"edge_index": index, "source_id": segments[index].get("source_id", ""), "distance_m": distance}}
		var length_m: float = (nodes[following].point - nodes[current].point).length()
		if length_m <= EPS_M: return {"valid": false, "reason": "degenerate_contour_edge"}
		pieces.append({"index": index, "a_distance": distance if keys[0] == current else distance + length_m,
			"b_distance": distance + length_m if keys[0] == current else distance})
		var first: Vector4 = nodes[current].weights
		var last: Vector4 = nodes[following].weights
		var lower := 0.0
		while boundaries.size() < 3:
			var distal: int = 2 - boundaries.size()
			var proximal: int = distal - 1 if distal > 0 else 3
			var start_weights := first.lerp(last, lower)
			var da: float = start_weights[distal] - start_weights[proximal]
			var db: float = last[distal] - last[proximal]
			if da < -WEIGHT_EPS: return {"valid": false, "reason": "influence_boundary_order_ambiguous"}
			if db > WEIGHT_EPS: break
			if da - db <= WEIGHT_EPS: return {"valid": false, "reason": "flat_influence_boundary"}
			var t: float = lower + (1.0 - lower) * clampf(da / (da - db), 0.0, 1.0)
			var crossing := first.lerp(last, t)
			if crossing[distal] <= WEIGHT_EPS or crossing[proximal] <= WEIGHT_EPS: return {"valid": false, "reason": "zero_influence_boundary"}
			for influence: int in 4:
				if crossing[influence] > crossing[distal] + WEIGHT_EPS: return {"valid": false, "reason": "nondominant_influence_boundary"}
			var boundary: float = distance + length_m * t
			if boundary <= (0.0 if boundaries.is_empty() else float(boundaries[-1])) + EPS_M: return {"valid": false, "reason": "degenerate_section_length"}
			boundaries.append(boundary)
			lower = t
		if boundaries.size() == 3:
			return {"valid": true, "pieces": pieces, "boundaries": boundaries,
				"lengths": [boundaries[2] - boundaries[1], boundaries[1] - boundaries[0], boundaries[0]]}
		distance += length_m
		var next_edges: Array = nodes[following].edges
		index = next_edges[1] if next_edges[0] == index else next_edges[0]
		current = following
	return {"valid": false, "reason": "palm_boundary_unreached"}


func _node_report(key: String, nodes: Dictionary) -> Dictionary:
	if not nodes.has(key): return {"key": key, "missing": true}
	var node: Dictionary = nodes[key]
	var point: Vector2 = node.point
	var weights: Vector4 = node.weights
	return {"key": key, "point_m": [float(point.x), float(point.y)], "bad": node.bad,
		"weights_s1_s2_s3_hand": [float(weights.x), float(weights.y), float(weights.z), float(weights.w)],
		"degree": node.edges.size(), "edge_indices": node.edges.slice(0, mini(6, node.edges.size()))}
