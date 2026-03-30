-- ============================================================================
-- Cyber Tapper - 赛博朋克霓虹酒保游戏
-- 玩法: Tapper 风格 - 控制酒保在4条吧台间移动，向顾客滑出饮料
-- 操作: 上/下切换通道, 1-6 发送对应饮料 (或点击屏幕按钮)
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- NanoVG & Resolution (Mode B: 系统逻辑分辨率)
-- ============================================================================
local vg = nil
local fontNormal = -1
local physW, physH = 0, 0
local dpr = 1.0
local logicalW, logicalH = 0, 0

local function RecalcResolution()
    physW = graphics:GetWidth()
    physH = graphics:GetHeight()
    dpr = graphics:GetDPR()
    logicalW = physW / dpr
    logicalH = physH / dpr
end

-- ============================================================================
-- 赛博朋克霓虹调色板
-- ============================================================================
local PAL = {
    bg1           = {10, 8, 24},
    bg2           = {18, 14, 38},
    neon_cyan     = {0, 255, 255},
    neon_pink     = {255, 50, 200},
    neon_purple   = {180, 80, 255},
    neon_yellow   = {255, 255, 60},
    neon_green    = {50, 255, 120},
    neon_orange   = {255, 160, 40},
    bar_surface   = {35, 25, 60},
    bar_front     = {22, 16, 42},
    bar_edge      = {60, 40, 100},
    bar_glow      = {100, 60, 200},
    hud_yellow    = {255, 255, 60},
    hud_white     = {230, 230, 255},
}

-- ============================================================================
-- 游戏配置
-- ============================================================================
local NUM_LANES = 4
local DRINK_SPEED = 220
local BOTTLE_RETURN_SPEED = 180
local CUSTOMER_WALK_SPEED = 120
local QUEUE_SPACING = 32
local BASE_SPAWN_INTERVAL = 2.8
local BASE_PATIENCE = 14
local BARTENDER_MOVE_TIME = 0.12
local MAX_LIVES = 3
local SERVES_PER_LEVEL = 16
local SERVES_LEVEL6 = 36

local DRINK_TYPES = {
    { name = "Neon Ale",    r = 0,   g = 255, b = 255, key = "1", icon = "I" },
    { name = "Plasma",      r = 255, g = 50,  b = 200, key = "2", icon = "II" },
    { name = "Dark Matter", r = 180, g = 80,  b = 255, key = "3", icon = "III" },
    { name = "Solar Flare", r = 255, g = 200, b = 40,  key = "4", icon = "IV" },
    { name = "Acid Rain",   r = 50,  g = 255, b = 120, key = "5", icon = "V" },
    { name = "Lava Flow",   r = 255, g = 100, b = 30,  key = "6", icon = "VI" },
}
local MAX_LEVEL = 6

local CUSTOMER_COLORS = {
    {0, 220, 255},
    {255, 60, 200},
    {180, 80, 255},
    {255, 200, 40},
    {50, 255, 120},
    {255, 100, 60},
    {100, 200, 255},
    {255, 150, 200},
}

-- ============================================================================
-- 游戏状态
-- ============================================================================
local gameState = "menu"
local gameWin = false
local time = 0
local score = 0
local highScore = 0
local lives = MAX_LIVES
local level = 1
local totalServed = 0
local combo = 0
local bestCombo = 0
local levelServed = 0
local shakeTimer = 0
local shakeIntensity = 0

local bgmNode = nil
local bgmSource = nil
local bgmVolume = 0.3
local masterVolume = 0.8
local sfxServe = nil
local sfxGlassBreak = nil
local sfxAngry = nil
local sfxSip = nil
local sfxGameOver = nil
local sfxGameWin = nil

local function ApplyBgmGain()
    if bgmSource then
        bgmSource.gain = bgmVolume * masterVolume
    end
end

local function PlaySfx(sound, gain)
    if sound and bgmNode then
        local src = bgmNode:CreateComponent("SoundSource")
        src.soundType = "Effect"
        src.gain = (gain or 0.6) * masterVolume
        src.autoRemoveMode = REMOVE_COMPONENT
        src:Play(sound)
    end
end

local bartender = {
    lane = 2,
    targetLane = 2,
    y = 0,
    animTime = 0,
    serveAnim = 0,
    leftDrinkAnim = 0,
    leftDrinkType = nil,
}

local customers = {}
local drinks = {}
local emptyBottles = {}
local particles = {}
local floatTexts = {}

local layout = {
    laneY = {},
    laneH = 0,
    counterLeft = 0,
    counterRight = 0,
    counterW = 0,
    bartenderX_right = 0,
    bartenderX_left = 0,
    drinkBtnX = 0,
    drinkBtnW = 0,
    drinkBtnH = 0,
    drinkBtnSpacing = 0,
    drinkBtnStartY = 0,
    moveTrackX = 0,
    moveTrackW = 0,
    moveTrackY = 0,
    moveTrackH = 0,
    customerOffsetY = 0,
}

local moveDrag = {
    active = false,
    touchId = -1,
}

local volumeDrag = {
    active = false,
    touchId = -1,
}

local masterDrag = {
    active = false,
    touchId = -1,
}

local spawnTimer = 0

-- ============================================================================
-- 排行榜数据
-- ============================================================================
local leaderboard = {}        -- { {rank, nickname, score, isMe}, ... }
local leaderboardLoading = false
local leaderboardLoaded = false
local myCloudHighScore = 0    -- 云端最高分
local myRank = nil            -- 我的排名
local leaderboardTotal = 0    -- 排行榜总人数

-- ============================================================================
-- 云端排行榜函数
-- ============================================================================

--- 上传最高分到云端
local function UploadHighScore(newScore)
    if not clientCloud then return end
    clientCloud:Get("high_score", {
        ok = function(values, iscores)
            myCloudHighScore = iscores.high_score or 0
            if newScore > myCloudHighScore then
                clientCloud:BatchSet()
                    :SetInt("high_score", newScore)
                    :SetInt("best_level", level)
                    :SetInt("best_combo", bestCombo)
                    :Save("更新最高分", {
                        ok = function()
                            myCloudHighScore = newScore
                            print("云端最高分已更新: " .. newScore)
                            FetchLeaderboard()
                        end,
                        error = function(code, reason)
                            print("上传分数失败: " .. tostring(reason))
                        end
                    })
            else
                FetchLeaderboard()
            end
        end,
        error = function(code, reason)
            print("读取云端分数失败: " .. tostring(reason))
            FetchLeaderboard()
        end
    })
end

--- 拉取排行榜 Top 10
function FetchLeaderboard()
    if not clientCloud then return end
    if leaderboardLoading then return end
    leaderboardLoading = true
    leaderboardLoaded = false

    clientCloud:GetRankList("high_score", 0, 10, {
        ok = function(rankList)
            local entries = {}
            local userIds = {}
            for i, item in ipairs(rankList) do
                table.insert(entries, {
                    rank = i,
                    userId = item.userId,
                    nickname = "...",
                    score = item.iscore.high_score or 0,
                    bestLevel = item.iscore.best_level or 0,
                    bestCombo = item.iscore.best_combo or 0,
                    isMe = item.userId == clientCloud.userId,
                })
                table.insert(userIds, item.userId)
            end

            -- 查自己的排名
            clientCloud:GetUserRank(clientCloud.userId, "high_score", {
                ok = function(rank, scoreValue)
                    myRank = rank
                end
            })

            clientCloud:GetRankTotal("high_score", {
                ok = function(total)
                    leaderboardTotal = total
                end
            })

            if #userIds == 0 then
                leaderboard = entries
                leaderboardLoading = false
                leaderboardLoaded = true
                return
            end

            GetUserNickname({
                userIds = userIds,
                onSuccess = function(nicknames)
                    local map = {}
                    for _, info in ipairs(nicknames) do
                        map[info.userId] = info.nickname or ""
                    end
                    for _, entry in ipairs(entries) do
                        entry.nickname = map[entry.userId] or "未知玩家"
                    end
                    leaderboard = entries
                    leaderboardLoading = false
                    leaderboardLoaded = true
                end,
                onError = function(errorCode)
                    leaderboard = entries
                    leaderboardLoading = false
                    leaderboardLoaded = true
                end
            })
        end,
        error = function(code, reason)
            print("获取排行榜失败: " .. tostring(reason))
            leaderboardLoading = false
        end
    }, "best_level", "best_combo")
end

local function IsInVolumeSlider(x, y)
    local pad = 12
    return x >= layout.volSliderX - pad
       and x <= layout.volSliderX + layout.volSliderW + pad
       and y >= layout.volSliderY - pad
       and y <= layout.volSliderY + layout.volSliderH + pad
end

local function DragVolume(x)
    local ratio = (x - layout.volSliderX) / layout.volSliderW
    bgmVolume = math.max(0, math.min(1, ratio))
    ApplyBgmGain()
end

local function IsInMasterSlider(x, y)
    local pad = 12
    return x >= layout.masterSliderX - pad
       and x <= layout.masterSliderX + layout.masterSliderW + pad
       and y >= layout.masterSliderY - pad
       and y <= layout.masterSliderY + layout.masterSliderH + pad
end

local function DragMasterVolume(x)
    local ratio = (x - layout.masterSliderX) / layout.masterSliderW
    masterVolume = math.max(0, math.min(1, ratio))
    ApplyBgmGain()
end

-- ============================================================================
-- 绘图辅助 (圆角 / 渐变 / 发光)
-- ============================================================================

