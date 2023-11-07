#!/usr/bin/env zsh
setopt EXTENDED_GLOB

local -a files=(**/*.sh(.N))
files+=(.github/**/*.sh)
files=(${files:#Pods/**})

shellcheck "${(o)files[@]}" 
