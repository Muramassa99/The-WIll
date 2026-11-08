#include "combat_forearm_clearance_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/basis.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>

namespace godot {
namespace {
constexpr double EPS = 1.0e-10;
double clamp(double value, double low, double high) { return std::max(low, std::min(high, value)); }
Dictionary failure(const String &reason) {
    Dictionary out;
    out["valid"] = false;
    out["reason"] = reason;
    return out;
}
struct Shape {
    bool capsule = false;
    Vector3 start, end, fallback_axis, fallback_up;
    double radius = 0.0;
    Transform3D frame;
    Vector3 half;
    String region;
    int64_t bone = -1;
};
struct Nearest { Vector3 first, second; };
struct Contact {
    double clearance = 0.0;
    Vector3 normal, axis_first, axis_second, surface_first, surface_second;
};
struct BoxDistance {
    double distance = std::numeric_limits<double>::infinity();
    Vector3 point, surface, normal;
};

Nearest closest_segments(const Vector3 &a, const Vector3 &b, const Vector3 &c, const Vector3 &d) {
    const Vector3 first = b - a, second = d - c, offset = a - c;
    const double aa = first.dot(first), ee = second.dot(second), ff = second.dot(offset);
    double s = 0.0, t = 0.0;
    if (aa <= EPS && ee <= EPS) return {a, c};
    if (aa <= EPS) {
        t = clamp(ff / ee, 0.0, 1.0);
    } else {
        const double cc = first.dot(offset);
        if (ee <= EPS) {
            s = clamp(-cc / aa, 0.0, 1.0);
        } else {
            const double bb = first.dot(second), determinant = aa * ee - bb * bb;
            if (determinant > EPS * aa * ee) s = clamp((bb * ff - cc * ee) / determinant, 0.0, 1.0);
            t = (bb * s + ff) / ee;
            if (t < 0.0) { t = 0.0; s = clamp(-cc / aa, 0.0, 1.0); }
            else if (t > 1.0) { t = 1.0; s = clamp((bb - cc) / aa, 0.0, 1.0); }
        }
    }
    return {a + first * s, c + second * t};
}

Vector3 coincident_normal(const Shape &a, const Shape &b) {
    const Vector3 first = a.end - a.start, second = b.end - b.start;
    const Vector3 cross = first.cross(second);
    if (cross.length_squared() > EPS) return cross.normalized();
    Vector3 fallback = b.fallback_axis;
    if (first.length_squared() > EPS) fallback -= first * fallback.dot(first) / first.length_squared();
    if (fallback.length_squared() <= EPS) fallback = b.fallback_up;
    return fallback.normalized();
}

Contact capsule_pair(const Shape &a, const Shape &b) {
    const Nearest nearest = closest_segments(a.start, a.end, b.start, b.end);
    const Vector3 difference = nearest.first - nearest.second;
    const double distance = difference.length();
    const Vector3 normal = distance > EPS ? difference / distance : coincident_normal(a, b);
    return {distance - a.radius - b.radius, normal, nearest.first, nearest.second,
        nearest.first - normal * a.radius, nearest.second + normal * b.radius};
}

// Same bounded piecewise-quadratic exterior and piecewise-linear interior
// segment/AABB minimum as the script reference. Never tests only endpoints.
BoxDistance segment_box(const Vector3 &start, const Vector3 &end, const Vector3 &half) {
    const Vector3 direction = end - start;
    std::vector<double> parameters{0.0, 1.0}, slopes, offsets;
    slopes.reserve(6); offsets.reserve(6); parameters.reserve(8);
    for (int axis = 0; axis < 3; ++axis) {
        for (double sign : {-1.0, 1.0}) {
            slopes.push_back(direction[axis] * sign);
            offsets.push_back(start[axis] * sign - half[axis]);
            if (std::abs(direction[axis]) > EPS) {
                const double crossing = (sign * half[axis] - start[axis]) / direction[axis];
                if (crossing > 0.0 && crossing < 1.0) parameters.push_back(crossing);
            }
        }
    }
    std::sort(parameters.begin(), parameters.end());
    std::vector<double> candidates = parameters;
    candidates.reserve(36);
    for (size_t interval = 0; interval + 1 < parameters.size(); ++interval) {
        const double low = parameters[interval], high = parameters[interval + 1];
        const Vector3 middle = start + direction * ((low + high) * 0.5);
        double numerator = 0.0, denominator = 0.0;
        for (int axis = 0; axis < 3; ++axis) {
            if (std::abs(middle[axis]) > half[axis]) {
                const double face = middle[axis] > 0.0 ? half[axis] : -half[axis];
                numerator += direction[axis] * (start[axis] - face);
                denominator += direction[axis] * direction[axis];
            }
        }
        if (denominator > EPS) candidates.push_back(clamp(-numerator / denominator, low, high));
    }
    for (int first = 0; first < 6; ++first) {
        for (int second = first + 1; second < 6; ++second) {
            const double divisor = slopes[first] - slopes[second];
            if (std::abs(divisor) <= EPS) continue;
            const double t = (offsets[second] - offsets[first]) / divisor;
            if (t > 0.0 && t < 1.0) candidates.push_back(t);
        }
    }
    BoxDistance best;
    for (double t : candidates) {
        const Vector3 point = start + direction * t;
        Vector3 surface(clamp(point.x, -half.x, half.x), clamp(point.y, -half.y, half.y), clamp(point.z, -half.z, half.z));
        const Vector3 outward = point - surface;
        double distance = outward.length();
        Vector3 normal;
        if (distance > EPS) {
            normal = outward / distance;
        } else {
            const Vector3 depths = point.abs() - half;
            int axis = 0;
            if (depths.y > depths.x) axis = 1;
            if (depths.z > depths[axis]) axis = 2;
            distance = depths[axis];
            normal[axis] = point[axis] >= 0.0 ? 1.0 : -1.0;
            surface = point - normal * distance;
        }
        if (distance < best.distance) best = {distance, point, surface, normal};
    }
    return best;
}

Contact capsule_box(const Shape &capsule, const Shape &box) {
    const Transform3D inverse = box.frame.affine_inverse();
    const BoxDistance nearest = segment_box(inverse.xform(capsule.start), inverse.xform(capsule.end), box.half);
    const Vector3 normal = box.frame.basis.xform(nearest.normal);
    const Vector3 point = box.frame.xform(nearest.point), surface = box.frame.xform(nearest.surface);
    return {nearest.distance - capsule.radius, normal, point, surface,
        point - normal * capsule.radius, surface};
}

bool transform_shape(bool capsule, double radius, double half_mid, const Vector3 &half,
        const Transform3D &transform, Shape &out) {
    if (!transform.is_finite() || transform.basis.determinant() <= EPS) return false;
    const Basis &basis = transform.basis;
    const Basis rotation = basis.orthonormalized();
    const Vector3 scales = basis.get_scale().abs();
    if (capsule) {
        out.capsule = true;
        double radius_scale = std::max({double(scales.x), double(scales.y), double(scales.z)});
        const Vector3 x = basis.get_column(0), y = basis.get_column(1), z = basis.get_column(2);
        const double shear = std::max({std::abs(double(x.normalized().dot(y.normalized()))),
            std::abs(double(x.normalized().dot(z.normalized()))), std::abs(double(y.normalized().dot(z.normalized())))});
        if (shear > 0.00001) radius_scale = std::sqrt(x.length_squared() + y.length_squared() + z.length_squared());
        out.start = transform.xform(Vector3(0.0, -half_mid, 0.0));
        out.end = transform.xform(Vector3(0.0, half_mid, 0.0));
        out.radius = radius * radius_scale;
        out.fallback_axis = rotation.get_column(0);
        out.fallback_up = rotation.get_column(2);
        return true;
    }
    out.capsule = false;
    const Basis projected = rotation.transposed() * basis;
    out.half = projected.get_column(0).abs() * half.x + projected.get_column(1).abs() * half.y + projected.get_column(2).abs() * half.z;
    out.frame = Transform3D(rotation, transform.origin);
    return true;
}

bool world_shape(const Dictionary &descriptor, const Transform3D &transform, Shape &out) {
    out.region = descriptor.get("region", "");
    out.bone = descriptor.get("bone_index", int64_t(-1));
    const String kind = descriptor.get("kind", "");
    if (kind == "capsule") return transform_shape(true, descriptor.get("radius", 0.0),
        descriptor.get("half_mid", 0.0), Vector3(), transform, out);
    if (kind != "box" || descriptor.get("half_size", Variant()).get_type() != Variant::VECTOR3) return false;
    return transform_shape(false, 0.0, 0.0, descriptor["half_size"], transform, out);
}
} // namespace

void CombatForearmClearanceKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("evaluate", "snapshot", "candidate_globals"), &CombatForearmClearanceKernel::evaluate);
    ClassDB::bind_method(D_METHOD("prepare", "snapshot"), &CombatForearmClearanceKernel::prepare);
    ClassDB::bind_method(D_METHOD("query_constraints", "candidate_globals"), &CombatForearmClearanceKernel::query_constraints);
}

