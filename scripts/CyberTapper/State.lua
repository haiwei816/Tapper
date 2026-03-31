-- ============================================================================
-- State.lua - 共享游戏状态 G 表 + 分辨率/布局计算
-- ============================================================================

local Config = require "CyberTapper.Config"

local G = {
    -- === 分辨率 (Mode B: 系统逻辑分辨率) ===
    vg = nil,
    fontNormal = -1,
    physW = 0, physH = 0,
    dpr = 1.0,
    logicalW = 0, logicalH = 0,

    -- === 游戏状态 ===
    gameState = "menu",
    gameWin = false,
    time = 0,
    score = 0,
    highScore = 0,
    lives = Config.MAX_LIVES,
    level = 1,
    totalServed = 0,
    combo = 0,
    bestCombo = 0,
    levelServed = 0,
    shakeTimer = 0,
    shakeIntensity = 0,
    spawnTimer = 0,

    -- === 实体 ===
    bartender = {
        lane = 2, targetLane = 2, y = 0,
        animTime = 0, serveAnim = 0,
        leftDrinkAnim = 0, leftDrinkType = nil,
    },
    customers = {},
    drinks = {},
    emptyBottles = {},
    particles = {},
    floatTexts = {},

    -- === 布局 ===
    layout = {
        laneY = {}, laneH = 0,
        counterLeft = 0, counterRight = 0, counterW = 0,
        bartenderX_right = 0, bartenderX_left = 0,
        drinkBtnX = 0, drinkBtnW = 0, drinkBtnH = 0,
        drinkBtnSpacing = 0, drinkBtnStartY = 0,
        moveTrackX = 0, moveTrackW = 0, moveTrackY = 0, moveTrackH = 0,
        customerOffsetY = 0,
        safeOffsetX = 0, safeW = 0,
        volSliderX = 0, volSliderY = 0, volSliderW = 0, volSliderH = 0,
        masterSliderX = 0, masterSliderY = 0, masterSliderW = 0, masterSliderH = 0,
    },

    -- === 输入/拖拽状态 ===
    moveDrag   = { active = false, touchId = -1 },
    volumeDrag = { active = false, touchId = -1 },
    masterDrag = { active = false, touchId = -1 },

    -- === 音频引用 (main.lua 中设置) ===
    bgmNode = nil, bgmSource = nil,
    bgmVolume = 0.3, masterVolume = 0.8,
    sfxServe = nil, sfxGlassBreak = nil,
    sfxAngry = nil, sfxSip = nil,
    sfxGameOver = nil, sfxGameWin = nil,

    -- === 排行榜 ===
    leaderboard = {},
    leaderboardLoading = false,
    leaderboardLoaded = false,
    myCloudHighScore = 0,
    myRank = nil,
    leaderboardTotal = 0,

    -- === 跨模块函数槽 (main.lua 中注入实际实现) ===
    PlaySfx = function() end,
    ApplyBgmGain = function() end,
    UploadHighScore = function() end,
    FetchLeaderboard = function() end,
}

-- ============================================================================
-- 分辨率计算
-- ============================================================================
function G.RecalcResolution()
    G.physW = graphics:GetWidth()
    G.physH = graphics:GetHeight()
    G.dpr = graphics:GetDPR()
    G.logicalW = G.physW / G.dpr
    G.logicalH = G.physH / G.dpr
end

-- ============================================================================
-- 布局计算
-- ============================================================================
function G.RecalcLayout()
    local logicalW = G.logicalW
    local logicalH = G.logicalH
    local layout = G.layout

    local topMargin = logicalH * 0.14
    local bottomMargin = logicalH * 0.08
    local gameAreaH = logicalH - topMargin - bottomMargin
    local laneSpacing = gameAreaH / Config.NUM_LANES

    layout.laneH = laneSpacing * 0.50

    local maxAspect = 18 / 9
    local maxGameW = logicalH * maxAspect
    local safeW = math.min(logicalW, maxGameW)
    local safeOffsetX = (logicalW - safeW) / 2

    layout.safeOffsetX = safeOffsetX
    layout.safeW = safeW

    local sideBtnW = math.max(44, safeW * 0.10)

    layout.counterLeft = safeOffsetX + sideBtnW + safeW * 0.04
    layout.counterRight = safeOffsetX + safeW - sideBtnW - safeW * 0.04
    layout.counterW = layout.counterRight - layout.counterLeft
    layout.bartenderX_right = layout.counterRight + safeW * 0.02
    layout.bartenderX_left = layout.counterLeft - safeW * 0.02

    for i = 1, Config.NUM_LANES do
        layout.laneY[i] = topMargin + (i - 0.5) * laneSpacing
    end

    layout.drinkBtnW = sideBtnW
    layout.drinkBtnH = math.min(logicalH * 0.08, 42)
    layout.drinkBtnSpacing = 3
    layout.drinkBtnX = safeOffsetX + safeW - sideBtnW - 4
    local unlockedCount = math.min(#Config.DRINK_TYPES, G.level)
    local totalDrinkH = unlockedCount * layout.drinkBtnH + (unlockedCount - 1) * layout.drinkBtnSpacing
    layout.drinkBtnStartY = topMargin + (gameAreaH - totalDrinkH) / 2

    layout.moveTrackW = sideBtnW
    layout.moveTrackX = safeOffsetX + 4
    layout.moveTrackY = topMargin + laneSpacing * 0.2
    layout.moveTrackH = gameAreaH - laneSpacing * 0.4

    layout.customerOffsetY = -layout.laneH * 0.12

    layout.volSliderW = math.max(56, safeW * 0.09)
    layout.volSliderH = 6
    layout.volSliderX = safeOffsetX + 10
    layout.volSliderY = 44

    layout.masterSliderW = layout.volSliderW
    layout.masterSliderH = 6
    layout.masterSliderX = safeOffsetX + safeW - layout.masterSliderW - 10
    layout.masterSliderY = 44
end

-- ============================================================================
-- 通道辅助函数
-- ============================================================================
function G.GetLaneY(lane)
    return G.layout.laneY[lane] or G.layout.laneY[1]
end

function G.GetClosestLaneFromY(y)
    local closest = 1
    local minDist = math.huge
    for i = 1, Config.NUM_LANES do
        local dist = math.abs(y - G.layout.laneY[i])
        if dist < minDist then
            minDist = dist
            closest = i
        end
    end
    return closest
end

return G
