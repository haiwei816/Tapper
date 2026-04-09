// ============================================================================
// draw_lib.h - NanoVG 绘图 → Godot CanvasItem 绘图工具
// (对应 Lua: CyberTapper/DrawLib.lua)
//
// Godot 的 _draw() API 映射：
//   nvgRect/Fill       → draw_rect()
//   nvgCircle          → draw_circle()
//   nvgLine            → draw_line()
//   nvgText            → draw_string()
//   nvgRoundedRect     → draw_rounded_rect() (自定义)
//   nvgLinearGradient   → draw_gradient_rect() (自定义)
// ============================================================================
#ifndef CYBER_TAPPER_DRAW_LIB_H
#define CYBER_TAPPER_DRAW_LIB_H

#include "config.h"
#include <godot_cpp/classes/canvas_item.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <cmath>
#include <algorithm>

namespace cyber_tapper {

class DrawLib {
public:
    // ----------------------------------------------------------------
    // 圆角矩形填充
    // ----------------------------------------------------------------
    static void round_rect(godot::CanvasItem* ci, float x, float y, float w, float h,
                           float rad, float cr, float cg, float cb, float ca = 255.0f) {
        // Godot 没有内置圆角矩形，用多边形近似
        godot::Color col = rgba(cr, cg, cb, ca);
        if (rad <= 0.5f) {
            ci->draw_rect(godot::Rect2(x, y, w, h), col);
            return;
        }
        rad = std::min(rad, std::min(w, h) / 2.0f);
        godot::PackedVector2Array pts;
        const int segs = 6;
        auto add_corner = [&](float cx, float cy, float start_angle) {
            for (int i = 0; i <= segs; i++) {
                float a = start_angle + (float)i / segs * (float)Math_PI * 0.5f;
                pts.push_back(godot::Vector2(cx + cosf(a) * rad, cy + sinf(a) * rad));
            }
        };
        add_corner(x + w - rad, y + rad, -Math_PI * 0.5f);   // 右上
        add_corner(x + w - rad, y + h - rad, 0.0f);            // 右下
        add_corner(x + rad, y + h - rad, Math_PI * 0.5f);      // 左下
        add_corner(x + rad, y + rad, Math_PI);                  // 左上
        ci->draw_colored_polygon(pts, col);
    }

    // ----------------------------------------------------------------
    // 圆角矩形描边
    // ----------------------------------------------------------------
    static void round_rect_stroke(godot::CanvasItem* ci, float x, float y, float w, float h,
                                  float rad, float cr, float cg, float cb, float ca = 200.0f,
                                  float line_w = 1.5f) {
        godot::Color col = rgba(cr, cg, cb, ca);
        if (rad <= 0.5f) {
            ci->draw_rect(godot::Rect2(x, y, w, h), col, false, line_w);
            return;
        }
        rad = std::min(rad, std::min(w, h) / 2.0f);
        godot::PackedVector2Array pts;
        const int segs = 6;
        auto add_corner = [&](float cx, float cy, float start_angle) {
            for (int i = 0; i <= segs; i++) {
                float a = start_angle + (float)i / segs * (float)Math_PI * 0.5f;
                pts.push_back(godot::Vector2(cx + cosf(a) * rad, cy + sinf(a) * rad));
            }
        };
        add_corner(x + w - rad, y + rad, -Math_PI * 0.5f);
        add_corner(x + w - rad, y + h - rad, 0.0f);
        add_corner(x + rad, y + h - rad, Math_PI * 0.5f);
        add_corner(x + rad, y + rad, Math_PI);
        pts.push_back(pts[0]); // 闭合
        ci->draw_polyline(pts, col, line_w);
    }

    // ----------------------------------------------------------------
    // 霓虹发光描边（双层：外层模糊 + 内层亮）
    // ----------------------------------------------------------------
    static void neon_stroke(godot::CanvasItem* ci, float x, float y, float w, float h,
                            float rad, float cr, float cg, float cb, float ca = 200.0f,
                            float lw = 2.0f) {
        // 外层发光
        round_rect_stroke(ci, x - 2, y - 2, w + 4, h + 4, rad + 1,
                          cr, cg, cb, ca * 0.3f, lw + 3);
        // 内层亮
        round_rect_stroke(ci, x, y, w, h, rad, cr, cg, cb, ca, lw);
    }