Dictionary CombatForearmClearanceKernel::prepare(const Dictionary &snapshot) {
    prepared_valid = false;
    prepared_shapes.clear(); prepared_pairs.clear();
    const Variant world_value = snapshot.get("skeleton_world", Variant());
    if (!bool(snapshot.get("valid", false)) || world_value.get_type() != Variant::TRANSFORM3D)
        return failure("forearm_clearance_snapshot_invalid");
    prepared_world = world_value;
    prepared_normalization = snapshot.get("normalization_meters", 0.0);
    if (!prepared_world.is_finite() || !std::isfinite(prepared_normalization) || prepared_normalization <= 0.0)
        return failure("forearm_clearance_snapshot_metric_invalid");
    const Variant shape_values = snapshot.get("shapes", Variant()), pair_values = snapshot.get("pairs", Variant());
    if (shape_values.get_type() != Variant::ARRAY || pair_values.get_type() != Variant::ARRAY)
        return failure("forearm_clearance_snapshot_invalid");
    const Array descriptors = shape_values, pairs = pair_values;
    prepared_shapes.reserve(static_cast<size_t>(descriptors.size()));
    prepared_pairs.reserve(static_cast<size_t>(pairs.size()));
    for (int64_t index = 0; index < descriptors.size(); ++index) {
        if (descriptors[index].get_type() != Variant::DICTIONARY) return failure("forearm_clearance_snapshot_invalid");
        const Dictionary descriptor = descriptors[index];
        PreparedShape shape;
        shape.bone = descriptor.get("bone_index", int64_t(-1));
        const Variant local = descriptor.get("bone_local_shape", Variant());
        if (shape.bone < 0 || local.get_type() != Variant::TRANSFORM3D)
            return failure("forearm_clearance_shape_transform_invalid");
        shape.local = local;
        const String kind = descriptor.get("kind", "");
        if (kind == "capsule") {
            shape.capsule = true;
            shape.radius = descriptor.get("radius", 0.0);
            shape.half_mid = descriptor.get("half_mid", 0.0);
        } else if (kind == "box" && descriptor.get("half_size", Variant()).get_type() == Variant::VECTOR3) {
            shape.half = descriptor["half_size"];
        } else return failure("forearm_clearance_shape_transform_invalid");
        prepared_shapes.push_back(shape);
    }
    for (int64_t index = 0; index < pairs.size(); ++index) {
        if (pairs[index].get_type() != Variant::DICTIONARY) return failure("forearm_clearance_snapshot_invalid");
        const Dictionary pair = pairs[index];
        const int64_t a = pair.get("forearm", int64_t(-1)), b = pair.get("body", int64_t(-1));
        if (a < 0 || b < 0 || a >= int64_t(prepared_shapes.size()) || b >= int64_t(prepared_shapes.size()) || !prepared_shapes[size_t(a)].capsule)
            return failure("forearm_clearance_snapshot_invalid");
        prepared_pairs.push_back({a, b});
    }
    prepared_valid = true;
    Dictionary result;
    result["valid"] = true;
    result["shape_count"] = int64_t(prepared_shapes.size());
    result["pair_count"] = int64_t(prepared_pairs.size());
    return result;
}

