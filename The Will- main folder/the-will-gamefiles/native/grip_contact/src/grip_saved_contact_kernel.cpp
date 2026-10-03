#include "grip_saved_contact_kernel.h"
#include "grip_contact_kernel.h"
#include "grip_ordered_target.h"

#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <deque>
#include <utility>
#include <vector>

namespace godot {
namespace {

constexpr size_t MAX_SECTIONS = 64;
constexpr double CONTACT_EPS_M = 0.000001;
constexpr const char *KINDS[] = {"handle", "digit_target", "palm_target"};
constexpr const char *WORK_FIELDS[] = {"intersection_tests", "contact_intersection_reuses",
    "contact_nearest_tests", "contact_aabb_tests", "contact_aabb_prunes", "sample_edge_tests", "sample_tree_prunes"};
using Clock = std::chrono::steady_clock;
using ClockPoint = Clock::time_point;
using Box = std::array<double, 4>;

int64_t elapsed_us(ClockPoint start) {
    return int64_t(std::chrono::duration_cast<std::chrono::microseconds>(Clock::now() - start).count());
}

double elapsed_ms(ClockPoint start) { return double(elapsed_us(start)) / 1000.0; }

bool text_type(const Variant &value) {
    return value.get_type() == Variant::STRING || value.get_type() == Variant::STRING_NAME;
}

bool named(const Variant &value) { return text_type(value) && !String(value).is_empty(); }

bool text_equals(const Variant &value, const StringName &expected) {
    return text_type(value) && StringName(value) == expected;
}

bool numeric(const Variant &value) {
    return value.get_type() == Variant::FLOAT || value.get_type() == Variant::INT || value.get_type() == Variant::BOOL;
}

bool numeric_value(const Variant &value, double &out) {
    if (numeric(value)) {
        out = double(value);
        return true;
    }
    // float(String) is supported by GDScript. Other malformed Variants are
    // rejected rather than reaching an unchecked C++ conversion or indexing.
    if (value.get_type() == Variant::STRING) {
        out = String(value).to_float();
        return true;
    }
    return false;
}

template <typename T> bool same_bits(T a, T b) { return std::memcmp(&a, &b, sizeof(T)) == 0; }

bool vector_bits(const Vector2 &a, const Vector2 &b) {
    return same_bits(a.x, b.x) && same_bits(a.y, b.y);
}

// Hashing only selects candidates. This separate comparison never uses
// approximate float/Vector equality and never accepts a hash collision as an
// identity. Unsupported metadata types conservatively prevent a cache hit.
bool exact_equal(const Variant &a, const Variant &b, int depth = 0) {
    if (a.get_type() != b.get_type() || depth > 128) return false;
    switch (a.get_type()) {
        case Variant::NIL: return true;
        case Variant::BOOL: return bool(a) == bool(b);
        case Variant::INT: return int64_t(a) == int64_t(b);
        case Variant::FLOAT: return same_bits(double(a), double(b));
        case Variant::STRING: return String(a) == String(b);
        case Variant::STRING_NAME: return StringName(a) == StringName(b);
        case Variant::VECTOR2: return vector_bits(Vector2(a), Vector2(b));
        case Variant::PACKED_VECTOR2_ARRAY: {
            const PackedVector2Array first = a, second = b;
            if (first.size() != second.size()) return false;
            for (int64_t i = 0; i < first.size(); ++i) if (!vector_bits(first[i], second[i])) return false;
            return true;
        }
        case Variant::PACKED_FLOAT64_ARRAY: {
            const PackedFloat64Array first = a, second = b;
            if (first.size() != second.size()) return false;
            for (int64_t i = 0; i < first.size(); ++i) if (!same_bits(first[i], second[i])) return false;
            return true;
        }
        case Variant::ARRAY: {
            const Array first = a, second = b;
            // Compare the container schema through the engine's exact
            // builtin/class/script-reference check. get_typed_script() wraps
            // an absent Ref<Script> as OBJECT(null), not NIL; passing that to
            // the data comparator would conservatively reject every array.
            if (first.size() != second.size() || !first.is_same_typed(second)) return false;
            for (int64_t i = 0; i < first.size(); ++i) if (!exact_equal(first[i], second[i], depth + 1)) return false;
            return true;
        }
        case Variant::DICTIONARY: {
            const Dictionary first = a, second = b;
            if (first.size() != second.size() || !first.is_same_typed(second)) return false;
            const Array first_keys = first.keys(), second_keys = second.keys();
            for (int64_t i = 0; i < first_keys.size(); ++i) {
                if (!exact_equal(first_keys[i], second_keys[i], depth + 1) ||
                        !exact_equal(first[first_keys[i]], second[second_keys[i]], depth + 1)) return false;
            }
            return true;
        }
        default: return false;
    }
}

Dictionary fail(const char *reason, const Dictionary &detail = Dictionary()) {
    Dictionary out;
    out["valid"] = false;
    out["reason"] = String(reason);
    out["detail"] = detail;
    out["production_pose_written"] = false;
    out["grip_accepted"] = false;
    return out;
}

Dictionary depth_fail(const char *reason, const Dictionary &details = Dictionary()) {
    Dictionary out;
    out["valid"] = false;
    out["cap_status"] = StringName("unknown");
    out["reason"] = String(reason);
    out["details"] = details;
    out["whole_skin_clearance_verified"] = false;
    out["actual_3d_grip_verified"] = false;
    return out;
}

Dictionary index_detail(int64_t index) {
    Dictionary out;
    out["segment_index"] = index;
    return out;
}

struct BusyScope {
    bool &flag;
    explicit BusyScope(bool &value) : flag(value) { flag = true; }
    ~BusyScope() { flag = false; }
};

struct WitnessEdge { Vector2 a; Vector2 b; };

struct WitnessTarget {
    std::vector<WitnessEdge> edges;
    Variant origin;
    Variant source;
    double winding = 0.0;
    double scale = 0.0;
};

Box bounds_for(const Vector2 &a, const Vector2 &b) {
    // Godot minf/maxf choose their second operand on ties, including signed
    // zero. Preserve those bits when checking a canonical prepared packet.
    return {MIN(double(a.x), double(b.x)), MIN(double(a.y), double(b.y)),
        MAX(double(a.x), double(b.x)), MAX(double(a.y), double(b.y))};
}

bool matches_box(const Variant &value, const Box &box) {
    if (value.get_type() != Variant::PACKED_FLOAT64_ARRAY) return false;
    const PackedFloat64Array given = value;
    if (given.size() != 4) return false;
    for (int i = 0; i < 4; ++i) if (!same_bits(given[i], box[size_t(i)])) return false;
    return true;
}

bool valid_tree(const Variant &value, const std::vector<Box> &boxes, int64_t first, int64_t last, Box &out) {
    if (value.get_type() != Variant::DICTIONARY) return false;
    const Dictionary node = value;
    const Variant begin = node.get("first", Variant()), end = node.get("last", Variant());
    if (begin.get_type() != Variant::INT || end.get_type() != Variant::INT ||
            int64_t(begin) != first || int64_t(end) != last) return false;
    if (last - first <= 8) {
        if (node.has("left") || node.has("right")) return false;
        out = boxes[size_t(first)];
        for (int64_t i = first + 1; i < last; ++i) {
            out[0] = MIN(out[0], boxes[size_t(i)][0]); out[1] = MIN(out[1], boxes[size_t(i)][1]);
            out[2] = MAX(out[2], boxes[size_t(i)][2]); out[3] = MAX(out[3], boxes[size_t(i)][3]);
        }
    } else {
        Box left, right;
        const int64_t middle = (first + last) >> 1;
        if (!valid_tree(node.get("left", Variant()), boxes, first, middle, left) ||
                !valid_tree(node.get("right", Variant()), boxes, middle, last, right)) return false;
        out = {MIN(left[0], right[0]), MIN(left[1], right[1]),
            MAX(left[2], right[2]), MAX(left[3], right[3])};
    }
    return matches_box(node.get("bounds", Variant()), out);
}

// Check internal packet consistency without repeating ordered-polygon
// self-intersection validation. prepare() already owns that topology check.
// This prevents the underlying kernel from silently reconstructing malformed
// bounds/tree data supplied in a mutated caller packet.
bool canonical_target(const Dictionary &target, WitnessTarget &view) {
    const Variant polygon_value = target.get("polygon", Variant());
    const Variant edges_value = target.get("edges", Variant());
    const Variant bounds_value = target.get("edge_bounds", Variant());
    if (polygon_value.get_type() != Variant::PACKED_VECTOR2_ARRAY || edges_value.get_type() != Variant::ARRAY ||
            bounds_value.get_type() != Variant::ARRAY || !named(target.get("origin_id", Variant())) ||
            !named(target.get("source_id", Variant()))) return false;
    const PackedVector2Array polygon = polygon_value;
    const Array edges = edges_value, given_bounds = bounds_value;
    if (polygon.size() < 3 || edges.size() != polygon.size() || given_bounds.size() != edges.size()) return false;
    std::vector<Box> boxes;
    boxes.reserve(size_t(edges.size()));
    WitnessTarget candidate;
    candidate.edges.reserve(size_t(edges.size()));
    double scale = 0.0;
    double twice_area = 0.0;
    Vector2 minimum(INFINITY, INFINITY), maximum(-INFINITY, -INFINITY);
    for (int64_t i = 0; i < edges.size(); ++i) {
        if (edges[i].get_type() != Variant::ARRAY) return false;
        const Array pair = edges[i];
        if (pair.size() != 2 || pair[0].get_type() != Variant::VECTOR2 || pair[1].get_type() != Variant::VECTOR2) return false;
        const Vector2 a = pair[0], b = pair[1];
        if (!a.is_finite() || !b.is_finite() || a == b || !vector_bits(a, polygon[i]) ||
                !vector_bits(b, polygon[(i + 1) % polygon.size()])) return false;
        const Box box = bounds_for(a, b);
        if (!matches_box(given_bounds[i], box)) return false;
        boxes.push_back(box);
        candidate.edges.push_back({a, b});
        scale = std::max(scale, std::max(std::abs(double(a.x)), std::abs(double(a.y))));
        minimum = minimum.min(a); maximum = maximum.max(a);
        twice_area += double(a.x) * double(b.y) - double(b.x) * double(a.y);
    }
    const double dx = double(maximum.x) - double(minimum.x), dy = double(maximum.y) - double(minimum.y);
    const double diameter = std::sqrt(dx * dx + dy * dy);
    if (!std::isfinite(twice_area) || twice_area == 0.0) return false;
    const double winding = twice_area > 0.0 ? 1.0 : -1.0;
    for (const char *field : {"coordinate_scale_m", "diameter_upper_m", "winding_sign"}) {
        if (target.get(field, Variant()).get_type() != Variant::FLOAT) return false;
    }
    if (!same_bits(double(target["coordinate_scale_m"]), scale) ||
            !same_bits(double(target["diameter_upper_m"]), diameter) || !same_bits(double(target["winding_sign"]), winding)) return false;
    const Variant tree_value = target.get("edge_tree", Variant());
    if (tree_value.get_type() != Variant::DICTIONARY) return false;
    if (edges.size() < 64) {
        if (!Dictionary(tree_value).is_empty()) return false;
    } else {
        Box root;
        if (!valid_tree(tree_value, boxes, 0, edges.size(), root)) return false;
    }
    candidate.origin = target["origin_id"];
    candidate.source = target["source_id"];
    candidate.scale = scale;
    candidate.winding = winding;
    view = std::move(candidate);
    return true;
}

struct PreparedEntry {
    int64_t hash = 0;
    Array identity;
    Dictionary packet;
};

struct NativeEntry {
    int64_t hash = 0;
    Array targets;
    std::array<int64_t, 3> handles{};
    std::array<WitnessTarget, 3> views;
};

struct Stats {
    int64_t batch_calls = 0;
    int64_t depth_batches = 0;
    int64_t logical_segments = 0;
    int64_t actual_segments = 0;
    int64_t actual_evaluations = 0;
    int64_t segment_us = 0;
    int64_t target_preparations = 0;
    int64_t target_preparation_us = 0;
    int64_t native_section_hits = 0;
    int64_t native_section_misses = 0;
    int64_t native_section_evictions = 0;
    int64_t prepared_hits = 0;
    int64_t prepared_misses = 0;
    std::array<int64_t, 7> work{};
};

bool strictly_exterior(const Dictionary &measured) {
    const Dictionary contact = measured["contact"];
    const double guard = std::max(double(measured["numeric_epsilon_m"]), double(contact.get("numeric_epsilon_m", 0.0)));
    const double distance = double(contact.get("distance_m", INFINITY));
    return int64_t(measured["inside_interval_count"]) == 0 && int64_t(measured["unmeasured_interval_count"]) == 0 &&
        double(measured["max_sampled_inward_depth_m"]) == 0.0 && Dictionary(measured["depth_lower_bound_witness"]).is_empty() &&
        std::isfinite(distance) && distance > guard;
}

double segment_parameter(const Vector2 &point, const Vector2 &a, const Vector2 &b) {
    const double dx = double(b.x) - double(a.x), dy = double(b.y) - double(a.y);
    return ((double(point.x) - double(a.x)) * dx + (double(point.y) - double(a.y)) * dy) / (dx * dx + dy * dy);
}

Dictionary witness(const Dictionary &segment, const Dictionary &measured, const WitnessTarget &target) {
    Dictionary chosen = measured["contact"];
    double gap = double(chosen.get("distance_m", INFINITY));
    bool deepest = false;
    const Dictionary lower_witness = measured["depth_lower_bound_witness"];
    if (double(measured["max_sampled_inward_depth_m"]) > 0.0 && !lower_witness.is_empty()) {
        chosen = lower_witness;
        gap = -double(measured["max_sampled_inward_depth_m"]);
        deepest = true;
    }
    const int64_t index = int64_t(chosen.get("target_edge_index", -1));
    if (index < 0 || index >= int64_t(target.edges.size())) return fail("witness_edge_missing");
    const Variant skin_value = chosen.get("skin_point_m", Variant());
    const Variant target_value = chosen.get(deepest ? "nearest_target_point_m" : "target_point_m", Variant());
    if (skin_value.get_type() != Variant::VECTOR2 || target_value.get_type() != Variant::VECTOR2) return fail("witness_point_missing");
    const WitnessEdge &edge = target.edges[size_t(index)];
    const Vector2 tangent = (edge.b - edge.a).normalized();
    const Vector2 outward = Vector2(tangent.y, -tangent.x) * real_t(target.winding);
    const Vector2 skin_point = skin_value, target_point = target_value;
    const double parameter = segment_parameter(skin_point, segment["a"], segment["b"]);
    const double epsilon = std::max(double(measured["numeric_epsilon_m"]), CONTACT_EPS_M);
    Array ties = Array(chosen.get("tied_target_edge_indices", Array())).duplicate();
    const double distance = double(skin_point.distance_to(target_point));
    Geometry2D *geometry = Geometry2D::get_singleton();
    if (geometry == nullptr) return fail("geometry_query_unavailable");
    if (deepest) {
        ties.clear();
        for (size_t candidate = 0; candidate < target.edges.size(); ++candidate) {
            const WitnessEdge &endpoints = target.edges[candidate];
            const Vector2 nearest = geometry->get_closest_point_to_segment(skin_point, endpoints.a, endpoints.b);
            if (std::abs(double(skin_point.distance_to(nearest)) - distance) <= epsilon) ties.append(int64_t(candidate));
        }
    }
    const bool corner = double(target_point.distance_to(edge.a)) <= epsilon || double(target_point.distance_to(edge.b)) <= epsilon;
    const double gradient_epsilon = std::max(double(measured["numeric_epsilon_m"]), std::max(target.scale * 0.0000002, 0.000000000001));
    TypedArray<Vector2> nearest_points;
    std::vector<Vector2> nearest_normals;
    for (int64_t i = 0; i < ties.size(); ++i) {
        const int64_t candidate = int64_t(ties[i]);
        if (candidate < 0 || candidate >= int64_t(target.edges.size())) return fail("witness_edge_missing");
        const WitnessEdge &endpoints = target.edges[size_t(candidate)];
        const Vector2 nearest = geometry->get_closest_point_to_segment(skin_point, endpoints.a, endpoints.b);
        if (std::abs(double(skin_point.distance_to(nearest)) - distance) > gradient_epsilon) continue;
        bool already_present = false;
        for (int64_t j = 0; j < nearest_points.size(); ++j) {
            const Vector2 point = nearest_points[j];
            if (double(point.distance_to(nearest)) <= gradient_epsilon) { already_present = true; break; }
        }
        if (!already_present) nearest_points.append(nearest);
        const Vector2 direction = (endpoints.b - endpoints.a).normalized();
        nearest_normals.push_back(Vector2(direction.y, -direction.x) * real_t(target.winding));
    }
    Vector2 gradient = outward;
    bool gradient_ambiguous = nearest_points.size() != 1;
    if (distance > gradient_epsilon) {
        gradient = gap < 0.0 ? (target_point - skin_point).normalized() : (skin_point - target_point).normalized();
    } else {
        for (const Vector2 &normal : nearest_normals) {
            if (double(normal.distance_to(outward)) > 0.000001) gradient_ambiguous = true;
        }
    }
    Dictionary out;
    out["valid"] = true;
    out["source_id"] = segment["source_id"];
    out["origin_id"] = target.origin;
    out["target_source_id"] = target.source;
    out["skin_point_m"] = skin_point;
    out["target_point_m"] = target_point;
    out["skin_segment_t"] = std::min(std::max(parameter, 0.0), 1.0);
    out["target_edge_index"] = index;
    out["target_outward_normal"] = gradient;
    out["target_edge_outward_normal"] = outward;
    out["target_edge_tangent"] = tangent;
    out["signed_clearance_m"] = gap;
    out["witness_kind"] = StringName(deepest ? "deepest_sampled_inside_lower_bound" : "nearest_boundary");
    out["corner_ambiguous"] = corner;
    out["tied_target_edge_indices"] = ties;
    out["tangent_ambiguous"] = corner || ties.size() != 1;
    out["gradient_ambiguous"] = gradient_ambiguous;
    out["gradient_nearest_target_points"] = nearest_points;
    out["numeric_epsilon_m"] = measured["numeric_epsilon_m"];
    out["depth_lower_m"] = measured["max_inward_depth_lower_m"];
    out["depth_upper_m"] = measured["max_inward_depth_upper_m"];
    out["cap_status"] = measured["cap_status"];
    out["depth_is_bounded_not_exact"] = true;
    return out;
}

Dictionary depth_batch(GripContactKernel &kernel, NativeEntry &entry, size_t kind, const Array &segments,
        const StringName &origin_id, const Dictionary &config, Stats &stats) {
    ++stats.depth_batches;
    if (entry.targets[int64_t(kind)].get_type() != Variant::DICTIONARY) return depth_fail("invalid_prepared_target");
    const Dictionary target = entry.targets[int64_t(kind)];
    if (!bool(target.get("valid", false)) || !text_equals(target.get("revision", Variant()), StringName("planar_skin_overlap_budget_v1")) ||
            !bool(target.get("complete", false))) return depth_fail("invalid_prepared_target");
    if (origin_id == StringName() || !text_equals(target.get("origin_id", Variant()), origin_id)) return depth_fail("missing_or_mismatched_plane_origin");
    if (segments.is_empty()) return depth_fail("missing_skin_segments");
    double tolerance = 0.0, requested_epsilon = 0.0, budget_number = 0.0;
    if (!numeric_value(config.get("depth_bound_tolerance_m", 0.000001), tolerance) ||
            !numeric_value(config.get("numeric_epsilon_m", 0.000000001), requested_epsilon) ||
            !numeric_value(config.get("max_evaluations_per_segment", 256), budget_number) ||
            !std::isfinite(tolerance) || tolerance <= 0.0 || !std::isfinite(requested_epsilon) || requested_epsilon < 0.0 ||
            !std::isfinite(budget_number) || budget_number < 3.0 || budget_number >= 65537.0) return depth_fail("invalid_depth_bound_configuration");
    const int64_t budget = int64_t(budget_number);
    const bool refine = bool(config.get("refine_depth_after_cap", false));
    const bool prune = bool(config.get("use_boundary_pruning", true));
    if (entry.handles[kind] == 0) {
        const ClockPoint started = Clock::now();
        ++stats.target_preparations;
        const bool consistent = canonical_target(target, entry.views[kind]);
        if (consistent) entry.handles[kind] = kernel.prepare_target(target);
        stats.target_preparation_us += elapsed_us(started);
        if (!consistent || entry.handles[kind] == 0) return depth_fail("noncanonical_prepared_target_packet");
    }
    Array records;
    bool all_within = true, any_exceeds = false;
    int64_t evaluations = 0;
    std::array<int64_t, 7> work{};
    for (int64_t index = 0; index < segments.size(); ++index) {
        if (segments[index].get_type() != Variant::DICTIONARY) return depth_fail("invalid_skin_segment", index_detail(index));
        const Dictionary segment = segments[index];
        if (!text_equals(segment.get("origin_id", Variant()), origin_id) || !named(segment.get("source_id", Variant()))) {
            return depth_fail("missing_or_mismatched_skin_origin_or_source", index_detail(index));
        }
        if (segment.get("a", Variant()).get_type() != Variant::VECTOR2 || segment.get("b", Variant()).get_type() != Variant::VECTOR2) {
            return depth_fail("missing_skin_endpoints", index_detail(index));
        }
        const Vector2 a = segment["a"], b = segment["b"];
        double cap = -1.0;
        if (!numeric_value(segment.get("max_inward_depth_m", -1.0), cap) || !a.is_finite() || !b.is_finite() || a == b ||
                !std::isfinite(cap) || cap < 0.0) return depth_fail("invalid_skin_segment_or_cap", index_detail(index));
        const double scale = std::max(entry.views[kind].scale,
            std::max(std::max(std::abs(double(a.x)), std::abs(double(a.y))), std::max(std::abs(double(b.x)), std::abs(double(b.y)))));
        const double epsilon = std::max(requested_epsilon, std::max(1.0e-12, scale * 1.0e-12));
        const ClockPoint started = Clock::now();
        Dictionary measured = kernel.evaluate_segment(segment, entry.handles[kind], tolerance, epsilon, budget, refine, prune);
        stats.segment_us += elapsed_us(started);
        ++stats.actual_segments;
        ++stats.logical_segments;
        if (!bool(measured.get("valid", false))) return measured;
        measured["segment_index"] = index;
        records.append(measured);
        all_within = all_within && text_equals(measured["cap_status"], StringName("within"));
        any_exceeds = any_exceeds || text_equals(measured["cap_status"], StringName("exceeds"));
        evaluations += int64_t(measured["depth_evaluations"]);
        stats.actual_evaluations += int64_t(measured["depth_evaluations"]);
        const Dictionary measured_work = measured["work_counts"];
        for (size_t i = 0; i < work.size(); ++i) {
            work[i] += int64_t(measured_work[WORK_FIELDS[i]]);
            stats.work[i] += int64_t(measured_work[WORK_FIELDS[i]]);
        }
    }
    Dictionary work_packet;
    for (size_t i = 0; i < work.size(); ++i) work_packet[WORK_FIELDS[i]] = work[i];
    Dictionary out;
    out["valid"] = true;
    out["revision"] = StringName("planar_skin_overlap_budget_v1");
    out["origin_id"] = origin_id;
    out["target_source_id"] = target["source_id"];
    out["segments"] = records;
    out["cap_status"] = StringName(any_exceeds ? "exceeds" : (all_within ? "within" : "unresolved"));
    out["all_segments_within_cap"] = all_within;
    out["any_segment_exceeds_cap"] = any_exceeds;
    out["depth_evaluations"] = evaluations;
    out["metric_units"] = StringName("meters");
    out["refine_depth_after_cap"] = refine;
    out["use_boundary_pruning"] = prune;
    out["work_counts"] = work_packet;
    out["acceptance_scope"] = StringName("supplied_2d_segments_against_one_polygon_only");
    out["whole_skin_clearance_verified"] = false;
    out["actual_3d_grip_verified"] = false;
    return out;
}

} // namespace

struct GripSavedContactKernel::Impl {
    Ref<GripContactKernel> kernel;
    std::deque<PreparedEntry> prepared;
    std::deque<NativeEntry> native;
    StringName acquisition_id;
    bool busy = false;
    Stats stats;

