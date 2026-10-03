#include "grip_slice_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/aabb.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace godot {
namespace {

constexpr double DISTANCE_EPSILON_M = 0.000001;
constexpr double POINT_MERGE_EPSILON_M = 0.000005;
constexpr double AREA_EPSILON_M2 = 0.000000000001;

struct Counts {
    int64_t triangles_total = 0;
    int64_t triangles_visited = 0;
    int64_t triangles_reach_pruned = 0;
    int64_t triangles_local = 0;
    int64_t triangles_intersected = 0;
    int64_t coplanar_triangles = 0;
    int64_t segments_before_clip = 0;
    int64_t segments_clipped = 0;
    int64_t segments_outside_disk = 0;
    int64_t segments_emitted = 0;
    int64_t contours_closed = 0;
    int64_t open_or_branched_vertices = 0;

    Dictionary dictionary() const {
        Dictionary out;
        out["triangles_total"] = triangles_total;
        out["triangles_visited"] = triangles_visited;
        out["triangles_reach_pruned"] = triangles_reach_pruned;
        out["triangles_local"] = triangles_local;
        out["triangles_intersected"] = triangles_intersected;
        out["coplanar_triangles"] = coplanar_triangles;
        out["segments_before_clip"] = segments_before_clip;
        out["segments_clipped"] = segments_clipped;
        out["segments_outside_disk"] = segments_outside_disk;
        out["segments_emitted"] = segments_emitted;
        out["contours_closed"] = contours_closed;
        out["open_or_branched_vertices"] = open_or_branched_vertices;
        out["bvh_used"] = false;
        return out;
    }
};

uint64_t integer_pair_key(int32_t x, int32_t y) {
    return (uint64_t(uint32_t(x)) << 32U) | uint64_t(uint32_t(y));
}

struct Edge {
    int32_t a;
    int32_t b;
    int64_t count;
};

uint64_t edge_key(int32_t a, int32_t b) {
    return integer_pair_key(std::min(a, b), std::max(a, b));
}

// GDScript Dictionary updates retain first insertion order. Keep that order
// independently from native hash-table lookup; it determines later weld IDs.
struct OrderedEdges {
    std::vector<Edge> order;
    std::unordered_map<uint64_t, size_t> index;

    void set(int32_t a, int32_t b) {
        const uint64_t key = edge_key(a, b);
        const auto found = index.find(key);
        if (found == index.end()) {
            index.emplace(key, order.size());
            order.push_back({std::min(a, b), std::max(a, b), 1});
        }
    }

    void increment(int32_t a, int32_t b) {
        if (a < 0 || b < 0 || a == b) return;
        const uint64_t key = edge_key(a, b);
        const auto found = index.find(key);
        if (found == index.end()) {
            index.emplace(key, order.size());
            order.push_back({std::min(a, b), std::max(a, b), 1});
        } else {
            ++order[found->second].count;
        }
    }
};

using Buckets = std::unordered_map<uint64_t, std::vector<int32_t>>;

bool valid_plane(const Transform3D &plane) {
    if (!plane.is_finite()) return false;
    const Vector3 x = plane.basis.get_column(0);
    const Vector3 y = plane.basis.get_column(1);
    const Vector3 z = plane.basis.get_column(2);
    return std::abs(double(x.length_squared()) - 1.0) < 0.000001 &&
        std::abs(double(y.length_squared()) - 1.0) < 0.000001 &&
        std::abs(double(z.length_squared()) - 1.0) < 0.000001 &&
        std::abs(double(x.dot(y))) < 0.000001 &&
        std::abs(double(x.dot(z))) < 0.000001 &&
        std::abs(double(y.dot(z))) < 0.000001 && double(plane.basis.determinant()) > 0.999999;
}

int32_t welded_point_id(std::vector<Vector2> &points, Buckets &buckets, const Vector3 &point,
        const Vector3 &origin, const Vector3 &axis_u, const Vector3 &axis_v) {
    const Vector3 relative = point - origin;
    const Vector2 point_2d(relative.dot(axis_u), relative.dot(axis_v));
    // roundi is scalar-double rounding away from zero at halfway values;
    // Vector2i then stores 32-bit coordinates, as do the reference buckets.
    const int32_t bucket_x = int32_t(int64_t(std::round(double(point_2d.x) / POINT_MERGE_EPSILON_M)));
    const int32_t bucket_y = int32_t(int64_t(std::round(double(point_2d.y) / POINT_MERGE_EPSILON_M)));
    for (int64_t x = int64_t(bucket_x) - 1; x < int64_t(bucket_x) + 2; ++x) {
        for (int64_t y = int64_t(bucket_y) - 1; y < int64_t(bucket_y) + 2; ++y) {
            const auto candidates = buckets.find(integer_pair_key(int32_t(x), int32_t(y)));
            if (candidates == buckets.end()) continue;
            for (const int32_t candidate : candidates->second) {
                if (double(points[size_t(candidate)].distance_squared_to(point_2d)) <=
                        POINT_MERGE_EPSILON_M * POINT_MERGE_EPSILON_M) return candidate;
            }
        }
    }
    const int32_t id = int32_t(points.size());
    points.push_back(point_2d);
    buckets[integer_pair_key(bucket_x, bucket_y)].push_back(id);
    return id;
}

int32_t plane_point_id(std::vector<Vector2> &points, Buckets &buckets, const Vector2 &point) {
    return welded_point_id(points, buckets, Vector3(point.x, point.y, 0.0), Vector3(),
        Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0));
}

