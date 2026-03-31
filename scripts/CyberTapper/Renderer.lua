-- ============================================================================
-- Renderer.lua - NanoVG 渲染（场景、HUD、菜单、结算）
-- ============================================================================

local Config = require "CyberTapper.Config"
local G = require "CyberTapper.State"
local Draw = require "CyberTapper.DrawLib"
local Logic = require "CyberTapper.GameLogic"

local Renderer = {}

-- 局部快捷引用
local RoundRect     = Draw.RoundRect
local NeonStroke    = Draw.NeonStroke
local GradientRect  = Draw.GradientRect
local DrawCircle    = Draw.DrawCircle
local DrawCyberChar = Draw.DrawCyberChar
local DrawCyberBartender = Draw.DrawCyberBartender
local DrawCyberDrink     = Draw.DrawCyberDrink
local DrawNeonSlider     = Draw.DrawNeonSlider

-- ============================================================================
-- 背景
-- ============================================================================

local function DrawBackground(ctx)
    local logicalW, logicalH = G.logicalW, G.logicalH
    GradientRect(ctx, 0, 0, logicalW, logicalH, 12, 8, 28, 255, 6, 4, 18, 255)

    nvgStrokeWidth(ctx, 0.5)
    local gridSize = 30
    for gx = 0, logicalW, gridSize do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, gx, 0)
        nvgLineTo(ctx, gx, logicalH)
        nvgStrokeColor(ctx, nvgRGBA(60, 40, 120, 20))
        nvgStroke(ctx)
    end
    for gy = 0, logicalH, gridSize do
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, 0, gy)
        nvgLineTo(ctx, logicalW, gy)
        nvgStrokeColor(ctx, nvgRGBA(60, 40, 120, 20))
        nvgStroke(ctx)
    end

    local topH = logicalH * 0.08
    local sx = G.layout.safeOffsetX
    local sw = G.layout.safeW
    GradientRect(ctx, sx, 0, sw, topH, 20, 10, 50, 240, 10, 5, 30, 200)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, topH)
    nvgLineTo(ctx, sx + sw, topH)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 150))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, topH)
    nvgLineTo(ctx, sx + sw, topH)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 30))
    nvgStrokeWidth(ctx, 8)
    nvgStroke(ctx)

    for i = 1, Config.NUM_LANES do
        local y = G.GetLaneY(i)
        local halfH = G.layout.laneH * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx, y - halfH - 1)
        nvgLineTo(ctx, sx + sw, y - halfH - 1)
        nvgStrokeColor(ctx, nvgRGBA(80, 50, 150, 40))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
end

-- ============================================================================
-- 吧台后层 / 前层
-- ============================================================================

local function DrawLanes_Back(ctx)
    local layout = G.layout
    for i = 1, Config.NUM_LANES do
        local y = G.GetLaneY(i)
        local h = layout.laneH
        local left = layout.counterLeft
        local right = layout.counterRight
        local w = right - left
        local topY = y - h * 0.5
        local surfaceH = h * 0.45

        GradientRect(ctx, left, topY, w, surfaceH, 45, 30, 75, 255, 35, 22, 60, 255, 3)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, topY + 1)
        nvgLineTo(ctx, right, topY + 1)
        nvgStrokeColor(ctx, nvgRGBA(120, 80, 200, 80))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        local railY = topY + surfaceH - 1
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left - 2, railY)
        nvgLineTo(ctx, right + 2, railY)
        nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 180))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left - 2, railY)
        nvgLineTo(ctx, right + 2, railY)
        nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 30))
        nvgStrokeWidth(ctx, 6)
        nvgStroke(ctx)
    end
end

