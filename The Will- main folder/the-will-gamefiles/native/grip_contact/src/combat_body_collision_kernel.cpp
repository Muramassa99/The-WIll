#include "combat_body_collision_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <cmath>
#include <limits>
#include <vector>

namespace godot {

namespace {

enum class ShapeKind { UNKNOWN, BOX, CAPSULE };

struct BodyShape {
    Transform3D inverse_transform;
    Basis global_basis;
    String body_region;
    String attachment_name;
    ShapeKind kind = ShapeKind::UNKNOWN;
    Vector3 half_size;
    double radius = 0.0;
    double half_mid = 0.0;
};

struct PointResult {
    bool inside = false;
    ShapeKind kind = ShapeKind::UNKNOWN;
    double clearance = std::numeric_limits<double>::infinity();
    Vector3 correction;
    const BodyShape *body = nullptr;
};

bool is_text(const Variant &value) {
    return value.get_type() == Variant::STRING || value.get_type() == Variant::STRING_NAME;
}

bool is_number(const Variant &value) {
    return value.get_type() == Variant::FLOAT || value.get_type() == Variant::INT;
}

bool read_shapes(const Array &prepared, std::vector<BodyShape> &shapes, String &error) {
    shapes.reserve(static_cast<size_t>(prepared.size()));
    for (int64_t i = 0; i < prepared.size(); ++i) {
        error = String("Invalid combat body snapshot entry ") + String::num_int64(i) + ".";
        if (prepared[i].get_type() != Variant::DICTIONARY) {
            return false;
        }
        const Dictionary entry = prepared[i];
        const Variant inverse = entry.get("inverse_transform", Variant());
        const Variant basis = entry.get("global_basis", Variant());
        const Variant region = entry.get("body_region", Variant());
        const Variant attachment = entry.get("attachment_name", Variant());
        const Variant kind_value = entry.get("shape_kind", Variant());
        if (inverse.get_type() != Variant::TRANSFORM3D || basis.get_type() != Variant::BASIS ||
                !is_text(region) || !is_text(attachment) || !is_text(kind_value)) {
            return false;
        }
        BodyShape shape;
        shape.inverse_transform = inverse;
        shape.global_basis = basis;
        shape.body_region = region;
        shape.attachment_name = attachment;
        const StringName kind = kind_value;
        if (kind == StringName("box")) {
            const Variant half_size = entry.get("half_size", Variant());
            if (half_size.get_type() != Variant::VECTOR3) {
                return false;
            }
            shape.kind = ShapeKind::BOX;
            shape.half_size = half_size;
        } else if (kind == StringName("capsule")) {
            const Variant radius = entry.get("radius", Variant());
            const Variant half_mid = entry.get("half_mid", Variant());
            if (!is_number(radius) || !is_number(half_mid)) {
                return false;
            }
            shape.kind = ShapeKind::CAPSULE;
            shape.radius = radius;
            shape.half_mid = half_mid;
        }
        // Unsupported shapes deliberately remain an outside result at -1 m,
        // matching the reference query rather than silently dropping them.
        shapes.push_back(shape);
    }
    return true;
}

StringName shape_name(ShapeKind kind) {
    switch (kind) {
        case ShapeKind::BOX: return StringName("box");
        case ShapeKind::CAPSULE: return StringName("capsule");
        default: return StringName();
    }
}

PointResult query_shape(const BodyShape &shape, const Vector3 &point_world, double clearance_offset) {
    const Vector3 local_point = shape.inverse_transform.xform(point_world);
    PointResult result;
    result.body = &shape;
    result.kind = shape.kind;
    if (shape.kind == ShapeKind::BOX) {
        const Vector3 abs_point(
                static_cast<real_t>(std::abs(static_cast<double>(local_point.x))),
                static_cast<real_t>(std::abs(static_cast<double>(local_point.y))),
                static_cast<real_t>(std::abs(static_cast<double>(local_point.z))));
        // GDScript component arithmetic uses double; Vector3 construction and
        // its length/basis operations use the engine's real_t precision.
        const double outside_x = static_cast<double>(abs_point.x) - static_cast<double>(shape.half_size.x);
        const double outside_y = static_cast<double>(abs_point.y) - static_cast<double>(shape.half_size.y);
        const double outside_z = static_cast<double>(abs_point.z) - static_cast<double>(shape.half_size.z);
        const Vector3 outside(
                static_cast<real_t>(outside_x > 0.0 ? outside_x : 0.0),
                static_cast<real_t>(outside_y > 0.0 ? outside_y : 0.0),
                static_cast<real_t>(outside_z > 0.0 ? outside_z : 0.0));
        result.inside = abs_point.x <= shape.half_size.x &&
                abs_point.y <= shape.half_size.y && abs_point.z <= shape.half_size.z;
        if (!result.inside) {
            result.clearance = outside.length();
            return result;
        }
        const double x_depth = static_cast<double>(shape.half_size.x) - static_cast<double>(abs_point.x);
        const double y_depth = static_cast<double>(shape.half_size.y) - static_cast<double>(abs_point.y);
        const double z_depth = static_cast<double>(shape.half_size.z) - static_cast<double>(abs_point.z);
        Vector3 correction_axis(local_point.x >= 0.0 ? 1.0 : -1.0, 0.0, 0.0);
        double penetration_depth = x_depth;
        if (y_depth < penetration_depth) {
            penetration_depth = y_depth;
            correction_axis = Vector3(0.0, local_point.y >= 0.0 ? 1.0 : -1.0, 0.0);
        }
        if (z_depth < penetration_depth) {
            penetration_depth = z_depth;
            correction_axis = Vector3(0.0, 0.0, local_point.z >= 0.0 ? 1.0 : -1.0);
        }
        result.clearance = -penetration_depth;
        result.correction = shape.global_basis.xform(correction_axis) *
                static_cast<real_t>(penetration_depth + clearance_offset);
        return result;
    }
    if (shape.kind == ShapeKind::CAPSULE) {
        const double local_y = local_point.y;
        const double clamped_y = local_y < -shape.half_mid ? -shape.half_mid :
                (local_y > shape.half_mid ? shape.half_mid : local_y);
        const Vector3 closest_axis_point(0.0, static_cast<real_t>(clamped_y), 0.0);
        const Vector3 radial_vector = local_point - closest_axis_point;
        const double radial_distance = radial_vector.length();
        if (radial_distance > shape.radius) {
            result.clearance = radial_distance - shape.radius;
            return result;
        }
        result.inside = true;
        const Vector3 correction_axis = radial_distance > 0.000001 ? radial_vector.normalized() : Vector3(1.0, 0.0, 0.0);
        const double penetration_depth = shape.radius - radial_distance;
        result.clearance = -penetration_depth;
        result.correction = shape.global_basis.xform(correction_axis) *
                static_cast<real_t>(penetration_depth + clearance_offset);
        return result;
    }
    result.clearance = -1.0;
    return result;
}

PointResult query_point(const std::vector<BodyShape> &shapes, const Vector3 &point_world, double clearance_offset) {
    PointResult result;
    for (const BodyShape &shape : shapes) {
        const PointResult candidate = query_shape(shape, point_world, clearance_offset);
        if (candidate.inside) {
            return candidate; // First inside shape wins, in snapshot order.
        }
        if (candidate.clearance < result.clearance) {
            result = candidate; // Strict comparison retains the first tie.
        }
    }
    if (result.clearance == std::numeric_limits<double>::infinity()) {
        result.clearance = -1.0;
    }
    return result;
}

Dictionary point_dictionary(const PointResult &point, const Vector3 &point_world) {
    Dictionary result;
    result["legal"] = !point.inside;
    result["inside"] = point.inside;
    result["body_region"] = point.body ? point.body->body_region : String();
    result["attachment_name"] = point.body ? point.body->attachment_name : String();
    result["shape_kind"] = shape_name(point.kind);
    result["estimated_clearance_meters"] = point.clearance;
    result["suggested_correction_world"] = point.correction;
    result["point_world"] = point_world;
    return result;
}

} // namespace

void CombatBodyCollisionKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("evaluate_weapon_pose", "prepared", "samples", "solved_transform", "clearance_offset"),
            &CombatBodyCollisionKernel::evaluate_weapon_pose);
    ClassDB::bind_method(D_METHOD("query_points", "prepared", "points", "clearance_offset"),
            &CombatBodyCollisionKernel::query_points);
}

