#include "input_handler.h"

#include <algorithm>
#include <cmath>
#include <limits>

#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace cyber_tapper {

// ---------------------------------------------------------------------------
// Hit-test helpers
// ---------------------------------------------------------------------------

bool InputHandler::is_in_volume_slider(const GameState &G, float x, float y) {
    constexpr float pad = 12.0f;
    const Layout &L = G.layout;
    return x >= L.vol_slider_x - pad && x <= L.vol_slider_x + L.vol_slider_w + pad
        && y >= L.vol_slider_y - pad && y <= L.vol_slider_y + L.vol_slider_h + pad;
}

bool InputHandler::is_in_master_slider(const GameState &G, float x, float y) {
    constexpr float pad = 12.0f;
    const Layout &L = G.layout;
    return x >= L.master_slider_x - pad && x <= L.master_slider_x + L.master_slider_w + pad
        && y >= L.master_slider_y - pad && y <= L.master_slider_y + L.master_slider_h + pad;
}

bool InputHandler::is_in_move_track(const GameState &G, float x, float y) {
    const Layout &L = G.layout;
    return x >= L.move_track_x && x <= L.move_track_x + L.move_track_w
        && y >= L.move_track_y - 20.0f && y <= L.move_track_y + L.move_track_h + 20.0f;
}

// ---------------------------------------------------------------------------
// Drag value updaters
// ---------------------------------------------------------------------------

void InputHandler::drag_volume(GameState &G, float x, GameCallbacks &cb) {
    float ratio = (x - G.layout.vol_slider_x) / G.layout.vol_slider_w;
    G.bgm_volume = std::clamp(ratio, 0.0f, 1.0f);
    cb.apply_bgm_gain(G);
}

void InputHandler::drag_master_volume(GameState &G, float x, GameCallbacks &cb) {
    float ratio = (x - G.layout.master_slider_x) / G.layout.master_slider_w;
    G.master_volume = std::clamp(ratio, 0.0f, 1.0f);
    cb.apply_bgm_gain(G);
}

void InputHandler::drag_move_bartender(GameState &G, float y) {
    if (G.layout.lane_y.empty()) {
        return;
    }
    float min_y = G.layout.lane_y[0];
    float max_y = G.layout.lane_y[Config::NUM_LANES - 1];
    G.bartender.y = std::clamp(y, min_y, max_y);
    G.bartender.target_lane = G.get_closest_lane_from_y(G.bartender.y);
}

// ---------------------------------------------------------------------------
// Pointer input (shared by mouse click and touch tap)
// ---------------------------------------------------------------------------

void InputHandler::process_pointer_input(GameState &G, float x, float y,
                                         GameLogic &logic, GameCallbacks &cb) {
    // Menu / gameover: any click restarts.
    if (G.game_state == PlayState::Menu) {
        logic.reset_game(G, cb);
        return;
    }
    if (G.game_state == PlayState::GameOver) {
        logic.reset_game(G, cb);
        return;
    }
    if (G.game_state != PlayState::Playing) {
        return;
    }

    const Layout &L = G.layout;

    // -- Drink button area --------------------------------------------------
    int unlocked_count = std::min(static_cast<int>(Config::DRINK_TYPES.size()),
                                  G.level);

    if (x >= L.drink_btn_x && unlocked_count > 0) {
        float total_h = unlocked_count * L.drink_btn_h
                      + (unlocked_count - 1) * L.drink_btn_spacing;
        float area_top = L.drink_btn_start_y - L.drink_btn_spacing;
        float area_bot = L.drink_btn_start_y + total_h + L.drink_btn_spacing;

        if (y >= area_top && y <= area_bot) {
            int   best_idx  = 0;
            float best_dist = std::numeric_limits<float>::infinity();

            for (int i = 0; i < unlocked_count; ++i) {
                float by = L.drink_btn_start_y
                         + i * (L.drink_btn_h + L.drink_btn_spacing);
                float btn_center_y = by + L.drink_btn_h * 0.5f;
                float dist = std::abs(y - btn_center_y);
                if (dist < best_dist) {
                    best_dist = dist;
                    best_idx  = i;           // 0-based drink index
                }
            }
            logic.serve_drink(G, best_idx, cb);
            return;
        }
    }

    // -- Lane clicking ------------------------------------------------------
    for (int i = 0; i < Config::NUM_LANES; ++i) {
        float ly = G.get_lane_y(i);
        if (std::abs(y - ly) < L.lane_h * 0.8f) {
            G.bartender.target_lane = i;     // 0-based lane index
            return;
        }
    }
}

