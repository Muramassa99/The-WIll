#include "combat_motion_anatomy_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <algorithm>
#include <cmath>
#include <limits>

using namespace godot;

namespace {
constexpr double PI_D = 3.1415926535897932384626433832795;
constexpr double TAU_D = 2.0 * PI_D;
constexpr double AXIS_EPSILON_SQUARED = 1.0e-12;
constexpr double ANTIPODE_EPSILON = 1.0e-6;
constexpr const char *WRIST_REVISION = "semantic_forearm_wrist_v1";
constexpr const char *FOREARM_REVISION = "elbow_conditioned_forearm_v1";
constexpr const char *SHOULDER_REVISION = "chest_relative_shoulder_v1";
constexpr const char *ANATOMICAL_ORIGIN = "CC_Base_Spine02ShoulderAnatomicalOrigin";
constexpr const char *ZERO_CONVENTION = "sideways_upperarm_forearm_forward_shortest_swing";

Quaternion engine_shortest_arc(const Vector3 &from, const Vector3 &to) {
    // The pinned extension_api.json names Quaternion(Vector3, Vector3) as
    // constructor 4. Use the engine's implementation exactly as GDScript does:
    // godot-cpp's header has a different near-antipode/normalization branch.
    static const GDExtensionPtrConstructor constructor =
            gdextension_interface::variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_QUATERNION, 4);
    Quaternion result;
    const GDExtensionConstTypePtr arguments[] = {&from, &to};
    constructor(&result, arguments);
    return result;
}

Dictionary wrist_fail(const String &reason, const String &status = "BLOCKED") {
    Dictionary diagnostics;
    diagnostics["revision"] = WRIST_REVISION;
    Dictionary result;
    result["valid"] = false;
    result["status"] = status;
    result["reason"] = reason;
    result["diagnostics"] = diagnostics;
    return result;
}

Dictionary shoulder_fail(const String &reason) {
    Dictionary result;
    result["valid"] = false;
    result["legal"] = false;
    result["covered"] = false;
    result["reason"] = reason;
    result["revision"] = SHOULDER_REVISION;
    return result;
}

Dictionary interval_fail(const String &reason) {
    Dictionary result;
    result["valid"] = false;
    result["reason"] = reason;
    return result;
}

bool uniform_basis(const Basis &basis) {
    if (!basis.is_finite() || basis.determinant() <= 0.0) return false;
    const Vector3 lengths = basis.get_scale();
    // GDScript is_equal_approx operates on double scalars, not real_t.
    if (std::min(double(lengths.x), std::min(double(lengths.y), double(lengths.z))) <= 0.000001 ||
            !Math::is_equal_approx(double(lengths.x), double(lengths.y)) ||
            !Math::is_equal_approx(double(lengths.x), double(lengths.z))) return false;
    const Basis normalized(basis.get_column(0) / lengths.x,
            basis.get_column(1) / lengths.y, basis.get_column(2) / lengths.z);
    return std::abs(normalized.get_column(0).dot(normalized.get_column(1))) < 0.00001 &&
            std::abs(normalized.get_column(0).dot(normalized.get_column(2))) < 0.00001 &&
            std::abs(normalized.get_column(1).dot(normalized.get_column(2))) < 0.00001;
}

bool state_valid(const Dictionary &state) {
    for (const char *key : {"rho", "beta", "gamma"}) {
        const Variant value = state.get(key, Variant());
        if ((value.get_type() != Variant::FLOAT && value.get_type() != Variant::INT) ||
                !std::isfinite(double(value))) return false;
    }
    return true;
}