void append_unique(std::vector<int32_t> &ids, int32_t id) {
    if (std::find(ids.begin(), ids.end(), id) == ids.end()) ids.push_back(id);
}

std::array<int32_t, 2> farthest_pair(const std::vector<int32_t> &ids, const std::vector<Vector2> &points) {
    std::array<int32_t, 2> best{-1, -1};
    double best_distance_squared = -1.0;
    for (size_t a = 0; a < ids.size(); ++a) {
        for (size_t b = a + 1; b < ids.size(); ++b) {
            const double distance_squared = double(points[size_t(ids[a])].distance_squared_to(points[size_t(ids[b])]));
            if (distance_squared <= best_distance_squared) continue;
            best_distance_squared = distance_squared;
            best = {ids[a], ids[b]};
        }
    }
    return best;
}

struct ClippedSegment {
    bool valid = false;
    Vector2 a;
    Vector2 b;
    bool clipped = false;
};

ClippedSegment clip_to_disk(const Vector2 &a, const Vector2 &b, double radius) {
    const Vector2 delta = b - a;
    const double length_squared = double(delta.length_squared());
    if (length_squared <= 0.000000000001) return {};
    const double projection = double(a.dot(delta));
    const double discriminant = projection * projection - length_squared *
        (double(a.length_squared()) - radius * radius);
    if (discriminant < 0.0) return {};
    const double root = std::sqrt(discriminant);
    const double lower = std::max(0.0, (-projection - root) / length_squared);
    const double upper = std::min(1.0, (-projection + root) / length_squared);
    if (upper <= lower) return {};
    Vector2 first = a + delta * real_t(lower);
    Vector2 last = a + delta * real_t(upper);
    if (double(first.length()) > radius) first *= real_t(radius / double(first.length()));
    if (double(last.length()) > radius) last *= real_t(radius / double(last.length()));
    return {true, first, last, lower > 0.0 || upper < 1.0};
}

bool polygon_centroid_valid(const PackedVector2Array &polygon) {
    double signed_area_twice = 0.0;
    for (int64_t index = 0; index < polygon.size(); ++index) {
        const Vector2 a = polygon[index];
        const Vector2 b = polygon[(index + 1) % polygon.size()];
        signed_area_twice += double(a.cross(b));
    }
    // _closed_contours reads only the valid flag from the reference centroid
    // helper. Keep its identical area sum; its unused centroid need not escape.
    return !(std::abs(signed_area_twice) <= AREA_EPSILON_M2);
}

