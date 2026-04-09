// ============================================================================
// game_state.h - 共享游戏状态 (对应 Lua: CyberTapper/State.lua)
// ============================================================================
#ifndef CYBER_TAPPER_GAME_STATE_H
#define CYBER_TAPPER_GAME_STATE_H

#include "config.h"
#include "types.h"
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <cmath>
#include <algorithm>
#include <vector>

namespace cyber_tapper {

struct GameState {
    // === 分辨率 ===
    float phys_w = 0, phys_h = 0;
    float dpr = 1.0f;
    float logical_w = 0, logical_h = 0;

    // === 字体 ===
    godot::Ref<godot::Font> font_normal;

    // === 游戏状态 ===
    GameStateEnum game_state = GameStateEnum::Menu;
    bool game_win = false;
    float time = 0.0f;
    int score = 0;
    int high_score = 0;
    int lives = MAX_LIVES;
    int level = 1;
    int total_served = 0;
    int combo = 0;
    int best_combo = 0;
    int level_served = 0;
    float shake_timer = 0.0f;
    float shake_intensity = 0.0f;
    float spawn_timer = 0.0f;

    // === 实体 ===
    Bartender bartender;
    std::vector<Customer> customers;
    std::vector<Drink> drinks;
    std::vector<EmptyBottle> empty_bottles;
    std::vector<Particle> particles;
    std::vector<FloatText> float_texts;

    // === 布局 ===
    Layout layout;

    // === 输入/拖拽 ===
    DragState move_drag;
    DragState volume_drag;
    DragState master_drag;

    // === 音频 ===
    float bgm_volume = 0.3f;
    float master_volume = 0.8f;

    // === 排行榜 ===
    std::vector<LeaderboardEntry> leaderboard;
    bool leaderboard_loading = false;
    bool leaderboard_loaded = false;
    int my_cloud_high_score = 0;
    int my_rank = -1; // -1 表示未知
    int leaderboard_total = 0;

    // ================================================================
    // 分辨率计算
    // ================================================================
    void recalc_resolution(float width, float height, float device_pixel_ratio) {
        phys_w = width;
        phys_h = height;
        dpr = device_pixel_ratio;
        logical_w = phys_w / dpr;
        logical_h = phys_h / dpr;
    }

    // ================================================================
    // 布局计算
    // ================================================================
    void recalc_layout() {
        float lw = logical_w;
        float lh = logical_h;

        float top_margin = lh * 0.14f;
        float bottom_margin = lh * 0.08f;
        float game_area_h = lh - top_margin - bottom_margin;
        float lane_spacing = game_area_h / NUM_LANES;

        layout.lane_h = lane_spacing * 0.50f;

        float max_aspect = 18.0f / 9.0f;
        float max_game_w = lh * max_aspect;
        float safe_w = std::min(lw, max_game_w);
        float safe_offset_x = (lw - safe_w) / 2.0f;

        layout.safe_offset_x = safe_offset_x;
        layout.safe_w = safe_w;

        float side_btn_w = std::max(44.0f, safe_w * 0.10f);

        layout.counter_left = safe_offset_x + side_btn_w + safe_w * 0.04f;
        layout.counter_right = safe_offset_x + safe_w - side_btn_w - safe_w * 0.04f;
        layout.counter_w = layout.counter_right - layout.counter_left;
        layout.bartender_x_right = layout.counter_right + safe_w * 0.02f;
        layout.bartender_x_left = layout.counter_left - safe_w * 0.02f;

        for (int i = 0; i < NUM_LANES; i++) {
            layout.lane_y[i] = top_margin + (i + 0.5f) * lane_spacing;
        }

        layout.drink_btn_w = side_btn_w;
        layout.drink_btn_h = std::min(lh * 0.08f, 42.0f);
        layout.drink_btn_spacing = 3.0f;
        layout.drink_btn_x = safe_offset_x + safe_w - side_btn_w - 4.0f;
        int unlocked = std::min((int)DRINK_TYPES.size(), level);
        float total_drink_h = unlocked * layout.drink_btn_h + (unlocked - 1) * layout.drink_btn_spacing;
        layout.drink_btn_start_y = top_margin + (game_area_h - total_drink_h) / 2.0f;

        layout.move_track_w = side_btn_w;
        layout.move_track_x = safe_offset_x + 4.0f;
        layout.move_track_y = top_margin + lane_spacing * 0.2f;
        layout.move_track_h = game_area_h - lane_spacing * 0.4f;

        layout.customer_offset_y = -layout.lane_h * 0.12f;

        layout.vol_slider_w = std::max(56.0f, safe_w * 0.09f);
        layout.vol_slider_h = 6.0f;
        layout.vol_slider_x = safe_offset_x + 10.0f;
        layout.vol_slider_y = 44.0f;

        layout.master_slider_w = layout.vol_slider_w;
        layout.master_slider_h = 6.0f;
        layout.master_slider_x = safe_offset_x + safe_w - layout.master_slider_w - 10.0f;
        layout.master_slider_y = 44.0f;
    }

    // ================================================================
    // 通道辅助
    // ================================================================
    // 注意：Lua 索引从1开始，C++ 从0开始。
    // lane 参数使用 0-based 索引。
    float get_lane_y(int lane) const {
        if (lane < 0) lane = 0;
        if (lane >= NUM_LANES) lane = NUM_LANES - 1;
        return layout.lane_y[lane];
    }

    int get_closest_lane_from_y(float y) const {
        int closest = 0;
        float min_dist = 1e9f;
        for (int i = 0; i < NUM_LANES; i++) {
            float dist = std::abs(y - layout.lane_y[i]);
            if (dist < min_dist) {
                min_dist = dist;
                closest = i;
            }
        }
        return closest;
    }
};

} // namespace cyber_tapper

#endif // CYBER_TAPPER_GAME_STATE_H
