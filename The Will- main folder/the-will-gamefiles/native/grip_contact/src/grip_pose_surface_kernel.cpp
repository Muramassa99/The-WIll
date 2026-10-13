#include "grip_pose_surface_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <numeric>
#include <tuple>
#include <utility>
#include <vector>

namespace godot {
namespace {

struct D3 {
    double x = 0.0, y = 0.0, z = 0.0;
    D3() = default;
    D3(double px, double py, double pz) : x(px), y(py), z(pz) {}
    explicit D3(const Vector3 &v) : x(v.x), y(v.y), z(v.z) {}
    D3 operator+(const D3 &b) const { return {x + b.x, y + b.y, z + b.z}; }
    D3 operator-(const D3 &b) const { return {x - b.x, y - b.y, z - b.z}; }
    D3 operator*(double s) const { return {x * s, y * s, z * s}; }
    double at(int axis) const { return axis == 0 ? x : (axis == 1 ? y : z); }
    double dot(const D3 &b) const { return x * b.x + y * b.y + z * b.z; }
    D3 cross(const D3 &b) const { return {y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x}; }
    double length_squared() const { return dot(*this); }
    D3 normalized() const { const double l = std::sqrt(length_squared()); return l > 0.0 ? *this * (1.0 / l) : D3(); }
    bool finite() const { return std::isfinite(x) && std::isfinite(y) && std::isfinite(z); }
    Vector3 vector() const { return Vector3(static_cast<real_t>(x), static_cast<real_t>(y), static_cast<real_t>(z)); }
};

struct Box {
    D3 low{std::numeric_limits<double>::infinity(), std::numeric_limits<double>::infinity(), std::numeric_limits<double>::infinity()};
    D3 high{-std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity(), -std::numeric_limits<double>::infinity()};
    void include(const D3 &p) {
        low = {std::min(low.x, p.x), std::min(low.y, p.y), std::min(low.z, p.z)};
        high = {std::max(high.x, p.x), std::max(high.y, p.y), std::max(high.z, p.z)};
    }
    void include(const Box &b) { include(b.low); include(b.high); }
    double distance_squared(const D3 &p) const {
        double d = 0.0;
        for (int a = 0; a != 3; ++a) {
            const double v = std::max({low.at(a) - p.at(a), 0.0, p.at(a) - high.at(a)});
            d += v * v;
        }
        return d;
    }
    bool ray(const D3 &p, const D3 &d, double maximum, double epsilon) const {
        double near = 0.0, far = maximum;
        for (int a = 0; a != 3; ++a) {
            const double direction = d.at(a), origin = p.at(a);
            if (std::abs(direction) < 1e-30) {
                if (origin < low.at(a) - epsilon || origin > high.at(a) + epsilon) return false;
                continue;
            }
            double first = (low.at(a) - epsilon - origin) / direction;
            double last = (high.at(a) + epsilon - origin) / direction;
            if (first > last) std::swap(first, last);
            near = std::max(near, first); far = std::min(far, last);
            if (near > far) return false;
        }
        return true;
    }
};

struct Triangle { D3 a, b, c, normal, center; Box bounds; int source = -1; };
struct Node { Box bounds; int begin = 0, end = 0, left = -1, right = -1; };
struct Nearest { double distance_squared = std::numeric_limits<double>::infinity(); D3 point; int triangle = -1; };
struct RayHit { double t = 0.0; bool edge = false; };

Dictionary failure(const char *reason) {
    Dictionary result;
    result["valid"] = false;
    result["reason"] = String(reason);
    return result;
}

// Voronoi-region closest point, evaluated entirely in scalar double precision.
D3 closest_triangle(const D3 &p, const Triangle &t) {
    const D3 ab = t.b - t.a, ac = t.c - t.a, ap = p - t.a;
    const double d1 = ab.dot(ap), d2 = ac.dot(ap);
    if (d1 <= 0.0 && d2 <= 0.0) return t.a;
    const D3 bp = p - t.b;
    const double d3 = ab.dot(bp), d4 = ac.dot(bp);
    if (d3 >= 0.0 && d4 <= d3) return t.b;
    const double vc = d1 * d4 - d3 * d2;
    if (vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0) return t.a + ab * (d1 / (d1 - d3));
    const D3 cp = p - t.c;
    const double d5 = ab.dot(cp), d6 = ac.dot(cp);
    if (d6 >= 0.0 && d5 <= d6) return t.c;
    const double vb = d5 * d2 - d1 * d6;
    if (vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0) return t.a + ac * (d2 / (d2 - d6));
    const double va = d3 * d6 - d5 * d4;
    if (va <= 0.0 && d4 - d3 >= 0.0 && d5 - d6 >= 0.0)
        return t.b + (t.c - t.b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)));
    const double inverse = 1.0 / (va + vb + vc);
    return t.a + ab * (vb * inverse) + ac * (vc * inverse);
}