    // ----------------------------------------------------------------
    // 垂直渐变矩形
    // ----------------------------------------------------------------
    static void gradient_rect(godot::CanvasItem* ci, float x, float y, float w, float h,
                              float r1, float g1, float b1, float a1,
                              float r2, float g2, float b2, float a2,
                              float rad = 0) {
        // 用顶点颜色插值模拟垂直渐变
        godot::PackedVector2Array pts;
        godot::PackedColorArray cols;
        godot::Color top = rgba(r1, g1, b1, a1);
        godot::Color bot = rgba(r2, g2, b2, a2);

        if (rad <= 0.5f) {
            pts.push_back(godot::Vector2(x, y));
            pts.push_back(godot::Vector2(x + w, y));
            pts.push_back(godot::Vector2(x + w, y + h));
            pts.push_back(godot::Vector2(x, y + h));
            cols.push_back(top);
            cols.push_back(top);
            cols.push_back(bot);
            cols.push_back(bot);
        } else {
            // 简化：渐变圆角矩形用中间色填充
            godot::Color mid(
                (top.r + bot.r) * 0.5f,
                (top.g + bot.g) * 0.5f,
                (top.b + bot.b) * 0.5f,
                (top.a + bot.a) * 0.5f
            );
            round_rect(ci, x, y, w, h, rad,
                        mid.r * 255, mid.g * 255, mid.b * 255, mid.a * 255);
            return;
        }
        ci->draw_polygon(pts, cols);
    }

    // ----------------------------------------------------------------
    // 圆形
    // ----------------------------------------------------------------
    static void draw_circle(godot::CanvasItem* ci, float cx, float cy, float r,
                            float cr, float cg, float cb, float ca = 255.0f) {
        ci->draw_circle(godot::Vector2(cx, cy), r, rgba(cr, cg, cb, ca));
    }

    // ----------------------------------------------------------------
    // 赛博朋克人物
    // ----------------------------------------------------------------
    static void draw_cyber_char(godot::CanvasItem* ci, float cx, float cy, float scale,
                                float body_r, float body_g, float body_b, float alpha = 255.0f) {
        float s = scale;
        // 头部
        draw_circle(ci, cx, cy - s * 5, s * 2, 210, 180, 150, alpha);
        // 帽子
        round_rect(ci, cx - s * 2.2f, cy - s * 7.2f, s * 4.4f, s * 2.5f, s * 0.8f, 40, 30, 60, alpha);
        // 面罩
        round_rect(ci, cx - s * 1.8f, cy - s * 5.5f, s * 3.6f, s * 1.2f, s * 0.4f, 20, 20, 30, alpha);
        // 眼睛
        round_rect(ci, cx - s * 1.5f, cy - s * 5.3f, s * 1.2f, s * 0.6f, s * 0.2f,
                   body_r, body_g, body_b, alpha * 0.6f);
        round_rect(ci, cx + s * 0.3f, cy - s * 5.3f, s * 1.2f, s * 0.6f, s * 0.2f,
                   body_r, body_g, body_b, alpha * 0.6f);
        // 身体
        round_rect(ci, cx - s * 2.2f, cy - s * 3, s * 4.4f, s * 4.5f, s * 0.6f,
                   body_r, body_g, body_b, alpha);
        // V 领
        godot::Color vest_col = rgba(20, 15, 30, alpha);
        ci->draw_line(godot::Vector2(cx - s * 0.8f, cy - s * 3),
                      godot::Vector2(cx, cy - s * 1.5f), vest_col, 1.5f);
        ci->draw_line(godot::Vector2(cx, cy - s * 1.5f),
                      godot::Vector2(cx + s * 0.8f, cy - s * 3), vest_col, 1.5f);
        // 手臂
        round_rect(ci, cx - s * 3.2f, cy - s * 2.5f, s * 1.2f, s * 3.5f, s * 0.5f,
                   body_r, body_g, body_b, alpha);
        round_rect(ci, cx + s * 2, cy - s * 2.5f, s * 1.2f, s * 3.5f, s * 0.5f,
                   body_r, body_g, body_b, alpha);
        // 腿
        float leg_r = std::max(0.0f, body_r * 0.4f);
        float leg_g = std::max(0.0f, body_g * 0.4f);
        float leg_b = std::max(0.0f, body_b * 0.4f);
        round_rect(ci, cx - s * 1.6f, cy + s * 1.5f, s * 1.4f, s * 3, s * 0.4f, leg_r, leg_g, leg_b, alpha);
        round_rect(ci, cx + s * 0.2f, cy + s * 1.5f, s * 1.4f, s * 3, s * 0.4f, leg_r, leg_g, leg_b, alpha);
        // 鞋子
        round_rect(ci, cx - s * 2, cy + s * 4.2f, s * 1.8f, s * 0.9f, s * 0.3f, 30, 25, 40, alpha);
        round_rect(ci, cx + s * 0.2f, cy + s * 4.2f, s * 1.8f, s * 0.9f, s * 0.3f, 30, 25, 40, alpha);
        // 轮廓
        round_rect_stroke(ci, cx - s * 2.2f, cy - s * 3, s * 4.4f, s * 4.5f, s * 0.6f,
                          body_r, body_g, body_b, alpha * 0.4f, 1.0f);
    }