Dictionary CombatBodyCollisionKernel::evaluate_weapon_pose(const Array &prepared, const Array &samples,
        const Transform3D &solved_transform, double clearance_offset) const {
    std::vector<BodyShape> shapes;
    String error;
    ERR_FAIL_COND_V_MSG(!read_shapes(prepared, shapes, error), Dictionary(), error);
    Dictionary result;
    result["legal"] = true;
    result["pose_legal"] = true;
    result["sample_count"] = samples.size();
    result["illegal_sample_count"] = 0;
    result["first_collision"] = Dictionary();
    result["colliding_body_region"] = "";
    result["colliding_body_attachment_name"] = "";
    result["colliding_sample_name"] = "";
    result["estimated_clearance_meters"] = std::numeric_limits<double>::infinity();
    result["suggested_correction_world"] = Vector3();
    double min_clearance = std::numeric_limits<double>::infinity();
    int64_t illegal_count = 0;
    for (int64_t i = 0; i < samples.size(); ++i) {
        ERR_FAIL_COND_V_MSG(samples[i].get_type() != Variant::DICTIONARY, Dictionary(), "Invalid combat weapon sample dictionary.");
        const Dictionary sample = samples[i];
        const Variant position = sample.get("local_position", Vector3());
        const Variant name = sample.get("name", String());
        ERR_FAIL_COND_V_MSG(position.get_type() != Variant::VECTOR3 || !is_text(name), Dictionary(),
                "Combat weapon samples require local_position (Vector3) and name (String).");
        const Vector3 local_point = position;
        const Vector3 world = solved_transform.xform(local_point);
        const PointResult point = query_point(shapes, world, clearance_offset);
        if (point.clearance < min_clearance) {
            min_clearance = point.clearance;
        }
        if (point.inside) {
            ++illegal_count;
            if (illegal_count == 1) {
                const String sample_name = name;
                Dictionary collision;
                collision["sample_name"] = sample_name;
                collision["sample_world"] = world;
                collision["body_region"] = point.body->body_region;
                collision["attachment_name"] = point.body->attachment_name;
                collision["shape_kind"] = shape_name(point.kind);
                collision["estimated_clearance_meters"] = point.clearance;
                collision["suggested_correction_world"] = point.correction;
                result["first_collision"] = collision;
                result["colliding_body_region"] = point.body->body_region;
                result["colliding_body_attachment_name"] = point.body->attachment_name;
                result["colliding_sample_name"] = sample_name;
                result["estimated_clearance_meters"] = point.clearance;
                result["suggested_correction_world"] = point.correction;
            }
        }
    }
    result["legal"] = illegal_count == 0;
    result["pose_legal"] = illegal_count == 0;
    result["illegal_sample_count"] = illegal_count;
    if (illegal_count == 0) {
        result["estimated_clearance_meters"] = min_clearance < std::numeric_limits<double>::infinity() ? min_clearance : -1.0;
    }
    return result;
}

Array CombatBodyCollisionKernel::query_points(const Array &prepared, const PackedVector3Array &points,
        double clearance_offset) const {
    std::vector<BodyShape> shapes;
    String error;
    ERR_FAIL_COND_V_MSG(!read_shapes(prepared, shapes, error), Array(), error);
    Array result;
    result.resize(points.size());
    for (int64_t i = 0; i < points.size(); ++i) {
        result[i] = point_dictionary(query_point(shapes, points[i], clearance_offset), points[i]);
    }
    return result;
}

} // namespace godot
