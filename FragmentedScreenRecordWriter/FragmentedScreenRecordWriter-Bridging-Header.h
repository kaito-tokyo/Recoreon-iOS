#pragma once

#include <stdint.h>

static inline void circCopyInt16ToFloat32(float *__nonnull dst, long dstCount, long dstOffset, int16_t *__nonnull src, long srcCount) {
  long mask = dstCount - 1;
  for (long i = 0; i < srcCount; i++) {
    dst[i & mask] = src[i];
  }
}