TypedArray<PackedVector2Array> closed_contours(const std::vector<Vector2> &points,
        const OrderedEdges &edges, const std::vector<std::vector<int32_t>> &adjacency,
        const std::unordered_set<int32_t> &cut_vertices) {
    TypedArray<PackedVector2Array> contours;
    std::unordered_set<uint64_t> visited;
    // Point IDs increase monotonically. Walking the populated slots is the
    // reference's sorted adjacency.keys() order, independent of hash ordering.
    for (size_t start = 0; start < adjacency.size(); ++start) {
        const std::vector<int32_t> &neighbors = adjacency[start];
        if (neighbors.size() != 2 || visited.count(edge_key(int32_t(start), neighbors[0])) != 0) continue;
        PackedVector2Array contour;
        int32_t previous = -1;
        int32_t current = int32_t(start);
        bool has_cut = false;
        for (size_t step = 0; step < edges.order.size() + 1; ++step) {
            const std::vector<int32_t> &options = adjacency[size_t(current)];
            if (options.size() != 2) break;
            has_cut = has_cut || cut_vertices.count(current) != 0;
            contour.append(points[size_t(current)]);
            const int32_t following = options[0] != previous ? options[0] : options[1];
            const uint64_t key = edge_key(current, following);
            if (visited.count(key) != 0) break;
            visited.insert(key);
            previous = current;
            current = following;
            if (current == int32_t(start)) {
                if (!has_cut && contour.size() >= 3 && polygon_centroid_valid(contour)) {
                    contour.append(contour[0]);
                    contours.append(contour);
                }
                break;
            }
        }
    }
    return contours;
}

} // namespace

void GripSliceKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("slice", "surface", "plane_to_world", "plane_origin_id", "reach_m", "skin_padding_m"),
        &GripSliceKernel::slice);
}

