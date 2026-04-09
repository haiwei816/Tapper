// ============================================================================
// game_logic.h - Game core logic (ported from Lua: CyberTapper/GameLogic.lua)
//
// All lane and drink-type indices are 0-based (C++ convention).
//   Lua lanes:       1..NUM_LANES     -> C++ lanes:       0..NUM_LANES-1
//   Lua drink types: 1..6             -> C++ drink types: 0..5
//   Lua sequence_index: 1-based       -> C++ sequence_index: 0-based
// ============================================================================
#ifndef CYBER_TAPPER_GAME_LOGIC_H
#define CYBER_TAPPER_GAME_LOGIC_H

#include "config.h"
#include "types.h"
#include "game_state.h"

#include <functional>
#include <string>

namespace cyber_tapper {

// ---------------------------------------------------------------------------
// Callback interface -- the host (Godot node) injects concrete implementations
// for sound effects and cloud score upload.
// ---------------------------------------------------------------------------
struct GameCallbacks {
    /// Play a named sound effect at the given volume (0..1).
    /// Names: "serve", "glass_break", "angry", "sip", "game_over", "game_win"
    std::function<void(const std::string& sfx_name, float volume)> play_sfx;

    /// Upload the player's final score to the cloud leaderboard.
    std::function<void(int score)> upload_high_score;
};

// ---------------------------------------------------------------------------
// GameLogic -- pure-static helper class that operates on a GameState reference.
// No instances are created; every method takes GameState& (and optionally
// GameCallbacks&) as the first argument.
// ---------------------------------------------------------------------------
class GameLogic {
public:
    // === Query helpers =====================================================

    /// Current patience duration (seconds) scaled by level.
    static float get_patience(const GameState& G);

    /// Current spawn interval (seconds) scaled by level.
    static float get_spawn_interval(const GameState& G);

    /// Number of active (non-exiting) customers in a 0-based lane.
    static int get_lane_active_count(const GameState& G, int lane);

    // === Player actions ====================================================

    /// Serve a drink of the given 0-based type from the bartender's lane.
    static void serve_drink(GameState& G, int drink_type, GameCallbacks& cb);

    /// Move the bartender by +1 (down) or -1 (up) lane.
    static void move_bartender(GameState& G, int delta);

    // === Game flow ==========================================================

    /// Reset all game state for a new round and enter Playing state.
    static void reset_game(GameState& G);

    /// Advance the entire game simulation by dt seconds.
    static void update_game(GameState& G, float dt, GameCallbacks& cb);

private:
    // === Particles & floating text =========================================
    static void create_serve_particles(GameState& G, float x, float y,
                                       int drink_type);
    static void update_particles(GameState& G, float dt);

    static void add_float_text(GameState& G, const std::string& text,
                               float x, float y, float r, float g, float b);
    static void update_float_texts(GameState& G, float dt);

    // === Life / game-over ==================================================
    static void game_over(GameState& G, GameCallbacks& cb);
    static void game_win(GameState& G, GameCallbacks& cb);
    static void lose_life(GameState& G, GameCallbacks& cb);

    // === Spawning ==========================================================
    static void spawn_customer(GameState& G);
    static void spawn_boss(GameState& G);

    // === Per-frame entity updates ==========================================
    static void recalc_lane_queues(GameState& G);
    static void update_customers(GameState& G, float dt, GameCallbacks& cb);
    static void update_drinks(GameState& G, float dt, GameCallbacks& cb);
    static void update_empty_bottles(GameState& G, float dt,
                                     GameCallbacks& cb);

    // === Random helpers (thin wrappers around <random>) ====================
    static void shuffle_array(std::vector<int>& arr);

    /// Inclusive integer random in [min_val, max_val].
    static int rand_int(int min_val, int max_val);

    /// Uniform float in [0, 1).
    static float rand_float();

    /// Uniform float in [min_val, max_val).
    static float rand_float(float min_val, float max_val);
};

} // namespace cyber_tapper

#endif // CYBER_TAPPER_GAME_LOGIC_H
