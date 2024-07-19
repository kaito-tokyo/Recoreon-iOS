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
  {
    float x0 = dst[-12];
    float y0 = dst[-11];
    float x1 = src[0] * INT16_TO_FLOAT_FACTOR;
    float y1 = src[1] * INT16_TO_FLOAT_FACTOR;
    for (long j = 1; j < 6; j++) {
      dst[j * 2 - 12] = x0 + (x1 - x0) * j / 6.0;
      dst[j * 2 - 11] = y0 + (y1 - y0) * j / 6.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = src[i * 2 + 0] * INT16_TO_FLOAT_FACTOR;
    float y0 = src[i * 2 + 1] * INT16_TO_FLOAT_FACTOR;
    float x1 = src[i * 2 + 2] * INT16_TO_FLOAT_FACTOR;
    float y1 = src[i * 2 + 3] * INT16_TO_FLOAT_FACTOR;
    for (long j = 0; j < 2; j++) {
      dst[i * 4 + j * 2 + 0] = x0 + (x1 - x0) * j / 2.0;
      dst[i * 4 + j * 2 + 1] = y0 + (y1 - y0) * j / 2.0;
    }
  }
}

static inline void copyStereoInt16UpsamplingBy6(float *__nonnull dst,
                                                int16_t *__nonnull src,
                                                long numSamples) {
  {
    float x0 = dst[-12];
    float y0 = dst[-11];
    float x1 = src[0] * INT16_TO_FLOAT_FACTOR;
    float y1 = src[1] * INT16_TO_FLOAT_FACTOR;
    for (long j = 1; j < 6; j++) {
      dst[j * 2 - 12] = x0 + (x1 - x0) * j / 6.0;
      dst[j * 2 - 11] = y0 + (y1 - y0) * j / 6.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = src[i * 2 + 0] * INT16_TO_FLOAT_FACTOR;
    float y0 = src[i * 2 + 1] * INT16_TO_FLOAT_FACTOR;
    float x1 = src[i * 2 + 2] * INT16_TO_FLOAT_FACTOR;
    float y1 = src[i * 2 + 3] * INT16_TO_FLOAT_FACTOR;
    for (long j = 0; j < 6; j++) {
      dst[i * 12 + j * 2 + 0] = x0 + (x1 - x0) * j / 6.0;
      dst[i * 12 + j * 2 + 1] = y0 + (y1 - y0) * j / 6.0;
    }
  }
}
