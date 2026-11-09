#include "combat_pose_capture_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

void CombatPoseCaptureKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("node_pose_signature", "node", "excluded_fields",
            "curl_fields", "ordered_digits", "normalized_curls", "required_usage"),
            &CombatPoseCaptureKernel::node_pose_signature);
}

String CombatPoseCaptureKernel::node_pose_signature(Object *node,
        const Array &excluded_fields, const Array &curl_fields,
        const Array &ordered_digits, const Dictionary &normalized_curls,
        int64_t required_usage) const {
    if (node == nullptr) {
        return String();
    }
    Array values;
    const TypedArray<Dictionary> properties = node->get_property_list();
    for (int64_t index = 0; index < properties.size(); ++index) {
        const Dictionary property = properties[index];
        const StringName name = property["name"];
        const int64_t usage = property.get("usage", 0);
        if ((usage & required_usage) != required_usage || excluded_fields.has(name)) {
            continue;
        }
        // Untyped arrays and StringName keys intentionally match the existing
        // GDScript var_to_bytes representation, including its property order.
        Array pair;
        pair.append(name);
        pair.append(node->get(name));
        values.append(pair);
    }
    for (int64_t field_index = 0; field_index < curl_fields.size(); ++field_index) {
        const StringName field = curl_fields[field_index];
        const Variant authored = normalized_curls.get(field, Dictionary());
        if (authored.get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary curls = authored;
        if (curls.is_empty()) {
            continue;
        }
        Array ordered;
        for (int64_t digit_index = 0; digit_index < ordered_digits.size(); ++digit_index) {
            const StringName digit = ordered_digits[digit_index];
            if (!curls.has(digit)) {
                continue;
            }
            Array pair;
            pair.append(digit);
            pair.append(curls[digit]);
            ordered.append(pair);
        }
        Array pair;
        pair.append(field);
        pair.append(ordered);
        values.append(pair);
    }
    // Preserve the on-disk contract: SHA256 of hexadecimal serialized bytes,
    // not SHA256 of the raw bytes. Use the engine serializer and hash routines.
    return UtilityFunctions::var_to_bytes(values).hex_encode().sha256_text();
}

} // namespace godot