local function DrawLanes_Front(ctx)
    local layout = G.layout
    for i = 1, Config.NUM_LANES do
        local y = G.GetLaneY(i)
        local h = layout.laneH
        local left = layout.counterLeft
        local right = layout.counterRight
        local w = right - left
        local topY = y - h * 0.5
        local surfaceH = h * 0.45
        local panelTop = topY + surfaceH
        local frontH = h * 0.55

        GradientRect(ctx, left, panelTop, w, frontH, 25, 18, 48, 255, 15, 10, 32, 255, 3)

        local stripH = frontH / 3
        for p = 1, 2 do
            local sy = panelTop + stripH * p
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, left + 8, sy)
            nvgLineTo(ctx, right - 8, sy)
            nvgStrokeColor(ctx, nvgRGBA(80, 50, 150, 30))
            nvgStrokeWidth(ctx, 0.5)
            nvgStroke(ctx)
        end

        GradientRect(ctx, left, panelTop, w, 4, 0, 0, 0, 100, 0, 0, 0, 0)

        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, panelTop + frontH)
        nvgLineTo(ctx, right, panelTop + frontH)
        nvgStrokeColor(ctx, nvgRGBA(255, 50, 200, 100))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, panelTop + frontH)
        nvgLineTo(ctx, right, panelTop + frontH)
        nvgStrokeColor(ctx, nvgRGBA(255, 50, 200, 20))
        nvgStrokeWidth(ctx, 6)
        nvgStroke(ctx)

        local totalH = surfaceH + frontH
        RoundRect(ctx, left - 3, topY, 3, totalH, 1, 40, 25, 70, 200)
        RoundRect(ctx, right, topY, 3, totalH, 1, 40, 25, 70, 200)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(120, 80, 200, 80))
        nvgText(ctx, left + 20, panelTop + frontH * 0.45, "BAR " .. tostring(i), nil)
    end
end

-- ============================================================================
-- 酒保
-- ============================================================================

local function DrawBartender(ctx)
    local bartender = G.bartender
    local layout = G.layout
    local by = bartender.y
    local serveAnim = math.max(0, bartender.serveAnim)
    local scale = math.max(3.5, layout.laneH * 0.065)

    DrawCyberBartender(ctx, layout.bartenderX_right, by, scale, true, serveAnim, 255)
    DrawCyberBartender(ctx, layout.bartenderX_left, by, scale, false, serveAnim * 0.5, 255)

    if bartender.leftDrinkAnim > 0 and bartender.leftDrinkType then
        local ldDt = Config.DRINK_TYPES[bartender.leftDrinkType]
        local s = scale
        local sipProgress = 1.0 - bartender.leftDrinkAnim
        local liftT
        if sipProgress < 0.2 then liftT = sipProgress / 0.2
        elseif sipProgress > 0.8 then liftT = (1.0 - sipProgress) / 0.2
        else liftT = 1.0 end
        local cupY = by + s * 0.5 + (by - s * 5 - by - s * 0.5) * liftT
        DrawCyberDrink(ctx, layout.bartenderX_left + s * 4, cupY, s * 0.7,
            ldDt.r, ldDt.g, ldDt.b, true)
    end
end

-- ============================================================================
-- 顾客
-- ============================================================================

local function DrawDrinkBubble(ctx, x, y, drinkType, alpha, remaining, scale, waitRatio)
    remaining = remaining or 1
    waitRatio = waitRatio or 0
    local dt = Config.DRINK_TYPES[drinkType]
    local s = scale or 2.5
    local bubbleSize = s * 4
    local rad = bubbleSize * 0.3

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + bubbleSize)
    nvgLineTo(ctx, x, y + bubbleSize + s * 2)
    nvgStrokeColor(ctx, nvgRGBA(dt.r, dt.g, dt.b, math.floor(alpha * 0.3)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    local bx = x - bubbleSize
    local by = y - bubbleSize
    local bw = bubbleSize * 2
    local bh = bubbleSize * 2
    RoundRect(ctx, bx, by, bw, bh, rad, 15, 10, 30, math.floor(alpha * 0.85))

    if waitRatio > 0.01 then
        local fillH = bh * waitRatio
        local fillY = by + bh - fillH
        local fr = 255
        local fg = math.floor(220 - 170 * waitRatio)
        local fb = math.floor(40 - 10 * waitRatio)
        local fa = math.floor(alpha * (0.25 + 0.35 * waitRatio))
        nvgSave(ctx)
        nvgIntersectScissor(ctx, bx, fillY, bw, fillH + 1)
        RoundRect(ctx, bx + 1, by + 1, bw - 2, bh - 2, rad, fr, fg, fb, fa)
        nvgRestore(ctx)
    end

    NeonStroke(ctx, bx, by, bw, bh, rad, dt.r, dt.g, dt.b, math.floor(alpha * 0.6), 1)

    if remaining > 1 then
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, math.max(10, s * 4))
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(dt.r, dt.g, dt.b, alpha))
        nvgText(ctx, x, y, "x" .. remaining, nil)
    else
        DrawCyberDrink(ctx, x, y, s * 0.5, dt.r, dt.g, dt.b, true)
    end
