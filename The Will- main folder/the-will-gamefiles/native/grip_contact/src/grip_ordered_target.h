#pragma once

#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace godot {

// Exact prepared-packet counterpart of
// planar_skin_overlap_budget.gd::prepare_ordered_target. Explicit polygon
// adjacency is authoritative: no mesh-soup welding, repair, or edge removal.
Dictionary prepare_grip_ordered_target(const PackedVector2Array &polygon,
    const StringName &origin, const StringName &source, bool complete);

} // namespace godot