    Impl() { kernel.instantiate(); }

    void clear() {
        kernel->clear_targets();
        prepared.clear();
        native.clear();
        acquisition_id = StringName();
        stats = Stats();
    }

    NativeEntry &intern(const Dictionary &packet) {
        Array targets;
        for (const char *kind : KINDS) targets.append(packet.get(kind, Variant()));
        const int64_t hash = targets.hash();
        for (NativeEntry &entry : native) {
            if (entry.hash == hash && exact_equal(entry.targets, targets)) {
                ++stats.native_section_hits;
                return entry;
            }
        }
        ++stats.native_section_misses;
        if (native.size() >= MAX_SECTIONS) {
            for (const int64_t handle : native.front().handles) if (handle != 0) kernel->release_target(handle);
            native.pop_front();
            ++stats.native_section_evictions;
        }
        NativeEntry entry;
        entry.hash = hash;
        entry.targets = targets.duplicate(true);
        native.push_back(std::move(entry));
        return native.back();
    }
};

GripSavedContactKernel::GripSavedContactKernel() : impl_(std::make_unique<Impl>()) {}
GripSavedContactKernel::~GripSavedContactKernel() = default;

void GripSavedContactKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("begin_acquisition", "identity"), &GripSavedContactKernel::begin_acquisition);
    ClassDB::bind_method(D_METHOD("reset"), &GripSavedContactKernel::reset);
    ClassDB::bind_method(D_METHOD("prepare", "section"), &GripSavedContactKernel::prepare);
    ClassDB::bind_method(D_METHOD("evaluate", "prepared", "segments", "origin_id", "depth_config"), &GripSavedContactKernel::evaluate);
    ClassDB::bind_method(D_METHOD("statistics"), &GripSavedContactKernel::statistics);
}