end

local function DrawBossBubble(ctx, x, y, sequence, seqIndex, alpha, scale, waitRatio)
    waitRatio = waitRatio or 0
    local s = scale or 3.2
    local totalDrinks = #sequence
    local iconS = s * 2.8
    local bubbleW = iconS * totalDrinks + s * 4
    local bubbleH = s * 7
    local bx = x - bubbleW / 2
    local by = y - bubbleH

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    nvgLineTo(ctx, x, y + s * 1.5)
    nvgStrokeColor(ctx, nvgRGBA(255, 160, 40, math.floor(alpha * 0.4)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    local rad = s * 1.2
    RoundRect(ctx, bx, by, bubbleW, bubbleH, rad, 15, 10, 30, math.floor(alpha * 0.9))

    if waitRatio > 0.01 then
        local fillH = bubbleH * waitRatio
        local fillY = by + bubbleH - fillH
        local fr = 255
        local fg = math.floor(220 - 170 * waitRatio)
        local fb = math.floor(40 - 10 * waitRatio)
        local fa = math.floor(alpha * (0.2 + 0.3 * waitRatio))
        nvgSave(ctx)
        nvgIntersectScissor(ctx, bx, fillY, bubbleW, fillH + 1)
        RoundRect(ctx, bx + 1, by + 1, bubbleW - 2, bubbleH - 2, rad, fr, fg, fb, fa)
        nvgRestore(ctx)
    end

    NeonStroke(ctx, bx, by, bubbleW, bubbleH, rad, 255, 160, 40, math.floor(alpha * 0.5), 1)

    local startX = bx + s * 2
    local iconCY = by + bubbleH / 2
    for i = 1, totalDrinks do
        local drinkIdx = sequence[i]
        local dt = Config.DRINK_TYPES[drinkIdx]
        local iconCX = startX + (i - 1) * iconS + iconS / 2
        local iconAlpha = alpha

        if i < seqIndex then
            iconAlpha = math.floor(alpha * 0.3)
            DrawCircle(ctx, iconCX, iconCY, s * 1.1, dt.r, dt.g, dt.b, iconAlpha)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, iconCX - s * 0.6, iconCY)
            nvgLineTo(ctx, iconCX - s * 0.15, iconCY + s * 0.5)
            nvgLineTo(ctx, iconCX + s * 0.7, iconCY - s * 0.5)
            nvgStrokeColor(ctx, nvgRGBA(0, 255, 120, math.floor(alpha * 0.7)))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        elseif i == seqIndex then
            local pulse = math.sin(G.time * 6) * 0.15 + 1.0
            local pr = s * 1.3 * pulse
            DrawCircle(ctx, iconCX, iconCY, pr + s * 0.4, dt.r, dt.g, dt.b, math.floor(alpha * 0.2))
            DrawCircle(ctx, iconCX, iconCY, pr, dt.r, dt.g, dt.b, iconAlpha)
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, math.max(9, s * 3))
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
            nvgText(ctx, iconCX, iconCY, dt.icon, nil)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, iconCX - s * 0.5, by + bubbleH - s * 0.4)
            nvgLineTo(ctx, iconCX, by + bubbleH + s * 0.4)
            nvgLineTo(ctx, iconCX + s * 0.5, by + bubbleH - s * 0.4)
            nvgFillColor(ctx, nvgRGBA(255, 200, 40, math.floor(iconAlpha * 0.8)))
            nvgFill(ctx)
        else
            iconAlpha = math.floor(alpha * 0.5)
            DrawCircle(ctx, iconCX, iconCY, s * 1.1, dt.r, dt.g, dt.b, iconAlpha)
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, math.max(8, s * 2.5))
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, math.floor(alpha * 0.4)))
            nvgText(ctx, iconCX, iconCY, dt.icon, nil)
        end
    end
