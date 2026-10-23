#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

// One synchronous query over a caller-owned value snapshot. No scene objects,
// resource references, or prepared state survive a method call.
class CombatBodyCollisionKernel : public RefCounted {
    GDCLASS(CombatBodyCollisionKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary evaluate_weapon_pose(const Array &prepared, const Array &samples,
            const Transform3D &solved_transform, double clearance_offset) const;
    Array query_points(const Array &prepared, const PackedVector3Array &points,
            double clearance_offset) const;
};

} // namespace godot