bool GripSavedContactKernel::begin_acquisition(const StringName &identity) {
    if (impl_->busy || identity == StringName()) return false;
    impl_->clear();
    impl_->acquisition_id = identity;
    return true;
}

bool GripSavedContactKernel::reset() {
    if (impl_->busy) return false;
    impl_->clear();
    return true;
}

Dictionary GripSavedContactKernel::prepare(const Dictionary &section) {
    if (impl_->busy) return fail("native_saved_contact_busy");
    BusyScope active(impl_->busy);
    const ClockPoint started = Clock::now();
    const Variant origin_value = section.get("origin_id", StringName());
    if (!named(origin_value)) return fail("missing_named_saved_section");
    const StringName origin = origin_value;
    const Variant center_value = section.get("center", Variant());
    if (origin == StringName("RL_BoneRoot") || center_value.get_type() != Variant::VECTOR2 ||
            !Vector2(center_value).is_finite()) return fail("missing_named_saved_section");
    Array identity;
    identity.append(StringName("saved_wrapper_skin_contact_v1"));
    identity.append(origin);
    identity.append(center_value);
    for (const char *name : KINDS) {
        const StringName kind(name);
        const Variant value = section.get(kind, Variant());
        Dictionary detail;
        detail["kind"] = kind;
        if (value.get_type() != Variant::DICTIONARY) return fail("incomplete_saved_section_surface", detail);
        const Dictionary surface = value;
        if (!bool(surface.get("valid", false)) || !bool(surface.get("complete", false))) return fail("incomplete_saved_section_surface", detail);
        if (!text_equals(surface.get("origin_id", Variant()), origin) ||
                surface.get("polygon", Variant()).get_type() != Variant::PACKED_VECTOR2_ARRAY) {
            return fail("saved_section_surface_origin_or_polygon_mismatch", detail);
        }
        const Variant source = surface.get("source_id", Variant());
        if (!named(source)) return fail("saved_section_surface_source_missing", detail);
        Array item;
        item.append(kind); item.append(source); item.append(surface["polygon"]);
        identity.append(item);
    }
    const int64_t hash = identity.hash();
    for (const PreparedEntry &entry : impl_->prepared) {
        if (entry.hash == hash && exact_equal(entry.identity, identity)) {
            ++impl_->stats.prepared_hits;
            Dictionary hit = entry.packet.duplicate(true);
            hit["cache_hit"] = true;
            hit["preparation_ms"] = elapsed_ms(started);
            return hit;
        }
    }
    ++impl_->stats.prepared_misses;
    Dictionary prepared;
    prepared["valid"] = true;
    prepared["revision"] = StringName("saved_wrapper_skin_contact_v1");
    prepared["origin_id"] = origin;
    prepared["center"] = center_value;
    prepared["center_origin_id"] = origin;
    prepared["metric_units"] = StringName("meters");
    prepared["cache_hit"] = false;
    prepared["wrapper_generated"] = false;
    prepared["target_offset_applied"] = false;
    prepared["production_pose_written"] = false;
    for (const char *name : KINDS) {
        const StringName kind(name);
        const Dictionary source = section[kind];
        const Dictionary target = prepare_grip_ordered_target(source["polygon"], origin, StringName(source["source_id"]), true);
        if (!bool(target.get("valid", false))) {
            Dictionary detail;
            detail["kind"] = kind; detail["result"] = target;
            return fail("saved_section_target_invalid", detail);
        }
        prepared[kind] = target;
    }
    if (impl_->prepared.size() >= MAX_SECTIONS) impl_->prepared.pop_front();
    impl_->prepared.push_back({hash, identity.duplicate(true), prepared.duplicate(true)});
    prepared["preparation_ms"] = elapsed_ms(started);
    return prepared;
}