Dictionary GripSliceKernel::slice(const Dictionary &surface, const Transform3D &plane_to_world,
        const StringName &plane_origin_id, double reach_m, double skin_padding_m) const {
    Dictionary result;
    result["valid"] = false;
    result["segments"] = Array();
    result["contours"] = Array();
    result["origin_id"] = plane_origin_id;
    result["reach_m"] = reach_m;
    result["skin_padding_m"] = skin_padding_m;
    result["classification_incomplete"] = true;
    result["counts"] = Dictionary();
    result["status"] = String("invalid_input");
    if (plane_origin_id == StringName() || !valid_plane(plane_to_world)) {
        result["status"] = String("invalid_plane_origin_or_metric_frame");
        return result;
    }
    if (!std::isfinite(reach_m) || reach_m <= 0.0 || !std::isfinite(skin_padding_m) || skin_padding_m < 0.0) return result;
    const double radius = reach_m + skin_padding_m;
    if (!std::isfinite(radius) || !std::isfinite(radius * radius)) return result;
    if (!bool(surface.get("valid", false)) ||
            surface.get("triangles_world", Variant()).get_type() != Variant::PACKED_VECTOR3_ARRAY) return result;
    if (StringName(surface.get("surface_source_origin_id", StringName())) == StringName() ||
            StringName(surface.get("resolved_world_origin_id", StringName())) == StringName()) {
        result["status"] = String("missing_surface_origins");
        return result;
    }
    const PackedVector3Array triangles = surface["triangles_world"];
    if (triangles.is_empty() || triangles.size() % 3 != 0) return result;
    Counts counts;
    counts.triangles_total = triangles.size() / 3;
    std::vector<Vector2> points;
    Buckets buckets;
    OrderedEdges edges;
    OrderedEdges coplanar;
    const Vector3 axis_u = plane_to_world.basis.get_column(0);
    const Vector3 axis_v = plane_to_world.basis.get_column(1);
    const Vector3 axis_normal = plane_to_world.basis.get_column(2);
    for (int64_t offset = 0; offset < triangles.size(); offset += 3) {
        ++counts.triangles_visited;
        const Vector3 a = triangles[offset];
        const Vector3 b = triangles[offset + 1];
        const Vector3 c = triangles[offset + 2];
        if (!a.is_finite() || !b.is_finite() || !c.is_finite()) {
            result["counts"] = counts.dictionary();
            result["status"] = String("nonfinite_triangle");
            return result;
        }
        const AABB bounds = AABB(a, Vector3()).expand(b).expand(c);
        const Vector3 closest = plane_to_world.origin.clamp(bounds.position, bounds.get_end());
        if (double(closest.distance_squared_to(plane_to_world.origin)) > radius * radius) {
            ++counts.triangles_reach_pruned;
            continue;
        }
        ++counts.triangles_local;
        const std::array<Vector3, 3> vertices{a, b, c};
        std::array<double, 3> distances;
        for (size_t index = 0; index < vertices.size(); ++index) {
            distances[index] = double((vertices[index] - plane_to_world.origin).dot(axis_normal));
        }
        const bool all_on = std::abs(distances[0]) <= DISTANCE_EPSILON_M &&
            std::abs(distances[1]) <= DISTANCE_EPSILON_M && std::abs(distances[2]) <= DISTANCE_EPSILON_M;
        std::vector<int32_t> ids;
        ids.reserve(3);
        for (size_t edge_index = 0; edge_index < 3; ++edge_index) {
            const size_t following = (edge_index + 1) % 3;
            if (std::abs(distances[edge_index]) <= DISTANCE_EPSILON_M) {
                append_unique(ids, welded_point_id(points, buckets, vertices[edge_index], plane_to_world.origin, axis_u, axis_v));
            }
            if ((distances[edge_index] > DISTANCE_EPSILON_M && distances[following] < -DISTANCE_EPSILON_M) ||
                    (distances[edge_index] < -DISTANCE_EPSILON_M && distances[following] > DISTANCE_EPSILON_M)) {
                const double ratio = distances[edge_index] / (distances[edge_index] - distances[following]);
                const Vector3 crossing = vertices[edge_index].lerp(vertices[following], real_t(ratio));
                append_unique(ids, welded_point_id(points, buckets, crossing, plane_to_world.origin, axis_u, axis_v));
            }
        }
        if (all_on) {
            ++counts.coplanar_triangles;
            for (size_t index = 0; index < ids.size(); ++index) coplanar.increment(ids[index], ids[(index + 1) % ids.size()]);
        } else if (ids.size() >= 2) {
            ++counts.triangles_intersected;
            const std::array<int32_t, 2> pair = farthest_pair(ids, points);
            edges.set(pair[0], pair[1]);
        }
    }
    for (const Edge &edge : coplanar.order) {
        if (edge.count % 2 == 1) edges.set(edge.a, edge.b);
    }
    counts.segments_before_clip = int64_t(edges.order.size());
    std::vector<Vector2> clipped_points;
    Buckets clipped_buckets;
    OrderedEdges clipped_edges;
    std::unordered_set<int32_t> cut_vertices;
    for (const Edge &edge : edges.order) {
        const ClippedSegment clipped = clip_to_disk(points[size_t(edge.a)], points[size_t(edge.b)], radius);
        if (!clipped.valid) {
            ++counts.segments_outside_disk;
            continue;
        }
        const int32_t first = plane_point_id(clipped_points, clipped_buckets, clipped.a);
        const int32_t last = plane_point_id(clipped_points, clipped_buckets, clipped.b);
        if (clipped.clipped) {
            ++counts.segments_clipped;
            cut_vertices.insert(first);
            cut_vertices.insert(last);
        }
        if (first != last) clipped_edges.set(first, last);
    }
    Array segments;
    std::vector<std::vector<int32_t>> adjacency(clipped_points.size());
    for (const Edge &edge : clipped_edges.order) {
        Array pair;
        pair.append(clipped_points[size_t(edge.a)]);
        pair.append(clipped_points[size_t(edge.b)]);
        segments.append(pair);
        adjacency[size_t(edge.a)].push_back(edge.b);
        adjacency[size_t(edge.b)].push_back(edge.a);
    }
    for (std::vector<int32_t> &neighbors : adjacency) {
        if (neighbors.empty()) continue;
        std::sort(neighbors.begin(), neighbors.end());
        if (neighbors.size() != 2) ++counts.open_or_branched_vertices;
    }
    const TypedArray<PackedVector2Array> contours = closed_contours(clipped_points, clipped_edges, adjacency, cut_vertices);
    counts.segments_emitted = segments.size();
    counts.contours_closed = contours.size();
    const Dictionary topology = surface.get("capsule_surface_topology", Dictionary());
    const bool incomplete = !bool(topology.get("closed", false)) || counts.triangles_reach_pruned > 0 ||
        counts.segments_clipped > 0 || counts.segments_outside_disk > 0 || counts.coplanar_triangles > 0 ||
        counts.open_or_branched_vertices > 0;
    result["segments"] = segments;
    result["contours"] = contours;
    result["counts"] = counts.dictionary();
    result["classification_incomplete"] = incomplete;
    result["search_radius_m"] = radius;
    result["valid"] = true;
    result["status"] = String(counts.segments_emitted == 0 ? "no_local_segments" :
        (incomplete ? "partial_local_slice" : "complete_closed_slice"));
    return result;
}

} // namespace godot
