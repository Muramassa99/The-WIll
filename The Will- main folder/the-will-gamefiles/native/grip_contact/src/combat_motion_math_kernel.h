#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/typed_array.hpp>

namespace godot {

// Pure numerical batches. No scene objects, anatomy, grip state, acceptance
// policy or caller-owned arrays are changed or retained by either method.
class CombatMotionMathKernel : public RefCounted {
    GDCLASS(CombatMotionMathKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary solve_qp(const Array &h, const PackedFloat64Array &g,
            const Array &equalities, const Array &inequalities,
            const PackedFloat64Array &limits, const PackedFloat64Array &initial) const;
    TypedArray<Transform3D> forward_pose(const TypedArray<Transform3D> &poses,
            const PackedInt32Array &parents) const;
};

} // namespace godot