end

local function DrawCustomers(ctx)
    local layout = G.layout
    local GetPatience = Logic.GetPatience

    for _, c in ipairs(G.customers) do
        local y = G.GetLaneY(c.lane) + layout.customerOffsetY
        local bob = math.sin(c.bobPhase) * 1.5
        local scale = math.max(3.2, layout.laneH * 0.06)
        if c.isBoss then scale = scale * 1.5 end
        local alpha = 255

        if c.servedAnim > 0 then
            alpha = math.floor(255 * (c.servedAnim / 0.8))
        end

        local cc = c.bodyColor
        local br, bg, bb = cc[1], cc[2], cc[3]

        if c.angryTimer and c.angryTimer > 0 then
            local angryT = math.sin(c.angryTimer * 20) * 0.5 + 0.5
            local mix = angryT * 0.6
            br = math.floor(br + (255 - br) * mix)
            bg = math.floor(bg * (1 - mix * 0.7))
            bb = math.floor(bb * (1 - mix * 0.7))
        end

        DrawCyberChar(ctx, c.x, y + bob, scale, br, bg, bb, alpha)

        if c.servedAnim <= 0 and not (c.sipAnim and c.sipAnim > 0) then
            local remaining = (c.drinksNeeded or 1) - (c.drinksReceived or 0)
            local patience = GetPatience()
            if c.isBoss then patience = patience * 3 end
            local waitRatio = math.min(1.0, (c.waitTime or 0) / patience)
            if c.isBoss and c.drinkSequence then
                DrawBossBubble(ctx, c.x, y + bob - scale * 9, c.drinkSequence, c.sequenceIndex, alpha, scale, waitRatio)
            else
                DrawDrinkBubble(ctx, c.x, y + bob - scale * 9, c.drinkType, alpha, remaining, scale, waitRatio)
            end
        end

        if c.sipAnim and c.sipAnim > 0 and c.sipDrinkType then
            local sipDt = Config.DRINK_TYPES[c.sipDrinkType]
            local sipProgress = 1.0 - (c.sipAnim / 1.0)
            local liftT
            if sipProgress < 0.2 then liftT = sipProgress / 0.2
            elseif sipProgress > 0.8 then liftT = (1.0 - sipProgress) / 0.2
            else liftT = 1.0 end
            local cupBaseY = y + bob
            local cupDrinkY = y + bob - scale * 6
            local cupY = cupBaseY + (cupDrinkY - cupBaseY) * liftT
            DrawCyberDrink(ctx, c.x + scale * 3.5, cupY, scale * 0.55,
                sipDt.r, sipDt.g, sipDt.b, true)
        end
    end
end

-- ============================================================================
-- 滑动饮料 / 空瓶
-- ============================================================================

local function DrawDrinks(ctx)
    local layout = G.layout
    for _, d in ipairs(G.drinks) do
        local y = G.GetLaneY(d.lane) - layout.laneH * 0.18
        local dt = Config.DRINK_TYPES[d.drinkType]
        local s = math.max(2, layout.laneH * 0.035)

        for t = 1, 4 do
            local tx = d.x + t * 8
            local ta = math.floor(120 - t * 25)
            DrawCircle(ctx, tx, y, 2, dt.r, dt.g, dt.b, ta)
        end

        DrawCyberDrink(ctx, d.x, y, s, dt.r, dt.g, dt.b, true)
    end
end

