-- ============================================================================
-- main.lua - Cyber Tapper 入口协调器
-- 职责：引擎初始化、音频加载、云端排行榜、事件注册
-- ============================================================================

require "LuaScripts/Utilities/Sample"

local G        = require "CyberTapper.State"
local Logic    = require "CyberTapper.GameLogic"
local Input    = require "CyberTapper.Input"
local Renderer = require "CyberTapper.Renderer"

-- ============================================================================
-- 音频辅助
-- ============================================================================

local function ApplyBgmGain()
    if G.bgmSource then
        G.bgmSource.gain = G.bgmVolume * G.masterVolume
    end
end

local function PlaySfx(sound, gain)
    if sound and G.bgmNode then
        local src = G.bgmNode:CreateComponent("SoundSource")
        src.soundType = "Effect"
        src.gain = (gain or 0.6) * G.masterVolume
        src.autoRemoveMode = REMOVE_COMPONENT
        src:Play(sound)
    end
end

local function StartBGM()
    local bgm = cache:GetResource("Sound", "audio/music_1774750187496.ogg")
    if bgm then
        bgm.looped = true
        ---@type Scene
        local scene = Scene()
        G.bgmNode = scene:CreateChild("BGM")
        G.bgmSource = G.bgmNode:CreateComponent("SoundSource")
        G.bgmSource.soundType = "Music"
        G.bgmSource.gain = G.bgmVolume * G.masterVolume
        G.bgmSource:Play(bgm)
        print("BGM started")
    else
        print("WARNING: Could not load BGM")
    end
end

-- ============================================================================
-- 云端排行榜
-- ============================================================================

local function FetchLeaderboard()
    if not clientCloud then return end
    if G.leaderboardLoading then return end
    G.leaderboardLoading = true
    G.leaderboardLoaded = false

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

            clientCloud:GetUserRank(clientCloud.userId, "high_score", {
                ok = function(rank, scoreValue)
                    G.myRank = rank
                end
            })

            clientCloud:GetRankTotal("high_score", {
                ok = function(total)
                    G.leaderboardTotal = total
                end
            })

            if #userIds == 0 then
                G.leaderboard = entries
                G.leaderboardLoading = false
                G.leaderboardLoaded = true
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
                    G.leaderboard = entries
                    G.leaderboardLoading = false
                    G.leaderboardLoaded = true
                end,
                onError = function(errorCode)
                    G.leaderboard = entries
                    G.leaderboardLoading = false
                    G.leaderboardLoaded = true
                end
            })
        end,
        error = function(code, reason)
            print("获取排行榜失败: " .. tostring(reason))
            G.leaderboardLoading = false
        end
    }, "best_level", "best_combo")
end

local function UploadHighScore(newScore)
    if not clientCloud then return end
    clientCloud:Get("high_score", {
        ok = function(values, iscores)
            G.myCloudHighScore = iscores.high_score or 0
            if newScore > G.myCloudHighScore then
                clientCloud:BatchSet()
                    :SetInt("high_score", newScore)
                    :SetInt("best_level", G.level)
                    :SetInt("best_combo", G.bestCombo)
                    :Save("更新最高分", {
                        ok = function()
                            G.myCloudHighScore = newScore
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

-- ============================================================================
-- 注入跨模块函数槽
-- ============================================================================

G.PlaySfx = PlaySfx
G.ApplyBgmGain = ApplyBgmGain
G.UploadHighScore = UploadHighScore
G.FetchLeaderboard = FetchLeaderboard

-- ============================================================================
-- 引擎生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = "Cyber Tapper"
    SampleStart()
    SampleInitMouseMode(MM_FREE)

    G.RecalcResolution()
    G.RecalcLayout()
    G.bartender.y = G.GetLaneY(2)

    G.vg = nvgCreate(1)
    if G.vg == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    G.fontNormal = nvgCreateFont(G.vg, "sans", "Fonts/MiSans-Regular.ttf")
    if G.fontNormal == -1 then
        print("ERROR: Could not load font")
        return
    end

    StartBGM()

    G.sfxServe      = cache:GetResource("Sound", "audio/sfx/serve_throw.ogg")
    G.sfxGlassBreak = cache:GetResource("Sound", "audio/sfx/glass_break.ogg")
    G.sfxAngry       = cache:GetResource("Sound", "audio/sfx/angry_customer.ogg")
    G.sfxSip         = cache:GetResource("Sound", "audio/sfx/drink_sip.ogg")
    G.sfxGameOver    = cache:GetResource("Sound", "audio/sfx/game_over.ogg")
    G.sfxGameWin     = cache:GetResource("Sound", "audio/sfx/game_win.ogg")

    -- 注册事件（全局函数包装器，引擎要求全局函数名）
    SubscribeToEvent(G.vg, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseClick")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("TouchBegin", "HandleTouchBegin")
    SubscribeToEvent("TouchMove", "HandleTouchMove")
    SubscribeToEvent("TouchEnd", "HandleTouchEnd")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")

    FetchLeaderboard()

    print("=== Cyber Tapper Started ===")
end

function Stop()
    if G.vg ~= nil then
        nvgDelete(G.vg)
        G.vg = nil
    end
    if G.bgmSource then
        G.bgmSource:Stop()
    end
end

-- ============================================================================
-- 全局事件包装器（引擎 SubscribeToEvent 要求全局函数名）
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    G.time = G.time + dt

    if G.shakeTimer > 0 then
        G.shakeTimer = G.shakeTimer - dt
    end

    Input.UpdateDrags(dt)
    Input.UpdateBartenderMovement(dt)

    if G.gameState == "playing" then
        Logic.UpdateGame(dt)
    end
end

function HandleRender(eventType, eventData)
    Renderer.HandleRender(eventType, eventData)
end

function HandleKeyDown(eventType, eventData)
    Input.HandleKeyDown(eventType, eventData)
end

function HandleMouseClick(eventType, eventData)
    Input.HandleMouseClick(eventType, eventData)
end

function HandleMouseUp(eventType, eventData)
    Input.HandleMouseUp(eventType, eventData)
end

function HandleTouchBegin(eventType, eventData)
    Input.HandleTouchBegin(eventType, eventData)
end

function HandleTouchMove(eventType, eventData)
    Input.HandleTouchMove(eventType, eventData)
end

function HandleTouchEnd(eventType, eventData)
    Input.HandleTouchEnd(eventType, eventData)
end

function HandleScreenMode(eventType, eventData)
    G.RecalcResolution()
    G.RecalcLayout()
end
