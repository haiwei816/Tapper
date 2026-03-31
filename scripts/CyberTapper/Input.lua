-- ============================================================================
-- Input.lua - 键盘/鼠标/触屏输入处理
-- ============================================================================

local Config = require "CyberTapper.Config"
local G = require "CyberTapper.State"
local Logic = require "CyberTapper.GameLogic"

local Input = {}

-- ============================================================================
-- 辅助：区域命中检测
-- ============================================================================

local function IsInVolumeSlider(x, y)
    local pad = 12
    local L = G.layout
    return x >= L.volSliderX - pad
       and x <= L.volSliderX + L.volSliderW + pad
       and y >= L.volSliderY - pad
       and y <= L.volSliderY + L.volSliderH + pad
end

local function IsInMasterSlider(x, y)
    local pad = 12
    local L = G.layout
    return x >= L.masterSliderX - pad
       and x <= L.masterSliderX + L.masterSliderW + pad
       and y >= L.masterSliderY - pad
       and y <= L.masterSliderY + L.masterSliderH + pad
end

local function IsInMoveTrack(x, y)
    local L = G.layout
    return x >= L.moveTrackX
       and x <= L.moveTrackX + L.moveTrackW
       and y >= L.moveTrackY - 20
       and y <= L.moveTrackY + L.moveTrackH + 20
end

-- ============================================================================
-- 拖拽操作
-- ============================================================================

local function DragVolume(x)
    local ratio = (x - G.layout.volSliderX) / G.layout.volSliderW
    G.bgmVolume = math.max(0, math.min(1, ratio))
    G.ApplyBgmGain()
end

local function DragMasterVolume(x)
    local ratio = (x - G.layout.masterSliderX) / G.layout.masterSliderW
    G.masterVolume = math.max(0, math.min(1, ratio))
    G.ApplyBgmGain()
end

local function DragMoveBartender(y)
    local minY = G.layout.laneY[1]
    local maxY = G.layout.laneY[Config.NUM_LANES]
    G.bartender.y = math.max(minY, math.min(maxY, y))
    G.bartender.targetLane = G.GetClosestLaneFromY(G.bartender.y)
end

-- ============================================================================
-- 指针点击处理（鼠标/触屏共用）
-- ============================================================================

