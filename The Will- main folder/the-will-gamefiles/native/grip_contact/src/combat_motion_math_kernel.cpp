#include "combat_motion_math_kernel.h"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace godot {

namespace {

// Exact numerical contract of CombatWeaponMotionAllocator at Stable-body.
// Keep double arithmetic, source ordering and rank/free-variable choices.
constexpr double CONSTRAINT_EPSILON = 1.0e-6;
constexpr double PIVOT_EPSILON = 1.0e-10;
constexpr int QP_ITERATIONS = 80;
using Row = std::vector<double>;
using Matrix = std::vector<Row>;

Row read_vector(const PackedFloat64Array &source) {
    Row result(static_cast<size_t>(source.size()));
    for (int64_t i = 0; i < source.size(); ++i) {
        result[static_cast<size_t>(i)] = source[i];
    }
    return result;
}

PackedFloat64Array pack_vector(const Row &source) {
    PackedFloat64Array result;
    result.resize(static_cast<int64_t>(source.size()));
    for (size_t i = 0; i < source.size(); ++i) {
        result.set(static_cast<int64_t>(i), source[i]);
    }
    return result;
}

PackedInt32Array pack_indices(const std::vector<int> &source) {
    PackedInt32Array result;
    result.resize(static_cast<int64_t>(source.size()));
    for (size_t i = 0; i < source.size(); ++i) {
        result.set(static_cast<int64_t>(i), source[i]);
    }
    return result;
}

bool read_matrix(const Array &source, size_t columns, Matrix &result) {
    result.reserve(static_cast<size_t>(source.size()));
    for (int64_t i = 0; i < source.size(); ++i) {
        if (source[i].get_type() != Variant::PACKED_FLOAT64_ARRAY) {
            return false;
        }
        const PackedFloat64Array row = source[i];
        if (static_cast<size_t>(row.size()) != columns) {
            return false;
        }
        result.push_back(read_vector(row));
    }
    return true;
}

double dot(const Row &a, const Row &b) {
    double value = 0.0;
    for (size_t i = 0; i < a.size(); ++i) {
        value += a[i] * b[i];
    }
    return value;
}

bool linear_solve(const Matrix &matrix, const Row &rhs, Row &answer) {
    const size_t count = rhs.size();
    Matrix a = matrix;
    for (size_t i = 0; i < count; ++i) {
        a[i].push_back(rhs[i]);
    }
    std::vector<size_t> pivots;
    size_t rank = 0;
    for (size_t column = 0; column < count; ++column) {
        size_t pivot = rank;
        for (size_t row = rank; row < count; ++row) {
            if (std::abs(a[row][column]) > std::abs(a[pivot][column])) {
                pivot = row;
            }
        }
        if (std::abs(a[pivot][column]) <= PIVOT_EPSILON) {
            continue;
        }
        std::swap(a[rank], a[pivot]);
        const double divisor = a[rank][column];
        for (size_t k = column; k < count + 1; ++k) {
            a[rank][k] /= divisor;
        }
        for (size_t row = 0; row < count; ++row) {
            if (row == rank) {
                continue;
            }
            const double factor = a[row][column];
            if (std::abs(factor) <= PIVOT_EPSILON) {
                continue;
            }
            for (size_t k = column; k < count + 1; ++k) {
                a[row][k] -= factor * a[rank][k];
            }
        }
        pivots.push_back(column);
        ++rank;
        if (rank == count) {
            break;
        }
    }
    for (size_t row = rank; row < count; ++row) {
        if (std::abs(a[row][count]) > 1.0e-7) {
            return false;
        }
    }
    answer.assign(count, 0.0);
    for (size_t row = 0; row < rank; ++row) {
        answer[pivots[row]] = a[row][count];
    }
    return true;
}

Dictionary failed_qp(const Row &x, const char *reason,
        const std::vector<int> &active, const Array &trace) {
    Dictionary result;
    result["valid"] = false;
    result["x"] = pack_vector(x);
    result["reason"] = reason;
    result["active"] = pack_indices(active);
    result["trace"] = trace;
    return result;
}

void append_trace(Array &trace, const Dictionary &step) {
    trace.append(step);
    if (trace.size() > 8) {
        trace.pop_front();
    }
}

bool forward_bone(size_t index, const std::vector<Transform3D> &local,
        const PackedInt32Array &parents, std::vector<Transform3D> &global,
        std::vector<uint8_t> &state) {
    if (state[index] == 2) {
        return true;
    }
    if (state[index] == 1) {
        return false;
    }
    state[index] = 1;
    const int parent = parents[static_cast<int64_t>(index)];
    if (parent >= 0) {
        if (static_cast<size_t>(parent) >= local.size() ||
                !forward_bone(static_cast<size_t>(parent), local, parents, global, state)) {
            return false;
        }
        // Same parent-before-child multiplication as the script. Transform3D
        // retains the engine's real_t precision and animated local offsets.
        global[index] = global[static_cast<size_t>(parent)] * local[index];
    } else {
        global[index] = local[index];
    }
    state[index] = 2;
    return true;
}

} // namespace

void CombatMotionMathKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("solve_qp", "h", "g", "equalities", "inequalities", "limits", "initial"),
            &CombatMotionMathKernel::solve_qp);
    ClassDB::bind_method(D_METHOD("forward_pose", "poses", "parents"),
            &CombatMotionMathKernel::forward_pose);
}

