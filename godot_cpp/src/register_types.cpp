// ============================================================================
// register_types.cpp - GDExtension registration for Cyber Tapper
//
// Standard boilerplate that registers the CyberTapper class with the Godot
// ClassDB so it can be used as a node type in the editor and at runtime.
// ============================================================================
#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "cyber_tapper.h"

using namespace godot;

// ---------------------------------------------------------------------------
// Initializer: called once per initialization level during engine startup.
// We register our classes at the SCENE level so they are available as nodes.
// ---------------------------------------------------------------------------
void initialize_cyber_tapper(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

    ClassDB::register_class<cyber_tapper::CyberTapper>();

    // Future classes to register here as the port grows:
    // ClassDB::register_class<cyber_tapper::SomeOtherNode>();
}

// ---------------------------------------------------------------------------
// Terminator: called once per initialization level during engine shutdown.
// Currently nothing to clean up; Godot's ClassDB handles deregistration.
// ---------------------------------------------------------------------------
void uninitialize_cyber_tapper(ModuleInitializationLevel p_level) {
    if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
    // No explicit teardown needed.
}

// ---------------------------------------------------------------------------
// GDExtension entry point
//
// This is the function named in the .gdextension configuration file.
// It wires up the initializer/terminator and sets the minimum init level.
//
// .gdextension example:
//   [configuration]
//   entry_symbol = "cyber_tapper_init"
//   compatibility_minimum = "4.2"
//
//   [libraries]
//   linux.debug.x86_64   = "res://bin/libcyber_tapper.linux.template_debug.x86_64.so"
//   linux.release.x86_64 = "res://bin/libcyber_tapper.linux.template_release.x86_64.so"
//   windows.debug.x86_64 = "res://bin/cyber_tapper.windows.template_debug.x86_64.dll"
//   windows.release.x86_64 = "res://bin/cyber_tapper.windows.template_release.x86_64.dll"
//   macos.debug          = "res://bin/libcyber_tapper.macos.template_debug.framework"
//   macos.release        = "res://bin/libcyber_tapper.macos.template_release.framework"
// ---------------------------------------------------------------------------
extern "C" {

GDExtensionBool GDE_EXPORT cyber_tapper_init(
        GDExtensionInterfaceGetProcAddress p_get_proc_address,
        GDExtensionClassLibraryPtr p_library,
        GDExtensionInitialization *r_initialization) {

    GDExtensionBinding::InitObject init_obj(
        p_get_proc_address, p_library, r_initialization);

    init_obj.register_initializer(initialize_cyber_tapper);
    init_obj.register_terminator(uninitialize_cyber_tapper);
    init_obj.set_minimum_library_initialization_level(
        MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_obj.init();
}

} // extern "C"
