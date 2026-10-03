#include "grip_contact_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <limits>
#include <unordered_map>
#include <utility>
#include <vector>

namespace godot {
namespace {

constexpr double INF_D = std::numeric_limits<double>::infinity();
constexpr double CONTACT_EPS_M = 0.000001;
using Bounds = std::array<double, 4>;
using PhaseClock = std::chrono::steady_clock;

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

struct Target {
    std::vector<Edge> edges;
    std::vector<EdgeNode> tree;
    int64_t root = -1;
    StringName origin_id;
    StringName source_id;
    double coordinate_scale_m = 0.0;
    double diameter_upper_m = 0.0;
    double winding_sign = 0.0;
};

struct Intersection {
    bool valid = false;
    double t = 0.0;
    Vector2 point;
    bool coincident = false;
};

struct NearestPair {
    double distance_squared = INF_D;
    Vector2 skin_point;
    Vector2 target_point;
};

struct DepthNode {
    double lo;
    double hi;
    double first_m;
    double middle_m;
    double last_m;
    double upper_m;
};

struct DepthBounds {
    double lower_m;
    double upper_m;
};

struct Sample {
    bool valid = false;
    bool inside = false;
    double depth_m = 0.0;
};

struct DepthWitness {
    bool valid = false;
    Vector2 skin_point;
    double t = 0.0;
    Vector2 target_point;
    int64_t edge_index = -1;
    double depth_m = 0.0;
};

struct SampleState {
    std::unordered_map<double, Sample> cache;
    int64_t evaluations = 0;
    int64_t budget = 0;
    double maximum_sampled_depth_m = 0.0;
    int64_t inside_interval_count = 0;
    DepthWitness witness;
    bool use_boundary_pruning = false;
    double epsilon = 0.0;
    int64_t sample_edge_tests = 0;
    int64_t sample_tree_prunes = 0;
};

struct WorkCounts {
    int64_t intersection_tests = 0;
    int64_t contact_intersection_reuses = 0;
    int64_t contact_nearest_tests = 0;
    int64_t contact_aabb_tests = 0;
    int64_t contact_aabb_prunes = 0;
    int64_t sample_edge_tests = 0;
    int64_t sample_tree_prunes = 0;