--- 圆角矩形填充
local function RoundRect(ctx, x, y, w, h, r, cr, cg, cb, ca)
    ca = ca or 255
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, r)
    nvgFillColor(ctx, nvgRGBA(cr, cg, cb, ca))
    nvgFill(ctx)
end

--- 霓虹发光描边
local function NeonStroke(ctx, x, y, w, h, rad, cr, cg, cb, ca, lw)
    ca = ca or 200
    lw = lw or 2
    -- 外发光 (模糊层)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - 2, y - 2, w + 4, h + 4, rad + 1)
    nvgStrokeColor(ctx, nvgRGBA(cr, cg, cb, math.floor(ca * 0.3)))
    nvgStrokeWidth(ctx, lw + 3)
    nvgStroke(ctx)
    -- 主描边
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, rad)
    nvgStrokeColor(ctx, nvgRGBA(cr, cg, cb, ca))
    nvgStrokeWidth(ctx, lw)
    nvgStroke(ctx)
end

--- 垂直渐变矩形
local function GradientRect(ctx, x, y, w, h, r1, g1, b1, a1, r2, g2, b2, a2, rad)
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
local function DrawCircle(ctx, cx, cy, r, cr, cg, cb, ca)
    ca = ca or 255
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgFillColor(ctx, nvgRGBA(cr, cg, cb, ca))
    nvgFill(ctx)
end

--- 赛博朋克人物 (圆润风格)
local function DrawCyberChar(ctx, cx, cy, scale, bodyR, bodyG, bodyB, alpha)
    alpha = alpha or 255
    local s = scale

    -- 头部 (圆形)
    DrawCircle(ctx, cx, cy - s * 5, s * 2, 210, 180, 150, alpha)
    -- 头发
    RoundRect(ctx, cx - s * 2.2, cy - s * 7.2, s * 4.4, s * 2.5, s * 0.8, 40, 30, 60, alpha)
    -- 墨镜 (赛博感)
    RoundRect(ctx, cx - s * 1.8, cy - s * 5.5, s * 3.6, s * 1.2, s * 0.4, 20, 20, 30, alpha)
    -- 镜片高光
    RoundRect(ctx, cx - s * 1.5, cy - s * 5.3, s * 1.2, s * 0.6, s * 0.2, bodyR, bodyG, bodyB, math.floor(alpha * 0.6))
    RoundRect(ctx, cx + s * 0.3, cy - s * 5.3, s * 1.2, s * 0.6, s * 0.2, bodyR, bodyG, bodyB, math.floor(alpha * 0.6))

    -- 身体 (夹克)
    RoundRect(ctx, cx - s * 2.2, cy - s * 3, s * 4.4, s * 4.5, s * 0.6, bodyR, bodyG, bodyB, alpha)
    -- 领口 V 形
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - s * 0.8, cy - s * 3)
    nvgLineTo(ctx, cx, cy - s * 1.5)
    nvgLineTo(ctx, cx + s * 0.8, cy - s * 3)
    nvgStrokeColor(ctx, nvgRGBA(20, 15, 30, alpha))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 手臂
    RoundRect(ctx, cx - s * 3.2, cy - s * 2.5, s * 1.2, s * 3.5, s * 0.5, bodyR, bodyG, bodyB, alpha)
    RoundRect(ctx, cx + s * 2, cy - s * 2.5, s * 1.2, s * 3.5, s * 0.5, bodyR, bodyG, bodyB, alpha)

    -- 腿
    local legR = math.max(0, math.floor(bodyR * 0.4))
    local legG = math.max(0, math.floor(bodyG * 0.4))
    local legB = math.max(0, math.floor(bodyB * 0.4))
    RoundRect(ctx, cx - s * 1.6, cy + s * 1.5, s * 1.4, s * 3, s * 0.4, legR, legG, legB, alpha)
    RoundRect(ctx, cx + s * 0.2, cy + s * 1.5, s * 1.4, s * 3, s * 0.4, legR, legG, legB, alpha)

    -- 鞋
    RoundRect(ctx, cx - s * 2, cy + s * 4.2, s * 1.8, s * 0.9, s * 0.3, 30, 25, 40, alpha)
    RoundRect(ctx, cx + s * 0.2, cy + s * 4.2, s * 1.8, s * 0.9, s * 0.3, 30, 25, 40, alpha)

    -- 身体霓虹边线
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - s * 2.2, cy - s * 3, s * 4.4, s * 4.5, s * 0.6)
    nvgStrokeColor(ctx, nvgRGBA(bodyR, bodyG, bodyB, math.floor(alpha * 0.4)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

--- 赛博酒保
local function DrawCyberBartender(ctx, cx, cy, scale, facingLeft, serveAnim, alpha)
    alpha = alpha or 255
    local s = scale

    -- 头部
    DrawCircle(ctx, cx, cy - s * 5, s * 2.2, 210, 180, 150, alpha)
    -- 帽子/头巾 (霓虹色)
    RoundRect(ctx, cx - s * 2.5, cy - s * 7.5, s * 5, s * 2.2, s * 0.8, 30, 20, 50, alpha)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - s * 2.5, cy - s * 7.5, s * 5, s * 2.2, s * 0.8)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, math.floor(alpha * 0.7)))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 眼睛
    DrawCircle(ctx, cx - s * 0.8, cy - s * 5, s * 0.5, 50, 50, 60, alpha)
    DrawCircle(ctx, cx + s * 0.8, cy - s * 5, s * 0.5, 50, 50, 60, alpha)
    -- 瞳孔发光
    DrawCircle(ctx, cx - s * 0.8, cy - s * 5, s * 0.25, 0, 255, 255, alpha)
    DrawCircle(ctx, cx + s * 0.8, cy - s * 5, s * 0.25, 0, 255, 255, alpha)

    -- 微笑
    nvgBeginPath(ctx)
    nvgArc(ctx, cx, cy - s * 3.8, s * 0.8, 0.2, math.pi - 0.2, NVG_CW)
    nvgStrokeColor(ctx, nvgRGBA(180, 130, 110, alpha))
    nvgStrokeWidth(ctx, 1.2)
    nvgStroke(ctx)

    -- 身体 (白色制服)
    RoundRect(ctx, cx - s * 2.5, cy - s * 3, s * 5, s * 5, s * 0.6, 220, 220, 240, alpha)
    -- 围裙
    RoundRect(ctx, cx - s * 1.8, cy - s * 1.5, s * 3.6, s * 3, s * 0.4, 200, 200, 220, alpha)
    -- 领结 (霓虹粉)
    RoundRect(ctx, cx - s * 0.6, cy - s * 3, s * 1.2, s * 0.8, s * 0.3, 255, 50, 200, alpha)

    -- 手臂
    local armExtend = serveAnim * s * 3
    if facingLeft then
        RoundRect(ctx, cx - s * 3.5 - armExtend, cy - s * 2, s * 1.3 + armExtend, s * 2.5, s * 0.5, 220, 220, 240, alpha)
        DrawCircle(ctx, cx - s * 3.5 - armExtend, cy - s * 0.5, s * 0.7, 210, 180, 150, alpha)
        RoundRect(ctx, cx + s * 2.2, cy - s * 2, s * 1.3, s * 2.5, s * 0.5, 220, 220, 240, alpha)
    else
        RoundRect(ctx, cx + s * 2.2, cy - s * 2, s * 1.3 + armExtend, s * 2.5, s * 0.5, 220, 220, 240, alpha)
        DrawCircle(ctx, cx + s * 3.5 + armExtend, cy - s * 0.5, s * 0.7, 210, 180, 150, alpha)
        RoundRect(ctx, cx - s * 3.5, cy - s * 2, s * 1.3, s * 2.5, s * 0.5, 220, 220, 240, alpha)
    end

    -- 蓝色裤子
    RoundRect(ctx, cx - s * 2, cy + s * 2, s * 1.8, s * 3, s * 0.4, 30, 40, 120, alpha)
    RoundRect(ctx, cx + s * 0.2, cy + s * 2, s * 1.8, s * 3, s * 0.4, 30, 40, 120, alpha)

    -- 鞋
    RoundRect(ctx, cx - s * 2.5, cy + s * 4.8, s * 2.2, s * 1, s * 0.4, 20, 15, 35, alpha)
    RoundRect(ctx, cx + s * 0.3, cy + s * 4.8, s * 2.2, s * 1, s * 0.4, 20, 15, 35, alpha)

    -- 制服霓虹边线
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - s * 2.5, cy - s * 3, s * 5, s * 5, s * 0.6)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, math.floor(alpha * 0.25)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

--- 赛博风格鸡尾酒杯
local function DrawCyberDrink(ctx, x, y, scale, drinkR, drinkG, drinkB, full)
    local s = scale
    -- 杯体 (半透明玻璃)
    RoundRect(ctx, x - s * 2, y - s * 3, s * 4, s * 5, s * 0.6, 80, 80, 120, 120)
    if full then
        -- 液体
        RoundRect(ctx, x - s * 1.5, y - s * 1.5, s * 3, s * 3, s * 0.4, drinkR, drinkG, drinkB, 200)
        -- 顶部泡沫/光晕
        RoundRect(ctx, x - s * 1.5, y - s * 2.2, s * 3, s * 1, s * 0.4, 255, 255, 255, 100)
    else
        RoundRect(ctx, x - s * 1.5, y - s * 0.5, s * 3, s * 2, s * 0.3, 60, 60, 80, 60)
    end
    -- 把手
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x + s * 2, y - s * 1.5, s * 1.2, s * 3, s * 0.3)
    nvgStrokeColor(ctx, nvgRGBA(120, 120, 160, 180))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)
    -- 杯体霓虹边
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x - s * 2, y - s * 3, s * 4, s * 5, s * 0.6)
    nvgStrokeColor(ctx, nvgRGBA(drinkR, drinkG, drinkB, 100))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)
