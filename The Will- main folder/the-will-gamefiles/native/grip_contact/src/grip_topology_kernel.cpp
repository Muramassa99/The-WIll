#include "grip_topology_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <algorithm>
#include <cstdint>
#include <vector>

namespace godot {
namespace {

constexpr double EPS_M = 0.000001;
constexpr double EPS_SQUARED = EPS_M * EPS_M;

struct Bounds {
    Vector2 minimum;
    Vector2 maximum;
};

struct Edge {
    Vector2 a;
    Vector2 b;
    Bounds bounds;
    int64_t first_vertex = 0;
    int64_t last_vertex = 0;
};

struct TopologyNode {
    int64_t first = 0;
    int64_t last = 0;
    Bounds bounds;
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

struct TopologyCounts {
    int64_t open_or_branched_vertices = 0;
    int64_t duplicate_edges = 0;
    int64_t self_intersections = 0;
    int64_t coplanar_edges = 0;
    int64_t sub_epsilon_edges = 0;
    int64_t noncoincident_endpoint_welds = 0;
    Array self_intersection_pairs;

    bool complete() const {
        return open_or_branched_vertices == 0 && duplicate_edges == 0 &&
            self_intersections == 0 && coplanar_edges == 0 &&
            sub_epsilon_edges == 0 && noncoincident_endpoint_welds == 0;
    }