local function DrawEmptyBottles(ctx)
    local layout = G.layout
    for _, b in ipairs(G.emptyBottles) do
        local y = G.GetLaneY(b.lane) - layout.laneH * 0.18
        local dt = Config.DRINK_TYPES[b.drinkType]
        local s = math.max(2, layout.laneH * 0.035)
        local spin = b.trailTimer * 6
        local tiltX = math.sin(spin) * s * 2
        local tiltY = math.cos(spin) * s
        DrawCyberDrink(ctx, b.x + tiltX, y + tiltY, s, dt.r, dt.g, dt.b, false)
    end
end

-- ============================================================================
-- 粒子 / 浮动文字
-- ============================================================================

local function DrawParticles(ctx)
    for _, p in ipairs(G.particles) do
        local alpha = math.floor((p.life / p.maxLife) * 255)
        local sz = math.max(1, p.size * (p.life / p.maxLife))
        DrawCircle(ctx, p.x, p.y, sz * 1.5, p.r, p.g, p.b, math.floor(alpha * 0.2))
        DrawCircle(ctx, p.x, p.y, sz * 0.6, p.r, p.g, p.b, alpha)
    end
end

local function DrawFloatTexts(ctx)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(G.floatTexts) do
        local alpha = math.floor((ft.life / ft.maxLife) * 255)
        local scale = 1.0 + (1.0 - ft.life / ft.maxLife) * 0.3
        nvgSave(ctx)
        nvgTranslate(ctx, ft.x, ft.y)
        nvgScale(ctx, scale, scale)
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(ft.r, ft.g, ft.b, math.floor(alpha * 0.3)))
        nvgText(ctx, 0, 0, ft.text, nil)
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(ft.r, ft.g, ft.b, alpha))
        nvgText(ctx, 0, 0, ft.text, nil)
        nvgRestore(ctx)
    end
end

-- ============================================================================
-- HUD
-- ============================================================================

local function DrawVolumeSliders(ctx)
    local layout = G.layout
    DrawNeonSlider(ctx,
        layout.volSliderX, layout.volSliderY,
        layout.volSliderW, layout.volSliderH,
        G.bgmVolume, "BGM", NVG_ALIGN_LEFT,
        0, 255, 255, 255, 50, 200)

    DrawNeonSlider(ctx,
        layout.masterSliderX, layout.masterSliderY,
        layout.masterSliderW, layout.masterSliderH,
        G.masterVolume, "VOL", NVG_ALIGN_RIGHT,
        255, 255, 60, 255, 160, 40)
end

local function DrawHUD(ctx)
    if G.gameState ~= "playing" then return end
    local logicalW, logicalH = G.logicalW, G.logicalH
    local layout = G.layout

    nvgFontFace(ctx, "sans")
    local sx = layout.safeOffsetX
    local sw = layout.safeW

    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, 200))
    nvgText(ctx, sx + 10, 4, "SCORE", nil)
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, sx + 10, 18, tostring(G.score), nil)

    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 50, 200, 255))
    nvgText(ctx, logicalW / 2, 4, "LEVEL " .. G.level, nil)

    if G.combo > 1 then
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(255, 255, 60, 255))
        nvgText(ctx, logicalW / 2, 22, "COMBO x" .. G.combo, nil)
    end

    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(255, 50, 200, 200))
    nvgText(ctx, sx + sw - 10, 4, "LIVES", nil)

    for i = 1, Config.MAX_LIVES do
        local hx = sx + sw - 14 - (Config.MAX_LIVES - i) * 18
        local hy = 22
        if i <= G.lives then
            DrawCircle(ctx, hx + 7, hy + 7, 6, 255, 50, 200, 220)
            DrawCircle(ctx, hx + 7, hy + 7, 3, 255, 150, 230, 180)
        else
            DrawCircle(ctx, hx + 7, hy + 7, 6, 50, 30, 60, 150)
        end
    end

    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(ctx, nvgRGBA(100, 80, 150, 120))
    nvgText(ctx, logicalW / 2, logicalH - 4, "UP/DOWN Move | 1-6 Send Drinks", nil)

    DrawVolumeSliders(ctx)
end

-- ============================================================================
-- 饮料按钮 / 移动轨道
-- ============================================================================