end

-- ============================================================================
-- 布局计算
-- ============================================================================
local function RecalcLayout()
    local topMargin = logicalH * 0.14
    local bottomMargin = logicalH * 0.08
    local gameAreaH = logicalH - topMargin - bottomMargin
    local laneSpacing = gameAreaH / NUM_LANES

    layout.laneH = laneSpacing * 0.50

    -- 安全区域：限制游戏区域最大宽度，超宽屏居中显示
    local maxAspect = 18 / 9  -- 最大支持 18:9，超出部分左右留黑边
    local maxGameW = logicalH * maxAspect
    local safeW = math.min(logicalW, maxGameW)
    local safeOffsetX = (logicalW - safeW) / 2  -- 居中偏移

    layout.safeOffsetX = safeOffsetX
    layout.safeW = safeW

    local sideBtnW = math.max(44, safeW * 0.10)

    layout.counterLeft = safeOffsetX + sideBtnW + safeW * 0.04
    layout.counterRight = safeOffsetX + safeW - sideBtnW - safeW * 0.04
    layout.counterW = layout.counterRight - layout.counterLeft
    layout.bartenderX_right = layout.counterRight + safeW * 0.02
    layout.bartenderX_left = layout.counterLeft - safeW * 0.02

    for i = 1, NUM_LANES do
        layout.laneY[i] = topMargin + (i - 0.5) * laneSpacing
    end

    layout.drinkBtnW = sideBtnW
    layout.drinkBtnH = math.min(logicalH * 0.08, 42)
    layout.drinkBtnSpacing = 3
    layout.drinkBtnX = safeOffsetX + safeW - sideBtnW - 4
    local unlockedCount = math.min(#DRINK_TYPES, level)
    local totalDrinkH = unlockedCount * layout.drinkBtnH + (unlockedCount - 1) * layout.drinkBtnSpacing
    layout.drinkBtnStartY = topMargin + (gameAreaH - totalDrinkH) / 2

    layout.moveTrackW = sideBtnW
    layout.moveTrackX = safeOffsetX + 4
    layout.moveTrackY = topMargin + laneSpacing * 0.2
    layout.moveTrackH = gameAreaH - laneSpacing * 0.4

    layout.customerOffsetY = -layout.laneH * 0.12

    -- BGM 音量滑块布局 (左上，积分下方)
    layout.volSliderW = math.max(56, safeW * 0.09)
    layout.volSliderH = 6
    layout.volSliderX = safeOffsetX + 10
    layout.volSliderY = 44

    -- 总音量滑块布局 (右上，血量下方)
    layout.masterSliderW = layout.volSliderW
    layout.masterSliderH = 6
    layout.masterSliderX = safeOffsetX + safeW - layout.masterSliderW - 10
    layout.masterSliderY = 44
end

-- ============================================================================
-- 入口
-- ============================================================================
function Start()
    graphics.windowTitle = "Cyber Tapper"
    SampleStart()
    SampleInitMouseMode(MM_FREE)

    RecalcResolution()
    RecalcLayout()
    bartender.y = GetLaneY(2)

    vg = nvgCreate(1)
    if vg == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    if fontNormal == -1 then
        print("ERROR: Could not load font")
        return
    end

    StartBGM()

    sfxServe = cache:GetResource("Sound", "audio/sfx/serve_throw.ogg")
    sfxGlassBreak = cache:GetResource("Sound", "audio/sfx/glass_break.ogg")
    sfxAngry = cache:GetResource("Sound", "audio/sfx/angry_customer.ogg")
    sfxSip = cache:GetResource("Sound", "audio/sfx/drink_sip.ogg")
    sfxGameOver = cache:GetResource("Sound", "audio/sfx/game_over.ogg")
    sfxGameWin = cache:GetResource("Sound", "audio/sfx/game_win.ogg")

    SubscribeToEvent(vg, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseClick")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")

    -- 初始拉取排行榜
    FetchLeaderboard()

    print("=== Cyber Tapper Started ===")
end

function StartBGM()
    local bgm = cache:GetResource("Sound", "audio/music_1774750187496.ogg")
    if bgm then
        bgm.looped = true
        ---@type Scene
        local scene = Scene()
        bgmNode = scene:CreateChild("BGM")
        bgmSource = bgmNode:CreateComponent("SoundSource")
        bgmSource.soundType = "Music"
        bgmSource.gain = bgmVolume * masterVolume
        bgmSource:Play(bgm)
        print("BGM started")
    else
        print("WARNING: Could not load BGM")
    end
end

function Stop()
    if vg ~= nil then
        nvgDelete(vg)
        vg = nil
    end
    if bgmSource then
        bgmSource:Stop()
    end
end

-- ============================================================================
-- 屏幕变化
-- ============================================================================
function HandleScreenMode(eventType, eventData)
    RecalcResolution()
    RecalcLayout()
end

-- ============================================================================
-- 游戏逻辑
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    time = time + dt

    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
    end

    if volumeDrag.active and volumeDrag.touchId == -1 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local mx = input.mousePosition.x / dpr
            DragVolume(mx)
        else
            volumeDrag.active = false
        end
    end

    if masterDrag.active and masterDrag.touchId == -1 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local mx = input.mousePosition.x / dpr
            DragMasterVolume(mx)
        else
            masterDrag.active = false
        end
    end

    if moveDrag.active and moveDrag.touchId == -1 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local my = input.mousePosition.y / dpr
            DragMoveBartender(my)
        else
            moveDrag.active = false
        end
    end

    if not moveDrag.active and #layout.laneY > 0 then
        local targetY = GetLaneY(bartender.targetLane)
        local diff = targetY - bartender.y
        if math.abs(diff) > 0.5 then
            bartender.y = bartender.y + diff * math.min(1.0, dt * 18)
        else
            bartender.y = targetY
        end
    end
    if #layout.laneY > 0 then
        bartender.lane = GetClosestLaneFromY(bartender.y)
    end

    if gameState == "playing" then
        UpdateGame(dt)
    end
end

local function GetPatience()
    return math.max(6, BASE_PATIENCE * (1 / (1 + (level - 1) * 0.1)))
end

local function GetSpawnInterval()
    return math.max(0.8, BASE_SPAWN_INTERVAL * (1 / (1 + (level - 1) * 0.15)))
end

function GetLaneY(lane)
    return layout.laneY[lane] or layout.laneY[1]
end

function UpdateGame(dt)
    bartender.animTime = bartender.animTime + dt
    if bartender.serveAnim > 0 then
        bartender.serveAnim = bartender.serveAnim - dt * 4
    end
    if bartender.leftDrinkAnim > 0 then
        bartender.leftDrinkAnim = bartender.leftDrinkAnim - dt
        if bartender.leftDrinkAnim <= 0 then
            bartender.leftDrinkType = nil
        end
    end

    spawnTimer = spawnTimer + dt
    if spawnTimer >= GetSpawnInterval() then
        spawnTimer = 0
        SpawnCustomer()
    end

    UpdateCustomers(dt)
    UpdateDrinks(dt)
    UpdateEmptyBottles(dt)
    UpdateParticles(dt)
    UpdateFloatTexts(dt)
end

local function GetLaneActiveCount(lane)
    local count = 0
    for _, c in ipairs(customers) do
        if c.lane == lane and c.servedAnim <= 0 then count = count + 1 end
    end
    return count
end

function SpawnCustomer()
    local lane = math.random(1, NUM_LANES)
    if GetLaneActiveCount(lane) >= 6 then
        local found = false
        for tryLane = 1, NUM_LANES do
            if GetLaneActiveCount(tryLane) < 6 then
                lane = tryLane
                found = true
                break
            end
        end
        if not found then return end
    end

    local maxType = math.min(#DRINK_TYPES, level)
    local drinkType = math.random(1, maxType)
    local drinksNeeded = 1
    if level >= 2 and math.random() < 0.3 then drinksNeeded = 2 end
    if level >= 4 and math.random() < 0.2 then drinksNeeded = 3 end

    local posInQueue = GetLaneActiveCount(lane)
    local targetX = layout.counterRight - 40 - posInQueue * QUEUE_SPACING
    local colorIdx = math.random(1, #CUSTOMER_COLORS)
    local cc = CUSTOMER_COLORS[colorIdx]

    table.insert(customers, {
        lane = lane,
        x = layout.counterLeft - 30,
        targetX = targetX,
        drinkType = drinkType,
        drinksNeeded = drinksNeeded,
        drinksReceived = 0,
        waitTime = 0,
        bodyColor = cc,
        bobPhase = math.random() * math.pi * 2,
        alive = true,
        servedAnim = 0,
        angryTimer = 0,
    })
end

--- Fisher-Yates 洗牌
local function ShuffleArray(arr)
    local n = #arr
    for i = n, 2, -1 do
        local j = math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return arr
end

function SpawnBoss()
    local lane = math.random(1, NUM_LANES)
    local posInQueue = GetLaneActiveCount(lane)
    local targetX = layout.counterRight - 40 - posInQueue * QUEUE_SPACING

    -- 随机顺序的6种酒
    local seq = {1, 2, 3, 4, 5, 6}
    ShuffleArray(seq)

    table.insert(customers, {
        lane = lane,
        x = layout.counterLeft - 30,
        targetX = targetX,
        drinkType = seq[1],
        drinksNeeded = 6,
        drinksReceived = 0,
        waitTime = 0,
        bodyColor = {255, 80, 40},
        bobPhase = math.random() * math.pi * 2,
        alive = true,
        servedAnim = 0,
        angryTimer = 0,
        -- 壮汉专属
        isBoss = true,
        drinkSequence = seq,
        sequenceIndex = 1,
    })
end

function RecalcLaneQueues()
    for lane = 1, NUM_LANES do
        local laneCustomers = {}
        for _, c in ipairs(customers) do
            if c.lane == lane and c.servedAnim <= 0 then
                table.insert(laneCustomers, c)
            end
        end
        table.sort(laneCustomers, function(a, b) return a.x > b.x end)
        for idx, c in ipairs(laneCustomers) do
            c.targetX = layout.counterRight - 40 - (idx - 1) * QUEUE_SPACING
        end
    end
end

function UpdateCustomers(dt)
    RecalcLaneQueues()
    for i = #customers, 1, -1 do
        local c = customers[i]
        if c.angryTimer and c.angryTimer > 0 then
            c.angryTimer = c.angryTimer - dt
        end
        if c.sipAnim and c.sipAnim > 0 then
            c.sipAnim = c.sipAnim - dt
            if c.sipAnim <= 0 and c.exitAfterSip then
                table.insert(emptyBottles, {
                    lane = c.lane,
                    x = c.x,
                    drinkType = c.sipDrinkType,
                    trailTimer = 0,
                })
                c.exitAfterSip = nil
                c.sipDrinkType = nil
                c.servedAnim = 0.8
            end
        end

        if c.servedAnim > 0 then
            c.servedAnim = c.servedAnim - dt
            c.x = c.x - 120 * dt
            if c.servedAnim <= 0 or c.x < layout.counterLeft - 40 then
                table.remove(customers, i)
            end
        elseif c.sipAnim and c.sipAnim > 0 then
            c.bobPhase = c.bobPhase + dt * 2
        else
            if c.targetX and math.abs(c.x - c.targetX) > 2 then
                if c.x < c.targetX then
                    c.x = math.min(c.x + CUSTOMER_WALK_SPEED * dt, c.targetX)
                else
                    c.x = math.max(c.x - CUSTOMER_WALK_SPEED * dt, c.targetX)
                end
                c.bobPhase = c.bobPhase + dt * 4
            else
                if c.targetX then c.x = c.targetX end
                c.bobPhase = c.bobPhase + dt * 2
                c.waitTime = (c.waitTime or 0) + dt
                local patience = GetPatience()
                if c.isBoss then patience = patience * 3 end
                if c.waitTime >= patience then
                    PlaySfx(sfxAngry, 0.7)
                    if c.isBoss then
                        for _ = 1, 3 do LoseLife() end
                    else
                        LoseLife()
                    end
                    shakeTimer = 0.3
                    shakeIntensity = c.isBoss and 8 or 4
                    local angryText = c.isBoss and "BOSS ANGRY! -3" or "ANGRY!"
                    AddFloatText(angryText, c.x, GetLaneY(c.lane) + layout.customerOffsetY - 25, 255, 80, 50)
                    table.remove(customers, i)
                end
            end
        end
    end
end

function ServeDrink(drinkType)
    if gameState ~= "playing" then return end
    if drinkType < 1 or drinkType > #DRINK_TYPES then return end
    local unlockedCount = math.min(#DRINK_TYPES, level)
    if drinkType > unlockedCount then return end
    PlaySfx(sfxServe, 0.6)
    bartender.serveAnim = 1.0
    table.insert(drinks, {
        lane = bartender.lane,
        x = layout.bartenderX_right - 10,
        drinkType = drinkType,
        trailTimer = 0,
    })
    local serveDt = DRINK_TYPES[drinkType]
    local serveY = GetLaneY(bartender.lane)
    for _ = 1, 5 do
        table.insert(particles, {
            x = layout.bartenderX_right,
            y = serveY,
            vx = -math.random(50, 120),
            vy = (math.random() - 0.5) * 50,
            life = 0.3 + math.random() * 0.2,
            maxLife = 0.5,
            r = serveDt.r, g = serveDt.g, b = serveDt.b,
            size = 3 + math.random() * 3,
        })
    end
end

function LoseLife()
    lives = lives - 1
    combo = 0
    if lives <= 0 then
        GameOver()
    end
end

function GameOver()
    gameState = "gameover"
    gameWin = false
    PlaySfx(sfxGameOver, 0.8)
    if score > highScore then
        highScore = score
    end
    UploadHighScore(score)
end

function GameWin()
    gameState = "gameover"
    gameWin = true
    PlaySfx(sfxGameWin, 0.8)
    if score > highScore then
        highScore = score
    end
    UploadHighScore(score)
end

function ResetGame()
    customers = {}
    drinks = {}
    emptyBottles = {}
    particles = {}
    floatTexts = {}
    score = 0
    lives = MAX_LIVES
    level = 1
    totalServed = 0
    levelServed = 0
    combo = 0
    bestCombo = 0
    spawnTimer = 0
    bartender.lane = 2
    bartender.targetLane = 2
    bartender.y = GetLaneY(2)
    bartender.serveAnim = 0
    bartender.leftDrinkAnim = 0
    bartender.leftDrinkType = nil
    shakeTimer = 0
    gameWin = false
    gameState = "playing"
end

-- ============================================================================
-- 粒子与浮动文字
-- ============================================================================
function CreateServeParticles(x, y, drinkType)
    local dt = DRINK_TYPES[drinkType]
    for _ = 1, 10 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 100
        table.insert(particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 30,
            life = 0.4 + math.random() * 0.3,
            maxLife = 0.7,
            r = dt.r, g = dt.g, b = dt.b,
            size = 3 + math.random() * 3,
        })
    end
end

function UpdateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 80 * dt
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function AddFloatText(text, x, y, r, g, b)
    table.insert(floatTexts, {
        text = text, x = x, y = y,
        r = r, g = g, b = b,
        life = 1.2, maxLife = 1.2,
    })
end

function UpdateFloatTexts(dt)
    for i = #floatTexts, 1, -1 do
        local ft = floatTexts[i]
        ft.life = ft.life - dt
        ft.y = ft.y - 40 * dt
        if ft.life <= 0 then
            table.remove(floatTexts, i)
        end
    end
end

-- ============================================================================
-- 饮料碰撞 / 空瓶
-- ============================================================================
function UpdateDrinks(dt)
    for i = #drinks, 1, -1 do
        local d = drinks[i]
        d.x = d.x - DRINK_SPEED * dt
        d.trailTimer = d.trailTimer + dt
        local serveY = GetLaneY(d.lane)
        local serveDt = DRINK_TYPES[d.drinkType]

        local hitCustomer = nil
        local hitX = -1
        for _, c in ipairs(customers) do
            -- 壮汉 sipAnim 期间仍可接酒（避免酒穿透 MISS）
            local isSipping = c.sipAnim and c.sipAnim > 0
            local canHit = c.lane == d.lane and c.servedAnim <= 0
                and (not isSipping or (c.isBoss and not c.exitAfterSip))
            if canHit and c.x > hitX then
                hitX = c.x
                hitCustomer = c
            end
        end

        if hitCustomer and d.x <= hitCustomer.x + 8 then
            if hitCustomer.drinkType == d.drinkType then
                hitCustomer.drinksReceived = (hitCustomer.drinksReceived or 0) + 1
                totalServed = totalServed + 1
                combo = combo + 1
                if combo > bestCombo then bestCombo = combo end
                local points = 10 * level + combo * 5
                if hitCustomer.isBoss then points = points + 20 end
                score = score + points
                local remaining = (hitCustomer.drinksNeeded or 1) - hitCustomer.drinksReceived
                local custY = serveY + layout.customerOffsetY
                PlaySfx(sfxSip, 0.5)
                if remaining <= 0 then
                    hitCustomer.sipAnim = 1.0
                    hitCustomer.sipDrinkType = d.drinkType
                    hitCustomer.exitAfterSip = true
                    AddFloatText("+" .. points, hitCustomer.x, custY - 20, 0, 255, 255)
                    if hitCustomer.isBoss then
                        AddFloatText("BOSS DOWN!", hitCustomer.x, custY - 45, 255, 200, 40)
                    end
                else
                    hitCustomer.sipAnim = 1.0
                    hitCustomer.sipDrinkType = d.drinkType
                    AddFloatText("+" .. points, hitCustomer.x, custY - 20, 0, 255, 255)
                    -- 壮汉：推进到下一杯
                    if hitCustomer.isBoss and hitCustomer.drinkSequence then
                        hitCustomer.sequenceIndex = hitCustomer.sequenceIndex + 1
                        hitCustomer.drinkType = hitCustomer.drinkSequence[hitCustomer.sequenceIndex]
                        AddFloatText(remaining .. " LEFT", hitCustomer.x, custY - 45, 255, 160, 40)
                    end
                end
                if combo > 1 then
                    AddFloatText("x" .. combo .. " COMBO!", hitCustomer.x, custY - 40, 255, 255, 60)
                end
                CreateServeParticles(hitCustomer.x, serveY, d.drinkType)
                levelServed = levelServed + 1
                local target = (level == MAX_LEVEL) and SERVES_LEVEL6 or SERVES_PER_LEVEL
                if levelServed >= target then
                    if level < MAX_LEVEL then
                        level = level + 1
                        levelServed = 0
                        AddFloatText("LEVEL " .. level .. "!", logicalW / 2, logicalH / 2 - 30, 255, 255, 60)
                        if level == MAX_LEVEL then
                            SpawnBoss()
                        end
                    else
                        GameWin()
                    end
                end
            else
                hitCustomer.servedAnim = 0.8
                hitCustomer.angryTimer = 0.6
                PlaySfx(sfxAngry, 0.7)
                if hitCustomer.isBoss then
                    for _ = 1, 3 do LoseLife() end
                else
                    LoseLife()
                end
                combo = 0
                shakeTimer = 0.3
                shakeIntensity = hitCustomer.isBoss and 8 or 4
                local wrongText = hitCustomer.isBoss and "WRONG! -3" or "WRONG!"
                AddFloatText(wrongText, hitCustomer.x, serveY + layout.customerOffsetY - 20, 255, 60, 60)
            end
            table.remove(drinks, i)
        elseif d.x <= layout.bartenderX_left + 15 then
            if bartender.lane == d.lane and bartender.leftDrinkAnim <= 0 then
                local points = 3
                score = score + points
                AddFloatText("CATCH +" .. points, layout.bartenderX_left, serveY - 20, 200, 255, 200)
                bartender.serveAnim = 0.5
                bartender.leftDrinkAnim = 1.0
                bartender.leftDrinkType = d.drinkType
                table.remove(drinks, i)
            elseif d.x < layout.counterLeft - 40 then
                PlaySfx(sfxGlassBreak, 0.7)
                LoseLife()
                combo = 0
                shakeTimer = 0.3
                shakeIntensity = 4
                AddFloatText("MISS!", layout.counterLeft + 10, serveY - 20, 255, 100, 50)
                table.remove(drinks, i)
            end
        end
    end
end

function UpdateEmptyBottles(dt)
    for i = #emptyBottles, 1, -1 do
        local b = emptyBottles[i]
        b.x = b.x - BOTTLE_RETURN_SPEED * dt
        b.trailTimer = b.trailTimer + dt
        if b.x <= layout.bartenderX_left + 15 then
            if bartender.lane == b.lane then
                local points = 5
                score = score + points
                AddFloatText("CATCH +" .. points, layout.bartenderX_left, GetLaneY(b.lane) - 20, 200, 255, 200)
                bartender.serveAnim = 0.5
                table.remove(emptyBottles, i)
            elseif b.x < layout.counterLeft - 40 then
                PlaySfx(sfxGlassBreak, 0.7)
                LoseLife()
                combo = 0
                shakeTimer = 0.3
                shakeIntensity = 4
                AddFloatText("MISS!", layout.counterLeft - 10, GetLaneY(b.lane) - 20, 255, 100, 50)
                table.remove(emptyBottles, i)
            end
        end
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if gameState == "menu" then
        if key == KEY_SPACE or key == KEY_RETURN then ResetGame() end
    elseif gameState == "playing" then
        if key == KEY_UP or key == KEY_W then MoveBartender(-1)
        elseif key == KEY_DOWN or key == KEY_S then MoveBartender(1)
        elseif key == KEY_1 or key == KEY_Z then ServeDrink(1)
        elseif key == KEY_2 or key == KEY_X then ServeDrink(2)
        elseif key == KEY_3 or key == KEY_C then ServeDrink(3)
        elseif key == KEY_4 then ServeDrink(4)
        elseif key == KEY_5 then ServeDrink(5)
        elseif key == KEY_6 then ServeDrink(6)
        end
    elseif gameState == "gameover" then
        if key == KEY_SPACE or key == KEY_RETURN then ResetGame() end
    end
end

function MoveBartender(delta)
    local newLane = bartender.targetLane + delta
    if newLane >= 1 and newLane <= NUM_LANES then
        bartender.targetLane = newLane
    end
end

function GetClosestLaneFromY(y)
    local closest = 1
    local minDist = math.huge
    for i = 1, NUM_LANES do
        local dist = math.abs(y - layout.laneY[i])
        if dist < minDist then
            minDist = dist
            closest = i
        end
    end
    return closest
end

local function IsInMoveTrack(x, y)
    return x >= layout.moveTrackX
       and x <= layout.moveTrackX + layout.moveTrackW
       and y >= layout.moveTrackY - 20
       and y <= layout.moveTrackY + layout.moveTrackH + 20
end

function DragMoveBartender(y)
    local minY = layout.laneY[1]
    local maxY = layout.laneY[NUM_LANES]
    bartender.y = math.max(minY, math.min(maxY, y))
    bartender.targetLane = GetClosestLaneFromY(bartender.y)
end

function HandleMouseClick(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    if input.numTouches > 0 then return end
    local mx = eventData["X"]:GetInt() / dpr
    local my = eventData["Y"]:GetInt() / dpr
    if gameState == "playing" and IsInVolumeSlider(mx, my) then
        volumeDrag.active = true
        volumeDrag.touchId = -1
        DragVolume(mx)
        return
    end
    if gameState == "playing" and IsInMasterSlider(mx, my) then
        masterDrag.active = true
        masterDrag.touchId = -1
        DragMasterVolume(mx)
        return
    end
    if gameState == "playing" and IsInMoveTrack(mx, my) then
        moveDrag.active = true
        moveDrag.touchId = -1
        DragMoveBartender(my)
        return
    end
    ProcessPointerInput(mx, my)
end

function HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    if input.numTouches > 0 then return end
    if volumeDrag.active and volumeDrag.touchId == -1 then
        volumeDrag.active = false
    end
    if masterDrag.active and masterDrag.touchId == -1 then
        masterDrag.active = false
    end
    if moveDrag.active and moveDrag.touchId == -1 then
        moveDrag.active = false
    end
end

function HandleTouchBegin(eventType, eventData)
    local tx = eventData["X"]:GetInt() / dpr
    local ty = eventData["Y"]:GetInt() / dpr
    local touchId = eventData["TouchID"]:GetInt()
    if gameState == "playing" and IsInVolumeSlider(tx, ty) then
        volumeDrag.active = true
        volumeDrag.touchId = touchId
        DragVolume(tx)
        return
    end
    if gameState == "playing" and IsInMasterSlider(tx, ty) then
        masterDrag.active = true
        masterDrag.touchId = touchId
        DragMasterVolume(tx)
        return
    end
    if gameState == "playing" and IsInMoveTrack(tx, ty) then
        moveDrag.active = true
        moveDrag.touchId = touchId
        DragMoveBartender(ty)
        return
    end
    ProcessPointerInput(tx, ty)
end

function HandleTouchMove(eventType, eventData)
    local touchId = eventData["TouchID"]:GetInt()
    if volumeDrag.active and volumeDrag.touchId == touchId then
        local tx = eventData["X"]:GetInt() / dpr
        DragVolume(tx)
        return
    end
    if masterDrag.active and masterDrag.touchId == touchId then
        local tx = eventData["X"]:GetInt() / dpr
        DragMasterVolume(tx)
        return
    end
    if moveDrag.active and moveDrag.touchId == touchId then
        local ty = eventData["Y"]:GetInt() / dpr
        DragMoveBartender(ty)
    end
end

function HandleTouchEnd(eventType, eventData)
    local touchId = eventData["TouchID"]:GetInt()
    if volumeDrag.active and volumeDrag.touchId == touchId then
        volumeDrag.active = false
        volumeDrag.touchId = -1
    end
    if masterDrag.active and masterDrag.touchId == touchId then
        masterDrag.active = false
        masterDrag.touchId = -1
    end
    if moveDrag.active and moveDrag.touchId == touchId then
        moveDrag.active = false
        moveDrag.touchId = -1
    end
end

function ProcessPointerInput(x, y)
    if gameState == "menu" then ResetGame(); return end
    if gameState == "gameover" then ResetGame(); return end
    if gameState ~= "playing" then return end

    local unlockedCount = math.min(#DRINK_TYPES, level)
    if x >= layout.drinkBtnX then
        local totalH = unlockedCount * layout.drinkBtnH + (unlockedCount - 1) * layout.drinkBtnSpacing
        local areaTop = layout.drinkBtnStartY - layout.drinkBtnSpacing
        local areaBot = layout.drinkBtnStartY + totalH + layout.drinkBtnSpacing
        if y >= areaTop and y <= areaBot and unlockedCount > 0 then
            local bestIdx = 1
            local bestDist = math.huge
            for i = 1, unlockedCount do
                local by = layout.drinkBtnStartY + (i - 1) * (layout.drinkBtnH + layout.drinkBtnSpacing)
                local btnCenterY = by + layout.drinkBtnH / 2
                local dist = math.abs(y - btnCenterY)
                if dist < bestDist then
                    bestDist = dist
                    bestIdx = i
                end
            end
            ServeDrink(bestIdx)
            return
        end
    end

    for i = 1, NUM_LANES do
        local ly = GetLaneY(i)
        if math.abs(y - ly) < layout.laneH * 0.8 then
            bartender.targetLane = i
            return
        end
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================
function HandleRender(eventType, eventData)
    if vg == nil then return end

    RecalcResolution()
    RecalcLayout()

    nvgBeginFrame(vg, logicalW, logicalH, dpr)

    local shakeX, shakeY = 0, 0
    if shakeTimer > 0 then
        shakeX = (math.random() - 0.5) * shakeIntensity * 2
        shakeY = (math.random() - 0.5) * shakeIntensity * 2
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

    if gameState == "menu" then
        DrawMenu(vg)
    elseif gameState == "gameover" then
        DrawGameOver(vg)
    end

    if shakeTimer > 0 then
        nvgTranslate(vg, -shakeX, -shakeY)
    end

    nvgEndFrame(vg)
end

-- ============================================================================
-- 赛博朋克霓虹风格绘制
-- ============================================================================

function DrawBackground(ctx)
    -- 深色渐变背景
    GradientRect(ctx, 0, 0, logicalW, logicalH, 12, 8, 28, 255, 6, 4, 18, 255)

    -- 网格线 (赛博朋克风)
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

    -- 顶部霓虹条带
    local topH = logicalH * 0.08
    local sx = layout.safeOffsetX
    local sw = layout.safeW
    GradientRect(ctx, sx, 0, sw, topH, 20, 10, 50, 240, 10, 5, 30, 200)
    -- 霓虹线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, topH)
    nvgLineTo(ctx, sx + sw, topH)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 150))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    -- 发光层
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, sx, topH)
    nvgLineTo(ctx, sx + sw, topH)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 30))
    nvgStrokeWidth(ctx, 8)
    nvgStroke(ctx)

    -- 通道分隔线 (霓虹暗线)
    for i = 1, NUM_LANES do
        local y = GetLaneY(i)
        local halfH = layout.laneH * 0.5
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx, y - halfH - 1)
        nvgLineTo(ctx, sx + sw, y - halfH - 1)
        nvgStrokeColor(ctx, nvgRGBA(80, 50, 150, 40))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)
    end
