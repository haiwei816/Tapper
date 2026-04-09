#ifndef CYBER_TAPPER_INPUT_HANDLER_H
#define CYBER_TAPPER_INPUT_HANDLER_H

#include "config.h"
#include "types.h"
#include "game_state.h"
#include "game_logic.h"

#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/input_event_key.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/input_event_screen_touch.hpp>
#include <godot_cpp/classes/input_event_screen_drag.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace cyber_tapper {

/// Handles all player input: keyboard, mouse, and touch.
/// All methods are static, operating on a GameState reference.
/// Lane and drink indices are 0-based (C++ convention).
class InputHandler {
public:
    /// Main entry point: dispatch an InputEvent to the appropriate handler.
    /// Called from the main node's _input(event) override.
    static void handle_input(GameState &G,
                             const godot::Ref<godot::InputEvent> &event,
                             GameLogic &logic,
                             GameCallbacks &cb);

    /// Per-frame update for active mouse drags.
    /// Checks whether the mouse button is still held and updates the
    /// corresponding value (volume, master volume, or bartender position).
    /// Called from the main node's _process(dt).
    static void update_drags(GameState &G, float dt);

    /// Per-frame smooth interpolation of the bartender toward its target lane.
    /// When no move-drag is active the bartender lerps toward target_lane;
    /// the current discrete lane is always kept in sync.
    /// Called from the main node's _process(dt).
    static void update_bartender_movement(GameState &G, float dt);

private:
    // ---- hit-test helpers ----

    static bool is_in_volume_slider(const GameState &G, float x, float y);
    static bool is_in_master_slider(const GameState &G, float x, float y);
    static bool is_in_move_track(const GameState &G, float x, float y);

    // ---- drag value updaters ----

    static void drag_volume(GameState &G, float x, GameCallbacks &cb);
    static void drag_master_volume(GameState &G, float x, GameCallbacks &cb);
    static void drag_move_bartender(GameState &G, float y);

    // ---- pointer (click / tap) processing ----

    /// Shared logic for mouse clicks and touch taps.
    /// Handles menu/gameover restart, drink-button selection, and lane clicking.
    static void process_pointer_input(GameState &G, float x, float y,
                                      GameLogic &logic, GameCallbacks &cb);

    // ---- per-event-type handlers ----

    static void handle_key_down(GameState &G,
                                const godot::InputEventKey *key_event,
                                GameLogic &logic, GameCallbacks &cb);

    static void handle_mouse_button(GameState &G,
                                    const godot::InputEventMouseButton *mb_event,
                                    GameLogic &logic, GameCallbacks &cb);

    static void handle_mouse_motion(GameState &G,
                                    const godot::InputEventMouseMotion *mm_event,
                                    GameCallbacks &cb);

    static void handle_touch_begin(GameState &G,
                                   const godot::InputEventScreenTouch *touch_event,
                                   GameLogic &logic, GameCallbacks &cb);

    static void handle_touch_end(GameState &G,
                                 const godot::InputEventScreenTouch *touch_event);

    static void handle_touch_drag(GameState &G,
                                  const godot::InputEventScreenDrag *drag_event,
                                  GameCallbacks &cb);
};

} // namespace cyber_tapper

#endif // CYBER_TAPPER_INPUT_HANDLER_H
