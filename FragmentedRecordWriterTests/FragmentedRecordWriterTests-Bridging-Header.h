#pragma once

#include <math.h>
#include <stdint.h>
#include <stdio.h>

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
  int16_t *__nonnull data;
  long numSamples;
  long numChannels;
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

  for (long i = 0; i < numSamples; i++) {
    t += tincr;
    tincr += tincr2;
    int16_t value = sin(t) * 10000;

    for (long j = 0; j < numChannels; j++) {
      state->data[i * numChannels + j] = value;
    }
  }

  state->t = t;
  state->tincr = tincr;
}
