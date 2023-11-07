#!/usr/bin/env zsh
setopt EXTENDED_GLOB

local -a files=(Recoreon*/*.(m|mm|h)(.N))

clang-format --Werror --dry-run "${(o)files[@]}" 