    // ----------------------------------------------------------------
    // 赛博酒保
    // ----------------------------------------------------------------
    static void draw_cyber_bartender(godot::CanvasItem* ci, float cx, float cy, float scale,
                                     bool facing_left, float serve_anim, float alpha = 255.0f) {
        float s = scale;
        // 头部
        draw_circle(ci, cx, cy - s * 5, s * 2.2f, 210, 180, 150, alpha);
        // 帽子 + 霓虹边
        round_rect(ci, cx - s * 2.5f, cy - s * 7.5f, s * 5, s * 2.2f, s * 0.8f, 30, 20, 50, alpha);
        round_rect_stroke(ci, cx - s * 2.5f, cy - s * 7.5f, s * 5, s * 2.2f, s * 0.8f,
                          0, 255, 255, alpha * 0.7f, 1.5f);
        // 眼睛
        draw_circle(ci, cx - s * 0.8f, cy - s * 5, s * 0.5f, 50, 50, 60, alpha);
        draw_circle(ci, cx + s * 0.8f, cy - s * 5, s * 0.5f, 50, 50, 60, alpha);
        draw_circle(ci, cx - s * 0.8f, cy - s * 5, s * 0.25f, 0, 255, 255, alpha);
        draw_circle(ci, cx + s * 0.8f, cy - s * 5, s * 0.25f, 0, 255, 255, alpha);
        // 嘴 (用弧线，Godot draw_arc)
        ci->draw_arc(godot::Vector2(cx, cy - s * 3.8f), s * 0.8f, 0.2f,
                     (float)Math_PI - 0.2f, 12, rgba(180, 130, 110, alpha), 1.2f);
        // 上身
        round_rect(ci, cx - s * 2.5f, cy - s * 3, s * 5, s * 5, s * 0.6f, 220, 220, 240, alpha);
        round_rect(ci, cx - s * 1.8f, cy - s * 1.5f, s * 3.6f, s * 3, s * 0.4f, 200, 200, 220, alpha);
        round_rect(ci, cx - s * 0.6f, cy - s * 3, s * 1.2f, s * 0.8f, s * 0.3f, 255, 50, 200, alpha);
        // 手臂
        float arm_extend = serve_anim * s * 3;
        if (facing_left) {
            round_rect(ci, cx - s * 3.5f - arm_extend, cy - s * 2, s * 1.3f + arm_extend, s * 2.5f,
                       s * 0.5f, 220, 220, 240, alpha);
            draw_circle(ci, cx - s * 3.5f - arm_extend, cy - s * 0.5f, s * 0.7f, 210, 180, 150, alpha);
            round_rect(ci, cx + s * 2.2f, cy - s * 2, s * 1.3f, s * 2.5f, s * 0.5f, 220, 220, 240, alpha);
        } else {
            round_rect(ci, cx + s * 2.2f, cy - s * 2, s * 1.3f + arm_extend, s * 2.5f,
                       s * 0.5f, 220, 220, 240, alpha);
            draw_circle(ci, cx + s * 3.5f + arm_extend, cy - s * 0.5f, s * 0.7f, 210, 180, 150, alpha);
            round_rect(ci, cx - s * 3.5f, cy - s * 2, s * 1.3f, s * 2.5f, s * 0.5f, 220, 220, 240, alpha);
        }
        // 裤子
        round_rect(ci, cx - s * 2, cy + s * 2, s * 1.8f, s * 3, s * 0.4f, 30, 40, 120, alpha);
        round_rect(ci, cx + s * 0.2f, cy + s * 2, s * 1.8f, s * 3, s * 0.4f, 30, 40, 120, alpha);
        // 鞋子
        round_rect(ci, cx - s * 2.5f, cy + s * 4.8f, s * 2.2f, s * 1, s * 0.4f, 20, 15, 35, alpha);
        round_rect(ci, cx + s * 0.3f, cy + s * 4.8f, s * 2.2f, s * 1, s * 0.4f, 20, 15, 35, alpha);
        // 上身霓虹轮廓
        round_rect_stroke(ci, cx - s * 2.5f, cy - s * 3, s * 5, s * 5, s * 0.6f,
                          0, 255, 255, alpha * 0.25f, 1.0f);
    }