// Exact elbow-conditioned table calculation, including legacy and error
// results. It remains dynamic: candidate elbow flexion is never cached.
Dictionary forearm_interval(const Dictionary &calibration, const Dictionary &profile,
        double elbow_bend, double full_flexion) {
    if (!profile.has("forearm_interval_revision")) {
        const double legacy = profile.get("forearm_roll_limit_radians", 0.0);
        Dictionary result;
        result["valid"] = std::isfinite(legacy) && legacy > 0.0;
        result["rho_min"] = -legacy;
        result["rho_max"] = legacy;
        result["conditioned"] = false;
        result["legacy"] = true;
        return result;
    }
    if (String(profile.get("forearm_interval_revision", "")) != FOREARM_REVISION ||
            String(calibration.get("forearm_interval_revision", "")) != FOREARM_REVISION)
        return interval_fail("forearm_interval_calibration_missing");
    const double zero = calibration.get("forearm_thumb_up_rho_radians", std::numeric_limits<double>::quiet_NaN());
    const double direction = calibration.get("forearm_pronation_sign", std::numeric_limits<double>::quiet_NaN());
    if (!std::isfinite(zero) || !std::isfinite(direction) || !Math::is_equal_approx(std::abs(direction), 1.0))
        return interval_fail("forearm_interval_calibration_invalid");
    PackedFloat64Array bends = profile.get("forearm_elbow_samples_radians", PackedFloat64Array());
    const PackedFloat64Array pronation = profile.get("forearm_pronation_limits_radians", PackedFloat64Array());
    const PackedFloat64Array supination = profile.get("forearm_supination_limits_radians", PackedFloat64Array());
    if (bends.size() < 2 || bends.size() != pronation.size() || bends.size() != supination.size() || !std::isfinite(full_flexion))
        return interval_fail("forearm_interval_samples_invalid");
    bends.set(bends.size() - 1, full_flexion); // Packed arrays use copy-on-write.
    double p = 0.0;
    double s = 0.0;
    for (int64_t i = 0; i < bends.size(); ++i) {
        if (!std::isfinite(bends[i]) || !std::isfinite(pronation[i]) || !std::isfinite(supination[i]) ||
                std::min(pronation[i], supination[i]) <= 0.0 || std::max(pronation[i], supination[i]) > PI_D ||
                (i > 0 && bends[i] <= bends[i - 1])) return interval_fail("forearm_interval_samples_invalid");
        p = std::max(p, pronation[i]);
        s = std::max(s, supination[i]);
    }
    const bool conditioned = std::isfinite(elbow_bend);
    if (conditioned) {
        const double bend = std::clamp(elbow_bend, bends[0], bends[bends.size() - 1]);
        for (int64_t i = 1; i < bends.size(); ++i) {
            if (bend <= bends[i]) {
                const double weight = (bend - bends[i - 1]) / (bends[i] - bends[i - 1]);
                p = Math::lerp(pronation[i - 1], pronation[i], weight);
                s = Math::lerp(supination[i - 1], supination[i], weight);
                break;
            }
        }
    }
    const double a = zero - direction * s;
    const double b = zero + direction * p;
    Dictionary result;
    result["valid"] = true;
    result["revision"] = FOREARM_REVISION;
    result["rho_min"] = std::min(a, b);
    result["rho_max"] = std::max(a, b);
    result["pronation_limit"] = p;
    result["supination_limit"] = s;
    result["conditioned"] = conditioned;
    result["thumb_up_rho"] = zero;
    result["pronation_sign"] = direction;
    result["elbow_bend_radians"] = elbow_bend;
    result["full_flexion_radians"] = full_flexion;
    result["legacy"] = false;
    return result;
}

struct MeasuredInterval { double minimum; double maximum; };
MeasuredInterval measured_interval(double plane, const Dictionary &profile) {
    const PackedFloat64Array planes = profile["plane_samples_radians"];
    const PackedFloat64Array minimums = profile["minimum_samples_radians"];
    const PackedFloat64Array maximums = profile["maximum_samples_radians"];
    for (int64_t i = 0; i < planes.size() - 1; ++i) {
        if (plane > planes[i + 1]) continue;
        const double weight = (plane - planes[i]) / (planes[i + 1] - planes[i]);
        return {Math::lerp(minimums[i], minimums[i + 1], weight), Math::lerp(maximums[i], maximums[i + 1], weight)};
    }
    return {minimums[minimums.size() - 1], maximums[maximums.size() - 1]};
}

