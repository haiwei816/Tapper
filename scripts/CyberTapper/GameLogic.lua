-- ============================================================================
-- GameLogic.lua - 游戏核心逻辑（更新、碰撞、实体管理、粒子、浮动文字）
-- ============================================================================

local Config = require "CyberTapper.Config"
local G = require "CyberTapper.State"

local Logic = {}

-- ============================================================================
-- 辅助函数
-- ============================================================================

local function GetPatience()
    return math.max(6, Config.BASE_PATIENCE * (1 / (1 + (G.level - 1) * 0.1)))
end
Logic.GetPatience = GetPatience

local function GetSpawnInterval()
    return math.max(0.8, Config.BASE_SPAWN_INTERVAL * (1 / (1 + (G.level - 1) * 0.15)))
end

local function GetLaneActiveCount(lane)
    local count = 0
    for _, c in ipairs(G.customers) do
        if c.lane == lane and c.servedAnim <= 0 then count = count + 1 end
    end
    return count
end

local function ShuffleArray(arr)
    local n = #arr
    for i = n, 2, -1 do
        local j = math.random(1, i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return arr
end

-- ============================================================================
-- 粒子与浮动文字
-- ============================================================================

local function CreateServeParticles(x, y, drinkType)
    local dt = Config.DRINK_TYPES[drinkType]
    for _ = 1, 10 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 100
        table.insert(G.particles, {
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

local function UpdateParticles(dt)
    for i = #G.particles, 1, -1 do
        local p = G.particles[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 80 * dt
        if p.life <= 0 then
            table.remove(G.particles, i)
        end
    end
end

local function AddFloatText(text, x, y, r, g, b)
    table.insert(G.floatTexts, {
        text = text, x = x, y = y,
        r = r, g = g, b = b,
        life = 1.2, maxLife = 1.2,
    })
end

local function UpdateFloatTexts(dt)
    for i = #G.floatTexts, 1, -1 do
        local ft = G.floatTexts[i]
        ft.life = ft.life - dt
        ft.y = ft.y - 40 * dt
        if ft.life <= 0 then
            table.remove(G.floatTexts, i)
        end
    end
end

-- ============================================================================
-- 生命与结算
-- ============================================================================

local function GameOver()
    G.gameState = "gameover"
    G.gameWin = false
    G.PlaySfx(G.sfxGameOver, 0.8)
    if G.score > G.highScore then
        G.highScore = G.score
    end
    G.UploadHighScore(G.score)
end

local function GameWin()
    G.gameState = "gameover"
    G.gameWin = true
    G.PlaySfx(G.sfxGameWin, 0.8)
    if G.score > G.highScore then
        G.highScore = G.score
    end
    G.UploadHighScore(G.score)
end

local function LoseLife()
    G.lives = G.lives - 1
    G.combo = 0
    if G.lives <= 0 then
        GameOver()
    end
end

-- ============================================================================
-- 生成顾客
-- ============================================================================

local function SpawnCustomer()
    local lane = math.random(1, Config.NUM_LANES)
    if GetLaneActiveCount(lane) >= 6 then
        local found = false
        for tryLane = 1, Config.NUM_LANES do
            if GetLaneActiveCount(tryLane) < 6 then
                lane = tryLane
                found = true
                break
            end
        end
        if not found then return end
    end

    local maxType = math.min(#Config.DRINK_TYPES, G.level)
    local drinkType = math.random(1, maxType)
    local drinksNeeded = 1
    if G.level >= 2 and math.random() < 0.3 then drinksNeeded = 2 end
    if G.level >= 4 and math.random() < 0.2 then drinksNeeded = 3 end

    local posInQueue = GetLaneActiveCount(lane)
    local targetX = G.layout.counterRight - 40 - posInQueue * Config.QUEUE_SPACING
    local colorIdx = math.random(1, #Config.CUSTOMER_COLORS)
    local cc = Config.CUSTOMER_COLORS[colorIdx]

    table.insert(G.customers, {
        lane = lane,
        x = G.layout.counterLeft - 30,
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

local function SpawnBoss()
    local lane = math.random(1, Config.NUM_LANES)
    local posInQueue = GetLaneActiveCount(lane)
    local targetX = G.layout.counterRight - 40 - posInQueue * Config.QUEUE_SPACING

    local seq = {1, 2, 3, 4, 5, 6}
    ShuffleArray(seq)

    table.insert(G.customers, {
        lane = lane,
        x = G.layout.counterLeft - 30,
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
        isBoss = true,
        drinkSequence = seq,
        sequenceIndex = 1,
    })
end

-- ============================================================================
-- 队列重排
-- ============================================================================

local function RecalcLaneQueues()
    for lane = 1, Config.NUM_LANES do
        local laneCustomers = {}
        for _, c in ipairs(G.customers) do
            if c.lane == lane and c.servedAnim <= 0 then
                table.insert(laneCustomers, c)
            end
        end
        table.sort(laneCustomers, function(a, b) return a.x > b.x end)
        for idx, c in ipairs(laneCustomers) do
            c.targetX = G.layout.counterRight - 40 - (idx - 1) * Config.QUEUE_SPACING
        end
    end
end

-- ============================================================================
-- 实体更新
-- ============================================================================

local function UpdateCustomers(dt)
    RecalcLaneQueues()
    for i = #G.customers, 1, -1 do
        local c = G.customers[i]
        if c.angryTimer and c.angryTimer > 0 then
            c.angryTimer = c.angryTimer - dt
        end
        if c.sipAnim and c.sipAnim > 0 then
            c.sipAnim = c.sipAnim - dt
            if c.sipAnim <= 0 and c.exitAfterSip then
                table.insert(G.emptyBottles, {
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
            if c.servedAnim <= 0 or c.x < G.layout.counterLeft - 40 then
                table.remove(G.customers, i)
            end
        elseif c.sipAnim and c.sipAnim > 0 then
            c.bobPhase = c.bobPhase + dt * 2
        else
            if c.targetX and math.abs(c.x - c.targetX) > 2 then
                if c.x < c.targetX then
                    c.x = math.min(c.x + Config.CUSTOMER_WALK_SPEED * dt, c.targetX)
                else
                    c.x = math.max(c.x - Config.CUSTOMER_WALK_SPEED * dt, c.targetX)
                end
                c.bobPhase = c.bobPhase + dt * 4
            else
                if c.targetX then c.x = c.targetX end
                c.bobPhase = c.bobPhase + dt * 2
                c.waitTime = (c.waitTime or 0) + dt
                local patience = GetPatience()
                if c.isBoss then patience = patience * 3 end
                if c.waitTime >= patience then
                    G.PlaySfx(G.sfxAngry, 0.7)
                    if c.isBoss then
                        for _ = 1, 3 do LoseLife() end
                    else
                        LoseLife()
                    end
                    G.shakeTimer = 0.3
                    G.shakeIntensity = c.isBoss and 8 or 4
                    local angryText = c.isBoss and "BOSS ANGRY! -3" or "ANGRY!"
                    AddFloatText(angryText, c.x, G.GetLaneY(c.lane) + G.layout.customerOffsetY - 25, 255, 80, 50)
                    table.remove(G.customers, i)
                end
            end
        end
    end
end

local function UpdateDrinks(dt)
    local layout = G.layout
    local bartender = G.bartender

    for i = #G.drinks, 1, -1 do
        local d = G.drinks[i]
        d.x = d.x - Config.DRINK_SPEED * dt
        d.trailTimer = d.trailTimer + dt
        local serveY = G.GetLaneY(d.lane)
        local serveDt = Config.DRINK_TYPES[d.drinkType]

        local hitCustomer = nil
        local hitX = -1
        for _, c in ipairs(G.customers) do
            local isSipping = c.sipAnim and c.sipAnim > 0
            local canHit = c.lane == d.lane and c.servedAnim <= 0
                and (not isSipping or not c.exitAfterSip)
            if canHit and c.x > hitX then
                hitX = c.x
                hitCustomer = c
            end
        end

        if hitCustomer and d.x <= hitCustomer.x + 8 then
            if hitCustomer.drinkType == d.drinkType then
                hitCustomer.drinksReceived = (hitCustomer.drinksReceived or 0) + 1
                G.totalServed = G.totalServed + 1
                G.combo = G.combo + 1
                if G.combo > G.bestCombo then G.bestCombo = G.combo end
                local points = 10 * G.level + G.combo * 5
                if hitCustomer.isBoss then points = points + 20 end
                G.score = G.score + points
                local remaining = (hitCustomer.drinksNeeded or 1) - hitCustomer.drinksReceived
                local custY = serveY + layout.customerOffsetY
                G.PlaySfx(G.sfxSip, 0.5)
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
                    hitCustomer.exitAfterSip = false
                    hitCustomer.waitTime = math.max(0, (hitCustomer.waitTime or 0) - 4)
                    AddFloatText("+" .. points, hitCustomer.x, custY - 20, 0, 255, 255)
                    if hitCustomer.isBoss and hitCustomer.drinkSequence then
                        hitCustomer.sequenceIndex = hitCustomer.sequenceIndex + 1
                        hitCustomer.drinkType = hitCustomer.drinkSequence[hitCustomer.sequenceIndex]
                        AddFloatText(remaining .. " LEFT", hitCustomer.x, custY - 45, 255, 160, 40)
                    end
                end
                if G.combo > 1 then
                    AddFloatText("x" .. G.combo .. " COMBO!", hitCustomer.x, custY - 40, 255, 255, 60)
                end
                CreateServeParticles(hitCustomer.x, serveY, d.drinkType)
                G.levelServed = G.levelServed + 1
                local target = (G.level == Config.MAX_LEVEL) and Config.SERVES_LEVEL6 or Config.SERVES_PER_LEVEL
                if G.levelServed >= target then
                    if G.level < Config.MAX_LEVEL then
                        G.level = G.level + 1
                        G.levelServed = 0
                        AddFloatText("LEVEL " .. G.level .. "!", G.logicalW / 2, G.logicalH / 2 - 30, 255, 255, 60)
                        if G.level == Config.MAX_LEVEL then
                            SpawnBoss()
                        end
                    else
                        GameWin()
                    end
                end
            else
                if not hitCustomer.wrongHitThisFrame then
                    hitCustomer.wrongHitThisFrame = true
                    hitCustomer.servedAnim = 0.8
                    hitCustomer.angryTimer = 0.6
                    G.PlaySfx(G.sfxAngry, 0.7)
                    if hitCustomer.isBoss then
                        for _ = 1, 3 do LoseLife() end
                    else
                        LoseLife()
                    end
                    G.combo = 0
                    G.shakeTimer = 0.3
                    G.shakeIntensity = hitCustomer.isBoss and 8 or 4
                    local wrongText = hitCustomer.isBoss and "WRONG! -3" or "WRONG!"
                    AddFloatText(wrongText, hitCustomer.x, serveY + layout.customerOffsetY - 20, 255, 60, 60)
                end
            end
            table.remove(G.drinks, i)
        elseif d.x <= layout.bartenderX_left + 15 then
            if bartender.lane == d.lane and bartender.leftDrinkAnim <= 0 then
                local points = 3
                G.score = G.score + points
                AddFloatText("CATCH +" .. points, layout.bartenderX_left, serveY - 20, 200, 255, 200)
                bartender.serveAnim = 0.5
                bartender.leftDrinkAnim = 1.0
                bartender.leftDrinkType = d.drinkType
                table.remove(G.drinks, i)
            elseif d.x < layout.counterLeft - 40 then
                G.PlaySfx(G.sfxGlassBreak, 0.7)
                LoseLife()
                G.combo = 0
                G.shakeTimer = 0.3
                G.shakeIntensity = 4
                AddFloatText("MISS!", layout.counterLeft + 10, serveY - 20, 255, 100, 50)
                table.remove(G.drinks, i)
            end
        end
    end
end

local function UpdateEmptyBottles(dt)
    local layout = G.layout
    local bartender = G.bartender

    for i = #G.emptyBottles, 1, -1 do
        local b = G.emptyBottles[i]
        b.x = b.x - Config.BOTTLE_RETURN_SPEED * dt
        b.trailTimer = b.trailTimer + dt
        if b.x <= layout.bartenderX_left + 15 then
            if bartender.lane == b.lane then
                local points = 5
                G.score = G.score + points
                AddFloatText("CATCH +" .. points, layout.bartenderX_left, G.GetLaneY(b.lane) - 20, 200, 255, 200)
                bartender.serveAnim = 0.5
                table.remove(G.emptyBottles, i)
            elseif b.x < layout.counterLeft - 40 then
                G.PlaySfx(G.sfxGlassBreak, 0.7)
                LoseLife()
                G.combo = 0
                G.shakeTimer = 0.3
                G.shakeIntensity = 4
                AddFloatText("MISS!", layout.counterLeft - 10, G.GetLaneY(b.lane) - 20, 255, 100, 50)
                table.remove(G.emptyBottles, i)
            end
        end
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

function Logic.ServeDrink(drinkType)
    if G.gameState ~= "playing" then return end
    if drinkType < 1 or drinkType > #Config.DRINK_TYPES then return end
    local unlockedCount = math.min(#Config.DRINK_TYPES, G.level)
    if drinkType > unlockedCount then return end
    G.PlaySfx(G.sfxServe, 0.6)
    G.bartender.serveAnim = 1.0
    table.insert(G.drinks, {
        lane = G.bartender.lane,
        x = G.layout.bartenderX_right - 10,
        drinkType = drinkType,
        trailTimer = 0,
    })
    local serveDt = Config.DRINK_TYPES[drinkType]
    local serveY = G.GetLaneY(G.bartender.lane)
    for _ = 1, 5 do
        table.insert(G.particles, {
            x = G.layout.bartenderX_right,
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

function Logic.MoveBartender(delta)
    local newLane = G.bartender.targetLane + delta
    if newLane >= 1 and newLane <= Config.NUM_LANES then
        G.bartender.targetLane = newLane
    end
end

function Logic.ResetGame()
    G.customers = {}
    G.drinks = {}
    G.emptyBottles = {}
    G.particles = {}
    G.floatTexts = {}
    G.score = 0
    G.lives = Config.MAX_LIVES
    G.level = 1
    G.totalServed = 0
    G.levelServed = 0
    G.combo = 0
    G.bestCombo = 0
    G.spawnTimer = 0
    G.bartender.lane = 2
    G.bartender.targetLane = 2
    G.bartender.y = G.GetLaneY(2)
    G.bartender.serveAnim = 0
    G.bartender.leftDrinkAnim = 0
    G.bartender.leftDrinkType = nil
    G.shakeTimer = 0
    G.gameWin = false
    G.gameState = "playing"
end

function Logic.UpdateGame(dt)
    -- 每帧重置顾客的错误命中标记
    for _, c in ipairs(G.customers) do
        c.wrongHitThisFrame = false
    end

    local bartender = G.bartender
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

    G.spawnTimer = G.spawnTimer + dt
    if G.spawnTimer >= GetSpawnInterval() then
        G.spawnTimer = 0
        SpawnCustomer()
    end

    UpdateCustomers(dt)
    UpdateDrinks(dt)
    UpdateEmptyBottles(dt)
    UpdateParticles(dt)
    UpdateFloatTexts(dt)
end

return Logic