    Dictionary dictionary() const {
        Dictionary out;
        out["intersection_tests"] = intersection_tests;
        out["contact_intersection_reuses"] = contact_intersection_reuses;
        out["contact_nearest_tests"] = contact_nearest_tests;
        out["contact_aabb_tests"] = contact_aabb_tests;
        out["contact_aabb_prunes"] = contact_aabb_prunes;
        out["sample_edge_tests"] = sample_edge_tests;
        out["sample_tree_prunes"] = sample_tree_prunes;
        return out;
    }
};

enum class CapStatus { WITHIN, EXCEEDS, UNRESOLVED };

double clamp01(double value) {
    return std::min(std::max(value, 0.0), 1.0);
}

Bounds scalar_bounds(const Vector2 &a, const Vector2 &b) {
    return {std::min(double(a.x), double(b.x)), std::min(double(a.y), double(b.y)),
        std::max(double(a.x), double(b.x)), std::max(double(a.y), double(b.y))};
}

double bounds_distance_squared(const Bounds &first, const Bounds &second) {
    const double gap_x = std::max(0.0, std::max(first[0] - second[2], second[0] - first[2]));
    const double gap_y = std::max(0.0, std::max(first[1] - second[3], second[1] - first[3]));
    return gap_x * gap_x + gap_y * gap_y;
}

double scalar_distance(const Vector2 &a, const Vector2 &b) {
    const double dx = double(b.x) - double(a.x);
    const double dy = double(b.y) - double(a.y);
    return std::sqrt(dx * dx + dy * dy);
}

double parameter(const Vector2 &point, const Vector2 &a, const Vector2 &b) {
    const double dx = double(b.x) - double(a.x);
    const double dy = double(b.y) - double(a.y);
    return ((double(point.x) - double(a.x)) * dx + (double(point.y) - double(a.y)) * dy) /
        (dx * dx + dy * dy);
}

// The engine Vector2 operations intentionally keep real_t precision. The
// scalar arithmetic in the GDScript reference is double and stays double here.
Intersection intersection(const Vector2 &a, const Vector2 &b, const Vector2 &c, const Vector2 &d) {
    const Vector2 r = b - a;
    const double rx = double(b.x) - double(a.x);
    const double ry = double(b.y) - double(a.y);
    const double sx = double(d.x) - double(c.x);
    const double sy = double(d.y) - double(c.y);
    const double qx = double(c.x) - double(a.x);
    const double qy = double(c.y) - double(a.y);
    const double cross = rx * sy - ry * sx;
    if (cross != 0.0) {
        if (a == c || a == d) return {true, 0.0, a, false};
        if (b == c || b == d) return {true, 1.0, b, false};
        const double t = (qx * sy - qy * sx) / cross;
        const double u = (qx * ry - qy * rx) / cross;
        if (t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0) {
            return {true, t, a + r * real_t(t), false};
        }
    } else if (qx * ry - qy * rx == 0.0) {
        const double first = (qx * rx + qy * ry) / (rx * rx + ry * ry);
        const double last = ((double(d.x) - double(a.x)) * rx + (double(d.y) - double(a.y)) * ry) /
            (rx * rx + ry * ry);
        const double lo = std::max(0.0, std::min(first, last));
        const double hi = std::min(1.0, std::max(first, last));
        if (hi >= lo) return {true, lo, a + r * real_t(lo), hi > lo};
    }
    return {};
}

Vector2 project(const Vector2 &point, const Vector2 &a, const Vector2 &b) {
    const Vector2 delta = b - a;
    const double ratio = clamp01(double((point - a).dot(delta)) / double(delta.length_squared()));
    return a + delta * real_t(ratio);
}

NearestPair nearest_pair(const Vector2 &a, const Vector2 &b, const Vector2 &c, const Vector2 &d,
        const Intersection &hit) {
    if (hit.valid) return {0.0, hit.point, hit.point};
    NearestPair result;
    Vector2 projected = project(a, c, d);
    double squared = double(a.distance_squared_to(projected));
    if (squared < result.distance_squared) result = {squared, a, projected};
    projected = project(b, c, d);
    squared = double(b.distance_squared_to(projected));
    if (squared < result.distance_squared) result = {squared, b, projected};
    projected = project(c, a, b);
    squared = double(projected.distance_squared_to(c));
    if (squared < result.distance_squared) result = {squared, projected, c};
    projected = project(d, a, b);
    squared = double(projected.distance_squared_to(d));
    if (squared < result.distance_squared) result = {squared, projected, d};
    return result;
}

int64_t edge_range(Target &target, int64_t first, int64_t last) {
    const int64_t index = int64_t(target.tree.size());
    target.tree.emplace_back();
    EdgeNode node;
    node.first = first;
    node.last = last;
    if (last - first <= 8) {
        node.bounds = target.edges[size_t(first)].bounds;
        for (int64_t i = first + 1; i < last; ++i) {
            const Bounds &next = target.edges[size_t(i)].bounds;
            node.bounds[0] = std::min(node.bounds[0], next[0]);
            node.bounds[1] = std::min(node.bounds[1], next[1]);
            node.bounds[2] = std::max(node.bounds[2], next[2]);
            node.bounds[3] = std::max(node.bounds[3], next[3]);
        }
    } else {
        const int64_t middle = (first + last) >> 1;
        node.left = edge_range(target, first, middle);
        node.right = edge_range(target, middle, last);
        const Bounds &left = target.tree[size_t(node.left)].bounds;
        const Bounds &right = target.tree[size_t(node.right)].bounds;
        node.bounds = {std::min(left[0], right[0]), std::min(left[1], right[1]),
            std::max(left[2], right[2]), std::max(left[3], right[3])};
    }
    target.tree[size_t(index)] = node;
    return index;
}

void append_edge_candidates(const Target &target, int64_t node_index, const Bounds &box,
        double guard_squared, int64_t first, std::vector<int64_t> &out) {
    const EdgeNode &node = target.tree[size_t(node_index)];
    if (node.last <= first || bounds_distance_squared(box, node.bounds) > guard_squared) return;
    if (node.left >= 0) {
        append_edge_candidates(target, node.left, box, guard_squared, first, out);
        append_edge_candidates(target, node.right, box, guard_squared, first, out);
    } else {
        for (int64_t i = std::max(first, node.first); i < node.last; ++i) out.push_back(i);
    }
}

DepthNode depth_node(double lo, double hi, double first, double middle, double last, double length_m) {
    const double half_length = length_m * (hi - lo) * 0.5;
    const double upper_left = std::max(std::max(first, middle), (first + middle + half_length) * 0.5);
    const double upper_right = std::max(std::max(middle, last), (middle + last + half_length) * 0.5);
    return {lo, hi, first, middle, last, std::max(upper_left, upper_right)};
}

DepthBounds depth_bounds(const std::vector<DepthNode> &nodes, const SampleState &state,
        int64_t pending, const Target &target) {
    const double lower = state.maximum_sampled_depth_m;
    double upper = lower;
    for (const DepthNode &node : nodes) upper = std::max(upper, node.upper_m);
    if (pending > 0) upper = std::max(upper, target.diameter_upper_m);
    return {lower, upper};
}

CapStatus cap_status(const DepthBounds &bounds, double cap, double epsilon) {
    if (bounds.lower_m - epsilon > cap) return CapStatus::EXCEEDS;
    if (bounds.upper_m + epsilon <= cap) return CapStatus::WITHIN;
    return CapStatus::UNRESOLVED;
}

Sample sample(const Vector2 &a, const Vector2 &b, double t, const Target &target, SampleState &state) {
    const auto cached = state.cache.find(t);
    if (cached != state.cache.end()) return cached->second;
    if (state.evaluations >= state.budget) return {};
    const double x = double(a.x) + (double(b.x) - double(a.x)) * t;
    const double y = double(a.y) + (double(b.y) - double(a.y)) * t;
    double nearest_squared = INF_D;
    bool inside = false;
    Vector2 nearest_point;
    int64_t nearest_edge = -1;
    const int64_t root = state.use_boundary_pruning ? target.root : -1;
    std::vector<int64_t> pending{root};
    while (!pending.empty()) {
        const int64_t node_index = pending.back();
        pending.pop_back();
        int64_t first = 0;
        int64_t last = int64_t(target.edges.size());
        if (node_index >= 0) {
            const EdgeNode &node = target.tree[size_t(node_index)];
            const Bounds &bounds = node.bounds;
            const bool ray_can_cross = y >= bounds[1] - state.epsilon &&
                y <= bounds[3] + state.epsilon && x <= bounds[2] + state.epsilon;
            if (!ray_can_cross && std::isfinite(nearest_squared)) {
                const double gx = std::max(0.0, std::max(bounds[0] - x, x - bounds[2]));
                const double gy = std::max(0.0, std::max(bounds[1] - y, y - bounds[3]));
                const double guarded = std::sqrt(nearest_squared) + state.epsilon;
                if (gx * gx + gy * gy > guarded * guarded) {
                    ++state.sample_tree_prunes;
                    continue;
                }
            }
            if (node.left >= 0) {
                pending.push_back(node.right);
                pending.push_back(node.left);
                continue;
            }
            first = node.first;
            last = node.last;
        }
        for (int64_t edge_index = first; edge_index < last; ++edge_index) {
            ++state.sample_edge_tests;
            const Edge &edge = target.edges[size_t(edge_index)];
            const Vector2 &c = edge.a;
            const Vector2 &d = edge.b;
            const double dx = double(d.x) - double(c.x);
            const double dy = double(d.y) - double(c.y);
            const double ratio = clamp01(((x - double(c.x)) * dx + (y - double(c.y)) * dy) /
                (dx * dx + dy * dy));
            const double gap_x = x - (double(c.x) + ratio * dx);
            const double gap_y = y - (double(c.y) + ratio * dy);
            const double squared = gap_x * gap_x + gap_y * gap_y;
            if (squared < nearest_squared) {
                nearest_squared = squared;
                nearest_point = Vector2(real_t(double(c.x) + ratio * dx), real_t(double(c.y) + ratio * dy));
                nearest_edge = edge_index;
            }
            if ((double(c.y) > y) != (double(d.y) > y) &&
                    x < double(c.x) + dx * (y - double(c.y)) / dy) {
                inside = !inside;
            }
        }
    }
    const double depth = inside ? std::sqrt(nearest_squared) : 0.0;
    const Sample result{true, inside && nearest_squared > 0.0, depth};
    ++state.evaluations;
    if (depth > state.maximum_sampled_depth_m) {
        state.witness = {true, Vector2(real_t(x), real_t(y)), t, nearest_point, nearest_edge, depth};
    }
    state.maximum_sampled_depth_m = std::max(state.maximum_sampled_depth_m, depth);
    state.cache.emplace(t, result);
    return result;
}

Dictionary nearest_contact(const Vector2 &a, const Vector2 &b, const Target &target, double epsilon,
        const std::vector<Intersection> &intersections, bool use_boundary_pruning, WorkCounts &work) {
    double nearest = INF_D;
    NearestPair best_pair;
    int64_t best_edge = -1;
    std::vector<int64_t> tied_edges;
    const double coordinate_scale = std::max(target.coordinate_scale_m,
        std::max(std::max(std::abs(double(a.x)), std::abs(double(a.y))),
            std::max(std::abs(double(b.x)), std::abs(double(b.y)))));
    const double contact_epsilon = std::max(epsilon, coordinate_scale * 0.0000002);
    const Bounds skin_bounds = scalar_bounds(a, b);
    std::vector<int64_t> pending{use_boundary_pruning ? target.root : -1};
    while (!pending.empty()) {
        const int64_t node_index = pending.back();
        pending.pop_back();
        int64_t first = 0;
        int64_t last = int64_t(target.edges.size());
        if (node_index >= 0) {
            const EdgeNode &node = target.tree[size_t(node_index)];
            if (std::isfinite(nearest)) {
                ++work.contact_aabb_tests;
                const double guarded = nearest + contact_epsilon + epsilon;
                if (bounds_distance_squared(skin_bounds, node.bounds) > guarded * guarded) {
                    work.contact_aabb_prunes += node.last - node.first;
                    continue;
                }
            }
            if (node.left >= 0) {
                pending.push_back(node.right);
                pending.push_back(node.left);
                continue;
            }
            first = node.first;
            last = node.last;
        }
        for (int64_t index = first; index < last; ++index) {
            const Edge &edge = target.edges[size_t(index)];
            if (use_boundary_pruning && std::isfinite(nearest)) {
                ++work.contact_aabb_tests;
                const double lower_squared = bounds_distance_squared(skin_bounds, edge.bounds);
                const double guarded_nearest = nearest + contact_epsilon + epsilon;
                if (lower_squared > guarded_nearest * guarded_nearest) {
                    ++work.contact_aabb_prunes;
                    continue;
                }
            }
            ++work.contact_intersection_reuses;
            ++work.contact_nearest_tests;
            const NearestPair pair = nearest_pair(a, b, edge.a, edge.b, intersections[size_t(index)]);
            const double distance = std::sqrt(pair.distance_squared);
            if (distance < nearest - epsilon) {
                nearest = distance;
                tied_edges.clear();
                best_pair = pair;
                best_edge = index;
            }
            if (std::abs(distance - nearest) <= epsilon) tied_edges.push_back(index);
        }
    }
    Dictionary result;
    bool corner_ambiguous = false;
    if (best_edge >= 0) {
        const Edge &edge = target.edges[size_t(best_edge)];
        const Vector2 tangent = (edge.b - edge.a).normalized();
        corner_ambiguous = double(best_pair.target_point.distance_to(edge.a)) <= std::max(epsilon, CONTACT_EPS_M) ||
            double(best_pair.target_point.distance_to(edge.b)) <= std::max(epsilon, CONTACT_EPS_M);
        result["distance_m"] = nearest;
        result["skin_point_m"] = best_pair.skin_point;
        result["target_point_m"] = best_pair.target_point;
        result["target_edge_index"] = best_edge;
        result["target_edge_tangent"] = tangent;
        result["skin_segment_tangent"] = (b - a).normalized();
        result["target_outward_normal"] = Vector2(tangent.y, -tangent.x) * real_t(target.winding_sign);
        result["corner_ambiguous"] = corner_ambiguous;
    }
    TypedArray<int64_t> ties;
    for (const int64_t index : tied_edges) ties.append(index);
    result["tied_target_edge_indices"] = ties;
    result["tangent_ambiguous"] = corner_ambiguous || tied_edges.size() != 1;
    result["origin_id"] = target.origin_id;
    result["target_source_id"] = target.source_id;
    result["numeric_epsilon_m"] = contact_epsilon;
    result["distance_is_numeric_estimate"] = true;
    return result;
}

Dictionary segment_solve(const Dictionary &segment, const Target &target, double tolerance, double epsilon,
        int64_t budget, bool refine_after_cap, bool use_boundary_pruning, Dictionary &timings) {
    const auto phase_start = PhaseClock::now();
    const Vector2 a = segment["a"];
    const Vector2 b = segment["b"];
    const double cap = segment["max_inward_depth_m"];
    std::vector<double> cuts{0.0, 1.0};
    std::vector<Intersection> intersections(target.edges.size());
    std::vector<int64_t> candidates;
    if (use_boundary_pruning && target.root >= 0) {
        append_edge_candidates(target, target.root, scalar_bounds(a, b), epsilon * epsilon, 0, candidates);
    } else {
        candidates.reserve(target.edges.size());
        for (int64_t i = 0; i < int64_t(target.edges.size()); ++i) candidates.push_back(i);
    }
    for (const int64_t edge_index : candidates) {
        const Edge &edge = target.edges[size_t(edge_index)];
        const Intersection hit = intersection(a, b, edge.a, edge.b);
        intersections[size_t(edge_index)] = hit;
        if (!hit.valid) continue;
        cuts.push_back(clamp01(hit.t));
        if (hit.coincident) {
            cuts.push_back(clamp01(parameter(edge.a, a, b)));
            cuts.push_back(clamp01(parameter(edge.b, a, b)));
        }
    }
    std::sort(cuts.begin(), cuts.end());
    cuts.erase(std::unique(cuts.begin(), cuts.end()), cuts.end());
    const auto intersections_finished = PhaseClock::now();
    SampleState state;
    state.budget = budget;
    state.use_boundary_pruning = use_boundary_pruning;
    state.epsilon = epsilon;
    std::vector<DepthNode> nodes;
    int64_t pending_intervals = 0;
    const double length_m = scalar_distance(a, b);
    for (size_t index = 0; index + 1 < cuts.size(); ++index) {
        const double lo = cuts[index];
        const double hi = cuts[index + 1];
        const Sample middle = sample(a, b, (lo + hi) * 0.5, target, state);
        if (!middle.valid) {
            ++pending_intervals;
            continue;
        }
        if (!middle.inside) continue;
        ++state.inside_interval_count;
        const Sample first = sample(a, b, lo, target, state);
        const Sample last = sample(a, b, hi, target, state);
        if (!first.valid || !last.valid) {
            ++pending_intervals;
            continue;
        }
        nodes.push_back(depth_node(lo, hi, first.depth_m, middle.depth_m, last.depth_m, length_m));
    }
    DepthBounds bounds = depth_bounds(nodes, state, pending_intervals, target);
    CapStatus status = cap_status(bounds, cap, epsilon);
    while ((status == CapStatus::UNRESOLVED || refine_after_cap) &&
            bounds.upper_m - bounds.lower_m > tolerance && state.evaluations + 2 <= budget && pending_intervals == 0) {
        int64_t best = -1;
        double highest = -INF_D;
        for (size_t index = 0; index < nodes.size(); ++index) {
            if (nodes[index].upper_m > highest) {
                highest = nodes[index].upper_m;
                best = int64_t(index);
            }
        }
        if (best < 0) break;
        const DepthNode parent = nodes[size_t(best)];
        const double middle_t = (parent.lo + parent.hi) * 0.5;
        const Sample left = sample(a, b, (parent.lo + middle_t) * 0.5, target, state);
        const Sample right = sample(a, b, (middle_t + parent.hi) * 0.5, target, state);
        if (!left.valid || !right.valid || middle_t == parent.lo || middle_t == parent.hi) break;
        nodes[size_t(best)] = depth_node(parent.lo, middle_t, parent.first_m, left.depth_m, parent.middle_m, length_m);
        nodes.push_back(depth_node(middle_t, parent.hi, parent.middle_m, right.depth_m, parent.last_m, length_m));
        bounds = depth_bounds(nodes, state, pending_intervals, target);
        status = cap_status(bounds, cap, epsilon);
    }
    const double lower = std::max(bounds.lower_m - epsilon, 0.0);
    const double upper = bounds.upper_m + epsilon;
    Dictionary witness;
    if (state.witness.valid) {
        witness["skin_point_m"] = state.witness.skin_point;
        witness["skin_segment_t"] = state.witness.t;
        witness["nearest_target_point_m"] = state.witness.target_point;
        witness["target_edge_index"] = state.witness.edge_index;
        witness["sampled_depth_m"] = state.witness.depth_m;
        witness["origin_id"] = target.origin_id;
        witness["target_source_id"] = target.source_id;
        witness["witness_is_numeric_sample_not_exact_global_maximum"] = true;
        witness["skin_source_id"] = segment["source_id"];
    }
    WorkCounts work;
    const auto depth_finished = PhaseClock::now();
    Dictionary nearest = nearest_contact(a, b, target, epsilon, intersections, use_boundary_pruning, work);
    const auto nearest_finished = PhaseClock::now();
    timings["boundary_intersections_us"] = int64_t(std::chrono::duration_cast<std::chrono::microseconds>(
        intersections_finished - phase_start).count());
    timings["depth_sampling_refinement_us"] = int64_t(std::chrono::duration_cast<std::chrono::microseconds>(
        depth_finished - intersections_finished).count());
    timings["nearest_contact_us"] = int64_t(std::chrono::duration_cast<std::chrono::microseconds>(
        nearest_finished - depth_finished).count());
    work.intersection_tests = int64_t(candidates.size());
    work.sample_edge_tests = state.sample_edge_tests;
    work.sample_tree_prunes = state.sample_tree_prunes;
    Dictionary result;
    result["valid"] = true;
    result["source_id"] = segment["source_id"];
    result["origin_id"] = segment["origin_id"];
    result["max_inward_depth_m"] = cap;
    result["cap_status"] = StringName(status == CapStatus::WITHIN ? "within" :
        (status == CapStatus::EXCEEDS ? "exceeds" : "unresolved"));
    result["max_inward_depth_lower_m"] = lower;
    result["max_inward_depth_upper_m"] = upper;
    result["max_sampled_inward_depth_m"] = state.maximum_sampled_depth_m;
    result["geometric_bound_width_m"] = bounds.upper_m - bounds.lower_m;
    result["depth_bound_width_m"] = upper - lower;
    result["numeric_epsilon_m"] = epsilon;
    result["depth_bound_tolerance_m"] = tolerance;
    result["depth_tolerance_met"] = upper - lower <= tolerance;
    result["refine_depth_after_cap"] = refine_after_cap;
    result["use_boundary_pruning"] = use_boundary_pruning;
    result["work_counts"] = work.dictionary();
    result["depth_evaluations"] = state.evaluations;
    result["evaluation_budget"] = budget;
    result["budget_exhausted"] = (status == CapStatus::UNRESOLVED ||
        (refine_after_cap && bounds.upper_m - bounds.lower_m > tolerance)) && state.evaluations + 2 > budget;
    result["unmeasured_interval_count"] = pending_intervals;
    result["inside_interval_count"] = state.inside_interval_count;
    result["depth_lower_bound_witness"] = witness;
    result["contact"] = nearest;
    result["depth_metric"] = StringName("maximum_inward_signed_distance_over_entire_segment_bounded");
    result["actual_3d_grip_verified"] = false;
    return result;
}

Dictionary fail(const char *reason) {
    Dictionary result;
    result["valid"] = false;
    result["cap_status"] = StringName("unknown");
    result["reason"] = String(reason);
    result["details"] = Dictionary();
    result["whole_skin_clearance_verified"] = false;
    result["actual_3d_grip_verified"] = false;
    return result;
}

} // namespace

struct GripContactKernel::Impl {
    std::unordered_map<int64_t, Target> targets;
    int64_t next_handle = 1;
    Dictionary last_timings;
};

GripContactKernel::GripContactKernel() : impl_(std::make_unique<Impl>()) {}
GripContactKernel::~GripContactKernel() = default;

void GripContactKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("prepare_target", "prepared_target"), &GripContactKernel::prepare_target);
    ClassDB::bind_method(D_METHOD("evaluate_segment", "segment", "target_handle", "tolerance", "epsilon",
        "budget", "refine_after_cap", "use_boundary_pruning"), &GripContactKernel::evaluate_segment);
    ClassDB::bind_method(D_METHOD("last_phase_timings_us"), &GripContactKernel::last_phase_timings_us);
    ClassDB::bind_method(D_METHOD("release_target", "target_handle"), &GripContactKernel::release_target);
    ClassDB::bind_method(D_METHOD("clear_targets"), &GripContactKernel::clear_targets);
}

