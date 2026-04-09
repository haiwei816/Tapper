// ============================================================================
// game_logic.cpp - Game core logic (ported from Lua: CyberTapper/GameLogic.lua)
//
// INDEX CONVENTION (throughout this file):
//   - Lane indices:       0-based  (0 .. NUM_LANES-1)
//   - Drink type indices: 0-based  (0 .. DRINK_TYPES.size()-1)
//   - Boss drink_sequence values:  0-based
//   - Boss sequence_index:         0-based
//   - Level numbers:               1-based  (1 .. MAX_LEVEL)  -- unchanged
// ============================================================================

#include "game_logic.h"

#include <algorithm>
#include <cmath>
#include <random>
#include <string>

namespace cyber_tapper {

// ---------------------------------------------------------------------------
// Thread-local random engine (seeded once per thread)
// ---------------------------------------------------------------------------
static std::mt19937& rng() {
    static thread_local std::mt19937 engine{std::random_device{}()};
    return engine;
}

// ============================================================================
// Random helpers
// ============================================================================

int GameLogic::rand_int(int min_val, int max_val) {
    std::uniform_int_distribution<int> dist(min_val, max_val);
    return dist(rng());
}

float GameLogic::rand_float() {
    std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    return dist(rng());
}

float GameLogic::rand_float(float min_val, float max_val) {
    std::uniform_real_distribution<float> dist(min_val, max_val);
    return dist(rng());
}

void GameLogic::shuffle_array(std::vector<int>& arr) {
    for (int i = (int)arr.size() - 1; i >= 1; --i) {
        int j = rand_int(0, i);
        std::swap(arr[i], arr[j]);
    }
}

// ============================================================================
// Query helpers
// ============================================================================

float GameLogic::get_patience(const GameState& G) {
    float p = BASE_PATIENCE * (1.0f / (1.0f + (G.level - 1) * 0.1f));
    return std::max(6.0f, p);
}

float GameLogic::get_spawn_interval(const GameState& G) {
    float s = BASE_SPAWN_INTERVAL * (1.0f / (1.0f + (G.level - 1) * 0.15f));
    return std::max(0.8f, s);
}

int GameLogic::get_lane_active_count(const GameState& G, int lane) {
    int count = 0;
    for (const auto& c : G.customers) {
        if (c.lane == lane && c.served_anim <= 0.0f) {
            ++count;
        }
    }
    return count;
}

// ============================================================================
// Particles
// ============================================================================

void GameLogic::create_serve_particles(GameState& G, float x, float y,
                                       int drink_type) {
    const auto& dt = DRINK_TYPES[drink_type];
    for (int i = 0; i < 10; ++i) {
        float angle = rand_float() * static_cast<float>(M_PI) * 2.0f;
        float speed = 50.0f + rand_float() * 100.0f;
        Particle p;
        p.x = x;
        p.y = y;
        p.vx = std::cos(angle) * speed;
        p.vy = std::sin(angle) * speed - 30.0f;
        p.life = 0.4f + rand_float() * 0.3f;
        p.max_life = 0.7f;
        p.r = dt.r;
        p.g = dt.g;
        p.b = dt.b;
        p.size = 3.0f + rand_float() * 3.0f;
        G.particles.push_back(p);
    }
}

void GameLogic::update_particles(GameState& G, float dt) {
    for (auto it = G.particles.begin(); it != G.particles.end();) {
        it->life -= dt;
        it->x += it->vx * dt;
        it->y += it->vy * dt;
        it->vy += 80.0f * dt; // gravity
        if (it->life <= 0.0f) {
            it = G.particles.erase(it);
        } else {
            ++it;
        }
    }
}

// ============================================================================
// Floating text
// ============================================================================

void GameLogic::add_float_text(GameState& G, const std::string& text,
                               float x, float y, float r, float g, float b) {
    FloatText ft;
    ft.text = text;
    ft.x = x;
    ft.y = y;
    ft.r = r;
    ft.g = g;
    ft.b = b;
    ft.life = 1.2f;
    ft.max_life = 1.2f;
    G.float_texts.push_back(ft);
}

void GameLogic::update_float_texts(GameState& G, float dt) {
    for (auto it = G.float_texts.begin(); it != G.float_texts.end();) {
        it->life -= dt;
        it->y -= 40.0f * dt; // float upward
        if (it->life <= 0.0f) {
            it = G.float_texts.erase(it);
        } else {
            ++it;
        }
    }
}

// ============================================================================
// Life / game-over / win
// ============================================================================

void GameLogic::game_over(GameState& G, GameCallbacks& cb) {
    G.game_state = GameStateEnum::GameOver;
    G.game_win = false;
    if (cb.play_sfx) cb.play_sfx("game_over", 0.8f);
    if (G.score > G.high_score) {
        G.high_score = G.score;
    }
    if (cb.upload_high_score) cb.upload_high_score(G.score);
}

void GameLogic::game_win(GameState& G, GameCallbacks& cb) {
    G.game_state = GameStateEnum::GameOver;
    G.game_win = true;
    if (cb.play_sfx) cb.play_sfx("game_win", 0.8f);
    if (G.score > G.high_score) {
        G.high_score = G.score;
    }
    if (cb.upload_high_score) cb.upload_high_score(G.score);
}

void GameLogic::lose_life(GameState& G, GameCallbacks& cb) {
    G.lives -= 1;
    G.combo = 0;
    if (G.lives <= 0) {
        game_over(G, cb);
    }
}

// ============================================================================
// Spawning
// ============================================================================

void GameLogic::spawn_customer(GameState& G) {
    int lane = rand_int(0, NUM_LANES - 1);

    // If the chosen lane is full, find an alternative.
    if (get_lane_active_count(G, lane) >= 6) {
        bool found = false;
        for (int try_lane = 0; try_lane < NUM_LANES; ++try_lane) {
            if (get_lane_active_count(G, try_lane) < 6) {
                lane = try_lane;
                found = true;
                break;
            }
        }
        if (!found) return; // all lanes full
    }

    // Drink type (0-based). Unlock more types as level increases.
    int max_type = std::min((int)DRINK_TYPES.size(), G.level); // level is 1-based
    int drink_type = rand_int(0, max_type - 1);

    // Higher levels may require multiple drinks.
    int drinks_needed = 1;
    if (G.level >= 2 && rand_float() < 0.3f) drinks_needed = 2;
    if (G.level >= 4 && rand_float() < 0.2f) drinks_needed = 3;

    int pos_in_queue = get_lane_active_count(G, lane);
    float target_x = G.layout.counter_right - 40.0f
                     - pos_in_queue * QUEUE_SPACING;

    // Random body colour (0-based).
    int color_idx = rand_int(0, (int)CUSTOMER_COLORS.size() - 1);
    const auto& cc = CUSTOMER_COLORS[color_idx];

    Customer c;
    c.lane = lane;
    c.x = G.layout.counter_left - 30.0f;
    c.target_x = target_x;
    c.drink_type = drink_type;
    c.drinks_needed = drinks_needed;
    c.drinks_received = 0;
    c.wait_time = 0.0f;
    c.body_r = cc.r;
    c.body_g = cc.g;
    c.body_b = cc.b;
    c.bob_phase = rand_float() * static_cast<float>(M_PI) * 2.0f;
    c.alive = true;
    c.served_anim = 0.0f;
    c.angry_timer = 0.0f;
    c.is_boss = false;
    G.customers.push_back(c);
}

void GameLogic::spawn_boss(GameState& G) {
    int lane = rand_int(0, NUM_LANES - 1);
    int pos_in_queue = get_lane_active_count(G, lane);
    float target_x = G.layout.counter_right - 40.0f
                     - pos_in_queue * QUEUE_SPACING;

    // Boss drink sequence: all 6 types in random order (0-based).
    std::vector<int> seq = {0, 1, 2, 3, 4, 5};
    shuffle_array(seq);

    Customer c;
    c.lane = lane;
    c.x = G.layout.counter_left - 30.0f;
    c.target_x = target_x;
    c.drink_type = seq[0]; // first required drink (0-based)
    c.drinks_needed = 6;
    c.drinks_received = 0;
    c.wait_time = 0.0f;
    c.body_r = 255.0f;
    c.body_g = 80.0f;
    c.body_b = 40.0f;
    c.bob_phase = rand_float() * static_cast<float>(M_PI) * 2.0f;
    c.alive = true;
    c.served_anim = 0.0f;
    c.angry_timer = 0.0f;
    c.is_boss = true;
    c.drink_sequence = seq;
    c.sequence_index = 0; // 0-based
    G.customers.push_back(c);
}

// ============================================================================
// Queue recalculation
// ============================================================================

void GameLogic::recalc_lane_queues(GameState& G) {
    for (int lane = 0; lane < NUM_LANES; ++lane) {
        // Gather active customers in this lane.
        std::vector<Customer*> lane_customers;
        for (auto& c : G.customers) {
            if (c.lane == lane && c.served_anim <= 0.0f) {
                lane_customers.push_back(&c);
            }
        }
        // Sort by x descending (rightmost first -- closest to bartender).
        std::sort(lane_customers.begin(), lane_customers.end(),
                  [](const Customer* a, const Customer* b) {
                      return a->x > b->x;
                  });
        // Reassign target positions.
        for (int idx = 0; idx < (int)lane_customers.size(); ++idx) {
            lane_customers[idx]->target_x =
                G.layout.counter_right - 40.0f - idx * QUEUE_SPACING;
        }
    }
}

// ============================================================================
// Entity updates
// ============================================================================

void GameLogic::update_customers(GameState& G, float dt, GameCallbacks& cb) {
    recalc_lane_queues(G);

    for (auto it = G.customers.begin(); it != G.customers.end();) {
        Customer& c = *it;
        bool removed = false;

        // Angry cooldown timer.
        if (c.angry_timer > 0.0f) {
            c.angry_timer -= dt;
        }

        // --- Sip animation ---
        if (c.sip_anim > 0.0f) {
            c.sip_anim -= dt;
            if (c.sip_anim <= 0.0f && c.exit_after_sip) {
                // Spawn empty bottle at customer position.
                EmptyBottle bottle;
                bottle.lane = c.lane;
                bottle.x = c.x;
                bottle.drink_type = c.sip_drink_type;
                bottle.trail_timer = 0.0f;
                G.empty_bottles.push_back(bottle);

                c.exit_after_sip = false;
                c.sip_drink_type = -1;
                c.served_anim = 0.8f;
            }
        }

        // --- Served exit animation ---
        if (c.served_anim > 0.0f) {
            c.served_anim -= dt;
            c.x -= 120.0f * dt; // walk off screen to the left
            if (c.served_anim <= 0.0f ||
                c.x < G.layout.counter_left - 40.0f) {
                it = G.customers.erase(it);
                removed = true;
            }
        } else if (c.sip_anim > 0.0f) {
            // Gentle bob while sipping.
            c.bob_phase += dt * 2.0f;
        } else {
            // --- Walking / waiting ---
            if (std::abs(c.x - c.target_x) > 2.0f) {
                // Walk toward target position.
                if (c.x < c.target_x) {
                    c.x = std::min(c.x + CUSTOMER_WALK_SPEED * dt, c.target_x);
                } else {
                    c.x = std::max(c.x - CUSTOMER_WALK_SPEED * dt, c.target_x);
                }
                c.bob_phase += dt * 4.0f; // faster bob while walking
            } else {
                c.x = c.target_x;
                c.bob_phase += dt * 2.0f; // idle bob

                c.wait_time += dt;
                float patience = get_patience(G);
                if (c.is_boss) patience *= 3.0f;

                if (c.wait_time >= patience) {
                    // Customer ran out of patience.
                    if (cb.play_sfx) cb.play_sfx("angry", 0.7f);

                    if (c.is_boss) {
                        for (int k = 0; k < 3; ++k) lose_life(G, cb);
                    } else {
                        lose_life(G, cb);
                    }

                    G.shake_timer = 0.3f;
                    G.shake_intensity = c.is_boss ? 8.0f : 4.0f;

                    float cust_y = G.get_lane_y(c.lane)
                                   + G.layout.customer_offset_y;
                    const char* angry_text =
                        c.is_boss ? "BOSS ANGRY! -3" : "ANGRY!";
                    add_float_text(G, angry_text, c.x, cust_y - 25.0f,
                                   255, 80, 50);

                    it = G.customers.erase(it);
                    removed = true;
                }
            }
        }

        if (!removed) ++it;
    }
}

// ---------------------------------------------------------------------------

void GameLogic::update_drinks(GameState& G, float dt, GameCallbacks& cb) {
    const Layout& layout = G.layout;
    Bartender& bartender = G.bartender;

    for (auto it = G.drinks.begin(); it != G.drinks.end();) {
        Drink& d = *it;
        d.x -= DRINK_SPEED * dt;
        d.trail_timer += dt;

        float serve_y = G.get_lane_y(d.lane);

        // Find the rightmost active customer in the same lane.
        Customer* hit = nullptr;
        float hit_x = -1.0f;
        for (auto& c : G.customers) {
            bool is_sipping = (c.sip_anim > 0.0f);
            bool can_hit = (c.lane == d.lane) && (c.served_anim <= 0.0f)
                           && (!is_sipping || !c.exit_after_sip);
            if (can_hit && c.x > hit_x) {
                hit_x = c.x;
                hit = &c;
            }
        }

        bool drink_removed = false;

        // --- Check customer collision ---
        if (hit != nullptr && d.x <= hit->x + 8.0f) {
            if (hit->drink_type == d.drink_type) {
                // === Correct drink ===
                hit->drinks_received += 1;
                G.total_served += 1;
                G.combo += 1;
                if (G.combo > G.best_combo) G.best_combo = G.combo;

                int points = 10 * G.level + G.combo * 5;
                if (hit->is_boss) points += 20;
                G.score += points;

                int remaining = hit->drinks_needed - hit->drinks_received;
                float cust_y = serve_y + layout.customer_offset_y;

                if (cb.play_sfx) cb.play_sfx("sip", 0.5f);

                if (remaining <= 0) {
                    // Customer fully served -- start sip-then-exit.
                    hit->sip_anim = 1.0f;
                    hit->sip_drink_type = d.drink_type;
                    hit->exit_after_sip = true;

                    add_float_text(G, "+" + std::to_string(points),
                                   hit->x, cust_y - 20.0f, 0, 255, 255);
                    if (hit->is_boss) {
                        add_float_text(G, "BOSS DOWN!",
                                       hit->x, cust_y - 45.0f, 255, 200, 40);
                    }
                } else {
                    // Customer still needs more drinks.
                    hit->sip_anim = 1.0f;
                    hit->sip_drink_type = d.drink_type;
                    hit->exit_after_sip = false;
                    hit->wait_time = std::max(0.0f, hit->wait_time - 4.0f);

                    add_float_text(G, "+" + std::to_string(points),
                                   hit->x, cust_y - 20.0f, 0, 255, 255);

                    // Advance boss drink sequence.
                    if (hit->is_boss && !hit->drink_sequence.empty()) {
                        hit->sequence_index += 1;
                        if (hit->sequence_index <
                            (int)hit->drink_sequence.size()) {
                            hit->drink_type =
                                hit->drink_sequence[hit->sequence_index];
                        }
                        add_float_text(G,
                                       std::to_string(remaining) + " LEFT",
                                       hit->x, cust_y - 45.0f, 255, 160, 40);
                    }
                }

                if (G.combo > 1) {
                    add_float_text(G,
                                   "x" + std::to_string(G.combo) + " COMBO!",
                                   hit->x,
                                   serve_y + layout.customer_offset_y - 40.0f,
                                   255, 255, 60);
                }

                create_serve_particles(G, hit->x, serve_y, d.drink_type);

                // --- Level progression ---
                G.level_served += 1;
                int target = (G.level == MAX_LEVEL) ? SERVES_LEVEL6
                                                    : SERVES_PER_LEVEL;
                if (G.level_served >= target) {
                    if (G.level < MAX_LEVEL) {
                        G.level += 1;
                        G.level_served = 0;
                        add_float_text(
                            G,
                            "LEVEL " + std::to_string(G.level) + "!",
                            G.logical_w / 2.0f,
                            G.logical_h / 2.0f - 30.0f,
                            255, 255, 60);
                        if (G.level == MAX_LEVEL) {
                            spawn_boss(G);
                        }
                    } else {
                        game_win(G, cb);
                    }
                }
            } else {
                // === Wrong drink ===
                if (!hit->wrong_hit_this_frame) {
                    hit->wrong_hit_this_frame = true;
                    hit->served_anim = 0.8f;
                    hit->angry_timer = 0.6f;

                    if (cb.play_sfx) cb.play_sfx("angry", 0.7f);

                    if (hit->is_boss) {
                        for (int k = 0; k < 3; ++k) lose_life(G, cb);
                    } else {
                        lose_life(G, cb);
                    }
                    G.combo = 0;
                    G.shake_timer = 0.3f;
                    G.shake_intensity = hit->is_boss ? 8.0f : 4.0f;

                    const char* wrong_text =
                        hit->is_boss ? "WRONG! -3" : "WRONG!";
                    add_float_text(G, wrong_text,
                                   hit->x,
                                   serve_y + layout.customer_offset_y - 20.0f,
                                   255, 60, 60);
                }
            }
            it = G.drinks.erase(it);
            drink_removed = true;

        } else if (d.x <= layout.bartender_x_left + 15.0f) {
            // Drink reached the far-left end of the counter.
            if (bartender.lane == d.lane && bartender.left_drink_anim <= 0.0f) {
                // Bartender catches the returning drink.
                int points = 3;
                G.score += points;
                add_float_text(G, "CATCH +" + std::to_string(points),
                               layout.bartender_x_left,
                               serve_y - 20.0f,
                               200, 255, 200);
                bartender.serve_anim = 0.5f;
                bartender.left_drink_anim = 1.0f;
                bartender.left_drink_type = d.drink_type;
                it = G.drinks.erase(it);
                drink_removed = true;
            } else if (d.x < layout.counter_left - 40.0f) {
                // Drink fell off the counter.
                if (cb.play_sfx) cb.play_sfx("glass_break", 0.7f);
                lose_life(G, cb);
                G.combo = 0;
                G.shake_timer = 0.3f;
                G.shake_intensity = 4.0f;
                add_float_text(G, "MISS!",
                               layout.counter_left + 10.0f,
                               serve_y - 20.0f,
                               255, 100, 50);
                it = G.drinks.erase(it);
                drink_removed = true;
            }
        }

        if (!drink_removed) ++it;
    }
}

// ---------------------------------------------------------------------------

void GameLogic::update_empty_bottles(GameState& G, float dt,
                                     GameCallbacks& cb) {
    const Layout& layout = G.layout;
    Bartender& bartender = G.bartender;

    for (auto it = G.empty_bottles.begin(); it != G.empty_bottles.end();) {
        EmptyBottle& b = *it;
        b.x -= BOTTLE_RETURN_SPEED * dt;
        b.trail_timer += dt;

        bool removed = false;

        if (b.x <= layout.bartender_x_left + 15.0f) {
            if (bartender.lane == b.lane) {
                // Bartender catches the empty bottle.
                int points = 5;
                G.score += points;
                add_float_text(G, "CATCH +" + std::to_string(points),
                               layout.bartender_x_left,
                               G.get_lane_y(b.lane) - 20.0f,
                               200, 255, 200);
                bartender.serve_anim = 0.5f;
                it = G.empty_bottles.erase(it);
                removed = true;
            } else if (b.x < layout.counter_left - 40.0f) {
                // Bottle fell off the counter.
                if (cb.play_sfx) cb.play_sfx("glass_break", 0.7f);
                lose_life(G, cb);
                G.combo = 0;
                G.shake_timer = 0.3f;
                G.shake_intensity = 4.0f;
                add_float_text(G, "MISS!",
                               layout.counter_left - 10.0f,
                               G.get_lane_y(b.lane) - 20.0f,
                               255, 100, 50);
                it = G.empty_bottles.erase(it);
                removed = true;
            }
        }

        if (!removed) ++it;
    }
}

// ============================================================================
// Public: serve_drink
// ============================================================================

void GameLogic::serve_drink(GameState& G, int drink_type, GameCallbacks& cb) {
    if (G.game_state != GameStateEnum::Playing) return;

    // drink_type is 0-based: valid range [0, DRINK_TYPES.size()-1].
    if (drink_type < 0 || drink_type >= (int)DRINK_TYPES.size()) return;

    // Only unlocked drink types can be served (unlock count = level, 1-based).
    int unlocked_count = std::min((int)DRINK_TYPES.size(), G.level);
    if (drink_type >= unlocked_count) return;

    if (cb.play_sfx) cb.play_sfx("serve", 0.6f);
    G.bartender.serve_anim = 1.0f;

    Drink d;
    d.lane = G.bartender.lane; // 0-based
    d.x = G.layout.bartender_x_right - 10.0f;
    d.drink_type = drink_type;
    d.trail_timer = 0.0f;
    G.drinks.push_back(d);

    // Serve particles at bartender position.
    const auto& dt_info = DRINK_TYPES[drink_type];
    float serve_y = G.get_lane_y(G.bartender.lane);
    for (int i = 0; i < 5; ++i) {
        Particle p;
        p.x = G.layout.bartender_x_right;
        p.y = serve_y;
        p.vx = -(float)rand_int(50, 120);
        p.vy = (rand_float() - 0.5f) * 50.0f;
        p.life = 0.3f + rand_float() * 0.2f;
        p.max_life = 0.5f;
        p.r = dt_info.r;
        p.g = dt_info.g;
        p.b = dt_info.b;
        p.size = 3.0f + rand_float() * 3.0f;
        G.particles.push_back(p);
    }
}

// ============================================================================
// Public: move_bartender
// ============================================================================

void GameLogic::move_bartender(GameState& G, int delta) {
    int new_lane = G.bartender.target_lane + delta;
    // 0-based bounds check: valid range [0, NUM_LANES-1].
    if (new_lane >= 0 && new_lane < NUM_LANES) {
        G.bartender.target_lane = new_lane;
    }
}

// ============================================================================
// Public: reset_game
// ============================================================================

void GameLogic::reset_game(GameState& G) {
    G.customers.clear();
    G.drinks.clear();
    G.empty_bottles.clear();
    G.particles.clear();
    G.float_texts.clear();

    G.score = 0;
    G.lives = MAX_LIVES;
    G.level = 1;
    G.total_served = 0;
    G.level_served = 0;
    G.combo = 0;
    G.best_combo = 0;
    G.spawn_timer = 0.0f;

    // Bartender starts on the second lane (0-based index 1).
    G.bartender.lane = 1;
    G.bartender.target_lane = 1;
    G.bartender.y = G.get_lane_y(1);
    G.bartender.serve_anim = 0.0f;
    G.bartender.left_drink_anim = 0.0f;
    G.bartender.left_drink_type = -1;
    G.bartender.anim_time = 0.0f;

    G.shake_timer = 0.0f;
    G.game_win = false;
    G.game_state = GameStateEnum::Playing;
}

// ============================================================================
// Public: update_game
// ============================================================================

void GameLogic::update_game(GameState& G, float dt, GameCallbacks& cb) {
    // Reset per-frame flags.
    for (auto& c : G.customers) {
        c.wrong_hit_this_frame = false;
    }

    // --- Bartender ---
    Bartender& bartender = G.bartender;

    // Snap lane so collision checks use the current target.
    bartender.lane = bartender.target_lane;

    bartender.anim_time += dt;

    if (bartender.serve_anim > 0.0f) {
        bartender.serve_anim -= dt * 4.0f;
    }
    if (bartender.left_drink_anim > 0.0f) {
        bartender.left_drink_anim -= dt;
        if (bartender.left_drink_anim <= 0.0f) {
            bartender.left_drink_type = -1;
        }
    }

    // --- Customer spawning ---
    G.spawn_timer += dt;
    if (G.spawn_timer >= get_spawn_interval(G)) {
        G.spawn_timer = 0.0f;
        spawn_customer(G);
    }

    // --- Entity updates ---
    update_customers(G, dt, cb);
    update_drinks(G, dt, cb);
    update_empty_bottles(G, dt, cb);
    update_particles(G, dt);
    update_float_texts(G, dt);
}

} // namespace cyber_tapper