// ---------------------------------------------------------------------------
// Keyboard
// ---------------------------------------------------------------------------

void InputHandler::handle_key_down(GameState &G,
                                   const InputEventKey *key_event,
                                   GameLogic &logic, GameCallbacks &cb) {
    if (!key_event->is_pressed() || key_event->is_echo()) {
        return;
    }

    Key key = key_event->get_keycode();

    switch (G.game_state) {
        case PlayState::Menu:
            if (key == KEY_SPACE || key == KEY_ENTER) {
                logic.reset_game(G, cb);
            }
            break;

        case PlayState::Playing:
            // Movement
            if (key == KEY_UP || key == KEY_W) {
                logic.move_bartender(G, -1);
            } else if (key == KEY_DOWN || key == KEY_S) {
                logic.move_bartender(G, 1);
            }
            // Serve drinks (0-based indices)
            else if (key == KEY_1 || key == KEY_Z) {
                logic.serve_drink(G, 0, cb);
            } else if (key == KEY_2 || key == KEY_X) {
                logic.serve_drink(G, 1, cb);
            } else if (key == KEY_3 || key == KEY_C) {
                logic.serve_drink(G, 2, cb);
            } else if (key == KEY_4) {
                logic.serve_drink(G, 3, cb);
            } else if (key == KEY_5) {
                logic.serve_drink(G, 4, cb);
            } else if (key == KEY_6) {
                logic.serve_drink(G, 5, cb);
            }
            break;

        case PlayState::GameOver:
            if (key == KEY_SPACE || key == KEY_ENTER) {
                logic.reset_game(G, cb);
            }
            break;

        default:
            break;
    }
}

// ---------------------------------------------------------------------------
// Mouse button (press / release)
// ---------------------------------------------------------------------------

void InputHandler::handle_mouse_button(GameState &G,
                                       const InputEventMouseButton *mb_event,
                                       GameLogic &logic, GameCallbacks &cb) {
    if (mb_event->get_button_index() != MOUSE_BUTTON_LEFT) {
        return;
    }

    float mx = mb_event->get_position().x / G.dpr;
    float my = mb_event->get_position().y / G.dpr;

    if (mb_event->is_pressed()) {
        // -- Begin drags (mouse uses touch_id == -1) ------------------------
        if (is_in_volume_slider(G, mx, my)) {
            G.volume_drag.active   = true;
            G.volume_drag.touch_id = -1;
            drag_volume(G, mx, cb);
            return;
        }
        if (is_in_master_slider(G, mx, my)) {
            G.master_drag.active   = true;
            G.master_drag.touch_id = -1;
            drag_master_volume(G, mx, cb);
            return;
        }
        if (is_in_move_track(G, mx, my)) {
            G.move_drag.active   = true;
            G.move_drag.touch_id = -1;
            drag_move_bartender(G, my);
            return;
        }

        // -- Regular click --------------------------------------------------
        process_pointer_input(G, mx, my, logic, cb);

    } else {
        // -- Mouse release: end mouse drags ---------------------------------
        if (G.volume_drag.active && G.volume_drag.touch_id == -1) {
            G.volume_drag.active = false;
        }
        if (G.master_drag.active && G.master_drag.touch_id == -1) {
            G.master_drag.active = false;
        }
        if (G.move_drag.active && G.move_drag.touch_id == -1) {
            G.move_drag.active = false;
        }
    }
}