int64_t GripContactKernel::prepare_target(const Dictionary &prepared_target) {
    if (!bool(prepared_target.get("valid", false)) || !bool(prepared_target.get("complete", false)) ||
            StringName(prepared_target.get("revision", StringName())) != StringName("planar_skin_overlap_budget_v1") ||
            prepared_target.get("edges", Variant()).get_type() != Variant::ARRAY) {
        return 0;
    }
    Target target;
    target.origin_id = prepared_target.get("origin_id", StringName());
    target.source_id = prepared_target.get("source_id", StringName());
    target.coordinate_scale_m = double(prepared_target.get("coordinate_scale_m", -1.0));
    target.diameter_upper_m = double(prepared_target.get("diameter_upper_m", -1.0));
    target.winding_sign = double(prepared_target.get("winding_sign", 0.0));
    if (target.origin_id == StringName() || target.source_id == StringName() ||
            !std::isfinite(target.coordinate_scale_m) || target.coordinate_scale_m < 0.0 ||
            !std::isfinite(target.diameter_upper_m) || target.diameter_upper_m <= 0.0 ||
            !std::isfinite(target.winding_sign) || std::abs(target.winding_sign) != 1.0) return 0;
    const Array edges = prepared_target["edges"];
    if (edges.size() < 3) return 0;
    target.edges.reserve(size_t(edges.size()));
    for (int64_t i = 0; i < edges.size(); ++i) {
        if (edges[i].get_type() != Variant::ARRAY) return 0;
        const Array pair = edges[i];
        if (pair.size() != 2 || pair[0].get_type() != Variant::VECTOR2 || pair[1].get_type() != Variant::VECTOR2) return 0;
        const Vector2 a = pair[0];
        const Vector2 b = pair[1];
        if (!a.is_finite() || !b.is_finite() || a == b) return 0;
        target.edges.push_back({a, b, scalar_bounds(a, b)});
    }
    // Valid prepared targets use precisely this source-contiguous tree. Build
    // it once as typed native nodes rather than traversing Variant Dictionaries.
    const Variant tree_variant = prepared_target.get("edge_tree", Dictionary());
    if (tree_variant.get_type() != Variant::DICTIONARY) return 0;
    const Dictionary tree = tree_variant;
    if (!tree.is_empty()) target.root = edge_range(target, 0, int64_t(target.edges.size()));
    if (impl_->next_handle == std::numeric_limits<int64_t>::max()) return 0;
    const int64_t handle = impl_->next_handle++;
    impl_->targets.emplace(handle, std::move(target));
    return handle;
}