PackedFloat64Array CombatForearmClearanceKernel::query_constraints(const Array &globals) const {
    if (!prepared_valid) return PackedFloat64Array();
    std::vector<Shape> shapes;
    shapes.reserve(prepared_shapes.size());
    for (const PreparedShape &prepared : prepared_shapes) {
        if (prepared.bone >= globals.size() || globals[prepared.bone].get_type() != Variant::TRANSFORM3D)
            return PackedFloat64Array();
        const Transform3D bone_global = globals[prepared.bone];
        Shape shape;
        if (!transform_shape(prepared.capsule, prepared.radius, prepared.half_mid, prepared.half,
                prepared_world * bone_global * prepared.local, shape)) return PackedFloat64Array();
        shapes.push_back(shape);
    }
    PackedFloat64Array constraints;
    constraints.resize(int64_t(prepared_pairs.size()));
    for (size_t index = 0; index < prepared_pairs.size(); ++index) {
        const PreparedPair &pair = prepared_pairs[index];
        const Shape &a = shapes[size_t(pair.first)], &b = shapes[size_t(pair.second)];
        double clearance;
        if (b.capsule) {
            const Nearest nearest = closest_segments(a.start, a.end, b.start, b.end);
            clearance = (nearest.first - nearest.second).length() - a.radius - b.radius;
        } else {
            const Transform3D inverse = b.frame.affine_inverse();
            clearance = segment_box(inverse.xform(a.start), inverse.xform(a.end), b.half).distance - a.radius;
        }
        if (!std::isfinite(clearance)) return PackedFloat64Array();
        constraints.set(int64_t(index), -clearance / prepared_normalization);
    }
    return constraints;
}