double region_blend(double start, double end, double value) {
    const double t = std::clamp((value - start) / (end - start), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

Dictionary shoulder_bounds(const Vector3 &direction, double side, const Dictionary &profile) {
    const Vector3 u = direction.normalized();
    const double plane = std::atan2(-double(u.z), double(u.x) * side);
    const double elevation = std::acos(std::clamp(-double(u.y), -1.0, 1.0));
    Dictionary result;
    result["covered"] = false;
    result["minimum_radians"] = 0.0;
    result["maximum_radians"] = 0.0;
    result["plane_radians"] = plane;
    result["elevation_radians"] = elevation;
    result["coverage_kind"] = "uncovered";
    result["provisional"] = false;
    result["coverage_sources"] = Array();
    result["reason"] = "shoulder_direction_not_calibrated";
    const PackedFloat64Array planes = profile["plane_samples_radians"];
    const double epsilon = profile["angle_epsilon_radians"];
    const double sampled_height = profile["sampled_elevation_radians"];
    if (std::abs(elevation - sampled_height) <= epsilon && plane >= planes[0] - epsilon && plane <= planes[planes.size() - 1] + epsilon) {
        const auto measured = measured_interval(std::clamp(plane, planes[0], planes[planes.size() - 1]), profile);
        result["minimum_radians"] = measured.minimum;
        result["maximum_radians"] = measured.maximum;
        result["covered"] = true;
        result["coverage_kind"] = "measured";
        result["reason"] = "";
        Dictionary source;
        source["sample_id"] = "mccully_2005_measured_band";
        source["provenance_kind"] = "original_reference";
        source["source"] = profile.get("source", "");
        source["plane_radians"] = plane;
        source["provisional"] = false;
        Array sources;
        sources.append(source);
        result["coverage_sources"] = sources;
        return result;
    }
    if (String(profile.get("coverage_mode", "")) != "continuous_provisional") return result;
    const Dictionary regions = profile["continuous_regions"];
    // Match GDScript Vector2 intermediates, including their float32 rounding.
    const Vector2 posterior{real_t(double(regions["posterior_minimum_radians"])), real_t(double(regions["posterior_maximum_radians"]))};
    Vector2 horizontal;
    if (plane < planes[0]) {
        const auto side_interval = measured_interval(planes[0], profile);
        horizontal = posterior.lerp(Vector2(side_interval.minimum, side_interval.maximum),
                region_blend(regions["posterior_transition_plane_radians"], planes[0], plane));
    } else if (plane > planes[planes.size() - 1]) {
        const auto front = measured_interval(planes[planes.size() - 1], profile);
        horizontal = Vector2(front.minimum, front.maximum).lerp(posterior,
                region_blend(planes[planes.size() - 1], PI_D, plane));
    } else {
        const auto measured = measured_interval(plane, profile);
        horizontal = Vector2(measured.minimum, measured.maximum);
    }
    Vector2 bounds;
    String region;
    if (elevation <= sampled_height) {
        bounds = Vector2(double(regions["lower_minimum_radians"]), double(regions["lower_maximum_radians"])).lerp(horizontal,
                region_blend(regions["lower_elevation_radians"], sampled_height, elevation));
        region = "lower_to_shoulder_height";
    } else {
        bounds = horizontal.lerp(Vector2(double(regions["upper_minimum_radians"]), double(regions["upper_maximum_radians"])),
                region_blend(sampled_height, regions["upper_elevation_radians"], elevation));
        region = "shoulder_height_to_upper";
    }
    result["covered"] = true;
    result["reason"] = "";
    result["coverage_kind"] = "provisional_continuous";
    result["provisional"] = true;
    result["minimum_radians"] = double(bounds.x);
    result["maximum_radians"] = double(bounds.y);
    Dictionary source;
    source["sample_id"] = region;
    source["provenance_kind"] = "provisional";
    source["origin_id"] = ANATOMICAL_ORIGIN;
    source["machine_origin_id"] = "RL_BoneRoot";
    source["zero_convention"] = ZERO_CONVENTION;
    source["source"] = String(regions["lower_source"]) + "; " + String(profile.get("source", "")) + "; " +
            String(regions["upper_source"]) + "; " + String(regions["posterior_source"]);
    source["provisional"] = true;
    Array sources;
    sources.append(source);
    result["coverage_sources"] = sources;
    return result;
}
} // namespace

void CombatMotionAnatomyKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("sample_wrist", "forearm", "hand", "prepared", "state", "elbow_bend", "full_flexion"), &CombatMotionAnatomyKernel::sample_wrist);
    ClassDB::bind_method(D_METHOD("measure_shoulder", "chest", "upperarm", "forearm", "prepared", "previous_state"), &CombatMotionAnatomyKernel::measure_shoulder);
}