local function DrawMoveTrack(ctx)
    local layout = G.layout
    local bartender = G.bartender
    local tx = layout.moveTrackX
    local ty = layout.moveTrackY
    local tw = layout.moveTrackW
    local th = layout.moveTrackH
    local cx = tx + tw / 2

    RoundRect(ctx, tx, ty, tw, th, 6, 15, 10, 30, 180)
    NeonStroke(ctx, tx, ty, tw, th, 6, 80, 60, 150, G.moveDrag.active and 150 or 60, 1)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx, ty + 10)
    nvgLineTo(ctx, cx, ty + th - 10)
    nvgStrokeColor(ctx, nvgRGBA(80, 60, 150, 60))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    for i = 1, Config.NUM_LANES do
        local laneY = layout.laneY[i]
        local isActive = (i == bartender.targetLane)
        DrawCircle(ctx, cx, laneY, isActive and 4 or 3,
            isActive and 0 or 60, isActive and 255 or 60, isActive and 255 or 80,
            isActive and 255 or 100)
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(100, 80, 150, 150))
        nvgText(ctx, tx + 10, laneY, tostring(i), nil)
    end

    local handleY = bartender.y
    local handleW = tw - 8
    local handleH = 14

    RoundRect(ctx, cx - handleW / 2, handleY - handleH / 2, handleW, handleH, 4, 0, 200, 220, 220)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - handleW / 2 - 2, handleY - handleH / 2 - 2, handleW + 4, handleH + 4, 5)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, G.moveDrag.active and 120 or 40))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)
end

local function DrawDrinkButtons(ctx)
    if G.gameState ~= "playing" then return end
    local layout = G.layout
    local unlockedCount = math.min(#Config.DRINK_TYPES, G.level)

    for i = 1, unlockedCount do
        local dt = Config.DRINK_TYPES[i]
        local bx = layout.drinkBtnX
        local by = layout.drinkBtnStartY + (i - 1) * (layout.drinkBtnH + layout.drinkBtnSpacing)

        RoundRect(ctx, bx, by, layout.drinkBtnW, layout.drinkBtnH, 4, 18, 12, 35, 200)
        NeonStroke(ctx, bx, by, layout.drinkBtnW, layout.drinkBtnH, 4, dt.r, dt.g, dt.b, 160, 1.5)

        local cx = bx + layout.drinkBtnW / 2
        local cy = by + layout.drinkBtnH / 2 - 2
        local s = math.max(1.2, layout.drinkBtnH * 0.06)
        DrawCyberDrink(ctx, cx, cy, s, dt.r, dt.g, dt.b, true)

        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 9)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(ctx, nvgRGBA(dt.r, dt.g, dt.b, 180))
        nvgText(ctx, cx, by + layout.drinkBtnH - 2, dt.key, nil)
    end

    DrawMoveTrack(ctx)
end

-- ============================================================================
-- 排行榜
-- ============================================================================