Dictionary CombatForearmClearanceKernel::evaluate(const Dictionary &snapshot, const Array &globals) const {
    const Variant world_value = snapshot.get("skeleton_world", Variant());
    if (!bool(snapshot.get("valid", false)) || world_value.get_type() != Variant::TRANSFORM3D)
        return failure("forearm_clearance_snapshot_invalid");
    const Transform3D world = world_value;
    const double normalization = snapshot.get("normalization_meters", 0.0);
    if (!world.is_finite() || normalization <= 0.0) return failure("forearm_clearance_snapshot_metric_invalid");
    const Variant shape_values = snapshot.get("shapes", Variant()), pair_values = snapshot.get("pairs", Variant());
    if (shape_values.get_type() != Variant::ARRAY || pair_values.get_type() != Variant::ARRAY)
        return failure("forearm_clearance_snapshot_invalid");
    const Array descriptors = shape_values, pairs = pair_values;
    std::vector<Shape> shapes;
    shapes.reserve(static_cast<size_t>(descriptors.size()));
    for (int64_t index = 0; index < descriptors.size(); ++index) {
        if (descriptors[index].get_type() != Variant::DICTIONARY) return failure("forearm_clearance_snapshot_invalid");
        const Dictionary descriptor = descriptors[index];
        const int64_t bone = descriptor.get("bone_index", int64_t(-1));
        if (bone < 0 || bone >= globals.size() || globals[bone].get_type() != Variant::TRANSFORM3D)
            return failure("forearm_clearance_candidate_bone_missing");
        const Variant local_value = descriptor.get("bone_local_shape", Variant());
        if (local_value.get_type() != Variant::TRANSFORM3D) return failure("forearm_clearance_shape_transform_invalid");
        const Transform3D bone_global = globals[bone], shape_local = local_value;
        Shape shape;
        if (!world_shape(descriptor, world * bone_global * shape_local, shape))
            return failure("forearm_clearance_shape_transform_invalid");
        shapes.push_back(shape);
    }
    PackedFloat64Array constraints;
    PackedStringArray reasons;
    Array contacts;
    constraints.resize(pairs.size()); reasons.resize(pairs.size()); contacts.resize(pairs.size());
    double minimum = std::numeric_limits<double>::infinity();
    for (int64_t index = 0; index < pairs.size(); ++index) {
        if (pairs[index].get_type() != Variant::DICTIONARY) return failure("forearm_clearance_snapshot_invalid");
        const Dictionary pair = pairs[index];
        const int64_t a = pair.get("forearm", int64_t(-1)), b = pair.get("body", int64_t(-1));
        if (a < 0 || b < 0 || a >= int64_t(shapes.size()) || b >= int64_t(shapes.size()) || !shapes[size_t(a)].capsule)
            return failure("forearm_clearance_snapshot_invalid");
        const Shape &first = shapes[size_t(a)], &second = shapes[size_t(b)];
        const Contact contact = second.capsule ? capsule_pair(first, second) : capsule_box(first, second);
        if (!std::isfinite(contact.clearance)) return failure("forearm_clearance_nonfinite_distance");
        const String reason = pair.get("reason", "");
        Dictionary row;
        row["valid"] = true;
        row["clearance_meters"] = contact.clearance;
        row["normal_world"] = contact.normal;
        row["forearm_axis_point_world"] = contact.axis_first;
        row["body_axis_point_world"] = contact.axis_second;
        row["forearm_surface_world"] = contact.surface_first;
        row["body_surface_world"] = contact.surface_second;
        row["reason"] = reason;
        row["forearm_region"] = first.region;
        row["body_region"] = second.region;
        row["forearm_bone_index"] = first.bone;
        row["body_bone_index"] = second.bone;
        row["origin_id"] = StringName("world");
        constraints.set(index, -contact.clearance / normalization);
        reasons.set(index, reason);
        contacts[index] = row;
        minimum = std::min(minimum, contact.clearance);
    }
    Dictionary out;
    out["valid"] = true;
    out["constraints"] = constraints;
    out["constraint_reasons"] = reasons;
    out["contacts"] = contacts;
    out["minimum_clearance_meters"] = minimum;
    out["origin_id"] = StringName("RL_BoneRoot");
    return out;
}

} // namespace godot