Dictionary GripSavedContactKernel::evaluate(const Dictionary &prepared, const Array &segments,
        const StringName &origin_id, const Dictionary &depth_config) {
    if (impl_->busy) return fail("native_saved_contact_busy");
    BusyScope active(impl_->busy);
    const ClockPoint started = Clock::now();
    ++impl_->stats.batch_calls;
    if (!bool(prepared.get("valid", false)) || !text_equals(prepared.get("revision", Variant()), StringName("saved_wrapper_skin_contact_v1")) ||
            !text_equals(prepared.get("origin_id", Variant()), origin_id)) return fail("invalid_prepared_saved_wrapper_contact");
    Array query_segments;
    for (int64_t i = 0; i < segments.size(); ++i) {
        if (segments[i].get_type() != Variant::DICTIONARY) return fail("invalid_skin_segment");
        const Dictionary source = segments[i];
        double cap = -1.0;
        if (!numeric_value(source.get("max_inward_depth_m", -1.0), cap) || !std::isfinite(cap) || cap < 0.0) return fail("invalid_skin_segment_or_cap");
        Dictionary query = source.duplicate(false);
        if (bool(source.get("allowance_unassigned", true))) query["max_inward_depth_m"] = 0.0;
        query_segments.append(query);
    }
    NativeEntry &entry = impl_->intern(prepared);
    const Dictionary material = depth_batch(*impl_->kernel.ptr(), entry, 0, query_segments, origin_id, depth_config, impl_->stats);
    if (!bool(material.get("valid", false))) return fail("saved_handle_material_measurement_failed", material);
    const double material_ms = elapsed_ms(started);
    const ClockPoint guide_started = Clock::now();
    std::array<Array, 2> groups;
    std::array<std::vector<int64_t>, 2> indices;
    for (int64_t i = 0; i < segments.size(); ++i) {
        const Dictionary segment = segments[i];
        const size_t group = bool(segment.get("palm_owned", false)) ? 1 : 0;
        groups[group].append(query_segments[i]);
        indices[group].push_back(i);
    }
    std::vector<Dictionary> guide_measurements(size_t(segments.size()));
    std::vector<size_t> guide_kinds(size_t(segments.size()));
    int64_t guide_evaluations = 0;
    for (size_t group = 0; group < groups.size(); ++group) {
        if (groups[group].is_empty()) continue;
        const Dictionary measured = depth_batch(*impl_->kernel.ptr(), entry, group + 1, groups[group], origin_id, depth_config, impl_->stats);
        if (!bool(measured.get("valid", false))) {
            Dictionary detail;
            detail["kind"] = StringName(KINDS[group + 1]); detail["result"] = measured;
            return fail("saved_wrapper_guide_measurement_failed", detail);
        }
        guide_evaluations += int64_t(measured["depth_evaluations"]);
        const Array results = measured["segments"];
        for (size_t local = 0; local < indices[group].size(); ++local) {
            const size_t original = size_t(indices[group][local]);
            guide_measurements[original] = results[int64_t(local)];
            guide_kinds[original] = group + 1;
        }
    }
    const double guide_ms = elapsed_ms(guide_started);
    const ClockPoint witnesses_started = Clock::now();
    Array records;
    const Array material_segments = material["segments"];
    int64_t unresolved = 0, exceeding = 0;
    bool material_safe = true, guide_safe = true;
    for (int64_t index = 0; index < segments.size(); ++index) {
        const Dictionary segment = segments[index];
        const Dictionary &guide = guide_measurements[size_t(index)];
        const Dictionary actual = material_segments[index];
        const size_t kind = guide_kinds[size_t(index)];
        const Dictionary guide_witness = witness(segment, guide, entry.views[kind]);
        const Dictionary material_witness = witness(segment, actual, entry.views[0]);
        if (!bool(guide_witness.get("valid", false)) || !bool(material_witness.get("valid", false))) {
            Dictionary detail;
            detail["index"] = index; detail["guide"] = guide_witness; detail["material"] = material_witness;
            return fail("saved_contact_witness_invalid", detail);
        }
        unresolved += int64_t(text_equals(actual["cap_status"], StringName("unresolved")));
        exceeding += int64_t(text_equals(actual["cap_status"], StringName("exceeds")));
        const bool material_exterior = strictly_exterior(actual), guide_exterior = strictly_exterior(guide);
        const bool assigned = !bool(segment.get("allowance_unassigned", true));
        const bool material_edge_safe = (assigned && text_equals(actual["cap_status"], StringName("within"))) || material_exterior;
        const bool guide_edge_safe = (assigned && text_equals(guide["cap_status"], StringName("within"))) || guide_exterior;
        material_safe = material_safe && material_edge_safe;
        guide_safe = guide_safe && guide_edge_safe;
        Dictionary record;
        record["segment"] = segment.duplicate(true);
        record["witness"] = guide_witness;
        record["guide_kind"] = StringName(KINDS[kind]);
        record["guide_gap_m"] = guide_witness["signed_clearance_m"];
        record["guide_cap_status"] = guide["cap_status"];
        record["guide_depth_lower_m"] = guide["max_inward_depth_lower_m"];
        record["guide_depth_upper_m"] = guide["max_inward_depth_upper_m"];
        record["material_witness"] = material_witness;
        record["material_gap_m"] = material_witness["signed_clearance_m"];
        record["material_cap_status"] = actual["cap_status"];
        record["max_inward_depth_m"] = actual["max_inward_depth_m"];
        record["source_max_inward_depth_m"] = segment["max_inward_depth_m"];
        record["material_constraint_safe"] = material_edge_safe;
        record["guide_constraint_safe"] = guide_edge_safe;
        record["material_strictly_exterior"] = material_exterior;
        record["guide_strictly_exterior"] = guide_exterior;
        record["depth_lower_m"] = actual["max_inward_depth_lower_m"];
        record["depth_upper_m"] = actual["max_inward_depth_upper_m"];
        record["material_budget_exhausted"] = actual["budget_exhausted"];
        record["material_evaluations"] = actual["depth_evaluations"];
        records.append(record);
    }
    Dictionary out;
    out["valid"] = true;
    out["revision"] = StringName("saved_wrapper_skin_contact_v1");
    out["origin_id"] = origin_id;
    out["segments"] = records;
    out["material_safe"] = material["all_segments_within_cap"];
    out["any_exceeds"] = exceeding > 0;
    out["any_unresolved"] = unresolved > 0;
    out["material_constraint_safe"] = material_safe;
    out["guide_constraint_safe"] = guide_safe;
    out["exceeding_segments"] = exceeding;
    out["unresolved_segments"] = unresolved;
    out["material_depth_evaluations"] = material["depth_evaluations"];
    out["guide_depth_evaluations"] = guide_evaluations;
    out["material_measurement_ms"] = material_ms;
    out["guide_measurement_ms"] = guide_ms;
    out["witness_normalization_ms"] = elapsed_ms(witnesses_started);
    out["evaluation_ms"] = elapsed_ms(started);
    out["metric_units"] = StringName("meters");
    out["grip_accepted"] = false;
    out["actual_3d_grip_verified"] = false;
    out["production_pose_written"] = false;
    out["scope"] = StringName("supplied_planar_skin_edges_only");
    return out;
}