// ---------------------------------------------------------------------------
// Mouse motion (drag while held)
// ---------------------------------------------------------------------------

void InputHandler::handle_mouse_motion(GameState &G,
                                       const InputEventMouseMotion *mm_event,
                                       GameCallbacks &cb) {
    float mx = mm_event->get_position().x / G.dpr;
    float my = mm_event->get_position().y / G.dpr;

    if (G.volume_drag.active && G.volume_drag.touch_id == -1) {
        drag_volume(G, mx, cb);
    }
    if (G.master_drag.active && G.master_drag.touch_id == -1) {
        drag_master_volume(G, mx, cb);
    }
    if (G.move_drag.active && G.move_drag.touch_id == -1) {
        drag_move_bartender(G, my);
    }
}

// ---------------------------------------------------------------------------
// Touch begin
// ---------------------------------------------------------------------------

void InputHandler::handle_touch_begin(GameState &G,
                                      const InputEventScreenTouch *touch_event,
                                      GameLogic &logic, GameCallbacks &cb) {
    if (!touch_event->is_pressed()) {
        return; // This is a release; handled in handle_touch_end.
    }

    int   tid = touch_event->get_index();
    float tx  = touch_event->get_position().x / G.dpr;
    float ty  = touch_event->get_position().y / G.dpr;

    // -- Begin drags --------------------------------------------------------
    if (is_in_volume_slider(G, tx, ty) && !G.volume_drag.active) {
        G.volume_drag.active   = true;
        G.volume_drag.touch_id = tid;
        drag_volume(G, tx, cb);
        return;
    }
    if (is_in_master_slider(G, tx, ty) && !G.master_drag.active) {
        G.master_drag.active   = true;
        G.master_drag.touch_id = tid;
        drag_master_volume(G, tx, cb);
        return;
    }
    if (is_in_move_track(G, tx, ty) && !G.move_drag.active) {
        G.move_drag.active   = true;
        G.move_drag.touch_id = tid;
        drag_move_bartender(G, ty);
        return;
    }

    // -- Regular tap --------------------------------------------------------
    process_pointer_input(G, tx, ty, logic, cb);
}

// ---------------------------------------------------------------------------
// Touch end
// ---------------------------------------------------------------------------

void InputHandler::handle_touch_end(GameState &G,
                                    const InputEventScreenTouch *touch_event) {
    if (touch_event->is_pressed()) {
        return; // Not a release.
    }

    int tid = touch_event->get_index();

    if (G.volume_drag.active && G.volume_drag.touch_id == tid) {
        G.volume_drag.active = false;
    }
    if (G.master_drag.active && G.master_drag.touch_id == tid) {
        G.master_drag.active = false;
    }
    if (G.move_drag.active && G.move_drag.touch_id == tid) {
        G.move_drag.active = false;
    }
}

// ---------------------------------------------------------------------------
// Touch drag (move while touching)
// ---------------------------------------------------------------------------

void InputHandler::handle_touch_drag(GameState &G,
                                     const InputEventScreenDrag *drag_event,
                                     GameCallbacks &cb) {
    int   tid = drag_event->get_index();
    float tx  = drag_event->get_position().x / G.dpr;
    float ty  = drag_event->get_position().y / G.dpr;

    if (G.volume_drag.active && G.volume_drag.touch_id == tid) {
        drag_volume(G, tx, cb);
    }
    if (G.master_drag.active && G.master_drag.touch_id == tid) {
        drag_master_volume(G, tx, cb);
    }
    if (G.move_drag.active && G.move_drag.touch_id == tid) {
        drag_move_bartender(G, ty);
    }
}

// ---------------------------------------------------------------------------
// Public: main event dispatcher
// ---------------------------------------------------------------------------