local function ProcessPointerInput(x, y)
    if G.gameState == "menu" then Logic.ResetGame(); return end
    if G.gameState == "gameover" then Logic.ResetGame(); return end
    if G.gameState ~= "playing" then return end

    local unlockedCount = math.min(#Config.DRINK_TYPES, G.level)
    local L = G.layout

    if x >= L.drinkBtnX then
        local totalH = unlockedCount * L.drinkBtnH + (unlockedCount - 1) * L.drinkBtnSpacing
        local areaTop = L.drinkBtnStartY - L.drinkBtnSpacing
        local areaBot = L.drinkBtnStartY + totalH + L.drinkBtnSpacing
        if y >= areaTop and y <= areaBot and unlockedCount > 0 then
            local bestIdx = 1
            local bestDist = math.huge
            for i = 1, unlockedCount do
                local by = L.drinkBtnStartY + (i - 1) * (L.drinkBtnH + L.drinkBtnSpacing)
                local btnCenterY = by + L.drinkBtnH / 2
                local dist = math.abs(y - btnCenterY)
                if dist < bestDist then
                    bestDist = dist
                    bestIdx = i
                end
            end
            Logic.ServeDrink(bestIdx)
            return
        end
    end

    for i = 1, Config.NUM_LANES do
        local ly = G.GetLaneY(i)
        if math.abs(y - ly) < G.layout.laneH * 0.8 then
            G.bartender.targetLane = i
            return
        end
    end
end

-- ============================================================================
-- Update 中的拖拽持续处理
-- ============================================================================

function Input.UpdateDrags(dt)
    if G.volumeDrag.active and G.volumeDrag.touchId == -1 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local mx = input.mousePosition.x / G.dpr
            DragVolume(mx)
        else
            G.volumeDrag.active = false
        end
    end

    if G.masterDrag.active and G.masterDrag.touchId == -1 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local mx = input.mousePosition.x / G.dpr
            DragMasterVolume(mx)
        else
            G.masterDrag.active = false
        end
    end

    if G.moveDrag.active and G.moveDrag.touchId == -1 then
        if input:GetMouseButtonDown(MOUSEB_LEFT) then
            local my = input.mousePosition.y / G.dpr
            DragMoveBartender(my)
        else
            G.moveDrag.active = false
        end
    end
end

-- ============================================================================
-- 酒保平滑移动（每帧调用）
-- ============================================================================

function Input.UpdateBartenderMovement(dt)
    local bartender = G.bartender
    if not G.moveDrag.active and #G.layout.laneY > 0 then
        local targetY = G.GetLaneY(bartender.targetLane)
        local diff = targetY - bartender.y
        if math.abs(diff) > 0.5 then
            bartender.y = bartender.y + diff * math.min(1.0, dt * 18)
        else
            bartender.y = targetY
        end
    end
    if #G.layout.laneY > 0 then
        bartender.lane = G.GetClosestLaneFromY(bartender.y)
    end
end

-- ============================================================================
-- 事件处理函数（供 main.lua 中注册）
-- ============================================================================

---@param eventType string
---@param eventData KeyDownEventData
function Input.HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    if G.gameState == "menu" then
        if key == KEY_SPACE or key == KEY_RETURN then Logic.ResetGame() end
    elseif G.gameState == "playing" then
        if key == KEY_UP or key == KEY_W then Logic.MoveBartender(-1)
        elseif key == KEY_DOWN or key == KEY_S then Logic.MoveBartender(1)
        elseif key == KEY_1 or key == KEY_Z then Logic.ServeDrink(1)
        elseif key == KEY_2 or key == KEY_X then Logic.ServeDrink(2)
        elseif key == KEY_3 or key == KEY_C then Logic.ServeDrink(3)
        elseif key == KEY_4 then Logic.ServeDrink(4)
        elseif key == KEY_5 then Logic.ServeDrink(5)
        elseif key == KEY_6 then Logic.ServeDrink(6)
        end
    elseif G.gameState == "gameover" then
        if key == KEY_SPACE or key == KEY_RETURN then Logic.ResetGame() end
    end
end

function Input.HandleMouseClick(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    if input.numTouches > 0 then return end
    local mx = eventData["X"]:GetInt() / G.dpr
    local my = eventData["Y"]:GetInt() / G.dpr
    if G.gameState == "playing" and IsInVolumeSlider(mx, my) then
        G.volumeDrag.active = true
        G.volumeDrag.touchId = -1
        DragVolume(mx)
        return
    end
    if G.gameState == "playing" and IsInMasterSlider(mx, my) then
        G.masterDrag.active = true
        G.masterDrag.touchId = -1
        DragMasterVolume(mx)
        return
    end
    if G.gameState == "playing" and IsInMoveTrack(mx, my) then
        G.moveDrag.active = true
        G.moveDrag.touchId = -1
        DragMoveBartender(my)
        return
    end
    ProcessPointerInput(mx, my)
end

function Input.HandleMouseUp(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    if input.numTouches > 0 then return end
    if G.volumeDrag.active and G.volumeDrag.touchId == -1 then
        G.volumeDrag.active = false
    end
    if G.masterDrag.active and G.masterDrag.touchId == -1 then
        G.masterDrag.active = false
    end
    if G.moveDrag.active and G.moveDrag.touchId == -1 then
        G.moveDrag.active = false
    end
end

function Input.HandleTouchBegin(eventType, eventData)
    local tx = eventData["X"]:GetInt() / G.dpr
    local ty = eventData["Y"]:GetInt() / G.dpr
    local touchId = eventData["TouchID"]:GetInt()
    if G.gameState == "playing" and IsInVolumeSlider(tx, ty) then
        G.volumeDrag.active = true
        G.volumeDrag.touchId = touchId
        DragVolume(tx)
        return
    end
    if G.gameState == "playing" and IsInMasterSlider(tx, ty) then
        G.masterDrag.active = true
        G.masterDrag.touchId = touchId
        DragMasterVolume(tx)
        return
    end
    if G.gameState == "playing" and IsInMoveTrack(tx, ty) then
        G.moveDrag.active = true
        G.moveDrag.touchId = touchId
        DragMoveBartender(ty)
        return
    end
    ProcessPointerInput(tx, ty)
end

function Input.HandleTouchMove(eventType, eventData)
    local touchId = eventData["TouchID"]:GetInt()
    if G.volumeDrag.active and G.volumeDrag.touchId == touchId then
        local tx = eventData["X"]:GetInt() / G.dpr
        DragVolume(tx)
        return
    end
    if G.masterDrag.active and G.masterDrag.touchId == touchId then
        local tx = eventData["X"]:GetInt() / G.dpr
        DragMasterVolume(tx)
        return
    end
    if G.moveDrag.active and G.moveDrag.touchId == touchId then
        local ty = eventData["Y"]:GetInt() / G.dpr
        DragMoveBartender(ty)
    end
end

function Input.HandleTouchEnd(eventType, eventData)
    local touchId = eventData["TouchID"]:GetInt()
    if G.volumeDrag.active and G.volumeDrag.touchId == touchId then
        G.volumeDrag.active = false
        G.volumeDrag.touchId = -1
    end
    if G.masterDrag.active and G.masterDrag.touchId == touchId then
        G.masterDrag.active = false
        G.masterDrag.touchId = -1
    end
    if G.moveDrag.active and G.moveDrag.touchId == touchId then
        G.moveDrag.active = false
        G.moveDrag.touchId = -1
    end
end

return Input
