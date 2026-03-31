-- ============================================================================
-- DrawLib.lua - 纯 NanoVG 绘图工具函数（无状态依赖）
-- ============================================================================

local Draw = {}

--- 圆角矩形填充
function Draw.RoundRect(ctx, x, y, w, h, r, cr, cg, cb, ca)
    ca = ca or 255
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillColor(ctx, nvgRGBA(cr, cg, cb, ca))
    nvgFill(ctx)
end

--- 霓虹发光描边
function Draw.NeonStroke(ctx, x, y, w, h, rad, cr, cg, cb, ca, lw)
    ca = ca or 200
    lw = lw or 2
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - 2, y - 2, w + 4, h + 4, rad + 1)
    nvgStrokeColor(ctx, nvgRGBA(cr, cg, cb, math.floor(ca * 0.3)))
    nvgStrokeWidth(ctx, lw + 3)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, rad)
    nvgStrokeColor(ctx, nvgRGBA(cr, cg, cb, ca))
    nvgStrokeWidth(ctx, lw)
    nvgStroke(ctx)
end

--- 垂直渐变矩形
function Draw.GradientRect(ctx, x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, rad)
    rad = rad or 0
    nvgBeginPath(ctx)
    if rad > 0 then
        nvgRoundedRect(ctx, x, y, w, h, rad)
    else
        nvgRect(ctx, x, y, w, h)
    end
    local paint = nvgLinearGradient(ctx, x, y, x, y + h,
        nvgRGBA(r1, g1, b1, a1), nvgRGBA(r2, g2, b2, a2))
    nvgFillPaint(ctx, paint)
    nvgFill(ctx)
end

--- 绘制圆形
function Draw.DrawCircle(ctx, cx, cy, r, cr, cg, cb, ca)
    ca = ca or 255
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(cr, cg, cb, ca))
    nvgFill(ctx)
end

--- 赛博朋克人物
function Draw.DrawCyberChar(ctx, cx, cy, scale, bodyR, bodyG, bodyB, alpha)
    alpha = alpha or 255
    local s = scale
    local RR = Draw.RoundRect
    local DC = Draw.DrawCircle

    DC(ctx, cx, cy - s * 5, s * 2, 210, 180, 150, alpha)
    RR(ctx, cx - s * 2.2, cy - s * 7.2, s * 4.4, s * 2.5, s * 0.8, 40, 30, 60, alpha)
    RR(ctx, cx - s * 1.8, cy - s * 5.5, s * 3.6, s * 1.2, s * 0.4, 20, 20, 30, alpha)
    RR(ctx, cx - s * 1.5, cy - s * 5.3, s * 1.2, s * 0.6, s * 0.2, bodyR, bodyG, bodyB, math.floor(alpha * 0.6))
    RR(ctx, cx + s * 0.3, cy - s * 5.3, s * 1.2, s * 0.6, s * 0.2, bodyR, bodyG, bodyB, math.floor(alpha * 0.6))

    RR(ctx, cx - s * 2.2, cy - s * 3, s * 4.4, s * 4.5, s * 0.6, bodyR, bodyG, bodyB, alpha)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - s * 0.8, cy - s * 3)
    nvgLineTo(ctx, cx, cy - s * 1.5)
    nvgLineTo(ctx, cx + s * 0.8, cy - s * 3)
    nvgStrokeColor(ctx, nvgRGBA(20, 15, 30, alpha))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    RR(ctx, cx - s * 3.2, cy - s * 2.5, s * 1.2, s * 3.5, s * 0.5, bodyR, bodyG, bodyB, alpha)
    RR(ctx, cx + s * 2, cy - s * 2.5, s * 1.2, s * 3.5, s * 0.5, bodyR, bodyG, bodyB, alpha)

    local legR = math.max(0, math.floor(bodyR * 0.4))
    local legG = math.max(0, math.floor(bodyG * 0.4))
    local legB = math.max(0, math.floor(bodyB * 0.4))
    RR(ctx, cx - s * 1.6, cy + s * 1.5, s * 1.4, s * 3, s * 0.4, legR, legG, legB, alpha)
    RR(ctx, cx + s * 0.2, cy + s * 1.5, s * 1.4, s * 3, s * 0.4, legR, legG, legB, alpha)

    RR(ctx, cx - s * 2, cy + s * 4.2, s * 1.8, s * 0.9, s * 0.3, 30, 25, 40, alpha)
    RR(ctx, cx + s * 0.2, cy + s * 4.2, s * 1.8, s * 0.9, s * 0.3, 30, 25, 40, alpha)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - s * 2.2, cy - s * 3, s * 4.4, s * 4.5, s * 0.6)
    nvgStrokeColor(ctx, nvgRGBA(bodyR, bodyG, bodyB, math.floor(alpha * 0.4)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

--- 赛博酒保
function Draw.DrawCyberBartender(ctx, cx, cy, scale, facingLeft, serveAnim, alpha)
    alpha = alpha or 255
    local s = scale
    local RR = Draw.RoundRect
    local DC = Draw.DrawCircle

    DC(ctx, cx, cy - s * 5, s * 2.2, 210, 180, 150, alpha)
    RR(ctx, cx - s * 2.5, cy - s * 7.5, s * 5, s * 2.2, s * 0.8, 30, 20, 50, alpha)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - s * 2.5, cy - s * 7.5, s * 5, s * 2.2, s * 0.8)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, math.floor(alpha * 0.7)))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    DC(ctx, cx - s * 0.8, cy - s * 5, s * 0.5, 50, 50, 60, alpha)
    DC(ctx, cx + s * 0.8, cy - s * 5, s * 0.5, 50, 50, 60, alpha)
    DC(ctx, cx - s * 0.8, cy - s * 5, s * 0.25, 0, 255, 255, alpha)
    DC(ctx, cx + s * 0.8, cy - s * 5, s * 0.25, 0, 255, 255, alpha)

    nvgBeginPath(ctx)
    nvgArc(ctx, cx, cy - s * 3.8, s * 0.8, 0.2, math.pi - 0.2, NVG_CW)
    nvgStrokeColor(ctx, nvgRGBA(180, 130, 110, alpha))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    RR(ctx, cx - s * 2.5, cy - s * 3, s * 5, s * 5, s * 0.6, 220, 220, 240, alpha)
    RR(ctx, cx - s * 1.8, cy - s * 1.5, s * 3.6, s * 3, s * 0.4, 200, 200, 220, alpha)
    RR(ctx, cx - s * 0.6, cy - s * 3, s * 1.2, s * 0.8, s * 0.3, 255, 50, 200, alpha)

    local armExtend = serveAnim * s * 3
    if facingLeft then
        RR(ctx, cx - s * 3.5 - armExtend, cy - s * 2, s * 1.3 + armExtend, s * 2.5, s * 0.5, 220, 220, 240, alpha)
        DC(ctx, cx - s * 3.5 - armExtend, cy - s * 0.5, s * 0.7, 210, 180, 150, alpha)
        RR(ctx, cx + s * 2.2, cy - s * 2, s * 1.3, s * 2.5, s * 0.5, 220, 220, 240, alpha)
    else
        RR(ctx, cx + s * 2.2, cy - s * 2, s * 1.3 + armExtend, s * 2.5, s * 0.5, 220, 220, 240, alpha)
        DC(ctx, cx + s * 3.5 + armExtend, cy - s * 0.5, s * 0.7, 210, 180, 150, alpha)
        RR(ctx, cx - s * 3.5, cy - s * 2, s * 1.3, s * 2.5, s * 0.5, 220, 220, 240, alpha)
    end

    RR(ctx, cx - s * 2, cy + s * 2, s * 1.8, s * 3, s * 0.4, 30, 40, 120, alpha)
    RR(ctx, cx + s * 0.2, cy + s * 2, s * 1.8, s * 3, s * 0.4, 30, 40, 120, alpha)

    RR(ctx, cx - s * 2.5, cy + s * 4.8, s * 2.2, s * 1, s * 0.4, 20, 15, 35, alpha)
    RR(ctx, cx + s * 0.3, cy + s * 4.8, s * 2.2, s * 1, s * 0.4, 20, 15, 35, alpha)

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - s * 2.5, cy - s * 3, s * 5, s * 5, s * 0.6)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, math.floor(alpha * 0.25)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

