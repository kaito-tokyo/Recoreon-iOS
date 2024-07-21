#!/bin/bash
dirs=(
  FragmentedRecordWriter
  FragmentedRecordWriterTests
  Recoreon
  RecoreonBroadcastUploadExtension
  RecoreonTests
  RecoreonUITests
)

if [[ $1 = format ]]
then swift-format format --in-place --recursive "${dirs[@]}"
else swift-format lint --strict --recursive "${dirs[@]}"
fi
