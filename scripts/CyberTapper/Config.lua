-- ============================================================================
-- Config.lua - 游戏常量配置
-- ============================================================================

local Config = {}

-- 赛博朋克霓虹调色板
Config.PAL = {
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

-- 游戏参数
Config.NUM_LANES = 4
Config.DRINK_SPEED = 220
Config.BOTTLE_RETURN_SPEED = 180
Config.CUSTOMER_WALK_SPEED = 120
Config.QUEUE_SPACING = 32
Config.BASE_SPAWN_INTERVAL = 2.8
Config.BASE_PATIENCE = 14
Config.BARTENDER_MOVE_TIME = 0.12
Config.MAX_LIVES = 3
Config.SERVES_PER_LEVEL = 16
Config.SERVES_LEVEL6 = 36
Config.MAX_LEVEL = 6

-- 饮料类型
Config.DRINK_TYPES = {
    { name = "Neon Ale",    r = 0,   g = 255, b = 255, key = "1", icon = "I" },
    { name = "Plasma",      r = 255, g = 50,  b = 200, key = "2", icon = "II" },
    { name = "Dark Matter", r = 180, g = 80,  b = 255, key = "3", icon = "III" },
    { name = "Solar Flare", r = 255, g = 200, b = 40,  key = "4", icon = "IV" },
    { name = "Acid Rain",   r = 50,  g = 255, b = 120, key = "5", icon = "V" },
    { name = "Lava Flow",   r = 255, g = 100, b = 30,  key = "6", icon = "VI" },
}

-- 顾客颜色
Config.CUSTOMER_COLORS = {
    {0, 220, 255},
    {255, 60, 200},
    {180, 80, 255},
    {255, 200, 40},
    {50, 255, 120},
    {255, 100, 60},
    {100, 200, 255},
    {255, 150, 200},
}

return Config
