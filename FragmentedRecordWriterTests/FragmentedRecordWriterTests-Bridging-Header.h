#pragma once

#include <math.h>
#include <stdbool.h>
#include <stdint.h>

#import "../FragmentedRecordWriter/FragmentedRecordWriter-Bridging-Header.h"

static inline void fillLumaPlane(uint8_t *__nonnull lumaData, long width,
                                 long height, long bytesPerRow,
                                 long frameIndex) {
  for (long y = 0; y < height; y++) {
    for (long x = 0; x < width; x++) {
      lumaData[y * bytesPerRow + x] = x + y + frameIndex * 3;
    }
  }
}

static inline void fillChromaPlane(uint8_t *__nonnull chromaData, long width,
                                   long height, long bytesPerRow,
                                   long frameIndex) {
  for (long y = 0; y < height; y++) {
    for (long x = 0; x < width; x++) {
      chromaData[y * bytesPerRow + x] = 128 + y + frameIndex * 2;
      chromaData[y * bytesPerRow + x + 1] = 64 + x + frameIndex * 5;
    }
  }
}

struct DummyAudioGeneratorState {
  void *__nonnull data;
  long numSamples;
  long numChannels;
  long bytesPerSample;
  bool isSwapped;
  double t;
  double tincr;
  double tincr2;
};

static inline void fillAudio(struct DummyAudioGeneratorState *state) {
  long numSamples = state->numSamples;
  long numChannels = state->numChannels;
  double t = state->t;
  double tincr = state->tincr;
  double tincr2 = state->tincr2;

  if (state->bytesPerSample == 1) {
    uint8_t *buffer = state->data;

    for (long i = 0; i < numSamples; i++) {
      t += tincr;
      tincr += tincr2;
      uint8_t value = sin(t) * 100 + 128;

      for (long j = 0; j < numChannels; j++) {
        buffer[i * numChannels + j] = value;
      }
    }
  } else if (state->bytesPerSample == 2) {
    if (state->isSwapped) {
      for (long i = 0; i < numSamples; i++) {
        uint8_t *buffer = state->data;

        t += tincr;
        tincr += tincr2;
        int16_t value = sin(t) * 10000;

        for (long j = 0; j < numChannels; j++) {
          buffer[(i * numChannels + j) * 2 + 0] = *((uint8_t *)&value + 1);
          buffer[(i * numChannels + j) * 2 + 1] = *((uint8_t *)&value + 0);
        }
      }
    } else {
      int16_t *buffer = state->data;

      for (long i = 0; i < numSamples; i++) {
        t += tincr;
        tincr += tincr2;
        int16_t value = sin(t) * 10000;

        for (long j = 0; j < numChannels; j++) {
          buffer[i * numChannels + j] = value;
        }
      }
    }
  }

  state->t = t;
  state->tincr = tincr;
}
