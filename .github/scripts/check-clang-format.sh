#!/usr/bin/env zsh
setopt EXTENDED_GLOB

local -a files=((Recoreon|FragmentedScreenRecordWriter)*/*.(m|mm|h)(.N))

if [[ $1 = format ]]
then clang-format -i "${(o)files[@]}" 
else clang-format --Werror --dry-run "${(o)files[@]}"
fi
