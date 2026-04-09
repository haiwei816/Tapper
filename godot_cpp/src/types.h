// ============================================================================
// types.h - 游戏实体数据结构
// ============================================================================
#ifndef CYBER_TAPPER_TYPES_H
#define CYBER_TAPPER_TYPES_H

#include <vector>
#include <string>

namespace cyber_tapper {

// --- 游戏状态枚举 ---
enum class GameStateEnum {
    Menu,
    Playing,
    GameOver,
};

// --- 酒保 ---
struct Bartender {
    int lane = 2;
    int target_lane = 2;
    float y = 0.0f;
    float anim_time = 0.0f;
    float serve_anim = 0.0f;
    float left_drink_anim = 0.0f;
    int left_drink_type = -1; // -1 表示无
};

// --- 顾客 ---
struct Customer {
    int lane = 1;
    float x = 0.0f;
    float target_x = 0.0f;
    int drink_type = 1;
    int drinks_needed = 1;
    int drinks_received = 0;
    float wait_time = 0.0f;
    float body_r = 0, body_g = 220, body_b = 255;
    float bob_phase = 0.0f;
    bool alive = true;
    float served_anim = 0.0f;
    float angry_timer = 0.0f;
    bool wrong_hit_this_frame = false;

    // 饮酒动画
    float sip_anim = 0.0f;
    int sip_drink_type = -1;
    bool exit_after_sip = false;

    // Boss
    bool is_boss = false;
    std::vector<int> drink_sequence;
    int sequence_index = 1;
};

// --- 饮料(滑动中) ---
struct Drink {
    int lane = 1;
    float x = 0.0f;
    int drink_type = 1;
    float trail_timer = 0.0f;
};

// --- 空瓶 ---
struct EmptyBottle {
    int lane = 1;
    float x = 0.0f;
    int drink_type = 1;
    float trail_timer = 0.0f;
};

// --- 粒子 ---
struct Particle {
    float x = 0, y = 0;
    float vx = 0, vy = 0;
    float life = 0;
    float max_life = 0;
    float r = 255, g = 255, b = 255;
    float size = 3.0f;
};

// --- 浮动文字 ---
struct FloatText {
    std::string text;
    float x = 0, y = 0;
    float r = 255, g = 255, b = 255;
    float life = 0;
    float max_life = 1.2f;
};

// --- 拖拽状态 ---
struct DragState {
    bool active = false;
    int touch_id = -1;
};

// --- 布局参数 ---
struct Layout {
    float lane_y[4] = {};
    float lane_h = 0;
    float counter_left = 0, counter_right = 0, counter_w = 0;
    float bartender_x_right = 0, bartender_x_left = 0;
    float drink_btn_x = 0, drink_btn_w = 0, drink_btn_h = 0;
    float drink_btn_spacing = 3.0f;
    float drink_btn_start_y = 0;
    float move_track_x = 0, move_track_w = 0;
    float move_track_y = 0, move_track_h = 0;
    float customer_offset_y = 0;
    float safe_offset_x = 0, safe_w = 0;
    float vol_slider_x = 0, vol_slider_y = 0;
    float vol_slider_w = 0, vol_slider_h = 0;
    float master_slider_x = 0, master_slider_y = 0;
    float master_slider_w = 0, master_slider_h = 0;
};

// --- 排行榜条目 ---
struct LeaderboardEntry {
    int rank = 0;
    std::string user_id;
    std::string nickname;
    int score = 0;
    int best_level = 0;
    int best_combo = 0;
    bool is_me = false;
};

} // namespace cyber_tapper

#endif // CYBER_TAPPER_TYPES_H
