#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <vector>

namespace godot {

// One synchronous FK-value batch. No scene object, resource or mutable pose is
// retained. The script owner captures named-bone proxy metadata once per request.
class CombatForearmClearanceKernel : public RefCounted {
    GDCLASS(CombatForearmClearanceKernel, RefCounted)
    struct PreparedShape {
        int64_t bone = -1;
        Transform3D local;
        bool capsule = false;
        double radius = 0.0, half_mid = 0.0;
        Vector3 half;
    };
    struct PreparedPair { int64_t first = -1, second = -1; };
    std::vector<PreparedShape> prepared_shapes;
    std::vector<PreparedPair> prepared_pairs;
    Transform3D prepared_world;
    double prepared_normalization = 0.0;
    bool prepared_valid = false;
protected:
    static void _bind_methods();
public:
    Dictionary evaluate(const Dictionary &snapshot, const Array &candidate_globals) const;
    Dictionary prepare(const Dictionary &snapshot);
    PackedFloat64Array query_constraints(const Array &candidate_globals) const;
};

} // namespace godot