local function DrawLeaderboard(ctx, panelX, panelY, panelW, panelH)
    local pad = 8
    local headerH = 24
    local rowH = 20
    local cx = panelX + panelW / 2

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 200, 40, 255))
    nvgText(ctx, cx, panelY + headerH / 2 + 2, "LEADERBOARD", nil)

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, panelX + pad, panelY + headerH)
    nvgLineTo(ctx, panelX + panelW - pad, panelY + headerH)
    nvgStrokeColor(ctx, nvgRGBA(255, 200, 40, 80))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    if G.leaderboardLoading then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(180, 180, 220, 180))
        nvgText(ctx, cx, panelY + headerH + 30, "加载中...", nil)
        return
    end

    if #G.leaderboard == 0 then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(180, 180, 220, 180))
        nvgText(ctx, cx, panelY + headerH + 30, "暂无数据", nil)
        return
    end

    local maxRows = math.min(#G.leaderboard, math.floor((panelH - headerH - 30) / rowH))
    for i = 1, maxRows do
        local entry = G.leaderboard[i]
        local ry = panelY + headerH + 6 + (i - 1) * rowH

        if entry.isMe then
            RoundRect(ctx, panelX + pad - 2, ry - 1, panelW - pad * 2 + 4, rowH - 2, 3, 0, 255, 255, 30)
        end

        local rr, rg, rb = 180, 180, 220
        if i == 1 then rr, rg, rb = 255, 215, 0
        elseif i == 2 then rr, rg, rb = 200, 200, 210
        elseif i == 3 then rr, rg, rb = 205, 127, 50
        end

        nvgFontSize(ctx, 12)
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(rr, rg, rb, 255))
        nvgText(ctx, panelX + pad + 2, ry + rowH / 2, "#" .. i, nil)

        local nameColor = entry.isMe and {0, 255, 255} or {220, 220, 240}
        nvgFillColor(ctx, nvgRGBA(nameColor[1], nameColor[2], nameColor[3], 255))
        local displayName = entry.nickname or "..."
        if #displayName > 18 then
            displayName = string.sub(displayName, 1, 16) .. ".."
        end
        nvgText(ctx, panelX + pad + 28, ry + rowH / 2, displayName, nil)

        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, panelX + panelW - pad - 2, ry + rowH / 2, tostring(entry.score), nil)
    end

    if G.myRank then
        local footerY = panelY + panelH - 18
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 180))
        local rankText = "我的排名: #" .. G.myRank
        if G.leaderboardTotal > 0 then
            rankText = rankText .. " / " .. G.leaderboardTotal .. "人"
        end
        nvgText(ctx, cx, footerY, rankText, nil)
    end
end

-- ============================================================================
-- 菜单 / 结算
-- ============================================================================

local function DrawMenu(ctx)
    local logicalW, logicalH = G.logicalW, G.logicalH
    RoundRect(ctx, 0, 0, logicalW, logicalH, 0, 0, 0, 0, 180)

    local cx, cy = logicalW / 2, logicalH / 2
    local totalW = math.min(600, logicalW * 0.90)
    local totalH = math.min(280, logicalH * 0.82)
    local startX = cx - totalW / 2
    local startY = cy - totalH / 2

    local leftW = totalW * 0.55
    local leftX = startX
    RoundRect(ctx, leftX, startY, leftW, totalH, 8, 12, 8, 28, 240)
    NeonStroke(ctx, leftX, startY, leftW, totalH, 8, 0, 255, 255, 200, 2)

    local leftCx = leftX + leftW / 2
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(ctx, 28)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, 255))
    nvgText(ctx, leftCx, startY + 36, "666，居然还有第六关？", nil)

    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, nvgRGBA(255, 50, 200, 200))
    nvgText(ctx, leftCx, startY + 62, "since 1983", nil)

    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(180, 180, 220, 200))
    nvgText(ctx, leftCx, startY + totalH * 0.42, "上/下 移动酒保", nil)
    nvgText(ctx, leftCx, startY + totalH * 0.42 + 18, "1-6 发送饮料 | 触屏：点击右侧按钮", nil)
    nvgText(ctx, leftCx, startY + totalH * 0.42 + 36, "触屏：拖动左侧轨道移动", nil)

    local blink = math.sin(G.time * 4) * 0.5 + 0.5
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, math.floor(100 + blink * 155)))
    nvgText(ctx, leftCx, startY + totalH - 50, "点击开始", nil)

    if G.highScore > 0 then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(255, 50, 200, 200))
        nvgText(ctx, leftCx, startY + totalH - 28, "最高分: " .. G.highScore, nil)
    end

    local gap = 8
    local rightW = totalW - leftW - gap
    local rightX = leftX + leftW + gap
    RoundRect(ctx, rightX, startY, rightW, totalH, 8, 12, 8, 28, 240)
    NeonStroke(ctx, rightX, startY, rightW, totalH, 8, 255, 200, 40, 150, 1.5)

    DrawLeaderboard(ctx, rightX, startY, rightW, totalH)
end

