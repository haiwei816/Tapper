// ============================================================================
// cyber_tapper.h - Cyber Tapper main game node (Godot 4.x GDExtension)
//
// Corresponds to: scripts/main.lua
// Entry point Node2D that owns GameState and coordinates all subsystems:
//   audio, input handling, game logic, and rendering.
// ============================================================================
#pragma once

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/audio_stream_player.hpp>
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/classes/input_event.hpp>

#include <functional>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace cyber_tapper {

// ---------------------------------------------------------------------------
// Forward declarations for modules implemented in separate translation units.
// Each mirrors a Lua module from scripts/CyberTapper/.
// ---------------------------------------------------------------------------
class GameState;    // State.lua   - shared game state + layout calculation
class GameLogic;    // GameLogic.lua - entity updates, collisions, scoring
class GameRenderer; // Renderer.lua + DrawLib.lua - all _draw() rendering
class InputHandler; // Input.lua   - keyboard / mouse / touch input

// ---------------------------------------------------------------------------
// GameCallbacks - function slots injected into game modules so they can
// trigger audio playback and score uploads without depending on CyberTapper
// directly.  Mirrors the G.PlaySfx / G.ApplyBgmGain / G.UploadHighScore
// slots that main.lua injects into the Lua G table.
// ---------------------------------------------------------------------------
struct GameCallbacks {
    // Play a named sound effect at the given linear gain (0.0 - 1.0).
    // Valid names: "serve", "glass_break", "angry", "sip", "game_over", "game_win"
    std::function<void(const std::string &sfx_name, float gain)> play_sfx;

    // Re-apply BGM volume after bgm_volume or master_volume changes.
    std::function<void()> apply_bgm_gain;

    // Upload a new high score to the platform leaderboard.
    std::function<void(int score)> upload_high_score;
};

// ---------------------------------------------------------------------------
// CyberTapper - the root scene node
// ---------------------------------------------------------------------------
class CyberTapper : public godot::Node2D {
    GDCLASS(CyberTapper, godot::Node2D)

public:
    CyberTapper();
    ~CyberTapper() override;

    // -- Godot lifecycle ----------------------------------------------------
    void _ready() override;
    void _process(double p_delta) override;
    void _draw() override;
    void _input(const godot::Ref<godot::InputEvent> &p_event) override;
    void _notification(int p_what);

protected:
    static void _bind_methods();

private:
    // -- Resolution / viewport ----------------------------------------------
    double logical_w_ = 0.0;
    double logical_h_ = 0.0;
    double dpr_ = 1.0; // Always 1.0; Godot handles DPI scaling internally.

    // -- Game sub-systems (owned) -------------------------------------------
    std::unique_ptr<GameState>    game_state_;
    std::unique_ptr<GameLogic>    game_logic_;
    std::unique_ptr<GameRenderer> game_renderer_;
    std::unique_ptr<InputHandler> input_handler_;

    GameCallbacks callbacks_;

    // -- Audio --------------------------------------------------------------
    // BGM: persistent AudioStreamPlayer child node.
    godot::AudioStreamPlayer *bgm_player_ = nullptr;
    float bgm_volume_    = 0.3f;  // Mirrors G.bgmVolume
    float master_volume_ = 0.8f;  // Mirrors G.masterVolume

    // SFX resource cache:  name -> preloaded AudioStream.
    std::unordered_map<std::string, godot::Ref<godot::AudioStream>> sfx_resources_;

    // SFX player pool for concurrent one-shot sounds.
    static constexpr int SFX_POOL_SIZE = 8;
    std::vector<godot::AudioStreamPlayer *> sfx_pool_;
    int sfx_pool_index_ = 0;

    // -- Font ---------------------------------------------------------------
    godot::Ref<godot::Font> font_;

    // -- Timing / screen-shake (duplicated from GameState for fast access) --
    double game_time_       = 0.0;
    double shake_timer_     = 0.0;
    double shake_intensity_ = 0.0;

    // -- Private helpers ----------------------------------------------------
    void recalc_resolution();
    void load_audio_resources();
    void start_bgm();
    void create_sfx_pool();
    void play_sfx(const std::string &sfx_name, float gain);
    void apply_bgm_gain();
    void setup_callbacks();
    void on_viewport_size_changed();

    /// Convert linear gain [0,1] to Godot volume_db.
    static float linear_to_db(float linear);
};

} // namespace cyber_tapper