Dictionary CombatMotionAnatomyKernel::sample_wrist(const Transform3D &forearm, const Transform3D &hand,
        const Dictionary &prepared, const Dictionary &state, double elbow_bend, double full_flexion) const {
    if (String(prepared.get("owner", "")) != "wrist_kinematics_v1") return wrist_fail("wrist_prepared_context_invalid");
    if (!forearm.is_finite() || !hand.is_finite() || !uniform_basis(forearm.basis) || !uniform_basis(hand.basis))
        return wrist_fail("wrist_reference_invalid");
    const Vector3 shaft = hand.origin - forearm.origin;
    if (shaft.length_squared() <= AXIS_EPSILON_SQUARED) return wrist_fail("wrist_forearm_axis_degenerate");
    const Dictionary calibration = prepared["calibration"];
    const Dictionary profile = prepared["profile"];
    const Dictionary configuration = prepared["configuration"];
    const Dictionary interval = forearm_interval(calibration, profile, elbow_bend, full_flexion);
    if (!bool(interval.get("valid", false))) return wrist_fail(interval.get("reason", "forearm_interval_invalid"), "INVALID_PROFILE");
    if (!state_valid(state)) return wrist_fail("wrist_state_invalid");
    const Vector3 axis = shaft.normalized();
    const Basis neutral = (forearm.basis.orthonormalized() * Basis(configuration["neutral_local"])).orthonormalized();
    const Basis anatomical_in_bone = configuration["anatomical_in_bone"];
    const double radial_sign = configuration["radial_sign"];
    // GDScript stores state in a Vector3 before constructing rotations.
    const Vector3 angles{real_t(double(state["rho"])), real_t(double(state["beta"])), real_t(double(state["gamma"]))};
    const Basis anatomical = (Basis(axis, angles.x) * neutral * Basis(Vector3(1, 0, 0), angles.y) *
            Basis(Vector3(0, 0, 1), radial_sign * angles.z)).orthonormalized();
    const double beta_limit = angles.y >= 0.0 ? double(profile["extension_limit_radians"]) : double(profile["flexion_limit_radians"]);
    const double gamma_limit = angles.z >= 0.0 ? double(profile["radial_limit_radians"]) : double(profile["ulnar_limit_radians"]);
    Dictionary result;
    result["valid"] = true;
    result["hand_basis"] = (anatomical * anatomical_in_bone.transposed()).orthonormalized().scaled(hand.basis.get_scale());
    result["envelope_value"] = std::pow(double(angles.y) / beta_limit, 2.0) + std::pow(double(angles.z) / gamma_limit, 2.0);
    result["state"] = state.duplicate();
    result["forearm_interval"] = interval;
    return result;
}

