#include "grip_ordered_target.h"

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <vector>

namespace godot {
namespace {

using Bounds = std::array<double, 4>;

struct Edge {
    Vector2 a;
    Vector2 b;
    Bounds bounds;
};

struct EdgeNode {
    int64_t first = 0;
    int64_t last = 0;
    Bounds bounds{};
    int64_t left = -1;
    int64_t right = -1;
};

struct Intersection {
    bool valid = false;
    double t = 0.0;
    double u = 0.0;
    Vector2 point;
    bool proper = false;
    bool coincident = false;

    Dictionary dictionary() const {
        Dictionary out;
        out["t"] = t;
        out["u"] = u;
        out["point"] = point;
        out["proper"] = proper;
        out["coincident"] = coincident;
        return out;
    }
};

Dictionary failure(const char *reason, const Dictionary &details = Dictionary()) {
    Dictionary out;
    out["valid"] = false;
    out["cap_status"] = StringName("unknown");
    out["reason"] = String(reason);
    out["details"] = details;
    out["whole_skin_clearance_verified"] = false;
    out["actual_3d_grip_verified"] = false;
    return out;
}

Dictionary edge_failure(const char *reason, int64_t edge) {
    Dictionary details;
    details["edge"] = edge;
    return failure(reason, details);
}

Bounds scalar_bounds(const Vector2 &a, const Vector2 &b) {
    // Unlike the mesh-soup topology helper, ordered-target broad-phase
    // bounds are scalar doubles and use a zero separation guard.
    return {MIN(double(a.x), double(b.x)), MIN(double(a.y), double(b.y)),
        MAX(double(a.x), double(b.x)), MAX(double(a.y), double(b.y))};
}

double bounds_distance_squared(const Bounds &first, const Bounds &second) {
    const double gap_x = MAX(0.0, MAX(first[0] - second[2], second[0] - first[2]));
    const double gap_y = MAX(0.0, MAX(first[1] - second[3], second[1] - first[3]));
    return gap_x * gap_x + gap_y * gap_y;
}

PackedFloat64Array packed_bounds(const Bounds &bounds) {
    PackedFloat64Array packed;
    packed.resize(4);
    for (int64_t index = 0; index < 4; ++index) packed.set(index, bounds[size_t(index)]);
    return packed;
}

Bounds merged_bounds(const Bounds &first, const Bounds &second) {
    return {MIN(first[0], second[0]), MIN(first[1], second[1]),
        MAX(first[2], second[2]), MAX(first[3], second[3])};
}

int64_t edge_range(const std::vector<Edge> &edges, int64_t first,
        int64_t last, std::vector<EdgeNode> &nodes) {
    const int64_t index = int64_t(nodes.size());
    nodes.push_back({});
    nodes[size_t(index)].first = first;
    nodes[size_t(index)].last = last;
    if (last - first <= 8) {
        Bounds bounds = edges[size_t(first)].bounds;
        for (int64_t next = first + 1; next < last; ++next) {
            bounds = merged_bounds(bounds, edges[size_t(next)].bounds);
        }
        nodes[size_t(index)].bounds = bounds;
    } else {
        const int64_t middle = (first + last) >> 1;
        const int64_t left = edge_range(edges, first, middle, nodes);
        const int64_t right = edge_range(edges, middle, last, nodes);
        nodes[size_t(index)].left = left;
        nodes[size_t(index)].right = right;
        nodes[size_t(index)].bounds = merged_bounds(nodes[size_t(left)].bounds, nodes[size_t(right)].bounds);
    }
    return index;
}

Dictionary node_dictionary(const std::vector<EdgeNode> &nodes, int64_t node_index) {
    const EdgeNode &node = nodes[size_t(node_index)];
    Dictionary out;
    out["first"] = node.first;
    out["last"] = node.last;
    if (node.left >= 0) {
        out["left"] = node_dictionary(nodes, node.left);
        out["right"] = node_dictionary(nodes, node.right);
    }
    out["bounds"] = packed_bounds(node.bounds);
    return out;
}

void append_edge_candidates(const std::vector<EdgeNode> &nodes, int64_t node_index,
        const Bounds &box, int64_t first, std::vector<int64_t> &out) {
    const EdgeNode &node = nodes[size_t(node_index)];
    if (node.last <= first || bounds_distance_squared(box, node.bounds) > 0.0) return;
    if (node.left >= 0) {
        // Contiguous source ranges, left first: retain the reference's first
        // rejected pair and its exact diagnostic intersection.
        append_edge_candidates(nodes, node.left, box, first, out);
        append_edge_candidates(nodes, node.right, box, first, out);
    } else {
        for (int64_t index = MAX(first, node.first); index < node.last; ++index) out.push_back(index);
    }
}

// Counterpart of skin_plane_contact_query.gd::_intersection. The full witness
// is needed for invalid-target diagnostics, including ordered endpoint t/u.
// Scalar predicates stay double; Vector2 operations retain project real_t.
Intersection intersection(const Vector2 &a, const Vector2 &b,
        const Vector2 &c, const Vector2 &d) {
    const Vector2 r = b - a;
    const Vector2 s = d - c;
    const double rx = double(b.x) - double(a.x);
    const double ry = double(b.y) - double(a.y);
    const double sx = double(d.x) - double(c.x);
    const double sy = double(d.y) - double(c.y);
    const double qx = double(c.x) - double(a.x);
    const double qy = double(c.y) - double(a.y);
    const double cross = rx * sy - ry * sx;
    if (cross != 0.0) {
        if (a == c) return {true, 0.0, 0.0, a, false, false};
        if (a == d) return {true, 0.0, 1.0, a, false, false};
        if (b == c) return {true, 1.0, 0.0, b, false, false};
        if (b == d) return {true, 1.0, 1.0, b, false, false};
        const double t = (qx * sy - qy * sx) / cross;
        const double u = (qx * ry - qy * rx) / cross;
        if (t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0) {
            return {true, t, u, a + r * real_t(t),
                t > 0.0 && t < 1.0 && u > 0.0 && u < 1.0, false};
        }
    } else if (qx * ry - qy * rx == 0.0) {
        const double first = (qx * rx + qy * ry) / (rx * rx + ry * ry);
        const double last = ((double(d.x) - double(a.x)) * rx +
            (double(d.y) - double(a.y)) * ry) / (rx * rx + ry * ry);
        const double lo = MAX(0.0, MIN(first, last));
        const double hi = MIN(1.0, MAX(first, last));
        if (hi >= lo) {
            const Vector2 point = a + r * real_t(lo);
            const double u = double((point - c).dot(s)) / double(s.length_squared());
            return {true, lo, u, point, false, hi > lo};
        }
    }
    return {};
}

} // namespace

Dictionary prepare_grip_ordered_target(const PackedVector2Array &polygon,
        const StringName &origin, const StringName &source, bool complete) {
    if (origin == StringName() || source == StringName()) return failure("missing_target_origin_or_source");
    if (!complete) return failure("incomplete_target_boundary");

    PackedVector2Array points = polygon.duplicate();
    if (points.size() > 1 && points[0] == points[points.size() - 1]) points.resize(points.size() - 1);
    if (points.size() < 3) return failure("target_has_too_few_vertices");

    std::vector<Edge> edges;
    edges.reserve(size_t(points.size()));
    Array output_edges;
    TypedArray<PackedFloat64Array> output_bounds;
    double scale_m = 0.0;
    double twice_area = 0.0;
    const real_t infinity = std::numeric_limits<real_t>::infinity();
    Vector2 minimum(infinity, infinity);
    Vector2 maximum(-infinity, -infinity);
    for (int64_t index = 0; index < points.size(); ++index) {
        const Vector2 a = points[index];
        const Vector2 b = points[(index + 1) % points.size()];
        if (!a.is_finite() || !b.is_finite()) return edge_failure("nonfinite_target_vertex", index);
        if (a == b) return edge_failure("zero_length_ordered_target_edge", index);

        const Bounds bounds = scalar_bounds(a, b);
        edges.push_back({a, b, bounds});
        Array pair;
        pair.append(a);
        pair.append(b);
        output_edges.append(pair);
        output_bounds.append(packed_bounds(bounds));
        scale_m = MAX(scale_m, MAX(std::abs(double(a.x)), std::abs(double(a.y))));
        minimum = minimum.min(a);
        maximum = maximum.max(a);
        twice_area += double(a.x) * double(b.y) - double(b.x) * double(a.y);
    }
    if (!std::isfinite(twice_area) || twice_area == 0.0) return failure("ordered_target_has_zero_or_nonfinite_area");

    std::vector<EdgeNode> nodes;
    if (edges.size() >= 64) {
        nodes.reserve(edges.size() * 2);
        edge_range(edges, 0, int64_t(edges.size()), nodes);
    }
    std::vector<int64_t> candidates;
    for (int64_t first = 0; first < int64_t(edges.size()); ++first) {
        candidates.clear();
        if (nodes.empty()) {
            for (int64_t second = first + 1; second < int64_t(edges.size()); ++second) candidates.push_back(second);
        } else {
            append_edge_candidates(nodes, 0, edges[size_t(first)].bounds, first + 1, candidates);
        }
        for (int64_t second : candidates) {
            const Edge &a = edges[size_t(first)];
            const Edge &b = edges[size_t(second)];
            if (bounds_distance_squared(a.bounds, b.bounds) > 0.0) continue;
            const Intersection hit = intersection(a.a, a.b, b.a, b.b);
            const bool adjacent = second == first + 1 || (first == 0 && second == int64_t(edges.size()) - 1);
            if (hit.valid && (!adjacent || hit.proper || hit.coincident)) {
                Array pair;
                pair.append(first);
                pair.append(second);
                Dictionary details;
                details["edges"] = pair;
                details["intersection"] = hit.dictionary();
                return failure("ordered_target_crossing_or_overlapping_edges", details);
            }
        }
    }

    const double dx = double(maximum.x) - double(minimum.x);
    const double dy = double(maximum.y) - double(minimum.y);
    Dictionary out;
    out["valid"] = true;
    out["revision"] = StringName("planar_skin_overlap_budget_v1");
    out["polygon"] = points;
    out["origin_id"] = origin;
    out["source_id"] = source;
    out["metric_units"] = StringName("meters");
    out["complete"] = true;
    out["edges"] = output_edges;
    out["edge_bounds"] = output_bounds;
    out["edge_tree"] = nodes.empty() ? Dictionary() : node_dictionary(nodes, 0);
    out["winding_sign"] = twice_area > 0.0 ? 1.0 : -1.0;
    out["coordinate_scale_m"] = scale_m;
    out["diameter_upper_m"] = std::sqrt(dx * dx + dy * dy);
    out["actual_3d_grip_verified"] = false;
    return out;
}

} // namespace godot
