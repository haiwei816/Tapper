// ============================================================================
// cyber_tapper.cpp - Cyber Tapper main game node implementation
//
// Corresponds to: scripts/main.lua
// Implements all lifecycle methods, audio management, and coordinates the
// GameState / GameLogic / GameRenderer / InputHandler subsystems.
// ============================================================================
#include "cyber_tapper.h"

// Godot API headers
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// Subsystem headers (to be provided in their own translation units)
// Uncomment these once the companion files exist:
// #include "game_state.h"
// #include "game_logic.h"
// #include "game_renderer.h"
// #include "input_handler.h"

#include <cmath>
#include <cstdlib>
#include <algorithm>

using namespace godot;

namespace cyber_tapper {

// ============================================================================
// Construction / Destruction
// ============================================================================

CyberTapper::CyberTapper() = default;

CyberTapper::~CyberTapper() {
    // unique_ptrs clean up GameState/GameLogic/GameRenderer/InputHandler.
    // Godot child nodes (bgm_player_, sfx pool) are freed by the scene tree.
    sfx_pool_.clear();
}

// ============================================================================
// GDExtension binding
// ============================================================================

void CyberTapper::_bind_methods() {
    // Internal signal callback for viewport resize.
    ClassDB::bind_method(
        D_METHOD("_on_viewport_size_changed"),
        &CyberTapper::on_viewport_size_changed);

    // No exported properties.  All configuration lives in GameState/Config
    // and is driven by code, not the Godot inspector.
}

// ============================================================================
// _ready()  --  corresponds to Lua Start()
// ============================================================================

void CyberTapper::_ready() {
    // Skip game logic when running inside the Godot editor.
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }

    // ---- Window title (Lua: graphics.windowTitle) -------------------------
    DisplayServer::get_singleton()->window_set_title("Cyber Tapper");

    // ---- Resolution -------------------------------------------------------
    recalc_resolution();

    // ---- Game state (Lua: G table from State.lua) -------------------------
    game_state_ = std::make_unique<GameState>();
    game_state_->logical_w = logical_w_;
    game_state_->logical_h = logical_h_;
    game_state_->dpr       = dpr_;
    game_state_->bgm_volume    = bgm_volume_;
    game_state_->master_volume = master_volume_;
    game_state_->recalc_layout();
    game_state_->bartender.y = game_state_->get_lane_y(2); // default lane

    // ---- Callbacks (Lua: G.PlaySfx / G.ApplyBgmGain / G.UploadHighScore) -
    setup_callbacks();

    // ---- Sub-systems ------------------------------------------------------
    game_logic_    = std::make_unique<GameLogic>(game_state_.get(), &callbacks_);
    game_renderer_ = std::make_unique<GameRenderer>(game_state_.get());
    input_handler_ = std::make_unique<InputHandler>(
        game_state_.get(), game_logic_.get(), &callbacks_);

    // ---- Font (Lua: nvgCreateFont) ----------------------------------------
    Ref<Resource> font_res =
        ResourceLoader::get_singleton()->load("res://fonts/MiSans-Regular.ttf");
    if (font_res.is_valid()) {
        font_ = font_res;
    } else {
        UtilityFunctions::print(
            "WARNING: Could not load MiSans-Regular.ttf, using default font");
        // ThemeDB fallback is available at runtime via get_theme_default_font()
        // on a Control.  For Node2D _draw we pass nullptr and let the renderer
        // fall back to Godot's built-in font.
    }
    if (game_renderer_) {
        game_renderer_->set_font(font_);
    }

    // ---- Audio ------------------------------------------------------------
    load_audio_resources();
    create_sfx_pool();
    start_bgm();

    // ---- Viewport resize signal -------------------------------------------
    // Node2D does not receive NOTIFICATION_WM_SIZE_CHANGED directly, so we
    // connect to the root viewport's size_changed signal as the primary
    // resize path.  _notification() acts as a secondary fallback.
    Viewport *vp = get_viewport();
    if (vp) {
        vp->connect("size_changed",
                     Callable(this, "_on_viewport_size_changed"));
    }

    UtilityFunctions::print("=== Cyber Tapper Started ===");
}

// ============================================================================
// _process()  --  corresponds to Lua HandleUpdate()
// ============================================================================

void CyberTapper::_process(double p_delta) {
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }

    // ---- Global timer (Lua: G.time) ---------------------------------------
    game_time_ += p_delta;
    if (game_state_) {
        game_state_->time = game_time_;
    }

    // ---- Screen shake countdown -------------------------------------------
    if (game_state_ && game_state_->shake_timer > 0.0) {
        game_state_->shake_timer -= p_delta;
    }

    // ---- Input: continuous drag updates (Lua: Input.UpdateDrags) -----------
    if (input_handler_) {
        input_handler_->update_drags(p_delta);
        input_handler_->update_bartender_movement(p_delta);
    }

    // ---- Game logic tick (Lua: Logic.UpdateGame) --------------------------
    if (game_state_ &&
        game_state_->game_state_enum == GameState::State::Playing) {
        if (game_logic_) {
            game_logic_->update_game(p_delta);
        }
    }

    // ---- Sync shake state for _draw() quick access ------------------------
    if (game_state_) {
        shake_timer_     = game_state_->shake_timer;
        shake_intensity_ = game_state_->shake_intensity;

        // Sync volume state back (sliders in InputHandler may change these)
        bgm_volume_    = game_state_->bgm_volume;
        master_volume_ = game_state_->master_volume;
    }

    // ---- Request redraw every frame (Lua: NanoVGRender fires each frame) --
    queue_redraw();
}