end

--- 吧台后层：台面 (画在顾客后面)
function DrawLanes_Back(ctx)
    for i = 1, NUM_LANES do
        local y = GetLaneY(i)
        local h = layout.laneH
        local left = layout.counterLeft
        local right = layout.counterRight
        local w = right - left
        local topY = y - h * 0.5
        local surfaceH = h * 0.45

        -- 台面 (暗紫渐变)
        GradientRect(ctx, left, topY, w, surfaceH, 45, 30, 75, 255, 35, 22, 60, 255, 3)

        -- 台面高光线
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, topY + 1)
        nvgLineTo(ctx, right, topY + 1)
        nvgStrokeColor(ctx, nvgRGBA(120, 80, 200, 80))
        nvgStrokeWidth(ctx, 1)
        nvgStroke(ctx)

        -- 前沿霓虹护栏
        local railY = topY + surfaceH - 1
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left - 2, railY)
        nvgLineTo(ctx, right + 2, railY)
        nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 180))
        nvgStrokeWidth(ctx, 2)
        nvgStroke(ctx)
        -- 发光
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left - 2, railY)
        nvgLineTo(ctx, right + 2, railY)
        nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, 30))
        nvgStrokeWidth(ctx, 6)
        nvgStroke(ctx)
    end
end

--- 吧台前层：前面板 (画在顾客前面，遮挡下半身)
function DrawLanes_Front(ctx)
    for i = 1, NUM_LANES do
        local y = GetLaneY(i)
        local h = layout.laneH
        local left = layout.counterLeft
        local right = layout.counterRight
        local w = right - left
        local topY = y - h * 0.5
        local surfaceH = h * 0.45
        local panelTop = topY + surfaceH
        local frontH = h * 0.55

        -- 前面板 (深色，关键遮挡层)
        GradientRect(ctx, left, panelTop, w, frontH, 25, 18, 48, 255, 15, 10, 32, 255, 3)

        -- 面板装饰线条
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

        -- 顶部阴影
        GradientRect(ctx, left, panelTop, w, 4, 0, 0, 0, 100, 0, 0, 0, 0)

        -- 底部霓虹边线
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, panelTop + frontH)
        nvgLineTo(ctx, right, panelTop + frontH)
        nvgStrokeColor(ctx, nvgRGBA(255, 50, 200, 100))
        nvgStrokeWidth(ctx, 1.5)
        nvgStroke(ctx)
        -- 发光
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, left, panelTop + frontH)
        nvgLineTo(ctx, right, panelTop + frontH)
        nvgStrokeColor(ctx, nvgRGBA(255, 50, 200, 20))
        nvgStrokeWidth(ctx, 6)
        nvgStroke(ctx)

        -- 侧面
        local totalH = surfaceH + frontH
        RoundRect(ctx, left - 3, topY, 3, totalH, 1, 40, 25, 70, 200)
        RoundRect(ctx, right, topY, 3, totalH, 1, 40, 25, 70, 200)

        -- 通道编号
        nvgFontFace(ctx, "sans")
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(120, 80, 200, 80))
        nvgText(ctx, left + 20, panelTop + frontH * 0.45, "BAR " .. tostring(i), nil)
    end
