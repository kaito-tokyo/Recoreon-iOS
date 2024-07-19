#pragma once

#include <stdint.h>

#define INT16_TO_FLOAT_FACTOR 3.0517578125e-05

static inline void copyStereoInt16(float *__nonnull dst, int16_t *__nonnull src,
                                   long numSamples) {
  for (long i = 0; i < numSamples * 2; i++) {
    dst[i] = src[i] * INT16_TO_FLOAT_FACTOR;
  }
}

static inline void copyStereoInt16UpsamplingBy2(float *__nonnull dst,
                                                int16_t *__nonnull src,
                                                long numSamples) {
  for (long i = 0; i < numSamples; i++) {
    float x0 = src[i * 2 + 0] * INT16_TO_FLOAT_FACTOR;
    float y0 = src[i * 2 + 1] * INT16_TO_FLOAT_FACTOR;
    dst[i * 4 + 0] = x0;
    dst[i * 4 + 1] = y0;
    dst[i * 4 + 2] = x0;
    dst[i * 4 + 3] = y0;
  }
}

static inline void copyStereoInt16UpsamplingBy6(float *__nonnull dst,
                                                int16_t *__nonnull src,
                                                long numSamples) {
  for (long i = 0; i < numSamples; i++) {
    float x0 = src[i * 2 + 0] * INT16_TO_FLOAT_FACTOR;
    float y0 = src[i * 2 + 1] * INT16_TO_FLOAT_FACTOR;
    dst[i * 12 + 0] = x0;
    dst[i * 12 + 1] = y0;
    dst[i * 12 + 2] = x0;
    dst[i * 12 + 3] = y0;
    dst[i * 12 + 4] = x0;
    dst[i * 12 + 5] = y0;
    dst[i * 12 + 6] = x0;
    dst[i * 12 + 7] = y0;
    dst[i * 12 + 8] = x0;
    dst[i * 12 + 9] = y0;
    dst[i * 12 + 10] = x0;
    dst[i * 12 + 11] = y0;
  }
}