// ============================================================================
// _draw()  --  corresponds to Lua Renderer.HandleRender()
//
// In Godot, _draw() is called after _process() when queue_redraw() was
// invoked.  The CanvasItem drawing API replaces NanoVG calls.
// GameRenderer translates all the NanoVG primitives from DrawLib.lua and
// Renderer.lua into Godot draw_* calls.
// ============================================================================

void CyberTapper::_draw() {
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }
    if (!game_renderer_ || !game_state_) {
        return;
    }

    // ---- Screen shake (Lua: nvgTranslate for shake) -----------------------
    double shake_x = 0.0;
    double shake_y = 0.0;
    if (shake_timer_ > 0.0) {
        shake_x = (static_cast<double>(std::rand()) / RAND_MAX - 0.5)
                  * shake_intensity_ * 2.0;
        shake_y = (static_cast<double>(std::rand()) / RAND_MAX - 0.5)
                  * shake_intensity_ * 2.0;
        draw_set_transform(Vector2(shake_x, shake_y));
    }

    // ---- Delegate all drawing to GameRenderer -----------------------------
    // GameRenderer::render() calls CanvasItem draw_* methods through the
    // pointer to this Node2D.  It renders in this order (matching Lua):
    //   1. Background + grid
    //   2. Lane back layers (bar surfaces, rails)
    //   3. Sliding drinks
    //   4. Empty bottles
    //   5. Customers (with drink-request bubbles)
    //   6. Lane front layers (front panels, neon edges)
    //   7. Bartender
    //   8. Particles
    //   9. Float texts
    //  10. HUD (score, lives, combo, level, volume sliders)
    //  11. Drink buttons + move track
    //  12. Menu overlay  -or-  Game-over overlay  (depending on state)
    game_renderer_->render(this);

    // ---- Reset transform after shake --------------------------------------
    if (shake_timer_ > 0.0) {
        draw_set_transform(Vector2(0.0, 0.0));
    }
}

// ============================================================================
// _input()  --  corresponds to Lua Handle{KeyDown,MouseClick,...}
// ============================================================================

void CyberTapper::_input(const Ref<InputEvent> &p_event) {
    if (Engine::get_singleton()->is_editor_hint()) {
        return;
    }
    if (input_handler_) {
        input_handler_->handle_input(p_event);
    }
}

// ============================================================================
// _notification()  --  secondary resize path
// ============================================================================

void CyberTapper::_notification(int p_what) {
    // MainLoop::NOTIFICATION_WM_SIZE_CHANGED == 1007 in Godot 4.x.
    // Nodes may or may not receive this depending on propagation settings;
    // the primary resize path is the viewport's "size_changed" signal
    // connected in _ready().  We handle it here as well for robustness.
    constexpr int NOTIF_WM_SIZE_CHANGED = 1007;

    switch (p_what) {
        case NOTIF_WM_SIZE_CHANGED: {
            on_viewport_size_changed();
        } break;
        default:
            break;
    }
}

// ============================================================================
// Viewport resize handler (Lua: HandleScreenMode)
// ============================================================================

void CyberTapper::on_viewport_size_changed() {
    recalc_resolution();
    if (game_state_) {
        game_state_->logical_w = logical_w_;
        game_state_->logical_h = logical_h_;
        game_state_->dpr       = dpr_;
        game_state_->recalc_layout();
    }
}

// ============================================================================
// Resolution calculation (Lua: G.RecalcResolution)
// ============================================================================

void CyberTapper::recalc_resolution() {
    // Godot handles high-DPI scaling internally; we work in logical
    // (viewport) pixels.  This mirrors the Lua code's Mode B approach
    // where logicalW/H = physW/H / dpr, except dpr is always 1.0 here.
    Viewport *vp = get_viewport();
    if (vp) {
        Vector2 size = vp->get_visible_rect().size;
        logical_w_ = size.x;
        logical_h_ = size.y;
    }
    dpr_ = 1.0;
}

// ============================================================================
// Audio: resource loading (Lua: cache:GetResource("Sound", ...))
// ============================================================================

void CyberTapper::load_audio_resources() {
    auto *loader = ResourceLoader::get_singleton();

    // Helper lambda: load a single SFX into the resource map.
    auto load_sfx = [&](const std::string &key, const String &path) {
        Ref<AudioStream> stream = loader->load(path);
        if (stream.is_valid()) {
            sfx_resources_[key] = stream;
        } else {
            UtilityFunctions::print("WARNING: Could not load SFX: ", path);
        }
    };

    // Corresponds to G.sfxServe .. G.sfxGameWin in main.lua Start()
    load_sfx("serve",       "res://audio/sfx/serve_throw.ogg");
    load_sfx("glass_break", "res://audio/sfx/glass_break.ogg");
    load_sfx("angry",       "res://audio/sfx/angry_customer.ogg");
    load_sfx("sip",         "res://audio/sfx/drink_sip.ogg");
    load_sfx("game_over",   "res://audio/sfx/game_over.ogg");
    load_sfx("game_win",    "res://audio/sfx/game_win.ogg");
}