bool ray_triangle(const D3 &origin, const D3 &direction, const Triangle &triangle,
        double minimum, double maximum, RayHit &hit) {
    const D3 e1 = triangle.b - triangle.a, e2 = triangle.c - triangle.a;
    const D3 h = direction.cross(e2);
    const double determinant = e1.dot(h);
    const double determinant_scale = std::sqrt(e1.length_squared() * h.length_squared());
    if (std::abs(determinant) <= determinant_scale * 1e-14) return false;
    const double inverse = 1.0 / determinant;
    const D3 s = origin - triangle.a;
    const double u = inverse * s.dot(h);
    if (u < -1e-12 || u > 1.0 + 1e-12) return false;
    const D3 q = s.cross(e1);
    const double v = inverse * direction.dot(q);
    if (v < -1e-12 || u + v > 1.0 + 1e-12) return false;
    const double t = inverse * e2.dot(q);
    if (t < minimum || t > maximum) return false;
    hit = {t, std::min({u, v, 1.0 - u - v}) < 1e-9};
    return true;
}

double segments_distance_squared(const D3 &p1, const D3 &q1, const D3 &p2, const D3 &q2) {
    const D3 d1 = q1 - p1, d2 = q2 - p2, r = p1 - p2;
    const double a = d1.dot(d1), e = d2.dot(d2), f = d2.dot(r);
    double s = 0.0, t = 0.0;
    if (a <= 1e-30 && e <= 1e-30) return r.length_squared();
    if (a <= 1e-30) t = std::clamp(f / e, 0.0, 1.0);
    else {
        const double c = d1.dot(r);
        if (e <= 1e-30) s = std::clamp(-c / a, 0.0, 1.0);
        else {
            const double b = d1.dot(d2), denominator = a * e - b * b;
            if (denominator > 1e-30) s = std::clamp((b * f - c * e) / denominator, 0.0, 1.0);
            t = (b * s + f) / e;
            if (t < 0.0) { t = 0.0; s = std::clamp(-c / a, 0.0, 1.0); }
            else if (t > 1.0) { t = 1.0; s = std::clamp((b - c) / a, 0.0, 1.0); }
        }
    }
    return (p1 + d1 * s - p2 - d2 * t).length_squared();
}

} // namespace

struct GripPoseSurfaceKernel::Impl {
    std::vector<Triangle> triangles;
    std::vector<int> order;
    std::vector<Node> nodes;
    double epsilon = 1e-10;
    // Coplanarity of independently transformed float32 API inputs needs a
    // rounding bound. This is NOT the signed-distance or overlap tolerance.
    double segment_input_epsilon = 1e-10;
    bool ready = false;

