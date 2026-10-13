#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <memory>

namespace godot {

// Immutable closed-surface query snapshot for bounded cosmetic grip fitting.
// The caller supplies faces and queries in one explicit, common metre frame.
// No skeleton, scene node, physics server, or grip policy is owned here.
class GripPoseSurfaceKernel : public RefCounted {
    GDCLASS(GripPoseSurfaceKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    GripPoseSurfaceKernel();
    ~GripPoseSurfaceKernel();

    Dictionary prepare(const PackedVector3Array &faces);
    Dictionary evaluate(const PackedVector3Array &points) const;
    PackedByteArray intersects_segments(const PackedVector3Array &endpoints) const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace godot
