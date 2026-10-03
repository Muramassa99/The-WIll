#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <memory>

namespace godot {

// One complete saved-wrapper contact query per native call. This class owns
// bounded per-acquisition prepared data and delegates numerical measurements
// to the already verified GripContactKernel; no second numerical solver.
class GripSavedContactKernel : public RefCounted {
    GDCLASS(GripSavedContactKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    GripSavedContactKernel();
    ~GripSavedContactKernel();

    bool begin_acquisition(const StringName &identity);
    bool reset();
    Dictionary prepare(const Dictionary &section);
    Dictionary evaluate(const Dictionary &prepared, const Array &segments,
        const StringName &origin_id, const Dictionary &depth_config);
    Dictionary statistics() const;

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace godot
