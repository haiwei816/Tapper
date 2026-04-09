// ============================================================================
// renderer.cpp - Game Renderer (corresponds to Lua: CyberTapper/Renderer.lua ~860 lines)
//
// All drawing uses Godot CanvasItem draw_* API.  Layers are drawn in order:
//   1. Background   2. Lanes back   3. Drinks   4. Empty bottles
//   5. Customers    6. Lanes front  7. Bartender  8. Particles
//   9. Float texts  10. HUD  11. Drink buttons + Move track
//   12. Menu / Game-over overlay
// ============================================================================

#include "renderer.h"

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <godot_cpp/classes/text_server.hpp>
#include <cmath>
#include <algorithm>
#include <cstdlib>

namespace cyber_tapper {

// ========================================================================
// Convenience aliases
// ========================================================================
using CI   = godot::CanvasItem;
using V2   = godot::Vector2;
using Col  = godot::Color;
using Font = godot::Font;
using Str  = godot::String;

// ========================================================================
// Patience formula (mirrors GameLogic::GetPatience in Lua)
// ========================================================================
float GameRenderer::get_patience(int level) {
    float p = BASE_PATIENCE * (1.0f / (1.0f + (level - 1) * 0.1f));
    return std::max(6.0f, p);
}

// ========================================================================
// draw_text helper -- wraps ci->draw_string with common defaults
// ========================================================================
static void draw_text(CI* ci, const godot::Ref<Font>& font, V2 pos, const Str& text,
                      godot::HorizontalAlignment halign, int font_size, Col color,
                      float width = -1.0f) {
    if (!font.is_valid()) return;
    ci->draw_string(font, pos, text, halign, width, font_size, color);
}

// ========================================================================
// 1. Background
// ========================================================================
void GameRenderer::draw_background(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    float lw = G.logical_w;
    float lh = G.logical_h;

    // Full-screen gradient (dark purple)
    DrawLib::gradient_rect(ci, 0, 0, lw, lh,
                           12, 8, 28, 255,
                           6, 4, 18, 255);

    // Grid lines
    const float grid_size = 30.0f;
    Col grid_col = rgba(60, 40, 120, 20);
    for (float gx = 0; gx <= lw; gx += grid_size) {
        ci->draw_line(V2(gx, 0), V2(gx, lh), grid_col, 0.5f);
    }
    for (float gy = 0; gy <= lh; gy += grid_size) {
        ci->draw_line(V2(0, gy), V2(lw, gy), grid_col, 0.5f);
    }

    // Top header bar
    float top_h = lh * 0.08f;
    float sx = G.layout.safe_offset_x;
    float sw = G.layout.safe_w;
    DrawLib::gradient_rect(ci, sx, 0, sw, top_h,
                           20, 10, 50, 240,
                           10, 5, 30, 200);

    // Cyan glow line at bottom of header
    ci->draw_line(V2(sx, top_h), V2(sx + sw, top_h), rgba(0, 255, 255, 150), 2.0f);
    ci->draw_line(V2(sx, top_h), V2(sx + sw, top_h), rgba(0, 255, 255, 30), 8.0f);

    // Lane separator lines
    for (int i = 0; i < NUM_LANES; i++) {
        float y = G.get_lane_y(i);
        float half_h = G.layout.lane_h * 0.5f;
        ci->draw_line(V2(sx, y - half_h - 1), V2(sx + sw, y - half_h - 1),
                      rgba(80, 50, 150, 40), 1.0f);
    }
}

// ========================================================================
// 2. Lanes back layer (counter surface + rail)
// ========================================================================
void GameRenderer::draw_lanes_back(CI* ci, GameState& G) {
    const Layout& L = G.layout;

    for (int i = 0; i < NUM_LANES; i++) {
        float y     = G.get_lane_y(i);
        float h     = L.lane_h;
        float left  = L.counter_left;
        float right = L.counter_right;
        float w     = right - left;
        float top_y = y - h * 0.5f;
        float surface_h = h * 0.45f;

        // Counter surface gradient
        DrawLib::gradient_rect(ci, left, top_y, w, surface_h,
                               45, 30, 75, 255,
                               35, 22, 60, 255, 3);

        // Top edge highlight
        ci->draw_line(V2(left, top_y + 1), V2(right, top_y + 1),
                      rgba(120, 80, 200, 80), 1.0f);

        // Rail neon (cyan)
        float rail_y = top_y + surface_h - 1;
        ci->draw_line(V2(left - 2, rail_y), V2(right + 2, rail_y),
                      rgba(0, 255, 255, 180), 2.0f);
        ci->draw_line(V2(left - 2, rail_y), V2(right + 2, rail_y),
                      rgba(0, 255, 255, 30), 6.0f);
    }
}

// ========================================================================
// 6. Lanes front layer (front panel, strips, neon edges, pillars, labels)
// ========================================================================
void GameRenderer::draw_lanes_front(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    const Layout& L = G.layout;

    for (int i = 0; i < NUM_LANES; i++) {
        float y     = G.get_lane_y(i);
        float h     = L.lane_h;
        float left  = L.counter_left;
        float right = L.counter_right;
        float w     = right - left;
        float top_y = y - h * 0.5f;
        float surface_h = h * 0.45f;
        float panel_top = top_y + surface_h;
        float front_h   = h * 0.55f;

        // Front panel gradient
        DrawLib::gradient_rect(ci, left, panel_top, w, front_h,
                               25, 18, 48, 255,
                               15, 10, 32, 255, 3);

        // Horizontal strip lines (2 inner dividers)
        float strip_h = front_h / 3.0f;
        for (int p = 1; p <= 2; p++) {
            float sy = panel_top + strip_h * p;
            ci->draw_line(V2(left + 8, sy), V2(right - 8, sy),
                          rgba(80, 50, 150, 30), 0.5f);
        }

        // Shadow gradient at panel top
        DrawLib::gradient_rect(ci, left, panel_top, w, 4,
                               0, 0, 0, 100,
                               0, 0, 0, 0);

        // Bottom neon edge (pink)
        float bottom_y = panel_top + front_h;
        ci->draw_line(V2(left, bottom_y), V2(right, bottom_y),
                      rgba(255, 50, 200, 100), 1.5f);
        ci->draw_line(V2(left, bottom_y), V2(right, bottom_y),
                      rgba(255, 50, 200, 20), 6.0f);

        // Side pillars
        float total_h = surface_h + front_h;
        DrawLib::round_rect(ci, left - 3, top_y, 3, total_h, 1, 40, 25, 70, 200);
        DrawLib::round_rect(ci, right, top_y, 3, total_h, 1, 40, 25, 70, 200);

        // "BAR N" label
        if (font.is_valid()) {
            Str label = Str("BAR ") + Str::num_int64(i + 1);
            draw_text(ci, font, V2(left + 20, panel_top + front_h * 0.45f + 4),
                      label, godot::HORIZONTAL_ALIGNMENT_CENTER, 10,
                      rgba(120, 80, 200, 80));
        }
    }
}

// ========================================================================
// 7. Bartender (two instances: right facing left, left facing right)
// ========================================================================
void GameRenderer::draw_bartender(CI* ci, GameState& G) {
    const Bartender& bt  = G.bartender;
    const Layout& L      = G.layout;
    float by             = bt.y;
    float serve_anim     = std::max(0.0f, bt.serve_anim);
    float scale          = std::max(3.5f, L.lane_h * 0.065f);

    // Right bartender (facing left)
    DrawLib::draw_cyber_bartender(ci, L.bartender_x_right, by, scale, true, serve_anim, 255);
    // Left bartender (facing right, half serve anim)
    DrawLib::draw_cyber_bartender(ci, L.bartender_x_left, by, scale, false, serve_anim * 0.5f, 255);

    // Left-side drink catching animation
    if (bt.left_drink_anim > 0.0f && bt.left_drink_type >= 0) {
        const DrinkType& dt = DRINK_TYPES[bt.left_drink_type];
        float s = scale;
        float sip_progress = 1.0f - bt.left_drink_anim;
        float lift_t;
        if (sip_progress < 0.2f) {
            lift_t = sip_progress / 0.2f;
        } else if (sip_progress > 0.8f) {
            lift_t = (1.0f - sip_progress) / 0.2f;
        } else {
            lift_t = 1.0f;
        }
        float cup_base_y = by + s * 0.5f;
        float cup_top_y  = by - s * 5.0f;
        float cup_y      = cup_base_y + (cup_top_y - cup_base_y) * lift_t;

        DrawLib::draw_cyber_drink(ci, L.bartender_x_left + s * 4.0f, cup_y, s * 0.7f,
                                  dt.r, dt.g, dt.b, true);
    }
}

// ========================================================================
// Drink bubble (single drink request)
// ========================================================================
void GameRenderer::draw_drink_bubble(CI* ci, const godot::Ref<Font>& font,
                                     float x, float y, int drink_type,
                                     float alpha, int remaining,
                                     float scale, float wait_ratio) {
    const DrinkType& dt = DRINK_TYPES[drink_type];
    float s = scale;
    float bubble_size = s * 4.0f;
    float rad = bubble_size * 0.3f;

    // Stem line
    ci->draw_line(V2(x, y + bubble_size), V2(x, y + bubble_size + s * 2.0f),
                  rgba(dt.r, dt.g, dt.b, std::floor(alpha * 0.3f)), 1.0f);

    // Bubble background
    float bx = x - bubble_size;
    float by = y - bubble_size;
    float bw = bubble_size * 2.0f;
    float bh = bubble_size * 2.0f;
    DrawLib::round_rect(ci, bx, by, bw, bh, rad,
                        15, 10, 30, std::floor(alpha * 0.85f));

    // Patience fill (vertical from bottom)
    if (wait_ratio > 0.01f) {
        float fill_h = bh * wait_ratio;
        float fill_y = by + bh - fill_h;
        float fr = 255;
        float fg = std::floor(220 - 170 * wait_ratio);
        float fb = std::floor(40 - 10 * wait_ratio);
        float fa = std::floor(alpha * (0.25f + 0.35f * wait_ratio));

        // Clipped fill -- use a slightly inset rect to simulate scissor
        DrawLib::round_rect(ci, bx + 1, fill_y, bw - 2, fill_h + 1, rad,
                            fr, fg, fb, fa);
    }

    // Neon border
    DrawLib::neon_stroke(ci, bx, by, bw, bh, rad,
                         dt.r, dt.g, dt.b, std::floor(alpha * 0.6f), 1.0f);

    // Content: remaining count or drink icon
    if (remaining > 1) {
        if (font.is_valid()) {
            Str text = Str("x") + Str::num_int64(remaining);
            draw_text(ci, font, V2(x, y + std::max(10.0f, s * 4.0f) * 0.35f),
                      text, godot::HORIZONTAL_ALIGNMENT_CENTER,
                      (int)std::max(10.0f, s * 4.0f),
                      rgba(dt.r, dt.g, dt.b, alpha));
        }
    } else {
        DrawLib::draw_cyber_drink(ci, x, y, s * 0.5f, dt.r, dt.g, dt.b, true);
    }
}

// ========================================================================
// Boss bubble (sequence of 6 drinks)
// ========================================================================
void GameRenderer::draw_boss_bubble(CI* ci, const godot::Ref<Font>& font,
                                    float x, float y,
                                    const std::vector<int>& sequence,
                                    int seq_index, float alpha, float scale,
                                    float wait_ratio, float time) {
    float s = scale;
    int total_drinks = (int)sequence.size();
    float icon_s  = s * 2.8f;
    float bubble_w = icon_s * total_drinks + s * 4.0f;
    float bubble_h = s * 7.0f;
    float bx = x - bubble_w / 2.0f;
    float by = y - bubble_h;

    // Stem line (orange)
    ci->draw_line(V2(x, y), V2(x, y + s * 1.5f),
                  rgba(255, 160, 40, std::floor(alpha * 0.4f)), 1.0f);

    float rad = s * 1.2f;
    DrawLib::round_rect(ci, bx, by, bubble_w, bubble_h, rad,
                        15, 10, 30, std::floor(alpha * 0.9f));

    // Patience fill
    if (wait_ratio > 0.01f) {
        float fill_h = bubble_h * wait_ratio;
        float fill_y = by + bubble_h - fill_h;
        float fr = 255;
        float fg = std::floor(220 - 170 * wait_ratio);
        float fb = std::floor(40 - 10 * wait_ratio);
        float fa = std::floor(alpha * (0.2f + 0.3f * wait_ratio));
        DrawLib::round_rect(ci, bx + 1, fill_y, bubble_w - 2, fill_h + 1, rad,
                            fr, fg, fb, fa);
    }

    // Neon border (orange)
    DrawLib::neon_stroke(ci, bx, by, bubble_w, bubble_h, rad,
                         255, 160, 40, std::floor(alpha * 0.5f), 1.0f);

    // Individual drink icons
    float start_x = bx + s * 2.0f;
    float icon_cy  = by + bubble_h / 2.0f;

    for (int i = 0; i < total_drinks; i++) {
        int drink_idx = sequence[i];
        const DrinkType& dt = DRINK_TYPES[drink_idx];
        float icon_cx = start_x + i * icon_s + icon_s / 2.0f;
        float icon_alpha = alpha;

        // seq_index is 1-based (from Lua), i is 0-based
        int one_based = i + 1;

        if (one_based < seq_index) {
            // Already completed -- dimmed with checkmark
            icon_alpha = std::floor(alpha * 0.3f);
            DrawLib::draw_circle(ci, icon_cx, icon_cy, s * 1.1f,
                                 dt.r, dt.g, dt.b, icon_alpha);
            // Checkmark
            Col check_col = rgba(0, 255, 120, std::floor(alpha * 0.7f));
            ci->draw_line(V2(icon_cx - s * 0.6f, icon_cy),
                          V2(icon_cx - s * 0.15f, icon_cy + s * 0.5f),
                          check_col, 2.0f);
            ci->draw_line(V2(icon_cx - s * 0.15f, icon_cy + s * 0.5f),
                          V2(icon_cx + s * 0.7f, icon_cy - s * 0.5f),
                          check_col, 2.0f);

        } else if (one_based == seq_index) {
            // Current -- pulsing
            float pulse = sinf(time * 6.0f) * 0.15f + 1.0f;
            float pr = s * 1.3f * pulse;
            // Outer glow
            DrawLib::draw_circle(ci, icon_cx, icon_cy, pr + s * 0.4f,
                                 dt.r, dt.g, dt.b, std::floor(alpha * 0.2f));
            // Inner
            DrawLib::draw_circle(ci, icon_cx, icon_cy, pr,
                                 dt.r, dt.g, dt.b, icon_alpha);
            // Icon text
            if (font.is_valid()) {
                int fs = (int)std::max(9.0f, s * 3.0f);
                draw_text(ci, font, V2(icon_cx, icon_cy + fs * 0.35f),
                          Str(dt.icon), godot::HORIZONTAL_ALIGNMENT_CENTER,
                          fs, rgba(255, 255, 255, icon_alpha));
            }
            // Arrow indicator below
            godot::PackedVector2Array arrow;
            arrow.push_back(V2(icon_cx - s * 0.5f, by + bubble_h - s * 0.4f));
            arrow.push_back(V2(icon_cx, by + bubble_h + s * 0.4f));
            arrow.push_back(V2(icon_cx + s * 0.5f, by + bubble_h - s * 0.4f));
            ci->draw_colored_polygon(arrow, rgba(255, 200, 40, std::floor(icon_alpha * 0.8f)));

        } else {
            // Future -- dimmed
            icon_alpha = std::floor(alpha * 0.5f);
            DrawLib::draw_circle(ci, icon_cx, icon_cy, s * 1.1f,
                                 dt.r, dt.g, dt.b, icon_alpha);
            if (font.is_valid()) {
                int fs = (int)std::max(8.0f, s * 2.5f);
                draw_text(ci, font, V2(icon_cx, icon_cy + fs * 0.35f),
                          Str(dt.icon), godot::HORIZONTAL_ALIGNMENT_CENTER,
                          fs, rgba(255, 255, 255, std::floor(alpha * 0.4f)));
            }
        }
    }
}

// ========================================================================
// 5. Customers
// ========================================================================
void GameRenderer::draw_customers(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    const Layout& L = G.layout;

    for (const Customer& c : G.customers) {
        float y = G.get_lane_y(c.lane) + L.customer_offset_y;
        float bob = sinf(c.bob_phase) * 1.5f;
        float scale = std::max(3.2f, L.lane_h * 0.06f);
        if (c.is_boss) scale *= 1.5f;
        float alpha = 255.0f;

        if (c.served_anim > 0.0f) {
            alpha = std::floor(255.0f * (c.served_anim / 0.8f));
        }

        float br = c.body_r;
        float bg = c.body_g;
        float bb = c.body_b;

        // Angry red mix
        if (c.angry_timer > 0.0f) {
            float angry_t = sinf(c.angry_timer * 20.0f) * 0.5f + 0.5f;
            float mix = angry_t * 0.6f;
            br = std::floor(br + (255 - br) * mix);
            bg = std::floor(bg * (1.0f - mix * 0.7f));
            bb = std::floor(bb * (1.0f - mix * 0.7f));
        }

        // Draw character body
        DrawLib::draw_cyber_char(ci, c.x, y + bob, scale, br, bg, bb, alpha);

        // Draw bubble (only if not being served and not sipping)
        if (c.served_anim <= 0.0f && !(c.sip_anim > 0.0f)) {
            int remaining = (c.drinks_needed) - (c.drinks_received);
            float patience = get_patience(G.level);
            if (c.is_boss) patience *= 3.0f;
            float wait_ratio = std::min(1.0f, c.wait_time / patience);

            if (c.is_boss && !c.drink_sequence.empty()) {
                draw_boss_bubble(ci, font, c.x, y + bob - scale * 9.0f,
                                 c.drink_sequence, c.sequence_index,
                                 alpha, scale, wait_ratio, G.time);
            } else {
                draw_drink_bubble(ci, font, c.x, y + bob - scale * 9.0f,
                                  c.drink_type, alpha, remaining, scale, wait_ratio);
            }
        }

        // Sip animation
        if (c.sip_anim > 0.0f && c.sip_drink_type >= 0) {
            const DrinkType& sip_dt = DRINK_TYPES[c.sip_drink_type];
            float sip_progress = 1.0f - (c.sip_anim / 1.0f);
            float lift_t;
            if (sip_progress < 0.2f)      lift_t = sip_progress / 0.2f;
            else if (sip_progress > 0.8f) lift_t = (1.0f - sip_progress) / 0.2f;
            else                           lift_t = 1.0f;

            float cup_base_y = y + bob;
            float cup_top_y  = y + bob - scale * 6.0f;
            float cup_y      = cup_base_y + (cup_top_y - cup_base_y) * lift_t;

            DrawLib::draw_cyber_drink(ci, c.x + scale * 3.5f, cup_y, scale * 0.55f,
                                     sip_dt.r, sip_dt.g, sip_dt.b, true);
        }
    }
}

// ========================================================================
// 3. Drinks (sliding along counter)
// ========================================================================
void GameRenderer::draw_drinks(CI* ci, GameState& G) {
    const Layout& L = G.layout;

    for (const Drink& d : G.drinks) {
        float y = G.get_lane_y(d.lane) - L.lane_h * 0.18f;
        const DrinkType& dt = DRINK_TYPES[d.drink_type];
        float s = std::max(2.0f, L.lane_h * 0.035f);

        // Trail particles
        for (int t = 1; t <= 4; t++) {
            float tx = d.x + t * 8.0f;
            float ta = std::floor(120 - t * 25);
            DrawLib::draw_circle(ci, tx, y, 2.0f, dt.r, dt.g, dt.b, ta);
        }

        // Drink icon
        DrawLib::draw_cyber_drink(ci, d.x, y, s, dt.r, dt.g, dt.b, true);
    }
}

// ========================================================================
// 4. Empty bottles (spinning back)
// ========================================================================
void GameRenderer::draw_empty_bottles(CI* ci, GameState& G) {
    const Layout& L = G.layout;

    for (const EmptyBottle& b : G.empty_bottles) {
        float y = G.get_lane_y(b.lane) - L.lane_h * 0.18f;
        const DrinkType& dt = DRINK_TYPES[b.drink_type];
        float s = std::max(2.0f, L.lane_h * 0.035f);

        float spin   = b.trail_timer * 6.0f;
        float tilt_x = sinf(spin) * s * 2.0f;
        float tilt_y = cosf(spin) * s;

        DrawLib::draw_cyber_drink(ci, b.x + tilt_x, y + tilt_y, s,
                                  dt.r, dt.g, dt.b, false);
    }
}

// ========================================================================
// 8. Particles
// ========================================================================
void GameRenderer::draw_particles(CI* ci, GameState& G) {
    for (const Particle& p : G.particles) {
        float alpha = std::floor((p.life / p.max_life) * 255.0f);
        float sz    = std::max(1.0f, p.size * (p.life / p.max_life));

        // Outer glow
        DrawLib::draw_circle(ci, p.x, p.y, sz * 1.5f,
                             p.r, p.g, p.b, std::floor(alpha * 0.2f));
        // Core
        DrawLib::draw_circle(ci, p.x, p.y, sz * 0.6f,
                             p.r, p.g, p.b, alpha);
    }
}

// ========================================================================
// 9. Float texts (scaling up, fading out)
// ========================================================================
void GameRenderer::draw_float_texts(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    if (!font.is_valid()) return;

    for (const FloatText& ft : G.float_texts) {
        float alpha = std::floor((ft.life / ft.max_life) * 255.0f);
        float scale = 1.0f + (1.0f - ft.life / ft.max_life) * 0.3f;

        // Apply scale transform centered on text position
        godot::Transform2D xform;
        xform = xform.translated(V2(ft.x, ft.y));
        xform = xform.scaled(V2(scale, scale));
        ci->draw_set_transform_matrix(xform);

        Str text(ft.text.c_str());

        // Shadow (larger, dimmer)
        draw_text(ci, font, V2(0, 0), text,
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 14,
                  rgba(ft.r, ft.g, ft.b, std::floor(alpha * 0.3f)));

        // Main text
        draw_text(ci, font, V2(0, 0), text,
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 13,
                  rgba(ft.r, ft.g, ft.b, alpha));

        // Reset transform
        ci->draw_set_transform_matrix(godot::Transform2D());
    }
}

// ========================================================================
// Volume sliders
// ========================================================================
void GameRenderer::draw_volume_sliders(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    const Layout& L = G.layout;

    // BGM slider (left)
    DrawLib::draw_neon_slider(ci, font,
                              L.vol_slider_x, L.vol_slider_y,
                              L.vol_slider_w, L.vol_slider_h,
                              G.bgm_volume, "BGM", false,
                              0, 255, 255,
                              255, 50, 200);

    // Master volume slider (right)
    DrawLib::draw_neon_slider(ci, font,
                              L.master_slider_x, L.master_slider_y,
                              L.master_slider_w, L.master_slider_h,
                              G.master_volume, "VOL", true,
                              255, 255, 60,
                              255, 160, 40);
}

// ========================================================================
// 10. HUD (score, level, combo, lives, controls hint)
// ========================================================================
void GameRenderer::draw_hud(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    if (G.game_state != GameStateEnum::Playing) return;
    if (!font.is_valid()) return;

    float lw = G.logical_w;
    float lh = G.logical_h;
    float sx = G.layout.safe_offset_x;
    float sw = G.layout.safe_w;

    // Score label
    draw_text(ci, font, V2(sx + 10, 14), Str("SCORE"),
              godot::HORIZONTAL_ALIGNMENT_LEFT, 12, rgba(0, 255, 255, 200));

    // Score value
    draw_text(ci, font, V2(sx + 10, 36), Str::num_int64(G.score),
              godot::HORIZONTAL_ALIGNMENT_LEFT, 22, rgba(255, 255, 255, 255));

    // Level
    Str level_str = Str("LEVEL ") + Str::num_int64(G.level);
    draw_text(ci, font, V2(lw / 2.0f, 16), level_str,
              godot::HORIZONTAL_ALIGNMENT_CENTER, 14, rgba(255, 50, 200, 255));

    // Combo
    if (G.combo > 1) {
        Str combo_str = Str("COMBO x") + Str::num_int64(G.combo);
        draw_text(ci, font, V2(lw / 2.0f, 34), combo_str,
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 13, rgba(255, 255, 60, 255));
    }

    // Lives label
    draw_text(ci, font, V2(sx + sw - 10, 14), Str("LIVES"),
              godot::HORIZONTAL_ALIGNMENT_RIGHT, 12, rgba(255, 50, 200, 200));

    // Lives circles
    for (int i = 0; i < MAX_LIVES; i++) {
        float hx = sx + sw - 14 - (MAX_LIVES - 1 - i) * 18.0f;
        float hy = 22.0f;
        if (i < G.lives) {
            DrawLib::draw_circle(ci, hx + 7, hy + 7, 6, 255, 50, 200, 220);
            DrawLib::draw_circle(ci, hx + 7, hy + 7, 3, 255, 150, 230, 180);
        } else {
            DrawLib::draw_circle(ci, hx + 7, hy + 7, 6, 50, 30, 60, 150);
        }
    }

    // Controls hint
    draw_text(ci, font, V2(lw / 2.0f, lh - 4), Str("UP/DOWN Move | 1-6 Send Drinks"),
              godot::HORIZONTAL_ALIGNMENT_CENTER, 10, rgba(100, 80, 150, 120));

    // Volume sliders
    draw_volume_sliders(ci, G, font);
}

// ========================================================================
// Move track (left panel with lane dots and handle slider)
// ========================================================================
void GameRenderer::draw_move_track(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    const Layout& L      = G.layout;
    const Bartender& bt  = G.bartender;
    float tx = L.move_track_x;
    float ty = L.move_track_y;
    float tw = L.move_track_w;
    float th = L.move_track_h;
    float cx = tx + tw / 2.0f;

    // Track background
    DrawLib::round_rect(ci, tx, ty, tw, th, 6, 15, 10, 30, 180);
    DrawLib::neon_stroke(ci, tx, ty, tw, th, 6,
                         80, 60, 150, G.move_drag.active ? 150.0f : 60.0f, 1.0f);

    // Center vertical line
    ci->draw_line(V2(cx, ty + 10), V2(cx, ty + th - 10),
                  rgba(80, 60, 150, 60), 2.0f);

    // Lane dots
    for (int i = 0; i < NUM_LANES; i++) {
        float lane_y = L.lane_y[i];
        bool is_active = (i == bt.target_lane);

        DrawLib::draw_circle(ci, cx, lane_y, is_active ? 4.0f : 3.0f,
                             is_active ? 0.0f : 60.0f,
                             is_active ? 255.0f : 60.0f,
                             is_active ? 255.0f : 80.0f,
                             is_active ? 255.0f : 100.0f);

        if (font.is_valid()) {
            Str num = Str::num_int64(i + 1);
            draw_text(ci, font, V2(tx + 10, lane_y + 3),
                      num, godot::HORIZONTAL_ALIGNMENT_CENTER, 9,
                      rgba(100, 80, 150, 150));
        }
    }

    // Handle slider
    float handle_y = bt.y;
    float handle_w = tw - 8.0f;
    float handle_h = 14.0f;

    DrawLib::round_rect(ci, cx - handle_w / 2.0f, handle_y - handle_h / 2.0f,
                        handle_w, handle_h, 4, 0, 200, 220, 220);

    // Handle glow outline
    DrawLib::round_rect_stroke(ci, cx - handle_w / 2.0f - 2, handle_y - handle_h / 2.0f - 2,
                               handle_w + 4, handle_h + 4, 5,
                               0, 255, 255, G.move_drag.active ? 120.0f : 40.0f, 3.0f);
}

// ========================================================================
// 11. Drink buttons (right side panel)
// ========================================================================
void GameRenderer::draw_drink_buttons(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    if (G.game_state != GameStateEnum::Playing) return;

    const Layout& L = G.layout;
    int unlocked_count = std::min((int)DRINK_TYPES.size(), G.level);

    for (int i = 0; i < unlocked_count; i++) {
        const DrinkType& dt = DRINK_TYPES[i];
        float bx = L.drink_btn_x;
        float by = L.drink_btn_start_y + i * (L.drink_btn_h + L.drink_btn_spacing);

        // Button background
        DrawLib::round_rect(ci, bx, by, L.drink_btn_w, L.drink_btn_h, 4,
                            18, 12, 35, 200);
        // Neon border
        DrawLib::neon_stroke(ci, bx, by, L.drink_btn_w, L.drink_btn_h, 4,
                             dt.r, dt.g, dt.b, 160, 1.5f);

        // Drink icon
        float btn_cx = bx + L.drink_btn_w / 2.0f;
        float btn_cy = by + L.drink_btn_h / 2.0f - 2.0f;
        float s = std::max(1.2f, L.drink_btn_h * 0.06f);
        DrawLib::draw_cyber_drink(ci, btn_cx, btn_cy, s, dt.r, dt.g, dt.b, true);

        // Key label
        if (font.is_valid()) {
            draw_text(ci, font, V2(btn_cx, by + L.drink_btn_h - 2),
                      Str(dt.key), godot::HORIZONTAL_ALIGNMENT_CENTER, 9,
                      rgba(dt.r, dt.g, dt.b, 180));
        }
    }

    // Also draw the move track on the left
    draw_move_track(ci, G, font);
}

// ========================================================================
// Leaderboard panel
// ========================================================================
void GameRenderer::draw_leaderboard(CI* ci, GameState& G, const godot::Ref<Font>& font,
                                    float panel_x, float panel_y,
                                    float panel_w, float panel_h) {
    if (!font.is_valid()) return;

    float pad      = 8.0f;
    float header_h = 24.0f;
    float row_h    = 20.0f;
    float cx       = panel_x + panel_w / 2.0f;

    // Header
    draw_text(ci, font, V2(cx, panel_y + header_h / 2.0f + 7),
              Str("LEADERBOARD"), godot::HORIZONTAL_ALIGNMENT_CENTER, 14,
              rgba(255, 200, 40, 255));

    ci->draw_line(V2(panel_x + pad, panel_y + header_h),
                  V2(panel_x + panel_w - pad, panel_y + header_h),
                  rgba(255, 200, 40, 80), 1.0f);

    // Loading state
    if (G.leaderboard_loading) {
        draw_text(ci, font, V2(cx, panel_y + header_h + 35),
                  Str::utf8("\xe5\x8a\xa0\xe8\xbd\xbd\xe4\xb8\xad..."), // "加载中..."
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 12,
                  rgba(180, 180, 220, 180));
        return;
    }

    // Empty state
    if (G.leaderboard.empty()) {
        draw_text(ci, font, V2(cx, panel_y + header_h + 35),
                  Str::utf8("\xe6\x9a\x82\xe6\x97\xa0\xe6\x95\xb0\xe6\x8d\xae"), // "暂无数据"
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 12,
                  rgba(180, 180, 220, 180));
        return;
    }

    // Entries
    int max_rows = std::min((int)G.leaderboard.size(),
                            (int)std::floor((panel_h - header_h - 30) / row_h));
    for (int i = 0; i < max_rows; i++) {
        const LeaderboardEntry& entry = G.leaderboard[i];
        float ry = panel_y + header_h + 6 + i * row_h;

        // Highlight own entry
        if (entry.is_me) {
            DrawLib::round_rect(ci, panel_x + pad - 2, ry - 1,
                                panel_w - pad * 2 + 4, row_h - 2, 3,
                                0, 255, 255, 30);
        }

        // Rank color (gold/silver/bronze/default)
        float rr = 180, rg = 180, rb = 220;
        if (i == 0)      { rr = 255; rg = 215; rb = 0; }
        else if (i == 1) { rr = 200; rg = 200; rb = 210; }
        else if (i == 2) { rr = 205; rg = 127; rb = 50; }

        // Rank number
        Str rank_str = Str("#") + Str::num_int64(i + 1);
        draw_text(ci, font, V2(panel_x + pad + 2, ry + row_h / 2.0f + 4),
                  rank_str, godot::HORIZONTAL_ALIGNMENT_LEFT, 12,
                  rgba(rr, rg, rb, 255));

        // Nickname
        Col name_col = entry.is_me ? rgba(0, 255, 255, 255) : rgba(220, 220, 240, 255);
        std::string display_name = entry.nickname.empty() ? "..." : entry.nickname;
        if (display_name.size() > 18) {
            display_name = display_name.substr(0, 16) + "..";
        }
        draw_text(ci, font, V2(panel_x + pad + 28, ry + row_h / 2.0f + 4),
                  Str(display_name.c_str()), godot::HORIZONTAL_ALIGNMENT_LEFT, 12,
                  name_col);

        // Score
        draw_text(ci, font, V2(panel_x + panel_w - pad - 2, ry + row_h / 2.0f + 4),
                  Str::num_int64(entry.score),
                  godot::HORIZONTAL_ALIGNMENT_RIGHT, 12,
                  rgba(255, 255, 255, 255));
    }

    // Footer: own rank
    if (G.my_rank > 0) {
        float footer_y = panel_y + panel_h - 14;
        // "我的排名: #N / M人"
        Str rank_text = Str::utf8("\xe6\x88\x91\xe7\x9a\x84\xe6\x8e\x92\xe5\x90\x8d: #")
                        + Str::num_int64(G.my_rank);
        if (G.leaderboard_total > 0) {
            rank_text = rank_text + Str(" / ") + Str::num_int64(G.leaderboard_total)
                        + Str::utf8("\xe4\xba\xba");
        }
        draw_text(ci, font, V2(cx, footer_y),
                  rank_text, godot::HORIZONTAL_ALIGNMENT_CENTER, 10,
                  rgba(0, 255, 255, 180));
    }
}

// ========================================================================
// 12a. Menu overlay
// ========================================================================
void GameRenderer::draw_menu(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    float lw = G.logical_w;
    float lh = G.logical_h;

    // Full-screen dim
    DrawLib::round_rect(ci, 0, 0, lw, lh, 0, 0, 0, 0, 180);

    float cx      = lw / 2.0f;
    float cy      = lh / 2.0f;
    float total_w = std::min(600.0f, lw * 0.90f);
    float total_h = std::min(280.0f, lh * 0.82f);
    float start_x = cx - total_w / 2.0f;
    float start_y = cy - total_h / 2.0f;

    // --- Left panel (game info) ---
    float left_w  = total_w * 0.55f;
    float left_x  = start_x;
    DrawLib::round_rect(ci, left_x, start_y, left_w, total_h, 8, 12, 8, 28, 240);
    DrawLib::neon_stroke(ci, left_x, start_y, left_w, total_h, 8, 0, 255, 255, 200, 2.0f);

    float left_cx = left_x + left_w / 2.0f;

    if (font.is_valid()) {
        // Title: "666，居然还有第六关？"
        draw_text(ci, font, V2(left_cx, start_y + 42),
                  Str::utf8("666\xef\xbc\x8c\xe5\xb1\x85\xe7\x84\xb6\xe8\xbf\x98\xe6\x9c\x89\xe7\xac\xac\xe5\x85\xad\xe5\x85\xb3\xef\xbc\x9f"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 28, rgba(0, 255, 255, 255));

        // Subtitle
        draw_text(ci, font, V2(left_cx, start_y + 68),
                  Str("since 1983"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 13, rgba(255, 50, 200, 200));

        // Controls hints
        float hint_y = start_y + total_h * 0.42f;
        // "上/下 移动酒保"
        draw_text(ci, font, V2(left_cx, hint_y + 4),
                  Str::utf8("\xe4\xb8\x8a/\xe4\xb8\x8b \xe7\xa7\xbb\xe5\x8a\xa8\xe9\x85\x92\xe4\xbf\x9d"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 11, rgba(180, 180, 220, 200));
        // "1-6 发送饮料 | 触屏：点击右侧按钮"
        draw_text(ci, font, V2(left_cx, hint_y + 22),
                  Str::utf8("1-6 \xe5\x8f\x91\xe9\x80\x81\xe9\xa5\xae\xe6\x96\x99 | \xe8\xa7\xa6\xe5\xb1\x8f\xef\xbc\x9a\xe7\x82\xb9\xe5\x87\xbb\xe5\x8f\xb3\xe4\xbe\xa7\xe6\x8c\x89\xe9\x92\xae"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 11, rgba(180, 180, 220, 200));
        // "触屏：拖动左侧轨道移动"
        draw_text(ci, font, V2(left_cx, hint_y + 40),
                  Str::utf8("\xe8\xa7\xa6\xe5\xb1\x8f\xef\xbc\x9a\xe6\x8b\x96\xe5\x8a\xa8\xe5\xb7\xa6\xe4\xbe\xa7\xe8\xbd\xa8\xe9\x81\x93\xe7\xa7\xbb\xe5\x8a\xa8"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 11, rgba(180, 180, 220, 200));

        // Blinking "点击开始"
        float blink = sinf(G.time * 4.0f) * 0.5f + 0.5f;
        draw_text(ci, font, V2(left_cx, start_y + total_h - 44),
                  Str::utf8("\xe7\x82\xb9\xe5\x87\xbb\xe5\xbc\x80\xe5\xa7\x8b"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 18,
                  rgba(0, 255, 255, std::floor(100 + blink * 155)));

        // High score
        if (G.high_score > 0) {
            // "最高分: N"
            Str hs_str = Str::utf8("\xe6\x9c\x80\xe9\xab\x98\xe5\x88\x86: ")
                         + Str::num_int64(G.high_score);
            draw_text(ci, font, V2(left_cx, start_y + total_h - 22),
                      hs_str, godot::HORIZONTAL_ALIGNMENT_CENTER, 12,
                      rgba(255, 50, 200, 200));
        }
    }

    // --- Right panel (leaderboard) ---
    float gap     = 8.0f;
    float right_w = total_w - left_w - gap;
    float right_x = left_x + left_w + gap;
    DrawLib::round_rect(ci, right_x, start_y, right_w, total_h, 8, 12, 8, 28, 240);
    DrawLib::neon_stroke(ci, right_x, start_y, right_w, total_h, 8,
                         255, 200, 40, 150, 1.5f);

    draw_leaderboard(ci, G, font, right_x, start_y, right_w, total_h);
}

// ========================================================================
// 12b. Game over overlay
// ========================================================================
void GameRenderer::draw_game_over(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    float lw = G.logical_w;
    float lh = G.logical_h;

    // Full-screen dim
    DrawLib::round_rect(ci, 0, 0, lw, lh, 0, 0, 0, 0, 200);

    float cx_screen = lw / 2.0f;
    float cy_screen = lh / 2.0f;
    float total_w   = std::min(600.0f, lw * 0.90f);
    float total_h   = std::min(280.0f, lh * 0.82f);
    float start_x   = cx_screen - total_w / 2.0f;
    float start_y   = cy_screen - total_h / 2.0f;

    // Determine title text and color
    Str title_text;
    float title_r, title_g, title_b;

    if (G.game_win) {
        // "666，居然过了第六关！"
        title_text = Str::utf8("666\xef\xbc\x8c\xe5\xb1\x85\xe7\x84\xb6\xe8\xbf\x87\xe4\xba\x86\xe7\xac\xac\xe5\x85\xad\xe5\x85\xb3\xef\xbc\x81");
        title_r = 0; title_g = 255; title_b = 200;
    } else if (G.level >= MAX_LEVEL) {
        // "666，居然没过第六关。"
        title_text = Str::utf8("666\xef\xbc\x8c\xe5\xb1\x85\xe7\x84\xb6\xe6\xb2\xa1\xe8\xbf\x87\xe7\xac\xac\xe5\x85\xad\xe5\x85\xb3\xe3\x80\x82");
        title_r = 255; title_g = 200; title_b = 50;
    } else {
        // "666，居然都没到第六关？"
        title_text = Str::utf8("666\xef\xbc\x8c\xe5\xb1\x85\xe7\x84\xb6\xe9\x83\xbd\xe6\xb2\xa1\xe5\x88\xb0\xe7\xac\xac\xe5\x85\xad\xe5\x85\xb3\xef\xbc\x9f");
        title_r = 255; title_g = 50; title_b = 80;
    }

    // --- Left panel ---
    float left_w = total_w * 0.55f;
    float left_x = start_x;
    DrawLib::round_rect(ci, left_x, start_y, left_w, total_h, 8, 15, 8, 20, 240);
    DrawLib::neon_stroke(ci, left_x, start_y, left_w, total_h, 8,
                         title_r, title_g, title_b, 200, 2.0f);

    float left_cx = left_x + left_w / 2.0f;

    if (font.is_valid()) {
        // Title
        draw_text(ci, font, V2(left_cx, start_y + 42),
                  title_text, godot::HORIZONTAL_ALIGNMENT_CENTER, 20,
                  rgba(title_r, title_g, title_b, 255));

        // Score: "得分: N"
        Str score_str = Str::utf8("\xe5\xbe\x97\xe5\x88\x86: ") + Str::num_int64(G.score);
        draw_text(ci, font, V2(left_cx, start_y + 82),
                  score_str, godot::HORIZONTAL_ALIGNMENT_CENTER, 20,
                  rgba(255, 255, 255, 255));

        // New record or high score
        if (G.score >= G.high_score && G.score > 0) {
            // "** 新纪录！ **"
            draw_text(ci, font, V2(left_cx, start_y + 110),
                      Str::utf8("** \xe6\x96\xb0\xe7\xba\xaa\xe5\xbd\x95\xef\xbc\x81 **"),
                      godot::HORIZONTAL_ALIGNMENT_CENTER, 14,
                      rgba(0, 255, 255, 255));
        } else {
            // "最高分: N"
            Str hs = Str::utf8("\xe6\x9c\x80\xe9\xab\x98\xe5\x88\x86: ")
                     + Str::num_int64(G.high_score);
            draw_text(ci, font, V2(left_cx, start_y + 110),
                      hs, godot::HORIZONTAL_ALIGNMENT_CENTER, 14,
                      rgba(180, 180, 220, 200));
        }

        // Stats line: "关卡:N 已服务:N 最佳连击:N"
        Str stats = Str::utf8("\xe5\x85\xb3\xe5\x8d\xa1:") + Str::num_int64(G.level)
                    + Str::utf8(" \xe5\xb7\xb2\xe6\x9c\x8d\xe5\x8a\xa1:") + Str::num_int64(G.total_served)
                    + Str::utf8(" \xe6\x9c\x80\xe4\xbd\xb3\xe8\xbf\x9e\xe5\x87\xbb:") + Str::num_int64(G.best_combo);
        draw_text(ci, font, V2(left_cx, start_y + 140),
                  stats, godot::HORIZONTAL_ALIGNMENT_CENTER, 11,
                  rgba(120, 100, 180, 200));

        // Global rank
        if (G.my_rank > 0) {
            // "全球排名: #N / M人"
            Str rank_info = Str::utf8("\xe5\x85\xa8\xe7\x90\x83\xe6\x8e\x92\xe5\x90\x8d: #")
                            + Str::num_int64(G.my_rank);
            if (G.leaderboard_total > 0) {
                rank_info = rank_info + Str(" / ") + Str::num_int64(G.leaderboard_total)
                            + Str::utf8("\xe4\xba\xba");
            }
            draw_text(ci, font, V2(left_cx, start_y + 166),
                      rank_info, godot::HORIZONTAL_ALIGNMENT_CENTER, 12,
                      rgba(0, 255, 255, 200));
        }

        // Blinking "再来一局？"
        float blink = sinf(G.time * 4.0f) * 0.5f + 0.5f;
        draw_text(ci, font, V2(left_cx, start_y + total_h - 30),
                  Str::utf8("\xe5\x86\x8d\xe6\x9d\xa5\xe4\xb8\x80\xe5\xb1\x80\xef\xbc\x9f"),
                  godot::HORIZONTAL_ALIGNMENT_CENTER, 16,
                  rgba(0, 255, 255, std::floor(100 + blink * 155)));
    }

    // --- Right panel (leaderboard) ---
    float gap     = 8.0f;
    float right_w = total_w - left_w - gap;
    float right_x = left_x + left_w + gap;
    DrawLib::round_rect(ci, right_x, start_y, right_w, total_h, 8, 12, 8, 28, 240);
    DrawLib::neon_stroke(ci, right_x, start_y, right_w, total_h, 8,
                         255, 200, 40, 150, 1.5f);

    draw_leaderboard(ci, G, font, right_x, start_y, right_w, total_h);
}

// ========================================================================
// Main render entry point
// ========================================================================
void GameRenderer::render(CI* ci, GameState& G, const godot::Ref<Font>& font) {
    // Screen shake offset
    float shake_x = 0.0f, shake_y = 0.0f;
    if (G.shake_timer > 0.0f) {
        shake_x = ((float)(rand() % 1000) / 1000.0f - 0.5f) * G.shake_intensity * 2.0f;
        shake_y = ((float)(rand() % 1000) / 1000.0f - 0.5f) * G.shake_intensity * 2.0f;

        godot::Transform2D shake_xform;
        shake_xform = shake_xform.translated(V2(shake_x, shake_y));
        ci->draw_set_transform_matrix(shake_xform);
    }

    // Draw all layers in order
    draw_background(ci, G, font);      // 1
    draw_lanes_back(ci, G);            // 2
    draw_drinks(ci, G);                // 3
    draw_empty_bottles(ci, G);         // 4
    draw_customers(ci, G, font);       // 5
    draw_lanes_front(ci, G, font);     // 6
    draw_bartender(ci, G);             // 7
    draw_particles(ci, G);             // 8
    draw_float_texts(ci, G, font);     // 9
    draw_hud(ci, G, font);            // 10
    draw_drink_buttons(ci, G, font);   // 11

    // Overlays
    if (G.game_state == GameStateEnum::Menu) {
        draw_menu(ci, G, font);        // 12a
    } else if (G.game_state == GameStateEnum::GameOver) {
        draw_game_over(ci, G, font);   // 12b
    }

    // Reset shake transform
    if (G.shake_timer > 0.0f) {
        ci->draw_set_transform_matrix(godot::Transform2D());
    }
}

} // namespace cyber_tapper
