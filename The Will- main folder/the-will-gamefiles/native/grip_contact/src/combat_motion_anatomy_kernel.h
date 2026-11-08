#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform3d.hpp>

namespace godot {

// Pure candidate sampling of validated, request-local calibration/profile
// snapshots. Frames retain their caller-named reference through RL_BoneRoot.
// No scene state, grip acquisition, limit widening or acceptance policy.
class CombatMotionAnatomyKernel : public RefCounted {
    GDCLASS(CombatMotionAnatomyKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary sample_wrist(const Transform3D &forearm, const Transform3D &hand,
            const Dictionary &prepared, const Dictionary &state,
            double elbow_bend, double full_flexion) const;
    Dictionary measure_shoulder(const Transform3D &chest, const Transform3D &upperarm,
            const Transform3D &forearm, const Dictionary &prepared,
            const Dictionary &previous_state) const;
};

} // namespace godot
