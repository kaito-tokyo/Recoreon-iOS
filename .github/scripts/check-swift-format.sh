#!/bin/bash
dirs=(
  Recoreon
  RecoreonBroadcastUploadExtension
  RecoreonBroadcastUploadExtensionSetupUI
  RecoreonTests
  RecoreonUITests
)
swift-format lint --strict --recursive "${dirs[@]}"