end

-- ============================================================================
-- 绘制酒保
-- ============================================================================
function DrawBartender(ctx)
    local by = bartender.y
    local serveAnim = math.max(0, bartender.serveAnim)
    local scale = math.max(3.5, layout.laneH * 0.065)

    DrawCyberBartender(ctx, layout.bartenderX_right, by, scale, true, serveAnim, 255)
    DrawCyberBartender(ctx, layout.bartenderX_left, by, scale, false, serveAnim * 0.5, 255)

    if bartender.leftDrinkAnim > 0 and bartender.leftDrinkType then
        local ldDt = DRINK_TYPES[bartender.leftDrinkType]
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
-- 绘制顾客
-- ============================================================================
function DrawCustomers(ctx)
    for _, c in ipairs(customers) do
        local y = GetLaneY(c.lane) + layout.customerOffsetY
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



        -- 饮料需求气泡
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

        -- 喝酒动画
        if c.sipAnim and c.sipAnim > 0 and c.sipDrinkType then
            local sipDt = DRINK_TYPES[c.sipDrinkType]
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

function DrawDrinkBubble(ctx, x, y, drinkType, alpha, remaining, scale, waitRatio)
    remaining = remaining or 1
    waitRatio = waitRatio or 0
    local dt = DRINK_TYPES[drinkType]
    local s = scale or 2.5
    local bubbleSize = s * 4
    local rad = bubbleSize * 0.3

    -- 连接线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y + bubbleSize)
    nvgLineTo(ctx, x, y + bubbleSize + s * 2)
    nvgStrokeColor(ctx, nvgRGBA(dt.r, dt.g, dt.b, math.floor(alpha * 0.3)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 气泡背景 (圆角半透明)
    local bx = x - bubbleSize
    local by = y - bubbleSize
    local bw = bubbleSize * 2
    local bh = bubbleSize * 2
    RoundRect(ctx, bx, by, bw, bh, rad, 15, 10, 30, math.floor(alpha * 0.85))

    -- 耐心填充：从下往上，黄→红渐变
    if waitRatio > 0.01 then
        local fillH = bh * waitRatio
        local fillY = by + bh - fillH
        -- 颜色：waitRatio 0→1 对应 黄(255,220,40)→红(255,50,30)
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

--- 壮汉 BOSS 气泡：显示6杯酒序列 + 当前进度
function DrawBossBubble(ctx, x, y, sequence, seqIndex, alpha, scale, waitRatio)
    waitRatio = waitRatio or 0
    local s = scale or 3.2
    local totalDrinks = #sequence
    -- 气泡尺寸：横向排列6个图标（大尺寸）
    local iconS = s * 2.8          -- 每个图标间距
    local bubbleW = iconS * totalDrinks + s * 4
    local bubbleH = s * 7
    local bx = x - bubbleW / 2
    local by = y - bubbleH

    -- 连接线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, x, y)
    nvgLineTo(ctx, x, y + s * 1.5)
    nvgStrokeColor(ctx, nvgRGBA(255, 160, 40, math.floor(alpha * 0.4)))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 气泡背景
    local rad = s * 1.2
    RoundRect(ctx, bx, by, bubbleW, bubbleH, rad, 15, 10, 30, math.floor(alpha * 0.9))

    -- 耐心填充
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

    -- 边框
    NeonStroke(ctx, bx, by, bubbleW, bubbleH, rad, 255, 160, 40, math.floor(alpha * 0.5), 1)

    -- 绘制6个酒类图标（大尺寸）
    local startX = bx + s * 2
    local iconCY = by + bubbleH / 2
    for i = 1, totalDrinks do
        local drinkIdx = sequence[i]
        local dt = DRINK_TYPES[drinkIdx]
        local iconCX = startX + (i - 1) * iconS + iconS / 2
        local iconAlpha = alpha

        if i < seqIndex then
            -- 已完成：暗灰 + 打勾
            iconAlpha = math.floor(alpha * 0.3)
            DrawCircle(ctx, iconCX, iconCY, s * 1.1, dt.r, dt.g, dt.b, iconAlpha)
            -- 打勾标记
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, iconCX - s * 0.6, iconCY)
            nvgLineTo(ctx, iconCX - s * 0.15, iconCY + s * 0.5)
            nvgLineTo(ctx, iconCX + s * 0.7, iconCY - s * 0.5)
            nvgStrokeColor(ctx, nvgRGBA(0, 255, 120, math.floor(alpha * 0.7)))
            nvgStrokeWidth(ctx, 2)
            nvgStroke(ctx)
        elseif i == seqIndex then
            -- 当前需要：大 + 发光 + 呼吸动画
            local pulse = math.sin(time * 6) * 0.15 + 1.0
            local pr = s * 1.3 * pulse
            DrawCircle(ctx, iconCX, iconCY, pr + s * 0.4, dt.r, dt.g, dt.b, math.floor(alpha * 0.2))
            DrawCircle(ctx, iconCX, iconCY, pr, dt.r, dt.g, dt.b, iconAlpha)
            -- 饮料罗马数字
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, math.max(9, s * 3))
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(255, 255, 255, iconAlpha))
            nvgText(ctx, iconCX, iconCY, dt.icon, nil)
            -- 底部箭头指示
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, iconCX - s * 0.5, by + bubbleH - s * 0.4)
            nvgLineTo(ctx, iconCX, by + bubbleH + s * 0.4)
            nvgLineTo(ctx, iconCX + s * 0.5, by + bubbleH - s * 0.4)
            nvgFillColor(ctx, nvgRGBA(255, 200, 40, math.floor(iconAlpha * 0.8)))
            nvgFill(ctx)
        else
            -- 未到达：半透明圆
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