    // ----------------------------------------------------------------
    // 赛博风格鸡尾酒杯
    // ----------------------------------------------------------------
    static void draw_cyber_drink(godot::CanvasItem* ci, float x, float y, float scale,
                                 float dr, float dg, float db, bool full) {
        float s = scale;
        // 杯体
        round_rect(ci, x - s * 2, y - s * 3, s * 4, s * 5, s * 0.6f, 80, 80, 120, 120);
        if (full) {
            round_rect(ci, x - s * 1.5f, y - s * 1.5f, s * 3, s * 3, s * 0.4f, dr, dg, db, 200);
            round_rect(ci, x - s * 1.5f, y - s * 2.2f, s * 3, s * 1, s * 0.4f, 255, 255, 255, 100);
        } else {
            round_rect(ci, x - s * 1.5f, y - s * 0.5f, s * 3, s * 2, s * 0.3f, 60, 60, 80, 60);
        }
        // 把手
        round_rect_stroke(ci, x + s * 2, y - s * 1.5f, s * 1.2f, s * 3, s * 0.3f,
                          120, 120, 160, 180, 1.5f);
        // 杯体轮廓
        round_rect_stroke(ci, x - s * 2, y - s * 3, s * 4, s * 5, s * 0.6f, dr, dg, db, 100, 1.0f);
    }

    // ----------------------------------------------------------------
    // 通用霓虹滑块
    // ----------------------------------------------------------------
    static void draw_neon_slider(godot::CanvasItem* ci, const godot::Ref<godot::Font>& font,
                                 float sx, float sy, float sw, float sh, float value,
                                 const char* label, bool align_right,
                                 float cr1, float cg1, float cb1,
                                 float cr2, float cg2, float cb2) {
        float knob_r = 5.0f;
        // 标签
        if (font.is_valid()) {
            godot::Color label_col = rgba(100, 80, 180, 150);
            float label_x = align_right ? sx + sw : sx;
            godot::String label_str(label);
            if (align_right) {
                godot::Vector2 sz = font->get_string_size(label_str, godot::HORIZONTAL_ALIGNMENT_LEFT, -1, 9);
                label_x -= sz.x;
            }
            ci->draw_string(font, godot::Vector2(label_x, sy - 3), label_str,
                            godot::HORIZONTAL_ALIGNMENT_LEFT, -1, 9, label_col);
        }
        // 轨道
        round_rect(ci, sx, sy, sw, sh, sh / 2, 25, 18, 45, 180);
        // 填充
        float fill_w = sw * value;
        if (fill_w > 1.0f) {
            // 简化渐变为左右两色混合
            godot::Color left = rgba(cr1, cg1, cb1, 180);
            godot::Color right = rgba(cr2, cg2, cb2, 180);
            godot::Color mid((left.r + right.r) * 0.5f, (left.g + right.g) * 0.5f,
                             (left.b + right.b) * 0.5f, left.a);
            round_rect(ci, sx, sy, fill_w, sh, sh / 2, mid.r * 255, mid.g * 255, mid.b * 255, 180);
        }
        // 轨道描边
        round_rect_stroke(ci, sx, sy, sw, sh, sh / 2, 80, 60, 160, 100, 1.0f);
        // 旋钮
        float knob_x = sx + fill_w;
        float knob_y = sy + sh / 2;
        draw_circle(ci, knob_x, knob_y, knob_r + 2, cr1, cg1, cb1, 40);
        draw_circle(ci, knob_x, knob_y, knob_r, 20, 15, 35, 240);
        draw_circle(ci, knob_x, knob_y, knob_r - 2, cr1, cg1, cb1, 200);
    }

    // ----------------------------------------------------------------
    // HSV → RGB
    // ----------------------------------------------------------------
    static godot::Color hsv_to_rgb(float h, float s, float v) {
        h = fmodf(h, 360.0f);
        if (h < 0) h += 360.0f;
        float c = v * s;
        float x = c * (1.0f - fabsf(fmodf(h / 60.0f, 2.0f) - 1.0f));
        float m = v - c;
        float r, g, b;
        if (h < 60)       { r = c; g = x; b = 0; }
        else if (h < 120) { r = x; g = c; b = 0; }
        else if (h < 180) { r = 0; g = c; b = x; }
        else if (h < 240) { r = 0; g = x; b = c; }
        else if (h < 300) { r = x; g = 0; b = c; }
        else              { r = c; g = 0; b = x; }
        return godot::Color(r + m, g + m, b + m);
    }
};

} // namespace cyber_tapper

#endif // CYBER_TAPPER_DRAW_LIB_H