Dictionary CombatMotionAnatomyKernel::measure_shoulder(const Transform3D &chest, const Transform3D &upperarm,
        const Transform3D &forearm, const Dictionary &prepared, const Dictionary &previous_state) const {
    if (String(prepared.get("owner", "")) != "shoulder_measurement_v1") return shoulder_fail("shoulder_prepared_context_invalid");
    for (const Transform3D &frame : {chest, upperarm, forearm}) {
        if (!frame.is_finite() || frame.basis.determinant() <= 0.0 || !frame.basis.is_conformal())
            return shoulder_fail("shoulder_pose_nonrigid");
    }
    const Dictionary calibration = prepared["calibration"];
    const Dictionary profile = prepared["profile"];
    const String mode = profile.get("coverage_mode", "");
    if (mode != "continuous_provisional" && mode != "measured_band_only") return shoulder_fail("shoulder_native_coverage_unsupported");
    const Basis chest_frame = chest.basis.orthonormalized() * Basis(calibration["chest_anatomical_in_bone"]);
    const Vector3 physical_shaft = forearm.origin - upperarm.origin;
    if (physical_shaft.length_squared() <= AXIS_EPSILON_SQUARED) return shoulder_fail("shoulder_zero_length_upperarm");
    const Vector3 shaft = chest_frame.transposed().xform(physical_shaft).normalized();
    // Match fixed_reference's second normalization, without altering the
    // independently retained measured shaft used by h and constraint rows.
    const Vector3 u = shaft.normalized();
    const double side = calibration["side_sign"];
    const Vector3 outward(side, 0.0, 0.0);
    Vector3 zero;
    String chart = "sideways_reference";
    String warning = "";
    if (outward.dot(u) < -1.0 + ANTIPODE_EPSILON) {
        zero = Basis(engine_shortest_arc(-outward, u)).xform(Vector3(0.0, side, 0.0));
        chart = "opposite_side_reference";
        warning = "uncovered_shoulder_reference_chart_seam";
    } else {
        zero = Basis(engine_shortest_arc(outward, u)).xform(Vector3(0.0, side, 0.0));
    }
    zero = (zero - u * zero.dot(u)).normalized();
    const Basis material = calibration["material_frame_in_upperarm"];
    Vector3 hinge = (chest_frame.transposed() * upperarm.basis.orthonormalized()).xform(material.get_column(0));
    hinge -= shaft * hinge.dot(shaft);
    if (hinge.length_squared() <= AXIS_EPSILON_SQUARED) return shoulder_fail("shoulder_material_hinge_parallel_to_shaft");
    hinge = hinge.normalized();
    double h = double(calibration["internal_sign"]) * std::atan2(double(shaft.dot(zero.cross(hinge))), double(zero.dot(hinge)));
    if (previous_state.has("h")) {
        const double prior = previous_state["h"];
        if (!std::isfinite(prior)) return shoulder_fail("shoulder_previous_angle_nonfinite");
        h += TAU_D * std::round((prior - h) / TAU_D);
    }
    const Dictionary bounds = shoulder_bounds(shaft, side, profile);
    const bool covered = bounds["covered"];
    PackedFloat64Array violations;
    bool legal = false;
    if (covered) {
        violations.append(double(bounds["minimum_radians"]) - h);
        violations.append(h - double(bounds["maximum_radians"]));
        legal = std::max(violations[0], violations[1]) <= double(profile["angle_epsilon_radians"]);
    }
    Dictionary state;
    state["h"] = h;
    Dictionary result;
    result["valid"] = true;
    result["legal"] = legal;
    result["covered"] = covered;
    result["reason"] = covered ? Variant("") : bounds.get("reason", "shoulder_direction_not_calibrated");
    result["state"] = state;
    result["minimum_radians"] = bounds["minimum_radians"];
    result["maximum_radians"] = bounds["maximum_radians"];
    result["violations"] = violations;
    result["direction_anatomical"] = shaft;
    result["plane_radians"] = bounds["plane_radians"];
    result["elevation_radians"] = bounds["elevation_radians"];
    result["revision"] = SHOULDER_REVISION;
    result["origin_id"] = calibration["origin_id"];
    result["reference_chart"] = chart;
    result["reference_warning"] = warning;
    result["coverage_kind"] = bounds["coverage_kind"];
    result["provisional"] = bounds["provisional"];
    result["coverage_sources"] = bounds["coverage_sources"];
    result["coverage_schema"] = profile.get("coverage_schema", "measured_band_only");
    return result;
}
