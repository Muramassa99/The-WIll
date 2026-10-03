#include "register_types.h"

#include "grip_contact_kernel.h"
#include "grip_saved_contact_kernel.h"
#include "grip_slice_kernel.h"
#include "grip_topology_kernel.h"

#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/vector2.hpp>

using namespace godot;

// Scalar geometry may use double internally; the engine-facing Vector2 ABI
// must remain compatible with this project's standard-precision Godot build.
static_assert(sizeof(real_t) == sizeof(float), "Grip contact requires Godot single-precision real_t.");

void initialize_grip_contact(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    GDREGISTER_CLASS(GripContactKernel);
    GDREGISTER_CLASS(GripSavedContactKernel);
    GDREGISTER_CLASS(GripSliceKernel);
    GDREGISTER_CLASS(GripTopologyKernel);
}

void uninitialize_grip_contact(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

extern "C" {

GDExtensionBool GDE_EXPORT grip_contact_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *initialization
) {
    GDExtensionBinding::InitObject init_object(get_proc_address, library, initialization);
    init_object.register_initializer(initialize_grip_contact);
    init_object.register_terminator(uninitialize_grip_contact);
    init_object.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init_object.init();
}

}
