#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

// Compiled counterpart of slice_reachable_surface.gd. Produces candidate 2D
// geometry in the caller's named metric plane; does not certify a 3D grip.
class GripSliceKernel : public RefCounted {
    GDCLASS(GripSliceKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary slice(const Dictionary &surface, const Transform3D &plane_to_world,
        const StringName &plane_origin_id, double reach_m, double skin_padding_m) const;
};

} // namespace godot
