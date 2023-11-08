#!/bin/bash
dirs=(
  Recoreon
  RecoreonBroadcastUploadExtension
  RecoreonBroadcastUploadExtensionSetupUI
  RecoreonTests
  RecoreonUITests
)

if [[ $1 = format ]]
then swift-format format --in-place --recursive "${dirs[@]}"
else swift-format lint --strict --recursive "${dirs[@]}"
fi