-- ============================================================================
-- 绘制滑动饮料
-- ============================================================================
function DrawDrinks(ctx)
    for _, d in ipairs(drinks) do
        local y = GetLaneY(d.lane) - layout.laneH * 0.18  -- 台面上方，避免和霓虹线重合
        local dt = DRINK_TYPES[d.drinkType]
        local s = math.max(2, layout.laneH * 0.035)

        -- 霓虹拖尾
        for t = 1, 4 do
            local tx = d.x + t * 8
            local ta = math.floor(120 - t * 25)
            DrawCircle(ctx, tx, y, 2, dt.r, dt.g, dt.b, ta)
        end

        DrawCyberDrink(ctx, d.x, y, s, dt.r, dt.g, dt.b, true)
    end
end

-- ============================================================================
-- 绘制空瓶
-- ============================================================================
function DrawEmptyBottles(ctx)
    for _, b in ipairs(emptyBottles) do
        local y = GetLaneY(b.lane) - layout.laneH * 0.18  -- 和饮料同高度
        local dt = DRINK_TYPES[b.drinkType]
        local s = math.max(2, layout.laneH * 0.035)

        local spin = b.trailTimer * 6
        local tiltX = math.sin(spin) * s * 2
        local tiltY = math.cos(spin) * s

        DrawCyberDrink(ctx, b.x + tiltX, y + tiltY, s, dt.r, dt.g, dt.b, false)
    end
