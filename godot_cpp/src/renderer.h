// ============================================================================
// renderer.h - Game Renderer (corresponds to Lua: CyberTapper/Renderer.lua)
//
// All drawing uses Godot CanvasItem draw_* API via a passed-in CanvasItem*.
// Static-method design: no instance state, everything read from GameState.
// ============================================================================
#ifndef CYBER_TAPPER_RENDERER_H
#define CYBER_TAPPER_RENDERER_H

#include "config.h"
#include "types.h"
#include "game_state.h"
#include "draw_lib.h"

#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/transform2d.hpp>

namespace cyber_tapper {

// ============================================================================
// GameRenderer - static-only class; every method takes a CanvasItem* for draw
// ============================================================================
class GameRenderer {
public:
    // ----------------------------------------------------------------
    // Main entry point - call from Node2D::_draw()
    // Draws everything in correct layer order.
    // ----------------------------------------------------------------
    static void render(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);

    // === Helper: patience formula (mirrors GameLogic::GetPatience) ===
    static float get_patience(int level);

private:
    // === Background ===
    static void draw_background(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);

    // === Lane layers ===
    static void draw_lanes_back(godot::CanvasItem* ci, GameState& G);
    static void draw_lanes_front(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);

    // === Bartender ===
    static void draw_bartender(godot::CanvasItem* ci, GameState& G);

    // === Customers ===
    static void draw_customers(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);
    static void draw_drink_bubble(godot::CanvasItem* ci, const godot::Ref<godot::Font>& font,
                                  float x, float y, int drink_type, float alpha,
                                  int remaining, float scale, float wait_ratio);
    static void draw_boss_bubble(godot::CanvasItem* ci, const godot::Ref<godot::Font>& font,
                                 float x, float y, const std::vector<int>& sequence,
                                 int seq_index, float alpha, float scale,
                                 float wait_ratio, float time);

    // === Drinks & empty bottles ===
    static void draw_drinks(godot::CanvasItem* ci, GameState& G);
    static void draw_empty_bottles(godot::CanvasItem* ci, GameState& G);

    // === Effects ===
    static void draw_particles(godot::CanvasItem* ci, GameState& G);
    static void draw_float_texts(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);

    // === HUD ===
    static void draw_hud(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);
    static void draw_volume_sliders(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);

    // === Buttons & controls ===
    static void draw_drink_buttons(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);
    static void draw_move_track(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);

    // === Overlays ===
    static void draw_leaderboard(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font,
                                 float panel_x, float panel_y, float panel_w, float panel_h);
    static void draw_menu(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);
    static void draw_game_over(godot::CanvasItem* ci, GameState& G, const godot::Ref<godot::Font>& font);
};

} // namespace cyber_tapper

#endif // CYBER_TAPPER_RENDERER_H