void InputHandler::handle_input(GameState &G,
                                const Ref<InputEvent> &event,
                                GameLogic &logic,
                                GameCallbacks &cb) {
    // Keyboard
    const InputEventKey *key_event =
        Object::cast_to<InputEventKey>(event.ptr());
    if (key_event) {
        handle_key_down(G, key_event, logic, cb);
        return;
    }

    // Mouse button
    const InputEventMouseButton *mb_event =
        Object::cast_to<InputEventMouseButton>(event.ptr());
    if (mb_event) {
        handle_mouse_button(G, mb_event, logic, cb);
        return;
    }

    // Mouse motion
    const InputEventMouseMotion *mm_event =
        Object::cast_to<InputEventMouseMotion>(event.ptr());
    if (mm_event) {
        handle_mouse_motion(G, mm_event, cb);
        return;
    }

    // Touch (press / release)
    const InputEventScreenTouch *touch_event =
        Object::cast_to<InputEventScreenTouch>(event.ptr());
    if (touch_event) {
        if (touch_event->is_pressed()) {
            handle_touch_begin(G, touch_event, logic, cb);
        } else {
            handle_touch_end(G, touch_event);
        }
        return;
    }

    // Touch drag
    const InputEventScreenDrag *drag_event =
        Object::cast_to<InputEventScreenDrag>(event.ptr());
    if (drag_event) {
        handle_touch_drag(G, drag_event, cb);
        return;
    }
}

// ---------------------------------------------------------------------------
// Public: per-frame drag update (called from _process)
// ---------------------------------------------------------------------------

void InputHandler::update_drags(GameState &G, float dt) {
    Input *input_singleton = Input::get_singleton();
    if (!input_singleton) {
        return;
    }

    bool mouse_held = input_singleton->is_mouse_button_pressed(
        MOUSE_BUTTON_LEFT);
    Vector2 mouse_pos = input_singleton->get_mouse_position();

    // Volume slider drag (mouse only, touch_id == -1)
    if (G.volume_drag.active && G.volume_drag.touch_id == -1) {
        if (mouse_held) {
            float mx = mouse_pos.x / G.dpr;
            float ratio = (mx - G.layout.vol_slider_x) / G.layout.vol_slider_w;
            G.bgm_volume = std::clamp(ratio, 0.0f, 1.0f);
            // Note: apply_bgm_gain is deferred to the caller or callbacks
            // since we don't hold a GameCallbacks& here. The Lua original
            // calls G.ApplyBgmGain() directly on the state, so we update
            // the value and let the main loop apply it.
        } else {
            G.volume_drag.active = false;
        }
    }

    // Master volume slider drag (mouse only)
    if (G.master_drag.active && G.master_drag.touch_id == -1) {
        if (mouse_held) {
            float mx = mouse_pos.x / G.dpr;
            float ratio = (mx - G.layout.master_slider_x)
                        / G.layout.master_slider_w;
            G.master_volume = std::clamp(ratio, 0.0f, 1.0f);
        } else {
            G.master_drag.active = false;
        }
    }

    // Move track drag (mouse only)
    if (G.move_drag.active && G.move_drag.touch_id == -1) {
        if (mouse_held) {
            float my = mouse_pos.y / G.dpr;
            drag_move_bartender(G, my);
        } else {
            G.move_drag.active = false;
        }
    }
}

// ---------------------------------------------------------------------------
// Public: per-frame bartender smooth movement
// ---------------------------------------------------------------------------

void InputHandler::update_bartender_movement(GameState &G, float dt) {
    Bartender &bartender = G.bartender;

    // When not dragging, smoothly interpolate toward the target lane.
    if (!G.move_drag.active && !G.layout.lane_y.empty()) {
        float target_y = G.get_lane_y(bartender.target_lane);
        float diff     = target_y - bartender.y;

        if (std::abs(diff) > 0.5f) {
            bartender.y += diff * std::min(1.0f, dt * 18.0f);
        } else {
            bartender.y = target_y;
        }
    }

    // Always keep the discrete lane index in sync with the current y.
    if (!G.layout.lane_y.empty()) {
        bartender.lane = G.get_closest_lane_from_y(bartender.y);
    }
}

} // namespace cyber_tapper