    Dictionary dictionary() const {
        Dictionary out;
        out["open_or_branched_vertices"] = open_or_branched_vertices;
        out["duplicate_edges"] = duplicate_edges;
        out["self_intersections"] = self_intersections;
        out["coplanar_edges"] = coplanar_edges;
        out["sub_epsilon_edges"] = sub_epsilon_edges;
        out["noncoincident_endpoint_welds"] = noncoincident_endpoint_welds;
        out["self_intersection_pairs"] = self_intersection_pairs;
        out["skipped"] = false;
        return out;
    }
};

Dictionary failure(const char *reason) {
    Dictionary out;
    out["valid"] = false;
    out["reason"] = String(reason);
    return out;
}

// This query intentionally uses Vector2/real_t subtraction, maxima and
// squared length, exactly like the reference. It is not the scalar-double
// conservative-bounds helper used by the separate penetration evaluator.
double bounds_distance_squared(const Bounds &a, const Bounds &b) {
    Vector2 gap = a.minimum - b.maximum;
    gap = gap.max(b.minimum - a.maximum).max(Vector2());
    return double(gap.length_squared());
}

Intersection intersection(const Vector2 &a, const Vector2 &b,
        const Vector2 &c, const Vector2 &d) {
    const Vector2 r = b - a;
    const Vector2 s = d - c;
    // GDScript scalar floats are double. Vector2 intermediates remain the
    // project's real_t, including the final scalar-to-vector multiplication.
    const double rx = double(b.x) - double(a.x);
    const double ry = double(b.y) - double(a.y);
    const double sx = double(d.x) - double(c.x);
    const double sy = double(d.y) - double(c.y);
    const double qx = double(c.x) - double(a.x);
    const double qy = double(c.y) - double(a.y);
    const double cross = rx * sy - ry * sx;
    if (cross != 0.0) {
        // Retain ordered exact endpoint handling before the scalar ratios.
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
        const double lo = std::max(0.0, std::min(first, last));
        const double hi = std::min(1.0, std::max(first, last));
        if (hi >= lo) {
            const Vector2 point = a + r * real_t(lo);
            const double u = double((point - c).dot(s)) / double(s.length_squared());
            return {true, lo, u, point, false, hi > lo};
        }
    }
    return {};
}

int64_t topology_range(const std::vector<Edge> &edges, int64_t first,
        int64_t last, std::vector<TopologyNode> &nodes) {
    const int64_t index = int64_t(nodes.size());
    nodes.push_back({});
    nodes[size_t(index)].first = first;
    nodes[size_t(index)].last = last;
    if (last - first <= 8) {
        Bounds bounds = edges[size_t(first)].bounds;
        for (int64_t edge_index = first + 1; edge_index < last; ++edge_index) {
            bounds.minimum = bounds.minimum.min(edges[size_t(edge_index)].bounds.minimum);
            bounds.maximum = bounds.maximum.max(edges[size_t(edge_index)].bounds.maximum);
        }
        nodes[size_t(index)].bounds = bounds;
    } else {
        const int64_t middle = (first + last) >> 1;
        const int64_t left = topology_range(edges, first, middle, nodes);
        const int64_t right = topology_range(edges, middle, last, nodes);
        nodes[size_t(index)].left = left;
        nodes[size_t(index)].right = right;
        nodes[size_t(index)].bounds.minimum =
            nodes[size_t(left)].bounds.minimum.min(nodes[size_t(right)].bounds.minimum);
        nodes[size_t(index)].bounds.maximum =
            nodes[size_t(left)].bounds.maximum.max(nodes[size_t(right)].bounds.maximum);
    }
    return index;
}

void append_topology_candidates(const Edge &edge,
        const std::vector<TopologyNode> &nodes, int64_t node_index,
        int64_t first_edge, std::vector<int64_t> &candidates) {
    const TopologyNode &node = nodes[size_t(node_index)];
    if (node.last <= first_edge + 1 ||
            bounds_distance_squared(edge.bounds, node.bounds) > EPS_SQUARED) {
        return;
    }
    if (node.left >= 0) {
        // Source-contiguous ranges and left-first traversal preserve [i,j]
        // ordering, including the first twelve reported intersections.
        append_topology_candidates(edge, nodes, node.left, first_edge, candidates);
        append_topology_candidates(edge, nodes, node.right, first_edge, candidates);
    } else {
        for (int64_t second = std::max(first_edge + 1, node.first);
                second < node.last; ++second) {
            candidates.push_back(second);
        }
    }
}

Dictionary prepare(const Array &raw) {
    if (raw.is_empty()) return failure("empty_boundary");

    std::vector<Edge> edges;
    edges.reserve(size_t(raw.size()));
    TypedArray<Dictionary> output_edges;
    std::vector<Vector2> points;
    std::vector<int64_t> degree;
    // Keep engine Dictionary key equality/hash behavior (including signed
    // zero), while the first-representative search remains a typed C++ loop.
    Dictionary representative_by_endpoint;
    Dictionary keys;
    TopologyCounts counts;

    for (int64_t index = 0; index < raw.size(); ++index) {
        const Variant item = raw[index];
        Dictionary packet;
        if (item.get_type() == Variant::DICTIONARY) {
            packet = Dictionary(item).duplicate(false);
        } else if (item.get_type() == Variant::ARRAY) {
            const Array pair = item;
            if (pair.size() == 2) {
                packet["a"] = pair[0];
                packet["b"] = pair[1];
            }
        } else if (item.get_type() == Variant::PACKED_VECTOR2_ARRAY) {
            const PackedVector2Array pair = item;
            if (pair.size() == 2) {
                packet["a"] = pair[0];
                packet["b"] = pair[1];
            }
        }
        const Variant a_value = packet.get("a", Variant());
        const Variant b_value = packet.get("b", Variant());
        if (a_value.get_type() != Variant::VECTOR2 || b_value.get_type() != Variant::VECTOR2) {
            return failure("invalid_or_nonfinite_edge");
        }
        const Vector2 a = a_value;
        const Vector2 b = b_value;
        if (!a.is_finite() || !b.is_finite()) return failure("invalid_or_nonfinite_edge");
        const double length_squared = double(a.distance_squared_to(b));
        if (length_squared == 0.0) {
            Dictionary out = failure("zero_length_edge");
            out["edge_index"] = int64_t(edges.size());
            out["length_m"] = 0.0;
            return out;
        }
        counts.sub_epsilon_edges += int64_t(length_squared <= EPS_SQUARED);
        Edge edge;
        edge.a = a;
        edge.b = b;
        edge.bounds.minimum = a.min(b);
        edge.bounds.maximum = a.max(b);
        packet["dynamic"] = bool(packet.get("dynamic", true));
        packet["minimum"] = edge.bounds.minimum;
        packet["maximum"] = edge.bounds.maximum;

        TypedArray<int64_t> ids;
        for (const Vector2 &point : {a, b}) {
            int64_t id = int64_t(representative_by_endpoint.get(point, int64_t(-1)));
            if (id < 0) {
                for (size_t candidate = 0; candidate < points.size(); ++candidate) {
                    if (double(points[candidate].distance_squared_to(point)) <= EPS_SQUARED) {
                        id = int64_t(candidate);
                        break;
                    }
                }
            }
            if (id < 0) {
                id = int64_t(points.size());
                points.push_back(point);
                degree.push_back(0);
            }
            representative_by_endpoint[point] = id;
            counts.noncoincident_endpoint_welds += int64_t(points[size_t(id)] != point);
            ++degree[size_t(id)];
            ids.append(id);
        }
        edge.first_vertex = int64_t(ids[0]);
        edge.last_vertex = int64_t(ids[1]);
        packet["vertex_ids"] = ids;
        const Vector2i key(int32_t(std::min(edge.first_vertex, edge.last_vertex)),
            int32_t(std::max(edge.first_vertex, edge.last_vertex)));
        counts.duplicate_edges += int64_t(keys.has(key));
        keys[key] = true;
        counts.coplanar_edges += int64_t(bool(packet.get("coplanar", false)));
        edges.push_back(edge);
        output_edges.append(packet);
    }

    for (int64_t count : degree) counts.open_or_branched_vertices += int64_t(count != 2);

    std::vector<TopologyNode> nodes;
    if (edges.size() >= 64) {
        nodes.reserve(edges.size() * 2);
        topology_range(edges, 0, int64_t(edges.size()), nodes);
    }
    std::vector<int64_t> candidates;
    for (int64_t first = 0; first < int64_t(edges.size()); ++first) {
        candidates.clear();
        if (nodes.empty()) {
            for (int64_t second = first + 1; second < int64_t(edges.size()); ++second) {
                candidates.push_back(second);
            }
        } else {
            append_topology_candidates(edges[size_t(first)], nodes, 0, first, candidates);
        }
        for (int64_t second : candidates) {
            const Edge &a = edges[size_t(first)];
            const Edge &b = edges[size_t(second)];
            if (bounds_distance_squared(a.bounds, b.bounds) > EPS_SQUARED) continue;
            const Intersection hit = intersection(a.a, a.b, b.a, b.b);
            if (!hit.valid) continue;
            const bool adjacent = a.first_vertex == b.first_vertex ||
                a.last_vertex == b.first_vertex || a.first_vertex == b.last_vertex ||
                a.last_vertex == b.last_vertex;
            if (!adjacent || hit.proper || hit.coincident) {
                ++counts.self_intersections;
                if (counts.self_intersection_pairs.size() < 12) {
                    Array pair;
                    pair.append(first);
                    pair.append(second);
                    Dictionary diagnostic;
                    diagnostic["edges"] = pair;
                    diagnostic["a"] = a.a;
                    diagnostic["b"] = a.b;
                    diagnostic["c"] = b.a;
                    diagnostic["d"] = b.b;
                    diagnostic["adjacent"] = adjacent;
                    diagnostic["intersection"] = hit.dictionary();
                    counts.self_intersection_pairs.append(diagnostic);
                }
            }
        }
    }

    Dictionary out;
    out["valid"] = true;
    out["segments"] = output_edges;
    out["topology_complete"] = counts.complete();
    out["topology"] = counts.dictionary();
    return out;
}

} // namespace

void GripTopologyKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("prepare_target", "segments", "origin_id"),
        &GripTopologyKernel::prepare_target);
}

Dictionary GripTopologyKernel::prepare_target(const Array &segments,
        const StringName &origin_id) const {
    if (origin_id == StringName()) return failure("missing_plane_origin");
    Dictionary out = prepare(segments);
    out["origin_id"] = origin_id;
    return out;
}

} // namespace godot
