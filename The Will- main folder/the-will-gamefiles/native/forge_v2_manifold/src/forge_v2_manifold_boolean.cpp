#include "forge_v2_manifold_boolean.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

#include <manifold/manifold.h>

#include <chrono>
#include <cmath>
#include <cstdint>
#include <limits>
#include <utility>

namespace godot {
namespace {

using Clock = std::chrono::steady_clock;

// Match Godot 4.7's CSGShape3D MeshGL64 import tolerance for the stateful
// live-compatibility lane. The stateless exact proof keeps tolerance zero.
constexpr double kGodotCsgMeshTolerance =
    2.0 * static_cast<double>(std::numeric_limits<float>::epsilon());

double elapsed_ms(const Clock::time_point &start, const Clock::time_point &end) {
    return std::chrono::duration<double, std::milli>(end - start).count();
}

const char *status_name(manifold::Manifold::Error status) {
    using Error = manifold::Manifold::Error;
    switch (status) {
        case Error::NoError: return "NoError";
        case Error::NonFiniteVertex: return "NonFiniteVertex";
        case Error::NotManifold: return "NotManifold";
        case Error::VertexOutOfBounds: return "VertexOutOfBounds";
        case Error::PropertiesWrongLength: return "PropertiesWrongLength";
        case Error::MissingPositionProperties: return "MissingPositionProperties";
        case Error::MergeVectorsDifferentLengths: return "MergeVectorsDifferentLengths";
        case Error::MergeIndexOutOfBounds: return "MergeIndexOutOfBounds";
        case Error::TransformWrongLength: return "TransformWrongLength";
        case Error::RunIndexWrongLength: return "RunIndexWrongLength";
        case Error::FaceIDWrongLength: return "FaceIDWrongLength";
        case Error::InvalidConstruction: return "InvalidConstruction";
        case Error::ResultTooLarge: return "ResultTooLarge";
    }
    return "Unknown";
}

Dictionary failure_result(const String &code, const String &message) {
    Dictionary result;
    result["ok"] = false;
    result["error_code"] = code;
    result["error_message"] = message;
    result["status"] = "NotRun";
    result["backend_id"] = "forge_v2_manifold_3_3_2_serial";
    return result;
}

struct PackedInput {
    manifold::MeshGL64 mesh;
    bool winding_reversed = false;
    double signed_volume = 0.0;
};

struct ExportPacket {
    PackedVector3Array vertices;
    PackedInt32Array indices;
    PackedInt32Array source_original_ids;
    PackedInt32Array source_face_ids;
    int64_t vertex_count = 0;
    int64_t triangle_count = 0;
};

struct StatefulTimings {
    double pack_ms = 0.0;
    double import_ms = 0.0;
    double boolean_ms = 0.0;
    double export_ms = 0.0;
    double commit_ms = 0.0;
};

struct ProtectedCompositionTimings {
    double import_base_ms = 0.0;
    double import_subtraction_ms = 0.0;
    double import_protected_ms = 0.0;
    double subtract_ms = 0.0;
    double union_ms = 0.0;
    double export_ms = 0.0;
};

bool pack_input(
    const PackedVector3Array &vertices,
    const PackedInt32Array &indices,
    uint32_t original_id,
    double tolerance,
    PackedInput &packed,
    String &error
) {
    if (vertices.is_empty()) {
        error = "vertex array is empty";
        return false;
    }
    if (indices.is_empty() || indices.size() % 3 != 0) {
        error = "index array must contain a non-empty triangle list";
        return false;
    }

    packed.mesh.numProp = 3;
    packed.mesh.vertProperties.reserve(static_cast<size_t>(vertices.size()) * 3U);
    for (int64_t i = 0; i < vertices.size(); ++i) {
        const Vector3 vertex = vertices[i];
        if (!vertex.is_finite()) {
            error = "vertex array contains a non-finite value";
            return false;
        }
        packed.mesh.vertProperties.push_back(static_cast<double>(vertex.x));
        packed.mesh.vertProperties.push_back(static_cast<double>(vertex.y));
        packed.mesh.vertProperties.push_back(static_cast<double>(vertex.z));
    }

    for (int64_t i = 0; i < indices.size(); i += 3) {
        const int32_t a = indices[i];
        const int32_t b = indices[i + 1];
        const int32_t c = indices[i + 2];
        if (a < 0 || b < 0 || c < 0 || a >= vertices.size() ||
            b >= vertices.size() || c >= vertices.size()) {
            error = "index array references a vertex outside the input array";
            return false;
        }
        if (a == b || b == c || c == a) {
            error = "index array contains a repeated triangle vertex";
            return false;
        }
        const Vector3 va = vertices[a];
        const Vector3 vb = vertices[b];
        const Vector3 vc = vertices[c];
        const Vector3 cross = (vb - va).cross(vc - va);
        if (!cross.is_finite() || cross.length_squared() <= 0.0) {
            error = "input contains a zero-area or non-finite triangle";
            return false;
        }
        packed.signed_volume += static_cast<double>(va.dot(vb.cross(vc))) / 6.0;
    }

    if (!std::isfinite(packed.signed_volume) || packed.signed_volume == 0.0) {
        error = "input signed volume is zero or non-finite";
        return false;
    }
    packed.winding_reversed = packed.signed_volume < 0.0;

    packed.mesh.triVerts.reserve(static_cast<size_t>(indices.size()));
    packed.mesh.faceID.reserve(static_cast<size_t>(indices.size() / 3));
    for (int64_t i = 0; i < indices.size(); i += 3) {
        const uint64_t a = static_cast<uint64_t>(indices[i]);
        const uint64_t b = static_cast<uint64_t>(indices[i + 1]);
        const uint64_t c = static_cast<uint64_t>(indices[i + 2]);
        packed.mesh.triVerts.push_back(a);
        packed.mesh.triVerts.push_back(packed.winding_reversed ? c : b);
        packed.mesh.triVerts.push_back(packed.winding_reversed ? b : c);
        packed.mesh.faceID.push_back(static_cast<uint64_t>(i / 3));
    }
    packed.mesh.runIndex = {0, static_cast<uint64_t>(packed.mesh.triVerts.size())};
    packed.mesh.runOriginalID = {original_id};
    packed.mesh.tolerance = tolerance;
    if (tolerance > 0.0) {
        // Godot's CSG packer calls Merge() before constructing Manifold. This
        // preserves already-indexed inputs and repairs compatible split
        // property vertices using the same tolerance contract.
        packed.mesh.Merge();
    }
    return true;
}

int32_t source_for_triangle(
    const manifold::MeshGL64 &mesh,
    size_t triangle_index,
    uint32_t base_id,
    uint32_t operand_id
) {
    if (mesh.runIndex.size() < 2 || mesh.runOriginalID.empty()) {
        return -1;
    }
    const uint64_t flat_index = static_cast<uint64_t>(triangle_index * 3U);
    for (size_t run = 0; run < mesh.runOriginalID.size(); ++run) {
        const uint64_t begin = mesh.runIndex[run];
        const uint64_t end = run + 1U < mesh.runIndex.size()
            ? mesh.runIndex[run + 1U]
            : static_cast<uint64_t>(mesh.triVerts.size());
        if (flat_index < begin || flat_index >= end) {
            continue;
        }
        if (mesh.runOriginalID[run] == base_id) {
            return 0;
        }
        if (mesh.runOriginalID[run] == operand_id) {
            return 1;
        }
        return -1;
    }
    return -1;
}

bool export_stateful_solid(
    const manifold::Manifold &solid,
    uint32_t current_operand_id,
    bool distinguish_current_operand,
    ExportPacket &packet,
    String &error_code,
    String &error_message
) {
    manifold::MeshGL64 output_mesh = solid.GetMeshGL64();
    if (output_mesh.numProp < 3 || output_mesh.vertProperties.size() % output_mesh.numProp != 0 ||
        output_mesh.triVerts.size() % 3U != 0) {
        error_code = "INVALID_OUTPUT_PACKET";
        error_message = "Manifold returned malformed mesh arrays";
        return false;
    }

    const size_t output_vertex_count = output_mesh.vertProperties.size() / output_mesh.numProp;
    if (output_vertex_count > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
        error_code = "OUTPUT_TOO_LARGE";
        error_message = "output vertex count exceeds PackedInt32Array capacity";
        return false;
    }

    packet.vertices.resize(static_cast<int64_t>(output_vertex_count));
    for (size_t i = 0; i < output_vertex_count; ++i) {
        const size_t offset = i * output_mesh.numProp;
        const Vector3 vertex(
            static_cast<real_t>(output_mesh.vertProperties[offset]),
            static_cast<real_t>(output_mesh.vertProperties[offset + 1U]),
            static_cast<real_t>(output_mesh.vertProperties[offset + 2U])
        );
        if (!vertex.is_finite()) {
            error_code = "NONFINITE_OUTPUT";
            error_message = "Manifold returned a non-finite vertex";
            return false;
        }
        packet.vertices.set(static_cast<int64_t>(i), vertex);
    }

    const size_t output_triangle_count = output_mesh.triVerts.size() / 3U;
    packet.indices.resize(static_cast<int64_t>(output_mesh.triVerts.size()));
    packet.source_original_ids.resize(static_cast<int64_t>(output_triangle_count));
    packet.source_face_ids.resize(static_cast<int64_t>(output_triangle_count));
    // MeshGL64 runIndex is ordered over triVerts. Advance once through it
    // instead of rescanning every historical run for every output triangle.
    // This keeps the same public base/current provenance values while making
    // state export linear in triangles plus runs.
    size_t source_run = 0;
    for (size_t triangle = 0; triangle < output_triangle_count; ++triangle) {
        const uint64_t a = output_mesh.triVerts[triangle * 3U];
        const uint64_t b = output_mesh.triVerts[triangle * 3U + 1U];
        const uint64_t c = output_mesh.triVerts[triangle * 3U + 2U];
        if (a >= output_vertex_count || b >= output_vertex_count || c >= output_vertex_count ||
            a > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
            b > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
            c > static_cast<uint64_t>(std::numeric_limits<int32_t>::max())) {
            error_code = "INVALID_OUTPUT_INDEX";
            error_message = "Manifold returned an invalid or oversized index";
            return false;
        }
        // Manifold emits positive/outward CCW. Forge's established ArrayMesh
        // convention is the opposite winding, so reverse exactly once.
        packet.indices.set(static_cast<int64_t>(triangle * 3U), static_cast<int32_t>(a));
        packet.indices.set(static_cast<int64_t>(triangle * 3U + 1U), static_cast<int32_t>(c));
        packet.indices.set(static_cast<int64_t>(triangle * 3U + 2U), static_cast<int32_t>(b));
        const uint64_t flat_index = static_cast<uint64_t>(triangle * 3U);
        while (
            source_run + 1U < output_mesh.runIndex.size() &&
            flat_index >= output_mesh.runIndex[source_run + 1U]
        ) {
            ++source_run;
        }
        int32_t source_id = -1;
        if (
            source_run < output_mesh.runOriginalID.size() &&
            source_run < output_mesh.runIndex.size() &&
            flat_index >= output_mesh.runIndex[source_run]
        ) {
            source_id = (
                distinguish_current_operand &&
                output_mesh.runOriginalID[source_run] == current_operand_id
            ) ? 1 : 0;
        }
        packet.source_original_ids.set(static_cast<int64_t>(triangle), source_id);
        const int32_t face_id = triangle < output_mesh.faceID.size() &&
            output_mesh.faceID[triangle] <= static_cast<uint64_t>(std::numeric_limits<int32_t>::max())
            ? static_cast<int32_t>(output_mesh.faceID[triangle])
            : -1;
        packet.source_face_ids.set(static_cast<int64_t>(triangle), face_id);
    }
    packet.vertex_count = static_cast<int64_t>(output_vertex_count);
    packet.triangle_count = static_cast<int64_t>(output_triangle_count);
    return true;
}

bool export_protected_composition(
    const manifold::Manifold &solid,
    uint32_t base_original_id,
    uint32_t protected_original_id,
    uint32_t subtraction_original_id,
    bool map_unknown_original_ids_to_base,
    ExportPacket &packet,
    int64_t &base_source_triangle_count,
    int64_t &protected_source_triangle_count,
    int64_t &subtraction_source_triangle_count,
    String &error_code,
    String &error_message
) {
    manifold::MeshGL64 output_mesh = solid.GetMeshGL64();
    if (
        output_mesh.numProp < 3 ||
        output_mesh.vertProperties.size() % output_mesh.numProp != 0 ||
        output_mesh.triVerts.size() % 3U != 0
    ) {
        error_code = "INVALID_OUTPUT_PACKET";
        error_message = "Manifold returned malformed mesh arrays";
        return false;
    }

    const size_t output_vertex_count =
        output_mesh.vertProperties.size() / output_mesh.numProp;
    if (output_vertex_count > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
        error_code = "OUTPUT_TOO_LARGE";
        error_message = "output vertex count exceeds PackedInt32Array capacity";
        return false;
    }

    packet.vertices.resize(static_cast<int64_t>(output_vertex_count));
    for (size_t i = 0; i < output_vertex_count; ++i) {
        const size_t offset = i * output_mesh.numProp;
        const Vector3 vertex(
            static_cast<real_t>(output_mesh.vertProperties[offset]),
            static_cast<real_t>(output_mesh.vertProperties[offset + 1U]),
            static_cast<real_t>(output_mesh.vertProperties[offset + 2U])
        );
        if (!vertex.is_finite()) {
            error_code = "NONFINITE_OUTPUT";
            error_message = "Manifold returned a non-finite vertex";
            return false;
        }
        packet.vertices.set(static_cast<int64_t>(i), vertex);
    }

    const size_t output_triangle_count = output_mesh.triVerts.size() / 3U;
    if (
        output_triangle_count > 0U &&
        (output_mesh.runIndex.empty() || output_mesh.runOriginalID.empty())
    ) {
        error_code = "MISSING_OUTPUT_PROVENANCE";
        error_message = "Manifold returned triangles without original-mesh provenance";
        return false;
    }

    packet.indices.resize(static_cast<int64_t>(output_mesh.triVerts.size()));
    packet.source_original_ids.resize(static_cast<int64_t>(output_triangle_count));
    packet.source_face_ids.resize(static_cast<int64_t>(output_triangle_count));
    base_source_triangle_count = 0;
    protected_source_triangle_count = 0;
    subtraction_source_triangle_count = 0;

    size_t source_run = 0U;
    for (size_t triangle = 0; triangle < output_triangle_count; ++triangle) {
        const uint64_t a = output_mesh.triVerts[triangle * 3U];
        const uint64_t b = output_mesh.triVerts[triangle * 3U + 1U];
        const uint64_t c = output_mesh.triVerts[triangle * 3U + 2U];
        if (
            a >= output_vertex_count || b >= output_vertex_count ||
            c >= output_vertex_count ||
            a > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
            b > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
            c > static_cast<uint64_t>(std::numeric_limits<int32_t>::max())
        ) {
            error_code = "INVALID_OUTPUT_INDEX";
            error_message = "Manifold returned an invalid or oversized index";
            return false;
        }

        // Manifold emits outward CCW. Forge ArrayMesh packets use the opposite
        // convention, so the composed packet reverses winding exactly once.
        packet.indices.set(
            static_cast<int64_t>(triangle * 3U),
            static_cast<int32_t>(a)
        );
        packet.indices.set(
            static_cast<int64_t>(triangle * 3U + 1U),
            static_cast<int32_t>(c)
        );
        packet.indices.set(
            static_cast<int64_t>(triangle * 3U + 2U),
            static_cast<int32_t>(b)
        );

        const uint64_t flat_index = static_cast<uint64_t>(triangle * 3U);
        while (
            source_run + 1U < output_mesh.runIndex.size() &&
            flat_index >= output_mesh.runIndex[source_run + 1U]
        ) {
            ++source_run;
        }
        if (
            source_run >= output_mesh.runIndex.size() ||
            source_run >= output_mesh.runOriginalID.size() ||
            flat_index < output_mesh.runIndex[source_run]
        ) {
            error_code = "INVALID_OUTPUT_PROVENANCE";
            error_message = "Manifold returned an invalid triangle provenance run";
            return false;
        }

        const uint32_t original_id = output_mesh.runOriginalID[source_run];
        int32_t source_id = -1;
        if (original_id == protected_original_id) {
            source_id = 1;
            ++protected_source_triangle_count;
        } else if (original_id == subtraction_original_id) {
            source_id = 2;
            ++subtraction_source_triangle_count;
        } else if (
            original_id == base_original_id ||
            map_unknown_original_ids_to_base
        ) {
            source_id = 0;
            ++base_source_triangle_count;
        } else {
            error_code = "UNKNOWN_OUTPUT_SOURCE";
            error_message = "Manifold returned a triangle with an unknown original mesh ID";
            return false;
        }
        packet.source_original_ids.set(static_cast<int64_t>(triangle), source_id);

        const int32_t face_id =
            triangle < output_mesh.faceID.size() &&
                output_mesh.faceID[triangle] <=
                    static_cast<uint64_t>(std::numeric_limits<int32_t>::max())
            ? static_cast<int32_t>(output_mesh.faceID[triangle])
            : -1;
        packet.source_face_ids.set(static_cast<int64_t>(triangle), face_id);
    }

    packet.vertex_count = static_cast<int64_t>(output_vertex_count);
    packet.triangle_count = static_cast<int64_t>(output_triangle_count);
    return true;
}

void append_state_metadata(
    Dictionary &result,
    bool initialized,
    uint64_t revision,
    int64_t vertex_count,
    int64_t triangle_count,
    double volume
) {
    result["state_initialized"] = initialized;
    result["revision"] = static_cast<int64_t>(revision);
    result["state_revision"] = static_cast<int64_t>(revision);
    result["state_vertex_count"] = vertex_count;
    result["state_triangle_count"] = triangle_count;
    result["state_volume_m3"] = volume;
}

void append_stateful_timings(
    Dictionary &result,
    const StatefulTimings &timings,
    const Clock::time_point &total_start,
    const Clock::time_point &total_end,
    bool cached_base_reused
) {
    result["pack_ms"] = timings.pack_ms;
    result["import_ms"] = timings.import_ms;
    result["boolean_ms"] = timings.boolean_ms;
    result["export_ms"] = timings.export_ms;
    result["commit_ms"] = timings.commit_ms;
    result["total_native_ms"] = elapsed_ms(total_start, total_end);
    result["cached_base_reused"] = cached_base_reused;
    // Keep the original proof's phase names available to metric consumers.
    result["import_a_ms"] = cached_base_reused ? 0.0 : timings.pack_ms + timings.import_ms;
    result["import_b_ms"] = cached_base_reused ? timings.pack_ms + timings.import_ms : 0.0;
}

void append_protected_composition_timings(
    Dictionary &result,
    const ProtectedCompositionTimings &timings,
    const Clock::time_point &total_start,
    const Clock::time_point &total_end
) {
    result["import_base_ms"] = timings.import_base_ms;
    result["import_subtraction_ms"] = timings.import_subtraction_ms;
    result["import_protected_ms"] = timings.import_protected_ms;
    result["import_protected_total_ms"] =
        timings.import_subtraction_ms + timings.import_protected_ms;
    result["imports_ms"] =
        timings.import_base_ms + timings.import_subtraction_ms +
        timings.import_protected_ms;
    result["import_a_ms"] = timings.import_base_ms;
    result["import_b_ms"] =
        timings.import_subtraction_ms + timings.import_protected_ms;
    result["subtract_ms"] = timings.subtract_ms;
    result["union_ms"] = timings.union_ms;
    result["boolean_ms"] = timings.subtract_ms + timings.union_ms;
    result["export_ms"] = timings.export_ms;
    result["total_native_ms"] = elapsed_ms(total_start, total_end);
}

Dictionary protected_composition_result_base(
    uint32_t base_original_id,
    uint32_t protected_original_id,
    uint32_t subtraction_original_id,
    int64_t base_vertex_count,
    int64_t base_triangle_count,
    int64_t protected_vertex_count,
    int64_t protected_triangle_count,
    bool base_empty
) {
    Dictionary result;
    result["ok"] = false;
    result["operation"] = "compose_with_protected_mesh";
    result["composition"] = "(base - protected) union protected";
    result["error_code"] = "";
    result["error_message"] = "";
    result["status"] = "NotRun";
    result["backend_id"] = "forge_v2_manifold_3_3_2_serial";
    result["manifold_version"] = "3.3.2";
    result["parallel"] = false;
    result["operation_scope"] = "stateless_exact_protected_composition";
    result["base_empty"] = base_empty;
    result["subtract_performed"] = false;
    result["union_performed"] = false;
    result["base_status"] = "NotRun";
    result["protected_status"] = "NotRun";
    result["subtraction_input_status"] = "NotRun";
    result["subtract_status"] = "NotRun";
    result["union_status"] = "NotRun";
    result["input_base_vertex_count"] = base_vertex_count;
    result["input_base_triangle_count"] = base_triangle_count;
    result["input_protected_vertex_count"] = protected_vertex_count;
    result["input_protected_triangle_count"] = protected_triangle_count;
    result["input_subtraction_vertex_count"] = protected_vertex_count;
    result["input_subtraction_triangle_count"] = protected_triangle_count;
    // Preserve the stateless A/B naming used by union_meshes as aliases.
    result["input_a_vertex_count"] = base_vertex_count;
    result["input_a_triangle_count"] = base_triangle_count;
    result["input_b_vertex_count"] = protected_vertex_count;
    result["input_b_triangle_count"] = protected_triangle_count;
    result["base_original_id"] = static_cast<int64_t>(base_original_id);
    result["protected_original_id"] = static_cast<int64_t>(protected_original_id);
    result["subtraction_original_id"] =
        static_cast<int64_t>(subtraction_original_id);
    result["source_base_id"] = static_cast<int64_t>(0);
    result["source_protected_id"] = static_cast<int64_t>(1);
    result["source_subtraction_id"] = static_cast<int64_t>(2);
    result["source_id_semantics"] =
        "0=ordinary_base,1=protected,2=subtraction_cut";
    result["input_base_winding_reversed"] = false;
    result["input_protected_winding_reversed"] = false;
    result["input_subtraction_winding_reversed"] = false;
    result["input_a_winding_reversed"] = false;
    result["input_b_winding_reversed"] = false;
    result["base_volume_m3"] = 0.0;
    result["protected_volume_m3"] = 0.0;
    result["subtraction_input_volume_m3"] = 0.0;
    result["subtracted_volume_m3"] = 0.0;
    result["output_volume_m3"] = 0.0;
    result["manifold_volume_m3"] = 0.0;
    result["output_vertex_count"] = static_cast<int64_t>(0);
    result["output_triangle_count"] = static_cast<int64_t>(0);
    result["base_source_triangle_count"] = static_cast<int64_t>(0);
    result["protected_source_triangle_count"] = static_cast<int64_t>(0);
    result["subtraction_source_triangle_count"] = static_cast<int64_t>(0);
    result["watertight"] = false;
    return result;
}

Dictionary stateful_result_base(const String &operation) {
    Dictionary result;
    result["ok"] = false;
    result["committed"] = false;
    result["operation"] = operation;
    result["error_code"] = "";
    result["error_message"] = "";
    result["status"] = "NotRun";
    result["backend_id"] = "forge_v2_manifold_3_3_2_serial";
    result["manifold_version"] = "3.3.2";
    result["parallel"] = false;
    return result;
}

void append_export_packet(Dictionary &result, const ExportPacket &packet) {
    result["output_vertex_count"] = packet.vertex_count;
    result["output_triangle_count"] = packet.triangle_count;
    result["vertices"] = packet.vertices;
    result["indices"] = packet.indices;
    result["source_original_ids"] = packet.source_original_ids;
    result["source_face_ids"] = packet.source_face_ids;
}

} // namespace

ForgeV2ManifoldBoolean::ForgeV2ManifoldBoolean() {
    // The live path defaults to one empty/current slot. The S0 checkpoint plus
    // five-state tail is retained only after an explicit pre-reset opt-in.
    history_states_.emplace_back();
}

ForgeV2ManifoldBoolean::~ForgeV2ManifoldBoolean() = default;

void ForgeV2ManifoldBoolean::append_history_metadata(Dictionary &result) const {
    const size_t retained_state_count = history_states_.size();
    const size_t tail_timeline_count = history_window_enabled_ && retained_state_count > 0U
        ? retained_state_count - 1U
        : 0U;
    const size_t redo_count = history_window_enabled_ && tail_timeline_count >= active_tail_cursor_
        ? tail_timeline_count - active_tail_cursor_
        : 0U;
    int64_t retained_total_vertices = 0;
    int64_t retained_total_triangles = 0;
    for (const HistoryState &state : history_states_) {
        retained_total_vertices += state.vertex_count;
        retained_total_triangles += state.triangle_count;
    }

    result["history_window_enabled"] = history_window_enabled_;
    result["history_window_capacity"] = static_cast<int64_t>(
        history_window_enabled_ ? kHistoryWindowCapacity : 0U
    );
    result["checkpoint_operation_count"] =
        static_cast<int64_t>(checkpoint_operation_count_);
    result["active_tail_cursor"] = static_cast<int64_t>(active_tail_cursor_);
    result["tail_timeline_count"] = static_cast<int64_t>(tail_timeline_count);
    result["redo_count"] = static_cast<int64_t>(redo_count);
    result["retained_state_count"] = static_cast<int64_t>(retained_state_count);
    result["retained_total_vertices"] = retained_total_vertices;
    result["retained_total_triangles"] = retained_total_triangles;
    result["promotion_count"] = static_cast<int64_t>(promotion_count_);
    result["boolean_count"] = static_cast<int64_t>(boolean_count_);
    result["export_count"] = static_cast<int64_t>(export_count_);
    result["checkpoint_materialization_attempt_count"] = static_cast<int64_t>(
        checkpoint_materialization_attempt_count_
    );
    result["checkpoint_materialization_count"] = static_cast<int64_t>(
        checkpoint_materialization_count_
    );
    result["last_mode"] = last_mode_;
    // Promotion is pointer/deque ownership movement only. These explicit
    // deltas make accidental Boolean or mesh-export work verifier-visible.
    result["promotion_boolean_delta"] = static_cast<int64_t>(0);
    result["promotion_export_delta"] = static_cast<int64_t>(0);
}

void ForgeV2ManifoldBoolean::activate_history_state(size_t cursor) {
    active_tail_cursor_ = cursor;
    const HistoryState &state = history_states_[cursor];
    state_solid_ = state.solid;
    state_vertex_count_ = state.vertex_count;
    state_triangle_count_ = state.triangle_count;
    state_volume_ = state.volume;
}

void ForgeV2ManifoldBoolean::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_backend_info"), &ForgeV2ManifoldBoolean::get_backend_info);
    ClassDB::bind_method(D_METHOD("get_state_info"), &ForgeV2ManifoldBoolean::get_state_info);
    ClassDB::bind_method(D_METHOD("get_history_info"), &ForgeV2ManifoldBoolean::get_history_info);
    ClassDB::bind_method(
        D_METHOD("set_history_window_enabled", "enabled"),
        &ForgeV2ManifoldBoolean::set_history_window_enabled
    );
    ClassDB::bind_method(D_METHOD("clear_state"), &ForgeV2ManifoldBoolean::clear_state);
    ClassDB::bind_method(
        D_METHOD("export_checkpoint_mesh"),
        &ForgeV2ManifoldBoolean::export_checkpoint_mesh
    );
    ClassDB::bind_method(
        D_METHOD(
            "reset_checkpoint_mesh",
            "vertices",
            "indices",
            "accumulated_operation_count"
        ),
        &ForgeV2ManifoldBoolean::reset_checkpoint_mesh
    );
    ClassDB::bind_method(
        D_METHOD("reset_mesh", "vertices", "indices"),
        &ForgeV2ManifoldBoolean::reset_mesh
    );
    ClassDB::bind_method(
        D_METHOD("add_mesh", "vertices", "indices"),
        &ForgeV2ManifoldBoolean::add_mesh
    );
    ClassDB::bind_method(D_METHOD("undo_state"), &ForgeV2ManifoldBoolean::undo_state);
    ClassDB::bind_method(D_METHOD("redo_state"), &ForgeV2ManifoldBoolean::redo_state);
    ClassDB::bind_method(
        D_METHOD(
            "compose_with_protected_mesh",
            "base_vertices",
            "base_indices",
            "protected_vertices",
            "protected_indices"
        ),
        &ForgeV2ManifoldBoolean::compose_with_protected_mesh
    );
    ClassDB::bind_method(
        D_METHOD(
            "compose_current_state_with_protected_mesh",
            "protected_vertices",
            "protected_indices"
        ),
        &ForgeV2ManifoldBoolean::compose_current_state_with_protected_mesh
    );
    ClassDB::bind_method(
        D_METHOD(
            "clip_current_state_with_protected_mesh",
            "protected_vertices",
            "protected_indices"
        ),
        &ForgeV2ManifoldBoolean::clip_current_state_with_protected_mesh
    );
    ClassDB::bind_method(
        D_METHOD(
            "union_meshes",
            "base_vertices",
            "base_indices",
            "operand_vertices",
            "operand_indices"
        ),
        &ForgeV2ManifoldBoolean::union_meshes
    );
}