    int build(int begin, int end) {
        const int index = static_cast<int>(nodes.size());
        nodes.emplace_back();
        Box bounds, centroids;
        for (int i = begin; i < end; ++i) { bounds.include(triangles[order[i]].bounds); centroids.include(triangles[order[i]].center); }
        nodes[index].bounds = bounds; nodes[index].begin = begin; nodes[index].end = end;
        if (end - begin <= 8) return index;
        const D3 extent = centroids.high - centroids.low;
        const int axis = extent.x >= extent.y && extent.x >= extent.z ? 0 : (extent.y >= extent.z ? 1 : 2);
        const int middle = begin + (end - begin) / 2;
        std::nth_element(order.begin() + begin, order.begin() + middle, order.begin() + end,
            [&](int a, int b) { return triangles[a].center.at(axis) < triangles[b].center.at(axis); });
        const int left = build(begin, middle), right = build(middle, end);
        nodes[index].left = left; nodes[index].right = right;
        return index;
    }

    void nearest(int index, const D3 &point, Nearest &result) const {
        const Node &node = nodes[index];
        if (node.bounds.distance_squared(point) > result.distance_squared) return;
        if (node.left < 0) {
            for (int i = node.begin; i < node.end; ++i) {
                const int id = order[i];
                const D3 closest = closest_triangle(point, triangles[id]);
                const double distance = (point - closest).length_squared();
                if (distance < result.distance_squared) result = {distance, closest, id};
            }
            return;
        }
        int first = node.left, last = node.right;
        if (nodes[first].bounds.distance_squared(point) > nodes[last].bounds.distance_squared(point)) std::swap(first, last);
        nearest(first, point, result); nearest(last, point, result);
    }

    void ray_hits(int index, const D3 &origin, const D3 &direction, std::vector<RayHit> &hits) const {
        const Node &node = nodes[index];
        if (!node.bounds.ray(origin, direction, std::numeric_limits<double>::infinity(), epsilon)) return;
        if (node.left >= 0) { ray_hits(node.left, origin, direction, hits); ray_hits(node.right, origin, direction, hits); return; }
        for (int i = node.begin; i < node.end; ++i) {
            RayHit hit;
            if (ray_triangle(origin, direction, triangles[order[i]], epsilon, std::numeric_limits<double>::infinity(), hit)) hits.push_back(hit);
        }
    }

    bool inside(const D3 &point, int &ambiguous_queries) const {
        const Box &bounds = nodes.front().bounds;
        if (bounds.distance_squared(point) > epsilon * epsilon) return false;
        static const std::array<D3, 5> directions{{
            D3(1.0, 0.3713906763541037, 0.6947465906068658).normalized(),
            D3(-0.542135623730951, 1.0, 0.219803902718557).normalized(),
            D3(0.3141592653589793, -0.618033988749895, 1.0).normalized(),
            D3(1.0, -0.754877666246693, -0.569840290998053).normalized(),
            D3(-0.414213562373095, -1.0, 0.732050807568877).normalized()
        }};
        int inside_votes = 0;
        for (const D3 &direction : directions) {
            std::vector<RayHit> hits;
            hits.reserve(8);
            ray_hits(0, point, direction, hits);
            std::sort(hits.begin(), hits.end(), [](const RayHit &a, const RayHit &b) { return a.t < b.t; });
            int crossings = 0;
            double previous = -std::numeric_limits<double>::infinity();
            bool ambiguous = false;
            for (const RayHit &hit : hits) {
                ambiguous = ambiguous || hit.edge;
                // Coincident hits from shared triangle edges are one surface.
                if (hit.t - previous > epsilon * 8.0) { ++crossings; previous = hit.t; }
            }
            const bool vote = (crossings % 2) != 0;
            if (!ambiguous) return vote;
            inside_votes += vote ? 1 : 0;
        }
        ++ambiguous_queries;
        return inside_votes >= 3;
    }

