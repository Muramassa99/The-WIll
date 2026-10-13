#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/transform3d.hpp>

#include <vector>

namespace godot {

// A packed snapshot of the solver's original-weight carrier algebra. This
// class neither changes skin weights nor approximates or owns grip geometry.
class GripSkinPointKernel : public RefCounted {
    GDCLASS(GripSkinPointKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary prepare(const Array &carriers, const Dictionary &default_frames);
    PackedVector3Array evaluate(const Dictionary &frames, const Vector3 &origin) const;

private:
    struct Influence {
        size_t bone;
        Vector3 weighted_point;
        real_t weight;
    };
    bool ready_ = false;
    std::vector<Vector3> fixed_;
    std::vector<size_t> offsets_;
    std::vector<Influence> influences_;
    std::vector<StringName> bones_;
    std::vector<Transform3D> defaults_;
};

} // namespace godot