end

-- ============================================================================
-- 绘制粒子 (发光圆点)
-- ============================================================================
function DrawParticles(ctx)
    for _, p in ipairs(particles) do
        local alpha = math.floor((p.life / p.maxLife) * 255)
        local sz = math.max(1, p.size * (p.life / p.maxLife))

        -- 外发光
        DrawCircle(ctx, p.x, p.y, sz * 1.5, p.r, p.g, p.b, math.floor(alpha * 0.2))
        -- 内核
        DrawCircle(ctx, p.x, p.y, sz * 0.6, p.r, p.g, p.b, alpha)
    end
end

-- ============================================================================
-- 绘制浮动文字
-- ============================================================================
function DrawFloatTexts(ctx)
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for _, ft in ipairs(floatTexts) do
        local alpha = math.floor((ft.life / ft.maxLife) * 255)
        local scale = 1.0 + (1.0 - ft.life / ft.maxLife) * 0.3

        nvgSave(ctx)
        nvgTranslate(ctx, ft.x, ft.y)
        nvgScale(ctx, scale, scale)

        nvgFontSize(ctx, 14)
        -- 发光
        nvgFillColor(ctx, nvgRGBA(ft.r, ft.g, ft.b, math.floor(alpha * 0.3)))
        nvgText(ctx, 0, 0, ft.text, nil)
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(ft.r, ft.g, ft.b, alpha))
        nvgText(ctx, 0, 0, ft.text, nil)

        nvgRestore(ctx)
    end
end

-- ============================================================================
-- HUD (赛博霓虹风)
-- ============================================================================
function DrawHUD(ctx)
    if gameState ~= "playing" then return end

    nvgFontFace(ctx, "sans")
    local topH = logicalH * 0.08
    local sx = layout.safeOffsetX
    local sw = layout.safeW

    -- 分数
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, 200))
    nvgText(ctx, sx + 10, 4, "SCORE", nil)
    nvgFontSize(ctx, 22)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
    nvgText(ctx, sx + 10, 18, tostring(score), nil)

    -- 等级
    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(ctx, nvgRGBA(255, 50, 200, 255))
    nvgText(ctx, logicalW / 2, 4, "LEVEL " .. level, nil)

    if combo > 1 then
        nvgFontSize(ctx, 13)
        nvgFillColor(ctx, nvgRGBA(255, 255, 60, 255))
        nvgText(ctx, logicalW / 2, 22, "COMBO x" .. combo, nil)
    end

    -- 生命
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFontSize(ctx, 12)
    nvgFillColor(ctx, nvgRGBA(255, 50, 200, 200))
    nvgText(ctx, sx + sw - 10, 4, "LIVES", nil)

    for i = 1, MAX_LIVES do
        local hx = sx + sw - 14 - (MAX_LIVES - i) * 18
        local hy = 22
        if i <= lives then
            -- 满心 (霓虹粉)
            DrawCircle(ctx, hx + 7, hy + 7, 6, 255, 50, 200, 220)
            DrawCircle(ctx, hx + 7, hy + 7, 3, 255, 150, 230, 180)
        else
            DrawCircle(ctx, hx + 7, hy + 7, 6, 50, 30, 60, 150)
        end
    end

    -- 底部提示
    nvgFontSize(ctx, 10)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(ctx, nvgRGBA(100, 80, 150, 120))
    nvgText(ctx, logicalW / 2, logicalH - 4, "UP/DOWN Move | 1-6 Send Drinks", nil)

    -- 音量滑块 (赛博霓虹风)
    DrawVolumeSliders(ctx)
end

--- 通用霓虹滑块绘制
---@param ctx any
---@param sx number 滑块 X
---@param sy number 滑块 Y
---@param sw number 滑块宽度
---@param sh number 滑块高度
---@param value number 0~1
---@param label string 标签文字
---@param labelAlign number NVG 文字对齐
---@param cr1 number 渐变起始 R
---@param cg1 number 渐变起始 G
---@param cb1 number 渐变起始 B
---@param cr2 number 渐变结束 R
---@param cg2 number 渐变结束 G
---@param cb2 number 渐变结束 B
local function DrawNeonSlider(ctx, sx, sy, sw, sh, value, label, labelAlign, cr1, cg1, cb1, cr2, cg2, cb2)
    local knobR = 5

    -- 标签
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 9)
    nvgTextAlign(ctx, labelAlign + NVG_ALIGN_BOTTOM)
    nvgFillColor(ctx, nvgRGBA(100, 80, 180, 150))
    local labelX = sx
    if labelAlign == NVG_ALIGN_RIGHT then labelX = sx + sw end
    nvgText(ctx, labelX, sy - 3, label, nil)

    -- 轨道背景
    RoundRect(ctx, sx, sy, sw, sh, sh / 2, 25, 18, 45, 180)

    -- 填充部分 (霓虹渐变)
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

    -- 轨道描边
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, sw, sh, sh / 2)
    nvgStrokeColor(ctx, nvgRGBA(80, 60, 160, 100))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    -- 旋钮
    local knobX = sx + fillW
    local knobY = sy + sh / 2
    DrawCircle(ctx, knobX, knobY, knobR + 2, cr1, cg1, cb1, 40)
    DrawCircle(ctx, knobX, knobY, knobR, 20, 15, 35, 240)
    DrawCircle(ctx, knobX, knobY, knobR - 2, cr1, cg1, cb1, 200)
end

function DrawVolumeSliders(ctx)
    -- BGM 滑块 (左下角，青→粉)
    DrawNeonSlider(ctx,
        layout.volSliderX, layout.volSliderY,
        layout.volSliderW, layout.volSliderH,
        bgmVolume, "BGM", NVG_ALIGN_LEFT,
        0, 255, 255, 255, 50, 200)

    -- 总音量滑块 (右下角，黄→橙)
    DrawNeonSlider(ctx,
        layout.masterSliderX, layout.masterSliderY,
        layout.masterSliderW, layout.masterSliderH,
        masterVolume, "VOL", NVG_ALIGN_RIGHT,
        255, 255, 60, 255, 160, 40)
end