    bool segment_hits(int index, const D3 &a, const D3 &b) const {
        const Node &node = nodes[index];
        const D3 direction = b - a;
        if (!node.bounds.ray(a, direction, 1.0, segment_input_epsilon)) return false;
        if (node.left >= 0) return segment_hits(node.left, a, b) || segment_hits(node.right, a, b);
        for (int i = node.begin; i < node.end; ++i) {
            const Triangle &triangle = triangles[order[i]];
            RayHit hit;
            if (ray_triangle(a, direction, triangle, -1e-12, 1.0 + 1e-12, hit)) return true;
            if (std::abs((a - triangle.a).dot(triangle.normal)) > segment_input_epsilon ||
                    std::abs((b - triangle.a).dot(triangle.normal)) > segment_input_epsilon) continue;
            // Coplanar segments need an explicit boundary/edge test.
            const double e2 = segment_input_epsilon * segment_input_epsilon;
            if ((a - closest_triangle(a, triangle)).length_squared() <= e2 ||
                    (b - closest_triangle(b, triangle)).length_squared() <= e2 ||
                    segments_distance_squared(a, b, triangle.a, triangle.b) <= e2 ||
                    segments_distance_squared(a, b, triangle.b, triangle.c) <= e2 ||
                    segments_distance_squared(a, b, triangle.c, triangle.a) <= e2) return true;
        }
        return false;
    }
};

GripPoseSurfaceKernel::GripPoseSurfaceKernel() : impl_(std::make_unique<Impl>()) {}
GripPoseSurfaceKernel::~GripPoseSurfaceKernel() = default;

void GripPoseSurfaceKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("prepare", "faces"), &GripPoseSurfaceKernel::prepare);
    ClassDB::bind_method(D_METHOD("evaluate", "points"), &GripPoseSurfaceKernel::evaluate);
    ClassDB::bind_method(D_METHOD("intersects_segments", "endpoints"), &GripPoseSurfaceKernel::intersects_segments);
}

Dictionary GripPoseSurfaceKernel::prepare(const PackedVector3Array &faces) {
    // A failed replacement must never silently keep the previous target alive.
    impl_ = std::make_unique<Impl>();
    if (faces.size() < 12 || faces.size() % 3 != 0) return failure("closed_triangle_faces_required");
    if (faces.size() / 3 > std::numeric_limits<int>::max()) return failure("surface_too_large");
    std::map<std::tuple<double, double, double>, int> vertices;
    std::map<std::pair<int, int>, int> edges;
    Box bounds;
    for (int64_t i = 0; i < faces.size(); i += 3) {
        Triangle triangle;
        triangle.a = D3(faces[i]); triangle.b = D3(faces[i + 1]); triangle.c = D3(faces[i + 2]);
        if (!triangle.a.finite() || !triangle.b.finite() || !triangle.c.finite()) return failure("nonfinite_surface_vertex");
        const D3 normal = (triangle.b - triangle.a).cross(triangle.c - triangle.a);
        if (normal.length_squared() <= 1e-40) return failure("degenerate_surface_triangle");
        triangle.normal = normal.normalized(); triangle.center = (triangle.a + triangle.b + triangle.c) * (1.0 / 3.0);
        triangle.bounds.include(triangle.a); triangle.bounds.include(triangle.b); triangle.bounds.include(triangle.c);
        triangle.source = static_cast<int>(i / 3); bounds.include(triangle.bounds);
        impl_->triangles.push_back(triangle);
        const std::array<D3, 3> points{{triangle.a, triangle.b, triangle.c}};
        int ids[3];
        for (int corner = 0; corner != 3; ++corner) {
            const D3 &p = points[corner]; const auto key = std::make_tuple(p.x, p.y, p.z);
            const auto found = vertices.find(key);
            if (found == vertices.end()) { ids[corner] = static_cast<int>(vertices.size()); vertices.emplace(key, ids[corner]); }
            else ids[corner] = found->second;
        }
        for (int corner = 0; corner != 3; ++corner) {
            const int a = ids[corner], b = ids[(corner + 1) % 3];
            ++edges[std::make_pair(std::min(a, b), std::max(a, b))];
        }
    }
    for (const auto &edge : edges) if (edge.second != 2) return failure("surface_is_not_closed_two_manifold");
    impl_->epsilon = std::max(1e-11, std::sqrt((bounds.high - bounds.low).length_squared()) * 1e-10);
    const double coordinate_size = std::max({std::abs(bounds.low.x), std::abs(bounds.low.y), std::abs(bounds.low.z),
        std::abs(bounds.high.x), std::abs(bounds.high.y), std::abs(bounds.high.z)});
    impl_->segment_input_epsilon = std::max(impl_->epsilon,
        coordinate_size * static_cast<double>(std::numeric_limits<real_t>::epsilon()) * 4.0);
    impl_->order.resize(impl_->triangles.size());
    std::iota(impl_->order.begin(), impl_->order.end(), 0);
    impl_->nodes.reserve(impl_->triangles.size() / 3 + 1);
    impl_->build(0, static_cast<int>(impl_->triangles.size()));
    impl_->ready = true;
    Dictionary result;
    result["valid"] = true; result["triangle_count"] = static_cast<int64_t>(impl_->triangles.size());
    result["bounds_min"] = bounds.low.vector(); result["bounds_max"] = bounds.high.vector();
    result["distance_policy"] = StringName("nearest_triangle_signed_ray_parity_double");
    result["normal_policy"] = StringName("signed_distance_outward_gradient");
    return result;
}