local function DrawGameOver(ctx)
    local logicalW, logicalH = G.logicalW, G.logicalH
    RoundRect(ctx, 0, 0, logicalW, logicalH, 0, 0, 0, 0, 200)

    local cx, cy = logicalW / 2, logicalH / 2
    local totalW = math.min(600, logicalW * 0.90)
    local totalH = math.min(280, logicalH * 0.82)
    local startX = cx - totalW / 2
    local startY = cy - totalH / 2

    local titleText
    local titleR, titleG, titleB
    if G.gameWin then
        titleText = "666，居然过了第六关！"
        titleR, titleG, titleB = 0, 255, 200
    elseif G.level >= Config.MAX_LEVEL then
        titleText = "666，居然没过第六关。"
        titleR, titleG, titleB = 255, 200, 50
    else
        titleText = "666，居然都没到第六关？"
        titleR, titleG, titleB = 255, 50, 80
    end

    local leftW = totalW * 0.55
    local leftX = startX
    RoundRect(ctx, leftX, startY, leftW, totalH, 8, 15, 8, 20, 240)
    NeonStroke(ctx, leftX, startY, leftW, totalH, 8, titleR, titleG, titleB, 200, 2)

    local leftCx = leftX + leftW / 2
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(titleR, titleG, titleB, 255))
    nvgText(ctx, leftCx, startY + 36, titleText, nil)

    nvgFontSize(ctx, 20)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, leftCx, startY + 76, "得分: " .. G.score, nil)

    if G.score >= G.highScore and G.score > 0 then
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 255))
        nvgText(ctx, leftCx, startY + 104, "** 新纪录！ **", nil)
    else
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(180, 180, 220, 200))
        nvgText(ctx, leftCx, startY + 104, "最高分: " .. G.highScore, nil)
    end

    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(120, 100, 180, 200))
    nvgText(ctx, leftCx, startY + 134, "关卡:" .. G.level .. " 已服务:" .. G.totalServed .. " 最佳连击:" .. G.bestCombo, nil)

    if G.myRank then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 200))
        local rankInfo = "全球排名: #" .. G.myRank
        if G.leaderboardTotal > 0 then
            rankInfo = rankInfo .. " / " .. G.leaderboardTotal .. "人"
        end
        nvgText(ctx, leftCx, startY + 160, rankInfo, nil)
    end

    local blink = math.sin(G.time * 4) * 0.5 + 0.5
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, math.floor(100 + blink * 155)))
    nvgText(ctx, leftCx, startY + totalH - 36, "再来一局？", nil)

    local gap = 8
    local rightW = totalW - leftW - gap
    local rightX = leftX + leftW + gap
    RoundRect(ctx, rightX, startY, rightW, totalH, 8, 12, 8, 28, 240)
    NeonStroke(ctx, rightX, startY, rightW, totalH, 8, 255, 200, 40, 150, 1.5)

    DrawLeaderboard(ctx, rightX, startY, rightW, totalH)
end

-- ============================================================================
-- 主渲染入口
-- ============================================================================

function Renderer.HandleRender(eventType, eventData)
    local vg = G.vg
    if vg == nil then return end

    G.RecalcResolution()
    G.RecalcLayout()

    nvgBeginFrame(vg, G.logicalW, G.logicalH, G.dpr)

    local shakeX, shakeY = 0, 0
    if G.shakeTimer > 0 then
        shakeX = (math.random() - 0.5) * G.shakeIntensity * 2
        shakeY = (math.random() - 0.5) * G.shakeIntensity * 2
        nvgTranslate(vg, shakeX, shakeY)
    end

    DrawBackground(vg)
    DrawLanes_Back(vg)
    DrawDrinks(vg)
    DrawEmptyBottles(vg)
    DrawCustomers(vg)
    DrawLanes_Front(vg)
    DrawBartender(vg)
    DrawParticles(vg)
    DrawFloatTexts(vg)
    DrawHUD(vg)
    DrawDrinkButtons(vg)

    if G.gameState == "menu" then
        DrawMenu(vg)
    elseif G.gameState == "gameover" then
        DrawGameOver(vg)
    end

    if G.shakeTimer > 0 then
        nvgTranslate(vg, -shakeX, -shakeY)
    end

    nvgEndFrame(vg)
end

return Renderer
