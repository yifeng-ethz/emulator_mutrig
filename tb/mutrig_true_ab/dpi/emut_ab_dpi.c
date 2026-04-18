#include <stdint.h>

static uint32_t rng_state = 1u;
static uint32_t cycle_ctr = 0u;

static uint32_t xorshift32(void) {
    uint32_t x = rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    if (x == 0u) {
        x = 1u;
    }
    rng_state = x;
    return x;
}

static uint64_t pack_l2_word(uint32_t channel, uint32_t tcc, uint32_t tfine, uint32_t ecc, uint32_t efine) {
    uint64_t word = 0u;

    word |= ((uint64_t)(channel & 0x1fu)) << 43;
    word |= ((uint64_t)(tcc & 0x7fffu)) << 27;
    word |= ((uint64_t)(tfine & 0x1fu)) << 22;
    word |= ((uint64_t)(ecc & 0x7fffu)) << 6;
    word |= ((uint64_t)(efine & 0x1fu)) << 1;
    word |= ((uint64_t)1u);
    return word;
}

void emut_ab_init(int seed) {
    rng_state = (seed == 0) ? 1u : (uint32_t)seed;
    cycle_ctr = 0u;
}

unsigned long long emut_ab_next_offer(int rate_cfg, int short_mode, int *valid) {
    uint32_t gate_rnd;
    uint32_t channel_rnd;
    uint32_t fine_a;
    uint32_t fine_b;
    uint32_t tfine;
    uint32_t efine;
    uint32_t coarse;

    (void)short_mode;

    cycle_ctr += 1u;
    gate_rnd = xorshift32();
    if ((gate_rnd & 0xffffu) >= (uint32_t)(rate_cfg & 0xffff)) {
        *valid = 0;
        return 0ull;
    }

    channel_rnd = xorshift32();
    fine_a = xorshift32() & 0x1fu;
    fine_b = xorshift32() & 0x1fu;
    coarse = cycle_ctr & 0x7fffu;

    if (fine_a <= fine_b) {
        tfine = fine_a;
        efine = fine_b;
    } else {
        tfine = fine_b;
        efine = fine_a;
    }

    *valid = 1;
    return pack_l2_word(channel_rnd & 0x1fu, coarse, tfine, coarse, efine);
}