Dictionary GripSavedContactKernel::statistics() const {
    const Stats &stats = impl_->stats;
    Dictionary out;
    out["revision"] = StringName("native_saved_contact_batch_v1");
    out["acquisition_id"] = impl_->acquisition_id;
    out["contact_backend"] = String("cpp_saved_contact_batch");
    out["segment_cache_mode"] = String("bypassed; complete native batch evaluates every requested segment");
    out["cache_enabled"] = false;
    out["cache_hits"] = int64_t(0);
    out["cache_bypasses"] = stats.logical_segments;
    out["fallback_calls"] = int64_t(0);
    out["prepared_section_count"] = int64_t(impl_->prepared.size());
    out["maximum_prepared_sections"] = int64_t(MAX_SECTIONS);
    out["prepared_section_cache_hits"] = stats.prepared_hits;
    out["prepared_section_cache_misses"] = stats.prepared_misses;
    out["native_section_count"] = int64_t(impl_->native.size());
    out["maximum_native_sections"] = int64_t(MAX_SECTIONS);
    int64_t targets = 0;
    for (const NativeEntry &entry : impl_->native) for (const int64_t handle : entry.handles) targets += int64_t(handle != 0);
    out["native_target_count"] = targets;
    out["maximum_native_targets"] = int64_t(MAX_SECTIONS * 3);
    out["native_section_cache_hits"] = stats.native_section_hits;
    out["native_section_cache_misses"] = stats.native_section_misses;
    out["native_section_evictions"] = stats.native_section_evictions;
    out["batch_calls"] = stats.batch_calls;
    out["depth_batch_calls"] = stats.depth_batches;
    out["logical_segment_calls"] = stats.logical_segments;
    out["actual_segment_calls"] = stats.actual_segments;
    out["actual_segment_us"] = stats.segment_us;
    out["actual_depth_evaluations"] = stats.actual_evaluations;
    Dictionary work;
    for (size_t i = 0; i < stats.work.size(); ++i) {
        work[WORK_FIELDS[i]] = stats.work[i];
        out[String("actual_") + String(WORK_FIELDS[i])] = stats.work[i];
    }
    out["actual_work_counts"] = work;
    Dictionary native;
    native["segment_calls"] = stats.actual_segments;
    native["segment_us"] = stats.segment_us;
    native["target_preparations"] = stats.target_preparations;
    native["target_preparation_us"] = stats.target_preparation_us;
    native["fallback_calls"] = int64_t(0);
    out["native_kernel"] = native;
    out["target_identity"] = String("hash candidate filter followed by exact type/component-bit comparison of detached complete target packets");
    return out;
}

} // namespace godot
