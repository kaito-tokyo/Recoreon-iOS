#pragma once

#include <stdint.h>
#include <stdio.h>

#define INT16_TO_FLOAT(x) (x * 3.0517578125e-05)

static inline void copyStereoInt16(float *__nonnull dst, int16_t *__nonnull src,
                                   long numSamples) {
  for (long i = 0; i < numSamples * 2; i++) {
    dst[i] = INT16_TO_FLOAT(src[i]);
  }
}

static inline void copyStereoInt16UpsamplingBy2(float *__nonnull dst,
                                                int16_t *__nonnull src,
                                                long numSamples) {
  {
    float x0 = dst[-4];
    float y0 = dst[-3];
    float x1 = INT16_TO_FLOAT(src[0]);
    float y1 = INT16_TO_FLOAT(src[1]);
    for (long j = 1; j <= 2; j++) {
      dst[j * 2 - 4] = x0 + (x1 - x0) * j / 2.0;
      dst[j * 2 - 3] = y0 + (y1 - y0) * j / 2.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = INT16_TO_FLOAT(src[i * 2 + 0]);
    float y0 = INT16_TO_FLOAT(src[i * 2 + 1]);
    float x1 = INT16_TO_FLOAT(src[i * 2 + 2]);
    float y1 = INT16_TO_FLOAT(src[i * 2 + 3]);
    for (long j = 1; j <= 2; j++) {
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
    float x1 = INT16_TO_FLOAT(src[0]);
    float y1 = INT16_TO_FLOAT(src[1]);
    for (long j = 1; j <= 6; j++) {
      dst[j * 2 - 12] = x0 + (x1 - x0) * j / 6.0;
      dst[j * 2 - 11] = y0 + (y1 - y0) * j / 6.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = INT16_TO_FLOAT(src[i * 2 + 0]);
    float y0 = INT16_TO_FLOAT(src[i * 2 + 1]);
    float x1 = INT16_TO_FLOAT(src[i * 2 + 2]);
    float y1 = INT16_TO_FLOAT(src[i * 2 + 3]);
    for (long j = 1; j <= 6; j++) {
      dst[i * 12 + j * 2 + 0] = x0 + (x1 - x0) * j / 6.0;
      dst[i * 12 + j * 2 + 1] = y0 + (y1 - y0) * j / 6.0;
    }
  }
}

static inline long copyStereoInt16UpsamplingFrom44100To48000(
    float *__nonnull dst, int16_t *__nonnull src, long numSamples) {
  long numOutputSamples = numSamples * 48000 / 44100;
  for (long outputIndex = 0; outputIndex < numOutputSamples; outputIndex++) {
    double inputSamplingPoint = outputIndex * 44100 / 48000;
    long inputIndex = inputSamplingPoint;
    double fraction = inputSamplingPoint - inputIndex;

    float x0 = INT16_TO_FLOAT(src[inputIndex * 2 + 0]);
    float y0 = INT16_TO_FLOAT(src[inputIndex * 2 + 1]);
    float x1 = INT16_TO_FLOAT(src[inputIndex * 2 + 2]);
    float y1 = INT16_TO_FLOAT(src[inputIndex * 2 + 3]);

    dst[outputIndex * 2 + 0] = x0 + fraction * (x1 - x0);
    dst[outputIndex * 2 + 1] = y0 + fraction * (y1 - y0);
  }

  return numOutputSamples;
}

static inline void copyMonoInt16(float *__nonnull dst, int16_t *__nonnull src,
                                 long numSamples) {
  for (long i = 0; i < numSamples; i++) {
    float x = INT16_TO_FLOAT(src[i]);
    dst[i * 2] = dst[i * 2 + 1] = x;
  }
}

static inline void copyMonoInt16UpsamplingBy2(float *__nonnull dst,
                                              int16_t *__nonnull src,
                                              long numSamples) {
  {
    float x0 = dst[-4];
    float x1 = INT16_TO_FLOAT(src[0]);
    for (long j = 1; j <= 2; j++) {
      dst[j * 2 - 4] = dst[j * 2 - 3] = x0 + (x1 - x0) * j / 2.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = INT16_TO_FLOAT(src[i + 0]);
    float x1 = INT16_TO_FLOAT(src[i + 1]);
    for (long j = 1; j <= 2; j++) {
      dst[i * 4 + j * 2] = dst[i * 4 + j * 2 + 1] = x0 + (x1 - x0) * j / 2.0;
    }
  }
}

static inline void copyMonoInt16UpsamplingBy6(float *__nonnull dst,
                                              int16_t *__nonnull src,
                                              long numSamples) {
  {
    float x0 = dst[-12];
    float x1 = INT16_TO_FLOAT(src[0]);
    for (long j = 1; j <= 6; j++) {
      dst[j * 2 - 12] = dst[j * 2 - 11] = x0 + (x1 - x0) * j / 6.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = INT16_TO_FLOAT(src[i + 0]);
    float x1 = INT16_TO_FLOAT(src[i + 1]);
    for (long j = 1; j <= 6; j++) {
      dst[i * 12 + j * 2] = dst[i * 12 + j * 2 + 1] = x0 + (x1 - x0) * j / 6.0;
    }
  }
}

static inline float int16ToFloatWithSwap(int16_t reversedValue) {
  uint16_t rawValue = *((uint16_t *)&reversedValue);
  uint16_t rawSwappedValue = (rawValue >> 8) | (rawValue << 8);
  return INT16_TO_FLOAT(*(int16_t *)&rawSwappedValue);
}

static inline void copyStereoInt16WithSwap(float *__nonnull dst,
                                           int16_t *__nonnull src,
                                           long numSamples) {
  for (long i = 0; i < numSamples * 2; i++) {
    dst[i] = int16ToFloatWithSwap(src[i]);
  }
}

static inline void copyStereoInt16UpsamplingBy2WithSwap(float *__nonnull dst,
                                                        int16_t *__nonnull src,
                                                        long numSamples) {
  {
    float x0 = dst[-4];
    float y0 = dst[-3];
    float x1 = int16ToFloatWithSwap(src[0]);
    float y1 = int16ToFloatWithSwap(src[1]);
    for (long j = 1; j <= 2; j++) {
      dst[j * 2 - 4] = x0 + (x1 - x0) * j / 2.0;
      dst[j * 2 - 3] = y0 + (y1 - y0) * j / 2.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = int16ToFloatWithSwap(src[i * 2 + 0]);
    float y0 = int16ToFloatWithSwap(src[i * 2 + 1]);
    float x1 = int16ToFloatWithSwap(src[i * 2 + 2]);
    float y1 = int16ToFloatWithSwap(src[i * 2 + 3]);
    for (long j = 1; j <= 2; j++) {
      dst[i * 4 + j * 2 + 0] = x0 + (x1 - x0) * j / 2.0;
      dst[i * 4 + j * 2 + 1] = y0 + (y1 - y0) * j / 2.0;
    }
  }
}

static inline void copyStereoInt16UpsamplingBy6WithSwap(float *__nonnull dst,
                                                        int16_t *__nonnull src,
                                                        long numSamples) {
  {
    float x0 = dst[-12];
    float y0 = dst[-11];
    float x1 = int16ToFloatWithSwap(src[0]);
    float y1 = int16ToFloatWithSwap(src[1]);
    for (long j = 1; j <= 6; j++) {
      dst[j * 2 - 12] = x0 + (x1 - x0) * j / 6.0;
      dst[j * 2 - 11] = y0 + (y1 - y0) * j / 6.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = int16ToFloatWithSwap(src[i * 2 + 0]);
    float y0 = int16ToFloatWithSwap(src[i * 2 + 1]);
    float x1 = int16ToFloatWithSwap(src[i * 2 + 2]);
    float y1 = int16ToFloatWithSwap(src[i * 2 + 3]);
    for (long j = 1; j <= 6; j++) {
      dst[i * 12 + j * 2 + 0] = x0 + (x1 - x0) * j / 6.0;
      dst[i * 12 + j * 2 + 1] = y0 + (y1 - y0) * j / 6.0;
    }
  }
}

static inline void copyMonoInt16WithSwap(float *__nonnull dst,
                                         int16_t *__nonnull src,
                                         long numSamples) {
  for (long i = 0; i < numSamples; i++) {
    float x = int16ToFloatWithSwap(src[i]);
    dst[i * 2] = dst[i * 2 + 1] = x;
  }
}

static inline void copyMonoInt16UpsamplingBy2WithSwap(float *__nonnull dst,
                                                      int16_t *__nonnull src,
                                                      long numSamples) {
  {
    float x0 = dst[-4];
    float x1 = int16ToFloatWithSwap(src[0]);
    for (long j = 1; j <= 2; j++) {
      dst[j * 2 - 4] = dst[j * 2 - 3] = dst[j * 2 - 3] =
          x0 + (x1 - x0) * j / 2.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = int16ToFloatWithSwap(src[i + 0]);
    float x1 = int16ToFloatWithSwap(src[i + 1]);
    for (long j = 1; j <= 2; j++) {
      dst[i * 4 + j * 2] = dst[i * 4 + j * 2 + 1] = x0 + (x1 - x0) * j / 2.0;
    }
  }
}

static inline void copyMonoInt16UpsamplingBy6WithSwap(float *__nonnull dst,
                                                      int16_t *__nonnull src,
                                                      long numSamples) {
  {
    float x0 = dst[-12];
    float x1 = int16ToFloatWithSwap(src[0]);
    for (long j = 1; j <= 6; j++) {
      dst[j * 2 - 12] = dst[j * 2 - 11] = x0 + (x1 - x0) * j / 6.0;
    }
  }

  for (long i = 0; i < numSamples - 1; i++) {
    float x0 = int16ToFloatWithSwap(src[i + 0]);
    float x1 = int16ToFloatWithSwap(src[i + 1]);
    for (long j = 1; j <= 6; j++) {
      dst[i * 12 + j * 2] = dst[i * 12 + j * 2 + 1] = x0 + (x1 - x0) * j / 6.0;
    }
  }
}
