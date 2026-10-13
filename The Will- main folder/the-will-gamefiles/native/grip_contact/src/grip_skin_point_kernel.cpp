#include "grip_skin_point_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>

#include <cmath>

namespace godot {

namespace {
Dictionary skin_failure(const char *reason) {
    Dictionary out;
    out["valid"] = false;
    out["reason"] = reason;
    return out;
}
}

void GripSkinPointKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("prepare", "carriers", "default_frames"), &GripSkinPointKernel::prepare);
    ClassDB::bind_method(D_METHOD("evaluate", "frames", "origin"), &GripSkinPointKernel::evaluate);
}

Dictionary GripSkinPointKernel::prepare(const Array &carriers, const Dictionary &default_frames) {
    ready_ = false;
    fixed_.clear(); offsets_.clear(); influences_.clear(); bones_.clear(); defaults_.clear();
    fixed_.reserve(carriers.size()); offsets_.reserve(carriers.size() + 1);
    Dictionary bone_indices;
    offsets_.push_back(0);
    for (int64_t sample = 0; sample < carriers.size(); ++sample) {
        if (carriers[sample].get_type() != Variant::DICTIONARY) return skin_failure("invalid_carrier");
        const Dictionary carrier = carriers[sample];
        if (carrier.get("fixed", Variant()).get_type() != Variant::VECTOR3 ||
                carrier.get("moving", Variant()).get_type() != Variant::DICTIONARY) return skin_failure("missing_carrier_coefficients");
        const Vector3 fixed = carrier["fixed"];
        if (!fixed.is_finite()) return skin_failure("nonfinite_fixed_point");
        fixed_.push_back(fixed);
        const Dictionary moving = carrier["moving"];
        // Dictionary iteration order is the original accumulation order used
        // by GDScript. Preserve it rather than regrouping or normalizing.
        const Array keys = moving.keys();
        for (int64_t i = 0; i < keys.size(); ++i) {
            if (keys[i].get_type() != Variant::STRING_NAME) return skin_failure("invalid_bone_name");
            const StringName bone = keys[i];
            if (moving[bone].get_type() != Variant::ARRAY) return skin_failure("invalid_influence");
            const Array influence = moving[bone];
            if (influence.size() != 2 || influence[0].get_type() != Variant::VECTOR3 ||
                    (influence[1].get_type() != Variant::FLOAT && influence[1].get_type() != Variant::INT)) return skin_failure("invalid_influence_coefficients");
            const Vector3 weighted_point = influence[0];
            const double weight_double = influence[1];
            const real_t weight = static_cast<real_t>(weight_double);
            if (!weighted_point.is_finite() || !std::isfinite(weight_double) || !std::isfinite(weight)) return skin_failure("nonfinite_influence");
            size_t index;
            if (bone_indices.has(bone)) index = static_cast<int64_t>(bone_indices[bone]);
            else {
                const Variant fallback = default_frames.get(bone, Variant());
                if (fallback.get_type() != Variant::TRANSFORM3D) return skin_failure("missing_default_bone_frame");
                const Transform3D frame = fallback;
                if (!frame.is_finite()) return skin_failure("nonfinite_default_bone_frame");
                index = bones_.size();
                bones_.push_back(bone); defaults_.push_back(frame);
                bone_indices[bone] = static_cast<int64_t>(index);
            }
            influences_.push_back({index, weighted_point, weight});
        }
        offsets_.push_back(influences_.size());
    }
    ready_ = true;
    Dictionary out;
    out["valid"] = true; out["sample_count"] = static_cast<int64_t>(fixed_.size());
    out["influence_count"] = static_cast<int64_t>(influences_.size());
    out["bone_count"] = static_cast<int64_t>(bones_.size());
    out["weights_normalized"] = false;
    out["arithmetic_policy"] = StringName("original_carrier_order_godot_real_t_no_fast_math");
    return out;
}

PackedVector3Array GripSkinPointKernel::evaluate(const Dictionary &frames, const Vector3 &origin) const {
    ERR_FAIL_COND_V_MSG(!ready_, PackedVector3Array(), "Skin point kernel is not prepared.");
    ERR_FAIL_COND_V_MSG(!origin.is_finite(), PackedVector3Array(), "Nonfinite skin query origin.");
    std::vector<Transform3D> current;
    current.reserve(bones_.size());
    for (size_t i = 0; i < bones_.size(); ++i) {
        const Variant value = frames.get(bones_[i], defaults_[i]);
        ERR_FAIL_COND_V_MSG(value.get_type() != Variant::TRANSFORM3D, PackedVector3Array(), "Invalid skin bone frame.");
        const Transform3D frame = value;
        ERR_FAIL_COND_V_MSG(!frame.is_finite(), PackedVector3Array(), "Nonfinite skin bone frame.");
        current.push_back(frame);
    }
    PackedVector3Array output;
    output.resize(static_cast<int64_t>(fixed_.size()));
    Vector3 *write = output.ptrw();
    for (size_t sample = 0; sample < fixed_.size(); ++sample) {
        Vector3 point = fixed_[sample];
        for (size_t i = offsets_[sample]; i < offsets_[sample + 1]; ++i) {
            const Influence &influence = influences_[i];
            const Transform3D &frame = current[influence.bone];
            point += frame.basis.xform(influence.weighted_point) + frame.origin * influence.weight;
        }
        write[sample] = point - origin;
        ERR_FAIL_COND_V_MSG(!write[sample].is_finite(), PackedVector3Array(), "Nonfinite evaluated skin point.");
    }
    return output;
}

} // namespace godot
