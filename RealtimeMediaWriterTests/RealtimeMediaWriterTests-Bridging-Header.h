#pragma once

#include <stdint.h>

static inline void fillLumaPlane(uint8_t *__nonnull lumaData, long width, long height, long bytesPerRow, long frameIndex) {
  for (long y = 0; y < height; y++) {
    for (long x = 0; x < width; x++) {
      lumaData[y * bytesPerRow + x] = x + y + frameIndex * 3;
    }
  }
}

static inline void fillChromaPlane(uint8_t *__nonnull chromaData, long width, long height, long bytesPerRow, long frameIndex) {
  for (long y = 0; y < height; y++) {
    for (long x = 0; x < width; x++) {
      chromaData[y * bytesPerRow + x] = 128 + y + frameIndex * 2;
      chromaData[y * bytesPerRow + x + 1] = 64 + x + frameIndex * 5;
    }
  }
}