// ============================================================================
// Audio: SFX player pool
//
// Instead of creating/destroying AudioStreamPlayer nodes each time a sound
// plays (Lua: autoRemoveMode = REMOVE_COMPONENT), we pre-allocate a small
// ring-buffer pool and cycle through them.  If all slots are busy the oldest
// one is interrupted -- acceptable for rapid-fire SFX.
// ============================================================================

void CyberTapper::create_sfx_pool() {
    sfx_pool_.reserve(SFX_POOL_SIZE);
    for (int i = 0; i < SFX_POOL_SIZE; ++i) {
        auto *player = memnew(AudioStreamPlayer);
        player->set_name(String("SFXPool_{0}").format(Array::make(i)));
        player->set_bus(StringName("Master")); // Use "SFX" bus if configured
        add_child(player);
        sfx_pool_.push_back(player);
    }
    sfx_pool_index_ = 0;
}

// ============================================================================
// Audio: BGM playback (Lua: StartBGM)
// ============================================================================

void CyberTapper::start_bgm() {
    Ref<AudioStream> bgm_stream =
        ResourceLoader::get_singleton()->load("res://audio/music_bgm.ogg");
    if (!bgm_stream.is_valid()) {
        UtilityFunctions::print("WARNING: Could not load BGM audio");
        return;
    }

    bgm_player_ = memnew(AudioStreamPlayer);
    bgm_player_->set_name("BGM");
    bgm_player_->set_bus(StringName("Master")); // Use "Music" bus if configured
    add_child(bgm_player_);

    bgm_player_->set_stream(bgm_stream);
    // AudioStream looping is set on the stream resource itself in Godot 4.
    // For OGG Vorbis, enable "loop" in the import settings.  If the stream
    // supports set_loop, call it programmatically:
    //   bgm_stream->set("loop", true);  // works for OggVorbis/MP3 streams

    apply_bgm_gain();
    bgm_player_->play();

    UtilityFunctions::print("BGM started");
}

// ============================================================================
// Audio: play a named SFX (Lua: PlaySfx(sound, gain))
//
// Maps string names produced by GameLogic to preloaded AudioStream resources.
// The Lua code maps:
//   G.sfxServe      -> "serve"
//   G.sfxGlassBreak -> "glass_break"
//   G.sfxAngry      -> "angry"
//   G.sfxSip        -> "sip"
//   G.sfxGameOver   -> "game_over"
//   G.sfxGameWin    -> "game_win"
// ============================================================================

void CyberTapper::play_sfx(const std::string &sfx_name, float gain) {
    auto it = sfx_resources_.find(sfx_name);
    if (it == sfx_resources_.end() || !it->second.is_valid()) {
        return;
    }

    // Pick the next player in the ring-buffer pool.
    AudioStreamPlayer *player = sfx_pool_[sfx_pool_index_];
    sfx_pool_index_ = (sfx_pool_index_ + 1) % SFX_POOL_SIZE;

    // If this slot is already playing, it will be interrupted.
    player->stop();
    player->set_stream(it->second);
    player->set_volume_db(linear_to_db(gain * master_volume_));
    player->play();
}

// ============================================================================
// Audio: apply BGM volume (Lua: ApplyBgmGain)
// ============================================================================

void CyberTapper::apply_bgm_gain() {
    if (bgm_player_) {
        bgm_player_->set_volume_db(linear_to_db(bgm_volume_ * master_volume_));
    }
}

// ============================================================================
// Callback setup (Lua: G.PlaySfx = PlaySfx; G.ApplyBgmGain = ...)
//
// These lambdas capture `this` and are passed to GameLogic / InputHandler
// so they can trigger audio and score uploads without a direct dependency
// on the CyberTapper class.
// ============================================================================

void CyberTapper::setup_callbacks() {
    callbacks_.play_sfx = [this](const std::string &sfx_name, float gain) {
        this->play_sfx(sfx_name, gain);
    };

    callbacks_.apply_bgm_gain = [this]() {
        this->apply_bgm_gain();
    };

    callbacks_.upload_high_score = [this](int score) {
        // Placeholder: integrate with platform leaderboard API here.
        // In the Lua original this calls clientCloud:Get / clientCloud:BatchSet
        // to upload to TapTap's cloud leaderboard.
        UtilityFunctions::print(
            "High score upload requested: ", score);
    };
}

// ============================================================================
// Utility: linear gain to decibels
// ============================================================================

float CyberTapper::linear_to_db(float linear) {
    if (linear <= 0.0f) {
        return -80.0f; // Silence
    }
    return 20.0f * std::log10(linear);
}

} // namespace cyber_tapper