-- ============================================================================
-- 饮料按钮 (霓虹风格)
-- ============================================================================
function DrawDrinkButtons(ctx)
    if gameState ~= "playing" then return end

    local unlockedCount = math.min(#DRINK_TYPES, level)

    for i = 1, unlockedCount do
        local dt = DRINK_TYPES[i]
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

function DrawMoveTrack(ctx)
    local tx = layout.moveTrackX
    local ty = layout.moveTrackY
    local tw = layout.moveTrackW
    local th = layout.moveTrackH
    local cx = tx + tw / 2

    RoundRect(ctx, tx, ty, tw, th, 6, 15, 10, 30, 180)
    NeonStroke(ctx, tx, ty, tw, th, 6, 80, 60, 150, moveDrag.active and 150 or 60, 1)

    -- 中央轨道线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx, ty + 10)
    nvgLineTo(ctx, cx, ty + th - 10)
    nvgStrokeColor(ctx, nvgRGBA(80, 60, 150, 60))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 通道刻度
    for i = 1, NUM_LANES do
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

    -- 滑块
    local handleY = bartender.y
    local handleW = tw - 8
    local handleH = 14

    RoundRect(ctx, cx - handleW / 2, handleY - handleH / 2, handleW, handleH, 4, 0, 200, 220, 220)
    -- 发光
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, cx - handleW / 2 - 2, handleY - handleH / 2 - 2, handleW + 4, handleH + 4, 5)
    nvgStrokeColor(ctx, nvgRGBA(0, 255, 255, moveDrag.active and 120 or 40))
    nvgStrokeWidth(ctx, 3)
    nvgStroke(ctx)
end

-- ============================================================================
-- 排行榜绘制
-- ============================================================================
function DrawLeaderboard(ctx, panelX, panelY, panelW, panelH)
    local pad = 8
    local headerH = 24
    local rowH = 20
    local cx = panelX + panelW / 2

    -- 标题
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 14)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 200, 40, 255))
    nvgText(ctx, cx, panelY + headerH / 2 + 2, "LEADERBOARD", nil)

    -- 分隔线
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, panelX + pad, panelY + headerH)
    nvgLineTo(ctx, panelX + panelW - pad, panelY + headerH)
    nvgStrokeColor(ctx, nvgRGBA(255, 200, 40, 80))
    nvgStrokeWidth(ctx, 1)
    nvgStroke(ctx)

    if leaderboardLoading then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(180, 180, 220, 180))
        nvgText(ctx, cx, panelY + headerH + 30, "加载中...", nil)
        return
    end

    if #leaderboard == 0 then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(180, 180, 220, 180))
        nvgText(ctx, cx, panelY + headerH + 30, "暂无数据", nil)
        return
    end

    -- 列表
    local maxRows = math.min(#leaderboard, math.floor((panelH - headerH - 30) / rowH))
    for i = 1, maxRows do
        local entry = leaderboard[i]
        local ry = panelY + headerH + 6 + (i - 1) * rowH

        -- 高亮自己
        if entry.isMe then
            RoundRect(ctx, panelX + pad - 2, ry - 1, panelW - pad * 2 + 4, rowH - 2, 3, 0, 255, 255, 30)
        end

        -- 排名颜色
        local rr, rg, rb = 180, 180, 220
        if i == 1 then rr, rg, rb = 255, 215, 0
        elseif i == 2 then rr, rg, rb = 200, 200, 210
        elseif i == 3 then rr, rg, rb = 205, 127, 50
        end

        nvgFontSize(ctx, 12)
        -- 排名
        nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(rr, rg, rb, 255))
        nvgText(ctx, panelX + pad + 2, ry + rowH / 2, "#" .. i, nil)

        -- 昵称（截断）
        local nameColor = entry.isMe and {0, 255, 255} or {220, 220, 240}
        nvgFillColor(ctx, nvgRGBA(nameColor[1], nameColor[2], nameColor[3], 255))
        local displayName = entry.nickname or "..."
        if #displayName > 18 then
            displayName = string.sub(displayName, 1, 16) .. ".."
        end
        nvgText(ctx, panelX + pad + 28, ry + rowH / 2, displayName, nil)

        -- 分数
        nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(255, 255, 255, 255))
        nvgText(ctx, panelX + panelW - pad - 2, ry + rowH / 2, tostring(entry.score), nil)
    end

    -- 我的排名（底部）
    if myRank then
        local footerY = panelY + panelH - 18
        nvgFontSize(ctx, 10)
        nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 180))
        local rankText = "我的排名: #" .. myRank
        if leaderboardTotal > 0 then
            rankText = rankText .. " / " .. leaderboardTotal .. "人"
        end
        nvgText(ctx, cx, footerY, rankText, nil)
    end
end

-- ============================================================================
-- 主菜单 (赛博霓虹风)
-- ============================================================================
function DrawMenu(ctx)
    -- 半透明遮罩
    RoundRect(ctx, 0, 0, logicalW, logicalH, 0, 0, 0, 0, 180)

    local cx, cy = logicalW / 2, logicalH / 2
    local totalW = math.min(600, logicalW * 0.90)
    local totalH = math.min(280, logicalH * 0.82)
    local startX = cx - totalW / 2
    local startY = cy - totalH / 2

    -- 左侧：游戏信息面板
    local leftW = totalW * 0.55
    local leftX = startX
    RoundRect(ctx, leftX, startY, leftW, totalH, 8, 12, 8, 28, 240)
    NeonStroke(ctx, leftX, startY, leftW, totalH, 8, 0, 255, 255, 200, 2)

    local leftCx = leftX + leftW / 2
    nvgFontFace(ctx, "sans")
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题
    nvgFontSize(ctx, 28)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, 255))
    nvgText(ctx, leftCx, startY + 36, "666，居然还有第六关？", nil)

    -- 副标题
    nvgFontSize(ctx, 13)
    nvgFillColor(ctx, nvgRGBA(255, 50, 200, 200))
    nvgText(ctx, leftCx, startY + 62, "since 1983", nil)

    -- 操作说明
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(180, 180, 220, 200))
    nvgText(ctx, leftCx, startY + totalH * 0.42, "上/下 移动酒保", nil)
    nvgText(ctx, leftCx, startY + totalH * 0.42 + 18, "1-6 发送饮料 | 触屏：点击右侧按钮", nil)
    nvgText(ctx, leftCx, startY + totalH * 0.42 + 36, "触屏：拖动左侧轨道移动", nil)

    -- 开始提示
    local blink = math.sin(time * 4) * 0.5 + 0.5
    nvgFontSize(ctx, 18)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, math.floor(100 + blink * 155)))
    nvgText(ctx, leftCx, startY + totalH - 50, "点击开始", nil)

    if highScore > 0 then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(255, 50, 200, 200))
        nvgText(ctx, leftCx, startY + totalH - 28, "最高分: " .. highScore, nil)
    end

    -- 右侧：排行榜面板
    local gap = 8
    local rightW = totalW - leftW - gap
    local rightX = leftX + leftW + gap
    RoundRect(ctx, rightX, startY, rightW, totalH, 8, 12, 8, 28, 240)
    NeonStroke(ctx, rightX, startY, rightW, totalH, 8, 255, 200, 40, 150, 1.5)

    DrawLeaderboard(ctx, rightX, startY, rightW, totalH)
end

-- ============================================================================
-- 游戏结束画面
-- ============================================================================
function DrawGameOver(ctx)
    RoundRect(ctx, 0, 0, logicalW, logicalH, 0, 0, 0, 0, 200)

    local cx, cy = logicalW / 2, logicalH / 2
    local totalW = math.min(600, logicalW * 0.90)
    local totalH = math.min(280, logicalH * 0.82)
    local startX = cx - totalW / 2
    local startY = cy - totalH / 2

    local titleText
    local titleR, titleG, titleB
    if gameWin then
        titleText = "666，居然过了第六关！"
        titleR, titleG, titleB = 0, 255, 200
    elseif level >= MAX_LEVEL then
        titleText = "666，居然没过第六关。"
        titleR, titleG, titleB = 255, 200, 50
    else
        titleText = "666，居然都没到第六关？"
        titleR, titleG, titleB = 255, 50, 80
    end

    -- 左侧：结算信息面板
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
    nvgText(ctx, leftCx, startY + 76, "得分: " .. score, nil)

    if score >= highScore and score > 0 then
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 255))
        nvgText(ctx, leftCx, startY + 104, "** 新纪录！ **", nil)
    else
        nvgFontSize(ctx, 14)
        nvgFillColor(ctx, nvgRGBA(180, 180, 220, 200))
        nvgText(ctx, leftCx, startY + 104, "最高分: " .. highScore, nil)
    end

    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, nvgRGBA(120, 100, 180, 200))
    nvgText(ctx, leftCx, startY + 134, "关卡:" .. level .. " 已服务:" .. totalServed .. " 最佳连击:" .. bestCombo, nil)

    -- 我的云端排名
    if myRank then
        nvgFontSize(ctx, 12)
        nvgFillColor(ctx, nvgRGBA(0, 255, 255, 200))
        local rankInfo = "全球排名: #" .. myRank
        if leaderboardTotal > 0 then
            rankInfo = rankInfo .. " / " .. leaderboardTotal .. "人"
        end
        nvgText(ctx, leftCx, startY + 160, rankInfo, nil)
    end

    local blink = math.sin(time * 4) * 0.5 + 0.5
    nvgFontSize(ctx, 16)
    nvgFillColor(ctx, nvgRGBA(0, 255, 255, math.floor(100 + blink * 155)))
    nvgText(ctx, leftCx, startY + totalH - 36, "再来一局？", nil)

    -- 右侧：排行榜面板
    local gap = 8
    local rightW = totalW - leftW - gap
    local rightX = leftX + leftW + gap
    RoundRect(ctx, rightX, startY, rightW, totalH, 8, 12, 8, 28, 240)
    NeonStroke(ctx, rightX, startY, rightW, totalH, 8, 255, 200, 40, 150, 1.5)

    DrawLeaderboard(ctx, rightX, startY, rightW, totalH)
end

-- ============================================================================
-- 工具
-- ============================================================================
function HSVtoRGB(h, s, v)
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