--- 赛博风格鸡尾酒杯
function Draw.DrawCyberDrink(ctx, x, y, scale, drinkR, drinkG, drinkB, full)
    local s = scale
    local RR = Draw.RoundRect

    RR(ctx, x - s * 2, y - s * 3, s * 4, s * 5, s * 0.6, 80, 80, 120, 120)
    if full then
        RR(ctx, x - s * 1.5, y - s * 1.5, s * 3, s * 3, s * 0.4, drinkR, drinkG, drinkB, 200)
        RR(ctx, x - s * 1.5, y - s * 2.2, s * 3, s * 1, s * 0.4, 255, 255, 255, 100)
    else
        RR(ctx, x - s * 1.5, y - s * 0.5, s * 3, s * 2, s * 0.3, 60, 60, 80, 60)
    end
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + s * 2, y - s * 1.5, s * 1.2, s * 3, s * 0.3)
    nvgStrokeColor(ctx, nvgRGBA(120, 120, 160, 180))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - s * 2, y - s * 3, s * 4, s * 5, s * 0.6)
    nvgStrokeColor(ctx, nvgRGBA(drinkR, drinkG, drinkB, 100))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

--- 通用霓虹滑块
function Draw.DrawNeonSlider(ctx, sx, sy, sw, sh, value, label, labelAlign,
                              cr1, cg1, cb1, cr2, cg2, cb2)
    local knobR = 5
    local RR = Draw.RoundRect
    local DC = Draw.DrawCircle

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 9)
    nvgTextAlign(ctx, labelAlign + NVG_ALIGN_BOTTOM)
    nvgFillColor(ctx, nvgRGBA(100, 80, 180, 150))
    local labelX = sx
    if labelAlign == NVG_ALIGN_RIGHT then labelX = sx + sw end
    nvgText(ctx, labelX, sy - 3, label, nil)

    RR(ctx, sx, sy, sw, sh, sh / 2, 25, 18, 45, 180)

    local fillW = sw * value
    if fillW > 1 then
        nvgSave(ctx)
        nvgIntersectScissor(ctx, sx, sy, fillW, sh)
        local paint = nvgLinearGradient(ctx, sx, sy, sx + sw, sy,
            nvgRGBA(cr1, cg1, cb1, 180), nvgRGBA(cr2, cg2, cb2, 180))
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sx, sy, sw, sh, sh / 2)
        nvgFillPaint(ctx, paint)
        nvgFill(ctx)
        nvgRestore(ctx)
    end

    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, sw, sh, sh / 2)
    nvgStrokeColor(ctx, nvgRGBA(80, 60, 160, 100))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    local knobX = sx + fillW
    local knobY = sy + sh / 2
    DC(ctx, knobX, knobY, knobR + 2, cr1, cg1, cb1, 40)
    DC(ctx, knobX, knobY, knobR, 20, 15, 35, 240)
    DC(ctx, knobX, knobY, knobR - 2, cr1, cg1, cb1, 200)
end

--- HSV 转 RGB
function Draw.HSVtoRGB(h, s, v)
    h = h % 360
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255)
end

return Draw