Dictionary CombatMotionMathKernel::solve_qp(const Array &h_values, const PackedFloat64Array &g_values,
        const Array &equality_values, const Array &inequality_values,
        const PackedFloat64Array &limits_values, const PackedFloat64Array &initial) const {
    const size_t count = static_cast<size_t>(initial.size());
    Matrix h, equalities, inequalities;
    if (h_values.size() != initial.size() || g_values.size() != initial.size() ||
            limits_values.size() != inequality_values.size() ||
            !read_matrix(h_values, count, h) || !read_matrix(equality_values, count, equalities) ||
            !read_matrix(inequality_values, count, inequalities)) {
        Dictionary result;
        result["valid"] = false;
        result["x"] = initial.duplicate();
        result["reason"] = "invalid_dimensions";
        return result;
    }
    const Row g = read_vector(g_values);
    const Row limits = read_vector(limits_values);
    Row x = read_vector(initial);
    std::vector<int> active;
    TypedArray<Dictionary> trace;
    for (size_t i = 0; i < inequalities.size(); ++i) {
        if (dot(inequalities[i], x) > limits[i] + CONSTRAINT_EPSILON) {
            Dictionary result;
            result["valid"] = false;
            result["x"] = initial.duplicate();
            result["reason"] = "infeasible_start";
            Array first_active;
            first_active.append(static_cast<int64_t>(i));
            result["active"] = first_active;
            return result;
        }
    }
    for (int iteration = 0; iteration < QP_ITERATIONS; ++iteration) {
        Matrix rows = equalities;
        for (int index : active) {
            rows.push_back(inequalities[static_cast<size_t>(index)]);
        }
        const size_t dimension = count + rows.size();
        Matrix system(dimension, Row(dimension, 0.0));
        Row rhs(dimension, 0.0);
        Row row_scales;
        row_scales.reserve(rows.size());
        for (size_t i = 0; i < count; ++i) {
            for (size_t k = 0; k < count; ++k) {
                system[i][k] = h[i][k];
            }
            rhs[i] = -g[i] - dot(h[i], x);
        }
        for (size_t row = 0; row < rows.size(); ++row) {
            const double row_norm = std::sqrt(dot(rows[row], rows[row]));
            const double row_scale = row_norm > PIVOT_EPSILON ? row_norm : 1.0;
            row_scales.push_back(row_scale);
            for (size_t column = 0; column < count; ++column) {
                system[count + row][column] = rows[row][column] / row_scale;
                system[column][count + row] = rows[row][column] / row_scale;
            }
        }
        Row solution;
        if (!linear_solve(system, rhs, solution)) {
            return failed_qp(x, "inconsistent_linear_system", active, trace);
        }
        const Row direction(solution.begin(), solution.begin() + static_cast<std::ptrdiff_t>(count));
        const double direction_squared = dot(direction, direction);
        Dictionary step_trace;
        step_trace["iteration"] = iteration;
        step_trace["active"] = pack_indices(active);
        step_trace["direction_squared"] = direction_squared;
        if (direction_squared <= 1.0e-18) {
            int remove = -1;
            double minimum = -1.0e-8;
            for (size_t i = 0; i < active.size(); ++i) {
                const double multiplier = solution[count + equalities.size() + i] / row_scales[equalities.size() + i];
                if (multiplier < minimum) {
                    minimum = multiplier;
                    remove = static_cast<int>(i);
                }
            }
            if (remove < 0) {
                Dictionary result;
                result["valid"] = true;
                result["x"] = pack_vector(x);
                return result;
            }
            step_trace["remove"] = active[static_cast<size_t>(remove)];
            append_trace(trace, step_trace);
            active.erase(active.begin() + remove);
            continue;
        }
        double fraction = 1.0;
        int blocker = -1;
        for (size_t i = 0; i < inequalities.size(); ++i) {
            if (std::find(active.begin(), active.end(), static_cast<int>(i)) != active.end()) {
                continue;
            }
            const double travel = dot(inequalities[i], direction);
            if (travel <= PIVOT_EPSILON) {
                continue;
            }
            const double available = std::max(0.0, limits[i] - dot(inequalities[i], x)) / travel;
            if (available < fraction) {
                fraction = available;
                blocker = static_cast<int>(i);
            }
        }
        for (size_t i = 0; i < count; ++i) {
            x[i] += direction[i] * fraction;
        }
        step_trace["fraction"] = fraction;
        step_trace["blocker"] = blocker;
        append_trace(trace, step_trace);
        if (blocker >= 0) {
            active.push_back(blocker);
        }
    }
    return failed_qp(x, "iteration_budget", active, trace);
}

TypedArray<Transform3D> CombatMotionMathKernel::forward_pose(const TypedArray<Transform3D> &poses,
        const PackedInt32Array &parents) const {
    TypedArray<Transform3D> result;
    if (poses.size() != parents.size()) {
        return result;
    }
    const size_t count = static_cast<size_t>(poses.size());
    std::vector<Transform3D> local(count), global(count);
    std::vector<uint8_t> state(count, 0);
    for (size_t i = 0; i < count; ++i) {
        local[i] = poses[static_cast<int64_t>(i)];
    }
    for (size_t i = 0; i < count; ++i) {
        if (!forward_bone(i, local, parents, global, state)) {
            return result;
        }
    }
    result.resize(poses.size());
    for (size_t i = 0; i < count; ++i) {
        result[static_cast<int64_t>(i)] = global[i];
    }
    return result;
}

} // namespace godot
