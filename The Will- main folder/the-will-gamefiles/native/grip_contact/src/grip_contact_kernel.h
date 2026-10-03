#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <cstdint>
#include <memory>

namespace godot {

// Compiled numerical kernel for planar_skin_overlap_budget.gd. The caller
// remains responsible for preparing/validating polygon topology and supplying
// the named metric plane. A target is an immutable, per-instance snapshot.
class GripContactKernel : public RefCounted {
    GDCLASS(GripContactKernel, RefCounted)

protected:
    static void _bind_methods();

public:
    GripContactKernel();
    ~GripContactKernel();

    int64_t prepare_target(const Dictionary &prepared_target);
    Dictionary evaluate_segment(const Dictionary &segment, int64_t target_handle,
        double tolerance, double epsilon, int64_t budget,
        bool refine_after_cap, bool use_boundary_pruning);
    Dictionary last_phase_timings_us() const;
    bool release_target(int64_t target_handle);
    void clear_targets();

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};

} // namespace godot
