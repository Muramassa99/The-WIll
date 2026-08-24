#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstddef>
#include <cstdint>
#include <deque>
#include <memory>

namespace manifold {
class Manifold;
}

namespace godot {

class ForgeV2ManifoldBoolean : public RefCounted {
    GDCLASS(ForgeV2ManifoldBoolean, RefCounted)

protected:
    static void _bind_methods();

public:
    ForgeV2ManifoldBoolean();
    ~ForgeV2ManifoldBoolean();

    Dictionary get_backend_info() const;
    Dictionary get_state_info() const;
    Dictionary get_history_info() const;
    Dictionary set_history_window_enabled(bool enabled);
    Dictionary clear_state();
    Dictionary export_checkpoint_mesh();
    Dictionary reset_checkpoint_mesh(
        const PackedVector3Array &vertices,
        const PackedInt32Array &indices,
        int64_t accumulated_operation_count
    );
    Dictionary reset_mesh(
        const PackedVector3Array &vertices,
        const PackedInt32Array &indices
    );
    Dictionary add_mesh(
        const PackedVector3Array &vertices,
        const PackedInt32Array &indices
    );
    Dictionary undo_state();
    Dictionary redo_state();
    Dictionary compose_with_protected_mesh(
        const PackedVector3Array &base_vertices,
        const PackedInt32Array &base_indices,
        const PackedVector3Array &protected_vertices,
        const PackedInt32Array &protected_indices
    ) const;
    Dictionary compose_current_state_with_protected_mesh(
        const PackedVector3Array &protected_vertices,
        const PackedInt32Array &protected_indices
    ) const;
    Dictionary clip_current_state_with_protected_mesh(
        const PackedVector3Array &protected_vertices,
        const PackedInt32Array &protected_indices
    ) const;
    Dictionary union_meshes(
        const PackedVector3Array &base_vertices,
        const PackedInt32Array &base_indices,
        const PackedVector3Array &operand_vertices,
        const PackedInt32Array &operand_indices
    ) const;

private:
    static constexpr size_t kHistoryWindowCapacity = 5U;

    struct HistoryState {
        std::shared_ptr<manifold::Manifold> solid;
        int64_t vertex_count = 0;
        int64_t triangle_count = 0;
        double volume = 0.0;
        uint32_t current_operand_id = 0;
        bool distinguish_current_operand = false;
    };

    void append_history_metadata(Dictionary &result) const;
    void activate_history_state(size_t cursor);

    std::shared_ptr<manifold::Manifold> state_solid_;
    std::deque<HistoryState> history_states_;
    bool history_window_enabled_ = false;
    size_t active_tail_cursor_ = 0U;
    uint64_t checkpoint_operation_count_ = 0;
    uint64_t promotion_count_ = 0;
    uint64_t boolean_count_ = 0;
    uint64_t export_count_ = 0;
    uint64_t checkpoint_materialization_attempt_count_ = 0;
    uint64_t checkpoint_materialization_count_ = 0;
    String last_mode_ = "initial";
    uint64_t state_revision_ = 0;
    int64_t state_vertex_count_ = 0;
    int64_t state_triangle_count_ = 0;
    double state_volume_ = 0.0;
};

} // namespace godot