Dictionary ForgeV2ManifoldBoolean::compose_with_protected_mesh(
    const PackedVector3Array &base_vertices,
    const PackedInt32Array &base_indices,
    const PackedVector3Array &protected_vertices,
    const PackedInt32Array &protected_indices
) const {
    const Clock::time_point total_start = Clock::now();
    const uint32_t first_id = manifold::Manifold::ReserveIDs(3);
    const uint32_t base_original_id = first_id;
    const uint32_t protected_original_id = first_id + 1U;
    const uint32_t subtraction_original_id = first_id + 2U;
    const bool base_vertices_empty = base_vertices.is_empty();
    const bool base_indices_empty = base_indices.is_empty();
    const bool base_empty = base_vertices_empty && base_indices_empty;

    ProtectedCompositionTimings timings;
    Dictionary result = protected_composition_result_base(
        base_original_id,
        protected_original_id,
        subtraction_original_id,
        base_vertices.size(),
        base_indices.size() / 3,
        protected_vertices.size(),
        protected_indices.size() / 3,
        base_empty
    );

    auto finish_failure = [&](
        const String &code,
        const String &message,
        const String &status
    ) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = status;
        append_protected_composition_timings(result, timings, total_start, end);
        return result;
    };

    if (base_vertices_empty != base_indices_empty) {
        return finish_failure(
            "INVALID_BASE_MESH",
            "base vertices and indices must either both be empty or both be populated",
            "NotRun"
        );
    }

    String error;
    PackedInput protected_input;
    const Clock::time_point import_protected_start = Clock::now();
    const bool protected_packed = pack_input(
        protected_vertices,
        protected_indices,
        protected_original_id,
        0.0,
        protected_input,
        error
    );
    if (!protected_packed) {
        const Clock::time_point import_protected_end = Clock::now();
        timings.import_protected_ms = elapsed_ms(
            import_protected_start,
            import_protected_end
        );
        return finish_failure("INVALID_PROTECTED_MESH", error, "NotRun");
    }
    manifold::Manifold protected_solid(protected_input.mesh);
    const manifold::Manifold::Error protected_status = protected_solid.Status();
    double protected_volume = 0.0;
    if (protected_status == manifold::Manifold::Error::NoError) {
        protected_volume = protected_solid.Volume();
    }
    const Clock::time_point import_protected_end = Clock::now();
    timings.import_protected_ms = elapsed_ms(
        import_protected_start,
        import_protected_end
    );
    result["input_protected_winding_reversed"] = protected_input.winding_reversed;
    result["input_b_winding_reversed"] = protected_input.winding_reversed;
    result["protected_status"] = status_name(protected_status);
    result["protected_volume_m3"] = protected_volume;
    if (protected_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "PROTECTED_MANIFOLD_" + String(status_name(protected_status)),
            "protected mesh is not a valid Manifold solid",
            status_name(protected_status)
        );
    }

    PackedInput subtraction_input;
    const Clock::time_point import_subtraction_start = Clock::now();
    const bool subtraction_packed = pack_input(
        protected_vertices,
        protected_indices,
        subtraction_original_id,
        0.0,
        subtraction_input,
        error
    );
    if (!subtraction_packed) {
        const Clock::time_point import_subtraction_end = Clock::now();
        timings.import_subtraction_ms = elapsed_ms(
            import_subtraction_start,
            import_subtraction_end
        );
        return finish_failure("INVALID_PROTECTED_MESH", error, "NotRun");
    }
    manifold::Manifold subtraction_solid(subtraction_input.mesh);
    const manifold::Manifold::Error subtraction_input_status =
        subtraction_solid.Status();
    double subtraction_input_volume = 0.0;
    if (subtraction_input_status == manifold::Manifold::Error::NoError) {
        subtraction_input_volume = subtraction_solid.Volume();
    }
    const Clock::time_point import_subtraction_end = Clock::now();
    timings.import_subtraction_ms = elapsed_ms(
        import_subtraction_start,
        import_subtraction_end
    );
    result["input_subtraction_winding_reversed"] =
        subtraction_input.winding_reversed;
    result["subtraction_input_status"] = status_name(subtraction_input_status);
    result["subtraction_input_volume_m3"] = subtraction_input_volume;
    if (subtraction_input_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "SUBTRACTION_INPUT_MANIFOLD_" +
                String(status_name(subtraction_input_status)),
            "subtraction copy of protected mesh is not a valid Manifold solid",
            status_name(subtraction_input_status)
        );
    }

    manifold::Manifold output_solid;
    double output_volume = 0.0;
    if (base_empty) {
        // A Handle-only workpiece is already the exact protected composition.
        // Avoid manufacturing an empty mesh or spending two no-op Booleans.
        output_solid = protected_solid;
        output_volume = protected_volume;
        result["base_status"] = "Empty";
        result["subtract_status"] = "SkippedEmptyBase";
        result["union_status"] = "SkippedEmptyBase";
    } else {
        PackedInput base_input;
        const Clock::time_point import_base_start = Clock::now();
        const bool base_packed = pack_input(
            base_vertices,
            base_indices,
            base_original_id,
            0.0,
            base_input,
            error
        );
        if (!base_packed) {
            const Clock::time_point import_base_end = Clock::now();
            timings.import_base_ms = elapsed_ms(import_base_start, import_base_end);
            return finish_failure("INVALID_BASE_MESH", error, "NotRun");
        }
        manifold::Manifold base_solid(base_input.mesh);
        const manifold::Manifold::Error base_status = base_solid.Status();
        double base_volume = 0.0;
        if (base_status == manifold::Manifold::Error::NoError) {
            base_volume = base_solid.Volume();
        }
        const Clock::time_point import_base_end = Clock::now();
        timings.import_base_ms = elapsed_ms(import_base_start, import_base_end);
        result["input_base_winding_reversed"] = base_input.winding_reversed;
        result["input_a_winding_reversed"] = base_input.winding_reversed;
        result["base_status"] = status_name(base_status);
        result["base_volume_m3"] = base_volume;
        if (base_status != manifold::Manifold::Error::NoError) {
            return finish_failure(
                "BASE_MANIFOLD_" + String(status_name(base_status)),
                "base mesh is not a valid Manifold solid",
                status_name(base_status)
            );
        }

        const Clock::time_point subtract_start = Clock::now();
        manifold::Manifold subtracted_solid = base_solid.Boolean(
            subtraction_solid,
            manifold::OpType::Subtract
        );
        const manifold::Manifold::Error subtract_status = subtracted_solid.Status();
        double subtracted_volume = 0.0;
        if (subtract_status == manifold::Manifold::Error::NoError) {
            subtracted_volume = subtracted_solid.Volume();
        }
        const Clock::time_point subtract_end = Clock::now();
        timings.subtract_ms = elapsed_ms(subtract_start, subtract_end);
        result["subtract_performed"] = true;
        result["subtract_status"] = status_name(subtract_status);
        result["subtracted_volume_m3"] = subtracted_volume;
        if (subtract_status != manifold::Manifold::Error::NoError) {
            return finish_failure(
                "SUBTRACT_MANIFOLD_" + String(status_name(subtract_status)),
                "base-minus-protected result is not a valid Manifold solid",
                status_name(subtract_status)
            );
        }

        const Clock::time_point union_start = Clock::now();
        output_solid = subtracted_solid.Boolean(
            protected_solid,
            manifold::OpType::Add
        );
        const manifold::Manifold::Error union_status = output_solid.Status();
        if (union_status == manifold::Manifold::Error::NoError) {
            output_volume = output_solid.Volume();
        }
        const Clock::time_point union_end = Clock::now();
        timings.union_ms = elapsed_ms(union_start, union_end);
        result["union_performed"] = true;
        result["union_status"] = status_name(union_status);
        if (union_status != manifold::Manifold::Error::NoError) {
            return finish_failure(
                "UNION_MANIFOLD_" + String(status_name(union_status)),
                "protected composition union is not a valid Manifold solid",
                status_name(union_status)
            );
        }
    }

    ExportPacket packet;
    int64_t base_source_triangle_count = 0;
    int64_t protected_source_triangle_count = 0;
    int64_t subtraction_source_triangle_count = 0;
    String export_error_code;
    String export_error_message;
    const Clock::time_point export_start = Clock::now();
    const bool export_ok = export_protected_composition(
        output_solid,
        base_original_id,
        protected_original_id,
        subtraction_original_id,
        false,
        packet,
        base_source_triangle_count,
        protected_source_triangle_count,
        subtraction_source_triangle_count,
        export_error_code,
        export_error_message
    );
    const Clock::time_point export_end = Clock::now();
    timings.export_ms = elapsed_ms(export_start, export_end);
    if (!export_ok) {
        return finish_failure(export_error_code, export_error_message, "NoError");
    }

    result["ok"] = true;
    result["status"] = "NoError";
    result["output_volume_m3"] = output_volume;
    result["manifold_volume_m3"] = output_volume;
    result["base_source_triangle_count"] = base_source_triangle_count;
    result["protected_source_triangle_count"] = protected_source_triangle_count;
    result["subtraction_source_triangle_count"] =
        subtraction_source_triangle_count;
    result["watertight"] = true;
    append_export_packet(result, packet);
    // source_original_ids is the established packet key; source_ids makes the
    // 0/1/2 material contract explicit without forcing consumers to rename.
    result["source_ids"] = packet.source_original_ids;
    append_protected_composition_timings(
        result,
        timings,
        total_start,
        export_end
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::compose_current_state_with_protected_mesh(
    const PackedVector3Array &protected_vertices,
    const PackedInt32Array &protected_indices
) const {
    const Clock::time_point total_start = Clock::now();
    const uint32_t first_id = manifold::Manifold::ReserveIDs(3);
    const uint32_t base_original_id = first_id;
    const uint32_t protected_original_id = first_id + 1U;
    const uint32_t subtraction_original_id = first_id + 2U;

    ProtectedCompositionTimings timings;
    Dictionary result = protected_composition_result_base(
        base_original_id,
        protected_original_id,
        subtraction_original_id,
        state_vertex_count_,
        state_triangle_count_,
        protected_vertices.size(),
        protected_indices.size() / 3,
        state_solid_ == nullptr
    );
    result["operation"] = "compose_current_state_with_protected_mesh";
    result["operation_scope"] =
        "current_state_exact_protected_composition";
    result["source_state_revision"] = static_cast<int64_t>(state_revision_);
    result["cached_base_reused"] = true;
    result["state_original_ids_map_to_base"] = true;
    result["base_original_id_applied_to_state"] = false;

    auto finish_failure = [&result, &timings, &total_start](
        const String &code,
        const String &message,
        const String &status
    ) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = status;
        append_protected_composition_timings(result, timings, total_start, end);
        return result;
    };

    if (!state_solid_) {
        result["base_status"] = "Empty";
    } else {
        const manifold::Manifold::Error base_status = state_solid_->Status();
        result["base_status"] = status_name(base_status);
        result["base_volume_m3"] = state_volume_;
        if (base_status != manifold::Manifold::Error::NoError) {
            return finish_failure(
                "STATE_MANIFOLD_" + String(status_name(base_status)),
                "current Manifold state is not a valid solid",
                status_name(base_status)
            );
        }
    }

    String error;
    PackedInput protected_input;
    const Clock::time_point import_protected_start = Clock::now();
    const bool protected_packed = pack_input(
        protected_vertices,
        protected_indices,
        protected_original_id,
        0.0,
        protected_input,
        error
    );
    if (!protected_packed) {
        const Clock::time_point import_protected_end = Clock::now();
        timings.import_protected_ms = elapsed_ms(
            import_protected_start,
            import_protected_end
        );
        return finish_failure("INVALID_PROTECTED_MESH", error, "NotRun");
    }
    manifold::Manifold protected_solid(protected_input.mesh);
    const manifold::Manifold::Error protected_status = protected_solid.Status();
    double protected_volume = 0.0;
    if (protected_status == manifold::Manifold::Error::NoError) {
        protected_volume = protected_solid.Volume();
    }
    const Clock::time_point import_protected_end = Clock::now();
    timings.import_protected_ms = elapsed_ms(
        import_protected_start,
        import_protected_end
    );
    result["input_protected_winding_reversed"] =
        protected_input.winding_reversed;
    result["input_b_winding_reversed"] = protected_input.winding_reversed;
    result["protected_status"] = status_name(protected_status);
    result["protected_volume_m3"] = protected_volume;
    if (protected_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "PROTECTED_MANIFOLD_" + String(status_name(protected_status)),
            "protected mesh is not a valid Manifold solid",
            status_name(protected_status)
        );
    }

    if (!state_solid_) {
        // A Handle-only workpiece is already the exact protected composition.
        // Preserve the current-state revision and skip the subtraction copy as
        // well as both Booleans; this const query must not touch live history.
        result["subtraction_input_status"] = "SkippedEmptyBase";
        result["subtract_performed"] = false;
        result["subtract_status"] = "SkippedEmptyBase";
        result["union_performed"] = false;
        result["union_status"] = "SkippedEmptyBase";

        ExportPacket packet;
        int64_t base_source_triangle_count = 0;
        int64_t protected_source_triangle_count = 0;
        int64_t subtraction_source_triangle_count = 0;
        String export_error_code;
        String export_error_message;
        const Clock::time_point export_start = Clock::now();
        const bool export_ok = export_protected_composition(
            protected_solid,
            base_original_id,
            protected_original_id,
            subtraction_original_id,
            true,
            packet,
            base_source_triangle_count,
            protected_source_triangle_count,
            subtraction_source_triangle_count,
            export_error_code,
            export_error_message
        );
        const Clock::time_point export_end = Clock::now();
        timings.export_ms = elapsed_ms(export_start, export_end);
        if (!export_ok) {
            return finish_failure(
                export_error_code,
                export_error_message,
                "NoError"
            );
        }
        if (
            base_source_triangle_count != 0 ||
            protected_source_triangle_count != packet.triangle_count ||
            subtraction_source_triangle_count != 0
        ) {
            return finish_failure(
                "HANDLE_ONLY_SOURCE_CLASSIFICATION_INVALID",
                "empty-state protected composition did not emit only protected triangles",
                "NoError"
            );
        }

        result["ok"] = true;
        result["status"] = "NoError";
        result["output_volume_m3"] = protected_volume;
        result["manifold_volume_m3"] = protected_volume;
        result["base_source_triangle_count"] = base_source_triangle_count;
        result["protected_source_triangle_count"] =
            protected_source_triangle_count;
        result["subtraction_source_triangle_count"] =
            subtraction_source_triangle_count;
        result["watertight"] = true;
        append_export_packet(result, packet);
        result["source_ids"] = packet.source_original_ids;
        append_protected_composition_timings(
            result,
            timings,
            total_start,
            export_end
        );
        return result;
    }

    PackedInput subtraction_input;
    const Clock::time_point import_subtraction_start = Clock::now();
    const bool subtraction_packed = pack_input(
        protected_vertices,
        protected_indices,
        subtraction_original_id,
        0.0,
        subtraction_input,
        error
    );
    if (!subtraction_packed) {
        const Clock::time_point import_subtraction_end = Clock::now();
        timings.import_subtraction_ms = elapsed_ms(
            import_subtraction_start,
            import_subtraction_end
        );
        return finish_failure("INVALID_PROTECTED_MESH", error, "NotRun");
    }
    manifold::Manifold subtraction_solid(subtraction_input.mesh);
    const manifold::Manifold::Error subtraction_input_status =
        subtraction_solid.Status();
    double subtraction_input_volume = 0.0;
    if (subtraction_input_status == manifold::Manifold::Error::NoError) {
        subtraction_input_volume = subtraction_solid.Volume();
    }
    const Clock::time_point import_subtraction_end = Clock::now();
    timings.import_subtraction_ms = elapsed_ms(
        import_subtraction_start,
        import_subtraction_end
    );
    result["input_subtraction_winding_reversed"] =
        subtraction_input.winding_reversed;
    result["subtraction_input_status"] = status_name(subtraction_input_status);
    result["subtraction_input_volume_m3"] = subtraction_input_volume;
    if (subtraction_input_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "SUBTRACTION_INPUT_MANIFOLD_" +
                String(status_name(subtraction_input_status)),
            "subtraction copy of protected mesh is not a valid Manifold solid",
            status_name(subtraction_input_status)
        );
    }

    const Clock::time_point subtract_start = Clock::now();
    manifold::Manifold subtracted_solid = state_solid_->Boolean(
        subtraction_solid,
        manifold::OpType::Subtract
    );
    const manifold::Manifold::Error subtract_status = subtracted_solid.Status();
    double subtracted_volume = 0.0;
    if (subtract_status == manifold::Manifold::Error::NoError) {
        subtracted_volume = subtracted_solid.Volume();
    }
    const Clock::time_point subtract_end = Clock::now();
    timings.subtract_ms = elapsed_ms(subtract_start, subtract_end);
    result["subtract_performed"] = true;
    result["subtract_status"] = status_name(subtract_status);
    result["subtracted_volume_m3"] = subtracted_volume;
    if (subtract_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "SUBTRACT_MANIFOLD_" + String(status_name(subtract_status)),
            "current-state-minus-protected result is not a valid Manifold solid",
            status_name(subtract_status)
        );
    }

    const Clock::time_point union_start = Clock::now();
    manifold::Manifold output_solid = subtracted_solid.Boolean(
        protected_solid,
        manifold::OpType::Add
    );
    const manifold::Manifold::Error union_status = output_solid.Status();
    double output_volume = 0.0;
    if (union_status == manifold::Manifold::Error::NoError) {
        output_volume = output_solid.Volume();
    }
    const Clock::time_point union_end = Clock::now();
    timings.union_ms = elapsed_ms(union_start, union_end);
    result["union_performed"] = true;
    result["union_status"] = status_name(union_status);
    if (union_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "UNION_MANIFOLD_" + String(status_name(union_status)),
            "protected composition union is not a valid Manifold solid",
            status_name(union_status)
        );
    }

    ExportPacket packet;
    int64_t base_source_triangle_count = 0;
    int64_t protected_source_triangle_count = 0;
    int64_t subtraction_source_triangle_count = 0;
    String export_error_code;
    String export_error_message;
    const Clock::time_point export_start = Clock::now();
    const bool export_ok = export_protected_composition(
        output_solid,
        base_original_id,
        protected_original_id,
        subtraction_original_id,
        true,
        packet,
        base_source_triangle_count,
        protected_source_triangle_count,
        subtraction_source_triangle_count,
        export_error_code,
        export_error_message
    );
    const Clock::time_point export_end = Clock::now();
    timings.export_ms = elapsed_ms(export_start, export_end);
    if (!export_ok) {
        return finish_failure(export_error_code, export_error_message, "NoError");
    }

    result["ok"] = true;
    result["status"] = "NoError";
    result["output_volume_m3"] = output_volume;
    result["manifold_volume_m3"] = output_volume;
    result["base_source_triangle_count"] = base_source_triangle_count;
    result["protected_source_triangle_count"] = protected_source_triangle_count;
    result["subtraction_source_triangle_count"] =
        subtraction_source_triangle_count;
    result["watertight"] = true;
    append_export_packet(result, packet);
    result["source_ids"] = packet.source_original_ids;
    append_protected_composition_timings(
        result,
        timings,
        total_start,
        export_end
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::clip_current_state_with_protected_mesh(
    const PackedVector3Array &protected_vertices,
    const PackedInt32Array &protected_indices
) const {
    const Clock::time_point total_start = Clock::now();
    const uint32_t first_id = manifold::Manifold::ReserveIDs(3);
    const uint32_t base_original_id = first_id;
    const uint32_t unused_protected_original_id = first_id + 1U;
    const uint32_t subtraction_original_id = first_id + 2U;

    ProtectedCompositionTimings timings;
    Dictionary result = protected_composition_result_base(
        base_original_id,
        unused_protected_original_id,
        subtraction_original_id,
        state_vertex_count_,
        state_triangle_count_,
        protected_vertices.size(),
        protected_indices.size() / 3,
        state_solid_ == nullptr
    );
    result["operation"] = "clip_current_state_with_protected_mesh";
    result["composition"] = "base - protected";
    result["operation_scope"] = "current_state_exact_protected_clip";
    result["source_id_semantics"] = "0=ordinary_base,2=subtraction_cut";
    result["source_protected_id"] = static_cast<int64_t>(-1);
    result["protected_original_id_applied"] = false;
    result["source_state_revision"] = static_cast<int64_t>(state_revision_);
    result["cached_base_reused"] = true;
    result["state_original_ids_map_to_base"] = true;
    result["base_original_id_applied_to_state"] = false;
    result["protected_status"] = "NotApplicable";
    result["union_status"] = "NotPerformed";

    auto finish_failure = [&result, &timings, &total_start](
        const String &code,
        const String &message,
        const String &status
    ) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = status;
        append_protected_composition_timings(result, timings, total_start, end);
        return result;
    };

    if (!state_solid_) {
        result["base_status"] = "Empty";
        return finish_failure(
            "STATE_EMPTY",
            "current Manifold state is empty",
            "Empty"
        );
    }

    const manifold::Manifold::Error base_status = state_solid_->Status();
    result["base_status"] = status_name(base_status);
    result["base_volume_m3"] = state_volume_;
    if (base_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "STATE_MANIFOLD_" + String(status_name(base_status)),
            "current Manifold state is not a valid solid",
            status_name(base_status)
        );
    }

    String error;
    PackedInput subtraction_input;
    const Clock::time_point import_subtraction_start = Clock::now();
    const bool subtraction_packed = pack_input(
        protected_vertices,
        protected_indices,
        subtraction_original_id,
        0.0,
        subtraction_input,
        error
    );
    if (!subtraction_packed) {
        const Clock::time_point import_subtraction_end = Clock::now();
        timings.import_subtraction_ms = elapsed_ms(
            import_subtraction_start,
            import_subtraction_end
        );
        return finish_failure("INVALID_PROTECTED_MESH", error, "NotRun");
    }
    manifold::Manifold subtraction_solid(subtraction_input.mesh);
    const manifold::Manifold::Error subtraction_input_status =
        subtraction_solid.Status();
    double subtraction_input_volume = 0.0;
    if (subtraction_input_status == manifold::Manifold::Error::NoError) {
        subtraction_input_volume = subtraction_solid.Volume();
    }
    const Clock::time_point import_subtraction_end = Clock::now();
    timings.import_subtraction_ms = elapsed_ms(
        import_subtraction_start,
        import_subtraction_end
    );
    result["input_subtraction_winding_reversed"] =
        subtraction_input.winding_reversed;
    result["input_protected_winding_reversed"] =
        subtraction_input.winding_reversed;
    result["input_b_winding_reversed"] = subtraction_input.winding_reversed;
    result["subtraction_input_status"] = status_name(subtraction_input_status);
    result["subtraction_input_volume_m3"] = subtraction_input_volume;
    result["protected_volume_m3"] = subtraction_input_volume;
    if (subtraction_input_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "SUBTRACTION_INPUT_MANIFOLD_" +
                String(status_name(subtraction_input_status)),
            "protected cutter mesh is not a valid Manifold solid",
            status_name(subtraction_input_status)
        );
    }

    const Clock::time_point subtract_start = Clock::now();
    manifold::Manifold output_solid = state_solid_->Boolean(
        subtraction_solid,
        manifold::OpType::Subtract
    );
    const manifold::Manifold::Error subtract_status = output_solid.Status();
    double output_volume = 0.0;
    if (subtract_status == manifold::Manifold::Error::NoError) {
        output_volume = output_solid.Volume();
    }
    const Clock::time_point subtract_end = Clock::now();
    timings.subtract_ms = elapsed_ms(subtract_start, subtract_end);
    result["subtract_performed"] = true;
    result["subtract_status"] = status_name(subtract_status);
    result["subtracted_volume_m3"] = output_volume;
    if (subtract_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "SUBTRACT_MANIFOLD_" + String(status_name(subtract_status)),
            "current-state-minus-protected result is not a valid Manifold solid",
            status_name(subtract_status)
        );
    }

    ExportPacket packet;
    int64_t base_source_triangle_count = 0;
    int64_t protected_source_triangle_count = 0;
    int64_t subtraction_source_triangle_count = 0;
    String export_error_code;
    String export_error_message;
    const Clock::time_point export_start = Clock::now();
    const bool export_ok = export_protected_composition(
        output_solid,
        base_original_id,
        unused_protected_original_id,
        subtraction_original_id,
        true,
        packet,
        base_source_triangle_count,
        protected_source_triangle_count,
        subtraction_source_triangle_count,
        export_error_code,
        export_error_message
    );
    const Clock::time_point export_end = Clock::now();
    timings.export_ms = elapsed_ms(export_start, export_end);
    if (!export_ok) {
        return finish_failure(export_error_code, export_error_message, "NoError");
    }
    if (protected_source_triangle_count != 0) {
        return finish_failure(
            "UNEXPECTED_PROTECTED_OUTPUT_SOURCE",
            "protected clip emitted a final-union protected source",
            "NoError"
        );
    }

    result["ok"] = true;
    result["status"] = "NoError";
    result["output_volume_m3"] = output_volume;
    result["manifold_volume_m3"] = output_volume;
    result["base_source_triangle_count"] = base_source_triangle_count;
    result["protected_source_triangle_count"] =
        protected_source_triangle_count;
    result["subtraction_source_triangle_count"] =
        subtraction_source_triangle_count;
    result["watertight"] = true;
    append_export_packet(result, packet);
    result["source_ids"] = packet.source_original_ids;
    append_protected_composition_timings(
        result,
        timings,
        total_start,
        export_end
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::get_backend_info() const {
    Dictionary info;
    info["backend_id"] = "forge_v2_manifold_3_3_2_serial";
    info["manifold_version"] = "3.3.2";
    info["manifold_commit"] = "798d83c8d7fabcddd23c1617097b95ba40f2597c";
    info["parallel"] = false;
    info["precision"] = "MeshGL64_double";
    info["operation_scope"] = "synchronous_union_proof";
    info["persistent_state"] = true;
    info["stateful_operation_scope"] = "synchronous_serial_reset_and_add";
    info["stateful_mesh_tolerance"] = kGodotCsgMeshTolerance;
    info["stateful_mesh_tolerance_contract"] = "Godot_4_7_CSG_2x_FLT_EPSILON";
    info["protected_composition_supported"] = true;
    info["protected_composition_scope"] =
        "stateless_and_current_state_exact_(base-minus-protected)-union-protected";
    info["protected_composition_source_ids"] =
        "0=ordinary_base,1=protected,2=subtraction_cut";
    info["current_state_protected_composition_supported"] = true;
    info["current_state_protected_clip_supported"] = true;
    info["current_state_protected_clip_source_ids"] =
        "0=ordinary_base,2=subtraction_cut";
    info["history_window_enabled"] = history_window_enabled_;
    info["history_window_capacity"] = static_cast<int64_t>(
        history_window_enabled_ ? kHistoryWindowCapacity : 0U
    );
    return info;
}

Dictionary ForgeV2ManifoldBoolean::get_state_info() const {
    Dictionary result = stateful_result_base("get_state_info");
    result["ok"] = true;
    result["status"] = state_solid_ ? "NoError" : "Empty";
    append_state_metadata(
        result,
        state_solid_ != nullptr,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    return result;
}

Dictionary ForgeV2ManifoldBoolean::get_history_info() const {
    Dictionary result = stateful_result_base("get_history_info");
    result["ok"] = true;
    result["status"] = state_solid_ ? "NoError" : "Empty";
    append_state_metadata(
        result,
        state_solid_ != nullptr,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    return result;
}

Dictionary ForgeV2ManifoldBoolean::set_history_window_enabled(bool enabled) {
    Dictionary result = stateful_result_base("set_history_window_enabled");
    result["requested_enabled"] = enabled;

    if (enabled == history_window_enabled_) {
        result["ok"] = true;
        result["committed"] = false;
        result["status"] = state_solid_ ? "NoError" : "Empty";
        result["changed"] = false;
        append_state_metadata(
            result,
            state_solid_ != nullptr,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        return result;
    }

    // Enabling after a reset/add would have no exact S0..Sn prefix states to
    // recover. Require the caller to opt in while the instance is empty.
    if (enabled && state_solid_) {
        result["error_code"] = "HISTORY_WINDOW_ENABLE_REQUIRES_EMPTY_STATE";
        result["error_message"] =
            "history must be enabled before reset_mesh initializes the state";
        result["status"] = "NoError";
        result["changed"] = false;
        append_state_metadata(
            result,
            true,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        return result;
    }

    history_window_enabled_ = enabled;
    history_states_.clear();
    if (state_solid_) {
        history_states_.push_back({
            state_solid_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_,
            0U,
            false,
        });
    } else {
        history_states_.emplace_back();
    }
    active_tail_cursor_ = 0U;
    checkpoint_operation_count_ = 0;
    promotion_count_ = 0;
    last_mode_ = enabled ? "history_window_enabled" : "history_window_disabled";

    result["ok"] = true;
    result["committed"] = true;
    result["status"] = state_solid_ ? "NoError" : "Empty";
    result["changed"] = true;
    append_state_metadata(
        result,
        state_solid_ != nullptr,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    return result;
}

Dictionary ForgeV2ManifoldBoolean::clear_state() {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    StatefulTimings timings;

    const Clock::time_point commit_start = Clock::now();
    history_states_.clear();
    history_states_.emplace_back();
    activate_history_state(0U);
    checkpoint_operation_count_ = 0;
    promotion_count_ = 0;
    boolean_count_ = 0;
    export_count_ = 0;
    checkpoint_materialization_attempt_count_ = 0;
    checkpoint_materialization_count_ = 0;
    last_mode_ = "clear";
    ++state_revision_;
    const Clock::time_point commit_end = Clock::now();
    timings.commit_ms = elapsed_ms(commit_start, commit_end);

    Dictionary result = stateful_result_base("clear_state");
    result["ok"] = true;
    result["committed"] = true;
    result["status"] = "Cleared";
    result["previous_revision"] = static_cast<int64_t>(previous_revision);
    append_export_packet(result, ExportPacket());
    append_state_metadata(result, false, state_revision_, 0, 0, 0.0);
    append_history_metadata(result);
    append_stateful_timings(result, timings, total_start, commit_end, false);
    return result;
}

Dictionary ForgeV2ManifoldBoolean::export_checkpoint_mesh() {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    StatefulTimings timings;
    ++checkpoint_materialization_attempt_count_;
    Dictionary result = stateful_result_base("export_checkpoint_mesh");
    result["previous_revision"] = static_cast<int64_t>(previous_revision);
    result["committed"] = false;
    result["changed"] = false;
    result["checkpoint_materialized"] = false;
    result["checkpoint_materialization_ms"] = 0.0;

    const HistoryState *checkpoint = history_states_.empty()
        ? nullptr
        : &history_states_.front();
    const bool checkpoint_initialized = checkpoint != nullptr && checkpoint->solid != nullptr;
    ExportPacket packet;

    if (checkpoint_initialized) {
        String export_error_code;
        String export_error_message;
        const Clock::time_point export_start = Clock::now();
        const bool export_ok = export_stateful_solid(
            *checkpoint->solid,
            checkpoint->current_operand_id,
            checkpoint->distinguish_current_operand,
            packet,
            export_error_code,
            export_error_message
        );
        const Clock::time_point export_end = Clock::now();
        timings.export_ms = elapsed_ms(export_start, export_end);
        result["checkpoint_materialization_ms"] = timings.export_ms;
        if (!export_ok) {
            result["error_code"] = export_error_code;
            result["error_message"] = export_error_message;
            result["status"] = "NoError";
            result["checkpoint_initialized"] = true;
            result["checkpoint_vertex_count"] = checkpoint->vertex_count;
            result["checkpoint_triangle_count"] = checkpoint->triangle_count;
            result["checkpoint_volume_m3"] = checkpoint->volume;
            append_export_packet(result, packet);
            append_state_metadata(
                result,
                state_solid_ != nullptr,
                state_revision_,
                state_vertex_count_,
                state_triangle_count_,
                state_volume_
            );
            append_history_metadata(result);
            append_stateful_timings(
                result,
                timings,
                total_start,
                export_end,
                true
            );
            return result;
        }
        ++checkpoint_materialization_count_;
        result["checkpoint_materialized"] = true;
    }

    const Clock::time_point end = Clock::now();
    result["ok"] = true;
    result["status"] = checkpoint_initialized ? "NoError" : "Empty";
    result["manifold_volume_m3"] = checkpoint_initialized ? checkpoint->volume : 0.0;
    result["checkpoint_initialized"] = checkpoint_initialized;
    result["checkpoint_vertex_count"] = checkpoint_initialized
        ? checkpoint->vertex_count
        : static_cast<int64_t>(0);
    result["checkpoint_triangle_count"] = checkpoint_initialized
        ? checkpoint->triangle_count
        : static_cast<int64_t>(0);
    result["checkpoint_volume_m3"] = checkpoint_initialized ? checkpoint->volume : 0.0;
    append_export_packet(result, packet);
    append_state_metadata(
        result,
        state_solid_ != nullptr,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    append_stateful_timings(
        result,
        timings,
        total_start,
        end,
        checkpoint_initialized
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::reset_checkpoint_mesh(
    const PackedVector3Array &vertices,
    const PackedInt32Array &indices,
    int64_t accumulated_operation_count
) {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    StatefulTimings timings;
    Dictionary result = stateful_result_base("reset_checkpoint_mesh");
    result["previous_revision"] = static_cast<int64_t>(previous_revision);
    result["changed"] = false;
    result["input_vertex_count"] = vertices.size();
    result["input_triangle_count"] = indices.size() / 3;
    result["input_a_vertex_count"] = vertices.size();
    result["input_a_triangle_count"] = indices.size() / 3;
    result["requested_accumulated_operation_count"] = accumulated_operation_count;

    auto finish_failure = [&](const String &code, const String &message, const String &status) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = status;
        append_state_metadata(
            result,
            state_solid_ != nullptr,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        append_stateful_timings(result, timings, total_start, end, false);
        return result;
    };

    if (!history_window_enabled_) {
        return finish_failure(
            "HISTORY_WINDOW_DISABLED",
            "checkpoint reset requires history to be enabled while the state is empty",
            state_solid_ ? "NoError" : "Empty"
        );
    }
    if (accumulated_operation_count < 0) {
        return finish_failure(
            "INVALID_CHECKPOINT_OPERATION_COUNT",
            "accumulated_operation_count must be non-negative",
            "NotRun"
        );
    }

    const bool empty_vertices = vertices.is_empty();
    const bool empty_indices = indices.is_empty();
    if (empty_vertices != empty_indices) {
        return finish_failure(
            "INVALID_CHECKPOINT_MESH",
            "checkpoint vertices and indices must either both be empty or both be populated",
            "NotRun"
        );
    }
    const bool empty_checkpoint = empty_vertices && empty_indices;
    if (empty_checkpoint && accumulated_operation_count != 0) {
        return finish_failure(
            "EMPTY_CHECKPOINT_REQUIRES_ZERO_OPERATIONS",
            "an empty checkpoint may only represent zero accumulated operations",
            "NotRun"
        );
    }

    std::shared_ptr<manifold::Manifold> candidate_solid;
    uint32_t base_id = 0U;
    double candidate_volume = 0.0;
    ExportPacket packet;
    if (!empty_checkpoint) {
        base_id = manifold::Manifold::ReserveIDs(1);
        PackedInput packed;
        String error;
        const Clock::time_point pack_start = Clock::now();
        const bool packed_ok = pack_input(
            vertices,
            indices,
            base_id,
            kGodotCsgMeshTolerance,
            packed,
            error
        );
        const Clock::time_point pack_end = Clock::now();
        timings.pack_ms = elapsed_ms(pack_start, pack_end);
        if (!packed_ok) {
            return finish_failure("INVALID_CHECKPOINT_MESH", error, "NotRun");
        }
        result["input_winding_reversed"] = packed.winding_reversed;
        result["input_a_winding_reversed"] = packed.winding_reversed;

        const Clock::time_point import_start = Clock::now();
        manifold::Manifold candidate(packed.mesh);
        const manifold::Manifold::Error candidate_status = candidate.Status();
        if (candidate_status == manifold::Manifold::Error::NoError) {
            candidate_volume = candidate.Volume();
        }
        const Clock::time_point import_end = Clock::now();
        timings.import_ms = elapsed_ms(import_start, import_end);
        if (candidate_status != manifold::Manifold::Error::NoError) {
            return finish_failure(
                "CHECKPOINT_MANIFOLD_" + String(status_name(candidate_status)),
                "checkpoint mesh is not a valid Manifold solid",
                status_name(candidate_status)
            );
        }

        String export_error_code;
        String export_error_message;
        const Clock::time_point export_start = Clock::now();
        const bool export_ok = export_stateful_solid(
            candidate,
            base_id,
            false,
            packet,
            export_error_code,
            export_error_message
        );
        const Clock::time_point export_end = Clock::now();
        timings.export_ms = elapsed_ms(export_start, export_end);
        if (!export_ok) {
            return finish_failure(export_error_code, export_error_message, "NoError");
        }

        candidate_solid = std::make_shared<manifold::Manifold>(std::move(candidate));
    }

    // Build the replacement before touching the active timeline. Validation,
    // export, and allocations must all succeed before the checkpoint commit.
    std::deque<HistoryState> replacement_states;
    if (candidate_solid) {
        replacement_states.push_back({
            candidate_solid,
            packet.vertex_count,
            packet.triangle_count,
            candidate_volume,
            base_id,
            false,
        });
    } else {
        replacement_states.emplace_back();
    }

    const Clock::time_point commit_start = Clock::now();
    history_states_.swap(replacement_states);
    activate_history_state(0U);
    checkpoint_operation_count_ = static_cast<uint64_t>(accumulated_operation_count);
    promotion_count_ = 0;
    boolean_count_ = 0;
    export_count_ = candidate_solid ? 1U : 0U;
    checkpoint_materialization_attempt_count_ = 0;
    checkpoint_materialization_count_ = 0;
    last_mode_ = empty_checkpoint ? "checkpoint_reset_empty" : "checkpoint_reset";
    ++state_revision_;
    const Clock::time_point commit_end = Clock::now();
    timings.commit_ms = elapsed_ms(commit_start, commit_end);

    result["ok"] = true;
    result["committed"] = true;
    result["changed"] = true;
    result["status"] = candidate_solid ? "NoError" : "Empty";
    result["manifold_volume_m3"] = candidate_volume;
    result["checkpoint_initialized"] = candidate_solid != nullptr;
    result["checkpoint_vertex_count"] = packet.vertex_count;
    result["checkpoint_triangle_count"] = packet.triangle_count;
    result["checkpoint_volume_m3"] = candidate_volume;
    append_export_packet(result, packet);
    append_state_metadata(
        result,
        candidate_solid != nullptr,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    append_stateful_timings(
        result,
        timings,
        total_start,
        commit_end,
        false
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::reset_mesh(
    const PackedVector3Array &vertices,
    const PackedInt32Array &indices
) {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    const bool truncates_redo = history_window_enabled_ &&
        active_tail_cursor_ + 1U < history_states_.size();
    StatefulTimings timings;
    Dictionary result = stateful_result_base("reset_mesh");
    result["previous_revision"] = static_cast<int64_t>(previous_revision);
    result["input_vertex_count"] = vertices.size();
    result["input_triangle_count"] = indices.size() / 3;
    result["input_a_vertex_count"] = vertices.size();
    result["input_a_triangle_count"] = indices.size() / 3;

    auto finish_failure = [&](const String &code, const String &message, const String &status) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = status;
        append_state_metadata(
            result,
            state_solid_ != nullptr,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        append_stateful_timings(result, timings, total_start, end, false);
        return result;
    };

    const uint32_t base_id = manifold::Manifold::ReserveIDs(1);
    PackedInput packed;
    String error;
    const Clock::time_point pack_start = Clock::now();
    const bool packed_ok = pack_input(
        vertices,
        indices,
        base_id,
        kGodotCsgMeshTolerance,
        packed,
        error
    );
    const Clock::time_point pack_end = Clock::now();
    timings.pack_ms = elapsed_ms(pack_start, pack_end);
    if (!packed_ok) {
        return finish_failure("INVALID_BASE_MESH", error, "NotRun");
    }
    result["input_winding_reversed"] = packed.winding_reversed;
    result["input_a_winding_reversed"] = packed.winding_reversed;

    const Clock::time_point import_start = Clock::now();
    manifold::Manifold candidate(packed.mesh);
    const manifold::Manifold::Error candidate_status = candidate.Status();
    double candidate_volume = 0.0;
    if (candidate_status == manifold::Manifold::Error::NoError) {
        candidate_volume = candidate.Volume();
    }
    const Clock::time_point import_end = Clock::now();
    timings.import_ms = elapsed_ms(import_start, import_end);
    if (candidate_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "BASE_MANIFOLD_" + String(status_name(candidate_status)),
            "base mesh is not a valid Manifold solid",
            status_name(candidate_status)
        );
    }

    ExportPacket packet;
    String export_error_code;
    String export_error_message;
    const Clock::time_point export_start = Clock::now();
    const bool export_ok = export_stateful_solid(
        candidate,
        base_id,
        false,
        packet,
        export_error_code,
        export_error_message
    );
    const Clock::time_point export_end = Clock::now();
    timings.export_ms = elapsed_ms(export_start, export_end);
    if (!export_ok) {
        return finish_failure(export_error_code, export_error_message, "NoError");
    }

    const Clock::time_point commit_start = Clock::now();
    std::shared_ptr<manifold::Manifold> candidate_solid =
        std::make_shared<manifold::Manifold>(std::move(candidate));
    history_states_.clear();
    if (history_window_enabled_) {
        // Opted-in history begins at empty S0. reset_mesh is deposited pass 1.
        history_states_.emplace_back();
        history_states_.push_back({
            candidate_solid,
            packet.vertex_count,
            packet.triangle_count,
            candidate_volume,
            base_id,
            false,
        });
        activate_history_state(1U);
    } else {
        // Production/live default: retain only the new current Manifold.
        history_states_.push_back({
            candidate_solid,
            packet.vertex_count,
            packet.triangle_count,
            candidate_volume,
            base_id,
            false,
        });
        activate_history_state(0U);
    }
    checkpoint_operation_count_ = 0;
    promotion_count_ = 0;
    boolean_count_ = 0;
    export_count_ = 1;
    checkpoint_materialization_attempt_count_ = 0;
    checkpoint_materialization_count_ = 0;
    last_mode_ = truncates_redo ? "branch_reset" : "reset";
    ++state_revision_;
    const Clock::time_point commit_end = Clock::now();
    timings.commit_ms = elapsed_ms(commit_start, commit_end);

    result["ok"] = true;
    result["committed"] = true;
    result["status"] = status_name(candidate_status);
    result["manifold_volume_m3"] = candidate_volume;
    append_export_packet(result, packet);
    append_state_metadata(
        result,
        true,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    append_stateful_timings(result, timings, total_start, commit_end, false);
    return result;
}

Dictionary ForgeV2ManifoldBoolean::add_mesh(
    const PackedVector3Array &vertices,
    const PackedInt32Array &indices
) {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    const int64_t cached_vertex_count = state_vertex_count_;
    const int64_t cached_triangle_count = state_triangle_count_;
    const bool truncates_redo = history_window_enabled_ &&
        active_tail_cursor_ + 1U < history_states_.size();
    StatefulTimings timings;
    Dictionary result = stateful_result_base("add_mesh");
    result["previous_revision"] = static_cast<int64_t>(previous_revision);
    result["input_vertex_count"] = vertices.size();
    result["input_triangle_count"] = indices.size() / 3;
    result["input_a_vertex_count"] = cached_vertex_count;
    result["input_a_triangle_count"] = cached_triangle_count;
    result["input_b_vertex_count"] = vertices.size();
    result["input_b_triangle_count"] = indices.size() / 3;

    auto finish_failure = [&](const String &code, const String &message, const String &status) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = status;
        append_state_metadata(
            result,
            state_solid_ != nullptr,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        append_stateful_timings(result, timings, total_start, end, state_solid_ != nullptr);
        return result;
    };

    if (!state_solid_) {
        return finish_failure(
            "STATE_NOT_INITIALIZED",
            "reset_mesh must commit a base solid before add_mesh",
            "Empty"
        );
    }

    const uint32_t operand_id = manifold::Manifold::ReserveIDs(1);
    PackedInput packed;
    String error;
    const Clock::time_point pack_start = Clock::now();
    const bool packed_ok = pack_input(
        vertices,
        indices,
        operand_id,
        kGodotCsgMeshTolerance,
        packed,
        error
    );
    const Clock::time_point pack_end = Clock::now();
    timings.pack_ms = elapsed_ms(pack_start, pack_end);
    if (!packed_ok) {
        return finish_failure("INVALID_OPERAND_MESH", error, "NotRun");
    }
    result["input_winding_reversed"] = packed.winding_reversed;
    result["input_b_winding_reversed"] = packed.winding_reversed;

    const Clock::time_point import_start = Clock::now();
    manifold::Manifold operand(packed.mesh);
    const manifold::Manifold::Error operand_status = operand.Status();
    const Clock::time_point import_end = Clock::now();
    timings.import_ms = elapsed_ms(import_start, import_end);
    if (operand_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "OPERAND_MANIFOLD_" + String(status_name(operand_status)),
            "operand mesh is not a valid Manifold solid",
            status_name(operand_status)
        );
    }

    const Clock::time_point boolean_start = Clock::now();
    manifold::Manifold candidate = state_solid_->Boolean(operand, manifold::OpType::Add);
    const manifold::Manifold::Error candidate_status = candidate.Status();
    double candidate_volume = 0.0;
    if (candidate_status == manifold::Manifold::Error::NoError) {
        candidate_volume = candidate.Volume();
    }
    const Clock::time_point boolean_end = Clock::now();
    timings.boolean_ms = elapsed_ms(boolean_start, boolean_end);
    if (candidate_status != manifold::Manifold::Error::NoError) {
        return finish_failure(
            "OUTPUT_MANIFOLD_" + String(status_name(candidate_status)),
            "union result is not a valid Manifold solid",
            status_name(candidate_status)
        );
    }

    ExportPacket packet;
    String export_error_code;
    String export_error_message;
    const Clock::time_point export_start = Clock::now();
    const bool export_ok = export_stateful_solid(
        candidate,
        operand_id,
        true,
        packet,
        export_error_code,
        export_error_message
    );
    const Clock::time_point export_end = Clock::now();
    timings.export_ms = elapsed_ms(export_start, export_end);
    if (!export_ok) {
        return finish_failure(export_error_code, export_error_message, "NoError");
    }

    const Clock::time_point commit_start = Clock::now();
    std::shared_ptr<manifold::Manifold> candidate_solid =
        std::make_shared<manifold::Manifold>(std::move(candidate));
    if (history_window_enabled_) {
        while (history_states_.size() > active_tail_cursor_ + 1U) {
            history_states_.pop_back();
        }
        history_states_.push_back({
            candidate_solid,
            packet.vertex_count,
            packet.triangle_count,
            candidate_volume,
            operand_id,
            true,
        });
        ++active_tail_cursor_;
    } else {
        // Replacing the sole retained slot releases the previous state as soon
        // as activate_history_state updates state_solid_.
        history_states_.clear();
        history_states_.push_back({
            candidate_solid,
            packet.vertex_count,
            packet.triangle_count,
            candidate_volume,
            operand_id,
            true,
        });
        active_tail_cursor_ = 0U;
    }
    ++boolean_count_;
    ++export_count_;
    last_mode_ = truncates_redo ? "branch_append" : "append";

    if (
        history_window_enabled_ &&
        history_states_.size() > kHistoryWindowCapacity + 1U
    ) {
        // S1 already owns the exact Manifold produced by its deposited call.
        // Dropping S0 promotes S1 to the prefix checkpoint without replaying
        // a Boolean and without exporting a base mesh on the hot path.
        history_states_.pop_front();
        --active_tail_cursor_;
        history_states_.front().current_operand_id = 0U;
        history_states_.front().distinguish_current_operand = false;
        ++checkpoint_operation_count_;
        ++promotion_count_;
        last_mode_ = "promotion_append";
    }
    activate_history_state(active_tail_cursor_);
    ++state_revision_;
    const Clock::time_point commit_end = Clock::now();
    timings.commit_ms = elapsed_ms(commit_start, commit_end);

    result["ok"] = true;
    result["committed"] = true;
    result["status"] = status_name(candidate_status);
    result["manifold_volume_m3"] = candidate_volume;
    append_export_packet(result, packet);
    append_state_metadata(
        result,
        true,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    append_stateful_timings(result, timings, total_start, commit_end, true);
    return result;
}

Dictionary ForgeV2ManifoldBoolean::undo_state() {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    StatefulTimings timings;
    Dictionary result = stateful_result_base("undo_state");
    result["previous_revision"] = static_cast<int64_t>(previous_revision);

    auto finish_failure = [&](const String &code, const String &message) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = state_solid_ ? "NoError" : "Empty";
        append_state_metadata(
            result,
            state_solid_ != nullptr,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        append_stateful_timings(
            result,
            timings,
            total_start,
            end,
            state_solid_ != nullptr
        );
        return result;
    };

    if (!history_window_enabled_) {
        return finish_failure(
            "HISTORY_WINDOW_DISABLED",
            "undo is unavailable unless history is enabled before reset_mesh"
        );
    }

    if (active_tail_cursor_ == 0U) {
        return finish_failure(
            "UNDO_UNAVAILABLE",
            "the active state is already the retained prefix checkpoint"
        );
    }

    const size_t target_cursor = active_tail_cursor_ - 1U;
    const HistoryState &target = history_states_[target_cursor];
    ExportPacket packet;
    if (target.solid) {
        String export_error_code;
        String export_error_message;
        const Clock::time_point export_start = Clock::now();
        const bool export_ok = export_stateful_solid(
            *target.solid,
            target.current_operand_id,
            target.distinguish_current_operand,
            packet,
            export_error_code,
            export_error_message
        );
        const Clock::time_point export_end = Clock::now();
        timings.export_ms = elapsed_ms(export_start, export_end);
        if (!export_ok) {
            return finish_failure(export_error_code, export_error_message);
        }
    }

    const bool target_initialized = target.solid != nullptr;
    const Clock::time_point commit_start = Clock::now();
    activate_history_state(target_cursor);
    if (target_initialized) {
        ++export_count_;
    }
    last_mode_ = "undo";
    ++state_revision_;
    const Clock::time_point commit_end = Clock::now();
    timings.commit_ms = elapsed_ms(commit_start, commit_end);

    result["ok"] = true;
    result["committed"] = true;
    result["status"] = target_initialized ? "NoError" : "Empty";
    result["manifold_volume_m3"] = state_volume_;
    append_export_packet(result, packet);
    append_state_metadata(
        result,
        target_initialized,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    append_stateful_timings(
        result,
        timings,
        total_start,
        commit_end,
        target_initialized
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::redo_state() {
    const Clock::time_point total_start = Clock::now();
    const uint64_t previous_revision = state_revision_;
    StatefulTimings timings;
    Dictionary result = stateful_result_base("redo_state");
    result["previous_revision"] = static_cast<int64_t>(previous_revision);

    auto finish_failure = [&](const String &code, const String &message) {
        const Clock::time_point end = Clock::now();
        result["error_code"] = code;
        result["error_message"] = message;
        result["status"] = state_solid_ ? "NoError" : "Empty";
        append_state_metadata(
            result,
            state_solid_ != nullptr,
            state_revision_,
            state_vertex_count_,
            state_triangle_count_,
            state_volume_
        );
        append_history_metadata(result);
        append_stateful_timings(
            result,
            timings,
            total_start,
            end,
            state_solid_ != nullptr
        );
        return result;
    };

    if (!history_window_enabled_) {
        return finish_failure(
            "HISTORY_WINDOW_DISABLED",
            "redo is unavailable unless history is enabled before reset_mesh"
        );
    }

    if (active_tail_cursor_ + 1U >= history_states_.size()) {
        return finish_failure(
            "REDO_UNAVAILABLE",
            "the active state is already the newest retained tail state"
        );
    }

    const size_t target_cursor = active_tail_cursor_ + 1U;
    const HistoryState &target = history_states_[target_cursor];
    ExportPacket packet;
    if (target.solid) {
        String export_error_code;
        String export_error_message;
        const Clock::time_point export_start = Clock::now();
        const bool export_ok = export_stateful_solid(
            *target.solid,
            target.current_operand_id,
            target.distinguish_current_operand,
            packet,
            export_error_code,
            export_error_message
        );
        const Clock::time_point export_end = Clock::now();
        timings.export_ms = elapsed_ms(export_start, export_end);
        if (!export_ok) {
            return finish_failure(export_error_code, export_error_message);
        }
    }

    const bool target_initialized = target.solid != nullptr;
    const Clock::time_point commit_start = Clock::now();
    activate_history_state(target_cursor);
    if (target_initialized) {
        ++export_count_;
    }
    last_mode_ = "redo";
    ++state_revision_;
    const Clock::time_point commit_end = Clock::now();
    timings.commit_ms = elapsed_ms(commit_start, commit_end);

    result["ok"] = true;
    result["committed"] = true;
    result["status"] = target_initialized ? "NoError" : "Empty";
    result["manifold_volume_m3"] = state_volume_;
    append_export_packet(result, packet);
    append_state_metadata(
        result,
        target_initialized,
        state_revision_,
        state_vertex_count_,
        state_triangle_count_,
        state_volume_
    );
    append_history_metadata(result);
    append_stateful_timings(
        result,
        timings,
        total_start,
        commit_end,
        target_initialized
    );
    return result;
}

Dictionary ForgeV2ManifoldBoolean::union_meshes(
    const PackedVector3Array &base_vertices,
    const PackedInt32Array &base_indices,
    const PackedVector3Array &operand_vertices,
    const PackedInt32Array &operand_indices
) const {
    const Clock::time_point total_start = Clock::now();
    const uint32_t first_id = manifold::Manifold::ReserveIDs(2);
    const uint32_t base_id = first_id;
    const uint32_t operand_id = first_id + 1U;

    String error;
    PackedInput base_input;
    const Clock::time_point import_a_start = Clock::now();
    if (!pack_input(base_vertices, base_indices, base_id, 0.0, base_input, error)) {
        return failure_result("INVALID_BASE_MESH", error);
    }
    manifold::Manifold base_solid(base_input.mesh);
    const manifold::Manifold::Error base_status = base_solid.Status();
    const Clock::time_point import_a_end = Clock::now();
    if (base_status != manifold::Manifold::Error::NoError) {
        return failure_result("BASE_MANIFOLD_" + String(status_name(base_status)), "base mesh is not a valid Manifold solid");
    }

    PackedInput operand_input;
    const Clock::time_point import_b_start = Clock::now();
    if (!pack_input(operand_vertices, operand_indices, operand_id, 0.0, operand_input, error)) {
        return failure_result("INVALID_OPERAND_MESH", error);
    }
    manifold::Manifold operand_solid(operand_input.mesh);
    const manifold::Manifold::Error operand_status = operand_solid.Status();
    const Clock::time_point import_b_end = Clock::now();
    if (operand_status != manifold::Manifold::Error::NoError) {
        return failure_result("OPERAND_MANIFOLD_" + String(status_name(operand_status)), "operand mesh is not a valid Manifold solid");
    }

    const Clock::time_point boolean_start = Clock::now();
    manifold::Manifold output_solid = base_solid.Boolean(operand_solid, manifold::OpType::Add);
    const manifold::Manifold::Error output_status = output_solid.Status();
    const Clock::time_point boolean_end = Clock::now();
    if (output_status != manifold::Manifold::Error::NoError) {
        return failure_result("OUTPUT_MANIFOLD_" + String(status_name(output_status)), "union result is not a valid Manifold solid");
    }

    const double output_volume = output_solid.Volume();
    const Clock::time_point export_start = Clock::now();
    manifold::MeshGL64 output_mesh = output_solid.GetMeshGL64();

    if (output_mesh.numProp < 3 || output_mesh.vertProperties.size() % output_mesh.numProp != 0 ||
        output_mesh.triVerts.size() % 3U != 0) {
        return failure_result("INVALID_OUTPUT_PACKET", "Manifold returned malformed mesh arrays");
    }
    const size_t output_vertex_count = output_mesh.vertProperties.size() / output_mesh.numProp;
    if (output_vertex_count > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
        return failure_result("OUTPUT_TOO_LARGE", "output vertex count exceeds PackedInt32Array capacity");
    }

    PackedVector3Array output_vertices;
    output_vertices.resize(static_cast<int64_t>(output_vertex_count));
    for (size_t i = 0; i < output_vertex_count; ++i) {
        const size_t offset = i * output_mesh.numProp;
        const Vector3 vertex(
            static_cast<real_t>(output_mesh.vertProperties[offset]),
            static_cast<real_t>(output_mesh.vertProperties[offset + 1U]),
            static_cast<real_t>(output_mesh.vertProperties[offset + 2U])
        );
        if (!vertex.is_finite()) {
            return failure_result("NONFINITE_OUTPUT", "Manifold returned a non-finite vertex");
        }
        output_vertices.set(static_cast<int64_t>(i), vertex);
    }

    const size_t output_triangle_count = output_mesh.triVerts.size() / 3U;
    PackedInt32Array output_indices;
    PackedInt32Array output_source_ids;
    PackedInt32Array output_face_ids;
    output_indices.resize(static_cast<int64_t>(output_mesh.triVerts.size()));
    output_source_ids.resize(static_cast<int64_t>(output_triangle_count));
    output_face_ids.resize(static_cast<int64_t>(output_triangle_count));
    for (size_t triangle = 0; triangle < output_triangle_count; ++triangle) {
        const uint64_t a = output_mesh.triVerts[triangle * 3U];
        const uint64_t b = output_mesh.triVerts[triangle * 3U + 1U];
        const uint64_t c = output_mesh.triVerts[triangle * 3U + 2U];
        if (a >= output_vertex_count || b >= output_vertex_count || c >= output_vertex_count ||
            a > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
            b > static_cast<uint64_t>(std::numeric_limits<int32_t>::max()) ||
            c > static_cast<uint64_t>(std::numeric_limits<int32_t>::max())) {
            return failure_result("INVALID_OUTPUT_INDEX", "Manifold returned an invalid or oversized index");
        }
        // Manifold emits positive/outward CCW. Forge's established ArrayMesh
        // convention is the opposite winding, so reverse exactly once.
        output_indices.set(static_cast<int64_t>(triangle * 3U), static_cast<int32_t>(a));
        output_indices.set(static_cast<int64_t>(triangle * 3U + 1U), static_cast<int32_t>(c));
        output_indices.set(static_cast<int64_t>(triangle * 3U + 2U), static_cast<int32_t>(b));
        output_source_ids.set(
            static_cast<int64_t>(triangle),
            source_for_triangle(output_mesh, triangle, base_id, operand_id)
        );
        const int32_t face_id = triangle < output_mesh.faceID.size() &&
            output_mesh.faceID[triangle] <= static_cast<uint64_t>(std::numeric_limits<int32_t>::max())
            ? static_cast<int32_t>(output_mesh.faceID[triangle])
            : -1;
        output_face_ids.set(static_cast<int64_t>(triangle), face_id);
    }
    const Clock::time_point export_end = Clock::now();

    Dictionary result;
    result["ok"] = true;
    result["error_code"] = "";
    result["error_message"] = "";
    result["status"] = status_name(output_status);
    result["backend_id"] = "forge_v2_manifold_3_3_2_serial";
    result["manifold_version"] = "3.3.2";
    result["parallel"] = false;
    result["input_a_winding_reversed"] = base_input.winding_reversed;
    result["input_b_winding_reversed"] = operand_input.winding_reversed;
    result["input_a_vertex_count"] = base_vertices.size();
    result["input_a_triangle_count"] = base_indices.size() / 3;
    result["input_b_vertex_count"] = operand_vertices.size();
    result["input_b_triangle_count"] = operand_indices.size() / 3;
    result["output_vertex_count"] = static_cast<int64_t>(output_vertex_count);
    result["output_triangle_count"] = static_cast<int64_t>(output_triangle_count);
    result["manifold_volume_m3"] = output_volume;
    result["vertices"] = output_vertices;
    result["indices"] = output_indices;
    result["source_original_ids"] = output_source_ids;
    result["source_face_ids"] = output_face_ids;
    result["import_a_ms"] = elapsed_ms(import_a_start, import_a_end);
    result["import_b_ms"] = elapsed_ms(import_b_start, import_b_end);
    result["boolean_ms"] = elapsed_ms(boolean_start, boolean_end);
    result["export_ms"] = elapsed_ms(export_start, export_end);
    result["total_native_ms"] = elapsed_ms(total_start, export_end);
    return result;
}

} // namespace godot
