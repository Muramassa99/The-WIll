#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

// Compiled equivalent of skin_plane_contact_query.gd::prepare_target. This
// prepares the supplied planar boundary only; it does not evaluate skin
// contact, change geometry, repair topology, or certify a three-dimensional
// solid. The named origin and complete reference packet are retained.
class GripTopologyKernel : public RefCounted {
    GDCLASS(GripTopologyKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    Dictionary prepare_target(const Array &segments, const StringName &origin_id) const;
};

} // namespace godot
