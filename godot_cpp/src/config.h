// ============================================================================
// config.h - 游戏常量配置 (对应 Lua: CyberTapper/Config.lua)
// ============================================================================
#ifndef CYBER_TAPPER_CONFIG_H
#define CYBER_TAPPER_CONFIG_H

#include <godot_cpp/variant/color.hpp>
#include <array>
#include <string>

namespace cyber_tapper {

// --- 赛博朋克霓虹调色板 ---
namespace PAL {
    constexpr godot::Color bg1{10.0f/255, 8.0f/255, 24.0f/255};
    constexpr godot::Color bg2{18.0f/255, 14.0f/255, 38.0f/255};
    constexpr godot::Color neon_cyan{0, 1.0f, 1.0f};
    constexpr godot::Color neon_pink{1.0f, 50.0f/255, 200.0f/255};
    constexpr godot::Color neon_purple{180.0f/255, 80.0f/255, 1.0f};
    constexpr godot::Color neon_yellow{1.0f, 1.0f, 60.0f/255};
    constexpr godot::Color neon_green{50.0f/255, 1.0f, 120.0f/255};
    constexpr godot::Color neon_orange{1.0f, 160.0f/255, 40.0f/255};
    constexpr godot::Color bar_surface{35.0f/255, 25.0f/255, 60.0f/255};
    constexpr godot::Color bar_front{22.0f/255, 16.0f/255, 42.0f/255};
    constexpr godot::Color bar_edge{60.0f/255, 40.0f/255, 100.0f/255};
    constexpr godot::Color bar_glow{100.0f/255, 60.0f/255, 200.0f/255};
    constexpr godot::Color hud_yellow{1.0f, 1.0f, 60.0f/255};
    constexpr godot::Color hud_white{230.0f/255, 230.0f/255, 1.0f};
} // namespace PAL

// --- 游戏参数 ---
constexpr int NUM_LANES = 4;
constexpr float DRINK_SPEED = 220.0f;
constexpr float BOTTLE_RETURN_SPEED = 180.0f;
constexpr float CUSTOMER_WALK_SPEED = 120.0f;
constexpr float QUEUE_SPACING = 32.0f;
constexpr float BASE_SPAWN_INTERVAL = 2.8f;
constexpr float BASE_PATIENCE = 14.0f;
constexpr float BARTENDER_MOVE_TIME = 0.12f;
constexpr int MAX_LIVES = 3;
constexpr int SERVES_PER_LEVEL = 16;
constexpr int SERVES_LEVEL6 = 36;
constexpr int MAX_LEVEL = 6;

// --- 饮料类型 ---
struct DrinkType {
    const char* name;
    float r, g, b;  // 0-255 范围，与 Lua 保持一致，使用时转换
    const char* key;
    const char* icon;

    godot::Color color(float alpha = 1.0f) const {
        return godot::Color(r / 255.0f, g / 255.0f, b / 255.0f, alpha);
    }
};

constexpr std::array<DrinkType, 6> DRINK_TYPES = {{
    {"Neon Ale",    0,   255, 255, "1", "I"},
    {"Plasma",      255, 50,  200, "2", "II"},
    {"Dark Matter", 180, 80,  255, "3", "III"},
    {"Solar Flare", 255, 200, 40,  "4", "IV"},
    {"Acid Rain",   50,  255, 120, "5", "V"},
    {"Lava Flow",   255, 100, 30,  "6", "VI"},
}};

// --- 顾客颜色 ---
struct CustomerColor {
    float r, g, b;
    godot::Color color(float alpha = 1.0f) const {
        return godot::Color(r / 255.0f, g / 255.0f, b / 255.0f, alpha);
    }
};

constexpr std::array<CustomerColor, 8> CUSTOMER_COLORS = {{
    {0,   220, 255},
    {255, 60,  200},
    {180, 80,  255},
    {255, 200, 40},
    {50,  255, 120},
    {255, 100, 60},
    {100, 200, 255},
    {255, 150, 200},
}};

// --- 辅助：RGBA 构造 (0-255) ---
inline godot::Color rgba(float r, float g, float b, float a = 255.0f) {
    return godot::Color(r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f);
}

} // namespace cyber_tapper

#endif // CYBER_TAPPER_CONFIG_H