Dictionary GripPoseSurfaceKernel::evaluate(const PackedVector3Array &points) const {
    if (!impl_->ready) return failure("surface_not_prepared");
    PackedFloat64Array distances;
    PackedVector3Array closest_points, normals;
    PackedInt32Array face_indices;
    distances.resize(points.size()); closest_points.resize(points.size()); normals.resize(points.size()); face_indices.resize(points.size());
    int ambiguous_queries = 0;
    for (int64_t i = 0; i < points.size(); ++i) {
        const D3 point(points[i]);
        if (!point.finite()) return failure("nonfinite_query_point");
        Nearest nearest;
        impl_->nearest(0, point, nearest);
        const double distance = std::sqrt(nearest.distance_squared);
        const bool boundary = distance <= impl_->epsilon;
        const bool inside = !boundary && impl_->inside(point, ambiguous_queries);
        distances.set(i, boundary ? 0.0 : (inside ? -distance : distance));
        closest_points.set(i, nearest.point.vector()); face_indices.set(i, impl_->triangles[nearest.triangle].source);
        D3 normal = impl_->triangles[nearest.triangle].normal;
        if (!boundary) normal = (point - nearest.point) * ((inside ? -1.0 : 1.0) / distance);
        else {
            // Winding-independent face normal at an exact boundary.
            if (impl_->inside(nearest.point + normal * (impl_->epsilon * 32.0), ambiguous_queries)) normal = normal * -1.0;
        }
        normals.set(i, normal.vector());
    }
    Dictionary result;
    result["valid"] = true; result["signed_distances"] = distances;
    result["closest_points"] = closest_points; result["normals"] = normals; result["face_indices"] = face_indices;
    result["ambiguous_parity_queries"] = ambiguous_queries;
    return result;
}

PackedByteArray GripPoseSurfaceKernel::intersects_segments(const PackedVector3Array &endpoints) const {
    PackedByteArray result;
    if (endpoints.size() % 2 != 0) return result;
    result.resize(endpoints.size() / 2);
    for (int64_t i = 0; i < endpoints.size(); i += 2) {
        const D3 a(endpoints[i]), b(endpoints[i + 1]);
        bool collision = true; // Fail closed for an unprepared or nonfinite query.
        if (impl_->ready && a.finite() && b.finite()) {
            int ambiguous = 0;
            collision = impl_->segment_hits(0, a, b) || impl_->inside(a, ambiguous) || impl_->inside(b, ambiguous);
        }
        result.set(i / 2, collision ? 1 : 0);
    }
    return result;
}

} // namespace godot