Dictionary GripContactKernel::evaluate_segment(const Dictionary &segment, int64_t target_handle,
        double tolerance, double epsilon, int64_t budget, bool refine_after_cap, bool use_boundary_pruning) {
    impl_->last_timings = Dictionary();
    const auto found = impl_->targets.find(target_handle);
    if (found == impl_->targets.end()) return fail("invalid_native_target_handle");
    const Target &target = found->second;
    if (StringName(segment.get("origin_id", StringName())) != target.origin_id ||
            StringName(segment.get("source_id", StringName())) == StringName()) {
        return fail("missing_or_mismatched_skin_origin_or_source");
    }
    if (segment.get("a", Variant()).get_type() != Variant::VECTOR2 ||
            segment.get("b", Variant()).get_type() != Variant::VECTOR2) return fail("missing_skin_endpoints");
    const Vector2 a = segment["a"];
    const Vector2 b = segment["b"];
    const double cap = double(segment.get("max_inward_depth_m", -1.0));
    if (!a.is_finite() || !b.is_finite() || a == b || !std::isfinite(cap) || cap < 0.0) {
        return fail("invalid_skin_segment_or_cap");
    }
    if (!std::isfinite(tolerance) || tolerance <= 0.0 || !std::isfinite(epsilon) || epsilon < 0.0 ||
            budget < 3 || budget > 65536) return fail("invalid_depth_bound_configuration");
    return segment_solve(segment, target, tolerance, epsilon, budget, refine_after_cap, use_boundary_pruning,
        impl_->last_timings);
}

Dictionary GripContactKernel::last_phase_timings_us() const {
    return impl_->last_timings.duplicate();
}

bool GripContactKernel::release_target(int64_t target_handle) {
    return impl_->targets.erase(target_handle) != 0;
}

void GripContactKernel::clear_targets() {
    impl_->targets.clear();
    // Handles never recycle: a stale caller handle cannot alias a later target.
}

} // namespace godot
