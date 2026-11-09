#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

// Read-only signature assembly. Field policy and normalized sparse controls
// belong to the caller; this kernel neither solves nor changes any pose.
class CombatPoseCaptureKernel : public RefCounted {
    GDCLASS(CombatPoseCaptureKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    String node_pose_signature(Object *node, const Array &excluded_fields,
            const Array &curl_fields, const Array &ordered_digits,
            const Dictionary &normalized_curls, int64_t required_usage) const;
};

} // namespace godot
